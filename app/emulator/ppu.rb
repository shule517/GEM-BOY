require 'app/emulator/bit'

# PPU (Picture Processing Unit)
#
# Game Boy の画面描画チップ。CPU の消費サイクル数を受け取って時間を進め、
# スキャンラインの進行を MMU の LY レジスタ(0xFF44)に反映する。
#
# === 1 フレームの構造 ===
# Pan Docs Rendering: https://gbdev.io/pandocs/Rendering.html
#
#   1 フレーム = 70224 T-cycle = 154 スキャンライン × 456 T-cycle/line
#
#   LY = 0..143  描画ライン(画面に見える 144 行)
#     Mode 2 (OAM Scan):  80 T-cycle
#     Mode 3 (Drawing):  172 T-cycle(本実装では固定で良い)
#     Mode 0 (HBlank):   204 T-cycle
#     → 合計 456 T-cycle で 1 ライン完成、LY を +1
#
#   LY = 144..153  VBlank(画面外、ゲームロジックの暇な時間)
#     Mode 1 (VBlank): 456 T-cycle × 10 ライン
#     → LY=154 で 0 に戻って次フレーム
#
# C-1 では「LY を時間とともに進める」最小機能のみ実装。
# 実際のピクセル生成(render_scanline)は C-2 で実装する。
#
# === I/O レジスタ ===
# Pan Docs LCDC: https://gbdev.io/pandocs/LCDC.html
# Pan Docs STAT: https://gbdev.io/pandocs/STAT.html
#
#   0xFF40  LCDC  LCD Control(bit7=LCD ON/OFF, bit0=BG ON/OFF など)
#   0xFF41  STAT  LCD Status(現在のモード、LY=LYC 比較)
#   0xFF42  SCY   BG スクロール Y
#   0xFF43  SCX   BG スクロール X
#   0xFF44  LY    現在のスキャンライン番号 (0..153)
#   0xFF45  LYC   LY と比較される値
#   0xFF47  BGP   BG パレット
class PPU
  # I/O レジスタアドレス(Pan Docs の慣用名と同じ)
  LCDC = 0xFF40
  STAT = 0xFF41
  SCY  = 0xFF42
  SCX  = 0xFF43
  LY   = 0xFF44
  LYC  = 0xFF45
  BGP  = 0xFF47

  # 画面サイズ(可視領域、Pan Docs で固定値として規定)
  SCREEN_WIDTH  = 160
  SCREEN_HEIGHT = 144

  # 1 スキャンラインに要する T-cycle 数
  # (Mode 2: 80 + Mode 3: 172 + Mode 0: 204 = 456)
  CYCLES_PER_SCANLINE = 456

  # 1 フレームのスキャンライン数(描画 144 + VBlank 10)
  SCANLINES_PER_FRAME = 154

  # 描画領域の最終ライン(これより大きい LY は VBlank)
  VBLANK_START_LY = 144

  attr_reader :framebuffer, :ly

  def initialize(mmu)
    @mmu = mmu
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(SCREEN_WIDTH * SCREEN_HEIGHT, 0)
  end

  # CPU が消費したサイクル数だけ PPU も時間を進める。
  # 456 サイクル経過するごとに 1 スキャンラインを描画して LY を +1。
  # LY=154 で 0 に戻る(1 フレーム完成)。
  #
  # LCD が OFF(LCDC bit7 = 0)のとき何もしない。
  # ROM が VRAM クリア中などで LCD を切ることがあるため、その間は LY 進行も止める。
  def step(cycles)
    return unless lcd_on?

    @cycles += cycles
    while @cycles >= CYCLES_PER_SCANLINE
      @cycles -= CYCLES_PER_SCANLINE
      render_scanline if @ly < VBLANK_START_LY
      @ly = (@ly + 1) % SCANLINES_PER_FRAME
      @mmu.write_io_direct(LY, @ly)
    end
  end

  private

  # LCDC bit7 が 1 のとき LCD が ON。0 のときは画面非表示で LY 進行を止める。
  # Pan Docs: https://gbdev.io/pandocs/LCDC.html#lcdc7--lcd-enable
  def lcd_on?
    (@mmu.read(address: LCDC) & 0x80) != 0
  end

  # 1 スキャンライン分のピクセルを framebuffer に書き込む。
  # C-1 では空(LY を進めるだけで描画はしない)。
  # C-2 で BG タイル描画ロジックを実装する。
  def render_scanline
    # C-2 で実装
  end
end
