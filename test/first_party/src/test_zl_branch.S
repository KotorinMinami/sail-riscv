// Zl register-register branches (L.Bcc, L.BccW, L.BCALL.cc) and BRANCH-IMM.

#include "common/zl.h"

zl_test_begin

  // Register-register branches.
  li a0, 5
  li a1, 5
  taken zl_b F6_BCC, F3_BEQ, A0, A1
  not_taken zl_b F6_BCC, F3_BNE, A0, A1
  li a0, -1
  li a1, 1
  taken zl_b F6_BCC, F3_BLT, A0, A1
  not_taken zl_b F6_BCC, F3_BGE, A0, A1
  not_taken zl_b F6_BCC, F3_BLTU, A0, A1
  taken zl_b F6_BCC, F3_BGEU, A0, A1
  // Backwards loop.
  li a0, 3
1:
  addi a0, a0, -1
  zl_b F6_BCC, F3_BNE, A0, ZERO, -4
  check a0, 0

#if __riscv_xlen == 64
  // L.BccW compares bits 31:0 only.
  li a0, 0xffffffff00000005
  li a1, 5
  taken zl_b F6_BCCW, F3_BEQ, A0, A1
  not_taken zl_b F6_BCC, F3_BEQ, A0, A1
  li a0, 0x80000000
  li a1, 1
  taken zl_b F6_BCCW, F3_BLT, A0, A1
  not_taken zl_b F6_BCC, F3_BLT, A0, A1
#endif

  // L.BCALL.cc writes ra = pc + 6 whether or not it is taken.
  li a0, 1
  li a1, 2
  li ra, 0
  zl_b F6_BCALL, F3_BEQ, A0, A1, 10
  auipc t1, 0
  bne ra, t1, fail
  li ra, 0
  zl_b F6_BCALL, F3_BNE, A0, A1, 10
  j fail
  auipc t1, 0
  addi t1, t1, -4
  bne ra, t1, fail

  // Compare with a sign-extended 11-bit immediate.
  li a0, -1
  taken zl_bi BEQI, A0, -1
  not_taken zl_bi BNEI, A0, -1
  li a0, -1024
  taken zl_bi BEQI, A0, -1024
  li a0, 1023
  taken zl_bi BEQI, A0, 1023
  li a0, 5
  taken zl_bi BLTI, A0, 6
  not_taken zl_bi BGEI, A0, 6
  taken zl_bi BGEI, A0, -1024
  taken zl_bi BLTUI, A0, -1
  not_taken zl_bi BGEUI, A0, -1
  taken zl_bi BGEUI, A0, 5
  li a0, 0xf0
  taken zl_bi BTANYI, A0, 0x10
  taken zl_bi BTNONEI, A0, 0x0f
  not_taken zl_bi BTANYI, A0, 0x0f

zl_test_end
