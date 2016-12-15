mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE := $(current_dir)
PREFIX ?= ~/.hammerspoon
VERSION ?= 0.x
HS_APPLICATION ?= /Applications

OBJCFILE = ${wildcard *.m}
# LUAFILE  = ${wildcard *.lua}
LUAFILE  = init.lua matrix.lua
HEADERS  = ${wildcard *.h}

# SOFILE  := $(OBJCFILE:.m=.so)
SOFILE  := internal.so matrix_internal.so
DEBUG_CFLAGS ?= -g

# special vars for uninstall
space :=
space +=
comma := ,
ALLFILES := $(LUAFILE)
ALLFILES += $(SOFILE)

.SUFFIXES: .m .so

#CC=cc
CC=@clang
WARNINGS ?= -Weverything -Wno-objc-missing-property-synthesis -Wno-implicit-atomic-properties -Wno-direct-ivar-access -Wno-cstring-format-directive -Wno-padded -Wno-covered-switch-default -Wno-missing-prototypes -Werror-implicit-function-declaration
EXTRA_CFLAGS ?= -F$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks -mmacosx-version-min=10.10

CFLAGS  += $(DEBUG_CFLAGS) -fmodules -fobjc-arc -DHS_EXTERNAL_MODULE $(WARNINGS) $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

all: verify internal.so matrix_internal.so

release: clean all
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=tmp make install ; cd tmp ; tar -cf ../$(MODULE)-v$(VERSION).tar hs ; cd .. ; gzip $(MODULE)-v$(VERSION).tar

internal.so: internal.m imageAdditions.m $(HEADERS)
	$(CC) internal.m imageAdditions.m $(CFLAGS) $(LDFLAGS) -o $@

matrix_internal.so: matrix_internal.m
	$(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

# .m.so: $(HEADERS) $(OBJCFILE)
# 	$(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

# internal.so: $(HEADERS) $(OBJCFILE)
# 	$(CC) $(OBJCFILE) $(CFLAGS) $(LDFLAGS) -o $@

install: verify install-objc install-lua

verify: $(LUAFILE) drawing.lua
	@if $$(hash lua-5.3 >& /dev/null); then (luac-5.3 -p $(LUAFILE) && echo "Lua Compile Verification Passed"); else echo "Skipping Lua Compile Verification"; fi

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/hs/_asm/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/hs/_asm/$(MODULE)
	cp -vpR $(SOFILE:.so=.so.dSYM) $(PREFIX)/hs/_asm/$(MODULE)
# 	cp -vpR $(SOFILE:.so=.so.dSYM) $(PREFIX)/hs/_asm/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/hs/_asm/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/hs/_asm/$(MODULE)
	mkdir -p $(PREFIX)/hs/drawing
	cp drawing.lua $(PREFIX)/hs/drawing/init.lua
	chmod 0644 $(PREFIX)/hs/drawing/init.lua

markdown:
	hs -c "dofile(\"utils/docmaker.lua\").genMarkdown([[$(dir $(mkfile_path))]])" > README.tmp.md

markdownWithTOC:
	hs -c "dofile(\"utils/docmaker.lua\").genMarkdown([[$(dir $(mkfile_path))]], true)" > README.tmp.md

clean:
	rm -rf $(SOFILE) *.dSYM tmp

uninstall:
	rm -v -f $(PREFIX)/hs/_asm/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
	(pushd $(PREFIX)/hs/_asm/$(MODULE)/ ; rm -v -fr $(OBJCFILE:.m=.so.dSYM) ; popd)
# 	(pushd $(PREFIX)/hs/_asm/$(MODULE)/ ; rm -v -fr $(SOFILE:.so=.so.dSYM) ; popd)
	rmdir -p $(PREFIX)/hs/_asm/$(MODULE) ; exit 0
	rm -v -f $(PREFIX)/hs/drawing/init.lua
	rmdir -p $(PREFIX)/hs/drawing ; exit 0

.PHONY: all clean uninstall verify install install-objc install-lua
