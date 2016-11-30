REM The menu may have done a VDU 21 if it had to explode the font.
VDU 6

REM We need to be able to access the screen memory directly in order to
REM calculate CRCs on it.
A%=&82:IF (USR(&FFF4) AND &FFFF00)<>&FFFF00 THEN PRINT'"This test can't run on a second"'"processor.":END

next$=$&900
PROCassemble

A%=0:X%=1:os%=(USR(&FFF4) DIV 256) AND &FF:master%=(os%>=3)
IF U% AND master% THEN OSCLI "FX20,6"
IF U% AND NOT master% THEN PROCudg

IF LEN(next$)>7 OR LEFT$(next$,2)<>"T." THEN PRINT'"Done; now run the required test.":END
CHAIN next$
END

DEF PROCassemble
code%=&900
osbyte=&FFF4
crc_low=&70
crc_high=&71
ptr=&72
count=&74
lines=&76
screen_start=&350
screen_memory_start_high_byte=&34E
screen_mode=&355
FOR opt%=0 TO 2 STEP 2
P%=code%
[OPT opt%
.calc_screen_crc
LDA #&84:JSR osbyte
TYA:BPL vram_ok
LDX #1
LDA #108:JSR osbyte
INX:BNE vram_ok
LDX #0
LDA #111:JSR osbyte
.vram_ok
LDX #32
LDA screen_mode:BEQ mode_0
LDX #25
.mode_0
STX lines
LDA screen_start:STA ptr
LDA screen_start+1:STA ptr+1
LDA #0
STA crc_high:STA crc_low
.line_loop
JSR crc_line
DEC lines
BNE line_loop
\ For convenience, in mode 3 we pretend to be in mode 0 with all the extra
\ lines blank - this makes CRCs common where possible.
LDA screen_mode:BEQ mode_0_again
LDA #(32-25):STA lines
.zero_loop
JSR crc_zero
DEC lines
BNE zero_loop
.mode_0_again
LDA #&84:JSR osbyte
TYA:BPL vram_ok2
LDX #0
LDA #108:JSR osbyte
INX:BNE vram_ok2
LDX #1
LDA #111:JSR osbyte
.vram_ok2
LDA crc_low:LDX crc_high
RTS

.crc_line
LDA #639 MOD 256:STA count
LDA #639 DIV 256:STA count+1
LDY #0
.crc_loop
LDA crc_high:EOR (ptr),Y:STA crc_high
LDX #8
.crc_loop2
LDA crc_high
ROL A
BCC bit_7_zero
LDA crc_high:EOR #8:STA crc_high
LDA crc_low:EOR #&10:STA crc_low
.bit_7_zero
ROL crc_low
ROL crc_high
DEX
BNE crc_loop2
INC ptr:BEQ ptr_low_zero
.not_wrapped
LDA count:SEC:SBC #1:STA count
LDA count+1:SBC #0:STA count+1
BPL crc_loop
RTS
.ptr_low_zero
INC ptr+1:LDA ptr+1
CMP #&80:BNE not_wrapped
LDA screen_memory_start_high_byte
STA ptr+1
JMP not_wrapped

.crc_zero
LDA #639 MOD 256:STA count
LDA #639 DIV 256:STA count+1
LDY #0
.crc_zero_loop
LDX #8
.crc_zero_loop2
LDA crc_high
ROL A
BCC zero_bit_7_zero
LDA crc_high:EOR #8:STA crc_high
LDA crc_low:EOR #&10:STA crc_low
.zero_bit_7_zero
ROL crc_low
ROL crc_high
DEX
BNE crc_zero_loop2
LDA count:SEC:SBC #1:STA count
LDA count+1:SBC #0:STA count+1
BPL crc_zero_loop
RTS
]
NEXT
ENDPROC

DEF PROCudg
FOR I%=0 TO 31
C%=&C000+(I%+65-32)*8
VDU 23,128+I%
FOR J%=0 TO 7
VDU (C%?J%) EOR 255
NEXT
NEXT
FOR I%=32 TO 126
C%=&C000+(I%-32)*8
VDU 23,128+I%
FOR J%=0 TO 7
VDU C%?(7-J%)
NEXT
NEXT
VDU 23,255,255,255,255,255,255,255,255,255
ENDPROC
