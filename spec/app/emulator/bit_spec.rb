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

  describe '.wrap_u8' do
    # 引数を 8bit にマスクして wrap させる(下位 8bit のみ残す)。
    # ADD A,B のキャリーアウト、INC r / DEC r のラップなど、
    # 8bit レジスタの演算結果を正規化するときに使う。
    subject { Bit.wrap_u8(n) }

    context '0x00 を渡したとき' do
      let(:n) { 0x00 }

      it '0x00 を返す' do
        is_expected.to eq 0x00
      end
    end

    context '0xFF (8bit の最大値) を渡したとき' do
      let(:n) { 0xFF }

      it '0xFF をそのまま返す' do
        is_expected.to eq 0xFF
      end
    end

    context '0x100 (8bit を 1 だけ超えた値) を渡したとき' do
      # A=0xFF + 1 のケース。bit8 を捨てて 0x00 へ wrap する。
      let(:n) { 0x100 }

      it '0x00 へ wrap する' do
        is_expected.to eq 0x00
      end
    end

    context '0x1FE (上位 bit がはみ出した値) を渡したとき' do
      # ADD A,r のキャリーアウトを捨てるケース(0xFF + 0xFF)。下位 8bit (0xFE) が残る。
      let(:n) { 0x1FE }

      it '下位 8bit (0xFE) を返す' do
        is_expected.to eq 0xFE
      end
    end

    context '-1 (負の値) を渡したとき' do
      # DEC r で 0x00 - 1 のケース。2 の補数で 0xFF として解釈される。
      let(:n) { -1 }

      it '0xFF へ wrap する' do
        is_expected.to eq 0xFF
      end
    end

    context '-2 (負の値) を渡したとき' do
      # 0x00 - 2 = -2 → 0xFE。
      let(:n) { -2 }

      it '0xFE へ wrap する' do
        is_expected.to eq 0xFE
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

  describe '.low_4bits' do
    # 8bit 値から下位 4bit を取り出す。半キャリー(H フラグ)計算で使う。
    subject { Bit.low_4bits(value) }

    context '0x34 を渡したとき' do
      let(:value) { 0x34 }

      it '下位 4bit (0x4) を返す' do
        is_expected.to eq 0x4
      end
    end

    context '0x00 を渡したとき' do
      let(:value) { 0x00 }

      it '0x0 を返す' do
        is_expected.to eq 0x0
      end
    end

    context '0xFF を渡したとき' do
      let(:value) { 0xFF }

      it '0xF を返す' do
        is_expected.to eq 0xF
      end
    end

    context '0x0F (上位 4bit がゼロ) を渡したとき' do
      # 下位 4bit だけに値があるケース。
      let(:value) { 0x0F }

      it '0xF を返す' do
        is_expected.to eq 0xF
      end
    end

    context '0xF0 (下位 4bit がゼロ) を渡したとき' do
      # 上位 4bit だけに値があるケース。下位 4bit は 0。
      let(:value) { 0xF0 }

      it '0x0 を返す' do
        is_expected.to eq 0x0
      end
    end
  end

  describe '.u8_to_i8' do
    # u8 (0..255) を i8 (-128..127) として再解釈する(2 の補数)。
    # JR i8 / ADD SP,i8 の符号付きオフセット、signed タイル番号で使う。
    subject { Bit.u8_to_i8(value) }

    context '0x00 を渡したとき' do
      let(:value) { 0x00 }

      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context '0x7F (i8 の最大値) を渡したとき' do
      # bit7 が 0 の最大値。正の値としてそのまま扱う。
      let(:value) { 0x7F }

      it '127 を返す' do
        is_expected.to eq 127
      end
    end

    context '0x80 (bit7 が立った最小値) を渡したとき' do
      # bit7 が 1 の境界値。i8 の最小値 -128 として解釈される。
      let(:value) { 0x80 }

      it '-128 を返す' do
        is_expected.to eq(-128)
      end
    end

    context '0xFF (u8 の最大値) を渡したとき' do
      # 2 の補数で -1。DEC や JR -1 と等価。
      let(:value) { 0xFF }

      it '-1 を返す' do
        is_expected.to eq(-1)
      end
    end

    context '0x01 を渡したとき' do
      let(:value) { 0x01 }

      it '1 を返す' do
        is_expected.to eq 1
      end
    end
  end

  describe '.bit_at' do
    # 値の n 番目のビット(0 or 1)を取り出す。
    # MRI Ruby では `value[n]` で同じことができるが、DragonRuby (mruby) は未対応。
    subject { Bit.bit_at(value, n) }

    context '0x80 の bit7 を取り出すとき' do
      let(:value) { 0x80 }
      let(:n) { 7 }

      it '1 を返す' do
        is_expected.to eq 1
      end
    end

    context '0x80 の bit0 を取り出すとき' do
      let(:value) { 0x80 }
      let(:n) { 0 }

      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context '0x91 の bit0 を取り出すとき(LCDC のBG有効ビット)' do
      let(:value) { 0x91 }
      let(:n) { 0 }

      it '1 を返す' do
        is_expected.to eq 1
      end
    end

    context '0x91 の bit3 を取り出すとき' do
      let(:value) { 0x91 }
      let(:n) { 3 }

      it '0 を返す' do
        is_expected.to eq 0
      end
    end

    context '0xFF のすべてのビットを取り出すとき' do
      let(:value) { 0xFF }

      (0..7).each do |bit|
        context "bit#{bit}" do
          let(:n) { bit }

          it '1 を返す' do
            is_expected.to eq 1
          end
        end
      end
    end
  end

  describe '.set_bit' do
    # 値の n 番目のビットを on/off に設定した結果を返す
    # F レジスタの Z/N/H/C を個別更新するときに使う
    subject { Bit.set_bit(value, n, on) }

    context '0x00 の bit7 を on にしたとき' do
      let(:value) { 0x00 }
      let(:n) { 7 }
      let(:on) { true }

      it '0x80 を返す' do
        is_expected.to eq 0x80
      end
    end

    context '0xFF の bit7 を off にしたとき' do
      let(:value) { 0xFF }
      let(:n) { 7 }
      let(:on) { false }

      it '0x7F を返す(他ビットは保持)' do
        is_expected.to eq 0x7F
      end
    end

    context '0xFF の bit0 を off にしたとき' do
      let(:value) { 0xFF }
      let(:n) { 0 }
      let(:on) { false }

      it '0xFE を返す(他ビットは保持)' do
        is_expected.to eq 0xFE
      end
    end

    context '0x00 の bit4 を on にしたとき(Cフラグセット相当)' do
      let(:value) { 0x00 }
      let(:n) { 4 }
      let(:on) { true }

      it '0x10 を返す' do
        is_expected.to eq 0x10
      end
    end

    context '既に on のビットを on にしたとき(冪等)' do
      let(:value) { 0x80 }
      let(:n) { 7 }
      let(:on) { true }

      it '値は変化せず 0x80 のまま' do
        is_expected.to eq 0x80
      end
    end

    context '既に off のビットを off にしたとき(冪等)' do
      let(:value) { 0x00 }
      let(:n) { 7 }
      let(:on) { false }

      it '値は変化せず 0x00 のまま' do
        is_expected.to eq 0x00
      end
    end

    context 'on に true 以外の真値(整数1)を渡したとき' do
      # F レジスタ setter からは Bit.bit_at の戻り値(0 or 1)が渡されるケースがある
      let(:value) { 0x00 }
      let(:n) { 7 }
      let(:on) { 1 }

      it '真として扱い bit7 を立てて 0x80 を返す' do
        is_expected.to eq 0x80
      end
    end

    context 'on に nil を渡したとき' do
      let(:value) { 0xFF }
      let(:n) { 7 }
      let(:on) { nil }

      it '偽として扱い bit7 をクリアして 0x7F を返す' do
        is_expected.to eq 0x7F
      end
    end

    context '0xF0 (Z=N=H=C=1) の bit5 (H) だけ off にしたとき' do
      # F レジスタの Half-Carry だけクリア。他フラグ (Z=bit7, N=bit6, C=bit4) は保持
      let(:value) { 0xF0 }
      let(:n) { 5 }
      let(:on) { false }

      it '0xD0 を返す(Z=1, N=1, H=0, C=1)' do
        is_expected.to eq 0xD0
      end
    end
  end
end
