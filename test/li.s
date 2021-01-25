# Program consisting of a single load immediate

.section .text
.globl _start
_start:

# Low order 3 nibbles unused
.equ CONSTANT, 0xbeeef000

        li a0, CONSTANT
