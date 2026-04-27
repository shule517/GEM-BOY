# GEM BOY — 実装ロードマップ

DragonRuby Game Toolkit で Ruby 製 Game Boy エミュレータ「**GEM BOY**」を作る。

## 戦略: Nintendo ロゴ表示を中心目標に置き、Blargg を診断ツールとして使う

「Blargg を全 Pass させてから先に進む」従来戦略をやめ、**一気にブート ROM 起動まで進める** 流れに改める。

1. CPU の必要命令と PPU 最小実装まで作る(B → C)
2. ブート ROM を仮接続して起動(D-1)
3. **崩れた Nintendo ロゴを目視**(D-2)★ 第一マイルストーン
4. **崩れていれば Blargg を 1 つずつ走らせて診断**(D-3、症状に応じた順序)
5. 修正後に再挑戦して **正しいロゴ**(D-4)★ 第二マイルストーン
6. tobu.gb タイトル画面まで実装(E)★ 第三マイルストーン

利点:
- ロゴが一発で動けば Blargg を 1 個も回さなくて良い(時間最大節約)
- 崩れたとき、Blargg は症状から推測した順番で診断ツールとして使える
- 「進捗が見えない時間」が短い(7〜12h で初の視覚的成果)

## 全体像

| フェーズ | ステップ数 | 想定時間 | 到達点 | 進捗 |
|---|---|---|---|---|
| A. 土台 | 3 | 3〜4h | ROM が読める、シリアル出力動く | 3/3 [完了] |
| B. CPU 必要命令の実装 | 3 | 4h | ブート ROM の命令を踏める | 0/3 |
| C. PPU 最小実装 | 2 | 2.5h | タイル + SCY 描画 | 0/2 |
| D. Nintendo ロゴ挑戦 | 5 | 2〜6h | **正しい Nintendo ロゴ表示 + ブートチャイム** | 0/5 |
| E. tobu.gb タイトル | 5 | 6.5〜10h | **tobu.gb タイトル表示** | 0/5 |

合計 18 ステップ、想定 17.5〜26.5h。**現在 3 ステップ完了(フェーズ A 完走)**。

## 進捗チェックリスト

- [x] A-1: プロジェクト初期化と画面表示
- [x] A-2: ROM読み込み
- [x] A-3: MMU骨組み + シリアル出力
- [ ] B-1: CPU 骨組み
- [ ] B-2: ブート ROM が使う命令一式
- [ ] B-3: CB-prefix BIT / RL
- [ ] C-1: PPU 骨組み(LCDC, LY, モード)
- [ ] C-2: BG タイル描画 + SCY スクロール
- [ ] D-1: ブート ROM mapping
- [ ] D-2: 起動 → 崩れたロゴ観察 ★第一マイルストーン
- [ ] D-3: Blargg 診断ループ(条件付き)
  - [ ] D-3a: `06-ld r,r.gb` で LD 命令検証
  - [ ] D-3b: `05-op rp.gb` で 16bit/INC・DEC 検証
  - [ ] D-3c: `04-op r,imm.gb` で即値 ALU 検証
  - [ ] D-3d: `11-op a,(hl).gb` でメモリ間接 ALU 検証
- [ ] D-4: 修正済みロゴ表示 ★第二マイルストーン
- [ ] D-5: ブートチャイム再生(NR14 trigger フック)
- [ ] E-1: MBC1 実装
- [ ] E-2: スプライト描画
- [ ] E-3: Joypad 入力
- [ ] E-4: Timer (DIV/TIMA)
- [ ] E-5: tobu.gb タイトル表示 ★第三マイルストーン

## 三段マイルストーン

1. **崩れた Nintendo ロゴ** (D-2 完了時): エミュレータが画面に何かを描いた瞬間。CPU と PPU が連動して動いた証拠
2. **正しい Nintendo ロゴ** (D-4 完了時): スクロールイン。ブート ROM が完走した証拠
3. **tobu.gb タイトル** (E-5 完了時): 実ゲームが起動。MBC1 + スプライト + 入力が揃った証拠

## 前提

