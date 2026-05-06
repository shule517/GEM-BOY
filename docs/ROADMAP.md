# GEM BOY — 実装ロードマップ

DragonRuby Game Toolkit で Ruby 製 Game Boy エミュレータ「**GEM BOY**」を作る。

## 戦略: 3 段マイルストーンを最短経路で順番に達成

「Blargg を全 Pass させてから先に進む」旧戦略も「Nintendo ロゴ一発狙い」中継戦略もやめ、**3 つの視覚的マイルストーンを近い順に並べて段階的に達成する**ルートに改める。

1. **HELLO WORLD 表示**(`hello.gb` を skip_boot 起動)★ 第一マイルストーン
2. **Nintendo ロゴ表示**(ブートROM 経由 + スクロールイン)★ 第二マイルストーン
3. **tobu.gb タイトル画面**(MBC1 + スプライト + 入力)★ 第三マイルストーン

利点:

- **「画面に何か出る」最初の瞬間が最も早く来る**(約 5〜6h で HELLO WORLD)。長時間進捗が見えない不安を解消
- 各マイルストーン到達時に **PPU / CPU / MMU の動作確認済みコンポーネント**が増えていく → 次段階のデバッグ時に「これは動いている」と切り分けがしやすい
- HELLO WORLD で PPU が動いているとブートROM 挑戦時に「PPU は OK、犯人は CPU 側」と限定でき、Nintendo ロゴ挑戦時の Blargg 診断(E-6)の時間が短くなる傾向

## 全体像

| フェーズ | 内容 | 想定時間 | 到達点 | 進捗 |
|---|---|---|---|---|
| A. 土台 | Cartridge + MMU 骨組み + シリアル出力 | 3〜4h | ROM が読める、シリアル出力動く | 3/3 [完了] |
| B. CPU 基本命令 | hello.gb が使う命令一式(CB-prefix なし) | 2〜2.5h | HELLO WORLD に必要な命令を踏める | 2/2 [完了](INC/DEC・AND・CALL/RET・JR Z/JR 無条件まで追加され、HELLO WORLD 統合シナリオが HALT 到達)|
| C. PPU 最小実装 | LCDC + LY + BG タイル描画(SCY=0 固定) | 2〜2.5h | タイルが描ける | 2/2 [完了](C-1: LY ティック / C-2: BG タイル描画。framebuffer に画素が乗るようになった)|
| D. HELLO WORLD 表示 | skip_boot 起動 + 画面確認 | 1h | **画面に "Hello World!" 表示** ★第一 | 2/2 [完了] ★ **第一マイルストーン達成**(`hello.gb` の `Hello 8-bit world!` が DragonRuby で描画された)|
| E. Nintendo ロゴ表示 | ブートROM 用追加命令 + CB-prefix + ブートROM mapping + スクロール | 2.5〜6.5h | **正しい Nintendo ロゴ** ★第二 | 3/7(E-1: STOP まで含む全 245 命令完成。E-2: **CB-prefix 全 256 命令完成**(RLC/RRC × 8 を追加)。残るは E-3〜E-7 と割り込み機構)|
| F. tobu.gb タイトル | MBC1 + スプライト + 入力 + タイマー | 6.5〜10h | **tobu.gb タイトル表示** ★第三 | 0/5 |

合計 21 ステップ、想定 17〜26.5h。**現在 13 ステップ完了(フェーズ A + B-1, B-2 + C-1, C-2 + D-1, D-2 + E-1, E-2 完了)**。★ **第一マイルストーン(HELLO WORLD 表示)達成**。CPU 命令実装は完成、残るは PPU 機能(SCY スクロール)・MMU 機能(ブート ROM mapping)・割り込み機構。

### 進行中の発見(2026-05-04 時点)

#### 1. ★ 第一マイルストーン達成: 実機 DragonRuby で `Hello 8-bit world!` が描画された

`./dragonruby .` で `data/hello.gb` を skip_boot 起動 → 左ペインに `Hello 8-bit world!` が DMG パレットで表示。右ペインには PC=0x01B9 / LY=74 が表示され、CPU が HALT 後も PPU が回り続けていることが目視できる。**フェーズ D 完了**。

#### 2. CPU は 245 通常 opcode + 256 CB opcode 実装(計 501 / 501 = **100%**、不正 opcode 11 個は実機ロックアップ相当で未実装のまま)

**実装済みカテゴリ(主要)**:
- **8bit ロード**: `LD r, u8` × 8、`LD r, r'` × 64、`LD A, (rr)` × 8、`LD A, (u16)` / `LD (u16), A`、I/O ポート系 (`LD (FF00+u8/C), A` 等)
- **16bit ロード**: `LD rr, u16` × 4、`LD (u16), SP`、`LD SP, HL`、`LD HL, SP+e8`(下位ニブル/バイトでフラグ計算)
- **PUSH / POP**: BC/DE/HL/AF 全 8 個(`push_u16` / `pop_u16` ヘルパで対称配置、`af` getter/setter も追加)
- **8bit 論理演算**: `AND/XOR/OR/CP r` × 32 + 即値 4 個 = 36 個
- **8bit 算術**: `ADD A, r/u8` × 9、`ADC A, r/u8` × 9、`SUB A, r/u8` × 9、`SBC A, r/u8` × 9(`add_a` / `adc_a` / `sub_a` / `sbc_a` ヘルパでフラグ計算を集約)
- **16bit 算術**: `ADD HL, rr` × 4(下位 12bit ハーフキャリー判定対応、Z 保持)、`ADD SP, e8` × 1(下位ニブル/バイトでフラグ計算)
- **INC / DEC**: 8bit レジスタ系 14 個 + 16bit ペア 8 個 + `INC (HL)` / `DEC (HL)` × 2
- **条件分岐**: JR cc × 5、JP cc × 6、CALL cc × 5、RET cc × 4(`jp(cc:)` / `jr(cc:)` / `call(cc:)` / `ret(condition:)` ヘルパで対称配置、`registers.nz?` / `z?` / `nc?` / `c?` 述語も追加)
- **コール/リターン**: 無条件 CALL / RET、**RST 00H〜38H × 8**(`rst(address:)` ヘルパ)、**RETI**(IME=1 して RET)
- **割り込み制御**: `DI` / `EI`(EI は即時版。1命令遅延仕様は TODO)
- **A 専用ローテート**: `RLCA` / `RRCA` / `RLA` / `RRA`(Z=0 固定の高速版、CB 経由の汎用版とは独立)
- **A 単項演算**: `CPL`(全ビット反転、N=H=1)、`SCF`(C=1)、`CCF`(C 反転)、`DAA`(BCD 補正)
- **CB-prefix**: BIT/RES/SET 計 192 個 + RR ファミリー 8 個 + RL ファミリー 8 個 + SRL ファミリー 8 個 + **SLA ファミリー 8 個**(`SLA (HL)` 含む)+ **SRA ファミリー 8 個** + **SWAP ファミリー 8 個**

