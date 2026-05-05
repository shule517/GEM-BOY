require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/08-misc instrs.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/08-misc instrs.s)が検証する
# 雑多な命令(LDH / LD r16,u16 / LD (u16),A / LD (u16),SP / PUSH / POP)を再現する。
#
#   $F0 LDH A,(u8)    / $E0 LDH (u8),A
#   $F2 LDH A,(C)     / $E2 LDH (C),A
#   $FA LD A,(u16)    / $EA LD (u16),A
#   $08 LD (u16),SP
#   $01/$11/$21/$31  LD rr,u16
#   $C5/$D5/$E5/$F5  PUSH rr     / $C1/$D1/$E1/$F1  POP rr
RSpec.describe 'Blargg cpu_instrs/08-misc instrs.gb 相当のシナリオテスト' do
  context '08-misc instrs.gb を実行したとき' do
    instr_address = 0xC000

    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:rom_data) { Array.new(0x8000, 0) }
    let(:instr_bytes) { [] }

    before do
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }
      cpu.registers.pc = instr_address
    end

    # ==========================================================================
    # LDH(I/O ポート 0xFF00-0xFFFF)
    # ==========================================================================

    context 'LDH A,(u8) (0xF0 0x91) を実行したとき' do
      # 0xFF91 から A に読み込む
      let(:instr_bytes) { [0xF0, 0x91] }
      before { mmu.write_u8(address: 0xFF91, value: 0x55) }

      it 'A=0x55' do
        cpu.step
        expect(cpu.registers.a).to eq 0x55
      end
    end

    context 'LDH (u8),A (0xE0 0x91) を実行したとき' do
      let(:instr_bytes) { [0xE0, 0x91] }
      before { cpu.registers.a = 0xAA }

      it '(0xFF91)=0xAA' do
        cpu.step
        expect(mmu.read_u8(address: 0xFF91)).to eq 0xAA
      end
    end

    context 'LDH A,(C) (0xF2) を実行したとき' do
      let(:instr_bytes) { [0xF2] }
      before do
        cpu.registers.c = 0x91
        mmu.write_u8(address: 0xFF91, value: 0x55)
      end

      it 'A=(0xFF00 + C)=0x55' do
        cpu.step
        expect(cpu.registers.a).to eq 0x55
      end
    end

    context 'LDH (C),A (0xE2) を実行したとき' do
      let(:instr_bytes) { [0xE2] }
      before { cpu.registers.c = 0x91; cpu.registers.a = 0xAA }

      it '(0xFF00 + C)=0xAA' do
        cpu.step
        expect(mmu.read_u8(address: 0xFF91)).to eq 0xAA
      end
    end

    # ==========================================================================
    # LD A,(u16) / LD (u16),A: 16bit 絶対アドレッシング
    # ==========================================================================

    context 'LD A,(u16) (0xFA 0x91 0xFF) を実行したとき' do
      let(:instr_bytes) { [0xFA, 0x91, 0xFF] }
      before { mmu.write_u8(address: 0xFF91, value: 0x55) }

      it 'A=0x55' do
        cpu.step
        expect(cpu.registers.a).to eq 0x55
      end
    end

    context 'LD (u16),A (0xEA 0x91 0xFF) を実行したとき' do
      let(:instr_bytes) { [0xEA, 0x91, 0xFF] }
      before { cpu.registers.a = 0xAA }

      it '(0xFF91)=0xAA' do
        cpu.step
        expect(mmu.read_u8(address: 0xFF91)).to eq 0xAA
      end
    end

    # ==========================================================================
    # LD (u16),SP (0x08): SP の 2 バイトを (u16) と (u16+1) にリトルエンディアンで書く
    # ==========================================================================

    context 'LD (u16),SP (0x08 0x00 0xC1) を実行したとき' do
      let(:instr_bytes) { [0x08, 0x00, 0xC1] }
      before { cpu.registers.sp = 0x1234 }

      it '(0xC100)=0x34(low)、(0xC101)=0x12(high)' do
        cpu.step
        expect(mmu.read_u8(address: 0xC100)).to eq 0x34
        expect(mmu.read_u8(address: 0xC101)).to eq 0x12
      end
    end

    # ==========================================================================
    # LD rr,u16: 16bit 即値ロード
    # ==========================================================================

    context 'LD BC,u16 (0x01 0x23 0x01) を実行したとき' do
      let(:instr_bytes) { [0x01, 0x23, 0x01] }

      it 'BC=0x0123' do
        cpu.step
        expect(cpu.registers.bc).to eq 0x0123
      end
    end

    context 'LD DE,u16 (0x11 0x23 0x01) を実行したとき' do
      let(:instr_bytes) { [0x11, 0x23, 0x01] }

      it 'DE=0x0123' do
        cpu.step
        expect(cpu.registers.de).to eq 0x0123
      end
    end

    context 'LD HL,u16 (0x21 0x23 0x01) を実行したとき' do
      let(:instr_bytes) { [0x21, 0x23, 0x01] }

      it 'HL=0x0123' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0123
      end
    end

    context 'LD SP,u16 (0x31 0x23 0x01) を実行したとき' do
      let(:instr_bytes) { [0x31, 0x23, 0x01] }

      it 'SP=0x0123' do
        cpu.step
        expect(cpu.registers.sp).to eq 0x0123
      end
    end

    # ==========================================================================
    # PUSH rr: SP -= 2、(SP+1)=high、(SP)=low
    # ==========================================================================

    context 'PUSH BC (0xC5) を実行したとき' do
      let(:instr_bytes) { [0xC5] }
      before { cpu.registers.sp = 0xDFFE; cpu.registers.bc = 0x1234 }

      it 'SP=0xDFFC, (0xDFFD)=0x12, (0xDFFC)=0x34' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDFFC
        expect(mmu.read_u8(address: 0xDFFD)).to eq 0x12
        expect(mmu.read_u8(address: 0xDFFC)).to eq 0x34
      end
    end

    context 'PUSH DE (0xD5) を実行したとき' do
      let(:instr_bytes) { [0xD5] }
      before { cpu.registers.sp = 0xDFFE; cpu.registers.de = 0x5678 }

      it 'SP=0xDFFC, (0xDFFD)=0x56, (0xDFFC)=0x78' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDFFC
        expect(mmu.read_u8(address: 0xDFFD)).to eq 0x56
        expect(mmu.read_u8(address: 0xDFFC)).to eq 0x78
      end
    end

    context 'PUSH HL (0xE5) を実行したとき' do
      let(:instr_bytes) { [0xE5] }
      before { cpu.registers.sp = 0xDFFE; cpu.registers.hl = 0xABCD }

      it 'SP=0xDFFC, (0xDFFD)=0xAB, (0xDFFC)=0xCD' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDFFC
        expect(mmu.read_u8(address: 0xDFFD)).to eq 0xAB
        expect(mmu.read_u8(address: 0xDFFC)).to eq 0xCD
      end
    end

    context 'PUSH AF (0xF5) を実行したとき' do
      let(:instr_bytes) { [0xF5] }
      before do
        cpu.registers.sp = 0xDFFE
        cpu.registers.a = 0x12
        cpu.registers.f = 0xF0 # Z=N=H=C=1
      end

      it 'SP=0xDFFC, (0xDFFD)=0x12, (0xDFFC)=0xF0' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDFFC
        expect(mmu.read_u8(address: 0xDFFD)).to eq 0x12
        expect(mmu.read_u8(address: 0xDFFC)).to eq 0xF0
      end
    end

    # ==========================================================================
    # POP rr: low=(SP), high=(SP+1)、SP += 2
    # ==========================================================================

    context 'POP BC (0xC1) を実行したとき' do
      let(:instr_bytes) { [0xC1] }
      before do
        cpu.registers.sp = 0xDFFC
        mmu.write_u8(address: 0xDFFC, value: 0x34) # low → C
        mmu.write_u8(address: 0xDFFD, value: 0x12) # high → B
      end

      it 'BC=0x1234, SP=0xDFFE' do
        cpu.step
        expect(cpu.registers.bc).to eq 0x1234
        expect(cpu.registers.sp).to eq 0xDFFE
      end
    end

    context 'POP DE (0xD1) を実行したとき' do
      let(:instr_bytes) { [0xD1] }
      before do
        cpu.registers.sp = 0xDFFC
        mmu.write_u8(address: 0xDFFC, value: 0x78)
        mmu.write_u8(address: 0xDFFD, value: 0x56)
      end

      it 'DE=0x5678, SP=0xDFFE' do
        cpu.step
        expect(cpu.registers.de).to eq 0x5678
        expect(cpu.registers.sp).to eq 0xDFFE
      end
    end

    context 'POP HL (0xE1) を実行したとき' do
      let(:instr_bytes) { [0xE1] }
      before do
        cpu.registers.sp = 0xDFFC
        mmu.write_u8(address: 0xDFFC, value: 0xCD)
        mmu.write_u8(address: 0xDFFD, value: 0xAB)
      end

      it 'HL=0xABCD, SP=0xDFFE' do
        cpu.step
        expect(cpu.registers.hl).to eq 0xABCD
        expect(cpu.registers.sp).to eq 0xDFFE
      end
    end

    context 'POP AF (0xF1) を実行したとき' do
      let(:instr_bytes) { [0xF1] }
      before do
        cpu.registers.sp = 0xDFFC
        mmu.write_u8(address: 0xDFFC, value: 0xFF) # F の下位 4bit はマスクされて 0xF0 になる
        mmu.write_u8(address: 0xDFFD, value: 0x12)
      end

      it 'A=0x12、F=0xF0(下位 4bit はマスク)、SP=0xDFFE' do
        cpu.step
        expect(cpu.registers.a).to eq 0x12
        expect(cpu.registers.f).to eq 0xF0
        expect(cpu.registers.sp).to eq 0xDFFE
      end
    end
  end
end
