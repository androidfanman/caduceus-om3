/* ================================================================== the Split toning strip, test w1 (feature/split-tone-row)
 * Owner (2026-11-23), mock-up C (two small wheels and the Balance slider on one screen): "its exactly what i am really
 * envisioning" -> "Yes, try it". This test only shows them; keys and storage are s1's.
 *
 * On the Split toning row's pages (P+AXIS 5 Shadows, 6 Highlights) the guide picture's place under the camera's wheel
 * (400 x 64, as the H / S / L bar: hbar.s) shows card/mkstwheel.py's strip: the Shadows wheel with a dot at its tint,
 * the Balance slider with a caret at Tone Balance and its value, the Highlights wheel; the page's wheel and label
 * white-marked. When: the wheel's readout (916 + slice) on those pages goes through tn_get, whose dial-label call
 * (vl_s) goes through st_vl -> st_rd first (as ed_get's hb_rd on the HSL pages; only with the films in, nothing at
 * start-up). st_rd builds the strip only when something on it changed, into the bar's buffer not on screen (hb_b0 /
 * hb_b1), points GDESC at it and puts the 12 hues into palette 62's entries 108..119 (hbar.s's slots). The two share
 * GDESC and the slots, so each one's new picture makes the other's key stale (hb_key, st_key). hb_gsel gives GDESC
 * back to the camera's picture on any page change, as for the bar.
 *
 * Each row: its background row (st_rows / st_tok, the page's variant) into st_row, then the four sprites over it (two
 * dots, the caret, the value; 0 = see-through), then st_row as greedy runs of up to 16 (HB_PUT), as mkstwheel.stream. */
.section .ext15,"ax"
 .include "stwheel.inc"           /* ST_*, st_rows, st_bg, st_cx, st_tok, st_dxy, st_dot, st_car, st_vtab, st_pal */
.set ST_F, 48                     /* st_rd's frame */
 .balign 4
st_key:                           /* what the strip on screen shows (st_rd's key), -1 none */
 .long -1
st_v:                             /* Shadows colour, strength, Highlights colour, strength, Balance + 5, page - 5 */
 .byte 0, 0, 0, 0, 0, 0, 0, 0
st_sp:                            /* the four sprites: u32 picture, u16 x, u16 y */
 .space 32
st_row:                           /* the row being built */
 .space 400
st_rend:
 .balign 2

/* st_vl <- tn_get's readout `call st_vl,[d2,d3,a2,a3],20` (was vl_s; a2 = P): the strip, then vl_s in the same frame. */
st_vl:
 call st_rd,[d2,d3,a2,a3],ST_F
 jmp vl_s

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
 movbu (AXIS,a2),d3
 add -5,d3
 cmp 2,d3
 bcc 9f
 movbu d3,(st_v + 5)
 movbu (EDK,a2),d0
 cmp 4,d0
 bcc 9f
 mov GDESC,a0                     /* the camera's 14 / 175 x 50 / 8 descriptor, or ours (400 x 64) */
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
 cmp HB_H,d2
 bne 9f
3:
 movhu (6,a0),d1
 cmp 8,d1
 bne 9f
 mov (16,a0),d1                   /* holding the camera's guide, ours, GUIDES.BIN's or TONES.BIN's (else leave it) */
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
 movbu (55,a0),d0                 /* Shadows colour (0..11) */
 cmp 12,d0
 bcs 4f
 clr d0
4:
 movbu d0,(st_v)
 movbu (56,a0),d0
 call st_code,[],0
 movbu d0,(st_v + 1)
 movbu (57,a0),d0                 /* Highlights colour */
 cmp 12,d0
 bcs 4f
 clr d0
