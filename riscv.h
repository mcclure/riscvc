#pragma once

// Instruction shape

// Bits filled out from diagram in riscv-spec unprivileged, 20190621-draft, sec 2.3

// All instructions
#define OPCODE 0
#define OPCODE_TO 6

// R, I, U, J
#define RD 7
#define RD_TO 11

// R, I, S, B
#define FUNCT3 12
#define FUNCT4 14
#define RS1 15
#define RS1_TO 19

// R, S, B
#define RS2  20
#define RS2_TO 24

// R
#define FUNCT7 25
#define FUNCT7_TO 31

// I

#define IMMI 20
#define IMMI_TO 24

// S

#define IMMS1 7
#define IMMS1_TO 11
#define IMMS2 25
#define IMMS2_TO 31

// B

#define IMMB1 8
#define IMMB1_TO 11
#define IMMB2 25
#define IMMB2_TO 30
#define IMMB3 7
#define IMMB3_TO 7
#define IMMB4 31
#define IMMB4_TO 31

// U

#define IMMU 12
#define IMMU_TO 31

// J

#define IMMJ1 21
#define IMMJ1_TO 30 
#define IMMJ2 20
#define IMMJ2_TO 20 
#define IMMJ3 12
#define IMMJ3_TO 19 
#define IMMJ4 31
#define IMMJ4_TO 31 

#define VREAD(FIELD)
#define VWRIT(FIELD, VALUE)

// Opcodes

// Generated using ./helper/opcode-map.pl from 20190621-draft tex

#define LOAD        0x03     // 3
#define LOAD_FP     0x07     // 7
#define MISC_MEM    0x0f     // 15
#define OP_IMM      0x13     // 19
#define AUIPC       0x17     // 23
#define OP_IMM_32   0x1b     // 27
#define STORE       0x23     // 35
#define STORE_FP    0x27     // 39
#define AMO         0x2f     // 47
#define OP          0x33     // 51
#define LUI         0x37     // 55
#define OP_32       0x3b     // 59
#define MADD        0x43     // 67
#define MSUB        0x47     // 71
#define NMSUB       0x4b     // 75
#define NMADD       0x4f     // 79
#define OP_FP       0x53     // 83
#define BRANCH      0x63     // 99
#define JALR        0x67     // 103
#define JAL         0x6f     // 111
#define SYSTEM      0x73     // 115

