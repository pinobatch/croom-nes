;
; Concentration Room main loop
; Copyright (C) 2010 Damian Yerrick
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.include "src/nes.h"
.include "src/ram.h"
.p02

.exportzp psg_sfx_state

.segment "ZEROPAGE"
.shuffle
nmis: .res 1
cur_keys: .res 2
new_keys: .res 2
psg_sfx_state: .res 32
.endshuffle

.segment "BSS"
storyStage: .res 1

.segment "INESHDR"
  .byt "NES",$1A
  .byt 1  ; 16 KiB PRG ROM
  .byt 1  ; 8 KiB CHR ROM
  .byt 1  ; vertical mirroring; low mapper nibble: 0
  .byt 0  ; high mapper nibble: 0

.segment "VECTORS"
  .addr nmi, reset, irq

.segment "CODE"
.shuffle --procs--
.proc irq
  rti
.endproc
--procs--
.proc nmi
  inc nmis
  rti
.endproc
--procs--
.proc reset
  sei
  
  ; Acknowledge and disable interrupt sources during bootup
  ldx #0
.shuffle
  stx PPUCTRL    ; disable vblank NMI
  stx PPUMASK    ; disable rendering (and rendering-triggered mapper IRQ)
.endshuffle
  lda #$40
.shuffle
  sta $4017      ; disable frame IRQ
  stx $4010      ; disable DPCM IRQ
.endshuffle
.shuffle
  bit PPUSTATUS  ; ack vblank NMI
  bit $4015      ; ack frame IRQ
  cld            ; disable decimal mode to help generic 6502 debuggers
                 ; http://magweasel.com/2009/08/29/hidden-messagin/
  dex            ; Set up the stack
.endshuffle
  txs
  
  ; Wait for the PPU to warm up (part 1 of 2)
vwait1:
  bit PPUSTATUS
  bpl vwait1

  ; While waiting for the PPU to finish warming up, we have about
  ; 29000 cycles to burn without touching the PPU.  So we have time
  ; to initialize some of RAM to known values.
  ; Ordinarily the "new game" initializes everything that the game
  ; itself needs, so we'll just do zero page and shadow OAM.
.shuffle
  ldy #$00
  lda #$F0
  ldx #$00
.endshuffle
clear_zp:
.shuffle
  sty $00,x
  sta OAM,x
.endshuffle
  inx
  bne clear_zp
  
  ; Initialize the randomizer
  ldx #$23
  stx rand3
  inx
  stx rand2
  inx
  stx rand1
  inx
  stx rand0

  jsr init_sound
  ; Wait for the PPU to warm up (part 2 of 2)
vwait2:
  bit PPUSTATUS
  bpl vwait2

titleLoop:
  jsr titleScreen
  jsr titleDispatch
  jmp titleLoop
.endproc
--procs--
.proc titleDispatch
  ; mix the mode and current time into the random seed
  asl a
  tax
  adc rand0
  sta rand0
  
.shuffle --steps--
  lda nmis
  eor rand2
  sta rand2
--steps--
  ; combine RTS dispatch with a tail call: set up the return address
  ; on the stack, so that when random returns, it tail-calls the mode
  lda titleModes+1,x
  pha
  lda titleModes,x
  pha
.endshuffle
  ; get the mixed-in random bits out of byte-alignment
  ldy #2
  jmp random
.endproc
.segment "RODATA"
titleModes:
  .addr storyMode-1, solitaireMode-1, twoPlayerMode-1
  .addr vsCPUMode-1, showLicense-1

.segment "CODE"
--procs--
.proc storyMode
  lda #0
  sta storyStage
  jsr scrollOpeningText

stageLoop:
  lda #0
.shuffle
  sta score
  sta score+1
.endshuffle
  lda storyStage
  asl a
  asl a
  asl a
  tax
  lda storyStages,x
  sta difficulty
  ldy #2
  lda storyStages+1,x
  sta aiNoiseLevel
  bpl isTwoPlayers
  lda difficulty
  asl a
  asl a
  adc difficulty
  asl a
  asl a
  adc #20
  sta score
  dey

isTwoPlayers:
  sty numPlayers
  dey
