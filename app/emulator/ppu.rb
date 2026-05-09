require 'app/emulator/bit'
require 'app/emulator/lcd_registers'

# PPU (Picture Processing Unit) — Game Boyの画面描画チップ
# CPUの消費サイクルを受け取って時間を進め、LYとframebufferを更新する
# Pan Docs: https://gbdev.io/pandocs/Rendering.html
class PPU
  # I/Oレジスタのアドレス https://gbdev.io/pandocs/Hardware_Reg_List.html

  STAT = 0xFF41 # LCD Status https://gbdev.io/pandocs/STAT.html#ff41--stat-lcd-status
  LY   = 0xFF44 # LCDの現在のY座標 https://gbdev.io/pandocs/STAT.html#ff44--ly-lcd-y-coordinate-read-only
  LYC  = 0xFF45 # LYCとLYを比較する(一致するとSTATに反映) https://gbdev.io/pandocs/STAT.html#ff45--lyc-ly-compare

  SCREEN_WIDTH  = 160 # 画面の横ピクセル数 https://gbdev.io/pandocs/Specifications.html#specifications
  SCREEN_HEIGHT = 144 # 画面の縦ピクセル数

  # 1スキャンラインに要するT-cycle数(Mode2: 80 + Mode3: 172 + Mode0: 204) https://gbdev.io/pandocs/Rendering.html#ppu-modes
  CYCLES_PER_SCANLINE = 456

  SCANLINES_PER_FRAME = 154 # 1フレームのスキャンライン数(描画144行 + VBlank10行) https://gbdev.io/pandocs/Rendering.html
  VBLANK_START_LY     = 144 # これ以上のY座標はVBlank(描画スキップ)

  attr_accessor :cycles, :ly, :framebuffer
  attr_reader :lcd_registers

  def initialize(mmu)
    @mmu = mmu
    @lcd_registers = LcdRegisters.new(mmu)
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(SCREEN_WIDTH * SCREEN_HEIGHT, 0)
  end

  # 引数のサイクル分 描画する
  def step(cycles)
    return unless lcd_registers.lcd_enabled? # LCDが無効
    self.cycles += cycles

    # 1ライン描画分サイクルが溜まったら描画する
    while self.cycles >= CYCLES_PER_SCANLINE
      self.cycles -= CYCLES_PER_SCANLINE

      # 1ライン描画する
      if ly < VBLANK_START_LY # 描画範囲内
        render_scanline
      end
      if ly == VBLANK_START_LY # VBlankに入った瞬間
        @mmu.write_io_direct(address: MMU::IF, value: Bit.set_bit(@mmu.read_u8(address: MMU::IF), 0, 1))
      end

      # LYを+1
      self.ly = (ly + 1) % SCANLINES_PER_FRAME # はみ出たら、次フレームへ
      @mmu.write_io_direct(address: LY, value: ly)
    end
  end

  private

  # 1スキャンライン分(160ピクセル)をframebufferに書き込む(C-2: BGタイル描画)
  # https://gbdev.io/pandocs/Tile_Maps.html / https://gbdev.io/pandocs/Tile_Data.html
  def render_scanline
    return unless lcd_registers.bg_enabled? # BGが無効

    scy = lcd_registers.scy # ViewportのY座標
    scx = lcd_registers.scx # ViewportのX座標
    bgp = lcd_registers.bgp # BGパレット(色)

    bg_y = Bit.wrap_u8(scy + ly)  # スクロール込みのBG上のY座標
    tilemap_row = (bg_y / 8).to_i # タイルマップ上の行番号(0..31)
    pixel_y = bg_y % 8            # タイル内のY座標(0..7)

    tile_map_address = lcd_registers.bg_tile_map_address
    tile_data_unsigned = lcd_registers.bg_tile_data_unsigned?

    SCREEN_WIDTH.times do |screen_x|
      bg_x = Bit.wrap_u8(scx + screen_x) # スクロール込みのBG上のX座標
      tilemap_col = (bg_x / 8).to_i      # タイルマップ上の列番号(0..31)
      pixel_x = bg_x % 8                 # タイル内のX座標(0..7)

      tile_number   = @mmu.read_u8(address: tile_map_address + tilemap_row * 32 + tilemap_col) # マップから絵柄番号を取得
      tile_address  = tile_data_address(tile_number, tile_data_unsigned)                       # 絵柄データのVRAMアドレス
      color_id      = pixel_color_id(tile_address, pixel_x, pixel_y)                           # 1ピクセルの色番号(0..3)を2bppデコード
      palette_color = (bgp >> (color_id * 2)) & 0b11                                           # BGPで色番号を画面明度(0..3)に変換

      @framebuffer[ly * SCREEN_WIDTH + screen_x] = palette_color
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
