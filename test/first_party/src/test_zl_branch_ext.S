// Zl BRANCH-EXT64: L.BFEQI, L.BFNEI, L.BRNG, L.BRNG.INV, L.BRNGU, L.BRNGU.INV, L.BTBL.

#include "common/zl.h"

zl_test_begin

  // =========================================================================
  // L.BFEQI / L.BFNEI: branch on bit field equality / inequality
  // =========================================================================

  // Single bit field at pos 0 (len = 1).
  li a0, 1
  taken64 zl64_bf F3_BFEQI, A0, 0, 1, 1
  not_taken64 zl64_bf F3_BFNEI, A0, 0, 1, 1
  not_taken64 zl64_bf F3_BFEQI, A0, 0, 1, 0
  taken64 zl64_bf F3_BFNEI, A0, 0, 1, 0

  // 8-bit field at pos 8 (len = 8).
  li a0, 0x12345678
  taken64 zl64_bf F3_BFEQI, A0, 8, 8, 0x56
  not_taken64 zl64_bf F3_BFNEI, A0, 8, 8, 0x56
  not_taken64 zl64_bf F3_BFEQI, A0, 8, 8, 0x57
  taken64 zl64_bf F3_BFNEI, A0, 8, 8, 0x57

  // 12-bit field matching signed immediate (imm = -1 -> 0xfff).
  li a0, 0x0fff
  taken64 zl64_bf F3_BFEQI, A0, 0, 12, -1
  not_taken64 zl64_bf F3_BFNEI, A0, 0, 12, -1

  // Top bit on RV32 / RV64.
#if __riscv_xlen == 32
  li a0, 0x80000000
  taken64 zl64_bf F3_BFEQI, A0, 31, 1, 1
  not_taken64 zl64_bf F3_BFNEI, A0, 31, 1, 1
  // Full 32-bit register compare.
  li a0, -100
  taken64 zl64_bf F3_BFEQI, A0, 0, 32, -100
  not_taken64 zl64_bf F3_BFNEI, A0, 0, 32, -100
#else
  li a0, 0x8000000000000000
  taken64 zl64_bf F3_BFEQI, A0, 63, 1, 1
  not_taken64 zl64_bf F3_BFNEI, A0, 63, 1, 1
  // Full 64-bit register compare.
  li a0, -100
  taken64 zl64_bf F3_BFEQI, A0, 0, 64, -100
  not_taken64 zl64_bf F3_BFNEI, A0, 0, 64, -100

  // Draft example: NaN-box tag check (pos = 47, len = 17, imm = -15).
  // sext(-15)[16:0] = 0x1fff1.
  li a0, 0x1fff1 << 47
  taken64 zl64_bf F3_BFEQI, A0, 47, 17, -15
  not_taken64 zl64_bf F3_BFNEI, A0, 47, 17, -15
#endif

  // pos + len > XLEN is reserved and raises illegal instruction.
  csrr t4, mtvec
  la t0, illegal_bfeqi
  csrw mtvec, t0
1:
#if __riscv_xlen == 32
  zl64_bf F3_BFEQI, A0, 16, 17, 0, 12  // 16 + 17 = 33 > 32
#else
  zl64_bf F3_BFEQI, A0, 32, 33, 0, 12  // 32 + 33 = 65 > 64
#endif
  j fail
.p2align 6
illegal_bfeqi:
  csrw mtvec, t4
  csrr t0, mcause
  check t0, 2
  csrr t0, mepc
  la t1, 1b
  bne t0, t1, fail

  // =========================================================================
  // L.BRNG / L.BRNG.INV: signed range branches
  // =========================================================================

  // Positive range: 10 <= a0 <= 20 (hi - lo = 10).
  li a0, 10
  taken64 zl64_brng F3_BRNG, A0, 10, 20
  not_taken64 zl64_brng F3_BRNG_INV, A0, 10, 20
  li a0, 20
  taken64 zl64_brng F3_BRNG, A0, 10, 20
  not_taken64 zl64_brng F3_BRNG_INV, A0, 10, 20
  li a0, 15
  taken64 zl64_brng F3_BRNG, A0, 10, 20
  not_taken64 zl64_brng F3_BRNG_INV, A0, 10, 20
  li a0, 9
  not_taken64 zl64_brng F3_BRNG, A0, 10, 20
  taken64 zl64_brng F3_BRNG_INV, A0, 10, 20
  li a0, 21
  not_taken64 zl64_brng F3_BRNG, A0, 10, 20
  taken64 zl64_brng F3_BRNG_INV, A0, 10, 20

  // Negative range across 0: -10 <= a0 <= 20 (hi - lo = 30).
  li a0, 0
  taken64 zl64_brng F3_BRNG, A0, -10, 20
  not_taken64 zl64_brng F3_BRNG_INV, A0, -10, 20
  li a0, -10
  taken64 zl64_brng F3_BRNG, A0, -10, 20
  li a0, -11
  not_taken64 zl64_brng F3_BRNG, A0, -10, 20
  taken64 zl64_brng F3_BRNG_INV, A0, -10, 20

  // Maximum delta (hi - lo = 255): 100 <= a0 <= 355.
  li a0, 355
  taken64 zl64_brng F3_BRNG, A0, 100, 355
  li a0, 356
  not_taken64 zl64_brng F3_BRNG, A0, 100, 355

  // =========================================================================
  // L.BRNGU / L.BRNGU.INV: unsigned range branches
  // =========================================================================

  // Draft example: isdigit '0' (48) <= a0 <= '9' (57), hi - lo = 9.
  li a0, 53  // '5'
  taken64 zl64_brng F3_BRNGU, A0, 48, 57
  not_taken64 zl64_brng F3_BRNGU_INV, A0, 48, 57
  li a0, 97  // 'a'
  not_taken64 zl64_brng F3_BRNGU, A0, 48, 57
  taken64 zl64_brng F3_BRNGU_INV, A0, 48, 57
  li a0, 0
  not_taken64 zl64_brng F3_BRNGU, A0, 48, 57
  taken64 zl64_brng F3_BRNGU_INV, A0, 48, 57

  // Distinction between signed and unsigned:
  // a0 = -1 (0xffffffff / 0xffffffffffffffff).
  // In signed range 0..100, -1 is outside.
  li a0, -1
  not_taken64 zl64_brng F3_BRNG, A0, 0, 100
  not_taken64 zl64_brng F3_BRNGU, A0, 0, 100
  // Range with bit 15 set: lo = 0x8000, hi = 0x8050.
  // In signed, 0x8000 sign-extends to negative.
  // In unsigned, 0x8000 zero-extends to +32768.
  li a0, 0x8020
  taken64 zl64_brng F3_BRNGU, A0, 0x8000, 0x8050
  not_taken64 zl64_brng F3_BRNGU_INV, A0, 0x8000, 0x8050

  // =========================================================================
  // L.BTBL: table branch
  // =========================================================================

  // 1. es = 00 (1 byte): target = pc + (e << 1)
  li a0, 1
  j 1f
