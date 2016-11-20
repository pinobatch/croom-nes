;
; Music sequence data for Concentration Room
; Copyright 2010 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty
; provided the copyright notice and this notice are preserved.
; This file is offered as-is, without any warranty.
;

.include "src/musicseq.h"

.segment "RODATA"
.shuffle --tables--
musicPatternTable:
  ; patterns 0-2: intro music
  .addr intro_sq1, intro_sq2, intro_bass
  ; patterns 3-4: cleared
  .addr cleared_sq2, cleared_bass
--tables--
drumSFX:
  .byt 10, 9
--tables--
instrumentTable:
  ; first byte: initial duty (0/4/8/c) and volume (1-F)
  ; second byte: volume decrease every 16 frames
  ; third byte:
  ; bit 7: cut note if half a row remains
  .byt $88, 0, $00, 0  ; intro bass
  .byt $48, 2, $00, 0  ; intro piano
--tables--
songTable:
  .addr intro_conductor, cleared_conductor
--tables--
;____________________________________________________________________
; orange screen theme

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
  .byt 255
--tables--
intro_sq2:
  .byt N_FSH|D_D4, N_FH|D_D4, N_DSH|D_D2
  .byt 255
--tables--
intro_bass:
  .byt N_DSH|D_D4, N_CSH|D_D4, N_B|D_D2
  .byt N_DSH|D_D4, N_CSH|D_D4, N_FS|D_D4, N_GS|D_D4
  .byt 255
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
  .byt 255
--tables--
cleared_bass:
  .byt N_CH|D_8, REST, N_G|D_8, REST, N_E|D_8, REST, N_C|D_8, REST
  .byt 255
.endshuffle