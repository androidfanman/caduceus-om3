/* Framing lines (#104, 2026-11-27): two more choices in the camera's Displayed Grid list, 10 "Cross" (a centre line
 * each way) and 11 "Ticks" (short marks at the middle of each edge and a small centre cross). firmware/gridlines.py
 * adds them to the lists (validators of 155 / 2047, the Displayed Grid menu records); the movie grid (446) is left
 * alone. The grid builders look the value up (0x611c78c7) and miss, as for a Border's value, so bl_tail (editor.s)
 * takes them and jumps here with the picture's place in bl_q (a crop's strip, after cr_gx). Lines go in bl_r's first
 * slots; a Border's frame follows in the slots left (with a Border, Ticks keeps only its centre cross).
 * research/NOTES.md "Framing lines (#104)". */
 .set ST_FG0, 0x7f75              /* our strings: "Cross", "Ticks" (st_get chain: si_str -> fg_str -> cr_str) */

.section .ext1,"ax"
fg_v155:                          /* validator list of 155 (stock 0, 5, 6, 1, 7, 8, 9 at 0x60616713) + 10, 11 */
 .byte 0, 5, 6, 1, 7, 8, 9, 10, 11
fg_v2047:                         /* validator list of 2047 (stock 0, 5, 6, 1, 7, 8 at 0x60618b62) + 10, 11 */
 .byte 0, 5, 6, 1, 7, 8, 10, 11

.section .ext15,"ax"
 .balign 4
fg_ml:                            /* the Displayed Grid menu list (stock 0x6158bf08, 7 x 12 B) + 2 entries (gridlines.py) */
 .space 9 * 12

.section .ext14,"ax"
/* fg_ln <- jmp from bl_tail's bl_cgb (no calls: bl_tail returns through the stack); a2 = bl_r (cleared, nothing copied
 * for 10 / 11), a3 = bl_q (x0, x1, y0, y1 u16; bl_q + 8.. free until the frame is built). -> jmp bl_cg2. */
fg_ln:
 mov (bl_v),d0
 and 15,d0
 cmp 10,d0
 bcs 9f
 cmp 12,d0
 bcc 9f
 movhu (0,a3),d1                  /* cx = x0 + (x1 - x0 + 1) / 2: halfway between the camera's thirds (3:2 0..899 */
 movhu (2,a3),d3                  /* -> 450, between 300 and 600; framing-lines-2, owner: "slightly off center to */
 sub d1,d3                        /* the left" with (x1 - x0) / 2 = 449) */
 inc d3
 lsr 1,d3
 add d3,d1
 movhu (4,a3),d2                  /* cy = y0 + (y1 - y0 + 1) / 2 (0..599 -> 300, between 199 and 400) */
 movhu (6,a3),d3
 sub d2,d3
 inc d3
 lsr 1,d3
 add d3,d2
 mov a2,a0
 cmp 10,d0
 bne 2f
 movhu (4,a3),d0                  /* Cross: {cx, y0, cx, y1}, {x0, cy, x1, cy} */
 movhu (6,a3),d3
 movhu d1,(0,a0)
 movhu d0,(2,a0)
 movhu d1,(4,a0)
 movhu d3,(6,a0)
 movhu (0,a3),d0
 movhu (2,a3),d3
 movhu d0,(8,a0)
 movhu d2,(10,a0)
 movhu d3,(12,a0)
 movhu d2,(14,a0)
9:
 jmp bl_cg2
2:                                /* Ticks: C = s / 16 + s / 32 (s the shorter half side), T = 2 C */
 movhu (0,a3),d0
 mov d1,d3
 sub d0,d3
 mov d3,(8,a3)                    /* half width */
 movhu (4,a3),d0
 mov d2,d3
 sub d0,d3                        /* half height */
 mov (8,a3),d0
 cmp d0,d3
 bls 3f
 mov d0,d3
3:
 mov d3,d0
 lsr 4,d3
 lsr 5,d0
 add d0,d3                        /* C */
 movhu d1,(0,a0)                  /* the centre cross: {cx, cy - C, cx, cy + C}, {cx - C, cy, cx + C, cy} */
 movhu d1,(4,a0)
 mov d2,d0
 sub d3,d0
 movhu d0,(2,a0)
 mov d2,d0
 add d3,d0
 movhu d0,(6,a0)
 mov d1,d0
 sub d3,d0
 movhu d0,(8,a0)
 mov d1,d0
 add d3,d0
 movhu d0,(12,a0)
 movhu d2,(10,a0)
 movhu d2,(14,a0)
 mov (bl_v),d0                    /* a Border (L > 0): its frame takes the other slots */
 and 0xf0,d0
 bne 9b
 add d3,d3                        /* T */
 movhu d1,(16,a0)                 /* top {cx, y0, cx, y0 + T} */
 movhu d1,(20,a0)
 movhu (4,a3),d0
 movhu d0,(18,a0)
 add d3,d0
 movhu d0,(22,a0)
 movhu d1,(24,a0)                 /* bottom {cx, y1 - T, cx, y1} */
 movhu d1,(28,a0)
 movhu (6,a3),d0
 movhu d0,(30,a0)
 sub d3,d0
 movhu d0,(26,a0)
 movhu d2,(34,a0)                 /* left {x0, cy, x0 + T, cy} */
 movhu d2,(38,a0)
 movhu (0,a3),d0
 movhu d0,(32,a0)
 add d3,d0
 movhu d0,(36,a0)
 movhu d2,(42,a0)                 /* right {x1 - T, cy, x1, cy} */
 movhu d2,(46,a0)
 movhu (2,a3),d0
 movhu d0,(44,a0)
 sub d3,d0
 movhu d0,(40,a0)
 jmp bl_cg2

.section .ext13,"ax"                /* beside si_str (the string chain stays in section 6) */
/* fg_str <- jmp from si_str (st_get's frame, ret [d2],8; d0 the id): our two names, else on to crop.s cr_str. */
fg_str:
 cmp ST_FG0,d0
 bne 1f
 mov fg_s0,a0
 ret [d2],8
1:
 cmp ST_FG0 + 1,d0
 bne 2f
 mov fg_s1,a0
 ret [d2],8
2:
 jmp cr_str
 .balign 2
fg_s0:
 .short 67, 114, 111, 115, 115, 0  /* "Cross" */
fg_s1:
 .short 84, 105, 99, 107, 115, 0   /* "Ticks" */
