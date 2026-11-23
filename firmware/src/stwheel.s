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
.set ST_PANV, (ST_PX - 80) | (ST_PY << 16)   /* the panel's (the viewfinder's right-hand widgets sit 80 px left of the rear screen's) */
.set ST_DX, -196                   /* the camera's column moves this far while the panel shows */
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

/* ST_HP reg, miss: reg is a word-aligned pointer into the heap's RAM (0x62000000..0x65ffffff; om-emu's GUI objects
 * are at 0x62c5...., w4 took only 0x62...... and found nothing on the camera), else miss. Uses d1. */
 .macro ST_HP reg, miss
 mov \reg,d1
 and 3,d1
 bne \miss
 mov \reg,d1
 add -0x62000000,d1
 cmp 0x04000000,d1
 bcc \miss
 .endm

/* st_place: `call st_place,[d2,d3,a2,a3],28`, d0 = 1 the panel's places / 0 the camera's -> d1 = 1 done, 0 nothing
 * changed. The screen's widget parent: (ST_GUI) -> (+0xdc); its children (st_wt): the guide picture's widget (0x3c7)
 * goes to the panel's place, at the right of the screen where the camera's wheel was; the camera's button frame
 * (0x3c6) to 4 x 4 pixels under the Shadows wheel's middle (it would show where the bar was); and the camera's own
 * column there (the two dial marks, "Color" and its swatch, the page label, its value and its mark, Reset's two) ST_DX
 * to the left, beside the panel. Each widget only if it checks out (st_w1); the picture's decides the answer. om-emu,
 * 2026-11-23. Uses d0, d1, a0, a1. */
st_place:
 mov d0,d3
 mov (ST_GUI),d0
 ST_HP d0, 8f
 mov d0,a0
 mov (0xdc,a0),d0
 ST_HP d0, 8f
 mov d0,(st_par)
 mov st_wt,a1
 call st_w1,[],4
 cmp 0,d1
 beq 8f
1:
 add 40,a1
 cmp st_wte,a1
 beq 2f
 call st_w1,[],4                  /* (keeps a1, d3) */
 bra 1b
2:
 mov 1,d1
 ret [d2,d3,a2,a3],28
8:
 clr d1
 ret [d2,d3,a2,a3],28

/* st_wt: per widget 10 words: its child slot in the parent, its id word, its method table, where its copy of the
 * rectangles is (viewfinder x | y << 16, w | h << 16, rear screen, w | h << 16), then its two places (viewfinder,
 * rear screen, size): the camera's, the panel's. ST_WT / ST_WX: a picture / the value text of the camera's column: the
 * camera's place and that place ST_DX to the left. (om-emu, 2026-11-23: slots, ids, tables, rectangles.) */
 .macro ST_WT off, id, xv, xr, y, w, h
 .long \off, (\id << 16) | 0x8003, ST_WVT, 0x140
 .long \xv | (\y << 16), \xr | (\y << 16), \w | (\h << 16)
 .long (\xv + ST_DX) | (\y << 16), (\xr + ST_DX) | (\y << 16), \w | (\h << 16)
 .endm
 .macro ST_WX off, id, xv, xr, y, w, h
 .long \off, (\id << 16) | 0x8013, 0x6135946c, 0xc0
 .long \xv | (\y << 16), \xr | (\y << 16), \w | (\h << 16)
 .long (\xv + ST_DX) | (\y << 16), (\xr + ST_DX) | (\y << 16), \w | (\h << 16)
 .endm
 .balign 4
st_par:                           /* the widget parent (st_place -> st_w1) */
 .long 0
