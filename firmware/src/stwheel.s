/* ================================================================== the Split toning panel, test w4 (feature/split-tone-row)
 * Owner (2026-11-23), mock-up C (two wheels and the Balance slider on one screen) -> w1 (a strip under the camera's
 * wheel) -> w2 (INFO to Balance, 400 x 200) -> w3 (no camera wheel on the row, camera-tested; points and cursor) ->
 * w4 (owner: the wheels stacked at the left of the screen, Highlights on top, Shadows, then the Balance bar; the
 * colour's point moves with its value):
 *  - INFO on the row steps Shadows -> Balance -> Highlights -> Shadows. Balance is the Highlights page (P+AXIS 6) with
 *    st_bal set (hb_next): there the readout and the dial read and write Tone Balance (slot +33, -5..5) in place of
 *    the tint (tn_get -> st_bv, tn_set -> sp_all / st_tset, then the wheel's own refresh s_cur; the readout's -5..+5
 *    glyphs: rd_a10 / rd_b10). Arriving on the row or leaving it clears st_bal (sp_sync).
 *  - card/mkstwheel.py's panel (188 x 481) goes into the guide's descriptor (GDESC) as the H / S / L bar does, and the
 *    guide picture's widget moves to the panel's place while it shows (st_place): the widgets copy their rectangles
 *    when Picture Mode opens, so the static ones (build.py: the bar's 400 x 64) cannot follow the row. st_place
 *    reaches the widget from the GUI's own pointers and changes nothing unless every step checks out; without it
 *    the panel is not drawn (the page's guide stays). hb_gsel puts the bar's place back on any page change.
 * When: the readout (916 + slice) on the row's pages goes through tn_get, whose dial-label call (vl_s) goes through
 * st_vl -> st_rd first (only with the films in, nothing at start-up). st_rd builds the panel only when something on it
 * changed, into the bar's heap buffer not on screen (hb_b0 / hb_b1, 16448 B each: malloc's largest), and puts the 12
 * hues into palette 62's entries 108..119 (the bar's slots; each one's new picture makes the other's key stale:
 * hb_key, st_key).
 * Each row: its three background parts (the page's variant) into st_row, then the seven sprites over it (per wheel an
 * eraser over the tint colour's point and its dot; the caret, the value, the cursor's ring; 0 = see-through), then
 * st_row as greedy runs of up to 16 (HB_PUT), as mkstwheel.stream. A stream that would not fit its buffer is not drawn. */
.section .ext15,"ax"
 .include "stwheel.inc"           /* ST_*, st_rows, st_bg, st_cx, st_tok, st_dxy, st_exy, st_dot, st_car, st_cur, st_etab, st_none, st_vtab, st_pal */
.set ST_F, 48                     /* st_rd's frame */
.set ST_GUI, 0x608546f8            /* the GUI's pointer to the open screen's layout object (om-emu: 0x62c5a140) */
.set ST_WVT, 0x6135993c            /* a picture widget's method table */
.set ST_WID, 0x03c78003            /* the guide picture's id word (widget 0x3c7) */
.set ST_BARV, 116 | (514 << 16)    /* the bar's place (build.py): viewfinder, rear screen, size */
.set ST_BARR, 157 | (514 << 16)
.set ST_BARS, 400 | (64 << 16)
.set ST_PANV, (ST_PX - 41) | (ST_PY << 16)   /* the panel's */
.set ST_PANR, ST_PX | (ST_PY << 16)
.set ST_PANS, ST_W | (ST_H << 16)
 .balign 4
st_key:                           /* what the panel on screen shows (st_rd's key), -1 none */
 .long -1
st_boff:                          /* sp_all -> st_tset: P offset of the Tone Balance byte just written */
 .long 0
st_v:                             /* Shadows colour, strength, Highlights colour, strength, Balance + 5, mode, the cursor's colour (w3) */
 .byte 0, 0, 0, 0, 0, 0, 0, 0
st_bal:                           /* 1: the row's Balance step (on the Highlights page) */
 .byte 0
 .balign 4
st_sv:                            /* hb_gsel's d0 over st_place */
 .long 0
st_wxy:                           /* the wheels' middles: Shadows x, y, Highlights x, y */
 .short ST_CX0, ST_CY0, ST_CX1, ST_CY1
st_sp:                            /* the seven sprites: u32 picture, u16 x, u16 y */
 .space 56
st_row:                           /* the row being built */
 .space ST_W
