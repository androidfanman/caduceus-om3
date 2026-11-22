/* ================================================================== the colour wheel's H / S / L bar (experiment/wheel-hsl-view)
 * Owner (2026-11-22): "think we could do something like this for our color wheels?" -> "Yes, build the bar" (h1,
 * camera-tested: "that is looking good. and works.") -> round 2 (h2): "make the hsl bottom part bigger ... display
 * color ... Ideally the sat and light would change if we change the hue"; "map the delete key while in color profile
 * mode to switch between hsl and the info key to switch to the other wheels".
 *
 * The bar (card/mkhbar.py makes its parts and the same picture; the emulator test compares them byte for byte):
 * 400 x 50 in the guide picture's place under the wheel. build.py's DATA widens the guide's two widgets (frame
 * 0x3c6, picture 0x3c7: rectangles at 0x61451e40 / 0x61451e50) to 400 px, between the left column and Reset, on the
 * rear screen and in the viewfinder. Left to right: a swatch of the colour under the cursor (turned by its Hue), then
 * H, S and L, each its value and an 11-step coloured slider with a mark (H: the neighbouring shades; S: grey to the
 * colour; L: black to the colour to white; S and L in the colour as its Hue turns it). The page's value white-boxed.
 *
 * When: the wheel's readout reads 916 + slice through GetValue on every redraw, before the screen's pictures are
 * drawn (om-emu trace, 2026-11-22). ed_get calls hb_rd there, after PVAL (only once the films are in: nothing at
 * start-up). hb_rd joins the bar only when something on it changed, into the buffer not on screen, then points GDESC
 * at it (400 wide). gd_set's gd_sel call goes through hb_gsel, which gives GDESC back to the camera's picture (175
 * wide) first. Leaving the wheel with MENU / OK keeps the bar in GDESC until the next half-press, as before.
 *
 * Keys (h2): Delete on the wheel row steps Saturation -> Hue -> Luminance -> Saturation; INFO steps to the other
 * wheels: from Saturation, Hue or Luminance to Shadows, then Highlights, then back to the HSL page it left. Delete's
 * press had no handler in the Picture Mode screen's key state (block 0x61322da0, entry 23 {0x01000026, 39, 1, 0}).
 * build.py's KEYW gives that entry hb_kdel: on the wheel row (GUI state 0x0418, Picture Mode's current item 5397,
 * films in) it turns the press into INFO's (GUI code 37 -> event 0x9014 to the wheel) and marks it (hb_del); its
 * release (entry 24) into INFO's release. INFO's own press (entry 26) goes through hb_kinf, which clears the mark,
 * then the stock 0x610b3ddb. ed_info's k_step asks hb_next for the page. */
.section .ext15,"ax"
 .include "hbar.inc"              /* HB_*, hb_rows, hb_seg, hb_tx, hb_mk, hb_tok (card/mkhbar.py) */
.set HB_W, 400
.set HB_H, 50
.set HB_BUF, 6144                 /* each stream buffer (worst case HB_WORST, checked by build.py) */
.set HB_F, 48                     /* hb_rd's frame */
.set HB_UI_INFO, 0x25             /* the GUI key codes of INFO's press and release (Delete's: 0x27, 0x29) */
.set HB_UI_INFOR, 0x26
.set PM_WHEEL, 5397               /* Picture Mode's wheel row */
 .balign 4
hb_b0:                            /* the two stream buffers (heap, hb_alloc), 0 = none: no bar */
 .long 0
hb_b1:
 .long 0
hb_cur:                           /* the one in GDESC now */
 .long 0
hb_key:                           /* what it shows: k << 24 | slice << 16 | axis << 12 | (l+5) << 8 | (s+5) << 4 | (h+5) */
 .long -1
hb_val:                           /* h, s, l (-5..5), the page's field (0..2), the slice (0..11) */
 .byte 0, 0, 0, 0, 0, 0, 0, 0
