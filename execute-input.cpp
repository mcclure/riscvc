//! PROLOGUE

#include <stdio.h>
#include "riscv.h"

//! END

//! METHOD
Emulator::Emulator(int memoryLen) {
}

void Emulator::run(uint32_t instr) {
	int x;
//! CONTENT
	LUI:
		printf("Load immediate: instr %x imm %x\n", instr, VREAD(instr, IMMU));
	default:
		printf("Bad instruction!\n");
//! END
}