4:
 movbu d0,(st_v + 2)
 movbu (58,a0),d0
 call st_code,[],0
 movbu d0,(st_v + 3)
 movbu (33,a0),d0                 /* Tone Balance -5..5 */
 call hb_clamp,[],0
 add 5,d0
 movbu d0,(st_v + 4)
 clr d3                           /* key: the six values, base 12 / 11 / 12 / 11 / 11 / 2 */
 mov st_v,a1
 movbu (a1),d3
 mov 11,d1
 mul d1,d3
 movbu (1,a1),d0
 add d0,d3
 mov 12,d1
 mul d1,d3
 movbu (2,a1),d0
 add d0,d3
 mov 11,d1
 mul d1,d3
 movbu (3,a1),d0
 add d0,d3
 mov 11,d1
 mul d1,d3
 movbu (4,a1),d0
 add d0,d3
 add d3,d3
 movbu (5,a1),d0
 add d0,d3
 mov d3,(20,sp)
 mov (st_key),d0                  /* nothing changed and the strip on screen: done */
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
 call st_join,[d2,d3,a2,a3],64    /* a1 = the buffer -> d0 = the stream's length (0: too long, nothing) */
 cmp 0,d0
 beq 9f
 mov GDESC,a0
 mov HB_W,d1
 movhu d1,(2,a0)
 mov HB_H,d1
 movhu d1,(4,a0)
 mov d0,(12,a0)
 mov a1,(16,a0)
 mov a1,(hb_cur)
 mov (20,sp),d0
 mov d0,(st_key)
 mov -1,d0                        /* the bar's picture and colours are gone */
 mov d0,(hb_key)
 call st_spal,[d2,d3,a2,a3],20
9:
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 mov (16,sp),a1
 ret [d2,d3,a2,a3],ST_F

/* st_spal: `call st_spal,[d2,d3,a2,a3],20`: st_pal into palette 62's entries 108..120 (table and screen), as hb_spal. */
st_spal:
 mov st_pal,a0
 mov HB_PALT,a1
 mov HB_NSLOT,d1
1:
 mov (a0),d0
 mov d0,(a1)
 add 4,a0
 add 4,a1
 add -1,d1
 bne 1b
 mov HB_SLOT0,d0
 mov HB_NSLOT,d1
 mov hb_lobj,a0
 mov HB_PALT,a1
 calls gpi_setpal
 ret [d2,d3,a2,a3],20

/* st_put: `call st_put,[],0`, a0 = st_sp's entry, d0 = the sprite (u16 w, h, bytes), d1 = its x, a1 = its y: noted. */
st_put:
 mov d0,(a0)
 movhu d1,(4,a0)
 mov a1,d0
 movhu d0,(6,a0)
 ret [],0                         /* (st_dotp's mul changed MDR: not retf) */

/* st_dotp: `call st_dotp,[],0`, a1 = st_v + 2i (colour, strength), d1 = the wheel's middle column, a0 = st_sp's entry:
 * the dot's place (st_dxy). Uses d0, a1. */
st_dotp:
 movbu (a1),d0
 mov 11,d2
 mul d2,d0
 movbu (1,a1),d2
 add d2,d0
 add d0,d0
 add st_dxy,d0
 mov d0,a1
 movbu (a1),d0
 extb d0
 add d0,d1
 movbu (1,a1),d0
 extb d0
 add ST_CY,d0
 mov d0,a1
 mov st_dot,d0
 jmp st_put

/* st_join: `call st_join,[d2,d3,a2,a3],64`, a1 = a stream buffer (HB_BUF bytes): st_v's strip as mkstwheel.stream ->
 * d0 = its length, 0 when it would not fit; a1 kept. Locals (4) y, (8) the buffer, (12) its limit, (16) the
 * background's row table, (20) tokens left in a background row, (24) sprite i. */
