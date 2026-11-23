/* ================================================================== the Split toning bar, test w7 (feature/split-tone-row)
 * Owner (2026-11-23), after w4..w6 (a panel at the right: moving the camera's widgets at run time found nothing on the
 * camera): "lets build something that looks very identical to the new HSL wheel ... but instead of HSL as the bottom
 * bars, we would have Shadow, balance and highlight."
 * So the Split toning row is the colour wheel row again: the camera's own wheel (its Shadows / Highlights pages, as s2;
 * w3's "no wheel" taken out) and under it, in the H / S / L bar's place and in its style, card/mkstwheel.py's bar: the
 * page's tint colour, then S (Shadows strength), B (Tone Balance), H (Highlights strength), each its value and a
 * gradient with carets; the page's field white-boxed.
 *  - INFO on the row steps Shadows -> Balance -> Highlights -> Shadows (w3). Balance is the Highlights page (P+AXIS 6)
 *    with st_bal set (hb_next): there the readout and the dial read and write Tone Balance (slot +33, -5..5) in place of
 *    the tint (tn_get -> st_bv, tn_set -> sp_all / st_tset, then the wheel's own refresh s_cur; the readout's -5..+5
 *    glyphs: rd_a10 / rd_b10). Arriving on the row or leaving it clears st_bal (sp_sync).
 * When: the readout (916 + slice) on the row's pages goes through tn_get, whose dial-label call (vl_s) goes through
 * st_vl -> st_rd first (only with the films in, nothing at start-up), as ed_get's hb_rd on the colour wheel row. st_rd
 * joins the bar only when something on it changed, into the H / S / L bar's buffer not on screen (hb_b0 / hb_b1),
 * points GDESC at it and writes its 13 colours into palette 62's entries 108..120 (the bar's slots; each one's new
 * picture makes the other's key stale: hb_key, st_key). hb_gsel gives GDESC back to the camera on any page change. */
.section .ext15,"ax"
 .include "stwheel.inc"           /* ST_WORST, ST_NONE, st_rows, st_gid, st_swr, st_tx, st_mk, st_tok, st_ctab */
.set ST_F, 48                     /* st_rd's frame */
 .balign 4
st_key:                           /* what the bar on screen shows (st_rd's key), -1 none */
 .long -1
st_boff:                          /* sp_all -> st_tset: P offset of the Tone Balance byte just written */
 .long 0
st_v:                             /* Shadows colour (ST_NONE: no tint), Highlights colour, the page mode (0 Shadows, */
 .byte 0, 0, 0, 0                 /* 1 Highlights, 2 Balance) */
st_fv:                            /* the three fields' value indices (S strength, Balance + 5, H strength), the boxed one */
 .byte 0, 0, 0, 0
st_bal:                           /* 1: the row's Balance step (on the Highlights page) */
 .byte 0
 .balign 2

/* st_vl <- tn_get's readout `call st_vl,[d2,d3,a2,a3],20` (was vl_s; a2 = P): the bar, then vl_s in the same frame. */
st_vl:
 call st_rd,[d2,d3,a2,a3],ST_F
 jmp vl_s

/* st_bv <- tn_get after TONEV: `add -4,sp; call st_bv,[],0; add 4,sp`, d0 = the value shown, a2 = P + 64k + 2 (axis -
 * 5): on the Balance step (the Highlights page) d0 = Tone Balance (slot +33 = P + 64k + 65) instead. Uses d3. */
st_bv:
 movbu (st_bal),d3
 cmp 0,d3
 beq 9f
 movbu (63,a2),d0
 extb d0
 cmp -5,d0
 bge 1f
 mov -5,d0
1:
 cmp 5,d0
 ble 9f
 mov 5,d0
9:
 ret [],0

/* rd_a10 / rd_b10 <- rd_a / rd_b on the row's pages (jmp; d0 = 5397, a2 back): the 0..10 strength glyphs (rd10_a /
 * rd10_b, as before), or on the Balance step the wheel's own -5..+5 ones (the stock path at rd_a5 / rd_b5, d3 = 0). */
