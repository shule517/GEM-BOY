require 'app/emulator/bit'

# Timer (DIV/TIMA/TMA/TAC) のレジスタを名前付きアクセサで操作する
# Pan Docs: https://gbdev.io/pandocs/Timer_and_Divider_Registers.html
#
#   0xFF04  DIV   16384 Hz で +1
#   0xFF05  TIMA  TAC の周波数で +1。0xFF を超えると TMA を再ロード + IF.timer をセット
#   0xFF06  TMA   TIMA オーバーフロー時に再ロードされる値
#   0xFF07  TAC   bit2=Enable / bits1-0=Clock select
#
# TAC Clock select:
#   00 → 1024 T-cycle ごとに +1 (4096 Hz)
#   01 →   16 T-cycle ごとに +1 (262144 Hz)
#   10 →   64 T-cycle ごとに +1 (65536 Hz)
#   11 →  256 T-cycle ごとに +1 (16384 Hz)
class Timer
  ENABLE_BIT = 2
  CLOCK_MASK = 0b11

  def initialize(mmu)
    @mmu = mmu
  end

  # TAC (Timer Control) bit2 (Enable): TIMAをインクリメントするかどうか。DIVは常に動くので無関係
  def timer_control_enabled
    Bit.bit_at(read_tac, ENABLE_BIT)
  end

  def timer_control_enabled?
    timer_control_enabled == 1
  end

  def timer_control_enabled=(value)
    write_tac(Bit.set_bit(read_tac, ENABLE_BIT, value))
  end

  # TAC (Timer Control) bits1-0 (Clock select): TIMAを+1する間隔
  def timer_control_clock
    read_tac & CLOCK_MASK
  end

  def timer_control_clock=(value)
    write_tac((read_tac & ~CLOCK_MASK) | (value & CLOCK_MASK))
  end

  # TIMA (Timer Counter): 現在のカウンタ値
  def timer_counter
    @mmu.read_u8(address: MMU::TIMA)
  end

  def timer_counter=(value)
    @mmu.write_io_direct(address: MMU::TIMA, value: value)
  end

  # TMA (Timer Modulo): TIMA がオーバーフローしたときに再ロードされる値
  def timer_modulo
    @mmu.read_u8(address: MMU::TMA)
  end

  def timer_modulo=(value)
    @mmu.write_io_direct(address: MMU::TMA, value: value)
  end

  private

  def read_tac
    @mmu.read_u8(address: MMU::TAC)
  end

  def write_tac(value)
    @mmu.write_io_direct(address: MMU::TAC, value: value)
  end
end
