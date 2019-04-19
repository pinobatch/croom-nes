;
; Pently audio engine
; Sound effect player and "mixer"
; Copyright 2009-2018 Damian Yerrick
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

.include "pentlyconfig.inc"
.include "pently.inc"
.if PENTLY_USE_MUSIC
  .import pently_update_music, pently_update_music_ch
.endif
.import periodTableLo, periodTableHi, pently_sfx_table
.if PENTLY_USE_PAL_ADJUST
  .importzp tvSystem
.endif
.export pentlyBSS
.exportzp pently_zp_state

.assert (pently_zptemp + 5) <= $100, error, "pently_zptemp must be within zero page"

SNDCHN = $4015

PULSE1_CH = $00
PULSE2_CH = $04
TRIANGLE_CH = $08
NOISE_CH = $0C
SFX_CHANNEL_BITS = $0C
ATTACK_TRACK = $10

.zeropage
.if PENTLY_USE_MUSIC = 0
  PENTLYZP_SIZE = 16
.elseif PENTLY_USE_ATTACK_PHASE
  PENTLYZP_SIZE = 32
.else
  PENTLYZP_SIZE = 21
.endif
pently_zp_state: .res PENTLYZP_SIZE
sfx_datalo = pently_zp_state + 0
sfx_datahi = pently_zp_state + 1

.bss
; The statically allocated prefix of pentlyBSS
pentlyBSS: .res 18

sfx_rate = pentlyBSS + 0
sfx_ratecd = pentlyBSS + 1
ch_lastfreqhi = pentlyBSS + 2
sfx_remainlen = pentlyBSS + 3

.segment PENTLY_CODE
pentlysound_code_start = *

;;
; Initializes all sound channels.
; Call this at the start of a program or as a "panic button" before
; entering a long stretch of code where you don't call pently_update.
;
.proc pently_init
  ; Turn on all channels
  lda #$0F
  sta SNDCHN
  ; Disable pulse sweep
  lda #8
  sta $4001
  sta $4005
  ; Invalidate last frequency high byte
  lda #$30
  sta ch_lastfreqhi+0
  sta ch_lastfreqhi+4
  ; Ignore length counters and use software volume
  sta $4000
  sta $4004
  sta $400C
  lda #$80
  sta $4008
  ; Clear high period, forcing a phase reset
  asl a
  sta $4003
  sta $4007
  sta $400F
  ; Clear sound effects state
  sta sfx_remainlen+0
  sta sfx_remainlen+4
  sta sfx_remainlen+8
  sta sfx_remainlen+12
  sta sfx_ratecd+0
  sta sfx_ratecd+4
  sta sfx_ratecd+8
  sta sfx_ratecd+12
  .if ::PENTLY_USE_MUSIC
    sta pently_music_playing
  .endif
  ; Set DAC value, which controls pulse vs. not-pulse balance
  lda #PENTLY_INITIAL_4011
  sta $4011
  rts
.endproc

;;
; Starts a sound effect.
; (Trashes pently_zptemp+0 through +4 and X.)
;
; @param A sound effect number (0-63)
;
.proc pently_start_sound
snddatalo = pently_zptemp + 0
snddatahi = pently_zptemp + 1
sndlen    = pently_zptemp + 3
sndrate   = pently_zptemp + 4

  asl a
  asl a
  tax
  lda pently_sfx_table,x
  sta snddatalo
  lda pently_sfx_table+1,x
  sta snddatahi
  lda pently_sfx_table+2,x
  lsr a
  lsr a
  lsr a
  lsr a
  sta sndrate
  lda pently_sfx_table+3,x
  sta sndlen
  lda pently_sfx_table+2,x
  and #SFX_CHANNEL_BITS
  tax

  ; Split up square wave sounds between pulse 1 ($4000) and
  ; pulse 2 ($4004) depending on which has less data left to play
  .if ::PENTLY_USE_SQUARE_POOLING
    bne not_ch0to4  ; if not ch 0, don't try moving it
      lda sfx_remainlen+4
      cmp sfx_remainlen
      bcs not_ch0to4
      ldx #4
    not_ch0to4:
  .endif 

  ; If this sound effect is no shorter than the existing effect
  ; on the same channel, replace the current effect if any
  lda sndlen
  cmp sfx_remainlen,x
  bcc ch_full
    sta sfx_remainlen,x
    lda snddatalo
    sta sfx_datalo,x
    lda snddatahi
    sta sfx_datahi,x
    lda sndrate
    sta sfx_rate,x
    sta sfx_ratecd,x
  ch_full:

  rts
.endproc

;;
; Updates sound effect channels.
;
.proc pently_update
  .if ::PENTLY_USE_MUSIC
    jsr pently_update_music
  .endif
  ldx #NOISE_CH
