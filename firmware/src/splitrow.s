/* ================================================================== the Split toning row (feature/split-tone-row)
 * Owner (2026-11-22): "moves the two split toning wheels to a new row. I want them seperate from HSL". Their answers
 * the same day: the row right under the colour wheel (Tone Balance stays its own row, below it); INFO steps Shadows
 * <-> Highlights; on the colour wheel INFO is "Color All" again (all colours on / off on Saturation); the row's
 * picture a circle half blue, half orange.
 *
 * The row (ST_IT) is the colour wheel's row (item 5397) a second time: the same case in each of the column's row
 * switches (build.py), an item table entry with its own cell picture (sp_cell -> IC_SP, mkicons PICTURES[23]), and
 * cv_inf / cv_rsi send INFO and the held-OK reset to its panel as for 5397. So it opens the camera's wheel, and which
 * pages that wheel has follows the row Picture Mode is on (hb_item, noted at each screen update):
 *   the colour wheel row: Saturation / Hue / Luminance (P+AXIS 0 / 2 / 1), stepped by Delete (hbar.s);
 *   this row: Shadows / Highlights (5 / 6), stepped by INFO.
 * sp_case / sp_whl (the two rows' update cases) and hb_pu (every row) put the page on the row's side: sp_sync.
 * Storage is untouched: slot +55..+58, LOOKS / EDITS record +53..+56, as since v0.26 / v0.28.
 * The row's '*' and Reset guide: its tints against the film's as built (no film: any strength), sp_star / sp_isdef /
 * sp_def; the colour wheel row's '*' no longer counts the tints (ed_isdef). The held-OK reset is the wheel's own,
 * unchanged (the film as built, or the whole COLOR). */
.section .ext15,"ax"
 .balign 4
sp_cell:                          /* the row's cell picture list, as 5397's 0x6154be9c */
 .short 3, IC_SP
 .long 0x6154b480
sp_a0:                            /* hb_pu's a0 over sp_sync */
 .long 0
sp_ed:                            /* the wheel editor ed_init last saw (ei_page), until the next screen update: its */
 .long 0                          /* children hold the values of the page it opened on */
sp_sv:                            /* sp_all: tn_set's d1, a0, a1 */
 .long 0, 0, 0
sp_upd:                           /* 1 while the camera asks "changed?" for this row (sp_case, sp_star): sp_isdef */
 .byte 0
 .balign 2

/* sp_case / sp_whl <- the column update's row switch 0x615510cc for this row / the wheel row (build.py). The camera
 * makes the wheel's editor anew at each arrival on either row (ed_init, on Saturation), then runs this case, which
 * reads the readout and the row's "changed?" (om-emu trace, 2026-11-22). So first the current item is noted and the
 * page put on the row's side (sp_sync), then the wheel's own case 0x611d04d3: for this row with sp_upd set, so its
 * Reset guide follows the tints (sp_isdef). */
sp_case:
 mov ST_IT,d0
 movhu d0,(hb_item)
 add -4,sp                        /* our call's slot (the screen update's own (0,sp) stays, as pu_hook) */
 call sp_sync,[d2,d3,a2,a3],20
 add 4,sp
 mov 1,d0
 movbu d0,(sp_upd)
 mov a3,a0                        /* as the stock case */
 mov a0,a1
 call WH_UPD,[d2,d3,a2,a3],56
 clr d0
 movbu d0,(sp_upd)
 jmp WH_END
sp_whl:
 mov 5397,d0
 movhu d0,(hb_item)
 add -4,sp
 call sp_sync,[d2,d3,a2,a3],20
 add 4,sp
 jmp WH_CASE

/* sp_sync: `call sp_sync,[d2,d3,a2,a3],20` from sp_case / sp_whl / hb_pu, d0 = Picture Mode's current item: with the
 * films in and the wheel used, on this row a page that is not Shadows / Highlights -> Shadows; on any other row
 * Shadows / Highlights -> Saturation. Then that page's guide picture, and the editor just made
 * (sp_ed) re-reads its 12 values, as after a page change by INFO (k_set). sp_ed is good for one update only.
 * Uses d0, d1, a0, a1. */
sp_sync:
 mov d0,d2
 PVAL 9f
 mov (EMARK,a2),d0
 cmp EMAGIC,d0
 bne 9f
 movbu (AXIS,a2),d0
 cmp ST_IT,d2
 bne 2f
 cmp 5,d0
 beq 9f
 cmp 6,d0
 beq 9f
 mov 5,d0
 bra 3f
2:
 cmp 5,d0
 beq 21f
 cmp 6,d0
 bne 9f
21:
 clr d0                           /* (the wheel row's editor opens on Saturation anyway, ei_page) */
3:
 movbu d0,(AXIS,a2)
 call gd_set,[d2,a2],8
 mov (sp_ed),a3
 cmp 0,a3
 beq 9f
 movhu (96,a3),d0                 /* a COLOR editor (key 0x1540..0x1543), as ed_info checks */
 add -0x1540,d0
 cmp 4,d0
 bcc 9f
 mov 128,d2                       /* children 1..12 re-read from the facade (stock 0x611b20ea, as k_set) */
4:
 mov a3,a0
 add d2,a0
 mov (a0),a0
 cmp 0,a0
 beq 9f
 call refresh,[d2,d3,a2,a3],68
 add 4,d2
 cmp 176,d2
 bne 4b
