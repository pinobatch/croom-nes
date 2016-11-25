#!/usr/bin/make -f
#
# Makefile for Concentration Room
# Copyright 2010 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
version = 0.02
objlist = litemain litetitle liteopponents \
          memorygame drawcards shuffle aidiocy \
          pads sound music musicseq unpkb bcd

CC65 = /usr/local/bin
AS65 = ca65
LD65 = ld65
CC = gcc
ifdef COMSPEC
DOTEXE := .exe
EMU := start
else
DOTEXE :=
EMU := fceux
endif
CFLAGS = -std=gnu99 -Wall -DNDEBUG -O
CFLAGS65 = 
objdir = obj/nes
srcdir = src
imgdir = tilesets

# -f while debugging code; -r while adding shuffle markup;
# neither once a module has stabilized
shufflemode = -r

objlistntsc = $(foreach o,$(objlist),$(objdir)/$(o).shuffle.o) $(objdir)/ntscPeriods.o

.PHONY: run clean dist zip

run: croom.nes
	$(EMU) $<

# Actually this depends on every single file in zip.in, but currently
# we use changes to croom.nes, makefile, and README as a heuristic
# for when something was changed.  Limitation: it won't see changes
# to docs or tools.
dist: zip
zip: ConcentrationRoom-$(version).zip
ConcentrationRoom-$(version).zip: zip.in croom.nes README.html $(objdir)/index.txt
	zip -9 -u $@ -@ < $<

$(objdir)/index.txt: makefile
	echo Files produced by build tools go here, but caulk goes where? > $@

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.shuffle.s: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	tools/shuffle.py $(shufflemode) --pln --print-lengths $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -Isrc -o $@

$(objdir)/ntscPeriods.s: tools/mktables.py
	$< period $@

$(objdir)/palPeriods.s: tools/mktables.py
	$< period $@

$(objdir)/litetitle.shuffle.o: $(srcdir)/litetitle.pkb

$(objdir)/liteopponents.shuffle.o: $(srcdir)/litetable.pkb

map.txt croom.prg: NROM.ini $(objlistntsc)
	$(LD65) -C $^ -m map.txt -o croom.prg

$(objdir)/titlegfx.chr: $(imgdir)/titlegfx.png
	tools/pilbmp2nes.py $< $@

$(objdir)/gamegfx.chr: $(imgdir)/gamegfx.png
	tools/pilbmp2nes.py $< $@

%.nes: %.prg %.chr
	cat $^ > $@

croom.chr: $(objdir)/titlegfx.chr $(objdir)/gamegfx.chr
	cat $^ > $@

clean:
	rm -r $(objdir)/*

