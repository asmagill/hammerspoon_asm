mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE := $(current_dir)
PREFIX ?= ~/.hammerspoon
HS_APPLICATION ?= /Applications

LUAFILE  = ${wildcard *.lua}

# special vars for uninstall
space :=
space +=
comma := ,
ALLFILES := $(LUAFILE)
ALLFILES += timeout3

all: verify $(SOFILE)

install: verify install-lua
	install -m 0755 timeout3 $(PREFIX)/hs/_asm/$(MODULE)

verify: $(LUAFILE)
	hash lua-5.3 >& /dev/null && luac-5.3 -p $(LUAFILE) && echo "Passed"

install-lua: $(LUAFILE)
	mkdir -p $(PREFIX)/hs/_asm/$(MODULE)
	install -m 0644 $(LUAFILE) $(PREFIX)/hs/_asm/$(MODULE)

markdown:
	hs -c "_xtras.docmaker.genMarkdown([[$(dir $(mkfile_path))]])" > README.tmp.md

clean:

uninstall:
	rm -v -f $(PREFIX)/hs/_asm/$(MODULE)/{$(subst $(space),$(comma),$(ALLFILES))}
	rmdir -p $(PREFIX)/hs/_asm/$(MODULE) ; exit 0

.PHONY: all clean uninstall verify install install-lua
