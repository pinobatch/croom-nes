;
; Concentration Room game logic
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

USE_SELECT_FOR_SLOWDOWN = 1
USE_B_FOR_RANDOM = 1
BOUNDS_CHECKING = 0

.segment "ZEROPAGE"
.shuffle
curState: .res 1
stateTimer: .res 1
cardToDraw: .res 1  ; card to redraw next frame
isCombo: .res 1  ; nonzero if the last was a combo
bgcolor: .res 1
gameOverClearTransitionY: .res 1
difficulty: .res 1
numPlayers: .res 1
lastPlayerIsAI: .res 1
scoreMethod: .res 1  ; 0: decrement on miss; 1: increment on match
score: .res 2  ; one for each player

; The game supports passing 1 controller or using 2 controllers.
activePad: .res 1  ; shows which controller the player is using
das_timer: .res 2  ; one for each pad
das_keys: .res 2  ; one for each pad
.endshuffle

.segment "CODE"
.shuffle --procs--
.proc play_memory
  lda #0
.shuffle
  sta curTurn
  sta gameOverClearTransitionY
  sta curAIState
  sta isCombo
  sta activePad
.endshuffle
  jsr shuffleCards
  lda #$18
  sta bgcolor
  jsr loadPlayScreen

.shuffle --thingstoinit--
  lda #PlayState::STILL
  sta curState
--thingstoinit--
  lda #4
  sta cursor_x
--thingstoinit--
  lda #3
  sta cursor_y
--thingstoinit--  
  lda #$FF
.shuffle
  sta selectedCards+0
  sta selectedCards+1
.endshuffle
--thingstoinit--
  ; Draw all the face-down cards to VRAM
  ldx #FIELD_HT*FIELD_WID-1
.endshuffle

allCardsLoop:
.shuffle
  stx cardToDraw
  lda #0
.endshuffle
  sta rememberState,x  ; clear CPU-remembered state of this card
  jsr buildCardTiles
  jsr popslide_terminate_blit
  ldx cardToDraw
  dex
  bpl allCardsLoop
  
cardsLoop:
  jsr read_pads
  ldx activePad
  jsr autorepeat
  lda curState
  cmp #PlayState::PASS_CONTROLLER
  beq notRight
  
  ldx activePad
.shuffle --keyz--
  lda new_keys,x
  and #KEY_UP
  beq notUp
  lda cursor_y
  beq notUp
  dec cursor_y
notUp:
--keyz--
  lda new_keys,x
  and #KEY_LEFT
  beq notLeft
  lda cursor_x
  beq notLeft
  dec cursor_x
notLeft:
--keyz--
  lda new_keys,x
  and #KEY_DOWN
  beq notDown
  lda cursor_y
  cmp #FIELD_HT - 1
  bcs notDown
  inc cursor_y
notDown:
--keyz--
  lda new_keys,x
  and #KEY_RIGHT
  beq notRight
  lda cursor_x
  cmp #FIELD_WID - 1
  bcs notRight
  inc cursor_x
notRight:
.endshuffle
  ; other keys like A and B are handled by the state handlers
  jsr stateDispatch

.shuffle --preps--
  ldx cardToDraw
  bmi :+
    jsr buildCardTiles
  :
--preps--
  jsr drawCardSprites
--preps--
  jsr pently_update
--preps--
  jsr gameOverClearRow
.endshuffle

  ; all done; now wait for vblank and blit the damn things
.if ::USE_SELECT_FOR_SLOWDOWN
  ldx #1
  lda #KEY_SELECT
  and cur_keys
  beq mainSlowdown
  ldx #15
.endif
mainSlowdown:
  jsr ppu_wait_vblank
.if ::USE_SELECT_FOR_SLOWDOWN
  dex
  bne mainSlowdown
.endif
  lda #0
.shuffle
  sta PPUMASK
  sta $2003
  bit PPUSTATUS
.endshuffle
  lda #>OAM
  sta $4014
.shuffle --thingstoblit--
  jsr blitCardSprites
--thingstoblit--
  jsr blitScoreUpdate
.endshuffle
  ; Call popslide last because it may draw things in column order,
  ; not row order.
  jsr popslide_terminate_blit
.shuffle
  lda #VBLANK_NMI|BG_1000|OBJ_1000
  ldx #0
  ldy #12
  sec
