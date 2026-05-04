require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg cpu_instrs テスト ROM (個別版) のシナリオ
#
# https://github.com/retrio/gb-test-roms の cpu_instrs/individual/ にある 11 個の ROM を
# 1 つずつ skip_boot で起動し、シリアル出力 (0xFF01/0xFF02) に Blargg が吐く
# "Passed\n" または "Failed #XX\n" を mmu.serial_buffer で観測する。
#
# 個別 ROM (32KB) は MBC を使わないので現状の実装で動かせる(cpu_instrs.gb 一体版は MBC1 が必要)。
# CLAUDE.md の方針どおり「ロゴが崩れる等の症状ごとに使う診断ツール」として全 11 個を並べておく。
# 未実装命令で例外停止する ROM はそこで失敗するので、次に何を実装すれば進めるかが
# 失敗メッセージから一目で分かる。
RSpec.describe 'Blargg cpu_instrs 個別 ROM 完走 (シリアルに "Passed" が出るまで)' do
  context '01-special.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/01-special.gb', __FILE__)).bytes }

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

  context '02-interrupts.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/02-interrupts.gb', __FILE__)).bytes }

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

  context '03-op sp,hl.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/03-op sp,hl.gb', __FILE__)).bytes }

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

  context '04-op r,imm.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/04-op r,imm.gb', __FILE__)).bytes }

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

  context '05-op rp.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/05-op rp.gb', __FILE__)).bytes }

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

  context '06-ld r,r.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/06-ld r,r.gb', __FILE__)).bytes }

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

  context '07-jr,jp,call,ret,rst.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/07-jr,jp,call,ret,rst.gb', __FILE__)).bytes }

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

  context '08-misc instrs.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/08-misc instrs.gb', __FILE__)).bytes }

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

  context '09-op r,r.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/09-op r,r.gb', __FILE__)).bytes }

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

  context '10-bit ops.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/10-bit ops.gb', __FILE__)).bytes }

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

  context '11-op a,(hl).gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/cpu_instrs/11-op a,(hl).gb', __FILE__)).bytes }

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
