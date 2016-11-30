REM *VT102 won't reset the emulation if it's already turned on, so we turn it
REM off and on as an easy way to start in a known state.
*VT102 OFF
*VT102
MODE 3
PRINT CHR$(27);"[1;4m";CHR$(27);"#6STEM input test";CHR$(27);"[m"
PRINT'"Please press keys as requested; if you see 'UNEXPECTED' that indicates a bug"
PRINT "unless you pressed the wrong key, in which case just try again."'

A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:M%=(os%=3)

crlf$=CHR$(13)+CHR$(10)

REM G0=US character set, G1=UK character set, select G0
PRINT CHR$(27);")A";CHR$(27);"(B";CHR$(15);

PRINT CHR$(27);"[8;32r";CHR$(27);"[8H";

PROCgroup("ANSI mode, cursor key mode reset")
PRINT CHR$(27);"[?1l";
PROCe("cursor up", CHR$(27)+"[A")
PROCe("cursor down", CHR$(27)+"[B")
PROCe("cursor right", CHR$(27)+"[C")
PROCe("cursor left", CHR$(27)+"[D")

PROCgroup("ANSI mode, cursor key mode set")
PRINT CHR$(27);"[?1h";
PROCe("cursor up", CHR$(27)+"OA")
PROCe("cursor down", CHR$(27)+"OB")
PROCe("cursor right", CHR$(27)+"OC")
PROCe("cursor left", CHR$(27)+"OD")

PROCgroup("VT52 mode")
PRINT CHR$(27);"[?2l";
PROCe("cursor up", CHR$(27)+"A")
PROCe("cursor down", CHR$(27)+"B")
PROCe("cursor right", CHR$(27)+"C")
PROCe("cursor left", CHR$(27)+"D")

PROCgroup("Back to ANSI mode, cursor key mode should still be set")
PRINT CHR$(27);"<";
PROCe("cursor up", CHR$(27)+"OA")

PROCgroup("US character set")
PROCe("SHIFT-_ (pound symbol)", CHR$(96))
PROCe("f0", CHR$(96))
VDU 14:PROCgroup("UK character set")
PROCe("SHIFT-_ (pound symbol)", CHR$(35))
PROCe("f0", CHR$(96))
VDU 15

PROCgroup("ANSI mode, numeric keypad mode, LNM reset")

IF M% THEN PROCe("keypad +", "+"):PROCe("keypad -", "-"):PROCe("keypad /", "/"):PROCe("keypad *", "*")
IF M% THEN PROCe("keypad 7", "7"):PROCe("keypad 8", "8"):PROCe("keypad 9", "9"):PROCe("keypad #", "#")
IF M% THEN PROCe("keypad 4", "4"):PROCe("keypad 5", "5"):PROCe("keypad 6", "6"):PROCe("keypad DELETE", CHR$(127))
IF M% THEN PROCe("keypad 1", "1"):PROCe("keypad 2", "2"):PROCe("keypad 3", "3"):PROCe("keypad ,", ",")
IF M% THEN PROCe("keypad 0", "0"):PROCe("keypad .", "."):PROCe("keypad RETURN", CHR$(13))

PROCe("f1", CHR$(27)+"OP")
PROCe("f2", CHR$(27)+"OQ")
PROCe("f3", CHR$(27)+"OR")
PROCe("f4", CHR$(27)+"OS")

PRINT "Press f7 to turn keypad emulation on before continuing..."'

PROCe("7", "7")
PROCe("8", "8")
PROCe("9", "9")
PROCe("0", "-")
PROCe("U", "4")
PROCe("I", "5")
PROCe("O", "6")
PROCe("P", ",")
PROCe("J", "1")
PROCe("K", "2")
PROCe("L", "3")
PROCe(";", CHR$(13))
PROCe("M", "0")
PROCe(",", "0")
PROCe(".", ".")
PROCe("/", CHR$(13))
PROCe("f1", CHR$(27)+"OP")
PROCe("f2", CHR$(27)+"OQ")
PROCe("f3", CHR$(27)+"OR")
PROCe("f4", CHR$(27)+"OS")

