;
; Game board display for Concentration Room
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
.include "nes.inc"
.include "global.inc"

; Transfer buffers used by this I/O module
; before transition to popslide
card_buf = $0180
sprpal_buf = $0190
scoreXferBuf = $019C
otherBuf = $01AA  ; Unallocated from here to $01BF

; When nonzero, show the game state, current turn, and AI state
; as sprites in the upper left corner.
SHOW_STATE_AND_TURN = 0
; The display engine can draw the backs of remembered cards in white
; as a tool for troubleshooting AI. It's a bit glitchy on the borders
; when an adjacent card redraws.
DRAW_REMEMBERED_BACKS = 0

; Various tile indices
CARD_BACK_TILE = $04
ARROW_TILE = $06
CARDCORNERS_BASE = $20
CARDTB_BASE = $30
CARDLR_BASE = $38

.segment "ZEROPAGE"
.shuffle
selectedCards: .res 2
card0FlipFrame: .res 1
card_dst_hi: .res 1
card_dst_lo: .res 1
collectingX: .res 2
collectingY: .res 2
collectingDX: .res 2
collectingDY: .res 2
cursor_x: .res 1  ; 0 to 8
cursor_y: .res 1  ; 0 to 7
cursor_sprite_x: .res 1  ; 32 to 224
cursor_sprite_y: .res 1  ; 39 to 207
curTurn: .res 1         ; 0: jews; 1: flp
scoreXferDst: .res 1  ; player for which a score update is ready
.endshuffle

.segment "BSS"
boardState: .res 72

.segment "CODE"
.shuffle --procs--
;;
; Finds which cards surround a given card.
; surrounds:
; 765
; 4 3
; 210
; @param x card position (0-71)
.proc card_get_surrounds
surrounds = 1
  lda #0
  sta surrounds

; handle board corners
  cpx #0
  bne notTopLeft
  lda #$80
  sta surrounds
  bne hitLSideCorner
notTopLeft:
  cpx #7
  bne notBottomLeft
  lda #$04
  sta surrounds
  bne hitLSideCorner
notBottomLeft:
  cpx #64
  bne notTopRight
  lda #$20
  sta surrounds
  bne hitRSideCorner
notTopRight:
  cpx #71
  bne notBottomRight
  lda #$01
  sta surrounds
  bne hitRSideCorner
notBottomRight:

  cpx #8
  bcc skippedLSide
hitRSideCorner:
  ; get the left side surrounding bits
  txa
  and #$07
  beq skippedUL
  lda boardState-9,x
  bpl skippedUL
  lda #$80
  ora surrounds
  sta surrounds
skippedUL:

  lda boardState-8,x
  bpl skippedL
  lda #$10
  ora surrounds
  sta surrounds
skippedL:

  txa
  and #$07
  cmp #7
  beq skippedDL
  lda boardState-7,x
  bpl skippedDL
  lda #$04
  ora surrounds
  sta surrounds
skippedDL:
skippedLSide:
hitLSideCorner:

  ; get the top and bottom surrounding bits
  txa
  and #$07
  beq skippedU
  lda boardState-1,x
  bpl skippedU
  lda #$40
  ora surrounds
  sta surrounds
skippedU:

  txa
  and #$07
  cmp #7
  beq skippedD
  lda boardState+1,x
  bpl skippedD
  lda #$02
  ora surrounds
  sta surrounds
skippedD:

  cpx #64
  bcs skippedRSide
  ; get the right side surrounding bits
  txa
  and #$07
  beq skippedUR
  lda boardState+7,x
  bpl skippedUR
  lda #$20
  ora surrounds
  sta surrounds
skippedUR:

  lda boardState+8,x
  bpl skippedR
  lda #$08
  ora surrounds
  sta surrounds
skippedR:

  txa
  and #$07
  cmp #7
  beq skippedDR
  lda boardState+9,x
  bpl skippedDR
  lda #$01
  ora surrounds
  sta surrounds
