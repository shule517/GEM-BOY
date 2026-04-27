class Cartridge
  def initialize(data)
    raise "Empty ROM data" if data.nil? || data.empty?
    @data = data
  end

  def read(address)
    @data[address] || 0xFF
  end

  # note: https://gbdev.io/pandocs/The_Cartridge_Header.html
  # 0134-0143 — Title
  def title
    @data[0x0134..0x0143].pack('C*').strip.delete("\x00")
  end

  def size
    @data.size
  end
end
