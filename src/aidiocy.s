;
; Artificial idiocy for Concentration Room
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

;
; Memory is a solved game, much like Tic-Tac-Toe or Checkers.
; Artificial idiocy is designed to make a CPU-controlled player
; play imperfectly in a realistic manner to keep the game
; interesting for human players.

.include "src/nes.h"  ; for KEY_A and bsod code
.include "src/ram.h"

.enum AIState
START = 0       ; Set curAITimer to the number of random cards to forget
FORGET          ; Forget one random card per frame then find an unremembered card
FIND_KNOWN_PAIR
FIND_MATCH_FOR  ; Find the match for this card if it is remembered
.endenum

; Pino finished 72-card with 35 turns left.  For development
; purposes, he ran trials to find the right noise level to match his
; own performance.  aiNoiseLevel = 2 turned out to be not nearly
; noisy enough.
; Results before adding FIND_KNOWN_PAIR state:
; aiNoiseLevel = 4: scores 39, 50, 43, 57, 53
; aiNoiseLevel = 6: scores 47, 40, 27,  2, 19
; After adding FIND_KNOWN_PAIR:
; aiNoiseLevel = 4: scores 56, 56, 51, 57, 61
; aiNoiseLevel = 6: scores 42, 51, 45, 49, 37
; aiNoiseLevel = 8: scores 

.segment "BSS"
.shuffle
curAIState: .res 1
curAITimer: .res 1
aiNoiseLevel: .res 1
rememberState: .res FIELD_WID*FIELD_HT
.endshuffle

.segment "CODE"

.shuffle --procs--
;;
; Draws a Y-colored screen of death and freezes.  Use ldy #$02 for blue.
.proc ysod
  lda #0
.shuffle
  sta PPUMASK
  ldx #$3F
.endshuffle
  stx PPUADDR
  sta PPUADDR
  sty PPUDATA
  sta PPUSCROLL
  sta PPUSCROLL
:
  jmp :- 
.endproc
--procs--

;;
; Randomly chooses a card from the table.
; @return y: index into boardState
.proc randomCard
range = 1

  ldy #8
  jsr random  ; about 8*48 cycles; fills rand3
  jsr countRemainingCards  ; about 13*72 cycles
  tya
  beq ohshi  ; don't freeze on zero cards
not_ohshi:

  ldx #$00
calcLog2:
  inx
  asl a
  bcc calcLog2
  ror a
  sta range
  lda rand3
divloop:
  cmp range
  bcc :+
  sbc range
:
  lsr range
  dex
  bne divloop

; ok, we have A as a random number in [0..nCards-1].  Map each of
; these to a card.  The loop takes about 15*72 cycles.
  tax
  ldy #71
findCardLoop:
  lda boardState,y
  bpl emptySpace
  dex
  bmi found
emptySpace:
  dey
  bpl findCardLoop
ohshi:
  ldy #$FF
found:
  rts
.endproc
--procs--

.proc doAI
.shuffle --dispatchTasks--
  ; disable the first gamepad while doing AI
  lda #0
  sta new_keys
--dispatchTasks--
  lda curAIState
  asl a
  tax
  lda aiSteps+1,x
  pha
  lda aiSteps,x
  pha
.endshuffle
  rts
.endproc
.segment "RODATA"
aiSteps:
  .addr aiStart-1, aiForget-1, aiFindKnownPair-1, aiFindMatchFor-1
.segment "CODE"
--procs--

.proc aiStart
.shuffle --setStates--
  lda aiNoiseLevel
  sta curAITimer
--setStates--
  lda #AIState::FORGET
  sta curAIState
.endshuffle
  rts
.endproc
--procs--

.proc aiForget
  lda curAITimer
  beq timerDone
  dec curAITimer
  
  ; choose a random position on the board and forget it
  ldy #8
  jsr random
  lda rand3
  cmp #144
  bcc :+
  sbc #144
:
  cmp #72
  bcc :+
  sbc #72
:
  tay
  lda #0
.shuffle
  sta rememberState,y
  sty cardToDraw  ; if drawing remembered backs, show it forgotten
.endshuffle
  rts
timerDone:

  ; At this point, we're done forgetting; now we find a card to use.
.shuffle --setStates--
  lda #AIState::FIND_KNOWN_PAIR
  sta curAIState
--setStates--
  lda #FIELD_WID*FIELD_HT
  sta curAITimer
.endshuffle
  ; fall through to aiFindKnownPair