skippedDR:
skippedRSide:

  lda surrounds
  rts
.endproc
--procs--
;;
; Builds the data for a single tile.
; @param x card position (0-71)
.proc buildCardTiles
surrounds = 1

; tiles $20-$2F: 1 top left present, 2 top right present,
; 4 bottom left present, 8 bottom right present
; tiles $2F-$37: 1 top present, 2 top present and flipped,
; 3 bottom present, 6 bottom present and flipped
; $2F does not exist so use $20 instead
; tiles $37-$3F: 1 left present, 2 left present and flipped,
; 3 right present, 6 right present and flipped
; $37 does not exist so use $20 instead

  txa
  pha
  jsr card_get_surrounds
  sta surrounds

  lda #CARDCORNERS_BASE
  ldx #15
clearBack:
  sta card_buf,x
  dex
  bpl clearBack
  pla
  tax

  asl surrounds
  bcc notUL
  lda #$01
  ora card_buf+0
  sta card_buf+0
notUL:
  asl surrounds
  bcc notU
  lda #CARDCORNERS_BASE|$01
  sta card_buf+1
  lda #$02
  ora card_buf+0
  sta card_buf+0
  lda #$01
  ora card_buf+3
  sta card_buf+3
  lda #$40
  and boardState-1,x
  beq notU
  lda #CARDCORNERS_BASE|$02
  sta card_buf+1
notU:
  asl surrounds
  bcc notUR
  lda #2
  ora card_buf+3
  sta card_buf+3
notUR:
  asl surrounds
  bcc notL
  lda #CARDCORNERS_BASE+1
  sta card_buf+4
  lda #$04
  ora card_buf+0
  sta card_buf+0
  lda #$01
  ora card_buf+12
  sta card_buf+12
  lda #$40
  and boardState-8,x
  beq notL
  lda #CARDCORNERS_BASE+2
  sta card_buf+4
notL:
  asl surrounds
  bcc notR
  lda #CARDCORNERS_BASE+3
  sta card_buf+7
  lda #$08
  ora card_buf+3
  sta card_buf+3
  lda #$02
  ora card_buf+15
  sta card_buf+15
  lda #$40
  and boardState+8,x
  beq notR
  lda #CARDCORNERS_BASE+6
  sta card_buf+7
notR:
  asl surrounds
  bcc notDL
  lda #$04
  ora card_buf+12
  sta card_buf+12
notDL:
  asl surrounds
  bcc notD
  lda #CARDCORNERS_BASE+3
  sta card_buf+13
  lda #$08
  ora card_buf+12
  sta card_buf+12
  lda #$04
  ora card_buf+15
  sta card_buf+15
  lda #$40
  and boardState+1,x
  beq notD
  lda #CARDCORNERS_BASE+6
  sta card_buf+13
notD:
  asl surrounds
  bcc notDR
  lda #$08
  ora card_buf+15
  sta card_buf+15
notDR:

  lda boardState,x
  bmi cardHere
  jmp notHere
cardHere:  
  ; add corners for the card in the middle
  lda #$08
  ora card_buf
  sta card_buf
  lda #$04
  ora card_buf+3
  sta card_buf+3
  lda #$02
  ora card_buf+12
  sta card_buf+12
  lda #$01
  ora card_buf+15
  sta card_buf+15
  
  ; process sides and middle
  lda boardState,x
  and #$40
  bne flippedHere
.if ::DRAW_REMEMBERED_BACKS
  lda rememberState,x
  bne flippedHere
.endif
  clc
  lda #3
  adc card_buf+1
  sta card_buf+1
  lda #3
  adc card_buf+4
  sta card_buf+4
  lda #1
  adc card_buf+7
  sta card_buf+7
  lda #1
  adc card_buf+13
  sta card_buf+13
  lda #CARD_BACK_TILE
  sta card_buf+5
  eor #$01
  sta card_buf+6
  eor #$11
  sta card_buf+9
  eor #$01
  sta card_buf+10
  bne notHere
