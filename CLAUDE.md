# GEM BOY

DragonRuby Game Toolkit 上で動く Ruby 製 Game Boy (DMG) エミュレータ。

## コーディング規約

詳細は @docs/CONVENTIONS.md を参照。

## 開発戦略

**Nintendo ロゴ表示を中心目標に置き、Blargg は診断ツールとして使う**。CPU 必要命令と PPU 最小実装ができたらブート ROM を仮接続し、画面に何かが出るところまで一気に進める。崩れた表示が出たら Blargg 個別 ROM を症状ごとに走らせて診断する流れ。「Blargg を全 Pass させてから先に進む」旧戦略は採らない(進捗が見えない時間が長すぎるため)。

詳細なステップ分解は `docs/ROADMAP.md` を参照(18ステップ / 17.5〜26.5時間)。

## 三段マイルストーン

1. **崩れた Nintendo ロゴ**(フェーズ D-2 完了): エミュレータが画面に何かを描いた瞬間。CPU と PPU が連動して動いた証拠
2. **正しい Nintendo ロゴ**(フェーズ D-4 完了): スクロールイン。ブート ROM が完走した証拠(D-5 でブートチャイムも追加)
3. **tobu.gb タイトル画面**(フェーズ E-5 完了): 実ゲームが起動。MBC1 + スプライト + 入力が揃った証拠

## ディレクトリ構造(最終形)

```
GEM-BOY/
├── app/
│   ├── main.rb              # DragonRuby tick エントリ / 画面描画 / 入力(args 依存はここだけ)
│   ├── emulator/            # 純 Ruby のエミュレータコア(args 非依存、MRI Ruby + RSpec でテスト可能)
│   │   ├── cartridge.rb     # カートリッジ
│   │   ├── mmu.rb           # メモリ管理 + シリアル出力
│   │   ├── cpu.rb           # CPU(フェーズBで追加)
│   │   ├── ppu.rb           # 描画(フェーズCで追加)
│   │   ├── boot_rom.rb      # ブートROM(フェーズDで追加)
│   │   ├── mbc1.rb          # MBC1 バンク切り替え(フェーズEで追加)
│   │   └── emulator.rb      # CPU/MMU/PPU の統合
│   └── core_ext/            # ビルトインクラスへの拡張(blank?, present?, String#last など)
│       ├── blank.rb         # Object#blank? / #present?, String#blank? など
│       └── last.rb          # String#last(n)(ActiveSupport 互換、シリアルバッファ切り詰めで使用)
├── data/
│   ├── tobu.gb              # 動作確認用 ROM(フェーズEのタイトル画面で使用)
│   ├── cpu_instrs/          # Blargg 個別 ROM(オリジナル配布構造のまま)
│   │   ├── 06-ld r,r.gb     # D-3a で使用
│   │   ├── 05-op rp.gb      # D-3b
│   │   ├── 04-op r,imm.gb   # D-3c
│   │   ├── 11-op a,(hl).gb  # D-3d
│   │   └── ... (他 7 個は完走後の追加検証用)
│   ├── hello.gb             # HelloWorld(付録、ROADMAP本流では未使用)
│   ├── dmg_boot.bin         # SameBoot等の互換ブートROM(フェーズDで使用)
│   └── game-boy-startup.wav # ブートチャイム(D-5 で再生)
├── spec/                    # RSpec(MRI Ruby で実行)
└── docs/                    # ROADMAP.md, CONVENTIONS.md など
```

**3 層分離の意図:**

- `app/main.rb` は DragonRuby (mruby) 専用 — `args.outputs`, `args.gtk` などのエンジン API はこのファイルだけが触る
- `app/emulator/` は純 Ruby に保つ。args を引数で受けない。これにより MRI Ruby + RSpec で単体テストできる(Blargg の前段の安全網)
- `app/core_ext/` は Object/String/Array などへの monkey patch。Rails の `active_support/core_ext/` と同じ位置づけ

## 必要なROM・テスト素材

ROADMAP 完走に必須のもの:

