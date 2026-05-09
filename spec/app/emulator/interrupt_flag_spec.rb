require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/interrupt_flag'

RSpec.describe InterruptFlag do
  let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }
  let(:interrupt_flag) { described_class.new(mmu) }

  describe '#v_blank?' do
    subject { interrupt_flag.v_blank? }

    context 'IF bit 0 が 1 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000001) }
      it { is_expected.to eq true }
    end

    context 'IF bit 0 が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#lcd?' do
    subject { interrupt_flag.lcd? }

    context 'IF bit 1 が 1 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000010) }
      it { is_expected.to eq true }
    end

    context 'IF bit 1 が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#timer?' do
    subject { interrupt_flag.timer? }

    context 'IF bit 2 が 1 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000100) }
      it { is_expected.to eq true }
    end

    context 'IF bit 2 が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#serial?' do
    subject { interrupt_flag.serial? }

    context 'IF bit 3 が 1 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00001000) }
      it { is_expected.to eq true }
    end

    context 'IF bit 3 が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#joypad?' do
    subject { interrupt_flag.joypad? }

    context 'IF bit 4 が 1 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00010000) }
      it { is_expected.to eq true }
    end

    context 'IF bit 4 が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it { is_expected.to eq false }
    end
  end

  describe '#timer=' do
    subject { interrupt_flag.timer = true }

    context '元の IF が 0 のとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00000000) }
      it 'IF bit 2 だけ立つ' do
        subject
        expect(mmu.read_u8(address: MMU::IF)).to eq 0b00000100
      end
    end

    context '他の bit が立っているとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00010001) } # joypad + v_blank
      it '他の bit を保ちつつ bit 2 を立てる' do
        subject
        expect(mmu.read_u8(address: MMU::IF)).to eq 0b00010101
      end
    end
  end

  describe '#timer= false' do
    subject { interrupt_flag.timer = false }

    context 'bit 2 が立っているとき' do
      before { mmu.write_u8(address: MMU::IF, value: 0b00011111) }
      it 'bit 2 だけクリアして他は保つ' do
        subject
        expect(mmu.read_u8(address: MMU::IF)).to eq 0b00011011
      end
    end
  end
end
