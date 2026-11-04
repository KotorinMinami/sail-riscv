// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// Put the illegal instructions last to use their wildcard match.

// *****************************************************************

mapping clause encdec = ILLEGAL(s) <-> s

function clause execute ILLEGAL(_s) = Illegal_Instruction()

mapping clause assembly = ILLEGAL(s) <-> "illegal" ^ spc() ^ hex_bits_32(s)

// *****************************************************************

mapping clause encdec_compressed = C_ILLEGAL(s) <-> s

function clause execute C_ILLEGAL(_s) = Illegal_Instruction()

mapping clause assembly = C_ILLEGAL(s) <-> "c.illegal" ^ spc() ^ hex_bits_16(s)

// *****************************************************************

mapping clause encdec_long48 = L_ILLEGAL(s) <-> s
function clause execute L_ILLEGAL(_) = Illegal_Instruction()
mapping clause assembly = L_ILLEGAL(s) <-> "l.illegal" ^ spc() ^ hex_bits_48(s)

mapping clause encdec_long64 = L_ILLEGAL64(s) <-> s
function clause execute L_ILLEGAL64(_) = Illegal_Instruction()
mapping clause assembly = L_ILLEGAL64(s) <-> "l.illegal" ^ spc() ^ hex_bits_64(s)

// End definitions
end extension
end extensionName
end hartSupports
end currentlyEnabled
end instruction
end execute
end assembly
end encdec
end encdec_compressed
end encdec_long48
end encdec_long64

// Some legal instructions do not have any corresponding assembly, e.g. reserved fences.
function instruction_to_str(insn : instruction) -> string =
  if assembly_forwards_matches(insn) then assembly(insn)
  else if encdec_long48_forwards_matches(insn) then ".insn " ^ bits_str(encdec_long48(insn))
  else if encdec_long64_forwards_matches(insn) then ".insn " ^ bits_str(encdec_long64(insn))
  else (".insn " ^ bits_str(encdec(insn)))

overload to_str = {instruction_to_str}
