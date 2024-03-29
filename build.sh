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
  unxz < "$DISTDIR/binutils-2.34.tar.xz" | tar -xf -
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
  unxz < "$DISTDIR/gcc-9.3.0.tar.xz" | tar -xf -
  cd gcc-9.3.0

  patch -d . < "$PATCHDIR/gcc-undeclared_fdset.patch"

  tar -xjf "$DISTDIR/gmp-6.1.0.tar.bz2"
  mv gmp-* gmp
  tar -xjf "$DISTDIR/mpfr-3.1.4.tar.bz2"
  mv mpfr-* mpfr
  tar -xzf "$DISTDIR/mpc-1.0.3.tar.gz"
  mv mpc-* mpc
  tar -xjf "$DISTDIR/isl-0.18.tar.bz2"
  mv isl-* isl

  mkdir first && cd first

  ../configure \
    --target=m68k-elf \
    --prefix="$PREFIX" \
    --without-headers \
    --with-newlib \
    --enable-languages=c \
    --disable-lto \
    --disable-libssp \
    --disable-tls \
    --with-cpu=m68000 \
    --disable-werror \
    --disable-nls \
    --disable-multilib

  gmake all install
}

newlib()
{
  cd "$ROOTDIR/work"
  tar -xzf "$DISTDIR/newlib-3.3.0.tar.gz"
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
    --disable-lto \
    --with-cpu=m68000 \
    --disable-werror \
    --disable-nls \
    --disable-multilib

  gmake all install

  cd "$PREFIX/lib"
  ln -s ../lib/gcc/m68k-elf/9.3.0/libgcc.a libgcc.a
}

INC="-I$SYSTEMDIR/include -I$SYSTEMDIR/res"
WARN="-Wall -Wextra -Wno-shift-negative-value -Wno-main -Wno-unused-parameter"
CFLAGS="$INC $WARN -m68000 -fno-builtin"

RELEASE_CFLAGS="$CFLAGS -O3 -fno-web -fno-gcse -fno-unit-at-a-time -fomit-frame-pointer"

system()
{
  cd "$ROOTDIR"
  rm -rf out
  cp -r "$SYSTEMDIR" out

  m68k-elf-gcc $CFLAGS -c -o out/rom_head.o out/src/boot/rom_head.c

  m68k-elf-ld -T out/lib/ldscripts/md.ld -nostdlib --oformat binary \
    -o out/rom_head.bin out/rom_head.o

  m68k-elf-gcc -x assembler-with-cpp $CFLAGS -c \
    -o out/lib/sega.o out/src/boot/sega.s

  rm out/rom_head.*

  "$CC" -o out/bin/sizebnd src/sizebnd/sizebnd.c
  chmod +x out/bin/mdcc
  cp -r prefix out/gcc
}

md()
{
  cd "$ROOTDIR"
  rm -rf md
  mkdir md

  "$CC" -o md/bintos src/bintos/bintos.c

  "$CXX" \
    -Wno-writable-strings -DMAX_PATH=MAXPATHLEN \
    -o md/sjasm src/sjasm/*.cpp

  UNITS=" \
    bmp dma everdrive fat16 joy map mapper maths \
    maths3D memory pal psg sound sprite_eng sram string \
    sys tab_cnv tab_log10 tab_log2 tab_sin tab_sqrt tab_vol \
    timer tools types vdp vdp_bg vdp_dma vdp_pal vdp_spr \
    vdp_tile vram xgm ym2612 z80_ctrl"

  for UNIT in $UNITS; do
    echo "Compiling: $UNIT.c"
    m68k-elf-gcc $RELEASE_CFLAGS -c -o md/$UNIT.o out/src/md/$UNIT.c
  done

  UNITS=" \
    bmp_a dma_a kdebug maths3D_a memory_a smp_null \
    smp_null_pcm sram_a sys_a tools_a vdp_tile_a"

  for UNIT in $UNITS; do
    echo "Compiling: $UNIT.s"

    m68k-elf-gcc -x assembler-with-cpp $RELEASE_CFLAGS -c \
      -o md/$UNIT.o out/src/md/$UNIT.s
  done

  m68k-elf-gcc -x assembler-with-cpp $RELEASE_CFLAGS -c \
    -o md/libres.o out/res/libres.s

  UNITS="z80_drv0 z80_drv1 z80_drv2 z80_drv3 z80_xgm"

  for UNIT in $UNITS; do
    echo "Compiling: $UNIT.s80"
    md/sjasm -q out/src/md/$UNIT.s80 md/$UNIT.o80
    md/bintos md/$UNIT.o80

    m68k-elf-gcc -x assembler-with-cpp $RELEASE_CFLAGS -c \
      -o md/$UNIT.o md/$UNIT.s
  done

  cd md
  m68k-elf-ar rcs libmd.a *.o
  cp libmd.a ../out/lib

  cd "$ROOTDIR"
  rm -rf md
}

example()
{
  cd "$ROOTDIR"

  #m68k-elf-gcc \
  #  $RELEASE_CFLAGS \
  #  -c \
  #  -o out/main.o \
  #  "$SYSTEMDIR/src/hello/main.c"

  m68k-elf-gcc \
    $RELEASE_CFLAGS \
    -T "$SYSTEMDIR/lib/ldscripts/md.ld" \
    -nostdlib \
    "$SYSTEMDIR/src/hello/main.c" \
    out/lib/sega.o \
    out/lib/libmd.a \
    "$PREFIX/lib/libgcc.a" \
    -Wl,--gc-sections \
    -o rom.out

  m68k-elf-objcopy -O binary rom.out rom.bin
  out/bin/sizebnd rom.bin -sizealign 131072
}

clean()
{
  cd "$ROOTDIR"
  rm -rf md
  rm -rf out
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

