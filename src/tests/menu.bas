*FX229,1
ON ERROR GOTO 100
*SHADOW 1
100ON ERROR OFF
ON ERROR GOTO 150
REM If we're running on a BBC B with an Integra-B, set an OSMODE that works.
*OSMODE 1
150ON ERROR OFF
MODE 7
FOR I%=1 TO 2
PRINT " ";CHR$(141);CHR$(132);CHR$(157);CHR$(135);"STEM demonstration/test suite  ";CHR$(156)
NEXT
REM Check to see if STEM is present and if so what size workspace we have
ON ERROR GOTO 1000
*VT102 OFF
large_workspace%=TRUE
ON ERROR GOTO 2000
*VT102 NOSTORED
ON ERROR large_workspace%=FALSE:GOTO 200
*VT102 STORED
200ON ERROR OFF
*VT102 OFF
PRINT'"Checking STEM version...";
found%=FALSE
REM Unfortunately OSRDRM doesn't seem to work across the tube, even if you use
REM OSWORD 6 to poke the bytes at &F6/F7.
A%=&82:IF (USR(&FFF4) AND &FFFF00)<>&FFFF00 THEN W%=0:GOTO 300
FOR rom%=15 TO 0 STEP -1
loaded_version$=FNtitle_version(rom%)
IF LEFT$(loaded_version$,5)="STEM " THEN found%=TRUE:W%=rom%?&DF0:rom%=0
NEXT
300caveat$="don't"
IF NOT found% THEN loaded_version$="undetermined":caveat$="may not"
I%=INSTR(loaded_version$," (")
IF I%<>0 THEN loaded_version$=LEFT$(loaded_version$,I%-1)
PRINT CHR$(13);" Installed version: ";loaded_version$;STRING$(39-POS," ")
disc_version$=""
file%=OPENIN("$.STEM")
PTR #file%=9
REPEAT
C%=BGET #file%
IF C%=32 THEN GOTO 500
IF C%=0 THEN C$=" " ELSE C$=CHR$(C%)
disc_version$=disc_version$+C$
500UNTIL C%=32
CLOSE #file%
IF disc_version$<>loaded_version$ THEN PRINT " Disc version:      ";disc_version$'CHR$(129);"Warning: versions ";caveat$;" match"
IF PAGE>&1A00 THEN PRINT CHR$(129);"Warning: high PAGE, some tests may fail";
IF NOT large_workspace% THEN PRINT CHR$(129);"Warning: stored screen can't be tested"
REM TODO: Should we include a brief README and/or a copy of LICENCE.txt on the
REM SSD and provide an option to display them?
PRINT'" C) Christmas animation"
PRINT " F) Firework animation"
PRINT'" 1) Output test 1 (very long running!)"
PRINT " 2) Output test 2"
PRINT " 3) Output test 3"
PRINT " 4) Output test 4"
PRINT " I) Interactive input test"
PRINT " B) Buffer handler test"
PRINT " S) Speed test"
PRINT " Z) Fuzz tester"
PRINT " M) Memmove test"
PRINT'" R) Reload STEM (to bank Z)"
PRINT'" Your choice? ";
REPEAT
key$=FNget
UNTIL INSTR("CF1234IBSZMR",key$)<>0
PRINT key$
U%=FALSE
IF key$="C" THEN F%=&4201:CHAIN "T.PLAYER"
IF key$="F" THEN F%=-1:CHAIN "T.PLAYER"
IF key$="1" THEN PROCchain_via_common("T.OUT1")
REM MODE 135 in next line avoids problems with Integra-B with *SHX OFF;
REM T.OUT2 is large and extends past &3000 with high PAGE.
IF key$="2" THEN MODE 135:PROCchain_via_common("T.OUT2")
IF key$="3" THEN MODE 135:PROCchain_via_common("T.OUT3")
IF key$="4" THEN U%=TRUE:PROCchain_via_common("T.OUT4")
IF key$="I" THEN CHAIN "T.IN"
IF key$="B" THEN CHAIN "T.BUFFER"
IF key$="S" THEN CHAIN "T.SPEED"
IF key$="Z" THEN PROCchain_via_common("T.FUZZ")
IF key$="M" THEN CHAIN "T.MEMMOVE"
IF key$="R" THEN GOTO 1010
UNTIL FALSE
END

DEF FNtitle_version(rom%)
LOCAL C%,T$,I%
C%=FNrdrm(&8007,rom%)
T$=""
FOR I%=&8009 TO &8000+C%-1
C%=FNrdrm(I%,rom%)
IF C%<32 THEN T$=T$+" " ELSE T$=T$+CHR$(C%)
NEXT
=T$

DEF FNrdrm(I%,Y%)
?&F6=I%:?&F7=I% DIV 256
=USR(&FFB9) AND &FF

DEF FNget
LOCAL key$
*FX21
key$=GET$
IF key$>="a" AND key$<="z" THEN key$=CHR$(ASC(key$)-ASC("a")+ASC("A"))
=key$

DEF PROCchain_via_common(next$)
REM Clunky, but just in case we're running with PAGE=&800
IF PAGE<&E00 THEN PRINT'"This test can't run on a second"'"processor.":END
$&900=next$
IF NOT U% THEN CHAIN "T.COMMON"
*KEY0 *FX20,6|M*BASIC|MCHAIN "T.COMMON"|M
*FX21
*FX138,0,128
VDU 21
END

1000PRINT'" STEM not installed!"
PRINT'" Press RETURN to load into bank Z...";
*FX21
REPEAT UNTIL GET=13
PRINT 
1010PRINT'" Loading..."
*KEY0 *SRLOAD STEM 8000 ZQ|M*FX151,78,127|MCALL !-4|M
*FX21
*FX138,0,128
END

2000PRINT'" STEM installed but no workspace!"
PRINT'" Press S to claim small workspace or"'" L to claim large workspace."
PRINT'" (Unless sideways RAM or private"'" workspace is available, large workspace will probably prevent tests running"'" successfully.)"'
REPEAT
key$=FNget
UNTIL INSTR("SL", key$)<>0
IF key$="S" THEN *STEM SMALL
IF key$="L" THEN *STEM LARGE
END
