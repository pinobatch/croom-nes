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
.include "popslide.inc"

; Transfer buffers that haven't yet been transitioned to popslide
sprpal_buf = $0180
otherBuf = $018C  ; Unallocated from here to $01BF

; The display engine can draw the backs of remembered cards in white
; as a tool for troubleshooting AI. It's a bit glitchy on the borders
; when an adjacent card redraws.
DRAW_REMEMBERED_BACKS = 0

; Various tile indices
BLANK_TILE = $00
OUTSIDE_TABLE_TILE = $03
CARD_BACK_TILE = $04
ARROW_TILE = $06
CARDCORNERS_BASE = $20
CARDTB_BASE = $30
CARDLR_BASE = $38

.segment "ZEROPAGE"
.shuffle
selectedCards: .res 2
card0FlipFrame: .res 1
collectingX: .res 2
collectingY: .res 2
collectingDX: .res 2
collectingDY: .res 2
cursor_x: .res 1  ; 0 to 8
cursor_y: .res 1  ; 0 to 7
cursor_sprite_x: .res 1  ; 32 to 224
cursor_sprite_y: .res 1  ; 39 to 207
curTurn: .res 1         ; 0: player; 1: cpu or player 2
oam_used: .res 1
card_palette_color_1: .res 36
card_palette_color_2: .res 36
card_palette_color_3: .res 36
.endshuffle

surrounds = $01

.segment "BSS"
boardState: .res 72

.segment "CODE"
SURR_NW = 1<<7
SURR_W  = 1<<4
SURR_SW = 1<<2
SURR_N  = 1<<6
SURR_S  = 1<<1
SURR_NE = 1<<5
SURR_E  = 1<<3
SURR_SE = 1<<0

.shuffle --procs--
;;
; Finds which cards surround a given card.
; surrounds:
; 765
; 4 3
; 210
; @param x card position (0-71)
; @return surrounds ($01): which adjacent cards are present
.proc card_get_surrounds
surrounds = 1
  lda #0
  sta surrounds

; handle board corners
  cpx #0
  bne notTopLeft
  lda #SURR_NW
  sta surrounds
  bne hitLSideCorner
notTopLeft:
  cpx #7
  bne notBottomLeft
  lda #SURR_SW
  sta surrounds
  bne hitLSideCorner
notBottomLeft:
  cpx #64
  bne notTopRight
  lda #SURR_NE
  sta surrounds
  bne hitRSideCorner
notTopRight:
  cpx #71
  bne notBottomRight
  lda #SURR_SE
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
  lda #SURR_NW
  ora surrounds
  sta surrounds
skippedUL:

  lda boardState-8,x
  bpl skippedL
  lda #SURR_W
  ora surrounds
  sta surrounds
skippedL:

  txa
  and #$07
  cmp #7
  beq skippedDL
  lda boardState-7,x
  bpl skippedDL
  lda #SURR_SW
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
  lda #SURR_N
  ora surrounds
  sta surrounds
skippedU:

  txa
  and #$07
  cmp #7
  beq skippedD
  lda boardState+1,x
  bpl skippedD
  lda #SURR_S
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
  lda #SURR_NE
  ora surrounds
  sta surrounds
skippedUR:

  lda boardState+8,x
  bpl skippedR
  lda #SURR_E
  ora surrounds
  sta surrounds
skippedR:

  txa
  and #$07
  cmp #7
  beq skippedDR
  lda boardState+9,x
  bpl skippedDR
  lda #SURR_SE
  ora surrounds
  sta surrounds
skippedDR:
skippedRSide:

  rts
.endproc

--procs--
;;
; Builds the data for a single tile.
; @param x card position (0-71)
.proc buildCardTiles
card_id = $00
card_dst_lo = $02
card_dst_hi = $03

nwtile = $07
wtile = $08
swtile = $09
ntile = $0A
centertile = $0B
stile = $0C
netile = $0D
etile = $0E
setile = $0F

