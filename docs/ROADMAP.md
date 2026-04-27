# GEM BOY — Game Boy エミュレータ実装ロードマップ

DragonRuby Game Toolkit で Ruby 製 Game Boy エミュレータ「**GEM BOY**」を作る。

## 戦略: Blargg最優先 → HelloWorld表示

PPU実装より先にCPUの正しさを Blargg テストで担保する。シリアル出力経由でテスト結果が見えるので、画面実装ゼロでも「Passed」という達成感が連続的に得られる。CPU が確実に動く状態で PPU 実装に入れるので、視覚的なゴール(HelloWorld表示)で詰まるリスクが激減する。

各ステップは1〜2時間で完了する粒度に分割し、最後に必ず「動作確認」がある構成。

## 全体像

| フェーズ | ステップ数 | 想定時間 | 到達点 | 進捗 |
|---|---|---|---|---|
| A. 土台 | 3 | 3〜4h | ROMが読める、シリアル出力が動く | 2/3 |
| B. CPU基礎 + Blargg初級 | 3 | 4〜6h | `06-ld r,r` Passed | 0/3 |
| C. CPU拡張 + Blargg中級 | 3 | 4〜6h | `04`, `05`, `11` Passed | 0/3 |
| D. PPU実装 + HelloWorld | 3 | 3〜5h | **HelloWorld表示** | 0/3 |
| E. ブートROM対応 | 3 | 4〜7h | **Nintendoロゴ表示** | 0/3 |

合計 15ステップ、18〜28時間。**現在 2 ステップ完了**。

## 進捗チェックリスト

- [x] A-1: プロジェクト初期化と画面表示
- [x] A-2: ROM読み込み
- [ ] A-3: MMU骨組み + シリアル出力
- [ ] B-1: CPUの骨組み
- [ ] B-2: 制御フロー命令の実装
- [ ] B-3: LD命令群 → `06-ld r,r.gb` パス
- [ ] C-1: 即値演算と8bit算術 → `04-op r,imm.gb` パス
- [ ] C-2: 16bit命令とINC/DEC → `05-op rp.gb` パス
- [ ] C-3: メモリ間接ALU → `11-op a,(hl).gb` パス
- [ ] D-1: PPU骨組みとLY
- [ ] D-2: タイル描画
- [ ] D-3: 画面表示 → HelloWorld表示
- [ ] E-1: ブートROM対応とMMU切り替え
- [ ] E-2: CB ビット操作命令
- [ ] E-3: ブートROM完走 → Nintendoロゴ表示

## 三段マイルストーン

**第一の達成感: Blargg `06-ld r,r.gb` の "Passed" がターミナルに出る** (ステップB-3完了時)

**第二の達成感: HelloWorldが画面に表示される** (ステップD-3完了時)

**第三の達成感: Nintendoロゴが画面にスクロールインする** (ステップE-3完了時)

## 前提

