# コーディング規約

## 命名

- **変数名は略さない**。`c` / `mmu_` / `tmp` のような短縮形を使わず、対象を素直に表す名前(`cpu` / `mmu` / `byte` など)で書く。読み手が省略の意図を毎回推測する手間を省き、grep もしやすくするため。`let(:cpu)` の中で同名のローカル変数 `cpu` を作って組み立て直すパターンも OK(let が最終戻り値で memoize される)
  ```ruby
  # bad
  let(:cpu) do
    c = described_class.new(mmu)
    c.a = 0x01
    c
  end

  # good
  let(:cpu) do
    cpu = described_class.new(mmu)
    cpu.a = 0x01
    cpu
  end
  ```
  ループカウンタの `i` / `j` や、引数として明らかな `e`(rescue の例外)程度の慣用は許容するが、ドメイン上意味のある変数(CPU、MMU、register、address など)は必ずフルネームで書く

## 言語・コメント

- **コメント・テストの説明文(`it` / `describe` / `context`)は日本語で書く**
- **Game Boy の仕様をコメントに書くときは、必ず Pan Docs の該当ページ URL を併記する**。引用元が辿れないと「これが正しいのか実装側のクセなのか」が後で判別できなくなるため。複数の仕様セクションを 1 つのクラスにまとめている場合は、各セクションの直前に対応する URL を置く
  ```ruby
  # === メモリマップ ===
  # Pan Docs: https://gbdev.io/pandocs/Memory_Map.html
  #
  #   0x8000-0x9FFF  VRAM
  #   ...

  # シリアルポート送信プロトコル
  # Pan Docs: https://gbdev.io/pandocs/Serial_Data_Transfer_(Link_Cable).html
  ```
  Pan Docs に該当ページがない補助情報(gbops オペコード表など)は別 URL でも可。出典そのものを略さない

## RSpec

- **メソッドごとに `describe '#メソッド名'` を定義する**。複数メソッドを 1 つの `context` でまとめてラップしない。ネスト順は **`describe > context > it`** を守る(`describe` = 何をテストするか、`context` = どういう状態で)
- **`let` / `before` は `describe '#メソッド名'` の中に書く**。`RSpec.describe ClassName` 直下に共通 `let` を置かない。**メソッドごとのテストを完全に独立させる**ためで、上位スコープに置くと暗黙のグローバル状態のように振る舞い、別メソッドのテストが意図せず依存してしまう。同じ setup が複数 describe で必要なら、その setup ごと describe 内に書き写すこと(DRY より独立性を優先)
- **`subject` は `describe '#メソッド名'` の直下に書く**(`let` よりも上)。各メソッドのテストはそのメソッド呼び出しを `subject` として定義し、入力のバリエーションは `context` + `let` で切り替える
- **`subject` は名前を付けず匿名形式 `subject { ... }` を使う**。参照は `is_expected.to ...`(値) または `expect { subject }.to raise_error(...)`(ブロック)で行う
- **`eq` は括弧を付けずに書く**(`eq(0)` ではなく `eq 0`)。読みやすさを揃えるため、`be`, `include`, `match` など他のマッチャも値を 1 つだけ取る場合は同様に括弧を省く
- **テストは具体的な値で検証する**。`be_empty` / `be_truthy` / `not_to be_nil` のような漠然とした述語、および `be >= 16` / `be > 0` / `be < 256` のような大小比較も使わず、**期待値を直接書く**(`eq "TOBU"`, `eq 262144`, `eq 16` など)。曖昧な検査だと実装ミスを取りこぼすため。「最低 N 以上消費する」のような不等号のテストは、**実装が偶然多めに動いても気づけない / 仕様が変わったときに失敗してくれない**。「ちょうど 16 サイクル」「ちょうど 4 回 fetch する」のように、その実行で起きる正確な値を書くこと(計算が面倒なら一度実行して実測値を貼る)

### サンプル

メソッドごとに `describe` を切り、各 `describe` 内に必要な `let` をそのまま書き下す。同じ setup が必要でも上位に括り出さない:

```ruby
RSpec.describe Cartridge do
  describe '#title' do
    subject { cartridge.title }
    let(:cartridge) { described_class.new(File.binread(rom_path).bytes) }
    let(:rom_path) { File.expand_path('../../../../data/tobu.gb', __FILE__) }

    it '"TOBU" を返す' do
      is_expected.to eq 'TOBU'
    end
  end

  describe '#size' do
    subject { cartridge.size }
    let(:cartridge) { described_class.new(File.binread(rom_path).bytes) }
    let(:rom_path) { File.expand_path('../../../../data/tobu.gb', __FILE__) }

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
