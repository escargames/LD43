
all:
	@echo '"make full" or "make mini"'

full:
	"/c/Program Files (x86)/PICO-8/pico8.exe" rainbowcats.p8 &

mini:
	cat rainbowcats.p8 | sed '/^$$/,/\[\[/s/^  *//; 6,$$s/ *--.*//' | grep . > rainbowcats-mini.p8
	"/c/Program Files (x86)/PICO-8/pico8.exe" rainbowcats-mini.p8 &

