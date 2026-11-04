// Zl instruction lengths: 64-bit encodings are fetched in full, longer ones are not.

#include "common/zl.h"

zl_test_begin

  // 64-bit encodings are fetched in full. None is defined in inst[6:5] = 01,
  // so this one is illegal and mtval holds the whole encoding (its low XLEN
  // bits), which shows that the fourth parcel was fetched.
  csrr t4, mtvec
  la t0, illegal64
  csrw mtvec, t0
1:
  .4byte 0x9abcde3f  // inst[33:32] = 11, inst[36:34] = 000
  .4byte 0x12345663
  j fail
.p2align 6
illegal64:
  csrw mtvec, t4
  csrr t0, mcause
  check t0, 2
  csrr t0, mepc
  la t1, 1b
  bne t0, t1, fail
  csrr t0, mtval
#if __riscv_xlen == 64
  check t0, 0x123456639abcde3f
#else
  check t0, 0x9abcde3f
#endif

  // Encodings longer than 64 bits (inst[36:34] = 111) are not supported:
  // only 48 bits are fetched and reported.
  la t0, illegal80
  csrw mtvec, t0
1:
  .4byte 0x9abcde3f
  .4byte 0x1234567f
  j fail
.p2align 6
illegal80:
  csrw mtvec, t4
  csrr t0, mcause
  check t0, 2
  csrr t0, mepc
  la t1, 1b
  bne t0, t1, fail
  csrr t0, mtval
#if __riscv_xlen == 64
  check t0, 0x567f9abcde3f
#else
  check t0, 0x9abcde3f
#endif

zl_test_end
