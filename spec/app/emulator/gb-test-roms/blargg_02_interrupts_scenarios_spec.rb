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

    let(:cpu) { CPU.new(mmu, skip_boot: false, trace: false) }
    let(:mmu) { MMU.new(Cartridge.new(rom_data), skip_boot: false) }
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
      let(:instr_bytes) { [CPU::EI, CPU::NOP] }
      before { cpu.ime = false }

      it 'EI の 1 命令遅延仕様: EI 直後の 1 命令を実行した後に IME=1 になる' do
        cpu.step # EI を実行
        expect(cpu.ime).to eq false # 遅延するのでまだ反映されない
        expect(cpu.ime_scheduled).to eq true # imeの有効が予約される

        cpu.step # NOP を実行
        expect(cpu.ime).to eq true # 遅延してここで有効になる
        expect(cpu.ime_scheduled).to eq false # 完了
      end
    end

    context 'IF & IE & 0x1F が真かつ IME=1 のとき割り込み dispatch される(Test 2)' do
      it 'IE=0x04 (Timer)、IF=0x04 をセットして次の step で 0x50 にジャンプし、IF bit 2 がクリアされる' do
        # https://gbdev.io/pandocs/Interrupts.html#interrupt-handling
        mmu.write_u8(address: MMU::IE, value: 0b00000100) # TimerフラグをON
        mmu.write_u8(address: MMU::IF, value: 0b00000100) # TimerフラグをON
        cpu.ime = true
        cpu.registers.sp = 0xDFFE # SP を WRAM 末尾に置き、dispatch で PC が push される先を検証可能な領域(0xDFFC/DFFD)に固定する
        cpu.registers.pc = 0xC100 # 割り込み発生時に stack へ push される「戻り先 PC」を既知の値にして、push されたバイトを後段で確認できるようにする
        mmu.write_u8(address: 0xC100, value: CPU::NOP) # dispatch されなければこれが実行される

        cpu.step

        expect(cpu.registers.pc).to eq timer_vector # 0x50 へ jump
        expect(cpu.ime).to eq false                  # IME クリア
        expect(mmu.read_u8(address: MMU::IF) & 0b00000100).to eq 0 # IF bit 2 クリア
        expect(cpu.registers.sp).to eq 0xDFFC        # 2 バイト push
        expect(mmu.read_u8(address: 0xDFFD)).to eq 0xC1 # 戻り先 high
        expect(mmu.read_u8(address: 0xDFFC)).to eq 0x00 # 戻り先 low
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
      it 'IE=0x04, IF=0x04 でも PC は変化せず、IF bit 2 は立ったまま' do
        cpu.ime = false
        mmu.write_u8(address: MMU::IE, value: 0b00000100) # TimerフラグをON
        mmu.write_u8(address: MMU::IF, value: 0b00000100) # TimerフラグをON
        cpu.registers.pc = 0xC100
        original_pc = cpu.registers.pc

        # IME=0 なら dispatch されないので NOP がそのまま実行される
        mmu.write_u8(address: 0xC100, value: CPU::NOP)
        cpu.step

        expect(cpu.registers.pc).to eq original_pc + 1 # NOP 1 byte 進むだけ
        expect(mmu.read_u8(address: MMU::IF) & 0b00000100).to eq 0b00000100 # IF bit 2 はクリアされない
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
      it 'TIMA=0xFF からオーバーフローすると IF bit 2 (Timer) が立ち、TIMA に TMA が再ロードされる' do
        # Pan Docs: https://gbdev.io/pandocs/Timer_and_Divider_Registers.html
        # TAC bit2=enable / bits1-0=rate, rate 01 = 262144 Hz = 4194304 Hz CPU / 16 → 16 T-cycles ごとに TIMA が +1
        mmu.write_u8(address: MMU::TAC,  value: 0b00000101) # TAC: bit2=enable + bits1-0=01 (rate 01 = 16 T-cycles per TIMA tick)
        mmu.write_u8(address: MMU::TIMA, value: 0xFF) # TIMA: 次の tick でオーバーフロー
        mmu.write_u8(address: MMU::TMA,  value: 0x42) # TMA: オーバーフロー時の再ロード値
        mmu.write_u8(address: MMU::IF, value: 0b00000000) # IF を全クリア(Timer overflow で bit 2 が立つことを後段で検証するため事前にゼロに揃える)
        cpu.registers.pc = 0xC100
        # NOP を 5 個 (20 T-cycles) 並べる: 16 T-cycles 目で overflow、+1 M-cycle (4 T-cycles) で TMA を TIMA に reload
        5.times { |i| mmu.write_u8(address: 0xC100 + i, value: CPU::NOP) }

        cpu.run(20)

        expect(mmu.read_u8(address: MMU::IF) & 0b00000100).to eq 0b00000100 # Timer 割り込み立つ
        expect(mmu.read_u8(address: MMU::TIMA)).to eq 0x42 # TMA が TIMA へ再ロード
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
      let(:instr_bytes) { [CPU::HALT] }

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

    context 'HALT 中に IF & IE が真になったとき(Test 5、IME=1)' do
      it 'halted=false に戻り、ベクタ 0x50 へ dispatch される' do
        cpu.ime = true
        cpu.halted = true
        cpu.registers.pc = 0xC100 # HALT復帰後に stack へ push される戻り先 PC を既知の値にしておく
        cpu.registers.sp = 0xDFFE # SP を WRAM 末尾に置き、dispatch の PC push が WRAM 内に収まるようにする
        mmu.write_u8(address: MMU::IE, value: 0b00000100) # TimerフラグをON
        mmu.write_u8(address: MMU::IF, value: 0b00000100) # TimerフラグをON

        cpu.step

        expect(cpu.halted).to eq false
        expect(cpu.registers.pc).to eq timer_vector
      end
    end

    context 'HALT 中に IF & IE が真になったとき(Test 5、IME=0)' do
      it 'halted=false に戻り、HALT の次の命令から再開する(dispatch されない)' do
        cpu.ime = false
        cpu.halted = true
        cpu.registers.pc = 0xC100
        mmu.write_u8(address: 0xC100, value: CPU::NOP)
        mmu.write_u8(address: MMU::IE, value: 0b00000100) # TimerフラグをON
        mmu.write_u8(address: MMU::IF, value: 0b00000100) # TimerフラグをON

        cpu.step

        expect(cpu.halted).to eq false
        expect(cpu.registers.pc).to eq 0xC101 # NOP を踏んだ後
      end
    end

    # ==========================================================================
    # IF (0xFF0F) と IE (0xFFFF) の I/O 直接アクセス
    # Pan Docs: https://gbdev.io/pandocs/Interrupts.html#ff0f--if-interrupt-flag
    # ==========================================================================

    context 'IF (MMU::IF) を MMU 経由で読み書きしたとき' do
      it '下位 5bit が書いた値で読める' do
        mmu.write_u8(address: MMU::IF, value: 0b00011111)
        expect(mmu.read_u8(address: MMU::IF)).to eq 0b00011111
      end
    end
  end
end