flippedHere:
  clc
  lda #6
  adc card_buf+1
  sta card_buf+1
  lda #6
  adc card_buf+4
  sta card_buf+4
  lda #2
  adc card_buf+7
  sta card_buf+7
  lda #2
  adc card_buf+13
  sta card_buf+13
  lda #$00
  sta card_buf+5
  sta card_buf+6
  sta card_buf+9
  sta card_buf+10

notHere:
  
  lda card_buf+1
  cmp #CARDCORNERS_BASE+1
  bcc :+
  adc #CARDTB_BASE-CARDCORNERS_BASE-2
  sta card_buf+1
  sta card_buf+2
:
  lda card_buf+4
  cmp #CARDCORNERS_BASE+1
  bcc :+
  adc #CARDLR_BASE-CARDCORNERS_BASE-2
  sta card_buf+4
  sta card_buf+8
:
  lda card_buf+7
  cmp #CARDCORNERS_BASE+1
  bcc :+
  adc #CARDLR_BASE-CARDCORNERS_BASE-2
  sta card_buf+7
  sta card_buf+11
:
  lda card_buf+13
  cmp #CARDCORNERS_BASE+1
  bcc :+
  adc #CARDTB_BASE-CARDCORNERS_BASE-2
  sta card_buf+13
  sta card_buf+14
:
  txa
  ; fall through to next proc
.endproc
.proc getCard_dst
  pha
  lsr a
  lsr a
  lsr a
  sta card_dst_lo
  asl a
  adc card_dst_lo
  adc #$62
  sta card_dst_lo
  pla
  and #$07
  sta card_dst_hi
  ; at this point: card_dst_hi = tileno / 8
  asl a
  adc card_dst_hi
  sta card_dst_hi
  ; at this point: card_dst_hi = (tileno / 8) * 3
  lda #0
  sec
  ror card_dst_hi
  ror a
  lsr card_dst_hi
  ror a
  lsr card_dst_hi
  ror a
  ; at this point: card_dst_hi:A = (tileno / 8) * 96
  adc card_dst_lo
  sta card_dst_lo
  bcc :+
    inc card_dst_hi
  :
  rts
.endproc
--procs--
.proc blitCard
  ldx #3
  lda #VBLANK_NMI|VRAM_DOWN
  sta PPUCTRL
rowloop:
  lda card_dst_hi
  sta PPUADDR
  txa
  clc
  adc card_dst_lo
  sta PPUADDR
  .repeat 4, I
    lda card_buf+4*I,x
    sta PPUDATA
  .endrepeat
  dex
  bpl rowloop
  rts
.endproc
--procs--
;;
; Clears a row of the playfield.
;
.proc gameOverClearRow
  lda gameOverClearTransitionY
  beq notClearOut
  ldx #VBLANK_NMI
  stx PPUCTRL
  ldx #0
  stx gameOverClearTransitionY
  lsr a
  ror gameOverClearTransitionY
  lsr a
  ror gameOverClearTransitionY
  lsr a
  ror gameOverClearTransitionY
  ora #$20
  sta PPUADDR
  lda gameOverClearTransitionY
  sta PPUADDR
  stx gameOverClearTransitionY
.shuffle
  ldx #16
  lda #$03  ; black tile
.endshuffle
:
  sta PPUDATA
  sta PPUDATA
  dex
  bne :-
notClearOut:
  rts
.endproc
--procs--
;;
; Makes a score update: 14 characters
; (>[].....18..)
; @param x the player for which to build the score update
; @param y nonzero: add "WIN"
.proc buildScoreUpdate
  tya
.shuffle
  pha
  stx scoreXferDst
.endshuffle

.shuffle --parts--

  ; first the endcaps
  lda #$64
  sta scoreXferBuf
--parts--
  lda #$67
  sta scoreXferBuf+13
