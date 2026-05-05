require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/01-special.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/01-special.s)が検証する
# 「テンプレートに収まらない」5 つの個別テスト:
#
#   Test 2: JR negative   - JR で後方ジャンプして所定の INC A を踏む
#   Test 3: JR positive   - JR で前方ジャンプして所定の INC A を踏む
#   Test 4: LD PC,HL      - JP HL(0xE9): HL の値に直接 jump
#   Test 5: POP AF        - F の下位 4bit が常に 0 にマスクされる
#   Test 6: DAA           - 256 値 × 16 フラグ組み合わせを CRC で検証
#
# RSpec では各サブテストを 1〜数ケースで検証する。Test 6 の DAA は全網羅は
# 非現実的なので、ADD/SUB それぞれの代表入力で挙動を確認する。
RSpec.describe 'Blargg cpu_instrs/01-special.gb 相当のシナリオテスト' do
  context '01-special.gb を実行したとき' do
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
    # Test 2: JR negative
    # 元コード:
    #   ld a,0
    #   jp jr_neg
    #   inc a       ; INC A1
    # -:inc a       ; INC A2(到達時にここから始まる)
    #   inc a       ; INC A3
    #   cp 2
    #   jp nz,test_failed
    #   jp +
    # jr_neg:
    #   jr -        ; 後方 JR で - ラベルへ
    # +
    # 期待: A=2(INC A2 と INC A3 の 2 回だけ実行される)
    # ==========================================================================

    context 'JR negative の挙動を再現したとき' do
      # 配置:
      #   0xC000: 0x3C        ; INC A1(jr_neg からの jr - で飛び越される)
      #   0xC001: 0x3C        ; INC A2(- ラベル)
      #   0xC002: 0x3C        ; INC A3
      #   0xC003: 0x18 0x02   ; JR +5(test_failed をスキップして + へ)
      #   0xC005: ...         ; test_failed 想定
      #   0xC006: 0x18 0xF9   ; JR -7(jr_neg → 0xC001 へ後方ジャンプ)
      let(:instr_bytes) { [0x3C, 0x3C, 0x3C, 0x18, 0x02, 0x00, 0x18, 0xF9] }

      before do
        cpu.registers.a = 0x00
        cpu.registers.pc = 0xC006 # jr_neg からスタート
      end

      it 'JR -7 で 0xC001 に戻り、INC A を 2 回実行して A=0x02 になる' do
        # JR -7 → PC=0xC001(0xC008 - 7)
        cpu.step
        expect(cpu.registers.pc).to eq 0xC001
        # INC A → A=1, PC=0xC002
        cpu.step
        # INC A → A=2, PC=0xC003
        cpu.step
        expect(cpu.registers.a).to eq 0x02
        expect(cpu.registers.pc).to eq 0xC003
      end
    end

    # ==========================================================================
    # Test 3: JR positive
    # 元コード:
    #   ld a,0
    #   jr +        ; 前方 JR で + ラベルへ
    #   inc a       ; INC A1(飛び越される)
    # +:inc a       ; INC A2(到達時にここから始まる)
    #   inc a       ; INC A3
    #   cp 2
    # 期待: A=2
    # ==========================================================================

    context 'JR positive の挙動を再現したとき' do
      # 配置:
      #   0xC000: 0x18 0x01   ; JR +1(INC A1 をスキップ)
      #   0xC002: 0x3C        ; INC A1
      #   0xC003: 0x3C        ; INC A2(到達点)
      #   0xC004: 0x3C        ; INC A3
      let(:instr_bytes) { [0x18, 0x01, 0x3C, 0x3C, 0x3C] }
      before { cpu.registers.a = 0x00 }

      it 'JR +1 で INC A1 をスキップ、INC A を 2 回実行して A=0x02 になる' do
        cpu.step # JR +1: PC = 0xC002 + 1 = 0xC003
        expect(cpu.registers.pc).to eq 0xC003
        cpu.step # INC A2: A=1, PC=0xC004
        cpu.step # INC A3: A=2, PC=0xC005
        expect(cpu.registers.a).to eq 0x02
        expect(cpu.registers.pc).to eq 0xC005
      end
    end

    # ==========================================================================
    # Test 4: LD PC,HL = JP HL (0xE9)
    # 元コード:
    #   ld hl,+
    #   ld a,0
    #   ld pc,hl    ; (実際のアセンブラでは JP HL として展開される)
    #   inc a       ; INC A1(飛び越される)
    # +:inc a       ; INC A2
    #   inc a       ; INC A3
    # 期待: A=2
    # ==========================================================================

    context 'JP HL (0xE9) で前方の INC A をスキップしたとき' do
      # 配置:
      #   0xC000: 0xE9        ; JP HL(HL=0xC002 にセット済み、INC A1 をスキップ)
      #   0xC001: 0x3C        ; INC A1(飛び越される)
      #   0xC002: 0x3C        ; INC A2(到達点)
      #   0xC003: 0x3C        ; INC A3
      let(:instr_bytes) { [0xE9, 0x3C, 0x3C, 0x3C] }
      before do
        cpu.registers.hl = 0xC002
        cpu.registers.a = 0x00
      end

      it 'PC=HL=0xC002 へ jump し、INC A を 2 回実行して A=0x02 になる' do
        cpu.step # JP HL → PC=0xC002
        expect(cpu.registers.pc).to eq 0xC002
        cpu.step # INC A2
        cpu.step # INC A3
        expect(cpu.registers.a).to eq 0x02
      end
    end

    # ==========================================================================
    # Test 5: POP AF
    # 元コード(BC を 0x1200 から 0x12FF まで回す):
    #   push bc
    #   pop af
    #   push af
    #   pop de
    #   ld a,c
    #   and $F0     ; F の下位 4bit を期待値からも消す
    #   cp e
    #   jp nz,test_failed
    # 期待: PUSH/POP AF で F の下位 4bit は常に 0 にマスクされる
    # ==========================================================================

    context 'PUSH BC → POP AF → PUSH AF → POP DE で F の下位 4bit がマスクされるか' do
      # POP AF / PUSH AF のラウンドトリップで F の下位 4bit が 0 になることを確認
      let(:instr_bytes) do
        [
          0xC5,       # PUSH BC: SP=0xDFFE → 0xDFFC、(0xDFFD)=B, (0xDFFC)=C
          0xF1,       # POP AF: A=B, F=C(F の下位 4bit はマスクされる)
          0xF5,       # PUSH AF: SP=0xDFFC → 0xDFFA
          0xD1        # POP DE: D=A, E=F
        ]
      end
      before do
        cpu.registers.sp = 0xDFFE
        cpu.registers.bc = 0x12FF # B=0x12, C=0xFF(F として使うと下位 4bit が立つ)
      end

      it 'POP AF で F の下位 4bit が 0xF→0 にマスクされ、E=0xF0 で取り出せる' do
        4.times { cpu.step }
        expect(cpu.registers.d).to eq 0x12 # A 経由で B の値が D へ
        expect(cpu.registers.e).to eq 0xF0 # F 経由で C の上位 4bit のみが E へ
      end
    end

    # ==========================================================================
    # Test 6: DAA
    # 元コード: 256 値 × 16 フラグの全網羅を CRC で照合する。
    # RSpec では仕様(https://rgbds.gbdev.io/docs/v1.0.1/gbz80.7#DAA)に基づく
    # 代表入力で検証する。
    # ==========================================================================

    context 'DAA で ADD 後の補正を再現したとき' do
      let(:instr_bytes) { [0x27] }

      context 'A=0x0A, N=0, H=0, C=0(下位ニブル > 9)のとき' do
        before do
          cpu.registers.a = 0x0A
          cpu.registers.negative_flag = 0
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 0
        end

        it 'A=0x10 に補正(+0x06)、C=0' do
          cpu.step
          expect(cpu.registers.a).to eq 0x10
          expect(cpu.registers.carry_flag).to eq 0
        end
      end

      context 'A=0xA0, N=0, H=0, C=0(高位ニブル > 9)のとき' do
        before do
          cpu.registers.a = 0xA0
          cpu.registers.negative_flag = 0
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 0
        end

        it 'A=0x00 に補正(+0x60)、C=1' do
          cpu.step
          expect(cpu.registers.a).to eq 0x00
          expect(cpu.registers.zero_flag).to eq 1
          expect(cpu.registers.carry_flag).to eq 1
        end
      end

      context 'A=0x9A, N=0, H=0, C=0(両方の補正)のとき' do
        before do
          cpu.registers.a = 0x9A
          cpu.registers.negative_flag = 0
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 0
        end

        it 'A=0x00、Z=1、C=1' do
          cpu.step
          expect(cpu.registers.a).to eq 0x00
          expect(cpu.registers.zero_flag).to eq 1
          expect(cpu.registers.carry_flag).to eq 1
        end
      end

      context 'A=0x00, N=0, H=1, C=0(直前の ADD で半キャリー発生)のとき' do
        before do
          cpu.registers.a = 0x00
          cpu.registers.negative_flag = 0
          cpu.registers.half_carry_flag = 1
          cpu.registers.carry_flag = 0
        end

        it 'A=0x06(+0x06 補正)' do
          cpu.step
          expect(cpu.registers.a).to eq 0x06
        end
      end

      context 'A=0x00, N=0, H=0, C=1(直前の ADD でキャリー発生)のとき' do
        before do
          cpu.registers.a = 0x00
          cpu.registers.negative_flag = 0
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 1
        end

        it 'A=0x60(+0x60 補正)、C=1 維持' do
          cpu.step
          expect(cpu.registers.a).to eq 0x60
          expect(cpu.registers.carry_flag).to eq 1
        end
      end
    end

    context 'DAA で SUB 後の補正を再現したとき' do
      let(:instr_bytes) { [0x27] }

      context 'A=0xFA, N=1, H=1, C=0(下位ニブル借り)のとき' do
        before do
          cpu.registers.a = 0xFA
          cpu.registers.negative_flag = 1
          cpu.registers.half_carry_flag = 1
          cpu.registers.carry_flag = 0
        end

        it 'A=0xF4(-0x06 補正)' do
          cpu.step
          expect(cpu.registers.a).to eq 0xF4
        end
      end

      context 'A=0x9A, N=1, H=0, C=1(高位ニブル借り)のとき' do
        before do
          cpu.registers.a = 0x9A
          cpu.registers.negative_flag = 1
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 1
        end

        it 'A=0x3A(-0x60 補正)' do
          cpu.step
          expect(cpu.registers.a).to eq 0x3A
        end
      end

      context 'A=0x00, N=1 のとき(補正なし)' do
        before do
          cpu.registers.a = 0x00
          cpu.registers.negative_flag = 1
          cpu.registers.half_carry_flag = 0
          cpu.registers.carry_flag = 0
        end

        it 'A=0x00 のまま、Z=1、N は保持、H=0' do
          cpu.step
          expect(cpu.registers.a).to eq 0x00
          expect(cpu.registers.zero_flag).to eq 1
          expect(cpu.registers.negative_flag).to eq 1
          expect(cpu.registers.half_carry_flag).to eq 0
        end
      end
    end

    context 'DAA 実行後、H フラグは常に 0 にクリアされる' do
      let(:instr_bytes) { [0x27] }
      before do
        cpu.registers.a = 0x00
        cpu.registers.half_carry_flag = 1
        cpu.registers.negative_flag = 0
        cpu.registers.carry_flag = 0
      end

      it 'H=0(DAA は半キャリーを使い切ってクリア)' do
        cpu.step
        expect(cpu.registers.half_carry_flag).to eq 0
      end
    end
  end
end