- DragonRuby Game Toolkit がインストール済み(プロジェクトルートに `dragonruby` バイナリ配置済み)
- Ruby 4.0.3 + RSpec(`bundle exec rspec` で実行)
- Pan Docs(https://gbdev.io/pandocs/)を別タブで開いておく
- gbops オペコード表(https://izik1.github.io/gbops/)を別タブで開いておく
- ROM 素材の入手と配置(取得済み):
  - `data/cpu_instrs/` の Blargg 個別 ROM(retrio/gb-test-roms 由来)
  - `data/hello.gb`(gitendo/helloworld)
  - `data/dmg_boot.bin`(SameBoy 同梱の SameBoot 実装、256B)
  - `data/tobu.gb`(動作確認用 / E フェーズで使用)

## ディレクトリ構造(最終形)

```
GEM-BOY/
├── app/
│   ├── main.rb              # DragonRuby tick エントリ(args 依存はここだけ)
│   ├── emulator/            # 純 Ruby のエミュレータコア
│   │   ├── cartridge.rb     # カートリッジ
│   │   ├── mmu.rb           # メモリ管理 + シリアル出力
│   │   ├── cpu.rb           # CPU(B フェーズで作成)
│   │   ├── ppu.rb           # 描画(C フェーズで作成)
│   │   ├── boot_rom.rb      # ブート ROM(D フェーズで作成)
│   │   ├── mbc1.rb          # MBC1 バンク切り替え(E フェーズで作成)
│   │   └── emulator.rb      # 統合
│   └── core_ext/            # ビルトインクラス拡張(blank? など)
├── data/                    # ROM(.gitignore 対象)
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

# フェーズ B: CPU 必要命令の実装(4時間)

ブート ROM (256 バイト)の実行に必要な Sharp LR35902(Game Boy CPU)命令を実装する。**Blargg は走らせない**(D-3 で必要になったときに使う)。

CPU リファレンス:
- Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html
- gbops オペコード表: https://izik1.github.io/gbops/

## ステップ B-1: CPU 骨組み (1時間)

**目標**: CPU クラスの土台を作り、未実装命令を踏むと例外で停止する状態にする。

### 作業

```ruby
# app/emulator/cpu.rb
class CPU
  attr_accessor :a, :b, :c, :d, :e, :h, :l, :f, :sp, :pc, :ime, :halted

  def initialize(mmu)
    @mmu = mmu
    # ブート ROM 経由で起動するので全レジスタ 0 から始める。
    # (skip_boot 起動なら A=0x01, F=0xB0, PC=0x0100, SP=0xFFFE 等)
    @a = @b = @c = @d = @e = @h = @l = @f = 0
    @sp = 0
    @pc = 0
    @ime = false  # Interrupt Master Enable
    @halted = false
    @opcodes = build_opcode_table
  end

  # 1 命令実行して、消費したサイクル数を返す
  def step
    return 4 if @halted

    opcode = fetch_byte
    handler = @opcodes[opcode]
    raise "Unimplemented opcode 0x#{opcode.to_s(16)} at PC=0x#{(@pc - 1).to_s(16)}" if handler.nil?
    handler.call
  end

  # 連続実行モード(1 tick で数千命令を回す)
  def run(cycles_target)
    cycles = 0
    while cycles < cycles_target
      cycles += step
    end
    cycles
  end

  private

  def fetch_byte
    byte = @mmu.read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    byte
  end

  def fetch_word
    lo = fetch_byte
    hi = fetch_byte
    (hi << 8) | lo
  end

  def build_opcode_table
    table = Array.new(256, nil)
    # B-2 でここに大量に追加していく
    table[0x00] = -> { 4 }  # NOP
    table
  end
end
```

### 動作確認

```ruby
mmu = MMU.new(Cartridge.new([0x00, 0x00, 0x00]))
cpu = CPU.new(mmu)
cpu.step  # NOP 実行 → 戻り値 4
cpu.pc    # → 1
```

未実装命令を踏むと `Unimplemented opcode 0xXX at PC=0xYYYY` で停止することを確認。

---

## ステップ B-2: ブート ROM が使う命令一式 (2時間)

**目標**: ブート ROM が実行する全ての命令を網羅する(CB-prefix を除く)。

### 実装する命令カテゴリ

| カテゴリ | 命令 |
|---|---|
| **8bit ロード** | `LD r,r'` / `LD r,n` / `LD r,(HL)` / `LD (HL),r` / `LD (HL),n` / `LD A,(rr)` / `LD A,(nn)` / `LD (rr),A` / `LD (nn),A` / `LD A,(HL+)` / `LD A,(HL-)` / `LD (HL+),A` / `LD (HL-),A` |
| **LDH(High RAM 専用)** | `LDH (n),A` (0xE0) / `LDH A,(n)` (0xF0) / `LD (C),A` (0xE2) / `LD A,(C)` (0xF2) |
| **16bit ロード** | `LD rr,nn` / `LD SP,nn` / `LD SP,HL` / `LD (nn),SP` |
| **8bit 算術** | `ADD A,r/n/(HL)` / `ADC A,...` / `SUB ...` / `SBC A,...` / `AND ...` / `OR ...` / `XOR ...` / `CP ...` |
| **16bit 算術** | `ADD HL,rr` / `ADD SP,r8` |
| **INC/DEC** | `INC r` / `INC (HL)` / `INC rr` / `DEC r` / `DEC (HL)` / `DEC rr` |
| **ジャンプ** | `JP nn` / `JP cc,nn` / `JP HL` / `JR r8` / `JR cc,r8` |
| **コール/リターン** | `CALL nn` / `CALL cc,nn` / `RET` / `RET cc` / `RETI` / `RST n` |
| **スタック** | `PUSH rr` / `POP rr` |
| **ローテート** | `RLCA` / `RLA` / `RRCA` / `RRA` |
| **その他** | `NOP` / `DI` / `EI` / `HALT` / `STOP` / `DAA` / `CPL` / `SCF` / `CCF` |

### 実装の進め方

- フラグレジスタ F は **bit7=Z, bit6=N, bit5=H, bit4=C**(下位 4bit は常に 0)
- フラグ計算ヘルパー `set_flags(z:, n:, h:, c:)` を 1 つ作って共有
- **未実装命令で停止** する設計を活かし、**ブート ROM を実行 → 停止 → そのオペコードを追加** のループで進めると効率良い
- 「全部書いてからテスト」より「**動かしながら必要分だけ追加**」がこのフェーズの推奨

### 動作確認

ブート ROM を `data/dmg_boot.bin` から読んで Cartridge 風に与え、`run(70_000_000)` 程度回しても未実装命令例外が出ないことを目安に。
(ただし完全な確認は D-2 で実機ロゴ確認時に行う)

### フラグ計算の罠(覚えておく)

- `RLA` (0x17) は Z フラグを **常にクリア**。`CB RL` (0xCB 0x10-0x17) は結果が 0 なら Z を立てる
- `ADD SP,r8` (0xE8) の H/C フラグは **下位ニブル/下位バイト**で計算
- `INC r` / `DEC r` は **C フラグを保持**(他のフラグだけ更新)
- `DAA` の挙動はやや複雑。Pan Docs の擬似コード通りに書く

---

## ステップ B-3: CB-prefix BIT / RL (1時間)

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

### 動作確認

`BIT 7, A` を A=0x80 で実行 → Z=0、A=0x00 で実行 → Z=1。
`RL B` (キャリー=1, B=0x80) 実行 → B=0x01, キャリー=1。

---

# フェーズ C: PPU 最小実装(2.5時間)

ブート ROM が画面に表示するのは **BG タイルのみ**(スプライトもウィンドウも使わない)。最小限の PPU で済む。

PPU リファレンス:
- Pan Docs Rendering: https://gbdev.io/pandocs/Rendering.html
- Pan Docs Pixel FIFO: https://gbdev.io/pandocs/pixel_fifo.html(参考、本実装では使わない)

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

## ステップ C-2: BG タイル描画 + SCY スクロール (1時間半)

**目標**: VRAM の Tile Data + Tile Map から 1 スキャンライン分のピクセルを生成し、`SCY` で縦スクロールする。

### 描画ロジック

各スキャンライン (`LY`) について:

1. `SCY` を加算して BG マップ上の Y 座標を求める: `bg_y = (LY + SCY) & 0xFF`
2. Tile Map のどの行か: `tile_row = bg_y / 8`、その中の何ラインか: `pixel_y = bg_y % 8`
3. Tile Map のアドレス(LCDC bit3 で 0x9800 か 0x9C00): `map_base + tile_row * 32`
4. 各ピクセル X (0..159):
   - `bg_x = (X + SCX) & 0xFF`
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

# フェーズ D: Nintendo ロゴ挑戦(2〜6時間)

ここからが本番。ブート ROM を仮接続して走らせる。

## ステップ D-1: ブート ROM mapping (30分)

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
def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
  boot_rom = args.gtk.read_file('data/dmg_boot.bin').bytes
  args.state.mmu = MMU.new(args.state.cartridge, boot_rom: boot_rom)
  args.state.cpu = CPU.new(args.state.mmu)
  args.state.ppu = PPU.new(args.state.mmu)
end

def tick(args)
  setup(args) if args.state.tick_count == 0
  # 1 フレーム分(70224 サイクル)実行
  cycles = args.state.cpu.run(70224)
  args.state.ppu.step(cycles)
  render_framebuffer(args)
end
```

### 動作確認

クラッシュしなければ OK(まだ画面には何も出ない)。

---

## ステップ D-2: 起動 → 崩れたロゴ観察 (30分) ★ 第一マイルストーン

**目標**: ブート ROM が動き始める瞬間を確認する。何が崩れているかを目視する。

### 観察チェックリスト

| 現象 | 推定原因 | 次のアクション |
|---|---|---|
| 即クラッシュ(未実装オペコード) | B-2/B-3 の漏れ | 該当命令を実装 → 再挑戦 |
| 黒画面のまま無反応 | LCDC の ON 検知不可 / PPU の `step` が回ってない | C-1 の lcd_on? と step を見直す |
| ロゴの一部が出るが歪む | タイル描画ロジックが微妙にズレ | C-2 の描画ロジックを確認 |
| **崩れたロゴが出る** | **CPU バグ濃厚 → D-3 で Blargg 診断** | D-3 へ進む |
| **正しいロゴが流れる** | **奇跡のショートカット成功** | D-3/D-4 をスキップして E へ |

ここで「何かが画面に出る」だけでも **第一マイルストーン達成**(ロゴが正しく出なくても可)。

---

## ステップ D-3: Blargg 診断ループ(条件付き、0〜4時間)

**条件**: D-2 で「崩れたロゴ」「黒画面」「実行が途中で止まる」のいずれかが起きたとき実行。

`ROM_PATH` を Blargg の個別 ROM に切り替えて起動 → ターミナルにテスト名と結果(`Passed` または `Failed XX`)が出る。`Failed XX` の `XX` はテストケース番号。

```ruby
# app/main.rb
ROM_PATH = 'data/cpu_instrs/06-ld r,r.gb'   # 切り替えてテスト
```

### 症状から推測する実行順序

| ロゴの崩れ方 | 推奨 Blargg | サブステップ |
|---|---|---|
| 即停止 / 一切動かない | `06-ld r,r.gb` | D-3a |
| ロゴ位置がズレる / スクロール変 | `05-op rp.gb` | D-3b |
| ロゴのドットが歪む | `04-op r,imm.gb` | D-3c |
| ロゴ転送が崩れる(部分的に出る) | `11-op a,(hl).gb` | D-3d |

順番に走らせて Pass を取っていく。Pass したら `ROM_PATH` を次に切り替え。

### ステップ D-3a: `06-ld r,r.gb` で LD 命令検証 (30〜90分)

**目標**: 全 LD 命令(レジスタ間転送、即値ロード、メモリロード)が完璧に動くことを確認。

```
ROM_PATH = 'data/cpu_instrs/06-ld r,r.gb'
```

**Failed XX が出たら:**
- `XX` は失敗したサブテストの番号
- Blargg のソース(retrio/gb-test-roms)で `06-ld r,r` の該当ケースを確認
- 該当 LD 命令(特定のレジスタ組み合わせ)の実装を見直す

### ステップ D-3b: `05-op rp.gb` で 16bit 命令と INC/DEC 検証 (30〜90分)

**目標**: 16bit ロード/算術と INC/DEC が完璧に動くことを確認。

```
ROM_PATH = 'data/cpu_instrs/05-op rp.gb'
```

**重要なフラグの罠:**
- `INC r` / `DEC r`: **C フラグを保持**(他は更新)
- `INC rr` / `DEC rr`: **フラグを一切変更しない**
- `ADD HL,rr`: Z フラグを保持、N=0、H/C は bit11/15 で計算
- `ADD SP,r8`: H/C は **下位ニブル/下位バイト**で計算

### ステップ D-3c: `04-op r,imm.gb` で即値 ALU 検証 (30〜90分)

**目標**: `ADD A,n` `SUB n` `AND n` `OR n` `XOR n` `CP n` 系の即値演算が完璧に動くことを確認。

```
ROM_PATH = 'data/cpu_instrs/04-op r,imm.gb'
```

### ステップ D-3d: `11-op a,(hl).gb` でメモリ間接 ALU 検証 (30〜90分)

**目標**: `(HL)` 経由の ALU 命令(`ADD A,(HL)` など)が完璧に動くことを確認。

```
ROM_PATH = 'data/cpu_instrs/11-op a,(hl).gb'
```

---

## ステップ D-4: 修正済みロゴ表示 (30分) ★ 第二マイルストーン

**目標**: D-3 で Blargg を Pass させた CPU で再びブート ROM を起動。

```ruby
# app/main.rb
ROM_PATH = 'data/tobu.gb'   # ブート ROM を抜けた直後の遷移先(ロゴ表示には何でも良い)
```

ブート ROM が完走すると:

1. グレー → 黒の画面遷移
2. **Nintendo ロゴが画面中央に上から下へスクロールイン**
3. 「ピーン」音(D-5 で実装、本ステップでは無音)
4. 約 1 秒静止
5. PC=0x0100 へジャンプ → カートリッジ本体へ

これで **ROADMAP の中心目標 = 第二マイルストーン達成**。

---

## ステップ D-5: ブートチャイム再生(NR14 trigger フック) (30分)

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

# フェーズ E: tobu.gb タイトル画面(6.5〜10時間)

ROADMAP の発展課題。ブート ROM が完走した後、tobu.gb の **タイトル画面**が表示されるところまで実装する。

## ステップ E-1: MBC1 実装 (2〜3時間)

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

## ステップ E-2: スプライト描画 (1.5〜2時間)

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

## ステップ E-3: Joypad 入力 (1時間)

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

## ステップ E-4: Timer (DIV/TIMA) (1時間)

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

## ステップ E-5: tobu.gb タイトル表示確認 (1〜3時間) ★ 第三マイルストーン

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

# 付録: HelloWorld 表示(任意)

旧 ROADMAP では D-3 として HelloWorld 表示を必須に置いていたが、新戦略では Nintendo ロゴ表示が同じ役割を果たすので **省略可能** とした。
動作確認用に試したい場合:

```ruby
ROM_PATH = 'data/hello.gb'
# ブート ROM mapping は無効にして、いきなり PC=0x0100 から起動
```

`Hello World!` がタイル描画で表示される。

---

# 参考リンク

- Pan Docs: https://gbdev.io/pandocs/
- gbops オペコード表: https://izik1.github.io/gbops/
- emudev.de: https://emudev.de/gameboy-emulator/testing-our-cpu/
- gameboy-doctor(CPU トレース比較): https://github.com/robert/gameboy-doctor
- ブート ROM 逆アセンブリ: https://github.com/ISSOtm/gb-bootroms
- Blargg gb-test-roms: https://github.com/retrio/gb-test-roms
- SameBoy(参照実装): https://github.com/LIJI32/SameBoy

# デバッグの優先順位

1. **未実装オペコードで停止** → エラーメッセージの PC とオペコードを gbops で確認して B-2 / B-3 に追加
2. **D-2 でロゴが崩れる** → 症状から推測した Blargg を D-3 で実行 → `Failed XX` のケース番号で原因特定
3. **画面が出ない / 崩れる**(D-2 以降) → CPU が固まっている前提なら、ほぼ確実に PPU 側のバグ(LCDC 検知、タイルアドレッシング、BGP パレット周り)
