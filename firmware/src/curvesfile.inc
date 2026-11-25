/* ------------------------------------------------------------------ CURVES.BIN (v0.30 test 9, owner: "New card file")
 * Each film's built-in RGB curves and colour mix, written by LookLab with LOOKS.BIN (docs/FORMATS.md, CURVES.BIN v1;
 * card/mkcurves.py): 'OM3K' | u16 1 | u16 432 | CRC-32 of 12.. | u16 20 | 18 zero | 20 entries of 20 B at 32 (film
 * j = COLOR k look v at 5k + v - 1): u32 the CRC-32 of the LOOKS record it was made for, the 15 curve values (R, G, B
 * x the 5 points) as nibbles two to a byte, low first, the 6 mix values (s8), 2 zero.
 * - Kept in M at +0x3BE20 (after 'OM3R', before +0x3C000), the file's 432 bytes as they are, so any card works
 *   afterwards. cv_load (the films' load: the early load or the first half-press, no card) -> ck_load: the copy in M,
 *   when valid, gives ck_bi. lg_pr -> ck_card at the first half-press with a card: C:\OM3MOD\CURVES.BIN, taken when
 *   valid and not the copy in M (ck_wr, as ub_wr: only while the camera is not saving M; else ck_pend, retried at the
 *   next shutter event); then ck_bi again (el_card may have brought new films). Film sets: with a set from the LOOKS
 *   folder in use its own file LOOKS\NAME.CRV instead, and the same at every set pick (ck_set from ls_pick).
 * - ck_bi[j] = the entry's values when its check equals film j's LOOKS record's CRC-32, else zero.
 * - A slot (cv_ram: 18 curve values, 6 mix, its byte 24 the flags, 25 zero) follows its film's built-in for each part
 *   whose flag is set: bit 0 the curves, bit 1 the mix, bit 7 the flags are set (a slot from test 8 or older has none:
 *   its parts that are all zero follow). ck_fix puts the built-in into the following parts whenever a slot becomes
 *   COLOR k's (cv_rec -> ck_rec, cv_sget, the load, a new file); an edit makes the part the user's own (ck_own); the
 *   RGB / Mix row's reset makes it follow again (ck_zp). The '*'s compare with the film's built-in (ck_kset, ck_jset,
 *   ck_star). With no valid file in M (ck_have 0) none of this runs: as test 8, built-in = flat. */
 .set CK_C, 0x6295c520            /* M image 0x62920700 + 0x3BE20 */
 .set CK_U, 0xa295c520
 .set CK_LEN, 432
 .set CK_MAGIC, 0x4b334d4f        /* "OM3K" */
 .set CK_BSZ, 24                  /* a film's built-in: its 18 curve values (as a slot), then its 6 mix values */

.section .ext11,"ax"

/* ck_valid: `call ck_valid,[d2,d3,a2,a3],20`, a0 = a 432-byte image (4-aligned) -> d0 1 when it is a valid CURVES.BIN:
 * magic, version 1, length 432, count 20, zero bytes zero, CRC, every nibble -7..+7 (not 8) and the 16th 0, every
 * mix value -7..+7. Uses d0, d1, a0, a1. */
ck_valid:
 mov a0,a2
 mov (a2),d0
 cmp CK_MAGIC,d0
 bne 8f
 mov (4,a2),d0                    /* u16 1 | u16 432 */
 cmp 0x01b00001,d0
 bne 8f
 movhu (12,a2),d0
 cmp 20,d0
 bne 8f
 mov 14,d2
1:
 movbu (d2,a2),d0
 cmp 0,d0
 bne 8f
 inc d2
 cmp 32,d2
 bcs 1b
 mov -1,d0
 mov a2,a0
 add 12,a0
 mov CK_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a2),d1
 cmp d1,d0
 bne 8f
 mov a2,a3
 add 32,a3
 mov 20,d3
2:
 mov 4,d2                         /* the curve bytes +4..+11 */
3:
 movbu (d2,a3),d0
 mov d0,d1
 and 15,d0
 cmp 8,d0
 beq 8f
 lsr 4,d1
 cmp 8,d1
 beq 8f
 inc d2
 cmp 12,d2
 bcs 3b
 movbu (11,a3),d0                 /* the 16th nibble */
 and 0xf0,d0
 bne 8f
