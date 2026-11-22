/* ------------------------------------------------------------------ five-point curve (owner, 2026-11-22: "brings the
 * black/white grid into the shadow curves as a 1st and 5th point"; mock-up variant A, "pairs with INFO")
 * On a film (COLOR 1-4) the Highlight & Shadow row's INFO steps Sh / Hi -> Mid -> Blk / Wht -> Sh / Hi. The Blk / Wht
 * page is the camera's H&S page in a mode of ours, as the RGB and Mix pages (rgbcurves.inc), cv_on = 3:
 *   Sh (the left header slot, event 0x9032) = the film's Blacks (P slot +47), Hi (the right one, 0x9031) = its Whites
 *   (+48), -7..+7; Mid = CV_MIDV, hidden. The header labels read "Blk" / "Wht" (cv_ic), the guide "Sh/Hi [INFO]".
 *   The picture (cv_draw's curve code on a made-up record, b5_dr): one white curve through five points, Blacks, Sh,
 *   Mid, Hi, Whites at 0 / 25 / 50 / 75 / 100 %, the two ends drawn big.
 * b5_pg (0 / 3) is the page while the row stays open: cv_hs (the row's update case) copies it to cv_on; another row
 * (cv_pu) or any GUI state change (cv_gx) clears it. On the camera's Mid page b5_mid makes the guide read
 * "B/W [INFO]". The Blacks / Whites grid row is out of the list (pm_list); the H&S row's '*' counts them (b5_star).
 * Camera settings: none written here (the film's two slot bytes, saved as every edit: P+DIRTY). */
.section .ext15,"ax"
 .set HS_SELH, 128                /* the H&S panel's value selectors (om-emu, 2026-11-22: 15 entries each, the entry */
 .set HS_SELS, 132                /* 7 - value): Hi, Sh (Mid's is at 136); a dial moves the entry, whose value it writes */
 .macro B5P miss, r=d1            /* a0 = P when valid (as PVAL, with \r / a0) */
 movhu (STATE),\r
 add -1,\r
 cmp HMAX,\r
 bcc \miss
 btst 3,\r
 bne \miss
 mov \r,a0
 add POOL,a0
 mov (a0),\r
 cmp MAGIC,\r
 bne \miss
 .endm

/* b5_hs <- cv_hs (the column's update case for the H&S row; d0 free): cv_on = the row's page (0 the camera's, 3 ours) */
b5_hs:
 movbu (b5_pg),d0
 mov d0,(cv_on)
 cmp 0,d0
 beq 1f
 mov (cv_gen),d0
 inc d0
 mov d0,(cv_gen)
1:
 jmp HS_CASE

/* cv_pu <- .hook_pu (the screen update's end, (4,sp) -> the current item): the RGB / Mix rows keep cv_on, the H&S row
 * has its page's, any other row -> off; off the H&S row the Blk / Wht page ends. Then pu_hook. Uses d0, a0. */
cv_pu:
 mov (4,sp),a0
 movhu (a0),d0
 cmp 5398,d0
 beq 2f
 mov d0,a0
 clr d0
 movbu d0,(b5_pg)
 movbu d0,(b5_mid)
 mov a0,d0
 cmp RG_IT,d0
 beq 1f
 cmp MX_IT,d0
 beq 1f
 mov 0,a0
 mov a0,(cv_on)
 bra 1f
2:
 movbu (b5_pg),d0
 mov d0,(cv_on)
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
 clr d1
 movbu d1,(b5_pg)
 movbu d1,(b5_mid)
1:
 jmp gx_map

/* cv_inf <- .hook_inf (0x611c29c2 in the column's row event function, d2 = the current item): INFO goes to the row's
 * panel for 5397 / 5398 (stock) and RG_IT / MX_IT (their panel kept in its outer look, mix test 6).
 * 5398 on a film (b5_fk, from b5_ev0 at this INFO): the panel's selector entry (0 outer = Sh / Hi, 1 middle = Mid)
 * and b5_pg give the step: Sh / Hi -> Mid as stock (b5_mid: its guide is ours); Mid -> Blk / Wht (the panel goes to
 * its outer look by itself; its 2191 write is refused by cv_sv); Blk / Wht -> Sh / Hi (the selector put on entry 1
 * first, so INFO's "up" lands on the outer look). Uses d0, a0. */
