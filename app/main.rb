require 'app/core_ext/blank.rb'
require 'app/core_ext/last.rb'
require 'app/emulator/cartridge.rb'
require 'app/emulator/mmu.rb'
require 'app/emulator/cpu.rb'

ROM_PATH = 'data/tobu.gb'

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]

  render_header(args)
  render_serial(args)

  if args.inputs.keyboard.key_down.space
    args.state.mmu.write_u8(address: MMU::SB, value: 'A'.ord)
    args.state.mmu.write_u8(address: MMU::SC, value: MMU::SC_TRANSFER_START)
  end
end

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  args.state.mmu = MMU.new(args.state.cartridge)
end

def render_header(args)
  cartridge = args.state.cartridge
  args.outputs.labels << { x: 20, y: 700, text: "GEM BOY", r: 255, g: 255, b: 255, size_enum: 2 }
  args.outputs.labels << { x: 20, y: 660, text: "ROM: #{File.basename(ROM_PATH)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 630, text: "Title: #{cartridge.title}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 600, text: "Size: #{cartridge.size} bytes", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 570, text: "ROM[0x0100]: 0x#{cartridge.read(0x0100).to_s(16)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 540, text: "Press SPACE to test serial", r: 150, g: 150, b: 150 }
end

def render_serial(args)
  args.outputs.labels << { x: 700, y: 700, text: "Serial Output:", r: 200, g: 200, b: 200 }

  buffer = args.state.mmu.serial_buffer
  buffer.split("\n").last(20).each_with_index do |line, i|
    args.outputs.labels << { x: 700, y: 670 - i * 22, text: line, r: 0, g: 255, b: 0, size_enum: -2 }
  end
end
