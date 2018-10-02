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
.include "nes.inc"
.include "global.inc"

CREDITS_MODE = 4

; Turn this on for semipublic beta test builds that aren't officially
; released on pineight.com.  It provides notice that this build is
; not subject to the license exception for unmodified binaries.
COPYLEFT_FBI_WARNING = 0

.segment "CODE"
.shuffle --procs--
;;
; Displays a menu and lets the player choose an item.
; @param A the menu id
; @param X bitset of buttons that the player can press to exit
; @param Y the default option (0 through A-1)
; @return (bit 7 off) index of selected item
;         (bit 7 on) another button was pressed, in new_keys
.proc titleDoMenu
  selectedItem = 6
  numItems = 7
  otherButtons = 8
  
.shuffle
  sty selectedItem
  stx otherButtons
.endshuffle
  jsr titleLoadMenu
  sta numItems
  jsr titleBlitMenu

; clear out excess sprites
.shuffle
  ldx #0
  lda #$F0
.endshuffle
:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne :-

waitloop:
.shuffle --oamels--
  lda selectedItem
  asl a
  asl a
  asl a
  adc #127
  sta OAM+4
--oamels--
  lda #'>'
  sta OAM+5
--oamels--
  lda #0
  sta OAM+6
--oamels--
  lda #52
  sta OAM+7
.endshuffle  
  lda nmis
:
  cmp nmis
  beq :-
  ldy #0
.shuffle --bgbackon--
  sty PPUSCROLL
  sty PPUSCROLL
--bgbackon--
.shuffle
  sty $2003
  lda #>OAM
.endshuffle
  sta $4014
--bgbackon--
  lda #VBLANK_NMI
  sta PPUCTRL
.endshuffle
  lda #%00011110
  sta PPUMASK
  jsr pently_update
  jsr read_pads
.shuffle --keys--
  lda new_keys
  and otherButtons
  bne pressedOtherButton
--keys--
  lda new_keys
  and #KEY_UP
  beq notUp
  lda selectedItem
  beq notUp
  dec selectedItem
notUp:
--keys--
  lda new_keys
  and #KEY_DOWN
  beq notDown
  inc selectedItem
  lda selectedItem
  cmp numItems
  bcc notDown
  dec selectedItem
notDown:
.endshuffle
  lda new_keys
  and #KEY_START | KEY_A
  beq waitloop
  lda selectedItem
  rts

pressedOtherButton:
  lda #$FF
  rts
.endproc
--procs--

.proc titleScreen
NUM_MODES = 3
mode = 6
  lda #VBLANK_NMI
.shuffle
  sta PPUCTRL
  ldy #0
.endshuffle
.shuffle
  sty PPUMASK
  ldx #$3F
.endshuffle
  stx PPUADDR
.shuffle
  sty PPUADDR
  lda #$0F
.endshuffle
.shuffle
  sta PPUDATA
  ldx #$20
.endshuffle
  stx PPUADDR
.shuffle
  sty PPUADDR
  lda #< title_pkb
.endshuffle
  sta 0
  lda #> title_pkb
  sta 1
  jsr PKB_unpackblk

; load palette
  lda #$3F
.shuffle
  sta PPUADDR
  ldx #0
.endshuffle
  stx PPUADDR
:
  lda title_palette,x
.shuffle
  sta PPUDATA
  inx
.endshuffle
  cpx #32
  bcc :-

mainMenu:
.shuffle
  lda #0
  ldy #0
  ldx #KEY_SELECT
.endshuffle
  jsr titleDoMenu
  ora #0
  bpl notSelectButton
isSelectButton:
  lda #CREDITS_MODE
  rts
notSelectButton:
  beq constantDifficulty
  
difficultyMenu:
.shuffle
  pha
  ldy difficulty
.endshuffle
  cpy #5
  bcc :+
  ldy #4
:
  lda #1
  ldx #KEY_SELECT|KEY_B
  jsr titleDoMenu
  ora #0
  bmi difficultyOtherButton
  sta difficulty
  pla