--parts--

  ; draw player's emblem
  txa
  asl a
  ora #$60
  sta scoreXferBuf+2
  ora #$01
  sta scoreXferBuf+3
.endshuffle

  ; clear space between emblem and right endcap
.shuffle
  ldy #9
  lda #$66
.endshuffle
:
  sta scoreXferBuf+3,y
  dey
  bne :-

  ; draw turn indicator
  cpx curTurn
  bne notMyTurn
  lda #$65
notMyTurn:
  sta scoreXferBuf+1

  ; draw win indicator if Y was nonzero on entry
  pla
  beq notWin
  ldy #$4D
  sty scoreXferBuf+5
  iny
  sty scoreXferBuf+6
  iny
  sty scoreXferBuf+7
notWin:

  ; draw score
  lda score,x
  jsr bcd8bit
  ora #$40
  sta scoreXferBuf+11
  lda 0
  beq tensIsZero
  cmp #16
  bcc noThirdDigit
  lsr a
  lsr a
  lsr a
  lsr a
  ora #$40
  sta scoreXferBuf+9
  lda 0
  and #$0F
noThirdDigit:
  ora #$40
  sta scoreXferBuf+10
tensIsZero:
  rts
.endproc
--procs--

.proc blitScoreUpdate
  ldx scoreXferDst
  bmi noScoreXfer

  lda #VBLANK_NMI
  sta PPUCTRL
  sta scoreXferDst
  lda #$23
  sta PPUADDR
  lda scoreBoxAddrLo,x
  sta PPUADDR
  ldy #0
:
  lda scoreXferBuf,y
  sta PPUDATA
  iny
  cpy #14
  bcc :-

  lda #$23
  sta PPUADDR
  lda scoreBoxAddrLo,x
  ora #$20
  sta PPUADDR
  ldy #0
:
  lda scoreXferBuf,y
  ora #$10
  sta PPUDATA
  iny
  cpy #14
  bcc :-
noScoreXfer:
  rts
.endproc
--procs--
.proc loadPlayScreen
.shuffle
  lda #VBLANK_NMI
  ldx #192
.endshuffle
.shuffle
  sta cursor_sprite_x
  stx cursor_sprite_y
  sta PPUCTRL
.endshuffle
  ldx #0
  stx collectingY+0
  stx collectingY+1
  stx collectingX+0
  stx collectingX+1
.shuffle
  stx PPUMASK
  lda #$20
.endshuffle
  sta PPUADDR
  stx PPUADDR
.shuffle
  lda #3
  ldx #48
.endshuffle
:
  sta PPUDATA
  sta PPUDATA
  dex
  bne :-
  
  ; draw main play area
  ldy #25
main_area_rowloop:
  sta PPUDATA
  sta PPUDATA
.shuffle
  lda #2
  ldx #14
.endshuffle
:
  sta PPUDATA
  sta PPUDATA
  dex
  bne :-     
  lda #3
  sta PPUDATA
  sta PPUDATA
  dey
  bne main_area_rowloop

  ; black area behind the status bar
  ldy #64
:
  sta PPUDATA
  dey
  bne :-

  ; Set attributes: 0 for playfield, 2 for player 1, 3 for player 2  
.shuffle
  ldx #56
  lda #0
.endshuffle
:
  sta PPUDATA
  dex
  bne :-
  lda #$0A
  .repeat 4
    sta PPUDATA
  .endrepeat
  lda #$0F
  .repeat 4
    sta PPUDATA
  .endrepeat

  ; draw the status bar
  ldx numPlayers
:
  dex
  txa
.shuffle
  pha
  ldy #0
.endshuffle
  jsr buildScoreUpdate
  jsr blitScoreUpdate
  pla
  tax 
  bne :-
  
  ; wait for vblank to set the palette so that there isn't
  ; rainbow garbage
  jsr ppu_wait_vblank

.shuffle
  lda #$3F
  ldx #0