; tiles $20-$2F: 1 top left present, 2 top right present,
; 4 bottom left present, 8 bottom right present
; tiles $2F-$37: 1 top present, 2 top present and flipped,
; 3 bottom present, 6 bottom present and flipped
; $2F does not exist so use $20 instead
; tiles $37-$3F: 1 left present, 2 left present and flipped,
; 3 right present, 6 right present and flipped
; $37 does not exist so use $20 instead

  stx card_id
  jsr card_get_surrounds

  ; Calculate destination address
  ; top left corner: $2062
  txa
  lsr a
  lsr a
  lsr a
  sta card_dst_lo
  asl a
  adc card_dst_lo
  adc #$62
  sta card_dst_lo
  txa
  and #$07
  sta card_dst_hi
  ; at this point: card_dst_hi = tileno / 8
  asl a
  adc card_dst_hi
  ; at this point: A = (tileno / 8) * 3
  ; multiply by 32 and add $2000
  sec
  ror a
  sta card_dst_hi
  lda #0
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

  ldx #8
  lda #CARDCORNERS_BASE
clearBack2:
  sta nwtile,x
  dex
  bpl clearBack2

  ldy card_id
  asl surrounds
  bcc notUL
  inc nwtile
notUL:
  asl surrounds
  bcc notU
  inc ntile
  lda #$02
  ora nwtile
  sta nwtile
  inc netile
  lda #$40
  and boardState-1,y  ; is N card faceup?
  beq notU
  lda #CARDCORNERS_BASE|$02
  sta ntile
notU:
  asl surrounds
  bcc notUR
  lda #$02
  ora netile
  sta netile
notUR:
  asl surrounds
  bcc notL
  inc wtile
  lda #$04
  ora nwtile
  sta nwtile
  inc swtile
  lda #$40
  and boardState-8,y  ; is W card faceup?
  beq notL
  lda #CARDCORNERS_BASE+2
  sta wtile
notL:
  asl surrounds
  bcc notR
  lda #CARDCORNERS_BASE+3
  sta etile
  lda #$08
  ora netile
  sta netile
  lda #$02
  ora setile
  sta setile
  lda #$40
  and boardState+8,y  ; is E card faceup?
  beq notR
  lda #CARDCORNERS_BASE+6
  sta etile
notR:
  asl surrounds
  bcc notDL
  lda #$04
  ora swtile
  sta swtile
notDL:
  asl surrounds
  bcc notD
  lda #CARDCORNERS_BASE+3
  sta stile
  lda #$08
  ora swtile
  sta swtile
  lda #$04
  ora setile
  sta setile
  lda #$40
  and boardState+1,y  ; is S faceup?
  beq notD
  lda #CARDCORNERS_BASE+6
  sta stile
notD:
  asl surrounds
  bcc notDR
  lda #$08
  ora setile
  sta setile
notDR:

  ; All the border tiles are calculated.  Time to actually put it
  ; in the buffer.
  ldx popslide_used
  lda card_dst_hi
  sta popslide_buf+0,x
  sta popslide_buf+7,x
  sta popslide_buf+14,x
  sta popslide_buf+21,x
  lda card_dst_lo
  sta popslide_buf+1,x
  clc
  adc #1
  sta popslide_buf+8,x
  adc #1
  sta popslide_buf+15,x
  adc #1
  sta popslide_buf+22,x
  lda #$83  ; 4 bytes, down
  sta popslide_buf+2,x
  sta popslide_buf+9,x
  sta popslide_buf+16,x
  sta popslide_buf+23,x

col0 = popslide_buf+3
col1 = popslide_buf+10
col2 = popslide_buf+17
col3 = popslide_buf+24

  lda boardState,y  ; If there's a card here, put it here
  bmi cardHere
  lda #CARDCORNERS_BASE
  bne have_center_solid
cardHere:  
  ; add corners for the card in the middle
  lda #$08
  ora nwtile
  sta nwtile
  lda #$04
  ora netile
  sta netile
  lda #$02
  ora swtile
  sta swtile
  inc setile
  
  ; process sides and middle
  lda boardState,y
  and #$40
  bne flippedHere
  ; AI debugging
.if ::DRAW_REMEMBERED_BACKS
  lda rememberState,y
  bne flippedHere
.endif
  clc
  lda #3
  adc ntile
  sta ntile
  lda #3
  adc wtile
  sta wtile
  lda #1
  adc etile
  sta etile
  lda #1
  adc stile
  sta stile
  lda #CARD_BACK_TILE
  sta col1+1,x
  eor #$01
  sta col2+1,x
  eor #$11
  sta col1+2,x
  eor #$01
  bne have_center_br
