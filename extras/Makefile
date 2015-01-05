mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

CONTAINER = _asm
TARGET ?= Hammerspoon
MODULE := $(current_dir)

ifeq ($(TARGET), Hammerspoon)
USERPATH = ~\/.hammerspoon
L_PATH = hs.$(CONTAINER)
endif

ifeq ($(TARGET), Mjolnir)
USERPATH = ~\/.mjolnir
L_PATH = mjolnir.$(CONTAINER)
endif

PREFIX ?= $(USERPATH)\/$(subst .,\/,$(L_PATH))

OBJCFILE = internal.m
LUAFILE  = init.lua
SOFILE  := internal-$(current_dir).so

target: clean $(LUAFILE) $(OBJCFILE) Makefile.$(TARGET)
	mkdir -p $(TARGET)/$(current_dir)
	cp Makefile.$(TARGET) $(TARGET)/$(current_dir)/Makefile
	cp -a LICENSE $(LUAFILE) $(OBJCFILE) $(TARGET)/$(current_dir)

output:
	@echo "TARGET   = $(TARGET)"
	@echo "MODULE   = $(MODULE)"
	@echo "L_PATH   = $(L_PATH)"
	@echo "USERPATH = $(USERPATH)"
	@echo "PREFIX   = $(PREFIX)"
	@echo "OBJCFILE = $(OBJCFILE)"
	@echo "LUAFILE  = $(LUAFILE)"
	@echo "SOFILE   = $(SOFILE)"

$(OBJCFILE): template.m
	sed -e 's/{TARGET}/$(TARGET)/g' \
		-e 's/{MODULE}/$(MODULE)/g' \
		-e 's/{PATH}/$(L_PATH)/g' \
		template.m > $@

$(LUAFILE): template.lua
		sed -e 's/{MODULE}/$(MODULE)/g' \
		-e 's/{PATH}/$(L_PATH)/g' \
		template.lua > $@

Makefile.$(TARGET): Makefile.template
	sed -e 's/{MODULE}/$(MODULE)/g' \
		-e 's/{SOFILE}/$(SOFILE)/g' \
		-e 's/{PREFIX}/$(PREFIX)/g' \
		Makefile.template > $@

install: target
	$(MAKE) -C $(TARGET)/$(current_dir) install

uninstall: target
	$(MAKE) -C $(TARGET)/$(current_dir) uninstall

clean:
	rm -v -fr $(LUAFILE) $(OBJCFILE) Makefile.Hammerspoon Hammerspoon Makefile.Mjolnir Mjolnir

.PHONY: target clean install uninstall output
