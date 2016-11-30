A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:bbc_b%=(os%=1):bbc_b_plus%=(os%=2)
shadow%=NOT bbc_b_plus%
10ON ERROR shadow%=FALSE:GOTO 50
IF shadow% THEN *SHADOW
50ON ERROR OFF
IF (W% AND NOT 32)>0 AND (W% AND NOT 32)<&80 AND NOT shadow% THEN PRINT'"Can't run with workspace in main RAM andno shadow RAM":END
70IF NOT shadow% AND PAGE>&E00 THEN R%=?&DBC:OSCLI "TAPE":R%?&2A1=0:OSCLI "KEY0 FOR I%=0 TO TOP-PAGE STEP 4:I%!&E00=I%!PAGE:NEXT|MPAGE=&E00|MOLD|MDELETE 10,70|MRUN|M":OSCLI "FX21":OSCLI "FX138,0,128":VDU 21:END
VDU 6
interactive%=FALSE
IF !&900<>&F42084A9 THEN PRINT "Run T.COMMON first!":END
redraw%=TRUE
ON ERROR redraw%=FALSE:GOTO 100
*VT102 STORED
100ON ERROR OFF
*VT102 OFF
vt102$="VT102"
OSCLI vt102$
MODE 0 
VDU 19,0,4,0,0,0
PROCea
*VT102 OFF
CLS
PRINT "All tests passed!"
END

DEF PROCreturn
IF interactive% THEN VDU 7:REPEAT UNTIL GET=13
ENDPROC

DEF FNscreen_crc=USR(&900)AND&FFFF

DEF PROCverify_crc(correct_crc%,correct_redraw_crc%)
PROCverify_one_crc(correct_crc%,1)
IF NOT redraw% THEN ENDPROC
*REDRAW
PROCverify_one_crc(correct_redraw_crc%,2)
ENDPROC

DEF PROCverify_one_crc(correct_crc%,colour%)
our_crc%=FNscreen_crc
IF correct_crc%=our_crc% THEN ENDPROC
VDU 7
VDU 19,0,colour%,0,0,0
*FX21
key%=GET
PRINTTAB(0,0);"Test: ";name$
PRINT "Expected CRC &";~correct_crc%;", our CRC &";~our_crc%;"."
END

DEF PROCassert_cursor(expected_y%,expected_x%)
LOCAL C%,Y%,X%
?&FE00=15
C%=?&FE01
?&FE00=14
C%=C%+256*?&FE01
C%=C%*8
C%=C%-(!&350 AND &FFFF)
Y%=C% DIV 640
X%=(C% MOD 640) DIV 8
IF Y%=expected_y%-1 AND X%=expected_x%-1 THEN ENDPROC
*VT102 OFF
VDU 19,0,2,0,0,0
*FX21
key%=GET
PRINTTAB(0,0);"Test: ";name$
END

DEF PROCea
name$="ea"
PRINT CHR$(27);"[2J";CHR$(27);"HTest of escape sequences inside Acorn VDU sequences"'
ul$=CHR$(27)+"[4m"
uo$=CHR$(27)+"[m"
PRINT ul$;"This sentence should be underlined.";uo$
VDU 23,255
PRINT ul$;
VDU 255,255,255,255
PRINT "This sentence should not contain any underlining, and should end with a strange"'"character: ";CHR$(255)
PRINT'"Push <RETURN>";
PROCverify_crc(&4DE4,&4DE4)
PROCreturn
ENDPROC
