/* ------------------------------------------------------------------ per-film colour mix (feature/rgb-curves)
 * A 3 x 3 colour matrix of ours per COLOR / film, put into the camera's own colour matrix for COLOR jobs.
 * The matrix function 0x605147a2 (research/NOTES.md, "Colour matrix per film") builds the job's matrix from the
 * camera's base matrix (a filter's, a picture mode's), then 0x605144ef scales each row to sum 128 and writes the job's
 * nine values. .hook_mx takes that last call (0x6051485a): for a COLOR job (key 11, or 12 with no filter, as split
 * toning) of the development function split toning runs in (its caller 0x605196f6: photos and live view, camera-tested
 * with probe m1; the other caller 0x6051a6fb is left stock), when COLOR k has a mix, ours x the matrix so far (the
 * camera's own 3 x 3 multiply 0x60514290: ours acts on the camera's colours), then the camera's row scaling, so greys
 * stay grey. Nothing before the films are read at the first half-press (cv_ok), as split toning.
 * The mix (owner's choice, mockup C, 2026-11-15): for each of red, green, blue (j) a hue h and a strength s, -7..+7,
 * in the 8 bytes each slot kept since test 1b (cv_ram slot + 18: h R, s R, h G, s G, h B, s B, then 2 bytes 0). Hue
 * moves colour j toward the next one (R -> G -> B -> R: red toward yellow, green toward cyan, blue toward purple),
 * strength makes it stronger: column j of ours gets M[next][j] = u (h - s), M[prev][j] = u (-h - s), u = MX_UNIT / 256;
 * each diagonal makes its row 256. All 0 = stock (research/colourmix/model.py is the model). */
 .set MX_UNIT, 8                  /* one step = 8 / 256 (~3 %) */
 .if MX_UNIT - 8
 .error "mx_go multiplies by 8 with asl 3"
 .endif

.section .hook_mx,"ax"
 jmp mx_g                         /* stock 0x6051485a: call 0x605144ef,[d2,d3,a2,a3],20. mx_g (editor.s): mx_go once section 6 is in */

.section .ext12,"ax"
/* mx_go <- .hook_mx, in the matrix function's frame F (84: (84,F) its return address, (96,F) the request R for the
 * caller 0x605196f6); d3 the key, a2 the matrix so far, a0 = d2 = F + 48 the output. Ends as the stock call, then
 * MX_BACK with d2, d3 as they came (the rest of the function uses them). Our frame: movm 16 B, then 32: (0) call slot,
 * (4..21) our matrix, (24) the matrix so far, (28) the free work matrix. Uses d0, d1, a0, a1, MDR. */
 .set MXF, 48                     /* (x, F) = (x + MXF, sp) */
mx_go:
 movm [d2,d3,a2,a3],(sp)
 add -32,sp
 mov a2,(24,sp)
 movbu (cv_ok),d0                 /* nothing before the films are read (first half-press) */
 cmp 0,d0
 beq 80f
 mov (84 + MXF,sp),d0             /* the development function split toning runs in */
 cmp MX_RET,d0
 bne 80f
 cmp 11,d3
 beq 1f
 cmp 12,d3
 bne 80f
 mov (96 + MXF,sp),a0             /* 12: only with no filter (as split toning) */
 movbu (1731,a0),d0
 cmp 0,d0
 bne 80f
1:
 call mx_photo,[],0               /* mix test 2 (owner: "Photos only"): video (recording, its live view) stays stock */
 cmp 0,d0
 beq 80f
 mov (108 + MXF,sp),a0            /* live look: the development function's (24,sp) is its context C + 12 */
 add -12,a0
 mov (96 + MXF,sp),a1             /* its request R */
 call lv_ref,[d2,d3,a2,a3],16
 call mx_any,[d2],8               /* no mix on any COLOR: no getter call */
 cmp 0,d0
 beq 80f
 mov 63153,d0                     /* effective COLOR profile number (as st_run) */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 add -1,d0
 cmp 4,d0
 bcc 80f
 call mx_lk,[],4                  /* a0 = COLOR k's six values */
 mov a0,a1
 clr d0
 mov 6,d1