cv_inf:
 exthu d2
 cmp 5397,d2
 beq 1f
 cmp 5398,d2
 beq 5f
 cmp RG_IT,d2
 beq 2f
 cmp MX_IT,d2
 beq 2f
 jmp INF_NO
2:
 mov (8,sp),a0
 mov (4,a0),a0
 cmp 0,a0
 beq 1f
 mov (HS_PSEL,a0),a0
 cmp 0,a0
 beq 1f
 movhu (SEL_N,a0),d0
 cmp 2,d0
 bne 1f
 mov 1,d0
 movhu d0,(SEL_I,a0)
1:
 jmp INF_GO
5:
 mov (8,sp),a0
 mov (4,a0),a0
 cmp 0,a0
 beq 1b
 mov (HS_PSEL,a0),a0
 cmp 0,a0
 beq 1b
 movhu (SEL_N,a0),d0
 cmp 2,d0
 bne 1b
 movbu (b5_pg),d0
 cmp 0,d0
 beq 6f
 clr d0                           /* Blk / Wht -> Sh / Hi */
 movbu d0,(b5_pg)
 mov d0,(cv_on)
 mov 1,d0
 movhu d0,(SEL_I,a0)
 movbu (b5_sh),d0                 /* the value selectors back on the film's Sh / Hi (they followed the dials) */
 extb d0
 not d0
 add 8,d0
 movbu d0,(b5_t)
 movbu (b5_hi),d0
 extb d0
 not d0
 add 8,d0
 movbu d0,(b5_t + 1)
 jmp b5_sel
6:
 mov (b5_fk),d0                   /* not a film: stock */
 cmp 0,d0
 blt 1b
 movhu (SEL_I,a0),d0
 cmp 0,d0
 bne 7f
 mov 1,d0                         /* Sh / Hi -> Mid */
 movbu d0,(b5_mid)
 bra 1b
7:
 clr d0                           /* Mid -> Blk / Wht */
 movbu d0,(b5_mid)
 mov 3,d0
 movbu d0,(b5_pg)
 mov d0,(cv_on)
 mov (b5_fk),d0
 mov d0,(cv_k)
 mov (cv_gen),d0
 inc d0
 mov d0,(cv_gen)
 mov 7,d0                         /* the value selectors on Blacks / Whites (7 - value; 0 without the table) */
 movbu d0,(b5_t)
 movbu d0,(b5_t + 1)
 B5P b5_sel, d0
 mov (b5_fk),d0
 asl 6,d0
 add d0,a0
 movbu (79,a0),d0
 extb d0
 cmp -7,d0
 blt 71f
 cmp 7,d0
 bgt 71f
 not d0
 add 8,d0
 movbu d0,(b5_t)
71:
 movbu (80,a0),d0
 extb d0
 cmp -7,d0
 blt b5_sel
 cmp 7,d0
 bgt b5_sel
 not d0
 add 8,d0
 movbu d0,(b5_t + 1)
b5_sel:                           /* the panel's Sh selector on entry b5_t, its Hi selector on b5_t + 1; INFO goes on */
 mov (8,sp),a0
 mov (4,a0),a0
 mov (HS_SELS,a0),a0
 cmp 0,a0
 beq 73f
 movhu (SEL_N,a0),d0
 cmp 15,d0
 bne 73f
 movbu (b5_t),d0
 cmp 15,d0
 bcc 73f
 movhu d0,(SEL_I,a0)
73:
 mov (8,sp),a0
 mov (4,a0),a0
 mov (HS_SELH,a0),a0
 cmp 0,a0
 beq 74f
 movhu (SEL_N,a0),d0
 cmp 15,d0
 bne 74f
 movbu (b5_t + 1),d0
 cmp 15,d0
 bcc 74f
 movhu d0,(SEL_I,a0)
