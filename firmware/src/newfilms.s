/* ================================================================== A new film set in every mode (#86, 2026-11-19)
 * The camera holds one list of 20 films (P+LPTR). A mode's per-mode set ('OM3S', ss_*) keeps per COLOR the look
 * NUMBER and that film's rows (its slot), and the camera keeps the film's 18 settings per mode; neither keeps the films
 * themselves. A new LOOKS.BIN (el_card after the early load, ub_pfl at a half-press load) swaps the list and left all
 * of that as it was, so every COLOR on a film the new set changed showed the new film's name over the old film's rows
 * and settings, with a '*' (om-emu, v0.40-beta2: P and C1 alike; issue #86). INSTALL.md promises a new set keeps "your
 * changes to the films that didn't change", so a changed film must come in as built.
 * Owner (2026-11-19, option C): a new film set replaces the films in every mode, custom modes included; a custom mode
 * keeps its film numbers, picture mode and Save Settings, and the films that did not change keep their changes.
 * - At the swap (nf_take / nf_blk): nf_chg = the films whose 64-byte record differs from the old set's (names do not
 *   count: a renamed film keeps its rows); the kept sets marked and written to M at once (nf_now: a power-off before
 *   the next photo look keeps them), then nf_pend.
 * - rc_go (nf_post, in place of its ss_post call; GUI task or task 165, under rc_busy): with nf_pend, every kept set's
 *   look on a changed film has the mark NF_MK (nf_mark again, when nf_now found rc_go busy) in its looks byte (in M with the set, so a custom mode on Reset is made
 *   again at each entry until it is assigned again), and each COLOR now on a changed film is made from the new film.
 *   Entering a kept set (a dial change, the first look, a Recall), each marked look still on its COLOR is made from
 *   the new film. "Made" = ss_lib (the slot from the film: its saved changes when made from this build, else as
 *   built; the COLOR's Extras stay) and its bit in ss_mask, so rc_go's rc_put writes the film's 18 settings through
 *   the manager. A set that holds (P group, a custom mode on Hold) then keeps its rows (ss_put), which clears its marks.
 * - ss_get copies a set's kept slot only where its looks byte equals P+LIDX, so a marked look is never copied back.
 * - nf_cur: a film's saved changes count for its '*' only when made from this build of it (fl_sw's own test for
 *   loading them), so films the new set changed lose their old '*' in the list.
 * Nothing here runs at start-up: the swap is at a half-press, rc_go at a dial change or a GUI event after the first
 * shutter event. el_pre's RAM-only entry finds a marked look not copied and leaves it to the first look. */
.section .ext13,"ax"
 .set NF_MK, 0x40                 /* a set's looks byte: this look's film changed since the set kept it */

/* nf_cmp: `call nf_cmp,[d2,d3,a2,a3],20`, a0 = the films the camera had (a LOOKS image; 0 = none: all count as
 * changed), a1 = the new films (a LOOKS image) -> nf_chg (bit j: film j's record differs), nf_nf (how many), nf_nt + 1.
 * Records only (32 + 64 j, 64 bytes): the header's selection and the names do not count. */
nf_cmp:
 mov 0xfffff,d0
 cmp 0,a0
 beq 7f
 clr d0
 mov d0,(nf_chg)
 mov a0,a2
 add 32,a2
 mov a1,a3
 add 32,a3
 clr d3                           /* j */
1:
 mov 64,d2
2:
 movbu (a2),d0
 movbu (a3),d1
 cmp d0,d1
 bne 3f
 inc a2
 inc a3
 add -1,d2
 bne 2b
 bra 4f
3:
 add d2,a2                        /* the rest of record j */
 add d2,a3
 mov 1,d0
 asl d3,d0
 mov (nf_chg),d1
 or d0,d1
 mov d1,(nf_chg)
4:
 inc d3
 cmp 20,d3
 bcs 1b
 mov (nf_chg),d0
7:
 mov d0,(nf_chg)
 clr d1                           /* how many */
5:
 cmp 0,d0
 beq 6f
 mov d0,d2
 and 1,d2
 add d2,d1
 lsr 1,d0
 bra 5b
6:
 mov d1,(nf_nf)
 mov (nf_nt),d0
 inc d0
 mov d0,(nf_nt)
 ret [d2,d3,a2,a3],20

/* nf_take: el_card's `call nf_take,[d2,d3,a2,a3],20` in place of its LPTR store, a2 = P, a1 = the new films (checked,
 * never had): compare with the films in use, publish the new ones (one store, as before), then nf_pend and rc_pend:
 * rc_go at the next GUI event makes the COLORs on changed films from the new ones. */
nf_take:
 mov a1,d2
 mov (LPTR,a2),a0
 call nf_cmp,[d2,d3,a2,a3],20
 mov d2,(LPTR,a2)                 /* one store: a reader has the old films or the new */
 call nf_now,[d2,d3,a2,a3],20
 mov 1,d0
 movbu d0,(nf_pend)               /* after the store: rc_go makes the COLORs from the new films */
 movbu d0,(rc_pend)
 ret [d2,d3,a2,a3],20

