require 'app/emulator/bit'

# Disassembler
#
# CPU が次に実行する 1 命令をログ出力可能な文字列に整形する。
# PC は進めず、MMU からのみ読む(完全に副作用なし)。
#
# 出力例:
#   00B8: E5          PUSH HL
#   00B9: 21 0F FF    LD HL, 0xFF0F
#
# === 命令長の取り扱い ===
# Game Boy の opcode は 1〜3 バイト。CB-prefix だけは「0xCB + 次のバイト」で常に 2 バイト
#
# === レジスタエンコーディング ===
# 多くの命令で 3bit の register code (0..7) が使われる:
#   0=B, 1=C, 2=D, 3=E, 4=H, 5=L, 6=(HL), 7=A
# Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html
#
# === 条件分岐の動的結果出力 ===
# JR cc / JP cc / CALL cc / RET cc は taken / not taken を取れる。disasm 行の末尾に
# 「→ taken (=> 0xXXXX)」または「→ not taken (=> 0xXXXX)」を付与して、実際の遷移先を見せる
# taken / not taken の判定は handler.call の戻り値 (cycles) を taken 時サイクル数と比較
class Disassembler
  REGS = ['B', 'C', 'D', 'E', 'H', 'L', '(HL)', 'A'].freeze

  # 条件分岐 opcode → [taken時サイクル数, 命令長(バイト)]
  # gbops: https://izik1.github.io/gbops/
  CONDITIONAL_BRANCHES = {
    0x20 => [12, 2], 0x28 => [12, 2], 0x30 => [12, 2], 0x38 => [12, 2], # JR NZ/Z/NC/C, i8 (taken: 12 / not taken: 8)
    0xC2 => [16, 3], 0xCA => [16, 3], 0xD2 => [16, 3], 0xDA => [16, 3], # JP NZ/Z/NC/C, u16 (taken: 16 / not taken: 12)
    0xC4 => [24, 3], 0xCC => [24, 3], 0xD4 => [24, 3], 0xDC => [24, 3], # CALL NZ/Z/NC/C, u16 (taken: 24 / not taken: 12)
    0xC0 => [20, 1], 0xC8 => [20, 1], 0xD0 => [20, 1], 0xD8 => [20, 1], # RET NZ/Z/NC/C (taken: 20 / not taken: 8)
  }.freeze

  def initialize(mmu, registers)
    @mmu = mmu
    @registers = registers # 条件分岐時のフラグ値読み取り用
  end

  # 指定 PC の命令を 1 行に整形して返す(改行なし)
  def disassemble(pc)
    opcode = @mmu.read_u8(address: pc)
    if opcode == 0xCB
      cb_opcode = @mmu.read_u8(address: pc + 1)
      format_line(pc, [opcode, cb_opcode], cb_mnemonic(cb_opcode))
    else
      length, mnemonic = decode(pc, opcode)
      bytes = (0...length).map { |i| @mmu.read_u8(address: pc + i) }
      format_line(pc, bytes, mnemonic)
    end
  end

  # 1命令のトレースは before_step → handler.call → after_step の順で使う:
  #
  #   context = disassembler.before_step(registers.pc)  # 命令前の状態を保存 + disasm 整形
  #   cycles = handler.call                              # 命令実行
  #   puts disassembler.after_step(context, opcode, cycles)  # 整形済みの完成行を返す
  #
  # 命令前の状態(PC, F, レジスタ snapshot, disasm 行)をまとめて返す
  # 同時に MMU の書き込みログを 1命令分に reset する
  def before_step(pc)
    @mmu.reset_write_log
    {
      pc: pc,
      f: @registers.f,
      snapshot: @registers.snapshot,
      line: disassemble(pc),
    }
  end

  # 命令実行後に before_step の戻り値と opcode/cycles を渡すと、整形済みのログ行を返す
  # レジスタ変化、メモリ書き込み、フラグ変化、条件分岐結果を1つの "# ..." コメントにまとめる
  def after_step(context, opcode, cycles)
    parts = [
      register_changes_str(context[:snapshot]),
      memory_writes_str,
      flag_changes_str(context[:f]),
      branch_outcome(opcode, context[:pc], cycles),
    ].reject(&:empty?)

    suffix = parts.empty? ? '' : " # #{parts.join(', ')}"
    (context[:line] + suffix).rstrip
  end

  private

  # 命令実行で F レジスタが変わったときのみ、変化後の Z/N/H/C を整形して返す
  # 変化なしなら空文字列(LD 系などフラグを触らない命令はログに出さない)
  def flag_changes_str(f_before)
    return '' if f_before == @registers.f
    "Z=#{Bit.bit_at(@registers.f, 7)} N=#{Bit.bit_at(@registers.f, 6)} H=#{Bit.bit_at(@registers.f, 5)} C=#{Bit.bit_at(@registers.f, 4)}"
  end

  # 条件分岐の実行結果文字列を返す。条件分岐 opcode でなければ空文字列を返す
  # 条件分岐は flag を変更しないので、実行後の flag 値 = 判定に使われた値
  def branch_outcome(opcode, pc_before, cycles)
    info = CONDITIONAL_BRANCHES[opcode]
    return '' unless info
    taken_cycles, length = info
    flag = condition_flag_state(opcode)
    if cycles == taken_cycles
      "#{flag} → taken (=> 0x#{hex4(@registers.pc)})"
    else
      next_pc = Bit.wrap_u16(pc_before + length) # 落ちた場合の次命令 = pc_before + 命令長
      "#{flag} → not taken (=> 0x#{hex4(next_pc)})"
    end
  end

  # 命令実行で値が変わったレジスタを "A: 0x12→0xCE" / "HL: 0x0000→0x0105" 形式で返す
  # ペア (BC/DE/HL) は両方変わったときだけ pair 表示、片方だけなら個別バイト表示
  def register_changes_str(snapshot_before)
    parts = []
    parts << "A: 0x#{hex2(snapshot_before[:a])}→0x#{hex2(@registers.a)}" if @registers.a != snapshot_before[:a]
    parts.concat(pair_changes('B', 'C', 'BC', @registers.b, @registers.c, @registers.bc, snapshot_before[:b], snapshot_before[:c]))
    parts.concat(pair_changes('D', 'E', 'DE', @registers.d, @registers.e, @registers.de, snapshot_before[:d], snapshot_before[:e]))
    parts.concat(pair_changes('H', 'L', 'HL', @registers.h, @registers.l, @registers.hl, snapshot_before[:h], snapshot_before[:l]))
    parts << "SP: 0x#{hex4(snapshot_before[:sp])}→0x#{hex4(@registers.sp)}" if @registers.sp != snapshot_before[:sp]
    parts.join(' ')
  end

  # 1命令分のメモリ書き込みを "(0xC100): 0x12→0xCE" 形式で返す。複数あればスペース区切り
  # 書き込みが無ければ空文字列
  def memory_writes_str
    writes = @mmu.write_log
    return '' if writes.empty?
    writes.map { |address, before, after| "(0x#{hex4(address)}): 0x#{hex2(before)}→0x#{hex2(after)}" }.join(' ')
  end

  MNEMONIC_WIDTH = 20 # ニーモニック列の固定幅。実行結果コメント (# 〜) の開始位置を揃えるため

  # PC、バイト列、ニーモニックを 1 行に整形する
  # ニーモニックは MNEMONIC_WIDTH 文字に右パディングして、後段で連結される " # ..." の開始位置を揃える
  # 例: "00B9: 21 0F FF    LD HL, 0xFF0F       "(末尾の余白は実行結果が無ければ rstrip される)
  def format_line(pc, bytes, mnemonic)
    pc_str = hex4(pc)
    bytes_str = bytes.map { |byte| hex2(byte) }.join(' ').ljust(11) # 最大 "XX XX XX" (8文字) + 余白3
    "#{pc_str}: #{bytes_str} #{mnemonic.ljust(MNEMONIC_WIDTH)}"
  end

  # 条件分岐 opcode から判定対象フラグと現在値を "Z=0" 形式で返す
  # bit 4 (0x10): 0=Zero flag、1=Carry flag (JR/JP/CALL/RET cc 全 16 個で共通のエンコーディング)
  # bit 3 (0x08): NZ/Z や NC/C の極性。taken/not taken は cycles で既に判定済みなので、ここでは不要
  def condition_flag_state(opcode)
    if (opcode & 0x10) == 0
      "Z=#{@registers.zero_flag}"
    else
      "C=#{@registers.carry_flag}"
    end
  end

  # 8bitペアの差分を before→after 形式で整形する。両方変わったらペア表示、片方だけなら個別バイト表示、
  # 変化なしなら空配列を返す
  def pair_changes(high_name, low_name, pair_name, high_after, low_after, pair_after, high_before, low_before)
    high_changed = high_after != high_before
    low_changed = low_after != low_before
    if high_changed && low_changed
      pair_before = (high_before << 8) | low_before
      ["#{pair_name}: 0x#{hex4(pair_before)}→0x#{hex4(pair_after)}"]
    elsif high_changed
      ["#{high_name}: 0x#{hex2(high_before)}→0x#{hex2(high_after)}"]
    elsif low_changed
      ["#{low_name}: 0x#{hex2(low_before)}→0x#{hex2(low_after)}"]
    else
      []
    end
  end

  # 8 / 16 bit 値を文字列に
  def hex2(value) = value.to_s(16).upcase.rjust(2, '0')
  def hex4(value) = value.to_s(16).upcase.rjust(4, '0')

  # PC+1 から 1 バイトを読んで "0xXX" に
  def u8_str(pc) = "0x#{hex2(@mmu.read_u8(address: pc + 1))}"

  # PC+1 から 2 バイトをリトルエンディアンで読んで "0xXXXX" に
  def u16_str(pc)
    low = @mmu.read_u8(address: pc + 1)
    high = @mmu.read_u8(address: pc + 2)
    "0x#{hex4((high << 8) | low)}"
  end

  # PC+1 から 1 バイトを符号付きとして読み、ジャンプ先絶対 PC も併記
  # JR の起点は「JR 命令の次バイト = pc + 2」
  # 無条件 JR (0x18) で使う。条件付き JR cc は branch_outcome 側で動的に表示するため i8_offset_str を使う
  def i8_jr_str(pc)
    raw = @mmu.read_u8(address: pc + 1)
    offset = raw < 0x80 ? raw : raw - 0x100
    target = Bit.wrap_u16(pc + 2 + offset)
    sign = offset >= 0 ? '+' : '-'
    "#{sign}#{offset.abs} (=> 0x#{hex4(target)})"
  end

  # PC+1 から 1 バイトを符号付きとして読み、オフセット値だけを返す(飛び先は付与しない)
  # 条件付き JR cc 用。実行結果は branch_outcome で末尾に付与される
  def i8_offset_str(pc)
    raw = @mmu.read_u8(address: pc + 1)
    offset = raw < 0x80 ? raw : raw - 0x100
    sign = offset >= 0 ? '+' : '-'
    "#{sign}#{offset.abs}"
  end

  # === メイン opcode の decode ===
  # 戻り値: [byte_length, mnemonic_string]
  # 規則的な範囲はビット分解、不規則な命令は個別 case
  def decode(pc, opcode)
    case opcode
    # === 制御 / システム ===
    when 0x00 then [1, 'NOP']
    when 0x76 then [1, 'HALT']
    when 0xF3 then [1, 'DI']
    when 0xFB then [1, 'EI']
    when 0xCB then [2, 'PREFIX CB'] # 通常は disassemble 側で吸収

    # === 8bit ロード - LD r,u8 ===
    when 0x06 then [2, "LD B, #{u8_str(pc)}"]
    when 0x0E then [2, "LD C, #{u8_str(pc)}"]
    when 0x16 then [2, "LD D, #{u8_str(pc)}"]
    when 0x1E then [2, "LD E, #{u8_str(pc)}"]
    when 0x26 then [2, "LD H, #{u8_str(pc)}"]
    when 0x2E then [2, "LD L, #{u8_str(pc)}"]
    when 0x36 then [2, "LD (HL), #{u8_str(pc)}"]
    when 0x3E then [2, "LD A, #{u8_str(pc)}"]

    # === 8bit ロード - LD r,r' (0x40-0x7F、0x76 は HALT で上で処理済み) ===
    when 0x40..0x7F
      dest = REGS[(opcode >> 3) & 0x07]
      src = REGS[opcode & 0x07]
      [1, "LD #{dest}, #{src}"]

    # === 8bit ロード - LD A,(rr) / LD (rr),A ===
    when 0x02 then [1, 'LD (BC), A']
    when 0x12 then [1, 'LD (DE), A']
    when 0x22 then [1, 'LD (HL+), A']
    when 0x32 then [1, 'LD (HL-), A']
    when 0x0A then [1, 'LD A, (BC)']
    when 0x1A then [1, 'LD A, (DE)']
    when 0x2A then [1, 'LD A, (HL+)']
    when 0x3A then [1, 'LD A, (HL-)']

    # === 8bit ロード - LD A,(u16) / LD (u16),A ===
    when 0xEA then [3, "LD (#{u16_str(pc)}), A"]
    when 0xFA then [3, "LD A, (#{u16_str(pc)})"]

    # === 8bit ロード - I/O ポート (0xFF00 + offset) ===
    when 0xE0 then [2, "LD (FF00+#{u8_str(pc)}), A"]
    when 0xE2 then [1, 'LD (FF00+C), A']
    when 0xF0 then [2, "LD A, (FF00+#{u8_str(pc)})"]
    when 0xF2 then [1, 'LD A, (FF00+C)']

    # === 16bit ロード ===
    when 0x01 then [3, "LD BC, #{u16_str(pc)}"]
    when 0x11 then [3, "LD DE, #{u16_str(pc)}"]
    when 0x21 then [3, "LD HL, #{u16_str(pc)}"]
    when 0x31 then [3, "LD SP, #{u16_str(pc)}"]
    when 0x08 then [3, "LD (#{u16_str(pc)}), SP"]
    when 0xF8 then [2, "LD HL, SP+#{i8_jr_str(pc)}"]
    when 0xF9 then [1, 'LD SP, HL']

    # === スタック - PUSH / POP ===
    when 0xC1 then [1, 'POP BC']
    when 0xD1 then [1, 'POP DE']
    when 0xE1 then [1, 'POP HL']
    when 0xF1 then [1, 'POP AF']
    when 0xC5 then [1, 'PUSH BC']
    when 0xD5 then [1, 'PUSH DE']
    when 0xE5 then [1, 'PUSH HL']
    when 0xF5 then [1, 'PUSH AF']

    # === 8bit 算術 - INC / DEC ===
    when 0x04 then [1, 'INC B']
    when 0x0C then [1, 'INC C']
    when 0x14 then [1, 'INC D']
    when 0x1C then [1, 'INC E']
    when 0x24 then [1, 'INC H']
    when 0x2C then [1, 'INC L']
    when 0x34 then [1, 'INC (HL)']
    when 0x3C then [1, 'INC A']
    when 0x05 then [1, 'DEC B']
    when 0x0D then [1, 'DEC C']
    when 0x15 then [1, 'DEC D']
    when 0x1D then [1, 'DEC E']
    when 0x25 then [1, 'DEC H']
    when 0x2D then [1, 'DEC L']
    when 0x35 then [1, 'DEC (HL)']
    when 0x3D then [1, 'DEC A']

    # === 16bit 算術 - INC rr / DEC rr ===
    when 0x03 then [1, 'INC BC']
    when 0x13 then [1, 'INC DE']
    when 0x23 then [1, 'INC HL']
    when 0x33 then [1, 'INC SP']
    when 0x0B then [1, 'DEC BC']
    when 0x1B then [1, 'DEC DE']
    when 0x2B then [1, 'DEC HL']
    when 0x3B then [1, 'DEC SP']

    # === 8bit 算術 - ADD / ADC / SUB / SBC (0x80-0x9F) ===
    when 0x80..0x87 then [1, "ADD A, #{REGS[opcode & 0x07]}"]
    when 0x88..0x8F then [1, "ADC A, #{REGS[opcode & 0x07]}"]
    when 0x90..0x97 then [1, "SUB A, #{REGS[opcode & 0x07]}"]
    when 0x98..0x9F then [1, "SBC A, #{REGS[opcode & 0x07]}"]
    when 0xC6 then [2, "ADD A, #{u8_str(pc)}"]
    when 0xCE then [2, "ADC A, #{u8_str(pc)}"]
    when 0xD6 then [2, "SUB A, #{u8_str(pc)}"]
    when 0xDE then [2, "SBC A, #{u8_str(pc)}"]

    # === 8bit 論理 / 比較 (0xA0-0xBF) ===
    when 0xA0..0xA7 then [1, "AND A, #{REGS[opcode & 0x07]}"]
    when 0xA8..0xAF then [1, "XOR A, #{REGS[opcode & 0x07]}"]
    when 0xB0..0xB7 then [1, "OR A, #{REGS[opcode & 0x07]}"]
    when 0xB8..0xBF then [1, "CP A, #{REGS[opcode & 0x07]}"]
    when 0xE6 then [2, "AND A, #{u8_str(pc)}"]
    when 0xEE then [2, "XOR A, #{u8_str(pc)}"]
    when 0xF6 then [2, "OR A, #{u8_str(pc)}"]
    when 0xFE then [2, "CP A, #{u8_str(pc)}"]

    # === ローテート (Aレジスタ用1バイト命令) ===
    when 0x07 then [1, 'RLCA']
    when 0x0F then [1, 'RRCA']
    when 0x17 then [1, 'RLA']
    when 0x1F then [1, 'RRA']

    # === その他演算 ===
    when 0x27 then [1, 'DAA']
    when 0x2F then [1, 'CPL']
    when 0x37 then [1, 'SCF']
    when 0x3F then [1, 'CCF']

    # === 16bit 算術 - ADD HL,rr ===
    when 0x09 then [1, 'ADD HL, BC']
    when 0x19 then [1, 'ADD HL, DE']
    when 0x29 then [1, 'ADD HL, HL']
    when 0x39 then [1, 'ADD HL, SP']
    when 0xE8 then [2, "ADD SP, #{i8_jr_str(pc)}"]

    # === ジャンプ - JP ===
    when 0xC3 then [3, "JP #{u16_str(pc)}"]
    when 0xE9 then [1, 'JP HL']
    when 0xC2 then [3, "JP NZ, #{u16_str(pc)}"]
    when 0xCA then [3, "JP Z, #{u16_str(pc)}"]
    when 0xD2 then [3, "JP NC, #{u16_str(pc)}"]
    when 0xDA then [3, "JP C, #{u16_str(pc)}"]

    # === ジャンプ - JR ===
    # 無条件 JR は静的飛び先を併記。条件付き JR cc は taken/not taken 判定後に branch_outcome で動的飛び先を付与する
    when 0x18 then [2, "JR #{i8_jr_str(pc)}"]
    when 0x20 then [2, "JR NZ, #{i8_offset_str(pc)}"]
    when 0x28 then [2, "JR Z, #{i8_offset_str(pc)}"]
    when 0x30 then [2, "JR NC, #{i8_offset_str(pc)}"]
    when 0x38 then [2, "JR C, #{i8_offset_str(pc)}"]

    # === コール / リターン ===
    when 0xCD then [3, "CALL #{u16_str(pc)}"]
    when 0xC4 then [3, "CALL NZ, #{u16_str(pc)}"]
    when 0xCC then [3, "CALL Z, #{u16_str(pc)}"]
    when 0xD4 then [3, "CALL NC, #{u16_str(pc)}"]
    when 0xDC then [3, "CALL C, #{u16_str(pc)}"]
    when 0xC9 then [1, 'RET']
    when 0xD9 then [1, 'RETI']
    when 0xC0 then [1, 'RET NZ']
    when 0xC8 then [1, 'RET Z']
    when 0xD0 then [1, 'RET NC']
    when 0xD8 then [1, 'RET C']

    # === RST ===
    when 0xC7 then [1, 'RST 00H']
    when 0xCF then [1, 'RST 08H']
    when 0xD7 then [1, 'RST 10H']
    when 0xDF then [1, 'RST 18H']
    when 0xE7 then [1, 'RST 20H']
    when 0xEF then [1, 'RST 28H']
    when 0xF7 then [1, 'RST 30H']
    when 0xFF then [1, 'RST 38H']

    # === STOP ===
    when 0x10 then [2, 'STOP']

    # === 未知 / 未割り当て ===
    else [1, "DB 0x#{hex2(opcode)}"]
    end
  end

  # === CB-prefix の decode (全 256 個を bit 分解で網羅) ===
  # 0xCB に続く 2 バイト目のフォーマット:
  #   0x00-0x07  RLC r       0x08-0x0F  RRC r
  #   0x10-0x17  RL r        0x18-0x1F  RR r
  #   0x20-0x27  SLA r       0x28-0x2F  SRA r
  #   0x30-0x37  SWAP r      0x38-0x3F  SRL r
  #   0x40-0x7F  BIT n,r     (n = bit5..3)
  #   0x80-0xBF  RES n,r
  #   0xC0-0xFF  SET n,r
  def cb_mnemonic(cb_opcode)
    reg = REGS[cb_opcode & 0x07]
    bit = (cb_opcode >> 3) & 0x07
    case cb_opcode
    when 0x00..0x07 then "RLC #{reg}"
    when 0x08..0x0F then "RRC #{reg}"
    when 0x10..0x17 then "RL #{reg}"
    when 0x18..0x1F then "RR #{reg}"
    when 0x20..0x27 then "SLA #{reg}"
    when 0x28..0x2F then "SRA #{reg}"
    when 0x30..0x37 then "SWAP #{reg}"
    when 0x38..0x3F then "SRL #{reg}"
    when 0x40..0x7F then "BIT #{bit}, #{reg}"
    when 0x80..0xBF then "RES #{bit}, #{reg}"
    when 0xC0..0xFF then "SET #{bit}, #{reg}"
    end
  end
end
