import errno
import os

opcode_echo = 0
opcode_echo_raw = 1
opcode_crc = 2
opcode_return = 3
opcode_name = 4

generated = set()

def write_u8(output, u):
    assert 0 <= u <= 255
    output.write(bytearray([u]))

def write_u16(output, u):
    assert 0 <= u <= 65535
    output.write(bytearray([u & 0xff, (u & 0xff00) >> 8]))

# TODO: We could be smarter and do something to concatenate multiple files
# into one opcode_echo stream, but it's not really a big deal.
class File:
    def __init__(self, filename, raw = False):
        self.filename = filename
        self.raw = raw

    def write(self, output):
        directory = ("generated" if self.filename in generated else "manual")
        with open(os.path.join(directory, self.filename), "rb") as input:
            data = input.read()
            if len(data) == 0:
                return
            write_u8(output, opcode_name)
            write_u8(output, len(self.filename))
            output.write(self.filename)
            write_u8(output, opcode_echo_raw if self.raw else opcode_echo)
            write_u16(output, len(data))
            output.write(data)

class Crc:
    def __init__(self, crc_stored_screen, crc_no_stored_screen = -1):
        if crc_no_stored_screen == -1:
            crc_no_stored_screen = crc_stored_screen
        self.crc_stored_screen = [crc_stored_screen]*3
        self.crc_no_stored_screen = [crc_no_stored_screen]*3

    @classmethod
    def line_based(cls, crc_24_line, crc_25_line, crc_32_line):
        c = cls(0)
        c.crc_stored_screen = [crc_24_line, crc_25_line, crc_32_line]
        c.crc_no_stored_screen = c.crc_stored_screen
        return c

    def write(self, output):
        write_u8(output, opcode_crc)
        for lines in range(0, 3):
            write_u16(output, self.crc_no_stored_screen[lines])
        for lines in range(0, 3):
            write_u16(output, self.crc_stored_screen[lines])

class Return:
    def write(self, output):
        write_u8(output, opcode_return)

# We write these tests to their own files rather than just putting the data
# straight into the compiled output so they can be run under xterm with a
# simple cat command to verify the behaviour there.
def write_test(filename, data):
    global generated
    generated.add(filename)
    with open(os.path.join("generated", filename), "wb") as output:
        for item in data:
            if isinstance(item, str):
                for c in item:
                    output.write(bytearray([c]))
            else:
                output.write(bytearray([item]))

def create_auto_wrap_insert(filename):
    # Clear screen, cursor to top left, auto-wrap on, insert mode on
    data = [27, "[2J", 27, "[H", 27, "[4h", 27, "[?7h"]
    # Show a description and the example output
    data += "Below should be two identical sentences wrapped at the right margin"
    data += [27, "[3;71HThis wraps"]
    data += [27, "[4;1Hneatly on to the next line"]
    # Now do the same thing but relying on the fact that we're in insert mode
    # and auto-wrap mode; note how we auto-wrap and then carry on inserting, so
    # "on to the next line" is moved to the right automatically.
    data += [27, "[6;71H0123456789"]
    data += [27, "[7;1Hon to the next line"]
    data += [27, "[6;71HThis wrapsneatly "]
    # Now do the same test but with double-width text. This actually doesn't
    # work with xterm, but I am assuming it should work.
    data += [27, "[9;1HAnd the same thing but using double-width characters"]
    data += [27, "[11;31H", 27, "#6This wraps"]
    data += [27, "[12;1H", 27, "#6neatly on to the next line"]
    data += [27, "[14;31H", 27, "#60123456789"]
    data += [27, "[15;1H", 27, "#6on to the next line"]
    data += [27, "[14;31HThis wrapsneatly "]
    # Turn insert mode off
    data += [27, "[4l"]
    data += [27, "[17;1HPush <RETURN>"]
    write_test(filename, data)

def create_abandoned_escape1(filename):
    # Clear screen, cursor to top left
    data = [27, "[2J", 27, "[HThis sh"]
    # Start to set reverse video and underline, but don't complete it - the
    # idea is that a bug here might leave the parameters hanging around
    data += [27, "[7;5"] # We just need the 'm' to complete the command
    # But instead we start a new command
    data += [27, "[mould be plain text, not reverse video or underlined."]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_abandoned_escape2(filename):
    # The same idea as create_abandoned_escape1(), but with an interrupted
    # escape sequence instead of an interrupted control sequence.
    data = [27, "[2J", 27, "[HThis sh-"]
    data += [27, "#"] # if there was a '6' following this would set double-width
    # Instead we ESC D to move the cursor down
    data += [27, "Dould split across two lines."]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_pip(filename):
    # Test of what happens when a control sequence has parameters (P), then an
    # intermediate character, *then another parameter*, which is not valid. I
    # don't know what the expected behaviour here is, but xterm seems to
    # swallow up to the final character and ignore the whole escape sequence,
    # so that's what this test expects.
    # Clear screen, cursor to top left
    data = [27, "[2J", 27, "[HTest of invalid P/I/P control sequ"]
    data += [27, "[3;#8Hence"]
    data += ["\n\nThe sentence above should be unbroken and with no spelling",
             "\nmistakes. Push <RETURN>"]
    write_test(filename, data)

def create_unrecognised_escape_sequence(filename):
    # Clear screen, cursor to top left
    data = [27, "[2J", 27, "[HTest of unre", 27, "Ycognised escape sequence."]
    data += ["\n\nThe sentence above should be unbroken and with no spelling",
             "\nmistakes. Push <RETURN>"]
    write_test(filename, data)

def create_unrecognised_control_sequence(filename):
    # Clear screen, cursor to top left
    data = [27, "[2J", 27, "[HTest of unre", 27, "[Ycognised control sequence."]
    data += ["\n\nThe sentence above should be unbroken and with no spelling",
             "\nmistakes. Push <RETURN>"]
    write_test(filename, data)

def create_long_escape_sequence(filename):
    data = [27, "[2J", 27, "[HThis sentence should be single-wi"]
    data += [27, "#"*256, "6dth with no stray characters"]
    data += ["\nor spelling mistakes. Push <RETURN>"]
    write_test(filename, data)

