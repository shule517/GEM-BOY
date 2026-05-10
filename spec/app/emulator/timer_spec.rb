require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/timer'

RSpec.describe Timer do
  let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }
  let(:timer) { described_class.new(mmu) }

  describe '#timer_control_enabled' do
    subject { timer.timer_control_enabled }

    context 'TAC bit 2 が 1 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) }
      it { is_expected.to eq 1 }
    end

    context 'TAC bit 2 が 0 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it { is_expected.to eq 0 }
    end
  end

  describe '#timer_control_enabled?' do
    subject { timer.timer_control_enabled? }

    context 'TAC bit 2 が 1 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) }
      it { is_expected.to eq true }
    end

    context 'TAC bit 2 が 0 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#timer_control_enabled=' do
    context 'true を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it 'TAC bit 2 が立つ' do
        timer.timer_control_enabled = true
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000100
      end
    end

    context 'false を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) }
      it 'TAC bit 2 だけクリアして他は保つ' do
        timer.timer_control_enabled = false
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000011
      end
    end
  end

  describe '#timer_control_clock' do
    subject { timer.timer_control_clock }

    context 'TAC bits1-0 が 01 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000101) }
      it { is_expected.to eq 0b01 }
    end

    context 'TAC bits1-0 が 11 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) }
      it { is_expected.to eq 0b11 }
    end
  end

  describe '#timer_control_clock=' do
    context '0b10 を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) } # enable=1, clock=00
      it 'TAC bits1-0 だけ書き換え、enable bit は保つ' do
        timer.timer_control_clock = 0b10
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000110
      end
    end

    context '0b00 を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) } # enable=1, clock=11
      it 'TAC bits1-0 だけクリアし、enable bit は保つ' do
        timer.timer_control_clock = 0b00
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000100
      end
    end
  end

  describe '#timer_counter' do
    subject { timer.timer_counter }

    context 'TIMA が 0x42 のとき' do
      before { mmu.write_u8(address: MMU::TIMA, value: 0x42) }
      it { is_expected.to eq 0x42 }
    end
  end

  describe '#timer_counter=' do
    it 'TIMA に値が書き込まれる' do
      timer.timer_counter = 0xAB
      expect(mmu.read_u8(address: MMU::TIMA)).to eq 0xAB
    end
  end

  describe '#timer_modulo' do
    subject { timer.timer_modulo }

    context 'TMA が 0x42 のとき' do
      before { mmu.write_u8(address: MMU::TMA, value: 0x42) }
      it { is_expected.to eq 0x42 }
    end
  end

  describe '#timer_modulo=' do
    it 'TMA に値が書き込まれる' do
      timer.timer_modulo = 0xCD
      expect(mmu.read_u8(address: MMU::TMA)).to eq 0xCD
    end
  end
end
