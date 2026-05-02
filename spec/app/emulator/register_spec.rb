require 'app/emulator/register'

RSpec.describe Register do
  describe '#initialize' do
    context 'skip_boot を指定しないとき(ブートROM 経由起動)' do
      subject { described_class.new }

      it '全レジスタが 0 で初期化される' do
        register = subject
        expect(register.a).to eq 0
        expect(register.b).to eq 0
        expect(register.c).to eq 0
        expect(register.d).to eq 0
        expect(register.e).to eq 0
        expect(register.h).to eq 0
        expect(register.l).to eq 0
        expect(register.f).to eq 0
      end
    end

    context 'skip_boot: true を指定したとき(ブートROM をスキップして起動)' do
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
      # ブートROM 完走後の DMG 実機値を最初からセットして起動する
      subject { described_class.new(skip_boot: true) }

      it 'A=0x01, F=0xB0(DMG識別値 + Z=1,N=0,H=1,C=1)' do
        expect(subject.a).to eq 0x01
        expect(subject.f).to eq 0xB0
      end

      it 'BC=0x0013, DE=0x00D8, HL=0x014D' do
        expect(subject.bc).to eq 0x0013
        expect(subject.de).to eq 0x00D8
        expect(subject.hl).to eq 0x014D
      end
    end
  end

  describe '#set_flags' do
    # F レジスタの bit7=Z, bit6=N, bit5=H, bit4=C を引数で更新するヘルパ
    # 引数を渡したビットだけ書き換え、省略したビットは現状を保持する
    subject { register.set_flags(**args) }
    let(:register) { described_class.new }
    let(:args) { {} }

    # F レジスタの bit レイアウト(上位 4bit がフラグ、下位 4bit は常に 0)
    #   bit7  bit6  bit5  bit4  bit3-0
    #   Z     N     H     C     (常に 0)

    context '全フラグを true に指定したとき' do
      let(:args) { { zero: true, negative: true, half_carry: true, carry: true } }

      it 'Z=1, N=1, H=1, C=1 になる' do
        subject
        expect(register.f).to eq 0b11110000
      end
    end

    context '全フラグを false に指定したとき' do
      let(:args) { { zero: false, negative: false, half_carry: false, carry: false } }
      before { register.f = 0b11110000 }  # 全 1 から始めて 0 になることを確認

      it 'Z=0, N=0, H=0, C=0 になる' do
        subject
        expect(register.f).to eq 0b00000000
      end
    end

    context 'zero だけ true、他は省略したとき' do
      let(:args) { { zero: true } }
      before { register.f = 0b00000000 }  # Z=0, N=0, H=0, C=0

      it 'Z bit だけ立ち、N/H/C は保持される' do
        subject
        expect(register.f).to eq 0b10000000  # Z=1, N=0, H=0, C=0
      end
    end

    context 'carry だけ false、他は省略したとき' do
      let(:args) { { carry: false } }
      before { register.f = 0b11110000 }  # Z=1, N=1, H=1, C=1

      it 'C bit だけクリア、Z/N/H は保持される' do
        subject
        expect(register.f).to eq 0b11100000  # Z=1, N=1, H=1, C=0
      end
    end

    context '引数を一切渡さなかったとき' do
      let(:args) { {} }
      before { register.f = 0b10100000 }  # Z=1, N=0, H=1, C=0

      it 'F は変化しない' do
        subject
        expect(register.f).to eq 0b10100000
      end
    end
  end

  describe '#bc' do
    # B + C を 16bit に合成して返す getter。B が上位、C が下位
    # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
    subject { register.bc }
    let(:register) { described_class.new }

    context 'B=0x12, C=0x34 のとき' do
      before do
        register.b = 0x12
        register.c = 0x34
      end

      it '0x1234 を返す' do
        is_expected.to eq 0x1234
      end
    end

    context 'B=0x00, C=0x00 のとき' do
      it '0x0000 を返す' do
        is_expected.to eq 0x0000
      end
    end

    context 'B=0xFF, C=0xFF のとき' do
      before do
        register.b = 0xFF
        register.c = 0xFF
      end

      it '0xFFFF を返す' do
        is_expected.to eq 0xFFFF
      end
    end

    context 'B=0x00, C=0xFF のとき' do
      before do
        register.b = 0x00
        register.c = 0xFF
      end

      it '0x00FF を返す' do
        is_expected.to eq 0x00FF
      end
    end

    context 'B=0xFF, C=0x00 のとき' do
      before do
        register.b = 0xFF
        register.c = 0x00
      end

      it '0xFF00 を返す' do
        is_expected.to eq 0xFF00
      end
    end
  end

  describe '#de' do
    # D + E を 16bit に合成して返す getter。D が上位、E が下位
    subject { register.de }
    let(:register) { described_class.new }

    context 'D=0x12, E=0x34 のとき' do
      before do
        register.d = 0x12
        register.e = 0x34
      end

      it '0x1234 を返す' do
        is_expected.to eq 0x1234
      end
    end

    context 'D=0x00, E=0x00 のとき' do
      it '0x0000 を返す' do
        is_expected.to eq 0x0000
      end
    end

    context 'D=0xFF, E=0xFF のとき' do
      before do
        register.d = 0xFF
        register.e = 0xFF
      end

      it '0xFFFF を返す' do
        is_expected.to eq 0xFFFF
      end
    end

    context 'D=0x00, E=0xFF のとき' do
      before do
        register.d = 0x00
        register.e = 0xFF
      end

      it '0x00FF を返す' do
        is_expected.to eq 0x00FF
      end
    end

    context 'D=0xFF, E=0x00 のとき' do
      before do
        register.d = 0xFF
        register.e = 0x00
      end

      it '0xFF00 を返す' do
        is_expected.to eq 0xFF00
      end
    end
  end

  describe '#hl' do
    # H + L を 16bit に合成して返す getter。H が上位、L が下位
    subject { register.hl }
    let(:register) { described_class.new }

    context 'H=0x12, L=0x34 のとき' do
      before do
        register.h = 0x12
        register.l = 0x34
      end

      it '0x1234 を返す' do
        is_expected.to eq 0x1234
      end
    end

    context 'H=0x00, L=0x00 のとき' do
      it '0x0000 を返す' do
        is_expected.to eq 0x0000
      end
    end

    context 'H=0xFF, L=0xFF のとき' do
      before do
        register.h = 0xFF
        register.l = 0xFF
      end

      it '0xFFFF を返す' do
        is_expected.to eq 0xFFFF
      end
    end

    context 'H=0x00, L=0xFF のとき' do
      before do
        register.h = 0x00
        register.l = 0xFF
      end

      it '0x00FF を返す' do
        is_expected.to eq 0x00FF
      end
    end

    context 'H=0xFF, L=0x00 のとき' do
      before do
        register.h = 0xFF
        register.l = 0x00
      end

      it '0xFF00 を返す' do
        is_expected.to eq 0xFF00
      end
    end

    context 'setter で代入した直後に getter で読み戻したとき' do
      # bc=, de=, hl= で書いた値と bc, de, hl で読んだ値が一致すること(往復確認)
      before { register.hl = 0xABCD }

      it '元の値 (0xABCD) が返る' do
        is_expected.to eq 0xABCD
      end
    end
  end

  describe '#bc=' do
    # 16bit 値を BC ペアに振り分ける setter。B が上位、C が下位
    # Pan Docs: https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
    subject { register.bc = value }
    let(:register) { described_class.new }

    context '0x1234 を渡したとき' do
      let(:value) { 0x1234 }

      it 'B=0x12, C=0x34 になる' do
        subject
        expect(register.b).to eq 0x12
        expect(register.c).to eq 0x34
      end
    end

    context '0x0000 を渡したとき' do
      let(:value) { 0x0000 }
      before do
        register.b = 0xAA
        register.c = 0xBB
      end

      it 'B=0x00, C=0x00 で上書きされる' do
        subject
        expect(register.b).to eq 0x00
        expect(register.c).to eq 0x00
      end
    end

    context '0xFFFF を渡したとき' do
      let(:value) { 0xFFFF }

      it 'B=0xFF, C=0xFF になる' do
        subject
        expect(register.b).to eq 0xFF
        expect(register.c).to eq 0xFF
      end
    end

    context '0x00FF (上位がゼロ) を渡したとき' do
      let(:value) { 0x00FF }

      it 'B=0x00, C=0xFF になる' do
        subject
        expect(register.b).to eq 0x00
        expect(register.c).to eq 0xFF
      end
    end

    context '0xFF00 (下位がゼロ) を渡したとき' do
      let(:value) { 0xFF00 }

      it 'B=0xFF, C=0x00 になる' do
        subject
        expect(register.b).to eq 0xFF
        expect(register.c).to eq 0x00
      end
    end
  end

  describe '#de=' do
    # 16bit 値を DE ペアに振り分ける setter。D が上位、E が下位
    subject { register.de = value }
    let(:register) { described_class.new }

    context '0x1234 を渡したとき' do
      let(:value) { 0x1234 }

      it 'D=0x12, E=0x34 になる' do
        subject
        expect(register.d).to eq 0x12
        expect(register.e).to eq 0x34
      end
    end

    context '0x0000 を渡したとき' do
      let(:value) { 0x0000 }
      before do
        register.d = 0xAA
        register.e = 0xBB
      end

      it 'D=0x00, E=0x00 で上書きされる' do
        subject
        expect(register.d).to eq 0x00
        expect(register.e).to eq 0x00
      end
    end

    context '0xFFFF を渡したとき' do
      let(:value) { 0xFFFF }

      it 'D=0xFF, E=0xFF になる' do
        subject
        expect(register.d).to eq 0xFF
        expect(register.e).to eq 0xFF
      end
    end

    context '0x00FF (上位がゼロ) を渡したとき' do
      let(:value) { 0x00FF }

      it 'D=0x00, E=0xFF になる' do
        subject
        expect(register.d).to eq 0x00
        expect(register.e).to eq 0xFF
      end
    end

    context '0xFF00 (下位がゼロ) を渡したとき' do
      let(:value) { 0xFF00 }

      it 'D=0xFF, E=0x00 になる' do
        subject
        expect(register.d).to eq 0xFF
        expect(register.e).to eq 0x00
      end
    end
  end

  describe '#hl=' do
    # 16bit 値を HL ペアに振り分ける setter。H が上位、L が下位
    subject { register.hl = value }
    let(:register) { described_class.new }

    context '0x1234 を渡したとき' do
      let(:value) { 0x1234 }

      it 'H=0x12, L=0x34 になる' do
        subject
        expect(register.h).to eq 0x12
        expect(register.l).to eq 0x34
      end
    end

    context '0x0000 を渡したとき' do
      let(:value) { 0x0000 }
      before do
        register.h = 0xAA
        register.l = 0xBB
      end

      it 'H=0x00, L=0x00 で上書きされる' do
        subject
        expect(register.h).to eq 0x00
        expect(register.l).to eq 0x00
      end
    end

    context '0xFFFF を渡したとき' do
      let(:value) { 0xFFFF }

      it 'H=0xFF, L=0xFF になる' do
        subject
        expect(register.h).to eq 0xFF
        expect(register.l).to eq 0xFF
      end
    end

    context '0x00FF (上位がゼロ) を渡したとき' do
      let(:value) { 0x00FF }

      it 'H=0x00, L=0xFF になる' do
        subject
        expect(register.h).to eq 0x00
        expect(register.l).to eq 0xFF
      end
    end

    context '0xFF00 (下位がゼロ) を渡したとき' do
      let(:value) { 0xFF00 }

      it 'H=0xFF, L=0x00 になる' do
        subject
        expect(register.h).to eq 0xFF
        expect(register.l).to eq 0x00
      end
    end
  end
end
