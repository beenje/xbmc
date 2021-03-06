#  A quick and dirty Makefile to download/build and install
#
#  Usage:
#    make
#    sudo make install

include ../config.mk

# lib name, version
LIBNAME=SDL_mixer
VERSION=1.2.8
SOURCE=$(LIBNAME)-$(VERSION)
# download location and format
#BASE_URL=http://mirrors.xbmc.org/build-deps/darwin-libs
BASE_URL=http://www.libsdl.org/projects/SDL_mixer/release
ARCHIVE=$(SOURCE).tar.gz

RETRIEVE_TOOL=/usr/bin/curl
RETRIEVE_TOOL_FLAGS=-Ls --output $(ARCHIVE)
ARCHIVE_TOOL=tar
ARCHIVE_TOOL_FLAGS=xf

# configuration settings
export CFLAGS+=-undefined dynamic_lookup 
export CXXFLAGS+=-undefined dynamic_lookup
export LDFLAGS+=-liconv -Wl,-read_only_relocs,suppress -Wl,-undefined,dynamic_lookup
CONFIGURE=./configure --prefix=$(PREFIX) --host=$(HOST) \
  --disable-music-ogg --disable-music-mp3 \
  --disable-music-mod --disable-music-midi --disable-smpegtest --disable-sdltest

LIBDYLIB=$(SOURCE)/.libs/$(LIBNAME).a

CLEAN_FILES=$(ARCHIVE) $(SOURCE)

all: $(LIBDYLIB) .installed

$(ARCHIVE):
	$(RETRIEVE_TOOL) $(RETRIEVE_TOOL_FLAGS) $(BASE_URL)/$(ARCHIVE)
	echo $(ARCHIVE) > .gitignore

$(SOURCE): $(ARCHIVE)
	-rm -rf $(SOURCE)
	$(ARCHIVE_TOOL) $(ARCHIVE_TOOL_FLAGS) $(ARCHIVE)
	echo $(SOURCE) >> .gitignore
	cd $(SOURCE); $(CONFIGURE)

$(LIBDYLIB): $(SOURCE)
	make -C $(SOURCE)

.installed:
	make -C $(SOURCE) install
	touch $@

clean:
	make -C $(SOURCE) clean
	rm  .installed

distclean::
	rm -rf $(SOURCE) .installed
