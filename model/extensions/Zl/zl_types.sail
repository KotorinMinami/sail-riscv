// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

enum zl_btest = {ZL_BTNONE, ZL_BTANY, ZL_BTALL, ZL_BTNALL, ZL_BBCR, ZL_BBSR}  // bit and mask tests
enum zl_belem = {ZL_BEQB, ZL_BNEB, ZL_BEQH, ZL_BNEH}                          // byte/halfword search
enum zl_bovf = {ZL_ADDBO, ZL_SUBBO, ZL_ADDBOU, ZL_SUBBOU, ZL_ADDWBO, ZL_SUBWBO, ZL_MULBO}  // overflow branches
enum zl_bimm = {ZL_BEQI, ZL_BNEI, ZL_BTNONEI, ZL_BTANYI, ZL_BLTI, ZL_BGEI, ZL_BLTUI, ZL_BGEUI}  // compare with immediate
enum zl_brng = {ZL_BRNG, ZL_BRNG_INV, ZL_BRNGU, ZL_BRNGU_INV}                          // range branches