9:
 clr d0
 mov d0,(sp_ed)
 ret [d2,d3,a2,a3],20

/* sp_inf <- jmp from ed_info's k_6b (its frame: (16) the cursor's value, 255 = all colours; (20) P; a3 the editor).
 * A Delete turned into INFO (hb_del): as h2, all colours off first, then the next HSL page. A real INFO: all colours
 * on -> the stock handler turns them off; Saturation with one colour -> the stock handler turns all on; Shadows /
 * Highlights -> the other one (k_step, hb_next); Hue / Luminance -> nothing. */
sp_inf:
 mov (20,sp),a2
 movbu (AXIS,a2),d1
 mov (16,sp),d0
 movbu (hb_del),d2
 cmp 0,d2
 beq 1f
 cmp 255,d0
 bne 2f
 jmp k_all
2:
 jmp k_step
1:
 cmp 255,d0
 beq 8f
 cmp 0,d1
 beq 8f
 cmp 5,d1
 bcs 7f
 jmp k_step
7:
 mov 1,d0
 ret [d2,d3,a2,a3],40
8:
 jmp f_no

/* sp_all: `add -4,sp; call sp_all,[d2,d3,a2,a3],20; add 4,sp` from tn_set, d2 = 12k + colour -> d0 = 1 when COLOR
 * k's wheel is on all colours (setting 2201 + k or the cursor 2197 + k reads 255, as k_ad), else 0. Keeps d1, a0, a1. */
sp_all:
 mov d1,(sp_sv)
 mov a0,(sp_sv + 4)
 mov a1,(sp_sv + 8)
 clr d3
1:
 cmp 12,d2
 bcs 2f
 add -12,d2
 inc d3
 bra 1b
2:
 mov d3,d0
 add 2201,d0
 call sget,[],4                   /* (keeps d2, d3, a2, a3) */
 and 255,d0
 cmp 255,d0
 beq 7f
 mov d3,d0
 add 2197,d0
 call sget,[],4
 and 255,d0
 cmp 255,d0
 beq 7f
 clr d0
 bra 8f
7:
 mov 1,d0
8:
 mov (sp_sv),d1
 mov (sp_sv + 4),a0
 mov (sp_sv + 8),a1
 ret [d2,d3,a2,a3],20

/* sp_star <- row switch sw13 for this row (the row's "changed?": its '*'; the frame of the wheel's case 0x611d1aa9):
 * the wheel's own routine with sp_upd set -> d2, then STAR_END.
 * sp_isdef <- the routine's "is at default" call 0x611d18a7 (12 sector ids of the COLOR; call [d2,d3,a2],24, d0 id ->
 * d0 1 default, 0 changed): while sp_upd, the first sector answers for the row's tints (sp_def), the rest 1. Else
 * fl_isdef, as every other site. */
sp_star:
 mov 1,d0
 movbu d0,(sp_upd)
 mov a3,a0
 call WH_STAR,[d2,d3,a2,a3],28
 mov d0,d2
 clr d0
 movbu d0,(sp_upd)
 jmp STAR_END
sp_isdef:
 movbu (sp_upd),d1
 cmp 0,d1
 bne 1f
 jmp fl_isdef
1:
 exthu d0
 add -928,d0
 clr d2
2:
 cmp 12,d0
 bcs 3f
 add -12,d0
 inc d2
 bra 2b
3:
 cmp 0,d0
 bne 8f
 cmp 4,d2
 bcc 8f
 mov d2,d0
 call sp_def,[d3,a2,a3],16
 mov d2,d0
 ret [d2,d3,a2],24
8:
 mov 1,d0
 ret [d2,d3,a2],24

/* sp_def: `call sp_def,[d3,a2,a3],16`, d0 = k -> d2 = 1 when COLOR k's Shadows and Highlights tints are its film's as
 * built (record +53..+56; a colour with strength 0 is no tint), without a film: both strengths 0. No settings block:
 * 1. Uses d0, d1, a0, a1. */
sp_def:
 mov d0,d2
 PVAL 8f
 mov d2,d0
 asl 6,d0
 mov a2,a3
 add d0,a3
 add 32,a3                        /* COLOR k's slot */
 call fl_film,[],0
 cmp 0,d0
 blt 5f
 mov d0,d3
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 5f
 mov (LPTR,a2),a0
 asl 6,d3
 add d3,a0
 add 32 + 53,a0                   /* film j's record +53 */
 movbu (56,a3),d0
 movbu (1,a0),d1
 cmp d1,d0
 bne 7f
 cmp 0,d0
 beq 1f
 movbu (55,a3),d0
 movbu (a0),d1
 cmp d1,d0
 bne 7f
1:
 movbu (58,a3),d0
 movbu (3,a0),d1
 cmp d1,d0
 bne 7f
 cmp 0,d0
 beq 8f
 movbu (57,a3),d0
 movbu (2,a0),d1
 cmp d1,d0
 bne 7f
 bra 8f
5:
 movbu (56,a3),d0
 cmp 0,d0
 bne 7f
 movbu (58,a3),d0
 cmp 0,d0
 bne 7f
8:
 mov 1,d2
 ret [d3,a2,a3],16
7:
 clr d2
 ret [d3,a2,a3],16

 .balign 8
sp_pay:                           /* the cell picture's stream (build.py) */
 .space 952                       /* picture-mode p1: the picture's size (948), was 2048 */
sp_pend:
