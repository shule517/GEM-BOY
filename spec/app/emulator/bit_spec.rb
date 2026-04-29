require 'app/emulator/bit'

RSpec.describe Bit do
  describe '.high_byte' do
    # 16bit 値から上位 8bit を取り出す。レジスタペア setter で使う。
    subject { Bit.high_byte(value) }

    context '0x1234 を渡したとき' do
      let(:value) { 0x1234 }

      it '上位 8bit (0x12) を返す' do
        is_expected.to eq 0x12
      end
    end

    context '0x0000 を渡したとき' do
      let(:value) { 0x0000 }

      it '0x00 を返す' do
        is_expected.to eq 0x00
      end
    end

    context '0xFFFF を渡したとき' do
      let(:value) { 0xFFFF }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end

    context '0x00FF (上位がゼロ) を渡したとき' do
      # 下位だけに値があるケース。上位 8bit は 0 になる。
      let(:value) { 0x00FF }

      it '0x00 を返す' do
        is_expected.to eq 0x00
      end
    end

    context '0xFF00 (下位がゼロ) を渡したとき' do
      # 上位だけに値があるケース。シフトで下位の位置に降りる。
      let(:value) { 0xFF00 }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end
  end

  describe '.low_byte' do
    # 16bit 値から下位 8bit を取り出す。レジスタペア setter で使う。
    subject { Bit.low_byte(value) }

    context '0x1234 を渡したとき' do
      let(:value) { 0x1234 }

      it '下位 8bit (0x34) を返す' do
        is_expected.to eq 0x34
      end
    end

    context '0x0000 を渡したとき' do
      let(:value) { 0x0000 }

      it '0x00 を返す' do
        is_expected.to eq 0x00
      end
    end

    context '0xFFFF を渡したとき' do
      let(:value) { 0xFFFF }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end

    context '0x00FF (上位がゼロ) を渡したとき' do
      let(:value) { 0x00FF }

      it '0xFF を返す' do
        is_expected.to eq 0xFF
      end
    end

    context '0xFF00 (下位がゼロ) を渡したとき' do
      let(:value) { 0xFF00 }

      it '0x00 を返す' do
        is_expected.to eq 0x00
      end
    end
  end

  describe '.make_u16' do
    # 上位 8bit + 下位 8bit を 16bit に合成する。high_byte / low_byte の逆操作。
    subject { Bit.make_u16(high: high, low: low) }

    context '高位バイトに 0x12、低位バイトに 0x34 を渡したとき' do
      let(:high) { 0x12 }
      let(:low)  { 0x34 }

      it '0x1234 を返す' do
        is_expected.to eq 0x1234
      end
    end

    context '両方 0x00 を渡したとき' do
      let(:high) { 0x00 }
      let(:low)  { 0x00 }

      it '0x0000 を返す' do
        is_expected.to eq 0x0000
      end
    end

    context '両方 0xFF を渡したとき' do
      let(:high) { 0xFF }
      let(:low)  { 0xFF }

      it '0xFFFF を返す' do
        is_expected.to eq 0xFFFF
      end
    end

    context '高位バイトが 0x00、低位バイトが 0xFF のとき' do
      let(:high) { 0x00 }
      let(:low)  { 0xFF }

      it '0x00FF を返す' do
        is_expected.to eq 0x00FF
      end
    end

    context '高位バイトが 0xFF、低位バイトが 0x00 のとき' do
      let(:high) { 0xFF }
      let(:low)  { 0x00 }

      it '0xFF00 を返す' do
        is_expected.to eq 0xFF00
      end
    end

    context 'high_byte / low_byte と組み合わせたとき' do
      # 16bit 値を一度バラして再合成すると元に戻ること(逆操作の確認)
      let(:high) { Bit.high_byte(0xABCD) }
      let(:low)  { Bit.low_byte(0xABCD) }

      it '元の 16bit 値に戻る (0xABCD)' do
        is_expected.to eq 0xABCD
      end
    end
  end

  describe '.wrap_u16' do
    # 引数を 16bit にマスクして wrap させる(下位 16bit のみ残す)。
    # PC の +1 オーバーフロー(0xFFFF→0x0000)、JR の負オフセット、
    # ADD HL,BC のキャリーアウトなど、16bit 演算結果を正規化するときに使う。
    subject { Bit.wrap_u16(n) }

    context '0x0000 を渡したとき' do
      let(:n) { 0x0000 }

      it '0x0000 を返す' do
        is_expected.to eq 0x0000
      end
    end

    context '0xFFFF (16bit の最大値) を渡したとき' do
      let(:n) { 0xFFFF }

      it '0xFFFF をそのまま返す' do
        is_expected.to eq 0xFFFF
      end
    end

    context '0x10000 (16bit を 1 だけ超えた値) を渡したとき' do
      # PC=0xFFFF + 1 のケース。bit16 を捨てて 0x0000 へ wrap する。
      let(:n) { 0x10000 }

      it '0x0000 へ wrap する' do
        is_expected.to eq 0x0000
      end
    end

    context '0x12345 (上位 bit がはみ出した値) を渡したとき' do
      # ADD HL,BC のキャリーアウトを捨てるケース。下位 16bit (0x2345) が残る。
      let(:n) { 0x12345 }

      it '下位 16bit (0x2345) を返す' do
        is_expected.to eq 0x2345
      end
    end

    context '-1 (負の値) を渡したとき' do
      # JR で PC=0x0000 から逆方向にジャンプしたケース。
      # 2 の補数で 0xFFFF として解釈される。
      let(:n) { -1 }

      it '0xFFFF へ wrap する' do
        is_expected.to eq 0xFFFF
      end
    end

    context '-2 (負の値) を渡したとき' do
      # 0x0000 - 2 = -2 → 0xFFFE。
      let(:n) { -2 }

      it '0xFFFE へ wrap する' do
        is_expected.to eq 0xFFFE
      end
    end
  end
end