def create_long_control_sequence_i(filename):
    data = [27, "[2J", 27, "[H", 27, "[4mThis sentence should be entirely underli"]
    data += [27, "[0;", "#"*256, "mned with no stray characters"]
    data += ["\nor spelling mistakes. Push <RETURN>", 27, "[m"]
    write_test(filename, data)

def create_long_control_sequence_p(filename):
    data = [27, "[2J", 27, "[H", 27, "[4mThis sentence should be entirely underli"]
    data += [27, "[", "0;"*128, "mned with no stray characters"]
    data += ["\nor spelling mistakes. Push <RETURN>", 27, "[m"]
    write_test(filename, data)

def create_acorn_mode1(filename):
    # Use the Acorn VDU 31 command (which we pass through) to set the cursor to
    # an odd character position and verify that we round it to an even position
    # on a double-width line.
    data = [27, "[2J", 27, "[H", 27, "#6Test of cursor adjustment: the"]
    # 9 moves the cursor one place right, but when we return to VT102 mode
    # we will round to an even boundary
    data += [31, 61, 0]
    data += ["re should\n"]
    data += [27, "#6be no extraneous space in 'there'."]
    # But you can get to odd character positions on single-width lines...
    data += ["\n\nThe", 31, 3, 3, "re should be no spelling mistake in this 'There'."]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_tab_double_width(filename):
    data = [27, "[3g", 27, "[2J", 27, "[H"]
    data += [27, "#6     ", 27, "H*     ", 27, "H*"]
    data += [27, "[1;40H*\n"]
    data += [27, "#6", 9, "*", 9, "*", 9, "*"]
    data += [27, "[3;1H", 27, "#6     ", 27, "[g      *"]
    data += [27, "[3;40H*\n"]
    data += [27, "[4;1H", 27, "#6", 9, "*", 9, "*"]
    data += [27, "[6;1HThe above lines should be identical pairs. Push <RETURN>"]
    data += [27, "[3g"]
    write_test(filename, data)

def create_set_cursor_off_screen1(filename):
    data = [27, "[2J", 27, "[39;1H"]
    data += ["This text should have appeared at the bottom of the screen."]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_set_cursor_off_screen2(filename):
    data = [27, "[2J", 27, "[1;90HA", 27, "[40;90HB", 27, "[40;1HC"]
    data += [27, "[3;1HThe screen should contain A at the top right, B at the bottom"]
    data += ["\nright and C at the bottom left."]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_save_restore_double_width(filename):
    data = [27, "[2J", 27, "[H"]
    data += ["Test of save and restore cursor attributes with varying character width."]
    data += ["\n\n", 27, "#6This line sh", 27, "7", 27, "#5", 27, "[H", 27, "8"]
    data += ["ould be single-width with no gaps.\n\n"]
    data += ["This line sh", 27, "7", 27, "#6", 27, "[H", 27, "8"]
    data += ["ould be double-width with no\n", 27, "#6gaps or spelling mistakes.\n\n"]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_save_restore_auto_wrap(filename):
    data = [27, "[2J", 27, "[H", 27, "[?7h"]
    data += ["Test of save and restore cursor attributes with auto-wrap. The final word of thX"]
    data += [27, "7", 27, "[5H", 27, "8"]
    data += ["etop line should be 'the'. "]
    data += ["Push <RETURN>", 27, "[?7l"]
    write_test(filename, data)

def create_line_attribute_scroll1(filename):
    data = [27, "[2J", 27, "[H\nThis line should be on the top line, single-width single-height.\n"]
    data += [27, "#3This line should be double-height.\n"]
    data += [27, "#4This line should be double-height.\n"]
    data += [27, "#6This line should be double-width.\n"]
    data += ["This line should be single-width single-height.\n\n"]
    data += ["Push <RETURN>", 27, "7"]
    data += [27, "[40H", 27, "D", 27, "8", 27, "M"]
    write_test(filename, data)

def create_line_attribute_scroll2(filename):
    data = [27, "[2J", 27, "[H", 27, "#6A double-width line", 13]
    data += [27, "M", "A single-width line", 13]
    data += [27, "M", "Another single-width line (will disappear)"]
    data += [27, "[100H", 27, "#6Another double-width line", 13]
    data += [27, "E", "Another single-width line"]
    data += [27, "[5HThere should be a single-width line on the top and bottom lines\n"]
    data += ["with a double-width line on the second and second-to-last lines.\n"]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_cr_auto_wrap(filename):
    data = [27, "[2J", 27, "[?7h"]
    data += [27, "[1;77Htwo.", 13]
    data += ["This line should be entirely on the top line of the screen, not broken over"]
    data += ["\n\nPush <RETURN>", 27, "[?7l"]
    write_test(filename, data)

def create_double_width_erase(filename):
    data = [27, "[2J", 27, "[H"]
    data += ["0123456789012345678901234567890123456789v-- All this text on the right half of\n"]
    data += ["                                        |   the screen should be erased and only\n"]
    data += ["This half of the screen should contain a|   the left half should remain.\n"]
    # The underlining on the right half of the next line would cause underlined spaces
    # if we didn't correctly clear the character attributes in the erased half.
    data += ["number line and this text. The right    |", 27, "[4mblah blah blah blah blah blah blah blah", 27, "[m\n"]
    data += ["half should be empty. Push <RETURN>     |blah blah blah blah blah blah blah blah\n"]
    data += [27, "[1H", 27, "#3\n", 27, "#4\n", 27, "#6\n", 27, "#3\n", 27, "#4\n"]
    data += [27, "[1H", 27, "#5\n", 27, "#5\n", 27, "#5\n", 27, "#5\n", 27, "#5\n"]
    write_test(filename, data)

def create_mixed_width_cursor_move(filename, name, down, up):
    data = [27, "[2J", 27, "[HTest of mixed-width characters with cursor movement ", name, "\n\n"]
    data += [27, "#6X", down, "X", up, "X", down, "X", up, "X"]
    data += ["\n\n\nThe two lines above should look like the following two lines:\n\n"]
    data += [27, "#6X X X\n X X\n\nPush <RETURN>"]
    write_test(filename, data)

