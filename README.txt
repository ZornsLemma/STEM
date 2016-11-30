STEM - Stream Terminal Emulator for the BBC Micro B, B+ and Master computers
============================================================================

STEM is a ROM-based emulator for the DEC VT102 and VT52 terminals. Unlike many
other terminal emulators, it is not intended for use with a serial connection
to a remote system; instead, it intercepts the operating system vectors to
provide terminal emulation for programs running locally.

This works for programs running under the native Acorn operating system
(referred to as 'MOS' from here on) - the demonstration and test suite is an
example of this - but this is not generally useful, as programs written to run
under MOS naturally use the MOS VDU sequences to control the display. STEM is
mainly useful with second processors running non-Acorn-specific
applications.

For example, a CP/M application may offer the ability to run using a variety of
different terminal types as standard, but it is unlikely to support the MOS VDU
sequences. By using STEM to provide a VT102 or VT52 emulation, the application
can be run using the Acorn Z80 second processor without needing to be patched.

STEM may also be useful for applications ported from other systems running on
second processors such as the 32016 and ARM.

A simple demonstration can be seen at https://youtu.be/t572FRaA0UI.

STEM is open source software; see LICENCE.txt for more information. The source
code can be downloaded from https://github.com/ZornsLemma/STEM. For binary
downloads, as well as any discussion related to STEM, have a look at this
thread on the stardot.org.uk forums:
http://www.stardot.org.uk/forums/viewtopic.php?f=2&t=10534&p=127899&hilit=ansi+vt102#p127899

Getting started
---------------

STEM is provided as a ROM image (filename "STEM") on a DFS disc image (a file
with a '.ssd' extension). You can insert this disc image into a virtual drive
under any BBC emulator, or you can transfer it on to suitable media for use
with a real machine. The disc image contains a number of test and demonstration
programs, but none of these are necessary for using STEM.

STEM will run from sideways ROM or sideways RAM. The simplest option is to run
it from sideways RAM, if you have it. How to load a ROM image into sideways RAM
varies with different third-party sideways RAM add ons; on many machines a
command such as the following will work:

*SRLOAD STEM 8000 Z

Press CTRL-BREAK after doing this and then try executing:

*HELP

You should see an entry like this among the other output:

STEM 0.02
  STEM

Executing:

*HELP STEM

will produce a list of the * commands supported and their arguments. Most of
the time you won't need to give any arguments; you can enable the emulation
simply by issuing a *VT102 or *VT52 command. If the ROM needs to claim
workspace by raising PAGE, it will tell you to execute the *STEM command - do
this, and then retry the *VT102 or *VT52 command.

STEM only works in 80 column modes (modes 0 and 3). It supports shadow RAM on
the BBC B and Master, but not (yet) on the BBC B+. On the BBC B shadow RAM
slows down the emulation noticeably. I recommend that you avoid the use of
shadow RAM unless you have a good reason for needing it; if you are using STEM
with a second processor the memory taken up in the host by the non-shadow
screen is probably not going to be a problem.

To see STEM working under MOS, you can try something like this from the BASIC
prompt:

MODE 0
*VT102
PRINT CHR$(27);"[1;4mThis is bold underlined text.";CHR$(27);"[m"

To use STEM with a second processor, you need to execute the *VT102 or *VT52
command with the second processor active - pressing BREAK will disable STEM.
With the Acorn Z80 second processor, the easiest way to do this is to press
BREAK - this will give you a '*' command prompt, at which you can enter:

*VT102
*CPM

to enter CP/M with STEM enabled. Alternatively you can use the STAR.COM utility
to execute *VT102 from within CP/M.

Demonstration/test suite
------------------------

The disc image containing the ROM is bootable and contains a number of
demonstrations and test programs. The test programs are only likely to be of
interest if you plan to make changes to STEM yourself.

Additional documentation
------------------------

More information about STEM can be found in the 'doc' directory:

credits.txt lists the various people and programs who provided help during
development.

function-key-strip.* is a function key strip you can print and cut out; it
shows how the red function keys are used to emulate keys missing on the BBC
keyboard compared to the real VT102 keyboard.

building.txt contains some notes on how to build STEM from source.

coding-conventions.txt contains some notes on the coding style used.

todo.txt contains some ideas for future enhancements.

Contact details
---------------

STEM was written by Steven Flintham; you can e-mail me at stem@lemma.co.uk,
although general questions and comments should probably go to the stardot
thread mentioned above.

vi: tw=79
