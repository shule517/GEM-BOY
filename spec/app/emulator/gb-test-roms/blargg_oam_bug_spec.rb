require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg oam_bug 個別 ROM のシナリオ
#
# https://github.com/retrio/gb-test-roms の oam_bug/rom_singles/ にある 8 個の ROM を
# 1 つずつ skip_boot で起動し、DMG 実機固有の OAM 破壊バグ
# (INC/DEC rr 等が OAM 域 0xFE00-0xFE9F を指す瞬間に走ると OAM が壊れる)を
# 正しく再現できているかを検証する。
# シリアル出力 (0xFF01/0xFF02) に "Passed\n" または "Failed #XX\n" が出る。
#
# 個別 ROM は 32KB で MBC を使わないので現状の実装で動かせる。
# 実機ゲームの大半は意図的にこの状態を踏まないので、対応の優先度は低い。
RSpec.describe 'Blargg oam_bug 個別 ROM 完走 (シリアルに "Passed" が出るまで)' do
  context '1-lcd_sync.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/1-lcd_sync.gb', __FILE__)).bytes }

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

  context '2-causes.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/2-causes.gb', __FILE__)).bytes }

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

  context '3-non_causes.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/3-non_causes.gb', __FILE__)).bytes }

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

  context '4-scanline_timing.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/4-scanline_timing.gb', __FILE__)).bytes }

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

  context '5-timing_bug.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/5-timing_bug.gb', __FILE__)).bytes }

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

  context '6-timing_no_bug.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/6-timing_no_bug.gb', __FILE__)).bytes }

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

  context '7-timing_effect.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/7-timing_effect.gb', __FILE__)).bytes }

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

  context '8-instr_effect.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/oam_bug/8-instr_effect.gb', __FILE__)).bytes }

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
