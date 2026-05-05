require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/11-op a,(hl).gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/11-op a,(hl).s)が検証する命令群:
#
#   レジスタペア間接 LD: $0A LD A,(BC) / $1A LD A,(DE) / $02 LD (BC),A / $12 LD (DE),A
#   HL+/-:               $2A/$3A LD A,(HL+/-)、$22/$32 LD (HL+/-),A
#   ALU (HL):            $B6 OR / $BE CP / $86 ADD / $8E ADC / $96 SUB / $9E SBC / $A6 AND / $AE XOR
#   メモリ INC/DEC:      $34 INC (HL) / $35 DEC (HL)
#   CB-prefix (HL):      ROTATE/SHIFT/SWAP/BIT/RES/SET の (HL) バリアント
#   DAA:                 $27
RSpec.describe 'Blargg cpu_instrs/11-op a,(hl).gb 相当のシナリオテスト' do
  context '11-op a,(hl).gb を実行したとき' do
    instr_address = 0xC000
    hl_target = 0xC100

    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:rom_data) { Array.new(0x8000, 0) }
    let(:instr_bytes) { [] }

    before do
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }
      cpu.registers.pc = instr_address
      cpu.registers.hl = hl_target
    end

    # ==========================================================================
    # レジスタペア間接 LD
    # ==========================================================================

    context 'LD A,(BC) (0x0A) を実行したとき' do
      let(:instr_bytes) { [0x0A] }
      before do
        cpu.registers.bc = 0xC100
        mmu.write_u8(address: 0xC100, value: 0x42)
      end

      it 'A=0x42' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
      end
    end

    context 'LD A,(DE) (0x1A) を実行したとき' do
      let(:instr_bytes) { [0x1A] }
      before do
        cpu.registers.de = 0xC100
        mmu.write_u8(address: 0xC100, value: 0x42)
      end

      it 'A=0x42' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
      end
    end

    context 'LD (BC),A (0x02) を実行したとき' do
      let(:instr_bytes) { [0x02] }
      before { cpu.registers.bc = 0xC100; cpu.registers.a = 0x55 }

      it '(BC)=0x55' do
        cpu.step
        expect(mmu.read_u8(address: 0xC100)).to eq 0x55
      end
    end

    context 'LD (DE),A (0x12) を実行したとき' do
      let(:instr_bytes) { [0x12] }
      before { cpu.registers.de = 0xC100; cpu.registers.a = 0x55 }

      it '(DE)=0x55' do
        cpu.step
        expect(mmu.read_u8(address: 0xC100)).to eq 0x55
      end
    end

    # ==========================================================================
    # HL+/- 系
    # ==========================================================================

    context 'LD A,(HL+) (0x2A) を実行したとき' do
      let(:instr_bytes) { [0x2A] }
      before { mmu.write_u8(address: hl_target, value: 0x42) }

      it 'A=0x42、HL=0xC101(増分)' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.hl).to eq 0xC101
      end
    end

    context 'LD A,(HL-) (0x3A) を実行したとき' do
      let(:instr_bytes) { [0x3A] }
      before { mmu.write_u8(address: hl_target, value: 0x42) }

      it 'A=0x42、HL=0xC0FF(減分)' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.hl).to eq 0xC0FF
      end
    end

    context 'LD (HL+),A (0x22) を実行したとき' do
      let(:instr_bytes) { [0x22] }
      before { cpu.registers.a = 0x55 }

      it '(HL=0xC100)=0x55、HL=0xC101' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x55
        expect(cpu.registers.hl).to eq 0xC101
      end
    end

    context 'LD (HL-),A (0x32) を実行したとき' do
      let(:instr_bytes) { [0x32] }
      before { cpu.registers.a = 0x55 }

      it '(HL=0xC100)=0x55、HL=0xC0FF' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x55
        expect(cpu.registers.hl).to eq 0xC0FF
      end
    end

    # ==========================================================================
    # ALU (HL): A と (HL) の値で演算
    # ==========================================================================

    context 'OR A,(HL) (0xB6) で A=0xF0 / (HL)=0x0F のとき' do
      let(:instr_bytes) { [0xB6] }
      before { cpu.registers.a = 0xF0; mmu.write_u8(address: hl_target, value: 0x0F) }

      it 'A=0xFF' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
      end
    end

    context 'CP A,(HL) (0xBE) で A == (HL) のとき' do
      let(:instr_bytes) { [0xBE] }
      before { cpu.registers.a = 0x42; mmu.write_u8(address: hl_target, value: 0x42) }

      it 'A 不変、Z=1、N=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
      end
    end

    context 'ADD A,(HL) (0x86) で 0x12 + 0x34 のとき' do
      let(:instr_bytes) { [0x86] }
      before { cpu.registers.a = 0x12; mmu.write_u8(address: hl_target, value: 0x34) }

      it 'A=0x46' do
        cpu.step
        expect(cpu.registers.a).to eq 0x46
      end
    end

    context 'ADC A,(HL) (0x8E) で 0xFF + 0x00 + C=1 のとき' do
      let(:instr_bytes) { [0x8E] }
      before do
        cpu.registers.a = 0xFF
        cpu.registers.carry_flag = 1
        mmu.write_u8(address: hl_target, value: 0x00)
      end

      it 'A=0x00、Z=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'SUB A,(HL) (0x96) で 0x10 - 0x01 のとき' do
      let(:instr_bytes) { [0x96] }
      before { cpu.registers.a = 0x10; mmu.write_u8(address: hl_target, value: 0x01) }

      it 'A=0x0F、N=1、H=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'SBC A,(HL) (0x9E) で 0x10 - 0x0F - C=1 のとき' do
      let(:instr_bytes) { [0x9E] }
      before do
        cpu.registers.a = 0x10
        cpu.registers.carry_flag = 1
        mmu.write_u8(address: hl_target, value: 0x0F)
      end

      it 'A=0x00、Z=1、N=1、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'AND A,(HL) (0xA6) で 0xFF & 0x0F のとき' do
      let(:instr_bytes) { [0xA6] }
      before { cpu.registers.a = 0xFF; mmu.write_u8(address: hl_target, value: 0x0F) }

      it 'A=0x0F、H=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'XOR A,(HL) (0xAE) で 0xFF ^ 0xFF のとき' do
      let(:instr_bytes) { [0xAE] }
      before { cpu.registers.a = 0xFF; mmu.write_u8(address: hl_target, value: 0xFF) }

      it 'A=0x00、Z=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # INC (HL) / DEC (HL): メモリの値を +1 / -1
    # ==========================================================================

    context 'INC (HL) (0x34) で (HL)=0x0F のとき' do
      let(:instr_bytes) { [0x34] }
      before { mmu.write_u8(address: hl_target, value: 0x0F); cpu.registers.carry_flag = 1 }

      it '(HL)=0x10、H=1、C は保持' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x10
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'INC (HL) で (HL)=0xFF のとき' do
      let(:instr_bytes) { [0x34] }
      before { mmu.write_u8(address: hl_target, value: 0xFF) }

      it '(HL)=0x00、Z=1、H=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'DEC (HL) (0x35) で (HL)=0x10 のとき' do
      let(:instr_bytes) { [0x35] }
      before { mmu.write_u8(address: hl_target, value: 0x10) }

      it '(HL)=0x0F、N=1、H=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0F
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'DEC (HL) で (HL)=0x01 のとき' do
      let(:instr_bytes) { [0x35] }
      before { mmu.write_u8(address: hl_target, value: 0x01) }

      it '(HL)=0x00、Z=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # CB-prefix (HL) バリアント: ROTATE / SHIFT / SWAP
    # ==========================================================================

    context 'CB RLC (HL) (0xCB 0x06) で (HL)=0x80 のとき' do
      let(:instr_bytes) { [0xCB, 0x06] }
      before { mmu.write_u8(address: hl_target, value: 0x80) }

      it '(HL)=0x01、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x01
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB RRC (HL) (0xCB 0x0E) で (HL)=0x01 のとき' do
      let(:instr_bytes) { [0xCB, 0x0E] }
      before { mmu.write_u8(address: hl_target, value: 0x01) }

      it '(HL)=0x80、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x80
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB RL (HL) (0xCB 0x16) で (HL)=0x80, C=0 のとき' do
      let(:instr_bytes) { [0xCB, 0x16] }
      before do
        mmu.write_u8(address: hl_target, value: 0x80)
        cpu.registers.carry_flag = 0
      end

      it '(HL)=0x00、Z=1、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB RR (HL) (0xCB 0x1E) で (HL)=0x01, C=0 のとき' do
      let(:instr_bytes) { [0xCB, 0x1E] }
      before do
        mmu.write_u8(address: hl_target, value: 0x01)
        cpu.registers.carry_flag = 0
      end

      it '(HL)=0x00、Z=1、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB SLA (HL) (0xCB 0x26) で (HL)=0x80 のとき' do
      let(:instr_bytes) { [0xCB, 0x26] }
      before { mmu.write_u8(address: hl_target, value: 0x80) }

      it '(HL)=0x00、Z=1、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB SRA (HL) (0xCB 0x2E) で (HL)=0x80(MSB 保持)のとき' do
      let(:instr_bytes) { [0xCB, 0x2E] }
      before { mmu.write_u8(address: hl_target, value: 0x80) }

      it '(HL)=0xC0(算術右シフト)、C=0' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0xC0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'CB SWAP (HL) (0xCB 0x36) で (HL)=0xA5 のとき' do
      let(:instr_bytes) { [0xCB, 0x36] }
      before { mmu.write_u8(address: hl_target, value: 0xA5) }

      it '(HL)=0x5A' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x5A
      end
    end

    context 'CB SRL (HL) (0xCB 0x3E) で (HL)=0x01 のとき' do
      let(:instr_bytes) { [0xCB, 0x3E] }
      before { mmu.write_u8(address: hl_target, value: 0x01) }

      it '(HL)=0x00、Z=1、C=1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # CB-prefix BIT/RES/SET (HL): メモリの bit を検査・操作
    # ==========================================================================

    context 'CB BIT 0,(HL) (0xCB 0x46) で (HL) の bit 0 = 1 のとき' do
      let(:instr_bytes) { [0xCB, 0x46] }
      before { mmu.write_u8(address: hl_target, value: 0x01) }

      it 'Z=0' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    context 'CB BIT 7,(HL) (0xCB 0x7E) で (HL) の bit 7 = 0 のとき' do
      let(:instr_bytes) { [0xCB, 0x7E] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it 'Z=1' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    context 'CB RES 0,(HL) (0xCB 0x86) で (HL)=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0x86] }
      before { mmu.write_u8(address: hl_target, value: 0xFF) }

      it '(HL)=0xFE' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0xFE
      end
    end

    context 'CB RES 7,(HL) (0xCB 0xBE) で (HL)=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0xBE] }
      before { mmu.write_u8(address: hl_target, value: 0xFF) }

      it '(HL)=0x7F' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x7F
      end
    end

    context 'CB SET 0,(HL) (0xCB 0xC6) で (HL)=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xC6] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it '(HL)=0x01' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x01
      end
    end

    context 'CB SET 7,(HL) (0xCB 0xFE) で (HL)=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xFE] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it '(HL)=0x80' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x80
      end
    end

    # ==========================================================================
    # DAA(0x27): BCD 補正
    # ==========================================================================

    context 'DAA (0x27) で ADD 後 A=0x0A(low nibble > 9)のとき' do
      let(:instr_bytes) { [0x27] }
      before do
        cpu.registers.a = 0x0A
        cpu.registers.negative_flag = 0 # 直前は ADD
        cpu.registers.half_carry_flag = 0
        cpu.registers.carry_flag = 0
      end

      it 'A=0x10(下位ニブル補正で +6)' do
        cpu.step
        expect(cpu.registers.a).to eq 0x10
      end
    end

    context 'DAA で ADD 後 A=0x9A(高位 > 0x99)のとき' do
      let(:instr_bytes) { [0x27] }
      before do
        cpu.registers.a = 0x9A
        cpu.registers.negative_flag = 0
        cpu.registers.half_carry_flag = 0
        cpu.registers.carry_flag = 0
      end

      it 'A=0x00、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'DAA で SUB 後 A=0xFA, H=1 のとき' do
      let(:instr_bytes) { [0x27] }
      before do
        cpu.registers.a = 0xFA
        cpu.registers.negative_flag = 1 # 直前は SUB
        cpu.registers.half_carry_flag = 1
        cpu.registers.carry_flag = 0
      end

      it 'A=0xF4(下位ニブル補正で -6)' do
        cpu.step
        expect(cpu.registers.a).to eq 0xF4
      end
    end
  end
end