def create_move_outside_scroll_region1(filename):
    data = [27, "[2J", 27, "[?6l        moving cursor outside scroll region (CUU/CUD)\n\n"]
    data += [27, "[3;22rTest\n\n"] # setting scroll region moves to home, so "Test" fills in gap
    data += ["     should be the third line from the top of the screen, counting from one."]
    data += [13, 27, "[2AThis"] # <ESC>[2A can't move outside scroll region so it's a no-op here
    # ESC[2H can move outside the scroll region (as origin mode is reset)
    data += [27, "[2HThis should be the second line from the top of the screen, counting from one."]
    data += [13, 27, "[A", 27, "[5Cof"] # <ESC>[A can move up once we're outside the scroll region
    data += [27, "[22H     should be the third-to-last line from the bottom of the 24-line screen."]
    data += [13, 27, "[BThis"] # <ESC>[B can't move outside the scroll region so it's a no-op here
    data += [27, "[23H", 27, "[BThis should be the bottom line of the 24-line screen. "]
    data += [27, "7", 27, "[r", 27, "8Push <RETURN>"] # <ESC>[B can move down outside the scroll region
    write_test(filename, data)

def create_move_outside_scroll_region2(filename):
    data = [27, "[2J", 27, "[?6l        moving cursor outside scroll region (IND/RI)\n\n"]
    data += [27, "[3;22rTest\n\n"] # setting scroll region moves to home, so "Test" fills in gap
    data += ["This should be the third line from the top of the screen, counting from one."]
    # ESC[2H can move outside the scroll region (as origin mode is reset)
    data += [27, "[2HThis should be the second line from the top of the screen, counting from one."]
    data += [27, "M", 27, "M", 27, "M", 27, "M", 27, "M"] # we don't scroll when we hit the top of screen
    data += [13, 27, "[5Cof"] # <ESC>M can move up once we're outside the scroll region
    data += [27, "[22HThis should be the third-to-last line from the bottom of the 24-line screen."]
    data += [27, "[23H", 27, "DThis should be the bottom line of the 24-line screen. ", 27, "7"]
    # We don't scroll when we hit the bottom of the screen
    for i in range(32):
        data += [27, "D"]
    data += [27, "[r", 27, "8Push <RETURN>"]
    write_test(filename, data)

def create_delete_line_character_attributes(filename):
    data = [27, "[2J", 27, "[1;24r", 27, "[24H", 27, "[?7l"]
    data += [27, "[4m", " "*80, 27, "[m"]
    # The VT102 manual at vt100.net says that on deleting a line, "Lines added
    # to bottom of screen have spaces with same character attributes as last
    # line moved up." This test attempts to invoke that behaviour. xterm doesn't
    # seem to do this, although I may have misunderstood.
    data += [27, "[10A", 13]
    data += [27, "[5M"]
    data += [27, "7", 27, "[r", 27, "8"]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_single_shift1(filename):
    # This assumes G2=UK, G3=special
    data = [27, "[2J", 27, "[HTest of single shift\n\n"]
    # Set G0=US, G1=UK, select G0
    data += [27, "(B", 27, ")A", 15]
    data += ["3xhash ", 35, 35, 35, ", 3xpound ", 14, 35, 35, 35, 15]
    data += [", hash-pound-hash ", 35, 27, "N", 35, 35]
    data += [", g-plus/minus-g-hash g", 27, "Ogg", 35]
    data += ["\n", 14, "3xpound ", 35, 27, "N", 35, 35]
    data += [", pound-plus/minus-pound ", 35, 27, "Og", 35]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_single_shift2(filename):
    # This assumes G2=UK, G3=special
    data = [27, "[2J", 27, "[HTest of single shift and insert mode\n\n"]
    # Set G0=US, G1=UK, select G0
    data += [27, "(B", 27, ")A", 15]
    # There was a bug where resetting the previous character set pointer after
    # use of G2/G3 would lose the first-class bits in fast_path_flags, so we verify that
    # this works by testing in insert mode, which is tracked by one of the
    # first-class bits. Interestingly enough, VT100-Hax appears to "fail" this
    # test - the first line says "#5 air" not "#5 a pair" - but this may be related
    # to my not having performed some relevant setup of G2/G3. gnome-terminal
    # and xterm both pass this test.
    data += [27, "[4ha pair\r", 27, "N", 35, "5 \n"]
    data += [27, "N", 35, "5 a pair\n\n"]
    data += ["The two lines above should be identical. Push <RETURN>"]
    data += [27, "[4l"]
    write_test(filename, data)

def create_single_shift3(filename):
    # This test has been mostly confirmed with the 'vt102' emulator, although I
    # couldn't quite get it to work as-is and had to change the two '15' codes
    # to '14' to see the mix of symbols and pound/hash are swapped - but the
    # point is that the pattern is the same.
    # This assumes G2=UK, G3=special
    data = [27, "[2J", 27, "[HTest of single shift and save/restore cursor attributes\n\n"]
    # Set G0=US, G1=UK, select G0
    data += [27, "(B", 27, ")A", 15]
    data += [35, 27, "N", 35, 35, 35, "\n"]
    data += [35, 27, "N", 27, "7", 27, "E", 35, 35, 35, 35]
    data += [27, "8", 35, 35, 35, "\n\n\n"]
    data += [15, 35, 27, "N", 35, 35, 35, "\n"]
    data += [35, 27, "N", 35, 35, 35, "\n"]
    data += [27, "N", 35, 35, 35, 35, "\n\n"]
    data += ["The two blocks of characters above should mix pound and hash symbols and be\n"]
    data += ["identical. Push <RETURN>"]
    write_test(filename, data)

def create_delete_character_reverse_video(filename):
    # I'm not 100% sure this test is correct; xterm doesn't pass it, but it
    # does seem correct based on my reading of the VT102 user guide.
    data = [27, "[2J", 27, "[HTest of delete character with reverse video\n\n"]
    sentence = "This JUNK whole line is reverse video."
    data += [27, "[7m", sentence, " "*(80 - len(sentence))]
    data += [27, "[mThe previous line should be entirely reverse video with a complete correct sent-\n"]
    data += ["ence. Push <RETURN>", 27, "7"]
    data += [27, "[3;5H", 27, "[5P", 27, "8"]
    write_test(filename, data)