4:
 movbu (d2,a3),d0                 /* the mix +12..+17 */
 extb d0
 cmp -7,d0
 blt 8f
 cmp 7,d0
 bgt 8f
 inc d2
 cmp 18,d2
 bcs 4b
 movhu (18,a3),d0
 cmp 0,d0
 bne 8f
 add 20,a3
 add -1,d3
 bne 2b
 mov 1,d0
 ret [d2,d3,a2,a3],20
8:
 clr d0
 ret [d2,d3,a2,a3],20

/* ck_mk: `call ck_mk,[d2,d3,a2,a3],24`, a0 = a valid image, a2 = P: ck_bi from it, for the films P has now. Local (4)
 * the image. Uses d0, d1, a0, a1, MDR. */
ck_mk:
 mov a0,(4,sp)
 mov ck_bi,a0
 mov 20 * CK_BSZ,d1
 call ub_zero,[],0
 clr d0
 mov d0,(ck_nm)
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 clr d2                           /* film j */
1:
 mov (LPTR,a2),a0                 /* its LOOKS record's CRC-32 */
 mov d2,d0
 asl 6,d0
 add 32,d0
 add d0,a0
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d2,d1                        /* entry j at 32 + 20 j */
 asl2 d1
 mov d1,d3
 asl2 d3
 add d3,d1
 mov (4,sp),a3
 add d1,a3
 add 32,a3
 mov (a3),d1
 cmp d1,d0
 bne 5f
 mov (ck_nm),d0
 inc d0
 mov d0,(ck_nm)
 mov d2,d0
 call ck_bij,[],4                 /* a0 = ck_bi[j] */
 clr d3                           /* curve value n = 5 channel + point */
2:
 mov d3,d0
 lsr 1,d0
 add 4,d0
 movbu (d0,a3),d1
 btst 1,d3
 beq 3f
 lsr 4,d1
3:
 asl 28,d1
 asr 28,d1
 mov ck_map,a1
 movbu (d3,a1),d0                 /* -> its place in the slot (values 0, 2, 3, 4, 5 of each channel) */
 movbu d1,(d0,a0)
 inc d3
 cmp 15,d3
 bcs 2b
 add 18,a0                        /* the mix */
 mov a3,a1
 add 12,a1
 mov 6,d1
 call ck_cpb,[],0
5:
 inc d2
 cmp 20,d2
 bcs 1b
9:
 ret [d2,d3,a2,a3],24

/* ck_p: `call ck_p,[],0` -> a1 = P, or 0 (PVAL's checks). Uses d1, a1. */
ck_p:
 movhu (STATE),d1
 add -1,d1
 cmp HMAX,d1
 bcc 8f
 btst 3,d1
 bne 8f
 mov d1,a1
 add POOL,a1
 mov (a1),d1
 cmp MAGIC,d1
 bne 8f
 ret [],0
8:
 mov 0,a1
 ret [],0

/* ck_bik: `call ck_bik,[],4`, d0 = k -> a0 = the built-in of the film on COLOR k (ck_zero when none). ck_bij: `call
 * ck_bij,[],4`, d0 = a film j (or -1) -> a0 = ck_bi[j] (ck_zero when none). Frame 4: ck_bik calls ck_p (a call
 * writes its return address at (0,sp)). Use d0, d1, a0, a1, MDR. */
ck_bik:
 mov d0,a0
 call ck_p,[],0
 cmp 0,a1
 beq 8f
 add d0,a1
 movbu (LIDX,a1),d1
 extb d1
 cmp 1,d1
 blt 8f
 cmp 5,d1
 bgt 8f
 mov a0,d0                        /* j = 5k + v - 1 */
 asl2 d0
 add a0,d0
 add d1,d0
 add -1,d0
ck_bij:
 cmp 0,d0
 blt 8f
 cmp 20,d0
 bge 8f
 mov CK_BSZ,d1
 mul d1,d0
 mov ck_bi,a0
 add d0,a0
 ret [],4
8:
 mov ck_zero,a0
 ret [],4

/* ck_nz: `call ck_nz,[],0`, a0, d1 bytes -> d0 1 when one is not 0. Uses d0, d1, a0. ck_cmp: `call ck_cmp,[d2],8`, a0,
 * a1, d1 bytes -> d0 1 when they differ. Uses d0, d1, a0, a1. ck_cpb: `call ck_cpb,[],0`: d1 bytes from a1 to a0. */
