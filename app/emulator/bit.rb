# 8bit / 16bit 値の相互変換ユーティリティ。
#
# Game Boy CPU(Sharp LR35902)は 8bit メモリインターフェースを通して
# 16bit のレジスタペアやアドレスを扱う。その変換は CPU だけでなく MMU や PPU でも
# 必要になるため、純粋関数として独立した名前空間にまとめる。
#
# 状態を持たないため `def self.xxx` で定義し、`Bit.low_byte(...)` の
# ようにモジュール関数として呼び出す(Ruby の `Math` / `JSON` と同じ流儀)。
# ※ DragonRuby (mruby) では `module_function` がうまく動かないため、
#    `def self.xxx` 形式で書く必要がある。
#
# Pan Docs: https://gbdev.io/pandocs/CPU_Instruction_Set.html
module Bit
  # 16bit 値から下位 8bit を取り出す。
  # 例: Bit.low_byte(0x1234) #=> 0x34
  # レジスタペア setter(BC=, DE=, HL=)で下位バイトを下位レジスタへ振り分けるときに使う。
  def self.low_byte(value)
    value & 0x00FF
  end

  # 16bit 値から上位 8bit を取り出す。
  # 例: Bit.high_byte(0x1234) #=> 0x12
  # レジスタペア setter(BC=, DE=, HL=)で上位バイトを上位レジスタへ振り分けるときに使う。
  def self.high_byte(value)
    (value & 0xFF00) >> 8
  end

  # 上位 8bit + 下位 8bit を 16bit に合成する。high_byte / low_byte の逆操作。
  # 例: Bit.make_u16(high: 0x12, low: 0x34) #=> 0x1234
  # レジスタペア getter(bc, de, hl)や、リトルエンディアンで読んだ 2 バイトを
  # 16bit に組み立てる場面で使う。
  def self.make_u16(high:, low:)
    (high << 8) | low
  end

  # 8bit にマスクして wrap させる(下位 8bit のみ残す)。
  # ADD A,B のキャリーアウト、INC r / DEC r のラップなど、
  # 8bit 演算結果を 8bit レジスタ(A/B/C/D/E/H/L)の範囲に正規化するときに使う。
  def self.wrap_u8(n)
    n & 0xFF
  end

  # 16bit にマスクして wrap させる(下位 16bit のみ残す)。
  # PC の +1 オーバーフロー(0xFFFF→0x0000)、JR の負オフセット、
  # ADD HL,BC のキャリーアウトなど、16bit 演算結果を正規化するときに使う。
  def self.wrap_u16(n)
    n & 0xFFFF
  end

  # 8bit 値から下位 4bit (lower 4 bits) を取り出す。
  # 半キャリー(H フラグ)計算で使う。
  # Pan Docs(https://gbdev.io/pandocs/CPU_Registers_and_Flags.html)では
  # "lower 4 bits" と表記される範囲。
  # 例: Bit.low_4bits(0x34) #=> 0x4
  def self.low_4bits(value)
    value & 0x0F
  end

  # u8 (0..255) を i8 (-128..127) として再解釈する(2 の補数)。
  # JR i8 / ADD SP,i8 の符号付きオフセット、signed タイル番号などで使う。
  # 例: Bit.u8_to_i8(0x7F) #=> 127, Bit.u8_to_i8(0x80) #=> -128, Bit.u8_to_i8(0xFF) #=> -1
  def self.u8_to_i8(u8)
    u8 >= 0x80 ? u8 - 256 : u8
  end

  # 値の n 番目のビット(0 or 1)を取り出す。
  # MRI Ruby では `value[n]`(Integer#[])で同じことができるが、
  # DragonRuby (mruby) では未対応のため自前で実装する。
  # 例: Bit.bit_at(0x80, 7) #=> 1, Bit.bit_at(0x80, 0) #=> 0
  def self.bit_at(value, n)
    (value >> n) & 1
  end
end
