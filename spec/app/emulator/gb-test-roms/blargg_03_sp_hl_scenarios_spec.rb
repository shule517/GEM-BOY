require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/03-op sp,hl.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/03-op sp,hl.s)が検証する
# SP / HL を絡めた 8 命令の挙動を再現する。
#
#   $33      INC SP
#   $3B      DEC SP
#   $39      ADD HL,SP
#   $F9      LD  SP,HL
#   $E8 i8   ADD SP,i8
#   $F8 i8   LD  HL,SP+i8
#
# Blargg は SP と HL を 15 種類の境界値(0x0000 / 0x000F / 0x0010 / 0x007F /
# 0x0080 / 0x00FF / 0x0100 / 0x0F00 / 0x1F00 / 0x1000 / 0x7FFF / 0x8000 / 0xFFFF)で
# 全組み合わせ × 2 通りのフラグで checksum 比較するが、RSpec では命令ごとに
# 代表値での挙動を 1〜2 ケースで検証する。
RSpec.describe 'Blargg cpu_instrs/03-op sp,hl.gb 相当のシナリオテスト' do
  context '03-op sp,hl.gb を実行したとき' do
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
    # INC SP / DEC SP(0x33 / 0x3B): 16bit ペア INC/DEC はフラグを変更しない
    # ==========================================================================

    context 'INC SP (0x33) を実行したとき' do
      let(:instr_bytes) { [0x33] }
      before { cpu.registers.sp = 0x1234; cpu.registers.f = 0xF0 }

      it 'SP=0x1235、フラグは保持' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x1235
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'INC SP で SP=0xFFFF のとき' do
      let(:instr_bytes) { [0x33] }
      before { cpu.registers.sp = 0xFFFF }

      it 'SP=0x0000 へラップ' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x0000
      end
    end

    context 'DEC SP (0x3B) を実行したとき' do
      let(:instr_bytes) { [0x3B] }
      before { cpu.registers.sp = 0x1234; cpu.registers.f = 0xF0 }

      it 'SP=0x1233、フラグは保持' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x1233
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'DEC SP で SP=0x0000 のとき' do
      let(:instr_bytes) { [0x3B] }
      before { cpu.registers.sp = 0x0000 }

      it 'SP=0xFFFF へラップ' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xFFFF
      end
    end

    # ==========================================================================
    # ADD HL,SP (0x39): Z 保持、N=0、H/C は bit11/15 のキャリーで計算
    # ==========================================================================

    context 'ADD HL,SP (0x39) を実行したとき' do
      let(:instr_bytes) { [0x39] }
      before { cpu.registers.hl = 0x1234; cpu.registers.sp = 0x0008 }

      it 'HL=0x123C、N=0、H=0、C=0、Z は保持' do
        cpu.registers.zero_flag = 1
        cpu.step
        expect(cpu.registers.hl).to eq 0x123C
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD HL,SP で bit 11 から繰り上がるとき' do
      let(:instr_bytes) { [0x39] }
      before { cpu.registers.hl = 0x0FFF; cpu.registers.sp = 0x0001 }

      it 'HL=0x1000、H=1、C=0' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x1000
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD HL,SP で bit 15 から繰り上がるとき' do
      let(:instr_bytes) { [0x39] }
      before { cpu.registers.hl = 0xFFFF; cpu.registers.sp = 0x0001 }

      it 'HL=0x0000、H=1、C=1' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0000
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # LD SP,HL (0xF9): フラグ変更なし
    # ==========================================================================

    context 'LD SP,HL (0xF9) を実行したとき' do
      let(:instr_bytes) { [0xF9] }
      before { cpu.registers.hl = 0xCAFE; cpu.registers.sp = 0x0000; cpu.registers.f = 0xF0 }

      it 'SP=HL=0xCAFE、フラグは保持' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xCAFE
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    # ==========================================================================
    # ADD SP,i8 (0xE8): Z=0/N=0、H/C は下位ニブル/バイトの加算で計算
    # ==========================================================================

    context 'ADD SP,1 (0xE8 0x01) を実行したとき' do
      let(:instr_bytes) { [0xE8, 0x01] }
      before { cpu.registers.sp = 0x0008 }

      it 'SP=0x0009、Z=0、N=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x0009
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD SP,1 で下位ニブルが繰り上がるとき' do
      let(:instr_bytes) { [0xE8, 0x01] }
      before { cpu.registers.sp = 0x000F }

      it 'SP=0x0010、H=1、C=0' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x0010
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD SP,1 で下位バイトが繰り上がるとき' do
      let(:instr_bytes) { [0xE8, 0x01] }
      before { cpu.registers.sp = 0x00FF }

      it 'SP=0x0100、H=1、C=1' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x0100
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'ADD SP,-1 (0xE8 0xFF) を実行したとき' do
      # i8 = 0xFF = -1。フラグは下位ニブル/バイト**unsigned**の加算で計算
      # 0xFE + 0xFF = 0x1FD → C=1, 0xE + 0xF = 0x1D → H=1
      let(:instr_bytes) { [0xE8, 0xFF] }
      before { cpu.registers.sp = 0x00FE }

      it 'SP=0x00FD、Z=0、N=0、H=1、C=1' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x00FD
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # LD HL,SP+i8 (0xF8): ADD SP と同じフラグ計算、SP は不変、HL のみ更新
    # ==========================================================================

    context 'LD HL,SP+1 (0xF8 0x01) を実行したとき' do
      let(:instr_bytes) { [0xF8, 0x01] }
      before { cpu.registers.sp = 0x0008; cpu.registers.hl = 0x0000 }

      it 'HL=0x0009、SP は不変、Z=0、N=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0009
        expect(cpu.registers.sp).to eq 0x0008
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'LD HL,SP+1 で下位ニブルが繰り上がるとき' do
      let(:instr_bytes) { [0xF8, 0x01] }
      before { cpu.registers.sp = 0x000F }

      it 'HL=0x0010、H=1、C=0' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0010
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'LD HL,SP-1 (0xF8 0xFF) を実行したとき' do
      let(:instr_bytes) { [0xF8, 0xFF] }
      before { cpu.registers.sp = 0x00FE }

      it 'HL=0x00FD、SP は不変、H=1、C=1' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x00FD
        expect(cpu.registers.sp).to eq 0x00FE
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end
  end
end
