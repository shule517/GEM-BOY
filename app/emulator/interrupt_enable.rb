require 'app/emulator/bit'

# Interrupt Enable (IE) レジスタ 0xFFFF の各ビットを名前付きアクセサで操作する
# Pan Docs: https://gbdev.io/pandocs/Interrupts.html#ffff--ie-interrupt-enable
#
#   bit 0  V-Blank
#   bit 1  LCD STAT
#   bit 2  Timer
#   bit 3  Serial
#   bit 4  Joypad
class InterruptEnable
  V_BLANK = 0
  LCD     = 1
  TIMER   = 2
  SERIAL  = 3
  JOYPAD  = 4

  def initialize(mmu)
    @mmu = mmu
  end

  def v_blank? = read_bit(V_BLANK) == 1
  def lcd?     = read_bit(LCD)     == 1
  def timer?   = read_bit(TIMER)   == 1
  def serial?  = read_bit(SERIAL)  == 1
  def joypad?  = read_bit(JOYPAD)  == 1

  def v_blank=(value); write_bit(V_BLANK, value); end
  def lcd=(value);     write_bit(LCD,     value); end
  def timer=(value);   write_bit(TIMER,   value); end
  def serial=(value);  write_bit(SERIAL,  value); end
  def joypad=(value);  write_bit(JOYPAD,  value); end

  private

  def read_bit(n)
    Bit.bit_at(@mmu.read_u8(address: MMU::IE), n)
  end

  def write_bit(n, value)
    byte = @mmu.read_u8(address: MMU::IE)
    @mmu.write_u8(address: MMU::IE, value: Bit.set_bit(byte, n, value))
  end
end
