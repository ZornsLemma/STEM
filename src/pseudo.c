// We have to record the characters on the screen and their attributes, as well
// as the line attributes. This is an enormous faff but without it we can't
// correctly handle lines changing between single width characters and double
// width/height characters. (To take one problematic case, suppose a line
// changes from 'double height bottom' to 'double height top'; the video RAM
// alone doesn't contain the information we need to do this.)
//
// [I did labour under the delusion we could get away with storing only the
// leftmost 40 characters of each line, but that's not good enough. Suppose we
// have an 80 character (single width) line, and we delete 10 characters at X
// position 35. That moves the character which was at position 45 into position
// 35. The line is then made double width, so we need to know the character at
// position 35, which we only know if we were able to move the character from
// position 45 to 35 in the stored screen when we deleted those 10 characters.]
//
// This takes a lot of memory. We store each character in its own byte but we
// pack the character attributes for two characters into a single byte to save
// space. So we have 32 lines of 80x1.5 bytes. This is conveniently 15*256, i.e.
// an exact number of 256-byte pages - this is useful because just as the
// hardware screen starts at a variable address within the screen RAM to
// implement hardware scrolling (saving the need to copy nearly 20K of data
// every time it scrolls by one line), we do the same with the stored screen,
// which means we need to handle wrapping, and it's convenient to only have to
// take the high byte of the address into account when wrapping.
//
// The line attributes are stored separately; this was originally motivated by
// not spoiling the exact multiple of 256 bytes for the stored screen, but it
// actually works out for the best, as it's pretty much essential to track the
// line attributes even if there's no stored screen. They are held in a separate
// 32-byte array of line attributes. We could use the same "variable start
// address" trick here, but it's easier to always have line 0 held in the first
// byte of the array and manually shuffle the data around (it's only 31 bytes to
// move at worst) than to faff around wrapping.
const unsigned stored_line_len_chars = 80;
const unsigned stored_line_len_bytes = stored_line_len_chars * 3 / 2;
const unsigned max_screen_lines = 32;
const unsigned stored_screen_size = max_screen_lines * stored_line_len_bytes;
char stored_screen[stored_screen_size];
unsigned stored_screen_start_line = 0;
char line_attributes[max_screen_lines];

// The top and bottom margins of the scrolling region. These are 0-based screen
// Y-coordinates, and both are *inclusive*. We always have 0 <= top_margin <
// bottom_margin < emulated_screen_lines and top_margin <= cursor_y <=
// bottom_margin.
unsigned top_margin;
unsigned bottom_margin;

void insert_line(unsigned count)
{
    if ((cursor_y < top_margin) || (cursor_y > bottom_margin))
    {
        return;
    }

    page_in_video_ram();
    copy_lines_within_margins(cursor_y, cursor_y + count);
    erase_lines_within_margins(cursor_y, cursor_y + count);
    page_in_main_ram();
}

void delete_line(unsigned count)
{
    if ((cursor_y < top_margin) || (cursor_y > bottom_margin))
    {
        return;
    }

    page_in_video_ram();
    copy_lines_within_margins(cursor_y + count, cursor_y);
    int from = bottom_margin + 1 - count; // may be negative
    from = max(cursor_y, from);
    erase_lines_within_margins((unsigned) from, max_screen_lines);
    page_in_main_ram();
}

// Corresponds to .index_scroll; needs to cope with scrolls of the
// scrolling region or the full screen.
void index_scroll()
{
    page_in_video_ram();

    bool scroll_entire_screen = scrolling_region_is_entire_screen();
    if (scroll_entire_screen)
    {
        erase_lines_within_margins(0, 1);

        // max_screen_lines is a power of two...
        stored_screen_start_line = (stored_screen_start_line + 1) & (max_screen_lines - 1);

        for (unsigned i = 1; i < emulated_screen_lines; ++i)
        {
            line_attributes[i - 1] = line_attributes[i];
        }
        line_attributes[emulated_screen_lines - 1] = 0;

        use_os_to_hardware_scroll_video_ram_up();
    }
    else
    {
        copy_lines_within_margins(top_margin + 1, top_margin);
        erase_lines_within_margins(bottom_margin, max_screen_lines);
    }

    page_in_main_ram();
}