.endshuffle
  jsr ppu_screen_on
  lda curState
  cmp #PlayState::DONE
  beq exit
  jmp cardsLoop
exit:
  rts
.endproc
--procs--

.proc stateDispatch
  lda curState
.if ::BOUNDS_CHECKING
  cmp #7
  bcc ok
  ldy #2
  jmp ysod
ok:
.endif
  asl a
  tax
  lda stateHandlers+1,x
  pha
  lda stateHandlers,x
  pha
  rts
  
stateHandlers:
  .addr handleStateStill-1, handleStateFlipping-1
  .addr handleStateUnflipping-1, handleStateCollecting-1
  .addr handleStatePassController-1, handleStateCleared-1
  .addr handleStateGameOver-1
.endproc
--procs--

.proc handleStateCleared
  ldx curTurn
  lda score,x
  tay
  jsr buildScoreUpdate
  dec stateTimer
  beq done
  rts
done:
  lda #PlayState::DONE
  sta curState
  sec
  sbc #$04
  ; fall through to still
.endproc
.proc handleStateStill
.if ::USE_B_FOR_RANDOM
  ldx activePad
  lda new_keys,x
  and #KEY_B
  beq notB
  lda #1
  jsr pently_start_sound
  jsr randomCard
  cpy #72
  bcc :+
  ldy #71
:
  tya
  and #$07
  sta cursor_y
  tya
  lsr a
  lsr a
  lsr a
  and #$0F
  sta cursor_x
notB:
.endif

  lda #0
  sta card0FlipFrame
  lda lastPlayerIsAI
  beq notAI
  lda numPlayers
  clc
  sbc curTurn
  bne notAI
  jsr doAI
notAI:

  ldx activePad
  lda new_keys,x
  and #KEY_A
  beq notA

  ; make sure the card is flipped over first
  lda cursor_x
  asl a
  asl a
  asl a
  ora cursor_y
  tay
.shuffle --notAreasons--
  cpy selectedCards+1  ; if same as other card, skip
  beq notA
--notAreasons--
  cpy selectedCards  ; if same as this card, skip
  beq notA
--notAreasons--
  lda boardState,y  ; if no card is there, skip
  bpl notA
.endshuffle

.shuffle
  sty selectedCards
  sty cardToDraw
.endshuffle
  lda boardState,y
  and #$3F
  ora #$40
  sta boardState,y
.shuffle --setFlippingState--
  lda #PlayState::FLIPPING
  sta curState
--setFlippingState--
  lda #0
  jsr pently_start_sound
--setFlippingState--
  lda #$08
  sta card0FlipFrame
--setFlippingState--
  lda #5
  sta stateTimer
.endshuffle
notA:
  rts
.endproc
--procs--

.proc handleStateFlipping
  lda stateTimer
  beq readyToFinish
notFirstFrame:  
  dec stateTimer
  lda stateTimer  ; $05-$00
  lsr a           ; $02-$00
.shuffle
  eor #$03        ; $01-$03
  clc
.endshuffle
  adc #$07        ; $08-$0A
  sta card0FlipFrame
  rts
readyToFinish:
  ldy selectedCards
  bmi nothingSelected
  sty cardToDraw
  lda boardState,y
  ora #$C0
.shuffle
  sta boardState,y
  sta rememberState,y
.endshuffle
  
  ; if the other card isn't flipped, swap these
  ldx selectedCards+1
  bpl hasCard2
  sty selectedCards+1
.shuffle --back2still--
  ldy #$FF
  sty selectedCards
--back2still--
  lda #PlayState::STILL
  sta curState
.endshuffle
nothingSelected:
  lda #0
  sta card0FlipFrame
  rts
hasCard2:

  ; After the player turns over the second card, move the arrow
  ; cursor out of the way if it's not already on the bottom row.
  ; 2010-03-24: We no longer do this because blargg suggested a
  ; better way, namely nudging the arrow by a few pixels and
  ; nudging it back.
.shuffle --notMatchIfNotFlip--
  ldx selectedCards
  bmi isNotMatch
--notMatchIfNotFlip--
  ldy selectedCards+1
  bmi isNotMatch
.endshuffle
  lda boardState,x
  eor boardState,y
  and #$3F
  bne isNotMatch

  lda #4
  ldx isCombo
  beq :+
  lda #5
