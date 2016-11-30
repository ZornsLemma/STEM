interactive%=FALSE
IF !&900<>&F42084A9 THEN PRINT "Run T.COMMON first!":END
redraw%=TRUE
ON ERROR redraw%=FALSE:GOTO 100
*VT102 STORED
100ON ERROR OFF
*VT102 OFF
vt102$="VT102"
OSCLI vt102$
A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:bbc_b%=(os%=1)
MODE 0
VDU 19,0,4,0,0,0
PROCfont
*VT102 OFF
CLS
PRINT "All tests passed!"
END

DEF PROCreturn
IF interactive% THEN VDU 7:REPEAT UNTIL GET=13:name$=""
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

DEF PROCfont
name$="font"
FOR I%=6 TO 0 STEP -1
OSCLI "FX20,"+STR$(I%)
FOR J%=0 TO 1
IF J%=0 THEN OSCLI "VT102 OFF":CLS ELSE CLS:OSCLI vt102$
PRINT "Entire font output (*FX20,";I%;")"'
FOR C%=32 TO 255
IF C%<>127 THEN VDU C%
NEXT
PRINT'
REM Do the same again; in VT102 mode use insert mode to force this to be handled
REM by the slow path.
IF J%=1 THEN PRINT CHR$(27);"[4h";
FOR C%=32 TO 255
IF C%<>127 THEN VDU C%
NEXT
PRINT'
IF J%=1 THEN PRINT CHR$(27);"[4l";
PRINT "Push <RETURN>";
PROCreturn
IF J%=0 THEN K%=FNscreen_crc ELSE PROCverify_crc(K%, K%)
NEXT
NEXT
ENDPROC
