/* ------------------------------------------------------------------ per-film R / G / B tone curves (feature/rgb-curves)
 * Each COLOR k has three curves (red, green, blue), 5 points each at input 0 / 25 / 50 / 75 / 100 % of the gamma
 * tables' 12-bit output (test 4, the owner's choice: on the page grid's quarter lines), an offset -7..+7 of CV_STEP
 * each (research/rgbcurves/model.py is the exact model). A curve keeps 6 values, as tests 1..2b had 6 points
 * (0 / 10 / 25 / 50 / 75 / 100 %): the points are values 0, 2, 3, 4, 5; value 1 (the old 10 % point) is unused, kept
 * 0 (cv_load clears it), so the record and slots keep their layout. st_run
 * (split toning's pass over the job's R / G / B tables, camera-tested since v0.26) adds the curve's delta D(t) to each
 * entry of its channel, with split toning's own delta, then its clamp and running max. All zero = no work.
 * Values (cv_ram; record 'OM3R' at M + 0x3B100, which older firmware never reads, holds them packed):
 *   a slot = 26 bytes: its curves (R 6, G 6, B 6 values, -7..+7), then 8 bytes kept for a per-film colour matrix (owner via
 *   the research lab, 2026-11-15: room now, so the record need not change again; zero, nothing reads them yet)
 *   +16 live[4]: COLOR k's slot now, as COLOR k's slot is its other rows now
 *   +120 ed[24]: EDITS record r's (film j, COLOR k's own 20 + k), kept and used with that record
 *   +744 sets[6] {live[4], ed[24]}: per-mode settings, as the 'OM3S' sets (C1..C5, P group)
 * In M (3348 bytes): +0 magic 'OM3R', +4 u16 version 2, +6 u16 length, +8 CRC-32 of 12.., +12 the films block's
 * generation when written (the record is used only with that block: a block written by older firmware drops the
 * curves), +16 the 196 slots in the same order, 17 bytes each: the 18 curve values two to a byte (low nibble first),
 * then the 8 kept bytes (cv_pk / cv_upk).
 * The curves follow the slot: whatever puts a record into COLOR k's slot (pf_put1, ss_slot) puts that record's
 * curves into live[k] (cv_rec: an EDITS record -> its ed[r], anything else -> flat); fl_sw's capture copies live[k]
 * into ed[r] (cv_cap); ss_put / ss_get / ss_ed copy them with the sets; e_rst clears them. */
 .set CV_ESZ, 26                  /* a slot: its curves (18: R 6, G 6, B 6), then 8 bytes kept for a colour matrix */
 .set CV_LV, 16
 .set CV_ED, CV_LV + 4 * CV_ESZ    /* 120 */
 .set CV_SS, CV_ED + 24 * CV_ESZ   /* 744 */
 .set CV_SSZ, 28 * CV_ESZ          /* 728 */
 .set CV_LEN, CV_SS + 6 * CV_SSZ   /* 5112 in RAM */
 .set CV_NE, 7 * 28                /* slots in all */
 .set CV_MLEN, 16 + CV_NE * 17     /* 3348 in M: the curves two to a byte, then the 8 kept bytes */
 .set CV_C, 0x6295b800            /* M image 0x62920700 + 0x3B100 (after 'OM3C' at +0x3B000, before +0x3C000) */
 .set CV_U, 0xa295b800
 .set CV_MAGIC, 0x52334d4f        /* "OM3R" */
 .set CV_STEP, 48
 .set CV_CLK, 14                  /* the most clicks one dial event moves: a value's whole -7..+7 */

.section .ext12,"ax"

/* cv_any: `call cv_any,[d2],8` -> d0 != 0 when any COLOR has a curve point set. Uses d0, d1, a0. */
cv_any:
 mov cv_ram + CV_LV,a0
 mov CV_ESZ,d1                    /* 4 slots: 4 x CV_ESZ bytes, CV_ESZ words */
 clr d0
1:
 mov (a0),d2
 or d2,d0
 add 4,a0
 add -1,d1
 bne 1b
 ret [d2],8

/* cv_prm: `call cv_prm,[d2,d3,a2,a3],64`, a0 = a channel's 6 values (s8; its points are values 0, 2, 3, 4, 5), a1 =
 * its 16-word block: Y[5] (offset x CV_STEP), A[4] (+24), B[4] (+44): each segment's Hermite tangent terms h m_i,
 * h m_i+1 (>> 12). Tangents: the harmonic mean of the two slopes (0 when they differ in sign or one is 0), the end
 * ones the end slopes. Locals (4..19) the slopes dQ[4] (Q12), (24..43) the tangents m[5]. Uses d0, d1, a0, a1, MDR. */
cv_prm:
 mov a0,a2
 mov a1,a3
 clr d2
1:
 mov d2,d1                        /* point i -> value i, but value 1 is unused: 0, 2, 3, 4, 5 */
 cmp 0,d1
 beq 9f
 inc d1
9:
 movbu (d1,a2),d0
 extb d0
 cmp -7,d0
 bge 2f
 mov -7,d0
2:
 cmp 7,d0
 ble 3f
 mov 7,d0
3:
 mov CV_STEP,d1
 mul d1,d0
 mov d2,d1
 asl2 d1
 mov d0,(d1,a3)                   /* Y[i] */
 inc d2
 cmp 5,d2
 bne 1b
 mov a3,a0
 mov cv_h,a1
 mov sp,a2
 add 4,a2
 mov 4,d2
4:
 mov (4,a0),d0
 mov (a0),d1
 sub d1,d0
 asl 12,d0
 mov (a1),d1
 ext d0
 div d1,d0                        /* dQ[i] = (Y[i+1] - Y[i]) 4096 / h (truncated) */
 mov d0,(a2)
 add 4,a0
 add 4,a1
 add 4,a2
 add -1,d2
 bne 4b
 mov (4,sp),d0
 mov d0,(24,sp)                   /* m[0] = dQ[0] */
 mov (16,sp),d0
 mov d0,(40,sp)                   /* m[4] = dQ[3] */
 mov sp,a2
 add 4,a2
 mov 3,d3
5:
 mov (a2),d0                      /* a = dQ[i - 1] */
 mov (4,a2),d1                    /* b = dQ[i] */
 mov d0,d2
 xor d1,d2
 cmp 0,d2
 blt 6f                           /* signs differ */
 cmp 0,d0
 beq 6f
 cmp 0,d1
 beq 6f
 mov d0,d2
 add d1,d2
 mul d1,d0
 add d0,d0
 ext d0
 div d2,d0                        /* m[i] = 2 a b / (a + b) */
 bra 7f
6:
 clr d0
7:
 mov d0,(24,a2)                   /* m[i] at (24 + 4 i, sp) */
 add 4,a2
 add -1,d3
 bne 5b
 mov cv_h,a1
 mov sp,a2
 add 24,a2
 mov a3,a0
 add 24,a0
 mov 4,d3
8:
 mov (a1),d1
 mov (a2),d0
 mul d1,d0
 asr 12,d0
 mov d0,(a0)                      /* A[i] = h m[i] >> 12 */
 mov (4,a2),d0
 mul d1,d0
 asr 12,d0
 mov d0,(20,a0)                   /* B[i] = h m[i + 1] >> 12 */
 add 4,a1
 add 4,a2
 add 4,a0
 add -1,d3
 bne 8b
 ret [d2,d3,a2,a3],64

/* cv_d: `call cv_d,[d2,d3,a2,a3],44`, d0 = t (0..4095), d1 = a channel's block (cv_prm) -> d0 = D(t). Keeps a0, a1
 * (locals (4), (8)); (12) sum, (16) s, (20) s2, (24) s3. Uses d0, d1, MDR. */
cv_d:
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov d1,a2
 mov d0,d2
 lsr 10,d2                        /* i = t >> 10 (test 4: 4 even segments), at most 3 */
 cmp 3,d2
 bls 1f
 mov 3,d2
1:
 mov d2,d3
 asl 10,d3                        /* X[i] */
 sub d3,d0                        /* x */
 mov d2,d1
 asl2 d1
 mov cv_inv,a3
 add d1,a3
 mov (a3),d1
 mul d1,d0
 lsr 12,d0                        /* s (Q12) */
 mov d0,(16,sp)
 mov d0,d3
 mul d0,d0
 lsr 12,d0                        /* s2 */
 mov d0,(20,sp)
 mul d3,d0
 lsr 12,d0                        /* s3 */
 mov d0,(24,sp)
 asl2 d2
 add d2,a2                        /* &Y[i] */
 mov (20,sp),d1
 mov d0,d2                        /* h00 = 2 s3 - 3 s2 + 4096 */
 add d2,d2
 sub d1,d2
 sub d1,d2
 sub d1,d2
 add 4096,d2
 mov (a2),d3
 mul d3,d2
 mov d2,(12,sp)
 mov (20,sp),d2                   /* h01 = 3 s2 - 2 s3 */
 mov d2,d1
 add d1,d1
 add d1,d2
 mov (24,sp),d1
 sub d1,d2
 sub d1,d2
 mov (4,a2),d3
 mul d3,d2
 mov (12,sp),d3
 add d3,d2
 mov d2,(12,sp)
 mov (24,sp),d2                   /* h10 = s3 - 2 s2 + s */
 mov (20,sp),d1
 sub d1,d2
 sub d1,d2
 mov (16,sp),d1
 add d1,d2
 mov (24,a2),d3
 mul d3,d2
 mov (12,sp),d3
 add d3,d2
 mov d2,(12,sp)
 mov (24,sp),d2                   /* h11 = s3 - s2 */
 mov (20,sp),d1
 sub d1,d2
 mov (44,a2),d3
 mul d3,d2
 mov (12,sp),d3
 add d3,d2
 asr 12,d2
 mov d2,d0
 mov (4,sp),a0
 mov (8,sp),a1
 ret [d2,d3,a2,a3],44