:
  jsr pently_start_sound
  lda #1
  sta isCombo
  lda #PlayState::COLLECTING
  bne dgafMatch
isNotMatch:
.shuffle --toUnflipping--
  lda #2
  jsr pently_start_sound
--toUnflipping--
  lda #0
  sta isCombo
.endshuffle
  lda #PlayState::UNFLIPPING

dgafMatch:
  sta curState
  lda #90
  sta stateTimer
  jmp nothingSelected
.endproc
--procs--

.proc handleStateUnflipping
  lda stateTimer
  beq timeToUnflip
  dec stateTimer
  cmp #89
  bne notLoseScore
.shuffle --notLoseReasons--
  lda scoreMethod
  bne notLoseScore
--notLoseReasons--
  ldx curTurn
  lda score,x
  beq notLoseScore
.endshuffle
  dec score,x
  bne notGameOverSound
  
  ; play game over sound
.shuffle --setStates--
  lda #$06
  sta bgcolor
--setStates--
  lda #7
  jsr pently_start_sound
--setStates--
  lda #8
  jsr pently_start_sound
--setStates--
  lda #PlayState::GAME_OVER
  sta curState
.endshuffle
  ldx curTurn
notGameOverSound:
  ldy #0
  jsr buildScoreUpdate
notLoseScore:
  lda stateTimer
  cmp #6
  bcs noAnimateYet

  ; Start to unflip the cards
  cmp #5
  bne notFirstUnflipFrame
.shuffle --startToUnflip--
  lda #3
  jsr pently_start_sound
--startToUnflip--
  ldy selectedCards
.shuffle
  sty cardToDraw
  lda boardState,y
.endshuffle
  and #$3F
  ora #$40
  sta boardState,y
.endshuffle
  lda stateTimer
notFirstUnflipFrame:
  lsr a
  clc
  adc #$08
  sta card0FlipFrame
  rts
timeToUnflip:
  ldy selectedCards
  sty cardToDraw
.shuffle --deselect--
  lda boardState,y
  and #$3F
  ora #$80
  sta boardState,y
--deselect--
  lda #$FF
  sta selectedCards
.endshuffle
  lda selectedCards+1
  bpl secondCardNeedsUnflipped

  lda numPlayers
  cmp #2
  bcs multiplayer
  lda #0
  sta curAIState
  lda scoreMethod
  ora score
  bne notFailed
  lda #PlayState::DONE
  bne setCurState
notFailed:
  lda #PlayState::STILL
setCurState:
  sta curState
noAnimateYet:
  lda #0
  sta card0FlipFrame
  rts

secondCardNeedsUnflipped:
  sta selectedCards
.shuffle --setupSecondCard--
  lda #$FF
  sta selectedCards+1
--setupSecondCard--
  lda #6
  sta stateTimer
.endshuffle
  bne noAnimateYet

multiplayer:
  lda curTurn
  tax
  inx
  cpx numPlayers
  bcc noWrapAroundToFirstPlayer
  ldx #0
noWrapAroundToFirstPlayer: 
  stx curTurn
  ; hide old arrow
.shuffle
  tax
  ldy #0
.endshuffle
  jsr buildScoreUpdate
  lda #PlayState::PASS_CONTROLLER
  sta curState
  bne noAnimateYet
  ; fall through to handleStateCollecting
.endproc
.proc handleStateCollecting
  lda stateTimer
  beq timeToUnflip
  dec stateTimer
  cmp #28
  beq start1Anim
  bcs noCoalesceYet
  cmp #16
  beq start2Anim
  bcs continue1Anim
  jmp clockCollecting2Animation
start1Anim:
  jsr initCollecting1Animation
  ldy selectedCards+1
.shuffle
  sty cardToDraw
  lda #$3F
.endshuffle
  and boardState,y
  sta boardState,y
already1Anim:
  jsr clockCollecting1Animation
noCoalesceYet:
  lda #0
  sta card0FlipFrame
  rts
continue1Anim:
  ldy selectedCards
.shuffle
  sty cardToDraw
  lda #$3F
.endshuffle
  and boardState,y
  sta boardState,y
  bpl already1Anim
start2Anim:
  jmp initCollecting2Animation
timeToUnflip:
  ldy selectedCards
.shuffle
  sty cardToDraw
  lda #0
