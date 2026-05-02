require 'app/emulator/bit'
require 'app/emulator/cpu_registers'

# CPU (Sharp LR35902)
#
# Game Boy (DMG) の CPU。Z80 と Intel 8080 を混ぜたような 8bit プロセッサで、
# クロック 4.194304 MHz、1 フレーム (1/60 秒) あたり約 70,000 サイクル相当を回す。
#
# ここでは「命令を載せる枠組み」だけを用意する。具体的なオペコードはステップ B-2 以降で
# `@opcodes` テーブルへ追加していく方針。未実装のオペコードを踏むと例外で停止するため、
# ブートROM が実際に必要とする命令だけが自然に浮かび上がる(ROADMAP.md / B-1 参照)。
#
# レジスタ (A/F/B/C/D/E/H/L とそのペア、フラグ操作) は CpuRegisters クラスに分離している。
# CPU 自身は `@registers` を持ち、SP / PC / IME / halted のような CPU 制御状態だけを保持する。
#
# === 命令ディスパッチ ===
# gbops オペコード表: https://izik1.github.io/gbops/
#
# `@opcodes` は 256 要素の配列で、各要素が「その命令を実行して消費サイクル数を返す lambda」
# CB-prefix 命令(0xCB に続く 2 バイト目)は B-3 で別テーブルとして追加する
class CPU
  attr_accessor :ime, # Interrupt Master Enable(割り込みマスタ有効フラグ) 1の時に処理を割り込む https://gbdev.io/pandocs/Interrupts.html
                :halted, # CPUの一時停止中フラグ https://gbdev.io/pandocs/halt.html
                :opcodes, # CPUの命令一覧 https://izik1.github.io/gbops/
                :mmu
  attr_reader :registers # 8bit レジスタ (A/F/B/C/D/E/H/L) と SP / PC、フラグ操作

  def initialize(mmu, skip_boot: false)
    @mmu = mmu
    @registers = CpuRegisters.new(skip_boot: skip_boot)
    @ime = false   # 割り込み許可フラグ(Interrupt Master Enable)
    @halted = false # CPUの一時停止中フラグ

    @opcodes = build_opcode_table
  end

  # １つ命令を実行する
  def step
    return 4 if halted # CPUが一時停止中。何もせずに4サイクル消費。 https://gbdev.io/pandocs/halt.html

    opcode = fetch_u8
    puts "opcode 0x#{opcode.to_s(16).rjust(2, '0').upcase} (PC=0x#{Bit.wrap_u16(registers.pc - 1).to_s(16).rjust(4, '0').upcase})"
    handler = opcodes[opcode]
    raise "未実装の opcode 0x#{opcode.to_s(16).rjust(2, '0').upcase} (PC=0x#{Bit.wrap_u16(registers.pc - 1).to_s(16).rjust(4, '0').upcase})" if handler.nil?
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

  # PCは、16bitレジスタ(Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html)
  def fetch_u8
    byte = mmu.read_u8(address: registers.pc) # PCから1バイト読み込む
    registers.pc = Bit.wrap_u16(registers.pc + 1) # PCを1つ進める
    byte
  end

  # PC が指す 2バイトをリトルエンディアンで読む(下位バイトが先)。
  # Game Boy のメモリレイアウトはリトルエンディアン(https://gbdev.io/pandocs/CPU_Instruction_Set.html)
  def fetch_u16
    low = fetch_u8
    high = fetch_u8
    Bit.make_u16(high: high, low: low)
  end

  # PC が指す 1バイトを符号付き(-128〜+127)として読む。JR i8 や ADD SP,i8 で使う。
  # 2の補数表現: bit7 が 1 の値(0x80〜0xFF)を負数として解釈する。
  def fetch_i8
    Bit.u8_to_i8(fetch_u8)
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
    table[0x76] = -> { self.halted = true; 4 } # HALT: CPUを停止状態に。割り込みが入るまでstep()は4サイクルだけ消費(命令fetch しない)https://gbdev.io/pandocs/halt.html
    table[0xF3] = -> { self.ime = false; 4 } # DI: IMEフラグをクリアして割り込みを無効
    # table[0xFB] = -> { 4 }  # EI
    # table[0xCB] = -> { 4 }  # PREFIX CB (CB-prefix命令へ分岐)

    # ============================================================
    # 8bit ロード - LD r,u8 (即値ロード)
    # ============================================================
    table[0x06] = -> { registers.b = fetch_u8; 8 } # LD B,u8
    table[0x0E] = -> { registers.c = fetch_u8; 8 } # LD C,u8
    table[0x16] = -> { registers.d = fetch_u8; 8 } # LD D,u8
    table[0x1E] = -> { registers.e = fetch_u8; 8 } # LD E,u8
    table[0x26] = -> { registers.h = fetch_u8; 8 } # LD H,u8
    table[0x2E] = -> { registers.l = fetch_u8; 8 } # LD L,u8
    # table[0x36] = -> { 12 } # LD (HL),u8
    table[0x3E] = -> { registers.a = fetch_u8; 8 } # LD A,u8

    # ============================================================
    # 8bit ロード - LD r,r' (レジスタ間転送)
    # ============================================================
    table[0x40] = -> { 4 } # LD B,B → 無意味な処理のため何もしない
    table[0x41] = -> { registers.b = registers.c; 4 }  # LD B,C
    table[0x42] = -> { registers.b = registers.d; 4 }  # LD B,D
    table[0x43] = -> { registers.b = registers.e; 4 }  # LD B,E
    table[0x44] = -> { registers.b = registers.h; 4 }  # LD B,H
    table[0x45] = -> { registers.b = registers.l; 4 }  # LD B,L
    # table[0x46] = -> { 8 }  # LD B,(HL)
    table[0x47] = -> { registers.b = registers.a; 4 }  # LD B,A
    table[0x48] = -> { registers.c = registers.b; 4 }  # LD C,B
    table[0x49] = -> { 4 }  # LD C,C → 無意味な処理のため何もしない
    table[0x4A] = -> { registers.c = registers.d; 4 }  # LD C,D
    table[0x4B] = -> { registers.c = registers.e; 4 }  # LD C,E
    table[0x4C] = -> { registers.c = registers.h; 4 }  # LD C,H
    table[0x4D] = -> { registers.c = registers.l; 4 }  # LD C,L
    # table[0x4E] = -> { 8 }  # LD C,(HL)
    table[0x4F] = -> { registers.c = registers.a; 4 }  # LD C,A
    table[0x50] = -> { registers.d = registers.b; 4 }  # LD D,B
    table[0x51] = -> { registers.d = registers.c; 4 }  # LD D,C
    table[0x52] = -> { 4 }  # LD D,D → 無意味な処理のため何もしない
    table[0x53] = -> { registers.d = registers.e; 4 }  # LD D,E
    table[0x54] = -> { registers.d = registers.h; 4 }  # LD D,H
    table[0x55] = -> { registers.d = registers.l; 4 }  # LD D,L
    # table[0x56] = -> { 8 }  # LD D,(HL)
    table[0x57] = -> { registers.d = registers.a; 4 }  # LD D,A
    table[0x58] = -> { registers.e = registers.b; 4 }  # LD E,B
    table[0x59] = -> { registers.e = registers.c; 4 }  # LD E,C
    table[0x5A] = -> { registers.e = registers.d; 4 }  # LD E,D
    table[0x5B] = -> { 4 }  # LD E,E → 無意味な処理のため何もしない
    table[0x5C] = -> { registers.e = registers.h; 4 }  # LD E,H
    table[0x5D] = -> { registers.e = registers.l; 4 }  # LD E,L
    # table[0x5E] = -> { 8 }  # LD E,(HL)
    table[0x5F] = -> { registers.e = registers.a; 4 }  # LD E,A
    table[0x60] = -> { registers.h = registers.b; 4 }  # LD H,B
    table[0x61] = -> { registers.h = registers.c; 4 }  # LD H,C
    table[0x62] = -> { registers.h = registers.d; 4 }  # LD H,D
    table[0x63] = -> { registers.h = registers.e; 4 }  # LD H,E
    table[0x64] = -> { 4 }  # LD H,H → 無意味な処理のため何もしない
    table[0x65] = -> { registers.h = registers.l; 4 }  # LD H,L
    # table[0x66] = -> { 8 }  # LD H,(HL)
    table[0x67] = -> { registers.h = registers.a; 4 }  # LD H,A
    table[0x68] = -> { registers.l = registers.b; 4 }  # LD L,B
    table[0x69] = -> { registers.l = registers.c; 4 }  # LD L,C
    table[0x6A] = -> { registers.l = registers.d; 4 }  # LD L,D
    table[0x6B] = -> { registers.l = registers.e; 4 }  # LD L,E
    table[0x6C] = -> { registers.l = registers.h; 4 }  # LD L,H
    table[0x6D] = -> { 4 }  # LD L,L → 無意味な処理のため何もしない
    # table[0x6E] = -> { 8 }  # LD L,(HL)
    table[0x6F] = -> { registers.l = registers.a; 4 }  # LD L,A
    # table[0x70] = -> { 8 }  # LD (HL),B
    # table[0x71] = -> { 8 }  # LD (HL),C
    # table[0x72] = -> { 8 }  # LD (HL),D
    # table[0x73] = -> { 8 }  # LD (HL),E
    # table[0x74] = -> { 8 }  # LD (HL),H
    # table[0x75] = -> { 8 }  # LD (HL),L
    # table[0x77] = -> { 8 }  # LD (HL),A
    table[0x78] = -> { registers.a = registers.b; 4 }  # LD A,B
    table[0x79] = -> { registers.a = registers.c; 4 }  # LD A,C
    table[0x7A] = -> { registers.a = registers.d; 4 }  # LD A,D
    table[0x7B] = -> { registers.a = registers.e; 4 }  # LD A,E
    table[0x7C] = -> { registers.a = registers.h; 4 }  # LD A,H
    table[0x7D] = -> { registers.a = registers.l; 4 }  # LD A,L
    # table[0x7E] = -> { 8 }  # LD A,(HL)
    table[0x7F] = -> { 4 }  # LD A,A → 無意味な処理のため何もしない

    # ============================================================
    # 8bit ロード - LD A,(rr) / LD (rr),A (レジスタペア間接)
    # ============================================================
    table[0x02] = -> { mmu.write_u8(address: registers.bc, value: registers.a); 8 } # LD (BC),A
    table[0x0A] = -> { registers.a = mmu.read_u8(address: registers.bc); 8 } # LD A,(BC)
    table[0x12] = -> { mmu.write_u8(address: registers.de, value: registers.a); 8 } # LD (DE),A
    table[0x1A] = -> { registers.a = mmu.read_u8(address: registers.de); 8 } # LD A,(DE)
    table[0x22] = -> { mmu.write_u8(address: registers.hl, value: registers.a); registers.hl += 1; 8 } # LD (HL+),A
    table[0x2A] = -> { registers.a = mmu.read_u8(address: registers.hl); registers.hl += 1; 8 } # LD A,(HL+)
    table[0x32] = -> { mmu.write_u8(address: registers.hl, value: registers.a); registers.hl -= 1; 8 } # LD (HL-),A
    table[0x3A] = -> { registers.a = mmu.read_u8(address: registers.hl); registers.hl -= 1; 8 }  # LD A,(HL-)

    # ============================================================
    # 8bit ロード - LD A,(u16) / LD (u16),A (絶対アドレス)
    # ============================================================
    table[0xEA] = -> { mmu.write_u8(address: fetch_u16, value: registers.a); 16 } # LD (u16),A: u16番地のメモリにAを書き込む
    table[0xFA] = -> { registers.a = mmu.read_u8(address: fetch_u16); 16 } # LD A,(u16) → ()はそのアドレスの先という意味

    # ============================================================
    # 8bit ロード - I/O ポート (0xFF00 + offset)
    # ============================================================
    table[0xE0] = -> { mmu.write_u8(address: 0xFF00 + fetch_u8, value: registers.a); 12 } # LD (FF00+u8),A
    table[0xE2] = -> { mmu.write_u8(address: 0xFF00 + registers.c, value: registers.a); 8 }  # LD (FF00+C),A
    table[0xF0] = -> { registers.a = mmu.read_u8(address: 0xFF00 + fetch_u8); 12 } # LD A,(FF00+u8)
    table[0xF2] = -> { registers.a = mmu.read_u8(address: 0xFF00 + registers.c); 8 }  # LD A,(FF00+C)

    # ============================================================
    # 16bit ロード - LD rr,u16
    # ============================================================
    table[0x01] = -> { registers.bc = fetch_u16; 12 } # LD BC,u16
    table[0x11] = -> { registers.de = fetch_u16; 12 } # LD DE,u16
    table[0x21] = -> { registers.hl = fetch_u16; 12 } # LD HL,u16
    table[0x31] = -> { registers.sp = fetch_u16; 12 } # LD SP,u16
    table[0x08] = -> { mmu.write_u16(address: fetch_u16, value: registers.sp); 20 } # LD (u16),SP
    table[0xF8] = -> { registers.hl = Bit.wrap_u16(registers.sp + fetch_i8); registers.negative_flag = 0; registers.negative_flag = 0; registers.half_carry_flag = 1; registers.carry_flag = 1; 12 } # LD HL,SP+i8 # TODO: FLAGが未実装
    table[0xF9] = -> { registers.sp = registers.hl; 8 } # LD SP,HL

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
    # 8bit 算術 - INC
    # ============================================================
    table[0x04] = -> { half_carry_result = Bit.low_4bits(registers.b) + 1 > 0x0F; registers.b = Bit.wrap_u8(registers.b + 1); registers.set_flags(zero: registers.b == 0, negative: false, half_carry: half_carry_result); 4 } # INC B: B+1。Cフラグは保持(他更新)、Hは下位4bitからの繰り上がり
    table[0x0C] = -> { half_carry_result = Bit.low_4bits(registers.c) + 1 > 0x0F; registers.c = Bit.wrap_u8(registers.c + 1); registers.set_flags(zero: registers.c == 0, negative: false, half_carry: half_carry_result); 4 } # INC C
    table[0x14] = -> { half_carry_result = Bit.low_4bits(registers.d) + 1 > 0x0F; registers.d = Bit.wrap_u8(registers.d + 1); registers.set_flags(zero: registers.d == 0, negative: false, half_carry: half_carry_result); 4 } # INC D
    table[0x1C] = -> { half_carry_result = Bit.low_4bits(registers.e) + 1 > 0x0F; registers.e = Bit.wrap_u8(registers.e + 1); registers.set_flags(zero: registers.e == 0, negative: false, half_carry: half_carry_result); 4 } # INC E
    table[0x24] = -> { half_carry_result = Bit.low_4bits(registers.h) + 1 > 0x0F; registers.h = Bit.wrap_u8(registers.h + 1); registers.set_flags(zero: registers.h == 0, negative: false, half_carry: half_carry_result); 4 } # INC H
    table[0x2C] = -> { half_carry_result = Bit.low_4bits(registers.l) + 1 > 0x0F; registers.l = Bit.wrap_u8(registers.l + 1); registers.set_flags(zero: registers.l == 0, negative: false, half_carry: half_carry_result); 4 } # INC L
    # table[0x34] = -> { 12 } # INC (HL)
    table[0x3C] = -> { half_carry_result = Bit.low_4bits(registers.a) + 1 > 0x0F; registers.a = Bit.wrap_u8(registers.a + 1); registers.set_flags(zero: registers.a == 0, negative: false, half_carry: half_carry_result); 4 } # INC A

    # ============================================================
    # 8bit 算術 - DEC
    # ============================================================
    table[0x05] = -> { half_carry_result = Bit.low_4bits(registers.b) == 0; registers.b = Bit.wrap_u8(registers.b - 1); registers.set_flags(zero: registers.b == 0, negative: true, half_carry: half_carry_result); 4 } # DEC B
    table[0x0D] = -> { half_carry_result = Bit.low_4bits(registers.c) == 0; registers.c = Bit.wrap_u8(registers.c - 1); registers.set_flags(zero: registers.c == 0, negative: true, half_carry: half_carry_result); 4 } # DEC C: C-1。Cフラグは保持(他更新)、Hは下位4bitが0なら借り発生
    table[0x15] = -> { half_carry_result = Bit.low_4bits(registers.d) == 0; registers.d = Bit.wrap_u8(registers.d - 1); registers.set_flags(zero: registers.d == 0, negative: true, half_carry: half_carry_result); 4 } # DEC D
    table[0x1D] = -> { half_carry_result = Bit.low_4bits(registers.e) == 0; registers.e = Bit.wrap_u8(registers.e - 1); registers.set_flags(zero: registers.e == 0, negative: true, half_carry: half_carry_result); 4 } # DEC E
    table[0x25] = -> { half_carry_result = Bit.low_4bits(registers.h) == 0; registers.h = Bit.wrap_u8(registers.h - 1); registers.set_flags(zero: registers.h == 0, negative: true, half_carry: half_carry_result); 4 } # DEC H
    table[0x2D] = -> { half_carry_result = Bit.low_4bits(registers.l) == 0; registers.l = Bit.wrap_u8(registers.l - 1); registers.set_flags(zero: registers.l == 0, negative: true, half_carry: half_carry_result); 4 } # DEC L
    # table[0x35] = -> { 12 } # DEC (HL)
    table[0x3D] = -> { half_carry_result = Bit.low_4bits(registers.a) == 0; registers.a = Bit.wrap_u8(registers.a - 1); registers.set_flags(zero: registers.a == 0, negative: true, half_carry: half_carry_result); 4 } # DEC A

    # ============================================================
    # 8bit 算術 - ADD A
    # ============================================================
    # TODO: 未実装 table[0x80] = -> { registers.a = Bit.wrap_u8(registers.a + registers.b); registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # ADD A,B
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
    table[0xA8] = -> { registers.a = registers.a ^ registers.b; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,B
    table[0xA9] = -> { registers.a = registers.a ^ registers.c; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,C
    table[0xAA] = -> { registers.a = registers.a ^ registers.d; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,D
    table[0xAB] = -> { registers.a = registers.a ^ registers.e; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,E
    table[0xAC] = -> { registers.a = registers.a ^ registers.h; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,H
    table[0xAD] = -> { registers.a = registers.a ^ registers.l; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # XOR A,L
    table[0xAE] = -> { byte = mmu.read_u8(address: registers.hl); registers.a = registers.a ^ byte; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 8 }  # XOR A,(HL)
    table[0xAF] = -> { registers.a = 0; registers.set_flags(zero: true, negative: false, half_carry: false, carry: false); 4 } # XOR A,A
    table[0xEE] = -> { byte = fetch_u8; registers.a = registers.a ^ byte; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 8 }  # XOR A,u8

    # ============================================================
    # 8bit 論理 - OR
    # ============================================================
    table[0xB0] = -> { registers.a = registers.a | registers.b; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 } # OR A,B
    table[0xB1] = -> { registers.a = registers.a | registers.c; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,C
    table[0xB2] = -> { registers.a = registers.a | registers.d; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,D
    table[0xB3] = -> { registers.a = registers.a | registers.e; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,E
    table[0xB4] = -> { registers.a = registers.a | registers.h; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,H
    table[0xB5] = -> { registers.a = registers.a | registers.l; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,L
    table[0xB6] = -> { registers.a = registers.a | mmu.read_u8(address: registers.hl); registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 8 }  # OR A,(HL)
    table[0xB7] = -> { registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 4 }  # OR A,A → a | aしても結果は同じ
    table[0xF6] = -> { registers.a = registers.a | fetch_u8; registers.set_flags(zero: registers.a == 0, negative: false, half_carry: false, carry: false); 8 }  # OR A,u8

    # ============================================================
    # 8bit 比較 - CP (Compare)
    # ============================================================
    table[0xB8] = -> { registers.set_flags(zero: registers.a == registers.b, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.b), carry: registers.a < registers.b); 4 }  # CP A,B
    table[0xB9] = -> { registers.set_flags(zero: registers.a == registers.c, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.c), carry: registers.a < registers.c); 4 }  # CP A,C
    table[0xBA] = -> { registers.set_flags(zero: registers.a == registers.d, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.d), carry: registers.a < registers.d); 4 }  # CP A,D
    table[0xBB] = -> { registers.set_flags(zero: registers.a == registers.e, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.e), carry: registers.a < registers.e); 4 }  # CP A,E
    table[0xBC] = -> { registers.set_flags(zero: registers.a == registers.h, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.h), carry: registers.a < registers.h); 4 }  # CP A,H
    table[0xBD] = -> { registers.set_flags(zero: registers.a == registers.l, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(registers.l), carry: registers.a < registers.l); 4 }  # CP A,L
    table[0xBE] = -> { byte = mmu.read_u8(address: registers.hl); registers.set_flags(zero: registers.a == byte, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(byte), carry: registers.a < byte); 8 }  # CP A,(HL)
    table[0xBF] = -> { registers.set_flags(zero: true, negative: true, half_carry: false, carry: false); 4 }  # CP A,A
    table[0xFE] = -> { byte = fetch_u8; registers.set_flags(zero: registers.a == byte, negative: true, half_carry: Bit.low_4bits(registers.a) < Bit.low_4bits(byte), carry: registers.a < byte); 8 } # CP A,u8: Compare(比較)

    # ============================================================
    # 16bit 算術 - ADD HL / INC rr / DEC rr / ADD SP,i8
    # ============================================================
    # table[0x09] = -> { 8 }  # ADD HL,BC
    # table[0x19] = -> { 8 }  # ADD HL,DE
    # table[0x29] = -> { 8 }  # ADD HL,HL
    # table[0x39] = -> { 8 }  # ADD HL,SP
    table[0x03] = -> { registers.bc = Bit.wrap_u16(registers.bc + 1); 8 } # INC BC
    table[0x13] = -> { registers.de = Bit.wrap_u16(registers.de + 1); 8 } # INC DE
    table[0x23] = -> { registers.hl = Bit.wrap_u16(registers.hl + 1); 8 } # INC HL
    table[0x33] = -> { registers.sp = Bit.wrap_u16(registers.sp + 1); 8 } # INC SP
    table[0x0B] = -> { registers.bc = Bit.wrap_u16(registers.bc - 1); 8 } # DEC BC
    table[0x1B] = -> { registers.de = Bit.wrap_u16(registers.de - 1); 8 } # DEC DE
    table[0x2B] = -> { registers.hl = Bit.wrap_u16(registers.hl - 1); 8 } # DEC HL
    table[0x3B] = -> { registers.sp = Bit.wrap_u16(registers.sp - 1); 8 } # DEC SP
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
    table[0xC3] = -> { registers.pc = fetch_u16; 16 } # JP u16
    table[0xE9] = -> { registers.pc = registers.hl; 4 } # JP HL
    # table[0xC2] = -> { 16 } # JP NZ,u16 (taken: 16 / not taken: 12)
    # table[0xCA] = -> { 16 } # JP Z,u16  (taken: 16 / not taken: 12)
    # table[0xD2] = -> { 16 } # JP NC,u16 (taken: 16 / not taken: 12)
    # table[0xDA] = -> { 16 } # JP C,u16  (taken: 16 / not taken: 12)

    # ============================================================
    # ジャンプ - JR (相対ジャンプ)
    # ============================================================
    table[0x18] = -> { offset_i8 = fetch_i8; registers.pc = Bit.wrap_u16(registers.pc + offset_i8); 12 } # JR i8: 無条件相対ジャンプ。fetch_i8 後のPC(=次の命令の先頭)を起点にオフセット加算
    # JR NZ,i8: Z フラグが 0 のとき、JR命令直後のアドレスから符号付き8bit分だけPCを動かす
    # fetch_i8 を先に呼ぶことで、PC が「次の命令の先頭」を指した状態でオフセット加算する
    table[0x20] = -> do
      offset_i8 = fetch_i8
      if registers.zero_flag == 0
        registers.pc = Bit.wrap_u16(registers.pc + offset_i8)
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
    table[0xCD] = -> { address = fetch_u16; registers.sp = Bit.wrap_u16(registers.sp - 2); mmu.write_u16(address: registers.sp, value: registers.pc); registers.pc = address; 24 } # CALL u16: 戻りアドレス(=次の命令のPC)をstackに積んでから呼び出し先にjump
    # table[0xC4] = -> { 24 } # CALL NZ,u16 (taken: 24 / not taken: 12)
    # table[0xCC] = -> { 24 } # CALL Z,u16  (taken: 24 / not taken: 12)
    # table[0xD4] = -> { 24 } # CALL NC,u16 (taken: 24 / not taken: 12)
    # table[0xDC] = -> { 24 } # CALL C,u16  (taken: 24 / not taken: 12)
    table[0xC9] = -> { registers.pc = mmu.read_u16(address: registers.sp); registers.sp = Bit.wrap_u16(registers.sp + 2); 16 } # RET: スタックから戻りアドレスをpopしてjump(CALLの逆操作)
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