flippedHere:
  clc
  lda #6
  adc ntile
  sta ntile
  lda #6
  adc wtile
  sta wtile
  lda #2
  adc etile
  sta etile
  lda #2
  adc stile
  sta stile
  lda #BLANK_TILE
have_center_solid:
  sta col1+1,x
  sta col2+1,x
  sta col1+2,x
have_center_br:
  sta col2+2,x

  ; Write out the borders
  lda nwtile
  sta col0+0,x
  lda netile
  sta col3+0,x
  lda swtile
  sta col0+3,x
  lda setile
  sta col3+3,x
  
  lda ntile
  cmp #CARDCORNERS_BASE+1
  bcc :+
    adc #CARDTB_BASE-CARDCORNERS_BASE-2
  :
  sta col1+0,x
  sta col2+0,x
  lda wtile
  cmp #CARDCORNERS_BASE+1
  bcc :+
    adc #CARDLR_BASE-CARDCORNERS_BASE-2
  :
  sta col0+1,x
  sta col0+2,x
  lda etile
  cmp #CARDCORNERS_BASE+1
  bcc :+
    adc #CARDLR_BASE-CARDCORNERS_BASE-2
  :
  sta col3+1,x
  sta col3+2,x
  lda stile
  cmp #CARDCORNERS_BASE+1
  bcc :+
    adc #CARDTB_BASE-CARDCORNERS_BASE-2
  :
  sta col1+3,x
  sta col2+3,x
  
  txa
  clc
  adc #28
  sta popslide_used

  ldy card_id
  rts
.endproc

--procs--
;;
; Clears a row of the playfield.
;
.proc gameOverClearRow
  lda gameOverClearTransitionY
  beq notClearOut
  ldx popslide_used
  sec
  ror a
  ror gameOverClearTransitionY
  lsr a
  ror gameOverClearTransitionY
  lsr a
  ror gameOverClearTransitionY
  sta popslide_buf+0,x
  lda gameOverClearTransitionY
  and #$E0
  sta popslide_buf+1,x
  lda #31|$40
  sta popslide_buf+2,x
  lda #OUTSIDE_TABLE_TILE
  sta popslide_buf+3,x
.shuffle
  txa
  clc
.endshuffle
  adc #4
  sta popslide_used
  lda #0
  sta gameOverClearTransitionY
notClearOut:
  rts
.endproc

--procs--
;;
; Makes a score update: 14 characters
;  3-16 (>[].....18..)
; 20-33 (>[].....18..)
; @param x the player for which to build the score update
; @param y nonzero: add "WIN"
.proc buildScoreUpdate
highdigits = $00
iswin = $01
.shuffle
  sty iswin
  txa
.endshuffle
.shuffle
  tay
  ldx popslide_used
  clc
.endshuffle
  lda scoreBoxAddrLo,y
  sta popslide_buf+1,x
  adc #$20
  sta popslide_buf+18,x

toprow    = popslide_buf+3
bottomrow = popslide_buf+20

.shuffle --parts--
  ; high byte
  lda #$23
.shuffle
  sta popslide_buf+0,x
  sta popslide_buf+17,x
.endshuffle
--parts--
  ; packet length
  lda #14-1
.shuffle
  sta popslide_buf+2,x
  sta popslide_buf+19,x
.endshuffle
--parts--
  ; first the endcaps
  lda #$64
  sta toprow+0,x
--parts--
  lda #$67
  sta toprow+13,x
--parts--
  ; draw player's emblem
  PLAYER_EMBLEM_TILE = $60
  tya
  asl a
  ora #PLAYER_EMBLEM_TILE
  sta toprow+2,x
  ora #$01
  sta toprow+3,x
--parts--
  ; clear space between emblem and right endcap
  sty highdigits
  SCOREBOX_BG_TILE = $66
  SCOREBOX_TURN_TILE = $65
.shuffle
  ldy #9
  lda #SCOREBOX_BG_TILE
.endshuffle
:
  sta toprow+4,x
  inx
  dey
  bne :-
  ldy highdigits
  ldx popslide_used
  ; draw turn indicator
  cpy curTurn
  bne notMyTurn
    lda #SCOREBOX_TURN_TILE
  notMyTurn:
  sta toprow+1,x
--parts--
  WORD_WIN_TILE = $4D
  lda iswin
  beq notWriteWin
.shuffle
    clc
    lda #$4D
.endshuffle
    sta toprow+5,x
    adc #1
    sta toprow+6,x
    adc #1
    sta toprow+7,x
  notWriteWin:
