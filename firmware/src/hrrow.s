/* Halation Radius row (owner, 2026-11-19: "Radius setting, 4 values"; the look approved on the camera's test builds
 * 0.40-hrT / hrM / hrW): a choice row under Halation on COLOR 1-4, Bloom (v0.40's pass, the default) / Tight /
 * Medium / Wide, per COLOR and so per film, independent of the Halation strength (hradius.s).
 *
 * Storage: G, the curves record's spare byte (live[k] +25 in cv_ram, better grain g2's byte; it goes wherever COLOR
 * k's curves go: EDITS records, the per-mode sets, the record in M), bits 5..6 = the radius. G's bit 7 says G is
 * set: G = 0 stays "nothing of its own" (a film as built: Bloom, the grain from its level, Medium); a radius on a COLOR
 * whose grain has nothing of its own is G = 0x88 | r << 5 (strength 0 = from the level, size Medium: gs_eff reads the
 * grain as before), and G goes back to 0 when the radius goes back to Bloom. gs_wr keeps the radius bits (rz_gk).
 * v0.40 and older read G's bits 0..4 only, so they keep the grain and ignore the radius (Bloom). The film's '*' and
 * the row's own count G != 0 (ck_kset / ck_jset, rz_def); the whole-profile reset clears G (gs_zk).
 * The capture (xblock xb_gs) passes the radius to hl_sel with the strength. Debug log: NOW's "Halation Radius on
 * COLOR 1-4". Photo code: byte 63 bits 2..3 (ex_rz).
 * The row's tables and helpers are here in .ext14 (the GX4-proven reserve after the debug log), with the item table
 * and the two re-hashed row switches moved here from the full .ext11. */
 .section .ext14,"ax"
 .balign 4
rz_tab:                           /* picture mode -> the row's bar id (as sz_tab) */
 .long 54, RZB, 55, RZB + 1, 56, RZB + 2, 64, RZB + 3
rz_title:
 .short 4, ST_RZT
 .long 0x6154b480
rz_l0:                            /* the title with its value */
 OPT 0, 4, ST_RZ0
 OPT 1, 4, ST_RZ0 + 1
 OPT 2, 4, ST_RZ0 + 2
 OPT 3, 4, ST_RZ0 + 3
rz_l1:                            /* the left column: "Radius" over Bloom / Tight / Med / Wide (mkicons PICTURES[15..18]) */
 OPT 0, 3, IC_RZ0
 OPT 1, 3, IC_RZ0 + 1
 OPT 2, 3, IC_RZ0 + 2
 OPT 3, 3, IC_RZ0 + 3
rz_l2:                            /* the strip: words in the camera's font */
 OPT 0, 4, ST_RZS
 OPT 1, 4, ST_RZS + 1
 OPT 2, 4, ST_RZS + 2
 OPT 3, 4, ST_RZS + 3
rz_strs:
 .long rzt_str, rz0_str, rz1_str, rz2_str, rz3_str, rzs0_str, rzs1_str, rzs2_str, rzs3_str
 .balign 2
rzt_str:                           /* "Halation Radius"; the title */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 82, 97, 100, 105, 117, 115, 0
rz0_str:                           /* "Halation Radius: Bloom"; the title with its value */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 82, 97, 100, 105, 117, 115, 58, 32, 66, 108, 111, 111, 109, 0
rz1_str:                           /* "Halation Radius: Tight" */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 82, 97, 100, 105, 117, 115, 58, 32, 84, 105, 103, 104, 116, 0
rz2_str:                           /* "Halation Radius: Medium" */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 82, 97, 100, 105, 117, 115, 58, 32, 77, 101, 100, 105, 117, 109, 0
rz3_str:                           /* "Halation Radius: Wide" */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 82, 97, 100, 105, 117, 115, 58, 32, 87, 105, 100, 101, 0
rzs0_str:                           /* "Bloom"; the strip */
 .short 66, 108, 111, 111, 109, 0
rzs1_str:                           /* "Tight" */
 .short 84, 105, 103, 104, 116, 0
rzs2_str:                           /* "Med"; "Medium" is too wide for a cell (as Grain Size) */
 .short 77, 101, 100, 0
rzs3_str:                           /* "Wide" */
 .short 87, 105, 100, 101, 0
 .balign 2

/* rz_str <- jmp from st_get (its frame: ret [d2],8), d0 = ST_RZT .. ST_RZS + 3 -> a0 the UTF-16 string. */
rz_str:
 mov d0,d2
 add -ST_RZT,d2
 asl2 d2
 mov rz_strs,a0
 add d2,a0
 mov (a0),a0
 ret [d2],8

/* rz_lc <- jmp from gr_lc (the left column's item -> setting id lookup, same frame), d0 = RZ_IT: rz_tab, 4 entries. */
rz_lc:
 mov rz_tab,a3
 mov 4,d2
 jmp lc_back

/* Row-switch cases (build.py sw_add, as Grain Size's): the choice row's id is ours, RZB + k. */
 CHC rz_a, RZB, cha_back
 CHC rz_b, RZB, chb_back
 CHC rz_c, RZB, chc_back
 CHC rz_d, RZB, chd_back
 CHC rz_f, RZB, chf_back
lc_rz:                            /* row switch 0x6155124c (the left column's cell): as lc_sz */
 mov RZ_IT,d2
 jmp lc_go

