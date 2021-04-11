set -e

ROOTDIR="$(pwd)"
PREFIX="$ROOTDIR/dist"
DISTDIR="$ROOTDIR/distfiles"
PATCHDIR="$ROOTDIR/patches"

export CC=clang
export CXX=clang++
export PATH="$PATH:$PREFIX/bin"

binutils()
{
  cd "$ROOTDIR/work"
  7z x -so "$DISTDIR/binutils-2.34.tar.xz" | tar xf -
  cd binutils-2.34
  mkdir build && cd build

  ../configure \
    --target=m68k-elf \
    --prefix="$PREFIX" \
    --enable-install-libbfd \
    --disable-werror

  gmake all install
}

gcc_first()
{
  cd "$ROOTDIR/work"
  7z x -so "$DISTDIR/gcc-9.3.0.tar.xz" | tar xf -
  cd gcc-9.3.0

  patch -d . < "$PATCHDIR/gcc-undeclared_fdset.patch"

  7z x -so "$DISTDIR/gmp-6.1.0.tar.bz2" | tar xf -
  mv gmp-* gmp
  7z x -so "$DISTDIR/mpfr-3.1.4.tar.bz2" | tar xf -
  mv mpfr-* mpfr
  7z x -so "$DISTDIR/mpc-1.0.3.tar.gz" | tar xf -
  mv mpc-* mpc
  7z x -so "$DISTDIR/isl-0.18.tar.bz2" | tar xf -
  mv isl-* isl

  mkdir first && cd first

  ../configure \
    --target=m68k-elf \
    --prefix="$PREFIX" \
    --without-headers \
    --with-newlib \
    --enable-languages=c \
    --disable-libssp \
    --disable-tls \
    --with-cpu=m68000 \
    --disable-werror \
    --disable-nls \
    --disable-multilib

  gmake all install

  cd "$PREFIX/libexec/gcc/m68k-elf/9.3.0"
  ln -s liblto_plugin.so.0.0 liblto_plugin.so.0
  ln -s liblto_plugin.so.0 liblto_plugin.so
}

newlib()
{
  cd "$ROOTDIR/work"
  7z x -so "$DISTDIR/newlib-3.3.0.tar.gz" | tar xf -
  cd newlib-3.3.0
  mkdir build && cd build

  ../configure \
    --target=m68k-elf \
    --prefix="$PREFIX" \
    --with-cpu=m68000 \
    --disable-werror

  gmake all install
}

gcc_second()
{
  cd "$ROOTDIR/work/gcc-9.3.0"
  mkdir second && cd second

  ../configure \
    --target=m68k-elf \
    --prefix="$PREFIX" \
    --with-newlib \
    --disable-libssp \
    --disable-tls \
    --enable-threads=single \
    --enable-languages=c \
    --with-cpu=m68000 \
    --disable-werror \
    --disable-nls \
    --disable-multilib

  gmake all install

  cd "$PREFIX/lib"
  ln -s ../lib/gcc/m68k-elf/9.3.0/libgcc.a libgcc.a
}

mkdir -p work
binutils
gcc_first
newlib
gcc_second