PROCgroup("ANSI mode, numeric keypad mode, LNM set")
PRINT CHR$(27);"[20h";
PROCe(";", crlf$)
PROCe("/", crlf$)
IF M% THEN PROCe("keypad RETURN", crlf$)
PRINT CHR$(27);"[20l";

PROCgroup("ANSI mode, application keypad mode, LNM reset")
VDU 27,ASC"="
PROCe("7", CHR$(27)+"Ow")
PROCe("8", CHR$(27)+"Ox")
PROCe("9", CHR$(27)+"Oy")
PROCe("0", CHR$(27)+"Om")
PROCe("U", CHR$(27)+"Ot")
PROCe("I", CHR$(27)+"Ou")
PROCe("O", CHR$(27)+"Ov")
PROCe("P", CHR$(27)+"Ol")
PROCe("J", CHR$(27)+"Oq")
PROCe("K", CHR$(27)+"Or")
PROCe("L", CHR$(27)+"Os")
PROCe(";", CHR$(27)+"OM")
PROCe("M", CHR$(27)+"Op")
PROCe(",", CHR$(27)+"Op")
PROCe(".", CHR$(27)+"On")
PROCe("/", CHR$(27)+"OM")
PROCe("f1", CHR$(27)+"OP")
PROCe("f2", CHR$(27)+"OQ")
PROCe("f3", CHR$(27)+"OR")
PROCe("f4", CHR$(27)+"OS")
IF M% THEN PROCe("keypad +", CHR$(27)+"OP"):PROCe("keypad -", CHR$(27)+"OQ"):PROCe("keypad /", CHR$(27)+"OR"):PROCe("keypad *", CHR$(27)+"OS")
IF M% THEN PROCe("keypad 7", CHR$(27)+"Ow"):PROCe("keypad 8", CHR$(27)+"Ox"):PROCe("keypad 9", CHR$(27)+"Oy"):PROCe("keypad #", CHR$(27)+"Om")
IF M% THEN PROCe("keypad 4", CHR$(27)+"Ot"):PROCe("keypad 5", CHR$(27)+"Ou"):PROCe("keypad 6", CHR$(27)+"Ov"):PROCe("keypad DELETE", CHR$(127))
IF M% THEN PROCe("keypad 1", CHR$(27)+"Oq"):PROCe("keypad 2", CHR$(27)+"Or"):PROCe("keypad 3", CHR$(27)+"Os"):PROCe("keypad ,", CHR$(27)+"Ol")
IF M% THEN PROCe("keypad 0", CHR$(27)+"Op"):PROCe("keypad .", CHR$(27)+"On"):PROCe("keypad RETURN", CHR$(27)+"OM")
PROCgroup("ANSI mode, application keypad mode, LNM set")
PRINT CHR$(27);"[20h";
PROCe(";", CHR$(27)+"OM") 
PROCe("/", CHR$(27)+"OM")
IF M% THEN PROCe("keypad RETURN", CHR$(27)+"OM")
PRINT CHR$(27);"[20l";