/* rz_eff: `call rz_eff,[d2,d3,a2],16`, a0 = COLOR k's slot (P + 32 + 64k) -> d0 its radius 0 Bloom, 1 Tight, 2 Medium,
 * 3 Wide (0 also when there is no settings block). Uses d0, d1, a0, a1 (keeps a3). Also the block's xb_gs (RZ_EFF). */
rz_eff:
 mov a0,a1
 call gs_ga,[d2,d3,a2],16
 clr d0
 cmp 0,a0
 beq 9f
 movbu (a0),d1
 btst 0x80,d1
 beq 9f
 mov d1,d0
 lsr 5,d0
 and 3,d0
9:
 ret [d2,d3,a2],16

/* rz_wr: `call rz_wr,[d2,d3,a2],16`, a0 = COLOR k's slot, d0 = radius 0..3 (the caller checks it): G's bits 5..6 <- it,
 * the grain's bits kept (G 0: 0x88, the grain from the level, Medium); G back to 0 when nothing of its own is left.
 * Uses d0, d1, a0, a1. */
rz_wr:
 mov d0,d3
 mov a0,a1
 call gs_ga,[d2,d3,a2],16
 cmp 0,a0
 beq 9f
 movbu (a0),d1
 btst 0x80,d1
 bne 1f
 mov 0x88,d1
1:
 and 0x9f,d1
 mov d3,d0
 asl 5,d0
 or d0,d1
 cmp 0x88,d1
 bne 2f
 clr d1
2:
 movbu d1,(a0)
9:
 ret [d2,d3,a2],16

/* rz_gk: `call rz_gk,[],0` from gs_wr in place of its store: a0 = &G, d3 = the grain's new G (0, or 0x80 | size << 3 |
 * strength) -> G = that with the Halation Radius bits G had (a radius over a grain G of 0: 0x88 | r << 5). Uses d0, d1. */
rz_gk:
 movbu (a0),d1
 clr d0
 btst 0x80,d1
 beq 1f
 mov d1,d0
 and 0x60,d0
1:
 mov d3,d1
 cmp 0,d0
 beq 3f
 cmp 0,d1
 bne 2f
 mov 0x88,d1
2:
 or d0,d1
3:
 movbu d1,(a0)
 ret [],0

/* rz_row: `call rz_row,[d2,d3,a2,a3],40` from sl_set0 (class 17), d1 the new value, d2 = P + 64k -> d1 0 stored, 1 out
 * of range. Keeps d0, a0, a1 (s_dirty reads them) and a2. Locals (4) d0, (8) a0, (12) a1. */
rz_row:
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 cmp 4,d1
 bcc 8f
 mov d1,d0
 mov d2,a0
 add 32,a0
 call rz_wr,[d2,d3,a2],16
 clr d1
 bra 9f
8:
 mov 1,d1
9:
 mov (4,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 ret [d2,d3,a2,a3],40

/* rz_def: `call rz_def,[d2,d3,a2],16` (fl_isdef: the row's '*' and Reset guide), d0 = RZB + k, a2 = P -> d0 1 when
 * the row is as built (Bloom: films carry no radius of their own), else 0. */
rz_def:
 exthu d0
 add -RZB,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0
 call rz_eff,[d2,d3,a2],16
 mov d0,d1
 clr d0
 cmp 0,d1
 bne 9f
 mov 1,d0
9:
 ret [d2,d3,a2],16

/* ex_rz: `call ex_rz,[],0` from ex_cd1 in place of its byte-63 store: a0 = the code's record, d1 = byte 63's half steps,
 * d2 = COLOR k -> byte 63 = d1 | COLOR k's radius << 2 when the code is COLOR k as set (ex_rk; the film as built:
 * Bloom, 0). Older readers read bits 0..1 only. Uses d0, a1, MDR. */
ex_rz:
 mov (ex_rk),d0
 cmp d2,d0
 bne 8f
 mov CV_ESZ,d0
 mul d2,d0
 add cv_ram + CV_LV + 25,d0
 mov d0,a1
 movbu (a1),d0
 btst 0x80,d0
 beq 8f
 lsr 3,d0
 and 12,d0
 or d0,d1
8:
 movbu d1,(63,a0)
 ret [],0

/* lg_rzn: `call lg_rzn,[d2,d3,a2,a3],24`: NOW's "Halation Radius on COLOR 1-4: Bloom, Tight, ..." (rz_eff). */
lg_rzn:
 LGS lg_rz0
 PVAL 9f
 clr d3
1:
 cmp 0,d3
 beq 2f
 LGS lg_cm
2:
 mov d3,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0
 call rz_eff,[d2,d3,a2],16
 mov lg_rzw,a0
 call lg_nth,[],0
 call lg_s,[],0
 inc d3
 cmp 4,d3
 bcs 1b
9:
 ret [d2,d3,a2,a3],24
lg_rz0:
 .asciz "\r\nHalation Radius on COLOR 1-4: "
lg_rzw:
 .ascii "Bloom\000Tight\000Medium\000Wide\000"
 .balign 4

 .balign 8
rz_pay:                           /* the row's four left cells (mkicons PICTURES[15..18]; build.py packs them here: ic_pay in
                                     .ext13 had no room for them) */
 .space 8160
rz_pend:
