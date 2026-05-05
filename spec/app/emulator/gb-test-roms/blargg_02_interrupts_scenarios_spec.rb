require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'

# Blargg cpu_instrs/02-interrupts.gb 相当のシナリオテスト
#
# 元 ROM(retrio/gb-test-roms cpu_instrs/source/02-interrupts.s)が検証するのは
# 4 つの個別テスト:
#
#   Test 2: EI                  - EI 後 IF & IE で割り込みベクタへ自動 dispatch
#   Test 3: DI                  - DI 中は IF が立っても dispatch されない
#   Test 4: Timer doesn't work  - TAC を有効にすると TIMA が増えて IF bit2 が立つ
#   Test 5: HALT                - HALT 中も Timer 割り込みで起き上がる
#
# 現状の GEM BOY 実装:
#   - DI / EI: IME フラグの即時操作のみ(EI の 1 命令遅延仕様は未対応)
#   - 割り込み dispatch(IF & IE → ベクタ jump): **未実装**
#   - Timer (DIV / TIMA / TMA / TAC): **未実装**
#   - HALT 解除条件: 簡易実装のみ
#
# したがって Test 2〜5 は実装が揃うまで pending(skip)になる。動く部分(IME/HALT
# の状態遷移、IF/IE レジスタ I/O)だけ通常の it として書き、dispatch / Timer 系は
# pending としてマークする。実装が進んだら pending を外して assertion を有効化する。
#
# Pan Docs:
#   - 割り込み: https://gbdev.io/pandocs/Interrupts.html
#   - HALT:     https://gbdev.io/pandocs/halt.html
#   - Timer:    https://gbdev.io/pandocs/Timer_and_Divider_Registers.html
RSpec.describe 'Blargg cpu_instrs/02-interrupts.gb 相当のシナリオテスト' do
  context '02-interrupts.gb を実行したとき' do
    instr_address = 0xC000
    if_address = 0xFF0F
    ie_address = 0xFFFF
    timer_vector = 0x0050

    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: true) }
    let(:rom_data) { Array.new(0x8000, 0) }
    let(:instr_bytes) { [] }

    before do
      instr_bytes.each_with_index { |byte, i| mmu.write_u8(address: instr_address + i, value: byte) }
      cpu.registers.pc = instr_address
    end

    # ==========================================================================
    # Test 2: EI
    # 元コード:
    #   wreg IE,$04         ; Timer 割り込みのみ有効
    #   ei                  ; IME=1(本来は 1 命令遅延)
    #   ld bc,0
    #   push bc
    #   pop bc
    #   inc b
    #   wreg IF,$04         ; Timer 割り込み発火 → ベクタ 0x50 へ jump
    # interrupt_addr:
    #   dec b               ; ISR 復帰後の最初の命令
    # 期待: ISR(.org $50: inc a; ret)が実行される / IF bit 2 がクリア /
    #       スタックに interrupt_addr が積まれる
    # ==========================================================================

    context 'EI で IME を立てる' do
      let(:instr_bytes) { [0xFB] } # EI

      it 'IME=true になる' do
        cpu.step
        expect(cpu.ime).to eq true
      end

      # 注: 本来は 1 命令遅延仕様だが、現状の実装は即時 EI なので
      # 「EI 直後に IME=true」を確認するに留める
      it 'EI の 1 命令遅延仕様は未対応(現状は即時 IME=1)' do
        skip 'EI の 1 命令遅延仕様(ime_pending → 次命令後に反映)が未実装'
      end
    end

    context 'IF & IE & 0x1F が真かつ IME=1 のとき割り込み dispatch される(Test 2)' do
      it 'IE=0x04 (Timer)、IF=0x04 をセットして次の step で 0x50 にジャンプし、IF bit 2 がクリアされる' do
        skip '割り込みベクタへの自動 dispatch が未実装(IF/IE → push PC → vector jump → IME=0)'

        # 期待される実装の挙動:
        # mmu.write_u8(address: ie_address, value: 0x04)
        # mmu.write_u8(address: if_address, value: 0x04)
        # cpu.ime = true
        # cpu.registers.sp = 0xDFFE
        # cpu.registers.pc = 0xC100
        # cpu.step
        # expect(cpu.registers.pc).to eq timer_vector
        # expect(cpu.ime).to eq false
        # expect(mmu.read_u8(address: if_address) & 0x04).to eq 0
        # expect(cpu.registers.sp).to eq 0xDFFC
        # expect(mmu.read_u8(address: 0xDFFD)).to eq 0xC1 # 戻り先 high
        # expect(mmu.read_u8(address: 0xDFFC)).to eq 0x00 # 戻り先 low
      end
    end

    # ==========================================================================
    # Test 3: DI
    # 元コード:
    #   di
    #   ld bc,0
    #   push bc
    #   pop bc
    #   wreg IF,$04         ; IF bit 2 を立てるだけ。dispatch は起きないはず
    # 期待: IME=0 のため IF が立っても割り込みは発生しない / IF bit 2 はそのまま立つ
    # ==========================================================================

    context 'DI で IME をクリア' do
      let(:instr_bytes) { [0xF3] } # DI
      before { cpu.ime = true }

      it 'IME=false になる' do
        cpu.step
        expect(cpu.ime).to eq false
      end
    end

    context 'IME=0 のとき IF が立っても dispatch されない(Test 3)' do
      it 'IE=0x04, IF=0x04 でも PC は変化せず、IF bit 2 は立ったまま' do
        cpu.ime = false
        mmu.write_u8(address: ie_address, value: 0x04)
        mmu.write_u8(address: if_address, value: 0x04)
        cpu.registers.pc = 0xC100
        original_pc = cpu.registers.pc

        # NOP を実行してもベクタへ飛ばないことを確認(現状でも動くはず:
        # IME=0 なら dispatch されないので)
        mmu.write_u8(address: 0xC100, value: 0x00) # NOP
        cpu.step

        expect(cpu.registers.pc).to eq original_pc + 1 # NOP 1 byte 進むだけ
        expect(mmu.read_u8(address: if_address) & 0x04).to eq 0x04 # IF bit 2 はクリアされない
      end
    end

    # ==========================================================================
    # Test 4: Timer doesn't work / works
    # 元コード:
    #   wreg TAC,$05        ; Timer enable + 262144 Hz
    #   wreg TIMA,0
    #   wreg IF,0
    #   delay 500
    #   lda IF
    #   delay 500
    #   and $04
    #   jp nz,test_failed   ; 500 サイクルでは IF bit 2 はまだ立たない
    #   delay 500
    #   lda IF
    #   and $04
    #   jp z,test_failed    ; さらに時間が経てば IF bit 2 が立つ
    # 期待: TIMA がオーバーフローしたら IF bit 2 が立つ
    # ==========================================================================

    context 'Timer 割り込み(Test 4)' do
      it 'TAC=0x05、TIMA=0xFF を超えると IF bit 2 (Timer) が立つ' do
        skip 'Timer (DIV / TIMA / TMA / TAC) と IF bit 2 の自動セットが未実装'

        # 期待される実装の挙動:
        # mmu.write_u8(address: 0xFF07, value: 0x05) # TAC: enable + 262144 Hz
        # mmu.write_u8(address: 0xFF05, value: 0xFF) # TIMA: 次の tick でオーバーフロー
        # mmu.write_u8(address: if_address, value: 0x00)
        # cpu.run(cycles_for_one_tima_tick) # 16 cycles 程度
        # expect(mmu.read_u8(address: if_address) & 0x04).to eq 0x04
        # expect(mmu.read_u8(address: 0xFF05)).to eq mmu.read_u8(address: 0xFF06) # TMA が再ロードされる
      end
    end

    # ==========================================================================
    # Test 5: HALT
    # 元コード:
    #   wreg TAC,$05
    #   wreg TIMA,0
    #   wreg IF,0
    #   halt                ; Timer 割り込みで HALT を抜ける
    #   nop                 ; DMG bug 回避
    #   lda IF
    #   and $04             ; IF bit 2 が立っていれば成功
    # 期待: HALT 中に Timer 割り込みが発生したら復帰する
    # ==========================================================================

    context 'HALT 命令で halted 状態になる' do
      let(:instr_bytes) { [0x76] } # HALT

      it 'halted=true' do
        cpu.step
        expect(cpu.halted).to eq true
      end

      it 'halted 中の step は 4 cycles 消費するだけで PC は進まない' do
        cpu.step # HALT 実行 → halted=true
        pc_before = cpu.registers.pc
        cycles = cpu.step
        expect(cycles).to eq 4
        expect(cpu.registers.pc).to eq pc_before
      end
    end

    context 'HALT 中に IF & IE が真になったとき(Test 5)' do
      it 'halted=false に戻り、IME=1 ならベクタへ dispatch、IME=0 なら次の命令から再開' do
        skip 'HALT 解除条件(IF & IE != 0)と dispatch / 非 dispatch の分岐が未実装'

        # 期待される実装の挙動:
        # IME=1 のケース:
        #   cpu.ime = true; cpu.halted = true
        #   mmu.write_u8(address: ie_address, value: 0x04)
        #   mmu.write_u8(address: if_address, value: 0x04)
        #   cpu.step
        #   expect(cpu.halted).to eq false
        #   expect(cpu.registers.pc).to eq timer_vector
        #
        # IME=0 のケース(HALT bug を避けて):
        #   cpu.ime = false; cpu.halted = true
        #   mmu.write_u8(address: ie_address, value: 0x04)
        #   mmu.write_u8(address: if_address, value: 0x04)
        #   cpu.step
        #   expect(cpu.halted).to eq false
        #   expect(cpu.registers.pc).to eq pc_before + 1 # HALT の次から再開
      end
    end

    # ==========================================================================
    # 0xFF0F (IF) と 0xFFFF (IE) の I/O 直接アクセス
    # ==========================================================================

    context 'IF (0xFF0F) と IE (0xFFFF) を MMU 経由で読み書きしたとき' do
      it '書いた値が読める' do
        mmu.write_u8(address: if_address, value: 0x1F)
        mmu.write_u8(address: ie_address, value: 0x1F)
        # IF の上位 3bit は常に 1 になる仕様だが、現状実装はそのまま保持しているはず
        expect(mmu.read_u8(address: if_address) & 0x1F).to eq 0x1F
        expect(mmu.read_u8(address: ie_address) & 0x1F).to eq 0x1F
      end
    end
  end
end
