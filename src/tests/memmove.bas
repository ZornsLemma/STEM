MODE 7
HIMEM=TOP+256-(TOP MOD 256)+&400
oswrch_t=&70
oswrch_u=&74
oswrch_v=&78
oswrch_w=&7A
*LOAD C.MEMMOVE 7800
test_block_size%=&E00
padding%=&200:REM each side
slow_test%=HIMEM
fast_test%=HIMEM+test_block_size%+2*padding%
IF fast_test%+test_block_size%+2*padding%>&7800 THEN PRINT "Bad setup":END

PROCtest("S1w", 3235, 3578, 274)
PROCtest("S1v", &3FE, &E03, 2)
PROCtest("S1u", &DFF, &F00, 2)
PROCtest("S1t", &DFF, &F00, 1)
PROCtest("S1s", &CFF, &F00, 256)
PROCtest("S1r", &CFF, &F00, 257)
PROCtest("S1q", &CFF, &F00, 260)
PROCtest("S1p", &CFF, &F00, 513)
PROCtest("S1o", &B5F, &F00, 513)
PROCtest("S1n", &D5F, &F00, 513)
PROCtest("S1m", &D5F, &F00, 512)
PROCtest("S1l", &D5F, &F00, 257)
PROCtest("S1k", 3167, &F00, 257)
PROCtest("S1j", 3167, &F00, 513)
PROCtest("S1i", &D00, 3400, 513)
PROCtest("S1h", &D00, 3400, 89+256)
PROCtest("S1g", &D00, 3400, 89)
PROCtest("S1f", &D00, 3400, 89+512)
PROCtest("S1e", 3167, &F00, 89+512)
PROCtest("S1d", &D00, &F00, 89+512)
PROCtest("S1c", 3167, 3400, 89+512)
PROCtest("S1b", 3167, 3400, 89+256)
PROCtest("S1a", 3167, 3400, 89)
PROCtest("S1", 3167, 3400, 857)
PROCtest("S2", 3285, 3961, 467)
PROCtest("S3", 3140, 3160, 541)
PROCtest("J", test_block_size%-&10, test_block_size%+&100, &301)
PROCtest("K", test_block_size%+&10, test_block_size%+&100, &301)
PROCtest("L", test_block_size%-&10, test_block_size%+&100, &2FF)
PROCtest("M", test_block_size%+&10, test_block_size%+&100, &2FF)
PROCtest("H", test_block_size%-&10, test_block_size%+&100, &300)
PROCtest("I", test_block_size%+&10, test_block_size%+&100, &300)
PROCtest("A", 0, 1, 1)
PROCtest("C", 0, 10, 20)
PROCtest("F", 0, 10, test_block_size%-1)
PROCtest("G", test_block_size%-&100, test_block_size%+&100, &200)
REPEAT
from%=RND(1024)-512
IF from%<0 THEN from%=test_block_size%+from%
to%=from%+RND(1024)
count%=RND(1024)
name$="R"+STR$(from%)+"/"+STR$(to%)+"/"+STR$(count%)
IF to%<0 THEN to%=test_block_size%+to%
PROCtest(name$, from%, to%, count%)
UNTIL FALSE
END

DEF PROCtest(name$, from_offset%, to_offset%, count%)
IF to_offset%<from_offset% THEN PRINT "PROCtest() needs from<to":END
PROCtest_core(name$+"-1",from_offset%,to_offset%,count%)
PROCtest_core(name$+"-2",to_offset%,from_offset%,count%)
ENDPROC

DEF PROCtest_core(name$, from_offset%, to_offset%, count%)
PRINT name$
offset%=padding%+test_block_size%
FOR I%=0 TO padding%-1:slow_test%?I%=&DD:fast_test%?I%=&DD:slow_test%?(I%+offset%)=&DD:fast_test%?(I%+offset%)=&DD:NEXT
IF from_offset%+count%>=2*test_block_size% THEN PRINT "Too big (1)":END
IF to_offset%+count%>=2*test_block_size% THEN PRINT "Too big (2)":END
FOR I%=padding% TO padding%+test_block_size%-1:slow_test%?I%=I% MOD 256:fast_test%?I%=I% MOD 256:NEXT
PROCslow_memmove(slow_test%+padding%+from_offset%, slow_test%+padding%+to_offset%, count%, slow_test%+padding%, slow_test%+padding%+test_block_size%)
PROCfast_memmove(fast_test%+padding%+from_offset%, fast_test%+padding%+to_offset%, count%, fast_test%+padding%, fast_test%+padding%+test_block_size%)
FOR I%=0 TO test_block_size%+2*padding%-1
IF slow_test%?I%<>fast_test%?I% THEN PRINT "Difference at offset ";I%;" (";I%-padding%;" within block)":END
NEXT
ENDPROC

DEF PROCslow_memmove(from%, to%, count%, wrap_bottom%, wrap_top%)
IF count%=0 OR from%=to% THEN ENDPROC
IF from%>to% THEN PROCslow_memmove_from_gt_to(from%, to%, count%, wrap_bottom%, wrap_top%) ELSE PROCslow_memmove_from_lt_to(from%, to%, count%, wrap_bottom%, wrap_top%)
ENDPROC

DEF PROCslow_memmove_from_gt_to(from%, to%, count%, wrap_bottom%, wrap_top%)
IF from%>=wrap_top% THEN from%=from%-(wrap_top%-wrap_bottom%)
IF to%>=wrap_top% THEN to%=to%-(wrap_top%-wrap_bottom%)
REPEAT
?to%=?from%
to%=to%+1
IF to%=wrap_top% THEN to%=wrap_bottom%
from%=from%+1
IF from%=wrap_top% THEN from%=wrap_bottom%
count%=count%-1
UNTIL count%=0
ENDPROC

DEF PROCslow_memmove_from_lt_to(from%, to%, count%, wrap_bottom%, wrap_top%)
from%=from%+count%
to%=to%+count%
IF from%>=wrap_top% THEN from%=from%-(wrap_top%-wrap_bottom%)
IF to%>=wrap_top% THEN to%=to%-(wrap_top%-wrap_bottom%)
REPEAT
IF from%=wrap_bottom% THEN from%=wrap_top%
from%=from%-1
IF to%=wrap_bottom% THEN to%=wrap_top%
to%=to%-1
REM PRINT "from &";~(from%-(slow_test%+&100));" to &";~(to%-(slow_test%+&100))
?to%=?from%
count%=count%-1
UNTIL count%=0
ENDPROC

DEF PROCfast_memmove(from%, to%, count%, wrap_bottom%, wrap_top%)
IF wrap_bottom% MOD 256<>0 OR wrap_top% MOD 256<>0 THEN PRINT "Can only wrap on page boundary":END
IF count%>=(wrap_top%-wrap_bottom%) THEN PRINT "Count must be smaller than total size":END
!oswrch_t=from%
!oswrch_u=to%
X%=count%:Y%=count% DIV 256
?oswrch_v=wrap_bottom% DIV 256
oswrch_v?1=wrap_top% DIV 256
PRINT "Calling"
CALL &7800
PRINT "Called"
ENDPROC
