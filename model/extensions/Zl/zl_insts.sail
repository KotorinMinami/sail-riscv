// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// 48-bit Zl long instructions, following the riscv-long-instruction draft
// (https://github.com/riscv/riscv-long-instruction). Opcode assignments are
// tentative in the draft and may change.
// This module deliberately does not add any clauses to the 32-bit encdec mapping.
//
// Major opcodes are selected by inst[6:5] and inst[33:32]:
//   00: LI / OP-IMM / reserved
//   01: LOAD / STORE / LS-PC
//   10: custom
//   11: JUMP / BRANCH / BRANCH-IMM
// In all formats the sign bit of the immediate (or branch offset) is inst[31].

// LI (L3U-type): f2 = inst[35:34] selects L.LI (00), L.LUI (01), L.AIPC (10)
// and L.AUIPC (11).
union clause instruction = L_LI : (bits(32), regidx)
union clause instruction = L_LUI : (bits(32), regidx)
union clause instruction = L_AIPC : (bits(32), regidx)
union clause instruction = L_AUIPC : (bits(32), regidx)

mapping clause encdec_long48 = L_LI(imm, rd)
  <-> imm[11..0] @ 0b00 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl)
mapping clause encdec_long48 = L_LUI(imm, rd)
  <-> imm[11..0] @ 0b01 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl) & xlen == 64
mapping clause encdec_long48 = L_AIPC(imm, rd)
  <-> imm[11..0] @ 0b10 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl)
mapping clause encdec_long48 = L_AUIPC(imm, rd)
  <-> imm[11..0] @ 0b11 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl) & xlen == 64

function clause execute L_LI(imm, rd) = {
  X(rd) = sign_extend(imm);
  RETIRE_SUCCESS
}
function clause execute L_LUI(imm, rd) = {
  assert(xlen == 64);
  X(rd) = imm @ X(rd)[31..0];
  RETIRE_SUCCESS
}

mapping clause assembly = L_LI(imm, rd)
  <-> "l.li" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)
function clause execute L_AIPC(imm, rd) = {
  X(rd) = PC + sign_extend(imm);
  RETIRE_SUCCESS
}
// Despite its name, L.AUIPC does not read the PC: it adds imm << 32 to rd.
function clause execute L_AUIPC(imm, rd) = {
  assert(xlen == 64);
  X(rd) = X(rd) + (imm @ sail_zeros(32));
  RETIRE_SUCCESS
}

mapping clause assembly = L_LUI(imm, rd)
  <-> "l.lui" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)
mapping clause assembly = L_AIPC(imm, rd)
  <-> "l.aipc" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)
mapping clause assembly = L_AUIPC(imm, rd)
  <-> "l.auipc" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)

// OP-IMM (L3I-type): L.ADDI, L.XORI, L.ORI and L.ANDI, funct3 as in OP-IMM.
union clause instruction = L_ITYPE : (bits(26), regidx, regidx, iop)

mapping clause encdec_long48 = L_ITYPE(imm, rs1, rd, op)
  <-> imm[24..11] @ 0b01 @ imm[25] @ imm[10..0] @ encdec_reg(rs1) @ encdec_iop(op) @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl) & op != SLTI & op != SLTIU

function clause execute L_ITYPE(imm, rs1, rd, op) = {
  let immext : xlenbits = sign_extend(imm);
  X(rd) = match op {
    ADDI => X(rs1) + immext,
    XORI => X(rs1) ^ immext,
    ORI  => X(rs1) | immext,
    ANDI => X(rs1) & immext,
    _    => internal_error(__FILE__, __LINE__, "L.SLTI/L.SLTIU are not encodable"),
  };
  RETIRE_SUCCESS
}

mapping clause assembly = L_ITYPE(imm, rs1, rd, op)
  <-> "l." ^ itype_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_26(imm)

// pc + offset, with pointer masking applied as for any explicit data access.
private function zl_pcrel_addr(offset : xlenbits, access_info : AccessInfo) -> virtaddr =
  transform_effective_address(Virtaddr(PC + offset), access_info)

