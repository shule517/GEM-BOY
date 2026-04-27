require 'app/emulator/cartridge'

RSpec.describe Cartridge do
  describe '#initialize' do
    subject { described_class.new(data) }

    context 'バイト配列を渡したとき' do
      let(:data) { [0xC3, 0x00, 0x01] }
      it 'Cartridge を返す' do
        is_expected.to be_a described_class
      end
    end

    context 'バイナリ文字列を渡したとき' do
      let(:data) { "\xC3\x00\x01".b }
      it 'Cartridge を返す' do
        is_expected.to be_a described_class
      end
    end

    context 'nil を渡したとき' do
      let(:data) { nil }
      it '例外を投げる' do
        expect { subject }.to raise_error(/Empty ROM/)
      end
    end

    context '空配列を渡したとき' do
      let(:data) { [] }
      it '例外を投げる' do
        expect { subject }.to raise_error(/Empty ROM/)
      end
    end
  end

  describe '#read' do
    subject { cartridge.read(address) }
    let(:cartridge) { described_class.new(data) }

    context 'ROM 範囲外のアドレスを指定したとき' do
      let(:data) { [0x01, 0x02] }
      let(:address) { 99 }
      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end
  end

  describe '#title' do
    subject { cartridge.title }
    let(:cartridge) { described_class.new(File.binread(rom_path).bytes) }
    let(:rom_path) { File.expand_path('../../../../data/tobu.gb', __FILE__) }

    it '"TOBU" を返す' do
      is_expected.to eq 'TOBU'
    end
  end

  describe '#size' do
    subject { cartridge.size }
    let(:cartridge) { described_class.new(File.binread(rom_path).bytes) }
    let(:rom_path) { File.expand_path('../../../../data/tobu.gb', __FILE__) }

    it '262144 (256KB) を返す' do
      is_expected.to eq 262144
    end
  end
end