def create_line_attribute_no_stored(filename, name, code):
    data = [27, "[2J", 27, "[HTest of line attribute changes for no stored screen (", name , ")\n\n"]
    data += [code]
    data += ["Single-width turned to double-width0123456", 27, "#6\n"]
    data += [27, "#6Double-width turned to single-width01234", 27, "#5\n"]
    data += ["Single-width to double-height012345678901234", 27, "#3\n"]
    data += ["Single-width to double-height012345678901234", 27, "#4\n"]
    data += ["Single-width to double-width to double-height", 27, "#6", 27, "#3\n"]
    data += ["Single-width to double-width to double-height", 27, "#6", 27, "#4\n"]
    data += [27, "#6Double-width to double-height01234567890", 27, "#3\n"]
    data += [27, "#6Double-width to double-height01234567890", 27, "#4\n"]
    data += [27, "#3Double-height to double-width01234567890", 27, "#6\n"]
    data += [27, "#4Double-height to double-width01234567890", 27, "#6\n"]
    data += [27, "#3Double-height to single-width01234567890", 27, "#5\n"]
    data += [27, "#4Double-height to single-width01234567890", 27, "#5\n"]
    data += ["\nPush <RETURN>", 27, "[m"]
    write_test(filename, data)

def create_tab_clear(filename):
    # This verifies that the tab my implementation puts in column 80 (1-based)
    # can't be erased by TBC.
    data = [27, "[2J", 27, "[HTest of clearing tab in column 80"]
    data += [27, "[3g", 27, "[3;80H", 27, "[g"]
    data += [27, "[3HThere should be an x at the far right of this line\tx"]
    data += ["and this should be on the following line. Push <RETURN>"]
    write_test(filename, data)

def create_cancel(filename, name, code):
    data = [27, "[2J", 27, "[HTest of cancelling escape/control sequence (", name, ")\n\n"]
    data += ["This should '", 27, "[4", code, "m' not be underlined, with 'chequerboard-m' inside the quotes.\n"]
    data += ["\nThis should '", 27, "#", code, "6' be single width with 'chequerboard-6' inside the quotes.\n"]
    data += ["\nPush <RETURN>"]
    write_test(filename, data)

def create_invalid_top_bottom_margin1(filename):
    # Top and bottom margins must be distinct; the minimum scroll region size
    # is two lines. VT100-Hax suggests a VT100 ignores the invalid scroll
    # region here, leaving the previous one in effect.
    data = [27, "[2J", 27, "[10;16r", 27, "[14;14r"]
    data += [27, "[HTest of invalid top/bottom margin 1\n\n"]
    data += ["Line %s\n" % i for i in range(3,24)]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_invalid_top_bottom_margin2(filename):
    # Top and bottom margins are 1-based. VT100-Hax suggests a VT100 treats 0
    # as 1 here.
    data = [27, "[2J", 27, "[10;16r", 27, "[0;14r"]
    data += [27, "[HTest of invalid top/bottom margin 2\n\n"]
    data += ["Line %s\n" % i for i in range(3,24)]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_invalid_top_bottom_margin3(filename):
    # Top and bottom margins are 1-based. VT100-Hax suggests a VT100 treats 0
    # as "last line of screen" here.
    data = [27, "[2J", 27, "[10;16r", 27, "[14;0r"]
    data += [27, "[HTest of invalid top/bottom margin 3\n\n"]
    data += ["Line %s\n" % i for i in range(3,35)]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_invalid_top_bottom_margin4(filename):
    # The top row shouldn't be lower than the bottom row. VT100-Hax suggests a
    # VT100 ignores this invalid scroll region, leaving the previous one in
    # effect.
    data = [27, "[2J", 27, "[10;16r", 27, "[14;13r"]
    data += [27, "[HTest of invalid top/bottom margin 4\n\n"]
    data += ["Line %s\n" % i for i in range(3,24)]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_auto_wrap_set_while_pending(filename):
    # Test of what happens when auto wrap is on and we set it on (redundantly)
    # while an auto wrap is pending.
    data = [27, "[2J", 27, "[HTest of auto wrap set while auto wrap pending\n\n"]
    data += [27, "[?7h"]
    data += ["This sentence should end exactly at the right margin and continue on to the nex-"]
    data += [27, "[?7h"]
    data += ["t line with a hyphen in the word 'next'. Push <RETURN>"]
    write_test(filename, data)

def create_vt52_filler(filename):
    # Test of what happens when "filler" characters appear inside a VT52 escape
    # sequence; testing with VT100-Hax suggests this should work, although
    # xterm doesn't seem to like it.
    data = [27, "[2J", 27, "[HTest of filler characters in VT52 escape sequences\n\n"]
    data += [27, "[?2l"]
    data += ["This          should be complete with no gaps and no other stray text on the\n"]
    data += ["screen."]
    data += [27, "Y", 0, 037+3, 0, 0, 0, 037+6, "sentx", 27, 127, "D", "en", 0, "ce"]
    data += [27, "Y", 037+4, 127, 037+9, "Push <RETURN>"]
    data += [27, "<"]
    write_test(filename, data)

def create_line_attribute_cursor_home(filename):
    # Test of what happens when cursor home is used to move into a line with
    # line attributes.
    data = [27, "[2J", 27, "[HTest of cursor home with line attributes\n\n"]
    data += [27, "#6This is a\n"]
    data += ["This is a single-width line."]
    data += [27, "[3;11H", "double-width line.\n\n\nPush <RETURN>"]
    write_test(filename, data)

def create_line_attribute_erase_in_display1(filename):
    # Test of what happens when a line with non-default line attributes is
    # partially erased by erase in display.
    data = [27, "[2J", 27, "[HTest of erase to end of display with line attributes\n\n"]
    data += [27, "#6This is a double-width line\n"]
    data += [27, "#6Another double-width line (will be erased)"]
    data += [27, "[3;11H", 27, "[Jdouble-width line."]
    data += ["\nThis is a single-width line.\n\nPush <RETURN>"]
    write_test(filename, data)

def create_line_attribute_erase_in_display2(filename):
    # Test of what happens when a line with non-default line attributes is
    # partially erased by erase in display.
    data = [27, "[2J", 27, "[3H"]
    data += [27, "#6This is a double-width line", 27, "[4D"]
    data += [27, "[1J\rThis is a double-width l"]
    data += [27, "[HTest of erase to start of display with line attributes"]
    data += [27, "[5HPush <RETURN>"]
    write_test(filename, data)