3:
 movbu (a0),d2
 or d2,d0
 inc a0
 add -1,d1
 bne 3b
 cmp 0,d0
 beq 80f                          /* no mix: stock */
 movbu (a1),d0                    /* red: M[G][R] (+6), M[B][R] (+12) */
 extb d0
 movbu (1,a1),d1
 extb d1
 mov d0,d2
 sub d1,d2
 asl 3,d2
 movhu d2,(4 + 6,sp)
 mov d0,d2
 add d1,d2
 not d2
 inc d2
 asl 3,d2
 movhu d2,(4 + 12,sp)
 movbu (2,a1),d0                  /* green: M[B][G] (+14), M[R][G] (+2) */
 extb d0
 movbu (3,a1),d1
 extb d1
 mov d0,d2
 sub d1,d2
 asl 3,d2
 movhu d2,(4 + 14,sp)
 mov d0,d2
 add d1,d2
 not d2
 inc d2
 asl 3,d2
 movhu d2,(4 + 2,sp)
 movbu (4,a1),d0                  /* blue: M[R][B] (+4), M[G][B] (+10) */
 extb d0
 movbu (5,a1),d1
 extb d1
 mov d0,d2
 sub d1,d2
 asl 3,d2
 movhu d2,(4 + 4,sp)
 mov d0,d2
 add d1,d2
 not d2
 inc d2
 asl 3,d2
 movhu d2,(4 + 10,sp)
 movhu (4 + 2,sp),d0              /* the diagonals: each row 256 */
 exth d0
 movhu (4 + 4,sp),d1
 exth d1
 add d1,d0
 mov 256,d2
 sub d0,d2
 movhu d2,(4,sp)
 movhu (4 + 6,sp),d0
 exth d0
 movhu (4 + 10,sp),d1
 exth d1
 add d1,d0
 mov 256,d2
 sub d0,d2
 movhu d2,(4 + 8,sp)
 movhu (4 + 12,sp),d0
 exth d0
 movhu (4 + 14,sp),d1
 exth d1
 add d1,d0
 mov 256,d2
 sub d0,d2
 movhu d2,(4 + 16,sp)
 mov sp,a0                        /* the free work matrix of the function: F + 8, or F + 28 when the matrix so far */
 mov a0,d0                        /* is there */
 add MXF + 8,d0
 mov (24,sp),d1
 cmp d0,d1
 bne 8f
 add 20,d0
8:
 mov d0,(28,sp)
 mov d0,a0                        /* ours x the matrix so far (ours acts on the camera's colours) */
 mov sp,a1
 add 4,a1
 mov (24,sp),d0
 call mx_mul,[d2,d3,a2,a3],116
 mov (28,sp),d0
 mov d0,(24,sp)
 mov (mx_n),d0
 inc d0
 mov d0,(mx_n)
80:
 mov sp,a0                        /* the stock call: a0 = F + 48, a1 = the matrix */
 add MXF + 48,a0
 mov (24,sp),a1
 call mx_row,[d2,d3,a2,a3],20
 add 32,sp
 movm (sp),[d2,d3,a2,a3]
 jmp MX_BACK

/* mx_photo: `call mx_photo,[],0` -> d0 1 in a photo mode (owner, mix test 1's clip: the mix and the curves are for
 * photos only): the mode's code 1..5 / 53..57, or, while it is 0 (power-on, or the movie / S&Q position in om-emu),
 * the photo / movie / S&Q switch 0xa32d9d0d = 2. ss_photo's test (camera-tested, custom modes) without its diagnostic
 * write, so the image task only reads. Uses d0, a0. */
mx_photo:
 mov (rc_in),a0
 cmp 0,a0
 beq 3f
 movbu (24,a0),d0
 cmp 0,d0
 beq 3f
 cmp 6,d0
 bcs 1f
 cmp 53,d0
 bcs 8f
 cmp 58,d0
 bcc 8f
1:
 mov 1,d0
 ret [],0
3:
 movbu (0xa32d9d0d),d0
 cmp 2,d0
 beq 1b
8:
 clr d0
 ret [],0

/* mx_any: `call mx_any,[d2],8` -> d0 != 0 when any COLOR has a mix. Uses d0, d1, a0, a1. */
mx_any:
 mov cv_ram + CV_LV + 18,a1
 clr d0
 mov 4,d1
