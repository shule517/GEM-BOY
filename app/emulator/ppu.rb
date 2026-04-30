require 'app/emulator/bit'

# PPU (Picture Processing Unit) — Game Boyの画面描画チップ
# CPUの消費サイクルを受け取って時間を進め、LYとframebufferを更新する
# Pan Docs: https://gbdev.io/pandocs/Rendering.html
class PPU
  # I/Oレジスタのアドレス https://gbdev.io/pandocs/Hardware_Reg_List.html

  # LCD = 液晶ディスプレイ
  LCDC = 0xFF40 # LCD Control https://gbdev.io/pandocs/LCDC.html#ff40--lcdc-lcd-control
  STAT = 0xFF41 # LCD Status https://gbdev.io/pandocs/STAT.html#ff41--stat-lcd-status

  SCY  = 0xFF42 # ViewportのY座標(BGマップのどこを映すか) https://gbdev.io/pandocs/Scrolling.html#ff42ff43--scy-scx-background-viewport-y-position-x-position
  SCX  = 0xFF43 # ViewportのX座標(BGマップのどこを映すか)

  LY   = 0xFF44 # LCDの現在のY座標 https://gbdev.io/pandocs/STAT.html#ff44--ly-lcd-y-coordinate-read-only
  LYC  = 0xFF45 # LYCとLYを比較する(一致するとSTATに反映) https://gbdev.io/pandocs/STAT.html#ff45--lyc-ly-compare
  BGP  = 0xFF47 # BGパレット(色) https://gbdev.io/pandocs/Palettes.html#ff47--bgp-non-cgb-mode-only-bg-palette-data

  SCREEN_WIDTH  = 160 # 画面の横ピクセル数 https://gbdev.io/pandocs/Specifications.html#specifications
  SCREEN_HEIGHT = 144 # 画面の縦ピクセル数

  # 1スキャンラインに要するT-cycle数(Mode2: 80 + Mode3: 172 + Mode0: 204) https://gbdev.io/pandocs/Rendering.html#ppu-modes
  CYCLES_PER_SCANLINE = 456

  SCANLINES_PER_FRAME = 154 # 1フレームのスキャンライン数(描画144行 + VBlank10行) https://gbdev.io/pandocs/Rendering.html
  VBLANK_START_LY     = 144 # これ以上のY座標はVBlank(描画スキップ)

  attr_accessor :cycles, :ly, :framebuffer

  def initialize(mmu)
    @mmu = mmu
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(SCREEN_WIDTH * SCREEN_HEIGHT, 0)
  end

  # 引数のサイクル分 描画する
  def step(cycles)
    return unless lcd_enabled? # LCDが無効
    self.cycles += cycles

    # 1ライン描画分サイクルが溜まったら描画する
    while self.cycles >= CYCLES_PER_SCANLINE
      self.cycles -= CYCLES_PER_SCANLINE

      # 1ライン描画する
      if ly < VBLANK_START_LY # 描画範囲内
        render_scanline
      end

      # LYを+1
      self.ly = (ly + 1) % SCANLINES_PER_FRAME # はみ出たら、次フレームへ
      @mmu.write_io_direct(LY, ly)
    end
  end

  private

  # LCDが有効か https://gbdev.io/pandocs/LCDC.html#lcdc7--lcd-enable
  def lcd_enabled?
    Bit.bit_at(@mmu.read_u8(address: LCDC), 7) == 1 # LCDC bit7 = LCD Enable
  end

  # BGが有効か https://gbdev.io/pandocs/LCDC.html#lcdc0--bg-and-window-enablepriority
  def bg_enabled?
    Bit.bit_at(@mmu.read_u8(address: LCDC), 0) == 1 # LCDC bit0 = BG/Window Enable
  end

  # BGタイルマップの先頭アドレス https://gbdev.io/pandocs/LCDC.html#lcdc3--bg-tile-map-area
  def bg_tile_map_address
    Bit.bit_at(@mmu.read_u8(address: LCDC), 3) == 1 ? 0x9C00 : 0x9800 # LCDC bit3
  end

  # BGタイルデータがunsignedアドレッシングか https://gbdev.io/pandocs/LCDC.html#lcdc4--bg-and-window-tile-data-area
  def bg_tile_data_unsigned?
    Bit.bit_at(@mmu.read_u8(address: LCDC), 4) == 1 # LCDC bit4=1 で unsigned(0x8000基点)、0 で signed(0x9000基点)
  end

  # 1スキャンライン分(160ピクセル)をframebufferに書き込む(C-2: BGタイル描画)
  # https://gbdev.io/pandocs/Tile_Maps.html / https://gbdev.io/pandocs/Tile_Data.html
  def render_scanline
    return unless bg_enabled? # BGが無効

    scy = @mmu.read_u8(address: SCY) # ViewportのY座標
    scx = @mmu.read_u8(address: SCX) # ViewportのX座標
    bgp = @mmu.read_u8(address: BGP) # BGパレット(色)

    bg_y = Bit.wrap_u8(scy + ly) # スクロール込みのBG上のY座標
    tilemap_row = bg_y / 8       # タイルマップ上の行番号(0..31)
    pixel_y = bg_y % 8           # タイル内のY座標(0..7)

    tile_map_address = bg_tile_map_address
    tile_data_unsigned = bg_tile_data_unsigned?

    SCREEN_WIDTH.times do |screen_x|
      bg_x = Bit.wrap_u8(scx + screen_x) # スクロール込みのBG上のX座標
      tilemap_col = bg_x / 8             # タイルマップ上の列番号(0..31)
      pixel_x = bg_x % 8                 # タイル内のX座標(0..7)

      tile_number   = @mmu.read_u8(address: tile_map_address + tilemap_row * 32 + tilemap_col) # マップから絵柄番号を取得
      tile_address  = tile_data_address(tile_number, tile_data_unsigned)                       # 絵柄データのVRAMアドレス
      color_id      = pixel_color_id(tile_address, pixel_x, pixel_y)                           # 1ピクセルの色番号(0..3)を2bppデコード
      palette_color = (bgp >> (color_id * 2)) & 0b11                                           # BGPで色番号を画面明度(0..3)に変換

      @framebuffer[ly * SCREEN_WIDTH + screen_x] = palette_color

      # DEBUG: LY=65 で書いた値を直後にverifyする(計算は正しいか? 実際に書けたか?)
      if @ly == 65 && @debug_verify_count.to_i < 1
        if screen_x < 30
          @debug_log_buffer ||= []
          @debug_log_buffer << "  X=#{format('%3d', screen_x)}: tile_num=0x#{format('%02X', tile_number)}, p_x=#{pixel_x}, p_y=#{pixel_y}, color_id=#{color_id}, palette=#{palette_color}, fb[#{ly * SCREEN_WIDTH + screen_x}]=#{@framebuffer[ly * SCREEN_WIDTH + screen_x]}"
        end
        if screen_x == 159
          @debug_verify_count = 1
          puts ""
          puts "=== render_scanline 内部トレース (LY=65 の最初の30ピクセル) ==="
          @debug_log_buffer.each { |line| puts line }
          puts ""
          puts "=== 直後の framebuffer Y=65 全体 ==="
          fb_row = (0..159).map { |x| @framebuffer[@ly * SCREEN_WIDTH + x] }
          visual = fb_row.map { |c| c == 0 ? '.' : c == 3 ? '█' : '▓' }.join
          puts "  Y=65 (直後): #{visual}"
          puts "==============================================="
        end
      end
    end
  end

  # タイル番号 → タイルデータの先頭アドレス(VRAM内) https://gbdev.io/pandocs/Tile_Data.html
  def tile_data_address(tile_number, tile_data_unsigned)
    if tile_data_unsigned
      # 0x8000..0x8FF0
      0x8000 + tile_number * 16
    else
      # 0x8800..0x97F0
      0x9000 + Bit.u8_to_i8(tile_number) * 16
    end
  end

  # タイル内の1ピクセルの色番号(0..3)を取り出す
  # Game Boyの2bppは「ビットプレーン分離」:1行8ピクセル分の色番号を2バイトに分けて格納する https://gbdev.io/pandocs/Tile_Data.html
  def pixel_color_id(tile_address, pixel_x, pixel_y)
    byte_lo = @mmu.read_u8(address: tile_address + pixel_y * 2)     # 8ピクセル分の色番号bit0(LSB)を並べたバイト
    byte_hi = @mmu.read_u8(address: tile_address + pixel_y * 2 + 1) # 8ピクセル分の色番号bit1(MSB)を並べたバイト
    bit = 7 - pixel_x                                               # 左端ピクセル(x=0)がbit7、右端(x=7)がbit0
    (Bit.bit_at(byte_hi, bit) << 1) | Bit.bit_at(byte_lo, bit)      # MSBとLSBを組み合わせて0..3の色番号
  end
end
