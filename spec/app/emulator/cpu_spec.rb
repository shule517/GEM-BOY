require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

RSpec.describe CPU do
  describe '#initialize' do
    let(:mmu) { MMU.new(Cartridge.new(Array.new(0x8000, 0))) }

    context 'skip_boot を指定しないとき(ブートROM 経由起動)' do
      subject { described_class.new(mmu) }

      it 'SP=0, PC=0、IME と halted が false で初期化される' do
        cpu = subject
        expect(cpu.sp).to eq 0
        expect(cpu.pc).to eq 0
        expect(cpu.ime).to eq false
        expect(cpu.halted).to eq false
      end

      it 'register が 0 初期化された Register として渡される' do
        expect(subject.register).to be_a Register
        expect(subject.register.a).to eq 0
        expect(subject.register.f).to eq 0
      end
    end

    context 'skip_boot: true を指定したとき(ブートROM をスキップして起動)' do
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
      # ブートROM 完走後の DMG 実機値を最初からセットして起動する
      subject { described_class.new(mmu, skip_boot: true) }

      it 'SP=0xFFFE(HRAM末端)' do
        expect(subject.sp).to eq 0xFFFE
      end

      it 'PC=0x0100(カートリッジコード開始位置)' do
        expect(subject.pc).to eq 0x0100
      end

      it 'IME=false, halted=false' do
        expect(subject.ime).to eq false
        expect(subject.halted).to eq false
      end

      it 'register が skip_boot: true の Register として渡される' do
        expect(subject.register.a).to eq 0x01
        expect(subject.register.f).to eq 0xB0
        expect(subject.register.bc).to eq 0x0013
        expect(subject.register.de).to eq 0x00D8
        expect(subject.register.hl).to eq 0x014D
      end
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

      it 'fetch_u8 で PC を 1 進めて 4 サイクルを返す' do
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

  describe '#fetch_i8' do
    # PC が指す 1 バイトを符号付き(-128〜+127)として読む private ヘルパ。
    # 2 の補数表現: bit7 が 1 の値(0x80〜0xFF)を負数として解釈する。
    # JR i8 / ADD SP,i8 / LD HL,SP+i8 で使う。
    subject { cpu.fetch_i8 }
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:rom_data) do
      data = Array.new(0x8000, 0)
      bytes.each_with_index { |b, i| data[i] = b }
      data
    end

    context 'PC が指すバイトが 0x00 のとき' do
      let(:bytes) { [0x00] }

      it '0 を返し PC が 1 進む' do
        is_expected.to eq 0
        expect(cpu.pc).to eq 0x0001
      end
    end

    context 'PC が指すバイトが 0x7F (正の最大値) のとき' do
      let(:bytes) { [0x7F] }

      it '+127 を返し PC が 1 進む' do
        is_expected.to eq 127
        expect(cpu.pc).to eq 0x0001
      end
    end

    context 'PC が指すバイトが 0x80 (負の最小値) のとき' do
      # bit7 = 1 の境界値。0x80 - 256 = -128。
      let(:bytes) { [0x80] }

      it '-128 を返し PC が 1 進む' do
        is_expected.to eq(-128)
        expect(cpu.pc).to eq 0x0001
      end
    end

    context 'PC が指すバイトが 0xFF のとき' do
      # 0xFF - 256 = -1。JR -1 で 1 バイト戻るパターンの典型値。
      let(:bytes) { [0xFF] }

      it '-1 を返し PC が 1 進む' do
        is_expected.to eq(-1)
        expect(cpu.pc).to eq 0x0001
      end
    end

    context 'PC が指すバイトが 0xFE のとき' do
      # 0xFE - 256 = -2。`JR -2` の無限ループで踏むパターン。
      let(:bytes) { [0xFE] }

      it '-2 を返し PC が 1 進む' do
        is_expected.to eq(-2)
        expect(cpu.pc).to eq 0x0001
      end
    end

    context 'PC が 0xFFFF を指していて 0xFF を読むとき' do
      # PC=0xFFFF で fetch すると、PC が +1 で 0x0000 へラップする。
      # 値の符号解釈とは独立したラップ挙動を確認する。
      let(:bytes) { [0x00] }
      before do
        cpu.pc = 0xFFFF
        # 0xFFFF は ROM 範囲外なので MMU.write で直接書ける場所ではない。
        # ここでは PC ラップだけ確認したいので、MMU が 0xFFFF をどう読むかに依存しない
        # アサーション (PC が 0x0000 になる) のみ行う。
      end

      it 'PC は 0x0000 へラップする' do
        subject
        expect(cpu.pc).to eq 0x0000
      end
    end
  end

  describe '#build_opcode_table' do
    # build_opcode_table が返すテーブル(initialize から呼ばれて cpu.opcodes に格納される)を
    # 取り出し、各 opcode の lambda を直接呼んで振る舞いを検証する。
    # step が消費するオペコード分の fetch_u8 は通っていない状態で lambda を呼ぶので、
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
      # lambda は fetch_u8 を 2 回呼ぶ。リトルエンディアンなので
      # 下位バイト(L)→ 上位バイト(H)の順に読む。
      # Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html

      context 'バイト列が [0x34, 0x12] のとき' do
        let(:bytes) { [0x34, 0x12] }

        it '12 サイクルを返し、L=0x34, H=0x12, PC が 2 進む' do
          expect(subject[0x21].call).to eq 12
          expect(cpu.register.l).to eq 0x34
          expect(cpu.register.h).to eq 0x12
          expect(cpu.pc).to eq 0x0002
        end
      end

      context 'バイト列が [0x00, 0x00] のとき' do
        # HL=0x0000 の境界値。L/H が両方ゼロにセットされることを確認する。
        let(:bytes) { [0x00, 0x00] }

        it 'L=0x00, H=0x00, PC が 2 進む' do
          expect(subject[0x21].call).to eq 12
          expect(cpu.register.l).to eq 0x00
          expect(cpu.register.h).to eq 0x00
          expect(cpu.pc).to eq 0x0002
        end
      end

      context 'バイト列が [0xFF, 0xFF] のとき' do
        # HL=0xFFFF の境界値。8bit の最大値が L/H 両方に入る。
        let(:bytes) { [0xFF, 0xFF] }

        it 'L=0xFF, H=0xFF, PC が 2 進む' do
          expect(subject[0x21].call).to eq 12
          expect(cpu.register.l).to eq 0xFF
          expect(cpu.register.h).to eq 0xFF
          expect(cpu.pc).to eq 0x0002
        end
      end

      context 'H/L に既に値が入っているとき' do
        # LD は宛先を上書きする。事前値が残らないことを確認する。
        let(:bytes) { [0x34, 0x12] }
        before do
          cpu.register.h = 0xAA
          cpu.register.l = 0xBB
        end

        it 'H/L が新しい値 (H=0x12, L=0x34) で上書きされる' do
          expect(subject[0x21].call).to eq 12
          expect(cpu.register.l).to eq 0x34
          expect(cpu.register.h).to eq 0x12
        end
      end

      context 'F レジスタに値が入っているとき' do
        # LD HL,u16 はフラグを一切変更しない命令。
        # Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html#ld-r16-n16
        let(:bytes) { [0x34, 0x12] }
        before { cpu.register.f = 0b11110000 } # Z=1, N=1, H=1, C=1

        it 'F レジスタは保持される' do
          subject[0x21].call
          expect(cpu.register.f).to eq 0b11110000
        end
      end
    end

    context 'table[0x31] (LD SP,u16) を呼び出したとき' do
      # fetch_u16 はリトルエンディアン(下位バイト → 上位バイトの順に読む)で 16bit を組み立てる。
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
      before { cpu.register.a = 0x42 }

      it '4 サイクルを返し、A=0x00, F=0x80 (Z=1, N=H=C=0), PC は進まない' do
        expect(subject[0xAF].call).to eq 4
        expect(cpu.register.a).to eq 0x00
        expect(cpu.register.f).to eq 0x80
        expect(cpu.pc).to eq 0x0000
      end
    end
  end

  describe 'HELLO WORLD 完走 (hello.gb が HALT に到達するまで)' do
    # CPU 単体ではなく CPU + MMU + Cartridge + PPU + hello.gb の統合シナリオ。
    # skip_boot 起動で hello.gb を走らせ、画面に "Hello World!" を描画したあと
    # PC=0x01B8 の HALT(0x76)で停止する。`halted` が true になることが完走の証拠。
    #
    # PPU は C-1 で実装済み。VBlank 待ちループ(LY=144 で抜ける)を成立させるため、
    # CPU が消費したサイクル数を PPU.step に渡して LY を進める必要がある。
    let(:cpu) { described_class.new(mmu, skip_boot: true) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:ppu) { PPU.new(mmu) }
    let(:rom_data) { File.binread(File.expand_path('../../../../data/hello.gb', __FILE__)).bytes }

    it 'PC=0x01B8 の HALT に到達して halted=true になる' do
      # hello.gb の初期化処理は実機で数万〜十数万 T-cycle 程度で完走する。
      # 上限 1,000,000 T-cycle まで run を繰り返し、HALT 命令で halted=true になるか確認する。
      # HALT(0x76)は 1 バイト命令なので、実行後 PC は次のバイト(0x01B9)を指している。
      elapsed = 0
      until cpu.halted || elapsed >= 1_000_000
        cycles = cpu.run(1000)
        ppu.step(cycles)
        elapsed += cycles
      end

      expect(cpu.halted).to eq true
      expect(cpu.pc).to eq 0x01B9
    end
  end

  describe 'ブートROM 完走 (PC が 0x0100 に到達するまで)' do
    # CPU 単体ではなく CPU + MMU + Cartridge + ブートROM の統合シナリオ。
    # 「ブートROM を実行して PC が 0x0100 に到達する」という振る舞いの検証なので
    # 特定のメソッド describe ではなくシナリオ名で切る。

    # ブートROM (256 バイト) を ROM 先頭に重ねて、tobu.gb の本体側 (Nintendo ロゴ + ヘッダ含む)
    # と組み合わせて流す。ブートROM はカートリッジヘッダのロゴ照合を通らないと 0x0100 へ
    # ジャンプしないため、tobu.gb の正規ロゴを 0x0104-0x0133 に置く必要がある。
    # E-4 で MMU 側にブートROM 重畳の正規実装が入るが、B-2/E-1/E-2 の進捗確認用にここでは
    # Cartridge 配列の先頭を直接書き換える簡易セットアップを使う。
    let(:cpu) { described_class.new(mmu) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data)) }
    let(:boot_rom) { File.binread(File.expand_path('../../../../data/dmg_boot.bin', __FILE__)).bytes }
    let(:tobu)     { File.binread(File.expand_path('../../../../data/tobu.gb', __FILE__)).bytes }
    let(:rom_data) { boot_rom + tobu[boot_rom.size..] }

    it 'tobu.gb のロゴ照合を通って PC=0x0100 に到達する' do
      # ブートROM は実機で約 70,000 T-cycle 程度で完走する。
      # 上限 200,000 T-cycle まで run を繰り返し、PC が 0x0100 (カートリッジ先頭) に到達するか確認する。
      elapsed = 0
      elapsed += cpu.run(1000) while cpu.pc < 0x0100 && elapsed < 200_000

      expect(cpu.pc).to eq 0x0100
    end
  end
end
