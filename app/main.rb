require 'app/core_ext/blank.rb'
require 'app/core_ext/last.rb'
require 'app/emulator/cartridge.rb'
require 'app/emulator/mmu.rb'
require 'app/emulator/cpu.rb'
require 'app/emulator/ppu.rb'

ROM_PATH = 'data/tobu.gb'
SKIP_BOOT = true # ブートROMをスキップして直接 PC=0x0100 から起動(D-1)

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

  if args.inputs.keyboard.key_down.space
    args.state.mmu.write_u8(address: MMU::SB, value: 'A'.ord)
    args.state.mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
  end
end

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  args.state.mmu = MMU.new(args.state.cartridge, skip_boot: SKIP_BOOT)
  args.state.cpu = CPU.new(args.state.mmu, skip_boot: SKIP_BOOT, trace: true)
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