st_wt:
 .long 0x344, ST_WID, ST_WVT, 0x140              /* the guide picture: the bar's place, the panel's */
 .long ST_BARV, ST_BARR, ST_BARS
 .long ST_PANV, ST_PANR, ST_PANS
 .long 0x340, 0x03c68003, ST_WVT, 0x140          /* the button frame behind it */
 .long ST_BARV, ST_BARR, ST_BARS
 .long (ST_PX - 80 + ST_CX0 - 2) | ((ST_PY + ST_CY0 - 2) << 16), (ST_PX + ST_CX0 - 2) | ((ST_PY + ST_CY0 - 2) << 16), 4 | (4 << 16)
 ST_WT 0x31c, 0x179, 542, 622, 115, 36, 24     /* the front dial's mark */
 ST_WT 0x320, 0x3c0, 542, 622, 461, 36, 24     /* the rear dial's */
 ST_WT 0x324, 0x3c1, 578, 658, 112, 70, 30     /* "Color" */
 ST_WT 0x328, 0x3c2, 648, 728, 112, 38, 30     /* its swatch */
 ST_WT 0x32c, 0x3c3, 578, 658, 458, 70, 30     /* the page label ("Tint") */
 ST_WX 0x330, 0x3c4, 652, 732, 458, 29, 30     /* its value (a text widget) */
 ST_WT 0x334, 0x3c5, 648, 728, 458, 38, 30     /* (the value's picture form) */
 ST_WT 0x338, 0x3be, 524, 604, 528, 180, 50    /* Reset */
 ST_WT 0x33c, 0x3bf, 524, 604, 528, 180, 50
st_wte:

/* st_w1: `call st_w1,[],4`, a1 = the widget's st_wt entry, d3 = 1 the panel's place / 0 the camera's, (st_par) the
 * parent -> d1 = 1 written, 0 not. The child must have the entry's method table and id word and hold one of the
 * entry's two places in its copy of the rectangles; +8 is the rectangle in use (viewfinder or rear screen), +12 its
 * size. Keeps a1, d3; uses d0, d1, d2, a0, a2, a3. */
st_w1:
 mov (st_par),a0                  /* w5: the child with the entry's method table and id word in any of the parent's */
 add 0x300,a0                     /* slots +0x300..+0x35c (w4 took the slot om-emu has it in) */
 mov 24,d2
0:
 mov (a0),d0
 ST_HP d0, 7f
 mov d0,a2
 mov (a2),d0
 mov (8,a1),d1
 cmp d1,d0
 bne 7f
 mov (4,a2),d0
 mov (4,a1),d1
 cmp d1,d0
 beq 9f
7:
 add 4,a0
 add -1,d2
 bne 0b
 bra 8f
9:
 mov (12,a1),d0
 mov a2,a3
 add d0,a3                        /* its copies: (0) viewfinder, (4) size, (8) rear screen, (12) size */
 mov a1,a0
 add 16,a0
 mov 2,d2
1:
 mov (a0),d0                      /* this place? (all four words) */
 mov (a3),d1
 cmp d0,d1
 bne 2f
 mov (4,a0),d0
 mov (8,a3),d1
 cmp d0,d1
 bne 2f
 mov (8,a0),d0
 mov (4,a3),d1
 cmp d0,d1
 bne 2f
 mov (12,a3),d1
 cmp d0,d1
 beq 3f
2:
 add 12,a0
 add -1,d2
 bne 1b
 bra 8f
3:
 mov (8,a2),d0                    /* in use: the viewfinder's (d2 = 1) or the rear screen's (0) */
 mov (a3),d1
 clr d2
 cmp d0,d1
 bne 4f
 inc d2
4:
 mov a1,a0
 add 16,a0
 cmp 0,d3
 beq 5f
 add 12,a0
5:
 mov (a0),d0
 mov d0,(a3)
 mov (4,a0),d1
 mov d1,(8,a3)
 cmp 0,d2
 bne 6f
 mov d1,d0
6:
 mov d0,(8,a2)
 mov (8,a0),d0
 mov d0,(4,a3)
 mov d0,(12,a3)
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
 .ifdef ST_DIAGTEST
 clr d1                           /* (a research build: as if the widgets were not found) */
 .else
 call st_place,[d2,d3,a2,a3],28
 .endif
 cmp 0,d1
 bne 7f
 mov 2,d0
 mov d0,(st_dst)
 mov d3,a1                        /* not found: what is there, as hex, in the bar's place and the debug log (st_diag) */
 call st_diag,[d2,d3,a2,a3],64
 bra 9f
