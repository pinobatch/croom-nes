.include "nes.inc"
.include "global.inc"

.segment "CODE"
.proc puthex
  pha
  lsr a
  lsr a
  lsr a
  lsr a
  jsr hex1
  pla
  and #$0F
hex1:
  cmp #10
  bcc :+
    adc #'a'-'0'-11
  :
  adc #'0'
  sta PPUDATA
  rts
.endproc

.proc test_countCardsInPattern
  lda #0
  sta PPUMASK
  lda #$21
  sta PPUADDR
  lda #$02
  sta PPUADDR
  ; should print >0a14243428.
  lda #'c'
  lda #'c'
  sta PPUDATA
  lda #'i'
  sta PPUDATA
  lda #'p'
  sta PPUDATA
  lda #'>'
  sta PPUDATA
  lda #0
  jsr countCardsInPattern
  jsr puthex
  lda #1
  jsr countCardsInPattern
  jsr puthex
  lda #2
  jsr countCardsInPattern
  jsr puthex
  lda #3
  jsr countCardsInPattern
  jsr puthex
  lda #4
  jsr countCardsInPattern
  jsr puthex
  lda #'.'
  sta PPUDATA
  lda nmis
:
  cmp nmis
  beq :-
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  lda #VBLANK_NMI
  sta PPUCTRL
  lda #%00001010
  sta PPUMASK
:
  jmp :-
  
.endproc

.proc test_bcd8bit
  pha
  lda #$21
  sta PPUADDR
  lda #$C2
  sta PPUADDR
  lda #'$'
  sta PPUDATA
  pla
  pha
  jsr puthex
  lda #'='
  sta PPUDATA
  pla
  jsr bcd8bit
  pha
  lda 0
  jsr puthex
  pla
  ora #'0'
  sta PPUDATA
  rts
.endproc


