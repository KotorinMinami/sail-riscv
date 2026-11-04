// Zl LI (L.LI, L.LUI, L.AIPC, L.AUIPC) and OP-IMM (L.ADDI, L.XORI, L.ORI, L.ANDI).

#include "common/zl.h"

zl_test_begin

  // L.LI sign-extends its 32-bit immediate.
  zl_li LI_LI, A0, 0x80000000
  check a0, -0x80000000
  zl_li LI_LI, A0, 0x12345678
  check a0, 0x12345678

  // L.AIPC: a0 = pc + imm.
  zl_li LI_AIPC, A0, 0x12345678
  auipc t1, 0
  li t2, 0x12345678 - 6
  add t1, t1, t2
  bne a0, t1, fail
  zl_li LI_AIPC, A0, -0x100
  auipc t1, 0
  addi t1, t1, -0x100 - 6
  bne a0, t1, fail

#if __riscv_xlen == 64
  // L.LUI replaces bits 63:32; L.AUIPC adds imm << 32.
  zl_li LI_LI, A0, 0x9abcdef0
  zl_li LI_LUI, A0, 0x12345678
  check a0, 0x123456789abcdef0
  li a0, 5
  zl_li LI_AUIPC, A0, 3
  check a0, 0x300000005

  // 64-bit L.LI with 46-bit immediate.
  zl64_li LI64_LI, A0, 0x123456789ab
  check a0, 0x123456789ab
  zl64_li LI64_LI, A0, -0x123456789ab
  check a0, -0x123456789ab
  zl64_li LI64_LI, A0, 0x1fffffffffff
  check a0, 0x1fffffffffff
  zl64_li LI64_LI, A0, -0x200000000000
  check a0, -0x200000000000
  zl64_li LI64_LI, ZERO, 0x123456789ab
  check zero, 0

  // 64-bit L.AIPC: a0 = pc + imm46.
  zl64_li LI64_AIPC, A0, 0x12345678
  auipc t1, 0
  li t2, 0x12345678 - 8
  add t1, t1, t2
  bne a0, t1, fail
  zl64_li LI64_AIPC, A0, -0x100
  auipc t1, 0
  addi t1, t1, -0x100 - 8
  bne a0, t1, fail
#else
  // LI64 is reserved on RV32 and raises an illegal-instruction exception.
  csrr t4, mtvec
  la t0, illegal_li64
  csrw mtvec, t0
1:
  zl64_li LI64_LI, A0, 0x12345678
  j fail
.p2align 6
illegal_li64:
  csrw mtvec, t4
  csrr t0, mcause
  check t0, 2
  csrr t0, mepc
  la t1, 1b
  bne t0, t1, fail
#endif

  // L.ADDI/L.XORI/L.ORI/L.ANDI with 26-bit immediates.
  li a1, 0x1000
  zl_opimm ADDI, A0, A1, 0x1234567
  check a0, 0x1235567
  zl_opimm ADDI, A0, A1, -0x2000000
  check a0, 0x1000 - 0x2000000
  li a1, 0x0ff00ff0
  zl_opimm XORI, A0, A1, 0x1ffffff
  check a0, 0x0ff00ff0 ^ 0x1ffffff
  zl_opimm ORI, A0, A1, 0x1000001
  check a0, 0x0ff00ff0 | 0x1000001
  zl_opimm ANDI, A0, A1, -0x100000
  check a0, 0x0ff00000

zl_test_end