private function zl_bop_taken forall 'n, 'n > 0. (op : bop, a : bits('n), b : bits('n)) -> bool =
  match op {
    BEQ  => a == b,
    BNE  => a != b,
    BLT  => a <_s b,
    BGE  => a >=_s b,
    BLTU => a <_u b,
    BGEU => a >=_u b,
  }

private function zl_branch(taken : bool, off : bits(21)) -> ExecutionResult =
  if taken then jump_to(PC + sign_extend(off)) else RETIRE_SUCCESS

// Branch if taken and write rd, unless the jump traps.
private function zl_branch_write(taken : bool, off : bits(21), rd : regidx, value : xlenbits) -> ExecutionResult = {
  if taken then {
    match jump_to(PC + sign_extend(off)) {
      Retire_Success() => (),
      failure => return failure,
    }
  };
  X(rd) = value;
  RETIRE_SUCCESS
}

union clause instruction = L_JAL : (bits(32), regidx)
union clause instruction = L_JALR : (bits(23), regidx, regidx)
union clause instruction = L_BRANCH : (bits(21), regidx, regidx, bop)

// JUMP: f3 = inst[47:45] selects L.JAL (000, L3J-type), L.JALR (001) and
// L.JALT (010, L3JT-type).
mapping clause encdec_long48 = L_JAL(imm @ 0b0, rd)
  <-> 0b000 @ imm[29..19] @ 0b00 @ imm[30] @ imm[9..0] @ imm[10] @ imm[18..11] @ encdec_reg(rd) @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)
mapping clause encdec_long48 = L_JALR(imm, rs1, rd)
  <-> 0b001 @ imm[21..11] @ 0b00 @ imm[22] @ imm[10..0] @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)
// BRANCH (L3B-type): funct6 = inst[39:34] = 000000 selects the register-register compares.
mapping clause encdec_long48 = L_BRANCH(imm @ 0b0, rs2, rs1, op)
  <-> imm[18..11] @ 0b000000 @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_bop(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L_JAL(imm, rd) = {
  let offset : xlenbits = sign_extend(imm);
  let link = get_next_pc();
  match jump_to(PC + offset) {
    Retire_Success() => { X(rd) = link; RETIRE_SUCCESS },
    failure => failure,
  }
}
function clause execute L_JALR(imm, rs1, rd) = {
  update_elp_state(rs1);
  let link = get_next_pc();
  let target = X(rs1) + sign_extend(imm);
  match jump_to([target with 0 = 0b0]) {
    Retire_Success() => { X(rd) = link; RETIRE_SUCCESS },
    failure => failure,
  }
}

function clause execute L_BRANCH(imm, rs2, rs1, op) =
  zl_branch(zl_bop_taken(op, X(rs1), X(rs2)), imm)

mapping clause assembly = L_JAL(imm, rd)
  <-> "l.jal" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_32(imm)
mapping clause assembly = L_JALR(imm, rs1, rd)
  <-> "l.jalr" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_23(imm) ^ "(" ^ reg_name(rs1) ^ ")"

// L.JALT calls through a table of XLEN-bit pointers: the target is read from
// pc + (sext(off) + rs1) * XLEN/8, i.e. off and rs1 count table entries. The
// table entry is read like a data load (the draft expects cores to crack the
// instruction into a load and an indirect jump), and with Zicfilp the target
// needs a landing pad.
union clause instruction = L_JALT : (bits(26), regidx, regidx)

mapping clause encdec_long48 = L_JALT(off, rs1, rd)
  <-> 0b010 @ off[24..14] @ 0b00 @ off[25] @ off[13..3] @ encdec_reg(rs1) @ off[2..0] @ encdec_reg(rd) @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L_JALT(off, rs1, rd) = {
  let index : xlenbits = sign_extend(off) + X(rs1);
  let entry_offset : xlenbits = if xlen == 32 then index << 2 else index << 3;
  let access : MemoryAccessType(mem_payload) = Load(Data);
  let access_info = default_access_info(access);
  match vmem_read_addr(zl_pcrel_addr(entry_offset, access_info), xlen_bytes, access, access_info, false, false, false) {
    Ok(target) => {
      set_elp_expected();
      let link = get_next_pc();
      match jump_to([target with 0 = 0b0]) {
        Retire_Success() => { X(rd) = link; RETIRE_SUCCESS },
        failure => failure,
      }
    },
    Err(e) => e,
  }
}

mapping clause assembly = L_JALT(off, rs1, rd)
  <-> "l.jalt" ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_26(off)
mapping clause assembly = L_BRANCH(imm, rs2, rs1, op)
  <-> "l." ^ btype_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)

