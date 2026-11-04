// Zl bit, mask, byte and halfword test branches.

#include "common/zl.h"

zl_test_begin

  // Bit and mask tests.
  li a0, 0xf0
  li a1, 0x0f
  taken zl_b F6_BTEST, BTNONE, A0, A1
  not_taken zl_b F6_BTEST, BTANY, A0, A1
  li a1, 0x30
  taken zl_b F6_BTEST, BTANY, A0, A1
  taken zl_b F6_BTEST, BTALL, A0, A1
  not_taken zl_b F6_BTEST, BTNALL, A0, A1
  li a1, 0x1f0
  not_taken zl_b F6_BTEST, BTALL, A0, A1
  taken zl_b F6_BTEST, BTNALL, A0, A1
  // Only rs2[log2(XLEN)-1:0] selects the bit.
  li a1, 0x44
  taken zl_b F6_BTEST, BBSR, A0, A1
  not_taken zl_b F6_BTEST, BBCR, A0, A1
  li a1, 0x43
  taken zl_b F6_BTEST, BBCR, A0, A1

  // Byte and halfword search.
  li a0, 0x11223344
  li a1, 0x22
  taken zl_b F6_BELEM, BEQB, A0, A1
  not_taken zl_b F6_BELEM, BNEB, A0, A1
  li a1, 0x55
  not_taken zl_b F6_BELEM, BEQB, A0, A1
  taken zl_b F6_BELEM, BNEB, A0, A1
  li a1, 0xff1122
  taken zl_b F6_BELEM, BEQH, A0, A1
  li a1, 0x2233
  not_taken zl_b F6_BELEM, BEQH, A0, A1
  taken zl_b F6_BELEM, BNEH, A0, A1
  // L.BNZB/L.BZB: search for a zero byte.
  li a0, -1
  taken zl_b F6_BELEM, BNEB, A0, ZERO
  li a0, 0x11003344
  taken zl_b F6_BELEM, BEQB, A0, ZERO
#if __riscv_xlen == 64
  li a0, 0x7700000000000001
  li a1, 0x77
  taken zl_b F6_BELEM, BEQB, A0, A1
#endif

  // L.BBC/L.BBS.
  li a0, 0x8
  taken zl_bbit 1, A0, 3
  not_taken zl_bbit 0, A0, 3
  taken zl_bbit 0, A0, 4
#if __riscv_xlen == 64
  li a0, 1
  slli a0, a0, 37
  taken zl_bbit 1, A0, 37
  not_taken zl_bbit 1, A0, 36
#endif

zl_test_end
