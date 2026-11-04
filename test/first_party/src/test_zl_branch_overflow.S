// Zl overflow branches.

#include "common/zl.h"

zl_test_begin

  // Overflow branches write rd and branch on overflow.
  li a0, -1
  srli a0, a0, 1
  li a1, 1
  taken zl_bovf ADDBO, A2, A0, A1
  addi t1, a0, 1
  bne a2, t1, fail
  li a1, -1
  not_taken zl_bovf ADDBO, A2, A0, A1
  addi t1, a0, -1
  bne a2, t1, fail
  li a0, 1
  slli a0, a0, __riscv_xlen - 1
  li a1, 1
  taken zl_bovf SUBBO, A2, A0, A1
  addi t1, a0, -1
  bne a2, t1, fail
  li a0, -1
  taken zl_bovf ADDBOU, A2, A0, A1
  check a2, 0
  not_taken zl_bovf ADDBOU, A2, A1, A1
  check a2, 2
  li a0, 1
  li a1, 2
  taken zl_bovf SUBBOU, A2, A0, A1
  check a2, -1
  not_taken zl_bovf SUBBOU, A2, A1, A0
  check a2, 1
  li a0, 1
  slli a0, a0, __riscv_xlen / 2
  taken zl_bovf MULBO, A2, A0, A0
  check a2, 0
  li a0, -5
  li a1, 3
  not_taken zl_bovf MULBO, A2, A0, A1
  check a2, -15
  // rd may alias a source.
  not_taken zl_bovf ADDBO, A0, A0, A1
  check a0, -2
#if __riscv_xlen == 64
  li a0, 0x7fffffff
  li a1, 1
  taken zl_bovf ADDWBO, A2, A0, A1
  check a2, 0xffffffff80000000
  li a0, 0x100000005
  not_taken zl_bovf ADDWBO, A2, A0, A1
  check a2, 6
  li a0, 0x80000000
  taken zl_bovf SUBWBO, A2, A0, A1
  check a2, 0x7fffffff
#endif

zl_test_end
