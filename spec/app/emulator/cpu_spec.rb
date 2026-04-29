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

  describe '#set_flags' do
    # F レジスタの bit7=Z, bit6=N, bit5=H, bit4=C を引数で更新する private ヘルパ。
    # 引数を渡したビットだけ書き換え、省略したビットは現状を保持する。
    subject { cpu.send(:set_flags, **args) }
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }
    let(:args) { {} }

    # F レジスタの bit レイアウト(上位 4bit がフラグ、下位 4bit は常に 0)
    #   bit7  bit6  bit5  bit4  bit3-0
    #   Z     N     H     C     (常に 0)

    context '全フラグを true に指定したとき' do
      let(:args) { { zero: true, negative: true, half_carry: true, carry: true } }

      it 'Z=1, N=1, H=1, C=1 になる' do
        subject
        expect(cpu.f).to eq 0b11110000
      end
    end

    context '全フラグを false に指定したとき' do
      let(:args) { { zero: false, negative: false, half_carry: false, carry: false } }
      before { cpu.f = 0b11110000 }  # 全 1 から始めて 0 になることを確認

      it 'Z=0, N=0, H=0, C=0 になる' do
        subject
        expect(cpu.f).to eq 0b00000000
      end
    end

    context 'zero だけ true、他は省略したとき' do
      let(:args) { { zero: true } }
      before { cpu.f = 0b00000000 }  # Z=0, N=0, H=0, C=0

      it 'Z bit だけ立ち、N/H/C は保持される' do
        subject
        expect(cpu.f).to eq 0b10000000  # Z=1, N=0, H=0, C=0
      end
    end

    context 'carry だけ false、他は省略したとき' do
      let(:args) { { carry: false } }
      before { cpu.f = 0b11110000 }  # Z=1, N=1, H=1, C=1

      it 'C bit だけクリア、Z/N/H は保持される' do
        subject
        expect(cpu.f).to eq 0b11100000  # Z=1, N=1, H=1, C=0
      end
    end

    context '引数を一切渡さなかったとき' do
      let(:args) { {} }
      before { cpu.f = 0b10100000 }  # Z=1, N=0, H=1, C=0

      it 'F は変化しない' do
        subject
        expect(cpu.f).to eq 0b10100000
      end
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

  describe 'HELLO WORLD 完走 (hello.gb が HALT に到達するまで)' do
    # CPU 単体ではなく CPU + MMU + Cartridge + hello.gb の統合シナリオ。
    # skip_boot 起動で hello.gb を走らせ、画面に "Hello World!" を描画したあと
    # PC=0x01B8 の HALT(0x76)で停止する。`halted` が true になることが完走の証拠。
    #
    # D-1 で CPU.new(skip_boot: true) が実装されるまでは、ここで初期レジスタを直接セットして
    # ブート ROM 終了直後の実機状態を再現する(B-2 の進捗確認用)。
    # 初期値の根拠 Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
    let(:cpu) do
      cpu = described_class.new(mmu)
      cpu.a = 0x01; cpu.f = 0xB0
      cpu.b = 0x00; cpu.c = 0x13
      cpu.d = 0x00; cpu.e = 0xD8
      cpu.h = 0x01; cpu.l = 0x4D
      cpu.sp = 0xFFFE
      cpu.pc = 0x0100
      cpu
    end
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/hello.gb', __FILE__)).bytes }

    it 'PC=0x01B8 の HALT に到達して halted=true になる' do
      # hello.gb の初期化処理は実機で数万〜十数万 T-cycle 程度で完走する。
      # 上限 1,000,000 T-cycle まで run を繰り返し、HALT 命令で halted=true になるか確認する。
      # HALT(0x76)は 1 バイト命令なので、実行後 PC は次のバイト(0x01B9)を指している。
      elapsed = 0
      elapsed += cpu.run(1000) until cpu.halted || elapsed >= 1_000_000

      expect(cpu.halted).to eq true
      expect(cpu.pc).to eq 0x01B9
    end
  end

  describe 'ブート ROM 完走 (PC が 0x0100 に到達するまで)' do
    # CPU 単体ではなく CPU + MMU + Cartridge + ブート ROM の統合シナリオ。
    # 「ブート ROM を実行して PC が 0x0100 に到達する」という振る舞いの検証なので
    # 特定のメソッド describe ではなくシナリオ名で切る。

    # ブート ROM (256 バイト) を ROM 先頭に重ねて、tobu.gb の本体側 (Nintendo ロゴ + ヘッダ含む)
    # と組み合わせて流す。ブート ROM はカートリッジヘッダのロゴ照合を通らないと 0x0100 へ
    # ジャンプしないため、tobu.gb の正規ロゴを 0x0104-0x0133 に置く必要がある。
    # E-4 で MMU 側にブート ROM 重畳の正規実装が入るが、B-2/E-1/E-2 の進捗確認用にここでは
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
