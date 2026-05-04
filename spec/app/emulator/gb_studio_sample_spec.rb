require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

# GB Studio サンプル ROM 起動シナリオ
#
# `data/gb-studio-sample.gb` は GB Studio (https://www.gbstudio.dev/) で書き出した
# サンプルゲーム ROM。タイトル "SAMPLE"、cartridge type 0x1E = MBC5+RUMBLE+RAM+BATTERY、
# ROM size 0x03 (256KB / 16 banks)、RAM size 0x03 (32KB / 4 banks of 8KB)。
#
# 現状の MMU は MBC を実装していないので、ROM bank 1 以降のコード(0x4000-0x7FFF)を
# 触ろうとすると bank 0 と同じデータが返る → 実機と挙動がズレる → 大抵は不正な PC に
# ジャンプして未実装命令で停止する想定。停止位置を観察する probe として使う。
#
# F-1 で MBC1/MBC5 が実装されたら、このシナリオが「タイトル画面表示で HALT に到達」する
# ことを確認する形に強化できる。
RSpec.describe 'GB Studio サンプル ROM 起動 (HALT に到達するまで)' do
  context 'gb-studio-sample.gb を skip_boot で起動したとき' do
    let(:cpu) { CPU.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/gb-studio-sample.gb', __FILE__)).bytes }

    it 'CPU が HALT 状態に到達する' do
      # 5M T-cycle ≒ 実機 1.2 秒。タイトル画面表示後の VBlank 待機 HALT に入る想定
      # MBC 未対応で早期に未実装命令で停止する場合は、その例外メッセージから次に実装すべき
      # 命令(または MBC 周りの修正点)が見えるので、停止位置を観察する probe として機能する
      elapsed = 0
      until cpu.halted || elapsed >= 5_000_000
        cycles = cpu.run(1000)
        ppu.step(cycles)
        elapsed += cycles
      end

      expect(cpu.halted).to eq true
    end
  end
end