ck_nz:
 movbu (a0),d0
 cmp 0,d0
 bne 2f
 inc a0
 add -1,d1
 bne ck_nz
 ret [],0
2:
 mov 1,d0
 ret [],0
ck_cmp:
 movbu (a0),d0
 movbu (a1),d2
 cmp d2,d0
 bne 2f
 inc a0
 inc a1
 add -1,d1
 bne ck_cmp
 clr d0
 ret [d2],8
2:
 mov 1,d0
 ret [d2],8
ck_cpb:
 movbu (a1),d0
 movbu d0,(a0)
 inc a0
 inc a1
 add -1,d1
 bne ck_cpb
 ret [],0

/* ck_fl: `call ck_fl,[d2],8`, a2 = a slot -> d0 = its flags; a slot from test 8 or older (bit 7 clear): bit 7 and
 * the bits of its parts that are all zero. Uses d0, d1, a0. */
ck_fl:
 movbu (24,a2),d0
 btst 0x80,d0
 bne 9f
 mov 0x80,d2
 mov a2,a0
 mov 18,d1
 call ck_nz,[],0
 cmp 0,d0
 bne 1f
 or 1,d2
1:
 mov a2,a0
 add 18,a0
 mov 6,d1
 call ck_nz,[],0
 cmp 0,d0
 bne 2f
 or 2,d2
2:
 mov d2,d0
9:
 ret [d2],8

/* ck_fix: `call ck_fix,[d2,d3,a2,a3],20`, a2 = a slot, a3 = its film's built-in: the parts that follow it <- it, the
 * flags noted. Nothing without a file (ck_have 0). Uses d0, d1, a0, a1. */
ck_fix:
 movbu (ck_have),d0
 cmp 0,d0
 beq 9f
 call ck_fl,[d2],8
 mov d0,d2
 btst 1,d2
 beq 1f
 mov a2,a0
 mov a3,a1
 mov 18,d1
 call ck_cpb,[],0
1:
 btst 2,d2
 beq 2f
 mov a2,a0
 add 18,a0
 mov a3,a1
 add 18,a1
 mov 6,d1
 call ck_cpb,[],0
2:
 movbu d2,(24,a2)
9:
 ret [d2,d3,a2,a3],20

/* ck_fixk: `call ck_fixk,[d2,d3,a2,a3],20`, d0 = k: live[k] follows the built-in of the film on COLOR k. ck_fixall:
 * all four. Use d0, d1, a0, a1, MDR. */
ck_fixk:
 mov d0,d2
 call ck_bik,[],4
 mov a0,a3
 mov d2,d0
 call cv_lk,[],0
 mov a0,a2
 call ck_fix,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20
ck_fixall:
 clr d2
1:
 mov d2,d0
 call ck_fixk,[d2,d3,a2,a3],20
 inc d2
 cmp 4,d2
 bcs 1b
 ret [d2,d3,a2,a3],20

/* ck_rec <- cv_rec (`call cv_rec,[d2,d3,a2,a3],20`: pf_put1, ss_slot: COLOR k's slot <- a record), a2 = P, d2 = k,
 * a3 = the record or 0: live[k] <- ed[r] for EDITS record r, else zero (as before), then the parts that follow take
 * the built-in of the record's film (EDITS record r < 20 = film r; LOOKS record j = film j as built). */
ck_rec:
 call cv_rid,[],0                 /* d0 = r, or -1 */
 mov d0,d3
 mov -1,d1                        /* the film */
 cmp 0,d3
 blt 1f
 cmp 20,d3
 bcc 3f
 mov d3,d1
 bra 3f
1:
 cmp 0,a3
 beq 3f
 mov (LPTR,a2),a1
 cmp 0,a1
 beq 3f
 mov a3,d0
 sub a1,d0
 add -32,d0
 cmp 0,d0
 blt 3f
 cmp 20 * 64,d0
 bge 3f
 btst 63,d0
 bne 3f
 lsr 6,d0
 mov d0,d1
3:
 mov d1,a3                        /* the film (a3, a2 are done with) */
 mov d2,d0
 call cv_lk,[],0
 mov a0,a2
 mov 0,a1
 cmp 0,d3
 blt 4f
 mov CV_ESZ,d0
 mul d3,d0
 mov cv_ram + CV_ED,a1
 add d0,a1
