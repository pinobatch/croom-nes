; Copyright 2010 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty
; provided the copyright notice and this notice are preserved.
; This file is offered as-is, without any warranty.

xferBuf = $0100
OAM = $0200
FIELD_WID = 9
FIELD_HT = 8
MAX_DIFFICULTY = 5

.enum PlayState
; These states have handlers
STILL
FLIPPING
UNFLIPPING
COLLECTING
PASS_CONTROLLER
CLEARED
GAME_OVER
; These must be at the bottom because there's no handler
DONE
.endenum

; reset fields
.globalzp nmis

; memorygame fields
.globalzp curState, stateTimer, card0FlipFrame, difficulty
.globalzp numPlayers, lastPlayerIsAI, score, scoreMethod
.globalzp cardToDraw, bgcolor, gameOverClearTransitionY
; memorygame methods
.global play_memory, countRemainingCards

; drawcards fields
.globalzp selectedCards, cursor_x, cursor_y, curTurn
.global boardState
; drawcards methods
.global loadPlayScreen
.global buildScoreUpdate, blitScoreUpdate, gameOverClearRow
.global buildCardTiles, blitCard
.global drawCardSprites, blitCardSprites
.global initCollecting1Animation, clockCollecting1Animation
.global initCollecting2Animation, clockCollecting2Animation
.global clearCollectingAnimation

; shuffle fields
.globalzp rand3, rand2, rand1, rand0
; shuffle methods
.global random, countCardsInPattern, shuffleCards

; pads fields
.globalzp cur_keys, new_keys, das_timer, das_keys
; pads methods
.global read_pads, autorepeat

; title methods
.global titleScreen, scrollOpeningText, puthex

; liteopponents methods
.global doOpponentScene

; unpkb methods
.global PKB_unpackblk

; Pently audio driver methods
.global pently_init, pently_start_sound, pently_update
.global pently_start_music, start_music, pently_stop_music

; bcd methods
.global bcd8bit, test_bcd8bit

; aidiocy fields
.global rememberState, curAIState, aiNoiseLevel
; aidiocy methods
.global randomCard, doAI, ysod

; ppuclear methods
.global ppu_clear_oam, ppu_clear_nt, ppu_screen_on, ppu_wait_vblank
