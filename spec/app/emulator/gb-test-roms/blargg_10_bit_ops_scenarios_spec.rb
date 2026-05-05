require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/10-bit ops.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/10-bit ops.s)が検証する
# CB-prefix の BIT n,r / RES n,r / SET n,r ファミリー(計 192 命令)を再現する。
#
#   $CB $40-$7F  BIT n,r   (Z=!bit_n(r), N=0, H=1, C 保持)
#   $CB $80-$BF  RES n,r   (フラグ変化なし)
#   $CB $C0-$FF  SET n,r   (フラグ変化なし)
#
# 全 192 命令を網羅するとケース数が膨大なので、以下に絞る:
#   - BIT 0,r / BIT 7,r で各レジスタ(r ごとに bit が立っている / 立っていないケース)
#   - RES / SET も同様に bit 0 / bit 7 を代表として
#   - (HL) バリアントは別ケースで
RSpec.describe 'Blargg cpu_instrs/10-bit ops.gb 相当のシナリオテスト' do
  context '10-bit ops.gb を実行したとき' do
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
    # BIT n,r(0x40-0x7F): 1 ビット検査
    # 仕様: Z = !bit_n(r), N = 0, H = 1, C は保持
    # ==========================================================================

    context 'BIT 0,B (0xCB 0x40) で B の bit 0 = 1 のとき' do
      let(:instr_bytes) { [0xCB, 0x40] }
      before { cpu.registers.b = 0x01; cpu.registers.carry_flag = 1 }

      it 'Z=0、N=0、H=1、C は保持' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 0
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 1
        expect(cpu.registers.carry_flag).to eq 1
      end
    end

    context 'BIT 0,B で B の bit 0 = 0 のとき' do
      let(:instr_bytes) { [0xCB, 0x40] }
      before { cpu.registers.b = 0xFE }

      it 'Z=1、N=0、H=1' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 1
        expect(cpu.registers.negative_flag).to eq 0
        expect(cpu.registers.half_carry_flag).to eq 1
      end
    end

    context 'BIT 7,A (0xCB 0x7F) で A の bit 7 = 1 のとき' do
      let(:instr_bytes) { [0xCB, 0x7F] }
      before { cpu.registers.a = 0x80 }

      it 'Z=0' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    context 'BIT 7,A で A の bit 7 = 0 のとき' do
      let(:instr_bytes) { [0xCB, 0x7F] }
      before { cpu.registers.a = 0x7F }

      it 'Z=1' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # 各レジスタで bit を 1 つチェック(BIT 3 を代表)
    [
      [0xCB, 0x58, :b, 'BIT 3,B'], [0xCB, 0x59, :c, 'BIT 3,C'],
      [0xCB, 0x5A, :d, 'BIT 3,D'], [0xCB, 0x5B, :e, 'BIT 3,E'],
      [0xCB, 0x5C, :h, 'BIT 3,H'], [0xCB, 0x5D, :l, 'BIT 3,L'],
      [0xCB, 0x5F, :a, 'BIT 3,A']
    ].each do |b1, b2, reg, name|
      context "#{name} (0x#{b1.to_s(16).upcase} 0x#{b2.to_s(16).upcase}) で bit 3 = 1 のとき" do
        let(:instr_bytes) { [b1, b2] }
        before do
          # H レジスタは hl_target=0xC100 なので別途調整、それ以外は 0x08 にセット
          if reg == :h
            cpu.registers.h = 0x08
          elsif reg == :l
            cpu.registers.l = 0x08
          else
            cpu.registers.send("#{reg}=", 0x08)
          end
        end

        it 'Z=0、H=1' do
          cpu.step
          expect(cpu.registers.zero_flag).to eq 0
          expect(cpu.registers.half_carry_flag).to eq 1
        end
      end
    end

    # ==========================================================================
    # BIT n,(HL): メモリ経由
    # ==========================================================================

    context 'BIT 0,(HL) (0xCB 0x46) で (HL) の bit 0 = 1 のとき' do
      let(:instr_bytes) { [0xCB, 0x46] }
      before { mmu.write_u8(address: hl_target, value: 0x01) }

      it 'Z=0' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 0
      end
    end

    context 'BIT 7,(HL) (0xCB 0x7E) で (HL) の bit 7 = 0 のとき' do
      let(:instr_bytes) { [0xCB, 0x7E] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it 'Z=1' do
        cpu.step
        expect(cpu.registers.zero_flag).to eq 1
      end
    end

    # ==========================================================================
    # RES n,r(0x80-0xBF): 指定ビットを 0 にクリア(フラグ変化なし)
    # ==========================================================================

    context 'RES 0,B (0xCB 0x80) で B=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0x80] }
      before { cpu.registers.b = 0xFF; cpu.registers.f = 0xF0 }

      it 'B=0xFE(bit 0 がクリア)、フラグは保持' do
        cpu.step
        expect(cpu.registers.b).to eq 0xFE
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'RES 0,B で B=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0x80] }
      before { cpu.registers.b = 0x00 }

      it 'B=0x00(変化なし)' do
        cpu.step
        expect(cpu.registers.b).to eq 0x00
      end
    end

    context 'RES 7,A (0xCB 0xBF) で A=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0xBF] }
      before { cpu.registers.a = 0xFF }

      it 'A=0x7F' do
        cpu.step
        expect(cpu.registers.a).to eq 0x7F
      end
    end

    [
      [0xCB, 0x98, :b, 'RES 3,B'], [0xCB, 0x99, :c, 'RES 3,C'],
      [0xCB, 0x9A, :d, 'RES 3,D'], [0xCB, 0x9B, :e, 'RES 3,E'],
      [0xCB, 0x9F, :a, 'RES 3,A']
    ].each do |b1, b2, reg, name|
      context "#{name} で値 0xFF のとき" do
        let(:instr_bytes) { [b1, b2] }
        before { cpu.registers.send("#{reg}=", 0xFF) }

        it "#{reg}=0xF7(bit 3 がクリア)" do
          cpu.step
          expect(cpu.registers.send(reg)).to eq 0xF7
        end
      end
    end

    # ==========================================================================
    # RES n,(HL): メモリ経由
    # ==========================================================================

    context 'RES 0,(HL) (0xCB 0x86) で (HL)=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0x86] }
      before { mmu.write_u8(address: hl_target, value: 0xFF) }

      it '(HL)=0xFE' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0xFE
      end
    end

    context 'RES 7,(HL) (0xCB 0xBE) で (HL)=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0xBE] }
      before { mmu.write_u8(address: hl_target, value: 0xFF) }

      it '(HL)=0x7F' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x7F
      end
    end

    # ==========================================================================
    # SET n,r(0xC0-0xFF): 指定ビットを 1 にセット(フラグ変化なし)
    # ==========================================================================

    context 'SET 0,B (0xCB 0xC0) で B=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xC0] }
      before { cpu.registers.b = 0x00; cpu.registers.f = 0xF0 }

      it 'B=0x01、フラグは保持' do
        cpu.step
        expect(cpu.registers.b).to eq 0x01
        expect(cpu.registers.f).to eq 0xF0
      end
    end

    context 'SET 0,B で B=0xFF のとき' do
      let(:instr_bytes) { [0xCB, 0xC0] }
      before { cpu.registers.b = 0xFF }

      it 'B=0xFF(変化なし)' do
        cpu.step
        expect(cpu.registers.b).to eq 0xFF
      end
    end

    context 'SET 7,A (0xCB 0xFF) で A=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xFF] }
      before { cpu.registers.a = 0x00 }

      it 'A=0x80' do
        cpu.step
        expect(cpu.registers.a).to eq 0x80
      end
    end

    [
      [0xCB, 0xD8, :b, 'SET 3,B'], [0xCB, 0xD9, :c, 'SET 3,C'],
      [0xCB, 0xDA, :d, 'SET 3,D'], [0xCB, 0xDB, :e, 'SET 3,E'],
      [0xCB, 0xDF, :a, 'SET 3,A']
    ].each do |b1, b2, reg, name|
      context "#{name} で値 0x00 のとき" do
        let(:instr_bytes) { [b1, b2] }
        before { cpu.registers.send("#{reg}=", 0x00) }

        it "#{reg}=0x08(bit 3 がセット)" do
          cpu.step
          expect(cpu.registers.send(reg)).to eq 0x08
        end
      end
    end

    # ==========================================================================
    # SET n,(HL): メモリ経由
    # ==========================================================================

    context 'SET 0,(HL) (0xCB 0xC6) で (HL)=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xC6] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it '(HL)=0x01' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x01
      end
    end

    context 'SET 7,(HL) (0xCB 0xFE) で (HL)=0x00 のとき' do
      let(:instr_bytes) { [0xCB, 0xFE] }
      before { mmu.write_u8(address: hl_target, value: 0x00) }

      it '(HL)=0x80' do
        cpu.step
        expect(mmu.read_u8(address: hl_target)).to eq 0x80
      end
    end
  end
end
