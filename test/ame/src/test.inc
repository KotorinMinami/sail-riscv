# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#
# Common test infrastructure for AME bare-metal tests.
# Include with: .include "test.inc"

# ── Entry point ──────────────────────────────────────────────────────────────
.text
.globl _start
_start:

# ── tohost/fromhost memory region ────────────────────────────────────────────
.pushsection .tohost,"aw",@progbits
.align 8; .global tohost; tohost: .dword 0
.align 8; .global fromhost; fromhost: .dword 0
.popsection

# ── Signal pass and spin ──────────────────────────────────────────────────────
.macro RVMODEL_HALT_PASS
    li    x1, 1
    la    t0, tohost
.Lpass_\@:
    sw    x1, 0(t0)
    sw    x0, 4(t0)
    j     .Lpass_\@
.endm

# ── Signal fail and spin ──────────────────────────────────────────────────────
.macro RVMODEL_HALT_FAIL
    li    x1, 3
    la    t0, tohost
.Lfail_\@:
    sw    x1, 0(t0)
    sw    x0, 4(t0)
    j     .Lfail_\@
.endm

# ── Equality assertion ────────────────────────────────────────────────────────
# EXPECT reg, const  — if reg != const, halt with fail.
# Clobbers: t6
.macro EXPECT reg, expected
    li    t6, \expected
    beq   \reg, t6, .Lexpect_ok_\@
    RVMODEL_HALT_FAIL
.Lexpect_ok_\@:
.endm
