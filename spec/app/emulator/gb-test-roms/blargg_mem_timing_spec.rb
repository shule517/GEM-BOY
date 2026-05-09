require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg mem_timing 個別 ROM のシナリオ
#
# https://github.com/retrio/gb-test-roms の mem_timing/individual/ にある 3 個の ROM を
# 1 つずつ skip_boot で起動し、メモリアクセス命令(LD/INC/DEC 系)が正しいサイクル数で
# 読み出し・書き込み・read-modify-write を行っているかを検証する。
# シリアル出力 (0xFF01/0xFF02) に "Passed\n" または "Failed #XX\n" が出る。
#
# 個別 ROM は 32KB で MBC を使わないので現状の実装で動かせる。
RSpec.describe 'Blargg mem_timing 個別 ROM 完走 (シリアルに "Passed" が出るまで)' do
  context '01-read_timing.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/mem_timing/01-read_timing.gb', __FILE__)).bytes }

    it 'シリアル出力に "Passed" が含まれる' do
      elapsed = 0
      until mmu.serial_buffer.include?('Passed') || mmu.serial_buffer.include?('Failed') || elapsed >= 10_000_000
        cycles = cpu.run(1000)
        ppu.step(cycles)
        elapsed += cycles
      end

      expect(mmu.serial_buffer).to include 'Passed'
    end
  end

  context '02-write_timing.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/mem_timing/02-write_timing.gb', __FILE__)).bytes }

    it 'シリアル出力に "Passed" が含まれる' do
      elapsed = 0
      until mmu.serial_buffer.include?('Passed') || mmu.serial_buffer.include?('Failed') || elapsed >= 10_000_000
        cycles = cpu.run(1000)
        ppu.step(cycles)
        elapsed += cycles
      end

      expect(mmu.serial_buffer).to include 'Passed'
    end
  end

  context '03-modify_timing.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/mem_timing/03-modify_timing.gb', __FILE__)).bytes }

    it 'シリアル出力に "Passed" が含まれる' do
      elapsed = 0
      until mmu.serial_buffer.include?('Passed') || mmu.serial_buffer.include?('Failed') || elapsed >= 10_000_000
        cycles = cpu.run(1000)
        ppu.step(cycles)
        elapsed += cycles
      end

      expect(mmu.serial_buffer).to include 'Passed'
    end
  end
end