.endshuffle
  sta PPUADDR
  stx PPUADDR
copypal:
  lda game_palette,x
.shuffle
  sta PPUDATA
  inx
.endshuffle
  cpx #16
  bcc copypal

  rts
.endproc
--procs--
.proc drawCardSprites
cards_left = 0
oam_index = 1
this_pos = 2
thisCard = 3
mul_temp = 4
this_pos_x = 5
this_pos_y = 6

  ldx #11
  lda #0
:
  sta sprpal_buf,x
  dex
  bpl :-

  lda #4
  sta oam_index

  ; First draw the arrow sprite because it's on top.
  lda lastPlayerIsAI
  bne notPassController
  lda curState
  cmp #PlayState::PASS_CONTROLLER
  beq drawPassController
notPassController:
  jmp drawArrow

drawPassController:
  ; If in pass-controller mode, draw "pass the controller" message

  ldx oam_index  
.shuffle --oamattrs--
  lda #191
.shuffle
  sta cursor_sprite_y
  sta OAM,x
  sta OAM+4,x
  sta OAM+8,x
  sta OAM+12,x
.endshuffle
--oamattrs--
  lda #201
.shuffle
  sta OAM+16,x
  sta OAM+20,x
  sta OAM+24,x
.endshuffle
--oamattrs--
  lda #$02
.shuffle
  sta OAM+2,x
  sta OAM+6,x
  sta OAM+10,x
  sta OAM+14,x
  sta OAM+18,x
  sta OAM+22,x
  sta OAM+25,x
  sta OAM+26,x
.endshuffle
--oamattrs--
  lda #$10
  sta OAM+1,x
--oamattrs--
  lda #$11
  sta OAM+5,x
--oamattrs--
  lda #$12
  sta OAM+9,x
--oamattrs--
  lda #$13
  sta OAM+13,x
--oamattrs--
  lda #$01
  sta OAM+17,x
--oamattrs--
  lda #$0b
  sta OAM+21,x
--oamattrs--
  
  ; (.[].......0.)
  ldy curTurn
.shuffle
  lda scoreBoxSprX,y
  clc
.endshuffle
  adc #24
  sta OAM+3,x
  adc #4
  sta OAM+19,x
  adc #4
.shuffle
  sta cursor_sprite_x
  sta OAM+7,x
.endshuffle
  adc #4
  sta OAM+23,x
  adc #4
  sta OAM+11,x
  adc #4
  sta OAM+27,x
  adc #4
  sta OAM+15,x
.endshuffle
.shuffle
  txa
  clc
.endshuffle
  adc #28
  and #$FC
  jmp arrowDone
  
drawArrow:
  lda cursor_x
  asl a
  adc cursor_x
  asl a
  asl a
  asl a
  adc #32
;  sta mul_temp
  ldy stateTimer
  cpy #8
  bcc isntDownRightX
  ldy curState
.shuffle --downRightStates--
  cpy #PlayState::COLLECTING
  beq isDownRightX
--downRightStates--
  cpy #PlayState::UNFLIPPING
  beq isDownRightX
.endshuffle
isntDownRightX:
  ldy #0
  beq afterDownRightX
isDownRightX:
  ; add 4 but we came here on a beq, and cmp/beq implies bcs
  adc #3
afterDownRightX:  
  sec
  sbc cursor_sprite_x
  bcs arrow_to_right
  lsr a
  lsr a
  ora #$C0
  bne arrow_x_done
arrow_to_right:
  adc #2
  lsr a
  lsr a
arrow_x_done:
  clc
  adc cursor_sprite_x
  sta cursor_sprite_x

  lda cursor_y
  asl a
  adc cursor_y
  asl a
  asl a
  asl a
  adc #27
  cpy #0
  beq notDownRightY
  adc #7
notDownRightY:
  sec
  sbc cursor_sprite_y
  bcs arrow_to_down
  lsr a
  lsr a
  ora #$C0
  bne arrow_y_done