/* nf_blk: ub_pfl's `call nf_blk,[d2,d3,a2,a3],20` (a half-press load taking films the camera never had, valid block),
 * a1 = the new films: compare with the block's (the films the camera had); the first look (rc_go) does the rest. */
nf_blk:
 mov UB_C + UB_LK,a0
 call nf_cmp,[d2,d3,a2,a3],20
 call nf_now,[d2,d3,a2,a3],20
 mov 1,d0
 movbu d0,(nf_pend)
 ret [d2,d3,a2,a3],20

/* nf_now: `call nf_now,[d2,d3,a2,a3],20` from nf_take / nf_blk (HLS task): the kept sets marked and written to M now,
 * when rc_go is not running, so a power-off before the next photo look (video, S&Q) keeps the marks. rc_go running:
 * nf_pend has it do the marking. */
nf_now:
 clr d0                           /* rc_go's lock and busy flag */
 call LOCK,[d2],8
 mov d0,d3
 movbu (rc_busy),d0
 cmp 0,d0
 beq 1f
 mov d3,d0
 call UNLOCK,[d2],8
 ret [d2,d3,a2,a3],20
1:
 mov 1,d0
 movbu d0,(rc_busy)
 mov d3,d0
 call UNLOCK,[d2],8
 call ss_ld,[d2,d3,a2,a3],20
 call nf_mark,[d2,d3,a2,a3],24
 call nf_wr,[d2,d3,a2,a3],20
 clr d0
 movbu d0,(rc_busy)
 ret [d2,d3,a2,a3],20

/* nf_wr: `call nf_wr,[d2,d3,a2,a3],20`: when ss_dirty, ss_ram -> M (both aliases), as ss_wr writes it but without
 * the curves record: in ub_pfl the curves are not loaded yet (cv_load comes after), and ss_wr would write them empty.
 * Held back while the camera saves M: ss_dirty stays, and the next ss_wr (rc_go, a half-press) writes it. */
nf_wr:
 movbu (ss_dirty),d0
 cmp 0,d0
 beq 9f
 mov SS_MAGIC,d0
 mov d0,(ss_ram)
 mov SS_VER,d0
 movhu d0,(ss_ram + 4)
 mov SS_LEN,d0
 movhu d0,(ss_ram + 6)
 mov -1,d0
 mov ss_ram + 12,a0
 mov SS_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(ss_ram + 8)
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 8f
 mov SS_C,a0
 mov ss_ram,a1
 mov SS_LEN,d1
 call ub_cpy,[],0
 mov SS_U,a0
 mov ss_ram,a1
 mov SS_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(UB_DIRTY)              /* M changed: the camera saves it at the next return to shooting or power-off */
 clr d0
 movbu d0,(ss_dirty)
 mov (ss_nw),d0
 inc d0
 mov d0,(ss_nw)
8:
 mov d3,d0
 call UNLOCK,[d2],8
9:
 ret [d2,d3,a2,a3],20

/* nf_film: `call nf_film,[],0`, d2 = k, d3 = look 1..5 -> d0 = 1 when film 5k + look - 1 is in nf_chg, else 0.
 * Uses d0, d1. */
nf_film:
 mov d2,d0
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 mov 1,d1
 asl d0,d1
 mov (nf_chg),d0
 and d1,d0
 beq 1f
 mov 1,d0
1:
 ret [],0

/* nf_mark: `call nf_mark,[d2,d3,a2,a3],24`: each kept set's look on a film in nf_chg gets NF_MK (ss_dirty: written
 * with the sets). Local (4) the set. */
nf_mark:
 clr d0
 mov d0,(4,sp)
1:
 mov (4,sp),d0
 mov 1,d1
 asl d0,d1
 movbu (ss_ram + 12),d0
 and d1,d0
 beq 5f                           /* not kept */
 mov (4,sp),d0
 call ss_base,[],0
 mov a0,a2
 clr d2
2:
 movbu (d2,a2),d3
 extb d3
 cmp 1,d3
 blt 4f                           /* own settings, or marked already (NF_MK makes it > 5) */
 cmp 5,d3
 bgt 4f
 call nf_film,[],0
 cmp 0,d0
 beq 4f
 or NF_MK,d3
 movbu d3,(d2,a2)
 mov 1,d0
 movbu d0,(ss_dirty)
 mov (nf_nm),d0
 inc d0
 mov d0,(nf_nm)
4:
 inc d2
 cmp 4,d2
 bcs 2b
5:
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 cmp 6,d0
 bcs 1b
 ret [d2,d3,a2,a3],24

/* nf_post: rc_go's `call nf_post,[d2,d3,a2,a3],28` in place of `call ss_post`, a2 = P (photo, films in): ss_post, then
 * the COLORs to make from the new films (above). Locals (4) the COLORs (bit k), (8) ss_cur before. */
