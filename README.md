This is a WIP. You are not currently granted any rights to it.

[Usage instructions are here](run.txt)

## Status

Currently the program only tests to verify it sees a load-unsigned-immediate and prints the immediate value. There is one test designed for use with this.

## Tests

Perform the steps in run.txt, then:

	# Path here will vary
    export LLVM=/Volumes/ToshibaMac/work/llvm/llvm9
    
    # Optional: Test your LLVM to see if it's compatible. Look for "riscv"
    $RISCV/bin/llc --version

    mkdir testbuild

    # Build ELF
    $LLVM/bin/clang -c --target=riscv32 test/li.s -o testbuild/li.o

    # Extract binary
    $LLVM/bin/llvm-objcopy -O binary --input-target=elf32-littleriscv testbuild/li.o testbuild/li.bin

    # Run test
    ./build/riscv testbuild/li.bin
