// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
let ame_num_m_regs : {16, 32} = config extensions.Zvame.ame_num_m_regs

let ame_num_acc_regs : {1, 2, 4} = config extensions.Zvame.ame_num_acc_regs

type amereglen = bits(mlen)

type ameaccreglen = bits(acclen)

newtype ameregidx = Ameregidx : bits(5)

newtype ameregno = Ameregno : range(0, 31)

newtype mdregidx = Mdregidx : bits(5)

newtype mdregno = Mdregno : range(0, 31)

newtype ameaccregidx = Ameaccregidx : bits(2)

newtype ameaccregno = Ameaccregno : range(0, 3)

newtype ameadregidx = Ameadregidx : bits(2)

newtype ameadregno = Ameadregno : range(0, 3)
