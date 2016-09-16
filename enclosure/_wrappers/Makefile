SUBMODULES := $(shell find . -type d -depth 1 ! -name \*.dSYM -print)

PREFIX ?= ~/.hammerspoon
HS_APPLICATION ?= /Applications

list:
	for k in $(SUBMODULES) ; do  echo "-- $$k --" ; done

all:
	for k in $(SUBMODULES) ; do  echo "-- $$k --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) && $(MAKE) -C $$k all ; done

install:
	for k in $(SUBMODULES) ; do  echo "-- $$k --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) && $(MAKE) -C $$k install ; done

clean:
	for k in $(SUBMODULES) ; do  echo "-- $$k --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) && $(MAKE) -C $$k clean ; done

uninstall:
	for k in $(SUBMODULES) ; do  echo "-- $$k --" && HS_APPLICATION=$(HS_APPLICATION) PREFIX=$(PREFIX) && $(MAKE) -C $$k uninstall ; done

.PHONY: list all install clean uninstall
