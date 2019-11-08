.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

.segment "CODE"
.proc start_editor
ppu_addr_offset = 6
card_id = 8
cycle_of_6 = 9
  ldy #$00
  sty PPUMASK
.shuffle --ntclears--
.shuffle
  lda #$00
  ldx #$20
.endshuffle
  tay
  jsr ppu_clear_nt
 --ntclears--
 .shuffle
  lda #$02
  ldx #$2c
  ldy #$ab
.endshuffle
  jsr ppu_clear_nt
.endshuffle

  jsr popslide_init
.shuffle
  ldx #>editor_screen_data
  lda #<editor_screen_data
.endshuffle
  jsr nstripe_append
  jsr popslide_terminate_blit

.shuffle
  ldx #>editor_screen_2_data
  lda #<editor_screen_2_data
.endshuffle
  jsr nstripe_append
  jsr popslide_terminate_blit

  lda #28
  sta card_id
  lda #<$2c63
  sta ppu_addr_offset+0
  lda #>$2c63
  sta ppu_addr_offset+1
  lda #$100-6
  sta cycle_of_6

draw_cards_loop:
  ; first load up the card template
.shuffle
  ldx #>card_data
  lda #<card_data
.endshuffle
  jsr nstripe_append

  ; then setting the X pointer to the start ...
  lda popslide_used
  sec
  sbc #card_data_size-1
  tax

  ; we'll edit it in place
  clc
  lda card_id
  and #%00111000
  adc card_id
  asl a
  sta popslide_buf+11, x
  clc
  adc #$10
  sta popslide_buf+12, x
  clc
  adc #$0100-$10+$01
  sta popslide_buf+18, x
  clc
  adc #$10
  sta popslide_buf+19, x

  ; I'm assuming that the low byte of PPUADDR won't cross a page in this loop.
  ldy #4
  :
    lda ppu_addr_offset+1
    sta popslide_buf+0, x
    lda ppu_addr_offset+0
    sta popslide_buf+1, x
    clc
    adc #1
    sta ppu_addr_offset+0
    txa
    clc
    adc #7
    tax
    dey
  bne :-
  jsr popslide_terminate_blit

  ; advance to the next card
  inc cycle_of_6
  bne not_next_row
    clc
    lda ppu_addr_offset+0
    adc #(32*4)-(4*6)
    sta ppu_addr_offset+0
    bcc :+
      inc ppu_addr_offset+1
    :
    lda #$100-6
    sta cycle_of_6
  not_next_row:
  ldy card_id
  iny
  sty card_id
  cpy #$40
  bcc draw_cards_loop


  lda #VBLANK_NMI|OBJ_1000|BG_1000
  sta PPUCTRL

;  lda #>$2c00
;  sta PPUADDR
;  lda #<$2c00
;  sta PPUADDR
;  lda #<screen_2_data
;  sta data_ptr+0
;  lda #>screen_2_data
;  sta data_ptr+1
;  ldx #4
;  ldy #$00
;  upload_loop_outer:
;    upload_loop_inner:
;      lda (data_ptr), y
;      sta PPUDATA
;      iny
;    bne upload_loop_inner
;    inc data_ptr+1
;    dex
;  bne upload_loop_outer

;  ldx popslide_used
;
;  sta popslide_buf+0, x
;
;  stx popslide_used
;  jsr popslide_terminate_blit

jam: jmp jam
.endproc

.segment "RODATA"

;screen_2_data:
;  .incbin "src/card-selection.bin"

card_data:
  .dbyt $0c00 + NTXY(0,0)
  .byte $80 + (4-1), $28, $3d, $3d, $22
  .dbyt $0c00 + NTXY(1,0)
  .byte $80 + (4-1), $35, $00, $10, $31
  .dbyt $0c00 + NTXY(2,0)
  .byte $80 + (4-1), $35, $01, $11, $31
  .dbyt $0c00 + NTXY(3,0)
  .byte $80 + (4-1), $24, $39, $39, $21
  .byte $ff
card_data_end:

card_data_size = card_data_end - card_data

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

  .dbyt NTXY(1,3)
  .byte $00 + (1-1), $28
--screen_data_parts--
  .dbyt NTXY(2,3)
  .byte $40 + (6-1), $35
--screen_data_parts--
  .dbyt NTXY(8,3)
  .byte $00 + (1-1), $24
--screen_data_parts--
  .dbyt NTXY(1,4)
  .byte $c0 + (10-1), $3d
--screen_data_parts--
  .dbyt NTXY(8,4)
  .byte $c0 + (10-1), $38
--screen_data_parts--
  .dbyt NTXY(1,14)
  .byte $00 + (1-1), $22
--screen_data_parts--
  .dbyt NTXY(2,14)
  .byte $40 + (6-1), $30
--screen_data_parts--
  .dbyt NTXY(8,14)
  .byte $00 + (1-1), $21
--screen_data_parts--

  .dbyt NTXY(2,15)
  .byte $00 + (1-1), $28
--screen_data_parts--
  .dbyt NTXY(3,15)
  .byte $40 + (4-1), $35
--screen_data_parts--
  .dbyt NTXY(7,15)
  .byte $00 + (1-1), $24
--screen_data_parts--
  .dbyt NTXY(2,16)
  .byte $c0 + (4-1), $3d
--screen_data_parts--
  .dbyt NTXY(7,16)
  .byte $c0 + (4-1), $38
--screen_data_parts--
  .dbyt NTXY(2,20)
  .byte $00 + (1-1), $22
--screen_data_parts--
  .dbyt NTXY(3,20)
  .byte $40 + (4-1), $30
--screen_data_parts--
  .dbyt NTXY(7,20)
  .byte $00 + (1-1), $21
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
.endshuffle
  .byte $ff

editor_screen_2_data:
.shuffle --screen_data_2_parts--
  .dbyt $0c00 + NTXY(0,1)
  .byte $00 + (1-1), $28
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(1,1)
  .byte $40 + (28-1), $35
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(29,1)
  .byte $00 + (1-1), $24
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(0,2)
  .byte $c0 + (26-1), $3d
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(29,2)
  .byte $c0 + (26-1), $38
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(0,28)
  .byte $00 + (1-1), $22
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(1,28)
  .byte $40 + (28-1), $30
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(29,28)
  .byte $00 + (1-1), $21
--screen_data_2_parts--

  .dbyt $0c00 + NTXY(1,2)
  .byte $c0 + (26-1), $00
--screen_data_2_parts--
  .dbyt $0c00 + NTXY(28,2)
  .byte $c0 + (26-1), $00
--screen_data_2_parts--
  .dbyt NTXY(31,0)
  .byte $c0 + (30-1), $02

;000003c0: 95 a5 a5 a5 a5 a5 a5 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003d0: 99 ab ab ab ab ab ab 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003e0: 99 ab ab ab ab ab ab 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003f0: 99 ab ab ab ab ab ab 55 55 55 55 55 55 55 55 55  .......UUUUUUUUU
; This may not be the best data structure for attributes
--screen_data_2_parts--
  .dbyt $2fc0
  .byte $00 + (1-1), $95
--screen_data_2_parts--
  .dbyt $2fc1
  .byte $40 + (6-1), $a5
--screen_data_2_parts--
  .dbyt $2fc7
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2fcf
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2fd7
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2fdf
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2fe7
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2fef
  .byte $00 + (2-1), $55, $99
--screen_data_2_parts--
  .dbyt $2ff7
  .byte $40 + (9-1), $55
.endshuffle
  .byte $ff
