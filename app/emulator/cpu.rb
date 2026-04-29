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

    opcode = fetch_u8
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

  # 16bit 値から上位 8bit を取り出す。
  # 例: high_byte(0x1234) #=> 0x12
  # レジスタペア setter(BC=, DE=, HL=)で上位バイトを上位レジスタへ振り分けるときに使う。
  def high_byte(value)
    (value & 0xFF00) >> 8
  end

  # 16bit 値から下位 8bit を取り出す。
  # 例: low_byte(0x1234) #=> 0x34
  # レジスタペア setter(BC=, DE=, HL=)で下位バイトを下位レジスタへ振り分けるときに使う。
  def low_byte(value)
    value & 0x00FF
  end

  # PCは、16bitレジスタ(Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html)
  def fetch_u8
    byte = mmu.read(pc) # PCから1バイト読み込む
    self.pc = wrap_u16(pc + 1) # PCを1つ進める
    byte
  end

  # 16bit にマスクして wrap させる(下位 16bit のみ残す)。
  # PC の +1 オーバーフロー(0xFFFF→0x0000)、JR の負オフセット、
  # ADD HL,BC のキャリーアウトなど、16bit 演算結果を正規化するときに使う。
  def wrap_u16(n)
    n & 0xFFFF
  end

  # PC が指す 2バイトをリトルエンディアンで読む(下位バイトが先)。
  # Game Boy のメモリレイアウトはリトルエンディアン(https://gbdev.io/pandocs/CPU_Instruction_Set.html)
  def fetch_u16
    lo = fetch_u8
    hi = fetch_u8
    (hi << 8) | lo
  end

  # PC が指す 1バイトを符号付き(-128〜+127)として読む。JR i8 や ADD SP,i8 で使う。
  # 2の補数表現: bit7 が 1 の値(0x80〜0xFF)を負数として解釈する。
  def fetch_i8
    byte = fetch_u8
    byte -= 256 if byte[7] == 1
    byte
  end

  # F レジスタ(bit7=Z, bit6=N, bit5=H, bit4=C、下位 4bit は常に 0)の各ビットを更新する。
  # true なら 1、false なら 0に変更する。
  # 引数名は gbops 表記に揃えている(`negative` は Pan Docs 正式名では Subtract フラグ)。
  # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#the-flags-register-lower-8-bits-of-af-register
  def set_flags(zero: nil, negative: nil, half_carry: nil, carry: nil)
    self.zero = zero unless zero.nil?                   # bit7 Zero
    self.negative = negative unless negative.nil?       # bit6 Negative (Subtract)
    self.half_carry = half_carry unless half_carry.nil? # bit5 Half Carry
    self.carry = carry unless carry.nil?                # bit4 Carry
  end

  def zero = f[7]
  def negative = f[6]
  def half_carry = f[5]
  def carry = f[4]

  def zero=(value)
    self.f = (f & 0b01111111) | (value ? 1 << 7 : 0) # bit7 Zero
  end

  def negative=(value)
    self.f = (f & 0b10111111) | (value ? 1 << 6 : 0) # bit6 Negative (Subtract)
  end

  def half_carry=(value)
    self.f = (f & 0b11011111) | (value ? 1 << 5 : 0) # bit5 Half Carry
  end

  def carry=(value)
    self.f = (f & 0b11101111) | (value ? 1 << 4 : 0) # bit4 Carry
  end

  def bc=(value)
    self.b = high_byte(value)
    self.c = low_byte(value)
  end

  def de=(value)
    self.d = high_byte(value)
    self.e = low_byte(value)
  end

  def hl=(value)
    self.h = high_byte(value)
    self.l = low_byte(value)
  end

  private

  # opcodeテーブル
  # CPUの命令一覧 https://izik1.github.io/gbops/
  # GB CPU 命令リファレンス(RGBDS 公式マニュアル) https://rgbds.gbdev.io/docs/v1.0.1/gbz80.7
  def build_opcode_table
    table = Array.new(256, nil)

    # ============================================================
    # 制御 / システム (Control / System)
    # ============================================================
    table[0x00] = -> { 4 } # NOP: 何もしない。4サイクル進む。
    # table[0x10] = -> { 4 }  # STOP
    # table[0x76] = -> { 4 }  # HALT
    table[0xF3] = -> { self.ime = false; 4 } # DI: IMEフラグをクリアして割り込みを無効
    # table[0xFB] = -> { 4 }  # EI
    # table[0xCB] = -> { 4 }  # PREFIX CB (CB-prefix命令へ分岐)

    # ============================================================
    # 8bit ロード - LD r,u8 (即値ロード)
    # ============================================================
    # table[0x06] = -> { 8 }  # LD B,u8
    # table[0x0E] = -> { 8 }  # LD C,u8
    # table[0x16] = -> { 8 }  # LD D,u8
    # table[0x1E] = -> { 8 }  # LD E,u8
    # table[0x26] = -> { 8 }  # LD H,u8
    # table[0x2E] = -> { 8 }  # LD L,u8
    # table[0x36] = -> { 12 } # LD (HL),u8
    # table[0x3E] = -> { 8 }  # LD A,u8

    # ============================================================
    # 8bit ロード - LD r,r' (レジスタ間転送)
    # ============================================================
    # table[0x40] = -> { 4 }  # LD B,B
    # table[0x41] = -> { 4 }  # LD B,C
    # table[0x42] = -> { 4 }  # LD B,D
    # table[0x43] = -> { 4 }  # LD B,E
    # table[0x44] = -> { 4 }  # LD B,H
    # table[0x45] = -> { 4 }  # LD B,L
    # table[0x46] = -> { 8 }  # LD B,(HL)
    # table[0x47] = -> { 4 }  # LD B,A
    # table[0x48] = -> { 4 }  # LD C,B
    # table[0x49] = -> { 4 }  # LD C,C
    # table[0x4A] = -> { 4 }  # LD C,D
    # table[0x4B] = -> { 4 }  # LD C,E
    # table[0x4C] = -> { 4 }  # LD C,H
    # table[0x4D] = -> { 4 }  # LD C,L
    # table[0x4E] = -> { 8 }  # LD C,(HL)
    # table[0x4F] = -> { 4 }  # LD C,A
    # table[0x50] = -> { 4 }  # LD D,B
    # table[0x51] = -> { 4 }  # LD D,C
    # table[0x52] = -> { 4 }  # LD D,D
    # table[0x53] = -> { 4 }  # LD D,E
    # table[0x54] = -> { 4 }  # LD D,H
    # table[0x55] = -> { 4 }  # LD D,L
    # table[0x56] = -> { 8 }  # LD D,(HL)
    # table[0x57] = -> { 4 }  # LD D,A
    # table[0x58] = -> { 4 }  # LD E,B
    # table[0x59] = -> { 4 }  # LD E,C
    # table[0x5A] = -> { 4 }  # LD E,D
    # table[0x5B] = -> { 4 }  # LD E,E
    # table[0x5C] = -> { 4 }  # LD E,H
    # table[0x5D] = -> { 4 }  # LD E,L
    # table[0x5E] = -> { 8 }  # LD E,(HL)
    # table[0x5F] = -> { 4 }  # LD E,A
    # table[0x60] = -> { 4 }  # LD H,B
    # table[0x61] = -> { 4 }  # LD H,C
    # table[0x62] = -> { 4 }  # LD H,D
    # table[0x63] = -> { 4 }  # LD H,E
    # table[0x64] = -> { 4 }  # LD H,H
    # table[0x65] = -> { 4 }  # LD H,L
    # table[0x66] = -> { 8 }  # LD H,(HL)
    # table[0x67] = -> { 4 }  # LD H,A
    # table[0x68] = -> { 4 }  # LD L,B
    # table[0x69] = -> { 4 }  # LD L,C
    # table[0x6A] = -> { 4 }  # LD L,D
    # table[0x6B] = -> { 4 }  # LD L,E
    # table[0x6C] = -> { 4 }  # LD L,H
    # table[0x6D] = -> { 4 }  # LD L,L
    # table[0x6E] = -> { 8 }  # LD L,(HL)
    # table[0x6F] = -> { 4 }  # LD L,A
    # table[0x70] = -> { 8 }  # LD (HL),B
    # table[0x71] = -> { 8 }  # LD (HL),C
    # table[0x72] = -> { 8 }  # LD (HL),D
    # table[0x73] = -> { 8 }  # LD (HL),E
    # table[0x74] = -> { 8 }  # LD (HL),H
    # table[0x75] = -> { 8 }  # LD (HL),L
    # table[0x77] = -> { 8 }  # LD (HL),A
    # table[0x78] = -> { 4 }  # LD A,B
    # table[0x79] = -> { 4 }  # LD A,C
    # table[0x7A] = -> { 4 }  # LD A,D
    # table[0x7B] = -> { 4 }  # LD A,E
    # table[0x7C] = -> { 4 }  # LD A,H
    # table[0x7D] = -> { 4 }  # LD A,L
    # table[0x7E] = -> { 8 }  # LD A,(HL)
    # table[0x7F] = -> { 4 }  # LD A,A

    # ============================================================
    # 8bit ロード - LD A,(rr) / LD (rr),A (レジスタペア間接)
    # ============================================================
    # table[0x02] = -> { 8 }  # LD (BC),A
    # table[0x0A] = -> { 8 }  # LD A,(BC)
    # table[0x12] = -> { 8 }  # LD (DE),A
    # table[0x1A] = -> { 8 }  # LD A,(DE)
    # table[0x22] = -> { 8 }  # LD (HL+),A
    # table[0x2A] = -> { 8 }  # LD A,(HL+)
    # table[0x32] = -> { 8 }  # LD (HL-),A
    # table[0x3A] = -> { 8 }  # LD A,(HL-)

    # ============================================================
    # 8bit ロード - LD A,(u16) / LD (u16),A (絶対アドレス)
    # ============================================================
    table[0xEA] = -> { mmu.write(fetch_u16, a); 16 } # LD (u16),A: u16番地のメモリにAを書き込む
    table[0xFA] = -> { self.a = fetch_u16; 16 } # LD A,(u16) # TODO: バグってそう

    # ============================================================
    # 8bit ロード - I/O ポート (0xFF00 + offset)
    # ============================================================
    # table[0xE0] = -> { 12 } # LD (FF00+u8),A
    # table[0xE2] = -> { 8 }  # LD (FF00+C),A
    # table[0xF0] = -> { 12 } # LD A,(FF00+u8)
    # table[0xF2] = -> { 8 }  # LD A,(FF00+C)

    # ============================================================
    # 16bit ロード - LD rr,u16
    # ============================================================
    table[0x01] = -> { self.bc = fetch_u16; 12 } # LD BC,u16
    table[0x11] = -> { self.de = fetch_u16; 12 } # LD DE,u16
    table[0x21] = -> { self.hl = fetch_u16; 12 } # LD HL,u16
    table[0x31] = -> { self.sp = fetch_u16; 12 } # LD SP,u16
    # table[0x08] = -> { 20 } # LD (u16),SP
    # table[0xF8] = -> { 12 } # LD HL,SP+i8
    # table[0xF9] = -> { 8 }  # LD SP,HL

    # ============================================================
    # スタック - PUSH / POP
    # ============================================================
    # table[0xC1] = -> { 12 } # POP BC
    # table[0xD1] = -> { 12 } # POP DE
    # table[0xE1] = -> { 12 } # POP HL
    # table[0xF1] = -> { 12 } # POP AF
    # table[0xC5] = -> { 16 } # PUSH BC
    # table[0xD5] = -> { 16 } # PUSH DE
    # table[0xE5] = -> { 16 } # PUSH HL
    # table[0xF5] = -> { 16 } # PUSH AF

    # ============================================================
    # 8bit 算術 - INC / DEC
    # ============================================================
    # table[0x04] = -> { 4 }  # INC B
    # table[0x0C] = -> { 4 }  # INC C
    # table[0x14] = -> { 4 }  # INC D
    # table[0x1C] = -> { 4 }  # INC E
    # table[0x24] = -> { 4 }  # INC H
    # table[0x2C] = -> { 4 }  # INC L
    # table[0x34] = -> { 12 } # INC (HL)
    # table[0x3C] = -> { 4 }  # INC A
    # table[0x05] = -> { 4 }  # DEC B
    # table[0x0D] = -> { 4 }  # DEC C
    # table[0x15] = -> { 4 }  # DEC D
    # table[0x1D] = -> { 4 }  # DEC E
    # table[0x25] = -> { 4 }  # DEC H
    # table[0x2D] = -> { 4 }  # DEC L
    # table[0x35] = -> { 12 } # DEC (HL)
    # table[0x3D] = -> { 4 }  # DEC A

    # ============================================================
    # 8bit 算術 - ADD A
    # ============================================================
    # table[0x80] = -> { 4 }  # ADD A,B
    # table[0x81] = -> { 4 }  # ADD A,C
    # table[0x82] = -> { 4 }  # ADD A,D
    # table[0x83] = -> { 4 }  # ADD A,E
    # table[0x84] = -> { 4 }  # ADD A,H
    # table[0x85] = -> { 4 }  # ADD A,L
    # table[0x86] = -> { 8 }  # ADD A,(HL)
    # table[0x87] = -> { 4 }  # ADD A,A
    # table[0xC6] = -> { 8 }  # ADD A,u8

    # ============================================================
    # 8bit 算術 - ADC A (キャリー込み加算)
    # ============================================================
    # table[0x88] = -> { 4 }  # ADC A,B
    # table[0x89] = -> { 4 }  # ADC A,C
    # table[0x8A] = -> { 4 }  # ADC A,D
    # table[0x8B] = -> { 4 }  # ADC A,E
    # table[0x8C] = -> { 4 }  # ADC A,H
    # table[0x8D] = -> { 4 }  # ADC A,L
    # table[0x8E] = -> { 8 }  # ADC A,(HL)
    # table[0x8F] = -> { 4 }  # ADC A,A
    # table[0xCE] = -> { 8 }  # ADC A,u8

    # ============================================================
    # 8bit 算術 - SUB A
    # ============================================================
    # table[0x90] = -> { 4 }  # SUB A,B
    # table[0x91] = -> { 4 }  # SUB A,C
    # table[0x92] = -> { 4 }  # SUB A,D
    # table[0x93] = -> { 4 }  # SUB A,E
    # table[0x94] = -> { 4 }  # SUB A,H
    # table[0x95] = -> { 4 }  # SUB A,L
    # table[0x96] = -> { 8 }  # SUB A,(HL)
    # table[0x97] = -> { 4 }  # SUB A,A
    # table[0xD6] = -> { 8 }  # SUB A,u8

    # ============================================================
    # 8bit 算術 - SBC A (キャリー込み減算)
    # ============================================================
    # table[0x98] = -> { 4 }  # SBC A,B
    # table[0x99] = -> { 4 }  # SBC A,C
    # table[0x9A] = -> { 4 }  # SBC A,D
    # table[0x9B] = -> { 4 }  # SBC A,E
    # table[0x9C] = -> { 4 }  # SBC A,H
    # table[0x9D] = -> { 4 }  # SBC A,L
    # table[0x9E] = -> { 8 }  # SBC A,(HL)
    # table[0x9F] = -> { 4 }  # SBC A,A
    # table[0xDE] = -> { 8 }  # SBC A,u8

    # ============================================================
    # 8bit 論理 - AND
    # ============================================================
    # table[0xA0] = -> { 4 }  # AND A,B
    # table[0xA1] = -> { 4 }  # AND A,C
    # table[0xA2] = -> { 4 }  # AND A,D
    # table[0xA3] = -> { 4 }  # AND A,E
    # table[0xA4] = -> { 4 }  # AND A,H
    # table[0xA5] = -> { 4 }  # AND A,L
    # table[0xA6] = -> { 8 }  # AND A,(HL)
    # table[0xA7] = -> { 4 }  # AND A,A
    # table[0xE6] = -> { 8 }  # AND A,u8

    # ============================================================
    # 8bit 論理 - XOR
    # ============================================================
    # table[0xA8] = -> { 4 }  # XOR A,B
    # table[0xA9] = -> { 4 }  # XOR A,C
    # table[0xAA] = -> { 4 }  # XOR A,D
    # table[0xAB] = -> { 4 }  # XOR A,E
    # table[0xAC] = -> { 4 }  # XOR A,H
    # table[0xAD] = -> { 4 }  # XOR A,L
    # table[0xAE] = -> { 8 }  # XOR A,(HL)
    table[0xAF] = -> { self.a = 0; self.f = 0b10000000; 4 } # XOR A,A
    # table[0xEE] = -> { 8 }  # XOR A,u8

    # ============================================================
    # 8bit 論理 - OR
    # ============================================================
    # table[0xB0] = -> { 4 }  # OR A,B
    # table[0xB1] = -> { 4 }  # OR A,C
    # table[0xB2] = -> { 4 }  # OR A,D
    # table[0xB3] = -> { 4 }  # OR A,E
    # table[0xB4] = -> { 4 }  # OR A,H
    # table[0xB5] = -> { 4 }  # OR A,L
    # table[0xB6] = -> { 8 }  # OR A,(HL)
    # table[0xB7] = -> { 4 }  # OR A,A
    # table[0xF6] = -> { 8 }  # OR A,u8

    # ============================================================
    # 8bit 比較 - CP (Compare)
    # ============================================================
    # table[0xB8] = -> { 4 }  # CP A,B
    # table[0xB9] = -> { 4 }  # CP A,C
    # table[0xBA] = -> { 4 }  # CP A,D
    # table[0xBB] = -> { 4 }  # CP A,E
    # table[0xBC] = -> { 4 }  # CP A,H
    # table[0xBD] = -> { 4 }  # CP A,L
    # table[0xBE] = -> { 8 }  # CP A,(HL)
    # table[0xBF] = -> { 4 }  # CP A,A
    table[0xFE] = -> { byte = fetch_u8; set_flags(zero: a == byte, negative: true, half_carry: (a & 0x1111) < (byte & 0x1111), carry: a < byte); 8 } # CP A,u8: Compare(比較)

    # ============================================================
    # 16bit 算術 - ADD HL / INC rr / DEC rr / ADD SP,i8
    # ============================================================
    # table[0x09] = -> { 8 }  # ADD HL,BC
    # table[0x19] = -> { 8 }  # ADD HL,DE
    # table[0x29] = -> { 8 }  # ADD HL,HL
    # table[0x39] = -> { 8 }  # ADD HL,SP
    # table[0x03] = -> { 8 }  # INC BC
    # table[0x13] = -> { 8 }  # INC DE
    # table[0x23] = -> { 8 }  # INC HL
    # table[0x33] = -> { 8 }  # INC SP
    # table[0x0B] = -> { 8 }  # DEC BC
    # table[0x1B] = -> { 8 }  # DEC DE
    # table[0x2B] = -> { 8 }  # DEC HL
    # table[0x3B] = -> { 8 }  # DEC SP
    # table[0xE8] = -> { 16 } # ADD SP,i8

    # ============================================================
    # ローテート (Aレジスタ用1バイト命令)
    # ============================================================
    # table[0x07] = -> { 4 }  # RLCA
    # table[0x0F] = -> { 4 }  # RRCA
    # table[0x17] = -> { 4 }  # RLA
    # table[0x1F] = -> { 4 }  # RRA

    # ============================================================
    # その他演算 (DAA / CPL / SCF / CCF)
    # ============================================================
    # table[0x27] = -> { 4 }  # DAA
    # table[0x2F] = -> { 4 }  # CPL
    # table[0x37] = -> { 4 }  # SCF
    # table[0x3F] = -> { 4 }  # CCF

    # ============================================================
    # ジャンプ - JP (絶対ジャンプ)
    # ============================================================
    table[0xC3] = -> { self.pc = fetch_u16; 16 } # JP u16
    # table[0xE9] = -> { 4 }  # JP HL
    # table[0xC2] = -> { 16 } # JP NZ,u16 (taken: 16 / not taken: 12)
    # table[0xCA] = -> { 16 } # JP Z,u16  (taken: 16 / not taken: 12)
    # table[0xD2] = -> { 16 } # JP NC,u16 (taken: 16 / not taken: 12)
    # table[0xDA] = -> { 16 } # JP C,u16  (taken: 16 / not taken: 12)

    # ============================================================
    # ジャンプ - JR (相対ジャンプ)
    # ============================================================
    # table[0x18] = -> { 12 } # JR i8
    # JR NZ,i8: Z フラグが 0 のとき、JR命令直後のアドレスから符号付き8bit分だけPCを動かす
    # fetch_i8 を先に呼ぶことで、PC が「次の命令の先頭」を指した状態でオフセット加算する
    table[0x20] = -> do
      offset_i8 = fetch_i8
      if zero == 0
        self.pc = wrap_u16(pc + offset_i8)
        12 # 分岐成立
      else
        8  # 分岐不成立
      end
    end
    # table[0x28] = -> { 12 } # JR Z,i8  (taken: 12 / not taken: 8)
    # table[0x30] = -> { 12 } # JR NC,i8 (taken: 12 / not taken: 8)
    # table[0x38] = -> { 12 } # JR C,i8  (taken: 12 / not taken: 8)

    # ============================================================
    # コール / リターン
    # ============================================================
    # table[0xCD] = -> { 24 } # CALL u16
    # table[0xC4] = -> { 24 } # CALL NZ,u16 (taken: 24 / not taken: 12)
    # table[0xCC] = -> { 24 } # CALL Z,u16  (taken: 24 / not taken: 12)
    # table[0xD4] = -> { 24 } # CALL NC,u16 (taken: 24 / not taken: 12)
    # table[0xDC] = -> { 24 } # CALL C,u16  (taken: 24 / not taken: 12)
    # table[0xC9] = -> { 16 } # RET
    # table[0xD9] = -> { 16 } # RETI
    # table[0xC0] = -> { 20 } # RET NZ (taken: 20 / not taken: 8)
    # table[0xC8] = -> { 20 } # RET Z  (taken: 20 / not taken: 8)
    # table[0xD0] = -> { 20 } # RET NC (taken: 20 / not taken: 8)
    # table[0xD8] = -> { 20 } # RET C  (taken: 20 / not taken: 8)

    # ============================================================
    # リセット (RST)
    # ============================================================
    # table[0xC7] = -> { 16 } # RST 00h
    # table[0xCF] = -> { 16 } # RST 08h
    # table[0xD7] = -> { 16 } # RST 10h
    # table[0xDF] = -> { 16 } # RST 18h
    # table[0xE7] = -> { 16 } # RST 20h
    # table[0xEF] = -> { 16 } # RST 28h
    # table[0xF7] = -> { 16 } # RST 30h
    # table[0xFF] = -> { 16 } # RST 38h

    # ============================================================
    # 未使用 (UNUSED) - 実機では実行すると CPU が固まる
    # ============================================================
    # table[0xD3] = nil # UNUSED
    # table[0xDB] = nil # UNUSED
    # table[0xDD] = nil # UNUSED
    # table[0xE3] = nil # UNUSED
    # table[0xE4] = nil # UNUSED
    # table[0xEB] = nil # UNUSED
    # table[0xEC] = nil # UNUSED
    # table[0xED] = nil # UNUSED
    # table[0xF4] = nil # UNUSED
    # table[0xFC] = nil # UNUSED
    # table[0xFD] = nil # UNUSED

    table
  end
end