// Corresponds to .reverse_index_scroll; needs to cope with scrolls of
// the scrolling region or the full screen. 
void reverse_index_scroll()
{
    page_in_video_ram();

    bool scroll_entire_screen = scrolling_region_is_entire_screen();
    if (scroll_entire_screen)
    {
        erase_lines_within_margins(bottom_margin, bottom_margin + 1);

        // max_screen_lines is a power of two...
        stored_screen_start_line = (stored_screen_start_line - 1) & (max_screen_lines - 1);

        for (unsigned i = emulated_screen_lines - 1; i >= 1; --i)
        {
            line_attributes[i] = line_attributes[i - 1];
        }
        line_attributes[0] = 0;

        use_os_to_hardware_scroll_video_ram_down();

    }
    else
    {
        copy_lines_within_margins(top_margin, top_margin + 1);
        erase_lines_within_margins(top_margin, top_margin + 1);
    }

    page_in_main_ram();
}

// corresponds to .ne_iff_partial_screen_scroll
bool scrolling_region_is_entire_screen()
{
    return (top_margin == 0) && ((bottom_margin + 1) == emulated_screen_lines);
}

// corresponds to .insert_a_characters
// Insert characters at the current cursor position, moving existing characters
// to the right; any which move off the end of the stored screen/video RAM line
// are lost. This works whether or not the line is double width. The inserted
// characters have the current character attributes.
void insert_characters(unsigned count)
{
    page_in_video_ram();

    unsigned to = logical_cursor_x + count;
    copy_characters_within_line(logical_cursor_x, to);
    erase_characters_within_line(logical_cursor_x, to, current_character_attributes);

    page_in_main_ram();
}

// corresponds to .delete_character
// Delete 'count' characters at the current cursor position, moving existing
// characters left into the space created; we fill the gap created at the right
// hand end of the line with spaces. This works whether or not the line is
// double width. The spaces created at the right all have the character
// attributes of the character at the far right of the line before this
// operation.
void delete_characters(unsigned count)
{
    page_in_video_ram();

    unsigned line_len = (is_current_line_double_width() ? 40 : 80);
    char character; // not used
    char character_attributes;
    get_stored_character(line_len - 1, cursor_y, &character, &character_attributes);
    copy_characters_within_line(logical_cursor_x + count, logical_cursor_x);
    unsigned erase_from = max(line_len - count, logical_cursor_x);
    erase_characters_within_line(erase_from, 80, character_attributes);

    page_in_main_ram();
}

// corresponds to .erase_to_end_of_screen
void erase_in_display_to_end_of_screen()
{
    page_in_video_ram();

    erase_characters_within_line(logical_cursor_x, 80, 0 /* character attributes */)
    // We don't use max_screen_lines here as a) in mode 3, that would
    // incorrectly wrap back round to the start of the screen b) in mode 0 in 25
    // line mode, it correctly but unnecessarily erases the unused lines.
    erase_lines_within_screen(cursor_y + 1, emulated_screen_lines);

    page_in_main_ram();
}

// corresponds to .erase_to_start_of_screen
void erase_in_display_to_start_of_screen()
{
    page_in_video_ram();

    erase_characters_within_line(0, logical_cursor_x + 1, 0 /* character attributes */)
    erase_lines_within_screen(0, cursor_y);

    page_in_main_ram();
}

// corresponds to .erase_screen_subroutine
void erase_in_display_entire_screen()
{
    page_in_video_ram();
    // As in erase_in_display_to_end_of_screen(), we cannot use max_screen_lines
    // here.
    erase_lines_within_screen(0, emulated_screen_lines);
    page_in_main_ram();
}

void erase_in_line_to_start_of_line()
{
    page_in_video_ram();
    erase_characters_within_line(0, logical_cursor_x + 1, 0 /* character attributes */);
    page_in_main_ram();
}

void erase_in_line_to_end_of_line()
{
    page_in_video_ram();
    erase_characters_within_line(logical_cursor_x, 80, 0 /* character attributes */);
    page_in_main_ram();
}

