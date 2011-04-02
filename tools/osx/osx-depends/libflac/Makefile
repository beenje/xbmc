#  A quick and dirty Makefile to download/build and install
#
#  Usage:
#    make
#    sudo make install

include ../config.mk
include $(foreach i,$(universal_archs), ../config.$(i).mk)

# lib name, version
LIBNAME=flac
VERSION=1.2.1
SOURCE=$(LIBNAME)-$(VERSION)
# download location and format
BASE_URL=http://mirrors.xbmc.org/build-deps/darwin-libs
ARCHIVE=$(SOURCE).tar.gz
TARBALLS_LOCATION=/Users/Shared/xbmc-depends/tarballs
RETRIEVE_TOOL=/usr/bin/curl
RETRIEVE_TOOL_FLAGS=-Ls --create-dirs --output $(TARBALLS_LOCATION)/$(ARCHIVE)
ARCHIVE_TOOL=tar
ARCHIVE_TOOL_FLAGS=xf

# configuration settings
ARCH_FLAGS=$(foreach i,$(universal_archs),-arch $(i))
CONFIGURE=./configure --prefix=$(PREFIX) \
  --disable-asm-optimizations \
  --disable-xmms-plugin \
  --disable-cpplibs \
  --disable-dependency-tracking

LIBDYLIB=$(SOURCE)/$(LIBNAME)/.libs/$(LIBNAME).dylib

CLEAN_FILES=$(ARCHIVE) $(SOURCE)

all: $(LIBDYLIB) .installed

$(TARBALLS_LOCATION)/$(ARCHIVE):
	$(RETRIEVE_TOOL) $(RETRIEVE_TOOL_FLAGS) $(BASE_URL)/$(ARCHIVE)

$(SOURCE): $(TARBALLS_LOCATION)/$(ARCHIVE)
	-rm -rf $(SOURCE)
	$(ARCHIVE_TOOL) $(ARCHIVE_TOOL_FLAGS) $(TARBALLS_LOCATION)/$(ARCHIVE)
	echo $(SOURCE) > .gitignore
	cd $(SOURCE); patch -p1 < ../01-build-lib-universal.patch
	cd $(SOURCE); $(CONFIGURE)
	cd $(SOURCE); sed -i .org "s/CC -dynamiclib/CC -dynamiclib $(ARCH_FLAGS)/g" libtool

$(LIBDYLIB): $(SOURCE)
	make -C $(SOURCE)

.installed:
	make -C $(SOURCE) install
	touch $@

clean:
	make -C $(SOURCE) clean
	rm .installed

distclean::
	rm -rf $(SOURCE) .installed