.endshuffle

  ; draw score
  DIGITS_BASE = $40
  lda score,y
  jsr bcd8bit
  ora #$40
  sta toprow+11,x
  lda 0
  beq tensIsZero
  cmp #16
  bcc noThirdDigit
  lsr a
  lsr a
  lsr a
  lsr a
  ora #$40
  sta toprow+9,x
  lda 0
  and #$0F
noThirdDigit:
  ora #$40
  sta toprow+10,x
tensIsZero:

.shuffle
  txa
  clc
  ldy #14
.endshuffle
  adc #34
  sta popslide_used
  endcopyloop:
    lda #$10
    ora toprow,x
    sta bottomrow,x
    inx
    dey
    bne endcopyloop
  rts
.endproc

--procs--
;;
; Loads the gameplay screen.
.proc loadPlayScreen
  jsr popslide_init
.shuffle
  lda #VBLANK_NMI
  ldx #192
.endshuffle
.shuffle
  sta cursor_sprite_x
  stx cursor_sprite_y
  sta PPUCTRL
.endshuffle
  ldy #0
.shuffle
  sty collectingY+0
  sty collectingY+1
  sty collectingX+0
  sty collectingX+1
  sty PPUMASK
  lda #$03
.endshuffle
  ldx #$20
  jsr ppu_clear_nt

  ; Set status bar attributes: 2 for player 1, 3 for player 2
.shuffle
  lda #$23
  ldx #$F8
  ldy #$0A
.endshuffle
  sta PPUADDR
.shuffle
  stx PPUADDR
  lda #$0F
.endshuffle
  .repeat 4
    sty PPUDATA
  .endrepeat
  .repeat 4
    sta PPUDATA
  .endrepeat

  ; draw the status bars
  ldx #0
  ldy #0
  jsr buildScoreUpdate
  ldx numPlayers
  dex
  beq not2players
    jsr buildScoreUpdate
  not2players:
  jsr popslide_terminate_blit
  
  ; wait for vblank to set the palette so that there isn't
  ; rainbow garbage
  jsr ppu_wait_vblank

.shuffle
  lda #$3F
  ldx #$00
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
objstrip_y = $00
objstrip_tile = $01
objstrip_attr = $02
objstrip_x = $03
objstrip_len = $04
.proc draw16x16
  jsr drawxstrip_len2
.endproc
; fallthrough
.proc draw8x16more_plus14
.shuffle
  clc
  lda #14
.endshuffle
  adc objstrip_tile
  sta objstrip_tile
.endproc
.proc draw8x16more
.shuffle --draw16x16attrs--
.shuffle
  clc
  lda #8
.endshuffle
  adc objstrip_y
  sta objstrip_y
--draw16x16attrs--
.shuffle
  clc
  lda #<-16
.endshuffle
  adc objstrip_x
  sta objstrip_x
.endshuffle
.endproc
; fall through
.proc drawxstrip_len2
  lda #2
  sta objstrip_len
.endproc
; fall through
.proc drawxstrip
  ldx oam_used
  loop:
    lda objstrip_y
    sta OAM,x
.shuffle
    inx
    lda objstrip_tile
.endshuffle
    sta OAM,x
.shuffle
    inc objstrip_tile
    inx
    lda objstrip_attr
.endshuffle
    sta OAM,x
.shuffle
    inx
    lda objstrip_x
    clc
.endshuffle
    sta OAM,x
.shuffle
    inx
    adc #8
.endshuffle
    sta objstrip_x
    dec objstrip_len
    bne loop
  stx oam_used
  rts
.endproc

--procs--
.proc drawCardSprites
mul_temp = $05

  ldx #11
  lda #0
:
  sta sprpal_buf,x
  dex
  bpl :-

  lda #0
  sta oam_used

  ; First draw the arrow sprite because it's on top.
  lda lastPlayerIsAI
  bne drawArrow
  lda curState
  cmp #PlayState::PASS_CONTROLLER
  bne drawArrow

  ; If in pass-controller mode, draw "pass the controller" message
.shuffle --passline1--
  lda #195
.shuffle
  sta cursor_sprite_y
  sta objstrip_y
.endshuffle
--passline1--
  lda #$10
  sta objstrip_tile
--passline1--
  lda #$02
  sta objstrip_attr
