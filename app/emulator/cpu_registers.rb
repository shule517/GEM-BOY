require 'app/emulator/bit'

# CPU の 8bit レジスタとフラグレジスタ
#
# Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
#
# === レジスタ ===
#
#   8bit:  A  B  C  D  E  H  L  F     汎用 7 + フラグ 1
#   pair:  AF, BC, DE, HL             8bit ペアを 16bit としても扱える
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
class CpuRegisters
  # F レジスタ内のフラグ位置(bit3-0 は常に 0)
  # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#the-flags-register-lower-8-bits-of-af-register
  FLAG_Z_BIT = 7 # Zero
  FLAG_N_BIT = 6 # Negative (Subtract)
  FLAG_H_BIT = 5 # Half Carry
  FLAG_C_BIT = 4 # Carry

  # レジスタ: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#cpu-registers-and-flags
  # 8bit レジスタの setter は値を u8 (0..255) にラップして保持する。算出結果が +1/-1 で
  # 256/-1 になっても各 setter 側で吸収するので、INC/DEC などの呼び出し側で毎回
  # Bit.wrap_u8 を書かなくて済む
  attr_reader :a, :f, # 8bitレジスタ: Accumulator, Flags(High / Low)
              :b, :c, # 8bitレジスタ(High / Low)
              :d, :e, # 8bitレジスタ(High / Low)
              :h, :l  # 8bitレジスタ(High / Low)

  # SP / PC の setter も値を u16 (0..0xFFFF) にラップして保持する
  attr_reader :sp, # スタックポインタ
              :pc # プログラムカウンタ 今メモリのどこを読んでいるか

  def a=(value); @a = Bit.wrap_u8(value); end
  def f=(value); @f = Bit.wrap_u8(value); end
  def b=(value); @b = Bit.wrap_u8(value); end
  def c=(value); @c = Bit.wrap_u8(value); end
  def d=(value); @d = Bit.wrap_u8(value); end
  def e=(value); @e = Bit.wrap_u8(value); end
  def h=(value); @h = Bit.wrap_u8(value); end
  def l=(value); @l = Bit.wrap_u8(value); end

  def sp=(value); @sp = Bit.wrap_u16(value); end
  def pc=(value); @pc = Bit.wrap_u16(value); end

  def initialize(skip_boot: false)
    if skip_boot
      # ブートROM 完走後の DMG 実機値(skip_boot 起動でブートROM をスキップ)
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
      @a = 0x01; @f = 0xB0 # A: DMG識別値、F: Z=1,N=0,H=1,C=1
      @b = 0x00; @c = 0x13
      @d = 0x00; @e = 0xD8
      @h = 0x01; @l = 0x4D # HL: カートリッジヘッダのチェックサム関連
      @sp = 0xFFFE         # HRAM末端
      @pc = 0x0100         # カートリッジコードの開始位置
    else
      # ブートROM 経由で起動するので全レジスタ 0 から始める
      @a = @b = @c = @d = @e = @h = @l = @f = @sp = @pc = 0
    end
  end

  # F レジスタ(bit7=Z, bit6=N, bit5=H, bit4=C、下位 4bit は常に 0)の各ビットを更新する
  # true なら 1、false なら 0に変更する
  # 引数名は gbops 表記に揃えている(`negative` は Pan Docs 正式名では Subtract フラグ)
  # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#the-flags-register-lower-8-bits-of-af-register
  def set_flags(zero: nil, negative: nil, half_carry: nil, carry: nil)
    self.zero_flag = zero unless zero.nil?                   # bit7 Zero
    self.negative_flag = negative unless negative.nil?       # bit6 Negative (Subtract)
    self.half_carry_flag = half_carry unless half_carry.nil? # bit5 Half Carry
    self.carry_flag = carry unless carry.nil?                # bit4 Carry
  end

  def zero_flag = Bit.bit_at(f, FLAG_Z_BIT)
  def negative_flag = Bit.bit_at(f, FLAG_N_BIT)
  def half_carry_flag = Bit.bit_at(f, FLAG_H_BIT)
  def carry_flag = Bit.bit_at(f, FLAG_C_BIT)

  def zero_flag=(value)
    self.f = Bit.set_bit(f, FLAG_Z_BIT, value) # bit7 Zero
  end

  def negative_flag=(value)
    self.f = Bit.set_bit(f, FLAG_N_BIT, value) # bit6 Negative (Subtract)
  end

  def half_carry_flag=(value)
    self.f = Bit.set_bit(f, FLAG_H_BIT, value) # bit5 Half Carry
  end

  def carry_flag=(value)
    self.f = Bit.set_bit(f, FLAG_C_BIT, value) # bit4 Carry
  end

  def bc = Bit.make_u16(high: b, low: c)
  def de = Bit.make_u16(high: d, low: e)
  def hl = Bit.make_u16(high: h, low: l)

  def bc=(value)
    self.b = Bit.high_byte(value)
    self.c = Bit.low_byte(value)
  end

  def de=(value)
    self.d = Bit.high_byte(value)
    self.e = Bit.low_byte(value)
  end

  def hl=(value)
    self.h = Bit.high_byte(value)
    self.l = Bit.low_byte(value)
  end

  # 16bit レジスタペアの +1 / -1(u16 ラップは setter 側で吸収)
  # INC rr / DEC rr(0x03/0x0B/0x13/0x1B/0x23/0x2B/0x33/0x3B)で使う。フラグは変化しない
  # Pan Docs: https://rgbds.gbdev.io/docs/v1.0.1/gbz80.7#INC_r16
  def bc_increment = self.bc = bc + 1
  def de_increment = self.de = de + 1
  def hl_increment = self.hl = hl + 1
  def sp_increment = self.sp = sp + 1
  def pc_increment = self.pc = pc + 1

  def bc_decrement = self.bc = bc - 1
  def de_decrement = self.de = de - 1
  def hl_decrement = self.hl = hl - 1
  def sp_decrement = self.sp = sp - 1
  def pc_decrement = self.pc = pc - 1
end