1:
 mov a1,a0
 movbu (a0),d2
 or d2,d0
 movbu (1,a0),d2
 or d2,d0
 movbu (2,a0),d2
 or d2,d0
 movbu (3,a0),d2
 or d2,d0
 movbu (4,a0),d2
 or d2,d0
 movbu (5,a0),d2
 or d2,d0
 add CV_ESZ,a1
 add -1,d1
 bne 1b
 ret [d2],8

/* mx_lk: `call mx_lk,[],4`, d0 = k -> a0 = live[k]'s six values. mx_zk: `call mx_zk,[d2],8`, d0 = k: COLOR k's
 * mix off (the Mix page's reset, e_rst). Use d0, d1, a0, MDR. */
mx_lk:
 call cv_lk,[],0
 add 18,a0
 ret [],4
mx_zk:
 jmp ck_mzk                       /* v0.30 test 9: zero, or with CURVES.BIN the film's built-in */

 .balign 4
mx_n:                             /* matrices put in (a count, for om-emu) */
 .long 0

/* ------------------------------------------------------------------ live look (2026-11-18, feature/live-look-refresh)
 * The camera rebuilds a job's tone tables only when the job's context C asks for it (C+60, a mask per pass): the RGB
 * gamma stage 0x60516ad9 copies the picture mode's curve into O+1252.. (mask 0x2230001e), the luminance LUT 0x60518db2
 * (0x4134063e), the tone curve 0x60518fa4 (0x3024ae). Split toning, Tone Balance and the RGB curves (st_run) and
 * Blacks / Whites (tone) work on those tables, so live view showed a change of ours only when the camera rebuilt them
 * itself (a half-press, AF, its own tone settings). om-emu, the development function 0x605196b4 on a fake live-view
 * job: after a change, a pass with C+60 0 keeps the old tables (~3k instructions); with bit 3 (8, in all three masks)
 * it copies, bends and builds them anew (~50k). lv_ref sets that bit once per change and output, as the camera's own
 * tone settings do.
 * `call lv_ref,[d2,d3,a2,a3],16` from mx_go after its gates (section 6 in, the films read, the development function
 * 0x605196b4's call, a COLOR job, a photo mode), a0 = the context C, a1 = the request R. A fingerprint of the tone
 * inputs of COLOR 1-4 (P slot +33 Tone Balance, +47 / +48 Blacks / Whites, +55..+58 split toning; cv_ram live[4]'s
 * curves, not the mix) is kept per output O (C+12) in lv_tab; when it differs from O's last one, C+60 |= LV_TONE.
 * An output not in the table yet is only recorded. Still development (R+14 0x1000) builds fresh: left alone.
 * Uses d0, d1, a0, a1. Stores: C+60, lv_tab, lv_rr, lv_n. */
 .set LV_TONE, 8
 .set LV_N, 4                     /* outputs kept, a power of 2 */
 .macro LVH
 mov d2,d3
 asl 5,d3
 add d3,d2
 add d0,d2
 .endm
lv_ref:
 mov a0,a3                        /* a3 = C */
 movhu (14,a1),d0
 cmp 0x1000,d0
 beq 9f
 PVAL 9f                          /* a2 = P (uses d3, a2) */
 clr d2                           /* d2 = the fingerprint, h = 33 h + x */
 add 32,a2                        /* COLOR 1's slot */
 mov 4,d1
1:
 .irp o, 33, 47, 48, 55, 56, 57, 58
 movbu (\o,a2),d0
 LVH
 .endr
 add 64,a2
 add -1,d1
 bne 1b
 mov cv_ram + CV_LV,a0            /* live[k]'s curves: 18 bytes of its 26 */
 mov 4,d1
2:
 .irp o, 0, 2, 4, 6, 8, 10, 12, 14, 16
 movhu (\o,a0),d0
 LVH
 .endr
 add CV_ESZ,a0
 add -1,d1
 bne 2b
 mov (12,a3),d3                   /* O */
 mov lv_tab,a0
 mov LV_N,d1
4:
 mov (a0),d0
 cmp d3,d0
 beq 6f
 add 8,a0
 add -1,d1
 bne 4b
 movbu (lv_rr),d0                 /* a new output: recorded in the next entry, round robin */
 mov d0,d1
 inc d1
 and LV_N - 1,d1
 movbu d1,(lv_rr)
 asl 3,d0
 mov lv_tab,a0
 add d0,a0
 mov d3,(a0)
 mov d2,(4,a0)
 bra 9f
