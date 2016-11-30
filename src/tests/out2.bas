A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:bbc_b%=(os%=1):bbc_b_plus%=(os%=2)
shadow%=NOT bbc_b_plus%
10ON ERROR shadow%=FALSE:GOTO 50
IF shadow% THEN *SHADOW
50ON ERROR OFF
IF (W% AND NOT 32)>0 AND (W% AND NOT 32)<&80 AND NOT shadow% THEN PRINT'"Can't run with workspace in main RAM andno shadow RAM":END
70IF NOT shadow% AND PAGE>&E00 THEN R%=?&DBC:OSCLI "TAPE":R%?&2A1=0:OSCLI "KEY0 FOR I%=0 TO TOP-PAGE STEP 4:I%!&E00=I%!PAGE:NEXT|MPAGE=&E00|MOLD|MDELETE 10,70|MDELETE 3000,3010|MRUN|M":OSCLI "FX21":OSCLI "FX138,0,128":VDU 21:END
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
PROCcsp
PROCcct
PROCcdw
PROCdbs
PROCptte
PROCsrcvs
PROCvt52
PROCmode_change_part_1:MODE 3:VDU 19,0,4,0,0,0:PROCmode_change_part_2:MODE 0:VDU 19,0,4,0,0,0
PROCdisable
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

DEF PROCcsp
name$="csp"
PRINT CHR$(27);"[2J";CHR$(27);"[HTest of cursor special positioning"
PRINT';
PROCassert_cursor(3,1)
PRINT "Some ";
PROCassert_cursor(3,6)
PRINT "simple text"
PRINT CHR$(27);"[3;80H";
PROCassert_cursor(3,80)
PRINT "x";
REM We're in auto-wrap mode, so the cursor is logically still on that x but
REM we will actually be showing it at the start of the next line
PROCassert_cursor(4,1)
PRINT "y";
PROCassert_cursor(4,2)
PRINT " - 'xy' should be wrapped across the right margin";
PRINT CHR$(27);"[32;80H";
PROCassert_cursor(32,80)
PRINT "x";
REM The cursor is logically on that x and as we're on the last line we can't
REM show the cursor on the next line.
PROCassert_cursor(32,80)
PRINT CHR$(27);"[6H";CHR$(27);"[6;10r"
REM The scrolling region acts similarly; on non-last-lines, the cursor is
REM logically at the last position but actually shows on the next line...
PRINT CHR$(27);"[6;80H";
PROCassert_cursor(6,80)
PRINT "a";
PROCassert_cursor(7,1)
PRINT "b - 'ab' should be wrapped across the right margin";
REM ... but on the last line the cursor stays within the scroll region
PRINT CHR$(27);"[10;80H";
PROCassert_cursor(10,80)
PRINT "z";
PROCassert_cursor(10,80)
PRINT CHR$(27);"[r";CHR$(27);"[12HPush <RETURN>";
PROCreturn
PROCverify_crc(&98CA,&98CA)
ENDPROC

DEF PROCcct
name$="cct"
REM Bit contrived to test a rare case where constrain_cursor_y finds the cursor
REM above the top margin; I am not sure this can happen without this kind of
REM fiddling.
PRINT CHR$(27);"[2J";CHR$(27);"[HTest of constraining cursor to top margin"
PRINT CHR$(27);"[3;10r";CHR$(27);"[?6h";
VDU 30:REM OS will move cursor to top left, we will drag it back
PRINT "This should be on line 3. Push <RETURN>";
PRINT CHR$(27);"[r";CHR$(27);"[?6l";
PROCreturn
PROCverify_crc(&CC3,&CC3)
ENDPROC

DEF PROCcdw
name$="cdw"
PRINT CHR$(27);"[2J";CHR$(27);"[H";
FOR I%=1 TO 5
PRINT CHR$(27);"#6"
NEXT
PRINT CHR$(27);"[3;10H";
PROCassert_cursor(3,19):REM args bit weird for double-width
PRINT CHR$(27);"[2J";
PROCassert_cursor(3,10)
PRINT "Single-width text at (3,10). Push <RETURN>";
PROCreturn
PROCverify_crc(&1ADE,&1ADE)
ENDPROC

