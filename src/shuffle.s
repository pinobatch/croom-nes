;
; Card shuffling for Concentration Room
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
.include "src/ram.h"
;.include "src/nes.h"  ; for debugging shuffle
.segment "ZEROPAGE"
rand0: .res 1
rand1: .res 1
rand2: .res 1
rand3: .res 1

.segment "CODE"
.shuffle --procs--
;; random
; Uses the crc32 polynomial to generate Y
; pseudorandom bits as the low_order bits of rand3.
; Average 48 cycles per bit.
; FIXME: May want to use the simpler polynomial version from
; try 2 if it too is full-period.
;
.proc random
  asl rand3
  rol rand2
  rol rand1
  rol rand0
  bcc @no_xor
.shuffle --crcbytes--
  lda rand0
  eor #$04
  sta rand0
--crcbytes--
  lda rand1
  eor #$c1
  sta rand1
--crcbytes--
  lda rand2
  eor #$1d
  sta rand2
--crcbytes--
  lda rand3
  eor #$b7
  sta rand3
.endshuffle
@no_xor:
  dey
  bne random
  rts
.endproc
--procs--

.proc findPattern
patternBase = 0

  ; First find the address of the pattern by multiplying
  ; A by 9.  This will start to fail once A >= 28
  sta patternBase
  asl a
  asl a
  asl a
  adc patternBase
  ; assuming carry is clear here
  adc #<dealPatterns
  sta patternBase
  lda #>dealPatterns
  adc #0
  sta patternBase+1
  rts
.endproc
--procs--

.proc countCardsInPattern
patternBase = 0
patternByte = 2

  jsr findPattern
.shuffle
  ldy #FIELD_WID - 1
  lda #0
  clc
.endshuffle
patrowloop:
  pha
  lda (patternBase),y
  sta patternByte
  pla
patbitloop:
  adc #0
  lsr patternByte
  bne patbitloop
  dey
  bpl patrowloop
  adc #0
  rts
.endproc
--procs--

;;
; @param x number of cards to shuffle
.proc shuffleCards
patternBase = 0
patternByte = 2
shufflePos = 3
nCards = 4
initialCardsBase = 6

  ; First get the address of this pattern and count the cards
  lda difficulty
  jsr countCardsInPattern
  sta nCards

  ; STEP 1: Seed the PRNG by mixing in the current time
  lda nmis
  eor rand3
  sta rand3
  ldy #8
  jsr random

  ; STEP 2: Clear the board
.shuffle
  ldx #71
  lda #0
.endshuffle
clearBoard:
  sta boardState,x
  dex
  bpl clearBoard

  ; STEP 3: Create two of each card in the deck
  lda difficulty
  asl a
  tay
.shuffle --lohi--
  lda standardCardSets,y
  sta initialCardsBase
--lohi--
  lda standardCardSets+1,y
  sta initialCardsBase+1
--lohi--
  ldx nCards
  dex
.endshuffle
  txa
  lsr a
  tay
gatherLoop:
  lda (initialCardsBase),y
.shuffle
  ora #$80
  dex
.endshuffle
  sta boardState+1,x
  sta boardState,x
  dex
  dey
  bpl gatherLoop
  ldx nCards
  dex
  stx shufflePos

  ; STEP 4: Swap each card with a randomly chosen card
swapLoop:
  ldy #6
  jsr random

  ; the starting card number is ((rand() % 64) + shufflePos + 1) % nCards
  lda #$3F
.shuffle
  and rand3
  sec
.endshuffle
  adc shufflePos
  sec
mod_nCards_loop:
  sbc nCards
  bcs mod_nCards_loop
  adc nCards
.shuffle
  tax
  ldy shufflePos
.endshuffle
  lda boardState,y
  pha
  lda boardState,x
  sta boardState,y
  pla
  sta boardState,x
  dec shufflePos
  bpl swapLoop
  
  ; STEP 5: Deal cards into their final positions
  ldx #71
  cpx nCards
  bcc dealDone
dealRow:
  txa
  lsr a
  lsr a
  lsr a
  tay
  lda (patternBase),y
  sta patternByte
dealloop:
  ; is there a card at this location?
  lsr patternByte
  bcc dealNoSwap
  dec nCards
  ldy nCards
  lda boardState,y
  sta boardState,x
  lda #0
  sta boardState,y
dealNoSwap:
  txa
  beq dealDone
  dex
  cpx nCards
  bcc dealDone
  and #%00000111
  bne dealloop
  beq dealRow
dealDone:
  rts
.endproc
.endshuffle

.segment "RODATA"
.shuffle --datablocks--
dealPatterns:
  .byt %00000000  ; pattern 1: 10 cards
  .byt %00000000
  .byt %00011000
  .byt %00100100
  .byt %00100100
  .byt %00100100
  .byt %00011000
  .byt %00000000
  .byt %00000000
  
  .byt %00000000  ; pattern 2: 20 cards
  .byt %00000000
  .byt %00111100
  .byt %00111100
  .byt %00111100
  .byt %00111100
  .byt %00111100
  .byt %00000000
  .byt %00000000
  
  .byt %00000000  ; pattern 3: 36 cards
  .byt %01111110
  .byt %01111110
  .byt %01111110
  .byt %00000000
  .byt %01111110
  .byt %01111110
  .byt %01111110
  .byt %00000000

  .byt %00000000  ; pattern 4: 52 cards
  .byt %01111110
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %01111110
  .byt %00000000

  .byt %11111111  ; pattern 5: 72 cards
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111
  .byt %11111111

--datablocks--
; Decide which cards are in each of the first 5 levels
; (standard card set)
standardCardSets:
  .addr level1cards, level2cards, level3cards, level4cards, level5cards
--datablocks--
level1cards:
level2cards:
level5cards:
  .byt $1C,$1D,$1E,$1F,$20  ; level 1, 2, 5
  .byt $21,$22,$23,$24,$25  ; level 2, 5
level3cards:
level4cards:
  .byt $26,$27,$2C,$2D,$2E,$2F,$30,$31,$32  ; level 3, 4, 5
  .byt $33,$34,$35,$36,$37,$3C,$3D,$3E,$3F  ; level 3, 4, 5
  .byt $28,$29,$2A,$2B,$38,$39,$3A,$3B  ; level 4, 5
.endshuffle
