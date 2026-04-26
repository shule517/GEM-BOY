# GEM BOY

DragonRuby Game Toolkit 上で動く Ruby 製 Game Boy (DMG) エミュレータ。

## 開発戦略

PPUより先にCPUの正しさをBlarggテストで担保する。シリアル出力経由でテスト結果が"Passed"として見えるので、画面実装ゼロでも合格判定が得られる。CPUが固まってからPPUに進むので、HelloWorld表示で詰まるリスクが小さい。

詳細なステップ分解は `ROADMAP.md` を参照(15ステップ / 18〜28時間)。

## 三段マイルストーン

1. **Blargg `06-ld r,r.gb` の Passed**(フェーズB完了): CPUの基礎が動いた証拠
2. **HelloWorld表示**(フェーズD完了): PPUが動いた証拠
3. **Nintendoロゴ表示**(フェーズE完了): ブートROMが完走した証拠

## ディレクトリ構造(最終形)

```
mygame/
├── app/
│   ├── main.rb          # tickエントリポイント
│   ├── emulator.rb      # CPU/MMU/PPUの統合
│   ├── cpu.rb           # CPU実装
│   ├── mmu.rb           # メモリ管理 + シリアル出力
│   ├── ppu.rb           # 描画
│   ├── boot_rom.rb      # ブートROM(フェーズEで追加)
│   └── cartridge.rb     # カートリッジ
└── data/
    ├── 06-ld_r_r.gb など # Blarggテストの個別ROM
    ├── hello.gb          # HelloWorld
    └── dmg_boot.bin      # SameBoot等の互換ブートROM
```

## 必要なROM・テスト素材

- Blarggテスト: https://github.com/retrio/gb-test-roms (`cpu_instrs/individual/` の個別ROMを使う。`cpu_instrs.gb` 単体はMBCを使うのでまだ動かない)
- HelloWorld: https://github.com/gitendo/helloworld の DMG用 `hello.gb`
- ブートROM: https://github.com/LIJI32/SameBoot

## 起動方法

```
./dragonruby mygame
```

ROMの切り替えは `app/main.rb` の `setup` 内 `args.state.rom_path` を変更するだけにする。

## 実装上の重要ポイント

- **シリアル出力(0xFF01/0xFF02)** はBlarggの結果が出る唯一の窓口。MMU実装で最初に確実に動かす
- **CPU初期状態**: `skip_boot: true` でブートROM終了後の値(A=0x01, F=0xB0, PC=0x0100, SP=0xFFFE 等)を採用。フェーズEではブートROM実行のため全レジスタ0/PC=0x0000で開始
- **連続実行モード**(1tickで数千命令)を最初から作る。1命令ステップは時間の無駄
- **未実装オペコードは例外を投げる**。本当に必要な命令だけが自然に浮かび上がる
- **フラグ計算の罠**:
  - `RLA` (0x17) は Z フラグを常にクリアする。`CB RL` (0xCB 0x10-0x17) は結果が0ならZを立てる。挙動が違う点に注意
  - `ADD SP,r8` (0xE8) のH/Cフラグは下位ニブル/バイトでの計算
  - `INC r` / `DEC r` は C フラグを保持する(他のフラグは更新)
- **MBCはまだ非対応**。32KB以下のROMのみ動く

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