/* STC c, k, b: st_all's work on entry a0 of channel c (t in a3), k = with split toning, b = with c's block if any */
 .macro STC c, k, b
 .if \k
 mov (16 + 16 * \c,sp),d2
 mov (80,sp),d1
 mul d1,d2
 mov (20 + 16 * \c,sp),d3
 mov (84,sp),d1
 mul d1,d3
 add d3,d2
 asr 9,d2
 .else
 clr d2
 .endif
 .if \b
 mov (24 + 16 * \c,sp),a2
 cmp 0,a2
 beq 91f
 mov (88,sp),d0
 add d0,a2
 mov (a2),d3
 mov (92,sp),d1
 mul d1,d3
 mov (4,a2),d0
 mov (96,sp),d1
 mul d1,d0
 add d0,d3
 mov (24,a2),d0
 mov (100,sp),d1
 mul d1,d0
 add d0,d3
 mov (44,a2),d0
 mov (104,sp),d1
 mul d1,d0
 add d0,d3
 asr 12,d3
 add d3,d2
91:
 .endif
 mov a3,d0
 add d2,d0
 bge 92f
 clr d0
92:
 cmp 4095,d0
 ble 93f
 mov 4095,d0
93:
 mov (28 + 16 * \c,sp),d1
 cmp d1,d0
 bge 94f
 mov d1,d0
94:
 mov d0,(28 + 16 * \c,sp)
 movhu d0,(640 * \c,a0)
 .endm

/* st_all: `call st_all,[d2,d3,a2,a3],132` (st_run, after its gates), a0 = st_run's sp, a3 = O: the pass over the job's
 * R, G, B tables (256 + 64 entries each, identical before). Each entry t of channel c gets (Ks ws + Kh wh) >> 9 and
 * cv_d's D(t) for c's block, then the clamp and the part's running max, as st_run did one channel at a time. The
 * balance, the weights and the Hermite basis depend on t only: worked out once per entry for the three channels.
 * Locals: (4) the R entry, (8) the part's end, (12) part, (16 + 16 c) channel c: Ks, Kh, block or 0, running max;
 * (64) c, (68) f1, (72) f2, (76) t, (80) ws, (84) wh, (88) 4 i, (92..104) h00 h01 h10 h11, (108) any K, (112) any
 * block. Uses d0, d1, a0, a1, MDR. */
st_all:
 mov a3,d0
 add 1252,d0
 mov d0,(4,sp)
 mov a0,a2
 mov cv_pp,a3
 mov sp,a1
 add 16,a1
 clr d2
 clr d3
 mov 3,d1
1:
 mov (32,a2),d0
 mov d0,(a1)
 or d0,d2
 mov (44,a2),d0
 mov d0,(4,a1)
 or d0,d2
 mov (a3),d0
 mov d0,(8,a1)
 or d0,d3
 add 4,a2
 add 4,a3
 add 16,a1
 add -1,d1
 bne 1b
 mov d2,(108,sp)
 mov d3,(112,sp)
 mov (76,a0),d0
 mov d0,(64,sp)
 mov (80,a0),d0
 mov d0,(68,sp)
 mov (84,a0),d0
 mov d0,(72,sp)
 clr d0
 mov d0,(12,sp)
 mov (4,sp),d1
 add 512,d1
 mov d1,(8,sp)
2:
 clr d0
 mov d0,(28,sp)
 mov d0,(44,sp)
 mov d0,(60,sp)
3:
 mov (4,sp),a0
 movhu (a0),d0
 mov d0,(76,sp)
 mov d0,a3                        /* t, for STC */
 mov (108,sp),d1
 cmp 0,d1
 beq 5f
 mov (64,sp),d1                   /* u = t moved by the balance (as st_run v0.28) */
 cmp d1,d0
 bcc 4f
 mov (68,sp),d1
 mul d1,d0
 lsr 16,d0
 bra 41f
4:
 sub d1,d0
 mov (72,sp),d1
 mul d1,d0
 lsr 16,d0
 add 2048,d0
41:
 mov 4095,d1
 sub d0,d1                        /* s */
 mov d0,d2
 mul d1,d2
 lsr 12,d2
 mul d1,d2
 lsr 12,d2
 mov d2,(80,sp)                   /* ws */
 mov d0,d3
 mul d0,d3
 lsr 12,d3
 mul d1,d3
 lsr 12,d3
 mov d3,(84,sp)                   /* wh */
5:
 mov (112,sp),d1
 cmp 0,d1
 beq 7f
 mov (76,sp),d0                   /* the Hermite basis at t (as cv_d) */
 mov d0,d2
 lsr 10,d2
 cmp 3,d2
 bls 6f
 mov 3,d2
6:
 mov d2,d3
 asl 10,d3
 sub d3,d0                        /* x */
 asl2 d2
 mov d2,(88,sp)
 mov cv_inv,a2
 add d2,a2
 mov (a2),d1
 mul d1,d0
 lsr 12,d0                        /* s */
 mov d0,d3
 mul d0,d0
 lsr 12,d0
 mov d0,d1                        /* s2 */
 mul d3,d0
 lsr 12,d0                        /* s3 */
 mov d0,d2
 add d2,d2
 sub d1,d2
 sub d1,d2
 sub d1,d2
 add 4096,d2
 mov d2,(92,sp)                   /* h00 = 2 s3 - 3 s2 + 4096 */
 mov d1,d2
 add d2,d2
 add d1,d2
 sub d0,d2
 sub d0,d2
 mov d2,(96,sp)                   /* h01 = 3 s2 - 2 s3 */
 mov d0,d2
 sub d1,d2
 sub d1,d2
 add d3,d2
 mov d2,(100,sp)                  /* h10 = s3 - 2 s2 + s */
 mov d0,d2
 sub d1,d2
 mov d2,(104,sp)                  /* h11 = s3 - s2 */
7:
 mov (4,sp),a0
 mov (108,sp),d1
 cmp 0,d1
 beq 72f
 mov (112,sp),d1
 cmp 0,d1
 beq 71f
 STC 0,1,1
 STC 1,1,1
 STC 2,1,1
 bra 79f
71:
 STC 0,1,0
 STC 1,1,0
 STC 2,1,0
 bra 79f
72:
 STC 0,0,1
 STC 1,0,1
 STC 2,0,1
79:
 mov (4,sp),d0
 add 2,d0
 mov d0,(4,sp)
 mov (8,sp),d1
 cmp d1,d0
 bne 3b
 mov (12,sp),d0
 cmp 0,d0
 bne 9f
 inc d0
 mov d0,(12,sp)                   /* part 1: the 64 entries after the 256 */
 add 128,d1
 mov d1,(8,sp)
 bra 2b
9:
 ret [d2,d3,a2,a3],132

/* cv_set: `call cv_set,[d2,d3,a2,a3],20`, d0 = COLOR k (0..3) -> d0 = its channels with a point set (bit c); their
 * blocks into cv_pb + 64 c and cv_pp[c] = that block, else 0. Uses d0, d1, a0, a1, MDR. */
cv_set:
 mov CV_ESZ,d1
 mul d1,d0
 mov cv_ram + CV_LV,a2
 add d0,a2                        /* live[k] */
 clr d3
 clr d2
1:
 mov a2,a0
 mov 6,d1
2:
 movbu (a0),d0
 cmp 0,d0
 bne 3f
 inc a0
 add -1,d1
 bne 2b
 clr d0                           /* flat: no block */
 bra 4f
3:
 mov d2,d0
 asl 6,d0
 mov cv_pb,a1
 add d0,a1
 mov a2,a0
 call cv_prm,[d2,d3,a2,a3],64
 mov d2,d0
 asl 6,d0
 add cv_pb,d0
 mov 1,d1
 asl d2,d1
 or d1,d3
4:
 mov d2,d1
 asl2 d1
 mov cv_pp,a0
 add d1,a0
 mov d0,(a0)
 add 6,a2
 inc d2
 cmp 3,d2
 bne 1b
 mov d3,d0
 ret [d2,d3,a2,a3],20

