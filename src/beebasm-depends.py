#!/usr/bin/env python

import argparse
import os
import sys


def die(error):
    sys.stderr.write(os.path.basename(sys.argv[0]) + ': ' + error + '\n')
    sys.exit(1)


def tokenise(line):
    i = 0
    tokens = []
    statement = []
    while i < len(line):
        while i < len(line) and line[i].isspace():
            i += 1
        if i >= len(line):
            break
        if line[i] == '"':
            j = line.find('"', i+1)
            if j == -1:
                j = len(line) 
            else:
                j += 1
            statement.append(line[i:j])
            i = j
        else:
            special = '#:,.^*'
            if line[i] in special:
                j = i + 1
            else:
                j = i
                while j < len(line) and not line[j].isspace() and not line[j] in special:
                    j += 1
            token = line[i:j]
            if token in ('\\', ';'):
                break
            if token == ':':
                tokens.append(statement)
                statement = []
            else:
                statement.append(token)
            i = j
    if statement:
        tokens.append(statement)
    return tokens


def process_file(filename):
    if filename in filenames_seen:
        return
    filenames_seen.add(filename)

    try:
        with open(filename) as f:
            for (line_number, line) in enumerate(f):
                line_number += 1 # switch from 0 to 1 based
                if line[-1] == '\n':
                    line = line[0:-1]
                tokens = tokenise(line)
                for statement in tokens:
                    if statement[0].lower() == 'include':
                        if (len(statement) == 2 and len(statement[1]) > 2 and
                            statement[1][0] == '"' and statement[1][-1] == '"'):
                            filename = statement[1][1:-1]
                            process_file(filename)
                    elif (statement[0].lower() == 'putbasic' or
                          statement[0].lower() == 'putfile' or
                          statement[0].lower() == 'puttext'):
                        if (len(statement) >= 2 and len(statement[1]) > 2 and
                            statement[1][0] == '"' and statement[1][-1] == '"'):
                            filename = statement[1][1:-1]
                            filenames_seen.add(filename)
    except IOError as e:
        die('Cannot open source file "' + filename + '": ' + os.strerror(e.errno))


parser = argparse.ArgumentParser(description='Generate make dependencies file from BeebAsm source file')
parser.add_argument('-f', metavar='depends_file', default='-', help='Write tags to specified file instead of standard output')
parser.add_argument('-o', metavar='target_file', action='append', help='Target file generated from input_file')
parser.add_argument('input_file', metavar='source_file', help='BeebAsm source file to scan')
args = parser.parse_args()

target_files = args.o
if not target_files:
    root, ext = os.path.splitext(args.input_file)
    if not ext:
        die("Input file has no extension so can't derive target filename; try -o")
    target_files = [root + '.ssd']

filenames_seen = set()
process_file(args.input_file)

# This distinctive comment enables the check for a non-depends file below and
# is mildly useful in its own right.
warning_comment = '# AUTO-GENERATED DEPENDENCIES, DO NOT EDIT BY HAND'

if args.f == '-':
    depends_file = sys.stdout
else:
    # Following the lead of exuberant ctags, we refuse to proceed if the
    # output file exists and is not a valid depends file. 
    try:
        with open(args.f, 'r') as f:
            line = f.readline()
            if line != warning_comment + '\n':
                die('Refusing to overwrite non-depends file "' + args.f + '"')
    except IOError:
        pass
    depends_file = open(args.f, 'w')

depends_file.write(warning_comment + '\n\n')
depends_file.write(' '.join(list(target_files)) + ': ' + 
                   ' '.join(list(filenames_seen)) + '\n\n')
for filename in filenames_seen:
    if filename == args.input_file:
        continue
    depends_file.write(filename + ':\n\n')

depends_file.close()
