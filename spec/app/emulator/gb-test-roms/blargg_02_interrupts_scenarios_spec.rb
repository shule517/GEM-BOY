require 'app/emulator/cartridge'
require 'app/emulator/mmu'
require 'app/emulator/cpu'
require 'app/emulator/ppu'

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
# Pan Docs:
#   - 割り込み: https://gbdev.io/pandocs/Interrupts.html
#   - HALT:     https://gbdev.io/pandocs/halt.html
#   - Timer:    https://gbdev.io/pandocs/Timer_and_Divider_Registers.html
RSpec.describe 'Blargg cpu_instrs/02-interrupts.gb 相当のシナリオテスト' do
  context '02-interrupts.gb を実行したとき' do
    instr_address = 0xC000
    timer_vector = 0x0050

    let(:cpu) { CPU.new(mmu, skip_boot: true, trace: false) } # 初期 SP=0xFFFE 等を取りたいので post-boot 状態で起動
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

    context 'EI を実行した直後(1命令遅延仕様)' do
      let(:instr_bytes) { [CPU::EI] }
      before { cpu.ime = false }

      it 'IME はまだ反映されない' do
        cpu.step
        expect(cpu.ime).to eq false
      end

      it 'ime_scheduled で IME の有効化が予約される' do
        cpu.step
        expect(cpu.ime_scheduled).to eq true
      end
    end

    context 'EI の次の命令を実行した後' do
      let(:instr_bytes) { [CPU::EI, CPU::NOP] }
      before { cpu.ime = false }

      it 'IME が有効になる' do
        cpu.step # EI
        cpu.step # NOP
        expect(cpu.ime).to eq true
      end

      it 'ime_scheduled が解除される' do
        cpu.step # EI
        cpu.step # NOP
        expect(cpu.ime_scheduled).to eq false
      end
    end

    context 'IE と IF が立ち IME=1 のとき割り込み dispatch される(Test 2)' do
      let(:instr_bytes) { [CPU::NOP] } # dispatch されなければ実行されるフォールバック命令

      before do
        # https://gbdev.io/pandocs/Interrupts.html#interrupt-handling
        mmu.interrupt_enable.timer = true # Timerの割り込みを有効にした
        mmu.interrupt_flag.timer = true # Timerの割り込みが発生した
        cpu.ime = true
      end

      it 'ベクタ 0x50 へ jump する' do
        cpu.step
        expect(cpu.registers.pc).to eq timer_vector
      end

      it 'IME がクリアされる' do
        cpu.step
        expect(cpu.ime).to eq false
      end

      it 'dispatch で Timer flag が自動クリアされる' do
        cpu.step
        expect(mmu.interrupt_flag.timer?).to eq false
      end

      it '2バイト push で SP が 2 減る' do
        initial_sp = cpu.registers.sp
        cpu.step
        expect(cpu.registers.sp).to eq initial_sp - 2
      end

      it '戻り先アドレス(instr_address=0xC000)が SP に積まれる' do
        initial_sp = cpu.registers.sp
        cpu.step
        expect(mmu.read_u8(address: initial_sp - 1)).to eq 0xC0 # 戻り先 high
        expect(mmu.read_u8(address: initial_sp - 2)).to eq 0x01 # 戻り先 low
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
      let(:instr_bytes) { [CPU::DI] }
      before { cpu.ime = true }

      it 'IME=false になる' do
        cpu.step
        expect(cpu.ime).to eq false
      end
    end

    context 'IME=0 のとき IF が立っても dispatch されない(Test 3)' do
      let(:instr_bytes) { [CPU::NOP] } # IME=0 なら dispatch されないのでこれがそのまま実行される

      before do
        cpu.ime = false
        mmu.interrupt_enable.timer = true # Timerの割り込みを有効にした
        mmu.interrupt_flag.timer = true # Timerの割り込みが発生した
      end

      it 'NOP がそのまま実行されて PC が 1 進む' do
        cpu.step
        expect(cpu.registers.pc).to eq instr_address + 1
      end

      it 'IME=0 では dispatch しないので Timer flag は保持される' do
        cpu.step
        expect(mmu.interrupt_flag.timer?).to eq true
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
      # NOP を 5 個 (20 T-cycles) 並べる: 16 T-cycles 目で overflow、+1 M-cycle (4 T-cycles) で TMA を TIMA に reload
      let(:instr_bytes) { Array.new(5, CPU::NOP) }
      let(:tma_reload_value) { 0b01000010 } # オーバーフロー時に TIMA に再ロードされる任意の値(0x42)

      before do
        # Pan Docs: https://gbdev.io/pandocs/Timer_and_Divider_Registers.html
        # TAC bit2=enable / bits1-0=rate, rate 01 = 262144 Hz = 4194304 Hz CPU / 16 → 16 T-cycles ごとに TIMA が +1
        mmu.write_u8(address: MMU::TAC,  value: 0b00000101) # TAC: bit2=enable + bits1-0=01 (rate 01 = 16 T-cycles per TIMA tick)
        mmu.write_u8(address: MMU::TIMA, value: 0b11111111) # TIMA: 次の tick でオーバーフロー (0xFF)
        mmu.write_u8(address: MMU::TMA,  value: tma_reload_value)
        mmu.interrupt_flag.timer = false # Timer overflow で Timer flag が立つことを検証するため事前にクリア
      end

      it 'TIMA overflow により Timer 割り込みが立つ' do
        cpu.run(20)
        expect(mmu.interrupt_flag.timer?).to eq true
      end

      it 'TMA が TIMA へ再ロードされる' do
        cpu.run(20)
        expect(mmu.read_u8(address: MMU::TIMA)).to eq tma_reload_value
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

    context 'HALT 命令を実行したとき' do
      let(:instr_bytes) { [CPU::HALT] }

      it 'halted=true になる' do
        cpu.step
        expect(cpu.halted).to eq true
      end
    end

    context 'halted 状態で step したとき' do
      let(:instr_bytes) { [CPU::HALT] }
      before { cpu.step } # HALT 実行 → halted=true

      it '4 cycles 消費する' do
        cycles = cpu.step
        expect(cycles).to eq 4
      end

      it 'PC は進まない' do
        pc_before = cpu.registers.pc
        cpu.step
        expect(cpu.registers.pc).to eq pc_before
      end
    end

    context 'HALT 中に Timer 割り込みが発火したとき(Test 5、IME=1)' do
      before do
        cpu.ime = true
        cpu.halted = true
        mmu.interrupt_enable.timer = true # Timerの割り込みを有効にした
        mmu.interrupt_flag.timer = true # Timerの割り込みが発生した
      end

      it 'halted=false に戻る' do
        cpu.step
        expect(cpu.halted).to eq false
      end

      it 'ベクタ 0x50 へ dispatch される' do
        cpu.step
        expect(cpu.registers.pc).to eq timer_vector
      end
    end

    context 'HALT 中に Timer 割り込みが発火したとき(Test 5、IME=0)' do
      let(:instr_bytes) { [CPU::NOP] } # HALT 復帰後に踏まれる NOP

      before do
        cpu.ime = false
        cpu.halted = true
        mmu.interrupt_enable.timer = true # Timerの割り込みを有効にした
        mmu.interrupt_flag.timer = true # Timerの割り込みが発生した
      end

      it 'halted=false に戻る' do
        cpu.step
        expect(cpu.halted).to eq false
      end

      it 'HALT の次の命令(NOP)から再開する(dispatch されない)' do
        cpu.step
        expect(cpu.registers.pc).to eq instr_address + 1
      end
    end

    # ==========================================================================
    # IF (0xFF0F) の各 bit を interrupt_flag 経由で読み書き
    # Pan Docs: https://gbdev.io/pandocs/Interrupts.html#ff0f--if-interrupt-flag
    # ==========================================================================

    context 'interrupt_flag の 5 つのフラグをすべて true にしたとき' do
      before do
        mmu.interrupt_flag.v_blank = true
        mmu.interrupt_flag.lcd     = true
        mmu.interrupt_flag.timer   = true
        mmu.interrupt_flag.serial  = true
        mmu.interrupt_flag.joypad  = true
      end

      it 'v_blank? が true として読める' do
        expect(mmu.interrupt_flag.v_blank?).to eq true
      end

      it 'lcd? が true として読める' do
        expect(mmu.interrupt_flag.lcd?).to eq true
      end

      it 'timer? が true として読める' do
        expect(mmu.interrupt_flag.timer?).to eq true
      end

      it 'serial? が true として読める' do
        expect(mmu.interrupt_flag.serial?).to eq true
      end

      it 'joypad? が true として読める' do
        expect(mmu.interrupt_flag.joypad?).to eq true
      end
    end
  end
end
