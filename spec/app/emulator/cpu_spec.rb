require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

RSpec.describe CPU do
  describe '#initialize' do
    subject { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    it '全レジスタが 0、IME と halted が false で初期化される' do
      cpu = subject
      expect(cpu.a).to eq 0
      expect(cpu.b).to eq 0
      expect(cpu.c).to eq 0
      expect(cpu.d).to eq 0
      expect(cpu.e).to eq 0
      expect(cpu.h).to eq 0
      expect(cpu.l).to eq 0
      expect(cpu.f).to eq 0
      expect(cpu.sp).to eq 0
      expect(cpu.pc).to eq 0
      expect(cpu.ime).to eq false
      expect(cpu.halted).to eq false
    end
  end

  describe '#step' do
    subject { cpu.step }
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:rom_data) do
      data = Array.new(0x8000, 0)
      # PC=0x0000 から実行されるので、テスト用バイト列を ROM の先頭に置く。
      bytes.each_with_index { |b, i| data[i] = b }
      data
    end

    context 'NOP (0x00) を実行したとき' do
      let(:bytes) { [0x00] }

      it '4 サイクル消費して PC が 1 進む' do
        is_expected.to eq 4
        expect(cpu.pc).to eq 0x0001
      end
    end

    context '未実装オペコード (0xD3) を踏んだとき' do
      let(:bytes) { [0xD3] }

      it 'PC とオペコードを含む例外を投げる' do
        expect { subject }.to raise_error(/Unimplemented opcode 0xD3 at PC=0x0000/)
      end
    end

    context 'halted が true のとき' do
      let(:bytes) { [0x00] }
      before { cpu.halted = true }

      it '4 サイクル消費して PC は進まない(命令を fetch しない)' do
        is_expected.to eq 4
        expect(cpu.pc).to eq 0x0000
      end
    end

    context 'PC が 0xFFFF を超えて折り返すとき' do
      let(:bytes) { [0x00] }
      before { cpu.pc = 0xFFFF }

      it 'PC は 0x0000 に wrap する' do
        is_expected.to eq 4
        expect(cpu.pc).to eq 0x0000
      end
    end
  end

  describe '#run' do
    subject { cpu.run(cycles_target) }
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:rom_data) { Array.new(0x8000, 0x00) }  # 全部 NOP
    let(:cycles_target) { 16 }

    it 'NOP 4 個分を実行して 16 サイクル消費し PC が 4 進む' do
      is_expected.to eq 16
      expect(cpu.pc).to eq 4
    end

    # ブート ROM (256 バイト) を ROM 先頭に重ねて、tobu.gb の本体側 (Nintendo ロゴ + ヘッダ含む)
    # と組み合わせて流す。ブート ROM はカートリッジヘッダのロゴ照合を通らないと 0x0100 へ
    # ジャンプしないため、tobu.gb の正規ロゴを 0x0104-0x0133 に置く必要がある。
    # D-1 で MMU 側にブート ROM 重畳の正規実装が入るが、B-2/B-3 の進捗確認用にここでは
    # Cartridge 配列の先頭を直接書き換える簡易セットアップを使う。
    context 'ブート ROM (data/dmg_boot.bin) と tobu.gb を重ねて実行したとき' do
      let(:boot_rom) { File.binread(File.expand_path('../../../../data/dmg_boot.bin', __FILE__)).bytes }
      let(:tobu)     { File.binread(File.expand_path('../../../../data/tobu.gb', __FILE__)).bytes }
      let(:rom_data) { boot_rom + tobu[boot_rom.size..] }

      it 'PC が 0x0100 に到達してブート ROM を完走する' do
        # ブート ROM は実機で約 70,000 T-cycle 程度で完走する。
        # 上限 200,000 T-cycle まで run を繰り返し、PC が 0x0100 (カートリッジ先頭) に到達するか確認する。
        elapsed = 0
        elapsed += cpu.run(1000) while cpu.pc < 0x0100 && elapsed < 200_000

        expect(cpu.pc).to eq 0x0100
      end
    end
  end
end