void erase_in_line_entire_line()
{
    page_in_video_ram();
    erase_characters_within_line(0, 80, 0 /* character attributes */);
    page_in_main_ram();
}

// Copies up to 80 characters from logical cursor position 'from' within the current
// line to logical cursor position 'to', operating on both the stored screen and
// the video RAM. 'from' may be greater or less than 'to'. This works for single
// and double width lines. Bounds checking is performed so 'from'/'to' may
// index off the right hand edge of the line safely; similarly if 'from+80'
// or 'to+80' indexes off the right hand edge of the line this is harmless.
void copy_characters_within_line(unsigned from, unsigned to)
{
    copy_characters_within_line_stored_screen(from, to);
    copy_characters_within_line_video_ram(from, to);
}

void copy_characters_within_line_stored_screen(unsigned from, unsigned to)
{
    unsigned line_len = (is_current_line_double_width() ? 40 : 80);
    from = min(from, line_len);
    to = min(to, line_len);
    count = min(line_len - to, line_line - from); // may be 0

    // This is inefficient but simple; we can always do some clever optimisation
    // here later, although to be honest I suspect this isn't going to be that
    // critical.
    if (from > to)
    {
        for (unsigned i = 0; i < count; ++i)
        {
            char character;
            char character_attributes;
            get_stored_character(from + i, &character, &character_attributes);
            set_stored_character(to + i, character, character_attributes);
        }
    }
    else if (from < to)
    {
        for (int i = count - 1; i >= 0; --i)
        {
            char character;
            char character_attributes;
            get_stored_character(from + i, &character, &character_attributes);
            set_stored_character(to + i, character, character_attributes);
        }
    }
}

void copy_characters_within_line_video_ram(unsigned from, unsigned to)
{
    if (is_current_line_double_width())
    {
        from *= 2;
        to *= 2;
    }

    from = min(from, 80);
    to = min(to, 80);
    count = min(80 - to, 80 - from); // may be 0

    const char *video_ram_from = get_video_ram_character_address_physical_x_unwrapped(from, cursor_y);
    char *video_ram_to = get_video_ram_character_address_physical_x_unwrapped(to, cursor_y);
    unsigned video_ram_count = count * 8;
    memmove(video_ram_to, video_ram_from, video_ram_count, video_ram_start, 0x8000);
}

// Erases characters from 'from' inclusive to 'to' exclusive in the current
// line, replacing them with spaces which have the specified character
// attributes. 'from' and 'to' are clamped to the actual line length so this is
// safe to call with overly-large values. Double-width lines are supported.
void erase_characters_within_line(unsigned from, unsigned to, char character_attribute)
{
    // The case from > to doesn't really make sense; it could be defined as a
    // no-op but it should never happen.
    assert(from <= to);

    erase_characters_within_line_stored_screen(from, to, character_attribute);
    erase_characters_within_line_video_ram(from, to);
}

void erase_characters_within_line_stored_screen(unsigned from, unsigned to, char character_attribute)
{
    from = min(from, stored_line_len_chars);
    to = min(to, stored_line_len_chars);
    // Note we may have from == to, in which case this is a no-op
    for (unsigned i = from; i < to; ++i)
    {
        set_stored_character(i, ' ', character_attributes);
    }
}

void erase_characters_within_line_video_ram(unsigned from, unsigned to, char character_attribute)
{
    if (is_current_line_double_width())
    {
        from *= 2;
        to *= 2;
    }
    from = min(from, 80);
    to = min(to, 80);
    char *video_ram_from = get_video_ram_character_address_physical_x_unwrapped(from, cursor_y);
    char *video_ram_to = get_video_ram_character_address_physical_x_unwrapped(to, cursor_y);
    char fill = (character_attribute & character_attribute_reverse) ? 255 : 0;
    memset(fill, video_ram_from, video_ram_to);
    if (character_attribute & character_attribute_underline)
    {
        for (char *p = video_ram_from; p < video_ram_to; p += 8)
        {
            *wrap(p + 7) ^= 255;
        }
    }
}

