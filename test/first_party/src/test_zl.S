// Tests for the experimental Zl 48-bit long instructions. Assemblers do not
// know them yet, so the macros below emit them as raw parcels following the
// riscv-long-instruction draft formats.

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

// LI (L3U-type).
.macro zl_li f2, rd, imm
  zl48 ((\imm) & 0xfffff000) | (\rd << 7) | 0x1f, \
       (((\imm) & 0xfff) << 4) | (\f2 << 2)
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

// Keep all base instructions 4 bytes long so that the fixed branch offsets hold.
.option norvc

#if __riscv_xlen == 64
#define PTR .8byte
#define SAVE_RA sd ra, 0(sp)
#define RESTORE_RA ld ra, 0(sp)
#else
#define PTR .4byte
#define SAVE_RA sw ra, 0(sp)
#define RESTORE_RA lw ra, 0(sp)
#endif

.global main
main:
  // The L.JAL and L.BCALL tests overwrite ra.
  addi sp, sp, -16
  SAVE_RA

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

  li a0, 0
  j done

fail:
  li a0, 1
done:
  RESTORE_RA
  addi sp, sp, 16
  ret

.data
.balign 8
data:
  .8byte 0
  .8byte 0
