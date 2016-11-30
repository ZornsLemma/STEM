REM We need to be able to call INSV etc directly.
A%=&82:IF (USR(&FFF4) AND &FFFF00)<>&FFFF00 THEN PRINT'"This test can't run on a second"'"processor.":END
*VT102 OFF
*VT102
MODE 3
PRINT "Testing buffer handlers; please don't touch the keyboard!"
PROCassemble
REPEAT UNTIL INKEY(0)=-1
normal_space%=32:REM must be consistent with STEM
cursor_left%=140
cursor_right%=141
cursor_down%=142
cursor_up%=143
initial_free%=FNcnpv_count_free

REM Basic functionality tests; nothing tricky here
PROCassert("B0",FNcnpv_count_used,0)
PROCassert("B1",FNinsv(65),FALSE)
PROCassert("B2",FNremv_examine,65)
PROCassert("B3",FNremv_examine,65)
PROCassert("B4",FNremv_remove,65)
PROCassert_empty("B5")
PROCassert("B9",FNinsv(65),FALSE)
PROCassert("B10",FNcnpv_count_free,initial_free%-1)
PROCassert("B11",FNcnpv_count_used,1)
PROCcnpv_purge
PROCassert_empty("B12")
FOR I%=1 TO normal_space%
PROCassert("B16-"+STR$(I%),FNinsv(64+I%),FALSE)
PROCassert("B16a-"+STR$(I%),FNcnpv_count_used,I%)
NEXT
FOR I%=1 TO normal_space%
PROCassert("B17-"+STR$(I%),FNinsv(32+I%),TRUE)
PROCassert("B17a-"+STR$(I%),FNcnpv_count_used,normal_space%)
NEXT
FOR I%=1 TO normal_space%
PROCassert_next("B18",64+I%)
PROCassert("B19a-"+STR$(I%),FNcnpv_count_used,normal_space%-I%)
NEXT
PROCassert_empty("B20")

REM Check we can indirectly insert a multi-byte cursor left sequence even with only one byte of normal space free
PROCcursor_left
PROCcursor_left_remove
PROCassert_empty("K9")

REM Check purging buffers purges priority space too
PROCcursor_left
PROCcnpv_purge
PROCassert_empty("K10")

REM Check reports still work even with the buffer full and some priority space used
PROCcursor_left
PRINT CHR$(27);"[25;80H";CHR$(27);"[6n";
PROCcursor_left_remove
PROCassert_contents("R1",CHR$(27)+"[25;80R")
PROCcursor_left
PRINT CHR$(27);"[3;10H";CHR$(27);"[6n";
PROCcursor_left_remove
PROCassert_contents("R2",CHR$(27)+"[3;10R")

REM Check that we don't insert a partial report when there isn't room for a full one
PROCcursor_left
PRINT CHR$(27);"[3;7H";CHR$(27);"[6n";
PRINT CHR$(27);"[4;8H";CHR$(27);"[6n";
PROCcursor_left_remove
PROCassert_contents("R3",CHR$(27)+"[3;7R")

REM Check that cursor position reports respect origin mode
PRINT CHR$(27);"[10;20r";CHR$(27);"[10H";CHR$(27);"[6n";
PROCassert_contents("R4",CHR$(27)+"[10;1R")
PRINT CHR$(27);"[?6h";CHR$(27);"[6n";
PROCassert_contents("R5",CHR$(27)+"[1;1R")
PRINT "   ";CHR$(27);"[6n";
PROCassert_contents("R6",CHR$(27)+"[1;4R")
PRINT CHR$(27);"[?6l";CHR$(27);"[6n";
PROCassert_contents("R7",CHR$(27)+"[1;1R")
PRINT CHR$(27);"[r";

PRINT CHR$(27);"[5n";
PROCassert_contents("R8", CHR$(27)+"[0n")

PRINT CHR$(27);"[?15n";
PROCassert_contents("R9", CHR$(27)+"[?13n")

PRINT CHR$(27);"[c";
PROCassert_contents("R10", CHR$(27)+"[?6c")
PRINT CHR$(27);"[0c";
PROCassert_contents("R11", CHR$(27)+"[?6c")
PRINT CHR$(27);"Z";
PROCassert_contents("R12", CHR$(27)+"[?6c")

PRINT CHR$(27);"[?2l";CHR$(27);"Z";
PROCassert_contents("R13", CHR$(27)+"/Z")
PRINT CHR$(27);"<";

REM Check that user input can't interleave with report results.
REM This will "fail" if the user presses a key which inserts an escape sequence.
PRINT CHR$(27);"[3HEverything OK so far. Now please hammer lots of alphanumeric keys, nothing"'"should fail...";
N%=0
REPEAT
PRINT CHR$(27);"[c";
REPEAT
C%=GET
IF C%<>27 AND C%>=32 THEN PRINT CHR$(27);"[6HKey: ";CHR$(C%);
UNTIL C%=27
A%=GET:B%=GET:C%=GET:D%=GET
IF A%<>ASC("[") OR B%<>ASC("?") OR C%<>ASC("6") OR D%<>ASC("c") THEN PRINT CHR$(27);"[9HFailed",A%,B%,C%,D%:END
PRINT CHR$(27);"[7HReports processed: ";N%;
N%=N%+1
UNTIL FALSE