// All BRANCH instructions use the L3B offset layout and are told apart by
// funct6 = inst[39:34]; funct6[5] = 1 selects the overflow branches.
union clause instruction = L_BRANCHW : (bits(21), regidx, regidx, bop)
union clause instruction = L_BCALL : (bits(21), regidx, regidx, bop)

// funct6 000001: compare bits 31:0 only (RV64).
mapping clause encdec_long48 = L_BRANCHW(imm @ 0b0, rs2, rs1, op)
  <-> imm[18..11] @ 0b000001 @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_bop(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl) & xlen == 64
// funct6 000100: write pc + 6 to ra whether or not the branch is taken.
mapping clause encdec_long48 = L_BCALL(imm @ 0b0, rs2, rs1, op)
  <-> imm[18..11] @ 0b000100 @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_bop(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L_BRANCHW(imm, rs2, rs1, op) =
  zl_branch(zl_bop_taken(op, X(rs1)[31..0], X(rs2)[31..0]), imm)

function clause execute L_BCALL(imm, rs2, rs1, op) =
  zl_branch_write(zl_bop_taken(op, X(rs1), X(rs2)), imm, ra, get_next_pc())

mapping zl_bcall_cond : bop <-> string = {
  BEQ  <-> "eq",
  BNE  <-> "ne",
  BLT  <-> "lt",
  BGE  <-> "ge",
  BLTU <-> "ltu",
  BGEU <-> "geu",
}

mapping clause assembly = L_BRANCHW(imm, rs2, rs1, op)
  <-> "l." ^ btype_mnemonic(op) ^ "w" ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)
mapping clause assembly = L_BCALL(imm, rs2, rs1, op)
  <-> "l.bcall." ^ zl_bcall_cond(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)

// funct6 000010: bit and mask tests.
union clause instruction = L_BTEST : (bits(21), regidx, regidx, zl_btest)

mapping encdec_zl_btest : zl_btest <-> bits(3) = {
  ZL_BTNONE <-> 0b000,
  ZL_BTANY  <-> 0b001,
  ZL_BTALL  <-> 0b010,
  ZL_BTNALL <-> 0b011,
  ZL_BBCR   <-> 0b100,
  ZL_BBSR   <-> 0b101,
}

mapping clause encdec_long48 = L_BTEST(imm @ 0b0, rs2, rs1, op)
  <-> imm[18..11] @ 0b000010 @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_zl_btest(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L_BTEST(imm, rs2, rs1, op) = {
  let a = X(rs1);
  let b = X(rs2);
  let bit : xlenbits = if xlen == 32
                       then zero_extend(0b1) << b[4..0]
                       else zero_extend(0b1) << b[5..0];
  let taken : bool = match op {
    ZL_BTNONE => (a & b) == zeros(),
    ZL_BTANY  => (a & b) != zeros(),
    ZL_BTALL  => (a & b) == b,
    ZL_BTNALL => (a & b) != b,
    ZL_BBCR   => (a & bit) == zeros(),
    ZL_BBSR   => (a & bit) != zeros(),
  };
  zl_branch(taken, imm)
}

mapping zl_btest_mnemonic : zl_btest <-> string = {
  ZL_BTNONE <-> "btnone",
  ZL_BTANY  <-> "btany",
  ZL_BTALL  <-> "btall",
  ZL_BTNALL <-> "btnall",
  ZL_BBCR   <-> "bbcr",
  ZL_BBSR   <-> "bbsr",
}

mapping clause assembly = L_BTEST(imm, rs2, rs1, op)
  <-> "l." ^ zl_btest_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)

// funct6 000011: search rs1 for a byte or halfword equal to the low bits of rs2.
union clause instruction = L_BELEM : (bits(21), regidx, regidx, zl_belem)

mapping encdec_zl_belem : zl_belem <-> bits(3) = {
  ZL_BEQB <-> 0b000,
  ZL_BNEB <-> 0b001,
  ZL_BEQH <-> 0b010,
  ZL_BNEH <-> 0b011,
}

