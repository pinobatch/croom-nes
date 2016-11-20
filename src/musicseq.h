; Copyright 2010 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty
; provided the copyright notice and this notice are preserved.
; This file is offered as-is, without any warranty.

.global musicPatternTable, drumSFX, instrumentTable, songTable

N_C  =  0*8
N_CS =  1*8
N_D  =  2*8
N_DS =  3*8
N_E  =  4*8
N_F  =  5*8
N_FS =  6*8
N_G  =  7*8
N_GS =  8*8
N_A  =  9*8
N_AS = 10*8
N_B  = 11*8
N_DB = N_CS
N_EB = N_DS
N_GB = N_FS
N_AB = N_GS
N_BB = N_AS
N_CH  = N_C  + 12*8
N_CSH = N_CS + 12*8
N_DBH = N_DB + 12*8
N_DH  = N_D  + 12*8
N_DSH = N_DS + 12*8
N_EBH = N_EB + 12*8
N_EH  = N_E  + 12*8
N_FH  = N_F  + 12*8
N_FSH = N_FS + 12*8
N_GBH = N_GB + 12*8
N_GH  = N_G  + 12*8
N_GSH = N_GS + 12*8
N_ABH = N_AB + 12*8
N_AH  = N_A  + 12*8
N_ASH = N_AS + 12*8
N_BBH = N_BB + 12*8
N_BH  = N_B  + 12*8
N_CHH = N_CH + 12*8
N_TIE = 25*8
REST  = 26*8

D_8  = 1
D_D8 = 2
D_4  = 3
D_D4 = 4
D_2  = 5
D_D2 = 6
D_1  = 7

CON_PLAYPAT = $00   ; next: pattern, transpose (if not drums), instrument (if not drums)
CON_LOOPPAT = $10   ; as CON_PLAYPAT
CON_WAITROWS = $20  ; next: number of rows to wait minus 1
CON_FINE = $21      ; stop music now
CON_SEGNO = $22     ; set loop point
CON_DALSEGNO = $23  ; jump to loop point. if no point was set, jump to start of song.
CON_SETTEMPO = $30  ; low bits: bits 8-9 of tempo in rows/min; next: bits 0-7 of tempo