- DragonRuby Game Toolkit がインストール済み
- Pan Docs(https://gbdev.io/pandocs/)を別タブで開いておく
- gbops オペコード表(https://izik1.github.io/gbops/)を別タブで開いておく
- Blargg テストROM(https://github.com/retrio/gb-test-roms)を入手 — `cpu_instrs/individual/` の中身を `data/cpu_instrs/` に配置(`cpu_instrs.gb` 単体は MBC を使うのでまだダメ)。実際に使うのは `06-ld r,r.gb` (B-3), `04-op r,imm.gb` (C-1), `05-op rp.gb` (C-2), `11-op a,(hl).gb` (C-3)
- HelloWorld ROM(https://github.com/gitendo/helloworld)を入手 — DMG用の `hello.gb` を `data/hello.gb` に配置
- 互換ブートROM(SameBoy リリース版に同梱の SameBoot 実装)を入手 — `dmg_boot.bin` (256 バイト) を `data/dmg_boot.bin` に配置(フェーズ E で使用)。取得手順は `CLAUDE.md` 参照

任意(ROADMAP 完走後の追加検証用):

- dmg-acid2.gb(https://github.com/mattcurrie/dmg-acid2)— PPU の 1px 精度テスト
- Mooneye Test Suite(https://gekkio.fi/files/mooneye-test-suite/)— MBC やタイミングの精密テスト
- instr_timing.gb(retrio/gb-test-roms 配下)— 命令サイクル数の検証

## ディレクトリ構造(最終形)

```
GEM-BOY/
├── app/
│   ├── main.rb              # DragonRuby tick エントリ(args 依存はここだけ)
│   ├── emulator/            # 純 Ruby のエミュレータコア
│   │   ├── cartridge.rb     # カートリッジ
│   │   ├── mmu.rb           # メモリ管理 + シリアル出力
│   │   ├── cpu.rb           # CPU
│   │   ├── ppu.rb           # 描画(後半で追加)
│   │   ├── boot_rom.rb      # ブートROM(フェーズEで追加)
│   │   └── emulator.rb      # 統合
│   └── core_ext/            # ビルトインクラス拡張(blank? など)
├── data/
│   ├── tobu.gb              # 動作確認用 ROM
│   ├── cpu_instrs/          # Blargg 個別 ROM(オリジナル配布構造のまま)
│   │   ├── 06-ld r,r.gb     # B-3
│   │   ├── 04-op r,imm.gb   # C-1
│   │   ├── 05-op rp.gb      # C-2
│   │   ├── 11-op a,(hl).gb  # C-3
│   │   └── ... (他 7 個は完走後の追加検証用)
│   ├── hello.gb             # HelloWorld
│   └── dmg_boot.bin         # ブートROM(SameBoot)
├── spec/                    # MRI Ruby で実行する RSpec
└── docs/
```

**3 層分離**: `app/main.rb`(DragonRuby 依存) / `app/emulator/`(純 Ruby、args 非依存) / `app/core_ext/`(ビルトイン拡張)。`app/emulator/` は MRI Ruby + RSpec で単体テスト可能。

---

# フェーズA: 土台 (3ステップ / 3〜4時間)

## ステップ A-1: プロジェクト初期化と画面表示 (45分) [完了]

**目標**: DragonRuby で「GEM BOY」と表示されたウィンドウが開くこと。

### 作業

```ruby
# app/main.rb
def tick(args)
  args.outputs.background_color = [30, 30, 30]
  args.outputs.labels << {
    x: 640, y: 360,
    text: "GEM BOY",
    alignment_enum: 1,
    r: 200, g: 200, b: 200,
    size_enum: 4
  }
  args.outputs.labels << {
    x: 640, y: 320,
    text: "Game Boy emulator in Ruby",
    alignment_enum: 1,
    r: 150, g: 150, b: 150
  }
end
```

### 動作確認

`./dragonruby .` で起動。グレー背景に「GEM BOY」の文字が中央に出れば成功。

---

## ステップ A-2: ROM読み込み (1時間) [完了]

**目標**: BlarggテストROMが読み込めて、ヘッダ情報が画面に表示できること。

### 作業

**設計方針**: `Cartridge` は `args` に依存せず、バイト配列だけを受け取る純 Ruby クラスにする(MRI Ruby + RSpec で単体テスト可能にするため)。ファイル I/O は呼び出し側 (`main.rb`) の責務。

```ruby
# app/emulator/cartridge.rb
class Cartridge
  def initialize(data)
    raise "Empty ROM data" if data.nil? || data.empty?
    @data = data
  end

  def read(address)
    @data[address] || 0xFF
  end

  # https://gbdev.io/pandocs/The_Cartridge_Header.html
  # 0134-0143 — Title
  def title
    @data[0x0134..0x0143].pack('C*').strip.delete("\x00")
  end

  def size
    @data.size
  end
end
```

```ruby
# app/main.rb
require 'app/core_ext/blank.rb'
require 'app/emulator/cartridge.rb'

ROM_PATH = 'data/tobu.gb'

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]

  cartridge = args.state.cartridge
  args.outputs.labels << { x: 20, y: 700, text: "GEM BOY", r: 255, g: 255, b: 255, size_enum: 2 }
  args.outputs.labels << { x: 20, y: 660, text: "ROM: #{File.basename(ROM_PATH)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 630, text: "Title: #{cartridge.title}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 600, text: "Size: #{cartridge.size} bytes", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 570, text: "ROM[0x0100]: 0x#{cartridge.read(0x0100).to_s(16)}", r: 200, g: 200, b: 200 }
end

def setup(args)
  args.state.cartridge = Cartridge.new(args.gtk.read_file(ROM_PATH).bytes)
end
```

ROM の切り替えは `ROM_PATH` 定数を書き換えるだけ。

### 動作確認

画面に以下のような情報が表示される(`tobu.gb` の例):
- `ROM: tobu.gb`
- `Title: TOBU`
- `Size: 262144 bytes` (Blargg 個別 ROM なら 32768 bytes 程度)
- `ROM[0x0100]: 0x0` または `0xC3`(JP命令)

---

## ステップ A-3: MMU骨組み + シリアル出力 (1時間半)

**目標**: メモリ領域別のread/writeができ、Blarggがシリアル出力に書き込んだ文字をターミナルに表示できること。これは後の全フェーズの土台。

### 作業

```ruby
# app/mmu.rb
class MMU
  def initialize(cartridge)
    @cartridge = cartridge
    @vram = Array.new(0x2000, 0)  # Video RAM (8KB)
    @wram = Array.new(0x2000, 0)  # Work RAM (8KB)
    @hram = Array.new(0x7F, 0)    # High RAM (127 bytes)
    @oam = Array.new(0xA0, 0)     # Object Attribute Memory (sprite info)
    @io = Array.new(0x80, 0)      # I/O Registers
    @ie = 0                        # Interrupt Enable register
    @serial_buffer = ""
  end

  attr_reader :serial_buffer, :vram

  def read(address)
    case address
    when 0x0000..0x7FFF then @cartridge.read(address)
    when 0x8000..0x9FFF then @vram[address - 0x8000]
    when 0xC000..0xDFFF then @wram[address - 0xC000]
    when 0xFE00..0xFE9F then @oam[address - 0xFE00]
    when 0xFF00..0xFF7F then @io[address - 0xFF00]
    when 0xFF80..0xFFFE then @hram[address - 0xFF80]
    when 0xFFFF then @ie
    else 0xFF
    end
  end

  def write(address, value)
    value &= 0xFF
    case address
    when 0x8000..0x9FFF then @vram[address - 0x8000] = value
    when 0xC000..0xDFFF then @wram[address - 0xC000] = value
    when 0xFE00..0xFE9F then @oam[address - 0xFE00] = value
    when 0xFF00..0xFF7F
      @io[address - 0xFF00] = value
      handle_serial(address, value)
    when 0xFF80..0xFFFE then @hram[address - 0xFF80] = value
    when 0xFFFF then @ie = value
    end
  end

  def write_io_direct(address, value)
    @io[address - 0xFF00] = value & 0xFF
  end

  private

  # Blarggテストはシリアルポートに結果文字列を出力する
  def handle_serial(address, value)
    return unless address == 0xFF02 && value == 0x81
    char = @io[0x01].chr
    $stdout.print char
    $stdout.flush
    @serial_buffer << char
    @serial_buffer = @serial_buffer[-500..] if @serial_buffer.length > 500
    @io[0x02] = 0x01
  end
end
```

```ruby
# app/main.rb
require 'app/cartridge.rb'
require 'app/mmu.rb'

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  render_header(args)
  render_serial(args)
  
  # テスト用: スペースキーでシリアル書き込みをシミュレート
  if args.inputs.keyboard.key_down.space
    args.state.mmu.write(0xFF01, 'A'.ord)
    args.state.mmu.write(0xFF02, 0x81)
  end
end

def setup(args)
  args.state.rom_path = 'data/cpu_instrs/06-ld r,r.gb'
  args.state.cartridge = Cartridge.new(args, args.state.rom_path)
  args.state.mmu = MMU.new(args.state.cartridge)
end

def render_header(args)
  args.outputs.labels << { x: 20, y: 700, text: "GEM BOY", r: 255, g: 255, b: 255, size_enum: 2 }
  args.outputs.labels << { x: 20, y: 660, text: "ROM: #{File.basename(args.state.rom_path)}", r: 200, g: 200, b: 200 }
  args.outputs.labels << { x: 20, y: 630, text: "Press SPACE to test serial", r: 150, g: 150, b: 150 }
end

def render_serial(args)
  args.outputs.labels << { x: 700, y: 700, text: "Serial Output:", r: 200, g: 200, b: 200 }
  
  buffer = args.state.mmu.serial_buffer
  buffer.split("\n").last(20).each_with_index do |line, i|
    args.outputs.labels << {
      x: 700, y: 670 - i * 22,
      text: line,
      r: 0, g: 255, b: 0,
      size_enum: -2
    }
  end
end
```

### 動作確認

スペースキーを押すと:
- 画面右側に "A" が緑色で表示される
- DragonRubyを起動したターミナルにも "A" が出力される

何度か押すと "AAAA..." と増えていく。これでシリアル出力の仕組みが完成。

---

# フェーズB: CPU基礎 + Blargg初級 (3ステップ / 4〜6時間)

## ステップ B-1: CPUの骨組み (1時間)

**目標**: CPUクラスができて、Blarggテストの最初の数命令を実行できる準備が整うこと。

### Blarggテストの開始位置

BlarggテストROMは0x0100から始まる。最初の命令は典型的に `JP $XXXX`(0xC3)で、ヘッダエリアを飛び越えて実際のコードへジャンプする。

### 作業

```ruby
# app/cpu.rb
class CPU
  FLAG_Z = 0x80
  FLAG_N = 0x40
  FLAG_H = 0x20
  FLAG_C = 0x10

  attr_accessor :a, :b, :c, :d, :e, :h, :l, :f, :sp, :pc

  def initialize(mmu)
    @mmu = mmu
    reset
  end

  # ブートROMをスキップした状態(DMG)
  def reset
    @a = 0x01
    @f = 0xB0
    @b = 0x00
    @c = 0x13
    @d = 0x00
    @e = 0xD8
    @h = 0x01
    @l = 0x4D
    @sp = 0xFFFE
    @pc = 0x0100
    @ime = false  # Interrupt Master Enable
  end

  def af; (@a << 8) | @f; end
  def bc; (@b << 8) | @c; end
  def de; (@d << 8) | @e; end
  def hl; (@h << 8) | @l; end

  def af=(v); @a = (value >> 8) & 0xFF; @f = v & 0xF0; end
  def bc=(v); @b = (value >> 8) & 0xFF; @c = v & 0xFF; end
  def de=(v); @d = (value >> 8) & 0xFF; @e = v & 0xFF; end
  def hl=(v); @h = (value >> 8) & 0xFF; @l = v & 0xFF; end

  def fetch
    op = @mmu.read(@pc)
    @pc = (@pc + 1) & 0xFFFF
    op
  end

  def fetch_word
    low_byte = fetch
    high_byte = fetch
    (high_byte << 8) | low_byte
  end

  def step
    opcode = fetch
    execute(opcode)
  end

  def execute(opcode)
    raise "Unimplemented opcode: 0x#{opcode.to_s(16).rjust(2,'0')} at PC=0x#{((@pc-1) & 0xFFFF).to_s(16).rjust(4,'0')}"
  end

  def state_string
    "PC=#{@pc.to_s(16).rjust(4,'0')} SP=#{@sp.to_s(16).rjust(4,'0')} A=#{@a.to_s(16).rjust(2,'0')} F=#{@f.to_s(16).rjust(2,'0')}"
  end
end
```

```ruby
# app/main.rb の setup と tick を更新
require 'app/cpu.rb'

def setup(args)
  args.state.rom_path = 'data/cpu_instrs/06-ld r,r.gb'
  args.state.cartridge = Cartridge.new(args, args.state.rom_path)
  args.state.mmu = MMU.new(args.state.cartridge)
  args.state.cpu = CPU.new(args.state.mmu)
end

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  if args.inputs.keyboard.key_down.space
    begin
      args.state.cpu.step
    rescue => e
      args.state.error = e.message
    end
  end
  
  render_header(args)
  render_cpu_state(args)
  render_serial(args)
end

def render_cpu_state(args)
  args.outputs.labels << { x: 20, y: 600, text: args.state.cpu.state_string, r: 255, g: 255, b: 255 }
  args.outputs.labels << { x: 20, y: 570, text: "Press SPACE to step", r: 150, g: 150, b: 150 }
  if args.state.error
    args.outputs.labels << { x: 20, y: 540, text: args.state.error, r: 255, g: 100, b: 100, size_enum: -2 }
  end
end
```

### 動作確認

起動時に `PC=0100 SP=FFFE A=01 F=B0` と表示される。スペースキーを1回押すと、未実装オペコード `0xC3` (JP nn) で例外が出る。これは想定通り。次のステップで実装する。

---

## ステップ B-2: 制御フロー命令の実装 (1時間半)

**目標**: BlarggテストがJPやCALLで進めるようになり、シリアル出力でテスト名(`06-ld r,r`)が表示されること。

### Blarggテストの典型的な開始フロー

```
0x0100: 00          NOP
0x0101: C3 50 01    JP $0150     ; ヘッダを飛び越える
...
0x0150: ...         ; テスト本体開始
        ;  最初にテスト名をシリアル出力
        ;  続いてレジスタ初期化、CALLでテストルーチン
```

### 必要な命令

| Opcode | 命令 | 用途 |
|---|---|---|
| 0x00 | NOP | 何もしない |
| 0xC3 | JP nn | 絶対ジャンプ |
| 0xCD | CALL nn | サブルーチン呼び出し |
| 0xC9 | RET | サブルーチンから戻る |
| 0xC5/D5/E5/F5 | PUSH BC/DE/HL/AF | スタックに積む |
| 0xC1/D1/E1/F1 | POP BC/DE/HL/AF | スタックから降ろす |
| 0x18 | JR r8 | 相対ジャンプ |
| 0x20/28/30/38 | JR NZ/Z/NC/C,r8 | 条件付き相対ジャンプ |
| 0xC2/CA/D2/DA | JP NZ/Z/NC/C,nn | 条件付き絶対ジャンプ |

### 作業

```ruby
# app/cpu.rb の execute メソッド
def execute(opcode)
  case opcode
  when 0x00 then 4  # NOP
  when 0xC3
    @pc = fetch_word
    16
  when 0xCD
    address = fetch_word
    push_word(@pc)
    @pc = address
    24
  when 0xC9
    @pc = pop_word
    16
  when 0xC5 then push_word(bc); 16
  when 0xD5 then push_word(de); 16
  when 0xE5 then push_word(hl); 16
  when 0xF5 then push_word(af); 16
  when 0xC1 then self.bc = pop_word; 12
  when 0xD1 then self.de = pop_word; 12
  when 0xE1 then self.hl = pop_word; 12
  when 0xF1 then self.af = pop_word; 12
  when 0x18
    offset = fetch
    offset -= 256 if offset >= 128
    @pc = (@pc + offset) & 0xFFFF
    12
  when 0x20 then jr_cond((@f & FLAG_Z) == 0)
  when 0x28 then jr_cond((@f & FLAG_Z) != 0)
  when 0x30 then jr_cond((@f & FLAG_C) == 0)
  when 0x38 then jr_cond((@f & FLAG_C) != 0)
  when 0xC2 then jp_cond((@f & FLAG_Z) == 0)
  when 0xCA then jp_cond((@f & FLAG_Z) != 0)
  when 0xD2 then jp_cond((@f & FLAG_C) == 0)
  when 0xDA then jp_cond((@f & FLAG_C) != 0)
  else
    raise "Unimplemented opcode: 0x#{opcode.to_s(16).rjust(2,'0')} at PC=0x#{((@pc-1) & 0xFFFF).to_s(16).rjust(4,'0')}"
  end
end

private

def jr_cond(condition)
  offset = fetch
  if condition
    offset -= 256 if offset >= 128
    @pc = (@pc + offset) & 0xFFFF
    12
  else
    8
  end
end

def jp_cond(condition)
  address = fetch_word
  if condition
    @pc = address
    16
  else
    12
  end
end

def push_word(value)
  @sp = (@sp - 1) & 0xFFFF
  @mmu.write(@sp, (value >> 8) & 0xFF)
  @sp = (@sp - 1) & 0xFFFF
  @mmu.write(@sp, value & 0xFF)
end

def pop_word
  low_byte = @mmu.read(@sp)
  @sp = (@sp + 1) & 0xFFFF
  high_byte = @mmu.read(@sp)
  @sp = (@sp + 1) & 0xFFFF
  (high_byte << 8) | low_byte
end
```

連続実行モードに変更:

```ruby
def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  unless args.state.error
    1000.times do
      begin
        args.state.cpu.step
      rescue => e
        args.state.error = e.message
        break
      end
    end
  end
  
  render_header(args)
  render_cpu_state(args)
  render_serial(args)
end
```

### 動作確認

実行すると、未実装命令でエラーになるが、停止する前にシリアル出力に `06-ld r,r` のような文字列が表示される。これはBlarggが「これからテストを始めます」と名前を出力している証拠。

これが見えれば、CPU の制御フローが正しく動いていることになる。次のステップでLD命令を実装すればテスト本体が走る。

---

## ステップ B-3: LD命令群 → `06-ld r,r.gb` パス (2時間)

**目標**: LD命令(レジスタ間転送)を全て実装し、Blarggの `06-ld r,r` テストが "Passed" を返すこと。

### 必要な命令

LD r1,r2 系の命令はオペコード 0x40〜0x7F の範囲に体系的に並んでいる(0x76 = HALT を除く)。一気に実装する。

```
0x40-0x47: LD B,r
0x48-0x4F: LD C,r
0x50-0x57: LD D,r
0x58-0x5F: LD E,r
0x60-0x67: LD H,r
0x68-0x6F: LD L,r
0x70-0x77: LD (HL),r  (0x76 はHALT)
0x78-0x7F: LD A,r
```

加えて、テストコード自体が使う以下も必要:

```
0x06: LD B,n
0x0E: LD C,n
0x16: LD D,n
0x1E: LD E,n
0x26: LD H,n
0x2E: LD L,n
0x3E: LD A,n
0x21: LD HL,nn
0x31: LD SP,nn
0x76: HALT
0xF3: DI(割り込み無効)
0xFB: EI(割り込み有効)
0xEA: LD (nn),A
0xFA: LD A,(nn)
```

### 作業

```ruby
# app/cpu.rb
def execute(opcode)
  case opcode
  # ... 既存の制御フロー命令 ...
  
  # LD r1,r2 (0x40-0x7F)
  when 0x40..0x7F
    execute_ld_rr(opcode)
  
  # LD r,n
  when 0x06 then @b = fetch; 8
  when 0x0E then @c = fetch; 8
  when 0x16 then @d = fetch; 8
  when 0x1E then @e = fetch; 8
  when 0x26 then @h = fetch; 8
  when 0x2E then @l = fetch; 8
  when 0x3E then @a = fetch; 8
  when 0x36 then @mmu.write(hl, fetch); 12
  
  # LD rr,nn
  when 0x01 then self.bc = fetch_word; 12
  when 0x11 then self.de = fetch_word; 12
  when 0x21 then self.hl = fetch_word; 12
  when 0x31 then @sp = fetch_word; 12
  
  # LD (nn),A / LD A,(nn)
  when 0xEA then @mmu.write(fetch_word, @a); 16
  when 0xFA then @a = @mmu.read(fetch_word); 16
  
  # LD (BC/DE),A / LD A,(BC/DE)
  when 0x02 then @mmu.write(bc, @a); 8
  when 0x12 then @mmu.write(de, @a); 8
  when 0x0A then @a = @mmu.read(bc); 8
  when 0x1A then @a = @mmu.read(de); 8
  
  # LD (HL+/-),A / LD A,(HL+/-)
  when 0x22
    @mmu.write(hl, @a)
    self.hl = (hl + 1) & 0xFFFF
    8
  when 0x32
    @mmu.write(hl, @a)
    self.hl = (hl - 1) & 0xFFFF
    8
  when 0x2A
    @a = @mmu.read(hl)
    self.hl = (hl + 1) & 0xFFFF
    8
  when 0x3A
    @a = @mmu.read(hl)
    self.hl = (hl - 1) & 0xFFFF
    8
  
  # LDH
  when 0xE0 then @mmu.write(0xFF00 + fetch, @a); 12
  when 0xF0 then @a = @mmu.read(0xFF00 + fetch); 12
  when 0xE2 then @mmu.write(0xFF00 + @c, @a); 8
  when 0xF2 then @a = @mmu.read(0xFF00 + @c); 8
  
  # 制御
  when 0x76 then @halted = true; 4
  when 0xF3 then @ime = false; 4  # DI: Disable Interrupts
  when 0xFB then @ime = true; 4   # EI: Enable Interrupts
  
  else
    raise "Unimplemented opcode: 0x#{opcode.to_s(16).rjust(2,'0')} at PC=0x#{((@pc-1) & 0xFFFF).to_s(16).rjust(4,'0')}"
  end
end

private

# LD r1,r2 を体系的にディスパッチ
def execute_ld_rr(opcode)
  dest_index = (opcode - 0x40) >> 3
  source_index = opcode & 0x07
  source_value = read_reg(source_index)
  write_reg(dest_index, source_value)
  (dest_index == 6 || source_index == 6) ? 8 : 4
end

def read_reg(index)
  case index
  when 0 then @b
  when 1 then @c
  when 2 then @d
  when 3 then @e
  when 4 then @h
  when 5 then @l
  when 6 then @mmu.read(hl)
  when 7 then @a
  end
end

def write_reg(index, value)
  case index
  when 0 then @b = value
  when 1 then @c = value
  when 2 then @d = value
  when 3 then @e = value
  when 4 then @h = value
  when 5 then @l = value
  when 6 then @mmu.write(hl, value)
  when 7 then @a = value
  end
end
```

HALT対応:

```ruby
def step
  return 4 if @halted
  opcode = fetch
  execute(opcode)
end
```

### 動作確認

🎉 **第一の達成感**

実行すると、ターミナルとDragonRuby画面に以下が表示される:

```
06-ld r,r


Passed
```

または失敗時:

```
06-ld r,r

00 01 02 03 04 ...
Failed
```

Failed の場合は、表示されている数字がどのテストケースで失敗したかを示す。デバッグして再挑戦。

成功すれば、LD命令群が完璧に動いている証拠。**初の機械的な合格判定**を獲得。

---

# フェーズC: CPU拡張 + Blargg中級 (3ステップ / 4〜6時間)

## ステップ C-1: 即値演算と8bit算術 → `04-op r,imm.gb` パス (1時間半)

**目標**: 即値を使った算術演算(ADD A,n, SUB n等)を実装し、Blargg `04-op r,imm` テストが Passed すること。

### 必要な命令

```
0xC6: ADD A,n
0xCE: ADC A,n
0xD6: SUB n
0xDE: SBC A,n
0xE6: AND n
0xEE: XOR n
0xF6: OR n
0xFE: CP n
```

### 作業

```ruby
# app/cpu.rb の execute に追加
when 0xC6 then add_a(fetch); 8
when 0xCE then adc_a(fetch); 8
when 0xD6 then sub_a(fetch); 8
when 0xDE then sbc_a(fetch); 8
when 0xE6 then and_a(fetch); 8
when 0xEE then xor_a(fetch); 8
when 0xF6 then or_a(fetch); 8
when 0xFE then cp(fetch); 8
```

ALU ヘルパー(フラグ計算は仕様通りに):

```ruby
private

def add_a(value)
  result = @a + value
  @f = 0
  @f |= FLAG_Z if (result & 0xFF) == 0
  @f |= FLAG_H if ((@a & 0x0F) + (value & 0x0F)) > 0x0F
  @f |= FLAG_C if result > 0xFF
  @a = result & 0xFF
end

def adc_a(value)
  carry = (@f & FLAG_C) != 0 ? 1 : 0
  result = @a + value + carry
  @f = 0
  @f |= FLAG_Z if (result & 0xFF) == 0
  @f |= FLAG_H if ((@a & 0x0F) + (value & 0x0F) + carry) > 0x0F
  @f |= FLAG_C if result > 0xFF
  @a = result & 0xFF
end

def sub_a(value)
  result = @a - value
  @f = FLAG_N
  @f |= FLAG_Z if (result & 0xFF) == 0
  @f |= FLAG_H if (@a & 0x0F) < (value & 0x0F)
  @f |= FLAG_C if result < 0
  @a = result & 0xFF
end

def sbc_a(value)
  carry = (@f & FLAG_C) != 0 ? 1 : 0
  result = @a - value - carry
  @f = FLAG_N
  @f |= FLAG_Z if (result & 0xFF) == 0
  @f |= FLAG_H if (@a & 0x0F) < ((value & 0x0F) + carry)
  @f |= FLAG_C if result < 0
  @a = result & 0xFF
end

def and_a(value)
  @a &= value
  @f = FLAG_H
  @f |= FLAG_Z if @a == 0
end

def or_a(value)
  @a |= value
  @f = 0
  @f |= FLAG_Z if @a == 0
end

def xor_a(value)
  @a ^= value
  @f = 0
  @f |= FLAG_Z if @a == 0
end

def cp(value)
  result = @a - value
  @f = FLAG_N
  @f |= FLAG_Z if (result & 0xFF) == 0
  @f |= FLAG_H if (@a & 0x0F) < (value & 0x0F)
  @f |= FLAG_C if result < 0
end
```

ROMを切り替え:

```ruby
def setup(args)
  args.state.rom_path = 'data/cpu_instrs/04-op r,imm.gb'
  args.state.cartridge = Cartridge.new(args, args.state.rom_path)
  args.state.mmu = MMU.new(args.state.cartridge)
  args.state.cpu = CPU.new(args.state.mmu)
end
```

### 動作確認

ターミナルとDragonRuby画面に:

```
04-op r,imm


Passed
```

Failed の場合、フラグ計算の H フラグまわりが怪しい。仕様を再確認。

---

## ステップ C-2: 16bit命令とINC/DEC → `05-op rp.gb` パス (2時間)

**目標**: 16bitレジスタ操作と、INC/DEC命令を実装し、Blargg `05-op rp` がパスすること。

### 必要な命令

```
0x03/13/23/33: INC BC/DE/HL/SP
0x0B/1B/2B/3B: DEC BC/DE/HL/SP
0x09/19/29/39: ADD HL,BC/DE/HL/SP
0x04/0C/14/1C/24/2C/34/3C: INC r/(HL)/A
0x05/0D/15/1D/25/2D/35/3D: DEC r/(HL)/A
0xE8: ADD SP,r8
0xF8: LD HL,SP+r8
0xF9: LD SP,HL
0x08: LD (nn),SP
```

### 作業

```ruby
# 16bit INC/DEC
when 0x03 then self.bc = (bc + 1) & 0xFFFF; 8
when 0x13 then self.de = (de + 1) & 0xFFFF; 8
when 0x23 then self.hl = (hl + 1) & 0xFFFF; 8
when 0x33 then @sp = (@sp + 1) & 0xFFFF; 8
when 0x0B then self.bc = (bc - 1) & 0xFFFF; 8
when 0x1B then self.de = (de - 1) & 0xFFFF; 8
when 0x2B then self.hl = (hl - 1) & 0xFFFF; 8
when 0x3B then @sp = (@sp - 1) & 0xFFFF; 8

# ADD HL,rr
when 0x09 then add_hl(bc); 8
when 0x19 then add_hl(de); 8
when 0x29 then add_hl(hl); 8
when 0x39 then add_hl(@sp); 8

# 8bit INC
when 0x04 then inc8(:b); 4
when 0x0C then inc8(:c); 4
when 0x14 then inc8(:d); 4
when 0x1C then inc8(:e); 4
when 0x24 then inc8(:h); 4
when 0x2C then inc8(:l); 4
when 0x34
  value = @mmu.read(hl)
  result = (value + 1) & 0xFF
  @mmu.write(hl, result)
  @f &= FLAG_C
  @f |= FLAG_Z if result == 0
  @f |= FLAG_H if (value & 0x0F) == 0x0F
  12
when 0x3C then inc8(:a); 4

# 8bit DEC
when 0x05 then dec8(:b); 4
when 0x0D then dec8(:c); 4
when 0x15 then dec8(:d); 4
when 0x1D then dec8(:e); 4
when 0x25 then dec8(:h); 4
when 0x2D then dec8(:l); 4
when 0x35
  value = @mmu.read(hl)
  result = (value - 1) & 0xFF
  @mmu.write(hl, result)
  @f = (@f & FLAG_C) | FLAG_N
  @f |= FLAG_Z if result == 0
  @f |= FLAG_H if (value & 0x0F) == 0
  12
when 0x3D then dec8(:a); 4

# SP関連
when 0xE8
  offset = fetch
  offset -= 256 if offset >= 128
  result = (@sp + offset) & 0xFFFF
  @f = 0
  @f |= FLAG_H if ((@sp & 0x0F) + (offset & 0x0F)) > 0x0F
  @f |= FLAG_C if ((@sp & 0xFF) + (offset & 0xFF)) > 0xFF
  @sp = result
  16
when 0xF8
  offset = fetch
  offset -= 256 if offset >= 128
  @f = 0
  @f |= FLAG_H if ((@sp & 0x0F) + (offset & 0x0F)) > 0x0F
  @f |= FLAG_C if ((@sp & 0xFF) + (offset & 0xFF)) > 0xFF
  self.hl = (@sp + offset) & 0xFFFF
  12
when 0xF9 then @sp = hl; 8
when 0x08
  address = fetch_word
  @mmu.write(address, @sp & 0xFF)
  @mmu.write(address + 1, (@sp >> 8) & 0xFF)
  20
```

ヘルパー:

```ruby
def inc8(reg)
  before = send(reg)
  after = (before + 1) & 0xFF
  send("#{reg}=", after)
  @f &= FLAG_C
  @f |= FLAG_Z if after == 0
  @f |= FLAG_H if (before & 0x0F) == 0x0F
end

def dec8(reg)
  before = send(reg)
  after = (before - 1) & 0xFF
  send("#{reg}=", after)
  @f = (@f & FLAG_C) | FLAG_N
  @f |= FLAG_Z if after == 0
  @f |= FLAG_H if (before & 0x0F) == 0
end

def add_hl(value)
  result = hl + value
  @f &= FLAG_Z
  @f |= FLAG_H if ((hl & 0x0FFF) + (value & 0x0FFF)) > 0x0FFF
  @f |= FLAG_C if result > 0xFFFF
  self.hl = result & 0xFFFF
end
```

### 動作確認

```
05-op rp


Passed
```

`ADD SP,r8` のフラグ計算が独特で、間違えるとここでハマる。仕様を慎重に確認。

---

## ステップ C-3: メモリ間接ALU → `11-op a,(hl).gb` パス (1時間半)

**目標**: (HL)経由のALU命令を実装し、Blargg `11-op a,(hl)` がパスすること。HelloWorld 表示で必須のメモリアクセス命令が揃う。

### 必要な命令

```
0x80-0x87: ADD A,r/(HL)
0x88-0x8F: ADC A,r/(HL)
0x90-0x97: SUB r/(HL)
0x98-0x9F: SBC A,r/(HL)
0xA0-0xA7: AND r/(HL)
0xA8-0xAF: XOR r/(HL)
0xB0-0xB7: OR r/(HL)
0xB8-0xBF: CP r/(HL)
```

### 作業

体系的にディスパッチ:

```ruby
when 0x80..0xBF then execute_alu_r(opcode)
```

```ruby
private

def execute_alu_r(opcode)
  operation_index = (opcode - 0x80) >> 3  # 0=ADD, 1=ADC, 2=SUB, 3=SBC, 4=AND, 5=XOR, 6=OR, 7=CP
  register_index = opcode & 0x07
  value = read_reg(register_index)
  
  case operation_index
  when 0 then add_a(value)
  when 1 then adc_a(value)
  when 2 then sub_a(value)
  when 3 then sbc_a(value)
  when 4 then and_a(value)
  when 5 then xor_a(value)
  when 6 then or_a(value)
  when 7 then cp(value)
  end
  
  register_index == 6 ? 8 : 4
end
```

これで0x80〜0xBFの32命令が一気に実装完了。

### 動作確認

```
11-op a,(hl)


Passed
```

ここまでパスすれば、CPUの基本機能の80%は完成。HelloWorld表示は確実にできる状態。

---

# フェーズD: PPU実装 + HelloWorld (3ステップ / 3〜5時間)

## ステップ D-1: PPU骨組みとLY (1時間)

**目標**: PPUがCPUと同期して動き、LYが0〜153を巡回すること。

### 作業

```ruby
# app/ppu.rb
class PPU
  WIDTH = 160
  HEIGHT = 144
  CYCLES_PER_SCANLINE = 456
  TOTAL_SCANLINES = 154

  attr_reader :framebuffer

  def initialize(mmu)
    @mmu = mmu
    @cycles = 0
    @ly = 0
    @framebuffer = Array.new(WIDTH * HEIGHT, 0)
  end

  def step(cpu_cycles)
    return unless lcd_enabled?
    @cycles += cpu_cycles
    if @cycles >= CYCLES_PER_SCANLINE
      @cycles -= CYCLES_PER_SCANLINE
      @ly = (@ly + 1) % TOTAL_SCANLINES
      @mmu.write_io_direct(0xFF44, @ly)
    end
  end

  private

  def lcd_enabled?
    (@mmu.read(0xFF40) & 0x80) != 0
  end
end
```

Emulatorクラスで統合:

```ruby
# app/emulator.rb
require 'app/cartridge.rb'
require 'app/mmu.rb'
require 'app/cpu.rb'
require 'app/ppu.rb'

class Emulator
  CYCLES_PER_FRAME = 70224

  attr_reader :cpu, :mmu, :ppu

  def initialize(args, rom_path)
    @cartridge = Cartridge.new(args, rom_path)
    @mmu = MMU.new(@cartridge)
    @cpu = CPU.new(@mmu)
    @ppu = PPU.new(@mmu)
  end

  def run_frame
    cycles = 0
    while cycles < CYCLES_PER_FRAME
      step_cycles = @cpu.step
      @ppu.step(step_cycles)
      cycles += step_cycles
    end
  end

  def serial_buffer
    @mmu.serial_buffer
  end
end
```

main.rb 更新:

```ruby
require 'app/emulator.rb'

def setup(args)
  args.state.rom_path = 'data/hello.gb'  # HelloWorld ROMに切り替え
  args.state.emulator = Emulator.new(args, args.state.rom_path)
end

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  unless args.state.error
    begin
      args.state.emulator.run_frame
    rescue => e
      args.state.error = "#{e.message}"
    end
  end
  
  render_header(args)
  render_status(args)
  render_serial(args)
end

def render_status(args)
  emulator = args.state.emulator
  args.outputs.labels << { x: 20, y: 600, text: emulator.cpu.state_string, r: 255, g: 255, b: 255 }
  args.outputs.labels << { x: 20, y: 570, text: "LY: #{emulator.mmu.read(0xFF44)}", r: 255, g: 255, b: 255 }
  args.outputs.labels << { x: 20, y: 540, text: "LCDC: 0x#{emulator.mmu.read(0xFF40).to_s(16)}", r: 255, g: 255, b: 255 }
  args.outputs.labels << { x: 20, y: 510, text: "FPS: #{args.gtk.current_framerate.to_i}", r: 200, g: 200, b: 200 }
  if args.state.error
    args.outputs.labels << { x: 20, y: 480, text: args.state.error.to_s.split("\n").first, r: 255, g: 100, b: 100, size_enum: -2 }
  end
end
```

### 動作確認

HelloWorld の ROM が動き始めると、LCDC が `0x91` 付近の値になり、LY が激しく変化する(60fpsで何度も0〜153を巡回)。エラーが出ている場合は未実装命令を追加(CB系のSWAP、SLA、SRA、SRL等が必要かもしれない)。

---

## ステップ D-2: タイル描画 (1時間半)

**目標**: PPUがVRAMを読んでフレームバッファを生成できること。

### 作業

```ruby
# app/ppu.rb
def step(cpu_cycles)
  return unless lcd_enabled?
  @cycles += cpu_cycles
  if @cycles >= CYCLES_PER_SCANLINE
    @cycles -= CYCLES_PER_SCANLINE
    render_scanline(@ly) if @ly < HEIGHT
    @ly = (@ly + 1) % TOTAL_SCANLINES
    @mmu.write_io_direct(0xFF44, @ly)
  end
end

private

def render_scanline(line)
  lcdc = @mmu.read(0xFF40)  # LCD Control register
  return if (lcdc & 0x01) == 0  # BG無効

  scroll_y = @mmu.read(0xFF42)
  scroll_x = @mmu.read(0xFF43)
  bg_palette = @mmu.read(0xFF47)

  tile_map_base = (lcdc & 0x08) != 0 ? 0x9C00 : 0x9800
  unsigned_addressing = (lcdc & 0x10) != 0

  y = (line + scroll_y) & 0xFF

  WIDTH.times do |x|
    target_x = (x + scroll_x) & 0xFF
    tile_row = y / 8
    tile_col = target_x / 8
    tile_index = @mmu.read(tile_map_base + tile_row * 32 + tile_col)

    tile_address = if unsigned_addressing
      0x8000 + tile_index * 16
    else
      signed_index = tile_index >= 128 ? tile_index - 256 : tile_index
      0x9000 + signed_index * 16
    end

    pixel_y = y % 8
    pixel_x = target_x % 8
    byte_low = @mmu.read(tile_address + pixel_y * 2)
    byte_high = @mmu.read(tile_address + pixel_y * 2 + 1)

    bit = 7 - pixel_x
    color_index = (((byte_high >> bit) & 1) << 1) | ((byte_low >> bit) & 1)
    color = (bg_palette >> (color_index * 2)) & 0x03

    @framebuffer[line * WIDTH + x] = color
  end
end
```

確認用ラベル追加:

```ruby
non_zero_count = args.state.emulator.ppu.framebuffer.count { |c| c != 0 }
args.outputs.labels << { x: 20, y: 480, text: "Non-zero pixels: #{non_zero_count}", r: 200, g: 200, b: 200 }
```

### 動作確認

`Non-zero pixels` の値が増える。HelloWorld のフォントタイルが描画されているはず。

---

## ステップ D-3: 画面表示 → HelloWorld表示 (1時間半)

**目標**: フレームバッファをDragonRubyの画面に描画して、Hello World! を目視できること。

### 作業

```ruby
# app/main.rb
PALETTE = [
  { r: 0xE0, g: 0xF8, b: 0xD0 },
  { r: 0x88, g: 0xC0, b: 0x70 },
  { r: 0x34, g: 0x68, b: 0x56 },
  { r: 0x08, g: 0x18, b: 0x20 }
]

GAMEBOY_WIDTH = 160
GAMEBOY_HEIGHT = 144
DISPLAY_SCALE = 4

def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  unless args.state.error
    begin
      args.state.emulator.run_frame
    rescue => e
      args.state.error = "#{e.message}"
    end
  end
  
  render_gameboy(args)
  render_header(args)
  render_status(args)
  render_serial(args)
end

def render_gameboy(args)
  render_target = args.outputs[:gameboy]
  render_target.width = GAMEBOY_WIDTH
  render_target.height = GAMEBOY_HEIGHT

  framebuffer = args.state.emulator.ppu.framebuffer
  pixels = []
  GAMEBOY_HEIGHT.times do |y|
    GAMEBOY_WIDTH.times do |x|
      color = PALETTE[framebuffer[y * GAMEBOY_WIDTH + x]]
      pixels << {
        x: x,
        y: GAMEBOY_HEIGHT - 1 - y,
        w: 1, h: 1,
        r: color[:r], g: color[:g], b: color[:b]
      }
    end
  end
  render_target.solids << pixels

  args.outputs.sprites << {
    x: 20, y: 100,
    w: GAMEBOY_WIDTH * DISPLAY_SCALE, h: GAMEBOY_HEIGHT * DISPLAY_SCALE,
    path: :gameboy
  }
end
```

### 動作確認

🎉 **第二の達成感: 画面に "Hello World!" が表示される**

CPUがBlarggテストでお墨付きをもらっているので、画面が出ない場合の原因はほぼ確実に PPU 側。デバッグ範囲が限定されている。

### よくあるトラブル

**症状: 真っ白**
- LCDC bit 7 を確認
- LY が更新されているか確認

**症状: 文字が崩れる**
- LCDC bit 4(タイルデータ選択)が正しいか
- unsigned/signed の切り替えが正しいか

**症状: 一部の文字だけ抜ける**
- BGP パレット適用が正しいか

---

# フェーズE: ブートROM対応 + Nintendoロゴ表示 (3ステップ / 4〜7時間)

ここまで来ればCPUとPPUの基本は完成している。フェーズEでは、本物のGame Boy起動シーケンスを再現する。

ブートROM(256バイト)はカートリッジ起動前に実行されるプログラムで、以下を行う:

1. VRAMをクリア
2. カートリッジヘッダ(0x0104〜0x0133)からNintendoロゴデータを読む
3. ロゴデータを2倍に拡大してVRAMのタイルデータ領域に書き込む
4. タイルマップにロゴを配置
5. パレット設定、画面をスクロールイン
6. ロゴチェックサム検証
7. 0x0100にジャンプ → ゲーム本体実行

### HelloWorldとの違い

HelloWorld は CPU 初期状態を「ブートROM終了後の値」に固定して 0x0100 から開始した。フェーズEではブートROMを実際に実行するので、CPU 初期状態は全レジスタ0、PC=0x0000 から始める。

## ステップ E-1: ブートROM対応とMMU切り替え (1時間半)

**目標**: ブートROMが読み込まれ、PC=0x0000 から実行が始まり、最初の数命令(LD SP, XOR A, LD HL)が動くこと。

### 作業

```ruby
# app/boot_rom.rb
class BootRom
  def initialize(args, path)
    @data = args.gtk.read_file(path).bytes
    raise "Boot ROM size invalid: #{@data.size}" unless @data.size == 256
  end

  def read(address)
    @data[address]
  end
end
```

MMUを更新して、ブートROM領域(0x0000〜0x00FF)を扱えるようにする:

```ruby
# app/mmu.rb
class MMU
  def initialize(cartridge, boot_rom = nil)
    @cartridge = cartridge
    @boot_rom = boot_rom
    @vram = Array.new(0x2000, 0)  # Video RAM (8KB)
    @wram = Array.new(0x2000, 0)  # Work RAM (8KB)
    @hram = Array.new(0x7F, 0)    # High RAM (127 bytes)
    @oam = Array.new(0xA0, 0)     # Object Attribute Memory (sprite info)
    @io = Array.new(0x80, 0)      # I/O Registers
    @ie = 0                        # Interrupt Enable register
    @serial_buffer = ""
    @boot_rom_enabled = !@boot_rom.nil?
  end

  def read(address)
    case address
    when 0x0000..0x00FF
      @boot_rom_enabled ? @boot_rom.read(address) : @cartridge.read(address)
    when 0x0100..0x7FFF then @cartridge.read(address)
    when 0x8000..0x9FFF then @vram[address - 0x8000]
    when 0xC000..0xDFFF then @wram[address - 0xC000]
    when 0xFE00..0xFE9F then @oam[address - 0xFE00]
    when 0xFF00..0xFF7F then @io[address - 0xFF00]
    when 0xFF80..0xFFFE then @hram[address - 0xFF80]
    when 0xFFFF then @ie
    else 0xFF
    end
  end

  def write(address, value)
    value &= 0xFF
    case address
    when 0x8000..0x9FFF then @vram[address - 0x8000] = value
    when 0xC000..0xDFFF then @wram[address - 0xC000] = value
    when 0xFE00..0xFE9F then @oam[address - 0xFE00] = value
    when 0xFF00..0xFF7F
      @io[address - 0xFF00] = value
      handle_serial(address, value)
      @boot_rom_enabled = false if address == 0xFF50 && value != 0
    when 0xFF80..0xFFFE then @hram[address - 0xFF80] = value
    when 0xFFFF then @ie = value
    end
  end

  # ... 既存のメソッド ...
end
```

CPUに「ブートROMから始める」モードを追加:

```ruby
# app/cpu.rb
def initialize(mmu, skip_boot: true)
  @mmu = mmu
  if skip_boot
    reset_post_boot
  else
    reset_pre_boot
  end
end

def reset_post_boot
  @a = 0x01; @f = 0xB0
  @b = 0x00; @c = 0x13
  @d = 0x00; @e = 0xD8
  @h = 0x01; @l = 0x4D
  @sp = 0xFFFE
  @pc = 0x0100
  @ime = false
end

def reset_pre_boot
  @a = @b = @c = @d = @e = @h = @l = @f = 0
  @sp = 0
  @pc = 0x0000
  @ime = false  # Interrupt Master Enable
end
```

Emulatorクラスを更新:

```ruby
# app/emulator.rb
class Emulator
  CYCLES_PER_FRAME = 70224

  attr_reader :cpu, :mmu, :ppu

  def initialize(args, rom_path, boot_path = nil)
    @cartridge = Cartridge.new(args, rom_path)
    @boot_rom = boot_path ? BootRom.new(args, boot_path) : nil
    @mmu = MMU.new(@cartridge, @boot_rom)
    @cpu = CPU.new(@mmu, skip_boot: @boot_rom.nil?)
    @ppu = PPU.new(@mmu)
  end

  # ...
end
```

main.rbでブートROM起動モードに切り替え:

```ruby
def setup(args)
  args.state.rom_path = 'data/tetris.gb'  # 何でも良い、ヘッダにロゴが入っているROM
  args.state.boot_path = 'data/dmg_boot.bin'
  args.state.emulator = Emulator.new(args, args.state.rom_path, args.state.boot_path)
end
```

### 動作確認

エラーが出るとしたら、未実装の命令(`0xCB 0x7C`(BIT 7,H)、`0x32`(LD (HL-),A) など)。エラーメッセージで停止した PC を確認し、ブートROMの逆アセンブリ(https://github.com/ISSOtm/gb-bootroms)と照合する。

ブートROMの最初の数命令:

```
0x0000: 31 FE FF       LD SP,$FFFE       ← 既に実装済み
0x0003: AF             XOR A             ← 既に実装済み
0x0004: 21 FF 9F       LD HL,$9FFF       ← 既に実装済み
0x0007: 32             LD (HL-),A        ← 実装済み
0x0008: CB 7C          BIT 7,H           ← 未実装の可能性あり
0x000A: 20 FB          JR NZ,-5          ← 既に実装済み
```

`0xCB 0x7C` (BIT 7,H) はBlarggの `10-bit ops` に含まれていなければ未実装のはず。次のステップで実装する。

---

## ステップ E-2: CB ビット操作命令 (1時間半)

**目標**: CB プレフィックス命令(BIT、RL、その他のビット操作)を実装し、ブートROMのロゴ展開ループが完走すること。

### 必要な命令

ブートROMで使われるCB命令は限られている:

```
0xCB 0x11: RL C        ← ロゴ展開の本体
0xCB 0x7C: BIT 7,H     ← VRAMクリアループの条件
```

ただし、せっかくなのでCB命令全体を体系的に実装してしまうのが効率的。Blargg `10-bit ops.gb` も同時にパスする。

### CB命令の体系

CB プレフィックスの後の1バイトで操作が決まる。`0xCB XX` の `XX` は、

- 上位2ビット: 操作種別(00=ローテート系, 01=BIT, 10=RES, 11=SET)
- 下位3ビット: 対象レジスタ(0=B, 1=C, 2=D, 3=E, 4=H, 5=L, 6=(HL), 7=A)

ローテート系はさらに上位5ビットで細分化:

```
0x00-0x07: RLC r
0x08-0x0F: RRC r
0x10-0x17: RL r
0x18-0x1F: RR r
0x20-0x27: SLA r
0x28-0x2F: SRA r
0x30-0x37: SWAP r
0x38-0x3F: SRL r
0x40-0x7F: BIT n,r (nは(opcode-0x40)>>3)
0x80-0xBF: RES n,r
0xC0-0xFF: SET n,r
```

### 作業

```ruby
# app/cpu.rb
when 0xCB then execute_cb(fetch)
```

```ruby
private

def execute_cb(opcode)
  register_index = opcode & 0x07
  
  case opcode
  when 0x00..0x07 then cb_rlc(register_index)
  when 0x08..0x0F then cb_rrc(register_index)
  when 0x10..0x17 then cb_rl(register_index)
  when 0x18..0x1F then cb_rr(register_index)
  when 0x20..0x27 then cb_sla(register_index)
  when 0x28..0x2F then cb_sra(register_index)
  when 0x30..0x37 then cb_swap(register_index)
  when 0x38..0x3F then cb_srl(register_index)
  when 0x40..0x7F then cb_bit((opcode - 0x40) >> 3, register_index)
  when 0x80..0xBF then cb_res((opcode - 0x80) >> 3, register_index)
  when 0xC0..0xFF then cb_set((opcode - 0xC0) >> 3, register_index)
  end
  
  # サイクル数: BITは8, それ以外で(HL)操作なら16, レジスタなら8
  if (0x40..0x7F).include?(opcode) && register_index == 6
    12  # BIT n,(HL)
  elsif register_index == 6
    16  # その他の(HL)操作
  else
    8
  end
end

def cb_rlc(register_index)
  value = read_reg(register_index)
  carry = (value & 0x80) != 0
  result = ((value << 1) | (carry ? 1 : 0)) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry
end

def cb_rrc(register_index)
  value = read_reg(register_index)
  carry = (value & 0x01) != 0
  result = ((value >> 1) | (carry ? 0x80 : 0)) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry
end

def cb_rl(register_index)
  value = read_reg(register_index)
  carry_in = (@f & FLAG_C) != 0 ? 1 : 0
  carry_out = (value & 0x80) != 0
  result = ((value << 1) | carry_in) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry_out
end

def cb_rr(register_index)
  value = read_reg(register_index)
  carry_in = (@f & FLAG_C) != 0 ? 0x80 : 0
  carry_out = (value & 0x01) != 0
  result = ((value >> 1) | carry_in) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry_out
end

def cb_sla(register_index)
  value = read_reg(register_index)
  carry = (value & 0x80) != 0
  result = (value << 1) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry
end

def cb_sra(register_index)
  value = read_reg(register_index)
  carry = (value & 0x01) != 0
  result = ((value >> 1) | (value & 0x80)) & 0xFF  # MSB保持
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry
end

def cb_swap(register_index)
  value = read_reg(register_index)
  result = ((value << 4) | (value >> 4)) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
end

def cb_srl(register_index)
  value = read_reg(register_index)
  carry = (value & 0x01) != 0
  result = (value >> 1) & 0xFF
  write_reg(register_index, result)
  @f = 0
  @f |= FLAG_Z if result == 0
  @f |= FLAG_C if carry
end

def cb_bit(bit_number, register_index)
  value = read_reg(register_index)
  zero = (value & (1 << bit_number)) == 0
  @f = (@f & FLAG_C) | FLAG_H
  @f |= FLAG_Z if zero
end

def cb_res(bit_number, register_index)
  value = read_reg(register_index)
  result = v & ~(1 << bit_number) & 0xFF
  write_reg(register_index, result)
end

def cb_set(bit_number, register_index)
  value = read_reg(register_index)
  result = v | (1 << bit_number)
  write_reg(register_index, result)
end
```

ついでに、ブートROMで使われる残りの非CB命令も確認する。多くはBlarggのテストで実装済みのはず。万一足りない命令でエラーが出たら個別に追加。

特にRLA(0x17)のフラグ計算を確認:

```ruby
when 0x17  # RLA
  carry_in = (@f & FLAG_C) != 0 ? 1 : 0
  carry_out = (@a & 0x80) != 0
  @a = ((@a << 1) | carry_in) & 0xFF
  @f = carry_out ? FLAG_C : 0  # RLAはZフラグを常にクリアする(CB RLとは違う)
  4
```

### 動作確認

ブートROMの実行が、未実装命令で止まらずに進むようになる。VRAMダンプでロゴデータが書き込まれているか確認:

```ruby
# main.rb にデバッグ機能を追加
if args.inputs.keyboard.key_down.v
  emulator = args.state.emulator
  puts "=== VRAM dump (0x8000-0x81FF) ==="
  (0x8000..0x81FF).step(16) do |address|
    bytes = (0...16).map { |i| emulator.mmu.read(address + i).to_s(16).rjust(2, '0') } puts "#{addressess.to_s(16)}: #{bytes.join(' ')}"
  end
end
```

V キーを押した時、0x8010 以降に非ゼロのバイト列(ロゴのビットパターン)が並んでいれば、ロゴ展開が成功している。

また、Blargg `10-bit ops.gb` を読み込ませて Passed することも確認できる(ROM切り替えで)。

---

## ステップ E-3: ブートROM完走 → Nintendoロゴ表示 (1時間半〜2時間)

**目標**: ブートROMが256バイト最後まで実行され、画面にNintendoロゴがスクロールインで表示されること。

### ブートROMの後半で必要な処理

ブートROM後半では以下が行われる:

1. ロゴをタイルマップに配置(0x9904 付近)
2. LCDC を有効化(0xFF40 = 0x91)
3. ロゴをスクロールイン(SCYを徐々に変化)
4. オーディオ初期化(無視してOK)
5. ロゴチェックサム検証
6. 0x0100へジャンプ

### よくある追加実装

ブートROMはサブルーチンを多用するので、CALL/RET は必須(実装済み)。それ以外で必要そうなものは概ね Blargg テストで実装済みのはず。

万一エラーで止まった場合、エラーメッセージのオペコードを確認して個別追加。

### ブートROM逆アセンブリの参照

詰まったら https://github.com/ISSOtm/gb-bootroms のソースを参照する。例えば 0x0095 付近のロゴ展開ループ:

```
0x0095:                  ; ロゴ展開ループ
    ld c, $04            ; カウンタ
0x0097:
    push bc              ; 退避
    rl c                 ; Cをローテート
    rla                  ; AをローテートしてキャリーをCに
    pop bc
    rl c
    rla
    dec b
    jr nz, $0097
    ; ...
```

このコードがエミュレータ内で正しく動くと、VRAMにビット展開されたロゴが書き込まれる。

### 起動時の特別処理

ブートROMが終了するとき、`LD A,$01 / LD ($FF50),A` を実行してブートROMを無効化する。これでMMUが0x0000〜0x00FFをカートリッジ側に切り替える。すでに実装済み(MMUのwrite内で`@boot_rom_enabled = false`)。

### ロゴ表示の維持

ブートROMが0x0100にジャンプした後、Tetris などの実機ROMはタイトル画面の処理を始めるが、テストROMとして使う場合は何も起きない可能性がある。**ロゴ表示そのものを観察するには、ブートROMが完走した直後の画面状態が見えれば十分**。

main.rbでロゴ表示状態を維持するため、PCが0x0100に到達したら一時停止するデバッグ機能を入れておくと便利:

```ruby
# main.rb
def tick(args)
  setup(args) if args.state.tick_count == 0
  args.outputs.background_color = [30, 30, 30]
  
  unless args.state.error || args.state.paused
    begin
      args.state.emulator.run_frame
      
      # PCが0x0100に到達したら一時停止(ロゴ表示維持)
      if args.state.emulator.cpu.pc == 0x0100 && !args.state.boot_done
        args.state.boot_done = true
        args.state.paused = true
      end
    rescue => e
      args.state.error = "#{e.message}"
    end
  end
  
  # スペースキーで再開
  if args.inputs.keyboard.key_down.space
    args.state.paused = false
  end
  
  render_gameboy(args)
  render_header(args)
  render_status(args)
  render_serial(args)
  
  if args.state.paused
    args.outputs.labels << { x: 640, y: 50, text: "Boot ROM completed - Press SPACE to continue", alignment_enum: 1, r: 255, g: 255, b: 100 }
  end
end
```

### 動作確認

🎉 **第三の達成感: 画面に Nintendoロゴが表示される**

ブートROMが実行され、ロゴが上から下にスクロールインしてきて、画面中央付近で停止する。「Boot ROM completed」というメッセージが出れば、ブートROMが正しく完走した証拠。

### よくあるトラブル

**症状: ロゴが縞模様 / 半分しか出ない**
- RLA(0x17)とCB RL(0xCB 0x10-0x17)のフラグ計算を確認
- 特にRLAは Z フラグを常に 0 にする点に注意(CB RLとは挙動が違う)

**症状: ロゴがスクロールしない**
- SCYレジスタ(0xFF42)の書き込みが反映されているか
- フレームごとにSCY値が変わっているかログで確認

**症状: ロゴ表示後すぐに変な画面になる**
- 0x0100 以降のカートリッジコードが実行されている可能性
- 上記の「PC=0x0100で一時停止」デバッグ機能で観察すれば解決

**症状: ロゴチェックサムで止まる**
- カートリッジヘッダ(0x0104〜0x0133)のロゴデータが正しいか確認
- Tetrisなど正規のROMヘッダなら問題ないはず

**症状: そもそもブートROM途中でクラッシュ**
- エラーメッセージのオペコードをgbopsで確認
- 多くは未実装のCB命令か、フラグ計算が違う命令
- 1命令ずつステップ実行(スペースキー)で原因箇所を特定できる

---

# 達成後に向けて

Nintendoロゴ表示まで来たら、エミュレータ基礎の80%は完成している。次に向かうべき道:

## 短期目標 (+5〜10時間)

**残りのBlarggテストもパス**

実装すべき命令の補完:
- `01-special.gb` - DAA命令、CPL、SCF、CCF
- `02-interrupts.gb` - 割り込み実装
- `03-op sp,hl.gb` - SP/HL関連
- `07-jr,jp,call,ret,rst.gb` - 制御フロー(RST命令追加)
- `08-misc instrs.gb` - その他
- `09-op r,r.gb` - レジスタ間ALU
- `10-bit ops.gb` - CB系ビット操作

これでCPUは完璧に近い状態になる。

## 中期目標 (+10〜20時間)

**HelloWorldリポジトリの次のサンプルを動かす**

- 画像表示(242タイル) - タイルデータの正確性検証
- 背景スクロール - SCX/SCYの実装検証
- ジョイパッド読み取り - 入力割り込み
- スプライト描画 - OAM、LCDC bit 1

## 長期目標 (+30〜60時間)

**Tetrisが起動してプレイできる**

タイマー、VBlank割り込み、スプライト、ジョイパッドが揃えばTetrisがプレイできる。

# 参考リンク

- Pan Docs: https://gbdev.io/pandocs/
- gbops オペコード表: https://izik1.github.io/gbops/
- Blargg test ROMs: https://github.com/retrio/gb-test-roms
- emudev.de: https://emudev.de/gameboy-emulator/testing-our-cpu/
- HelloWorld サンプル: https://github.com/gitendo/helloworld
- gameboy-doctor: https://github.com/robert/gameboy-doctor

# Tips

1. **シリアル出力は最強のデバッグツール**。PPU実装前に「Passed」が見えるのは精神衛生に良い
2. **ROMの切り替えは setup の1行を変えるだけ**。テストのたびに簡単に切り替えられる構造にしておく
3. **連続実行モード**を最初から作っておく。1命令ずつステップする時間がもったいない
4. **未実装命令で例外**にしておくと、必要な命令だけが浮かび上がる
5. **DragonRubyのホットリロード**を活かす。コードを変えて即座に動作確認できる
6. **Failed の数字**は失敗したテストケース番号。BlarggのソースコードがGitHubにあるので、対応するテストの内容を確認できる
