# This file is part of STEM. It is subject to the licence terms in the
# LICENCE.txt file found in the top-level directory of this distribution and
# at https://github.com/ZornsLemma/STEM. No part of STEM, including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENCE.txt file.

from __future__ import print_function

# We have a 128-byte table fast_path_character_table to support the fast path
# code, but it is only actually used to contain a boolean flag in b7 for each
# character < 128. We can avoid wasting space by overlapping various other
# tables with it; as long as the overlapped values share the same b7 this 'just
# works'. Rather than manually interleave the tables, we use this Python script
# to do it, which is hopefully more readable and less error prone.

b7 = 128

# We have one table which is able to partially overlap with the start of
# fast_path_character_table, so we have this many bytes before the start of
# fast_path_character_table.
fast_path_character_offset = 8

# The main table in which all the others are embedded; only b7 is significant
# here. This indicates whether a character can be processed via the fast path
# inside OSWRCH (b7 clear) or not (b7 set). In general this is characters which
# encode_character would encode as their own code, but we also include CR (13).
table = (128+fast_path_character_offset)*[0]
merged_value = len(table)*[False]
for c in list(range(0, 32)) + [35, 96, 127]:
    if c != 13:
        table[fast_path_character_offset + c] = b7
labels = {fast_path_character_offset: ['.fast_path_character_table'],
          fast_path_character_offset + 128: ['\\ .fast_path_character_table_end']}
suffix = []

def merge(name, offset, data):
    assert offset + len(data) - 1 <= len(table)
    for data_i in range(0, len(data)):
        table_i = offset + data_i;
        assert not merged_value[table_i] or table[table_i] == data[data_i]
        assert (table_i < fast_path_character_offset or 
                (table[table_i] & b7) == (data[data_i] & b7))
        table[table_i] = data[data_i]
        merged_value[table_i] = True
    if offset not in labels:
        labels[offset] = []
    if offset + len(data) not in labels:
        labels[offset + len(data)] = []
    labels[offset].append('.' + name)
    labels[offset + len(data)].append('\\ .' + name + '_end')


# Table used by get_tab_stop_mask_and_offset_current_cursor_x; used to convert
# a bit-reversed 3-bit value p into 1<<p.
tab_mask_table = [
    # 1<<p          bit-reversed(cursor X % 8)    p=cursor X % 8
      0b00000001, # 0b000                         0b000 0
      0b00010000, # 0b001                         0b100 4
      0b00000100, # 0b010                         0b010 2
      0b01000000, # 0b011                         0b110 6
      0b00000010, # 0b100                         0b001 1
      0b00100000, # 0b101                         0b101 5
      0b00001000, # 0b110                         0b011 3
      0b10000000  # 0b111                         0b111 7
]
merge('tab_mask_table', fast_path_character_offset+127-7, tab_mask_table)


# Table used to allow (e.g.) ORA identity_table,X to act like ORA X for 4-bit
# values of X. TODO: Possibly get rid of this, it's only used in a couple of
# places now - it would depend if we could use this space better for something
# else.
merge('identity_table', fast_path_character_offset+127-7-16, range(0, 16))


# Table used to shift a 4-bit value left by 4 bits. The last eight bytes of
# this have the top bit set, which means it can't be fully contained anywhere
# within fast_path_character_table, but we can overlap it with the start of
# fast_path_character_table.
merge('left_shift_4_table', 0, [i << 4 for i in range(0, 16)])


# state_mask_table is used to compress key_translation_table; the latter
# contains an offset of a pair of bytes in the former. We actually force the 
# top bit set on all these; this isn't strictly desirable, but it only requires
# an extra ora #top_bit in our_buffer_insert and allows us to pack this into 
# the initial part of fast_path_character_table.

# These are copies of constants in buffer.beebasm; the two must be kept in
# sync.
state_uk = 1<<0
state_keypad_emulation = 1<<1
state_application_keypad_mode = 1<<2
state_shift = 1<<3
state_ctrl = 1<<6