char *stored_screen_current_line_start()
{
    return stored_screen_line_start_unwrapped(cursor_y);
}

// corresponds to .get_stored_screen_line_a_start_to_zp_x_unwrapped
char *stored_screen_line_start_unwrapped(unsigned y)
{
    unsigned adjusted_y = stored_screen_start_line + y;
    return stored_screen + (stored_line_len_chars * adjusted_y);
}

// Copy up to 32 lines starting at line 'from' to line 'to'. 'from' and
// 'to' must be >= top_margin; bounds checking is performed against the bottom
// margin automatically. It is OK if 'count' implies copying past the bottom
// margin; the bounds checking takes care of this. 'from' and 'to' are
// screen-relative 0-based coordinates; the name 'within_margins' just relates
// to the clipping boundaries used internally.
void copy_lines_within_margins(unsigned from, unsigned to)
{
    assert(from >= top_margin);
    assert(to >= top_margin);
    from = min(from, bottom_margin + 1);
    to = min(to, bottom_margin + 1);
    count = min(count, bottom_margin + 1 - from, bottom_margin + 1 - to);
    count = min(count, max_screen_lines);
    if (count == 0)
    {
        return;
    }

    const char *stored_screen_from = stored_screen_line_start_unwrapped(from);
    char *stored_screen_to = stored_screen_line_start_unwrapped(to);
    unsigned stored_screen_count = count * stored_line_len_bytes;
    memmove(stored_screen_to, stored_screen_from, stored_screen_count, 
            stored_screen, stored_screen + stored_screen_size);

    if (from > to)
    {
        for (unsigned i = 0; i < count; ++i)
        {
            line_attributes[to + i] = line_attributes[from + i];
        }
    }
    else if (from < to)
    {
        for (int i = count - 1; i >= 0; --i)
        {
            line_attributes[to + i] = line_attributes[from + i];
        }
    }

    const char *video_ram_from = get_video_ram_character_address_physical_x_unwrapped(0, from);
    const char *video_ram_to = get_video_ram_character_address_physical_x_unwrapped(0, to);
    unsigned video_ram_count = count * 640;
    memmove(video_ram_to, video_ram_from, video_ram_count, video_ram_start, 0x8000);
}

// Erase lines (screen-oriented co-ordinates, not margin-relative - this is only
// 'within margins' in the sense that's what the bounds clamping uses) from
// 'from' inclusive to 'to' exclusive. Both 'from' and 'to' must be >=
// top_margin; they will be clamped to the bottom margin.
void erase_lines_within_margins(unsigned from, unsigned to)
{
    assert(from >= top_margin);
    assert(to >= top_margin);
    from = min(from, bottom_margin + 1);
    to = min(to, bottom_margin + 1);

    erase_lines_within_screen(from, to, false);
}

// Erase lines from 'from' inclusive to 'to' exclusive. No bounds checking is
// performed on either 'from' or 'to'; both must be in the range
// 0-emulated_screen_lines inclusive. If 'from==to' this is a no-op. If
// 'stored_only' is true, the video RAM will not be modified.
void erase_lines_within_screen(unsigned from, unsigned to, bool stored_only)
{
    assert(from <= to);
    assert(from <= emulated_screen_lines);
    assert(to <= emulated_screen_lines);

    char *stored_screen_from = stored_screen_line_start_unwrapped(from);
    char *stored_screen_to = stored_screen_line_start_unwrapped(to);
    memset(' ', stored_screen_from, stored_screen_to, 
           stored_screen, stored_screen + stored_screen_size);
    
    for (unsigned i = from; i < to; ++i)
    {
        line_attributes[i] = 0;
    }

    if (stored_only)
    {
        return;
    }

    char *video_ram_from = get_video_ram_character_address_physical_x_unwrapped(0, from);
    char *video_ram_to = get_video_ram_character_address_physical_x_unwrapped(0, to);
    memset(0, video_ram_from, video_ram_to, video_ram_start, 0x8000);
}

