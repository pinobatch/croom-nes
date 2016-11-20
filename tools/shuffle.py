#!/usr/bin/env python
"""

Computer programs have defects.  One of the most common is a buffer
overflow, which occurs when a program writes after the end of a
buffer and scribbles over whatever variables happen to sit after the
buffer in memory.  Managed languages such as C# and Java make buffer
overflows impossible because they check each array access against the
boundaries of the array.  But C and assembly language don't have such
luxuries.  In fact, unlike C, assembly language makes no distinction
between a scalar variable and a 1-element array, making it easy to
forget whether a variable is an array at all.

There are three times when a developer can find defects in a program:
at compile time, at run time during controlled testing, or at run
time after deployment.  Obviously, one wants to find defects earlier
when they are less expensive to fix.  Because assembly language
provides few tools for finding defects at compile time, any technique
to make run-time problems show up sooner is valuable.

Ordinarly, one can detect an overflow from the behavior of a program
when it uses what is stored after the overflowed buffer.  However,
the effects of writing after a buffer into memory that a program is
not using at the moment may not be apparent until it's too late.
One class of techniques to make overflows apparent sooner adds what
could be called a "canary in the coal mine".  Stack smash protection
measures used by modern C compilers insert explicit canary variables
near sensitive variables, but this has a few drawbacks on an 8-bit
computer:  canaries take space in memory, and checking their values
takes time.  Some operating systems for modern PCs and other
machines with memory protection hardware use address space layout
randomization (ASLR), which sets up memory so that a buffer overflow
causes an exception that the CPU traps.  But small microcontrollers
often have no memory protection.

So I propose a method that combines ideas from canaries and ASLR:
randomize the order of things in memory, so that each buffer that
can be overflowed is more likely to eventually end up before
something where the effect of the overflow is visible.  In essence,
each variable is randomly selected to be another variable's canary.
This involves an extension to 6502 assembly language that introduces
a new control command called '.shuffle'. An assembler should permute
the lines between .shuffle and .endshuffle when assembling the
program, so that variables end up in a different order each time
the program is assembled.  For example:

.shuffle
foo: .res 32
bar: .res 4
baz: .res 4
cnut: .res 32
.endshuffle

might become

cnut: .res 32
baz: .res 4
foo: .res 32
bar: .res 4

It's also useful for finding overflows that fall off the end of a
read-only data segment.  For these, you'll want to permute chunks
longer than one line, which is why the .shuffle keyword takes an
optional delimiter argument.

.shuffle THE_GAME
title_screen:
  .byt ...
  .byt ...
THE_GAME
character_menu:
  .byt ...
  .byt ...
THE_GAME
stage_menu:
  .byt ...
  .byt ...
.endshuffle

The .shuffle command also helps to document the data flow within a
program.  If lines of code can be executed in no particular order,
such as 'lda' and 'clc' instructions, putting them in a .shuffle
block lets others know that this is the case.

Another potential application even after you have found and fixed
buffer overflows is binary watermarking.  If you are distributing
copies of a program under nondisclosure agreement, you can covertly
mark each copy uniquely by permuting the subroutines and variables.

This program ordinarily shuffles based on randomness provided by the
operating system.  But it also has command-line options to force
a specific order: forward, reverse, or with a seed derived from
a string.  This is useful because sometimes, .shuffle itself can
lead to defects when it turns out that a program's correctness did
in fact depend on order.  To make sure that your .shuffle commands
are semantics-preserving, first test each program with all modules
shuffled forward and again with all modules shuffled in reverse.

The output of this preprocessor doesn't have the .shuffle commands.
This means line numbers in your assembler's error messages won't
necessarily match line numbers in the original source code file.
So there is another option to preserve line numbers by making a
blank line where the shuffle command hits, which makes the line
numbers correct when you force forward order.

It's fairly easy to integrate this into a makefile.  One way
reshuffles the file every time you change the source code:

AS65 = ca65

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.shuffle.s: $(srcdir)/%.s
	tools/shuffle.py $< -o $@

Or changing the seed to be based on the file name would let you
freeze the order while you investigate a given defect:

$(objdir)/%.shuffle.s: $(srcdir)/%.s
	tools/shuffle.py $< --seed 345$< -o $@

Further reading:

Article on Wikipedia about explicit instruction-level parallelism
http://en.wikipedia.org/wiki/Explicitly_parallel_instruction_computing

"Software Watermarking: Models and Dynamic Embeddings"
by C. Collberg and C. Thomborson of the University of Auckland
http://www.cs.arizona.edu/~collberg/Research/Publications/CollbergThomborson99a/

"""
from __future__ import with_statement
import sys
import random
versionText = """0.02
Copyright 2010 Damian Yerrick
Copying and distribution of this file, with or without
modification, are permitted in any medium without royalty
provided the copyright notice and this notice are preserved.
This file is offered as-is, without any warranty.
"""

