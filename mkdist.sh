#!/bin/bash

make -C src || exit $?

VERSION="$(grep --context=1 'macro version_text' src/constants.beebasm|tail -1|sed -e 's/^.*equs "//g' -e 's/"$//g')"
ZIPFILE="stem-$VERSION.zip"

/bin/rm "$ZIPFILE" 2>/dev/null
# We want stem.ssd in the root of the zip file, so we junk paths for this.
zip -9vj "$ZIPFILE" src/stem.ssd
# To minimise clutter, we preserve the distinction between text files in
# the "root" of the repo and the "doc" directory in the zip file, so we
# don't junk paths in the following.
zip -9v "$ZIPFILE" doc/*.pdf doc/*.odt
# We add text files to the .zip file with CRLF endings, this way Notepad
# on Windows will display them properly, and just about any other editor
# on any platform will handle this properly. We don't use a wildcard here
# to avoid developer-only files being included.
zip -9vl "$ZIPFILE" LICENCE.txt README.txt doc/credits.txt