rd_a10:
 movbu (st_bal),d3
 cmp 0,d3
 bne 1f
 mov rd10_a,a0
 mov 11,d3
 jmp rda_none
1:
 clr d3
 jmp rd_a5
rd_b10:
 movbu (st_bal),d3
 cmp 0,d3
 bne 1f
 mov rd10_b,a0
 jmp rd_b10r
1:
 clr d3
 jmp rd_b5

/* st_l / st_r <- COLOR1-4 editor records +20 / +24 (build.py; were ed_l / ed_r): the colour cursor's left / right
 * (the front dial). On the row's Balance step (st_bal, the Highlights page) nothing (d0 = 1, as ed_l's "nothing"):
 * w8, owner: "remove the option to spin the dial on the wheel when balance is selected". Else ed_l / ed_r with every
 * register as at entry. CALLS entry. */
st_l:
 movm [d2,d3,a2],(sp)
 add -4,sp                        /* the call's return slot: it would overwrite the saved d2 */
 call st_lb,[],0
 add 4,sp
 cmp 0,d2                         /* (before movm, which leaves the flags as they are) */
 movm (sp),[d2,d3,a2]
 bne 1f
 jmp ed_l
st_r:
 movm [d2,d3,a2],(sp)
 add -4,sp                        /* the call's return slot: it would overwrite the saved d2 */
 call st_lb,[],0
 add 4,sp
 cmp 0,d2                         /* (before movm, which leaves the flags as they are) */
 movm (sp),[d2,d3,a2]
 bne 1f
 jmp ed_r
1:
 mov 1,d0
 rets

/* st_lb: `call st_lb,[],0` -> d2 = 1 on the row's Balance step (st_bal, films in, the editor on page 6), else 0. Uses
 * d2, d3, a2 (st_l / st_r give them back: movm). */
st_lb:
 movbu (st_bal),d2
 cmp 0,d2
 beq 9f
 PVAL 8f                          /* (uses d3, a2) */
 mov (EMARK,a2),d3
 cmp EMAGIC,d3
 bne 8f
 movbu (AXIS,a2),d3
 cmp 6,d3
 beq 9f
8:
 clr d2
9:
 ret [],0

/* st_kc <- k_set (ed_info's frame: (16) the cursor value it pokes back, a2 = P, the new page in P+AXIS) `call
 * st_kc,[],0`: on the Split toning row's Shadows page (5) or Highlights page (6 without st_bal), when that tint has a
 * strength, the value becomes its colour (slice + 1): the cursor goes back to the tint's colour (w8, owner: "when we
 * switch back to shadow or highlight, can the slice selector go back to the color we had selected"). Uses d0, d1, a0. */
st_kc:
 movbu (AXIS,a2),d0
 mov 55,d1
 cmp 5,d0
 beq 1f
 cmp 6,d0
 bne 9f
 movbu (st_bal),d1
 cmp 0,d1
 bne 9f
 mov 57,d1
1:
 movbu (EDK,a2),d0
 cmp 4,d0
 bcc 9f
 asl 6,d0
 add 32,d0
 add d1,d0
 mov a2,a0
 add d0,a0                        /* COLOR k's slot + 55 / + 57: the colour, then its strength code */
 movbu (1,a0),d0
 cmp 0,d0
 beq 9f
 movbu (a0),d0
 cmp 12,d0
 bcc 9f
 inc d0
 mov d0,(16,sp)
9:
 ret [],0

/* st_tset <- tn_set (its frame 68) when sp_all answered non-zero: 2 = Tone Balance written (st_boff) -> the wheel's
 * refresh s_cur for that byte (dirty, saved at the next half-press); else nothing, as tn_set's own exit. */
st_tset:
 cmp 2,d0
 bne 8f
 mov (st_boff),d2
 jmp s_cur
8:
 clr d0
 ret [d2,d3,a2,a3],68

/* st_code: `call st_code,[],0`, d0 = a stored strength code (byte) -> d0 = strength 0..10 (tn_set's code undone:
 * even s -> s / 2, odd s -> -(s + 1) / 2). */
st_code:
 extb d0
 cmp 0,d0
 blt 1f
 add d0,d0
 bra 2f
