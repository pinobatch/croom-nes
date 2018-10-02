; sound.s
; Pently audio engine 0.02

;;; Copyright (C) 2009 Damian Yerrick
;
;   This program is free software; you can redistribute it and/or
;   modify it under the terms of the GNU General Public License
;   as published by the Free Software Foundation; either version 3
;   of the License, or (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to 
;     Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;     Boston, MA  02111-1307, USA.
;
;   Visit http://www.pineight.com/ for more information.

.import periodTableLo, periodTableHi
.importzp pently_zp_state  ; a 32 byte buffer in zp?
.import update_music, update_music_ch, music_playing
.export pently_init, pently_start_sound, pently_update, pentlyBSS

; turn this off to force all square wave sound effects to
; be played on $4000 (and not $4004)
.define SQUARE_POOLING 1


SNDCHN = $4015

.segment "BSS"
pentlyBSS: .res 64

psg_sfx_datalo = pently_zp_state + 0
psg_sfx_datahi = pently_zp_state + 1
psg_sfx_lastfreqhi = pently_zp_state + 18
psg_sfx_remainlen = pently_zp_state + 19
psg_sfx_rate = pentlyBSS + 3
psg_sfx_ratecd = pentlyBSS + 19

.segment "CODE"

;;
; Initializes all sound channels.
;
.proc pently_init
  lda #$0F
  sta SNDCHN
  lda #$30
  sta $4000
  sta $4004
  sta $400C
  sta psg_sfx_lastfreqhi+0
  sta psg_sfx_lastfreqhi+8
  sta psg_sfx_lastfreqhi+4
  lda #8
  sta $4001
  sta $4005
  lda #0
  sta $4003
  sta $4007
  sta $400F
  sta psg_sfx_remainlen+0
  sta psg_sfx_remainlen+4
  sta psg_sfx_remainlen+8
  sta psg_sfx_remainlen+12
  sta music_playing
  lda #64
  sta $4011
  rts
.endproc

;;
; Starts a sound effect.
; @param A sound effect number (0-63)
;
.proc pently_start_sound
snddatalo = 0
snddatahi = 1
sndchno = 2
sndlen = 3
sndrate = 4

  asl a
  asl a
  tax
  lda pently_sfx_table,x
  sta snddatalo
  lda pently_sfx_table+1,x
  sta snddatahi
  lda pently_sfx_table+2,x
  and #$0C
  sta sndchno
  lda pently_sfx_table+2,x
  lsr a
  lsr a
  lsr a
  lsr a
  sta sndrate
  
  lda pently_sfx_table+3,x
  sta sndlen

  ; split up square wave sounds between $4000 and $4004
  .if SQUARE_POOLING
    lda sndchno
    bne not_ch0to4  ; if not ch 0, don't try moving it
      lda psg_sfx_remainlen+4
      cmp psg_sfx_remainlen
      bcs not_ch0to4
      lda #4
      sta sndchno
    not_ch0to4:
  .endif 

  ldx sndchno
  lda sndlen
  cmp psg_sfx_remainlen,x
  bcs ch_not_full
  rts
ch_not_full:

  lda snddatalo
  sta psg_sfx_datalo,x
  lda snddatahi
  sta psg_sfx_datahi,x
  lda sndlen
  sta psg_sfx_remainlen,x
  lda sndrate
  sta psg_sfx_rate,x
  lda #0
  sta psg_sfx_ratecd,x
  rts
.endproc


;;
; Updates sound effect channels.
;
.proc pently_update
  jsr update_music
  ldx #12
loop:
  jsr update_music_ch
  jsr update_one_ch
  dex
  dex
  dex
  dex
  bpl loop
  rts
.endproc

.proc update_one_ch
  lda psg_sfx_remainlen,x
  bne ch_not_done
  lda 2
  bne update_channel_hw

  ; Turn off the channel and force a reinit of the length counter.
  cpx #8
  beq not_triangle_kill
    lda #$30
  not_triangle_kill:
  sta $4000,x
  lda #$FF
  sta psg_sfx_lastfreqhi,x
  rts
ch_not_done:

  ; playback rate divider
  dec psg_sfx_ratecd,x
  bpl rate_divider_cancel
  lda psg_sfx_rate,x
  sta psg_sfx_ratecd,x

  ; fetch the instruction
  lda psg_sfx_datalo+1,x
  sta 1
  lda psg_sfx_datalo,x
  sta 0
  clc
  adc #2
  sta psg_sfx_datalo,x
  bcc :+
  inc psg_sfx_datahi,x
:
  ldy #0
  lda (0),y
  sta 2
  iny
  lda (0),y
  sta 3
  dec psg_sfx_remainlen,x

update_channel_hw:
  lda 2
  ora #$30
  cpx #12
  bne notnoise
  sta $400C
  lda 3
  sta $400E
rate_divider_cancel:
  rts

notnoise:
  sta $4000,x
  ldy 3
.ifdef PAL
  iny
.endif
  lda periodTableLo,y
  sta $4002,x
  lda periodTableHi,y
  cmp psg_sfx_lastfreqhi,x
  beq no_change_to_hi_period
  sta psg_sfx_lastfreqhi,x
  sta $4003,x
no_change_to_hi_period:

  rts
.endproc

.segment "RODATA"
pently_sfx_table:
  .addr turn_snd
  .byt 0, 6
  .addr shift_snd
  .byt 0, 2
  .addr land_snd
  .byt 0, 8
  .addr lock_snd
  .byt 12, 2
  .addr line_snd
  .byt 0, 15
  .addr homer_snd
  .byt 0, 25
  .addr garbage_snd
  .byt 0, 6
  .addr die1_snd
  .byt 48+0, 17
  .addr die2_snd
  .byt 48+12, 17
  .addr snare_snd
  .byt 12, 8
  .addr kick_snd
  .byt 12, 8

; alternating duty/volume and pitch bytes

turn_snd:
  .byt $4F, $24, $44, $24
  .byt $4F, $29, $44, $29
  .byt $4F, $2E, $44, $2E
shift_snd:
  .byt $4F, $30, $44, $30
land_snd:
  .byt $8F, $13, $8D, $0F
  .byt $8B, $0C, $89, $09
  .byt $87, $07, $85, $05
  .byt $83, $03, $81, $02
lock_snd:
  .byt $06, $03, $03, $03
line_snd:
  .byt $4F, $27, $4E, $2A, $4D, $2C
  .byt $4C, $27, $4B, $29, $4A, $2C
  .byt $89, $27, $88, $2A, $87, $2C
  .byt $86, $27, $85, $29, $84, $2C
  .byt $83, $27, $82, $2A, $81, $2C
homer_snd:
  .byt $4F, $27, $4E, $2A, $4D, $2C
  .byt $4C, $27, $4B, $29, $4A, $2C
  .byt $89, $27, $88, $2A, $87, $2C
  .byt $86, $27
  .byt $4F, $2a, $4E, $2d, $4D, $2f
  .byt $4C, $2a, $4B, $2c, $4A, $2f
  .byt $89, $2a, $88, $2d, $87, $2f
  .byt $86, $2a, $85, $2c, $84, $2f
  .byt $83, $2a, $82, $2d, $81, $2f
garbage_snd:
  .byt $4F, $10, $4D, $13, $4B, $16
  .byt $49, $19, $47, $1C, $45, $1F
die1_snd:
  .byt $0F, $07
  .byt $0F, $07
  .byt $0E, $07
  .byt $0D, $07
  .byt $0C, $07
  .byt $0B, $07
  .byt $0A, $07
  .byt $09, $07
  .byt $08, $07
  .byt $07, $07
  .byt $06, $07
  .byt $05, $07
  .byt $04, $07
  .byt $03, $07
  .byt $02, $07, $01, $07, $01, $07
die2_snd:
  .byt $0F, $0C
  .byt $0F, $0D
  .byt $0E, $0E
  .byt $0D, $0E
  .byt $0C, $0E
  .byt $0B, $0E
  .byt $0A, $0E
  .byt $09, $0E
  .byt $08, $0E
  .byt $07, $0E
  .byt $06, $0E
  .byt $05, $0E
  .byt $04, $0E
  .byt $03, $0E
  .byt $02, $0E, $01, $0E, $01, $0E
snare_snd:
  .byt $0A, $04, $08, $04, $06, $04
  .byt $05, $04, $04, $04, $03, $04, $02, $04, $01, $04
kick_snd:
  .byt $08,$04,$08,$0D,$06,$0E
  .byt $05,$0E,$04,$0E,$03,$0E,$02,$0E,$01,$0E
