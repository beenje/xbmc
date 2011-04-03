#  A quick and dirty Makefile to download/build and install
#
#  Usage:
#    make
#    sudo make install

include ../config.mk

# lib name, version
LIBNAME=SDL
VERSION=1.2.13
SOURCE=$(LIBNAME)-$(VERSION)

ARCHS=$(universal_archs)

all: $(ARCHS) .installed

$(ARCHS):
	-rm -rf $@; mkdir $@
	sed "s/_ARCH_/$@/g" Makefile.arch > $@/Makefile
	echo $@ >> .gitignore
	make -C $@

.installed: $(ARCHS)
	../merge.rb -e $(SOURCE) -o $(PREFIX) $(ARCHS)
	touch $@

clean:
	rm -rf $(ARCHS) .installed .gitignore

distclean::
	rm -rf $(ARCHS) .installed .gitignore