.endproc
;;
; Looks for a pair of matching cards among remembered cards.
.proc aiFindKnownPair

  ; as long as curAITimer > 1, search for matches
  ; because the pair has to lie between 0 and curAITimer-1
  ldy curAITimer
  dey
  bmi to_nkp
  bne findRememberedCardLoop
to_nkp:
  jmp noKnownPairs

findRememberedCardLoop:
  lda rememberState,y
  beq notRemembered
  lda boardState,y
  bmi findSecondRemembered
notRemembered:
  dey
  bpl :+
  ldy #$06  ; dark red
  jmp ysod
:
  bne findRememberedCardLoop 
  sty curAITimer
  rts
findSecondRemembered:
  sty curAITimer

  ; Search for the face-down card matching this card
  dey
  bpl :+
  ldy #$04  ; dark purple
  jmp ysod
:
findMatchLoop:
  cmp boardState,y
  beq foundMatch
  dey
  bpl findMatchLoop
  rts
foundMatch:
  lda rememberState,y
  bne matchIsRemembered
  rts
matchIsRemembered:
  lda #AIState::FIND_MATCH_FOR
  sta curAIState
  jmp moveToYAndTurn
.endproc
--procs--

.proc noKnownPairs

  ; Now look for a random unremembered card.
  ; Use X to time out the search; if we've seen all the cards,
  ; we've pretty much won the game, so just use card Y.
  jsr randomCard
  ldx #FIELD_WID*FIELD_HT
nkpSearchLoop:
  lda boardState,y
  bpl notThis
  lda rememberState,y
  beq nkpSearchDone
notThis:
  dey
  bpl :+
  ldy #FIELD_WID*FIELD_HT-1
:
  dex
  bne nkpSearchLoop

  ; we've fallen out of the loop, so everything else is a match

nkpSearchDone:
  lda #AIState::FIND_MATCH_FOR
  sta curAIState

  ; and fall through to moveToYAndTurn
.endproc
.proc moveToYAndTurn
  cpy #FIELD_WID * FIELD_HT
  bcc :+
  ldy #$08  ; red-brown
  jmp ysod
:
  ; At this point, move to card Y and turn it over.
  lda boardState,y
  bmi :+
  ldy #$28  ; yellow
  jmp ysod
: 
.shuffle --coords--
  tya
  lsr a
  lsr a
  lsr a
  and #$0F
  sta cursor_x
--coords--
  tya
  and #$07
  sta cursor_y
--coords--
  lda #KEY_A
  sta new_keys
--coords--
  lda #30
  sta curAITimer
.endshuffle
  rts
.endproc
--procs--

.proc aiFindMatchFor
  lda curAITimer
  beq ready
  dec curAITimer
  rts
ready:

  ; Search for the face-down card matching this card
  ldy selectedCards+1
  lda boardState,y
.shuffle
  and #$BF
  ora #$80
.endshuffle
  ldy #FIELD_WID*FIELD_HT-1
findMatchLoop:
  cmp boardState,y
  beq foundMatch
  dey
  bpl findMatchLoop

  ; Defensive programming: For some reason we didn't find the match,
  ; so look for a nearby face-down card.
  ; reminder: $00 removed; $40 flipping; $80 face down; $C0 face up
notFoundMatch:
  ldy #1
  jsr random
  lda rand3
  and #%00000001
  beq :+
  lda #(FIELD_WID - 2)*FIELD_HT
:
  clc
  adc #FIELD_HT
  clc
  adc selectedCards+1
  cmp #FIELD_WID*FIELD_HT
  bcc :+
  sbc #FIELD_WID*FIELD_HT
:
  tay
  ldx #FIELD_WID*FIELD_HT
notFoundLoop:

  ; AI always plays as the last player.  So if we're also the first
  ; player, make sure that the second card is NOT remembered.
  lda curTurn
  bne dontCareAboutRemembered
  lda rememberState,y
  bne skipRememberedSecond
dontCareAboutRemembered:
  lda boardState,y
  and #$C0
  cmp #$80
  beq useThisCard
skipRememberedSecond:
  dey
  bpl :+
  ldy #FIELD_WID*FIELD_HT-1
:
  dex
  bne notFoundLoop
  
  ; We should NEVER get here
  ldy #$02  ; blue
  jmp ysod

  ; but pretend we can't see the backs, so if it's not remembered,
  ; randomize it
foundMatch:
  lda rememberState,y
  beq notFoundMatch
useThisCard:
  lda #AIState::START
  sta curAIState
  jmp moveToYAndTurn
.endproc
.endshuffle
