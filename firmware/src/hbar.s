/* ================================================================== the colour wheel's H / S / L bar (experiment/wheel-hsl-view)
 * Owner (2026-11-22): "think we could do something like this for our color wheels?" (another camera's Color / Vivid
 * screen with H, S and L of the chosen colour under the wheel) -> "Yes, build the bar". Test 1: on the wheel's Color
 * (one colour), Hue and Luminance pages the guide picture under the wheel (GDESC, 175 x 50, where "Hue [INFO]" was)
 * shows "H+2  S±0  L-1" for the colour under the cursor, each with a small slider, the page's field framed.
 * card/mkhbar.py makes the pieces (hbar.inc) and the same picture (the emulator test compares them).
 *
 * When: the wheel's readout ("Vivid +2") reads 916 + slice through GetValue on every redraw (dial, INFO, the wheel
 * opening), before the screen's pictures are drawn (om-emu trace, 2026-11-22: readout, the wheel's 12 reads, then the
 * 23 pictures, GDESC last). ed_get calls hb_rd there, after PVAL (only once the films are in: nothing at start-up).
 * hb_rd draws only when something on the bar changed, into the buffer not on screen, then points GDESC at it
 * (two heap buffers: pictures in flash blank the menu, 2026-11-16). gd_set's gd_sel call goes through hb_gsel, which
 * gives GDESC back to the camera's picture first, so gd_set's own checks and pictures work as before (Shadows /
 * Highlights, the half-press's "stock pictures"). Leaving the wheel with MENU / OK keeps the bar in GDESC until the next
 * half-press, as the page guides did before. */
.section .ext15,"ax"
 .include "hbar.inc"              /* hb_rows, hb_tc, hb_ta, hb_tb, hb_tok, HB_WORST (card/mkhbar.py) */
.set HB_W, 175
.set HB_H, 50
.set HB_BUF, 4096                 /* each stream buffer (worst case HB_WORST, checked by build.py) */
.set HB_F, 48                     /* hb_rd's frame */
 .balign 4
hb_b0:                            /* the two stream buffers (heap, hb_alloc), 0 = none: no bar */
 .long 0
hb_b1:
 .long 0
hb_cur:                           /* the one in GDESC now */
 .long 0
hb_key:                           /* what it shows: k << 20 | slice << 16 | axis << 12 | (l+5) << 8 | (s+5) << 4 | (h+5) */
 .long -1
hb_val:                           /* h, s, l (-5..5), the framed field (0..2) */
 .byte 0, 0, 0, 0

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

/* hb_gsel <- gd_set's `call hb_gsel,[d2,d3,a2,a3],24` (was gd_sel): GDESC holding a bar -> the camera's guide again,
 * then gd_sel (same frame). Keeps d0, a2; uses d1, a0. */
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
 mov GSTOCK_S,d1
 mov d1,(12,a0)
 mov GSTOCK_P,d1
 mov d1,(16,a0)
9:
 jmp gd_sel

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
 mov GDESC,a0                     /* the camera's 14 / 175 x 50 / 8 descriptor */
 movhu (a0),d1
 cmp 14,d1
 bne 9f
 movhu (2,a0),d1
 cmp 175,d1
 bne 9f
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
 movbu (EDK,a2),d0                /* k: the slot P + 32 + 64k, the colour's h at +slice, l at +12 + slice */
 mov d0,d1
 asl 6,d0
 add d2,d0
 mov a2,a0
 add d0,a0
 mov d1,d0                        /* key: k << 20 | slice << 16 | axis << 12 */
 asl 4,d0
 or d2,d0
 asl 4,d0
 or d3,d0
 asl 12,d0
 mov d0,(20,sp)
 mov 1,d0                         /* the framed field: axis 2 Hue -> 0, 0 Saturation -> 1, 1 Luminance -> 2 */
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

/* hb_join: `call hb_join,[d2,d3,a2,a3],80`, a1 = a stream buffer (HB_BUF bytes; build.py checks HB_WORST < HB_BUF):
 * hb_val's bar as mkhbar.stream: the header, then for each of the 50 rows, for H, S, L: the frame's left part (hb_ta),
 * the content (hb_tc), the frame's right part (hb_tb), their tokens packed five to a 64-bit word, the last padded with
 * zero tokens -> d0 = the length; a1 kept. Locals (4..39) the 9 parts' tables (field * 3 + part), (40) the row * 2,
 * (44) the part, (48) the buffer. Packing: d2 the bit buffer, d3 its bits, a2 the tokens in the word, a3 the output. */
hb_join:
 mov a1,(48,sp)
 mov GHDR,d0                      /* 175 x 50, type 11 */
 mov d0,(a1)
 clr d0
 mov d0,(40,sp)
 mov sp,a0
 add 4,a0
 clr d1                           /* field f */
1:
 movbu (hb_val+3),d2              /* the frame's parts: framed * 2 + (f = L) */
 clr d3
 cmp d1,d2
 bne 2f
 mov 2,d3
2:
 cmp 2,d1
 bne 3f
 inc d3
3:
 mov 100,d0
 mul d0,d3
 mov hb_ta,d0
 add d3,d0
 mov d0,(a0)
 mov hb_tb,d0
 add d3,d0
 mov d0,(8,a0)
 mov hb_val,a2                    /* the content: f * 11 + v + 5 */
 movbu (d1,a2),d0
 extb d0
 add 5,d0
 mov d1,d2
 mov 11,d3
 mul d3,d2
 add d2,d0
 mov 100,d3
 mul d3,d0
 add hb_tc,d0
 mov d0,(4,a0)
 add 12,a0
 inc d1
 cmp 3,d1
 bne 1b
 mov (48,sp),a3
 add 4,a3
 clr d2
 clr d3
 mov 0,a2
4:                                /* a row */
 clr d0
 mov d0,(44,sp)
5:                                /* a part: its row's tokens */
 mov (44,sp),d0
 asl2 d0
 mov sp,a1
 add d0,a1
 mov (4,a1),a1
 mov (40,sp),d0
 movhu (d0,a1),d0                 /* the row part's index */
 asl2 d0
 mov hb_rows,a1
 mov (d0,a1),d1                   /* its first token << 8 | its count */
 mov d1,d0
 lsr 8,d0
 add d0,d0
 mov hb_tok,a0
 add d0,a0
 and 255,d1
 beq 8f
6:
 movhu (a0),d0
 add 2,a0
 asl d3,d0
 or d0,d2
 add 12,d3
 add 1,a2
 cmp 5,a2
 bne 7f
 mov 0,a2
 add 4,d3                         /* a word's last 4 bits stay 0 */
7:
 cmp 8,d3
 bcs 71f
 movbu d2,(a3)
 inc a3
 lsr 8,d2
 add -8,d3
 bra 7b
71:
 add -1,d1
 bne 6b
8:
 mov (44,sp),d0
 inc d0
 mov d0,(44,sp)
 cmp 9,d0
 bne 5b
 mov (40,sp),d0
 add 2,d0
 mov d0,(40,sp)
 cmp 2 * HB_H,d0
 bne 4b
9:                                /* zero tokens to the end of the word */
 cmp 0,a2
 beq 10f
 add 12,d3
 add 1,a2
 cmp 5,a2
 bne 91f
 mov 0,a2
 add 4,d3
91:
 cmp 8,d3
 bcs 9b
 movbu d2,(a3)
 inc a3
 lsr 8,d2
 add -8,d3
 bra 91b
10:
 mov (48,sp),a1
 mov a3,d0
 mov a1,d1
 sub d1,d0
 ret [d2,d3,a2,a3],80