6:
 mov (4,a0),d0
 cmp d2,d0
 beq 9f
 mov d2,(4,a0)
 mov (60,a3),d0                   /* changed since O's last pass: this pass rebuilds O's tone tables */
 or LV_TONE,d0
 mov d0,(60,a3)
 mov (lv_n),d0
 inc d0
 mov d0,(lv_n)
9:
 ret [d2,d3,a2,a3],16

 .balign 4
lv_tab:                           /* LV_N x {output O, its fingerprint} */
 .space 8 * LV_N
lv_n:                             /* passes given the tone bit (a count, for om-emu) */
 .long 0
lv_rr:                            /* the entry a new output takes */
 .byte 0
 .balign 4

/* ------------------------------------------------------------------ the Mix page (mockup C, owner 2026-11-15)
 * Row MX_IT under the RGB row: the RGB page's machinery (rgbcurves.inc) with cv_on = 2. INFO = the colour (cv_c,
 * shared with the RGB page), the sub dial (event 0x9031) its hue (Hi, the right header slot under that dial's symbol,
 * label "Hue" in that colour), the main dial (0x9032) its strength (Sh, the left slot, "Sat"), as the camera's own page
 * pairs them (om-emu); hold OK = COLOR k's mix off. The picture: a ring with the three
 * colours as dots (where each sits now: angle = its start + MX_DEG x hue, radius MXR + 4 x strength), marks where they
 * start, spokes from the centre; the chosen one bigger, ringed white (mx_pre, mx_line, from cv_draw). */
.section .ext12,"ax"
 .set MXC, 150                    /* the ring's centre and radius in the 300 x 300 picture */
 .set MXR, 90
 .set MXG, 20                     /* curve-layer colours: grey (as the curves' diagonal), white */
 .set MXW, 14

/* mx_case: the column's update switch for MX_IT (as cv_case) */
mx_case:
 mov 2,d0
 mov d0,(cv_on)
 mov (cv_gen),d0
 inc d0
 mov d0,(cv_gen)
 jmp HS_CASE

/* lc_mx: the column's left-cell switch for MX_IT (as lc_rg: our "Mix" cell) */
lc_mx:
 mov (20,sp),a3
 mov 1,d0
 add d1,a3
 movbu d0,(a3)
 inc4 a3
 mov mx_l1,a1
 mov 1,d1
 mov a3,(4,sp)
 mov (36,sp),a0
 clr d0
 call LC_PICK,[d2,d3,a2,a3],24
 jmp LC_DONE
 .balign 4
mx_l1:
 .long 0
 .short 3, CVI_MXC
 .long 0x6154b480

/* mx_star: the column's "row changed?" switch for MX_IT (as cv_star): d2 = 1 when COLOR k has no mix */
mx_star:
 mov 1,d2
 mov (12,sp),d0
 add -1,d0
 cmp 4,d0
 bcc 9f
 mov 1,d1                         /* v0.30 test 9: the mix against the film's built-in (off without CURVES.BIN) */
 call ck_star,[d3,a2,a3],16
9:
 jmp STAR_END

/* mx_val: (jumped to from cv_val, its frame `ret [d2,d3],12`) d1 = the slot (0 Hi, 1 Mid, 2 Sh), d2 = k -> d0 = the
 * Mix page's value: Hi (the right slot) = the chosen colour's hue, Sh (the left slot) = its strength, Mid = CV_MIDV.
 * As the camera's own page (om-emu): the sub dial (event 0x9031) changes Hi, the right value, the main dial (0x9032)
 * Sh, the left one, each under its dial's symbol; mx_ev uses the same pairing. */
mx_val:
 cmp 1,d1
 bne 1f
 mov CV_MIDV,d0
 ret [d2,d3],12
1:
 mov d2,d0
 mov d1,d3
 call mx_lk,[],4
 movbu (cv_c),d0
 asl 1,d0
 add d0,a0
 cmp 0,d3
 beq 2f
 inc a0                           /* Sh: the strength (Hi: the hue) */
2:
 movbu (a0),d0
 extb d0
 ret [d2,d3],12

