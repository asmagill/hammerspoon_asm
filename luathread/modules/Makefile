PREFIX ?= ~/.config/hammerspoon
HS_APPLICATION ?= /Applications

all:

install: clean
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C .. $@
	-for f in [a-z_]* ; do [ -d $$f ] && echo "-- $$f --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C $$f $@ ; done

uninstall:
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C .. $@
	-for f in [a-z_]* ; do [ -d $$f ] && echo "-- $$f --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C $$f $@ ; done

clean:
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C .. $@
	-for f in [a-z_]* ; do [ -d $$f ] && echo "-- $$f --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) $(MAKE) -C $$f $@ ; done

release:
	rm -fr ../luathread
	HS_APPLICATION=$(HS_APPLICATION) PREFIX=luathread $(MAKE) -C .. clean install
	-for f in [a-z_]* ; do [ -d $$f ] && echo "-- $$f --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=../../luathread $(MAKE) -C $$f clean install ; done

.phony: all install uninstall release clean
