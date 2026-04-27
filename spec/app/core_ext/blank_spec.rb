require 'app/core_ext/blank'

RSpec.describe 'core_ext/blank' do
  describe '#blank?' do
    subject { value.blank? }

    context 'nil の場合' do
      let(:value) { nil }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'false の場合' do
      let(:value) { false }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'true の場合' do
      let(:value) { true }
      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context '空文字列の場合' do
      let(:value) { '' }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context '半角スペースだけの文字列の場合' do
      let(:value) { '   ' }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context 'タブと改行だけの文字列の場合' do
      let(:value) { "\t\n" }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context '中身のある文字列の場合' do
      let(:value) { 'foo' }
      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context '0 (Numeric) の場合' do
      let(:value) { 0 }
      it 'false を返す(数値は値があるとみなす)' do
        is_expected.to eq false
      end
    end

    context '空配列の場合' do
      let(:value) { [] }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context '要素のある配列の場合' do
      let(:value) { [1] }
      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context '空ハッシュの場合' do
      let(:value) { {} }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context '要素のあるハッシュの場合' do
      let(:value) { { a: 1 } }
      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context '通常の Object の場合' do
      let(:value) { Object.new }
      it 'false を返す' do
        is_expected.to eq false
      end
    end
  end

  describe '#present?' do
    subject { value.present? }

    context 'nil の場合' do
      let(:value) { nil }
      it 'false を返す' do
        is_expected.to eq false
      end
    end

    context '中身のある文字列の場合' do
      let(:value) { 'foo' }
      it 'true を返す' do
        is_expected.to eq true
      end
    end

    context '0 (Numeric) の場合' do
      let(:value) { 0 }
      it 'true を返す' do
        is_expected.to eq true
      end
    end
  end
end