1:
 not d0                           /* -c - 1 */
 add d0,d0
 inc d0                           /* -2c - 1 */
2:
 cmp 10,d0
 ble 3f
 mov 10,d0
3:
 retf [],0

/* st_rd: `call st_rd,[d2,d3,a2,a3],ST_F`, a2 = P. Keeps d0, d1, a0, a1 (and d2, d3, a2, a3 by the call); MDR not.
 * Locals (4) d0, (8) d1, (12) a0, (16) a1, (20) key. */
st_rd:
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 mov (hb_b0),d0
 cmp 0,d0
 beq 9f
 mov (EMARK,a2),d0
 cmp EMAGIC,d0
 bne 9f
 movbu (AXIS,a2),d3               /* mode: 0 Shadows, 1 Highlights, 2 Balance (Highlights with st_bal) */
 add -5,d3
 cmp 2,d3
 bcc 9f
 cmp 0,d3
 beq 4f
 movbu (st_bal),d0
 add d0,d3
4:
 movbu d3,(st_v + 2)
 mov 0,d0                         /* the boxed field: Shadows 0, Balance 1, Highlights 2 */
 cmp 0,d3
 beq 4f
 mov 1,d0
 cmp 2,d3
 beq 4f
 mov 2,d0
4:
 movbu d0,(st_fv + 3)
 movbu (EDK,a2),d0
 cmp 4,d0
 bcc 9f
 mov GDESC,a0                     /* the camera's 14 / 175 x 50 / 8 descriptor, or the bars' (400 x 64) */
 movhu (a0),d1
 cmp 14,d1
 bne 9f
 movhu (2,a0),d1
 movhu (4,a0),d2
 cmp 175,d1
 bne 1f
 cmp 50,d2
 beq 3f
 bra 9f
1:
 cmp HB_W,d1
 bne 9f
 cmp HB_PH,d2
 bne 9f
3:
 movhu (6,a0),d1
 cmp 8,d1
 bne 9f
 mov (16,a0),d1                   /* holding the camera's guide, a bar of ours, GUIDES.BIN's or TONES.BIN's */
 cmp GSTOCK_P,d1
 beq 2f
 mov (hb_b0),d2
 cmp d2,d1
 beq 2f
 mov (hb_b1),d2
 cmp d2,d1
 beq 2f
 mov (tg_ptr),d2
 cmp 0,d2
 beq 1f
 mov d1,a1
 sub d2,a1
 cmp 16448,a1
 bcs 2f
1:
 mov (GPTR,a2),d2
 cmp 0,d2
 beq 9f
 mov d1,a1
 sub d2,a1
 cmp 24576,a1
 bcc 9f
2:
 asl 6,d0                         /* COLOR k's slot: P + 32 + 64k */
 mov a2,a0
 add d0,a0
 add 32,a0
 movbu (56,a0),d0                 /* Shadows strength (0..10) and colour (0..11; no strength: ST_NONE) */
 call st_code,[],0
 movbu d0,(st_fv)
 mov d0,d1
 movbu (55,a0),d0
 cmp 12,d0
 bcs 4f
 clr d0
4:
 cmp 0,d1
 bne 4f
 mov ST_NONE,d0
4:
 movbu d0,(st_v)
 movbu (58,a0),d0                 /* Highlights */
 call st_code,[],0
 movbu d0,(st_fv + 2)
 mov d0,d1
 movbu (57,a0),d0
 cmp 12,d0
 bcs 4f
 clr d0
4:
 cmp 0,d1
 bne 4f
 mov ST_NONE,d0
4:
 movbu d0,(st_v + 1)
 movbu (33,a0),d0                 /* Tone Balance -5..5 */
 call hb_clamp,[],0
 add 5,d0
 movbu d0,(st_fv + 1)
 mov st_v,a1                      /* key: S colour, H colour, mode, the three values: base 13 / 13 / 3 / 11 / 11 / 11 */
 movbu (a1),d3
 mov 13,d1
 mul d1,d3
 movbu (1,a1),d0
 add d0,d3
 mov 3,d1
 mul d1,d3
 movbu (2,a1),d0
 add d0,d3
 mov st_fv,a1
 mov 11,d1
 mul d1,d3
 movbu (a1),d0
 add d0,d3
 mov 11,d1
 mul d1,d3
 movbu (1,a1),d0
 add d0,d3
 mov 11,d1
 mul d1,d3
 movbu (2,a1),d0
 add d0,d3
 mov d3,(20,sp)
 mov (st_key),d0                  /* nothing changed and the bar on screen: done */
 cmp d0,d3
 bne 5f
 mov GDESC,a0
 mov (16,a0),d0
 mov (hb_cur),d1
 cmp d0,d1
 beq 9f