.shuffle
  sty lastPlayerIsAI
  sty scoreMethod
.endshuffle
  jsr play_memory

  ; at this point, if player 2's score is greater than or equal to
  ; player 1's, it's a fail.
  lda storyStage
  asl a
  asl a
  asl a
  tax
  lda score+1
  cmp score
  bcc notFail
  inx
  inx
notFail:
  lda storyStages+5,x
  bpl notDone
  rts
notDone:
  sta storyStage
  lda storyStages+4,x
  bmi noScrollText
  cmp #$40
  bcc normalScrollText
  and #$3F
  jsr doOpponentScene
  jmp stageLoop
normalScrollText:
  jsr scrollOpeningText
noScrollText:
  jmp stageLoop
.endproc

.segment "RODATA"

; The game can have up to 32 stages.
; Byte 0: layout (0: 10 cards; 4: 72 cards)
; Byte 1: if positive: stupidity of CPU opponent
;         if negative: use solitaire
; Byte 2: unused
; Byte 3: unused
; Byte 4: id of scrolltext to show after a win (neg: none)
; Byte 5: next stage after a win (neg: none)
; Byte 6: id of scrolltext to show after a loss (neg: none)
; Byte 7: next stage after a loss (neg: none)
;
; A loss is finishing with 0 points in solitaire or fewer than
; the opponent in vs. CPU.
storyStages:
;     Diff Noi -- -- Wtxt Wst Ltxt Lst
  .byt   0, -1, 0, 0,  64,  1,  -1, -1  ;  0: beginner stage
  .byt   0, 16, 0, 0,  65,  2,  66,  0  ;  1: vs. preschooler
  .byt   1, -1, 0, 0,  67,  3,  -1, -1  ;  2: easy stage
  .byt   1, 12, 0, 0,  68,  4,  69,  2  ;  3: vs. grade schooler
  .byt   2, -1, 0, 0,  70,  5,  -1, -1  ;  4: medium stage
  .byt   2,  8, 0, 0,  71,  6,  72,  4  ;  5: vs. middle schooler
  .byt   3, -1, 0, 0,  73,  7,  -1, -1  ;  2: hard stage
  .byt   3,  8, 0, 0,  74,  8,  75,  6  ;  3: vs. high schooler
  .byt   4, -1, 0, 0,  76,  9,  -1, -1  ;  4: expert stage
  .byt   4,  8, 0, 0,  77, -1,  78,  8  ;  5: vs. lab technician

.segment "CODE"
--procs--
.proc solitaireMode
.shuffle --steps--
  lda #0
.shuffle
  sta lastPlayerIsAI
  sta scoreMethod
.endshuffle
--steps--
  lda #1
  sta numPlayers
--steps--
  lda difficulty
  asl a
  asl a
  adc difficulty
  asl a
  asl a
  adc #20
  sta score
.endshuffle
  lda #1
  jsr scrollOpeningText
  jsr play_memory
  rts
.endproc
--procs--
.proc twoPlayerMode
  ldx #2
  stx numPlayers
  dex
  stx scoreMethod
  dex
.shuffle
  stx lastPlayerIsAI
  stx score
  stx score+1
  lda #4
.endshuffle
  jsr scrollOpeningText
  jsr play_memory
  rts
.endproc
--procs--
.if 0
.proc watchCPUMode
  lda #0
  sta scoreMethod
  lda #100
  sta score
  lda #1
  sta lastPlayerIsAI
  sta numPlayers
  lda #8
  sta aiNoiseLevel
  lda #3
  jsr scrollOpeningText
  jsr play_memory
  rts
.endproc
.endif
--procs--
.proc vsCPUMode
.shuffle --steps--
  lda #8
  sta aiNoiseLevel
--steps--
  ldx #2
  stx numPlayers
  dex
.shuffle
  stx scoreMethod
  stx lastPlayerIsAI
.endshuffle
  dex
.shuffle
  stx score
  stx score+1
.endshuffle

.endshuffle
  lda #4
  jsr scrollOpeningText
  jsr play_memory
  rts
.endproc
--procs--
.proc showLicense
  lda #2
  jmp scrollOpeningText
.endproc
.endshuffle
