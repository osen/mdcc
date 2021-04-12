set -e

ROOTDIR="$(pwd)"
PREFIX="$ROOTDIR/prefix"
DISTDIR="$ROOTDIR/distfiles"
PATCHDIR="$ROOTDIR/patches"
SYSTEMDIR="$ROOTDIR/system"

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

INC="-I$SYSTEMDIR/include -I$SYSTEMDIR/res"
CFLAGS="$INC -m68000 -Wall -Wextra -Wno-shift-negative-value -Wno-main -Wno-unused-parameter -fno-builtin"
RELEASE_CFLAGS="$CFLAGS -O3 -fuse-linker-plugin -fno-web -fno-gcse -fno-unit-at-a-time -fomit-frame-pointer -flto"
RELEASE_ASMFLAGS="$CFLAGS -O3 -fuse-linker-plugin -fno-web -fno-gcse -fno-unit-at-a-time -fomit-frame-pointer -S"

system()
{
  cd "$ROOTDIR"
  rm -rf out
  mkdir out

  m68k-elf-gcc $CFLAGS -c -o out/rom_head.o system/src/boot/rom_head.c
  m68k-elf-ld -T "$SYSTEMDIR/ldscripts/md.ld" -nostdlib --oformat binary -o out/rom_head.bin out/rom_head.o
  m68k-elf-gcc -x assembler-with-cpp $CFLAGS -c -o out/sega.o system/src/boot/sega.s

  "$CC" -o out/sizebnd system/src/sizebnd/sizebnd.c
}

md()
{
  cd "$ROOTDIR"
  rm -rf md
  mkdir md

  UNITS=" \
    bmp dma everdrive fat16 joy map mapper maths \
    maths3D memory pal psg sound sprite_eng sram string \
    sys tab_cnv tab_log10 tab_log2 tab_sin tab_sqrt tab_vol \
    timer tools types vdp vdp_bg vdp_dma vdp_pal vdp_spr \
    vdp_tile vram xgm ym2612 z80_ctrl"

  for UNIT in $UNITS; do
    echo "Compiling: $UNIT.c"
    m68k-elf-gcc $RELEASE_CFLAGS -c -o md/$UNIT.o system/src/md/$UNIT.c
  done

  cd md
  m68k-elf-ar rcs libmd.a --plugin=$PREFIX/libexec/gcc/m68k-elf/9.3.0/liblto_plugin.so *.o
  mkdir -p "$SYSTEMDIR/lib"
  cp libmd.a "$SYSTEMDIR/lib"
}

example()
{
  cd "$ROOTDIR"

  m68k-elf-gcc \
    $CFLAGS \
    -c \
    -o out/main.o \
    "$SYSTEMDIR/src/hello/main.c"

  m68k-elf-gcc \
    -n \
    -T "$SYSTEMDIR/ldscripts/md.ld" \
    -nostdlib \
    out/sega.o \
    out/main.o \
    "$SYSTEMDIR/lib/libmd.a" \
    "$PREFIX/lib/libgcc.a" \
    -o out/rom.out \
    -Wl,--gc-sections

  #m68k-elf-ld \
  #  -T "$SYSTEMDIR/ldscripts/md.ld" \
  #  -nostdlib \
  #  out/sega.o \
  #  out/main.o \
  #  "$SYSTEMDIR/lib/libmd.a" \
  #  "$PREFIX/lib/libgcc.a" \
  #  -o out/rom.out \
  #  --plugin=$PREFIX/libexec/gcc/m68k-elf/9.3.0/liblto_plugin.so \
  #  --gc-sections

  #m68k-elf-gcc \
  #  -n \
  #  -T "$SYSTEMDIR/ldscripts/md.ld" \
  #  -nostdlib \
  #  out/sega.o \
  #  out/main.o \
  #  "$SYSTEMDIR/lib/libmd.a" \
  #  "$PREFIX/lib/libgcc.a" \
  #  -o out/rom.out

  m68k-elf-objcopy -O binary out/rom.out out/rom.bin
  out/sizebnd out/rom.bin -sizealign 131072
}

clean()
{
  cd "$ROOTDIR"
  rm -rf md
  rm -rf out
  rm -rf "$SYSTEMDIR/lib"
}

mkdir -p work
binutils
gcc_first
newlib
gcc_second
system
md
example
#clean