5:
 mov (hb_cur),d0                  /* the buffer not on screen */
 mov (hb_b0),a1
 cmp a1,d0
 bne 6f
 mov (hb_b1),a1
6:
 call st_join,[d2,d3,a2,a3],64    /* a1 = the buffer -> d0 = the stream's length */
 mov GDESC,a0
 mov HB_W,d1
 movhu d1,(2,a0)
 mov HB_PH,d1
 movhu d1,(4,a0)
 mov d0,(12,a0)
 mov a1,(16,a0)
 mov a1,(hb_cur)
 mov (20,sp),d0
 mov d0,(st_key)
 mov -1,d0                        /* the H / S / L bar's picture and colours are gone */
 mov d0,(hb_key)
 call st_spal,[d2,d3,a2,a3],20
9:
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 mov (16,sp),a1
 ret [d2,d3,a2,a3],ST_F

/* st_spal: `call st_spal,[d2,d3,a2,a3],20`: the bar's 13 colours (mkstwheel.colours, from st_ctab: per colour 8 words
 * full, 25 / 50 / 75 % over grey, dark, middle, light, lighter) into palette 62's entries 108..120, in its table and on
 * the screen (GPISetPalette), as hb_spal. Uses d0, d1, a0, a1, mdr. */
st_spal:
 movbu (st_v),d0                  /* a0 = the Shadows colour's words, a1 = the table's 108.. */
 asl 5,d0
 add st_ctab,d0
 mov d0,a0
 mov HB_PALT,a1
 mov (a0),d0                      /* 108..111: S full, over grey */
 mov d0,(a1)
 mov (4,a0),d0
 mov d0,(4,a1)
 mov (8,a0),d0
 mov d0,(8,a1)
 mov (12,a0),d0
 mov d0,(12,a1)
 mov (16,a0),d0                   /* 116, 117: S dark, middle */
 mov d0,(32,a1)
 mov (20,a0),d0
 mov d0,(36,a1)
 movbu (st_v + 2),d1              /* 118: the swatch: the page's colour (Balance: grey) */
 mov (a0),d0
 cmp 0,d1
 beq 1f
 mov (ST_NONE * 32 + st_ctab),d0
 cmp 2,d1
 beq 1f
 movbu (st_v + 1),d0
 asl 5,d0
 add st_ctab,d0
 mov d0,a0
 mov (a0),d0
1:
 mov d0,(40,a1)
 movbu (st_v + 1),d0              /* the Highlights colour's words */
 asl 5,d0
 add st_ctab,d0
 mov d0,a0
 mov (a0),d0                      /* 112..115: H full, over grey */
 mov d0,(16,a1)
 mov (4,a0),d0
 mov d0,(20,a1)
 mov (8,a0),d0
 mov d0,(24,a1)
 mov (12,a0),d0
 mov d0,(28,a1)
 mov (24,a0),d0                   /* 119, 120: H light, lighter */
 mov d0,(44,a1)
 mov (28,a0),d0
 mov d0,(48,a1)
 mov HB_SLOT0,d0
 mov HB_NSLOT,d1
 mov hb_lobj,a0
 mov HB_PALT,a1
 calls gpi_setpal
 ret [d2,d3,a2,a3],20

/* st_trow: `call st_trow,[],0`, d0 = a fixed row part (st_rows index): its tokens. Uses d0, d1, a0. */
st_trow:
 asl2 d0
 mov st_rows,a0
 mov (d0,a0),d1
 mov d1,d0
 lsr 8,d0
 add d0,d0
 mov st_tok,a0
 add d0,a0
 and 255,d1
 beq 9f