constantDifficulty:
  rts
difficultyOtherButton:
  pla
  lda new_keys
  and #KEY_SELECT
.shuffle
  bne isSelectButton
  beq mainMenu
.endshuffle
.endproc
--procs--

.proc titleBlitMenu
  lda nmis
:
  cmp nmis
  beq :-
  lda PPUSTATUS
.shuffle
  lda #$22
  ldx #$00
.endshuffle
  sta PPUADDR
  stx PPUADDR
.shuffle
  stx OAMADDR
  lda #>OAM
  clc
.endshuffle
  sta OAM_DMA
:
  .repeat 16,I
  lda xferBuf+I,x
  sta PPUDATA
  .endrepeat
  txa
  adc #16
  tax
  cpx #160
  bcc :-
.shuffle --finishparts--
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
--finishparts--
  lda #VBLANK_NMI
  sta PPUCTRL
.endshuffle
  rts
.endproc
--procs--

.proc titleClearSubmenu
.shuffle
  ldx #159
  lda #0
.endshuffle
.shuffle --firstandrest--
  sta xferBuf
--firstandrest--
:
  sta xferBuf,x
  dex
  bne :-
.endshuffle
  rts
.endproc
--procs--

.proc titleLoadMenu
textBase = 0
rowStart = 2
  asl a
  tax
.shuffle --lohi--
  lda titleMenus,x
  sta textBase
--lohi--
  lda titleMenus+1,x
  sta textBase+1
.endshuffle
  jsr titleClearSubmenu
  lda #8
.shuffle
  sta rowStart
  ldy #0
.endshuffle
lineLoop:
  ldx rowStart
charLoop:
  lda (textBase),y
  beq out
  cmp #$0A
  beq newline
  sta xferBuf,x
  inx
  iny
  bne charLoop
out:
  lda rowStart
  lsr a
  lsr a
  lsr a
  lsr a
  lsr a
  rts
newline:
.shuffle
  iny
  lda rowStart
  clc
.endshuffle
  adc #32
  sta rowStart
  cmp #160
  bcc lineLoop
  bcs out
.endproc
--procs--

.proc scrollOpeningText
bgoam_y = 1
srcAddr = 6
yscroll = 8
ytimer = 9
isNewRow = 10
blankLinesAfterEndOfText = 11
fadeValue = 12
fadeTimer = 13
multemp = isNewRow

.if 0
  cmp #0
  bne notOpeningText
  jsr testOpponents
  lda #0
notOpeningText:
.endif

  asl a
  tax
.shuffle --lohi--
  lda texts,x
  sta srcAddr
--lohi--
  lda texts+1,x
  sta srcAddr+1
--lohi--
  lda #$10
  sta fadeValue
.endshuffle
  lda #0
  sta fadeTimer
  jsr pently_start_music
.shuffle
  ldx #$3F
  ldy #0
  lda #VBLANK_NMI
.endshuffle
.shuffle
  sta PPUCTRL
  sty PPUMASK
.endshuffle
  stx PPUADDR
.shuffle
  sty PPUADDR
  lda #$17  ; initial background color
.endshuffle
  sta PPUDATA
  lda #$20
  sta PPUADDR
.shuffle
  sty PPUADDR
  tya
.endshuffle
clear_nt:
  .repeat 4
    sta PPUDATA
  .endrepeat
  dey
  bne clear_nt

; data is in 2-byte packets.
; byte 0:
; bit 7: true for new row
; bit 6-0: x offset for this sprite
; byte 1:
; bit 7: flip vertical
; bit 6: flip horizontal
; bits 5-0: tile number
.shuffle
  clc
  ldx #0  ; X: sprite data offset
  lda #96
.endshuffle
  sta bgoam_y
  ;ldy #0  ; Y: hombon_map data offset
  ; but it's already 0 from the clear_nt loop
setup_oam:
  lda hombon_map,y
  bpl not_new_logo_row
  cmp #$FF
  beq setup_oam_done
  lda #8
  adc bgoam_y
  sta bgoam_y
  lda hombon_map,y
  and #%01111111
