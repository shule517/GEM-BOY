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
#   bit0-3                常に 0(書いても保持されない)
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
                :opcodes # CPUの命令一覧 https://izik1.github.io/gbops/

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

  # PC が指す 2 バイトをリトルエンディアンで読む(下位バイトが先)。
  # Game Boy のメモリレイアウトはリトルエンディアン(Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html)
  def fetch_word
    lo = fetch_byte
    hi = fetch_byte
    (hi << 8) | lo
  end

  # opcodeテーブル
  # CPUの命令一覧 https://izik1.github.io/gbops/
  def build_opcode_table
    table = Array.new(256, nil)
    table[0x00] = -> { 4 }  # NOP: 何もしない。4サイクル進む。
    table
  end
end