PROCgroup("VT52 mode, still in application keypad mode, LNM reset")
PRINT CHR$(27);"[?2l";
PROCe("7", CHR$(27)+"?w")
PROCe("8", CHR$(27)+"?x")
PROCe("9", CHR$(27)+"?y")
PROCe("0", CHR$(27)+"?m")
PROCe("U", CHR$(27)+"?t")
PROCe("I", CHR$(27)+"?u")
PROCe("O", CHR$(27)+"?v")
PROCe("P", CHR$(27)+"?l")
PROCe("J", CHR$(27)+"?q")
PROCe("K", CHR$(27)+"?r")
PROCe("L", CHR$(27)+"?s")
PROCe(";", CHR$(27)+"?M")
PROCe("M", CHR$(27)+"?p")
PROCe(",", CHR$(27)+"?p")
PROCe(".", CHR$(27)+"?n")
PROCe("/", CHR$(27)+"?M")
PROCe("f1", CHR$(27)+"P")
PROCe("f2", CHR$(27)+"Q")
PROCe("f3", CHR$(27)+"R")
PROCe("f4", CHR$(27)+"S")
IF M% THEN PROCe("keypad +", CHR$(27)+"P"):PROCe("keypad -", CHR$(27)+"Q"):PROCe("keypad /", CHR$(27)+"R"):PROCe("keypad *", CHR$(27)+"S")
IF M% THEN PROCe("keypad 7", CHR$(27)+"?w"):PROCe("keypad 8", CHR$(27)+"?x"):PROCe("keypad 9", CHR$(27)+"?y"):PROCe("keypad #", CHR$(27)+"?m")
IF M% THEN PROCe("keypad 4", CHR$(27)+"?t"):PROCe("keypad 5", CHR$(27)+"?u"):PROCe("keypad 6", CHR$(27)+"?v"):PROCe("keypad DELETE", CHR$(127))
IF M% THEN PROCe("keypad 1", CHR$(27)+"?q"):PROCe("keypad 2", CHR$(27)+"?r"):PROCe("keypad 3", CHR$(27)+"?s"):PROCe("keypad ,", CHR$(27)+"?l")
IF M% THEN PROCe("keypad 0", CHR$(27)+"?p"):PROCe("keypad .", CHR$(27)+"?n"):PROCe("keypad RETURN", CHR$(27)+"?M")

PROCgroup("VT52 mode, numeric keypad mode, LNM reset")
VDU 27,ASC">"
PROCe("7", "7")
PROCe("8", "8")
PROCe("9", "9")
PROCe("0", "-")
PROCe("U", "4")
PROCe("I", "5")
PROCe("O", "6")
PROCe("P", ",")
PROCe("J", "1")
PROCe("K", "2")
PROCe("L", "3")
PROCe(";", CHR$(13))
PROCe("M", "0")
PROCe(",", "0")
PROCe(".", ".")
PROCe("/", CHR$(13))
PROCe("f1", CHR$(27)+"P")
PROCe("f2", CHR$(27)+"Q")
PROCe("f3", CHR$(27)+"R")
PROCe("f4", CHR$(27)+"S")
IF M% THEN PROCe("keypad +", "+"):PROCe("keypad -", "-"):PROCe("keypad /", "/"):PROCe("keypad *", "*")
IF M% THEN PROCe("keypad 7", "7"):PROCe("keypad 8", "8"):PROCe("keypad 9", "9"):PROCe("keypad #", "#")
IF M% THEN PROCe("keypad 4", "4"):PROCe("keypad 5", "5"):PROCe("keypad 6", "6"):PROCe("keypad DELETE", CHR$(127))
IF M% THEN PROCe("keypad 1", "1"):PROCe("keypad 2", "2"):PROCe("keypad 3", "3"):PROCe("keypad ,", ",")
IF M% THEN PROCe("keypad 0", "0"):PROCe("keypad .", "."):PROCe("keypad RETURN", CHR$(13))

PROCgroup("VT52 mode, application keypad mode, LNM reset")
VDU 27,ASC"="
PROCe("7", CHR$(27)+"?w")
PROCgroup("ANSI mode, still in application keypad mode, LNM reset")
VDU 27,ASC"<"
PROCe("7", CHR$(27)+"Ow")
PROCgroup("ANSI mode, back to numeric keypad mode, LNM reset")
VDU 27,ASC">"
PROCe("7", "7")
PROCe("SHIFT-7", "'")
IF M% THEN PROCe("keypad 7", "7"):PROCe("SHIFT-keypad 7", "7"):PROCe("SHIFT-keypad .", ".")

PROCgroup("VT52 mode, numeric keypad mode, LNM set")
PRINT CHR$(27);"[20h";
PRINT CHR$(27);"[?2l";
PROCe(";", crlf$)
PROCe("/", crlf$)
IF M% THEN PROCe("keypad RETURN", crlf$)
PROCgroup("VT52 mode, application keypad mode, LNM set")
VDU 27,ASC"="
PROCe(";", CHR$(27)+"?M")
PROCe("/", CHR$(27)+"?M")
IF M% THEN PROCe("keypad RETURN", CHR$(27)+"?M")
VDU 27,ASC">"
VDU 27,ASC"<"
PRINT CHR$(27);"[20l";