DEF PROCdbs
name$="dbs"
REM Check backspace at top left scrolls screen in reverse
PRINT CHR$(27);"[2J";CHR$(27);"[Hsentence wraps around at the right margin.";CHR$(27);"[H";CHR$(127);CHR$(127);CHR$(127);CHR$(127);"This";CHR$(27);"[H";CHR$(27);CHR$(27);"M";CHR$(27);"M"
PRINT CHR$(27);"[HTest of destructive backspace"
PRINT''''"This should bejunk";CHR$(127);CHR$(127);CHR$(127);CHR$(127);" a correct sentence.X";CHR$(127)
PRINT CHR$(27);"#6This should also bejunk";CHR$(127);CHR$(127);CHR$(127);CHR$(127);" a correct sentence.X";CHR$(127)
PRINT'"This sentence wraps around onto the following line but it should still be correjunk";CHR$(127);CHR$(127);CHR$(127);CHR$(127);"-ct."
REM The next line backspaces when in auto-wrap pending.
PRINT'"This sentence also wraps around onto the following line but it should be correcX";CHR$(127);"tas well."
PRINT'CHR$(27);"#6This sentence starts off double-width junk";CHR$(127);CHR$(127);CHR$(127);CHR$(127);"b-ut wraps onto a single-width line. ";
PRINT CHR$(27);"7"'CHR$(27);"#6";CHR$(27);"8";
PRINT "While this sentence starts on a single-widtjunk";CHR$(127);CHR$(127);CHR$(127);CHR$(127);"h line but wraps onto a double-width line."
REM Check backspace at top left of scroll region does a reverse scroll.
PRINT CHR$(27);"[19;22r";CHR$(27);"[19Haround on to the next line.";
PRINT CHR$(13);CHR$(127);CHR$(127);"ps";
PRINT CHR$(13);"This sentence is very long and when it eventually hits the right margin it wra"
PRINT CHR$(27);"[r";CHR$(27);"[22HPush <RETURN>";
PROCreturn
PROCverify_crc(&3199,&3199)
ENDPROC

DEF PROCptte
name$="ptte"
PRINT CHR$(27);"[2J";CHR$(27);"[HTest of pass through and temporary escape into Acorn mode"'
PRINT CHR$(27);"#6Double-width text";
VDU 28,0,10,79,0
PRINT " and single-width text";
VDU 26
REM Key thing here is that the VT102 cursor is positioned where it was when we
REM did VDU 28.
PRINT CHR$(27);"D";CHR$(27);"7";CHR$(27);"#6with double-width text"
PRINT CHR$(27);"8";CHR$(27);"D";CHR$(27);"#6beneath single-wid";
REM The current VT102 cursor position is outside the text window we're about
REM to define (although the *logical* X coordinate is within, as it's a
REM double-width line), so the Acorn cursor ends up at the top left of the
REM window.
VDU 28,0,4,60,3
PRINT "and single-width text"'"beneath double-width";
VDU 26:REM we're now back where we were before VDU 28
PRINT "th"
PRINT'"A line of single-";
VDU 5
MOVE 8,796
PRINT "Another line of single-width text offset half a character from the line above."
VDU 4
PRINT "width text starting at the left of the screen."
PRINT'"And another line back a";
VDU 21:PRINT "invisible";:VDU 6
PRINT "t the left margin."
REM Now we try nesting some of the escapes into Acorn mode
PRINT'" ingle-width te";
VDU 5
VDU 28,0,31,79,11
MOVE 0,700
PRINT "S";
VDU 21:PRINT "invisible":VDU 6
VDU 4
3000REM On a B+ or Master, the cursor is now at the top left corner of the text
REM window. On a B, it's at the top left of the screen. This is nothing to do
REM with STEM; try MODE 0:VDU 5,28,0,31,79,11,4 on different machines without
REM STEM installed. We're obviously being ridiculously "clever" with this test,
3010REM but that's kind of the point.
IF bbc_b% THEN VDU 30
PRINT "split over two adjacent lines.";
VDU 21:PRINT "invisible":VDU 6
VDU 26
PRINT "xt whi";
VDU 21:PRINT "invisible":VDU 6
PRINT "ch has been";
MOVE 32,16:MOVE 1008,16:PLOT 85,1008,76:MOVE 32,76:PLOT 85,32,16
GCOL 4,1
VDU 5
MOVE 48,60:PRINT "Single-width reverse video text in a box via Acorn plotting"
VDU 4
GCOL 0,1
PRINT'''"Push <RETURN>";
PROCreturn
PROCverify_crc(&50A9,&1099)
ENDPROC

DEF PROCsrcvs
name$="srcvs"
PRINT CHR$(27);"[2J";CHR$(27);"[HTest of save/restore cursor with varying screen size"'
PRINT CHR$(27);"[32HThis should be erased.";CHR$(27);"7";
OSCLI vt102$+" 24"
PRINT CHR$(27);"8Bar";
PRINT CHR$(27);"[24HFoo";
PRINT CHR$(27);"[3HFoo and Bar should appear on the same line below. Push <RETURN>";
OSCLI vt102$
PROCreturn
PROCverify_crc(&67E4,&67E4)
ENDPROC

DEF PROCvt52
name$="vt52"
OSCLI "VT52"+MID$(vt102$,6)
PRINT CHR$(27);"H";CHR$(27);"JTest of *VT52 command";
PRINT CHR$(27);"Y"+CHR$(3+31)+CHR$(1+31);"This sentence should have one blank line between it and the title."
PRINT "Push <RETURN>";
PROCreturn
PROCverify_crc(&DD,&DD)
OSCLI vt102$
ENDPROC

DEF PROCmode_change_part_1
name$="mode_change_part_1"
PRINT CHR$(27);"[2J";CHR$(27);"[H";
FOR I%=1 TO 61
PRINT "Line ";I%
NEXT
PRINT "Push <RETURN>";
PROCreturn
PROCverify_crc(&105C,&105C)
ENDPROC

DEF PROCmode_change_part_2
name$="mode_change_part_2"
REM This test illustrates a bug on redraw where the stored screen still had junk
REM left over from part 1.
PRINT CHR$(27);"[25HA"'"B"'"C"'"Push <RETURN>";
PROCverify_crc(&58E3, &58E3)
ENDPROC

DEF PROCdisable
name$="disable"
*VT102 OFF
*FX219,65
OSCLI vt102$
PRINT CHR$(27);"[2J";CHR$(27);"[HTest of disabling emulation"'
PRINT CHR$(27);"#6Double-width turn";
PROCassert_cursor(3,35):REM args bit weird for double-width
*VT102 OFF
A%=219:X%=0:Y%=&FF:R%=USR(&FFF4)
IF (R% AND &FF00) DIV 256<>65 THEN PRINT "Keyboard settings not restored!":END
PROCassert_cursor(3,35)
PRINT "ed to single-width mid-word";
OSCLI vt102$
PROCverify_crc(&885D,0)
PRINT ". Push <RETURN>";
PROCreturn
ENDPROC