mapping clause encdec_long48 = L_BELEM(imm @ 0b0, rs2, rs1, op)
  <-> imm[18..11] @ 0b000011 @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_zl_belem(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

// Whether any naturally aligned element of v equals e.
private function zl_any_elem_eq forall 'w, 'w in {8, 16}. (v : xlenbits, e : bits('w)) -> bool = {
  var found : bool = false;
  foreach (i from 0 to (xlen - length(e)) by length(e)) {
    if truncate(v >> i, length(e)) == e then found = true;
  };
  found
}

function clause execute L_BELEM(imm, rs2, rs1, op) = {
  let a = X(rs1);
  let b = X(rs2);
  let taken : bool = match op {
    ZL_BEQB => zl_any_elem_eq(a, b[7..0]),
    ZL_BNEB => not(zl_any_elem_eq(a, b[7..0])),
    ZL_BEQH => zl_any_elem_eq(a, b[15..0]),
    ZL_BNEH => not(zl_any_elem_eq(a, b[15..0])),
  };
  zl_branch(taken, imm)
}

mapping zl_belem_mnemonic : zl_belem <-> string = {
  ZL_BEQB <-> "beqb",
  ZL_BNEB <-> "bneb",
  ZL_BEQH <-> "beqh",
  ZL_BNEH <-> "bneh",
}

mapping clause assembly = L_BELEM(imm, rs2, rs1, op)
  <-> "l." ^ zl_belem_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)

// funct6 00011 @ idx[5] (L3BX-type): funct3 000 L.BBC, 001 L.BBS.
union clause instruction = L_BBIT : (bits(21), bits(6), regidx, bool)

mapping clause encdec_long48 = L_BBIT(imm @ 0b0, idx, rs1, set)
  <-> imm[18..11] @ 0b00011 @ idx[5] @ 0b01 @ imm[19] @ imm[9..4] @ idx[4..0] @ encdec_reg(rs1) @ 0b00 @ bool_bit(set) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl) & (xlen == 64 | idx[5] == 0b0)

function clause execute L_BBIT(imm, idx, rs1, set) = {
  let bit : xlenbits = if xlen == 32
                       then zero_extend(0b1) << idx[4..0]
                       else zero_extend(0b1) << idx;
  zl_branch(((X(rs1) & bit) != zeros()) == set, imm)
}

mapping zl_bbit_mnemonic : bool <-> string = {
  false <-> "bbc",
  true  <-> "bbs",
}

mapping clause assembly = L_BBIT(imm, idx, rs1, set)
  <-> "l." ^ zl_bbit_mnemonic(set) ^ spc() ^ reg_name(rs1) ^ sep() ^ hex_bits_6(idx) ^ sep() ^ hex_bits_signed_21(imm)

// funct6[5] = 1 (L3BA-type): write the result to rd (in funct6[4:0]) and branch on overflow.
union clause instruction = L_BOVF : (bits(21), regidx, regidx, regidx, zl_bovf)

mapping encdec_zl_bovf : zl_bovf <-> bits(3) = {
  ZL_ADDBO  <-> 0b000,
  ZL_SUBBO  <-> 0b001,
  ZL_ADDBOU <-> 0b010,
  ZL_SUBBOU <-> 0b011,
  ZL_ADDWBO <-> 0b100,
  ZL_SUBWBO <-> 0b101,
  ZL_MULBO  <-> 0b110,
}

private function zl_bovf_supported(op : zl_bovf) -> bool =
  match op {
    ZL_ADDWBO => xlen == 64,
    ZL_SUBWBO => xlen == 64,
    ZL_MULBO  => (config extensions.Zl.mulbo : bool) & currentlyEnabled(Ext_Zmmul),
    _         => true,
  }

mapping clause encdec_long48 = L_BOVF(imm @ 0b0, rs2, rs1, rd, op)
  <-> imm[18..11] @ 0b1 @ encdec_reg(rd) @ 0b01 @ imm[19] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_zl_bovf(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl) & zl_bovf_supported(op)