arrow_to_down:
  adc #2
  lsr a
  lsr a
arrow_y_done:
  clc
  adc cursor_sprite_y
.shuffle
  sta cursor_sprite_y
  ldx oam_index  
.endshuffle

.shuffle --arrowoamparts--
  lda cursor_sprite_y
.shuffle
  sta OAM,x
  sta OAM+4,x
  clc
.endshuffle
  adc #8
.shuffle
  sta OAM+8,x
  sta OAM+12,x
.endshuffle
--arrowoamparts--
  lda #ARROW_TILE
  sta OAM+1,x
--arrowoamparts--
  lda #ARROW_TILE|$01
  sta OAM+5,x
--arrowoamparts--
  lda #ARROW_TILE|$10
  sta OAM+9,x
--arrowoamparts--
  lda #ARROW_TILE|$11
  sta OAM+13,x
--arrowoamparts--
  lda #2
.shuffle
  sta OAM+2,x
  sta OAM+6,x
  sta OAM+10,x
  sta OAM+14,x
.endshuffle
--arrowoamparts--
  lda cursor_sprite_x
.shuffle
  sta OAM+3,x
  sta OAM+11,x
  clc
.endshuffle
  adc #8
.shuffle
  sta OAM+7,x
  sta OAM+15,x
.endshuffle
.endshuffle

.shuffle
  txa
  clc
.endshuffle
  adc #16
arrowDone:
  sta oam_index
.shuffle --arrowcolors--
  lda #$30  ; white for arrow
  sta sprpal_buf+2
--arrowcolors--
  lda #$16  ; red color for buttons
  sta sprpal_buf+6
--arrowcolors--
  lda #$0F  ; black for arrow
  sta sprpal_buf+10
.endshuffle

  ; Now that we've drawn the arrow, we can draw the card sprites
  ; under it.
  
  lda gameOverClearTransitionY
  beq :+
  jmp spriteloop_done
:

  lda #1
  sta cards_left

spriteloop:
  ; high bit set means this isn't the position of a turned-over card
  ldx cards_left
  bne to_nfc0
  lda card0FlipFrame
  bne :+
to_nfc0:
  jmp notFlippingCard0
:
  ; draw flipping card 0
  ldx oam_index
  lda selectedCards
  and #%00000111
  sta mul_temp
  asl a
  adc mul_temp
  asl a
  asl a
  asl a
  adc #15
  sta OAM,x
  sta OAM+4,x
  adc #8
  sta OAM+8,x
  sta OAM+12,x
  adc #8
  sta OAM+16,x
  sta OAM+20,x
  lda card0FlipFrame
  sta OAM+1,x
  sta OAM+5,x
  sta OAM+17,x
  sta OAM+21,x
  ora #$10
  sta OAM+9,x
  sta OAM+13,x
  lda #$02
  sta OAM+2,x
  sta OAM+10,x
  lda #$42
  sta OAM+6,x
  lda #$82
  sta OAM+18,x
  lda #$C2
  sta OAM+14,x
  sta OAM+22,x
  lda selectedCards
  and #%01111000
  sta mul_temp
  asl a
  adc #24
  adc mul_temp
  sta OAM+3,x
  sta OAM+11,x
  sta OAM+19,x
  adc #8
  sta OAM+7,x
  sta OAM+15,x
  sta OAM+23,x

  txa
  clc
  adc #24
  sta oam_index
    
  jmp card_not_selected
notFlippingCard0:
  lda selectedCards,x
  bpl card_is_selected
  jmp card_not_selected
card_is_selected:

  ; retrieve the shape of the card (28-63)
  sta this_pos
  tay

  ; calc Y position
  lda collectingY,x
  bne overriddenY
  tya
  and #%00000111
  sta mul_temp
  asl a
  adc mul_temp
  asl a
  asl a
  asl a
  adc #19
