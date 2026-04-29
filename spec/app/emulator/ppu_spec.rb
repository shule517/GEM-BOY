require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/ppu'

RSpec.describe PPU do
  describe '#initialize' do
    subject { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    it 'LY=0、framebuffer は SCREEN_WIDTH * SCREEN_HEIGHT サイズの 0 配列' do
      ppu = subject
      expect(ppu.ly).to eq 0
      expect(ppu.framebuffer.size).to eq 160 * 144
      expect(ppu.framebuffer.all? { |pixel| pixel == 0 }).to eq true
    end
  end

  describe '#step' do
    subject { ppu.step(cycles) }
    let(:ppu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'LCD が OFF (LCDC bit7=0) のとき' do
      # ROM が VRAM クリア中などで LCD を消している間は LY 進行を止める。
      before { mmu.write(address: 0xFF40, value: 0x00) } # LCDC bit7=0
      let(:cycles) { 1000 }

      it 'LY は 0 のまま、LY レジスタも 0' do
        subject
        expect(ppu.ly).to eq 0
        expect(mmu.read(address: 0xFF44)).to eq 0
      end
    end

    context 'LCD が ON (LCDC bit7=1) のとき' do
      before { mmu.write(address: 0xFF40, value: 0x80) } # LCDC bit7=1

      context '455 サイクル進めたとき(1 ライン未満)' do
        let(:cycles) { 455 }

        it 'LY は 0 のまま(まだ 456 に達していない)' do
          subject
          expect(ppu.ly).to eq 0
          expect(mmu.read(address: 0xFF44)).to eq 0
        end
      end

      context '456 サイクル進めたとき(ちょうど 1 ライン)' do
        let(:cycles) { 456 }

        it 'LY=1 になり、MMU の 0xFF44 にも反映される' do
          subject
          expect(ppu.ly).to eq 1
          expect(mmu.read(address: 0xFF44)).to eq 1
        end
      end

      context '456 * 144 サイクル進めたとき(VBlank 開始ライン)' do
        # hello.gb の VBlank 待ちループ(CP 0x90, JR NZ)が抜けるタイミング
        let(:cycles) { 456 * 144 }

        it 'LY=144 になる(VBlank 開始)' do
          subject
          expect(ppu.ly).to eq 144
          expect(mmu.read(address: 0xFF44)).to eq 144
        end
      end

      context '456 * 154 サイクル進めたとき(1 フレーム完了)' do
        # 1 フレーム = 70224 T-cycle = 154 ライン × 456 cycle
        let(:cycles) { 456 * 154 }

        it 'LY は 0 にラップする(次フレーム開始)' do
          subject
          expect(ppu.ly).to eq 0
          expect(mmu.read(address: 0xFF44)).to eq 0
        end
      end

      context '小さなサイクルを複数回呼んだとき' do
        # CPU の各命令(4〜20 サイクル)の積み重ねを再現
        before do
          mmu.write(address: 0xFF40, value: 0x80)
          228.times { ppu.step(2) } # 228 * 2 = 456
        end

        it '累積 456 サイクルで LY=1 になる' do
          expect(ppu.ly).to eq 1
        end
      end
    end
  end
end