7:
 mov 1,d0
 mov d0,(st_dst)
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

/* ------------------------------------------------------------------ w5: what the camera has, on the screen
 * When st_place does not find the guide picture's widget, the bar's place (400 x 64) shows 7 lines of 7 hex words
 * (st_hexf, 5 x 7 digits, white on black) for a photo of the screen:
 *  line 1: (ST_GUI), then its +0xdc, +0xd0, +0xd4, +0xd8, +0xe0, +0x130
 *  lines 2, 3: the parent's (+0xdc's) slots +0x310..+0x344
 *  line 4: slot +0x344's object: +0, +4, +8, +12, +0x140, +0x144, +0x148; line 5: slot +0x324's, the same;
 *  line 6: slot +0x330's: +0, +4, +8, +12, +0xc0, +0xc4, +0xc8; line 7: slot +0x340's, as line 4.
 * EEEEEEEE: not read (the pointer before it is not a heap address). */
 .balign 4
st_dw:
 .space 49 * 4
st_do1:
 .short 0xdc, 0xd0, 0xd4, 0xd8, 0xe0, 0x130
st_doa:
 .short 0, 4, 8, 12, 0x140, 0x144, 0x148
st_dob:
 .short 0, 4, 8, 12, 0xc0, 0xc4, 0xc8
st_drow:
 .space 400
st_drend:
 .balign 2

st_dst:                           /* 0 the panel not asked for yet, 1 st_place moved the widgets, 2 it found none (st_dw) */
 .long 0
st_ls:
 .asciz "\r\nSplit toning panel (w5; 1 placed, 2 not found, then st_diag's 49 words): "
st_lnl:
 .asciz "\r\n  "
st_lsp:
 .asciz " "
 .balign 2

/* st_lg: `call st_lg,[d2,d3,a2,a3],24` from the debug log's NOW section (lg_now): st_dst and st_dw, 7 words a line. */
st_lg:
 LGS st_ls
 mov (st_dst),d0
 call lg_h,[],0
 mov (st_dst),d0                  /* the words only when it found none */
 cmp 2,d0
 bne 3f
 mov st_dw,a2
 clr d2
1:
 mov d2,d0
 mov 7,d1
 clr d3
 mov d3,mdr
 divu d1,d0
 mov mdr,d0
 cmp 0,d0
 bne 2f
 LGS st_lnl
2:
 mov (a2),d0
 call lg_h,[],0
 LGS st_lsp
 add 4,a2
 inc d2
 cmp 49,d2
 bne 1b
3:
 ret [d2,d3,a2,a3],24

/* st_dcp: `call st_dcp,[],4`, a0 = an object, a2 = d2 offsets (u16), a1 = where: its words there. Uses d0, d2, a1, a2, a3. */
st_dcp:
 movhu (a2),d0
 add 2,a2
 mov a0,a3
 add d0,a3
 mov (a3),d0
 mov d0,(a1)
 add 4,a1
 add -1,d2
 bne st_dcp
 ret [],4

/* ST_DW src, offs, dst: st_dw[src] a heap pointer -> its 7 words at offs into st_dw[dst..]. */
 .macro ST_DW src, offs, dst
 mov (st_dw + 4 * \src),d0
 ST_HP d0, 91f
 mov d0,a0
 mov \offs,a2
 mov 7,d2
 mov st_dw + 4 * \dst,a1
 call st_dcp,[],4
91:
 .endm

/* st_diag: `call st_diag,[d2,d3,a2,a3],64`, a1 = a stream buffer: the words above into it and into GDESC (400 x 64).
 * Locals (4) y, (8) the buffer, (12) the digit row, (16) the line's next word, (20) word i, (24) digits left, (28) the
 * word. Uses d0, d1, a0, a1. */
