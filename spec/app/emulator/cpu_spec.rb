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
      bytes.each_with_index { |b, i| data[i] = b }
      data
    end

    context 'opcode を fetch して opcodes テーブルから lambda を引いて呼ぶとき' do
      # NOP (0x00) で dispatch の最小動作だけを検証する。
      let(:bytes) { [0x00] }

      it 'fetch_byte で PC を 1 進めて 4 サイクルを返す' do
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
  end

  describe '#build_opcode_table' do
    # build_opcode_table が返すテーブル(initialize から呼ばれて cpu.opcodes に格納される)を
    # 取り出し、各 opcode の lambda を直接呼んで振る舞いを検証する。
    # step が消費するオペコード分の fetch_byte は通っていない状態で lambda を呼ぶので、
    # 即値オペランドは PC=0x0000 から読まれる点に注意。
    subject { cpu.opcodes }
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:rom_data) do
      data = Array.new(0x8000, 0)
      bytes.each_with_index { |b, i| data[i] = b }
      data
    end
    let(:bytes) { [] }

    context 'table[0x00] (NOP) を呼び出したとき' do
      it '4 サイクルを返す(レジスタは変化しない)' do
        expect(subject[0x00].call).to eq 4
        expect(cpu.pc).to eq 0x0000
      end
    end

    context 'table[0x21] (LD HL,u16) を呼び出したとき' do
      # lambda は fetch_byte を 2 回呼ぶ。リトルエンディアンなので
      # 下位バイト(0x34)が先に L へ、続けて上位バイト(0x12)が H へ入る。
      let(:bytes) { [0x34, 0x12] }

      it '12 サイクルを返し、L=0x34, H=0x12, PC が 2 進む' do
        expect(subject[0x21].call).to eq 12
        expect(cpu.l).to eq 0x34
        expect(cpu.h).to eq 0x12
        expect(cpu.pc).to eq 0x0002
      end
    end

    context 'table[0x31] (LD SP,u16) を呼び出したとき' do
      # fetch_word はリトルエンディアン(下位バイト → 上位バイトの順に読む)で 16bit を組み立てる。
      # bytes = [0x34, 0x12] → SP = 0x1234
      let(:bytes) { [0x34, 0x12] }

      it '12 サイクルを返し、SP=0x1234, PC が 2 進む' do
        expect(subject[0x31].call).to eq 12
        expect(cpu.sp).to eq 0x1234
        expect(cpu.pc).to eq 0x0002
      end
    end

    context 'table[0xAF] (XOR A,A) を呼び出したとき' do
      # A の初期値に関係なく A^A は必ず 0 になる。事前に非ゼロを入れて確実に上書きされることを確認する。
      before { cpu.a = 0x42 }

      it '4 サイクルを返し、A=0x00, F=0x80 (Z=1, N=H=C=0), PC は進まない' do
        expect(subject[0xAF].call).to eq 4
        expect(cpu.a).to eq 0x00
        expect(cpu.f).to eq 0x80
        expect(cpu.pc).to eq 0x0000
      end
    end
  end

  describe 'ブート ROM 完走 (PC が 0x0100 に到達するまで)' do
    # CPU 単体ではなく CPU + MMU + Cartridge + ブート ROM の統合シナリオ。
    # 「ブート ROM を実行して PC が 0x0100 に到達する」という振る舞いの検証なので
    # 特定のメソッド describe ではなくシナリオ名で切る。

    # ブート ROM (256 バイト) を ROM 先頭に重ねて、tobu.gb の本体側 (Nintendo ロゴ + ヘッダ含む)
    # と組み合わせて流す。ブート ROM はカートリッジヘッダのロゴ照合を通らないと 0x0100 へ
    # ジャンプしないため、tobu.gb の正規ロゴを 0x0104-0x0133 に置く必要がある。
    # D-1 で MMU 側にブート ROM 重畳の正規実装が入るが、B-2/B-3 の進捗確認用にここでは
    # Cartridge 配列の先頭を直接書き換える簡易セットアップを使う。
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:boot_rom) { File.binread(File.expand_path('../../../../data/dmg_boot.bin', __FILE__)).bytes }
    let(:tobu)     { File.binread(File.expand_path('../../../../data/tobu.gb', __FILE__)).bytes }
    let(:rom_data) { boot_rom + tobu[boot_rom.size..] }

    it 'tobu.gb のロゴ照合を通って PC=0x0100 に到達する' do
      # ブート ROM は実機で約 70,000 T-cycle 程度で完走する。
      # 上限 200,000 T-cycle まで run を繰り返し、PC が 0x0100 (カートリッジ先頭) に到達するか確認する。
      elapsed = 0
      elapsed += cpu.run(1000) while cpu.pc < 0x0100 && elapsed < 200_000

      expect(cpu.pc).to eq 0x0100
    end
  end
end