// Truncate s to n bits; the flag is set if s does not fit as a signed/unsigned value.
private function zl_wrap_signed forall 'n, 'n > 0. (n : int('n), s : int) -> (bits('n), bool) = {
  let r : bits('n) = to_bits_truncate(n, s);
  (r, signed(r) != s)
}
private function zl_wrap_unsigned forall 'n, 'n > 0. (n : int('n), s : int) -> (bits('n), bool) = {
  let r : bits('n) = to_bits_truncate(n, s);
  (r, unsigned(r) != s)
}

function clause execute L_BOVF(imm, rs2, rs1, rd, op) = {
  let a = X(rs1);
  let b = X(rs2);
  let (result, overflow) : (xlenbits, bool) = match op {
    ZL_ADDBO  => zl_wrap_signed(xlen, signed(a) + signed(b)),
    ZL_SUBBO  => zl_wrap_signed(xlen, signed(a) - signed(b)),
    ZL_ADDBOU => zl_wrap_unsigned(xlen, unsigned(a) + unsigned(b)),
    ZL_SUBBOU => zl_wrap_unsigned(xlen, unsigned(a) - unsigned(b)),
    ZL_ADDWBO => {
      let (r, o) = zl_wrap_signed(32, signed(a[31..0]) + signed(b[31..0]));
      (sign_extend(r), o)
    },
    ZL_SUBWBO => {
      let (r, o) = zl_wrap_signed(32, signed(a[31..0]) - signed(b[31..0]));
      (sign_extend(r), o)
    },
    ZL_MULBO  => zl_wrap_signed(xlen, signed(a) * signed(b)),
  };
  zl_branch_write(overflow, imm, rd, result)
}

mapping zl_bovf_mnemonic : zl_bovf <-> string = {
  ZL_ADDBO  <-> "addbo",
  ZL_SUBBO  <-> "subbo",
  ZL_ADDBOU <-> "addbou",
  ZL_SUBBOU <-> "subbou",
  ZL_ADDWBO <-> "addwbo",
  ZL_SUBWBO <-> "subwbo",
  ZL_MULBO  <-> "mulbo",
}

mapping clause assembly = L_BOVF(imm, rs2, rs1, rd, op)
  <-> "l." ^ zl_bovf_mnemonic(op) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_21(imm)

// BRANCH-IMM (L3BI-type). The 11-bit immediate is sign-extended from its own
// top bit (inst[30]); inst[31] is the sign of the branch offset.
union clause instruction = L_BRANCH_IMM : (bits(21), bits(11), regidx, zl_bimm)

mapping encdec_zl_bimm : zl_bimm <-> bits(3) = {
  ZL_BEQI    <-> 0b000,
  ZL_BNEI    <-> 0b001,
  ZL_BTNONEI <-> 0b010,
  ZL_BTANYI  <-> 0b011,
  ZL_BLTI    <-> 0b100,
  ZL_BGEI    <-> 0b101,
  ZL_BLTUI   <-> 0b110,
  ZL_BGEUI   <-> 0b111,
}

mapping clause encdec_long48 = L_BRANCH_IMM(off @ 0b0, imm, rs1, op)
  <-> off[18..11] @ off[9..4] @ 0b10 @ off[19] @ imm @ encdec_reg(rs1) @ encdec_zl_bimm(op) @ off[3..0] @ off[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L_BRANCH_IMM(off, imm, rs1, op) = {
  let a = X(rs1);
  let b : xlenbits = sign_extend(imm);
  let taken : bool = match op {
    ZL_BEQI    => a == b,
    ZL_BNEI    => a != b,
    ZL_BTNONEI => (a & b) == zeros(),
    ZL_BTANYI  => (a & b) != zeros(),
    ZL_BLTI    => a <_s b,
    ZL_BGEI    => a >=_s b,
    ZL_BLTUI   => a <_u b,
    ZL_BGEUI   => a >=_u b,
  };
  zl_branch(taken, off)
}

mapping zl_bimm_mnemonic : zl_bimm <-> string = {
  ZL_BEQI    <-> "beqi",
  ZL_BNEI    <-> "bnei",
  ZL_BTNONEI <-> "btnonei",
  ZL_BTANYI  <-> "btanyi",
  ZL_BLTI    <-> "blti",
  ZL_BGEI    <-> "bgei",
  ZL_BLTUI   <-> "bltui",
  ZL_BGEUI   <-> "bgeui",
}

mapping clause assembly = L_BRANCH_IMM(off, imm, rs1, op)
  <-> "l." ^ zl_bimm_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_11(imm) ^ sep() ^ hex_bits_signed_21(off)

union clause instruction = L_LOAD : (bits(26), regidx, regidx, bool, word_width)
union clause instruction = L_STORE : (bits(26), regidx, regidx, word_width)

// LOAD (L3I-type) and STORE (L3S-type), funct3 as in the 32-bit LOAD/STORE.
mapping clause encdec_long48 = L_LOAD(imm, rs1, rd, is_unsigned, width)
  <-> imm[24..11] @ 0b00 @ imm[25] @ imm[10..0] @ encdec_reg(rs1) @ bool_bit(is_unsigned) @ width_enc(width) @ encdec_reg(rd) @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Zl) & valid_load_encdec(width, is_unsigned)
mapping clause encdec_long48 = L_STORE(imm, rs2, rs1, width)
  <-> imm[24..11] @ 0b01 @ imm[25] @ imm[10..5] @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b0 @ width_enc(width) @ imm[4..0] @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Zl) & width <= xlen_bytes

function clause execute L_LOAD(imm, rs1, rd, is_unsigned, width) = {
  assert(width <= xlen_bytes);
  let offset : xlenbits = sign_extend(imm);
  match vmem_read(rs1, offset, width, Load(Data), false, false, false) {
    Ok(data) => { X(rd) = extend_value(is_unsigned, data); RETIRE_SUCCESS },
    Err(e) => e,
  }
}
function clause execute L_STORE(imm, rs2, rs1, width) = {
  assert(width <= xlen_bytes);
  let offset : xlenbits = sign_extend(imm);
  let data = X(rs2)[width * 8 - 1..0];
  match vmem_write(rs1, offset, width, data, Store(Data), false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  }
}

mapping clause assembly = L_LOAD(imm, rs1, rd, is_unsigned, width)
  <-> "l.l" ^ width_mnemonic(width) ^ maybe_u(is_unsigned) ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_26(imm) ^ "(" ^ reg_name(rs1) ^ ")"
mapping clause assembly = L_STORE(imm, rs2, rs1, width)
  <-> "l.s" ^ width_mnemonic(width) ^ spc() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_26(imm) ^ "(" ^ reg_name(rs1) ^ ")"

// LS-PC (L3P-type): access pc + sext(off). S = inst[15] selects a load into rd
// (funct3 as in LOAD) or a store of rs2 in the rd field (funct3 as in STORE).
union clause instruction = L_LOAD_PC : (bits(30), regidx, bool, word_width)
union clause instruction = L_STORE_PC : (bits(30), regidx, word_width)

mapping clause encdec_long48 = L_LOAD_PC(off, rd, is_unsigned, width)
  <-> off[28..15] @ 0b10 @ off[29] @ off[14..0] @ 0b0 @ bool_bit(is_unsigned) @ width_enc(width) @ encdec_reg(rd) @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Zl) & valid_load_encdec(width, is_unsigned)
