#pragma once

namespace V {

struct RegisterInst {
	unsigned int opcode:7;
	unsigned int rd:5;
	unsigned int funct3:3;
	unsigned int rs1:5
	unsigned int rs2:5;
	unsigned int funct7:7;
};

struct ImmediateInst {
	unsigned int opcode:7;
	unsigned int rd:5;
	unsigned int funct3:3;
	unsigned int rs1:5;
	unsigned int imm:11;
};

struct UpperInst { // Or Jump
	unsigned int opcode:7;
	unsigned int rd:5;
	unsigned int imm:20;
};

