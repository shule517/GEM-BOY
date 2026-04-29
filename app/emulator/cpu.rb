# CPU (Sharp LR35902)
#
# Game Boy (DMG) の CPU。Z80 と Intel 8080 を混ぜたような 8bit プロセッサで、
# クロック 4.194304 MHz、1 フレーム (1/60 秒) あたり約 70,000 サイクル相当を回す。
#
# ここでは「命令を載せる枠組み」だけを用意する。具体的なオペコードはステップ B-2 以降で
# `@opcodes` テーブルへ追加していく方針。未実装のオペコードを踏むと例外で停止するため、
# ブート ROM が実際に必要とする命令だけが自然に浮かび上がる(ROADMAP.md / B-1 参照)。
#
# === レジスタ ===
# Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
#
#   8bit:  A  B  C  D  E  H  L  F     汎用 7 + フラグ 1
#   16bit: SP  PC                     スタックポインタ + プログラムカウンタ
#   pair:  AF, BC, DE, HL             8bit ペアを 16bit としても扱える(B-2 で追加)
#
# F レジスタの bit 構成:
#
#   bit7  Z (Zero)        演算結果が 0 のとき 1
#   bit6  N (Subtract)    直前が減算系なら 1(DAA で参照)
#   bit5  H (Half-Carry)  下位 4bit からの繰り上がり/下がり
#   bit4  C (Carry)       上位からの繰り上がり/下がり
#   bit3                  常に0
#   bit2                  常に0
#   bit1                  常に0
#   bit0                  常に0
#
# === 命令ディスパッチ ===
# gbops オペコード表: https://izik1.github.io/gbops/
#
# `@opcodes` は 256 要素の配列で、各要素が「その命令を実行して消費サイクル数を返す lambda」。
# CB-prefix 命令(0xCB に続く 2 バイト目)は B-3 で別テーブルとして追加する。
class CPU
  # レジスタ: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#cpu-registers-and-flags
  attr_accessor :a, :f, # 8bitレジスタ: Accumulator, Flags(High / Low)
                :b, :c, # 8bitレジスタ(High / Low)
                :d, :e, # 8bitレジスタ(High / Low)
                :h, :l, # 8bitレジスタ(High / Low)
                :sp, # スタックポインタ
                :pc, # プログラムカウンタ 今メモリのどこを読んでいるか
                :ime, # Interrupt Master Enable(割り込みマスタ有効フラグ) 1の時に処理を割り込む https://gbdev.io/pandocs/Interrupts.html
                :halted, # CPUの一時停止中フラグ https://gbdev.io/pandocs/halt.html
                :opcodes, # CPUの命令一覧 https://izik1.github.io/gbops/
                :mmu

  def initialize(mmu)
    @mmu = mmu

    # ブート ROM 経由で起動するので全レジスタ 0 から始める。
    # (skip_boot 起動なら A=0x01, F=0xB0, PC=0x0100, SP=0xFFFE 等)
    @a = @b = @c = @d = @e = @h = @l = @f = 0
    @sp = 0 # スタックポインタ
    @pc = 0 # プログラムカウンタ
    @ime = false  # 割り込み許可フラグ(Interrupt Master Enable)
    @halted = false # CPUの一時停止中フラグ

    @opcodes = build_opcode_table
  end

  # １つ命令を実行する
  def step
    return 4 if halted # CPUが一時停止中。何もせずに4サイクル消費。 https://gbdev.io/pandocs/halt.html

    opcode = fetch_byte
    puts "opcode 0x#{opcode.to_s(16).rjust(2, '0').upcase} at PC=0x#{((pc - 1) & 0xFFFF).to_s(16).rjust(4, '0').upcase}"
    handler = opcodes[opcode]
    raise "Unimplemented opcode 0x#{opcode.to_s(16).rjust(2, '0').upcase} at PC=0x#{((pc - 1) & 0xFFFF).to_s(16).rjust(4, '0').upcase}" if handler.nil?
    handler.call
  end

  # cycles_targetサイクル分だけ実行する
  # 連続実行モード。DragonRuby の 1 tick (1/60 秒) で約 70,000 サイクルを回したいので、
  # 1 命令ずつ呼ばれるオーバーヘッドを避けるためにループを CPU 側に閉じ込める。
  def run(cycles_target)
    cycles = 0
    cycles += step while cycles < cycles_target
    cycles
  end

  private

  # PCは、16bitレジスタ(Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html)
  def fetch_byte
    byte = @mmu.read(pc) # PCから1バイト読み込む
    @pc = (pc + 1) & 0xFFFF # PCを1つ進める。16bit(0xFFFF)を超えたら0に戻る。
    byte
  end

  # PC が指す 2バイトをリトルエンディアンで読む(下位バイトが先)。
  # Game Boy のメモリレイアウトはリトルエンディアン(https://gbdev.io/pandocs/CPU_Instruction_Set.html)
  def fetch_word
    lo = fetch_byte
    hi = fetch_byte
    (hi << 8) | lo
  end

  # F レジスタ(bit7=Z, bit6=N, bit5=H, bit4=C、下位 4bit は常に 0)の各ビットを更新する。
  # true なら 1、false なら 0に変更する。
  # 引数名は gbops 表記に揃えている(`negative` は Pan Docs 正式名では Subtract フラグ)。
  # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#the-flags-register-lower-8-bits-of-af-register
  def set_flags(zero: nil, negative: nil, half_carry: nil, carry: nil)
    @f = (@f & 0b01111111) | (zero       ? 1 << 7 : 0) unless zero.nil?        # bit7 Zero
    @f = (@f & 0b10111111) | (negative   ? 1 << 6 : 0) unless negative.nil?    # bit6 Negative (Subtract)
    @f = (@f & 0b11011111) | (half_carry ? 1 << 5 : 0) unless half_carry.nil?  # bit5 Half Carry
    @f = (@f & 0b11101111) | (carry      ? 1 << 4 : 0) unless carry.nil?       # bit4 Carry
  end

  # opcodeテーブル
  # CPUの命令一覧 https://izik1.github.io/gbops/
  # GB CPU 命令リファレンス(RGBDS 公式マニュアル) https://rgbds.gbdev.io/docs/v1.0.1/gbz80.7
  def build_opcode_table
    table = Array.new(256, nil)
    table[0x00] = -> { 4 } # NOP: 何もしない。4サイクル進む。
    table[0x21] = -> { @l = fetch_byte; @h = fetch_byte; 12 }  # LD HL,u16: 8bitをL。8bitをHに設定
    table[0x31] = -> { @sp = fetch_word; 12 }  # LD SP,u16: 16bitをSPに設定
    table[0xAF] = -> { @a = 0; @f = 0b10000000; 4 } # XOR A,A
    table[0xC3] = -> { @pc = fetch_word; 16 } # JP u16
    table[0xF3] = -> { @ime = false; 4 } # DI: IMEフラグをクリアして割り込みを無効
    table[0xFA] = -> { @a = fetch_word; 16 } # LD A,(u16)
    table[0xFE] = -> { byte = fetch_byte; set_flags(zero: a == byte, negative: true, half_carry: (a & 0x1111) < (byte & 0x1111), carry: a < byte); 8 } # CP A,u8: Compare(比較)
    table
  end
end
