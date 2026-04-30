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

  SCREEN_WIDTH_PIXEL  = 160 # 画面の横ピクセル数 https://gbdev.io/pandocs/Specifications.html#specifications
  SCREEN_HEIGHT_PIXEL = 144 # 画面の縦ピクセル数

  # 1スキャンラインに要するT-cycle数(Mode2: 80 + Mode3: 172 + Mode0: 204) https://gbdev.io/pandocs/Rendering.html#ppu-modes
  CYCLES_PER_SCANLINE = 456

  SCANLINES_PER_FRAME = 154 # 1フレームのスキャンライン数(描画144行 + VBlank10行) https://gbdev.io/pandocs/Rendering.html
  VBLANK_START_LY     = 144 # これ以上のY座標はVBlank(描画スキップ)

  attr_reader :framebuffer, :ly

  def initialize(mmu)
    @mmu = mmu
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(SCREEN_WIDTH_PIXEL * SCREEN_HEIGHT_PIXEL, 0)
  end

  # 引数のサイクルだけ処理を実行する
  # 456サイクル経過するごとに1ライン描画 + LYを+1、154でラップ
  def step(cycles)
    return unless lcd_enabled? # LCDが無効

    @cycles += cycles
    while @cycles >= CYCLES_PER_SCANLINE
      @cycles -= CYCLES_PER_SCANLINE

      if @ly < VBLANK_START_LY # 描画範囲内
        render_scanline
      end

      @ly = (@ly + 1) % SCANLINES_PER_FRAME # 154で0にラップ(次フレーム)
      @mmu.write_io_direct(LY, @ly)         # LYを更新
    end
  end

  private

  # LCDが有効か https://gbdev.io/pandocs/LCDC.html#lcdc7--lcd-enable
  def lcd_enabled?
    @mmu.read(address: LCDC)[7] == 1 # LCDC bit7 = LCD Enable
  end

  # BGが有効か https://gbdev.io/pandocs/LCDC.html#lcdc0--bg-and-window-enablepriority
  def bg_enabled?
    @mmu.read(address: LCDC)[0] == 1 # LCDC bit0 = BG/Window Enable
  end

  # 1スキャンライン分(160ピクセル)をframebufferに書き込む(C-2: BGタイル描画)
  # Pan Docs: https://gbdev.io/pandocs/Tile_Maps.html / https://gbdev.io/pandocs/Tile_Data.html
  def render_scanline
    return unless bg_enabled? # BGが無効

    scy  = @mmu.read(address: SCY)  # ViewportのY座標
    scx  = @mmu.read(address: SCX)  # ViewportのX座標
    bgp  = @mmu.read(address: BGP)  # BGパレット(色)
    lcdc = @mmu.read(address: LCDC) # LCD Control

    bg_y = (@ly + scy) & 0xFF # スクロール込みのBG上のY座標(8bitラップ)
    tile_row = bg_y / 8       # タイルマップ上の行番号(0..31)
    pixel_y = bg_y % 8        # タイル内のY座標(0..7)

    map_base = (lcdc & 0x08) != 0 ? 0x9C00 : 0x9800 # LCDC bit3でタイルマップを切替
    unsigned_addressing = (lcdc & 0x10) != 0        # LCDC bit4: 1=unsigned(0x8000基点), 0=signed(0x9000基点)

    SCREEN_WIDTH_PIXEL.times do |x|
      bg_x = (scx + x) & 0xFF       # スクロール込みのBG上のX座標(8bitラップ)
      tile_col = bg_x / 8           # タイルマップ上の列番号(0..31)
      pixel_x = bg_x % 8            # タイル内のX座標(0..7)

      tile_num = @mmu.read(address: map_base + tile_row * 32 + tile_col)  # マップから絵柄番号を取得
      tile_addr = tile_data_address(tile_num, unsigned_addressing)         # 絵柄データのVRAMアドレス
      color_id = pixel_color(tile_addr, pixel_x, pixel_y)                  # 1ピクセルの色番号(0..3)を2bppデコード
      actual_color = (bgp >> (color_id * 2)) & 0b11                        # BGPで色番号を画面明度(0..3)に変換

      @framebuffer[@ly * SCREEN_WIDTH_PIXEL + x] = actual_color
    end
  end

  # タイル番号 → タイルデータの先頭アドレス(VRAM内) https://gbdev.io/pandocs/Tile_Data.html
  def tile_data_address(tile_num, unsigned_addressing)
    if unsigned_addressing
      0x8000 + tile_num * 16                                  # tile_num=0..255 → 0x8000..0x8FF0
    else
      signed = tile_num >= 0x80 ? tile_num - 256 : tile_num   # 0x80..0xFFを-128..-1として再解釈
      0x9000 + signed * 16                                    # signed=-128..127 → 0x8800..0x97F0
    end
  end

  # タイル内の1ピクセルの色番号(0..3)を2bppデコードで取り出す https://gbdev.io/pandocs/Tile_Data.html
  def pixel_color(tile_addr, pixel_x, pixel_y)
    byte_lo = @mmu.read(address: tile_addr + pixel_y * 2)      # その行の各ピクセルのbit0(LSB)を並べたバイト
    byte_hi = @mmu.read(address: tile_addr + pixel_y * 2 + 1)  # その行の各ピクセルのbit1(MSB)を並べたバイト
    bit = 7 - pixel_x                                           # 左端ピクセル(x=0)= bit7、右端(x=7)= bit0
    ((byte_hi >> bit) & 1) << 1 | ((byte_lo >> bit) & 1)        # MSBとLSBを組み合わせて0..3の色番号
  end
end
