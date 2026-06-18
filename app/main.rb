require 'app/core_ext/blank.rb'
require 'app/core_ext/last.rb'
require 'app/emulator/cartridge.rb'
require 'app/emulator/mmu.rb'
require 'app/emulator/cpu.rb'
require 'app/emulator/ppu.rb'

ROM_PATH = 'data/gb-studio-sample.gb'
SKIP_BOOT = true # ブートROMをスキップして直接 PC=0x0100 から起動(D-1)
TRACE = true

# 1フレームのT-cycle数(154スキャンライン × 456 cycle = 70224)
CYCLES_PER_FRAME = 154 * 456

# CPU/PPUを交互に進める粒度。1000サイクル(=約2スキャンライン)ごとにLYを更新する
# 一度に70224サイクル進めるとVBlank待ちループ中にLYが進まず無限ループする
CYCLES_PER_CHUNK = 1000

# Game Boy 4階調をRGBに変換するパレット(DMG標準)
GB_PALETTE = [
  [232, 232, 232], # 色0: 白
  [160, 160, 160], # 色1: ライトグレー
  [88,  88,  88],  # 色2: ダークグレー
  [16,  16,  16],  # 色3: 黒
]

# Game Boy画面の表示位置と拡大倍率(160×144 → 640×576)
SCREEN_SCALE = 4
SCREEN_X = 20
SCREEN_Y = 72

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]

  step_emulator(args) unless args.state.crashed

  render_framebuffer(args)
  render_header(args)
  render_serial(args)
  render_crash(args) if args.state.crashed
  debug_vram(args)

  if args.inputs.keyboard.key_down.space
    args.state.mmu.write_u8(address: MMU::SB, value: 'A'.ord)
    args.state.mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
  end
end

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  args.state.mmu = MMU.new(args.state.cartridge, skip_boot: SKIP_BOOT)
  args.state.cpu = CPU.new(args.state.mmu, skip_boot: SKIP_BOOT, trace: TRACE)
  args.state.ppu = PPU.new(args.state.mmu)
  args.state.crashed = false
  args.state.crash_message = nil
end

# 1フレーム分(70224 T-cycle)エミュレーションを進める
# CPUとPPUを小さな粒度で交互に進めることで、VBlank待ちループ等のLY依存処理が抜けられる
def step_emulator(args)
  total_cycles = 0
  while total_cycles < CYCLES_PER_FRAME
    cycles = args.state.cpu.run(CYCLES_PER_CHUNK)
    args.state.ppu.step(cycles)
    total_cycles += cycles
  end
rescue => error
  args.state.crashed = true
  args.state.crash_message = error.message
end

# PPUのframebuffer(160×144の色番号0..3)を画面に描画する
def render_framebuffer(args)
  framebuffer = args.state.ppu.framebuffer
  PPU::SCREEN_HEIGHT.times do |y|
    PPU::SCREEN_WIDTH.times do |x|
      color_id = framebuffer[y * PPU::SCREEN_WIDTH + x]
      r, g, b = GB_PALETTE[color_id]
      args.outputs.solids << {
        # Y軸反転: Game Boyは上が y=0、DragonRubyは下が y=0
        x: SCREEN_X + x * SCREEN_SCALE,
        y: SCREEN_Y + (PPU::SCREEN_HEIGHT - 1 - y) * SCREEN_SCALE,
        w: SCREEN_SCALE, h: SCREEN_SCALE,
        r: r, g: g, b: b,
      }
    end
  end
end

