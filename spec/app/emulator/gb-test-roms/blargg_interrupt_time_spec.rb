require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# Blargg interrupt_time.gb テスト ROM のシナリオ
#
# https://github.com/retrio/gb-test-roms の interrupt_time/interrupt_time.gb を skip_boot で起動して、
# 割り込みハンドラ呼び出しに必要なサイクル数(20 cycle: 5 M-cycle)が正しいかを検証する。
# シリアル出力 (0xFF01/0xFF02) に "Passed\n" または "Failed #XX\n" が出る。
#
# interrupt_time.gb は 32KB で MBC を使わないので現状の実装で動かせる。
# IME / EI / RETI / 割り込みベクタジャンプを正しく実装してから初めて意味のある結果が出る。
RSpec.describe 'Blargg interrupt_time 完走 (シリアルに "Passed" が出るまで)' do
  context 'interrupt_time.gb を実行したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../../data/gb-test-roms/interrupt_time.gb', __FILE__)).bytes }

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
