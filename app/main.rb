require 'app/core_ext/blank.rb'
require 'app/emulator/cartridge.rb'

ROM_PATH = 'data/tobu.gb'

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]

  cartridge = args.state.cartridge
  args.outputs.labels << { x: 20, y: 700, text: "GEM BOY", r: 255, g: 255, b: 255, size_enum: 2 }
  args.outputs.labels << { x: 20, y: 660, text: "ROM: #{File.basename(ROM_PATH)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 630, text: "Title: #{cartridge.title}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 600, text: "Size: #{cartridge.size} bytes", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 570, text: "ROM[0x0100]: 0x#{cartridge.read(0x0100).to_s(16)}", r: 200, g: 200, b: 200 }
end

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
end
