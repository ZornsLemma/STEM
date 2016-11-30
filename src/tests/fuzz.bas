redraw_interval%=4096
ON ERROR redraw_interval%=0:GOTO 100
*VT102 STORED
100ON ERROR OFF
*VT102 OFF
IF !&900<>&F42084A9 THEN PRINT "Run T.COMMON first!":END
MODE 0
VDU 19,0,4,0,0,0
*VT102 OFF
*FX21
PRINT "STEM fuzz tester"
PRINT'"Hold down SHIFT to print the number of cycles; this will interfere with the"'"reproducibility of the test using the seed, however."
PRINT'"Press S to toggle sound on and off during the test."
PRINT'"Enter no seed or a 0 seed to have one picked automatically."
REM Seed is in S% so it's available for inspection after BREAK
INPUT'"Seed? "S%
IF S%=0 THEN S%=TIME:REM not perfect but not too bad
CLS
REM Strict mode so the random output can't change Acorn mode or anything.
*VT102 STRICT
A%=RND(-S%)
B%=0
REPEAT
IF INKEY-82 THEN REPEAT UNTIL NOT INKEY-82:*FX210,255,255
R%=RND(100)
IF R%<=25 THEN S$=FNescape ELSE IF R%<=50 THEN S$=FNcontrol ELSE IF R%<=98 THEN S$=CHR$(RND(256)) ELSE IF R%<=99 THEN S$=CHR$(27)+"<" ELSE S$=CHR$(27)+"[?2l"
T$=""
FOR I%=1 TO LEN(S$)
C$=MID$(S$,I%,1)
R%=RND(40)
IF R%<=30 THEN T$=T$+C$ ELSE IF R%<=35 THEN T$=T$+CHR$(RND(256))+C$:REM ELSE T$=T$, i.e. drop C$
NEXT
PRINT T$;
B%=B%+1
IF redraw_interval%<>0 THEN IF (B% MOD redraw_interval%)=0 THEN PROCredraw
REM This output could of course make the run non-reproducible from the
REM seed...
IF INKEY-1 THEN PRINT "***";B%;"***";:REPEAT UNTIL NOT INKEY-1
UNTIL FALSE
END

DEF FNescape
LOCAL S$,R%,I%
S$=CHR$(27)
REM Add 0-2 intermediate characters
R%=RND(5)
IF R%>3 THEN FOR I%=1 TO R%-3:S$=S$+CHR$(31+RND(16)):NEXT
S$=S$+CHR$(47+RND(79))
=S$

DEF FNcontrol
LOCAL S$,R%,A$,I%
S$=CHR$(27)+"["
REM Possibly add a private parameter character
IF RND(20)>=18 THEN S$=S$+MID$("<=>?",RND(4),1)
REM Add 0-3 numeric parameters
R%=RND(6)
IF R%>3 THEN A$="":FOR I%=1 TO R%-3:S$=S$+A$+STR$(FNrandom_byte_ish):A$=";":NEXT
REM Add 0-2 intermediate characters
R%=RND(20)
IF R%>18 THEN FOR I%=1 TO R%-18:S$=S$+CHR$(31+RND(16)):NEXT
S$=S$+CHR$(63+RND(63))
=S$

DEF FNrandom_byte_ish
LOCAL R%
R%=RND(260)
IF R%<=255 THEN =R% ELSE =255+RND(1000)

DEF FNscreen_crc=USR(&900)AND&FFFF

DEF PROCredraw
crc%=FNscreen_crc
*REDRAW
IF crc%=FNscreen_crc THEN ENDPROC
*VT102 OFF
VDU 7
VDU 19,0,1,0,0,0
*FX21
key%=GET
END

REM For debugging

DEF PROCtest(control%)
REPEAT
IF control% THEN PROCprint(FNcontrol) ELSE PROCprint(FNescape)
PRINT
UNTIL FALSE
ENDPROC

DEF PROCprint(S$)
LOCAL I%,C%
FOR I%=1 TO LEN(S$)
C%=ASC(MID$(S$,I%,1))
IF C%>=32 AND C%<=126 THEN PRINT I%,C%," "+CHR$(C%) ELSE PRINT I%,C%
NEXT
ENDPROC
