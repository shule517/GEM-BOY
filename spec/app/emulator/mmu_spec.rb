require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/lcd_registers'

RSpec.describe MMU do
  describe '#read' do
    subject { mmu.read_u8(address: address) }
    let(:mmu) { described_class.new(cartridge) }
    let(:cartridge) { Cartridge.new(rom_data) }
    let(:rom_data) do
      data = Array.new(0x8000, 0)
      # 0x0100 = カートリッジのエントリポイント、0xC3 = JP 命令のオペコード。
      # 実 ROM の先頭にも現れる典型的な値で、ここに「ゼロ初期値ではない目印」を置くことで
      # ROM 読み込みが正しく振り分けられたか / ROM 書き込みが無視されるかをテストできる。
      data[0x0100] = 0xC3
      data
    end

    context 'ROM領域 (0x0000-0x7FFF) を読んだとき' do
      let(:address) { 0x0100 }
      it 'カートリッジの値 0xC3 を返す' do
        is_expected.to eq 0xC3
      end
    end

    context 'VRAM領域 (0x8000-0x9FFF) を読んだとき' do
      let(:address) { 0x8000 }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'WRAM領域 (0xC000-0xDFFF) を読んだとき' do
      let(:address) { 0xC000 }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'OAM領域 (0xFE00-0xFE9F) を読んだとき' do
      let(:address) { 0xFE00 }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'I/O領域 (0xFF00-0xFF7F) を読んだとき' do
      let(:address) { 0xFF00 }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'HRAM領域 (0xFF80-0xFFFE) を読んだとき' do
      let(:address) { 0xFF80 }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'IEレジスタ (0xFFFF) を読んだとき' do
      let(:address) { 0xFFFF }
      it '初期値 0 を返す' do
        is_expected.to eq 0
      end
    end

    context '使用禁止領域 (0xFEA0-0xFEFF) を読んだとき' do
      let(:address) { 0xFEA0 }
      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end
  end

  describe '#write' do
    let(:mmu) { described_class.new(cartridge) }
    let(:cartridge) { Cartridge.new(rom_data) }
    let(:rom_data) do
      data = Array.new(0x8000, 0)
      # 0x0100 = カートリッジのエントリポイント、0xC3 = JP 命令のオペコード。
      # 実 ROM の先頭にも現れる典型的な値で、ここに「ゼロ初期値ではない目印」を置くことで
      # ROM 読み込みが正しく振り分けられたか / ROM 書き込みが無視されるかをテストできる。
      data[0x0100] = 0xC3
      data
    end

    before do
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    context 'VRAM領域に書き込んだとき' do
      subject do
        mmu.write_u8(address: 0x8000, value: 0x42)
        mmu.read_u8(address: 0x8000)
      end
      it '読み戻すと 0x42 になる' do
        is_expected.to eq 0x42
      end
    end

    context 'WRAM領域に書き込んだとき' do
      subject do
        mmu.write_u8(address: MMU::WRAM_START, value: 0x42)
        mmu.read_u8(address: MMU::WRAM_START)
      end
      it '読み戻すと 0x42 になる' do
        is_expected.to eq 0x42
      end
    end

    context 'HRAM領域に書き込んだとき' do
      subject do
        mmu.write_u8(address: MMU::HRAM_START, value: 0x42)
        mmu.read_u8(address: MMU::HRAM_START)
      end
      it '読み戻すと 0x42 になる' do
        is_expected.to eq 0x42
      end
    end

    context 'IEレジスタに書き込んだとき' do
      subject do
        mmu.write_u8(address: MMU::IE, value: 0x1F)
        mmu.read_u8(address: MMU::IE)
      end
      it '読み戻すと 0x1F になる' do
        is_expected.to eq 0x1F
      end
    end

    context '0xFF を超える値を書き込んだとき' do
      subject do
        mmu.write_u8(address: MMU::WRAM_START, value: 0x1FF)
        mmu.read_u8(address: MMU::WRAM_START)
      end
      it '下位 8bit に切り詰められた 0xFF になる' do
        is_expected.to eq 0xFF
      end
    end

    context 'ROM領域に書き込んだとき' do
      subject do
        mmu.write_u8(address: 0x0100, value: 0x42)
        mmu.read_u8(address: 0x0100)
      end
      it '書き込みは無視され、ROM の値 0xC3 のまま' do
        is_expected.to eq 0xC3
      end
    end
  end

  describe '#serial_buffer' do
    subject { mmu.serial_buffer }
    let(:mmu) { described_class.new(cartridge) }
    let(:cartridge) { Cartridge.new(rom_data) }
    let(:rom_data) { Array.new(0x8000, 0) }

    before do
      allow($stdout).to receive(:print)
      allow($stdout).to receive(:flush)
    end

    context '初期状態' do
      it '空文字列' do
        is_expected.to eq ''
      end
    end

    context 'SB に文字を置いて SC に SC_TRANSFER_START を書いたとき' do
      before do
        mmu.write_u8(address: MMU::SB, value: 'A'.ord)
        mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
      end
      it '"A" が追記される' do
        is_expected.to eq 'A'
      end
    end

    context '複数文字を順次送信したとき' do
      before do
        %w(G B).each do |c|
          mmu.write_u8(address: MMU::SB, value: c.ord)
          mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
        end
      end
      it '"GB" の順で連結される' do
        is_expected.to eq 'GB'
      end
    end

    context 'SC に SC_TRANSFER_START 以外を書いたとき' do
      before do
        mmu.write_u8(address: MMU::SB, value: 'A'.ord)
        mmu.write_u8(address: MMU::SC, value: 0x80)
      end
      it 'serial_buffer は空のまま' do
        is_expected.to eq ''
      end
    end

    context 'シリアル送信後の SC を読んだとき' do
      subject do
        mmu.write_u8(address: MMU::SB, value: 'A'.ord)
        mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
        mmu.read_u8(address: MMU::SC)
      end
      it '転送完了シグナル 0x01 (bit7 が落ちている) になる' do
        is_expected.to eq 0x01
      end
    end
  end

  describe '#initialize' do
    let(:cartridge) { Cartridge.new(Array.new(0x8000, 0)) }

    context 'skip_boot を指定しないとき(ブートROM 経由起動)' do
      subject { described_class.new(cartridge) }

      it 'I/O レジスタは 0 で初期化される(LCDC=0, BGP=0)' do
        expect(subject.read_u8(address: LcdRegisters::LCDC)).to eq 0
        expect(subject.read_u8(address: LcdRegisters::BGP)).to eq 0
      end
    end

    context 'skip_boot: true を指定したとき(ブートROM をスキップして起動)' do
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#hardware-registers
      # ブートROM 完走後の I/O レジスタ初期値を最初からセットして起動する
      subject { described_class.new(cartridge, skip_boot: true) }

      it 'LCDC=0x91(LCD ON + BG ON + unsigned addressing)' do
        expect(subject.read_u8(address: LcdRegisters::LCDC)).to eq 0x91
      end

      it 'BGP=0xFC(標準パレット)' do
        expect(subject.read_u8(address: LcdRegisters::BGP)).to eq 0xFC
      end
    end
  end
end
