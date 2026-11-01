// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// Local experimental 48-bit encodings; not a ratified RISC-V extension.
// This module deliberately does not add any clauses to the 32-bit encdec mapping.

union clause instruction = L_LI : (bits(32), regidx)
union clause instruction = L_LUI : (bits(32), regidx)

mapping clause encdec_long48 = L_LI(imm, rd)
  <-> imm[11..0] @ 0b00 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Xlong48)
mapping clause encdec_long48 = L_LUI(imm, rd)
  <-> imm[11..0] @ 0b01 @ 0b00 @ imm[31..12] @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Xlong48) & xlen == 64

function clause execute L_LI(imm, rd) = {
  X(rd) = zero_extend(imm);
  RETIRE_SUCCESS
}
function clause execute L_LUI(imm, rd) = {
  assert(xlen == 64);
  X(rd) = imm @ X(rd)[31..0];
  RETIRE_SUCCESS
}

mapping clause assembly = L_LI(imm, rd)
  <-> "l.li" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)
mapping clause assembly = L_LUI(imm, rd)
  <-> "l.lui" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_32(imm)

union clause instruction = L_JAL : (bits(35), regidx)
union clause instruction = L_JALR : (bits(26), regidx, regidx)
union clause instruction = L_BRANCH : (bits(27), regidx, regidx, bop)

// Follow the generic LJ/LB format: inst[31] is the *top* immediate bit.
mapping clause encdec_long48 = L_JAL(imm @ 0b0, rd)
  <-> imm[32..19] @ 0b00 @ imm[33] @ imm[9..0] @ imm[10] @ imm[18..11] @ encdec_reg(rd) @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Xlong48)
mapping clause encdec_long48 = L_JALR(imm, rs1, rd)
  <-> imm[25..12] @ 0b00 @ imm[11..0] @ encdec_reg(rs1) @ 0b000 @ encdec_reg(rd) @ 0b10 @ 0b11111
  when currentlyEnabled(Ext_Xlong48)
mapping clause encdec_long48 = L_BRANCH(imm @ 0b0, rs2, rs1, op)
  <-> imm[24..11] @ 0b00 @ imm[25] @ imm[9..4] @ encdec_reg(rs2) @ encdec_reg(rs1) @ encdec_bop(op) @ imm[3..0] @ imm[10] @ 0b11 @ 0b11111
  when currentlyEnabled(Ext_Xlong48)

function clause execute L_JAL(imm, rd) = {
  let offset : xlenbits = if xlen == 32 then imm[31..0] else sign_extend(imm);
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

$[split op]
function clause execute L_BRANCH(imm, rs2, rs1, op) = {
  let taken : bool = match op {
    BEQ => X(rs1) == X(rs2),
    BNE => X(rs1) != X(rs2),
    BLT => X(rs1) <_s X(rs2),
    BGE => X(rs1) >=_s X(rs2),
    BLTU => X(rs1) <_u X(rs2),
    BGEU => X(rs1) >=_u X(rs2),
  };
  if taken then jump_to(PC + sign_extend(imm)) else RETIRE_SUCCESS
}

mapping clause assembly = L_JAL(imm, rd)
  <-> "l.jal" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_35(imm)
mapping clause assembly = L_JALR(imm, rs1, rd)
  <-> "l.jalr" ^ spc() ^ reg_name(rd) ^ sep() ^ hex_bits_signed_26(imm) ^ "(" ^ reg_name(rs1) ^ ")"
mapping clause assembly = L_BRANCH(imm, rs2, rs1, op)
  <-> "l." ^ btype_mnemonic(op) ^ spc() ^ reg_name(rs1) ^ sep() ^ reg_name(rs2) ^ sep() ^ hex_bits_signed_27(imm)

union clause instruction = L_LOAD : (bits(26), regidx, regidx, bool, word_width)
union clause instruction = L_STORE : (bits(26), regidx, regidx, word_width)

mapping clause encdec_long48 = L_LOAD(imm, rs1, rd, is_unsigned, width)
  <-> imm[25..12] @ 0b01 @ imm[11..0] @ encdec_reg(rs1) @ bool_bit(is_unsigned) @ width_enc(width) @ encdec_reg(rd) @ 0b00 @ 0b11111
  when currentlyEnabled(Ext_Xlong48) & valid_load_encdec(width, is_unsigned)
mapping clause encdec_long48 = L_STORE(imm, rs2, rs1, width)
  <-> imm[25..12] @ 0b01 @ imm[11..5] @ encdec_reg(rs2) @ encdec_reg(rs1) @ 0b0 @ width_enc(width) @ imm[4..0] @ 0b01 @ 0b11111
  when currentlyEnabled(Ext_Xlong48) & width <= xlen_bytes

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