/* cv_rid: `call cv_rid,[],0`, a2 = P, a3 = a record -> d0 = r when a3 is record r (0..23) of the EDITS image in use,
 * else -1. Uses d0, d1, a1. */
cv_rid:
 mov -1,d0
 mov (TORG,a2),a1
 cmp 0,a1
 beq 9f
 add TWO + 16,a1
 clr d1
1:
 cmp a3,a1
 beq 2f
 add 68,a1
 inc d1
 cmp 24,d1
 bne 1b
 ret [],0
2:
 mov d1,d0
9:
 ret [],0

/* cv_lk: `call cv_lk,[],0`, d0 = k -> a0 = live[k]. Uses d0, d1, a0, MDR. */
cv_lk:
 mov CV_ESZ,d1
 mul d1,d0
 mov cv_ram + CV_LV,a0
 add d0,a0
 ret [],0

/* cv_rec: `call cv_rec,[d2,d3,a2,a3],20` (pf_put1, ss_slot: COLOR k's slot <- a record), a2 = P, d2 = k, a3 = the
 * record or 0 -> live[k] <- that record's curves: ed[r] for EDITS record r, else flat. Uses d0, d1, a0, a1, MDR. */
cv_rec:
 jmp ck_rec                        /* v0.30 test 9: and the built-in of the record's film (curvesfile.inc) */

/* cv_cap: `call cv_cap,[d2,d3,a2,a3],20` (fl_sw, after pf_capto put COLOR k into EDITS record a3), a2 = P, d2 = k:
 * ed[r] <- live[k]. Uses d0, d1, a0, a1, MDR. */
cv_cap:
 call cv_rid,[],0
 cmp 0,d0
 blt 9f
 mov CV_ESZ,d1
 mul d1,d0
 mov cv_ram + CV_ED,a1
 add d0,a1
 mov d2,d0
 call cv_lk,[],0
 mov CV_ESZ,d1
1:
 movbu (a0),d0
 movbu d0,(a1)
 inc a0
 inc a1
 add -1,d1
 bne 1b
9:
 ret [d2,d3,a2,a3],20

/* cv_zk: `call cv_zk,[d2],8`, d0 = k: live[k]'s curves flat (e_rst; the RGB page's reset); with CURVES.BIN the film's
 * built-in. */
cv_zk:
 jmp ck_zk                         /* v0.30 test 9: with CURVES.BIN, back to the film's built-in */

/* cv_kset: `call cv_kset,[d2,d3,a2,a3],20`, d2 = k -> d0 1 when COLOR k's curves or colour mix differ from its film's
 * built-in (fl_live: the film's '*'). cv_jset: the same for EDITS record d0's saved ones (fl_fch). Zero built-in
 * without CURVES.BIN, as before. */
cv_kset:
 jmp ck_kset                       /* v0.30 test 9: against the film's built-in (curvesfile.inc) */
cv_jset:
 jmp ck_jset

/* cv_sput: `call cv_sput,[d2,d3,a2,a3],20` (ss_put), d0 = a set: the set's live[4] and ed[24] <- ours; ss_chg = 1
 * when any byte differed (so the set is written). Uses d0, d1, a0, a1, MDR. */
cv_sput:
 mov CV_SSZ,d1
 mul d1,d0
 mov cv_ram + CV_SS,a0
 add d0,a0
 mov cv_ram + CV_LV,a1
 mov CV_SSZ,d1
 call ss_cc,[d2],8
 ret [d2,d3,a2,a3],20

/* cv_sget: `call cv_sget,[d2,d3,a2,a3],20` (ss_get, COLOR k's slot from the set), d0 = the set, d2 = k: live[k] <-
 * the set's. Uses d0, d1, a0, a1, MDR. */
cv_sget:
 mov CV_SSZ,d1
 mul d1,d0
 mov cv_ram + CV_SS,a1
 add d0,a1
 mov CV_ESZ,d0
 mul d2,d0
 add d0,a1
 mov d2,d0
 call cv_lk,[],0
 mov CV_ESZ,d1
1:
 movbu (a1),d0
 movbu d0,(a0)
 inc a0
 inc a1
 add -1,d1
 bne 1b
 mov d2,d0                        /* v0.30 test 9: its following parts take the film's built-in */
 call ck_fixk,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20

/* cv_sed: `call cv_sed,[d2,d3,a2,a3],20` (ss_ed: the set's film changes become the ones in use), d0 = the set:
 * ed[24] <- the set's. Uses d0, d1, a0, a1, MDR. */
cv_sed:
 mov CV_SSZ,d1
 mul d1,d0
 mov cv_ram + CV_SS + 4 * CV_ESZ,a1
 add d0,a1
 mov cv_ram + CV_ED,a0
 mov 24 * CV_ESZ,d1
 call ub_cpy,[],0
 ret [d2,d3,a2,a3],20

/* cv_load: `call cv_load,[d2,d3,a2,a3],20` (ub_pfl, the first half-press; once a power-on): the record in M when it
 * is valid and was written with the films block the camera had at power-on (ub_ok0, generation ub_gen0), unpacked;
 * else every slot zero. */