not_new_logo_row:

  ; Absolutely centered in the NES picture would be x=108.
  ; But I'll draw it at x=104 because most TV sets draw the NES
  ; picture slightly to the right of center.
  adc #104
  sta OAM+3,x
  lda bgoam_y
  sta OAM,x
  iny
  lda hombon_map,y
  and #%00111111
  beq tileIsEmpty
  sta OAM+1,x
  lda hombon_map,y
  ora #%00100011  ; behind and with palette 3
  sta OAM+2,x
  inx
  inx
  inx
  inx
tileIsEmpty:
  iny
  bpl setup_oam
setup_oam_done:

  lda #$F0
clearTheRest:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne clearTheRest

  lda nmis
:
  cmp nmis
  beq :-

.shuffle
  lda #VBLANK_NMI
  ldy #7
  ldx #12
.endshuffle
.shuffle
  sta PPUCTRL
  sty yscroll
  sty ytimer
  stx blankLinesAfterEndOfText
.endshuffle

  lda nmis
:
  cmp nmis
  beq :-
  ldx #0
.shuffle
  stx $2003
  lda #>OAM
.endshuffle
  sta $4014
  jsr read_pads

loop:
  lda #0
  sta isNewRow
  dec ytimer
  bne noYDown
  lda #6
.shuffle
  sta ytimer
  inc yscroll
.endshuffle
  ldy yscroll
  tya
  and #%00000111
  bne notNewRow
  inc isNewRow
notNewRow:
  cpy #240
  bcc noYDown
  lda #0
  sta yscroll
noYDown:
  
  lda nmis
:
  cmp nmis
  beq :-
  lda PPUSTATUS

  ; rewrite the palette
  ; fill $3F3F through $3F44 - fills the last sprite color and
  ; the first set of bg colors
  ldx #$3F
  stx PPUADDR
  stx PPUADDR
  ldx #0
load_intro_palette:
.shuffle
  sec
  lda intro_palette,x
.endshuffle
  sbc fadeValue
  bcs notBlack
  lda #$0F
notBlack:
.shuffle
  sta PPUDATA
  inx
.endshuffle
  cpx #5
  bcc load_intro_palette

  lda isNewRow
  beq dontWriteNewRow

  ; Always write to the top row of a pair of nametable rows:
  ; a multiple of 16 pixels or 64 NT bytes.
  ; First write a row of spaces when row is at the top.
  ; Then write a row of text once it has wrapped off the bottom.
  lda yscroll
  and #%11110000
  sta multemp
  lda #$08
  asl multemp
  rol a
  asl multemp
  rol a
  sta PPUADDR
  lda multemp
  ora #$02
  sta PPUADDR
  lda yscroll
  and #$08
  bne writeTextToThisRow
.shuffle
  ldx #15
  lda #' '
.endshuffle
:
  sta PPUDATA
  sta PPUDATA
  dex
  bne :-
  beq dontWriteNewRow
writeTextToThisRow:
  ldy #0
eachTextChar:
  lda (srcAddr),y
  bne :+
  dec blankLinesAfterEndOfText
  bne dontWriteNewRow
  lda fadeTimer
  bne dontWriteNewRow
  inc fadeTimer
  bne dontWriteNewRow
:
  cmp #$0A
  beq textLineFinished
  sta PPUDATA
  iny
  bne eachTextChar
textLineFinished:
  ; we come in with the carry set and (srcAddr+Y) pointing at the
  ; newline character, so add Y+srcAddr+1 to skip the newline
  tya
  adc srcAddr
  sta srcAddr
  lda #0
  adc srcAddr+1
  sta srcAddr+1
dontWriteNewRow:

  lda #0
  sta PPUSCROLL
.shuffle
  ldy yscroll
  ldx #VBLANK_NMI
  lda #%00011110
.endshuffle
.shuffle
  sty PPUSCROLL
  stx PPUCTRL
  sta PPUMASK
