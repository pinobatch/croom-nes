.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

.segment "CODE"
.proc start_editor
  lda #$00
  sta PPUMASK

.shuffle --ntclears--
  lda #$00
  ldx #$20
  jsr ppu_clear_nt
 --ntclears--
  lda #$02
  ldx #$2c
  jsr ppu_clear_nt
.endshuffle

  jsr popslide_init
.shuffle
  ldx #>editor_screen_data
  lda #<editor_screen_data
.endshuffle
  jsr nstripe_append
  jsr popslide_terminate_blit

;  ldx popslide_used
;
;  sta popslide_buf+0, x
;
;  stx popslide_used
;  jsr popslide_terminate_blit

  ldx #VBLANK_NMI|OBJ_1000|BG_1000
  stx PPUCTRL

jam: jmp jam

  rts
.endproc

.segment "RODATA"
editor_screen_data:
.shuffle --screen_data_parts--
  .dbyt NTXY(12,3)
  .byte $40 + (16-1), $03
--screen_data_parts--
  .dbyt NTXY(10,5)
  .byte $c0 + (16-1), $03
--screen_data_parts--
  .dbyt NTXY(12,22)
  .byte $40 + (16-1), $03
--screen_data_parts--
  .dbyt NTXY(29,5)
  .byte $c0 + (16-1), $03
--screen_data_parts--
  .dbyt NTXY(2,3)
  .byte $40 + (6-1), $35
--screen_data_parts--
  .dbyt NTXY(1,4)
  .byte $c0 + (10-1), $3d
--screen_data_parts--
  .dbyt NTXY(2,14)
  .byte $40 + (6-1), $31
--screen_data_parts--
  .dbyt NTXY(8,4)
  .byte $c0 + (10-1), $39
--screen_data_parts--
  .dbyt NTXY(3,15)
  .byte $40 + (4-1), $35
--screen_data_parts--
  .dbyt NTXY(2,16)
  .byte $c0 + (4-1), $3d
--screen_data_parts--
  .dbyt NTXY(3,20)
  .byte $40 + (4-1), $31
--screen_data_parts--
  .dbyt NTXY(7,16)
  .byte $c0 + (4-1), $39
--screen_data_parts--
  .dbyt NTXY(2,4)
  .byte $40 + (6-1), $02
--screen_data_parts--
  .dbyt NTXY(2,5)
  .byte $c0 + (8-1), $02
--screen_data_parts--
  .dbyt NTXY(7,5)
  .byte $c0 + (8-1), $02
--screen_data_parts--
  .dbyt NTXY(2,13)
  .byte $40 + (6-1), $02
; 64 bytes at this moment
--screen_data_parts--
  .dbyt NTXY(3,5)
  .byte $80 + (8-1), $28, $3a, $3a, $22, $28, $3d, $3d, $22
--screen_data_parts--
  .dbyt NTXY(4,5)
  .byte $80 + (8-1), $32, $04, $14, $30, $35, $00, $00, $31
--screen_data_parts--
  .dbyt NTXY(5,5)
  .byte $80 + (8-1), $32, $05, $15, $30, $35, $00, $00, $31
--screen_data_parts--
  .dbyt NTXY(6,5)
  .byte $80 + (8-1), $24, $38, $38, $21, $24, $39, $39, $21
--screen_data_parts--
  .dbyt NTXY(5,16)
  .byte $40 + (2-1), $02
--screen_data_parts--
  .dbyt NTXY(5,17)
  .byte $40 + (2-1), $02
--screen_data_parts--
  .dbyt NTXY(3,18)
  .byte $00 + (4-1), $01, $01, $03, $03
--screen_data_parts--
  .dbyt NTXY(3,19)
  .byte $00 + (4-1), $01, $01, $03, $03
--screen_data_parts--
; Second screen borders
  .dbyt $0c00 + NTXY(2,1)
  .byte $40 + (28-1), $35
--screen_data_parts--
  .dbyt $0c00 + NTXY(1,2)
  .byte $c0 + (26-1), $3d
--screen_data_parts--
  .dbyt $0c00 + NTXY(2,28)
  .byte $40 + (28-1), $31
--screen_data_parts--
  .dbyt $0c00 + NTXY(30,2)
  .byte $c0 + (26-1), $39
.endshuffle
  .byte $ff