class BlocksReader(object):
    def __init__(self, seq, terminator, sep=None):
        self.lines = []
        self.stopped = False
        self.seq = seq
        self.terminator = terminator
        self.sep = sep

    def __iter__(self):
        return self

    def __repr__(self):
        return ("BlocksReader(%s, %s, %s)"
                % (repr(self.seq), self.terminator, self.sep))

    def next(self):
        if self.stopped:
            raise StopIteration
        if self.sep is None:
            line = self.seq.next()
            if line.strip() == self.terminator:
                self.stopped = True
                raise StopIteration
            return line

        # if we have a separator, read lines and combine them
        lines = []
        while True:
            try:
                line = self.seq.next()
            except StopIteration:
                self.stopped = True
                return ''.join(lines)
            stripped = line.strip()
            if stripped == self.terminator:
                self.stopped = True
                return ''.join(lines)
            if stripped == self.sep:
                return ''.join(lines)
            lines.append(line)

class ShuffledReader(object):

    def __init__(self, seq, rng=random, preserveLineNumbers=False):
        self.seq = iter(seq)
        self.rng = rng
        self.bookends = '\n' if preserveLineNumbers else ''
        self.factorials = []

    def __iter__(self):
        return self

    def next(self):
        line = self.seq.next()  # raises StopIteration here
        splitLine = line.split(None, 1)
        if len(splitLine) == 0:
            return line
        cmd = splitLine[0]
        args = splitLine[1].strip() if len(splitLine) > 1 else None
        if cmd == '.shuffle':
            inner = ShuffledReader(self.seq, self.rng, self.bookends)
            lines = list(BlocksReader(inner, '.endshuffle', args))
            if len(lines) > 1:
                self.factorials.append(len(lines))
            self.factorials.extend(inner.factorials)
            self.rng.shuffle(lines)
            between = self.bookends if args is not None else ''
            return self.bookends + between.join(lines) + self.bookends
        else:
            return line

class ForwardShuffle(object):
    def shuffle(self, ls):
        pass

class ReverseShuffle(object):
    def shuffle(self, ls):
        ls.reverse()

def main(argv=None):
    from optparse import OptionParser
    if argv is None:
        argv = sys.argv
    parser = OptionParser(usage="%prog [options] [FILE...]",
                          version=versionText)
    parser.add_option("-f", "--forward",
                      action="store_false", dest="reverse",
                      help="shuffle all blocks in forward order")
    parser.add_option("-r", "--reverse",
                      action="store_true", dest="reverse",
                      help="shuffle all blocks in reverse order")
    parser.add_option("-l", "--print-lengths",
                      action="store_true", dest="printLengths",
                      help="write lengths of shuffled blocks to stderr")
    parser.add_option("-s", "--seed",
                      dest="seed",
                      help="seed the random number generator with a string",
                      metavar="SEEDSTRING")
    parser.add_option("-o", "--output", dest="outfile",
                      help="write shuffled output to OUTFILE", metavar="OUTFILE")
    parser.add_option("-U", "--universal-newlines",
                      action="store_true", dest="universalNewlines", default=False,
                      help="convert line endings (CR/LF) in input and output files")
    parser.add_option("--pln", "--preserve-line-numbers",
                      action="store_true", dest="preserveLineNumbers", default=False,
                      help="insert blank lines to compensate for removed .shuffle commands")
    (options, filenames) = parser.parse_args(argv[1:])
    if options.outfile is None:
        outfp = sys.stdout
    else:
        outfp = open(options.outfile,
                     'wt' if options.universalNewlines else 'wb')
    if options.reverse is False:
        rng = ForwardShuffle()
    elif options.reverse is True:
        rng = ReverseShuffle()
    else:
        rng = random.Random(options.seed)
    if len(filenames) == 0:
        reader = ShuffledReader(sys.stdin, rng,
                                options.preserveLineNumbers)
        for line in reader:
            outfp.write(line)
    else:
        readMode = 'rU' if options.universalNewlines else 'rb'
        for filename in filenames:
            with open(filename, readMode) as infp:
                reader = ShuffledReader(infp, rng,
                                        options.preserveLineNumbers)
                for line in reader:
                    outfp.write(line)
    if options.outfile is not None:
        outfp.close()
    if options.printLengths and len(reader.factorials) > 0:
        import math
        lengths = "".join('%d!' % l for l in reader.factorials)
        product = 1
        for l in reader.factorials:
            product *= math.factorial(l)
        print >>sys.stderr, "%s = %d" % (lengths, product)

if __name__=='__main__':
    main()
##    main('shuffle --pln -U shuffletest.txt -o test.out.txt'.split())
