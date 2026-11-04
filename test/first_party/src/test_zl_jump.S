// Zl JUMP: L.JAL, L.JALR and L.JALT, including Zicfilp landing pads for L.JALT.

#include "common/zl.h"

zl_test_begin

  // L.JAL forwards: ra = pc + 6.
  zl_jal RA, 10
  j fail
  auipc t1, 0
  addi t1, t1, -4
  bne ra, t1, fail
  // L.JAL backwards.
  j 2f
1:
  j 3f
2:
  zl_jal ZERO, -4
  j fail
3:

  // 64-bit L.JAL forwards: ra = pc + 8.
  zl64_jal RA, 12
  j fail
  auipc t1, 0
  addi t1, t1, -4
  bne ra, t1, fail

  // 64-bit L.JAL backwards (rd = x0).
  j 2f
1:
  j 3f
2:
  zl64_jal ZERO, -4
  j fail
3:

  // 64-bit L.JAL with rd != ra.
  zl64_jal A0, 12
  j fail
  auipc t1, 0
  addi t1, t1, -4
  bne a0, t1, fail

  // L.JALR clears bit 0 of the target and links pc + 6.
  auipc t0, 0
  zl_jalr A0, T0, 15
  j fail
  addi t0, t0, 10
  bne a0, t0, fail

  // L.JALT: rd = pc + 6; pc = mem[pc + (off + rs1) * XLEN/8] & ~1. Each
  // table sits right before its L.JALT, which is therefore XLEN-aligned.
  li a1, 1
  j 1f
.balign 8
  PTR fail
  PTR 2f + 1  // bit 0 is cleared
1:
  zl_jalt RA, A1, -2
3:
  j fail
2:
  la t1, 3b
  bne ra, t1, fail
  // Tail jump (rd = x0) with a negative index.
  li a1, -1
  j 1f
.balign 8
  PTR 2f
1:
  zl_jalt ZERO, A1, 0
  j fail
2:
  // rs1 is read before rd is written.
  li a1, 1
  j 1f
.balign 8
  PTR fail
  PTR 2f
1:
  zl_jalt A1, A1, -2
3:
  j fail
2:
  la t1, 3b
  bne a1, t1, fail

  // With Zicfilp (mseccfg.MLPE), the target of L.JALT needs a landing pad.
  li t0, 1 << 10
  csrs 0x747, t0
  j 1f
.balign 8
  PTR 2f
1:
  zl_jalt ZERO, ZERO, -1
  j fail
.balign 4
2:
  .4byte 0x00000017  // lpad 0
  // Without one, the target raises a software-check exception.
  csrr t4, mtvec
  la t0, lp_fault
  csrw mtvec, t0
  j 1f
.balign 8
  PTR 2f
1:
  zl_jalt ZERO, ZERO, -1
  j fail
.balign 4
2:
  j fail
.p2align 6
lp_fault:
  csrw mtvec, t4
  li t0, 1 << 10
  csrc 0x747, t0
  csrr t0, mcause
  check t0, 18
  csrr t0, mtval
  check t0, 2

zl_test_end