**PPU(C-1, C-2)** 完了済み(LY ティック + BG タイル描画)。**HELLO WORLD** は HALT(PC=0x01B8)到達で halted=true、実機でも文字描画確認済み(2026-05-02)。

**Blargg 進捗**: cpu_instrs 個別 ROM 11 個 + instr_timing / mem_timing / mem_timing-2 / halt_bug / interrupt_time / oam_bug / dmg_sound 個別 ROM 計 41 件のシナリオテストが `spec/app/emulator/gb-test-roms/` 配下に整備されており、停止点が **`0xC4 (CALL NZ)` → `0xC6 (ADD A, u8)` → `0xD6 (SUB A, u8)` → CB `0x38` (SRL B)** と前進し、`10-bit ops.gb` で **初の Pass を達成**。

**残る未実装機能**(命令そのものは完成、機能面で残るもの):
- 割り込み機構: `EI` の 1命令遅延、IF/IE による割り込みベクタへの自動 dispatch、PPU の VBlank IF 立ち上げ
- Timer: DIV / TIMA / TMA / TAC とオーバーフロー時の IF bit2 立ち上げ
- HALT 解除条件: IF & IE != 0 で復帰、HALT bug
- 不正 opcode 11 個(0xD3/DB/DD/E3/E4/EB/EC/ED/F4/FC/FD): 実機ロックアップ相当。現状は `nil` で raise する設計(デバッグ目的では推奨)。第三マイルストーン以降で必要なら実機相当のロックアップ実装へ切り替え

**`RRC A` (0x0F) のバグ**: 代入先が `registers.b` になっていて A が更新されない、Z 判定も旧 A で誤判定。要修正。

#### 3. ブートROM: VRAM クリアループ(`LD (HL+),A` / `BIT 5,H` / `JR Z,-5`)で 200,000 サイクル枠を超過して停止

`spec` の "ブートROM 完走" は SameBoy `dmg_boot.bin` の VRAM クリア部 PC=0x0007〜0x000A の 4 命令ループに入っており、**ループが正しく回りきる前に上限サイクル数 200,000 で打ち切られている**(`expected: 256, got: 7`)。原因は実装バグではなく、VRAM 8KB を 1 バイトずつ詰めるのに `(8 + 8 + 12) × 8192 ≈ 230,000` サイクル必要なためテスト枠が足りない。**枠を伸ばすか、PPU を組み込んで実機相当の挙動にすれば抜けるはず**。先送り判断中。

#### 4. クラス分離・リネーム系のリファクタリング

- **`CpuRegisters` クラスを新設**(`app/emulator/cpu_registers.rb`)— 旧 `Register` をリネームして昇格、A/B/C/D/E/H/L/F に加えて **PC / SP も移譲**(`registers.pc` / `registers.sp` で参照)。`set_flags(zero: ..., negative: ..., half_carry: ..., carry: ...)` と `zero_flag` / `negative_flag` / `half_carry_flag` / `carry_flag` の getter/setter を提供。**`af` getter / setter / `nz?` / `z?` / `nc?` / `c?` 述語**(condition codes)も追加され、条件分岐 16 命令が `registers.nz?` のように 1 行で書ける
- **`LcdRegisters` クラスを新設**(`app/emulator/lcd_registers.rb`)— LCDC / SCY / SCX / BGP の読み出しとビットデコードを PPU から分離。`lcd_enabled?` / `bg_enabled?` / `bg_tile_map_address` / `bg_tile_data_unsigned?` / `scy` / `scx` / `bgp` を提供。PPU 側からは `0xFF40` などのマジックナンバーが消えた
- **`Bit.bit_at(value, n)` / `Bit.set_bit(value, n, flag)` を追加** — `value[n]` / フラグ反映のロジックを 1 か所に集約。CB-prefix の BIT/RES/SET、F レジスタの個別ビットアクセスから利用
- **`core_ext/bit_index.rb` を追加** — DragonRuby (mruby) は標準で `Integer#[]` を提供しないので、`value[n]` を MRI / mruby 両対応にする monkey patch。`Bit.bit_at` の置き換えとして使える
- **スタック操作ヘルパを追加** — `push_u16(value)` / `pop_u16` を CPU に、`sp_increment_u16` / `sp_decrement_u16` を CpuRegisters に。CALL/RET/PUSH/POP の 8 命令と RET が同じプリミティブ上で書けて対称
- **条件分岐ヘルパ `jp(cc:)` / `jr(cc:)` / `call(cc:)` を追加** — `fetch_u16/i8 → 条件判定 → ジャンプ/push の有無 → サイクル数返却` を 1 メソッドに集約。利用側は `table[0xC2] = -> { jp(cc: registers.nz?) }` のような 1 行記述に統一できた

#### 5. Disassembler とトレースモードを追加