4:
 mov CV_ESZ,d1
 mov a2,a0
5:
 clr d0
 cmp 0,a1
 beq 6f
 movbu (a1),d0
 inc a1
6:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 5b
 mov a3,d0
 call ck_bij,[],4
 mov a0,a3
 call ck_fix,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20

/* ck_kset <- cv_kset (`call cv_kset,[d2,d3,a2,a3],20`, d2 = k: fl_live, the film's '*') -> d0 1 when COLOR k's
 * curves or mix differ from its film's built-in. ck_jset <- cv_jset (d0 = EDITS record r: fl_fch) -> d0 1 when a
 * part of ed[r] that does not follow differs from film r's built-in. Without a file the built-in is zero: as before. */
ck_kset:
 mov d2,d0
 call ck_bik,[],4
 mov a0,a3
 mov d2,d0
 call cv_lk,[],0
 mov a3,a1
 mov CK_BSZ,d1
 call ck_cmp,[d2],8
 cmp 0,d0
 bne 9f
 mov d2,d0                        /* better grain g2: a Film Grain strength / Grain Size of its own (G, the slot's spare
                                     byte +25, not 0) counts too */
 call cv_lk,[],0
 movbu (25,a0),d0
 cmp 0,d0
 beq 9f
 mov 1,d0
9:
 ret [d2,d3,a2,a3],20
ck_jset:
 mov d0,d3
 mov CV_ESZ,d1
 mul d1,d0
 mov cv_ram + CV_ED,a2
 add d0,a2
 mov d3,d0
 cmp 20,d0
 bcs 1f
 mov -1,d0
1:
 call ck_bij,[],4
 mov a0,a3
 call ck_fl,[d2],8
 mov d0,d2
 clr d3
 btst 1,d2
 bne 2f
 mov a2,a0
 mov a3,a1
 mov 18,d1
 call ck_cmp,[d2],8
 or d0,d3
2:
 btst 2,d2
 bne 3f
 mov a2,a0
 add 18,a0
 mov a3,a1
 add 18,a1
 mov 6,d1
 call ck_cmp,[d2],8
 or d0,d3
3:
 movbu (25,a2),d0                 /* better grain g2: a saved Film Grain strength / Grain Size (G != 0) counts too */
 cmp 0,d0
 beq 4f
 mov 1,d3
4:
 mov d3,d0
 ret [d2,d3,a2,a3],20

/* ck_star: `call ck_star,[d3,a2,a3],16` (cv_star, mx_star: the RGB / Mix row's '*' and Reset guide), d0 = k, d1 = 0
 * the curves, 1 the mix -> d2 1 when that part of COLOR k is its film's built-in. Uses d0, d1, a0, a1, MDR. */
ck_star:
 mov d0,d3
 mov d1,a2
 call ck_bik,[],4
 mov a0,a3
 mov d3,d0
 call cv_lk,[],0
 mov a3,a1
 mov 18,d1
 mov a2,d0
 cmp 0,d0
 beq 1f
 add 18,a0
 add 18,a1
 mov 6,d1
1:
 call ck_cmp,[d2],8
 mov 1,d2
 cmp 0,d0
 beq 2f
 clr d2
2:
 ret [d3,a2,a3],16

/* ck_zk <- cv_zk, ck_mzk <- mx_zk (`call cv_zk,[d2],8`, d0 = k: the RGB / Mix page's reset, e_rst): COLOR k's curves
 * (mix) zero as before; with a file they follow the film's built-in again. ck_zp: d0 = k, d1 = the part's bit. */
ck_zk:
 mov 1,d1
 bra 1f
ck_mzk:
 mov 2,d1
1:
 call ck_zp,[d2,d3,a2,a3],20
 ret [d2],8
ck_zp:
 mov d0,d2
 mov d1,d3
 call cv_lk,[],0
 mov a0,a2
 mov 18,d1
 btst 1,d3
 bne 1f
 add 18,a0
 mov 6,d1
1:
 clr d0
2:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 2b
 movbu (ck_have),d0
 cmp 0,d0
 beq 9f
 call ck_fl,[d2],8
 or d3,d0
 movbu d0,(24,a2)
 mov d2,d0
 call ck_bik,[],4
 mov a0,a3
 call ck_fix,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* ck_own: `call ck_own,[d2,d3,a2,a3],20` (cv_ev, mx_ev: a value changed on the page), d1 = 1 the curves, 2 the mix:
 * that part of COLOR cv_k is the user's own from now on. Nothing without a file. Uses d0, d1, a0, MDR. */
ck_own:
 movbu (ck_have),d0
 cmp 0,d0
 beq 9f
 mov d1,d3
 mov (cv_k),d0
 call cv_lk,[],0
 mov a0,a2
 call ck_fl,[d2],8
 not d3
 and d3,d0
 movbu d0,(24,a2)
9:
 ret [d2,d3,a2,a3],20

/* ck_load: `call ck_load,[d2,d3,a2,a3],20` from cv_load (once a power-on, the films just in), a2 = P: the copy in M,
 * when valid, -> ck_bi, COLOR 1..4 follow it; the card pass due. Reads M only. */
ck_load:
 mov 1,d0
 movbu d0,(ck_cd)
 mov CK_C,a0
 call ck_valid,[d2,d3,a2,a3],20
 movbu d0,(ck_have)
 cmp 0,d0
 beq 9f
 mov CK_C,a0
 call ck_mk,[d2,d3,a2,a3],24
 call ck_fixall,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* ck_card: `call ck_card,[d2,d3,a2,a3],24` from lg_pr (every shutter event, HLS task): a held-back write; once, at
 * the first shutter event with the films in and a card: the curves file of the set in use (ls_cvp: C:\OM3MOD\CURVES.BIN,
 * or C:\OM3MOD\LOOKS\NAME.CRV with a set from the folder, so CURVES.BIN does not replace that set's), then ck_bi from
 * what the camera has now (el_card may have brought new films): ck_set (looksets.s). */
ck_card:
 movbu (ck_pend),d0
 cmp 0,d0
 beq 1f
 call ck_wr,[d2,d3,a2,a3],20
1:
 movbu (ck_cd),d0
 cmp 0,d0
 beq 9f
 PVAL 9f
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f                           /* no card yet: the next shutter event tries again */
 clr d0
 movbu d0,(ck_cd)
 call ls_init,[d2,d3,a2,a3],20    /* the set in use (ls_go comes after this) */
 call ck_set,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],24

/* ck_wr: `call ck_wr,[d2,d3,a2,a3],20`: ck_buf into M (both aliases) with dispatch held, only while the camera is not
 * saving M (as ub_wr), M marked changed; else ck_pend (ck_card tries again). */
ck_wr:
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 2f
 mov CK_C,a0
 mov ck_buf,a1
 mov CK_LEN,d1
 call ub_cpy,[],0
 mov CK_U,a0
 mov ck_buf,a1
 mov CK_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(UB_DIRTY)
 mov d3,d0
 call UNLOCK,[d2],8
 clr d0
 movbu d0,(ck_pend)
 mov (ck_nw),d0
 inc d0
 mov d0,(ck_nw)
 ret [d2,d3,a2,a3],20
2:
 mov d3,d0
 call UNLOCK,[d2],8
 mov 1,d0
 movbu d0,(ck_pend)
 ret [d2,d3,a2,a3],20

 .balign 4
ck_nm:                            /* films the file matches */
 .long 0
ck_nw:                            /* writes to M this power-on */
 .long 0
ck_bi:                            /* each film's built-in: 18 curve values (as a slot), 6 mix */
 .space 20 * CK_BSZ
ck_zero:
 .space CK_BSZ
ck_buf:                           /* the file taken this power-on (ck_wr: to M) */
 .space CK_LEN + 4
ck_have:                          /* 1: a valid file in M (or taken this power-on) */
 .byte 0
ck_cd:                            /* 1: the card pass is due */
 .byte 0
ck_pend:                          /* 1: a write to M waits for the camera's own save */
 .byte 0
ck_st:                            /* this power-on's last curves file: 0 none, 1 taken, 2 the same, 3 not valid */
 .byte 0
ck_map:                           /* curve value n (5 channel + point) -> its byte in a slot */
 .byte 0, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17
ck_path:
 .asciz "C:\\OM3MOD\\CURVES.BIN"
 .balign 4
