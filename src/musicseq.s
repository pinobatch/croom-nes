;
; Music sequence data for Concentration Room
; Copyright 2010 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty
; provided the copyright notice and this notice are preserved.
; This file is offered as-is, without any warranty.
;

.include "pentlyseq.inc"

.segment "PENTLYDATA"
.shuffle --tables--

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

; alternating duty/volume and pitch bytes

--tables--
turn_snd:
  .byt $4F, $24, $44, $24
  .byt $4F, $29, $44, $29
  .byt $4F, $2E, $44, $2E
--tables--
shift_snd:
  .byt $4F, $30, $44, $30
--tables--
land_snd:
  .byt $8F, $13, $8D, $0F
  .byt $8B, $0C, $89, $09
  .byt $87, $07, $85, $05
  .byt $83, $03, $81, $02
--tables--
lock_snd:
  .byt $06, $03, $03, $03
--tables--
line_snd:
  .byt $4F, $27, $4E, $2A, $4D, $2C
  .byt $4C, $27, $4B, $29, $4A, $2C
  .byt $89, $27, $88, $2A, $87, $2C
  .byt $86, $27, $85, $29, $84, $2C
  .byt $83, $27, $82, $2A, $81, $2C
--tables--
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
--tables--
garbage_snd:
  .byt $4F, $10, $4D, $13, $4B, $16
  .byt $49, $19, $47, $1C, $45, $1F
--tables--
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
--tables--
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

--tables--
pently_instruments:
  ; first byte: initial duty (0/4/8/c) and volume (1-F)
  ; second byte: volume decrease every 16 frames
  ; third byte:
  ;   bit 7: cut note if half a row remains
  ;   bit 6-0: length of attack if any
  ; fourth byte: 
  .byt $88, 0, $00  ; intro bass
  .addr 0
  .byt $48, 2, $00  ; intro piano
  .addr 0

--tables--
; This soundtrack does not use drums.  Overlap the drum table
; with another table.
pently_drums:

pently_songs:
  .addr intro_conductor, cleared_conductor
--tables--
pently_patterns:
  ; patterns 0-2: intro music
  .addr intro_sq1, intro_sq2, intro_bass
  ; patterns 3-4: cleared
  .addr cleared_sq2, cleared_bass

;____________________________________________________________________
; orange screen theme

--tables--
intro_conductor:
  .byt CON_SEGNO
  .byt CON_SETTEMPO+(>220), <220
  .byt CON_PLAYPAT+2, 2, 15, 0
  .byt CON_PLAYPAT+0, 0, 15, 1
  .byt CON_WAITROWS, 1
  .byt CON_PLAYPAT+1, 1, 15, 1
  .byt CON_WAITROWS, 45
  .byt CON_DALSEGNO
--tables--
intro_sq1:
  .byt REST, N_AS, N_DSH|D_4, REST, N_GS, N_CSH|D_4
  .byt REST, N_FS, N_AS|D_4, N_TIE|D_D4
  .byte PATEND
--tables--
intro_sq2:
  .byt N_FSH|D_D4, N_FH|D_D4, N_DSH|D_D2
  .byte PATEND
--tables--
intro_bass:
  .byt N_DSH|D_D4, N_CSH|D_D4, N_B|D_D2
  .byt N_DSH|D_D4, N_CSH|D_D4, N_FS|D_D4, N_GS|D_D4
  .byte PATEND
--tables--
  
;____________________________________________________________________
; cleared theme

cleared_conductor:
  .byt CON_SETTEMPO+(>360), <360
  .byt CON_PLAYPAT+2, 4, 24, 0
  .byt CON_PLAYPAT+1, 3, 24, 1
  .byt CON_PLAYPAT+0, 4, 0, 1
  .byt CON_WAITROWS, 11
  .byt CON_FINE
--tables--
cleared_sq2:
  .byt N_G, N_A, N_G, N_F, N_E, N_D, N_C, N_E, N_G, N_CH|D_D8
  .byte PATEND
--tables--
cleared_bass:
  .byt N_CH|D_8, REST, N_G|D_8, REST, N_E|D_8, REST, N_C|D_8, REST
  .byte PATEND
.endshuffle
