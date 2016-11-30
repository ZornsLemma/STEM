IF !&900<>&F42084A9 THEN PRINT "Run T.COMMON first!":END
interactive%=FALSE
redraw_interval%=0:REM 0 disables
large_workspace%=TRUE
ON ERROR large_workspace%=FALSE:GOTO 100
*VT102 STORED
100ON ERROR OFF
*VT102 OFF
IF NOT large_workspace% THEN redraw_interval%=0
MODE 128
shadow_available%=(HIMEM=&8000)
A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:IF os%=2 THEN shadow_available%=FALSE
IF shadow_available% THEN shadow_max%=128 ELSE shadow_max%=0
DIM crc%(5)
FOR stored_screen%=large_workspace% TO FALSE
FOR shadow%=0 TO shadow_max% STEP 128
FOR mode%=0 TO 3 STEP 3
lines%=25:IF mode%=0 THEN lines%=32
FOR hardware_scroll_offset%=lines%-1 TO 0 STEP -1
FOR em_lines_i%=0 TO 2
IF em_lines_i%=0 THEN em_lines%=24 ELSE IF em_lines_i%=1 THEN em_lines%=25 ELSE em_lines%=32
IF em_lines%>lines% THEN GOTO 200
REM By turning the emulation off first, we ensure that it subsequently
REM turns on in a known state.
*VT102 OFF
REM By explicitly requesting STORED we will get an error if we
REM don't have large workspace, rather than a CRC failure later.
IF stored_screen% THEN OSCLI "VT102 DECUS NODEL STORED "+STR$(em_lines%) ELSE OSCLI "VT102 DECUS NODEL NOSTORED "+STR$(em_lines%)
MODE shadow%+mode%
VDU 19,0,4,0,0,0
IF hardware_scroll_offset%<>0 THEN FOR I%=0 TO hardware_scroll_offset%-1:PRINT CHR$(27);"[H";CHR$(27);"M";:NEXT
name$=""
file%=OPENIN("D.TESTS")
REPEAT
opcode%=BGET #file%
IF opcode%=0 OR opcode%=1 THEN PROCecho(file%, opcode%=1)
IF opcode%=2 THEN PROCcrc(file%)
IF opcode%=3 AND interactive% THEN VDU 7:REPEAT UNTIL GET=13:name$=""
IF opcode%=4 THEN name$="":len%=BGET #file%:FOR I%=1 TO len%:name$=name$+CHR$(BGET #file%):NEXT
UNTIL EOF #file%
CLOSE #file%
200NEXT
NEXT
NEXT
NEXT
NEXT
*VT102 OFF
CLS
PRINT "All tests passed!"
END

DEF FNread_u16(file%)
LOCAL low%,high%
low%=BGET #file%
high%=BGET #file%
=low%+256*high%

DEF FNscreen_crc=USR(&900)AND&FFFF

DEF PROCecho(file%, raw%)
LOCAL size%,byte%,B%
size%=FNread_u16(file%)
IF size%=0 THEN ENDPROC
REM TODO: Would be good to use OSGBPB and perhaps a little machine code loop
REM to optimise this.
REM For non-raw, we turn 10 (LF) into 10+13 (LFCR); as far as I can tell this is something the
REM Unix terminal driver does (stty onlcr seems to be enabled) and without this
REM I can't see how some of the vttest tests can work whatever the line feed mode
REM setting on the emulated VT102 is.
FOR byte%=1 TO size%
B%=BGET #file%
VDU B%
IF NOT raw% AND B%=10 THEN VDU 13
IF redraw_interval%>0 THEN IF byte%<size% THEN IF (byte% MOD redraw_interval%)=0 THEN PROCredraw_test(FNscreen_crc)
NEXT
echo_crc%=FNscreen_crc
IF redraw_interval%>0 THEN IF ((byte%-1) MOD redraw_interval%)<>0 THEN PROCredraw_test(echo_crc%)
ENDPROC

DEF PROCredraw_test(correct_crc%)
*REDRAW
PROCverify_crc(correct_crc%,2)
ENDPROC

DEF PROCcrc(file%)
LOCAL I%
FOR I%=0 TO 5
crc%(I%)=FNread_u16(file%)
NEXT
IF em_lines%=24 THEN I%=0 ELSE IF em_lines%=25 THEN I%=1 ELSE I%=2
IF stored_screen% THEN I%=I%+3
PROCverify_crc(crc%(I%),1)
ENDPROC

DEF PROCverify_crc(correct_crc%,colour%)
IF correct_crc%=echo_crc% THEN ENDPROC
VDU 7
VDU 19,0,colour%,0,0,0
*FX21
key%=GET
PRINTTAB(0,0);"Test: ";name$
PRINT "Stored screen: ";stored_screen%
PRINT "Mode: ";shadow%+mode%
PRINT "Emulated lines: ";em_lines%
PRINT "Hardware scroll offset: ";hardware_scroll_offset%
PRINT "Expected CRC &";~correct_crc%;", our CRC &";~echo_crc%;"."
END
