# Cartridge
# Game Boy のカートリッジ ROM を表す純 Ruby クラス。
#
# === カートリッジヘッダ (0x0100-0x014F の 80 バイト) ===
# Pan Docs: https://gbdev.io/pandocs/The_Cartridge_Header.html
#
# DMG が起動すると、ブートROM が 0x0104-0x0133 の Nintendo ロゴをチェックし、
# 一致すれば 0x0100 へジャンプして実行を開始する。ヘッダはその直後の領域に
# メタ情報を格納している。
#
#   0x0100-0x0103  Entry Point      多くは NOP + JP 0x0150(本体プログラムへ飛ぶ)
#   0x0104-0x0133  Nintendo Logo    起動時のロゴ画像データ。書き換えると起動拒否
#   0x0134-0x0143  Title            16 バイトの ASCII。空きは 0x00 パディング
#                                   新しいカートリッジでは末尾が以下に再割当て:
#                                     0x013F-0x0142  Manufacturer Code (4 文字)
#                                     0x0143         CGB Flag (0x80=対応, 0xC0=専用)
#   0x0144-0x0145  New Licensee     2 文字の ASCII(新方式)
#   0x0146         SGB Flag         0x03 なら SGB 機能対応
#   0x0147         Cartridge Type   MBC の種類 (0x00 = ROM only, 0x01-03 = MBC1, ...)
#   0x0148         ROM Size         0x00 = 32KB, 0x01 = 64KB, ..., 0x08 = 8MB
#   0x0149         RAM Size         External RAM のサイズ (0x00 = なし)
#   0x014A         Destination Code 0x00 = 日本, 0x01 = 海外
#   0x014B         Old Licensee     1 バイトの旧方式ライセンスコード
#   0x014C         ROM Version
#   0x014D         Header Checksum  0x0134-0x014C のチェックサム。違うと起動拒否
#   0x014E-0x014F  Global Checksum  ROM 全体の単純加算チェックサム(実機は確認しない)
class Cartridge
  def initialize(data)
    raise "ROM データが空です" if data.nil? || data.empty?
    @data = data
  end

  # MMU から呼ばれる。範囲外は 0xFF(実機の未接続バスの挙動)。
  def read(address)
    @data[address] || 0xFF
  end

  # ROM ヘッダの Title 領域 (0x0134-0x0143) を ASCII 文字列として取り出す。
  # 仕様上は最大 16 文字で、足りない分は 0x00 パディング。
  # CGB 対応カートリッジでは末尾が Manufacturer/CGB Flag になっているため、
  # 厳密には 11-15 文字までが Title だが、ここでは雑に NUL を全消しして対応する。
  def title
    @data[0x0134..0x0143].pack('C*').strip.delete("\x00")
  end

  def size
    @data.size
  end
end
