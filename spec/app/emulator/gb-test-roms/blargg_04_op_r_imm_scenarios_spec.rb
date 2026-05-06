require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/04-op r,imm.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/04-op r,imm.s)が検証する
# 即値オペランド (u8) を取る命令一式の挙動を再現する。
#
#   LD r,$XX:    $36/$06/$0E/$16/$1E/$26/$2E/$3E
#   ALU A,$XX:   $C6 ADD / $CE ADC / $D6 SUB / $DE SBC
#                $E6 AND / $EE XOR / $F6 OR  / $FE CP
#
# Blargg は A 値 × 即値 × 4 種類の F 初期値で全組み合わせの checksum 比較するが、
# RSpec では命令ごとに代表値での挙動と境界フラグ計算を 1〜3 ケースで検証する。
RSpec.describe 'Blargg cpu_instrs/04-op r,imm.gb 相当のシナリオテスト' do
  context '04-op r,imm.gb を実行したとき' do
    instr_address = 0xC000

    let(:cpu) { CPU.new(mmu, skip_boot: false, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: false) }
    let(:rom_data) { Array.new(0x8000, 0) }
    let(:instr_bytes) { [] }

    before do
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }
      cpu.registers.pc = instr_address
    end

    # ==========================================================================
    # LD r,u8 系: フラグ変更なし
    # ==========================================================================

    context 'LD B,u8 (0x06) を実行したとき' do
      let(:instr_bytes) { [0x06, 0x42] }
      before { cpu.registers.f = 0xF0 }

      it 'B=0x42、フラグは保持' do
        cpu.step
        expect(cpu.registers.b).to eq 0x42
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'LD C,u8 (0x0E) を実行したとき' do
      let(:instr_bytes) { [0x0E, 0x42] }

      it 'C=0x42' do
        cpu.step
        expect(cpu.registers.c).to eq 0x42
      end
    end

    context 'LD D,u8 (0x16) を実行したとき' do
      let(:instr_bytes) { [0x16, 0x42] }

      it 'D=0x42' do
        cpu.step
        expect(cpu.registers.d).to eq 0x42
      end
    end

    context 'LD E,u8 (0x1E) を実行したとき' do
      let(:instr_bytes) { [0x1E, 0x42] }

      it 'E=0x42' do
        cpu.step
        expect(cpu.registers.e).to eq 0x42
      end
    end

    context 'LD H,u8 (0x26) を実行したとき' do
      let(:instr_bytes) { [0x26, 0x42] }

      it 'H=0x42' do
        cpu.step
        expect(cpu.registers.h).to eq 0x42
      end
    end

    context 'LD L,u8 (0x2E) を実行したとき' do
      let(:instr_bytes) { [0x2E, 0x42] }

      it 'L=0x42' do
        cpu.step
        expect(cpu.registers.l).to eq 0x42
      end
    end

    context 'LD (HL),u8 (0x36) を実行したとき' do
      let(:instr_bytes) { [0x36, 0x42] }
      before { cpu.registers.hl = 0xC100 }

      it '(HL=0xC100)=0x42' do
        cpu.step
        expect(mmu.read_u8(address: 0xC100)).to eq 0x42
      end
    end

    context 'LD A,u8 (0x3E) を実行したとき' do
      let(:instr_bytes) { [0x3E, 0x42] }

      it 'A=0x42' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
      end
    end

    # ==========================================================================
    # ADD A,u8 (0xC6): Z = result==0、N=0、H = bit3 繰り上がり、C = bit7 繰り上がり
    # ==========================================================================

    context 'ADD A,u8 (0xC6) で 0x12 + 0x34 のとき' do
      let(:instr_bytes) { [0xC6, 0x34] }
      before { cpu.registers.a = 0x12 }

      it 'A=0x46、Z=0、N=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x46
        expect(cpu.registers.f).to eq 0x00
      end
    end

    context 'ADD A,u8 で 0x0F + 0x01(下位ニブル繰り上がり)のとき' do
      let(:instr_bytes) { [0xC6, 0x01] }
      before { cpu.registers.a = 0x0F }

      it 'A=0x10、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x10
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD A,u8 で 0xFF + 0x01(8bit 繰り上がり)のとき' do
      let(:instr_bytes) { [0xC6, 0x01] }
      before { cpu.registers.a = 0xFF }

      it 'A=0x00、Z=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # ADC A,u8 (0xCE): C を加味した加算
    # ==========================================================================

    context 'ADC A,u8 (0xCE) で 0x10 + 0x10 + C=1 のとき' do
      let(:instr_bytes) { [0xCE, 0x10] }
      before { cpu.registers.a = 0x10; cpu.registers.carry_flag = 1 }

      it 'A=0x21、Z=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x21
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADC A,u8 で 0xFF + 0x00 + C=1 のとき' do
      let(:instr_bytes) { [0xCE, 0x00] }
      before { cpu.registers.a = 0xFF; cpu.registers.carry_flag = 1 }

      it 'A=0x00、Z=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # SUB A,u8 (0xD6): Z, N=1, H=借り bit3, C=借り bit7
    # ==========================================================================

    context 'SUB A,u8 (0xD6) で 0x34 - 0x12 のとき' do
      let(:instr_bytes) { [0xD6, 0x12] }
      before { cpu.registers.a = 0x34 }

      it 'A=0x22、N=1、Z=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x22
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'SUB A,u8 で 0x10 - 0x01(借り bit3)のとき' do
      let(:instr_bytes) { [0xD6, 0x01] }
      before { cpu.registers.a = 0x10 }

      it 'A=0x0F、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'SUB A,u8 で A < B(借り bit7)のとき' do
      let(:instr_bytes) { [0xD6, 0x01] }
      before { cpu.registers.a = 0x00 }

      it 'A=0xFF、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'SUB A,u8 で A == B のとき' do
      let(:instr_bytes) { [0xD6, 0x42] }
      before { cpu.registers.a = 0x42 }

      it 'A=0x00、Z=1、N=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
      end
    end

    # ==========================================================================
    # SBC A,u8 (0xDE): C を加味した減算
    # ==========================================================================

    context 'SBC A,u8 (0xDE) で 0x10 - 0x0F - C=1 のとき' do
      let(:instr_bytes) { [0xDE, 0x0F] }
      before { cpu.registers.a = 0x10; cpu.registers.carry_flag = 1 }

      it 'A=0x00、Z=1、N=1、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'SBC A,u8 で 0x00 - 0x00 - C=1 のとき' do
      let(:instr_bytes) { [0xDE, 0x00] }
      before { cpu.registers.a = 0x00; cpu.registers.carry_flag = 1 }

      it 'A=0xFF、N=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # AND A,u8 (0xE6): Z, N=0, H=1(AND の特殊仕様), C=0
    # ==========================================================================

    context 'AND A,u8 (0xE6) で 0xF0 & 0x0F のとき' do
      let(:instr_bytes) { [0xE6, 0x0F] }
      before { cpu.registers.a = 0xF0 }

      it 'A=0x00、Z=1、N=0、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.f).to eq 0xA0 # Z=1, H=1
      end
    end

    context 'AND A,u8 で 0xFF & 0x0F のとき' do
      let(:instr_bytes) { [0xE6, 0x0F] }
      before { cpu.registers.a = 0xFF }

      it 'A=0x0F、Z=0、H=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
        expect(cpu.registers.f).to eq 0x20 # H=1 のみ
      end
    end

    # ==========================================================================
    # XOR A,u8 (0xEE): Z, N=H=C=0
    # ==========================================================================

    context 'XOR A,u8 (0xEE) で 0xF0 ^ 0x0F のとき' do
      let(:instr_bytes) { [0xEE, 0x0F] }
      before { cpu.registers.a = 0xF0 }

      it 'A=0xFF、Z=0、N=H=C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
        expect(cpu.registers.f).to eq 0x00
      end
    end

    context 'XOR A,u8 で A == byte のとき' do
      let(:instr_bytes) { [0xEE, 0x42] }
      before { cpu.registers.a = 0x42 }

      it 'A=0x00、Z=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # OR A,u8 (0xF6): Z, N=H=C=0
    # ==========================================================================

    context 'OR A,u8 (0xF6) で 0xF0 | 0x0F のとき' do
      let(:instr_bytes) { [0xF6, 0x0F] }
      before { cpu.registers.a = 0xF0 }

      it 'A=0xFF、Z=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
        expect(cpu.registers.f).to eq 0x00
      end
    end

    context 'OR A,u8 で 0x00 | 0x00 のとき' do
      let(:instr_bytes) { [0xF6, 0x00] }
      before { cpu.registers.a = 0x00 }

      it 'A=0x00、Z=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # CP A,u8 (0xFE): SUB と同じフラグ計算だが A は変更しない
    # ==========================================================================

    context 'CP A,u8 (0xFE) で A == byte のとき' do
      let(:instr_bytes) { [0xFE, 0x42] }
      before { cpu.registers.a = 0x42 }

      it 'A=0x42(変化なし)、Z=1、N=1、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'CP A,u8 で A < byte のとき' do
      let(:instr_bytes) { [0xFE, 0xFF] }
      before { cpu.registers.a = 0x00 }

      it 'A 不変、Z=0、N=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end
  end
end
