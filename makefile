# This attempts to build the game for you. 
# Note: This is a pretty poor excuse for a makefile. I'd look elsewhere for better examples. 
# Prequisites:
# - A few fairly standard unix applications available; Gow/Cygwin installed for Windows.
# - ca65 binaries in the tools folder

### USER EDITABLE STUFF STARTS HERE

ROM_NAME=world
OBJECTS_TO_BUILD=$(ROM_NAME).c levels/processed/lvl1_tiles.asm levels/processed/lvl2_tiles.asm levels/processed/lvl3_tiles.asm levels/processed/lvl4_tiles.asm levels/processed/lvl5_tiles.asm levels/processed/lvl6_tiles.asm bin/build_info.h bin/crt0.o bin/$(ROM_NAME).o bin/title.o bin/level_manip.o bin/movement.o bin/sprites.o

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
MAIN_COMPILER=./tools/cc65/bin/cc65
MAIN_ASM_COMPILER=./tools/cc65/bin/ca65
MAIN_LINKER=./tools/cc65/bin/ld65
MAIN_EMULATOR=tools/fceux/fceux
DEBUG_EMULATOR=tools/nintendulatordx/nintendulator
SPACE_CHECKER=tools/nessc/nessc
LEVEL_CONVERTER=node tools/level-converter
CONFIG_FILE=$(ROOT_DIR)/cfg/game.cfg
ifeq ($(OS),Windows_NT)
	TEXT2DATA=tools/famitone2/tools/text2data
	NSF2DATA=tools/famitone2/tools/nsf2data
	BUILD_DATE=$(shell echo %DATE% %TIME:~0,5%)
else
	TEXT2DATA=echo Music compilation can only be done under Windows. There is not a good linux/osx port. Exiting without doing anything. 
	NSF2DATA=echo Sound effect compilation can only be done under Windows. There is not a good linux/osx port. Exiting without doing anything.
	BUILD_DATE=$(shell date +"%a %m/%d/%Y  %H:%M")
endif

### USER EDITABLE STUFF ENDS HERE

.PHONY: clean fceux run nintendulator debug space_check .FORCE

.FORCE: 
# Empty target used to regenerate constants every single time.

all: $(ROM_NAME).nes

bin/%.s: %.c
	$(MAIN_COMPILER) -Oi $< --add-source --include-dir ./tools/cc65/include -o $@

bin/%.s: src/%.c
	$(MAIN_COMPILER) -Oi $< --add-source --include-dir ./tools/cc65/include -o $@

bin/crt0.o: lib/crt0.asm sound/sfx.s sound/music.s lib/boilerplate.asm
	$(MAIN_ASM_COMPILER) lib/crt0.asm -o bin/crt0.o

sound/sfx.s: sound/sfx.nsf
	$(NSF2DATA) sound/sfx.nsf -ntsc -ca65

sound/music.s: sound/music.txt
	$(TEXT2DATA) sound/music.txt -ca65 -ntsc

bin/%.o: bin/%.s
	$(MAIN_ASM_COMPILER) $<

levels/processed/%_tiles.asm: levels/%.json
	$(LEVEL_CONVERTER) $<

bin/build_info.h: .FORCE
# Outputs a bunch of build stats info build_info.h. Use it in your project to show details about the build in-game!
	@printf "// WARNING: This file is autogenerated by your makefile. Never edit it by hand.\n\n" > bin/build_info.h
	@printf "#define BUILD_DATE \"$(BUILD_DATE)\"\n" >> bin/build_info.h
	@printf "#define COMMIT_COUNT $(shell git rev-list --count HEAD)\n" >> bin/build_info.h
	@printf "#define COMMIT_COUNT_STR \"$(shell git rev-list --count HEAD)\"\n" >> bin/build_info.h
	@printf "#define GIT_COMMIT_ID \"$(shell git rev-parse HEAD)\"\n" >> bin/build_info.h
	@printf "#define GIT_COMMIT_ID_SHORT \"$(shell git rev-parse --short HEAD)\"\n" >> bin/build_info.h

# We also can get some info from environment variables in CircleCI... otherwise we kinda have to improvise a little.
ifeq ($(CIRCLECI), true)
	@printf "#define REPOSITORY_NAME \"$(value CIRCLE_PROJECT_REPONAME)\"\n" >> bin/build_info.h
	@printf "#define GIT_BRANCH \"$(value CIRCLE_BRANCH)\"\n" >> bin/build_info.h
	@printf "#define GIT_TAG \"$(value CIRCLE_TAG)\"\n" >> bin/build_info.h
	@printf "#define BUILD_NUMBER $(value CIRCLE_BUILD_NUM)\n" >> bin/build_info.h
	@printf "#define BUILD_NUMBER_STR \"$(value CIRCLE_BUILD_NUM)\"\n" >> bin/build_info.h
else
	@printf "#define REPOSITORY_NAME \"$(ROM_NAME)\"\n" >> bin/build_info.h
	@printf "#define GIT_BRANCH \"$(shell git symbolic-ref --short HEAD)\"\n" >> bin/build_info.h
	@printf "#define GIT_TAG \"\"\n" >> bin/build_info.h
	@printf "#define BUILD_NUMBER 0\n" >> bin/build_info.h
	@printf "#define BUILD_NUMBER_STR \"0\"\n" >> bin/build_info.h
endif

$(ROM_NAME).nes: $(OBJECTS_TO_BUILD)
	$(MAIN_LINKER) -C $(CONFIG_FILE) -o $(ROM_NAME).nes bin/*.o lib/runtime.lib

fceux:
	$(MAIN_EMULATOR) $(ROM_NAME).nes
	
run: fceux

nintendulator:
	$(DEBUG_EMULATOR) $(ROM_NAME).nes

debug: nintendulator

space_check:
ifeq ($(OS),Windows_NT)
	$(SPACE_CHECKER) $(ROM_NAME).nes
else
	@echo "Space check is only available on Windows right now, sorry!"
endif

clean:
	-rm -f *.nes
	-rm -f *.o
	-rm -f bin/*.o
	-rm -f bin/*.s
	-rm -f levels/processed/*.asm
	-rm -f levels/processed/*.h

