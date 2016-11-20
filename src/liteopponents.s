;
; Title screen for Concentration Room (free version)
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
.export doOpponentScene

.segment "CODE"
.proc drawOpponent
attr0 = 0
attr1 = 1
attr2 = 2
attr3 = 3
baseX = 4
baseY = 5
deltaX = 6
deltaY = 7
nTiles = 8
deltaTile = 9
palette = 10

  stx baseX
  sty baseY
  tax
  lda opponentShapeOffsets,x
  tax
  ldy #0
copypal:
  lda opponentShape0,x
  sta palette,y
  inx
  iny
  cpy #6
  bcc copypal
  ldy #0
  ;C4B1 breakpoint here
opcodeloop:
  lda opponentShape0,x
  bne notBail
  lda #$F0
:
  sta OAM,y
  iny
  iny
  iny
  iny
  bne :-
  rts
notBail:
  and #$0F
  sta nTiles
  lda opponentShape0,x
  and #$40
  asl a
  rol a
  rol a
  sta attr2
  lda opponentShape0,x
  bmi isDown
  
  lda #1
  sta deltaTile
  lsr a
  sta deltaY
  lda #8
  bne haveDeltaX
isDown:
  lda #8
  sta deltaY
  asl a
  sta deltaTile
  lda #0
haveDeltaX:
  sta deltaX
  inx
  clc
  lda opponentShape0,x
  inx
  adc baseX
  sta attr3
  clc
  lda opponentShape0,x
  inx
  adc baseY
  sta attr0
  lda opponentShape0,x
  inx
  sta attr1
tileloop:
  lda attr0
  sta OAM,y
  iny
  clc
  adc deltaY
  sta attr0
  lda attr1
  sta OAM,y
  iny
  clc
  adc deltaTile
  sta attr1
  lda attr2
  sta OAM,y
  iny
  lda attr3
  sta OAM,y
  iny
  clc
  adc deltaX
  sta attr3
  dec nTiles
  bne tileloop
  jmp opcodeloop
.endproc

.segment "RODATA"
opponentShapeOffsets:
  .byt opponentShape0-opponentShape0
  .byt opponentShape1-opponentShape0
  .byt opponentShape2-opponentShape0
  .byt opponentShape3-opponentShape0
  .byt opponentShape4-opponentShape0

opponentShape0:
  .byt $26,$38,$0F,$26,$14,$0F
  .byt $01, 4, 8,$CF
  .byt $01,21, 8,$DF
  .byt $04, 0,16,$D0
  .byt $04, 0,24,$E0
  .byt $43, 4,32,$F0
  .byt $00

opponentShape1:
  .byt $26,$16,$0F,$1A,$1A,$1A
  .byt $84, 8, 8,$C4
  .byt $84,16, 8,$C5
  .byt $01, 0,16,$C0
  .byt $00

opponentShape2:
  .byt $26,$18,$0F,$26,$27,$0F
  .byt $03, 4,10,$C6
  .byt $03, 4,18,$D6
  .byt $42, 8,26,$E7
  .byt $43, 4,34,$F6
  .byt $00

opponentShape3:
  .byt $26,$17,$0F,$26,$38,$0F
  .byt $03, 4, 8,$C9
  .byt $03, 4,16,$D9
  .byt $03, 4,24,$E9
  .byt $43, 4,32,$F9
  .byt 0

opponentShape4:
  .byt $26,$03,$0F,$26,$30,$0F
  .byt $03, 2, 4,$C1
  .byt $03, 2,12,$CC
  .byt $03, 2,20,$DC
  .byt $43, 2,28,$EC
  .byt $43, 2,36,$FC
  .byt $01,26,24,$EF
  .byt $01,26,32,$FF
  .byt $00

.segment "CODE"
.proc doOpponentScene
src = 6
dstLo = 14
dstHi = 15

  pha
  ldx #$20
  lda #0
  sta PPUMASK
  stx PPUADDR
  sta PPUADDR
  lda #< table_pkb
  sta 0
  lda #> table_pkb
  sta 1
  jsr PKB_unpackblk
  pla
  asl a
  asl a
  pha
  tax
  lda opponentScenes+2,x
  ldx #112
  ldy #47
  jsr drawOpponent
  pla
  tax
  lda opponentScenes,x
  sta src
  lda opponentScenes+1,x
  sta src+1
  
  ; set up palette
  lda nmis
:
  cmp nmis
  beq :-
  ldy #$3F
  lda #$00
  ldx #7
  sty PPUADDR
  sta PPUADDR
:
  lda tablepalreverse,x
  sta PPUDATA
  dex
  bpl :-

  ldy #$3F
  lda #$00
  ldx #7
  sty PPUADDR
  sta PPUADDR