hb_item:                          /* Picture Mode's current item (pu_hook's screen update, via hb_pu) */
 .short 0
hb_del:                           /* 1: the INFO now reaching the wheel was a Delete press */
 .byte 0
hb_dcv:                           /* 1: a Delete press was turned into INFO's: its release too */
 .byte 0
hb_last:                          /* the HSL page INFO last left (0 Saturation, 1 Luminance, 2 Hue) */
 .byte 0
 .balign 2

/* hb_alloc <- jmp from fl_mk's end (its frame: ret [d2,d3,a2,a3],80; a2 = P): the two stream buffers, once. */
hb_alloc:
 mov (hb_b0),d0
 cmp 0,d0
 bne 9f
 mov HB_BUF,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,d2
 mov HB_BUF,d0
 call malloc,[],4
 cmp 0,a0
 bne 1f
 mov d2,a0                        /* only one: no bar */
 call free,[],4
 bra 9f
1:
 mov a0,(hb_b1)
 mov d2,(hb_b0)
9:
 ret [d2,d3,a2,a3],80

/* hb_gsel <- gd_set's `call hb_gsel,[d2,d3,a2,a3],24` (was gd_sel): GDESC holding a bar -> the camera's guide again
 * (175 wide), then gd_sel (same frame). Keeps d0, a2; uses d1, d2, a0. */
hb_gsel:
 mov GDESC,a0
 mov (16,a0),d1
 mov (hb_b0),d2
 cmp 0,d2
 beq 9f
 cmp d2,d1
 beq 1f
 mov (hb_b1),d2
 cmp d2,d1
 bne 9f
1:
 mov 175,d1
 movhu d1,(2,a0)
 mov GSTOCK_S,d1
 mov d1,(12,a0)
 mov GSTOCK_P,d1
 mov d1,(16,a0)
9:
 jmp gd_sel

/* hb_pu <- pu_hook's `call hb_pu,[d2,d3,a2,a3],20` (was gr_upd), a0 -> Picture Mode's current item: noted, then gr_upd. */
hb_pu:
 movhu (a0),d0
 movhu d0,(hb_item)
 jmp gr_upd

/* hb_kdel <- the Delete press entry of the Picture Mode screen's key state (CALLS: a1 = the key event, its GUI code at
 * (32,a1), already 0x27). On the wheel row with the films in: INFO's code, marked. Else nothing, as stock. */
hb_kdel:
 movm [d2,d3,a2,a3],(sp)
 mov (0x603713a4),a0              /* GUI state 0x0418: Picture Mode */
 cmp 0,a0
 beq 9f
 movbu (a0),d0
 cmp 4,d0
 bne 9f
 movbu (1,a0),d0
 cmp 0x18,d0
 bne 9f
 movhu (hb_item),d0
 cmp PM_WHEEL,d0
 bne 9f
 PVAL 9f                          /* (uses d3, a2) */
 mov (EMARK,a2),d0
 cmp EMAGIC,d0
 bne 9f
 mov HB_UI_INFO,d0
 mov d0,(32,a1)
 mov 1,d0
 movbu d0,(hb_del)
 movbu d0,(hb_dcv)
9:
 ret [d2,d3,a2,a3],16

/* hb_krel <- the Delete release entry (CALLS, a1 the event): after a turned press, INFO's release code. */
hb_krel:
 movbu (hb_dcv),d0
 cmp 0,d0
 beq 9f
 clr d0
 movbu d0,(hb_dcv)
 mov HB_UI_INFOR,d0
 mov d0,(32,a1)
9:
 rets

/* hb_kinf <- the INFO press entry (CALLS): a real INFO, not a Delete: the mark off, then the stock handler. */
hb_kinf:
 clr d0
 movbu d0,(hb_del)
 jmp hb_info_stock

/* hb_next <- jmp from ed_info's k_step (its frame; a2 = P, d0 = the page now) -> jmp k_set with d1 = the next page.
 * Delete (hb_del): Saturation -> Hue -> Luminance -> Saturation; from Shadows / Highlights the HSL page INFO left.
 * INFO: Saturation / Hue / Luminance -> Shadows (that page noted), Shadows -> Highlights, Highlights -> the page noted. */