state_mask_table = [
    state_ctrl,
    state_ctrl,
    0,
    0,
    state_uk,
    state_uk,
    state_keypad_emulation,
    state_keypad_emulation ,
    state_ctrl|state_application_keypad_mode,
    0,
    state_ctrl|state_application_keypad_mode,
    state_application_keypad_mode
]
state_mask_table = [b7|x for x in state_mask_table]
merge('state_mask_table', fast_path_character_offset + 14, state_mask_table)


# High bytes of 120*Y multiplication table for Y in [0, 32]
mult_120_table_high = [(y * 120) >> 8 for y in range(0, 33)]
merge('mult_120_table_high', fast_path_character_offset + 96 - len(mult_120_table_high), mult_120_table_high)


# mult_640_table_high is suitable for merging but there's just no room for it.
# mult_640_table_high = [(y * 640) >> 8 for y in range(0, 33)]
# merge('multi_640_table_high', fast_path_character_offset + 96 - len(mult_120_table_high) - len(mult_640_table_high), mult_640_table_high)


# Registers and values for mode 3 gap control.
mode_3_gap_control_register_list = [4, 9, 11, 7] # it's important 7 comes last as mode_3_gap_control relies on that
mode_3_gap_control_value_list = [
        38, 7, 8, 31, # gapless
        30, 9, 9, 27  # gappy
]
merge('mode_3_gap_control_register_list', fast_path_character_offset + 97, mode_3_gap_control_register_list)
suffix += ['mode_3_gap_control_register_list_last_index = %s' % (len(mode_3_gap_control_register_list) - 1)]
merge('mode_3_gap_control_value_list', fast_path_character_offset + 36, mode_3_gap_control_value_list)
suffix += ['mode_3_gap_control_gapless = 3', 'mode_3_gap_control_gappy = 7']


# Vector numbers to claim; this pairs up with the elements of our_vector_table.
wrchv_number = 7
insv_number = 21
remv_number = 22
cnpv_number = 23
vector_number_table = [
    insv_number,
    remv_number,
    cnpv_number,
    wrchv_number
]
merge('vector_number_table', fast_path_character_offset + 44, vector_number_table)
suffix += ['assert our_vector_count == %d' % (len(vector_number_table))]


# Table used to convert user_option_*_lines flags into a number of lines. This
# must be kept in sync with the user_option_*_lines constants.
user_option_lines_table = [
    32, # user_option_32_lines
    25, # user_option_25_lines
    24, # not used but "just in case"
    24  # user_option_24_lines
]
merge('user_option_lines_table', fast_path_character_offset + 48, user_option_lines_table)


# Separate state table used when pending_escape is full; this causes us to
# enter the relevant error state. pending_escape can't become full when we
# are in state 0 as we know pending_escape is large enough to hold a single
# '['; we therefore use the previous arbitrary byte as the state 0 entry.
pending_escape_full_state_table_plus_1 = [
       # Current state
    3, # 1
    3, # 2
    3, # 3
    5, # 4
    5  # 5
]
merge('pending_escape_full_state_table_plus_1', fast_path_character_offset + 52, pending_escape_full_state_table_plus_1)
suffix += ['pending_escape_full_state_table = pending_escape_full_state_table_plus_1 - 1']


print('\\ AUTO-GENERATED FILE, DO NOT EDIT BY HAND; edit make-table.py instead.\n')

# Ensure the fast_path_character_offset table doesn't cross a page boundary; 
# this is potentially wasteful but we know that the generated beebasm source 
# will be included immediately before the workspace, which aligns to a page 
# boundary anyway.
print('if hi(P%%+%d) != hi(P%%+%d+%d-1)' % (fast_path_character_offset, fast_path_character_offset, len(table)-fast_path_character_offset))
print('    skipto (P%% and &ff00)+&100-%d' % fast_path_character_offset)
print('endif\n')

for i in range(len(table) + 1):
    if i in labels:
        for label in labels[i]:
            print(label)
    if i >= len(table):
        break
    c_name = ''
    c = i - fast_path_character_offset
    if c >= 0:
        c_name += ', character %3d' % c
    if c >= 32 and c < 127:
        c_name += ' (' + chr(c) + ')'
    print('    equb &%02x \ %%%s%s' % (
        table[i], bin(0x100+table[i])[3:], c_name))

print()
for s in suffix:
    print(s)

print()
print("xassert_table_on_one_page fast_path_character_table")