overriddenY:
  sta this_pos_y

  ; calc X position
  lda collectingX,x
  bne overriddenX
  tya  
  and #%01111000
  sta mul_temp
  asl a
  adc #24
  adc mul_temp
overriddenX:
  sta this_pos_x

  lda boardState,y
  and #%00111111
  sta thisCard
  and #%00000111
  sta mul_temp
  lda thisCard
  and #%00111000
  asl a
  ora mul_temp
  asl a

  ldx oam_index
  sta OAM+1,x
  eor #$01
  sta OAM+5,x
  eor #$11
  sta OAM+9,x
  eor #$01
  sta OAM+13,x

  ; calc the Y position
  lda this_pos_y
  sta OAM,x
  sta OAM+4,x
  adc #8
  sta OAM+8,x
  sta OAM+12,x

  ; calc the X position
  lda this_pos_x
  sta OAM+3,x
  sta OAM+11,x
  adc #8
  sta OAM+7,x
  sta OAM+15,x
  lda cards_left
  sta OAM+2,x
  sta OAM+6,x
  sta OAM+10,x
  sta OAM+14,x
  clc
  txa
  adc #16
  sta oam_index
  
  lda thisCard
  asl a
  tay
  
  ldx cards_left
  lda card_palettes-56,y
  sta sprpal_buf,x
  lda card_palettes-55,y
  sta sprpal_buf+4,x
  lda #$0F
  sta sprpal_buf+8,x
  
card_not_selected:
  dec cards_left
  bmi spriteloop_done
  jmp spriteloop
spriteloop_done:

.if ::SHOW_STATE_AND_TURN
  ldx oam_index
  lda #11
  sta OAM,x
  lda #23
  sta OAM+4,x
  lda #35
  sta OAM+8,x
  lda curState
  ora #$40
  sta OAM+1,x
  lda curTurn
  ora #$40
  sta OAM+5,x
  lda curAIState
  ora #$40
  sta OAM+9,x
  lda #2
  sta OAM+2,x
  sta OAM+6,x
  sta OAM+10,x
  lda #8
  sta OAM+3,x
  sta OAM+7,x
  sta OAM+11,x
  
  txa
  clc
  adc #12
  sta oam_index
.endif
  ; and clear the rest of the sprites
  lda #$F0
  ldx oam_index
:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne :-
  sta OAM

  rts
.endproc
--procs--
.proc blitCardSprites
  lda #VBLANK_NMI
  sta PPUCTRL
.shuffle --parts--
  ldx #0
  stx $2003
  lda #>OAM
  sta $4014
--parts--
  lda #$3F
  sta PPUADDR
  lda #$02
  sta PPUADDR
  lda bgcolor
  sta PPUDATA
--parts--
  lda #$3F
  sta PPUADDR
  lda #$10
  sta PPUADDR

  ; The sprite palette data is interleaved: instead of palette
  ; x located at 4*x+1, 4*x+2, and 4*x+3, it's located at
  ; x, x+4, and x+8.  This simplifies fast copying, and it even
  ; simplifies loading palettes indexed by player or play step.
.shuffle
  ldx #0
  ldy #$30
.endshuffle  
palloop:
  sty PPUDATA
  .repeat 3,I
  lda sprpal_buf+4*I,x
  sta PPUDATA
  .endrepeat
  inx
  cpx #4
  bcc palloop
.endshuffle
  rts
.endproc
--procs--
.proc initCollecting1Animation

  ; 1. Calculate which row and column they're in
  ldx #1
loop1:
.shuffle --coords--
  lda selectedCards,x
  and #%01111000
  lsr a
  lsr a
  lsr a
  sta collectingX,x
--coords--
  lda selectedCards,x
  and #%00000111
  sta collectingY,x
.endshuffle
  dex
  bpl loop1

  ; 2. Calculate the distance between the two cards, in 1/24 rows.
  ; That way, we add the velocity to one position and subtract it
  ; from the other over the two cards to unite them at the midpoint
  ; of the line segment between them before sending them to the
  ; player's collector.
