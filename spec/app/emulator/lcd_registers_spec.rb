require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/lcd_registers'

RSpec.describe LcdRegisters do
  describe '#lcd_enabled?' do
    # LCDC bit7 = LCD Enable
    # Pan Docs: https://gbdev.io/pandocs/LCDC.html#lcdc7--lcd-enable
    subject { lcd_registers.lcd_enabled? }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'LCDC bit7=1 (0x80) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x80) }

      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'LCDC bit7=0 (0x00) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x00) }

      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context 'LCDC=0x7F (bit7=0, 他全部1) のとき' do
      # bit7だけを見て他のビットには影響されないことを確認
      before { mmu.write_u8(address: 0xFF40, value: 0x7F) }

      it 'false を返す' do
        is_expected.to eq false
      end
    end
  end

  describe '#bg_enabled?' do
    # LCDC bit0 = BG/Window Enable
    # Pan Docs: https://gbdev.io/pandocs/LCDC.html#lcdc0--bg-and-window-enablepriority
    subject { lcd_registers.bg_enabled? }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'LCDC bit0=1 (0x01) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x01) }

      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'LCDC bit0=0 (0x00) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x00) }

      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context 'LCDC=0xFE (bit0=0, 他全部1) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0xFE) }

      it 'false を返す' do
        is_expected.to eq false
      end
    end
  end

  describe '#bg_tile_map_address' do
    # LCDC bit3 = BG Tile Map Area
    # Pan Docs: https://gbdev.io/pandocs/LCDC.html#lcdc3--bg-tile-map-area
    subject { lcd_registers.bg_tile_map_address }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'LCDC bit3=0 のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x00) }

      it '0x9800 を返す' do
        is_expected.to eq 0x9800
      end
    end

    context 'LCDC bit3=1 (0x08) のとき' do
      before { mmu.write_u8(address: 0xFF40, value: 0x08) }

      it '0x9C00 を返す' do
        is_expected.to eq 0x9C00
      end
    end
  end

  describe '#bg_tile_data_unsigned?' do
    # LCDC bit4 = BG and Window Tile Data Area
    # Pan Docs: https://gbdev.io/pandocs/LCDC.html#lcdc4--bg-and-window-tile-data-area
    subject { lcd_registers.bg_tile_data_unsigned? }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'LCDC bit4=1 (0x10) のとき(unsigned アドレッシング、0x8000基点)' do
      before { mmu.write_u8(address: 0xFF40, value: 0x10) }

      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'LCDC bit4=0 のとき(signed アドレッシング、0x9000基点)' do
      before { mmu.write_u8(address: 0xFF40, value: 0x00) }

      it 'false を返す' do
        is_expected.to eq false
      end
    end
  end

  describe '#scy' do
    # 0xFF42 = SCY (Viewport Y) を素直にバイトとして返す
    # Pan Docs: https://gbdev.io/pandocs/Scrolling.html
    subject { lcd_registers.scy }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'SCY=0x00 のとき' do
      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'SCY=0x42 のとき' do
      before { mmu.write_u8(address: 0xFF42, value: 0x42) }

      it '0x42 を返す' do
        is_expected.to eq 0x42
      end
    end

    context 'SCY=0xFF のとき' do
      before { mmu.write_u8(address: 0xFF42, value: 0xFF) }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end
  end

  describe '#scx' do
    # 0xFF43 = SCX (Viewport X) を素直にバイトとして返す
    subject { lcd_registers.scx }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'SCX=0x00 のとき' do
      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'SCX=0x42 のとき' do
      before { mmu.write_u8(address: 0xFF43, value: 0x42) }

      it '0x42 を返す' do
        is_expected.to eq 0x42
      end
    end

    context 'SCX=0xFF のとき' do
      before { mmu.write_u8(address: 0xFF43, value: 0xFF) }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end
  end

  describe '#bgp' do
    # 0xFF47 = BGP (BG Palette) を素直にバイトとして返す
    # Pan Docs: https://gbdev.io/pandocs/Palettes.html#ff47--bgp-non-cgb-mode-only-bg-palette-data
    subject { lcd_registers.bgp }
    let(:lcd_registers) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'BGP=0x00 のとき' do
      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context 'BGP=0xFC (色0=白、色1〜3=黒) のとき' do
      before { mmu.write_u8(address: 0xFF47, value: 0xFC) }

      it '0xFC を返す' do
        is_expected.to eq 0xFC
      end
    end

    context 'BGP=0xE4 (恒等パレット 0b11_10_01_00) のとき' do
      before { mmu.write_u8(address: 0xFF47, value: 0xE4) }

      it '0xE4 を返す' do
        is_expected.to eq 0xE4
      end
    end
  end
end