hb_next:
 movbu (hb_del),d1
 cmp 0,d1
 beq 5f
 clr d1
 movbu d1,(hb_del)
 mov 2,d1
 cmp 0,d0
 beq 9f
 mov 1,d1
 cmp 2,d0
 beq 9f
 clr d1
 cmp 1,d0
 beq 9f
 movbu (hb_last),d1
 bra 9f
5:
 cmp 3,d0
 bcc 6f
 movbu d0,(hb_last)
 mov 5,d1
 bra 9f
6:
 mov 6,d1
 cmp 5,d0
 beq 9f
 movbu (hb_last),d1
9:
 jmp k_set

/* hb_rd: `mov mdr,d3; add -4,sp; call hb_rd,[d2,d3,a2,a3],HB_F; add 4,sp; mov d3,mdr` from ed_get on a readout id
 * (916 + slice), after PVAL: d2 = slice (0..11), a2 = P. Keeps d0, d1, a0, a1 (and d2, d3, a2, a3 by the call).
 * Locals (4) d0, (8) d1, (12) a0, (16) a1, (20) key. A frame of N bytes: the saved registers at its top 16, locals
 * below them, (0) the slot of a call's return address. */
hb_rd:
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
 movbu (AXIS,a2),d3               /* pages 0 Saturation, 1 Luminance, 2 Hue */
 cmp 3,d3
 bcc 9f
 movbu (EDK,a2),d0
 cmp 4,d0
 bcc 9f
 mov GDESC,a0                     /* the camera's 14 / 175 x 50 / 8 descriptor, or ours (400 wide) */
 movhu (a0),d1
 cmp 14,d1
 bne 9f
 movhu (2,a0),d1
 cmp 175,d1
 beq 1f
 cmp HB_W,d1
 bne 9f
1:
 movhu (4,a0),d1
 cmp 50,d1
 bne 9f
 movhu (6,a0),d1
 cmp 8,d1
 bne 9f
 mov (16,a0),d1                   /* holding the camera's guide or one of ours (else someone else's: leave it) */
 cmp GSTOCK_P,d1
 beq 2f
 mov (hb_b0),d0
 cmp d0,d1
 beq 2f
 mov (hb_b1),d0
 cmp d0,d1
 beq 2f
 mov (GPTR,a2),d0                 /* GUIDES.BIN's pictures */
 cmp 0,d0
 beq 1f
 mov d1,a1
 sub d0,a1
 cmp 24576,a1
 bcs 2f
1:
 mov (SATB,a2),d0                 /* the Saturation page's pictures */
 cmp 0,d0
 beq 9f
 sub d0,d1
 cmp SAT_LEN,d1
 bcc 9f
2:
 movbu d2,(hb_val+4)              /* the slice */
 movbu (EDK,a2),d0                /* k: the slot P + 32 + 64k, the colour's h at +slice, l at +12 + slice */
 mov d0,d1
 asl 6,d0
 add d2,d0
 mov a2,a0
 add d0,a0
 mov d1,d0                        /* key: k << 24 | slice << 16 | axis << 12 */
 asl 8,d0
 or d2,d0
 asl 4,d0
 or d3,d0
 asl 12,d0
 mov d0,(20,sp)
 mov 1,d0                         /* the boxed field: axis 2 Hue -> 0, 0 Saturation -> 1, 1 Luminance -> 2 */
 cmp 0,d3
 beq 4f
 mov 2,d0
 cmp 1,d3
 beq 4f
 clr d0