def create_line_attribute_erase_in_display3(filename):
    # Test of what happens when a line with non-default line attributes is
    # partially erased by erase in display.
    data = [27, "[2J", 27, "[3H"]
    data += [27, "#6This is a double-width line\r"]
    data += [27, "[2JThis is a single-width line."]
    data += [27, "[HTest of erase entire display with line attributes"]
    data += [27, "[5HPush <RETURN>"]
    write_test(filename, data)

def create_cr_lf(filename):
    data = [27, "[2J", 27, "[HTest of CR and LF\n\n"]
    # Note that we do a "redundant" CR at the start of the line; this would
    # have been broken by one of my optimisations.
    data += ["\rThis sentence should be split into two short lines\n"]
    data += ["XXXX\rstarting at the left margin with no Xs. Push <RETURN>"]
    write_test(filename, data)

def create_linefeed_new_line_mode1(filename):
    # Note that this is a raw test so we don't get automatic \n -> \r\n
    # conversions happening.
    data = [27, "[2J", 27, "[HTest of linefeed/new line mode\n\n\r"]
    data += [27, "[20l"]
    data += ["All the lines\013in this sentence\014should be staggered\nacross the screen."]
    data += ["\n\n\r"]
    data += [27, "[20h"]
    data += ["All the lines\013in this sentence\014should start at the\nleft margin."]
    data += ["\n\n\rPush <RETURN>"]
    write_test(filename, data)

def create_save_restore_outside_margins1(filename):
    # I can't say I'm very happy with this test, but the behaviour has been
    # checked with the vt102 emulator. It seems that even in origin mode, the
    # cursor can be moved outside the margins using ESC 8 to restore a saved
    # cursor position.
    data = [27, "[2J", 27, "[HTest of save/restore cursor attributes outside margins"]
    data += [27, "[?6h", 27, "[22HSome text on line 22. ", 27, "7"]
    data += [27, "[3;20r", 27, "8", "More text on line 22.\nText on line 23."]
    data += [27, "[HSome text on line 3."]
    data += [27, "[?6l", 27, "[r", 27, "[24HPush <RETURN>"]
    write_test(filename, data)

def create_square_bracket1(filename):
    # Behaviour of this test checked against 'vt102' emulator
    data = [27, "[2J", 27, "[HTest of square brackets inside escape/control sequence\n\n"]
    data += [27, "[4[;7mThis line should start with ';7m'\n"]
    data += [27, "#[6This line should start with '6'\n"]
    data += [27, "[[1mThis line should start with '1m'\n"]
    data += ["All the lines should be in normal single-width text. Push <RETURN>"]
    write_test(filename, data)

def create_vt52_character_set1(filename):
    data = [27, "[2J", 27, "[HTest of character set for VT52 mode\n\n"]
    data += [27, "(A", 15, "Pound sterling: #\n"]
    data += [27, ")B", 14, "Hash: #\n"]
    data += [15, 27, "[?2l", "Pound sterling: #\n"]
    data += [14, "Hash: #\n\n"]
    data += [27, "<Push <RETURN>"]
    write_test(filename, data)

def create_vt52_character_set2(filename):
    # Behaviour of this checked with the 'vt102' emulator.
    data = [27, "[2J", 27, "[HTest of character set for VT52 mode with graphics\n\n"]
    # Set G0=UK, G1=US (remember SI (15)=G0, SO (14)=G1)
    data += [27, "(A", 27, ")B"]
    data += ["ANSI mode:\n"]
    data += [15, "G0 (UK) code 35: ", 35, "\n"]
    data += [14, "G1 (US) code 35: ", 35, "\n"]
    data += [27, "[?2l"]
    # Demonstrate that we're still in G1 after switching to VT52 mode, and that
    # we can use SI/SO to change character sets.
    data += ["VT52 mode:\n"]
    data += ["G1 code 35: ", 35, "\n"]
    data += [15, "G0 code 35: ", 35, "\n"]
    data += [14, "G1 code 35: ", 35, "\n"]
    # Demonstrate that switching into graphics mode and back out resets G0 and
    # G1 to US.
    data += [15, "G0 code 35 then plus/minus then US code 35: ", 35, 27, "F", "g", 27, "G", 35, "\n"]
    # Demonstrate that switching back to ANSI mode doesn't alter the character
    # sets.
    data += [27, "<", "US code 35 twice: ", 14, 35, 15, 35, "\n"]
    data += ["\nPush <RETURN>"]
    write_test(filename, data)

def create_auto_wrap_scroll(filename):
    data = [27, "[2J", 27, "[HTest of auto wrap with scrolling\n\n"]
    data += [27, "[3;4r", 27, "[3H\n"]
    data += ["This sentence should wrap neatly around at the right margin, without any strangespacing or other formatting errors. Push <RETURN>"]
    data += [27, "[r"]
    write_test(filename, data)

def create_reset(filename):
    data = [27, "[3;10r", 27, "[?6h", 27, "H"]
    data += [27, "[?5h"]
    data += [27, "[?20h"]
    data += [27, "[4h"]
    data += [27, "[4m"]
    data += [27, "c"]
    data += ["Test of reset\n\n"]
    # junk would be pushed right and not overwritten if insert mode weren't
    # reset.
    data += ["junk\rThis should be normal text with no reverse video on\n"]
    data += ["the top four lines of the screen. Push <RETURN>"]
    write_test(filename, data)

def create_control_sequence_intermediate_character1(filename):
    data = [27, "[2J", 27, "[HTest of control sequences with intermediate characters"]
    # Testing with the 'vt102' emulator suggests the presence of intermediate
    # characters causes the escape sequence to be ignored.
    data += [27, "[3H", 27, "[##H"]
    data += ["This should appear at the left margin on line 3. Push <RETURN>"]
    write_test(filename, data)

