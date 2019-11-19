.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

.segment "ZEROPAGE"
  current_card_id: .res 1
  editor_pen_x: .res 1
  editor_pen_y: .res 1
  editor_pen_i: .res 1
  current_emblem_pixels: .res 16
  current_emblem_pal: .res 4
  palette_bg: .res 1
  palette_color_1: .res 8
  palette_color_2: .res 8
  palette_color_3: .res 8

.segment "CODE"
.proc start_editor
paint_nametables:
ppu_addr_offset = 6
card_id = 8
cycle_of_6 = 9
  ldy #$00
  sty PPUMASK
.shuffle --ntclears--
.shuffle
  tya  ;,; lda #$00
  ldx #$20
.endshuffle
  jsr ppu_clear_nt
 --ntclears--
 .shuffle
  lda #$02
  ldx #$2c
.endshuffle
  jsr ppu_clear_nt
.endshuffle

.shuffle
  lda #>$23c0
  ldy #<$23c0
.endshuffle
  sta PPUADDR
  sty PPUADDR
.shuffle
  lda #>screen_1_attribute_table_pkb
  ldy #<screen_1_attribute_table_pkb
.endshuffle
.shuffle
  sty 0
  sta 1
.endshuffle
  jsr PKB_unpackblk

.shuffle
  lda #>$2fc0
  ldy #<$2fc0
.endshuffle
  sta PPUADDR
  sty PPUADDR
.shuffle
  lda #>screen_2_attribute_table_pkb
  ldy #<screen_2_attribute_table_pkb
.endshuffle
.shuffle
  sty 0
  sta 1
.endshuffle
  jsr PKB_unpackblk

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

  jsr initalize_palette

  lda #VBLANK_NMI|OBJ_1000|BG_1000
  sta PPUCTRL

  jmp editor_select_card_mode
.endproc


.proc editor_select_card_mode
  jsr ppu_wait_vblank
  jsr upload_palette

  lda #VBLANK_NMI|OBJ_1000|BG_1000
  ldx #256-8
  ldy #0
  sec
  jsr ppu_screen_on

jam: jmp jam

  rts
.endproc

.proc editor_edit_card_mode
.shuffle
  ldx #>edit_card_text
  lda #<edit_card_text
.endshuffle
  jsr nstripe_append
  jsr popslide_terminate_blit

  jsr ppu_wait_vblank
  jsr upload_palette

  lda #VBLANK_NMI|OBJ_1000|BG_1000
  ldx #0
  ldy #0
  sec
  jsr ppu_screen_on

jam: jmp jam

  rts
.endproc

.proc editor_edit_color_mode
.shuffle
  ldx #>edit_color_text
  lda #<edit_color_text
.endshuffle
  jsr nstripe_append
  jsr popslide_terminate_blit

  rts
.endproc

.proc initalize_palette
  lda #$30
  sta palette_bg
  ldx #8-1
  init_loop:
    lda #$10
    sta palette_color_1, x
    lda #$00
    sta palette_color_2, x
    lda #$0f
    sta palette_color_3, x
    dex
  bpl init_loop
  rts
.endproc

.proc upload_palette
  lda #>$3fe0
  sta PPUADDR
  lda #<$3fe0
  sta PPUADDR
  ldx #0
  upload_loop:
    lda palette_bg
    sta PPUDATA
    lda palette_color_1, x
    sta PPUDATA
    lda palette_color_2, x
    sta PPUDATA
    lda palette_color_3, x
    sta PPUDATA
    inx
    cpx #8
  bcc upload_loop
  rts
.endproc

.segment "RODATA"
.shuffle --editor_rodata--
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

--editor_rodata--
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

--editor_rodata--
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
.endshuffle
  .byte $ff

--editor_rodata--
edit_card_text:
.shuffle --edit_card_text_parts--
  .dbyt NTXY(2,23)
  .byte 8-1, "A: draw "
--edit_card_text_parts--
  .dbyt NTXY(2,25)
  .byte 13-1, "B: pick color"
--edit_card_text_parts--
  .dbyt NTXY(19,25)
  .byte 11-1, "Start: done"
--edit_card_text_parts--
  .dbyt NTXY(2,27)
  .byte 18-1, "Select: edit color"
--edit_card_text_parts--
  .dbyt NTXY(15,25)
  .byte $40 + 4-1, $03
--edit_card_text_parts--
  .dbyt NTXY(20,27)
  .byte $40 + 10-1, $03
.endshuffle
  .byte $ff

--editor_rodata--
edit_color_text:
.shuffle --edit_color_text_parts--
  .dbyt NTXY(2,23)
  .byte 6-1, "Color "
--edit_color_text_parts--
  .dbyt NTXY(2,25)
  .byte 7-1, $0e, $0f, ": hue"
--edit_color_text_parts--
  .dbyt NTXY(21,25)
  .byte 9-1, "A: accept"
--edit_color_text_parts--
  .dbyt NTXY(2,27)
  .byte 14-1, $0c, $0d, ": brightness"
--edit_color_text_parts--
  .dbyt NTXY(21,27)
  .byte 9-1, "B: cancel"
--edit_color_text_parts--
  .dbyt NTXY(9,25)
  .byte $40 + 12-1, $03
--edit_color_text_parts--
  .dbyt NTXY(16,27)
  .byte $40 + 5-1, $03
.endshuffle
  .byte $ff

--editor_rodata--
screen_1_attribute_table_pkb:
;00000000: aa aa aa aa aa aa aa aa 66 55 aa 00 00 00 00 00  ........fU......
;00000010: 66 45 aa 00 00 00 00 00 a6 a5 aa 00 00 00 00 00  fE..............
;00000020: 22 00 aa 00 00 00 00 00 fa fa fa a0 a0 a0 a0 a0  "...............
;00000030: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff  ................
  .dbyt 64
  .byte $101-8, $aa
  .byte -1+3, $66, $55, $aa
  .byte $101-5, $00
  .byte -1+3, $66, $45, $aa
  .byte $101-5, $00
  .byte -1+3, $a6, $a5, $aa
  .byte $101-5, $00
  .byte -1+3, $22, $00, $aa
  .byte $101-5, $00
  .byte $101-3, $fa
  .byte $101-5, $a0
  .byte $101-16, $ff

--editor_rodata--
screen_2_attribute_table_pkb:
;000003c0: 95 a5 a5 a5 a5 a5 a5 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003d0: 99 ab ab ab ab ab ab 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003e0: 99 ab ab ab ab ab ab 55 99 ab ab ab ab ab ab 55  .......U.......U
;000003f0: 99 ab ab ab ab ab ab 55 55 55 55 55 55 55 55 55  .......UUUUUUUUU
  .dbyt 64
  .byte -1+1, $95
  .byte $101-6, $a5
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte -1+2, $55, $99
  .byte $101-6, $ab
  .byte $101-9, $55
.endshuffle