4:
 movbu d0,(hb_val+3)
 movbu (32,a0),d0                 /* h */
 call hb_clamp,[],0
 movbu d0,(hb_val)
 add 5,d0
 mov (20,sp),d3
 or d0,d3
 mov d3,(20,sp)
 movbu (44,a0),d0                 /* l */
 call hb_clamp,[],0
 movbu d0,(hb_val+2)
 add 5,d0
 asl 8,d0
 mov (20,sp),d3
 or d0,d3
 mov d3,(20,sp)
 mov d1,d0                        /* s: the camera's setting 928 + 12k + slice, read as the wheel's drawing reads it */
 asl2 d0
 mov d0,d3
 add d0,d0
 add d3,d0                        /* 12k */
 add d2,d0
 add 928,d0
 call aget,[],4
 call hb_clamp,[],0
 movbu d0,(hb_val+1)
 add 5,d0
 asl 4,d0
 mov (20,sp),d3
 or d0,d3
 mov d3,(20,sp)
 mov (hb_key),d0                  /* nothing changed and the bar on screen: done */
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
 call hb_join,[d2,d3,a2,a3],80    /* a1 = the buffer -> d0 = the stream's length */
 mov GDESC,a0
 mov HB_W,d1
 movhu d1,(2,a0)
 mov d0,(12,a0)
 mov a1,(16,a0)
 mov a1,(hb_cur)
 mov (20,sp),d0
 mov d0,(hb_key)
9:
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 mov (16,sp),a1
 ret [d2,d3,a2,a3],HB_F

/* hb_clamp: `call hb_clamp,[],0`, d0 = a byte -> d0 = it as signed, -5..5. */
hb_clamp:
 extb d0
 cmp -5,d0
 bge 1f
 mov -5,d0
1:
 cmp 5,d0
 ble 2f
 mov 5,d0
2:
 retf [],0

/* The packing (hb_join's registers): d2 the bit buffer, d3 its bits, a2 the tokens in the 64-bit word, a3 the output.
 * HB_PUT: d0 = a token (12 bits) -> the stream; five a word, its last 4 bits 0. Uses d0. */
 .macro HB_PUT
 asl d3,d0
 or d0,d2
 add 12,d3
 add 1,a2
 cmp 5,a2
 bne 81f
 mov 0,a2
 add 4,d3
81:
 cmp 8,d3
 bcs 82f
 movbu d2,(a3)
 inc a3
 lsr 8,d2
 add -8,d3
 bra 81b
82:
 .endm

/* hb_trow: `call hb_trow,[],0`, d0 = a fixed row part (hb_rows index): its tokens. Uses d0, d1, a0. */
hb_trow:
 asl2 d0
 mov hb_rows,a0
 mov (d0,a0),d1
 mov d1,d0
 lsr 8,d0
 add d0,d0
 mov hb_tok,a0
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

/* hb_trun: `call hb_trun,[],0`, d0 = a colour, d1 = a width: one run, as tokens of up to 16. Uses d0, d1, a0. */
hb_trun:
 asl 4,d0
 mov d0,a0
1:
 mov d1,d0
 cmp 16,d0
 bls 2f
 mov 16,d0
2:
 sub d0,d1
 add -1,d0
 add a0,d0
 HB_PUT
 cmp 0,d1
 bne 1b
 retf [],0

/* hb_join: `call hb_join,[d2,d3,a2,a3],80`, a1 = a stream buffer (HB_BUF bytes): hb_val's bar as mkhbar.stream ->
 * d0 = its length; a1 kept. Locals (4) y, (8) 1 << (y & 3), (12) the colour table (hb_seg + (slice * 11 + h + 5) *
 * 136), (16..27) the 3 fields' text tables, (28..39) their mark tables, (40) the buffer, (44) the field, (48) the
 * step's entry, (52) steps left. */
hb_join:
 mov a1,(40,sp)
 mov HB_HDR,d0                    /* 400 x 50, type 11 */
 mov d0,(a1)
 movbu (hb_val+4),d0
 mov 11,d1
 mul d1,d0
 movbu (hb_val),d1
 extb d1
 add 5,d1
 add d1,d0
 mov 136,d1
 mul d1,d0
 add hb_seg,d0
 mov d0,(12,sp)
 mov sp,a0
 add 16,a0
 clr d1                           /* field f */
