require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/07-jr,jp,call,ret,rst.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/07-jr,jp,call,ret,rst.s)が行う
# test_instr フレームワークを RSpec で再現する。フレームワークは:
#
#   1. 0xDF80 - 5..-2 に sentinel バイト(0x78,0x56,0x34,0x12)を書く
#   2. SP = 0xDF80
#   3. 戻り先(instr+3 = 0xC003)を push → SP=0xDF7E
#      これで 0xDF7F=0xC0(high), 0xDF7E=0x03(low) に上書きされる
#   4. PC = instr (0xC000) に jump
#   5. 命令を 1 個実行
#   6. 結果の PC / SP / A / スタック内容を検証
#
# Blargg は 16 通りのフラグ組み合わせ × 24 命令の checksum 比較で全網羅するが、
# RSpec では「分岐成立 / 不成立それぞれで PC・SP・スタックがどう動くか」を
# 命令ごとに 1〜2 ケースで代表検証する。
RSpec.describe 'Blargg cpu_instrs/07-jr,jp,call,ret,rst.gb 相当のシナリオテスト' do
  context '07-jr,jp,call,ret,rst.gb を実行したとき' do
    # === 共通定数 ===
    instr_address  = 0xC000 # 命令バイトを置く WRAM 上のアドレス
    return_address = 0xC003 # 命令の次バイト(test_instr が push する戻り先)

    let(:cpu) { CPU.new(mmu, skip_boot: false, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: false) }
    let(:rom_data) { Array.new(0x8000, 0) } # ROM は使わないので 32KB のゼロ配列
    let(:instr_bytes) { [] }

    # test_instr フレームワークと同等の初期状態を組み立てる
    before do
      # 1. 命令バイトを 0xC000 に配置
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }

      # 2. sentinel バイトを 0xDF7B..0xDF7E に書く
      mmu.write_u8(address: 0xDF7E, value: 0x12)
      mmu.write_u8(address: 0xDF7D, value: 0x34)
      mmu.write_u8(address: 0xDF7C, value: 0x56)
      mmu.write_u8(address: 0xDF7B, value: 0x78)

      # 3. SP=0xDF80 から戻り先(0xC003)を push → SP=0xDF7E
      #    push は high → low の順に書く(GB のスタックは高→低に伸びる)
      mmu.write_u8(address: 0xDF7F, value: (return_address >> 8) & 0xFF) # 0xC0
      mmu.write_u8(address: 0xDF7E, value: return_address & 0xFF)        # 0x03(0x12 sentinel を上書き)
      cpu.registers.sp = 0xDF7E

      # 4. PC = 0xC000
      cpu.registers.pc = instr_address

      # 5. A 初期値(InstrumentationCRC が比較対象にするため固定値)
      cpu.registers.a = 0x00
    end

    # ==========================================================================
    # JR(相対ジャンプ)
    # 3 バイトレイアウト: [opcode, +1, INC A($3C)]
    # 分岐成立 → PC = instr+3(INC A をスキップ)
    # 分岐不成立 → INC A も実行されて PC = instr+3、A=+1
    # ==========================================================================

    context 'JR i8 (0x18) を実行したとき' do
      let(:instr_bytes) { [0x18, 0x01, 0x3C] } # JR *+3 ; INC A

      it 'PC=0xC003, SP/スタックは変化しない、A は INC されない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF7E
        expect(cpu.registers.a).to eq 0x00
        expect(mmu.read_u8(address: 0xDF7E)).to eq 0x03 # 戻り先 low
        expect(mmu.read_u8(address: 0xDF7F)).to eq 0xC0 # 戻り先 high
      end
    end

    context 'JR NZ,i8 (0x20) で Z=0(成立)のとき' do
      let(:instr_bytes) { [0x20, 0x01, 0x3C] }
      before { cpu.registers.zero_flag = 0 }

      it 'PC=0xC003, A は INC されない(分岐成立で INC A をスキップ)' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'JR NZ,i8 (0x20) で Z=1(不成立)のとき' do
      let(:instr_bytes) { [0x20, 0x01, 0x3C] }
      before { cpu.registers.zero_flag = 1 }

      it 'JR を実行しても PC は instr+2、続けて INC A を実行すると PC=0xC003, A=0x01' do
        cpu.step # JR NZ(分岐せず PC = 0xC002)
        expect(cpu.registers.pc).to eq 0xC002
        cpu.step # INC A
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x01
      end
    end

    context 'JR Z,i8 (0x28) で Z=1(成立)のとき' do
      let(:instr_bytes) { [0x28, 0x01, 0x3C] }
      before { cpu.registers.zero_flag = 1 }

      it 'PC=0xC003, A は INC されない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'JR Z,i8 (0x28) で Z=0(不成立)のとき' do
      let(:instr_bytes) { [0x28, 0x01, 0x3C] }
      before { cpu.registers.zero_flag = 0 }

      it '2 step 後 PC=0xC003, A=0x01' do
        2.times { cpu.step }
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x01
      end
    end

    context 'JR NC,i8 (0x30) で C=0(成立)のとき' do
      let(:instr_bytes) { [0x30, 0x01, 0x3C] }
      before { cpu.registers.carry_flag = 0 }

      it 'PC=0xC003, A は INC されない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'JR NC,i8 (0x30) で C=1(不成立)のとき' do
      let(:instr_bytes) { [0x30, 0x01, 0x3C] }
      before { cpu.registers.carry_flag = 1 }

      it '2 step 後 PC=0xC003, A=0x01' do
        2.times { cpu.step }
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x01
      end
    end

    context 'JR C,i8 (0x38) で C=1(成立)のとき' do
      let(:instr_bytes) { [0x38, 0x01, 0x3C] }
      before { cpu.registers.carry_flag = 1 }

      it 'PC=0xC003, A は INC されない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'JR C,i8 (0x38) で C=0(不成立)のとき' do
      let(:instr_bytes) { [0x38, 0x01, 0x3C] }
      before { cpu.registers.carry_flag = 0 }

      it '2 step 後 PC=0xC003, A=0x01' do
        2.times { cpu.step }
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.a).to eq 0x01
      end
    end

    # ==========================================================================
    # JP(絶対ジャンプ)
    # 3 バイトレイアウト: [opcode, low(taken), high(taken)]
    # taken のアドレスを 0xC003(=instr+3 = test_instr のフォールスルー先)とする
    # 成立 / 不成立どちらでも PC=0xC003 になる(SP/A は不変)
    # ==========================================================================

    context 'JP u16 (0xC3) を実行したとき' do
      let(:instr_bytes) { [0xC3, 0x03, 0xC0] } # JP 0xC003

      it 'PC=0xC003, SP/A/スタックは変化しない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF7E
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'JP NZ,u16 (0xC2) で Z=0(成立)のとき' do
      let(:instr_bytes) { [0xC2, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 0 }

      it 'PC=0xC003' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    context 'JP NZ,u16 (0xC2) で Z=1(不成立)のとき' do
      let(:instr_bytes) { [0xC2, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 1 }

      it 'PC=0xC003(オペランド読み込みで自然に instr+3 へ進む)' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    context 'JP Z,u16 (0xCA) で Z=1(成立)のとき' do
      let(:instr_bytes) { [0xCA, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 1 }

      it 'PC=0xC003' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    context 'JP NC,u16 (0xD2) で C=0(成立)のとき' do
      let(:instr_bytes) { [0xD2, 0x03, 0xC0] }
      before { cpu.registers.carry_flag = 0 }

      it 'PC=0xC003' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    context 'JP C,u16 (0xDA) で C=1(成立)のとき' do
      let(:instr_bytes) { [0xDA, 0x03, 0xC0] }
      before { cpu.registers.carry_flag = 1 }

      it 'PC=0xC003' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    # ==========================================================================
    # CALL(コール)
    # 3 バイトレイアウト: [opcode, low(taken), high(taken)]
    # 成立: 戻り先(=instr+3=0xC003)を push、SP-=2、PC=taken(=0xC003)
    # 不成立: 何も push せず、PC は instr+3 へ自然進行(SP 不変)
    # ==========================================================================

    context 'CALL u16 (0xCD) を実行したとき' do
      let(:instr_bytes) { [0xCD, 0x03, 0xC0] } # CALL 0xC003

      it 'PC=0xC003, SP=0xDF7C(2 減る)、新しいスタック top に instr+3 が積まれる' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF7C
        expect(mmu.read_u8(address: 0xDF7D)).to eq 0xC0 # 新たに push した high
        expect(mmu.read_u8(address: 0xDF7C)).to eq 0x03 # 新たに push した low(0x56 sentinel を上書き)
        # フレームワークが先に push した戻り先は 0xDF7E/0xDF7F に残ったまま
        expect(mmu.read_u8(address: 0xDF7E)).to eq 0x03
        expect(mmu.read_u8(address: 0xDF7F)).to eq 0xC0
      end
    end

    context 'CALL NZ,u16 (0xC4) で Z=0(成立)のとき' do
      let(:instr_bytes) { [0xC4, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 0 }

      it 'SP=0xDF7C, スタック top に instr+3 が積まれる' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'CALL NZ,u16 (0xC4) で Z=1(不成立)のとき' do
      let(:instr_bytes) { [0xC4, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 1 }

      it 'SP は不変、push は起きない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF7E
      end
    end

    context 'CALL Z,u16 (0xCC) で Z=1(成立)のとき' do
      let(:instr_bytes) { [0xCC, 0x03, 0xC0] }
      before { cpu.registers.zero_flag = 1 }

      it 'SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'CALL NC,u16 (0xD4) で C=0(成立)のとき' do
      let(:instr_bytes) { [0xD4, 0x03, 0xC0] }
      before { cpu.registers.carry_flag = 0 }

      it 'SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'CALL C,u16 (0xDC) で C=1(成立)のとき' do
      let(:instr_bytes) { [0xDC, 0x03, 0xC0] }
      before { cpu.registers.carry_flag = 1 }

      it 'SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    # ==========================================================================
    # RET / RETI(リターン)
    # 3 バイトレイアウト: [opcode, INC A($3C), 0]
    # 成立: スタック top から戻り先 pop、SP+=2、PC=戻り先(=0xC003)
    # 不成立: pop せず、PC は instr+1 へ進む → 続けて INC A 実行
    # ==========================================================================

    context 'RET (0xC9) を実行したとき' do
      let(:instr_bytes) { [0xC9, 0x3C, 0x00] }

      it 'PC=0xC003(戻り先 pop)、SP=0xDF80(2 増える)' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
      end
    end

    context 'RET NZ (0xC0) で Z=0(成立)のとき' do
      let(:instr_bytes) { [0xC0, 0x3C, 0x00] }
      before { cpu.registers.zero_flag = 0 }

      it 'PC=0xC003, SP=0xDF80, A は INC されない' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
        expect(cpu.registers.a).to eq 0x00
      end
    end

    context 'RET NZ (0xC0) で Z=1(不成立)のとき' do
      let(:instr_bytes) { [0xC0, 0x3C, 0x00] }
      before { cpu.registers.zero_flag = 1 }

      it 'pop しないので SP=0xDF7E のまま、続けて INC A 実行で A=0x01' do
        cpu.step # RET NZ(不成立)
        expect(cpu.registers.sp).to eq 0xDF7E
        expect(cpu.registers.pc).to eq 0xC001
        cpu.step # INC A
        expect(cpu.registers.a).to eq 0x01
      end
    end

    context 'RET Z (0xC8) で Z=1(成立)のとき' do
      let(:instr_bytes) { [0xC8, 0x3C, 0x00] }
      before { cpu.registers.zero_flag = 1 }

      it 'PC=0xC003, SP=0xDF80' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
      end
    end

    context 'RET NC (0xD0) で C=0(成立)のとき' do
      let(:instr_bytes) { [0xD0, 0x3C, 0x00] }
      before { cpu.registers.carry_flag = 0 }

      it 'PC=0xC003, SP=0xDF80' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
      end
    end

    context 'RET C (0xD8) で C=1(成立)のとき' do
      let(:instr_bytes) { [0xD8, 0x3C, 0x00] }
      before { cpu.registers.carry_flag = 1 }

      it 'PC=0xC003, SP=0xDF80' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
      end
    end

    context 'RETI (0xD9) を実行したとき' do
      let(:instr_bytes) { [0xD9, 0x3C, 0x00] }
      before { cpu.ime = false }

      it 'PC=0xC003, SP=0xDF80, IME=true(EI と違い遅延なしで即時 1)' do
        cpu.step
        expect(cpu.registers.pc).to eq 0xC003
        expect(cpu.registers.sp).to eq 0xDF80
        expect(cpu.ime).to eq true
      end
    end

    # ==========================================================================
    # RST(リセット)
    # 1 バイト命令: 現在の PC を push して固定ベクタ(0x00, 0x08, ..., 0x38)へ jump
    # SP-=2、新しいスタック top = instr+1(RST の次バイト)
    # ==========================================================================

    context 'RST $00 (0xC7) を実行したとき' do
      let(:instr_bytes) { [0xC7, 0x00, 0x00] }

      it 'PC=0x0000, SP=0xDF7C, スタック top に instr+1=0xC001 が push される' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0000
        expect(cpu.registers.sp).to eq 0xDF7C
        expect(mmu.read_u8(address: 0xDF7D)).to eq 0xC0
        expect(mmu.read_u8(address: 0xDF7C)).to eq 0x01
      end
    end

    context 'RST $08 (0xCF) を実行したとき' do
      let(:instr_bytes) { [0xCF, 0x00, 0x00] }

      it 'PC=0x0008, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0008
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $10 (0xD7) を実行したとき' do
      let(:instr_bytes) { [0xD7, 0x00, 0x00] }

      it 'PC=0x0010, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0010
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $18 (0xDF) を実行したとき' do
      let(:instr_bytes) { [0xDF, 0x00, 0x00] }

      it 'PC=0x0018, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0018
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $20 (0xE7) を実行したとき' do
      let(:instr_bytes) { [0xE7, 0x00, 0x00] }

      it 'PC=0x0020, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0020
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $28 (0xEF) を実行したとき' do
      let(:instr_bytes) { [0xEF, 0x00, 0x00] }

      it 'PC=0x0028, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0028
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $30 (0xF7) を実行したとき' do
      let(:instr_bytes) { [0xF7, 0x00, 0x00] }

      it 'PC=0x0030, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0030
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end

    context 'RST $38 (0xFF) を実行したとき' do
      let(:instr_bytes) { [0xFF, 0x00, 0x00] }

      it 'PC=0x0038, SP=0xDF7C' do
        cpu.step
        expect(cpu.registers.pc).to eq 0x0038
        expect(cpu.registers.sp).to eq 0xDF7C
      end
    end
  end
end
