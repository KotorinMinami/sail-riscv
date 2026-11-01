// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// The Isla footprint entry accepts only 16/32-bit opcodes, not parcel fetches.
$ifdef SYMBOLIC
function backend_supports_xlong48() -> bool = false
$else
function backend_supports_xlong48() -> bool = true
$endif
