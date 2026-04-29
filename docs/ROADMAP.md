# GEM BOY — 実装ロードマップ

DragonRuby Game Toolkit で Ruby 製 Game Boy エミュレータ「**GEM BOY**」を作る。

## 戦略: 3 段マイルストーンを最短経路で順番に達成

「Blargg を全 Pass させてから先に進む」旧戦略も「Nintendo ロゴ一発狙い」中継戦略もやめ、**3 つの視覚的マイルストーンを近い順に並べて段階的に達成する**ルートに改める。

1. **HELLO WORLD 表示**(`hello.gb` を skip_boot 起動)★ 第一マイルストーン
2. **Nintendo ロゴ表示**(ブート ROM 経由 + スクロールイン + チャイム)★ 第二マイルストーン
3. **tobu.gb タイトル画面**(MBC1 + スプライト + 入力)★ 第三マイルストーン

利点:

- **「画面に何か出る」最初の瞬間が最も早く来る**(約 5〜6h で HELLO WORLD)。長時間進捗が見えない不安を解消
- 各マイルストーン到達時に **PPU / CPU / MMU の動作確認済みコンポーネント**が増えていく → 次段階のデバッグ時に「これは動いている」と切り分けがしやすい
- HELLO WORLD で PPU が動いているとブート ROM 挑戦時に「PPU は OK、犯人は CPU 側」と限定でき、Nintendo ロゴ挑戦時の Blargg 診断(E-6)の時間が短くなる傾向

## 全体像

| フェーズ | 内容 | 想定時間 | 到達点 | 進捗 |
|---|---|---|---|---|
| A. 土台 | Cartridge + MMU 骨組み + シリアル出力 | 3〜4h | ROM が読める、シリアル出力動く | 3/3 [完了] |
| B. CPU 基本命令 | hello.gb が使う命令一式(CB-prefix なし) | 2〜2.5h | HELLO WORLD に必要な命令を踏める | 1/2 |
| C. PPU 最小実装 | LCDC + LY + BG タイル描画(SCY=0 固定) | 2〜2.5h | タイルが描ける | 0/2 |
| D. HELLO WORLD 表示 | skip_boot 起動 + 画面確認 | 1h | **画面に "Hello World!" 表示** ★第一 | 0/2 |
| E. Nintendo ロゴ表示 | ブート ROM 用追加命令 + CB-prefix + ブート ROM mapping + スクロール + チャイム | 3〜7h | **正しい Nintendo ロゴ + ブートチャイム** ★第二 | 0/8 |
| F. tobu.gb タイトル | MBC1 + スプライト + 入力 + タイマー | 6.5〜10h | **tobu.gb タイトル表示** ★第三 | 0/5 |

合計 22 ステップ、想定 17.5〜27h。**現在 4 ステップ完了(フェーズ A 完走 + B-1 完了)**。

## 進捗チェックリスト

### フェーズ A: 土台 [完了]
- [x] A-1: プロジェクト初期化と画面表示
- [x] A-2: ROM 読み込み
- [x] A-3: MMU 骨組み + シリアル出力

### フェーズ B: CPU 基本命令(hello.gb 用)
- [x] B-1: CPU 骨組み(NOP のみ)
- [ ] B-2: hello.gb が使う命令一式

### フェーズ C: PPU 最小実装
- [ ] C-1: PPU 骨組み(LCDC, LY, モード)
- [ ] C-2: BG タイル描画(SCY=0 固定)

### フェーズ D: HELLO WORLD 表示
- [ ] D-1: skip_boot モード実装
- [ ] D-2: hello.gb 起動 → "Hello World!" 表示 ★第一マイルストーン

### フェーズ E: Nintendo ロゴ表示
- [ ] E-1: ブート ROM 用 CPU 命令追加(B-2 で省いた分)
- [ ] E-2: CB-prefix `BIT n,r` / `RL r` 実装
- [ ] E-3: PPU SCY スクロール対応
- [ ] E-4: MMU にブート ROM mapping 追加
- [ ] E-5: ブート ROM 起動 → 崩れたロゴ観察
- [ ] E-6: Blargg 診断ループ(崩れたとき、症状から推測した順序で)
  - [ ] E-6a: `06-ld r,r.gb` で LD 命令検証
  - [ ] E-6b: `05-op rp.gb` で 16bit / INC・DEC 検証
  - [ ] E-6c: `04-op r,imm.gb` で即値 ALU 検証
  - [ ] E-6d: `11-op a,(hl).gb` でメモリ間接 ALU 検証
- [ ] E-7: 修正済み Nintendo ロゴ表示 ★第二マイルストーン
- [ ] E-8: ブートチャイム再生(NR14 trigger フック)

### フェーズ F: tobu.gb タイトル
- [ ] F-1: MBC1 実装
- [ ] F-2: スプライト描画
- [ ] F-3: Joypad 入力
- [ ] F-4: Timer (DIV / TIMA)
- [ ] F-5: tobu.gb タイトル表示 ★第三マイルストーン

