REM TODO: This can probably be enhanced. Some ideas:
REM - we should run in both modes 0 and 3
REM - we could benchmark some STEM-only behaviour (e.g. bold text)
REM   to allow performance regressions to be caught

ON ERROR writeable%=FALSE:GOTO 100
writeable%=TRUE
*SPOOL O.TestSp
*SPOOL

100old_at%=@%
ON ERROR @%=old_at%:REPORT:PRINT " at line ";ERL:END

DIM test$(10)
DIM result%(10,1)

REM 0=OS, 1=STEM
FOR stem%=0 TO 1
IF stem% THEN OSCLI "VT102" ELSE *VT102 OFF
mode%=0
RESTORE
count%=0
REPEAT
READ test_fn$
IF test_fn$<>"" THEN MODE mode%:result%(count%,stem%)=EVAL("FN"+test_fn$):count%=count%+1
UNTIL test_fn$=""
NEXT
*VT102 OFF
MODE mode%
IF writeable% THEN *SPOOL O.TestSp
PRINTTAB(40)"   OS (cs) STEM (cs)      ratio"
FOR test%=0 TO count%-1
os%=result%(test%,0)
stem%=result%(test%,1)
PRINT test$(test%);TAB(40),os%,stem%;
@%=&2020A
PRINT,100*stem%/os%;"%"
@%=old_at%
NEXT
PRINT'"Ratios below 100% indicate STEM is faster than the OS; ratios above 100%"'"indicate STEM is slower than the OS."
A%=&82:IF (USR(&FFF4) AND &FFFF00)<>&FFFF00 THEN PRINT'"Tests have been run on a second processor; timings may be inaccurate."
*SPOOL
END

DATA "long_lines_wrap"
DATA "lines_cr(79)"
DATA "lines_cr(1)"
DATA "full_screen_scroll"
DATA "full_screen_reverse_scroll"
DATA "partial_screen_scroll"
DATA "partial_screen_reverse_scroll"
DATA "cursor_move(5)"
DATA "cursor_move(1)"
DATA ""

DEF FNlong_lines_wrap
LOCAL A$
test$(count%)="Long wrapped text lines, no scroll"
A$=STRING$(255,"X")
IF mode%=0 THEN C%=10 ELSE C%=7
IF stem% THEN R$=CHR$(27)+"[H" ELSE R$=CHR$(30)
T%=TIME
FOR J%=1 TO 10:PRINT R$;:FOR I%=1 TO C%:PRINT A$;:NEXT:NEXT
T%=TIME-T%
=T%

DEF FNlines_cr(length%)
LOCAL A$
test$(count%)=STR$(length%)+" character text lines, no scroll"
IF mode%=0 THEN C%=31 ELSE C%=24
IF stem% THEN R$=CHR$(27)+"[H" ELSE R$=CHR$(30)
IF length%>20 THEN R%=5 ELSE R%=50
A$=STRING$(length%,"X")
T%=TIME
FOR J%=1 TO R%:PRINT R$;:FOR I%=1 TO C%:PRINT A$:NEXT:NEXT
T%=TIME-T%
=T%

DEF FNfull_screen_scroll 
test$(count%)="Full screen scroll"
T%=TIME
FOR I%=1 TO 500:PRINT I%:NEXT
T%=TIME-T%
=T%

DEF FNfull_screen_reverse_scroll
test$(count%)="Full screen reverse scroll"
IF stem% THEN S$=CHR$(27)+"M"+CHR$(13) ELSE S$=CHR$(11)+CHR$(13)
T%=TIME
FOR I%=1 TO 500:PRINT I%;S$;:NEXT
T%=TIME-T%
=T%

DEF FNpartial_screen_scroll
test$(count%)="Partial screen scroll"
IF stem% THEN PRINT CHR$(27);"[2;24r";CHR$(27);"[2H"; ELSE VDU 28,0,23,79,1
T%=TIME
FOR I%=1 TO 200:PRINT I%:NEXT
T%=TIME-T%
REM mode change between tests will undo the scroll region/text window
=T%

DEF FNpartial_screen_reverse_scroll
test$(count%)="Partial screen reverse scroll"
IF stem% THEN PRINT CHR$(27);"[2;24r";CHR$(27);"[2H";:S$=CHR$(27)+"M"+CHR$(13) ELSE VDU 28,0,23,79,1:S$=CHR$(11)+CHR$(13)
T%=TIME
FOR I%=1 TO 200:PRINT I%;S$;:NEXT
T%=TIME-T%
REM mode change between tests will undo the scroll region/text window
=T%

DEF FNcursor_move(length%)
LOCAL A$
test$(count%)="Cursor movement, "+STR$(length%)+" character output"
A$=""
FOR Y%=0 TO 20 STEP 5
FOR X%=0 TO 60 STEP 20
IF stem% THEN A$=A$+CHR$(27)+"["+STR$(Y%+1)+";"+STR$(X%+1)+"H" ELSE A$=A$+CHR$(31)+CHR$(X%)+CHR$(Y%)
A$=A$+STRING$(length%,"X")
NEXT
NEXT
T%=TIME
FOR I%=1 TO 50:PRINT A$:NEXT
T%=TIME-T%
=T%