- **Blargg 個別 ROM**(フェーズ D-3 診断ループ): https://github.com/retrio/gb-test-roms — `cpu_instrs/individual/` をそのまま `data/cpu_instrs/` に置く。`cpu_instrs.gb` 単体は MBC を使うのでまだ動かない。実際に使うのは `06-ld r,r.gb` (D-3a), `05-op rp.gb` (D-3b), `04-op r,imm.gb` (D-3c), `11-op a,(hl).gb` (D-3d) の 4 個
- **ブートROM**(フェーズ D): SameBoy リリース版に同梱の `dmg_boot.bin`(SameBoot 互換実装)を `data/dmg_boot.bin` に配置。256 バイト。取得手順:
  ```bash
  curl -L -o /tmp/sameboy.zip https://github.com/LIJI32/SameBoy/releases/download/v1.0.3/sameboy_cocoa_v1.0.3.zip
  unzip -p /tmp/sameboy.zip 'SameBoy.app/Contents/Resources/dmg_boot.bin' > data/dmg_boot.bin
  ```
  検証用 SHA256: `6f64da4cecd7e54e2f928eb3e3ba7810a7a567d0d247cc71737d1771e073a916`(SameBoy v1.0.3 / SameBoot)。バージョンを上げる場合は SHA256 が変わるので留意
- **ブートチャイム WAV**(フェーズ D-5): `data/game-boy-startup.wav`。APU 本体は実装せず、ブート ROM が NR14(0xFF14)の trigger bit に書き込んだ瞬間にこの WAV を再生して演出代替する

ROADMAP 外の任意の追加検証用(完走後に正確性を上げたいとき):

- **HelloWorld**: https://github.com/gitendo/helloworld の DMG 用 `hello.gb`。旧 ROADMAP では D-3 として必須だったが、Nintendo ロゴ表示が同じ役割を果たすので新方針では付録扱い
- **dmg-acid2.gb**: https://github.com/mattcurrie/dmg-acid2/releases — PPU の 1px 精度テスト
- **Mooneye Test Suite**: https://gekkio.fi/files/mooneye-test-suite/ — MBC やタイミングの精密テスト
- **instr_timing.gb**: 上記 retrio/gb-test-roms 配下 — 命令サイクル数の検証

## 起動方法

```
./dragonruby .
```

ROM の切り替えは `app/main.rb` トップレベルの `ROM_PATH` 定数を書き換えるだけにする。

## テスト方針

- `app/emulator/` と `app/core_ext/` は **純 Ruby に保つ**(`args` を受けない、DragonRuby API を呼ばない)
- テストは **MRI Ruby + RSpec** で実行する(`bundle exec rspec`)。DragonRuby (mruby) を起動せずに CPU 命令やメモリ挙動を高速検証できる
- 使用 Ruby は `.ruby-version` で固定(現状 4.0.3)。`Gemfile` で RSpec を管理
- テスト規約は `docs/CONVENTIONS.md` を参照

## 実装上の重要ポイント

- **シリアル出力(0xFF01/0xFF02)** はBlarggの結果が出る唯一の窓口。MMU実装で最初に確実に動かす
- **CPU初期状態**: `skip_boot: true` でブートROM終了後の値(A=0x01, F=0xB0, PC=0x0100, SP=0xFFFE 等)を採用。フェーズDではブートROM実行のため全レジスタ0/PC=0x0000で開始
- **連続実行モード**(1tickで数千命令)を最初から作る。1命令ステップは時間の無駄
- **未実装オペコードは例外を投げる**。本当に必要な命令だけが自然に浮かび上がる
- **フラグ計算の罠**:
  - `RLA` (0x17) は Z フラグを常にクリアする。`CB RL` (0xCB 0x10-0x17) は結果が0ならZを立てる。挙動が違う点に注意
  - `ADD SP,r8` (0xE8) のH/Cフラグは下位ニブル/バイトでの計算
  - `INC r` / `DEC r` は C フラグを保持する(他のフラグは更新)
- **MBCはまだ非対応**。32KB以下のROMのみ動く
- **DragonRuby は mruby ベース** — `Regexp` クラスや bundler 経由の gem(ActiveSupport 等)は使えない。汎用ヘルパーは `app/core_ext/` に手書きで足す。テスト時のみ MRI Ruby が使える

## 参考リンク

- Pan Docs: https://gbdev.io/pandocs/
- gbops オペコード表: https://izik1.github.io/gbops/
- emudev.de: https://emudev.de/gameboy-emulator/testing-our-cpu/
- gameboy-doctor: https://github.com/robert/gameboy-doctor
- ブートROM逆アセンブリ: https://github.com/ISSOtm/gb-bootroms

## デバッグの優先順位

1. 未実装オペコードで停止 → エラーメッセージのPCとオペコードをgbopsで確認して追加
2. Blarggが`Failed XX`を出す → XXは失敗テストケース番号。Blarggのソースで該当箇所を確認
3. 画面が出ない/崩れる → CPUがBlarggをパスしている前提なら、ほぼ確実にPPU側のバグ(LCDC、タイルアドレッシング、BGPパレット周り)