st_join:
 mov a1,(8,sp)
 mov a1,d0
 add HB_BUF - 16,d0
 mov d0,(12,sp)
 movbu (st_v + 5),d0              /* the page's background: st_bg + 128 (page - 5) */
 asl 7,d0
 add st_bg,d0
 mov d0,(16,sp)
 mov st_sp,a0                     /* the sprites */
 mov a0,(24,sp)
 mov st_v,a1
 mov ST_CX0,d1
 call st_dotp,[],0
 mov (24,sp),a0
 add 8,a0
 mov st_v + 2,a1
 mov ST_CX1,d1
 call st_dotp,[],0
 mov (24,sp),a0
 add 16,a0
 movbu (st_v + 4),d0
 add d0,d0
 mov st_cx,a1
 add d0,a1
 movhu (a1),d1
 mov ST_CTOP,a1
 mov st_car,d0
 call st_put,[],0
 mov (24,sp),a0
 add 24,a0
 movbu (st_v + 4),d0
 asl2 d0
 mov st_vtab,a1
 add d0,a1
 mov (a1),d0
 mov ST_VX,d1
 mov ST_VY,a1
 call st_put,[],0
 mov (8,sp),a1
 mov ST_HDR,d0                    /* 400 x 64, type 11 */
 mov d0,(a1)
 mov a1,a3
 add 4,a3
 clr d2
 clr d3
 mov 0,a2
 clr d0
 mov d0,(4,sp)
10:                               /* a row: its background */
 mov (4,sp),d0
 add d0,d0
 mov (16,sp),a0
 add d0,a0
 movhu (a0),d0
 asl2 d0
 mov st_rows,a0
 add d0,a0
 mov (a0),d0
 mov d0,d1
 and 255,d1
 mov d1,(20,sp)
 lsr 8,d0
 add d0,d0
 add st_tok,d0
 mov d0,a0
 mov st_row,a1
11:
 mov (20,sp),d1
 cmp 0,d1
 beq 20f
 add -1,d1
 mov d1,(20,sp)
 movhu (a0),d0
 add 2,a0
 mov d0,d1
 and 15,d1
 inc d1                           /* the run */
 lsr 4,d0                         /* the colour */
12:
 movbu d0,(a1)
 inc a1
 add -1,d1
 bne 12b
 bra 11b
20:                               /* the sprites over it */
 clr d0
 mov d0,(24,sp)
21:
 mov (24,sp),d0
 asl 3,d0
 add st_sp,d0
 mov d0,a0
 movhu (6,a0),d1                  /* r = y - its y */
 mov (4,sp),d0
 sub d1,d0
 blt 29f
 mov (a0),a1                      /* the sprite */
 movhu (2,a1),d1                  /* its height */
 cmp d1,d0
 bcc 29f
 movhu (a1),d1                    /* its width */
 mul d1,d0
 add 4,d0
 add d0,a1                        /* its row r */
 movhu (4,a0),d0
 add st_row,d0
 mov d0,a0                        /* where it goes */
22:
 movbu (a1),d0
 inc a1
 cmp 0,d0
 beq 23f
 movbu d0,(a0)
23:
 inc a0
 add -1,d1
 bne 22b
29:
 mov (24,sp),d0
 inc d0
 mov d0,(24,sp)
 cmp 4,d0
 bne 21b
 mov st_row,a0                    /* the row as runs of up to 16 */
30:
 movbu (a0),d1
 mov a0,a1
 inc a1
31:
 cmp st_rend,a1
 beq 32f
 mov a1,d0
 sub a0,d0
 cmp 16,d0
 beq 32f
 movbu (a1),d0
 cmp d1,d0
 bne 32f
 inc a1
 bra 31b
32:
 mov a1,d0
 sub a0,d0
 add -1,d0
 asl 4,d1
 or d1,d0
 HB_PUT
 mov a1,a0
 cmp st_rend,a0
 bne 30b
 mov (12,sp),d0                   /* too long: nothing */
 cmp d0,a3
 bcc 70f
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
 mov (8,sp),a1
 mov a3,d0
 mov a1,d1
 sub d1,d0
 ret [d2,d3,a2,a3],64
70:
 mov (8,sp),a1
 clr d0
 ret [d2,d3,a2,a3],64