## 三段マイルストーン

1. **HELLO WORLD 表示**(D-2 完了時, 約 5〜6h):画面に文字が出た瞬間。CPU 基本命令と PPU が連動して動いた証拠。「自分で書ける範囲のコードが正しく解釈・描画される」最小ループの完成
2. **Nintendo ロゴ表示**(E-7 完了時, 約 8〜13h):スクロールインのロゴ。**ブート ROM 完走** = CPU + MMU + PPU + フラグ計算 + CB-prefix が全部揃った証拠。E-8 でブートチャイム
3. **tobu.gb タイトル**(F-5 完了時, 約 14.5〜23h):実ゲームが起動。MBC1 + スプライト + 入力 + タイマー が揃った証拠

## 前提

- DragonRuby Game Toolkit がインストール済み(プロジェクトルートに `dragonruby` バイナリ配置済み)
- Ruby 4.0.3 + RSpec(`bundle exec rspec` で実行)
- Pan Docs(https://gbdev.io/pandocs/)を別タブで開いておく
- gbops オペコード表(https://izik1.github.io/gbops/)を別タブで開いておく
- ROM 素材の入手と配置(取得済み):
  - `data/hello.gb`(gitendo/helloworld) ← フェーズ D で使用
  - `data/dmg_boot.bin`(SameBoy 同梱の SameBoot 実装、256B) ← フェーズ E で使用
  - `data/cpu_instrs/` の Blargg 個別 ROM(retrio/gb-test-roms 由来) ← E-6 診断時に使用
  - `data/tobu.gb` ← フェーズ F で使用
  - `data/game-boy-startup.wav` ← E-8 で使用

## ディレクトリ構造(最終形)

```
GEM-BOY/
├── app/
│   ├── main.rb              # DragonRuby tick エントリ(args 依存はここだけ)
│   ├── emulator/            # 純 Ruby のエミュレータコア
│   │   ├── cartridge.rb     # カートリッジ
│   │   ├── mmu.rb           # メモリ管理 + シリアル出力(E-4 でブート ROM mapping 追加)
│   │   ├── cpu.rb           # CPU(B-1 完了:骨組み + NOP のみ。B-2 で hello.gb 用、E-1/E-2 でブート ROM 用に拡充)
│   │   ├── ppu.rb           # 描画(C で骨組み + BG タイル、E-3 で SCY スクロール対応)
│   │   ├── boot_rom.rb      # ブート ROM ローダ(E-4 で作成、任意で別ファイル化)
│   │   ├── mbc1.rb          # MBC1 バンク切り替え(F-1 で作成)
│   │   └── emulator.rb      # 統合
│   └── core_ext/            # ビルトインクラス拡張(blank? など)
├── data/                    # ROM 素材(.gitignore 対象)
├── spec/                    # MRI Ruby で実行する RSpec
└── docs/
```

**3 層分離**: `app/main.rb`(DragonRuby 依存) / `app/emulator/`(純 Ruby、args 非依存) / `app/core_ext/`(ビルトイン拡張)。`app/emulator/` は MRI Ruby + RSpec で単体テスト可能。

---

# フェーズ A: 土台 [完了]

3 ステップ完了済み。実装内容:

- **A-1**: `app/main.rb` で「GEM BOY」表示
- **A-2**: `app/emulator/cartridge.rb` で ROM ヘッダ読み取り、`Cartridge.new(bytes)` の純 Ruby インターフェイス
- **A-3**: `app/emulator/mmu.rb` でメモリマップとシリアル出力。スペースキーで `'A'` がシリアル送信される動作確認済み

詳細は `git log` を参照。

---

# フェーズ B: CPU 基本命令(hello.gb 用)

`hello.gb` の実行に必要な Sharp LR35902(Game Boy CPU)命令を実装する。**ブート ROM が使う命令の一部のみ**で済む(CB-prefix は不要、`PUSH/POP/CALL/RET` も hello.gb 次第で省略可能)。残りの命令はフェーズ E で追加する。

CPU リファレンス:
- Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html
- gbops オペコード表: https://izik1.github.io/gbops/
- RGBDS 命令リファレンス: https://rgbds.gbdev.io/docs/gbz80.7

## ステップ B-1: CPU 骨組み (1時間) [完了]

**目標**: CPU クラスの土台を作り、未実装命令を踏むと例外で停止する状態にする。

実装内容:

- `app/emulator/cpu.rb` に CPU クラスを追加(レジスタ A/B/C/D/E/H/L/F + SP/PC + IME/halted、すべて初期値 0 / false)
- `step` / `run(cycles_target)` / `fetch_byte` / `fetch_word` を実装。HALT 中は fetch せず 4 サイクルだけ消費する分岐込み
- 256 要素の `@opcodes` テーブルを用意し、現状は **NOP (0x00) のみ** 実装。それ以外を踏むと `Unimplemented opcode 0xXX at PC=0xYYYY` で例外停止
- `spec/app/emulator/cpu_spec.rb` で `#initialize` / `#step` / `#build_opcode_table` / `#run` を検証

詳細は `git log` を参照。

---

## ステップ B-2: hello.gb が使う命令一式 (1〜1.5時間)

**目標**: `data/hello.gb` の実行に必要な命令を網羅する。**CB-prefix と一部のブート ROM 専用命令はスキップ**(フェーズ E で追加)。

### 実装する命令カテゴリ(おおよその範囲)

`hello.gb` は典型的に「LCD 無効化 → タイルデータ転送 → タイルマップ書き込み → BGP 設定 → LCD 有効化 → 無限ループ」の構造で、以下が中心:

| カテゴリ | 命令 | 備考 |
|---|---|---|
| **8bit ロード** | `LD r,n8` / `LD r,r'` / `LD (HL),A` / `LD (HL+),A` | hello.gb の中心命令 |
| **LDH(I/O 専用)** | `LDH (n8),A` (0xE0) / `LDH A,(n8)` (0xF0) | LCDC や BGP の設定 |
| **16bit ロード** | `LD HL,n16` / `LD SP,n16` / `LD BC,n16` / `LD DE,n16` | アドレスのセット |
| **8bit 算術/論理** | `XOR A` / `OR A` / `CP n8` | 限定的 |
| **INC/DEC** | `INC HL` / `DEC B` / `DEC C` 等 | ループカウンタ用 |
| **ジャンプ** | `JR n8` / `JR cc,n8` | 短距離分岐(ループ) |
| **その他** | `NOP` / `HALT` / `DI` | アイドル |

### 実装の進め方

- フラグレジスタ F は **bit7=Z, bit6=N, bit5=H, bit4=C**(下位 4bit は常に 0)
- フラグ計算ヘルパー `set_flags(z:, n:, h:, c:)` を作って共有
- HL/BC/DE のペアアクセサ(`hl` / `hl=` 等)を先に作ると後の命令が一気に楽になる
- **未実装命令で停止** する設計を活かし、**hello.gb を実行 → 停止 → そのオペコードを追加** のループで進める。「全部書いてからテスト」より「**動かしながら必要分だけ追加**」が推奨

### 動作確認

`spec/app/emulator/cpu_spec.rb` の `#build_opcode_table` 配下に各命令の単体テストを追加。`hello.gb` を直接実行する統合テストは D-2 で行う。

### フラグ計算の罠

- `INC r` / `DEC r` は **C フラグを保持**(他のフラグだけ更新)
- `INC rr` / `DEC rr`(16bit)は **フラグを一切変更しない**
- `XOR A` で Z=1、`OR A` も同様(自分との論理演算は flag のみ更新意図で多用される)

---

# フェーズ C: PPU 最小実装

`hello.gb` および ブート ROM が画面に表示するのは **BG タイルのみ**(スプライトもウィンドウも使わない)。最小限の PPU で済む。**SCY スクロール対応はフェーズ E**(Nintendo ロゴで必須)に回す。

PPU リファレンス:
- Pan Docs Rendering: https://gbdev.io/pandocs/Rendering.html
- Pan Docs Tile Data: https://gbdev.io/pandocs/Tile_Data.html
- Pan Docs LCDC: https://gbdev.io/pandocs/LCDC.html

## ステップ C-1: PPU 骨組み(LCDC, LY, モード) (1時間)

**目標**: PPU が時間経過とともに `LY` をインクリメントし、4 つのモードを遷移するようにする。

### モード遷移(456 ドット = 1 スキャンライン)

```
LY = 0..143 (描画ライン):
  Mode 2 (OAM Scan):  80 ドット
  Mode 3 (Drawing):  172 ドット(本実装では固定で良い)
  Mode 0 (HBlank):   204 ドット
  → LY を +1

LY = 144..153 (VBlank):
  Mode 1 (VBlank): 456 ドット × 10 ライン
  → LY=154 で 0 に戻る
```

### 実装

```ruby
# app/emulator/ppu.rb
class PPU
  LCDC = 0xFF40
  STAT = 0xFF41
  SCY  = 0xFF42
  SCX  = 0xFF43
  LY   = 0xFF44
  LYC  = 0xFF45
  BGP  = 0xFF47

  SCREEN_WIDTH  = 160
  SCREEN_HEIGHT = 144

  def initialize(mmu)
    @mmu = mmu
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(SCREEN_WIDTH * SCREEN_HEIGHT, 0)
  end

  attr_reader :framebuffer

  # CPU が消費したサイクル数だけ PPU も進める
  def step(cycles)
    return unless lcd_on?
    @cycles += cycles
    if @cycles >= 456
      @cycles -= 456
      render_scanline if @ly < 144
      @ly = (@ly + 1) % 154
      @mmu.write_io_direct(LY, @ly)
    end
  end

  private

  def lcd_on?
    (@mmu.read(LCDC) & 0x80) != 0
  end

  def render_scanline
    # C-2 で実装
  end
end
```

### 動作確認

`step(70224)` (= 1 フレーム分のサイクル) 程度を回し、`@ly` が 0..153 を循環することを確認。

---

## ステップ C-2: BG タイル描画(SCY=0 固定) (1〜1.5時間)

**目標**: VRAM の Tile Data + Tile Map から 1 スキャンライン分のピクセルを生成する。**SCY/SCX は読み込むけど 0 固定前提でコードは書く**(`hello.gb` はスクロールしない)。

### 描画ロジック

各スキャンライン (`LY`) について:

1. BG マップ上の Y 座標: `bg_y = LY`(SCY=0 前提なので加算不要、ただし SCY を読む箇所は明示しておく)
2. Tile Map のどの行か: `tile_row = bg_y / 8`、その中の何ラインか: `pixel_y = bg_y % 8`
3. Tile Map のアドレス(LCDC bit3 で 0x9800 か 0x9C00): `map_base + tile_row * 32`
4. 各ピクセル X (0..159):
   - `bg_x = X`
   - `tile_col = bg_x / 8`、`pixel_x = bg_x % 8`
   - Tile Map から **タイル番号**を取得
   - LCDC bit4 で Tile Data の解釈方式を選ぶ(0x8000 unsigned / 0x8800 signed)
   - **Tile Data から 16 バイト = 1 タイル分**を取得し、(pixel_x, pixel_y) のドットを取り出す
   - BGP パレットで色を変換 → framebuffer に書き込み

### 1 タイルの 2bpp デコード

1 タイル = 16 バイト。各行(2 バイト)= 8 ピクセル。
- バイト 1 = ピクセルの bit0 を並べたもの
- バイト 2 = ピクセルの bit1 を並べたもの

```ruby
def pixel_color(tile_data_addr, pixel_x, pixel_y)
  byte1 = @mmu.read(tile_data_addr + pixel_y * 2)
  byte2 = @mmu.read(tile_data_addr + pixel_y * 2 + 1)
  bit = 7 - pixel_x
  ((byte2 >> bit) & 1) << 1 | ((byte1 >> bit) & 1)  # 0..3
end
```

### 動作確認

VRAM に手で適当なタイル + マップを書いて、`render_scanline` を 144 回呼んで framebuffer 全体を埋める。`framebuffer.tally` で複数色が出ていれば OK。

---

# フェーズ D: HELLO WORLD 表示 ★第一マイルストーン

skip_boot 起動で `hello.gb` を直接実行し、画面に "Hello World!" を表示する。**フェーズ B + C の組み合わせが正しく動いているかの最小統合テスト**。

## ステップ D-1: skip_boot モード実装 (30分)

**目標**: ブート ROM を使わず、直接 `PC=0x0100` から起動できるようにする。ブート ROM 終了直後の実機状態をハードコードで再現する。

### CPU 初期値の差し替え

```ruby
# app/emulator/cpu.rb
class CPU
  def initialize(mmu, skip_boot: false)
    @mmu = mmu
    if skip_boot
      # ブート ROM 終了直後の実機値(DMG)
      # Pan Docs: https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers
      @a = 0x01; @f = 0xB0
      @b = 0x00; @c = 0x13
      @d = 0x00; @e = 0xD8
      @h = 0x01; @l = 0x4D
      @sp = 0xFFFE
      @pc = 0x0100
    else
      @a = @b = @c = @d = @e = @h = @l = @f = 0
      @sp = 0; @pc = 0
    end
    @ime = false
    @halted = false
    @opcodes = build_opcode_table
  end
end
```

### MMU 側の I/O レジスタ初期値

ブート ROM が設定する I/O レジスタ(LCDC = 0x91、BGP = 0xFC など)も、skip_boot モードでは MMU 初期化時に同じ値を入れておく必要がある。Pan Docs の Power-Up Sequence の一覧を参照。

### main.rb 統合

```ruby
# app/main.rb
ROM_PATH = 'data/hello.gb'
SKIP_BOOT = true

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  args.state.mmu = MMU.new(args.state.cartridge)
  args.state.cpu = CPU.new(args.state.mmu, skip_boot: SKIP_BOOT)
  args.state.ppu = PPU.new(args.state.mmu)
end
```

### 動作確認

`PC` が `0x0100` で開始、レジスタが上記の値になっていることを RSpec で確認。

---

## ステップ D-2: hello.gb 起動 → "Hello World!" 表示 (30分) ★第一マイルストーン

**目標**: `data/hello.gb` を起動して画面に **「Hello World!」が表示される**こと。

### 観察チェックリスト

| 現象 | 推定原因 | 次のアクション |
|---|---|---|
| 即クラッシュ(未実装オペコード) | B-2 の漏れ | 該当命令を実装 → 再挑戦 |
| 黒画面のまま無反応 | LCDC の ON 検知不可 / PPU の `step` が回っていない | C-1 の `lcd_on?` と `step` を見直す |
| 画面に何かが出るが文字にならない | Tile Data / Tile Map の解釈ミス | C-2 のタイルアドレッシング(LCDC bit4)と 2bpp デコードを確認 |
| 文字色が反転している | BGP パレット未対応 | BGP レジスタ(0xFF47)の参照を追加 |
| **"Hello World!" が出る** | **成功** | ★ 第一マイルストーン達成 |

ここで「画面に文字が出る」だけでも **第一マイルストーン達成**。これで PPU の正しさが裏取りできるので、フェーズ E のブート ROM 挑戦に進んだとき「PPU は OK、犯人は CPU 側」と切り分け可能になる。

---

# フェーズ E: Nintendo ロゴ表示 ★第二マイルストーン

ブート ROM 全体を完走させ、**スクロールインする Nintendo ロゴ**を表示する。HELLO WORLD で動作確認済みの PPU と CPU 命令一式を土台にして、不足分(CB-prefix・ブート ROM 専用命令・スクロール・ブート ROM mapping)を追加していく。

## ステップ E-1: ブート ROM 用 CPU 命令追加 (30分〜1時間)

**目標**: ブート ROM が使うが hello.gb では使わなかった命令を追加する。

### 想定される追加命令

`hello.gb` で省いた命令のうち、ブート ROM が使うもの:

| カテゴリ | 命令 |
|---|---|
| **メモリ間接 ALU** | `ADD A,(HL)` / `CP (HL)` / `XOR (HL)` 等 |
| **スタック** | `PUSH BC/DE/HL/AF` / `POP BC/DE/HL/AF` |
| **コール/リターン** | `CALL n16` / `CALL cc,n16` / `RET` / `RET cc` / `RETI` / `RST n` |
| **ロード追加** | `LD A,(BC)` / `LD A,(DE)` / `LD (BC),A` / `LD (DE),A` / `LD (HL-),A` / `LD A,(HL+)` / `LD A,(HL-)` / `LD (n16),A` / `LD A,(n16)` |
| **絶対ジャンプ** | `JP n16` / `JP cc,n16` / `JP HL` |
| **ローテート(非 CB)** | `RLCA` / `RLA` / `RRCA` / `RRA` |
| **その他** | `EI` / `DI` / `STOP` / `DAA` / `CPL` / `SCF` / `CCF` |

### 進め方

B-2 と同じ「動かしながら必要分だけ追加」の流れで進める。`data/dmg_boot.bin` を E-4 で MMU に接続するまでは実行できないので、E-4 と E-1 を交互に進めても OK。

---

## ステップ E-2: CB-prefix `BIT n,r` / `RL r` 実装 (1時間)

**目標**: 0xCB に続く 8bit でオペコードを解釈する CB 系命令を実装。ブート ROM のロゴ展開で使われる。

CB-prefix 命令は全 256 種類だが、ロゴ展開で使うのは:
- **`BIT n,r`** (0x40-0x7F): 1 ビット検査(Z = !bit_n(r), N=0, H=1)
- **`RL r`** (0x10-0x17): キャリー経由の左ローテート

### 実装方針

256 個の表を作り、すべて埋める(BIT/RES/SET/RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL の系統的な組み合わせ)。

```ruby
# app/emulator/cpu.rb の中で
def execute_cb
  opcode = fetch_byte
  # opcode の上位 2bit で大別: 00=ローテート系, 01=BIT, 10=RES, 11=SET
  # 下位 3bit でレジスタ選択 (B/C/D/E/H/L/(HL)/A)
  # ...
end
```

### フラグ計算の罠

- `RLA`(非 CB, 0x17)は Z フラグを **常にクリア**。`CB RL`(0xCB 0x10-0x17)は **結果が 0 なら Z を立てる**(挙動が違う)
- `BIT n,r` は Z=!(bit_n(r))、N=0、H=1、**C は保持**

### 動作確認

`BIT 7, A` を A=0x80 で実行 → Z=0、A=0x00 で実行 → Z=1。
`RL B` (キャリー=1, B=0x80) 実行 → B=0x01, キャリー=1。

---

## ステップ E-3: PPU SCY スクロール対応 (30分)

**目標**: ブート ROM のロゴスクロールイン演出のため、PPU の BG 描画に `SCY` を反映する。

C-2 で `SCY=0` 固定にしていた箇所を、`bg_y = (LY + SCY) & 0xFF` に変更するだけ。`SCX` も同様に対応しておくと将来の拡張で楽。

### 動作確認

VRAM に固定タイルを書き、`SCY` を 1 ずつ増やして `render_scanline` を呼ぶと縦スクロールしていく。framebuffer の差分で確認可能。

---

## ステップ E-4: MMU にブート ROM mapping 追加 (30分)

**目標**: MMU を改造し、ブート ROM 期間中は `0x0000-0x00FF` をブート ROM (`data/dmg_boot.bin`) にマップする。

### MMU 改造

```ruby
# app/emulator/mmu.rb
class MMU
  BOOT_ROM_OFF = 0xFF50  # 0x01 を書き込むとブート ROM 切断

  def initialize(cartridge, boot_rom: nil)
    @cartridge = cartridge
    @boot_rom = boot_rom
    @boot_rom_active = !boot_rom.nil?
    # ... 既存の初期化
  end

  def read(address)
    return @boot_rom[address] if @boot_rom_active && address < 0x0100
    # ... 既存のルーティング
  end

  def write(address, value)
    value &= 0xFF
    if address == BOOT_ROM_OFF && value == 0x01
      @boot_rom_active = false
    end
    # ... 既存の write
  end
end
```

### main.rb 統合

```ruby
# app/main.rb
ROM_PATH = 'data/tobu.gb'  # ブート ROM を抜けた直後の遷移先(ロゴ表示には何でも良い)
SKIP_BOOT = false

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  boot_rom = args.gtk.read_file('data/dmg_boot.bin').bytes
  args.state.mmu = MMU.new(args.state.cartridge, boot_rom: boot_rom)
  args.state.cpu = CPU.new(args.state.mmu, skip_boot: SKIP_BOOT)
  args.state.ppu = PPU.new(args.state.mmu)
end
```

### 動作確認

クラッシュしなければ OK(まだ画面には何も出ない or 崩れたロゴが出る)。

---

## ステップ E-5: ブート ROM 起動 → 崩れたロゴ観察 (30分)

**目標**: ブート ROM が動き始める瞬間を確認する。何が崩れているかを目視する。

### 観察チェックリスト

| 現象 | 推定原因 | 次のアクション |
|---|---|---|
| 即クラッシュ(未実装オペコード) | E-1/E-2 の漏れ | 該当命令を実装 → 再挑戦 |
| 黒画面のまま無反応 | LCDC 検知 / PPU step 不調 | C-1, E-3 を見直す |
| ロゴの一部が出るが歪む | タイル描画ロジックが微妙にズレ | C-2/E-3 を確認 |
| **崩れたロゴが出る** | **CPU バグ濃厚 → E-6 で Blargg 診断** | E-6 へ進む |
| **正しいロゴが流れる** | **奇跡のショートカット成功** | E-6 をスキップして E-7 へ |

HELLO WORLD で PPU が動いている前提なので、**「画面に何か出る」が崩れる場合は CPU 側のバグである可能性が高い**(ロゴが派手に崩れていなければ E-6 をスキップして E-7 へ進む選択肢もある)。

---

## ステップ E-6: Blargg 診断ループ(条件付き、0〜4時間)

**条件**: E-5 で「崩れたロゴ」「黒画面」「実行が途中で止まる」のいずれかが起きたとき実行。

`ROM_PATH` を Blargg の個別 ROM に切り替えて起動 → ターミナルにテスト名と結果(`Passed` または `Failed XX`)が出る。`Failed XX` の `XX` はテストケース番号。

```ruby
# app/main.rb
ROM_PATH = 'data/cpu_instrs/06-ld r,r.gb'   # 切り替えてテスト
```

### 症状から推測する実行順序

| ロゴの崩れ方 | 推奨 Blargg | サブステップ |
|---|---|---|
| 即停止 / 一切動かない | `06-ld r,r.gb` | E-6a |
| ロゴ位置がズレる / スクロール変 | `05-op rp.gb` | E-6b |
| ロゴのドットが歪む | `04-op r,imm.gb` | E-6c |
| ロゴ転送が崩れる(部分的に出る) | `11-op a,(hl).gb` | E-6d |

順番に走らせて Pass を取っていく。Pass したら `ROM_PATH` を次に切り替え。

### サブステップ E-6a〜E-6d

| サブステップ | ROM | 検証対象 |
|---|---|---|
| E-6a | `06-ld r,r.gb` | 全 LD 命令(レジスタ間転送・即値・メモリ) |
| E-6b | `05-op rp.gb` | 16bit ロード/算術 + INC/DEC |
| E-6c | `04-op r,imm.gb` | `ADD A,n` / `SUB n` / `AND n` / `OR n` / `XOR n` / `CP n` |
| E-6d | `11-op a,(hl).gb` | `(HL)` 経由の ALU 命令(`ADD A,(HL)` など) |

### 重要なフラグの罠(再掲)

- `INC r` / `DEC r`: **C フラグを保持**(他は更新)
- `INC rr` / `DEC rr`: **フラグを一切変更しない**
- `ADD HL,rr`: Z フラグを保持、N=0、H/C は bit11/15 で計算
- `ADD SP,r8`: H/C は **下位ニブル/下位バイト**で計算

---

## ステップ E-7: 修正済み Nintendo ロゴ表示 (30分) ★第二マイルストーン

**目標**: E-6 で Blargg を Pass させた CPU で再びブート ROM を起動。

```ruby
# app/main.rb
ROM_PATH = 'data/tobu.gb'
SKIP_BOOT = false
```

ブート ROM が完走すると:

1. グレー → 黒の画面遷移
2. **Nintendo ロゴが画面中央に上から下へスクロールイン**
3. 「ピーン」音(E-8 で実装、本ステップでは無音)
4. 約 1 秒静止
5. PC=0x0100 へジャンプ → カートリッジ本体へ

これで **第二マイルストーン達成**。

---

## ステップ E-8: ブートチャイム再生(NR14 trigger フック) (30分)

**目標**: ブート ROM が APU の Channel 1 を trigger した瞬間を MMU で検知し、`data/game-boy-startup.wav` を再生する。APU 本体は実装せず、**WAV 再生で代替**するライト実装。

### MMU にチャイムフック追加

```ruby
# app/emulator/mmu.rb
class MMU
  attr_accessor :on_chime_trigger

  # APU レジスタ Channel 1 周波数上位
  # Pan Docs: https://gbdev.io/pandocs/Audio_Registers.html#ff14--nr14-channel-1-period-high--control
  NR14 = 0xFF14
  NR14_TRIGGER_BIT = 0x80

  def write(addr, value)
    # ... 既存の処理

    # ブートチャイム検知(初回 trigger のみ)
    if addr == NR14 && (value & NR14_TRIGGER_BIT) != 0 && !@chime_triggered
      @chime_triggered = true
      @on_chime_trigger&.call
    end
  end
end
```

### main.rb 側でコールバック登録

```ruby
# app/main.rb
def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  args.state.mmu = MMU.new(args.state.cartridge)
  args.state.mmu.on_chime_trigger = -> {
    args.outputs.sounds << 'data/game-boy-startup.wav'
  }
end
```

### 一発フラグの理由

ブート ROM は **チャイムを 2 回 trigger する**(低音 → 待ちループ → 高音)。今回の WAV は既に「ポイーン」2 音入りの録音なので、**毎回鳴らすと 4 音重なって崩れる**。`@chime_triggered` で初回だけ拾い、以降は無視する。

### 受け入れ条件

- ブート ROM が完走する瞬間に「ポイーン」が 1 回だけ鳴る
- ロゴのスクロールインと音のタイミングが大きくズレない(数フレームの遅延は許容)
- 2 回目の起動でも正常に鳴る(`@chime_triggered` が setup でリセットされること)

### 補足

将来 APU 本体を実装するときは、この WAV 再生フックを外して、Channel 1 の矩形波生成 + envelope に置き換える。今はあくまで**演出としての音**であり、実機の APU レジスタ値からの音色生成ではない。

---

# フェーズ F: tobu.gb タイトル画面 ★第三マイルストーン

ブート ROM が完走した後、tobu.gb の **タイトル画面**が表示されるところまで実装する。

## ステップ F-1: MBC1 実装 (2〜3時間)

**目標**: 32KB を超える ROM(tobu.gb は 256KB)で **バンク切り替え**ができるようにする。

Pan Docs: https://gbdev.io/pandocs/MBC1.html

### MBC1 の制御レジスタ

| アドレス範囲 | 機能 |
|---|---|
| `0x0000-0x1FFF` | RAM 有効化(0x0A で有効、それ以外で無効) |
| `0x2000-0x3FFF` | ROM Bank 番号(下位 5bit、0x00 → 0x01 に補正) |
| `0x4000-0x5FFF` | RAM Bank 番号 / ROM Bank の上位 2bit |
| `0x6000-0x7FFF` | バンクモード切り替え |

### 実装方針

`Cartridge` を拡張するか、`app/emulator/mbc1.rb` を新設して `Cartridge` に注入する。
ROM Bank 0 (`0x0000-0x3FFF`) は固定、Bank 1..NN (`0x4000-0x7FFF`) が切り替え可能。

### 動作確認

`tobu.gb` をロードして起動。ブート ROM 完走後、`PC` がカートリッジの命令を実行し続けることを確認(クラッシュしなければ OK の段階)。

---

## ステップ F-2: スプライト描画 (1.5〜2時間)

**目標**: OAM (`0xFE00-0xFE9F`) に書かれた 40 個のスプライトを描画できるようにする。

Pan Docs OAM: https://gbdev.io/pandocs/OAM.html

### 各スプライトの 4 バイト構造

| オフセット | 内容 |
|---|---|
| +0 | Y 座標(画面上端 = 16) |
| +1 | X 座標(画面左端 = 8) |
| +2 | タイル番号 |
| +3 | 属性: bit7=BG優先 / bit6=Y反転 / bit5=X反転 / bit4=パレット選択 / bit3-0=CGB のみ |

### 描画ロジック

各スキャンラインで:
1. OAM をスキャンして、その行に重なるスプライトを最大 10 個選ぶ
2. X 座標が小さい順に描画(BG より前)
3. 透明色(色番号 0)はスキップ
4. 属性に応じてパレット (`OBP0`/`OBP1`) を選ぶ

---

## ステップ F-3: Joypad 入力 (1時間)

**目標**: DragonRuby のキー入力を Game Boy の Joypad レジスタ (`0xFF00`) に反映する。

Pan Docs: https://gbdev.io/pandocs/Joypad_Input.html

### P1 (0xFF00) の読み書き

bit5/bit4 が選択ビット(CPU が書く):
- bit4 = 0: 方向キー(↑↓←→)
- bit5 = 0: ボタン(A/B/Start/Select)

bit3-0 がキー状態(0 = 押されている)。

### キー割り当て(DragonRuby → Game Boy)

| DR キー | GB ボタン |
|---|---|
| 矢印キー | 方向キー |
| Z | A |
| X | B |
| Enter | Start |
| Right Shift | Select |

`MMU#read(0xFF00)` をオーバーライドして、`@mmu` が外部から受け取った入力状態を返すように。

---

## ステップ F-4: Timer (DIV/TIMA) (1時間)

**目標**: タイマーレジスタを実機通りに動かし、TIMA オーバーフローで割り込みを発生させる。

Pan Docs: https://gbdev.io/pandocs/Timer_and_Divider_Registers.html

### レジスタ

| アドレス | 名前 | 機能 |
|---|---|---|
| 0xFF04 | DIV | 16384Hz でインクリメント。書き込みで 0 にリセット |
| 0xFF05 | TIMA | TAC で指定された頻度でインクリメント |
| 0xFF06 | TMA | TIMA がオーバーフローしたとき再ロードされる値 |
| 0xFF07 | TAC | bit2 = タイマー有効、bit1-0 = 頻度(00=4096Hz, 01=262144Hz, 10=65536Hz, 11=16384Hz) |

### 実装

CPU が実行したサイクル数を `Timer#step(cycles)` に渡し、内部カウンタで DIV/TIMA を進める。
TIMA オーバーフローで `IF` (0xFF0F) の bit2 を立てる。

---

## ステップ F-5: tobu.gb タイトル表示確認 (1〜3時間) ★第三マイルストーン

**目標**: `ROM_PATH = 'data/tobu.gb'` で起動して **タイトル画面が表示される**こと。

### 想定される実機差バグ

- **割り込みのタイミング**: V-Blank 割り込みが正確なフレームで発火しないとタイトル画面が描画されない
- **PPU モード遷移**: STAT 割り込みを使うゲームは Mode 切り替えタイミングで詰まる
- **タイマー割り込み**: 一部の処理が DIV ベースの待ちループを使っている

ここはバッファタイム。デバッグ込みで 1〜3 時間。

### 動作確認

タイトル画面の **「TOBU TOBU GIRL」のロゴ + キャラクター** が表示されれば成功。
ゲームプレイ(矢印キーでキャラ操作)は最低限動けばクリア。

---

# 参考リンク

- Pan Docs: https://gbdev.io/pandocs/
- gbops オペコード表: https://izik1.github.io/gbops/
- RGBDS gbz80(7) 命令リファレンス: https://rgbds.gbdev.io/docs/gbz80.7
- emudev.de: https://emudev.de/gameboy-emulator/testing-our-cpu/
- gameboy-doctor(CPU トレース比較): https://github.com/robert/gameboy-doctor
- ブート ROM 逆アセンブリ: https://github.com/ISSOtm/gb-bootroms
- Blargg gb-test-roms: https://github.com/retrio/gb-test-roms
- SameBoy(参照実装): https://github.com/LIJI32/SameBoy
- gitendo HelloWorld: https://github.com/gitendo/helloworld

# デバッグの優先順位

1. **未実装オペコードで停止** → エラーメッセージの PC とオペコードを gbops で確認して B-2 / E-1 / E-2 に追加
2. **D-2 で HELLO WORLD が出ない** → PPU 側のバグ濃厚(LCDC 検知、タイルアドレッシング、BGP パレット)。CPU は hello.gb の単純な構造で動かないなら未実装命令で止まるはず
3. **E-5 でロゴが崩れる** → PPU は HELLO WORLD で動作確認済みなので CPU 側のバグ濃厚。症状から推測した Blargg を E-6 で実行 → `Failed XX` のケース番号で原因特定
4. **F フェーズで止まる** → 割り込み(V-Blank / STAT / Timer)のタイミング、または MBC1 のバンク切り替え周り