PRINT "Press f7 to turn keypad emulation off before continuing..."'

PROCgroup("Normal keyboard keys, LNM set")
PRINT CHR$(27);"[20h";
PROCe("RETURN", crlf$)
PROCe("f5", CHR$(10))
PRINT CHR$(27);"[20l";

PROCgroup("Normal keyboard keys, LNM reset")

PROCe("COPY", CHR$(8))
PROCe("TAB", CHR$(9))
PROCe("RETURN", CHR$(13))
PROCe("f5", CHR$(10))
PROCe("ESCAPE", CHR$(27))
PROCe("DELETE", CHR$(127))

PROCe("CTRL-space", CHR$(0))
FOR I%=1 TO 26
PROCe("CTRL-"+CHR$(ASC"A"-1+I%), CHR$(I%))
NEXT
PROCe("CTRL-[", CHR$(27))
PROCe("CTRL-"+CHR$(92), CHR$(28)):REM CTRL-backslash
PROCe("CTRL-]", CHR$(29))
PROCe("CTRL-_", CHR$(30))
PROCe("CTRL-SHIFT-_ (CTRL-pound symbol)", CHR$(30))
PROCe("CTRL-f0", CHR$(30))
PROCgroup("Normal keyboard keys, UK character set")
VDU 14:REM UK character set - should make no difference, but we check
PROCe("CTRL-_", CHR$(30))
PROCe("CTRL-SHIFT-_ (CTRL-pound symbol)", CHR$(30))
PROCe("CTRL-f0", CHR$(30))
VDU 15:REM Back to US
PROCgroup("Normal keyboard keys, back to US character set")
PROCe("CTRL-/", CHR$(31))
END

DEF FNterminal_mode
LOCAL M%,E$
REM We use DECID as it works in both VT52 and VT102 mode
VDU 27,ASC"Z"
M%=0
REPEAT
E$=FNread_escape
REM We may have read two escape sequences (e.g. the user pressed a cursor
REM key before the program started running), so we use INSTR() here.
IF E$<>"" AND INSTR(E$,CHR$(27)+"[?6c")<>0 THEN M%=102
IF E$<>"" AND INSTR(E$,CHR$(27)+"/Z")<>0 THEN M%=52
UNTIL E$=""
IF M%=0 THEN VDU 127
=M%

REM Discards characters up to and including ESC, then returns everything in the 
REM keyboard buffer after it; returns an empty string if no ESC is seen.
DEF FNread_escape
LOCAL C%,E$
REPEAT
C%=INKEY(0)
IF C%=27 THEN E$=CHR$(27)+FNread_string
UNTIL C%=-1 OR C%=27
=E$

DEF FNread_string
LOCAL C$,S$
REPEAT
C$=INKEY$(0)
S$=S$+C$
UNTIL C$=""
=S$

DEF PROCgroup(name$)
LOCAL M%
M%=FNterminal_mode
IF M%=52 THEN PRINT CHR$(27);"<";
PRINT CHR$(27);"7";CHR$(27);"[6H";CHR$(27);"[KCurrent group: ";name$;CHR$(27);"8";
IF M%=52 THEN PRINT CHR$(27);"[?2l";
ENDPROC

DEF PROCe(key$, sequence$)
LOCAL C$
PRINT "Press "+key$+":"
REPEAT
C$=FNread_string
IF C$=sequence$ THEN PRINT "    OK"'
IF C$<>"" AND C$<>sequence$ THEN PRINT "    UNEXPECTED ("+FNpretty_print(C$)+")"
UNTIL C$=sequence$
ENDPROC

DEF FNpretty_print(S$)
LOCAL space$,T$,I%,C%
IF S$="" THEN =""
space$=""
FOR I%=1 TO LEN(S$)
C%=ASC(MID$(S$,I%,1))
IF C%<=32 OR C%>126 OR C%=35 OR C%=96 THEN T$=T$+space$+"<"+STR$(C%)+">" ELSE T$=T$+space$+CHR$(C%)
space$=" "
NEXT
=T$