st_rend:
 .balign 2

/* ST_HP reg, miss: reg is a word-aligned pointer into the GUI's heap (0x62......), else miss. Uses d1. */
 .macro ST_HP reg, miss
 mov \reg,d1
 and 0xff000003,d1
 cmp 0x62000000,d1
 bne \miss
 .endm

/* st_place: `call st_place,[d2,d3,a2,a3],28`, d0 = 1 the panel's place / 0 the bar's -> d1 = 1 done, 0 nothing
 * changed. The screen's widget parent: (ST_GUI) -> (+0xdc); its child 7 is the guide picture's widget (0x3c7), child
 * 6 the camera's button frame behind it (0x3c6): for the panel the picture goes to the panel's place and the frame to
 * 4 x 4 pixels under the Shadows wheel's middle (it would show where the bar was). Each widget only if it checks out
 * (st_w1); the picture's decides the answer. om-emu, 2026-11-23. Uses d0, d1, a0, a1. */
st_place:
 mov d0,d3
 mov (ST_GUI),d0
 ST_HP d0, 8f
 mov d0,a0
 mov (0xdc,a0),d0
 ST_HP d0, 8f
 mov d0,a3
 mov st_wt7,a1
 call st_w1,[],4
 cmp 0,d1
 beq 8f
 mov st_wt6,a1
 call st_w1,[],4
 mov 1,d1
 ret [d2,d3,a2,a3],28
8:
 clr d1
 ret [d2,d3,a2,a3],28

 .balign 4
st_wt7:                           /* the child's place in the parent, its id word; the bar's rectangles (viewfinder */
 .long 0x344, ST_WID              /* x | y << 16, rear screen, w | h << 16), the panel's */
 .long ST_BARV, ST_BARR, ST_BARS
 .long ST_PANV, ST_PANR, ST_PANS
st_wt6:
 .long 0x340, 0x03c68003
 .long ST_BARV, ST_BARR, ST_BARS
 .long (ST_PX - 41 + ST_CX0 - 2) | ((ST_PY + ST_CY0 - 2) << 16), (ST_PX + ST_CX0 - 2) | ((ST_PY + ST_CY0 - 2) << 16), 4 | (4 << 16)

/* st_w1: `call st_w1,[],4`, a3 = the parent, a1 = the widget's table (st_wt7 / st_wt6), d3 = 1 the panel's place / 0
 * the bar's -> d1 = 1 written, 0 not. The child must be a picture widget (ST_WVT) with the table's id and hold one of
 * the table's two places in its copy of the rectangles (+0x140 viewfinder, +0x148 rear screen: x, y, w, h shorts);
 * +8 is the one in use. Uses d0, d1, d2, a0, a2. */
st_w1:
 mov (a1),d0
 mov a3,a0
 add d0,a0
 mov (a0),d0
 ST_HP d0, 8f
 mov d0,a2
 mov (a2),d0
 cmp ST_WVT,d0
 bne 8f
 mov (4,a2),d0
 mov (4,a1),d1
 cmp d1,d0
 bne 8f
 mov a1,a0
 add 8,a0
 mov 2,d2
1:
 mov (a0),d0                      /* this place? (all four words) */
 mov (0x140,a2),d1
 cmp d0,d1
 bne 2f
 mov (4,a0),d0
 mov (0x148,a2),d1
 cmp d0,d1
 bne 2f
 mov (8,a0),d0
 mov (0x144,a2),d1
 cmp d0,d1
 bne 2f
 mov (0x14c,a2),d1
 cmp d0,d1
 beq 3f
2:
 add 12,a0
 add -1,d2
 bne 1b
 bra 8f
3:
 mov (8,a2),d0                    /* in use: the viewfinder's (d2 = 1) or the rear screen's (0) */
 mov (0x140,a2),d1
 clr d2
 cmp d0,d1
 bne 4f
 inc d2
4:
 mov a1,a0
 add 8,a0
 cmp 0,d3
 beq 5f
 add 12,a0
5:
 mov (a0),d0
 mov d0,(0x140,a2)
 mov (4,a0),d1
 mov d1,(0x148,a2)
 cmp 0,d2
 bne 6f
 mov d1,d0
6:
 mov d0,(8,a2)
 mov (8,a0),d0
 mov d0,(0x144,a2)
 mov d0,(0x14c,a2)
 mov d0,(12,a2)
 mov 1,d1
 ret [],4
8:
 clr d1
 ret [],4

