require 'app/core_ext/last'
require 'app/emulator/bit'

# MMU (Memory Management Unit)
#
# CPU からのメモリアクセスを、アドレスに応じて適切な領域へ振り分けるルーター。
# Game Boy には実際には MMU という専用チップは存在せず、SoC 内部のバス調停回路が
# この役割を果たしているが、エミュレータ実装では「アドレス → 物理領域」の対応を
# 1 クラスにまとめると見通しが良いので慣習的に MMU と呼ばれる。
#
# === Game Boy のメモリマップ (16bit アドレス空間 = 64KB) ===
# Pan Docs: https://gbdev.io/pandocs/Memory_Map.html
#
#   0x0000-0x3FFF  ROM Bank 00      カートリッジ ROM 先頭 16KB(常時アクセス可)
#   0x4000-0x7FFF  ROM Bank 01..NN  MBC で切り替え可能な 16KB バンク(MBC 非対応の今は固定)
#   0x8000-0x9FFF  VRAM             8KB。タイルデータ + 背景マップ + ウィンドウマップ
#   0xA000-0xBFFF  External RAM     カートリッジ側 RAM。バッテリーバックアップでセーブに使う(今は未対応)
#   0xC000-0xCFFF  WRAM Bank 0      4KB
#   0xD000-0xDFFF  WRAM Bank 1      4KB(CGB なら切り替え可、DMG では固定)
#   0xE000-0xFDFF  Echo RAM         WRAM の鏡像。実機ハードウェアの副産物。Pan Docs は使用非推奨
#   0xFE00-0xFE9F  OAM              160B = 40 スプライト × 4 バイト(Y, X, タイル番号, 属性)
#   0xFEA0-0xFEFF  使用禁止領域       read は 0xFF を返すのが慣例(実機は不定)
#   0xFF00-0xFF7F  I/O Registers    128B。後述の各種 I/O レジスタが分布
#   0xFF80-0xFFFE  HRAM             127B。CPU からのアクセスが速い特殊 RAM
#   0xFFFF         IE               Interrupt Enable レジスタ(1 バイトだが地位が特別)
#
# === 主な I/O レジスタ (0xFF00-0xFF7F) ===
# Pan Docs: https://gbdev.io/pandocs/Hardware_Reg_List.html
#
#   0xFF00  P1/JOYP   ジョイパッド(キー入力)
#   0xFF01  SB        Serial Buffer(送信データ)
#   0xFF02  SC        Serial Control(転送制御)
#   0xFF04  DIV       Divider Register(16384Hz でインクリメント)
#   0xFF05  TIMA      Timer Counter
#   0xFF06  TMA       Timer Modulo
#   0xFF07  TAC       Timer Control
#   0xFF0F  IF        Interrupt Flag(発生した割り込み種別)
#   0xFF40  LCDC      LCD Control(画面 ON/OFF、BG/Window/Sprite 表示)
#   0xFF41  STAT      LCD Status(モード、LY=LYC 比較)
#   0xFF42  SCY       BG スクロール Y
#   0xFF43  SCX       BG スクロール X
#   0xFF44  LY        現在描画中のスキャンライン (0..153)
#   0xFF45  LYC       LY と比較される値
#   0xFF46  DMA       OAM DMA 転送開始
#   0xFF47  BGP       BG パレット
#   0xFF48  OBP0      Sprite パレット 0
#   0xFF49  OBP1      Sprite パレット 1
#   0xFF4A  WY        Window Y
#   0xFF4B  WX        Window X (+7 オフセット)
#
# === VRAM の論理構造 (0x8000-0x9FFF) ===
# Tile Data: https://gbdev.io/pandocs/Tile_Data.html
# Tile Maps: https://gbdev.io/pandocs/Tile_Maps.html
#
#   0x8000-0x97FF  Tile Data    384 タイル分。1 タイル = 16 バイト = 8x8 px の 2bpp
#   0x9800-0x9BFF  Tile Map 0   32x32 = 1024 バイト。BG/Window 用タイル番号配列
#   0x9C00-0x9FFF  Tile Map 1   同上、もう 1 セット
#
# === OAM の構造 (0xFE00-0xFE9F) ===
# Pan Docs: https://gbdev.io/pandocs/OAM.html
#
#   1 スプライト = 4 バイト × 40 個 = 160 バイト
#     +0  Y 座標 (-16 オフセット)
#     +1  X 座標 (-8 オフセット)
#     +2  タイル番号
#     +3  属性 (パレット / 反転 / 優先度)
class MMU
  attr_reader :serial_buffer

  # I/O レジスタアドレス(Pan Docs の慣用名と同じ)
  SB = 0xFF01  # Serial Buffer: 送信したい 1 バイト
  SC = 0xFF02  # Serial Control: 転送制御
  SC_TRANSFER_START = 0x81  # SC への書き込みがこの値のとき転送開始 (bit7=1, bit0=1)

  def initialize(cartridge, skip_boot: false, boot_rom: nil)
    @cartridge = cartridge

    # 各領域は「サイズちょうどの 0 埋め配列」として確保する(各要素は 0..0xFF)。
    @vram = Array.new(0x2000, 0)  # [ 8 KB, 0x8000..0x9FFF] / VRAM (Video RAM): PPU が画面を作るためのメモリ。タイルデータとタイルマップ置き場。CPU と PPU が共有
    @wram = Array.new(0x2000, 0)  # [ 8 KB, 0xC000..0xDFFF] / WRAM (Work RAM): ゲームプログラムが自由に使う汎用 RAM。変数・配列・構造体などの一時データ置き場
    @hram = Array.new(0x7F,   0)  # [127 B, 0xFF80..0xFFFE] / HRAM (High RAM): CPU に内蔵された高速 RAM。OAM DMA 転送中もアクセス可能なので割り込みハンドラやスタックを置くのが定石
    @oam  = Array.new(0xA0,   0)  # [160 B, 0xFE00..0xFE9F] / OAM (Object Attribute Memory): スプライト 40 個分の属性テーブル(1 スプライト 4 バイト × 40 = 160 B)
    @io   = Array.new(0x80,   0)  # [128 B, 0xFF00..0xFF7F] / I/O Registers: ハードウェア制御の窓口。キー入力/タイマー/LCD/シリアル等が各バイトに割り当てられたメモリマップド I/O
    @ie   = 0                     # [  1 B, 0xFFFF        ] / IE (Interrupt Enable): どの割り込み(V-Blank/LCD/Timer/Serial/Joypad)を有効にするかを示すビットフラグ

    # ブートROM(256B)重畳: skip_boot=falseかつboot_romが渡されたとき0x0000-0x00FFをブートROMで覆う
    # CPUがPC=0x0000から起動して256バイトを実行し、最後に0xFF50へ非ゼロ書き込みすると外れてカートリッジが見える
    # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#monochrome-models-dmg0-dmg-mgb
    @boot_rom = boot_rom
    @boot_rom_enabled = !skip_boot && !boot_rom.nil?

    # シリアル送信履歴。0xFF02 ← 0x81 が発火するたびに 0xFF01 の文字が追記される。
    # Blargg のテスト結果("Passed" / "Failed XX") はこの経路でしか届かない。
    @serial_buffer = ''

    setup_post_boot_io if skip_boot
  end

  # アドレスに対応する領域から 1バイト読み込む
  # 未対応・使用禁止領域は 0xFF(実機の挙動)。CPU 側で nil 演算事故を防ぐ意図もある。
  def read_u8(address:)
    return @boot_rom[address] if @boot_rom_enabled && address < 0x0100 # ブートROM重畳中は先頭256Bだけ差し替える
    case address
    when 0x0000..0x7FFF then @cartridge.read(address)
    when 0x8000..0x9FFF then @vram[address - 0x8000]
    when 0xC000..0xDFFF then @wram[address - 0xC000]
    when 0xFE00..0xFE9F then @oam[address - 0xFE00]
    when 0xFF00..0xFF7F then @io[address - 0xFF00]
    when 0xFF80..0xFFFE then @hram[address - 0xFF80]
    when 0xFFFF then @ie
    else 0xFF
    end
  end

  # アドレスに対応する領域へ 1バイト書き込む
  # ROM 領域 (0x0000-0x7FFF) はあえて分岐に入れていない
  # (MBC 対応後はここでバンク切り替えレジスタの判定が入る)
  def write_u8(address:, value:)
    value &= 0xFF # 1バイトにする(下位8bitのみ)

    case address
    when 0x8000..0x9FFF then @vram[address - 0x8000] = value
    when 0xC000..0xDFFF then @wram[address - 0xC000] = value
    when 0xFE00..0xFE9F then @oam[address - 0xFE00] = value
    when 0xFF00..0xFF7F then @io[address - 0xFF00] = value; handle_serial(address, value); handle_boot_rom_disable(address, value)
    when 0xFF80..0xFFFE then @hram[address - 0xFF80] = value
    when 0xFFFF then @ie = value
    end
  end

  # 16bit を 2 バイトに分けてリトルエンディアンで書く(下位 → 上位 の順)。
  # LD (u16),SP (0x08) などで使う。address+1 は 16bit でラップ(0xFFFF→0x0000)。
  def write_u16(address:, value:)
    write_u8(address: address, value: Bit.low_byte(value))
    write_u8(address: Bit.wrap_u16(address + 1), value: Bit.high_byte(value))
  end

  # 16bit を 2 バイトに分けてリトルエンディアンで読む(下位 → 上位 の順)。
  # 16bit ジャンプテーブルや関数ポインタの取得で使う。
  def read_u16(address:)
    low  = read_u8(address: address)
    high = read_u8(address: Bit.wrap_u16(address + 1))
    Bit.make_u16(high: high, low: low)
  end

  # 内部状態として I/O を直接触りたいとき用(タイマー割り込み等で使う)。
  # write_u8() を経由するとシリアル判定が走ってしまうので、その副作用を避ける裏口。
  def write_io_direct(address, value)
    @io[address - 0xFF00] = value & 0xFF
  end

  private

  # ブートROM 完走後の I/O レジスタ初期値を設定する(skip_boot 起動でブートROM をスキップするため)
  # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#hardware-registers
  def setup_post_boot_io
    write_io_direct(0xFF40, 0x91) # LCDC: LCD ON + BG ON + unsigned addressing
    write_io_direct(0xFF47, 0xFC) # BGP : 標準パレット(色0=白、色1〜3=黒)
  end

  # ブートROM無効化レジスタ(0xFF50)への書き込み処理
  # 非ゼロを書き込まれた瞬間に重畳を解除する(以後0x0000-0x00FFはカートリッジが見える)
  # 一度解除したら再有効化はできない(実機ハードウェアでも同じ)
  # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#monochrome-models-dmg0-dmg-mgb
  def handle_boot_rom_disable(address, value)
    return if address != 0xFF50 || value == 0
    @boot_rom_enabled = false
  end

  # シリアルポートの送信プロトコル
  # Pan Docs: https://gbdev.io/pandocs/Serial_Data_Transfer_(Link_Cable).html
  #
  #   SB (0xFF01) 送信したい 1 バイト
  #   SC (0xFF02) bit7 = Transfer Start Flag (0=待機, 1=開始)
  #               bit1 = Clock Speed (CGB のみ。DMG では使わない)
  #               bit0 = Shift Clock (0=外部 / 1=内部)
  #
  # 0xFF02 ← 0x81 (= 1000_0001b) は「内部クロックで送信開始」の意味。
  # 実機ではこの後 8 サイクルかけて 8bit を Link Cable に送出するが、
  # エミュレータでは即時に「送信完了」として扱って充分(Blargg もそれを前提にしている)。
  def handle_serial(address, value)
    return if address != SC || value != SC_TRANSFER_START

    # SB に置かれた 1 バイトを ASCII 文字として取り出す。
    char = @io[SB - 0xFF00].chr

    # ターミナルへ即時出力。Blargg のリアルタイム進捗を見るのに必要。
    $stdout.print char
    $stdout.flush

    # 画面表示用にも追記。テスト結果は最大数百文字なのでリングバッファで頭を切る。
    @serial_buffer << char
    @serial_buffer = @serial_buffer.last(500)

    # bit7(Transfer Start Flag)を落として「転送完了」を Blargg に通知する。
    # ここを忘れると Blargg は 1 文字目で永久ループに入る。
    @io[SC - 0xFF00] = 0x01
  end
end
