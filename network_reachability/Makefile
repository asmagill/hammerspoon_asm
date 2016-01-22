# mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
# current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
current_dir = network
MODULE := $(current_dir)
PREFIX ?= ~/.hammerspoon
HS_APPLICATION ?= /Applications

OBJCFILE = ${wildcard *.m}
LUAFILE  = ${wildcard *.lua}
HEADERS  = ${wildcard *.h}

SOFILE  := $(OBJCFILE:.m=.so)
DEBUG_CFLAGS ?= -g
DOC_FILE = hs.$(MODULE).json

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
CFLAGS  += $(DEBUG_CFLAGS) -fobjc-arc -DHS_EXTERNAL_MODULE -Wall -Wextra $(EXTRA_CFLAGS)
LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS)

DOC_SOURCES = $(LUAFILE) $(OBJCFILE)

all: verify $(SOFILE)

.m.so: $(HEADERS)
	$(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

install: verify install-objc install-lua

verify: $(LUAFILE)
	luac-5.3 -p $(LUAFILE) && echo "Passed"

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/hs/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/hs/$(MODULE)
	cp -vpR $(OBJCFILE:.m=.so.dSYM) $(PREFIX)/hs/$(MODULE)

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/hs/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/hs/$(MODULE)

docs: $(DOC_FILE)

$(DOC_FILE): $(DOC_SOURCES)
	find . -type f \( -name '*.lua' -o -name '*.m' \) -not -name 'template.*' -not -path './_*' -exec cat {} + | __doc_tools/gencomments | __doc_tools/genjson > $@

install-docs: docs
	mkdir -p $(PREFIX)/hs/$(MODULE)
	install -m 0644 $(DOC_FILE) $(PREFIX)/hs/$(MODULE)

clean:
	rm -v -rf $(SOFILE) *.dSYM $(DOC_FILE)

uninstall:
	rm -v -f $(PREFIX)/hs/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
	(pushd $(PREFIX)/hs/$(MODULE)/ ; rm -v -fr $(OBJCFILE:.m=.so.dSYM) ; popd)
	rm -v -f $(PREFIX)/hs/$(MODULE)/$(DOC_FILE)
	rmdir -p $(PREFIX)/hs/$(MODULE) ; exit 0

.PHONY: all clean uninstall verify docs install install-objc install-lua install-docs