--passline1--
  ldy curTurn
  lda scoreBoxSprX,y
.shuffle
  sta objstrip_x
  sta cursor_sprite_x
.endshuffle
--passline1--
  lda #4
  sta objstrip_len
.endshuffle
  jsr drawxstrip
.shuffle --passline2--
  lda #3
  sta objstrip_len
--passline2--
  lda #$0B
  sta objstrip_tile
--passline2--
.shuffle
  lda #8
  clc
.endshuffle
  adc objstrip_x
  sta objstrip_x
.endshuffle
  jsr drawxstrip
  jmp arrowDone
  
drawArrow:
  ; Place the arrow at (24 * X + 32, 24 * Y + 28)
  ; If unflipping or collecting is in progress, move by (4, 8)
  lda cursor_x
  asl a
  adc cursor_x
  asl a
  asl a
  asl a
  adc #32

  ; Move down and to the right to stay out of the way of the
  ; revealed cards.  But if there are more than 8 frames left(?)
  ; in this state, don't move.
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
  ; Y nonzero means down and to the right is needed
  ldy #0
  beq afterDownRightX
isDownRightX:
  ; add 4 but we came here on a beq, and cmp/beq implies bcs
  adc #3
afterDownRightX:

  ; First order low pass filtering on the cursor position
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
  sta objstrip_x

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
  sta cursor_sprite_y
  sta objstrip_y

  lda #ARROW_TILE
  sta objstrip_tile
  lda #2
  sta objstrip_attr
  jsr draw16x16
arrowDone:

.shuffle --arrowcolors--
  lda #$30  ; white for arrow
  sta sprpal_buf+2
--arrowcolors--
  lda nmis
  and #$10
  clc
  adc #$16  ; red color for A and B buttons
  sta sprpal_buf+6
--arrowcolors--
  lda #$0F  ; black for arrow
  sta sprpal_buf+10
.endshuffle

  ; Now that we've drawn the arrow, we can draw the card sprites
  ; under it.  Don't draw them in Game Over.
  lda gameOverClearTransitionY
  beq :+
    jmp draw_no_card
  :

  ; Draw second card if upturned
  ldx #1
  jsr drawOneCard

  ; Draw card 0 if it is flipping.
  ; (Card 1 is drawn with background)
  lda card0FlipFrame
  beq notFlippingCard0
  ldx oam_used
  lda selectedCards+0
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
  sta oam_used
  jmp draw_no_card
notFlippingCard0:
  ldx #0
  jsr drawOneCard
draw_no_card:

  ; and clear the rest of the sprites
  ldx oam_used
  jmp ppu_clear_oam
.endproc

--procs--
.proc drawOneCard
mul_temp = $05
cards_left = objstrip_attr
  stx cards_left
  ldy selectedCards,x
  bpl :+
    rts
  :

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
  sta objstrip_y

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
  sta objstrip_x

  lda boardState,y
  and #%00111111
  sta mul_temp
  and #%00111000
  adc mul_temp
  asl a
  sta objstrip_tile
  jsr draw16x16

  lda mul_temp
;  asl a
  tax
  ldy cards_left
  lda card_palette_color_1-28, x
  sta sprpal_buf,y
  lda card_palette_color_2-28, x
  sta sprpal_buf+4,y
  lda card_palette_color_3-28, x
  sta sprpal_buf+8,y
  rts
.endproc

--procs--
.proc blitCardSprites
  lda #VBLANK_NMI
  sta PPUCTRL
.shuffle --parts--
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

--procs--
.proc initCardPalettes
  ldy #0
  ldx #0
  loop:
    lda default_card_palettes, y
    sta card_palette_color_1, x
    lda default_card_palettes+1, y
    sta card_palette_color_2, x
    lda #$0f
    sta card_palette_color_3, x
    inx
    iny
    iny
    cpy #36*2
  bcc loop
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
default_card_palettes:
  .dbyt                         $161A,$1609,$2717,$3617
  .dbyt $2919,$271A,$1018,$1018,$1016,$1018,$2202,$2817
  .dbyt $2716,$101A,$2616,$1000,$2811,$1011,$2718,$2728
  .dbyt $2919,$3616,$3212,$3424,$2404,$2707,$1101,$1A0A
  .dbyt $2717,$1000,$1602,$1602,$1000,$2919,$2A16,$1606
.endshuffle
.segment "CODE"