.endshuffle
  sta boardState,y
  lda #$FF
  sta selectedCards
  lda selectedCards+1
  bpl secondCardNeedsUnflipped

  ldx curTurn
  lda scoreMethod
  beq notAddScore
  inc score,x
notAddScore:
  ldy #0
  jsr buildScoreUpdate
  jsr clearCollectingAnimation
  jsr countRemainingCards
  cpy #0
  beq noCardsLeft
  lda numPlayers
  cmp #2
  bcc notVs
  
  ; Compute maximum possible score for other player
  ; as (nCardsLeft / 2) + otherPlayerCards
  lda curTurn
  eor #1
  tax
  tya
  lsr a
  clc
  adc score,x
  sta 0
  
  ; if score >= maxPossibleScore then give summary judgment.
  ldx curTurn
.shuffle
  sec
  lda score,x
.endshuffle
  sbc 0
  bcs noCardsLeft

notVs:
.shuffle --setstates--
  lda #0
  sta curAIState
--setstates--
  lda #PlayState::STILL
  sta curState
.endshuffle
  rts
noCardsLeft:
  lda lastPlayerIsAI  ; no CPU player in the game: win for player.
  beq setWin
  ldx numPlayers  ; no human player in the game: win for CPU.
  dex
  beq setWin
  cpx curTurn  ; current player is not the CPU: win.
  bne setWin

  ; so if we have a cpu player and a human player, and it's the CPU
  ; player's turn, it's a lose.
.shuffle --setstates--
  lda #90
  sta stateTimer
--setstates--
  lda #PlayState::GAME_OVER
  sta curState
--setstates--
  lda #$06
  sta bgcolor
--setstates--
  lda #7
  jsr pently_start_sound
.endshuffle
  lda #8
  jmp pently_start_sound
setWin:
.shuffle --setstates--
  lda #180
  sta stateTimer
--setstates--
  lda #PlayState::CLEARED
  sta curState
.endshuffle
  lda #1
  jmp pently_start_music
secondCardNeedsUnflipped:
  sta selectedCards
  lda #$FF
  sta selectedCards+1
  rts
.endproc
--procs--

.proc handleStatePassController
.shuffle
  ldx curTurn
  ldy #0
.endshuffle
  jsr buildScoreUpdate

  lda lastPlayerIsAI
  beq notPassingToAI
.ifdef WITH_FOUR_SCORE  ; deluxe version might allow >2 players
  lda nPlayers
  cmp #3
  bcc notPassingToAI
  clc
  sbc curTurn
  bne notPassingToAI
.endif
  lda #PlayState::STILL
  sta curState
  jmp done
notPassingToAI:

  ; find which keys
  ldx #1
padLoop:
  lda cur_keys,x
  and #KEY_A|KEY_B
  cmp #KEY_A|KEY_B
  bne notAPlusB
  and new_keys,x
  bne pressedAPlusB
notAPlusB:
  dex
  bpl padLoop
  rts
pressedAPlusB:
.shuffle
  stx activePad
  lda #1
.endshuffle
  jsr pently_start_sound

done:
  ; Cancel autorepeat so that keypresses from logging in don't
  ; leak into turning cards over. 
.shuffle --setStates--
.shuffle
  ldx activePad
  lda #0
.endshuffle
--setStates--
  sta das_keys,x
  lda #PlayState::STILL
  sta curState
.endshuffle
  rts
.endproc
--procs--

.proc handleStateGameOver
  lda stateTimer
  bne notDone
  lda #PlayState::DONE
  sta curState
notDone:
  dec stateTimer
  cmp #26
  bcc clearToCenter
  rts
clearToCenter:

  ; The playfield occupies rows 3 to 27 of the first nametable.
  ; We want to clear one row per frame: 
  lsr a      ; 12+ 12- 11+ 11- [...] 1+ 1- 0+
  bcc :+
  eor #$FF
:            ; 243+ 12- 244+ 11- [...] 254+ 1- 255+
  adc #15    ; 3 12 4 11 [...] 14 16 15
  sta gameOverClearTransitionY
  rts
.endproc
--procs--

;;
; Counts the cards remaining in the field.
; @return y: number of cards
.proc countRemainingCards
  ldx #FIELD_WID*FIELD_HT-1
  ldy #0
lookForCardsLeft:
  lda boardState,x
  bpl :+
  iny
:
  dex
  bpl lookForCardsLeft
  rts
.endproc
.endshuffle
