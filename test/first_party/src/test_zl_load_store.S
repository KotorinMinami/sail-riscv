// Zl LOAD/STORE relative to a base register and LS-PC (PC-relative) loads and stores.

#include "common/zl.h"

zl_test_begin

  // L.SW/L.LW with offsets beyond 12 bits.
  la t0, data
  li t1, 0x100000
  add t1, t0, t1
  li a0, 0x80000001
  zl_store STORE_W, A0, T1, -0x100000 + 4
  zl_load LOAD_W, A1, T0, 4
  check a1, -0x7fffffff
#if __riscv_xlen == 64
  zl_load LOAD_WU, A1, T0, 4
  check a1, 0x80000001
  li a0, 0x0123456789abcdef
  zl_store STORE_D, A0, T1, -0x100000 + 8
  zl_load LOAD_D, A1, T0, 8
  check a1, 0x0123456789abcdef
#endif

  // PC-relative loads and stores. The assembler can only compute the offsets
  // if the data and the accesses are in the same fragment, i.e. no branches
  // in between, so all checks come afterwards.
  j 1f
.balign 8
pc_data:
  .4byte 0x80000001
  .4byte 0x13579bdf
1:
  zl_lspc 0, LOAD_W, A0, pc_data
  li a1, 0x2468ace0
  zl_lspc 1, STORE_W, A1, pc_data
  zl_lspc 0, LOAD_W, A2, pc_data
#if __riscv_xlen == 64
  zl_lspc 0, LOAD_WU, T0, pc_data + 4
  zl_lspc 0, LOAD_D, T1, pc_data
#endif
  check a0, -0x7fffffff
  check a2, 0x2468ace0
#if __riscv_xlen == 64
  check t0, 0x13579bdf
  check t1, 0x13579bdf2468ace0
#endif

zl_test_end

.data
.balign 8
data:
  .8byte 0
  .8byte 0
