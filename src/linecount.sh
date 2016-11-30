#!/bin/sh
#cat *.beebasm | grep -v '^[ \t]*\\'|grep -v '^[ \t]*$'|grep -v '^[{}]$'|less|wc -l
for x in *.beebasm; do
	echo $(cat $x | grep -v '^[ \t]*\\' | grep -v '^[ \t{}]*$' | wc -l) $x
done | sort -n | gawk '
	BEGIN { t=0 } 
	{ printf("%5s %s\n", $1, $2); t += $1} 
	END { printf("%5s total\n", t) }'
