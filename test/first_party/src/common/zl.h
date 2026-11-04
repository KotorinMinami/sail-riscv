// Helpers for the Zl long instruction tests. Assemblers do not know the Zl
// instructions yet, so the macros below emit them as raw parcels following the
// riscv-long-instruction draft formats.

#ifndef ZL_H
#define ZL_H

#define ZERO 0
#define RA 1
#define T0 5
#define T1 6
#define A0 10
#define A1 11
#define A2 12

#define F3_BEQ 0
#define F3_BNE 1
#define F3_BLT 4
#define F3_BGE 5
#define F3_BLTU 6
#define F3_BGEU 7

#define F6_BCC 0
#define F6_BCCW 1
#define F6_BTEST 2
#define F6_BELEM 3
#define F6_BCALL 4

#define BTNONE 0
#define BTANY 1
#define BTALL 2
#define BTNALL 3
#define BBCR 4
#define BBSR 5

#define BEQB 0
#define BNEB 1
#define BEQH 2
#define BNEH 3

#define ADDBO 0
#define SUBBO 1
#define ADDBOU 2
#define SUBBOU 3
#define ADDWBO 4
#define SUBWBO 5
#define MULBO 6

#define BEQI 0
#define BNEI 1
#define BTNONEI 2
#define BTANYI 3
#define BLTI 4
#define BGEI 5
#define BLTUI 6
#define BGEUI 7

#define LI_LI 0
#define LI_LUI 1
#define LI_AIPC 2
#define LI_AUIPC 3

#define LI64_LI 0
#define LI64_AIPC 1

#define ADDI 0
#define XORI 4
#define ORI 6
#define ANDI 7

#define LOAD_W 2
#define LOAD_D 3
#define LOAD_WU 6
#define STORE_W 2
#define STORE_D 3

// 48-bit instruction from inst[31:0] and inst[47:32].
.macro zl48 lo, hi
  .4byte (\lo) & 0xffffffff
  .2byte (\hi) & 0xffff
.endm

// 64-bit instruction from inst[31:0] and inst[63:32].
.macro zl64 lo, hi
  .4byte (\lo) & 0xffffffff
  .4byte (\hi) & 0xffffffff
.endm

// LI (L3U-type).
.macro zl_li f2, rd, imm
  zl48 ((\imm) & 0xfffff000) | (\rd << 7) | 0x1f, \
       (((\imm) & 0xfff) << 4) | (\f2 << 2)
.endm

// LI64 (L4U-type).
.macro zl64_li f1, rd, imm
  zl64 (((((\imm) >> 45) & 1) << 31) | ((\imm) & 0x7ffff000) | (\rd << 7) | 0x1f), \
       ((((((\imm) >> 31) & 0x3fff) << 18) | (((\imm) & 0xfff) << 6) | (\f1 << 5) | 3))
.endm

// OP-IMM (op = 1) and LOAD (group = 1, op = 0), L3I-type.
.macro zl_i group, op, funct3, rd, rs1, imm
  zl48 ((((\imm) >> 25) & 1) << 31) | (((\imm) & 0x7ff) << 20) | (\rs1 << 15) | (\funct3 << 12) | (\rd << 7) | (\group << 5) | 0x1f, \
       ((((\imm) >> 11) & 0x3fff) << 2) | \op
.endm
.macro zl_opimm funct3, rd, rs1, imm
  zl_i 0, 1, \funct3, \rd, \rs1, \imm
.endm
.macro zl_load funct3, rd, rs1, imm
  zl_i 1, 0, \funct3, \rd, \rs1, \imm
.endm

// STORE (L3S-type).
.macro zl_store funct3, rs2, rs1, imm
  zl48 ((((\imm) >> 25) & 1) << 31) | ((((\imm) >> 5) & 0x3f) << 25) | (\rs2 << 20) | (\rs1 << 15) | (\funct3 << 12) | (((\imm) & 0x1f) << 7) | (1 << 5) | 0x1f, \
       ((((\imm) >> 11) & 0x3fff) << 2) | 1
.endm

// LS-PC (L3P-type) to a label in the same section.
.macro zl_lspc s, funct3, reg, target
999:
  zl48 ((((\target - 999b) >> 29) & 1) << 31) | (((\target - 999b) & 0x7fff) << 16) | (\s << 15) | (\funct3 << 12) | (\reg << 7) | (1 << 5) | 0x1f, \
       ((((\target - 999b) >> 15) & 0x3fff) << 2) | 2