- **`Disassembler` クラス**(`app/emulator/disassembler.rb`)を新設 — 1 命令を `00B8: E5          PUSH HL` 形式に整形。CB-prefix も全 256 個カバー、JP/JR/CALL/RET cc は実行後に `# Z=1 → taken (=> 0x01BF)` のような **判定値 + 結果 + 飛び先** を末尾に付与。`#` の右側に **レジスタ変化 (`A: 0x12→0xCE`)、メモリ書き込み (`(0x9900): 0x00→0x48`)、フラグ変化 (`Z=1 N=0 H=1 C=0`)、条件分岐結果** をまとめて出力するので、命令ごとの状態遷移が 1 行で読める
- **`CPU.new(mmu, skip_boot:, trace: false)` の trace 引数** — テスト実行時はデフォルト `false` で disasm 出力を完全 OFF にし、`app/main.rb` 側だけ `trace: true` で実機トレースを残す。trace OFF 時は `before_step` / `after_step` も呼ばれないので RSpec での Blargg 41 件が 1〜2 秒で完走する

#### 6. Blargg テストハーネス整備

- `spec/app/emulator/gb-test-roms/` 配下に **Blargg 個別 ROM 41 件のシナリオテスト** を整備
  - `cpu_instrs` 11 件、`instr_timing` 1 件、`halt_bug` 1 件、`interrupt_time` 1 件、`mem_timing` 3 件、`mem_timing-2` 3 件、`oam_bug` 8 件、`dmg_sound` 12 件
- 各テストはシリアル出力 (`mmu.serial_buffer`) に `Passed` が出るかを検証する。未実装命令で停止した場合は **どの opcode で詰まったかが失敗メッセージから一目で分かる** 診断ツールとして機能
- 実装が進むたびに「次に詰まる命令」が浮かび上がる仕組みで、cpu_instrs は `0xC4` → `0xC6` と着実に前進中

#### 5. main.rb での画面描画

- `tick(args)` で **PPU の framebuffer(160×144 の色番号 0..3)を 4 倍拡大して画面に描画** — DMG 4階調を RGB に変換するパレット (`GB_PALETTE`)、Y軸反転で Game Boy 上端を画面上に揃える、`SCREEN_X=20, SCREEN_Y=72` に配置。`step_emulator` で 1 フレーム(70224 T-cycle)を 1000 サイクル粒度で CPU/PPU 交互に進める

### 次の最短経路

★第一マイルストーン達成済み。次は **★第二マイルストーン(Nintendo ロゴ表示)** に向かう。**CPU 命令は 501/501 で完成**(不正 opcode 11 個は実機ロックアップ相当で除外)。ボトルネックは **割り込み機構** と **PPU/MMU の追加機能**側に完全に移った。優先順位:

1. **`RRC A` (0x0F) のバグ修正** — 代入先が B になっている小さい修正。CPU の最後の不具合
2. **割り込み機構**(`EI` の 1 命令遅延化 + IF/IE → ベクタ自動 dispatch + PPU の VBlank IF 立ち上げ) — ブートROM の VBlank 待ちループで詰まっている本質的問題。これが解けると HALT/RET 周りも整い、Blargg `02-interrupts.gb` が通る
3. **Timer (DIV/TIMA/TMA/TAC)** — `interrupt_time.gb` / `instr_timing.gb` の前提
4. **E-3 PPU SCY スクロール対応 / E-4 ブートROM mapping** — Nintendo ロゴのスクロールイン演出に必要(コードは小さい)

CPU 命令の網羅は完了したので、第二マイルストーン達成の鍵は完全に **割り込み機構** と **PPU/MMU まわり** に絞られた。ここまで実装すれば、ブートROM 完走の条件はほぼ揃う。

## 進捗チェックリスト

### フェーズ A: 土台 [完了]
- [x] A-1: プロジェクト初期化と画面表示
- [x] A-2: ROM 読み込み
- [x] A-3: MMU 骨組み + シリアル出力

### フェーズ B: CPU 基本命令(hello.gb 用)
- [x] B-1: CPU 骨組み(NOP + ヘルパ群)
- [x] B-2: hello.gb が使う命令一式(B-2 完了時 ~161 オペコード、現在は E-1/E-2 で拡張され 207 通常 + 223 CB = 計 430 命令。HELLO WORLD 完走シナリオが HALT 到達)

### フェーズ C: PPU 最小実装
- [x] C-1: PPU 骨組み(LCDC, LY, モード) — LY ティック動作、HELLO WORLD は VBlank ループを抜けて CALL で停止
- [x] C-2: BG タイル描画(SCY=0 固定) — render_scanline 実装、2bpp デコード / signed-unsigned 切替 / パレット変換まで対応

### フェーズ D: HELLO WORLD 表示 [完了] ★第一マイルストーン達成
- [x] D-1: skip_boot モード実装 — `CPU.new(mmu, skip_boot: true)` / `MMU.new(cartridge, skip_boot: true)` で実機ブート完走後の状態(レジスタ値 + I/O 初期値 LCDC=0x91, BGP=0xFC)を再現、main.rb を `hello.gb` + skip_boot 起動に切り替え
- [x] D-2: hello.gb 起動 → "Hello World!" 表示 ★第一マイルストーン達成 — `./dragonruby .` で `Hello 8-bit world!` が DMG パレットで描画されることを目視確認(2026-05-02)。統合テスト `HELLO WORLD 完走` も HALT 到達で pass

### フェーズ E: Nintendo ロゴ表示
- [x] E-1: ブートROM 用 CPU 命令追加 [完了] — **全 245 通常 opcode 実装完成**(PUSH/POP × 8、JP cc × 4、JR cc × 5、CALL/CALL cc × 5、ADD/ADC/SUB/SBC × 36、ADD HL × 4、ADD SP, e8、LD HL, SP+e8、A 専用ローテート 4 個、INC/DEC (HL)、CPL/SCF/CCF、DAA、RST × 8、RETI、RET cc × 4、EI(即時版)、STOP、`registers.nz?/z?/nc?/c?` 述語、`push_u16`/`pop_u16`/`rst(address:)` ヘルパ)。**残機能(命令ではない)**: EI 1命令遅延化、割り込みベクタ dispatch、Timer。`RRC A`(0x0F)に代入先バグあり要修正
- [x] E-2: CB-prefix 実装 [完了] — **CB-prefix 全 256 命令実装完成**(BIT/RES/SET 計 192 + RR/RL/SRL/SLA/SRA/SWAP/RLC/RRC × 8 = 64、(HL) バリアント含む)
- [ ] E-3: PPU SCY スクロール対応
- [ ] E-4: MMU にブートROM mapping 追加 + VBlank IF (0xFF0F bit 0) 立ち上げ + IF/IE による割り込みベクタ自動 dispatch
- [ ] E-5: ブートROM 起動 → 崩れたロゴ観察
- [ ] E-6: Blargg 診断ループ — **`spec/app/emulator/gb-test-roms/` に 41 件のシナリオテスト整備済み**(cpu_instrs / instr_timing / mem_timing / mem_timing-2 / halt_bug / interrupt_time / oam_bug / dmg_sound)。停止位置が opcode 単位で見え、`0xC4 → 0xC6 → 0xD6 → CB 0x38` と前進し、**`10-bit ops.gb` で初の Pass 達成**
- [ ] E-7: 修正済み Nintendo ロゴ表示 ★第二マイルストーン

