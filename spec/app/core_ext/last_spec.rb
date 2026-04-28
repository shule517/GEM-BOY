require 'app/core_ext/last'

RSpec.describe 'core_ext/last' do
  describe '#last' do
    subject { string.last(limit) }

    context '引数を省略したとき' do
      subject { string.last }
      let(:string) { 'abcdef' }
      it '末尾1文字を返す' do
        is_expected.to eq 'f'
      end
    end

    context '文字数より小さい数を渡したとき' do
      let(:string) { 'abcdef' }
      let(:limit) { 3 }
      it '末尾 limit 文字を返す' do
        is_expected.to eq 'def'
      end
    end

    context '文字数と等しい数を渡したとき' do
      let(:string) { 'abcdef' }
      let(:limit) { 6 }
      it '文字列全体を返す' do
        is_expected.to eq 'abcdef'
      end
    end

    context '文字数より大きい数を渡したとき' do
      let(:string) { 'abc' }
      let(:limit) { 10 }
      it '文字列全体を返す' do
        is_expected.to eq 'abc'
      end
    end

    context '0 を渡したとき' do
      let(:string) { 'abcdef' }
      let(:limit) { 0 }
      it '空文字列を返す' do
        is_expected.to eq ''
      end
    end

    context '空文字列に対して呼び出したとき' do
      let(:string) { '' }
      let(:limit) { 5 }
      it '空文字列を返す' do
        is_expected.to eq ''
      end
    end

    context 'シリアルバッファのような長い文字列を 500 文字に切り詰めるとき' do
      let(:string) { 'x' * 1000 }
      let(:limit) { 500 }
      it '末尾 500 文字を返す' do
        expect(subject.length).to eq 500
      end
    end
  end
end