def create_not_quite_line_attributes(filename):
    # Simplified version of failure found with fuzz tester; the line attribute
    # code was updating the flags before it checked for the presence of the
    # essential # intermediate character; this caused the question mark to be
    # printed in single height, single width. (Nothing special about the
    # question mark, just an arbitrary character chosen for this test.) FWIW,
    # the seed which found it was 1529457 (on a Master 128); B% gets to about
    # 45000 at the failure point, which is caught because *REDRAW changes the
    # screen.
    data = [27, "[2J", 27, "[HTest of not-quite-line-attributes\n\n"]
    data += [27, "#3Double-height question mark: ", 27, "5?\n"]
    data += [27, "#4Double-height question mark: ", 27, "5?\n\n"]
    data += ["The double-height question mark should actually be double height. Push <RETURN>"]
    write_test(filename, data)

def create_insert_line_line_attributes(filename):
    # Simplified version of failure found with fuzz tester (Master
    # 128, S%=13569, B%=507904); the fast path cursor position wasn't being
    # updated when an insert line changed the line attributes.
    data = [27, "[2J", 27, "[H", 27, "#3Double-height text"]
    data += [27, "[Le with non-default line attributes"]
    data += [13, "Test of insert lin"]
    data += ["\n", 27, "[L", "\n\n", 27, "#4Double-height text\n\n"]
    data += ["The top line should be the test title in single-width text with no gaps. Beneath"]
    data += ["that should be some double-height text. Push <RETURN>"]
    write_test(filename, data)

def create_delete_line_line_attributes(filename):
    # Test of delete line inspired by create_insert_line_line_attributes()
    data = [27, "[2J", 27, "[HTest of delete line with non-default line attributes\n\n"]
    data += [27, "#3foo", 27, "[Ms text should be single-width with no gaps. Push <RETURN>"]
    data += [27, "7", 13, "Thi", 27, "8"]
    write_test(filename, data)