.balign 4
tbl_1b:
  .byte (target_1b_0 - 1f) >> 1
  .byte (target_1b_1 - 1f) >> 1
  .byte (target_1b_2 - 1f) >> 1
  .byte 0
1:
  zl64_btbl A0, 0, 3, ES_1B, (tbl_1b - 1b)
  j fail
target_1b_0:
  j fail
target_1b_1:
  j 2f
target_1b_2:
  j fail
2:

  // 2. es = 01 (2 bytes): bias = 10, index 1 (a0 = 11)
  li a0, 11
  j 1f
.balign 4
tbl_2b:
  .2byte (target_2b_0 - 1f) >> 1
  .2byte (target_2b_1 - 1f) >> 1
1:
  zl64_btbl A0, 10, 2, ES_2B, (tbl_2b - 1b)
  j fail
target_2b_0:
  j fail
target_2b_1:
  j 2f
2:

  // 3. es = 10 (4 bytes): bias = 0, index 0 (a0 = 0)
  li a0, 0
  j 1f
.balign 4
tbl_4b:
  .4byte (target_4b_0 - 1f) >> 1
  .4byte (target_4b_1 - 1f) >> 1
1:
  zl64_btbl A0, 0, 2, ES_4B, (tbl_4b - 1b)
  j fail
target_4b_0:
  j 2f
target_4b_1:
  j fail
2:

  // 4. Out-of-bounds index: falls through sequentially without jumping.
  li a0, 5  // bound is 3, 5 >= 3
  j 1f
.balign 4
tbl_oob:
  .byte 0, 0, 0, 0
1:
  zl64_btbl A0, 0, 3, ES_1B, (tbl_oob - 1b)
  // If we reach here, fall-through succeeded!
  j 2f
  j fail
2:

  // Out-of-bounds: a0 < bias (i wraps to large unsigned value >= bound).
  li a0, 5  // bias is 10 -> i = 5 - 10 = -5 (unsigned huge) >= bound 3
  j 1f
.balign 4
tbl_underflow:
  .byte 0, 0, 0, 0
1:
  zl64_btbl A0, 10, 3, ES_1B, (tbl_underflow - 1b)
  j 2f
  j fail
2:

  // 5. Reserved es = 0b11: raises illegal instruction.
  csrr t4, mtvec
  la t0, illegal_es
  csrw mtvec, t0
1:
  zl64_btbl A0, 0, 2, 3, 0
  j fail
.p2align 6
illegal_es:
  csrw mtvec, t4
  csrr t0, mcause
  check t0, 2
  csrr t0, mepc
  la t1, 1b
  bne t0, t1, fail

  // 6. With Zicfilp (mseccfg.MLPE), target of L.BTBL needs a landing pad.
  li t0, 1 << 10
  csrs 0x747, t0

  // Valid landing pad at target: succeeds.
  li a0, 0
  j 1f
.balign 4
tbl_lp_ok:
  .2byte (target_lp_ok - 1f) >> 1
1:
  zl64_btbl A0, 0, 1, ES_2B, (tbl_lp_ok - 1b)
  j fail
.balign 4
target_lp_ok:
  .4byte 0x00000017  // lpad 0
  j 2f
2:

  // Target missing landing pad: raises software-check exception (mcause 18, mtval 2).
  csrr t4, mtvec
  la t0, lp_fault
  csrw mtvec, t0
  li a0, 0
  j 1f
.balign 4
tbl_lp_missing:
  .2byte (target_lp_missing - 1f) >> 1
1:
  zl64_btbl A0, 0, 1, ES_2B, (tbl_lp_missing - 1b)
  j fail
.balign 4
target_lp_missing:
  j fail
lp_fault:
  csrw mtvec, t4
  li t0, 1 << 10
  csrc 0x747, t0
  csrr t0, mcause
  check t0, 18
  csrr t0, mtval
  check t0, 2

zl_test_end