// Set memory from 'start' inclusive to 'end' exclusive to c; they may point past
// the 'end' of the actual memory to be set, wrapping will be performed at
// 'wrap_top' to 'wrap_bottom'.
void memset(char c, char *start, char *end, char *wrap_bottom, char *wrap_top)
{
    assert(start <= end);
    assert(wrap_bottom < wrap_top);

    // We have to check for this explicitly, as otherwise the wrapping makes
    // this indistinguishable from a full clear. Consider memset(0, 0x3100,
    // 0x8100, 0x3000, 0x8000); after wrapping this has start=end=0x3100, so we
    // must treat this below as a non-empty operation.
    if (start == end)
    {
        return;
    }

    ptrdiff_t wrap_adjust = wrap_top - wrap_bottom;
    // note strictly greater than - must be consistent with end otherwise start
    // == end == wrap_top would not be a no-op
    if (start > wrap_top) 
    {
        start -= wrap_adjust;
    }
    if (end > wrap_top) // note strictly greater than
    {
        end -= wrap_adjust;
    }

    if (start >= end)
    {
        // Because we only wrapped end if it was strictly greater than wrap_top
        // above, we should only get here if there's actually at least one byte
        // to set.
        assert(end > wrap_bottom);
        memset(c, wrap_bottom, end, wrap_bottom, wrap_top); // can enter at memset_unwrapped
        end = wrap_top;
    }

// memset_unwrapped
    y = lo(start);
    for (x = hi(end) - hi(start); x > 0; --x) // may make 0 passes
    {
        for (; y < 256; ++y)
        {
            page[hi(start)][y] = c;
        }
        y = 0;
        ++hi(start);
    }
    assert(hi(start) == hi(end));
    // We've now set everything except the bytes in the end page
    for (; y < lo(end); ++y) // may make 0 passes round this loop
    {
        page[hi(start)][y] = c;
    }
}

