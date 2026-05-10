require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/timer'

RSpec.describe Timer do
  let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }
  let(:timer) { described_class.new(mmu) }

  describe '#tac_enable' do
    subject { timer.tac_enable }

    context 'TAC bit 2 が 1 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) }
      it { is_expected.to eq 1 }
    end

    context 'TAC bit 2 が 0 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it { is_expected.to eq 0 }
    end
  end

  describe '#tac_enable?' do
    subject { timer.tac_enable? }

    context 'TAC bit 2 が 1 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) }
      it { is_expected.to eq true }
    end

    context 'TAC bit 2 が 0 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#tac_enable=' do
    context 'true を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000000) }
      it 'TAC bit 2 が立つ' do
        timer.tac_enable = true
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000100
      end
    end

    context 'false を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) }
      it 'TAC bit 2 だけクリアして他は保つ' do
        timer.tac_enable = false
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000011
      end
    end
  end

  describe '#tac_clock' do
    subject { timer.tac_clock }

    context 'TAC bits1-0 が 01 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000101) }
      it { is_expected.to eq 0b01 }
    end

    context 'TAC bits1-0 が 11 のとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) }
      it { is_expected.to eq 0b11 }
    end
  end

  describe '#tac_clock=' do
    context '0b10 を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000100) } # enable=1, clock=00
      it 'TAC bits1-0 だけ書き換え、enable bit は保つ' do
        timer.tac_clock = 0b10
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000110
      end
    end

    context '0b00 を設定したとき' do
      before { mmu.write_u8(address: MMU::TAC, value: 0b00000111) } # enable=1, clock=11
      it 'TAC bits1-0 だけクリアし、enable bit は保つ' do
        timer.tac_clock = 0b00
        expect(mmu.read_u8(address: MMU::TAC)).to eq 0b00000100
      end
    end
  end

  describe '#tima' do
    subject { timer.tima }

    context 'TIMA が 0x42 のとき' do
      before { mmu.write_u8(address: MMU::TIMA, value: 0x42) }
      it { is_expected.to eq 0x42 }
    end
  end

  describe '#tima=' do
    it 'TIMA に値が書き込まれる' do
      timer.tima = 0xAB
      expect(mmu.read_u8(address: MMU::TIMA)).to eq 0xAB
    end
  end

  describe '#tma' do
    subject { timer.tma }

    context 'TMA が 0x42 のとき' do
      before { mmu.write_u8(address: MMU::TMA, value: 0x42) }
      it { is_expected.to eq 0x42 }
    end
  end

  describe '#tma=' do
    it 'TMA に値が書き込まれる' do
      timer.tma = 0xCD
      expect(mmu.read_u8(address: MMU::TMA)).to eq 0xCD
    end
  end
end
