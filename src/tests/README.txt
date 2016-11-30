The tests in the 'manual' subdirectory were all derived from the output of
vttest (the C program). This file contains a few notes on them.

setup1.txt - equivalent to setup_terminal()
vt52-off.txt - used to disable VT52 mode after VT52 tests
deccolm.txt - selects 80 column mode, also clearing the screen

1. Test of cursor movements
vttest1-1.txt - tst_movements box(80 cols)
vttest1-2.txt - tst_movements wrap(80 cols)
vttest1-3.txt - tst_movements cursor-controls in ESC sequences
vttest1-4.txt - tst_movements leading zeros in ESC sequences

2. Test of screen features
vttest2-1.txt - wrap around
vttest2-2.txt - tab setting
vttest2-3.txt - TODO
vttest2-4.txt - TODO
vttest2-5.txt - TODO
vttest2-6.txt - TODO
vttest2-7.txt - origin mode
vttest2-8.txt - origin mode
vttest2-9.txt - graphic rendition (dark background)
vttest2-10.txt - graphic rendition (light background)
vttest2-11.txt - save/restore cursor

3. Test of character sets
vttest3-1.txt - VT100 character sets

4. Test of double-sized characters
vttest4-1.txt - basic test
vttest4-2.txt - continued
vttest4-3.txt - double-sized with cursor movements
vttest4-4.txt - continued

7. Test of VT52 mode
vttest7-1.txt - basic VT52 functionality
vttest7-2.txt - VT52 character sets

8. Test of VT102 features (Insert/Delete Char/Line)
[These tend to be 'cumulative' and rely on the previous tests' output.]
vttest8-1.txt - Screen accordion test (Insert & Delete Line)
vttest8-2.txt - contd
vttest8-3.txt - Test of 'Insert Mode'
vttest8-4.txt - Test of 'Delete Character'
vttest8-5.txt - Another test of 'Delete Character'
vttest8-5d.txt - as vttest8-5.txt but with double width characters
vttest8-6.txt - test of ANSI insert character