/* st_vl <- tn_get's readout `call st_vl,[d2,d3,a2,a3],20` (was vl_s; a2 = P): the panel, then vl_s in the same frame. */
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

/* st_rd: `call st_rd,[d2,d3,a2,a3],ST_F`, a2 = P, d2 = the readout's slice (the cursor's colour, 0..11). Keeps d0, d1,
 * a0, a1 (and d2, d3, a2, a3 by the call); MDR not. Locals (4) d0, (8) d1, (12) a0, (16) a1, (20) key. */
st_rd:
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 cmp 12,d2
 bcc 9f
 movbu d2,(st_v + 6)
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
 movbu d3,(st_v + 5)
 movbu (EDK,a2),d0
 cmp 4,d0
 bcc 9f
 mov GDESC,a0                     /* the camera's 14 / 175 x 50 / 8 descriptor, or the bar's, or ours */
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
 bne 1f
 cmp HB_PH,d2
 beq 3f
 bra 9f
1:
 cmp ST_W,d1
 bne 9f
 cmp ST_H,d2
 bne 9f
3:
 movhu (6,a0),d1
 cmp 8,d1
 bne 9f
 mov (16,a0),d1                   /* holding the camera's guide, the bar, ours, GUIDES.BIN's or TONES.BIN's */
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
 mov st_v,a1                      /* key: the six values, base 12 / 11 / 12 / 11 / 11 / 3 */
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
 mov 3,d1
 mul d1,d3
 movbu (5,a1),d0
 add d0,d3
 mov 12,d1
 mul d1,d3
 movbu (6,a1),d0
 add d0,d3
 mov d3,(20,sp)
 mov (st_key),d0                  /* nothing changed and the panel on screen: done */
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
 mov d0,d2                        /* the widget to the panel's place first: not there, no panel (uses d0, d1, a0, a1) */
 mov a1,d3
 mov 1,d0
 call st_place,[d2,d3,a2,a3],28
 cmp 0,d1
 beq 9f
 mov d2,d0
 mov d3,a1
 mov GDESC,a0
 mov ST_W,d1
 movhu d1,(2,a0)
 mov ST_H,d1
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

/* st_wh: `call st_wh,[],4`, d3 = wheel i (0 Shadows, 1 Highlights): its two sprites, st_sp's entries i (the eraser
 * over the tint colour's point) and 2 + i (the dot); strength 0: neither (st_none). Uses d0, d1, d2, a0, a1, a2, a3. */
st_wh:
 mov d3,d0
 asl2 d0
 add st_wxy,d0
 mov d0,a3                        /* the wheel's middle: x, y */
 mov d3,d0
 add d0,d0
 add st_v,d0
 mov d0,a2                        /* its tint: colour, strength */
 mov d3,d0
 asl 3,d0
 add st_sp,d0
 mov d0,a0
 movbu (1,a2),d2
 cmp 0,d2
 bne 1f
 mov st_none,d0
 clr d1
 mov d1,a1
 call st_put,[],0
 add 16,a0
 mov st_none,d0
 clr d1
 mov d1,a1
 call st_put,[],0
 ret [],4
1:
 movbu (a2),d2                    /* the eraser: st_etab[colour] at the colour's point (st_exy) */
 mov d2,d0
 add d0,d0
 add st_exy,d0
 mov d0,a1
 movbu (a1),d1
 extb d1
 movhu (a3),d0
 add d0,d1
 movbu (1,a1),d0
 extb d0
 mov d0,a1
 movhu (2,a3),d0
 add d0,a1
 mov d2,d0
 asl2 d0
 add st_etab,d0
 mov d0,a2
 mov (a2),d0
 call st_put,[],0
 add 16,a0                        /* the dot: at st_dxy[colour * 11 + strength] */
 mov d3,d0
 add d0,d0
 add st_v,d0
 mov d0,a2
 movbu (a2),d0
 mov 11,d2
 mul d2,d0
 movbu (1,a2),d2
 add d2,d0
 add d0,d0
 add st_dxy,d0
 mov d0,a1
 movbu (a1),d1
 extb d1
 movhu (a3),d0
 add d0,d1
 movbu (1,a1),d0
 extb d0
 mov d0,a1
 movhu (2,a3),d0
 add d0,a1
 mov st_dot,d0
 call st_put,[],0
 ret [],4