.endshuffle

  jsr read_pads
.shuffle --keyz--
  lda cur_keys
  and #KEY_DOWN
  beq notPressingDown
  lda #1  ; Force scrolling to happen in the next frame
  sta ytimer
notPressingDown:
--keyz--
  lda cur_keys
  and #KEY_UP
  beq notPressingUp
  lda #3  ; Force the timer to remain high enough that no scroll happens
  sta ytimer
notPressingUp:
--keyz--
  ; start the fadeout if player 1 has pressed A  
  lda new_keys
  and #KEY_START|KEY_A
  beq notPressingA
  lda fadeTimer
  bne notPressingA
  inc fadeTimer
notPressingA:
.endshuffle
  jsr pently_update
  lda fadeTimer
  beq :+
  inc fadeTimer
:
  asl a
  asl a
  and #$F0
  sta fadeValue
  cmp #$40
  bcs out
  jmp loop
out:
  jmp pently_stop_music
.endproc
.endshuffle

.if 0
.proc puthex
  pha
  lsr a
  lsr a
  lsr a
  lsr a
  jsr put1hex
  pla
  and #$0F
put1hex:
  cmp #10
  bcc :+
    adc #'a'-'0'-11
  :
  adc #'0'
  sta PPUDATA
  rts
.endproc
.endif

.segment "RODATA"
.shuffle --arrays--
texts:
  .addr openingText
  .addr instructionsText
  .addr coprNoticeText
  .addr unimplementedText
  .addr twoPlayerText
  .addr defaultChallengerText
  .addr defaultLoseText
  .addr endingText
 --arrays--
openingText:
  .byt "Once upon a time in the",$0A
  .byt "Third Realm from the Sun,",$0A
  .byt "a team of biochemists were",$0A
  .byt "perfecting a truth serum.",$0A
  .byt "Codenamed Pinenut, the serum",$0A
  .byt "was intended to make it more",$0A
  .byt "difficult for a detainee to",$0A
  .byt "keep a secret from police",$0A
  .byt "and to make the physical",$0A
  .byt "tells of deception more",$0A
  .byt "obvious.",$0A
  .byt "",$0A
  .byt "But a lab accident at",$0A
  .byt "Hombon Pharma led to the",$0A
  .byt "creation of a mildly",$0A
  .byt "neurotoxic substance.",$0A
  .byt "Lab assistants were exposed",$0A
  .byt "to this ",34,"bad batch",34,$0A
  .byt "before it could be",$0A
  .byt "properly cleaned up.",$0A
  .byt "To make things worse, it",$0A
  .byt "had to happen on Bring",$0A
  .byt "Your Child to Work Day.",$0A
  .byt "",$0A
  .byt "The assistants and their",$0A
  .byt "children were put in",$0A
  .byt "quarantine until their",$0A
  .byt "bodies eliminated the toxin.",$0A
  .byt "It caused painful seizures",$0A
  .byt "until they started thinking",$0A
  .byt "of other things to get their",$0A
  .byt "mind off the pain.",$0A
  .byt "One of the children in",$0A
  .byt "quarantine was carrying a",$0A
  .byt "deck of Concentration cards.",$0A
  .byt "It worked.",$0A
  .byt "",$0A
  .byt "The more intensely they",$0A
  .byt "thought, the more the",$0A
  .byt "side effects subsided.",$0A
  .byt "Concentrating heavily would",$0A
  .byt "reduce the concentration of",$0A
  .byt "the toxin in brain fluid,",$0A
  .byt "as it bound to waste",$0A
  .byt "products from metabolism",$0A
  .byt "in the brain.",$0A
  .byt "",$0A
instructionsText:
  .byt "Flip two cards, and if they",$0A
  .byt "match, you keep them. If",$0A
  .byt "they don't, flip them back.",$0A
  .byt "Good luck; you'll need it!",$0A,$00
--arrays--
.macro decbytes num
  .if num >= 10
    decbytes num / 10
  .endif
  .byt '0'+(num .mod 10)
