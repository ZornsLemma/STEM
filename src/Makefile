# Auto-dependency generation based on
# http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
# but no doubt implemented badly; it does seem to work though.

# We go out of our way to avoid the .ssd files ever being deleted; even
# clean just truncates them. This avoids problems during development where
# an emulator which has the .ssd file open retains access to that old file
# once it's deleted and doesn't automatically see the new, unrelated file
# of the same name. Instead, we truncate them to zero size and touch them
# to an old date so subsequent makes will try to rebuild them rather than
# reporting "nothing to do". (beebasm never deletes the output file on
# error; it just leaves a truncated and partially written file in place. We
# do a full truncation because it's easy and to make it obvious in the 
# emulator.)

SSDS=stem.ssd
OTHER_TARGETS=tags table.beebasm tests/generated/memmove.bbc

.PHONY: all
all: $(SSDS) $(OTHER_TARGETS)

.PHONY: clean
clean:
	rm -f $(OTHER_TARGETS) \
	      $(patsubst %.ssd,%.lst,$(SSDS)) \
	      $(patsubst %.ssd,%.d,$(SSDS)) \
	      tests/generated/*
	for SSD in $(SSDS); do > $$SSD; touch -c --date=yesterday $$SSD; done

# We touch the .d file at the end of this recipe since if it's left as-is, it's
# newer than the .ssd file so a subsequent make will rebuild even if nothing's 
# changed.
%.ssd: %.beebasm %.d
	beebasm -w -i $< -do $@ -opt 3 -title "STEM" -v >$(patsubst %.ssd,%.lst,$@) \
		|| (> $@; touch -c --date=yesterday $@; false)
	python beebasm-depends.py -o $@ $< > $(patsubst %.beebasm,%.d.tmp,$<)
	mv $(patsubst %.beebasm,%.d.tmp,$<) $(patsubst %.beebasm,%.d,$<)
	touch --reference=$@ $(patsubst %.beebasm,%.d,$<)

%.d: ;
.PRECIOUS: %.d

# We list these generated dependencies of stem.ssd directly; beebasm-depends.py
# will correctly deduce them, but after a "make clean" the next make would
# fail if we didn't also list them here. TODO: It might be possible to avoid
# this.
stem.ssd: table.beebasm tests/generated/tests.dat tests/generated/memmove.bbc

# TODO: It would be nice (but we've mostly got by without it) to be able to
# crunch (at a minimum, strip out REM statements) the .bas files to temporary
# copies and have stem.beebasm include those instead. (Or extend BeebAsm to
# support crunching of BASIC files when adding them to the ssd.)

table.beebasm: make-table.py
	python make-table.py > $@

tests/generated/tests.dat: tests/compile.py tests/manual/*.dat
	cd tests; python compile.py

tests/generated/memmove.bbc: tests/memmove-test.beebasm memmove.beebasm
	beebasm -i $< -o $@ -v >$(patsubst %.bbc,%.lst,$@) \
		|| (> $@; touch -c --date=yesterday $@; false)

tags: *.beebasm
	beebasm-tags *.beebasm

-include $(patsubst %.ssd,%.d,$(SSDS))