.shuffle --coords--
  lda collectingX+1
  sec
  sbc collectingX
  sta collectingDX
--coords--
  lda collectingY+1
  sec
  sbc collectingY+0
  sta collectingDY
.endshuffle

  ; 3. Calculate the actual starting positions.
  ldx #1
loop2:
.shuffle --coords--
  lda collectingX,x
  asl a
  adc collectingX,x
  asl a
  asl a
  asl a
  adc #24
  sta collectingX,x
--coords--
  lda collectingY,x
  asl a
  adc collectingY,x
  asl a
  asl a
  asl a
  adc #18
  sta collectingY,x
.endshuffle
  dex
  bpl loop2
  rts
.endproc
--procs--
.proc clockCollecting1Animation
.shuffle --coords--
.shuffle
  lda collectingY+0
  clc
.endshuffle
  adc collectingDY
  sta collectingY+0
--coords--
.shuffle
  lda collectingX+0
  clc
.endshuffle
  adc collectingDX
  sta collectingX+0
--coords--
.shuffle
  lda collectingY+1
  sec
.endshuffle
  sbc collectingDY
  sta collectingY+1
--coords--
.shuffle
  lda collectingX+1
  sec
.endshuffle
  sbc collectingDX
  sta collectingX+1
.endshuffle
  rts
.endproc
--procs--
.proc initCollecting2Animation
.shuffle --coords--
.shuffle
  lda #212
  sec
.endshuffle
  sbc collectingY
  lsr a
  lsr a
  lsr a
  lsr a
  adc #0
  sta collectingDY
--coords--
  ldx curTurn
.shuffle
  lda scoreBoxSprX,x
  sec
.endshuffle
  sbc collectingX
  ror a
  lsr a
  lsr a
  lsr a  ; range: 00-0F negative; 10-1F positive
  adc #$F0  ; F0-FF negative; 00-10 positive; rounded to half
  sta collectingDX
--coords--
  lda #$F0  ; hide the second sprite
  sta collectingY+1
.endshuffle
  rts
.endproc
--procs--
.proc clockCollecting2Animation
.shuffle --coords--
.shuffle
  lda collectingY
  clc
.endshuffle
  adc collectingDY
  sta collectingY
--coords--
.shuffle
  lda collectingX
  clc
.endshuffle
  adc collectingDX
  sta collectingX
.endshuffle
  rts
.endproc
--procs--
.proc clearCollectingAnimation
  lda #0
.shuffle
  sta collectingX
  sta collectingX+1
  sta collectingY
  sta collectingY+1
.endshuffle
  rts
.endproc
.endshuffle

.segment "RODATA"
.shuffle --vars--
game_palette:
  ; Backdrop, unused, player 1, player 2
  .byt $0F,$10,$18,$0F,$30,$10,$00,$0F,$30,$22,$02,$0F,$30,$26,$16,$0F
  ; Card 1, card 2, cursor, unused
  ; The first entry in the palette is $0F so that the
  ; screen can be black during board setup.  It turns white again
  ; after blitCardSprites sets up the sprite palette.
--vars--
scoreBoxAddrLo:  ; scoreBox goes at $23xx in vram
  .byt $82, $90
--vars--
scoreBoxSprX:    ; where tiles go
  .byt $20, $90
--vars--
card_palettes:
  .dbyt                         $161A,$1609,$2717,$3617
  .dbyt $2919,$1018,$1018,$1016,$1018,$2202,$2716,$101A
  .dbyt $2919,$3616,$3212,$3424,$2718,$2728,$2817,$1000
  .dbyt $2811,$1011,$2616,$1000,$2717,$271A,$1602,$1602
  .dbyt $2404,$2707,$1101,$1A0A,$1000,$2919,$2A16,$1606
.endshuffle
.segment "CODE"