.endmacro

coprNoticeText:
  .byt "Build time: "
  decbytes .time
  .byt $0A
  .byt $07," 2010 Damian Yerrick",$0A
  .byt "Comes with ABSOLUTELY NO",$0A
  .byt "WARRANTY.  This is free",$0A     
  .byt "software, and you are",$0A
  .byt "welcome to spread it",$0A  
  .byt "under certain conditions;",$0A
  .byt "see GPLv3.txt for details.",$0A,$0A
  .byt "Program by Damian Yerrick",$0A
  .byt "Graphics by Damian Yerrick",$0A
  .byt "and Sara Crickard",$0A,$0A
.if COPYLEFT_FBI_WARNING
  .byt "FIGHT COPYLEFT INFRINGEMENT!",$0A
  .byt "If your copy of this program",$0A
  .byt "came without source code,",$0A
  .byt "it may be pirated.",$0A
.endif
  .byt "Visit pineight.com/nes",$0A,$00
--arrays--
twoPlayerText:
  .byt "Press the A and B Buttons",$0A
  .byt "when the other player",$0A
  .byt "gives you the controller,",$0A
  .byt "and flip two cards.",$0A
  .byt "If they don't match, it's",$0A
  .byt "the other player's turn.",$0A
  .byt "Match more pairs than the",$0A
  .byt "other player to win.",$0A,$00
--arrays--
defaultChallengerText:
  .byt "Here comes a new challenger!",$0A,$0A
  .byt "Flip two cards, and if they",$0A
  .byt "don't match, it's my turn.",$0A
  .byt "Can you match more than me?",$0A,$00
--arrays--
defaultLoseText:
  .byt "You need more practice.",$0A
  .byt "Come play me again once",$0A
  .byt "you're thinking straight.",$0A,$00
--arrays--
unimplementedText:
  .byt "UNDER CONSTRUCTION",$0A,$0A
  .byt "This part isn't made yet.",$0A
  .byt "To get it done faster, send",$0A
  .byt "your bribe through PayPal",$0A
  .byt "to tepples@spamcop.net",$0A,$00
--arrays--
endingText:
  .byt "Good news!",$0A
  .byt "The doctor came back with",$0A
  .byt "your blood work, and the",$0A
  .byt "toxin level in your body has",$0A
  .byt "fallen below harmful level.",$0A
  .byt "You're free to go now.",$0A,$00
--arrays--
hombon_map:
  .byt $08,$10,$10,$11,$18,$50
  .byt $84,$12,$0C,$13,$14,$53,$1C,$52
  .byt $84,$14,$0C,$15,$1A,$5A
  .byt $84,$16,$0C,$17,$14,$57,$1C,$1B
  .byt $82,$18,$0A,$19,$16,$59,$1E,$1C
  .byt $82,$1A,$1E,$1D
  .byt $96,$D9,$1E,$9C
  .byt $84,$DB,$0C,$97,$14,$D7,$1C,$9B
  .byt $FF
--arrays--
intro_palette:
  .byt $20,$27,$00,$00,$0F
--arrays--
title_palette:
  .byt $30,$10,$00,$0F,$30,$10,$00,$0F,$30,$10,$00,$0F,$30,$10,$00,$0F
  .byt $30,$10,$00,$0F,$30,$10,$00,$0F,$30,$10,$00,$0F,$30,$10,$00,$0F
--arrays--
title_pkb:
  .incbin "src/litetitle.pkb"
--arrays--
titleMenus:
  .addr mainMenu, difficultyMenu
--arrays--
mainMenu:
  .byt "1 Player Story",$0A
  .byt "1 Player Solitaire",$0A
  .byt "2 Players",$0A
  .byt "Vs. CPU",$0A,$00
--arrays--
difficultyMenu:
  .byt "Preschool",$0A
  .byt "Elementary",$0A
  .byt "Junior High",$0A
  .byt "High School",$0A
  .byt "Lab Technician",$0A,$00
.endshuffle