1:
 movhu (a0),d0
 add 2,a0
 HB_PUT
 add -1,d1
 bne 1b
9:
 retf [],0

/* st_join: `call st_join,[d2,d3,a2,a3],64`, a1 = a stream buffer (HB_BUF bytes): st_fv's bar as mkstwheel.stream ->
 * d0 = its length; a1 kept. Each row: the swatch column (its colour rows st_gid's first row, the others st_swr), then
 * per field its text part (st_tx) and its slider part (gradient rows st_gid's, the others st_mk). Locals (4) y, (8)
 * st_gid (4 u16), (12..23) the 3 fields' text tables, (24..35) their slider tables, (40) the buffer, (44) the field. */
st_join:
 mov a1,(40,sp)
 mov HB_HDR,d0                    /* 400 x 64, type 11 */
 mov d0,(a1)
 mov st_gid,d0                    /* the colour rows (the colour itself is in palette entries 108..120) */
 mov d0,(8,sp)
 mov sp,a0
 add 12,a0
 clr d1                           /* field f */
1:
 mov st_fv,a1
 movbu (d1,a1),d0                 /* its value index, 0..10 */
 mov d0,d3
 movbu (st_fv + 3),d2
 cmp d1,d2
 bne 2f
 add 11,d0                        /* boxed */
2:
 mov 22,d2
 mul d1,d2
 add d2,d0
 mov HB_H * 2,d2
 mul d2,d0
 add st_tx,d0
 mov d0,(a0)
 mov HB_H * 2,d2
 mul d2,d3
 add st_mk,d3
 mov d3,(12,a0)
 add 4,a0
 inc d1
 cmp 3,d1
 bne 1b
 mov (40,sp),a3
 add 4,a3
 clr d2
 clr d3
 mov 0,a2
 .if HB_PAD
 mov HB_PAD * 25,d1               /* clear rows over the bar (25 runs of 16 a row, entry 0): w2 / w3 */
5:
 mov 15,d0
 HB_PUT
 add -1,d1
 bne 5b
 .endif
 clr d0
 mov d0,(4,sp)
10:                               /* a row: the swatch column */
 mov (4,sp),d1
 cmp HB_SWF0,d1
 bcs 11f
 cmp HB_SWF1,d1
 bhi 11f
 mov (8,sp),a0
 movhu (a0),d0
 bra 12f
11:
 mov st_swr,a0
 mov d1,d0
 add d0,d0
 movhu (d0,a0),d0
12:
 call st_trow,[],0
 clr d0
 mov d0,(44,sp)
20:                               /* a field: its text part */
 mov (44,sp),d0
 asl2 d0
 mov sp,a0
 add d0,a0
 mov (12,a0),a1
 mov (4,sp),d0
 add d0,d0
 movhu (d0,a1),d0
 call st_trow,[],0
 mov (4,sp),d1                    /* its slider part */
 cmp HB_SLF0,d1
 bcs 21f
 cmp HB_SLF1,d1
 bhi 21f
 mov (44,sp),d0                   /* a gradient row: st_gid's entry 1 + f */
 add d0,d0
 mov (8,sp),a0
 add d0,a0
 movhu (2,a0),d0
 bra 22f
21:
 mov (44,sp),d0
 asl2 d0
 mov sp,a0
 add d0,a0
 mov (24,a0),a1
 mov d1,d0
 add d0,d0
 movhu (d0,a1),d0
22:
 call st_trow,[],0
 mov (44,sp),d0
 inc d0
 mov d0,(44,sp)
 cmp 3,d0
 bne 20b
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 cmp HB_H,d0
 bne 10b
50:                               /* zero tokens to the end of the word */
 cmp 0,a2
 beq 60f
 add 12,d3
 add 1,a2
 cmp 5,a2
 bne 51f
 mov 0,a2
 add 4,d3
51:
 cmp 8,d3
 bcs 50b
 movbu d2,(a3)
 inc a3
 lsr 8,d2
 add -8,d3
 bra 51b
60:
 mov (40,sp),a1
 mov a3,d0
 mov a1,d1
 sub d1,d0
 ret [d2,d3,a2,a3],64