### フェーズ F: tobu.gb タイトル
- [ ] F-1: MBC1 実装
- [ ] F-2: スプライト描画
- [ ] F-3: Joypad 入力
- [ ] F-4: Timer (DIV / TIMA)
- [ ] F-5: tobu.gb タイトル表示 ★第三マイルストーン

## 三段マイルストーン

1. **HELLO WORLD 表示**(D-2 完了時, 約 5〜6h):画面に文字が出た瞬間。CPU 基本命令と PPU が連動して動いた証拠。「自分で書ける範囲のコードが正しく解釈・描画される」最小ループの完成
2. **Nintendo ロゴ表示**(E-7 完了時, 約 8〜13h):スクロールインのロゴ。**ブートROM 完走** = CPU + MMU + PPU + フラグ計算 + CB-prefix が全部揃った証拠
3. **tobu.gb タイトル**(F-5 完了時, 約 14.5〜23h):実ゲームが起動。MBC1 + スプライト + 入力 + タイマー が揃った証拠

## 前提

- DragonRuby Game Toolkit がインストール済み(プロジェクトルートに `dragonruby` バイナリ配置済み)
- Ruby 4.0.3 + RSpec(`bundle exec rspec` で実行)
- Pan Docs(https://gbdev.io/pandocs/)を別タブで開いておく
- gbops オペコード表(https://izik1.github.io/gbops/)を別タブで開いておく
- ROM 素材の入手と配置(取得済み):
  - `data/hello.gb`(gitendo/helloworld) ← フェーズ D で使用
  - `data/dmg_boot.bin`(SameBoy 同梱の SameBoot 実装、256B) ← フェーズ E で使用
  - `data/gb-test-roms/cpu_instrs/` の Blargg 個別 ROM(retrio/gb-test-roms 由来) ← E-6 診断時に使用
  - `data/tobu.gb` ← フェーズ F で使用

## ディレクトリ構造(最終形)

```
GEM-BOY/
├── app/
│   ├── main.rb              # DragonRuby tick エントリ + framebuffer 描画 + ROM/シリアル UI(args 依存はここだけ)
│   ├── emulator/            # 純 Ruby のエミュレータコア
│   │   ├── bit.rb           # 8bit/16bit/4bit 操作の純粋関数ヘルパ(low_byte / high_byte / make_u16 / wrap_u8 / wrap_u16 / low_4bits / u8_to_i8 / bit_at / set_bit)
│   │   ├── cartridge.rb     # カートリッジ
│   │   ├── mmu.rb           # メモリ管理 + シリアル出力 + read_u8/write_u8/read_u16/write_u16(E-4 でブートROM mapping 追加)
│   │   ├── cpu.rb           # CPU(B-1, B-2 完了。E-1 の大半 + E-2 の BIT/RES/SET を前倒し実装済み)
│   │   ├── cpu_registers.rb # CPU レジスタ A/F/B/C/D/E/H/L + PC/SP + フラグ(zero/negative/half_carry/carry)getter/setter
│   │   ├── lcd_registers.rb # LCD I/O レジスタ(LCDC/SCY/SCX/BGP)読み出し + ビットデコード
│   │   ├── ppu.rb           # 描画(C-1, C-2 完了: LY ティック + BG タイル描画。E-3 で SCY スクロール対応)
│   │   ├── boot_rom.rb      # ブートROM ローダ(E-4 で作成、任意で別ファイル化)
│   │   ├── mbc1.rb          # MBC1 バンク切り替え(F-1 で作成)
│   │   └── emulator.rb      # 統合
│   └── core_ext/            # ビルトインクラス拡張
│       ├── blank.rb         # Object#blank? / #present?
│       ├── last.rb          # String#last(n)
│       └── bit_index.rb     # Integer#[](n)(mruby に欠けているので monkey patch)
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

`hello.gb` の実行に必要な Sharp LR35902(Game Boy CPU)命令を実装する。**ブートROM が使う命令の一部のみ**で済む(CB-prefix は不要、`PUSH/POP/CALL/RET` も hello.gb 次第で省略可能)。残りの命令はフェーズ E で追加する。

CPU リファレンス:
- Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html
- gbops オペコード表: https://izik1.github.io/gbops/
- RGBDS 命令リファレンス: https://rgbds.gbdev.io/docs/gbz80.7

## ステップ B-1: CPU 骨組み (1時間) [完了]

**目標**: CPU クラスの土台を作り、未実装命令を踏むと例外で停止する状態にする。

実装内容:

- `app/emulator/cpu.rb` に CPU クラスを追加(レジスタ A/B/C/D/E/H/L/F + SP/PC + IME/halted、すべて初期値 0 / false)
- `step` / `run(cycles_target)` / `fetch_u8` / `fetch_u16` / `fetch_i8` / `set_flags` を実装。HALT 中は fetch せず 4 サイクルだけ消費する分岐込み
- 256 要素の `@opcodes` テーブルを用意し、未実装オペコードを踏むと `Unimplemented opcode 0xXX at PC=0xYYYY` で例外停止
- `app/emulator/bit.rb` を新設: `low_byte` / `high_byte` / `make_u16` / `wrap_u8` / `wrap_u16` / `low_4bits` を `Bit` モジュールに集約(CPU と MMU の両方から `Bit.xxx` で呼ぶ)
- F レジスタの個別 setter / getter (`zero` / `negative` / `half_carry` / `carry`)、レジスタペア (`bc` / `de` / `hl`) の getter / setter を実装
- `spec/app/emulator/cpu_spec.rb` / `spec/app/emulator/bit_spec.rb` で各メソッド単体テスト

詳細は `git log` を参照。

---

## ステップ B-2: hello.gb が使う命令一式 (1〜1.5時間) [完了]

**目標**: `data/hello.gb` の実行に必要な命令を網羅する。**CB-prefix と一部のブートROM 専用命令はスキップ**(フェーズ E で追加)。

### 現状(2026-05-02 時点)

**実装済み命令カテゴリ(B-2 完了時の計 ~161 通常 opcode + 168 CB opcode、現在は E-1/E-2 で拡張され 207 + 223 = 430 命令):**

| カテゴリ | 範囲 | 状態 |
|---|---|---|
| **制御** | NOP(0x00), HALT(0x76), DI(0xF3), CB-prefix(0xCB) | ✓ |
| **8bit ロード r,r'** | 0x40-0x7F の 49 命令(`LD r,(HL)` / `LD (HL),r` / HALT 0x76 含む) | ✓ |
| **8bit ロード r,u8** | 0x06/0x0E/0x16/0x1E/0x26/0x2E/0x36/0x3E | ✓ |
| **8bit ロード レジスタペア間接** | LD (BC),A(0x02)、LD A,(BC)(0x0A)、LD (DE),A(0x12)、LD A,(DE)(0x1A)、LD (HL+),A(0x22)、LD A,(HL+)(0x2A)、LD (HL-),A(0x32)、LD A,(HL-)(0x3A) | ✓ |
| **8bit ロード u16 即値** | LD (u16),A(0xEA)、LD A,(u16)(0xFA) | ✓ |
| **LDH(I/O)** | LDH (u8),A(0xE0)、LDH A,(u8)(0xF0)、LD (C),A(0xE2)、LD A,(C)(0xF2) | ✓ |
| **16bit ロード** | LD BC,u16(0x01)、LD DE,u16(0x11)、LD HL,u16(0x21)、LD SP,u16(0x31)、LD (u16),SP(0x08) | ✓ |
| **16bit ロード SP 系** | LD SP,HL(0xF9)、LD HL,SP+i8(0xF8) | ✓(F8 はフラグ計算 TODO 残り) |
| **論理 AND** | 0xA0〜0xA7 + 0xE6 | ✓ 全 9 命令(H=1 の特殊フラグ) |
| **論理 XOR** | 0xA8〜0xAF + 0xEE | ✓ 全 9 命令 |
| **論理 OR** | 0xB0〜0xB7 + 0xF6 | ✓ 全 9 命令 |
| **比較 CP** | 0xB8〜0xBF + 0xFE | ✓ 全 9 命令(`Bit.low_4bits` で半キャリー計算済み) |
| **8bit INC/DEC** | INC B/C/D/E/H/L/A(0x04/0x0C/0x14/0x1C/0x24/0x2C/0x3C)、DEC B/C/D/E/H/L/A(0x05/0x0D/0x15/0x1D/0x25/0x2D/0x3D) | ✓((HL) 版 0x34/0x35 のみ未) |
| **16bit INC/DEC** | INC BC/DE/HL/SP(0x03/0x13/0x23/0x33)、DEC BC/DE/HL/SP(0x0B/0x1B/0x2B/0x3B) | ✓ |
| **ジャンプ** | JP u16(0xC3)、JP HL(0xE9)、JR i8(0x18)、JR NZ,i8(0x20)、JR Z,i8(0x28) | △(JR NC/JR C / JP cc は未実装) |
| **コール/リターン** | CALL u16(0xCD)、RET(0xC9) | △(CALL cc / RET cc / RETI / RST は未実装) |
| **CB-prefix BIT n,r** | 0x40-0x7F((HL) 版 0x46/4E/56/5E/66/6E/76/7E を除く 56 命令) | ✓ |
| **CB-prefix RES n,r** | 0x80-0xBF((HL) 版を除く 56 命令) | ✓ |
| **CB-prefix SET n,r** | 0xC0-0xFF((HL) 版を除く 56 命令) | ✓ |
| **算術 ADD/ADC/SUB/SBC** | 0x80-0x9F、0xC6/D6/CE/DE | ❌ 未実装 |
| **ADD HL,rr / ADD SP,i8** | 0x09/0x19/0x29/0x39 / 0xE8 | ❌ 未実装 |
| **スタック PUSH/POP** | 0xC1/D1/E1/F1, 0xC5/D5/E5/F5 | ❌ 未実装 |
| **コール残り / リセット** | CALL cc / RET cc / RETI / RST 0x07 系 | ❌ 未実装 |
| **CB-prefix ROTATE** | RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL(0x00-0x3F) | ❌ 未実装(E-2 残タスク) |
| **非 CB ローテート** | RLCA/RRCA/RLA/RRA(0x07/0x0F/0x17/0x1F) | ❌ 未実装 |
| **DAA / CPL / SCF / CCF** | 0x27 / 0x2F / 0x37 / 0x3F | ❌ 未実装 |

**hello.gb の到達点:**

`spec/app/emulator/cpu_spec.rb` の **"HELLO WORLD 完走" シナリオは PC=0x01B8 の HALT に到達して halted=true** に到達(`expect(cpu.halted).to eq true` / `expect(cpu.registers.pc).to eq 0x01B9` が pass)。CPU + MMU + PPU + hello.gb の統合がスペックレベルで完走した状態。

**ブートROM の到達点:**

`spec/app/emulator/cpu_spec.rb` の "ブートROM 完走" は VRAM クリアループ(`LD (HL+),A` 0x22 → CB-prefix BIT 5,H 0xCB 0x6C → JR Z,i8 0x28)に入り、**そこでループしながら 200,000 サイクルの上限で打ち切られている**(失敗は CPU バグではなく、VRAM 8KB クリアに 230,000 サイクル必要なため枠不足。E-2 ROTATE 系を通すかテスト枠を伸ばす必要あり)。

### E フェーズで実装する残り命令

E-1 で残っている主な命令: **算術系(ADD/ADC/SUB/SBC + ADD HL,rr + ADD SP,i8)、スタック系(PUSH/POP/RST/RETI)、ローテート(非 CB の RLCA/RLA/RRCA/RRA)、その他演算(DAA/CPL/SCF/CCF)、条件付き JP/CALL/RET、JR NC/JR C**。E-2 で残っているのは **CB-prefix ROTATE 系(RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL)と、各 CB 命令の (HL) バリアント**。`RL r` がブートROM のロゴ展開で頻発する点に注意。

### 実装の進め方

- フラグレジスタ F は **bit7=Z, bit6=N, bit5=H, bit4=C**(下位 4bit は常に 0)
- フラグ計算は `CpuRegisters#set_flags(zero:, negative:, half_carry:, carry:)` に集約済み
- HL/BC/DE のペアアクセサ(`registers.hl` / `registers.hl=` 等)は `CpuRegisters` に実装済み
- **未実装命令で停止** する設計を活かし、**ROM を実行 → 停止 → そのオペコードを追加** のループで進める。「全部書いてからテスト」より「**動かしながら必要分だけ追加**」が推奨。E-1 / E-2 の残命令もこの流れで埋める

### フラグ計算の罠

- `INC r` / `DEC r` は **C フラグを保持**(他のフラグだけ更新)
- `INC rr` / `DEC rr`(16bit)は **フラグを一切変更しない**
- `XOR A` で Z=1、`OR A` も同様(自分との論理演算は flag のみ更新意図で多用される)

---

# フェーズ C: PPU 最小実装

`hello.gb` および ブートROM が画面に表示するのは **BG タイルのみ**(スプライトもウィンドウも使わない)。最小限の PPU で済む。**SCY スクロール対応はフェーズ E**(Nintendo ロゴで必須)に回す。

PPU リファレンス:
- Pan Docs Rendering: https://gbdev.io/pandocs/Rendering.html
- Pan Docs Tile Data: https://gbdev.io/pandocs/Tile_Data.html
- Pan Docs LCDC: https://gbdev.io/pandocs/LCDC.html

## ステップ C-1: PPU 骨組み(LCDC, LY, モード) (1時間) [完了]

**目標**: PPU が時間経過とともに `LY` をインクリメントし、4 つのモードを遷移するようにする。

実装内容:

- `app/emulator/ppu.rb` に PPU クラスを新設
- I/O レジスタ定数(LCDC / STAT / SCY / SCX / LY / LYC / BGP)、画面サイズ定数(SCREEN_WIDTH / SCREEN_HEIGHT)、サイクル定数(CYCLES_PER_SCANLINE=456 / SCANLINES_PER_FRAME=154 / VBLANK_START_LY=144)を定義
- `step(cycles)` メソッド: CPU の消費サイクルを受け取り、累積が 456 を超えるごとに LY を +1(154 でラップ)、MMU の 0xFF44 に反映
- `lcd_on?` プライベートメソッド: LCDC bit7 = 0 の間は LY 進行を止める(VRAM クリア中の挙動を再現)
- `render_scanline` プライベートメソッド: C-2 で実装するためのフック(現在は空)
- `spec/app/emulator/ppu_spec.rb` で `#initialize` / `#step`(LCD OFF / 1 ライン / VBlank 開始 / 1 フレーム完了 / 小サイクル累積)を 7 ケース検証
- `spec/app/emulator/cpu_spec.rb` の "HELLO WORLD 完走" 統合テストを更新: PPU を組み込んで LY ティックを CPU の `cpu.run` ループと連動、ブートROM 終了直後の I/O 初期値(LCDC=0x91, BGP=0xFC)を `mmu.write_io_direct` でセット

結果: **HELLO WORLD は VBlank 待ちループを抜けて初期化処理に進み、PC=0x0177 の `CALL u16`(未実装)で停止**するようになった。CPU と PPU の連動が確認できた。

詳細は `git log` を参照。

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

## ステップ C-2: BG タイル描画(SCY=0 固定) (1〜1.5時間) [完了]

**目標**: VRAM の Tile Data + Tile Map から 1 スキャンライン分のピクセルを生成する。**SCY/SCX は読み込むけど 0 固定前提**(`hello.gb` はスクロールしない)。

実装内容:

- `app/emulator/ppu.rb` の `render_scanline` を実装(C-1 で残していた空フックを埋めた)
- **BG 有効判定**(LCDC bit0)で無効時はスキップ、`bg_enabled?` プライベートメソッドで判定
- **タイルマップ切替**(LCDC bit3 で 0x9800 / 0x9C00)
- **アドレッシング切替**(LCDC bit4): unsigned(0x8000 + tile_num × 16)/ signed(0x9000 + (signed)tile_num × 16)
  - signed の場合は tile_num=0x80..0xFF を -128..-1 として解釈
  - `tile_data_address(tile_num, unsigned_addressing)` プライベートメソッドに切り出し
- **2bpp デコード**を `pixel_color(tile_addr, pixel_x, pixel_y)` プライベートメソッドに集約
  - 1 タイル = 16 バイト、1 行 = 2 バイト(下位ビット並び + 上位ビット並び)
  - 左端ピクセル = bit7、右端 = bit0(逆順)
- **BGP パレット変換**: 色番号(0..3)を `(BGP >> (color_id * 2)) & 0b11` で明度(0..3)に変換
- SCY / SCX 加算と 8bit ラップを適用(hello.gb は 0 固定だが将来の E-3 SCY スクロール対応の下準備)
- `spec/app/emulator/ppu_spec.rb` で 7 ケース検証:
  - BG 無効で framebuffer 不変
  - 全色 0 / 全色 3 のタイル
  - パレット反転(色 3 → 明度 0)
  - **bit 順序**(左端 = bit7、右端 = bit0)を明示的に確認
  - LCDC bit3=1 でタイルマップ 0x9C00 が参照されること
  - LCDC bit4=0(signed)で tile_num=0xFF が 0x8FF0 を指すこと

結果: PPU が画素を framebuffer に書き込めるようになった。**HELLO WORLD の詰まり位置は変わらず PC=0x0177 の `CALL u16`**(C-2 の影響範囲外)。CPU 側のスタック系を実装すれば D-1 / D-2 で画面表示まで進める。

詳細は `git log` を参照。

---

# フェーズ D: HELLO WORLD 表示 ★第一マイルストーン [完了]

skip_boot 起動で `hello.gb` を直接実行し、画面に "Hello World!" を表示する。**フェーズ B + C の組み合わせが正しく動いているかの最小統合テスト**。**2026-05-02 達成**: `./dragonruby .` で `Hello 8-bit world!` を DMG パレットで描画。CPU が HALT(PC=0x01B8)に到達したあとも PPU が回り続けて LY が進行することも目視で確認。

## ステップ D-1: skip_boot モード実装 (30分) [完了]

**目標**: ブートROM を使わず、直接 `PC=0x0100` から起動できるようにする。ブートROM 終了直後の実機状態をハードコードで再現する。

実装内容:

- `CpuRegisters#initialize(skip_boot: false)` でブートROM 完走後の実機値を再現(A=0x01, F=0xB0, B=0x00, C=0x13, D=0x00, E=0xD8, H=0x01, L=0x4D, SP=0xFFFE, PC=0x0100)
- `MMU#initialize(cartridge, skip_boot: false)` で I/O レジスタ初期値(LCDC=0x91, BGP=0xFC など)をセット
- `app/main.rb` トップレベルの `ROM_PATH = 'data/hello.gb'` / `SKIP_BOOT` を切り替えるだけで起動モードを変更可能

詳細は `git log` を参照。

---

## ステップ D-2: hello.gb 起動 → "Hello World!" 表示 (30分) ★第一マイルストーン [完了]

**目標**: `data/hello.gb` を起動して画面に **「Hello World!」が表示される**こと。

### 達成状況(2026-05-02)

- `./dragonruby .` で `data/hello.gb` を skip_boot 起動 → 左ペインに `Hello 8-bit world!` が DMG パレットで描画されることを目視確認 ★ **第一マイルストーン達成**
- 統合テスト `HELLO WORLD 完走 (hello.gb が HALT に到達するまで)` は PC=0x01B8 の HALT で halted=true になることを確認(`bundle exec rspec` で pass)
- `app/main.rb` で framebuffer を 4倍拡大して描画(160×144 → 640×576、DMG 4階調を RGB に変換、Y軸反転で Game Boy 上端を画面上に揃える)
- HUD 右ペインに ROM ファイル名 / Title / Size / PC / LY を表示。CPU が HALT したあとも PPU が回り続けて LY が変動するのが目視できる

### 観察チェックリスト

| 現象 | 推定原因 | 次のアクション |
|---|---|---|
| 即クラッシュ(未実装オペコード) | B-2 の漏れ | 該当命令を実装 → 再挑戦 |
| 黒画面のまま無反応 | LCDC の ON 検知不可 / PPU の `step` が回っていない | C-1 の `lcd_on?` と `step` を見直す |
| 画面に何かが出るが文字にならない | Tile Data / Tile Map の解釈ミス | C-2 のタイルアドレッシング(LCDC bit4)と 2bpp デコードを確認 |
| 文字色が反転している | BGP パレット未対応 | BGP レジスタ(0xFF47)の参照を追加 |
| **"Hello World!" が出る** | **成功** | ★ 第一マイルストーン達成 |

ここで「画面に文字が出る」だけでも **第一マイルストーン達成**。これで PPU の正しさが裏取りできるので、フェーズ E のブートROM 挑戦に進んだとき「PPU は OK、犯人は CPU 側」と切り分け可能になる。

---

# フェーズ E: Nintendo ロゴ表示 ★第二マイルストーン

ブートROM 全体を完走させ、**スクロールインする Nintendo ロゴ**を表示する。HELLO WORLD で動作確認済みの PPU と CPU 命令一式を土台にして、不足分(CB-prefix・ブートROM 専用命令・スクロール・ブートROM mapping)を追加していく。

## ステップ E-1: ブートROM 用 CPU 命令追加 (30分〜1時間) [部分実装]

**目標**: ブートROM が使うが hello.gb では使わなかった命令を追加する。

### 実装済み

- **メモリ間接 LD**: `LD A,(BC)` / `LD A,(DE)` / `LD (BC),A` / `LD (DE),A` / `LD (HL+),A` / `LD A,(HL+)` / `LD (HL-),A` / `LD A,(HL-)` / `LD (u16),A` / `LD A,(u16)`
- **論理演算 (HL) 経由**: `AND A,(HL)` / `XOR A,(HL)` / `OR A,(HL)` / `CP A,(HL)`
- **絶対ジャンプ**: `JP u16` / `JP HL` / `JP cc,u16` × 4
- **相対ジャンプ**: `JR i8` / `JR cc,i8` × 4
- **コール/リターン**: `CALL u16` / `CALL cc,u16` × 4 / `RET` / `RET cc` × 4 / `RETI` / `RST 0x00〜0x38` × 8
- **スタック**: `PUSH/POP BC/DE/HL/AF` 全 8 個
- **メモリ間接 ALU**: `ADD/ADC/SUB/SBC A,(HL)` / `INC (HL)` / `DEC (HL)`
- **算術**: `ADD/ADC/SUB/SBC A,r/(HL)/u8` 計 36 個 / `ADD HL,rr` × 4 / `ADD SP,e8` / `LD HL, SP+e8`
- **A 専用ローテート(非 CB)**: `RLCA` / `RLA` / `RRCA` / `RRA`(Z=0 固定)
- **A 単項演算**: `CPL` / `SCF` / `CCF` / `DAA`(BCD 補正)
- **8bit INC/DEC**: B/C/D/E/H/L/A
- **16bit INC/DEC**: BC/DE/HL/SP
- **割り込み制御**: `DI` / `EI`(EI は即時版、1 命令遅延は未対応)

### 残タスク

| カテゴリ | 命令 |
|---|---|
| **割り込み機構** | `EI` の 1 命令遅延化 / IF/IE による割り込みベクタ自動 dispatch / PPU の VBlank IF 立ち上げ(E-4 と一緒に) |
| **その他** | `STOP`(0x10、実機では稀)|
| **不正 opcode** | 0xD3 / 0xDB / 0xDD / 0xE3 / 0xE4 / 0xEB / 0xEC / 0xED / 0xF4 / 0xFC / 0xFD(11 個、実機では使われないので未実装でも問題なし)|

### 進め方

B-2 と同じ「動かしながら必要分だけ追加」の流れで進める。`data/dmg_boot.bin` を E-4 で MMU に接続するまでは実行できないので、E-4 と E-1 を交互に進めても OK。

---

## ステップ E-2: CB-prefix `BIT n,r` / `RL r` 実装 (1時間) [部分実装]

**目標**: 0xCB に続く 8bit でオペコードを解釈する CB 系命令を実装。ブートROM のロゴ展開で使われる。

### 実装済み(計 240 / 256 命令)

- **`BIT n,r`**(0x40-0x7F、64 命令、(HL) 版含む)— 1 ビット検査(Z = !bit_n(r), N=0, H=1, C 保持)
- **`RES n,r`**(0x80-0xBF、64 命令、(HL) 版含む)— 指定ビットを 0 にクリア(フラグ変化なし)
- **`SET n,r`**(0xC0-0xFF、64 命令、(HL) 版含む)— 指定ビットを 1 にセット(フラグ変化なし)
- **`RL r`** / **`RR r`**(0x10-0x1F、16 命令、(HL) 版含む)— C を経由した左/右ローテート
- **`SLA r`** / **`SRA r`**(0x20-0x2F、16 命令、(HL) 版含む)— 算術左/右シフト(SRA は bit 7 保持)
- **`SWAP r`**(0x30-0x37、8 命令、(HL) 版含む)— 上位 4bit / 下位 4bit を入れ替え
- **`SRL r`**(0x38-0x3F、8 命令、(HL) 版含む)— 論理右シフト

### 残タスク

- **`RLC r`**(0x00-0x07、8 命令)— C を経由しない左ローテート(bit 7 → bit 0 + C)
- **`RRC r`**(0x08-0x0F、8 命令)— C を経由しない右ローテート(bit 0 → bit 7 + C)

`RLC r` はブートROM のロゴ展開で頻発するので優先度が高い。RL/RR と類似のパターンで量産可能。

### 実装方針

256 個の `cb_table` を作り、未実装は nil のまま。`dispatch_cb` で fetch した次バイトを `cb_table[opcode]` で引き、nil なら例外を投げる。

```ruby
def dispatch_cb
  cb_opcode = fetch_u8
  cb_handler = cb_opcodes[cb_opcode]
  raise "未実装の CB opcode 0x#{...}" if cb_handler.nil?
  cb_handler.call
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

**目標**: ブートROM のロゴスクロールイン演出のため、PPU の BG 描画に `SCY` を反映する。

C-2 で `SCY=0` 固定にしていた箇所を、`bg_y = (LY + SCY) & 0xFF` に変更するだけ。`SCX` も同様に対応しておくと将来の拡張で楽。

### 動作確認

VRAM に固定タイルを書き、`SCY` を 1 ずつ増やして `render_scanline` を呼ぶと縦スクロールしていく。framebuffer の差分で確認可能。

---

## ステップ E-4: MMU にブートROM mapping 追加 (30分)

**目標**: MMU を改造し、ブートROM 期間中は `0x0000-0x00FF` をブートROM (`data/dmg_boot.bin`) にマップする。

### MMU 改造

```ruby
# app/emulator/mmu.rb
class MMU
  BOOT_ROM_OFF = 0xFF50  # 0x01 を書き込むとブートROM 切断

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
ROM_PATH = 'data/tobu.gb'  # ブートROM を抜けた直後の遷移先(ロゴ表示には何でも良い)
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

## ステップ E-5: ブートROM 起動 → 崩れたロゴ観察 (30分)

**目標**: ブートROM が動き始める瞬間を確認する。何が崩れているかを目視する。

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
ROM_PATH = 'data/gb-test-roms/cpu_instrs/06-ld r,r.gb'   # 切り替えてテスト
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

**目標**: E-6 で Blargg を Pass させた CPU で再びブートROM を起動。

```ruby
# app/main.rb
ROM_PATH = 'data/tobu.gb'
SKIP_BOOT = false
```

ブートROM が完走すると:

1. グレー → 黒の画面遷移
2. **Nintendo ロゴが画面中央に上から下へスクロールイン**
3. 約 1 秒静止
4. PC=0x0100 へジャンプ → カートリッジ本体へ

これで **第二マイルストーン達成**。

---

# フェーズ F: tobu.gb タイトル画面 ★第三マイルストーン

ブートROM が完走した後、tobu.gb の **タイトル画面**が表示されるところまで実装する。

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

`tobu.gb` をロードして起動。ブートROM 完走後、`PC` がカートリッジの命令を実行し続けることを確認(クラッシュしなければ OK の段階)。

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
- ブートROM 逆アセンブリ: https://github.com/ISSOtm/gb-bootroms
- Blargg gb-test-roms: https://github.com/retrio/gb-test-roms
- SameBoy(参照実装): https://github.com/LIJI32/SameBoy
- gitendo HelloWorld: https://github.com/gitendo/helloworld

# デバッグの優先順位

1. **未実装オペコードで停止** → エラーメッセージの PC とオペコードを gbops で確認して B-2 / E-1 / E-2 に追加
2. **D-2 で HELLO WORLD が出ない** → PPU 側のバグ濃厚(LCDC 検知、タイルアドレッシング、BGP パレット)。CPU は hello.gb の単純な構造で動かないなら未実装命令で止まるはず
3. **E-5 でロゴが崩れる** → PPU は HELLO WORLD で動作確認済みなので CPU 側のバグ濃厚。症状から推測した Blargg を E-6 で実行 → `Failed XX` のケース番号で原因特定
4. **F フェーズで止まる** → 割り込み(V-Blank / STAT / Timer)のタイミング、または MBC1 のバンク切り替え周り