74:
 jmp INF_GO

/* b5_ev0 (jumped to from cv_ev with no page of ours on, its frame; d0 = the event): at INFO, is the picture mode a
 * film (b5_fk = k, else -1), and its Sh / Mid / Hi for the Blk / Wht page's picture (they can't change while it shows:
 * cv_sv refuses their writes). Then the event goes on (cv_ev90). */
b5_ev0:
 cmp 0x9014,d0
 bne 9f
 mov 111,d0
 call sget,[],4
 call fl_k,[],0
 mov d0,(b5_fk)
 cmp 0,d0
 blt 9f
 mov d0,d3
 add d0,d0
 add d0,d3                        /* 3k */
 mov d3,d0
 add 976,d0
 call sget,[],4
 movbu d0,(b5_hi)
 mov d3,d0
 add 977,d0
 call sget,[],4
 movbu d0,(b5_md)
 mov d3,d0
 add 978,d0
 call sget,[],4
 movbu d0,(b5_sh)
9:
 jmp cv_ev90

/* b5_ev (jumped to from cv_ev on the Mix or the Blk / Wht page, its frame; d0 the event, d2 = cv_on, d3 the dials'
 * clicks): Mix -> mx_ev. Blk / Wht: 0x9031 Whites (+ clicks), 0x9032 Blacks (- clicks), as the camera's own page
 * pairs Hi / Sh; -7..+7; then cv_dty -> cv_ev80. INFO goes on as it came (cv_inf steps the page); else cv_ev5. */
b5_ev:
 cmp 2,d2
 bne 1f
 jmp mx_ev
1:
 cmp 0x9031,d0
 beq 2f
 cmp 0x9032,d0
 beq 3f
 cmp 0x9014,d0
 bne 11f
 jmp cv_ev90
11:
 jmp cv_ev5
2:
 mov 80,d2
 bra 4f
3:
 mov 79,d2
 not d3
 inc d3
4:
 B5P 9f
 mov (cv_k),d1
 and 3,d1
 asl 6,d1
 add d1,a0
 add d2,a0
 movbu (a0),d2
 extb d2
 cmp -7,d2                        /* a value out of range counts as 0 (as tone reads it) */
 blt 41f
 cmp 7,d2
 ble 42f
41:
 clr d2
42:
 add d3,d2
 cmp -7,d2
 bge 5f
 mov -7,d2
5:
 cmp 7,d2
 ble 6f
 mov 7,d2
6:
 movbu d2,(a0)
 call cv_dty,[d2,d3,a2,a3],20
 jmp cv_ev80
9:
 jmp cv_ev90

/* b5_val (jumped to from cv_val, its frame `ret [d2,d3],12`): d0 = cv_on, d1 = the slot (0 Hi, 1 Mid, 2 Sh), d2 = k.
 * Mix -> mx_val. Blk / Wht: Hi = Whites, Sh = Blacks, Mid = CV_MIDV. */
b5_val:
 cmp 2,d0
 bne 1f
 jmp mx_val
1:
 cmp 1,d1
 bne 2f
 mov CV_MIDV,d0
 ret [d2,d3],12
2:
 mov d1,d3
 clr d0
 B5P 9f
 and 3,d2
 asl 6,d2
 add d2,a0
 movbu (79,a0),d0
 cmp 0,d3
 bne 3f
 movbu (80,a0),d0
3:
 extb d0
 cmp -7,d0
 blt 8f
 cmp 7,d0
 ble 9f
8:
 clr d0
9:
 ret [d2,d3],12

/* b5_chg: `call b5_chg,[],0` (cv_dflt: the page's Reset guide) -> d0 != 0 when COLOR cv_k has Blacks or Whites set.
 * Uses d0, d1, a0. */