/* mx_ev: (jumped to from cv_ev on the Mix page, its frame; d0 the event, d3 the dials' clicks, -CV_CLK..CV_CLK): the
 * front dial (0x9031) the hue (+ clicks), the rear dial (0x9032) the strength (- clicks, as the RGB page's
 * offset), -7..+7, then cv_dty (saved at the next half-press, drawn again) -> cv_ev80; other events -> cv_ev5. */
mx_ev:
 cmp 0x9031,d0
 beq 1f
 cmp 0x9032,d0
 beq 2f
 jmp cv_ev5
1:
 mov (cv_k),d0
 call mx_lk,[],4
 movbu (cv_c),d0
 asl 1,d0
 add d0,a0
 movbu (a0),d2
 extb d2
 add d3,d2
 bra 3f
2:
 mov (cv_k),d0
 call mx_lk,[],4
 movbu (cv_c),d0
 asl 1,d0
 add d0,a0
 inc a0
 movbu (a0),d2
 extb d2
 sub d3,d2
3:
 cmp -7,d2
 bge 4f
 mov -7,d2
4:
 cmp 7,d2
 ble 5f
 mov 7,d2
5:
 movbu d2,(a0)
 mov 2,d1                         /* v0.30 test 9: the mix is the user's own now */
 call ck_own,[d2,d3,a2,a3],20
 call cv_dty,[d2,d3,a2,a3],20
 jmp cv_ev80

/* cv_zx: `call cv_zx,[d2],8`, d0 = k: the open page's reset: the Mix page -> mx_zk, else cv_zk */
cv_zx:
 mov (cv_on),d1
 cmp 2,d1
 bne 1f
 call mx_zk,[d2],8
 ret [d2],8
1:
 cmp 3,d1                         /* five-point curve: the Blk / Wht page's (b5_zk, curve5.inc) */
 bne 2f
 jmp b5_zk
2:
 call cv_zk,[d2],8
 ret [d2],8

/* mx_pre: `call mx_pre,[d2,d3,a2,a3],20` (cv_draw, before the rows): each colour's dot centre -> mx_px / mx_py.
 * Uses d0, d1, a0, a1, MDR. */
mx_pre:
 mov (cv_k),d0
 cmp 4,d0
 bcs 1f
 clr d0
1:
 call mx_lk,[],4
 mov a0,a2
 clr d3                           /* j */
2:
 movbu (a2),d0                    /* hue -> the angle's entry j x 15 + 7 + h */
 extb d0
 call mx_c7,[],0
 add 7,d0
 mov d3,d1
 mov 15,d2
 mul d2,d1
 add d1,d0
 add d0,d0
 mov d0,a3                        /* its offset in mx_ux / mx_uy */
 movbu (1,a2),d0                  /* strength -> the radius MXR + 4 s */
 extb d0
 call mx_c7,[],0
 asl2 d0
 add MXR,d0
 mov d0,d2
 mov mx_ux,a0
 add a3,a0
 movhu (a0),d1
 exth d1
 mov d2,d0
 mul d1,d0
 asr 10,d0
 add MXC,d0
 mov d3,d1
 asl2 d1
 mov mx_px,a1
 add d1,a1
 mov d0,(a1)
 mov mx_uy,a0
 add a3,a0
 movhu (a0),d1
 exth d1
 mov d2,d0
 mul d1,d0
 asr 10,d0
 add MXC,d0
 mov d3,d1
 asl2 d1
 mov mx_py,a1
 add d1,a1
 mov d0,(a1)
 add 2,a2
 inc d3
 cmp 3,d3
 bcs 2b
 ret [d2,d3,a2,a3],20

/* mx_c7: `call mx_c7,[],0`: d0 clamped to -7..+7 */
mx_c7:
 cmp -7,d0
 bge 1f
 mov -7,d0
1:
 cmp 7,d0
 ble 2f
 mov 7,d0
2:
 ret [],0

/* mx_line: `call mx_line,[d2,d3,a2,a3],20`, d0 = the row y: the Mix picture's row into CV_WRK + CW_ROW (cleared by
 * cv_draw): the ring, its centre, the three start marks, the spokes, the two other dots, the chosen dot (white ring,
 * then its colour). Uses d0, d1, a0, a1, MDR. */
mx_line:
 mov d0,(mx_y)
 mov d0,d2                        /* the ring: dy = |y - MXC| */
 add -MXC,d2
 bge 1f
 not d2
 inc d2
