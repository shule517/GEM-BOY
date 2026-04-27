# コーディング規約

## 言語・コメント

- **コメント・テストの説明文(`it` / `describe` / `context`)は日本語で書く**

## RSpec

- **メソッドごとに `describe '#メソッド名'` を定義する**。複数メソッドを 1 つの `context` でまとめてラップしない。ネスト順は **`describe > context > it`** を守る(`describe` = 何をテストするか、`context` = どういう状態で)。共通 setup は `RSpec.describe ClassName` 直下に `let` で置く
- **`subject` は `describe '#メソッド名'` の直下に書く**(`let` よりも上)。各メソッドのテストはそのメソッド呼び出しを `subject` として定義し、入力のバリエーションは `context` + `let` で切り替える
- **`subject` は名前を付けず匿名形式 `subject { ... }` を使う**。参照は `is_expected.to ...`(値) または `expect { subject }.to raise_error(...)`(ブロック)で行う
- **`eq` は括弧を付けずに書く**(`eq(0)` ではなく `eq 0`)。読みやすさを揃えるため、`be`, `include`, `match` など他のマッチャも値を 1 つだけ取る場合は同様に括弧を省く
- **テストは具体的な値で検証する**。`be_empty` / `be_truthy` / `not_to be_nil` のような漠然とした述語ではなく、**期待値を直接書く**(`eq "TOBU"`, `eq 262144` など)。曖昧な検査だと実装ミスを取りこぼすため

### サンプル

共通 setup を `RSpec.describe` 直下に置き、メソッドごとに `describe` を切る:

```ruby
RSpec.describe Cartridge do
  let(:cartridge) { described_class.new(File.binread(rom_path).bytes) }
  let(:rom_path) { File.expand_path('../../../../data/tobu.gb', __FILE__) }

  describe '#title' do
    subject { cartridge.title }
    it '"TOBU" を返す' do
      is_expected.to eq 'TOBU'
    end
  end

  describe '#size' do
    subject { cartridge.size }
    it '262144 (256KB) を返す' do
      is_expected.to eq 262144
    end
  end
end
```

入力のバリエーションは `context` + `let` で切り替える:

```ruby
describe '#initialize' do
  subject { described_class.new(data) }

  context 'バイト配列を渡したとき' do
    let(:data) { [0xC3, 0x00, 0x01] }
    it 'Cartridge を返す' do
      is_expected.to be_a described_class
    end
  end

  context 'nil を渡したとき' do
    let(:data) { nil }
    it '例外を投げる' do
      expect { subject }.to raise_error(/Empty ROM/)
    end
  end
end
```
