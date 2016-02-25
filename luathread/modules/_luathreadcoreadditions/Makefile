mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE := $(current_dir)
PREFIX ?= ~/.hammerspoon
HS_APPLICATION ?= /Applications

OBJCFILE = ${wildcard *.m}
LUAFILE  = ${wildcard *.lua}
HEADERS  = ${wildcard *.h}

SOFILE  := $(OBJCFILE:.m=.so)
DEBUG_CFLAGS ?= -g

# special vars for uninstall
space :=
space +=
comma := ,
ALLFILES := $(LUAFILE)
ALLFILES += $(SOFILE)

.SUFFIXES: .m .so

#CC=cc
CC=clang
EXTRA_CFLAGS ?= -Wconversion -Wdeprecated -F$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks
CFLAGS  += $(DEBUG_CFLAGS) -fmodules -fobjc-arc -DHS_EXTERNAL_MODULE -Wall -Wextra $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: verify $(SOFILE)

.m.so: $(HEADERS)
	$(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

install: verify install-objc install-lua

verify: $(LUAFILE)
	luac-5.3 -p $(LUAFILE) && echo "Passed"

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)
	cp -vpR $(OBJCFILE:.m=.so.dSYM) $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)

markdown:
	hs -c "_xtras.docmaker.genMarkdown([[$(dir $(mkfile_path))]])" > README.tmp.md

clean:
	rm -v -rf $(SOFILE) *.dSYM

uninstall:
	rm -v -f $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
	(pushd $(PREFIX)/hs/_asm/luathread/hs/$(MODULE)/ ; rm -v -fr $(OBJCFILE:.m=.so.dSYM) ; popd)
	rmdir -p $(PREFIX)/hs/_asm/luathread/hs/$(MODULE) ; exit 0

.PHONY: all clean uninstall verify install install-objc install-lua