def create_insert_delete_characters_with_attributes1(filename):
    # Simplified version of failure found with fuzz tester (Master 128,
    # S%=60605376, B%=102400); insert characters was not correctly inserting
    # characters with the underline attribute set. Behaviour of the delete
    # character part of this checked with 'vt102' emulator (it doesn't support
    # insert character).
    data = [27, "[2J", 27, "[HTest of insert/delete characters with character attributes 1"]
    data += [27, "[3g", 27, "[1;80H", 27, "H", "\n"]
    # The ordering of these tests is important for verifying the output; this
    # way the reverse video underline is visible as it forms a line in the two adjacent
    # reverse video lines, and the non-reverse video underline is visible as
    # it's not adjacent to any reverse video.
    data += ["\nThis line contains a '", 27, "7' quoted reverse video underlined blank."]
    data += [27, "8", 27, "[4;7m", 27, "[4@", 27, "[0m"]
    data += ["\nThis line contains a '", 27, "7' quoted reverse video blank."]
    data += [27, "8", 27, "[7m", 27, "[4@", 27, "[0m"]
    data += ["\nThis line contains a '", 27, "7' quoted underlined blank."]
    data += [27, "8", 27, "[4m", 27, "[4@", 27, "[0m"]
    data += ["\nThis line has a reverse video underlined blank at the right margin."]
    data += [27, "7", 27, "[4;7m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\nThis line has a reverse video blank at the right margin."]
    data += [27, "7", 27, "[7m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\nThis line has an underlined blank at the right margin."]
    data += [27, "7", 27, "[4m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_insert_delete_characters_with_attributes2(filename):
    # Double-width version of create_insert_delete_characters_with_attributes1
    data = [27, "[2J", 27, "[HTest of insert/delete characters with character attributes 2"]
    data += [27, "[3g", 27, "[1;80H", 27, "H", "\n"]
    # The ordering of these tests is important for verifying the output; this
    # way the reverse video underline is visible as it forms a line in the two adjacent
    # reverse video lines, and the non-reverse video underline is visible as
    # it's not adjacent to any reverse video.
    data += ["\n", 27, "#6'", 27, "7' reverse video underlined blank"]
    data += [27, "8", 27, "[4;7m", 27, "[4@", 27, "[0m"]
    data += ["\n", 27, "#6'", 27, "7' reverse video blank"]
    data += [27, "8", 27, "[7m", 27, "[4@", 27, "[0m"]
    data += ["\n", 27, "#6'", 27, "7' quoted underlined blank"]
    data += [27, "8", 27, "[4m", 27, "[4@", 27, "[0m"]
    data += ["\n", 27, "#6Reverse video underlined right"]
    data += [27, "7", 27, "[4;7m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\n", 27, "#6Reverse video blank right"]
    data += [27, "7", 27, "[7m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\n", 27, "#6Underlined blank right"]
    data += [27, "7", 27, "[4m", "\t ", 27, "8", 27, "[4P", 27, "[0m"]
    data += ["\n\nPush <RETURN>"]
    write_test(filename, data)

def create_delete_line_high_count(filename):
    # Test case for a bug found in the implemetation of delete_line where
    # bottom_margin + 1 - count was negative.
    data = [27, "[2J", 27, "[HTest of delete line with high count"]
    data += [27, "[7HLine 5"]
    data += [27, "[3;6r", 27, "[3HLine 1\nLine 2\nLine 3\nLine 4"]
    data += [27, "[4H", 27, "[7M"]
    data += [27, "[r", 27, "[4Hx\nx\nx\n\n\n"]
    data += ["There should be three lines with just 'x' on between line 1 and line 5.\n"]
    data += ["Push <RETURN>"]
    write_test(filename, data)

def create_delete_character_high_count(filename):
    # Test case for a bug found in the implementation of delete_character where
    # line_length - count was negative; because the count is clamped at 80,
    # this can only occur with double-width lines.
    data = [27, "[2J", 27, "[HTest of delete character with high count\n\n"]
    data += [27, "#6", "This sentence should be double-width JUN"]
    data += [27, "[3D"]
    data += [27, "[81P"]
    data += ["\n", 27, "#6with no stray words. Push <RETURN>"]
    write_test(filename, data)

# TODO: Add test cases for double-height/width underlined/bold/reverse video in
# various combinations


try:
    os.mkdir("generated")
except OSError as e:
    if e.errno == errno.EEXIST:
        pass
    else:
        raise

create_single_shift3("ss-3.dat")
create_single_shift2("ss-2.dat")
create_auto_wrap_insert("awi-1.dat")
create_abandoned_escape1("ae-1.dat")
create_abandoned_escape2("ae-2.dat")
create_pip("pip-1.dat")
create_unrecognised_escape_sequence("ue-1.dat")
create_unrecognised_control_sequence("ue-2.dat")
create_long_escape_sequence("long-1.dat")
create_long_control_sequence_i("long-2.dat")
create_long_control_sequence_p("long-3.dat")
create_acorn_mode1("acorn-1.dat")
create_tab_double_width("tabdw-1.dat")
create_set_cursor_off_screen1("cos-1.dat")
create_set_cursor_off_screen2("cos-2.dat")
create_save_restore_double_width("srdw-1.dat")
create_save_restore_auto_wrap("sraw-1.dat")
create_line_attribute_scroll1("las-1.dat")
create_line_attribute_scroll2("las-2.dat")
create_cr_auto_wrap("craw-1.dat")
create_double_width_erase("dwe-1.dat")
create_mixed_width_cursor_move("mwcm-1.dat", "(IND/RI)", chr(27) + "D", chr(27) + "M")
create_mixed_width_cursor_move("mwcm-2.dat", "(CUD/CUU)", chr(27) + "[B", chr(27) + "[A")
create_move_outside_scroll_region1("mos-1.dat")
create_move_outside_scroll_region2("mos-2.dat")
create_delete_line_character_attributes("dlca-1.dat")
create_single_shift1("ss-1.dat")
create_delete_character_reverse_video("dcrv-1.dat")
create_line_attribute_no_stored("lans-1.dat", "normal", "")
create_line_attribute_no_stored("lans-2.dat", "bold", chr(27) + "[1m")
create_tab_clear("tc-1.dat")
create_cancel("can-1.dat", "CAN", chr(0x18))
create_cancel("can-2.dat", "SUB", chr(0x1a))
create_invalid_top_bottom_margin1("itbm-1.dat")
create_invalid_top_bottom_margin2("itbm-2.dat")
create_invalid_top_bottom_margin3("itbm-3.dat")
create_invalid_top_bottom_margin4("itbm-4.dat")
create_auto_wrap_set_while_pending("awsp-1.dat")
create_vt52_filler("v52f-1.dat")
create_line_attribute_cursor_home("lach-1.dat")
create_line_attribute_erase_in_display1("laeid-1.dat")
create_line_attribute_erase_in_display2("laeid-2.dat")
create_line_attribute_erase_in_display3("laeid-3.dat")
create_cr_lf("crlf-1.dat")
create_linefeed_new_line_mode1("lnm-1.dat")
create_save_restore_outside_margins1("srom-1.dat")
create_square_bracket1("sb-1.dat")
create_vt52_character_set1("v52cs-1.dat")
create_vt52_character_set2("v52cs-2.dat")
create_auto_wrap_scroll("aws-1.dat")
create_reset("rs-1.dat")
create_control_sequence_intermediate_character1("csic-1.dat")
create_not_quite_line_attributes("nqla-1.dat")
create_insert_line_line_attributes("illa-1.dat")
create_delete_line_line_attributes("dlla-1.dat")
create_insert_delete_characters_with_attributes1("idcwa-1.dat")
create_insert_delete_characters_with_attributes2("idcwa-2.dat")
create_delete_line_high_count("dlhc-1.dat")
create_delete_character_high_count("dchc-1.dat")

# TODO: The first element in each item in tests is never used; my original
# intention was that it might be a more descriptive name which we'd store in a
# convenient index and which a test harness would use to provide a menu of
# individual tests to choose from.
tests = [
    ["dchc-1.dat", File("dchc-1.dat"), Crc(0x10d9), Return()],
    ["dlhc-1.dat", File("dlhc-1.dat"), Crc(0x8f22), Return()],
    ["idcwa-1.dat", File("idcwa-1.dat"), Crc(0xe696, 0x68d4), Return()],
    ["idcwa-2.dat", File("idcwa-2.dat"), Crc(0xd50c, 0xa255), Return()],
    ["dlla-1.dat", File("dlla-1.dat"), Crc(0x4abb), Return()],
    ["illa-1.dat", File("illa-1.dat"), Crc(0x118), Return()],
    ["nqla-1.dat", File("nqla-1.dat"), Crc(0xfebe), Return()],
    ["csic-1.dat", File("csic-1.dat"), Crc(0xa998), Return()],
    ["rs-1.dat", File("rs-1.dat"), Crc(0xeeed), Return()],
    ["aws-1.dat", File("aws-1.dat"), Crc(0xbb54), Return()],
    ["v52cs-1.dat", File("v52cs-1.dat"), Crc(0x6828), Return()],
    ["v52cs-2.dat", File("v52cs-2.dat"), Crc(0x2f70), Return()],
    ["sb-1.dat", File("sb-1.dat"), Crc(0x5a5e), Return()],
    ["srom-1.dat", File("srom-1.dat"), Crc(0xfbc), Return()],
    ["lnm-1.dat", File("lnm-1.dat", True), Crc(0x4c97), Return()],
    ["crlf-1.dat", File("crlf-1.dat"), Crc(0x879b), Return()],
    ["laeid-1.dat", File("laeid-1.dat"), Crc(0x94fc), Return()],
    ["laeid-2.dat", File("laeid-2.dat"), Crc(0xe372), Return()],
    ["laeid-3.dat", File("laeid-3.dat"), Crc(0xeb8a), Return()],
    ["lach-1.dat", File("lach-1.dat"), Crc(0xdb9d), Return()],
    ["v52f-1.dat", File("v52f-1.dat"), Crc(0xb5dd), Return()],
    ["awsp-1.dat", File("awsp-1.dat"), Crc(0x638b), Return()],
    ["itbm-1.dat", File("itbm-1.dat"), Crc(0x15ec), Return()],
    ["itbm-2.dat", File("itbm-2.dat"), Crc(0x6f30), Return()],
    ["itbm-3.dat", File("itbm-3.dat"), Crc.line_based(0x3d22, 0x9b98, 0xb61b), Return()],
    ["itbm-4.dat", File("itbm-4.dat"), Crc(0xc4f8), Return()],
    ["can-1.dat", File("can-1.dat"), Crc(0x1819), Return()],
    ["can-2.dat", File("can-2.dat"), Crc(0xe010), Return()],
    ["tc-1.dat", File("tc-1.dat"), Crc(0xfb03), Return()],
    ["lans-1.dat", File("lans-1.dat"), Crc(0xd9d4, 0x4c53), Return()],
    ["lans-2.dat", File("lans-2.dat"), Crc(0xceed, 0xb691), Return()],
    ["dcrv-1.dat", File("dcrv-1.dat"), Crc(0x7080, 0xd5b0), Return()],
    ["ss-1.dat", File("ss-1.dat"), Crc(0x67db), Return()],
    ["ss-2.dat", File("ss-2.dat"), Crc(0xc100), Return()],
    ["ss-3.dat", File("ss-3.dat"), Crc(0x95e9), Return()],
    ["dlca-1.dat", File("dlca-1.dat"), Crc(0xe7b9), Return()],
    ["mos-1.dat", File("mos-1.dat"), Crc(0x3d1a), Return()],
    ["mos-2.dat", File("mos-2.dat"), Crc(0x670e), Return()],
    ["mwcm-1.dat", File("mwcm-1.dat"), Crc(0x24e), Return()],
    ["mwcm-2.dat", File("mwcm-2.dat"), Crc(0x123b), Return()],
    ["dwe-1.dat", File("dwe-1.dat"), Crc(0x9b71, 0x5acb), Return()],
    ["craw-1.dat", File("craw-1.dat"), Crc(0x98a6), Return()],
    ["las-1.dat", File("las-1.dat"), Crc(0x25a7), Return()],
    ["las-2.dat", File("las-2.dat"), Crc.line_based(0x6a9b, 0xa712, 0x8e75), Return()],
    ["sraw-1.dat", File("sraw-1.dat"), Crc(0x09cc), Return()],
    ["srdw-1.dat", File("srdw-1.dat"), Crc(0x8a4d), Return()],
    ["cos-1.dat", File("cos-1.dat"), Crc.line_based(0x1f05, 0x4291, 0xda7e), Return()],
    ["cos-2.dat", File("cos-2.dat"), Crc.line_based(0xc8b1, 0x9882, 0x61d1), Return()],
    ["tabdw-1.dat", File("tabdw-1.dat"), Crc(0x5292), Return()],
    ["acorn-1.dat", File("acorn-1.dat"), Crc(0x3499), Return()],
    ["long-1.dat", File("long-1.dat"), Crc(0xe6f4), Return()],
    ["long-2.dat", File("long-2.dat"), Crc(0x70f0), Return()],
    ["long-3.dat", File("long-3.dat"), Crc(0x70f0), Return()],
    ["ue-1.dat", File("ue-1.dat"), Crc(0x4ef5), Return()],
    ["ue-2.dat", File("ue-2.dat"), Crc(0x98a5), Return()],
    ["pip-1.dat", File("pip-1.dat"), Crc(0xe865), Return()],
    ["awi-1.dat", File("awi-1.dat"), Crc(0x4502), Return()],
    ["ae-1.dat", File("ae-1.dat"), Crc(0xda2c), Return()],
    ["ae-2.dat", File("ae-2.dat"), Crc(0x6d69), Return()],
    ["vttest4-1", File("setup1.dat"), File("vttest4-1.dat"), Crc(0x7885, 0x7b63), Return()],
    ["vttest4-2", File("vttest4-2.dat"), Crc(0xcc98, 0xcf7e), Return()],
    ["vttest4-3", File("vttest4-3.dat"), Crc(0x3232), Return()],
    ["vttest4-4", File("vttest4-4.dat"), Crc(0xed6f), Return()],
    ["vttest1-1", File("setup1.dat"), File("vttest1-1.dat"), Crc(0x01b5), Return()],
    ["vttest1-2", File("deccolm.dat"), File("vttest1-2.dat"), Crc(0xfa62), Return()],
    ["vttest1-3", File("deccolm.dat"), File("vttest1-3.dat"), Crc(0x4403), Return()],
    ["vttest1-4", File("vttest1-4.dat"), Crc(0xd7bf), Return()],
    ["vttest7-1", File("setup1.dat"), File("vttest7-1.dat"), Crc(0xa617), Return()],
    ["vttest7-2", File("vttest7-2.dat"), Crc(0x3817), Return()],
    ["vt52-off", File("vt52-off.dat")],
    ["vttest3-1", File("setup1.dat"), File("vttest3-1.dat"), Crc(0xe203), Return()],
    ["vttest2-1", File("setup1.dat"), File("vttest2-1.dat"), Crc(0xe8ae), Return()],
    ["vttest2-2", File("vttest2-2.dat"), Crc(0x6454), Return()],
    ["vttest2-3", File("vttest2-3.dat"), Crc(0x932f), Return()],
    ["vttest2-4", File("vttest2-4.dat"), Crc(0x5c73), Return()],
    ["vttest2-5", File("vttest2-5.dat"), Crc(0x621d), Return()],
    ["vttest2-6", File("vttest2-6.dat"), Crc(0x2ec2), Return()],
    ["vttest2-7", File("vttest2-7.dat"), Crc(0x6bae), Return()],
    ["vttest2-8", File("vttest2-8.dat"), Crc(0x8569), Return()],
    ["vttest2-9", File("vttest2-9.dat"), Crc(0x6131), Return()],
    ["vttest2-10", File("vttest2-10.dat"), Crc(0xd6a5), Return()],
    ["vttest2-11", File("vttest2-11.dat"), Crc(0xb6b8), Return()],
    ["vttest8-1", File("setup1.dat"), File("vttest8-1.dat"), Crc(0xe517), Return()],
    ["vttest8-2", File("vttest8-2.dat"), Crc(0xdcf0), Return()],
    ["vttest8-3", File("vttest8-3.dat"), Crc(0xcdac), Return()],
    ["vttest8-4", File("vttest8-4.dat"), Crc(0xaa48), Return()],
    ["vttest8-5", File("vttest8-5.dat"), Crc(0x3ca3), Return()],
    ["vttest8-5d", File("vttest8-5d.dat"), Crc(0x1fd0), Return()],
    ["vttest8-6", File("vttest8-6.dat"), Crc(0x6435), Return()]
]

output = open(os.path.join("generated", "tests.dat"), "wb")
for test in tests:
    name = test[0]
    for component in test[1:]:
        component.write(output)
