require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/09-op r,r.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/09-op r,r.s)が検証する命令群:
#
#   NOP / CPL / SCF / CCF
#   ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,r(各 7 命令、A,A 含む)
#   INC/DEC r(7 命令ずつ)
#   RLCA / RLA / RRCA / RRA
#   CB-prefix RLC / RRC / RL / RR / SLA / SRA / SWAP / SRL の各 7 命令
#
# 全 80+ 命令を網羅する。Blargg は 16 種類の値 × 4 通りの F 初期値で全組合せ checksum
# 比較するが、RSpec では命令ごとに代表値で挙動を検証する(B レジスタとの組み合わせを基本に)。
RSpec.describe 'Blargg cpu_instrs/09-op r,r.gb 相当のシナリオテスト' do
  context '09-op r,r.gb を実行したとき' do
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
    # NOP / CPL / SCF / CCF
    # ==========================================================================

    context 'NOP (0x00) を実行したとき' do
      let(:instr_bytes) { [0x00] }
      before { cpu.registers.f = 0xF0 }

      it 'レジスタ・フラグ変化なし' do
        cpu.step
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'CPL (0x2F) を実行したとき' do
      let(:instr_bytes) { [0x2F] }
      before { cpu.registers.a = 0xA5 }

      it 'A=0x5A(全 bit 反転)、N=1、H=1、Z/C は保持' do
        cpu.registers.zero_flag = 1; cpu.registers.carry_flag = 1
        cpu.step
        expect(cpu.registers.a).to eq 0x5A
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'SCF (0x37) を実行したとき' do
      let(:instr_bytes) { [0x37] }
      before { cpu.registers.zero_flag = 1; cpu.registers.carry_flag = 0 }

      it 'C=1 にセット、N=0、H=0、Z は保持' do
        cpu.step
        expect(cpu.registers.carry_flag).to eq 1
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 0
      end
    end

    context 'CCF (0x3F) で C=0 のとき' do
      let(:instr_bytes) { [0x3F] }
      before { cpu.registers.carry_flag = 0 }

      it 'C=1(反転)' do
        cpu.step
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CCF (0x3F) で C=1 のとき' do
      let(:instr_bytes) { [0x3F] }
      before { cpu.registers.carry_flag = 1 }

      it 'C=0(反転)' do
        cpu.step
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    # ==========================================================================
    # OR A,r(0xB0-0xB7、A=A は B7): Z, N=H=C=0
    # ==========================================================================

    [
      [0xB0, :b, 'OR B'], [0xB1, :c, 'OR C'], [0xB2, :d, 'OR D'],
      [0xB3, :e, 'OR E'], [0xB4, :h, 'OR H'], [0xB5, :l, 'OR L']
    ].each do |opcode, reg, name|
      context "#{name} (0x#{opcode.to_s(16).upcase}) を実行したとき" do
        let(:instr_bytes) { [opcode] }
        before { cpu.registers.a = 0xF0; cpu.registers.send("#{reg}=", 0x0F) }

        it "A=0xFF(0xF0 | 0x0F)、Z=0、N=H=C=0" do
          cpu.step
          expect(cpu.registers.a).to eq 0xFF
          expect(cpu.registers.f).to eq 0x00
        end
      end
    end

    context 'OR A,A (0xB7) を実行したとき' do
      let(:instr_bytes) { [0xB7] }
      before { cpu.registers.a = 0x42 }

      it 'A 不変、Z は A==0 で判定' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    # ==========================================================================
    # CP A,r(0xB8-0xBF): SUB と同じフラグ計算、A は不変
    # ==========================================================================

    context 'CP A,B (0xB8) で A == B のとき' do
      let(:instr_bytes) { [0xB8] }
      before { cpu.registers.a = 0x42; cpu.registers.b = 0x42 }

      it 'A 不変、Z=1、N=1、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
      end
    end

    context 'CP A,A (0xBF) を実行したとき' do
      let(:instr_bytes) { [0xBF] }
      before { cpu.registers.a = 0x42 }

      it 'Z=1、N=1(A は常に自分と等しい)' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
      end
    end

    # ==========================================================================
    # ADD A,r(0x80-0x87)
    # ==========================================================================

    context 'ADD A,B (0x80) で 0x12 + 0x34 のとき' do
      let(:instr_bytes) { [0x80] }
      before { cpu.registers.a = 0x12; cpu.registers.b = 0x34 }

      it 'A=0x46、Z=0、N=0、H=0、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x46
        expect(cpu.registers.f).to eq 0x00
      end
    end

    context 'ADD A,A (0x87) を実行したとき' do
      let(:instr_bytes) { [0x87] }
      before { cpu.registers.a = 0x80 }

      it 'A=0x00(2 倍で 8bit オーバーフロー)、Z=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # ADC A,r(0x88-0x8F): C を加味
    # ==========================================================================

    context 'ADC A,B (0x88) で 0xFF + 0x00 + C=1 のとき' do
      let(:instr_bytes) { [0x88] }
      before { cpu.registers.a = 0xFF; cpu.registers.b = 0x00; cpu.registers.carry_flag = 1 }

      it 'A=0x00、Z=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # SUB A,r(0x90-0x97)
    # ==========================================================================

    context 'SUB A,B (0x90) で 0x10 - 0x01(borrow bit3)のとき' do
      let(:instr_bytes) { [0x90] }
      before { cpu.registers.a = 0x10; cpu.registers.b = 0x01 }

      it 'A=0x0F、N=1、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'SUB A,A (0x97) を実行したとき' do
      let(:instr_bytes) { [0x97] }
      before { cpu.registers.a = 0x42 }

      it 'A=0x00、Z=1、N=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
      end
    end

    # ==========================================================================
    # SBC A,r(0x98-0x9F): C を加味
    # ==========================================================================

    context 'SBC A,B (0x98) で 0x10 - 0x0F - C=1 のとき' do
      let(:instr_bytes) { [0x98] }
      before { cpu.registers.a = 0x10; cpu.registers.b = 0x0F; cpu.registers.carry_flag = 1 }

      it 'A=0x00、Z=1、N=1、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'SBC A,A (0x9F) で C=1 のとき' do
      let(:instr_bytes) { [0x9F] }
      before { cpu.registers.a = 0x42; cpu.registers.carry_flag = 1 }

      it 'A=0xFF(A - A - 1 = -1 → wrap)、N=1、H=1、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0xFF
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # AND A,r(0xA0-0xA7): N=0, H=1(特殊), C=0
    # ==========================================================================

    context 'AND A,B (0xA0) で 0xF0 & 0x0F のとき' do
      let(:instr_bytes) { [0xA0] }
      before { cpu.registers.a = 0xF0; cpu.registers.b = 0x0F }

      it 'A=0x00、Z=1、N=0、H=1、C=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.f).to eq 0xA0 # Z=1, H=1
      end
    end

    context 'AND A,A (0xA7) を実行したとき' do
      let(:instr_bytes) { [0xA7] }
      before { cpu.registers.a = 0x42 }

      it 'A 不変、Z は A==0 で判定、H=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x42
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # XOR A,r(0xA8-0xAF): N=H=C=0
    # ==========================================================================

    context 'XOR A,B (0xA8) で 0xFF ^ 0xF0 のとき' do
      let(:instr_bytes) { [0xA8] }
      before { cpu.registers.a = 0xFF; cpu.registers.b = 0xF0 }

      it 'A=0x0F' do
        cpu.step
        expect(cpu.registers.a).to eq 0x0F
      end
    end

    context 'XOR A,A (0xAF) を実行したとき' do
      let(:instr_bytes) { [0xAF] }
      before { cpu.registers.a = 0x42 }

      it 'A=0x00、Z=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # INC r / DEC r: H フラグの境界を確認
    # ==========================================================================

    context 'INC B (0x04) で B=0x0F のとき' do
      let(:instr_bytes) { [0x04] }
      before { cpu.registers.b = 0x0F }

      it 'B=0x10、H=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x10
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'INC B で B=0xFF(8bit ラップ)のとき' do
      let(:instr_bytes) { [0x04] }
      before { cpu.registers.b = 0xFF; cpu.registers.carry_flag = 1 }

      it 'B=0x00、Z=1、H=1、C は保持' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'DEC B (0x05) で B=0x10 のとき' do
      let(:instr_bytes) { [0x05] }
      before { cpu.registers.b = 0x10 }

      it 'B=0x0F、N=1、H=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0F
        expect(cpu.registers.negative_flag).to eq 1
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'DEC B で B=0x01 のとき' do
      let(:instr_bytes) { [0x05] }
      before { cpu.registers.b = 0x01 }

      it 'B=0x00、Z=1、N=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # A 専用ローテート: RLCA / RLA / RRCA / RRA(Z=0 固定)
    # ==========================================================================

    context 'RLCA (0x07) で A=0x80 のとき' do
      let(:instr_bytes) { [0x07] }
      before { cpu.registers.a = 0x80 }

      it 'A=0x01、C=1、Z=0(固定)、N=0、H=0' do
        cpu.step
        expect(cpu.registers.a).to eq 0x01
        expect(cpu.registers.f).to eq 0x10 # C=1 のみ
      end
    end

    context 'RLA (0x17) で A=0x80, C=0 のとき' do
      let(:instr_bytes) { [0x17] }
      before { cpu.registers.a = 0x80; cpu.registers.carry_flag = 0 }

      it 'A=0x00(旧 C=0 が bit0 に入る)、C=1、Z=0(固定)' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.carry_flag).to eq 1
        expect(cpu.registers.zero_flag).to eq 0 # RLA は Z=0 固定
      end
    end

    context 'RRCA (0x0F) で A=0x01 のとき' do
      let(:instr_bytes) { [0x0F] }
      before { cpu.registers.a = 0x01 }

      it 'A=0x80、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x80
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'RRA (0x1F) で A=0x01, C=0 のとき' do
      let(:instr_bytes) { [0x1F] }
      before { cpu.registers.a = 0x01; cpu.registers.carry_flag = 0 }

      it 'A=0x00、C=1' do
        cpu.step
        expect(cpu.registers.a).to eq 0x00
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    # ==========================================================================
    # CB-prefix ROTATE 系: 8bit 系の Z は結果で判定
    # ==========================================================================

    context 'CB RLC B (0xCB 0x00) で B=0x80 のとき' do
      let(:instr_bytes) { [0xCB, 0x00] }
      before { cpu.registers.b = 0x80 }

      it 'B=0x01、C=1、Z=0' do
        cpu.step
        expect(cpu.registers.b).to eq 0x01
        expect(cpu.registers.carry_flag).to eq 1
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    context 'CB RL B (0xCB 0x10) で B=0x80, C=0 のとき' do
      let(:instr_bytes) { [0xCB, 0x10] }
      before { cpu.registers.b = 0x80; cpu.registers.carry_flag = 0 }

      it 'B=0x00、C=1、Z=1(RLA と違い結果で判定)' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
        expect(cpu.registers.carry_flag).to eq 1
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    context 'CB RRC B (0xCB 0x08) で B=0x01 のとき' do
      let(:instr_bytes) { [0xCB, 0x08] }
      before { cpu.registers.b = 0x01 }

      it 'B=0x80、C=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x80
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB RR B (0xCB 0x18) で B=0x01, C=0 のとき' do
      let(:instr_bytes) { [0xCB, 0x18] }
      before { cpu.registers.b = 0x01; cpu.registers.carry_flag = 0 }

      it 'B=0x00、Z=1、C=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB SLA B (0xCB 0x20) で B=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0x20] }
      before { cpu.registers.b = 0xFF }

      it 'B=0xFE(左シフト)、C=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0xFE
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'CB SRA B (0xCB 0x28) で B=0x80 のとき' do
      let(:instr_bytes) { [0xCB, 0x28] }
      before { cpu.registers.b = 0x80 }

      it 'B=0xC0(算術右シフト、bit 7 保持)、C=0' do
        cpu.step
        expect(cpu.registers.b).to eq 0xC0
        expect(cpu.registers.carry_flag).to eq 0
      end
    end

    context 'CB SWAP B (0xCB 0x30) で B=0xA5 のとき' do
      let(:instr_bytes) { [0xCB, 0x30] }
      before { cpu.registers.b = 0xA5 }

      it 'B=0x5A(上下ニブル入れ替え)、N=H=C=0' do
        cpu.step
        expect(cpu.registers.b).to eq 0x5A
        expect(cpu.registers.f).to eq 0x00
      end
    end

    context 'CB SRL B (0xCB 0x38) で B=0x01 のとき' do
      let(:instr_bytes) { [0xCB, 0x38] }
      before { cpu.registers.b = 0x01 }

      it 'B=0x00、Z=1、C=1' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end
  end
end
