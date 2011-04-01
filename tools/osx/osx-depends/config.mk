# Find where this Makefile is located
TOP := $(dir $(lastword $(MAKEFILE_LIST)))

platform_os=MacOSX
platform_sdk_version=10.4u
platform_min_version=macosx-version-min=10.4
platform_gcc_version=4.0.1
platform_path=/Developer
platform_os_cflags=-no_compact_linkedit
platform_os_ldflags=-no_compact_linkedit
prefix_path=/Users/Shared/xbmc-depends/osx-10.4_i386_ppc
platform_sdk_path=${platform_path}/SDKs/${platform_os}${platform_sdk_version}.sdk
platform_bin_path=${platform_path}/usr/bin
universal_archs=i386 ppc

export universal_archs
export platform_sdk_version
export NM=/usr/bin/nm
export CPP=/usr/bin/cpp-4.0
export CXXCPP=${CPP}
export CPPFLAGS=-no-cpp-precomp -I${prefix_path}/include
export CC=/usr/bin/gcc-4.0
export CFLAGS=-std=gnu89 -no-cpp-precomp -m${platform_min_version} -isysroot ${platform_sdk_path} ${platform_os_cflags} -I${platform_sdk_path}/usr/include
export LD=${platform_bin_path}/ld
export LDFLAGS=-m${platform_min_version} -isysroot ${platform_sdk_path} ${platform_os_ldflags} -L${prefix_path}/lib -L${platform_sdk_path}/usr/lib
export CXX=/usr/bin/g++-4.0
export CXXFLAGS=-m${platform_min_version} -isysroot ${platform_sdk_path} ${platform_os_cflags}
export AR=${platform_bin_path}/ar
export AS=${platform_bin_path}/as
export STRIP=${platform_bin_path}/strip
export RANLIB=${platform_bin_path}/ranlib
export ACLOCAL=aclocal -I ${prefix_path}/share/aclocal -I /Developer/usr/share/aclocal
export LIBTOOL=${prefix_path}/bin/glibtool
export LIBTOOLIZE=${prefix_path}/bin/glibtoolize
export PREFIX=${prefix_path}
export DEVROOT=${platform_path}
export SDKROOT=${platform_sdk_path}
export PKG_CONFIG_PATH=${prefix_path}:${platform_sdk_path}/usr/lib/pkgconfig
export PATH:=${prefix_path}/bin:${platform_bin_path}:/Developer/usr/bin:$(PATH)
export MACOSX_DEPLOYMENT_TARGET=10.4