1:
 mov hb_val,a1
 movbu (d1,a1),d0
 extb d0
 add 5,d0                         /* v + 5 */
 mov d0,d3
 movbu (hb_val+3),d2
 cmp d1,d2
 bne 2f
 add 11,d0                        /* boxed */
2:
 mov 22,d2
 mul d1,d2
 add d2,d0
 mov 100,d2                       /* 50 rows of u16 */
 mul d2,d0
 add hb_tx,d0
 mov d0,(a0)
 mov 100,d2
 mul d2,d3
 add hb_mk,d3
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
 clr d0
 mov d0,(4,sp)
10:                               /* a row */
 mov (4,sp),d0
 and 3,d0
 mov 1,d1
 asl d0,d1
 mov d1,(8,sp)
 mov (4,sp),d1                    /* the swatch */
 mov HB_R_SW_BLANK,d0
 cmp HB_SWY0,d1
 bcs 13f
 cmp HB_SWY1,d1
 bhi 13f
 mov HB_R_SW_EDGE,d0
 cmp HB_SWY0,d1
 beq 13f
 cmp HB_SWY1,d1
 beq 13f
 mov HB_R_SW_LINE,d0
 cmp HB_SWY0 + 1,d1
 beq 13f
 cmp HB_SWY1 - 1,d1
 beq 13f
 mov HB_R_SW_HEAD,d0
 call hb_trow,[],0
 mov (12,sp),a0
 movbu (2,a0),d0
 mov (8,sp),d1
 and d1,d0
 beq 11f
 movbu (1,a0),d0
 bra 12f
11:
 movbu (a0),d0
12:
 mov HB_SWF,d1
 call hb_trun,[],0
 mov HB_R_SW_TAIL,d0
13:
 call hb_trow,[],0
 clr d0
 mov d0,(44,sp)
20:                               /* a field: its text part */
 mov (44,sp),d0
 asl2 d0
 mov sp,a0
 add d0,a0
 mov (16,a0),a1
 mov (4,sp),d0
 add d0,d0
 movhu (d0,a1),d0
 call hb_trow,[],0
 mov (4,sp),d1                    /* its slider part */
 cmp HB_SLY0,d1
 beq 25f
 bcs 27f
 cmp HB_SLY1,d1
 beq 25f
 bcs 30f
 cmp HB_MKY0,d1
 bcs 27f
 cmp HB_MKY1,d1
 bhi 27f
 mov (44,sp),d0                   /* the mark's row */
 asl2 d0
 mov sp,a0
 add d0,a0
 mov (28,a0),a1
 mov d1,d0
 add d0,d0
 movhu (d0,a1),d0
 bra 28f
25:
 mov HB_R_SL_EDGE,d0
 bra 28f
27:
 mov HB_R_SL_BLANK,d0
28:
 call hb_trow,[],0
 bra 40f
30:                               /* a slider fill row: head, 11 steps, tail */
 mov HB_R_SL_HEAD,d0
 call hb_trow,[],0
 mov (44,sp),d0                   /* the field's steps: entries 1 + 11 f .. */
 mov 44,d1
 mul d1,d0
 add 4,d0
 mov (12,sp),d1
 add d1,d0
 mov d0,(48,sp)
 mov HB_NSTEP,d0
 mov d0,(52,sp)
31:
 mov (48,sp),a0
 movbu (2,a0),d0
 mov (8,sp),d1
 and d1,d0
 beq 32f
 movbu (1,a0),d0
 bra 33f
32:
 movbu (a0),d0
33:
 add 4,a0
 mov a0,(48,sp)
 mov HB_STEPW,d1
 call hb_trun,[],0
 mov (52,sp),d0
 add -1,d0
 mov d0,(52,sp)
 bne 31b
 mov HB_R_SL_TAIL,d0
 call hb_trow,[],0
40:
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
 ret [d2,d3,a2,a3],80