def render_header(args)
  cartridge = args.state.cartridge
  args.outputs.labels << { x: 700, y: 700, text: "GEM BOY", r: 255, g: 255, b: 255, size_enum: 2 }
  args.outputs.labels << { x: 700, y: 660, text: "ROM: #{File.basename(ROM_PATH)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 700, y: 630, text: "Title: #{cartridge.title}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 700, y: 600, text: "Size: #{cartridge.size} bytes", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 700, y: 570, text: "PC: 0x#{args.state.cpu.registers.pc.to_s(16).rjust(4, '0').upcase}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 700, y: 540, text: "LY: #{args.state.ppu.ly}", r: 200, g: 200, b: 200 }
end

def render_serial(args)
  args.outputs.labels << { x: 700, y: 480, text: "Serial Output:", r: 200, g: 200, b: 200 }

  buffer = args.state.mmu.serial_buffer
  buffer.split("\n").last(10).each_with_index do |line, i|
    args.outputs.labels << { x: 700, y: 450 - i * 22, text: line, r: 0, g: 255, b: 0, size_enum: -2 }
  end
end

def render_crash(args)
  args.outputs.labels << { x: 700, y: 200, text: "CRASHED:", r: 255, g: 50, b: 50, size_enum: 2 }
  args.outputs.labels << { x: 700, y: 170, text: args.state.crash_message, r: 255, g: 100, b: 100 }
end

# VRAM の中身をデバッグ出力(初回のみ実行)
# - タイルマップ(0x9800)の最初の20バイト = 画面1行目に配置されているタイル番号
# - タイルデータ(0x8000+)を ASCII の 'H' (0x48) と 'e' (0x65) のあたりで dump
def debug_vram(args)
  return if args.state.tick_count != 60 # 1秒(60tick)後に1回だけ
  return if args.state.crashed
  mmu = args.state.mmu

  puts ""
  puts "=== VRAM DEBUG ==="

  # タイルマップ全 18 行(画面の縦方向)を dump、各行に 20 タイル(画面横)
  # ASCII 値が見えるので、'Hello World!' の文字列が含まれている行が見つかる
  puts "Tile Map (0x9800-, 画面 18行 × 20タイル):"
  18.times do |row|
    bytes = (0..19).map { |col| format("%02X", mmu.read_u8(address: 0x9800 + row * 32 + col)) }
    # ASCII 表示も右に併記(0x20-0x7E のみ)
    ascii = (0..19).map do |col|
      v = mmu.read_u8(address: 0x9800 + row * 32 + col)
      (0x20..0x7E).include?(v) ? v.chr : '.'
    end.join
    puts "  Row #{format('%2d', row)}: #{bytes.join(' ')}  | #{ascii}"
  end

  puts ""
  puts "Tile Data 0x8480 ('H' = tile 0x48):"
  tile_h = (0..15).map { |i| format("%02X", mmu.read_u8(address: 0x8480 + i)) }
  puts "  " + tile_h.join(' ')

  puts ""
  puts "Tile Data 0x8200 ('SPACE' = tile 0x20):"
  tile_space = (0..15).map { |i| format("%02X", mmu.read_u8(address: 0x8200 + i)) }
  puts "  " + tile_space.join(' ')

  puts ""
  puts "LCDC: 0x#{format('%02X', mmu.read_u8(address: 0xFF40))}"
  puts "BGP:  0x#{format('%02X', mmu.read_u8(address: 0xFF47))}"
  puts "SCY:  0x#{format('%02X', mmu.read_u8(address: 0xFF42))}"
  puts "SCX:  0x#{format('%02X', mmu.read_u8(address: 0xFF43))}"

  # framebuffer の Y=64..71(タイルマップ Row 8 = "Hello 8-bit world!" の領域)を視覚化
  # 期待される値: 0=白(背景), 3=黒(文字), 1=ライトグレー, 2=ダークグレー
  puts ""
  puts "Framebuffer Y=64..71 (Hello 8-bit world! 行):"
  fb = args.state.ppu.framebuffer
  (64..71).each do |y|
    row = (0..159).map { |x| fb[y * 160 + x] }
    # 0(白)=「.」、3(黒)=「█」、1/2(灰)=「▓」で描画
    visual = row.map { |c| c == 0 ? '.' : c == 3 ? '█' : '▓' }.join
    puts "  Y=#{format('%3d', y)}: #{visual}"
  end

  # 現在の MMU 状態で LY=65, X=0..30 を「手で」レンダリングして
  # 「期待される値」と「実際の framebuffer」を比較する
  puts ""
  puts "=== 手動トレース LY=65, X=0..30(現在のMMU状態で計算)==="
  ly_test = 65
  scy_v = mmu.read_u8(address: 0xFF42)
  scx_v = mmu.read_u8(address: 0xFF43)
  bgp_v = mmu.read_u8(address: 0xFF47)
  lcdc_v = mmu.read_u8(address: 0xFF40)
  bg_y = (scy_v + ly_test) & 0xFF
  tilemap_row = bg_y / 8
  pixel_y = bg_y % 8
  map_base = (lcdc_v & 0x08) != 0 ? 0x9C00 : 0x9800
  unsigned = (lcdc_v & 0x10) != 0
  puts "  scy=#{scy_v}, scx=#{scx_v}, bgp=0x#{format('%02X', bgp_v)}, lcdc=0x#{format('%02X', lcdc_v)}"
  puts "  bg_y=#{bg_y}, tilemap_row=#{tilemap_row}, pixel_y=#{pixel_y}, map_base=0x#{format('%04X', map_base)}, unsigned=#{unsigned}"
  (0..30).each do |sx|
    bg_x = (scx_v + sx) & 0xFF
    tilemap_col = bg_x / 8
    pixel_x = bg_x % 8
    tile_num = mmu.read_u8(address: map_base + tilemap_row * 32 + tilemap_col)
    if unsigned
      tile_addr = 0x8000 + tile_num * 16
    else
      signed = tile_num >= 0x80 ? tile_num - 256 : tile_num
      tile_addr = 0x9000 + signed * 16
    end
    byte_lo = mmu.read_u8(address: tile_addr + pixel_y * 2)
    byte_hi = mmu.read_u8(address: tile_addr + pixel_y * 2 + 1)
    bit = 7 - pixel_x
    color_id = (((byte_hi >> bit) & 1) << 1) | ((byte_lo >> bit) & 1)
    expected = (bgp_v >> (color_id * 2)) & 0b11
    actual = fb[ly_test * 160 + sx]
    mark = expected == actual ? '✓' : '✗'
    puts "  X=#{format('%2d', sx)}: tile=0x#{format('%02X', tile_num)} p_x=#{pixel_x} b_lo=0x#{format('%02X', byte_lo)} b_hi=0x#{format('%02X', byte_hi)} color_id=#{color_id} expected=#{expected} actual=#{actual} #{mark}"
  end
  puts "=================="
end