.endm

// JUMP: L.JAL (L3J-type) and L.JALR.
.macro zl_jal rd, off
  zl48 ((((\off) >> 31) & 1) << 31) | ((((\off) >> 1) & 0x3ff) << 21) | ((((\off) >> 11) & 1) << 20) | ((((\off) >> 12) & 0xff) << 12) | (\rd << 7) | (3 << 5) | 0x1f, \
       ((((\off) >> 20) & 0x7ff) << 2)
.endm

// JUMP64: L.JAL (L4J-type).
.macro zl64_jal rd, off
  zl64 (((((\off) >> 47) & 1) << 31) | ((((\off) >> 1) & 0x3ff) << 21) | ((((\off) >> 11) & 1) << 20) | ((((\off) >> 12) & 0xff) << 12) | (\rd << 7) | (3 << 5) | 0x1f), \
       (((((\off) >> 20) & 0x7ffffff) << 5) | 3)
.endm
.macro zl_jalr rd, rs1, imm
  zl48 ((((\imm) >> 22) & 1) << 31) | (((\imm) & 0x7ff) << 20) | (\rs1 << 15) | (\rd << 7) | (3 << 5) | 0x1f, \
       (1 << 13) | ((((\imm) >> 11) & 0x7ff) << 2)
.endm
// L.JALT (L3JT-type); off counts table entries.
.macro zl_jalt rd, rs1, off
  zl48 ((((\off) >> 25) & 1) << 31) | ((((\off) >> 3) & 0x7ff) << 20) | (\rs1 << 15) | (((\off) & 7) << 12) | (\rd << 7) | (3 << 5) | 0x1f, \
       (2 << 13) | ((((\off) >> 14) & 0x7ff) << 2)
.endm

// BRANCH (L3B-type and its variants).
.macro zl_b funct6, funct3, rs1, rs2, off
  zl48 ((((\off) >> 20) & 1) << 31) | ((((\off) >> 5) & 0x3f) << 25) | (\rs2 << 20) | (\rs1 << 15) | (\funct3 << 12) | ((((\off) >> 1) & 0xf) << 8) | ((((\off) >> 11) & 1) << 7) | (3 << 5) | 0x1f, \
       ((((\off) >> 12) & 0xff) << 8) | (\funct6 << 2) | 1
.endm
.macro zl_bbit set, rs1, idx, off
  zl_b (6 | (((\idx) >> 5) & 1)), \set, \rs1, ((\idx) & 0x1f), \off
.endm
.macro zl_bovf op, rd, rs1, rs2, off
  zl_b (0x20 | \rd), \op, \rs1, \rs2, \off
.endm

// BRANCH-IMM (L3BI-type).
.macro zl_bi funct3, rs1, imm, off
  zl48 ((((\off) >> 20) & 1) << 31) | (((\imm) & 0x7ff) << 20) | (\rs1 << 15) | (\funct3 << 12) | ((((\off) >> 1) & 0xf) << 8) | ((((\off) >> 11) & 1) << 7) | (3 << 5) | 0x1f, \
       ((((\off) >> 12) & 0xff) << 8) | ((((\off) >> 5) & 0x3f) << 2) | 2
.endm

// The branch must be taken: it skips over `j fail` (6 + 4 bytes).
.macro taken insn:vararg
  \insn, 10
  j fail
.endm

// The branch must not be taken: if it is, it lands on `j fail`.
.macro not_taken insn:vararg
  \insn, 10
  j 1f
  j fail
1:
.endm

.macro check reg, expected
  li t3, \expected
  bne \reg, t3, fail
.endm

#if __riscv_xlen == 64
#define PTR .8byte
#define SAVE_RA sd ra, 0(sp)
#define RESTORE_RA ld ra, 0(sp)
#else
#define PTR .4byte
#define SAVE_RA sw ra, 0(sp)
#define RESTORE_RA lw ra, 0(sp)
#endif

// zl_test_begin starts main and zl_test_end returns 0 from it; `fail` returns 1.
// main saves ra because the L.JAL and L.BCALL tests overwrite it.
.macro zl_test_begin
// Keep all base instructions 4 bytes long so that the fixed branch offsets hold.
.option norvc
.global main
main:
  addi sp, sp, -16
  SAVE_RA
.endm

.macro zl_test_end
  li a0, 0
  j done
fail:
  li a0, 1
done:
  RESTORE_RA
  addi sp, sp, 16
  ret
.endm

#endif
