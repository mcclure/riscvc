# Program consisting of a single load immediate

.section .text
.globl _start
_start:

# Single lui can only hold 5 nibbles
.equ CONSTANT, 0xbeeef

        lui a0, CONSTANT