cv_load:
 movbu (cv_ok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(cv_ok)
 movbu (ub_ok0),d0
 cmp 0,d0
 beq 8f
 mov CV_C,a3
 mov (a3),d0
 cmp CV_MAGIC,d0
 bne 8f
 movhu (4,a3),d0
 cmp 2,d0
 bne 8f
 movhu (6,a3),d0
 cmp CV_MLEN,d0
 bne 8f
 mov (12,a3),d0
 mov (ub_gen0),d1
 cmp d1,d0
 bne 8f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov CV_MLEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 8f
 mov cv_ram + 16,a0
 mov CV_C + 16,a1
 call cv_upk,[d2,d3],12
 mov cv_ram + 16,a0               /* test 4: value 1 of each curve (tests 1..2b's 10 % point) unused: cleared */
 mov CV_NE,d1
 clr d0
7:
 movbu d0,(1,a0)
 movbu d0,(7,a0)
 movbu d0,(13,a0)
 add CV_ESZ,a0
 add -1,d1
 bne 7b
 mov 1,d0
 movbu d0,(cv_v0)
 bra 10f
8:
 mov cv_ram + CV_LV,a0
 mov CV_LEN - CV_LV,d1
 call ub_zero,[],0
10:
 call ck_load,[d2,d3,a2,a3],20    /* v0.30 test 9: the films' built-in curves and mix (CURVES.BIN's copy in M) */
9:
 ret [d2,d3,a2,a3],20

/* cv_hdr: `call cv_hdr,[d2,d3,a2,a3],20` before ub_wr's / ss_wr's locked write (interrupts on), d0 = the films
 * block's generation the record goes with, a0 = that save's own buffer (CV_WRK + CW_SU / CW_SS): cv_ram packed into
 * it, its header and CRC, as the record will be in M. Test 1b..3 did this inside the locked write (212,851
 * instructions with interrupts off; test 3 froze the camera once: research/NOTES.md). Uses d0, d1, a0, a1. */
cv_hdr:
 mov a0,a2
 mov d0,(12,a2)
 mov CV_MAGIC,d0
 mov d0,(a2)
 mov 2,d0
 movhu d0,(4,a2)
 mov CV_MLEN,d0
 movhu d0,(6,a2)
 mov a2,a0
 add 16,a0
 mov cv_ram + 16,a1
 call cv_pk,[d2,d3],12
 mov -1,d0
 mov a2,a0
 add 12,a0
 mov CV_MLEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(8,a2)
 ret [d2,d3,a2,a3],20

/* cv_put: `call cv_put,[d2],8` inside ub_wr's / ss_wr's locked write (the camera not saving M), a1 = the buffer cv_hdr
 * made: copied into M, both aliases (word copies only, as the films block's own). Uses d0, d1, a0, a1; keeps d3 (the
 * callers' lock state). */
cv_put:
 movbu (cv_ok),d0                 /* never before the record was read this power-on (it would be overwritten flat) */
 cmp 0,d0
 beq 9f
 mov a1,d2
 mov CV_C,a0
 mov CV_MLEN,d1
 call ub_cpy,[],0
 mov CV_U,a0
 mov d2,a1
 mov CV_MLEN,d1
 call ub_cpy,[],0
 mov (cv_nw),d0
 inc d0
 mov d0,(cv_nw)
9:
 ret [d2],8

/* cv_pk: `call cv_pk,[d2,d3],12`, a0 = M's slots, a1 = cv_ram's: each slot's 18 curve values two to a byte (low
 * nibble first), then its 8 kept bytes. cv_upk: the other way (a0 = cv_ram's, a1 = M's), nibbles sign-extended.
 * Use d0, d1, a0, a1. */
cv_pk:
 mov CV_NE,d3
1:
 mov 9,d2
2:
 movbu (a1),d0
 and 15,d0
 movbu (1,a1),d1
 asl 4,d1
 or d1,d0
 movbu d0,(a0)
 add 2,a1
 inc a0
 add -1,d2
 bne 2b
 mov 8,d2
3:
 movbu (a1),d0
 movbu d0,(a0)
 inc a1
 inc a0
 add -1,d2
 bne 3b
 add -1,d3
 bne 1b
 ret [d2,d3],12
cv_upk:
 mov CV_NE,d3
1:
 mov 9,d2
2:
 movbu (a1),d0
 mov d0,d1
 asl 28,d0
 asr 28,d0
 movbu d0,(a0)
 asl 24,d1
 asr 28,d1
 movbu d1,(1,a0)
 add 2,a0
 inc a1
 add -1,d2
 bne 2b
 mov 8,d2
3:
 movbu (a1),d0
 movbu d0,(a0)
 inc a1
 inc a0
 add -1,d2
 bne 3b
 add -1,d3
 bne 1b
 ret [d2,d3],12

 .balign 4
cv_h:                             /* the segments' widths (test 4: 0 / 25 / 50 / 75 / 100 %) */
 .long 1024, 1024, 1024, 1024
cv_inv:                           /* 2^24 / h */
 .long 16384, 16384, 16384, 16384
cv_pp:
 .long 0, 0, 0
cv_nw:
 .long 0
cv_pb:
 .space 3 * 64
 .balign 4
cv_ram:
 .space CV_LEN
cv_ok:
 .byte 0
cv_v0:
 .byte 0
 .balign 4

/* ------------------------------------------------------------------ the RGB page (mockup B, owner 2026-11-15)
 * Row RG_IT under the Highlight & Shadow row. It is the camera's H&S row in all of the column's switches (so the
 * camera shows its curve page and runs its dials), except: its left cell is ours ("RGB", lc_rg), and its update case
 * (cv_case) marks our page on (cv_on; H&S's own case, cv_hs, and every other row, cv_pu, mark it off; any GUI state
 * change too, cv_gx). While it is on, the page's reads of COLOR k's H&S settings (976 + 3k Hi, 977 Mid, 978 Sh) and
 * of its INFO setting 2191 are ours, and their writes leave the camera's values as they are (cv_sv):
 *   Sh (the rear dial, the left header slot) = the offset -7..+7 of the selected point of the selected colour
 *   Hi (the front dial, the right header slot) = the selected point 1..5
 *   Mid = CV_MIDV 0 (the middle slot), 2191 reads 886 (the Sh / Hi mode; the camera sets it on entering the row).
 * Reads are ours only for the page's own callers (cv_get / cv_dflt: return addresses below), so the H&S row's left
 * cell and the '*' checks keep reading the camera's values. The dials and INFO are handled in cv_ev (the camera's dial
 * handler keeps its own running value, so its writes are not used).
 * Pictures while on (cv_ic): the curve halves 4147..4176 clear, the middle curves 4177..4206 our picture of the three
 * curves (cv_draw, drawn when anything changed), the header labels (test 7) "Sh" 4208 -> "Level", "Hi" 4207 -> "Pt" (its "+" blank), "Mid"
 * 4331 -> the colour's name in its colour, the guides 16247 / 16248 -> "Color [INFO]" (firmware/rgbpics.py). */
 .set CV_RFID, 2191               /* cv_sv's refresh write on our pages */
 .set CV_MIDV, 0                  /* a value in -7..+7: the middle curve's object (our picture) shows only then (om-emu) */
 .set HS_GSH, 0x612881f2          /* the page's reads (0x61288159): GetValue Hi / Sh / Mid return here */
 .set HS_GHI, 0x612881de
 .set HS_GMD, 0x61288206
 .set HS_DSH, 0x61288230          /* its GetDefault reads */
 .set HS_DHI, 0x6128821b
 .set HS_DMD, 0x61288245
 .set HS_DIAL, 0x611b43ad         /* the dial handler's read before its write */
 .set HS_PSEL, 124               /* mix test 6: the H&S panel's selector of its look (outer / middle) */
 .set SEL_N, 92                   /* a selector's entry count (u16) and current entry (u16) */
 .set SEL_I, 94
 .set HS_HDRAW, 0x610daa1f        /* mix test 5: the page header's picture draw (its return into the lookup) */
 .set HS_MID0, 0x6146656c         /* its layout records of the middle slot: the dial symbol (Mid look), "Mid", the */
 .set HS_MIDN, 0x61466680 - HS_MID0  /* sign, the digits; the left slot's records lie below, the right's from 0x61466680 */
.set HS_MLAB, 0x61466580         /* test 7: the middle slot's "Mid" label record (om-emu) */
.set HS_DRAW2, 0x610eb160        /* test 7: the second lookup of each header picture (the one drawn; om-emu) */
.set HS_RPM, 0x614666a8          /* test 7: the right slot's "±" and "+" sign records (om-emu; glyphs 1131 / 1132, */
.set HS_RPLUS, 0x614666b8        /* both 13 x 30) */
 .set CVI0, 0x7f60                /* our picture ids (cv_ent order, rgbpics.py; 0x7f60.. is free) */
 .set CVI_N, 14                   /* + colour mix: "Sat" R / G / B, "Hue" R / G / B, the "Mix" cell */
 .set CVI_CELL, CVI0 + 6
 .set CVI_MXC, CVI0 + 13
 .set CV_WRK, 0xa0fa3000          /* the drawing's work area (uncached), after the built-in files; build.py loads it */
 .set CW_LO, 0                    /* u16 lo[3][300], hi[3][300]: each curve's rows at each column */
 .set CW_HI, 1800
 .set CW_ROW, 3600                /* one row of palette indices */
 .set CW_ST, 4096                 /* the stream */
 .set CW_END, 0x6000              /* ... up to here (2b: was 0x8000; the largest seen in om-emu is ~13 KB) */
 .set CW_SU, 0x6000               /* 2b: the curves record packed for the films save (ub_wr), and for the custom */
 .set CW_SS, 0x7000               /* modes' save (ss_wr): 3,348 B each, made before the locked write (cv_hdr) */
 .set CW_XR, 0x8000               /* u16 xmin, xmax [3][300]: the columns whose span holds the row (empty: 0xffff, 0) */
 .if CV_WRK + CW_SU - CV_STU
 .error "CV_STU (editor.s) is not CV_WRK + CW_SU"
 .endif
 .if CV_WRK + CW_SS - CV_STS
 .error "CV_STS (editor.s) is not CV_WRK + CW_SS"
 .endif

/* cv_case: the column's update switch for RG_IT (as H&S's case 0x611d04e5; d0 free there) */
cv_case:
 mov 1,d0
 mov d0,(cv_on)
 mov (cv_gen),d0
 inc d0
 mov d0,(cv_gen)
 jmp HS_CASE
cv_hs:                            /* ... and for the H&S row itself */
 clr d0
 mov d0,(cv_on)
 jmp HS_CASE

/* cv_pu <- .hook_pu (the screen update's end, (4,sp) -> the current item): another row -> off; then pu_hook */
cv_pu:
 mov (4,sp),a0
 movhu (a0),d0
 cmp RG_IT,d0
 beq 1f
 cmp MX_IT,d0                     /* colour mix: its page too (cv_on 2) */
 beq 1f
 mov 0,a0
 mov a0,(cv_on)
1:
 jmp pu_hook

/* cv_gx <- .hook_gx (d0 = the next GUI state; a0, a1, d1 free): any state change -> off; then gx_map */
cv_gx:
 mov d0,d1
 exthu d1
 cmp 0,d1
 beq 1f
 mov 0,a1
 mov a1,(cv_on)
1:
 jmp gx_map

/* lc_rg: the column's left-cell switch for RG_IT (as lc_bw, then lch_back's pick with our one-option list) */
lc_rg:
 mov (20,sp),a3
 mov 1,d0
 add d1,a3
 movbu d0,(a3)
 inc4 a3
 mov rg_l1,a1
 mov 1,d1
 mov a3,(4,sp)
 mov (36,sp),a0
 clr d0
 call LC_PICK,[d2,d3,a2,a3],24
 jmp LC_DONE
 .balign 4
rg_l1:
 .long 0
 .short 3, CVI_CELL
 .long 0x6154b480

/* cv_val: `call cv_val,[d2,d3],12`, d1 = id - 976 (0..11) -> d0 = our value for it; cv_k = k. Uses d0, d1, a0. */
cv_val:
 clr d2
1:
 cmp 3,d1
 bcs 2f
 add -3,d1
 inc d2
 bra 1b
2:
 mov d2,(cv_k)
 mov (cv_on),d0                   /* colour mix: the Mix page's values */
 cmp 2,d0
 bne 21f
 jmp mx_val
21:
 cmp 0,d1
 bne 3f
 movbu (cv_p),d0                  /* Hi: the point 1..5 */
 inc d0
 bra 9f
3:
 cmp 1,d1
 bne 4f
 mov CV_MIDV,d0
 bra 9f
4:
 mov CV_ESZ,d3                    /* Sh: the offset */
 mul d2,d3
 movbu (cv_c),d1
 asl 1,d1
 add d1,d3
 asl 1,d1
 add d1,d3
 movbu (cv_p),d1
 cmp 0,d1
 beq 5f
 inc d1                           /* point -> value: 0, 2, 3, 4, 5 */
5:
 add d1,d3
 mov cv_ram + CV_LV,a0
 movbu (d3,a0),d0
 extb d0
9:
 ret [d2,d3],12

/* cv_get <- facade GetValue word 0x60e57480 (CALLS: d0 id, a0 facade, a1 out, MDR return); else sl_get */
cv_get:
 cmp 0,a1
 beq 9f
 mov (cv_on),d1
 cmp 0,d1
 beq 9f
 cmp 2191,d0
 bne 1f
 mov 886,d1
 mov d1,(a1)
 clr d0
 rets
1:
 mov d0,d1
 exthu d1
 add -976,d1
 cmp 12,d1
 bcc 9f
 movm [d2,d3,a2],(sp)
 mov mdr,d2
 cmp HS_GSH,d2
 beq 2f
 cmp HS_GHI,d2
 beq 2f
 cmp HS_GMD,d2
 beq 2f
 cmp HS_DIAL,d2
 beq 2f
 movm (sp),[d2,d3,a2]
 bra 9f
2:
 mov d2,a2
 add -4,sp
 call cv_val,[d2,d3],12
 add 4,sp
 mov d0,(a1)
 mov a2,d2
 mov d2,mdr
 movm (sp),[d2,d3,a2]
 clr d0
 rets
9:
 jmp sl_get

/* cv_dflt <- facade GetDefault word 0x60e57510: the page's own reads -> our value, but Mid's 1 when COLOR k has a
 * point set (the page then counts as changed); else ed_default */
cv_dflt:
 cmp 0,a1
 beq 9f
 mov (cv_on),d1
 cmp 0,d1
 beq 9f
 mov d0,d1
 exthu d1
 add -976,d1
 cmp 12,d1
 bcc 9f
 movm [d2,d3,a2],(sp)
 mov mdr,d2
 cmp HS_DSH,d2
 beq 2f
 cmp HS_DHI,d2
 beq 2f
 cmp HS_DMD,d2
 beq 2f
 movm (sp),[d2,d3,a2]
 bra 9f
2:
 mov d2,a2
 add -4,sp
 call cv_val,[d2,d3],12
 cmp HS_DMD,a2                    /* Mid's default: 1 when COLOR k has a point set, so the page counts as changed */
 bne 3f                           /* (its Reset guide) */
 mov (cv_k),d0
 call cv_lk,[],0
 mov 18,d1
 mov (cv_on),d0                   /* colour mix: on the Mix page, its six values */
 cmp 2,d0
 bne 41f
 add 18,a0
 mov 6,d1
41:
 clr d0
4:
 movbu (a0),d3
 or d3,d0
 inc a0
 add -1,d1
 bne 4b
 cmp 0,d0
 beq 3f
 mov CV_MIDV + 1,d0
3:
 add 4,sp
 mov d0,(a1)
 mov a2,d2
 mov d2,mdr
 movm (sp),[d2,d3,a2]
 clr d0
 rets
9:
 jmp ed_default

/* cv_sv <- .hook_set (the facade SetValue's manager call, entered as the manager: d0 id, d1 value, a0 inner, a1 mode;
 * d2 / d3 / a2 / a3 saved by the call, frame 68, the return address at (68,sp)): while our page is on, COLOR k's H&S
 * ids and 2191 keep the camera's own values (the manager gets 2191 back: no change, the page refreshes, as ed_set);
 * our values change in cv_ev only, and on the camera's reset of our row (cv_rst). Else sl_set. */
cv_sv:
 mov (cv_on),d2
 cmp 0,d2
 beq 9f
 cmp 2191,d0
 beq 8f
 mov d0,d2
 exthu d2
 add -976,d2
 cmp 12,d2
 bcc 9f
 movbu (cv_rst),d2                /* the camera's reset of our row (OK held): COLOR k's curves flat, once */
 cmp 1,d2
 bne 7f
 mov 2,d2
 movbu d2,(cv_rst)
 mov d0,a3
 mov d1,d3
 mov (cv_k),d0
 add -4,sp
 call cv_zx,[d2],8                /* the open page's: curves or mix */
 call cv_dty,[d2,d3,a2,a3],20
 add 4,sp
 mov a3,d0
 mov d3,d1
7:
 mov CV_RFID,d0                   /* the refresh: the panel's mode 2191 with its own value (~20k instructions; the H&S */
8:                                /* id's write re-checks 37 more settings, ~355k). The page redraws the same. */
 mov d0,d2
 mov a0,d3
 mov a1,a2
 add -4,sp
 call sget,[],4
 add 4,sp
 mov d0,d1
 mov (68,sp),d0
 mov d0,mdr
 mov d2,d0
 mov d3,a0
 mov a2,a1
 jmp manager
9:
 jmp sl_set

/* cv_ev <- .hook_pme (Picture Mode's event handler, CALLS: d0 event, d1, a0, a1; MDR return). On our page: the front dial (0x9031, a1 its clicks) moves the point (the way the camera's
 * Highlights value goes for it), the rear dial (0x9032) the offset (as the camera's Shadows), INFO (0x9014) picks the
 * next colour. The events then go on to the camera (pm_ev) as they came: its dial handler writes its own running
 * value and its panel toggles 2191 on INFO (cv_inf), both refused by cv_sv, and it redraws the page as for its own
 * rows (consuming the event, or passing another in its place, left the page stale or closed it: om-emu). OK held
 * (0xf802 while OK is down, 0x900c .. 0x900d) -> cv_rst: the camera's own reset of the row follows (cv_rsi), and its
 * first write makes COLOR k's curves flat (cv_sv); without one, the release does it. */
cv_ev:
 movm [d2,d3,a2,a3],(sp)
 add -24,sp                       /* (0) call slot, (4) MDR, (8) d0, (12) d1, (16) a0, (20) a1 */
 mov mdr,d2
 mov d2,(4,sp)
 mov d0,(8,sp)
 mov d1,(12,sp)
 mov a0,(16,sp)
 mov a1,(20,sp)
 mov (cv_on),d2
 cmp 0,d2
 bne 1f
 jmp 90f
1:
 cmp 0x900c,d0                    /* OK pressed / released: the reset counts only while it is held */
 bne 2f
 mov 1,d2
 movbu d2,(cv_okd)
 jmp 90f
2:
 cmp 0x900d,d0
 bne 3f
 clr d2
 movbu d2,(cv_okd)
 movbu (cv_rst),d2                /* a reset the camera made no write for: the curves flat now */
 cmp 1,d2
 bne 21f
 mov (cv_k),d0
 call cv_zx,[d2],8                /* the open page's: curves or mix */
 call cv_dty,[d2,d3,a2,a3],20
21:
 clr d2
 movbu d2,(cv_rst)
 jmp 90f
3:
 mov a1,d3                        /* the dials' clicks, signed: a fast turn brings several in one event (the camera's */
 cmp -CV_CLK,d3                   /* own pages count them all) */
 bge 30f
 mov -CV_CLK,d3
30:
 cmp CV_CLK,d3
 ble 31f
 mov CV_CLK,d3
31:
 mov (cv_on),d2                   /* colour mix: the Mix page's dials */
 cmp 2,d2
 bne 311f
 jmp mx_ev
311:
 cmp 0x9031,d0                    /* front dial: the point */
 bne 4f
 movbu (cv_p),d2
 add d3,d2
 cmp 0,d2
 bge 32f
 clr d2
32:
 cmp 4,d2                         /* test 4: 5 points */
 ble 33f
 mov 4,d2
33:
 movbu d2,(cv_p)
 jmp 80f
4:
 cmp 0x9032,d0                    /* rear dial: the offset of the selected point of the selected colour */
 bne 5f
 mov (cv_k),d0
 call cv_lk,[],0
 movbu (cv_c),d2
 mov d2,d0
 add d0,d0
 add d2,d0
 add d0,d0
 movbu (cv_p),d2
 cmp 0,d2
 beq 43f
 inc d2                           /* point -> value: 0, 2, 3, 4, 5 */
43:
 add d2,d0
 add d0,a0
 movbu (a0),d2
 extb d2
 sub d3,d2
 cmp -7,d2
 bge 41f
 mov -7,d2
41:
 cmp 7,d2
 ble 42f
 mov 7,d2
42:
 movbu d2,(a0)
 mov 1,d1                         /* v0.30 test 9: the curves are the user's own now */
 call ck_own,[d2,d3,a2,a3],20
 PVAL 80f
 mov 1,d3
 movbu d3,(DIRTY,a2)              /* saved at the next half-press / on leaving Picture Mode */
 jmp 80f
5:
cv_ev5:
 cmp 0x9014,d0                    /* INFO: the next colour */
 bne 6f
 movbu (cv_c),d2
 inc d2
 cmp 3,d2
 bcs 51f
 clr d2
51:
 movbu d2,(cv_c)
 jmp 80f                          /* ... and goes on to the camera: its panel toggles 2191 (cv_inf lets it reach */
                                  /* the panel on our row; cv_sv refuses the write) and redraws the page */
6:
 cmp 0xf802,d0                    /* OK held */
 bne 90f
 movbu (cv_okd),d2
 cmp 0,d2
 beq 90f
 mov 1,d2                         /* the camera's own reset of the row follows (cv_rsi lets it reach the panel): */
 movbu d2,(cv_rst)                /* its first write makes COLOR k's curves flat (cv_sv), and it redraws the page */
 bra 90f
80:
cv_ev80:
 mov (cv_gen),d0                  /* changed: drawn again; the event goes on to the camera, whose writes cv_sv */
 inc d0                           /* refuses but which refreshes the page as for its own rows */
 mov d0,(cv_gen)
90:
 mov (4,sp),d2
 mov d2,mdr
 mov (8,sp),d0
 mov (12,sp),d1
 mov (16,sp),a0
 mov (20,sp),a1
 add 24,sp
 movm (sp),[d2,d3,a2,a3]
 jmp pm_ev

/* cv_star: the column's "row changed?" switch (0x611d1a03, its sw13 table) for RG_IT, in that function's frame
 * ((12,sp) = setting 903, the COLOR 1..4): d2 = 1 when COLOR k's curves are flat, else 0 -> STAR_END, which returns
 * 1 / 2. It drives the row's '*' and, on our page, the "Reset [OK hold]" guide. Uses d0, d1, d2, a0. */
cv_star:
 mov 1,d2
 mov (12,sp),d0
 add -1,d0
 cmp 4,d0
 bcc 9f
 clr d1                           /* v0.30 test 9: the curves against the film's built-in (flat without CURVES.BIN) */
 call ck_star,[d3,a2,a3],16
9:
 jmp STAR_END

/* cv_dty: `call cv_dty,[d2,d3,a2,a3],20`: P dirty (saved at the next half-press / on leaving Picture Mode), the
 * curves drawn again. Uses d0. */
cv_dty:
 PVAL 1f
 mov 1,d0
 movbu d0,(DIRTY,a2)
1:
 mov (cv_gen),d0
 inc d0
 mov d0,(cv_gen)
 ret [d2,d3,a2,a3],20

/* cv_inf <- .hook_inf (0x611c29c2 in the column's row event function, d2 = the current item): INFO goes to the row's
 * panel for 5397 / 5398 (stock) and RG_IT. cv_rsi <- .hook_rsi (0x611c296f): the held-OK reset the same for 5052 /
 * 5396 / 5397 / 5398 (stock) and RG_IT; 111 its own; else nothing. */
cv_inf:
 exthu d2
 cmp 5397,d2
 beq 1f
 cmp 5398,d2
 beq 1f
 cmp RG_IT,d2
 beq 2f
 cmp MX_IT,d2
 beq 2f
 jmp INF_NO
2:
 mov (8,sp),a0                    /* mix test 6 (owner: always the outer look): the H&S panel ((4, the column)) keeps */
 mov (4,a0),a0                    /* its look in a two-entry selector ((124, panel); om-emu): INFO sends it "up" and */
 cmp 0,a0                         /* OK, and the entry it lands on (0 outer: dials over our two values, 1 middle) goes */
 beq 1f                           /* to +122 and 2191. On our rows the selector is put on entry 1 first, so INFO always */
 mov (HS_PSEL,a0),a0              /* lands on the outer look; INFO still reaches the panel, which redraws the page */
 cmp 0,a0
 beq 1f
 movhu (SEL_N,a0),d0
 cmp 2,d0
 bne 1f
 mov 1,d0
 movhu d0,(SEL_I,a0)
1:
 jmp INF_GO
cv_rsi:
 exthu d2
 cmp 5052,d2
 beq 1f
 cmp 5396,d2
 beq 1f
 cmp 5397,d2
 beq 1f
 cmp 5398,d2
 beq 1f
 cmp RG_IT,d2
 beq 1f
 cmp MX_IT,d2
 beq 1f
 cmp 111,d2
 bne 2f
 jmp RSI_111
2:
 jmp RSI_NO
1:
 jmp RSI_GO

.section .hook_inf,"ax"
 jmp cv_inf                       /* stock 0x611c29c2: exthu d2; cmp 5397,d2 */
.section .hook_rsi,"ax"
 jmp cv_rsi                       /* stock 0x611c296f: exthu d2; cmp 5052,d2 */
.section .ext12,"ax"

/* cv_ic <- .hook_ic (the picture lookup, d0 id -> a0 its slot, `retf`): our pictures CVI0.., and while the page is
 * on the curve page's swaps (above); else ar_ic. Uses d1, a0 (cv_pic keeps the rest). */
cv_ic:
 mov d0,d1
 exthu d1
 cmp CVI0,d1
 bcs 1f
 cmp CVI0 + CVI_N,d1
 bcc 1f
 add -CVI0,d1
 asl2 d1
 mov cv_ent,a0
 add d1,a0
 retf [],0
1:
 mov mdr,d1                       /* mix test 5 (owner: "turn the center dial and number black"): on our pages the */
 cmp HS_HDRAW,d1                  /* H&S header's middle (its dial symbol, name, number) clear. The header's draw */
 bne 18f                          /* (return HS_HDRAW) passes in a0 the layout record of the spot: the middle's are */
 mov (cv_on),d1                   /* HS_MID0.. (om-emu, in both of the panel's looks); the left and right values' */
 cmp 0,d1                         /* records lie below and above, so their pictures, which the middle shares, stay */
 beq 12f
 cmp 1,d1                         /* colour menu (test 7, spec section 4): on RGB the right value's sign records */
 bne 15f                          /* ("±", "+") get a clear picture (14 x 30; the glyphs are 13 x 30), so it reads */
 cmp HS_RPM,a0                    /* "Pt 2". Each header lookup is followed at once by a second one for the same id */
 beq 17f                          /* (return HS_DRAW2, om-emu) whose picture is the one drawn: cv_sgn marks it */
 cmp HS_RPLUS,a0
 bne 15f
17:
 mov 1,d1
 mov d1,(cv_sgn)
 mov cv_ent + 4 * (CVI_N + 1),a0
 retf [],0
18:
 cmp HS_DRAW2,d1
 bne 12f
 mov (cv_sgn),d1
 cmp 0,d1
 beq 12f
 mov 0,d1
 mov d1,(cv_sgn)
 mov (cv_on),d1
 cmp 1,d1
 bne 12f
 mov cv_ent + 4 * (CVI_N + 1),a0
 retf [],0
15:
 mov 0,d1
 mov d1,(cv_sgn)
 mov a0,d1
 add -HS_MID0,d1
 cmp HS_MIDN,d1
 bcc 12f
 cmp HS_MLAB - HS_MID0,d1         /* test 7: the "Mid" label's record -> the colour's name in its colour */
 beq 16f
 mov cv_ent + 4 * CVI_N,a0        /* a clear picture the size of the slot (a small one left old pixels, om-emu) */
 retf [],0
16:
 movbu (cv_c),d1
 add 10,d1
 asl2 d1
 mov cv_ent,a0
 add d1,a0
 retf [],0
12:
 mov d0,d1
 exthu d1
 mov (cv_on),a0
 cmp 0,a0
 beq 8f
 cmp 10912,d1                     /* mix test 6, a backstop: the middle look's full dial pictures (10912 / 10913, */
 beq 13f                          /* 10919) cleared on our pages, by any lookup */
 cmp 10913,d1
 beq 13f
 cmp 10919,d1
 bne 14f
13:
 mov cv_ent + 4 * CVI_N,a0
 retf [],0
14:
 mov cv_ent,a0                    /* entry 0: clear */
 cmp 4147,d1
 bcs 3f
 cmp 4177,d1
 bcs 7f                           /* the halves */
 cmp 4207,d1
 bcs cv_pic                       /* the middle curves: ours */
3:
 cmp 4331,d1                      /* test 7: "Mid" (any other lookup) -> the colour's name, as above */
 beq 16b
 cmp 4208,d1
 bne 4f
 mov (cv_on),a0                   /* test 7 (spec section 4): "Sh" -> "Level" on RGB, "Sat" on Mix */
 cmp 2,a0
 beq 31f
 mov cv_ent + 4 * 9,a0
 retf [],0
31:
 mov cv_ent + 4 * 7,a0
 retf [],0
4:
 cmp 4207,d1
 bne 5f
 mov (cv_on),a0
 cmp 2,a0
 beq 41f
 mov cv_ent + 16,a0               /* "Hi" -> "Pt" */
 retf [],0
41:
 mov cv_ent + 4 * 8,a0            /* colour mix: "Hue" */
 retf [],0
5:
 cmp 16247,d1
 beq 6f
 cmp 16248,d1
 bne 8f
6:
 add 20,a0                        /* the guide */
7:
 retf [],0
8:
 jmp ar_ic

/* cv_pic: (from cv_ic) our curves' picture, drawn again when anything changed (cv_gen) -> a0 = its slot */
cv_pic:
 movm [d2,d3,a2,a3],(sp)
 add -8,sp
 mov mdr,d2
 mov d2,(4,sp)
 mov (cv_gen),d0
 mov (cv_dgen),d1
 cmp d1,d0
 beq 1f
 mov d0,(cv_dgen)
 call cv_draw,[d2,d3,a2,a3],128
1:
 mov (4,sp),d2
 mov d2,mdr
 add 8,sp
 movm (sp),[d2,d3,a2,a3]
 mov cv_slot,a0
 retf [],0

/* cv_draw: `call cv_draw,[d2,d3,a2,a3],128`: COLOR cv_k's three curves as a 300 x 300 OSD type-11 picture (the curve
 * layer's palette: white 14, black 2, grey 20, cv_col) at
 * CV_WRK + CW_ST, cv_desc's size and payload. Each column's span of each curve (lo / hi: this and the last column's
 * rows, 3 px for the selected colour) and each row's range of such columns (CW_XR), then row by row: the diagonal, the other two, the selected one, its 5 points
 * (the selected one white, bigger: radius 8, else 5), runs packed five 12-bit tokens a 64-bit word. Locals: (4) k, (8) c, (12) p,
 * (16) y / x, (20) write pointer, (24) / (28) the word being packed, (32) tokens in it, (36) channel, (40) last row,
 * (44) live[k], (48..59) points' rows (u16), (60) colour, (64) the row's x, (68) run start, (72) half width,
 * (76) flat, (80) r, (84) dy, (88) point i. */
 .set CV_PX0, 0
cv_draw:
 mov (cv_on),d0                   /* colour mix: the Mix page's picture (mx_pre, mx_line) */
 cmp 2,d0
 bne cvd_rgb
 call mx_pre,[d2,d3,a2,a3],20
 movbu (cv_c),d0
 mov d0,(8,sp)
 jmp cvd_st
cvd_rgb:
 mov (cv_k),d0
 cmp 4,d0
 bcs 1f
 clr d0
1:
 mov d0,(4,sp)
 call cv_lk,[],0
 mov a0,(44,sp)
 movbu (cv_c),d0
 mov d0,(8,sp)
 movbu (cv_p),d0
 mov d0,(12,sp)
 clr d0                           /* 1. the spans, channel by channel */
 mov d0,(36,sp)
10:
 mov (36,sp),d0
 mov d0,d1
 add d1,d1
 add d0,d1
 add d1,d1                        /* 6 ch */
 mov (44,sp),a0
 add d1,a0
 mov a0,a2
 mov 6,d1
 mov 1,d2                         /* flat? */
11:
 movbu (a2),d0
 cmp 0,d0
 beq 12f
 clr d2
12:
 inc a2
 add -1,d1
 bne 11b
 mov d2,(76,sp)
 cmp 0,d2
 bne 13f
 mov cv_pd,a1
 call cv_prm,[d2,d3,a2,a3],64
13:
 clr d0                           /* half width: 1 for the selected colour */
 mov (36,sp),d1
 mov (8,sp),d2
 cmp d1,d2
 bne 14f
 mov 1,d0
14:
 mov d0,(72,sp)
 clr d0
 mov d0,(16,sp)                   /* x */
 mov -1,d0
 mov d0,(40,sp)
 mov (36,sp),d0                   /* this channel's row ranges: all empty */
 mov 1200,d1
 mul d1,d0
 mov CV_WRK + CW_XR,a0
 add d0,a0
 mov 0x0000ffff,d0
 mov 300,d1
151:
 mov d0,(a0)
 add 4,a0
 add -1,d1
 bne 151b
15:
 mov (16,sp),d0
 mov 14024,d1
 mul d1,d0
 lsr 10,d0                        /* t = x 4095 / 299 */
 mov d0,d2
 mov (76,sp),d1
 cmp 0,d1
 bne 16f
 mov cv_pd,d1
 call cv_d,[d2,d3,a2,a3],44
 add d0,d2
16:
 cmp 0,d2
 bge 161f
 clr d2
161:
 cmp 4095,d2
 ble 162f
 mov 4095,d2
162:
 mov 4787,d1
 mul d1,d2
 lsr 16,d2
 mov 299,d0
 sub d2,d0                        /* this column's row */
 mov (40,sp),d1
 cmp 0,d1
 bge 17f
 mov d0,d1
17:
 mov d0,(40,sp)
 mov d0,d2                        /* lo = min - w, hi = max + w */
 mov d1,d3
 cmp d3,d2
 ble 18f
 mov d1,d2
 mov d0,d3
18:
 mov (72,sp),d1
 sub d1,d2
 add d1,d3
 cmp 0,d2
 bge 181f
 clr d2
181:
 cmp 299,d3
 ble 182f
 mov 299,d3
182:
 mov (36,sp),d0                   /* lo[ch][x], hi[ch][x] */
 mov 600,d1
 mul d1,d0
 mov (16,sp),d1
 add d1,d1
 add d1,d0
 mov CV_WRK + CW_LO,a0
 add d0,a0
 movhu d2,(a0)
 movhu d3,(CW_HI,a0)
 mov (36,sp),d0                   /* rows lo..hi: this x is in their range (x only grows) */
 mov 1200,d1
 mul d1,d0
 mov d2,d1
 asl2 d1
 add d1,d0
 mov CV_WRK + CW_XR,a0
 add d0,a0
 sub d2,d3
 inc d3
 mov (16,sp),d0
183:
 movhu (a0),d1
 cmp 300,d1
 bcs 184f
 movhu d0,(a0)
184:
 movhu d0,(2,a0)
 add 4,a0
 add -1,d3
 bne 183b
 mov (16,sp),d0
 inc d0
 mov d0,(16,sp)
 cmp 300,d0
 bcs 15b
 mov (36,sp),d0
 inc d0
 mov d0,(36,sp)
 cmp 3,d0
 bcs 10b
 clr d2                           /* 2. the selected colour's points: rows (u16 at (48 + 2 i)) */
20:
 mov (8,sp),d0
 mov d0,d1
 add d1,d1
 add d0,d1
 add d1,d1
 add d2,d1
 cmp 0,d2
 beq 201f
 inc d1                           /* point -> value: 0, 2, 3, 4, 5 */
201:
 mov (44,sp),a0
 movbu (d1,a0),d0
 extb d0
 mov CV_STEP,d1
 mul d1,d0
 mov d2,d1
 asl2 d1
 mov cv_h0,a0
 add d1,a0
 mov (a0),d1
 add d1,d0
 cmp 0,d0
 bge 21f
 clr d0
21:
 cmp 4095,d0
 ble 22f
 mov 4095,d0
22:
 mov 4787,d1
 mul d1,d0
 lsr 16,d0
 mov 299,d1
 sub d0,d1
 mov sp,a0
 add 48,a0
 mov d2,d0
 add d0,d0
 movhu d1,(d0,a0)
 inc d2
 cmp 5,d2
 bcs 20b
cvd_st:
 mov CV_WRK + CW_ST,a0            /* 3. the stream: its header, then row by row */
 mov 0x0b12b12b,d0                /* 300 x 300, type 11 */
 mov d0,(a0)
 add 4,a0
 mov a0,(cv_wp)
 clr d0
 mov d0,(cv_wn)
 mov d0,(16,sp)                   /* y */
30:
 mov (cv_wp),d0                   /* room for one more row (300 tokens at worst) */
 cmp CV_WRK + CW_END - 520,d0
 bcs 31f
 clr d0
 mov d0,(cv_desc + 12)            /* too big: nothing shown */
 jmp 99f
31:
 mov CV_WRK + CW_ROW,a0           /* the row clear, three words a turn */
 clr d0
 mov 25,d1
32:
 mov d0,(a0)
 mov d0,(4,a0)
 mov d0,(8,a0)
 add 12,a0
 add -1,d1
 bne 32b
 mov (cv_on),d0                   /* colour mix: its row instead */
 cmp 2,d0
 bne cvd_crv
 mov (16,sp),d0
 call mx_line,[d2,d3,a2,a3],20
 jmp cvd_enc
cvd_crv:
 mov CV_WRK + CW_ROW,a0           /* the diagonal */
 mov 299,d0
 mov (16,sp),d1
 sub d1,d0
 mov 20,d1
 movbu d1,(d0,a0)
 clr d3                           /* the curves: the other two, then the selected one */
33:
 mov (8,sp),d2
 add 1,d2
 add d3,d2
 cmp 3,d2
 bcs 34f
 add -3,d2
34:
 cmp 2,d3
 bne 341f
 mov (8,sp),d2
341:
 mov d2,d0                        /* its colour: bright if selected */
 asl 1,d0
 cmp 2,d3
 bne 342f
 inc d0
342:
 mov cv_col,a0
 movbu (d0,a0),d0
 mov d0,(60,sp)
 mov 600,d0
 mul d2,d0
 mov d0,d1
 add d1,d1
 mov CV_WRK + CW_LO,a1
 add d0,a1                        /* lo[ch] */
 mov (16,sp),d2                   /* y */
 mov d2,d0
 asl2 d0
 add d0,d1
 mov CV_WRK + CW_XR,a0
 add d1,a0
 movhu (a0),d0                    /* only columns xmin..xmax can hold this row */
 movhu (2,a0),d1
 cmp d0,d1
 bcs 37f
 sub d0,d1
 inc d1
 mov CV_WRK + CW_ROW,a0
 add d0,a0
 add d0,d0
 add d0,a1
35:
 movhu (a1),d0
 cmp d0,d2
 blt 36f
 movhu (CW_HI,a1),d0
 cmp d0,d2
 bgt 36f
 mov (60,sp),d0
 movbu d0,(a0)
36:
 inc a0
 add 2,a1
 add -1,d1
 bne 35b
37:
 inc d3
 cmp 3,d3
 bcs 33b
 clr d0                           /* the selected colour's points */
 mov d0,(88,sp)
40:
 mov (88,sp),d2
 mov sp,a0
 add 48,a0
 mov d2,d0
 add d0,d0
 movhu (d0,a0),d0
 mov (16,sp),d1
 sub d0,d1
 mov d1,(84,sp)                   /* dy */
 mov 5,d0                         /* r: 5, the selected point 8; its fill white, else the colour */
 mov (8,sp),d1
 asl 1,d1
 inc d1
 mov cv_col,a0
 movbu (d1,a0),d1
 mov (12,sp),d3
 cmp d3,d2
 bne 41f
 mov 8,d0
 mov 14,d1
41:
 mov d1,(100,sp)
 mov d0,(80,sp)
 mov d0,d1
 mul d0,d1
 mov d1,(92,sp)                   /* r^2 */
 mov d0,d1
 add -2,d1
 mul d1,d1
 mov d1,(96,sp)                   /* (r - 2)^2 */
 mov (84,sp),d1
 cmp 0,d1
 bge 42f
 not d1
 inc d1
42:
 cmp d0,d1
 bgt 49f                          /* not on this row */
 mov d2,d1
 asl2 d1
 mov cv_px,a0
 add d1,a0
 mov (a0),d1
 mov d1,(64,sp)                   /* the point's column */
 mov d0,d3
 not d3
 inc d3                           /* dx = -r .. r */
43:
 mov (64,sp),d2
 add d3,d2
 cmp 0,d2
 blt 48f
 cmp 299,d2
 bgt 48f
 mov d3,d0
 mul d3,d0
 mov (84,sp),d1
 mul d1,d1
 add d1,d0                        /* dx^2 + dy^2 */
 mov (92,sp),d1
 cmp d1,d0
 bgt 48f
 mov (96,sp),d1
 cmp d1,d0
 bgt 44f
 mov (100,sp),d1                  /* inside: the fill */
 bra 45f
44:
 mov 2,d1                         /* the ring: black */
45:
 mov CV_WRK + CW_ROW,a0
 movbu d1,(d2,a0)
48:
 inc d3
 mov (80,sp),d0
 cmp d0,d3
 ble 43b
49:
 mov (88,sp),d0
 inc d0
 mov d0,(88,sp)
 cmp 5,d0
 bcs 40b
cvd_enc:
 mov CV_WRK + CW_ROW,a2           /* the row's runs (<= 16, never past its end) as tokens */
 clr d3
50:
 mov a2,a0
 add d3,a0
 movbu (a0),d0
 cmp 0,d0
 beq 55f
 mov d3,d1                        /* a1: the run's end at most */
 add 16,d1
 cmp 300,d1
 ble 501f
 mov 300,d1
501:
 mov a2,a1
 add d1,a1
51:
 inc a0
 cmp a1,a0
 bcc 52f
 movbu (a0),d2
 cmp d0,d2
 beq 51b
52:
 mov a0,d1
 mov a2,d2
 sub d2,d1                        /* the next run's start */
 mov d1,d2
 sub d3,d1
 mov d2,d3
 asl 4,d0
 add -1,d1
 or d1,d0
 call cv_tok,[d2,d3],12
 cmp 300,d3
 bcs 50b
 bra 59f
55:                               /* colour 0: up to the next pixel of another colour (a0) or the row's end, word by */
 mov a2,a1                        /* word where aligned, then the same 16-pixel runs as above */
 add 300,a1
56:
 inc a0
 cmp a1,a0
 bcc 58f
 mov a0,d1
 and 3,d1
 beq 57f
 movbu (a0),d1
 cmp 0,d1
 beq 56b
 bra 58f
57:
 mov (a0),d1
 cmp 0,d1
 bne 571f
 add 4,a0
 cmp a1,a0
 bcs 57b
 bra 58f
571:
 movbu (a0),d1
 cmp 0,d1
 bne 58f
 inc a0
 bra 571b
58:
 mov a0,d1
 mov a2,d2
 sub d2,d1
 mov d1,d2
 sub d3,d2                        /* d2 = the length, d3 = the next run's start */
 mov d1,d3
581:
 cmp 16,d2
 bcs 582f
 mov 15,d0
 call cv_tok,[d2,d3],12
 add -16,d2
 bra 581b
582:
 cmp 0,d2
 beq 583f
 mov d2,d0
 add -1,d0
 call cv_tok,[d2,d3],12
583:
 cmp 300,d3
 bcs 50b
59:
 mov (16,sp),d0                   /* next row */
 inc d0
 mov d0,(16,sp)
 cmp 300,d0
 bcc 60f
 jmp 30b
60:
 mov (cv_wn),d0                   /* the last word, then the descriptor */
 cmp 0,d0
 beq 61f
 mov (cv_wp),a0
 mov (cv_wl),d0
 mov d0,(a0)
 mov (cv_wh),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(cv_wp)
61:
 mov (cv_wp),d0
 add -(CV_WRK + CW_ST),d0
 mov d0,(cv_desc + 12)
 mov CV_WRK + CW_ST,d0
 mov d0,(cv_desc + 16)
99:
 ret [d2,d3,a2,a3],128

/* cv_tok: `call cv_tok,[d2,d3],12`, d0 = a 12-bit token: packed five a 64-bit word (cv_wl / cv_wh, cv_wn of them),
 * the full word stored at cv_wp. Uses d0, d1, a0. */
cv_tok:
 mov (cv_wn),d1
 cmp 0,d1
 bne 1f
 mov d0,(cv_wl)
 clr d2
 mov d2,(cv_wh)
 bra 8f
1:
 cmp 1,d1
 bne 2f
 asl 12,d0
 mov (cv_wl),d2
 or d0,d2
 mov d2,(cv_wl)
 bra 8f
2:
 cmp 2,d1
 bne 3f
 mov d0,d2
 asl 24,d2
 mov (cv_wl),d3
 or d2,d3
 mov d3,(cv_wl)
 lsr 8,d0
 mov d0,(cv_wh)
 bra 8f
3:
 cmp 3,d1
 bne 4f
 asl 4,d0
 mov (cv_wh),d2
 or d0,d2
 mov d2,(cv_wh)
 bra 8f
4:
 asl 16,d0
 mov (cv_wh),d2
 or d0,d2
 mov (cv_wp),a0
 mov (cv_wl),d3
 mov d3,(a0)
 mov d2,(4,a0)
 add 8,a0
 mov a0,(cv_wp)
 mov -1,d1
8:
 inc d1
 mov d1,(cv_wn)
 ret [d2,d3],12

 .balign 4
cv_col:                           /* per colour: dim, bright. The curve layer has 32 colours, none red or blue (its
                                   * palette 0x614a5fe0): red = orange 6 / 4, green 8 / 9; test 2 (owner: "the line
                                   * isn't blue"): blue = 30 / 29, unused fillers made blue by build.py (31 fills
                                   * whole screens; 27..30 changed nothing on 29 screens in om-emu) */
 .byte 6, 4, 8, 9, 30, 29
 .balign 4
cv_px:                            /* the 5 points' columns and inputs (test 4: the grid's quarter lines) */
 .long 0, 75, 150, 224, 299
cv_h0:
 .long 0, 1024, 2048, 3072, 4095
cv_pd:
 .space 64
cv_on:
 .long 0
cv_sgn:                           /* test 7: 1 between RGB's right sign lookup and its second (drawn) lookup */
 .long 0
cv_gen:
 .long 0
cv_dgen:
 .long -1
cv_k:
 .long 0
cv_wp:
 .long 0
cv_wl:
 .long 0
cv_wh:
 .long 0
cv_wn:
 .long 0
cv_slot:
 .long cv_desc
cv_desc:                          /* format 14, 300 x 300, as the camera's curve pictures; size and payload from cv_draw */
 .short 14, 300, 300, 8, 0, 0
 .long 0, 0, 0, 0
cv_c:
 .byte 0
cv_p:
 .byte 0
cv_okd:
 .byte 0
cv_rst:
 .byte 0
.section .ext11,"ax"                /* colour mix: the pictures moved here (ext12 is nearly full) */
 .balign 4
 .include "rgbpics.inc"