st_diag:
 mov a1,(8,sp)
 mov st_dw,a0
 mov 49,d0
 mov 0xeeeeeeee,d1
1:
 mov d1,(a0)
 add 4,a0
 add -1,d0
 bne 1b
 mov (ST_GUI),d0
 mov d0,(st_dw)
 ST_HP d0, 5f
 mov d0,a0
 mov st_do1,a2
 mov 6,d2
 mov st_dw + 4,a1
 call st_dcp,[],4
 mov (st_dw + 4),d0
 ST_HP d0, 5f
 mov d0,a0
 add 0x310,a0
 mov st_dw + 28,a1
 mov 14,d2
2:
 mov (a0),d0
 mov d0,(a1)
 add 4,a0
 add 4,a1
 add -1,d2
 bne 2b
 ST_DW 20, st_doa, 21
 ST_DW 12, st_doa, 28
 ST_DW 15, st_dob, 35
 ST_DW 19, st_doa, 42
5:
 mov (8,sp),a1
 mov HB_HDR,d0                    /* 400 x 64, type 11 */
 mov d0,(a1)
 mov a1,a3
 add 4,a3
 clr d2
 clr d3
 mov 0,a2
 clr d0
 mov d0,(4,sp)
10:                               /* a row: black */
 mov st_drow,a0
 mov 400,d1
 mov 7,d0
11:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 11b
 mov (4,sp),d0                    /* line y / 9, digit row y % 9 (rows 7, 8 of a line and lines 7.. stay black) */
 clr d1
12:
 cmp 9,d0
 bcs 13f
 add -9,d0
 inc d1
 bra 12b
13:
 cmp 7,d0
 bcc 30f
 cmp 7,d1
 bcc 30f
 mov d0,(12,sp)
 mov 28,d0
 mul d0,d1
 add st_dw,d1
 mov d1,(16,sp)
 clr d0
 mov d0,(20,sp)
 mov st_drow + 4,a0
14:                               /* a word: 8 digits */
 mov (16,sp),a1
 mov (a1),d1
 add 4,a1
 mov a1,(16,sp)
 mov 8,d0
 mov d0,(24,sp)
15:
 mov d1,d0
 lsr 28,d0
 asl 4,d1
 mov d1,(28,sp)
 mov 7,d1
 mul d1,d0
 mov (12,sp),d1
 add d1,d0
 add st_hexf,d0
 mov d0,a1
 movbu (a1),d0                    /* the digit's row: 5 pixels, bit 4 the left one */
 mov 10,d1
 mov a0,a1
 add 5,a1
16:
 btst 16,d0
 beq 17f
 movbu d1,(a0)
17:
 add d0,d0
 inc a0
 cmp a1,a0
 bne 16b
 inc a0
 mov (28,sp),d1
 mov (24,sp),d0
 add -1,d0
 mov d0,(24,sp)
 bne 15b
 add 8,a0
 mov (20,sp),d0
 inc d0
 mov d0,(20,sp)
 cmp 7,d0
 bne 14b
30:                               /* the row as runs of up to 16 */
 mov st_drow,a0
31:
 movbu (a0),d1
 mov a0,a1
 inc a1
32:
 cmp st_drend,a1
 beq 33f
 mov a1,d0
 sub a0,d0
 cmp 16,d0
 beq 33f
 movbu (a1),d0
 cmp d1,d0
 bne 33f
 inc a1
 bra 32b
33:
 mov a1,d0
 sub a0,d0
 add -1,d0
 asl 4,d1
 or d1,d0
 HB_PUT
 mov a1,a0
 cmp st_drend,a0
 bne 31b
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
 mov GDESC,a0
 mov HB_W,d1
 movhu d1,(2,a0)
 mov HB_PH,d1
 movhu d1,(4,a0)
 mov d0,(12,a0)
 mov a1,(16,a0)
 mov a1,(hb_cur)
 mov -1,d0                        /* neither the panel nor the bar is on screen */
 mov d0,(st_key)
 mov d0,(hb_key)
 ret [d2,d3,a2,a3],64

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
