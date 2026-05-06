require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/06-ld r,r.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/06-ld r,r.s)が検証する
# 0x40-0x7F の LD r,r ファミリー(63 命令、HALT=0x76 を除く全て)を再現する。
#
# Blargg は r1/r2 全組み合わせ × 値の組み合わせで checksum 比較するが、
# RSpec ではレジスタペアごとに代表値で「コピー後に dest=src になっている」ことを
# 1 ケースで検証する。HALT (0x76) は LD ではなく停止命令なので除外する。
RSpec.describe 'Blargg cpu_instrs/06-ld r,r.gb 相当のシナリオテスト' do
  context '06-ld r,r.gb を実行したとき' do
    instr_address = 0xC000
    hl_target = 0xC100 # (HL) 経由のロード/ストアで使う

    let(:cpu) { CPU.new(mmu, skip_boot: false, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: false) }
    let(:rom_data) { Array.new(0x8000, 0) }
    let(:instr_bytes) { [] }

    before do
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }
      cpu.registers.pc = instr_address
      # 各レジスタに識別可能な初期値をセット
      cpu.registers.a = 0x0A
      cpu.registers.b = 0x0B
      cpu.registers.c = 0x0C
      cpu.registers.d = 0x0D
      cpu.registers.e = 0x0E
      cpu.registers.h = (hl_target >> 8) & 0xFF # 0xC1
      cpu.registers.l = hl_target & 0xFF        # 0x00
      mmu.write_u8(address: hl_target, value: 0x42) # (HL) の中身
    end

    # ==========================================================================
    # LD B,r 系 (0x40-0x47): B を更新
    # ==========================================================================

    context 'LD B,B (0x40) を実行したとき' do
      let(:instr_bytes) { [0x40] }
      it 'B は変化しない(自身代入)' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0B
      end
    end

    context 'LD B,C (0x41) を実行したとき' do
      let(:instr_bytes) { [0x41] }
      it 'B=C=0x0C' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0C
      end
    end

    context 'LD B,D (0x42) を実行したとき' do
      let(:instr_bytes) { [0x42] }
      it 'B=D=0x0D' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0D
      end
    end

    context 'LD B,E (0x43) を実行したとき' do
      let(:instr_bytes) { [0x43] }
      it 'B=E=0x0E' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0E
      end
    end

    context 'LD B,H (0x44) を実行したとき' do
      let(:instr_bytes) { [0x44] }
      it 'B=H=0xC1' do
        cpu.step
        expect(cpu.registers.b).to eq 0xC1
      end
    end

    context 'LD B,L (0x45) を実行したとき' do
      let(:instr_bytes) { [0x45] }
      it 'B=L=0x00' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
      end
    end

    context 'LD B,(HL) (0x46) を実行したとき' do
      let(:instr_bytes) { [0x46] }
      it 'B=(HL)=0x42' do
        cpu.step
        expect(cpu.registers.b).to eq 0x42
      end
    end

    context 'LD B,A (0x47) を実行したとき' do
      let(:instr_bytes) { [0x47] }
      it 'B=A=0x0A' do
        cpu.step
        expect(cpu.registers.b).to eq 0x0A
      end
    end

    # ==========================================================================
    # LD C,r 系 (0x48-0x4F)
    # ==========================================================================

    context 'LD C,B (0x48) を実行したとき' do
      let(:instr_bytes) { [0x48] }
      it 'C=B=0x0B' do cpu.step; expect(cpu.registers.c).to eq 0x0B end
    end

    context 'LD C,C (0x49) を実行したとき' do
      let(:instr_bytes) { [0x49] }
      it 'C は変化しない' do cpu.step; expect(cpu.registers.c).to eq 0x0C end
    end

    context 'LD C,D (0x4A) を実行したとき' do
      let(:instr_bytes) { [0x4A] }
      it 'C=D=0x0D' do cpu.step; expect(cpu.registers.c).to eq 0x0D end
    end

    context 'LD C,E (0x4B) を実行したとき' do
      let(:instr_bytes) { [0x4B] }
      it 'C=E=0x0E' do cpu.step; expect(cpu.registers.c).to eq 0x0E end
    end

    context 'LD C,H (0x4C) を実行したとき' do
      let(:instr_bytes) { [0x4C] }
      it 'C=H=0xC1' do cpu.step; expect(cpu.registers.c).to eq 0xC1 end
    end

    context 'LD C,L (0x4D) を実行したとき' do
      let(:instr_bytes) { [0x4D] }
      it 'C=L=0x00' do cpu.step; expect(cpu.registers.c).to eq 0x00 end
    end

    context 'LD C,(HL) (0x4E) を実行したとき' do
      let(:instr_bytes) { [0x4E] }
      it 'C=(HL)=0x42' do cpu.step; expect(cpu.registers.c).to eq 0x42 end
    end

    context 'LD C,A (0x4F) を実行したとき' do
      let(:instr_bytes) { [0x4F] }
      it 'C=A=0x0A' do cpu.step; expect(cpu.registers.c).to eq 0x0A end
    end

    # ==========================================================================
    # LD D,r 系 (0x50-0x57)
    # ==========================================================================

    context 'LD D,B (0x50) を実行したとき' do
      let(:instr_bytes) { [0x50] }
      it 'D=B=0x0B' do cpu.step; expect(cpu.registers.d).to eq 0x0B end
    end

    context 'LD D,C (0x51) を実行したとき' do
      let(:instr_bytes) { [0x51] }
      it 'D=C=0x0C' do cpu.step; expect(cpu.registers.d).to eq 0x0C end
    end

    context 'LD D,D (0x52) を実行したとき' do
      let(:instr_bytes) { [0x52] }
      it 'D は変化しない' do cpu.step; expect(cpu.registers.d).to eq 0x0D end
    end

    context 'LD D,E (0x53) を実行したとき' do
      let(:instr_bytes) { [0x53] }
      it 'D=E=0x0E' do cpu.step; expect(cpu.registers.d).to eq 0x0E end
    end

    context 'LD D,H (0x54) を実行したとき' do
      let(:instr_bytes) { [0x54] }
      it 'D=H=0xC1' do cpu.step; expect(cpu.registers.d).to eq 0xC1 end
    end

    context 'LD D,L (0x55) を実行したとき' do
      let(:instr_bytes) { [0x55] }
      it 'D=L=0x00' do cpu.step; expect(cpu.registers.d).to eq 0x00 end
    end

    context 'LD D,(HL) (0x56) を実行したとき' do
      let(:instr_bytes) { [0x56] }
      it 'D=(HL)=0x42' do cpu.step; expect(cpu.registers.d).to eq 0x42 end
    end

    context 'LD D,A (0x57) を実行したとき' do
      let(:instr_bytes) { [0x57] }
      it 'D=A=0x0A' do cpu.step; expect(cpu.registers.d).to eq 0x0A end
    end

    # ==========================================================================
    # LD E,r 系 (0x58-0x5F)
    # ==========================================================================

    context 'LD E,B (0x58) を実行したとき' do
      let(:instr_bytes) { [0x58] }
      it 'E=B=0x0B' do cpu.step; expect(cpu.registers.e).to eq 0x0B end
    end

    context 'LD E,C (0x59) を実行したとき' do
      let(:instr_bytes) { [0x59] }
      it 'E=C=0x0C' do cpu.step; expect(cpu.registers.e).to eq 0x0C end
    end

    context 'LD E,D (0x5A) を実行したとき' do
      let(:instr_bytes) { [0x5A] }
      it 'E=D=0x0D' do cpu.step; expect(cpu.registers.e).to eq 0x0D end
    end

    context 'LD E,E (0x5B) を実行したとき' do
      let(:instr_bytes) { [0x5B] }
      it 'E は変化しない' do cpu.step; expect(cpu.registers.e).to eq 0x0E end
    end

    context 'LD E,H (0x5C) を実行したとき' do
      let(:instr_bytes) { [0x5C] }
      it 'E=H=0xC1' do cpu.step; expect(cpu.registers.e).to eq 0xC1 end
    end

    context 'LD E,L (0x5D) を実行したとき' do
      let(:instr_bytes) { [0x5D] }
      it 'E=L=0x00' do cpu.step; expect(cpu.registers.e).to eq 0x00 end
    end

    context 'LD E,(HL) (0x5E) を実行したとき' do
      let(:instr_bytes) { [0x5E] }
      it 'E=(HL)=0x42' do cpu.step; expect(cpu.registers.e).to eq 0x42 end
    end

    context 'LD E,A (0x5F) を実行したとき' do
      let(:instr_bytes) { [0x5F] }
      it 'E=A=0x0A' do cpu.step; expect(cpu.registers.e).to eq 0x0A end
    end

    # ==========================================================================
    # LD H,r 系 (0x60-0x67)
    # ==========================================================================

    context 'LD H,B (0x60) を実行したとき' do
      let(:instr_bytes) { [0x60] }
      it 'H=B=0x0B' do cpu.step; expect(cpu.registers.h).to eq 0x0B end
    end

    context 'LD H,C (0x61) を実行したとき' do
      let(:instr_bytes) { [0x61] }
      it 'H=C=0x0C' do cpu.step; expect(cpu.registers.h).to eq 0x0C end
    end

    context 'LD H,D (0x62) を実行したとき' do
      let(:instr_bytes) { [0x62] }
      it 'H=D=0x0D' do cpu.step; expect(cpu.registers.h).to eq 0x0D end
    end

    context 'LD H,E (0x63) を実行したとき' do
      let(:instr_bytes) { [0x63] }
      it 'H=E=0x0E' do cpu.step; expect(cpu.registers.h).to eq 0x0E end
    end

    context 'LD H,H (0x64) を実行したとき' do
      let(:instr_bytes) { [0x64] }
      it 'H は変化しない' do cpu.step; expect(cpu.registers.h).to eq 0xC1 end
    end

    context 'LD H,L (0x65) を実行したとき' do
      let(:instr_bytes) { [0x65] }
      it 'H=L=0x00' do cpu.step; expect(cpu.registers.h).to eq 0x00 end
    end

    context 'LD H,(HL) (0x66) を実行したとき' do
      let(:instr_bytes) { [0x66] }
      it 'H=(HL)=0x42' do cpu.step; expect(cpu.registers.h).to eq 0x42 end
    end

    context 'LD H,A (0x67) を実行したとき' do
      let(:instr_bytes) { [0x67] }
      it 'H=A=0x0A' do cpu.step; expect(cpu.registers.h).to eq 0x0A end
    end

    # ==========================================================================
    # LD L,r 系 (0x68-0x6F)
    # ==========================================================================

    context 'LD L,B (0x68) を実行したとき' do
      let(:instr_bytes) { [0x68] }
      it 'L=B=0x0B' do cpu.step; expect(cpu.registers.l).to eq 0x0B end
    end

    context 'LD L,C (0x69) を実行したとき' do
      let(:instr_bytes) { [0x69] }
      it 'L=C=0x0C' do cpu.step; expect(cpu.registers.l).to eq 0x0C end
    end

    context 'LD L,D (0x6A) を実行したとき' do
      let(:instr_bytes) { [0x6A] }
      it 'L=D=0x0D' do cpu.step; expect(cpu.registers.l).to eq 0x0D end
    end

    context 'LD L,E (0x6B) を実行したとき' do
      let(:instr_bytes) { [0x6B] }
      it 'L=E=0x0E' do cpu.step; expect(cpu.registers.l).to eq 0x0E end
    end

    context 'LD L,H (0x6C) を実行したとき' do
      let(:instr_bytes) { [0x6C] }
      it 'L=H=0xC1' do cpu.step; expect(cpu.registers.l).to eq 0xC1 end
    end

    context 'LD L,L (0x6D) を実行したとき' do
      let(:instr_bytes) { [0x6D] }
      it 'L は変化しない' do cpu.step; expect(cpu.registers.l).to eq 0x00 end
    end

    context 'LD L,(HL) (0x6E) を実行したとき' do
      let(:instr_bytes) { [0x6E] }
      it 'L=(HL)=0x42' do cpu.step; expect(cpu.registers.l).to eq 0x42 end
    end

    context 'LD L,A (0x6F) を実行したとき' do
      let(:instr_bytes) { [0x6F] }
      it 'L=A=0x0A' do cpu.step; expect(cpu.registers.l).to eq 0x0A end
    end

    # ==========================================================================
    # LD (HL),r 系 (0x70-0x77、0x76 = HALT は除く)
    # メモリ 0xC100 に書き込む
    # ==========================================================================

    context 'LD (HL),B (0x70) を実行したとき' do
      let(:instr_bytes) { [0x70] }
      it '(0xC100)=B=0x0B' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0B
      end
    end

    context 'LD (HL),C (0x71) を実行したとき' do
      let(:instr_bytes) { [0x71] }
      it '(0xC100)=C=0x0C' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0C
      end
    end

    context 'LD (HL),D (0x72) を実行したとき' do
      let(:instr_bytes) { [0x72] }
      it '(0xC100)=D=0x0D' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0D
      end
    end

    context 'LD (HL),E (0x73) を実行したとき' do
      let(:instr_bytes) { [0x73] }
      it '(0xC100)=E=0x0E' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0E
      end
    end

    context 'LD (HL),H (0x74) を実行したとき' do
      let(:instr_bytes) { [0x74] }
      it '(0xC100)=H=0xC1' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0xC1
      end
    end

    context 'LD (HL),L (0x75) を実行したとき' do
      let(:instr_bytes) { [0x75] }
      it '(0xC100)=L=0x00' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x00
      end
    end

    context 'LD (HL),A (0x77) を実行したとき' do
      let(:instr_bytes) { [0x77] }
      it '(0xC100)=A=0x0A' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x0A
      end
    end

    # ==========================================================================
    # LD A,r 系 (0x78-0x7F)
    # ==========================================================================

    context 'LD A,B (0x78) を実行したとき' do
      let(:instr_bytes) { [0x78] }
      it 'A=B=0x0B' do cpu.step; expect(cpu.registers.a).to eq 0x0B end
    end

    context 'LD A,C (0x79) を実行したとき' do
      let(:instr_bytes) { [0x79] }
      it 'A=C=0x0C' do cpu.step; expect(cpu.registers.a).to eq 0x0C end
    end

    context 'LD A,D (0x7A) を実行したとき' do
      let(:instr_bytes) { [0x7A] }
      it 'A=D=0x0D' do cpu.step; expect(cpu.registers.a).to eq 0x0D end
    end

    context 'LD A,E (0x7B) を実行したとき' do
      let(:instr_bytes) { [0x7B] }
      it 'A=E=0x0E' do cpu.step; expect(cpu.registers.a).to eq 0x0E end
    end

    context 'LD A,H (0x7C) を実行したとき' do
      let(:instr_bytes) { [0x7C] }
      it 'A=H=0xC1' do cpu.step; expect(cpu.registers.a).to eq 0xC1 end
    end

    context 'LD A,L (0x7D) を実行したとき' do
      let(:instr_bytes) { [0x7D] }
      it 'A=L=0x00' do cpu.step; expect(cpu.registers.a).to eq 0x00 end
    end

    context 'LD A,(HL) (0x7E) を実行したとき' do
      let(:instr_bytes) { [0x7E] }
      it 'A=(HL)=0x42' do cpu.step; expect(cpu.registers.a).to eq 0x42 end
    end

    context 'LD A,A (0x7F) を実行したとき' do
      let(:instr_bytes) { [0x7F] }
      it 'A は変化しない' do cpu.step; expect(cpu.registers.a).to eq 0x0A end
    end
  end
end