// Copy 'count' bytes from 'from' to 'to', coping correctly if the ranges
// overlap. 'from' and/or 'to' may point past the end of the actual memory to be
// moved; wrapping will be performed at 'wrap_top' to 'wrap_bottom'.
void memmove(char *to, char *from, unsigned count, char *wrap_bottom, char *wrap_top)
{
    assert(wrap_bottom < wrap_top);
    ptrdiff_t wrap_adjust = wrap_top - wrap_bottom;
    if (to == from) { return; }

    if (from > to)
    {
        if (from >= wrap_top) from -= wrap_adjust;
        if (to >= wrap_top) to -= wrap_adjust;

        y    = from & 0x00ff;
        from = from & 0xff00;
        to   = to - y;

        while (count > 0)
        {
            chunk_size = min(count, wrap_top - (from + y), wrap_top - (to + y));
            count -= chunk_size;

            if (chunk_size >= 256 - y)
            {
                chunk_size -= 256 - y;
                x = 1 + hi(chunk_size);
                chunk_size = lo(chunk_size);

                for (; x > 0; --x)
                {
                    y_loop:
                        lda (from),y:sta (to),y:iny;
                        bne y_loop

                    from += 0x100;
                    to += 0x100;
                }
                assert(y == 0);

                if (from + y >= wrap_top) from -= wrap_adjust;
                if (to + y >= wrap_top) to -= wrap_adjust;
            }
            if (chunk_size > 0)
            {
                assert(chunk_size < 256);
                // y cannot wrap around here; it would wrap iff chunk_size >=
                // (256 - y). If we didn't go into the previous if, that's
                // guaranteed by the previous if's condition. If we did go into
                // the previous iff, we ended with y == 0, and we know
                // chunk_size < 256, so it can't be >= 256-y=256.
                for (x = chunk_size; x > 0; --x)
                {
                    lda (from),y:sta (to),y:iny;
                    assert(y != 0);
                }
                // from + y can't have wrapped, since y hasn't wrapped to 0
                if (to + y >= wrap_top) to -= wrap_adjust;
            }
        }
    }
    else
    {
        // to and from point to the next byte we want to move.
        to += count - 1;
        from += count - 1;

        // We never need to adjust for wrap_bottom here; since we're copying
        // downwards, the only way we can get to an address below
        // wrap_bottom is in the decrements below, so we just
        // handle that there.
        if (from >= wrap_top) from -= wrap_adjust;
        if (to >= wrap_top) to -= wrap_adjust;

        from = from & 0xff00;
        y    = from & 0x00ff;

        // to is adjusted so that we can use the same y offset
        // for both from and to. from is used to choose y as
        // it allows us to avoid the page-crossing penalty on lda (zp),y;
        // sta (zp),y doesn't have one.
        to = to - y;
        // Note that it's to+y which is important for wrapping, so this
        // subtraction does not trigger a wrap - we know what is now to+y is a valid
        // address already.

        while (count > 0)
        {
            // 'actual_from' = from + y, ditto for to.
            // We add one in the next line because if (for example) actual_from ==
            // wrap_bottom, that means we need to move 1 byte in this chunk, not
            // 0.
            chunk_size = min(count, 1 + from + y - wrap_bottom, 1 + to + y - wrap_bottom);
            count -= chunk_size;

            // The inner loop here copies starting with from[y] and ending up
            // with from[0] (both inclusive), i.e. y+1 bytes. That's only OK if
            // the chunk is at least that large.
            if (chunk_size >= y + 1)
            {
                // We want to make one pass round this loop for the initial y+1
                // bytes in the "highest" page, then one loop for every 256
                // bytes of the rest of the chunk - this will leave us 0-255
                // bytes left to copy afterwards, not ending at y=0 (otherwise
                // we'd be doing it in here).
                chunk_size -= y + 1
                x = 1 + hi(chunk_size);
                chunk_size = lo(chunk_size);
                // Avoid the corner case where the innermost loop would copy two
                // bytes if y==0 when it should only copy 1. This can only
                // happen on the first pass round the x loop.
                if (y == 0) {
                    jmp y_is_0;
                }
                for (; x > 0; --x)
                {
                    y_loop:
                        lda (from),y;
                        sta (to),y;
                        dey;
                        bne y_loop;
                    y_is_0:
                        lda (from),y;
                        sta (to),y;
                        dey;
                    assert(y == 0xff);
                    from -= 0x100; 
                    to   -= 0x100;
                }
                if (from + y < wrap_bottom) from += wrap_adjust;
                if (to + y < wrap_bottom) to += wrap_adjust;
            }
            // Now finish off this chunk if necessary by copying which doesn't
            // have to end by reading from from[0].
            if (chunk_size > 0)
            {
                assert(chunk_size < 0x100);
                for (x = chunk_size; x > 0; --x, --y)
                {
                    to[y] = from[y];
                }
                assert(from + y >= wrap_bottom);
                if (to + y < wrap_bottom) to += wrap_adjust;
            }
        }

    }
}

// Get the stored character and its attributes at logical cursor position 'x'
// of the current line. 'x' must be within bounds.
void get_stored_character(unsigned x, char *character, char *attributes)
{
    const char *stored_screen_ptr = stored_screen_current_line_start();
    // Each stored screen line consists of 40 repetitions of three bytes:
    // character n
    // character n+1
    // character n attributes in high bits | character n+1 attributes in low bits
    stored_screen_ptr += (x / 2) * 3;
    if ((x % 2) == 0)
    {
        *character = stored_screen_ptr[0];
        *attributes = (stored_screen_ptr[2] >> 4);
    }
    else
    {
        *character = stored_screen_ptr[1];
        *attributes = (stored_screen_ptr[2] & 0xf);
    }
}

// Set the stored character and its attributes at logical cursor position 'x'
// of the current line. 'x' must be within bounds.
void set_stored_character(unsigned x, char character, char attributes)
{
    char *stored_screen_ptr = stored_screen_current_line_start();
    stored_screen_ptr += (x / 2) * 3;
    char clear_mask;
    char set_mask;
    if ((x % 2) == 0)
    {
        stored_screen_ptr[0] = character;
        clear_mask = 0x0f;
        set_mask = (attributes << 4);
    }
    else
    {
        stored_screen_ptr[1] = character;
        clear_mask = 0xf0;
        set_mask = attributes;
    }
    stored_screen_ptr[2] &= clear_mask;
    stored_screen_ptr[2] |= set_mask;
}