b5_chg:
 clr d0
 B5P 9f
 mov (cv_k),d1
 and 3,d1
 asl 6,d1
 add d1,a0
 movbu (79,a0),d0
 movbu (80,a0),d1
 or d1,d0
9:
 ret [],0

/* b5_zk (jumped to from cv_zx on the Blk / Wht page, its frame `ret [d2],8`; d0 = k): Blacks and Whites 0 */
b5_zk:
 mov d0,d2
 B5P 9f
 and 3,d2
 asl 6,d2
 add d2,a0
 clr d1
 movbu d1,(79,a0)
 movbu d1,(80,a0)
9:
 ret [d2],8

/* b5_star: the column's "row changed?" switch (sw13) for the H&S row, in that function's frame ((12,sp) = setting
 * 903, the COLOR 1..4): Blacks or Whites set -> changed (d2 0 -> STAR_END), else the camera's own check (HS_STAR). */
b5_star:
 mov (12,sp),d0
 add -1,d0
 cmp 4,d0
 bcc 9f
 B5P 9f
 mov (12,sp),d0
 add -1,d0
 asl 6,d0
 add d0,a0
 movbu (79,a0),d0
 movbu (80,a0),d1
 or d1,d0
 cmp 0,d0
 beq 9f
 clr d2
 jmp STAR_END
9:
 jmp HS_STAR

/* b5_dr (jumped to from cv_draw on the Blk / Wht page, its frame): the made-up record at b5_rec, channel 0 = the
 * five points as RGB-curve offsets (x 2: a step of 96 / 4095, +-7 = +-16 %, about the camera's own curve's bend):
 * [0] Blacks, [2] Sh, [3] Mid, [4] Hi, [5] Whites, [1] (the 10 % input) between Blacks and Sh; channels 1, 2 flat.
 * Then cv_draw's locals: (4) k, (44) the record, (8) colour 0, (12) no selected point -> cvd_go. */
b5_dr:
 mov (cv_k),d0
 and 3,d0
 mov d0,(4,sp)
 mov b5_rec,a1
 clr d1
 mov d1,(a1)
 mov d1,(4,a1)
 mov d1,(8,a1)
 mov d1,(12,a1)
 mov d1,(16,a1)
 B5P 3f
 asl 6,d0
 add d0,a0
 movbu (79,a0),d0
 extb d0
 cmp -7,d0
 blt 1f
 cmp 7,d0
 bgt 1f
 add d0,d0
 movbu d0,(a1)
1:
 movbu (80,a0),d0
 extb d0
 cmp -7,d0
 blt 3f
 cmp 7,d0
 bgt 3f
 add d0,d0
 movbu d0,(5,a1)
3:
 movbu (b5_sh),d0
 extb d0
 add d0,d0
 movbu d0,(2,a1)
 movbu (b5_md),d0
 extb d0
 add d0,d0
 movbu d0,(3,a1)
 movbu (b5_hi),d0
 extb d0
 add d0,d0
 movbu d0,(4,a1)
 movbu (a1),d0                    /* [1] = (3 Blacks + 2 Sh) / 5 */
 extb d0
 mov d0,d1
 add d0,d0
 add d1,d0
 movbu (2,a1),d1
 extb d1
 add d1,d0
 add d1,d0
 mov 205,d1
 mul d1,d0
 asr 10,d0
 movbu d0,(1,a1)
 mov a1,(44,sp)
 clr d0
 mov d0,(8,sp)
 mov 5,d0
 mov d0,(12,sp)
 jmp cvd_go

 .balign 4
b5_fk:                            /* the film k at the last INFO off our pages, -1 not a film */
 .long -1
b5_rec:
 .space 20
b5_pg:
 .byte 0
b5_t:
 .byte 7, 7
b5_mid:
 .byte 0
b5_sh:
 .byte 0
b5_md:
 .byte 0
b5_hi:
 .byte 0
 .balign 4
 .include "curve5pics.inc"        /* "Blk", "Wht", the two guides (rgbpics.py entries 16..19; build.py) */
.section .ext12,"ax"
