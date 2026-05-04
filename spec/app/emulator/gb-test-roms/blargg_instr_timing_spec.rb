require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg instr_timing.gb テスト ROM のシナリオ
#
# https://github.com/retrio/gb-test-roms の instr_timing/instr_timing.gb を skip_boot で起動して、
# 全 256 個の opcode が正しいサイクル数を返しているかを検証する。
# シリアル出力 (0xFF01/0xFF02) に "Passed\n" または "Failed #XX\n" が出る。
#
# instr_timing.gb は 32KB で MBC を使わないので現状の実装で動かせる。
# サイクル数のずれは PPU の LY 進みやタイミング依存命令(JR cc / CALL cc / RET cc 等)に影響するので
# このテストが通らない間は、tobu.gb のような実機 ROM で微妙な挙動の差が出る可能性がある。
RSpec.describe 'Blargg instr_timing 完走 (シリアルに "Passed" が出るまで)' do
  context 'instr_timing.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/instr_timing.gb', __FILE__)).bytes }

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