1:
 cmp MXR + 3,d2
 bcc 3f
 mov mx_ro,a0
 add d2,a0
 movbu (a0),d3                    /* outer half width */
 mov mx_ri,a0
 add d2,a0
 movbu (a0),d2                    /* inner (0: none) */
 cmp 0,d3
 beq 3f
 mov MXG,a1
 cmp 0,d2
 bne 2f
 mov MXC,d0
 sub d3,d0
 mov MXC,d1
 add d3,d1
 call mx_fill,[d2,d3],12
 bra 3f
2:
 mov MXC,d0
 sub d3,d0
 mov MXC,d1
 sub d2,d1
 call mx_fill,[d2,d3],12
 mov MXC,d0
 add d2,d0
 mov MXC,d1
 add d3,d1
 call mx_fill,[d2,d3],12
3:
 mov (mx_y),d0                    /* the centre: 5 x 5 */
 add -MXC,d0
 add 2,d0
 cmp 5,d0
 bcc 4f
 mov MXC - 2,d0
 mov MXC + 2,d1
 mov MXG,a1
 call mx_fill,[d2,d3],12
4:
 clr d3                           /* the start marks (mx_tk: x0, y0, x1, y1 each), grey */
5:
 mov d3,d0
 asl 4,d0
 mov mx_tk,a0
 add d0,a0
 mov (a0),d0
 mov d0,(mx_sg)
 mov (4,a0),d0
 mov d0,(mx_sg + 4)
 mov (8,a0),d0
 mov d0,(mx_sg + 8)
 mov (12,a0),d0
 mov d0,(mx_sg + 12)
 mov MXG,a1
 call mx_seg,[d2,d3,a2,a3],20
 inc d3
 cmp 3,d3
 bcs 5b
 clr d3                           /* the spokes, each colour's dim */
6:
 mov MXC,d0
 mov d0,(mx_sg)
 mov d0,(mx_sg + 4)
 mov d3,d0
 asl2 d0
 mov mx_px,a0
 add d0,a0
 mov (a0),d1
 mov d1,(mx_sg + 8)
 mov mx_py,a0
 add d0,a0
 mov (a0),d1
 mov d1,(mx_sg + 12)
 mov d3,d0
 asl 1,d0
 mov cv_col,a0
 add d0,a0
 movbu (a0),d0
 mov d0,a1
 call mx_seg,[d2,d3,a2,a3],20
 inc d3
 cmp 3,d3
 bcs 6b
 clr d3                           /* the two other dots: radius 8, dim */
7:
 movbu (cv_c),d0
 cmp d0,d3
 beq 8f
 mov d3,d0
 asl 1,d0
 mov cv_col,a0
 add d0,a0
 movbu (a0),d0
 mov d0,a1
 mov 8,d1
 mov d3,d0
 call mx_dot,[d2,d3,a2,a3],20
8:
 inc d3
 cmp 3,d3
 bcs 7b
 movbu (cv_c),d3                  /* the chosen one: radius 16 white, then 13 bright */
 cmp 3,d3
 bcc 9f
 mov MXW,a1
 mov 16,d1
 mov d3,d0
 call mx_dot,[d2,d3,a2,a3],20
 mov d3,d0
 asl 1,d0
 inc d0
 mov cv_col,a0
 add d0,a0
 movbu (a0),d0
 mov d0,a1
 mov 13,d1
 mov d3,d0
 call mx_dot,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* mx_dot: `call mx_dot,[d2,d3,a2,a3],20`, d0 = colour j (its centre mx_px / mx_py), d1 = radius r, a1 = palette
 * index: the disc's span on row mx_y. Uses d0, d1, a0, a1, MDR. */
mx_dot:
 mov d1,d3                        /* r */
 asl2 d0
 mov mx_px,a0
 add d0,a0
 mov (a0),a2                      /* cx */
 mov mx_py,a0
 add d0,a0
 mov (a0),d2
 mov (mx_y),d0
 sub d2,d0                        /* dy */
 bge 1f
 not d0
 inc d0
1:
 cmp d3,d0
 bgt 9f
 mul d0,d0                        /* dy^2 */
 mov d3,d2
 mov d3,d1
 mul d1,d1
 add d3,d1                        /* r^2 + r (rounder) */
 sub d0,d1                        /* the room for w^2 */