/* st_half: `call st_half,[],8`, a0 = a background part's table entry (u16 st_rows index), a1 = where in st_row ->
 * its pixels; a1 after them. Uses d0, d1, a0; local (4) the tokens left. */
st_half:
 movhu (a0),d0
 asl2 d0
 mov st_rows,a0
 add d0,a0
 mov (a0),d0
 mov d0,d1
 and 255,d1
 lsr 8,d0
 add d0,d0
 add st_tok,d0
 mov d0,a0
 cmp 0,d1
 beq 9f
1:
 movhu (a0),d0
 add 2,a0
 mov d1,(4,sp)                    /* tokens left */
 mov d0,d1
 and 15,d1
 inc d1                           /* the run */
 lsr 4,d0                         /* the colour */
2:
 movbu d0,(a1)
 inc a1
 add -1,d1
 bne 2b
 mov (4,sp),d1
 add -1,d1
 bne 1b
9:
 ret [],8

/* st_join: `call st_join,[d2,d3,a2,a3],64`, a1 = a stream buffer (HB_BUF bytes): st_v's panel as mkstwheel.stream ->
 * d0 = its length, 0 when it would not fit; a1 kept. Locals (4) y, (8) the buffer, (12) its limit, (16) the page's
 * first part table (st_bg + 2 H mode; the next parts 6 H bytes on), (20) part k, (24) sprite i. */
st_join:
 mov a1,(8,sp)
 mov a1,d0
 add HB_BUF - 16,d0
 mov d0,(12,sp)
 movbu (st_v + 5),d0              /* the page's parts */
 mov ST_H * 2,d1
 mul d1,d0
 add st_bg,d0
 mov d0,(16,sp)
 clr d3                           /* the sprites: per wheel its eraser and dot */
 call st_wh,[],4
 mov 1,d3
 call st_wh,[],4
 mov st_sp + 32,a0                /* the caret: its column from Tone Balance */
 movbu (st_v + 4),d0
 add d0,d0
 mov st_cx,a1
 add d0,a1
 movhu (a1),d1
 mov ST_CTOP,a1
 mov st_car,d0
 call st_put,[],0
 mov st_sp + 40,a0                /* the value */
 movbu (st_v + 4),d0
 asl2 d0
 mov st_vtab,a1
 add d0,a1
 mov (a1),d0
 mov ST_VX,d1
 mov ST_VY,a1
 call st_put,[],0
 mov st_sp + 48,a0                /* the cursor's ring on the page's wheel (none on Balance): at the cursor */
 mov st_none,d0                   /* colour's point, or at the dot when that colour is the tint's */
 clr d1
 mov d1,a1
 movbu (st_v + 5),d2
 cmp 2,d2
 bcc 4f
 add d2,d2
 add st_v,d2
 mov d2,a1                        /* the page's tint: colour, strength */
 movbu (st_v + 6),d0
 movbu (a1),d2
 cmp d0,d2
 bne 1f
 movbu (1,a1),d2
 bra 2f
1:
 clr d2
2:
 mov 11,d1
 mul d1,d0
 add d2,d0
 add d0,d0
 add st_dxy,d0
 mov d0,a1
 movbu (st_v + 5),d0
 asl2 d0
 add st_wxy,d0
 mov d0,a3
 movbu (a1),d1
 extb d1
 movhu (a3),d0
 add d0,d1
 add ST_CURD,d1
 movbu (1,a1),d0
 extb d0
 mov d0,a1
 movhu (2,a3),d0
 add d0,a1
 add ST_CURD,a1
 mov st_cur,d0
4:
 call st_put,[],0
 mov (8,sp),a1
 mov ST_HDR,d0                    /* ST_W x ST_H, type 11 */
 mov d0,(a1)
 mov a1,a3
 add 4,a3
 clr d2
 clr d3
 mov 0,a2
 clr d0
 mov d0,(4,sp)
10:                               /* a row: its three background parts */
 mov st_row,a1
 clr d0
 mov d0,(20,sp)
11:
 mov (20,sp),d1                   /* part k's entry: (16) + 6 H k + 2 y */
 mov ST_H * 6,d0
 mul d0,d1
 mov (4,sp),d0
 add d0,d0
 add d0,d1
 mov (16,sp),d0
 add d0,d1
 mov d1,a0
 call st_half,[],8
 mov (20,sp),d0
 inc d0
 mov d0,(20,sp)
 cmp 3,d0
 bne 11b
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
 cmp 7,d0
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
 cmp ST_H,d0
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