mapping clause encdec_long48 = L_STORE_PC(off, rs2, width)
  <-> off[28..15] @ 0b10 @ off[29] @ off[14..0] @ 0b1 @ 0b0 @ width_enc(width) @ encdec_reg(rs2) @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Zl) & width <= xlen_bytes

function clause execute L_LOAD_PC(off, rd, is_unsigned, width) = {
  assert(width <= xlen_bytes);
  let access : MemoryAccessType(mem_payload) = Load(Data);
  let access_info = default_access_info(access);
  match vmem_read_addr(zl_pcrel_addr(sign_extend(off), access_info), width, access, access_info, false, false, false) {
    Ok(data) => { X(rd) = extend_value(is_unsigned, data); RETIRE_SUCCESS },
    Err(e) => e,
  }
}
function clause execute L_STORE_PC(off, rs2, width) = {
  assert(width <= xlen_bytes);
  let access : MemoryAccessType(mem_payload) = Store(Data);
  let access_info = default_access_info(access);
  let data = X(rs2)[width * 8 - 1..0];
  match vmem_write_addr(zl_pcrel_addr(sign_extend(off), access_info), width, data, access, access_info, false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  }
}

mapping clause assembly = L_LOAD_PC(off, rd, is_unsigned, width)
  <-> "l.l" ^ width_mnemonic(width) ^ maybe_u(is_unsigned) ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_30(off)
