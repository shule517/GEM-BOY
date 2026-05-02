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
class Register
  # レジスタ: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#cpu-registers-and-flags
  attr_accessor :a, :f, # 8bitレジスタ: Accumulator, Flags(High / Low)
                :b, :c, # 8bitレジスタ(High / Low)
                :d, :e, # 8bitレジスタ(High / Low)
                :h, :l  # 8bitレジスタ(High / Low)

  def initialize(skip_boot: false)
    if skip_boot
      # ブートROM 完走後の DMG 実機値(skip_boot 起動でブートROM をスキップ)
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
      @a = 0x01; @f = 0xB0 # A: DMG識別値、F: Z=1,N=0,H=1,C=1
      @b = 0x00; @c = 0x13
      @d = 0x00; @e = 0xD8
      @h = 0x01; @l = 0x4D # HL: カートリッジヘッダのチェックサム関連
    else
      # ブートROM 経由で起動するので全レジスタ 0 から始める
      @a = @b = @c = @d = @e = @h = @l = @f = 0
    end
  end

  # F レジスタ(bit7=Z, bit6=N, bit5=H, bit4=C、下位 4bit は常に 0)の各ビットを更新する
  # true なら 1、false なら 0に変更する
  # 引数名は gbops 表記に揃えている(`negative` は Pan Docs 正式名では Subtract フラグ)
  # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html#the-flags-register-lower-8-bits-of-af-register
  def set_flags(zero: nil, negative: nil, half_carry: nil, carry: nil)
    self.zero = zero unless zero.nil?                   # bit7 Zero
    self.negative = negative unless negative.nil?       # bit6 Negative (Subtract)
    self.half_carry = half_carry unless half_carry.nil? # bit5 Half Carry
    self.carry = carry unless carry.nil?                # bit4 Carry
  end

  def zero = Bit.bit_at(f, 7)
  def negative = Bit.bit_at(f, 6)
  def half_carry = Bit.bit_at(f, 5)
  def carry = Bit.bit_at(f, 4)

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
end