:
  lda tablepalreverse,x
  sta PPUDATA
  dex
  bpl :-
  sty PPUADDR
  lda #$11
  sta PPUADDR
  lda 10
  sta PPUDATA
  lda 11
  sta PPUDATA
  lda 12
  sta PPUDATA
  sta PPUDATA
  lda 13
  sta PPUDATA
  lda 14
  sta PPUDATA
  lda 15
  sta PPUDATA

  lda #$22
  sta dstHi
  lda #$42
  sta dstLo

frameLoop:
  lda nmis
:
  cmp nmis
  beq :-
  
  ; draw another letter if needed
  
  ldy #0
  lda (src),y
  beq noLetter
  inc src
  bne :+
  inc src+1
:
  cmp #10
  beq isNewline
  ldx dstHi
  stx PPUADDR
  ldx dstLo
  inc dstLo
  stx PPUADDR
  sta PPUDATA
  jmp noLetter
isNewline:
  lda dstLo
  clc
  and #$C0
  adc #66
  sta dstLo
  bcc noLetter
  inc dstHi


noLetter:
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda #VBLANK_NMI
  sta PPUCTRL
  lda #BG_ON|OBJ_ON
  sta PPUMASK

  jsr read_pads
  lda new_keys
  and #KEY_A
  beq frameLoop
  rts
.endproc

.segment "RODATA"
table_pkb:
  .incbin "src/litetable.pkb"
tablepalreverse:
  .byt $30,$27,$07,$0F,$30,$10,$07,$0F

  ; Opponent lose is when you beat them and THEY lose

opponentScenes:
  .addr opponent1introText
  .byt 0  ; Lillie
  .byt 0  ; unused
  .addr opponent1LoseText
  .byt 0
  .byt 0
  .addr opponent1WinText
  .byt 0
  .byt 0
  .addr opponent2introText
  .byt 1  ; Ethan
  .byt 0  ; unused
  .addr opponent2LoseText
  .byt 1
  .byt 0
  .addr opponent2WinText
  .byt 1
  .byt 0
  .addr opponent3introText
  .byt 2  ; Venny
  .byt 0  ; unused
  .addr opponent3LoseText
  .byt 2
  .byt 0
  .addr opponent3WinText
  .byt 2
  .byt 0
  .addr opponent4introText
  .byt 3  ; Snowy
  .byt 0  ; unused
  .addr opponent4LoseText
  .byt 3
  .byt 0
  .addr opponent4WinText
  .byt 3
  .byt 0
  .addr opponent5introText
  .byt 4  ; Susan
  .byt 0  ; unused
  .addr opponent5LoseText
  .byt 4
  .byt 0
  .addr opponent5WinText
  .byt 4
  .byt 0

opponent1introText:
  .byt "<Lillie>",$0A
  .byt "Hey, you look fun.",$0A
  .byt "Wanna play?",$0A,$00

opponent1LoseText:
  .byt "<Lillie>",$0A
  .byt "Awww, you're no fun",$0A
  .byt "after all.",$0A,$00

opponent1WinText:
  .byt "<Lillie>",$0A
  .byt "Yay! I won!",$0A
  .byt "Wanna try again later?",$0A,$00

opponent2introText:
  .byt "<Ethan>",$0A
  .byt "How dare you make my",$0A
  .byt "sister cry? You'll pay!",$0A,$00

opponent2LoseText:
  .byt "<Ethan>",$0A
  .byt "Dang, you're good.",$0A,$00

opponent2WinText:
  .byt "<Ethan>",$0A
  .byt "I told you that you'd pay.",$0A,$00

opponent3introText:
  .byt "<Venny>",$0A
  .byt "You're pretty good.",$0A
  .byt "Wanna play me?",$0A,$00

opponent3LoseText:
  .byt "<Venny>",$0A
  .byt "I guess I was right:",$0A
  .byt "you are pretty good.",$0A,$00

opponent3WinText:
  .byt "<Venny>",$0A
  .byt "I guess I was wrong.",$0A
  .byt "Wanna play again later?",$0A,$00

opponent4introText:
  .byt "<Snowy>",$0A
  .byt "Random challenge! Go!",$0A,$00

opponent4LoseText:
  .byt "<Snowy>",$0A
  .byt "Aaah, my random challenge",$0A
  .byt "failed me. You won.",$0A,$00

opponent4WinText:
  .byt "<Snowy>",$0A
  .byt "Yay! Awesome random",$0A
  .byt "challenges are awesome.",$0A
  .byt "Wanna play again later?",$0A,$00

opponent5introText:
  .byt "<Susan>",$0A
  .byt "You are quite intriguing.",$0A
  .byt "Mind a match of cards",$0A
  .byt "with me?",$0A,$00

opponent5LoseText:
  .byt "<Susan>",$0A
  .byt "Very amusing, you are skilled",$0A
  .byt "in the game of cards.",$0A
  .byt "Well done.",$0A,$0A

opponent5WinText:
  .byt "<Susan>",$0A
  .byt "Hmmm.... I'm sorry, I",$0A
  .byt "misjudged you. You still",$0A
  .byt "need to work on it.",$0A,$00