nf_post:
 movbu (ss_cur),d0
 mov d0,(8,sp)
 call ss_post,[d2,d3,a2,a3],24
 clr d0
 mov d0,(4,sp)
 movbu (nf_pend),d0               /* a new set: mark the kept sets, and the COLORs now on a changed film */
 cmp 0,d0
 beq 20f
 clr d0
 movbu d0,(nf_pend)
 call nf_mark,[d2,d3,a2,a3],24
 clr d2
11:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 12f
 cmp 5,d3
 bgt 12f
 call nf_film,[],0
 cmp 0,d0
 beq 12f
 mov 1,d0
 asl d2,d0
 mov (4,sp),d1
 or d0,d1
 mov d1,(4,sp)
12:
 inc d2
 cmp 4,d2
 bcs 11b
20:
 movbu (ss_fn),d0                 /* the set entered: a Recall's, or a new ss_cur, or the first look's */
 cmp 0xff,d0
 bne 21f
 movbu (ss_cur),d0
 mov (8,sp),d1
 cmp d0,d1
 bne 21f
 movbu (cm_first),d1
 cmp 0,d1
 bne 30f                          /* the same set again: nothing more */
21:
 cmp 6,d0
 bcc 30f
 mov d0,d3
 mov 1,d1
 asl d0,d1
 movbu (ss_ram + 12),d0
 and d1,d0
 beq 30f                          /* not kept: no marks */
 mov d3,d0
 call ss_base,[],0
 mov a0,a3
 clr d2
22:
 movbu (d2,a3),d0
 btst NF_MK,d0
 beq 23f
 and NF_MK - 1,d0
 mov a2,a1
 add d2,a1
 movbu (LIDX,a1),d1
 cmp d0,d1
 bne 23f                          /* that COLOR is on another look now */
 mov 1,d0
 asl d2,d0
 mov (4,sp),d1
 or d0,d1
 mov d1,(4,sp)
23:
 inc d2
 cmp 4,d2
 bcs 22b
30:
 mov (4,sp),d0                    /* make them */
 cmp 0,d0
 beq 9f
 clr d2
31:
 mov 1,d0
 asl d2,d0
 mov (4,sp),d1
 and d1,d0
 beq 32f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d3
 extb d3
 call ss_lib,[d2,d3,a2,a3],20     /* the slot from the new film (its Extras stay) */
 mov 1,d0
 asl d2,d0
 movbu (ss_mask),d1
 or d0,d1
 movbu d1,(ss_mask)               /* rc_go's rc_put: its 18 settings */
 mov (nf_nr),d0
 inc d0
 mov d0,(nf_nr)
32:
 inc d2
 cmp 4,d2
 bcs 31b
 mov (4,sp),d0
 call fw_nf,[d2,d3,a2,a3],24      /* #88: the film on screen's WB to the camera (fw_apply) */
 movbu (ss_cur),d0                /* the set now keeps them when it holds (its marks cleared) */
 cmp 6,d0
 bcc 9f
 mov d0,d2
 call ss_trust,[],0
 cmp 0,d0
 beq 9f
 mov d2,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 mov d2,d0
 clr d1
 call ss_put,[d2,d3,a2,a3],32
9:
 ret [d2,d3,a2,a3],28

/* nf_cur: `call nf_cur,[d2,d3,a2,a3],20`, a2 = P, d0 = film j with a valid EDITS record -> d0 1 when that record was
 * made from this build of film j (its check at +64 = CRC-32 of the film as built: fl_sw's test), else 0. */
nf_cur:
 mov d0,d2
 mov (TORG,a2),a3
 add TWO,a3
 mov d2,d1                        /* the saved record: TWO + 16 + 68 j */
 asl 6,d1
 mov d2,d0
 asl2 d0
 add d0,d1
 add 16,d1
 add d1,a3
 mov d2,d1                        /* the film as built */
 asl 6,d1
 add 32,d1
 mov (LPTR,a2),a0
 add d1,a0
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (64,a3),d1
 cmp d0,d1
 bne 8f
 mov 1,d0
 ret [d2,d3,a2,a3],20
8:
 clr d0
 ret [d2,d3,a2,a3],20

/* CADLOG (cm_txt, CUSTOM MODES): "New film sets taken this power-on: N, films changed in the last M of 20, COLORs
 * made from the new films R, per-mode looks marked K". */
nf_txt:
 LGS nf_s1
 mov (nf_nt),d0
 LGD
 LGS nf_s2
 mov (nf_nf),d0
 LGD
 LGS nf_s3
 mov (nf_nr),d0
 LGD
 LGS nf_s4
 mov (nf_nm),d0
 LGD
 ret [d2,d3],12
nf_s1:
 .asciz "\r\nNew film sets taken this power-on: "
nf_s2:
 .asciz ", films changed in the last "
nf_s3:
 .asciz " of 20, COLORs made from the new films "
nf_s4:
 .asciz ", per-mode looks marked "

 .balign 4
nf_chg:                           /* bit j: film j's record changed in the last new set */
 .long 0
nf_nf:
 .long 0
nf_nt:
 .long 0
nf_nr:
 .long 0
nf_nm:
 .long 0
nf_pend:
 .byte 0
 .balign 2
