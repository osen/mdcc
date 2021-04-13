mdcc - Mega Drive C Compiler Toolchain
======================================

Building
--------
To build the toolchain, just change into the root of the extracted
project and execute:

$ sh build.sh

By the end of this process, you should have a new directory called
"out".  This provides the entire toolchain and can be copied and
run from any location. This is what should be packaged.

Using
-----
You can now compile a sample project via:

$ out/bin/mdcc out/src/hello/main.c

This will prodice a final rom file called "rom.bin" in the current
working directory. This can be run in the emulator, i.e:

$ dgen rom.bin

Requires
--------
texinfo - to compile gcc
perl - to compile gcc
gmake - to compile gcc
xz - to extract gcc
clang - system compiler

Thanks
------
Much of this project is based on the SGDK and gendev projects. They
were a great source of tools, scripts and underlying documentation.
