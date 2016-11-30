#!/bin/sh

# Simple build script as an alternative to the makefile.

set -e
python make-table.py > table.beebasm
(cd tests; python compile.py) # returns to this directory afterwards
beebasm -i tests/memmove-test.beebasm -o tests/generated/memmove.bbc -v >tests/generated/memmove.lst
beebasm -w -i stem.beebasm -do stem.ssd -opt 3 -title "STEM" -v >stem.lst
