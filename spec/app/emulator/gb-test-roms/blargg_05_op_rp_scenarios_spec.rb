require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/05-op rp.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/05-op rp.s)が検証する
# レジスタペア(BC/DE/HL)の INC/DEC と ADD HL,rp の挙動を再現する。
#
#   $03 INC BC / $13 INC DE / $23 INC HL
#   $0B DEC BC / $1B DEC DE / $2B DEC HL
#   $09 ADD HL,BC / $19 ADD HL,DE / $29 ADD HL,HL
#
# Blargg は 16 種類の値の全組み合わせ × 2 通りのフラグで checksum 比較する。
# RSpec では命令ごとに代表値とフラグ計算の境界ケースを検証する。
RSpec.describe 'Blargg cpu_instrs/05-op rp.gb 相当のシナリオテスト' do
  context '05-op rp.gb を実行したとき' do
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
    # INC rr / DEC rr: フラグ変更なし(16bit ペアの増減)
    # ==========================================================================

    context 'INC BC (0x03) を実行したとき' do
      let(:instr_bytes) { [0x03] }
      before { cpu.registers.bc = 0x1234; cpu.registers.f = 0xF0 }

      it 'BC=0x1235、フラグは保持' do
        cpu.step
        expect(cpu.registers.bc).to eq 0x1235
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'INC BC で BC=0xFFFF のとき' do
      let(:instr_bytes) { [0x03] }
      before { cpu.registers.bc = 0xFFFF }

      it 'BC=0x0000 へラップ、フラグ Z は立てない' do
        cpu.step
        expect(cpu.registers.bc).to eq 0x0000
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    context 'INC DE (0x13) を実行したとき' do
      let(:instr_bytes) { [0x13] }
      before { cpu.registers.de = 0x00FF }

      it 'DE=0x0100' do
        cpu.step
        expect(cpu.registers.de).to eq 0x0100
      end
    end

    context 'INC HL (0x23) を実行したとき' do
      let(:instr_bytes) { [0x23] }
      before { cpu.registers.hl = 0x0FFF }

      it 'HL=0x1000' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x1000
      end
    end

    context 'DEC BC (0x0B) を実行したとき' do
      let(:instr_bytes) { [0x0B] }
      before { cpu.registers.bc = 0x1234 }

      it 'BC=0x1233' do
        cpu.step
        expect(cpu.registers.bc).to eq 0x1233
      end
    end

    context 'DEC BC で BC=0x0000 のとき' do
      let(:instr_bytes) { [0x0B] }
      before { cpu.registers.bc = 0x0000 }

      it 'BC=0xFFFF へラップ' do
        cpu.step
        expect(cpu.registers.bc).to eq 0xFFFF
      end
    end

    context 'DEC DE (0x1B) を実行したとき' do
      let(:instr_bytes) { [0x1B] }
      before { cpu.registers.de = 0x0100 }

      it 'DE=0x00FF' do
        cpu.step
        expect(cpu.registers.de).to eq 0x00FF
      end
    end

    context 'DEC HL (0x2B) を実行したとき' do
      let(:instr_bytes) { [0x2B] }
      before { cpu.registers.hl = 0x1000 }

      it 'HL=0x0FFF' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0FFF
      end
    end

    # ==========================================================================
    # ADD HL,rp: Z 保持、N=0、H=bit11 繰り上がり、C=bit15 繰り上がり
    # ==========================================================================

    context 'ADD HL,BC (0x09) で 0x1234 + 0x4321 のとき' do
      let(:instr_bytes) { [0x09] }
      before { cpu.registers.hl = 0x1234; cpu.registers.bc = 0x4321 }

      it 'HL=0x5555、N=0、H=0、C=0、Z は保持' do
        cpu.registers.zero_flag = 1
        cpu.step
        expect(cpu.registers.hl).to eq 0x5555
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD HL,BC で bit 11 繰り上がりのとき' do
      let(:instr_bytes) { [0x09] }
      before { cpu.registers.hl = 0x0FFF; cpu.registers.bc = 0x0001 }

      it 'HL=0x1000、H=1、C=0' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x1000
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'ADD HL,BC で bit 15 繰り上がりのとき' do
      let(:instr_bytes) { [0x09] }
      before { cpu.registers.hl = 0xFFFF; cpu.registers.bc = 0x0001 }

      it 'HL=0x0000、H=1、C=1' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0000
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'ADD HL,DE (0x19) を実行したとき' do
      let(:instr_bytes) { [0x19] }
      before { cpu.registers.hl = 0x1000; cpu.registers.de = 0x0F00 }

      it 'HL=0x1F00' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x1F00
      end
    end

    context 'ADD HL,HL (0x29) を実行したとき' do
      let(:instr_bytes) { [0x29] }
      before { cpu.registers.hl = 0x1234 }

      it 'HL=0x2468(自分自身を 2 倍)' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x2468
      end
    end

    context 'ADD HL,HL で 0x8000 を 2 倍するとき' do
      let(:instr_bytes) { [0x29] }
      before { cpu.registers.hl = 0x8000 }

      it 'HL=0x0000、C=1(bit 15 繰り上がり)' do
        cpu.step
        expect(cpu.registers.hl).to eq 0x0000
        expect(cpu.registers.carry_flag).to eq 1
      end
    end
  end
end