mapping clause assembly = L_STORE_PC(off, rs2, width)
  <-> "l.s" ^ width_mnemonic(width) ^ spc() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_30(off)

// =======================================================================================
// 64-bit Zl instructions
// =======================================================================================

// LI64 (L4U-type): 46-bit immediate with sign bit at inst[31] (imm[45]).
// f1 = inst[37] selects L.LI (0) and L.AIPC (1). Reserved on RV32 per draft.
union clause instruction = L64_LI : (bits(46), regidx)
union clause instruction = L64_AIPC : (bits(46), regidx)

mapping clause encdec_long64 = L64_LI(imm, rd)
  <-> imm[44..31] @ imm[11..0] @ 0b0 @ 0b000 @ 0b11 @ imm[45] @ imm[30..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl) & xlen == 64
mapping clause encdec_long64 = L64_AIPC(imm, rd)
  <-> imm[44..31] @ imm[11..0] @ 0b1 @ 0b000 @ 0b11 @ imm[45] @ imm[30..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Zl) & xlen == 64

function clause execute L64_LI(imm, rd) = {
  assert(xlen == 64);
  X(rd) = sign_extend(imm);
  RETIRE_SUCCESS
}
function clause execute L64_AIPC(imm, rd) = {
  assert(xlen == 64);
  X(rd) = PC + sign_extend(imm);
  RETIRE_SUCCESS
}

mapping clause assembly = L64_LI(imm, rd)
  <-> "l.li" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_46(imm)
mapping clause assembly = L64_AIPC(imm, rd)
  <-> "l.aipc" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_46(imm)

// JUMP64 (L4J-type): 48-bit offset with sign bit at inst[31] (off[47]), off[0] = 0.
union clause instruction = L64_JAL : (bits(48), regidx)

mapping clause encdec_long64 = L64_JAL(imm @ 0b0, rd)
  <-> imm[45..19] @ 0b000 @ 0b11 @ imm[46] @ imm[9..0] @ imm[10] @ imm[18..11] @ encdec_reg(rd) @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L64_JAL(imm, rd) = {
  let offset : xlenbits = if xlen == 32 then imm[31..0] else sign_extend(imm);
  let link = get_next_pc();
  match jump_to(PC + offset) {
    Retire_Success() => { X(rd) = link; RETIRE_SUCCESS },
    failure => failure,
  }
}

mapping clause assembly = L64_JAL(imm, rd)
  <-> "l.jal" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_48(imm)

// BRANCH-IMM64 (L4BI-type): 24-bit immediate, 21-bit offset with sign bit at inst[31] (off[20]).
union clause instruction = L64_BRANCH_IMM : (bits(21), bits(24), regidx, zl_bimm)

mapping clause encdec_long64 = L64_BRANCH_IMM(off @ 0b0, imm, rs1, op)
  <-> imm[23..11] @ off[18..11] @ off[9..4] @ 0b001 @ 0b11 @ off[19] @ imm[10..0] @ encdec_reg(rs1) @ encdec_zl_bimm(op) @ off[3..0] @ off[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Zl)

function clause execute L64_BRANCH_IMM(off, imm, rs1, op) = {
  let a = X(rs1);
  let b : xlenbits = sign_extend(imm);
  let taken : bool = match op {
    ZL_BEQI    => a == b,
    ZL_BNEI    => a != b,
    ZL_BTNONEI => (a & b) == zeros(),
    ZL_BTANYI  => (a & b) != zeros(),
    ZL_BLTI    => a <_s b,
    ZL_BGEI    => a >=_s b,
    ZL_BLTUI   => a <_u b,
    ZL_BGEUI   => a >=_u b,
  };
  zl_branch(taken, off)
}

mapping clause assembly = L64_BRANCH_IMM(off, imm, rs1, op)
  <-> "l." ^ zl_bimm_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ hex_bits_signed_24(imm) ^ sep() ^ hex_bits_signed_21(off)