END

DEF PROCassemble
DIM code% 32
FOR opt%=0 TO 2 STEP 2
P%=code%
[OPT opt%
.remv_clv
CLV
JMP (&22C)
.remv_sev
BIT rts
JMP (&22C)
.cnpv_clv
CLV
JMP (&22E)
.cnpv_sev
BIT rts
JMP (&22E)
.rts
RTS
]
NEXT
ENDPROC

DEF PROCassert(N$,A%,B%)
IF A%=B% THEN ENDPROC
PRINT CHR$(27);"[3HAssertion failed: ";N$
END

DEF PROCassert_empty(N$)
PROCassert(N$+"-1",FNremv_examine,-1)
PROCassert(N$+"-2",FNremv_remove,-1)
PROCassert(N$+"-3",FNcnpv_count_free,initial_free%)
PROCassert(N$+"-4",FNcnpv_count_used,0)
ENDPROC

DEF PROCassert_next(N$,C%)
PROCassert(N$+"-1",FNremv_examine,C%)
PROCassert(N$+"-2",FNremv_remove,C%)
ENDPROC

DEF PROCassert_contents(N$,S$)
LOCAL I%
FOR I%=1 TO LEN(S$)
PROCassert_next(N$+"-"+STR$(I%),ASC(MID$(S$,I%,1)))
NEXT
PROCassert_empty(N$+"-E")
ENDPROC

REM FNcarry and FNoverflow work as they do to avoid problems
REM with DIV when top bit of flags byte is set

DEF FNcarry(R%)
!&70=R%
=?&73 AND 1

DEF FNoverflow(R%)
!&70=R%
=?&73 AND &40

REM Returns TRUE if buffer full
DEF FNinsv(char%)
LOCAL A%,X%,R%
A%=char%
X%=0
R%=USR(?&22A+256*?&22B)
PROCassert("INSV preserve A",A%,R% AND &FF)
PROCassert("INSV preserve X",X%,(R% AND &FF00) DIV &100)
=FNcarry(R%)=1

REM Return character or -1 if buffer empty on entry
DEF FNremv_examine
LOCAL X%,R%
X%=0
R%=USR(remv_sev)
PROCassert("REMV examine preserve X",X%,(R% AND &FF00) DIV &100)
IF FNcarry(R%) THEN =-1 ELSE =R% AND &FF

REM Return character or -1 if buffer empty on entry
DEF FNremv_remove
LOCAL X%,R%
X%=0
R%=USR(remv_clv)
PROCassert("REMV remove preserve X",X%,(R% AND &FF00) DIV &100)
IF FNcarry(R%) THEN =-1 ELSE =(R% AND &FF0000) DIV &10000

DEF FNcnpv_count_free=FNcnpv_count(TRUE)
DEF FNcnpv_count_used=FNcnpv_count(FALSE)
DEF FNcnpv_count(C%)
LOCAL X%,R%
IF C% THEN C%=1
X%=0
R%=USR(cnpv_clv)
PROCassert("CNPV count preserve V",0,FNoverflow(R%))
PROCassert("CNPV count preserve C",C%,FNcarry(R%))
=(R% AND &FFFF00) DIV &100

DEF PROCcnpv_purge
LOCAL C%,X%,Y%,R%
C%=0:REM arbitrary
X%=0
Y%=42:REM arbitrary
R%=USR(cnpv_sev)
PROCassert("CNPV purge preserve V",&40,FNoverflow(R%))
PROCassert("CNPV purge preserve C",C%,FNcarry(R%))
PROCassert("CNPV purge preserve X",X%,(R% AND &FF00) DIV &100)
PROCassert("CNPV purge preserve Y",Y%,(R% AND &FF0000) DIV &10000)
ENDPROC

DEF PROCcursor_left
LOCAL I%
FOR I%=1 TO normal_space%-1
PROCassert("K1-"+STR$(I%),FNinsv(64+I%),FALSE)
NEXT
PROCassert("K2",FNinsv(cursor_left%),FALSE)
PROCassert("K3",FNinsv(cursor_right%),TRUE)
PROCassert("K4",FNinsv(48),TRUE)
ENDPROC

DEF PROCcursor_left_remove
LOCAL I%
FOR I%=1 TO normal_space%-1
PROCassert("K5",FNremv_remove,64+I%)
NEXT
PROCassert_next("K6",27)
PROCassert_next("K7",ASC"[")
PROCassert_next("K8",ASC"D")
ENDPROC
