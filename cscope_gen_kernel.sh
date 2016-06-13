#!/bin/sh
rm cscope.*

find ./ \
	-path "./arch/alpha" -prune \
	-o -path "./arch/avr32" -prune \
	-o -path "./arch/blackfin" -prune \
	-o -path "./arch/cris" -prune \
	-o -path "./arch/frv" -prune \
	-o -path "./arch/h8300" -prune \
	-o -path "./arch/ia64" -prune \
	-o -path "./arch/m32r" -prune \
	-o -path "./arch/m68k" -prune \
	-o -path "./arch/m68knommu" -prune \
	-o -path "./arch/microblaze" -prune \
	-o -path "./arch/mips" -prune \
	-o -path "./arch/mn10300" -prune \
	-o -path "./arch/parisc" -prune \
	-o -path "./arch/powerpc" -prune \
	-o -path "./arch/s390" -prune \
	-o -path "./arch/score" -prune \
	-o -path "./arch/sh" -prune \
	-o -path "./arch/sparc" -prune \
	-o -path "./arch/um" -prune \
	-o -path "./arch/x86" -prune \
	-o -path "./arch/xtensa" -prune \
	-o -path "./Documentation" -prune \
	-o -iname "*.[chxsS]" -print \
	> ./cscope.files

find ./arch/arm/boot/dts -iname "*mx*.dts" >> ./cscope.files
find ./arch/arm/boot/dts -iname "*mx*.dtsi" >> ./cscope.files

cscope -b -q

