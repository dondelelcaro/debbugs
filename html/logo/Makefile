#!/usr/bin/make -f

all: debbugs_logo.svg debbugs_logo_icon.png

## if you want to modify debbugs_logo.svg do the modifications to
## debbugs_logo_orig.svg, and then run make update_debbugs_logo and check the
## changes in.
update_debbugs_logo: debbugs_logo_orig.svg
	inkscape --without-gui \
	--export-text-to-path --export-plain-svg debbugs_logo.svg $<;

debbugs_logo_icon.png: debbugs_logo.svg
	inkscape --without-gui \
	--export-width 32 --export-height 32 \
	--export-background=white \
	--export-png $@ $<
