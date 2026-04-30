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

  describe '#step(456) による BG タイル描画(C-2)' do
    # render_scanline は private なので、step(456) を介して間接的にテストする。
    # LY=0 の 1 ライン分(160 ピクセル)が framebuffer の先頭 160 要素に書かれる。
    let(:ppu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    # 共通セットアップ:LCD ON、BG ON、unsigned アドレッシング、BG タイルマップ 0x9800
    # LCDC = 0b1001_0001 = 0x91 (bit7=LCD ON, bit4=unsigned, bit0=BG ON)
    before do
      mmu.write(address: 0xFF40, value: 0x91)
    end

    context 'BG が無効(LCDC bit0=0)のとき' do
      before do
        mmu.write(address: 0xFF40, value: 0x90) # LCD ON だが BG OFF
        # framebuffer に既存値を入れて、render が走らないことを確認
        ppu.framebuffer.fill(0xAA)
      end

      it 'framebuffer は変更されない' do
        ppu.step(456)
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 0xAA }).to eq true
      end
    end

    context 'タイル 0 を全色 3(黒)で塗りつぶしたとき' do
      # 1 タイル 16 バイトの 2bpp フォーマット:
      #   各行 2 バイトの両方を 0xFF にすると、その行の 8 ピクセルすべてが
      #   color_id = (1 << 1) | 1 = 3(最も濃い色)になる
      before do
        16.times { |i| mmu.write(address: 0x8000 + i, value: 0xFF) } # タイル 0 全画素を色 3
        # タイルマップの 1 行目を全部タイル 0 にする(20 タイル分で画面横が埋まる)
        20.times { |col| mmu.write(address: 0x9800 + col, value: 0x00) }
        # BGP: 色番号 3 → 0b11(明度 3、黒)
        mmu.write(address: 0xFF47, value: 0xFC) # 0b11_11_11_00 = 色 0→白、色 1〜3 → 黒
      end

      it 'LY=0 の 160 ピクセルがすべて明度 3(黒)になる' do
        ppu.step(456) # LY=0 を描画してから LY=1 へ
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 3 }).to eq true
      end
    end

    context 'タイル 0 を全色 0(白)で塗りつぶしたとき' do
      # タイルデータが全部 0 → 全ピクセル color_id = 0
      before do
        # VRAM はデフォルトで 0 なのでタイル 0 / マップ 0 は色 0 になる
        # BGP: 色番号 0 → 0b00(明度 0、白)
        mmu.write(address: 0xFF47, value: 0xFC) # 色 0 → 白
      end

      it 'LY=0 の 160 ピクセルがすべて明度 0(白)になる' do
        ppu.step(456)
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 0 }).to eq true
      end
    end

    context 'パレット(BGP)を反転したとき' do
      # タイルデータは色 3 だが、BGP で色 3 を明度 0(白)にマップする
      before do
        16.times { |i| mmu.write(address: 0x8000 + i, value: 0xFF) } # 全画素 color_id=3
        20.times { |col| mmu.write(address: 0x9800 + col, value: 0x00) }
        # BGP: 色番号 3 → 0b00(白)、色番号 0 → 0b11(黒)に反転
        mmu.write(address: 0xFF47, value: 0b00_01_10_11)
      end

      it 'LY=0 の 160 ピクセルが明度 0(白)になる(色番号 3 → 明度 0)' do
        ppu.step(456)
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 0 }).to eq true
      end
    end

    context '左端ピクセルが色 1、右端ピクセルが色 2 のタイルのとき' do
      # 2bpp デコードのビット順序確認(左端 = bit7、右端 = bit0)
      # byte_lo = 0b10000000 = 0x80 → 左端 bit=1、右端 bit=0
      # byte_hi = 0b00000001 = 0x01 → 左端 bit=0、右端 bit=1
      # 結果:
      #   ピクセル 0(左端、bit7): hi=0, lo=1 → color_id = 0b01 = 1
      #   ピクセル 7(右端、bit0): hi=1, lo=0 → color_id = 0b10 = 2
      before do
        mmu.write(address: 0x8000, value: 0x80)     # 1 行目 byte_lo
        mmu.write(address: 0x8001, value: 0x01)     # 1 行目 byte_hi
        mmu.write(address: 0x9800, value: 0x00)     # マップ位置 (0,0) にタイル 0
        # BGP: 恒等パレット(色番号 = 明度)
        mmu.write(address: 0xFF47, value: 0b11_10_01_00)
      end

      it '左端ピクセルが明度 1、8 番目のピクセル(タイル 0 の右端)が明度 2' do
        ppu.step(456)
        expect(ppu.framebuffer[0]).to eq 1 # 左端
        expect(ppu.framebuffer[7]).to eq 2 # タイル 0 の右端
      end
    end

    context 'LCDC bit3=1(タイルマップ 0x9C00)を指定したとき' do
      # 通常のタイルマップ(0x9800)ではなく、もう一方(0x9C00)を使う
      before do
        mmu.write(address: 0xFF40, value: 0x99) # 0b1001_1001(bit3=1)
        16.times { |i| mmu.write(address: 0x8000 + i, value: 0xFF) }
        # 0x9800 側にはタイル 0 を置かない(マップが切り替わったか確認用)
        20.times { |col| mmu.write(address: 0x9C00 + col, value: 0x00) }
        mmu.write(address: 0xFF47, value: 0xFC)
      end

      it '0x9C00 のマップが参照されて画素が描画される' do
        ppu.step(456)
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 3 }).to eq true
      end
    end

    context 'LCDC bit4=0(signed アドレッシング)で tile_num=0xFF を参照したとき' do
      # signed mode: tile_num=0xFF → -1 → 0x9000 + (-1) * 16 = 0x8FF0 を参照
      before do
        mmu.write(address: 0xFF40, value: 0x81) # 0b1000_0001(bit4=0, bit0=BG ON, bit7=LCD ON)
        # タイルデータを 0x8FF0 に置く(signed の tile_num=-1 が指す場所)
        16.times { |i| mmu.write(address: 0x8FF0 + i, value: 0xFF) }
        # マップに tile_num=0xFF を書く
        20.times { |col| mmu.write(address: 0x9800 + col, value: 0xFF) }
        mmu.write(address: 0xFF47, value: 0xFC)
      end

      it 'signed アドレッシングで 0x8FF0 のタイルが描画される' do
        ppu.step(456)
        expect(ppu.framebuffer[0...160].all? { |pixel| pixel == 3 }).to eq true
      end
    end
  end
end
