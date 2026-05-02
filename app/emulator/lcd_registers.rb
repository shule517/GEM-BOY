require 'app/emulator/bit'

# LCD I/O レジスタの読み出しとビットデコードをまとめる
#
# Pan Docs: https://gbdev.io/pandocs/Hardware_Reg_List.html
#
# === 担当する I/O レジスタ ===
#
#   0xFF40  LCDC      LCD Control(画面 ON/OFF、BG タイルマップ位置などを 1 バイトに詰めた制御レジスタ)
#                     https://gbdev.io/pandocs/LCDC.html
#   0xFF42  SCY       BG ビューポートの Y座標(BG マップのどこを映すか)
#                     https://gbdev.io/pandocs/Scrolling.html
#   0xFF43  SCX       BG ビューポートの X座標
#                     https://gbdev.io/pandocs/Scrolling.html
#   0xFF47  BGP       BG パレット(色番号 0..3 → 明度 0..3 の対応)
#                     https://gbdev.io/pandocs/Palettes.html
class LcdRegisters
  LCDC = 0xFF40 # LCD Control https://gbdev.io/pandocs/LCDC.html#ff40--lcdc-lcd-control
  SCY  = 0xFF42 # ViewportのY座標 https://gbdev.io/pandocs/Scrolling.html#ff42ff43--scy-scx-background-viewport-y-position-x-position
  SCX  = 0xFF43 # ViewportのX座標
  BGP  = 0xFF47 # BGパレット(色) https://gbdev.io/pandocs/Palettes.html#ff47--bgp-non-cgb-mode-only-bg-palette-data

  def initialize(mmu)
    @mmu = mmu
  end

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

  # ViewportのY座標を 0xFF42 から読む
  def scy = @mmu.read_u8(address: SCY)

  # ViewportのX座標を 0xFF43 から読む
  def scx = @mmu.read_u8(address: SCX)

  # BGパレットを 0xFF47 から読む
  def bgp = @mmu.read_u8(address: BGP)
end
