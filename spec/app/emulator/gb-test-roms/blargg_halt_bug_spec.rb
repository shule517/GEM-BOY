require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg halt_bug.gb テスト ROM のシナリオ
#
# https://github.com/retrio/gb-test-roms の halt_bug.gb を skip_boot で起動して、
# DMG 実機固有の HALT バグ(IME=0 で IF & IE が 0 でないときに HALT を実行すると
# 直後の命令の opcode を 1バイト読み取って PC が進まない)を再現できているかを検証する。
# シリアル出力 (0xFF01/0xFF02) に "Passed\n" または "Failed #XX\n" が出る。
#
# halt_bug.gb は 32KB で MBC を使わないので現状の実装で動かせる。
RSpec.describe 'Blargg halt_bug 完走 (シリアルに "Passed" が出るまで)' do
  context 'halt_bug.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/halt_bug.gb', __FILE__)).bytes }

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