2:
 mov d2,d0                        /* w from r down while w^2 > room */
 mul d0,d0
 cmp d1,d0
 ble 3f
 add -1,d2
 bra 2b
3:
 mov a2,d0
 sub d2,d0
 mov a2,d1
 add d2,d1
 call mx_fill,[d2,d3],12
9:
 ret [d2,d3,a2,a3],20

/* mx_seg: `call mx_seg,[d2,d3,a2,a3],20`, mx_sg = x0, y0, x1, y1 (words), a1 = palette index: the line's span on row
 * mx_y, 2 px wide. Uses d0, d1, a0, a1, MDR. */
mx_seg:
 mov (mx_sg + 4),d0               /* y0 <= y1 (swap the ends) */
 mov (mx_sg + 12),d1
 cmp d1,d0
 ble 1f
 mov (mx_sg),d2
 mov (mx_sg + 8),d3
 mov d3,(mx_sg)
 mov d2,(mx_sg + 8)
 mov d1,(mx_sg + 4)
 mov d0,(mx_sg + 12)
1:
 mov (mx_y),d2
 mov (mx_sg + 4),d0
 cmp d0,d2
 blt 9f
 mov (mx_sg + 12),d1
 cmp d1,d2
 bgt 9f
 cmp d0,d1
 bne 2f
 mov (mx_sg),d0                   /* flat: the whole span */
 mov (mx_sg + 8),d1
 bra 5f
2:
 mov d2,d0                        /* x at y */
 call mx_xat,[d2,d3],12
 mov d0,a2
 mov (mx_y),d0                    /* x at min(y + 1, y1) */
 inc d0
 mov (mx_sg + 12),d1
 cmp d1,d0
 ble 3f
 mov d1,d0
3:
 call mx_xat,[d2,d3],12
 mov d0,d1
 mov a2,d0
5:
 cmp d1,d0                        /* d0 <= d1 */
 ble 6f
 mov d0,d2
 mov d1,d0
 mov d2,d1
6:
 add -1,d0                        /* 2 px wide */
 call mx_fill,[d2,d3],12
9:
 ret [d2,d3,a2,a3],20

/* mx_xat: `call mx_xat,[d2,d3],12`, d0 = y (y0 <= y <= y1, y0 < y1) -> d0 = x0 + (x1 - x0)(y - y0) / (y1 - y0).
 * Uses d0, d1, MDR. */
mx_xat:
 mov (mx_sg + 4),d1
 sub d1,d0                        /* y - y0 */
 mov (mx_sg + 8),d2
 mov (mx_sg),d1
 sub d1,d2                        /* x1 - x0 */
 mul d2,d0
 mov (mx_sg + 12),d2
 mov (mx_sg + 4),d1
 sub d1,d2                        /* y1 - y0 > 0 */
 ext d0
 div d2,d0
 mov (mx_sg),d1
 add d1,d0
 ret [d2,d3],12

/* mx_fill: `call mx_fill,[d2,d3],12`, d0..d1 (inclusive, clipped to 0..299), a1 = palette index: the row's pixels.
 * Uses d0, d1, a0. */
mx_fill:
 cmp 0,d0
 bge 1f
 clr d0
1:
 cmp 299,d1
 ble 2f
 mov 299,d1
2:
 cmp d1,d0
 bgt 9f
 mov a1,d2
 mov CV_WRK + CW_ROW,a0
 add d0,a0
 sub d0,d1
 inc d1
3:
 movbu d2,(a0)
 inc a0
 add -1,d1
 bne 3b
9:
 ret [d2,d3],12

 .balign 4
mx_y:
 .long 0
mx_sg:
 .long 0, 0, 0, 0
mx_px:
 .long 0, 0, 0
mx_py:
 .long 0, 0, 0
 .include "mixtab.inc"            /* mx_ux / mx_uy (each colour's direction for hue -7..+7, x 1024), mx_ro / mx_ri
                                   * (the ring's half widths by |dy|), mx_tk (the start marks): firmware/rgbpics.py */
 .balign 4
 .include "rgbpics2.inc"          /* the Mix page's pictures ("Sat", "Hue", the "Mix" cell; rgbpics.py, cv_ent) */
 .balign 4
.section .ext12,"ax"