loop:
  .if ::PENTLY_USE_MUSIC
    jsr pently_update_music_ch
  .endif
  jsr pently_update_one_ch
  dex
  dex
  dex
  dex
  bpl loop
  .if ::PENTLY_USE_ATTACK_TRACK
    ldx #ATTACK_TRACK
    jmp pently_update_music_ch
  .else
    rts
  .endif
.endproc

out_volume   = pently_zptemp + 2
out_pitch    = pently_zptemp + 3
out_pitchadd = pently_zptemp + 4

.proc pently_update_one_ch
srclo        = pently_zptemp + 0
srchi        = pently_zptemp + 1

  ; At this point, pently_update_music_ch should have left
  ; duty and volume in out_volume and pitch in out_pitch.
  lda sfx_remainlen,x
  bne ch_not_done
  
    ; Only music is playing on this channel, no sound effect
    .if ::PENTLY_USE_MUSIC
      lda out_volume
      .if ::PENTLY_USE_VIS
        sta pently_vis_dutyvol,x
      .endif
      bne update_channel_hw
    .endif

    ; Turn off the channel and force a reinit of the length counter.
    cpx #TRIANGLE_CH
    beq not_triangle_kill
      lda #$30
    not_triangle_kill:
    sta $4000,x
    lda #$FF
    sta ch_lastfreqhi,x
    rts
  ch_not_done:

  ; Get the sound effect word's address
  lda sfx_datalo+1,x
  sta srchi
  lda sfx_datalo,x
  sta srclo

  ; Advance if playback rate divider says so
  dec sfx_ratecd,x
  bpl no_next_word
    clc
    adc #2
    sta sfx_datalo,x
    bcc :+
      inc sfx_datahi,x
    :
    lda sfx_rate,x
    sta sfx_ratecd,x
    dec sfx_remainlen,x
  no_next_word:

  ; fetch the instruction
  ldy #0
  .if ::PENTLY_USE_MUSIC
    .if ::PENTLY_USE_MUSIC_IF_LOUDER
      lda out_volume
      pha
      and #$0F
      sta out_volume
      lda (srclo),y
      and #$0F

      ; At this point: A = sfx volume; out_volume = music volume
      cmp out_volume
      pla
      sta out_volume
      bcc update_channel_hw
    .endif
    .if ::PENTLY_USE_VIBRATO || ::PENTLY_USE_PORTAMENTO
      sty out_pitchadd  ; sfx don't support fine pitch adjustment
      .if ::PENTLY_USE_VIS
        tya
        sta pently_vis_pitchlo,x
      .endif
    .endif
  .endif
  lda (srclo),y
  sta out_volume
  iny
  lda (srclo),y
  sta out_pitch
  ; jmp update_channel_hw
.endproc

.proc update_channel_hw
  ; XXX vis does not work with no-music
  .if ::PENTLY_USE_VIS
    lda out_pitch
    sta pently_vis_pitchhi,x
  .endif
  lda out_volume
  .if ::PENTLY_USE_VIS
    sta pently_vis_dutyvol,x
  .endif
  ora #$30
  cpx #NOISE_CH
  bne notnoise
    sta $400C
    lda out_pitch
    sta $400E
    rts
  notnoise:

  ; If triangle, keep linear counter load (bit 7) on while playing
  ; so that envelopes don't terminate prematurely
  .if ::PENTLY_USE_TRIANGLE_DUTY_FIX
    cpx #8
    bne :+
    and #$0F
    beq :+
      ora #$80  ; for triangle keep bit 7 (linear counter load) on
    :
  .endif

  sta $4000,x
  ldy out_pitch
  .if ::PENTLY_USE_PAL_ADJUST
    ; Correct pitch for PAL NES only, not NTSC (0) or PAL famiclone (2)
    lda tvSystem
    lsr a
    bcc :+
      iny
  :
  .endif

  lda periodTableLo,y
  .if ::PENTLY_USE_VIBRATO || ::PENTLY_USE_PORTAMENTO
    clc
    adc out_pitchadd
    sta $4002,x
    lda out_pitchadd
    and #$80
    bpl :+
      lda #$FF
    :
    adc periodTableHi,y
  .else
    sta $4002,x
    lda periodTableHi,y
  .endif
  cpx #8
  beq always_write_high_period
  cmp ch_lastfreqhi,x
  beq no_change_to_hi_period
  sta ch_lastfreqhi,x
always_write_high_period:
  sta $4003,x
no_change_to_hi_period:

  rts
.endproc

PENTLYSOUND_SIZE = * - pentlysound_code_start

; aliases for cc65
_pently_init = pently_init
_pently_start_sound = pently_start_sound
_pently_update = pently_update
