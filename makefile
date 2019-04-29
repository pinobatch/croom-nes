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
title := croom
version := wip
objlist := \
  litemain litetitle liteopponents \
  memorygame drawcards shuffle aidiocy \
  pads ppuclear unpkb bcd pentlysound pentlymusic musicseq \
  popslide16 nstripe

CC65 = /usr/local/bin
AS65 = ca65
LD65 = ld65
CC = gcc
ifdef COMSPEC
DOTEXE := .exe
else
DOTEXE :=
endif
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/FCEUX/fceux.exe
EMU := fceux
CFLAGS = -std=gnu99 -Wall -DNDEBUG -O
CFLAGS65 = 
objdir = obj/nes
srcdir = src
imgdir = tilesets

# The Windows Python installer puts py.exe in the path, but not
# python3.exe, which confuses MSYS Make.  COMSPEC will be set to
# the name of the shell on Windows and not defined on UNIX.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

# -f while debugging code; -r while adding shuffle markup;
# neither once a module has stabilized
shufflemode = -r

objlistntsc = $(foreach o,$(objlist),$(objdir)/$(o).shuffle.o) $(objdir)/ntscPeriods.o

.PHONY: run clean dist zip all debug

run: $(title).nes
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<

# Distribution

# Actually this depends on every single file in zip.in, but currently
# we use changes to croom.nes, makefile, and README as a heuristic
# for when something was changed.  Limitation: it won't see changes
# to docs or tools.
dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in $(title).nes README.md $(objdir)/index.txt
	zip -9 -u $@ -@ < $<

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo $(title).nes >> $@
	echo zip.in >> $@

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go in this directory." > $@

# the program

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.shuffle.s: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(PY) tools/shuffle.py $(shufflemode) --pln --print-lengths $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -Isrc -o $@

# extra headers

$(objdir)/pentlysound.shuffle.o $(objdir)/pentlymusic.shuffle.o: \
  $(objdir)/pentlybss.inc

# incbins

$(objdir)/liteopponents.shuffle.o: $(srcdir)/litetable.pkb
$(objdir)/litemain.shuffle.o: $(objdir)/titlegfx.chr $(objdir)/gamegfx.chr

# the executable

all: $(title).nes

map.txt $(title).nes: nrom128.x $(objlistntsc)
	$(LD65) -C $^ -m map.txt -o $(title).nes

# graphics conversion

$(objdir)/%.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py $< $@

# audio conversion

$(objdir)/pentlybss.inc: $(srcdir)/pentlyconfig.inc
	$(PY) tools/pentlybss.py $< pentlymusicbase -o $@

$(objdir)/ntscPeriods.s: tools/mktables.py
	$(PY) $< period $@

# housekeeping

clean:
	-rm -r $(objdir)/*.s $(objdir)/*.inc $(objdir)/*.chr $(objdir)/*.o
	-rm zip.in
