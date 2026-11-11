/* v0.24 film test 7 (owner): the wheel's Film and Extras pages are hidden (their code stays; 1 brings them back) */
 .set W_FILM, 0
 .set W_EXTRAS, 0
 .set ST_STILL, 0                 /* sp4: split toning on every COLOR pass (live view too, if it runs this stage); sp2/sp3 stills only
                                   * (the silent-mode restart that made us add it was the WB grid holder, sp3) */
 .set W_TONE, 1                   /* v0.26 split toning: Luminance -> Shadows (axis 5) -> Highlights (axis 6) -> Color */
/* film test 12 (owner, camera: test 11 went "sat, hue, sat, lum, all weird"): "work with the firmware, not against
 * it" -> the wheel's own order again, Color -> Color All -> Hue -> Luminance (the guide keeps the name Luminance).
 * W_SALL / W_SONE / W_HSL 0; their code stays. */
 .set W_SALL, 0                   /* film test 8 (owner): Saturation always shows all colours (no single-colour page) */
 .set W_SONE, 0                   /* film test 11 (owner): the Saturation page shows ONE colour at a time (film test 8
                                   * misread "hide the color select wheel": the page the owner meant was the all-colours
                                   * one, whose guide reads "Color Select [INFO]"); all colours never come on (0: film
                                   * test 8, all colours always). Needs W_SALL 1 */
 .set W_HSL, 0                    /* film test 10 (owner): pages in HSL order, Hue -> Saturation -> Luminance, opening on
                                   * Hue; their dial labels Hue / Saturation / Luminance (0: S -> H -> L, open on S) */
/* OM-3 1.1 editor test 1 (= probe 2 + on-camera Hue/Light pages + card save).
 * Probe 2 part: looks in a heap block, loaded from C:\OM3MOD\BUNDLES.BIN when valid.
 * Adapted from Caduceus SD loader v3 (cakelesscoder/caduceus-ep7, Apache-2.0): same state encoding,
 * gate, file sequence, header/CRC/range check and pool-handle publication; OM-3 addresses.
 *
 * STATE (u16) = 0x62b4dd16, event-manager padding (camera-proven by probe 1):
 *   0 = not attempted, 0xFFFF = attempted / no table, 1..HMAX = handle h, block at POOL + h - 1.
 * Block (1024 B, class-1 pool, uncached): +0 header (magic 'OM3B'...), +32 8 slots x 64 B
 *   (Caduceus bundle ABI: hue[12] s8 +0, light[12] s8 +12, flags +31 bit1 = H/L enabled; UI sector order).
 * First gated shutter event per power-on: STATE = 0xFFFF; malloc(1024); copy built-in defaults;
 *   fopen/fseek(END)/ftell == 544/fseek(SET)/fread/fclose; header + CRC-32 + per-byte ranges;
 *   any failure -> built-in defaults again; publish h when the block is inside the pool and 4-aligned.
 * The COLOR hook reads the published block only; STATE 0 / 0xFFFF -> stock output.
 * No store into the loaded image; stores: STATE (2x), the heap block, stack frames.
 */
.section .hook_color,"ax"
 jmp hl_pp
.section .hook_shutter,"ax"
 jmp pr_hook
.section .hook_set,"ax"
 call sl_set,[d2,d3,a2,a3],68     /* stock: call 0x60bb528f,[d2,d3,a2,a3],68 (settings manager); sl_set -> ed_set */
.section .hook_tone,"ax"
 call tone,[d2,d3,a2,a3],56       /* stock 0x605197d7: mov d3,a0; call 0x60518fa4,[d2,d3,a2,a3],56 */
.section .hook_rng,"ax"
 jmp sl_rng                       /* v0.23 stock 0x611d1041: call facade; mov 7,d0; bra (the Sharpness slider's -2..+2) */
 .byte 0xcb,0xcb,0xcb,0xcb,0xcb,0xcb
.section .hook_dot,"ax"
 jmp sl_dot                       /* v0.23 stock 0x611d10fb: mov (8,sp),a0; mov a2,d1; mul 155,d1 */
 .byte 0xcb,0xcb,0xcb
.section .hook_bar,"ax"
 jmp rw_bar                       /* v0.23 stock 0x611d1035 (bar setup): cmp 59,d0; beq; cmp 5399,d0; beq; bra 0x611d1092 */
 .byte 0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb
.section .hook_rda,"ax"
 jmp rd_a                         /* v0.23 stock 0x611d16b4 (readout sign): cmp 1011; beq; cmp 5397; beq; bra */
 .byte 0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb
.section .hook_rdb,"ax"
 jmp rd_b                         /* v0.23 stock 0x611d1725 (readout digit): the same */
 .byte 0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb,0xcb
.section .hook_pg,"ax"
 jmp pg_fix                       /* v0.23 stock 0x611d07a4 (left column window: 2 pages of 5 rows max) */
 .fill 19, 1, 0xcb
.section .hook_pg2,"ax"
 jmp pg_mod                       /* v0.23 stock 0x611c3709 (cursor -> slot: cursor > 4 ? cursor - 5) */
 .byte 0xcb,0xcb
.section .hook_arw,"ax"
 jmp pg_arw                       /* v0.23 stock 0x611d0be0 (scroll arrows: up on page 2, down on page 1) */
 .byte 0xcb,0xcb,0xcb
.section .hook_rev,"ax"
 jmp rv_chk                       /* v0.23 stock 0x611b21e8 (a bar's value list top-down if its id is in 0x6152d6fe) */
 .byte 0xcb,0xcb,0xcb,0xcb,0xcb
.section .hook_pme,"ax"
 jmp pm_ev                        /* v0.25 stock 0x6125becc (Picture Mode's event handler): movm [d2,a2,a3],(sp);
                                   * add -60,sp */
.section .hook_gx,"ax"
 jmp gx_map                       /* v0.25 grid (as test 13): stock 0x610f6016 (after a screen handler: d0 = next
                                   * state): mov d0,d3; exthu d3; mov d3,d2; asr 8,d2 */
 .byte 0xcb
.section .hook_sc,"ax"
 jmp sc_cap                       /* stock 0x610cdf05 (a holder gets its scene): mov d0,a3; mov a0,d3; mov 1,d0 */
 .byte 0xcb
.section .hook_pu,"ax"
 jmp pu_hook                      /* stock 0x611d04ec (Picture Mode update): mov (0x6037a360),d0 */
 .byte 0xcb
.section .hook_ic,"ax"
 jmp ar_ic                        /* v0.27: ar_ic (▲ / ◀ pictures), then ic_get. v0.23 stock 0x610f5611 (picture id -> its slot in the picture table): mov d0,d1;
                                   * exthu d1; cmp 0,d1; bne 0x610f561b */
 .byte 0xcb
.section .hook_stp,"ax"
 jmp st_chk                       /* v0.23 stock 0x611b201b (a bar stops at its ends if its id is in 0x6152d520):
                                   * clr d0; mov 116,a0; add a3,a0; mov d0,(a0) */
 .byte 0xcb
.section .hook_str,"ax"
 jmp st_get                       /* v0.23 stock 0x610f56a6 (string getter, d0 id): mov d0,d2; call 0x610f56bd,[],0 */
 .byte 0xcb
.section .hook_lc,"ax"
 jmp gr_lc                        /* v0.23 stock 0x611d1982 (left-column id lookup): cmp 5400,d0; beq 0x611d19ac;
                                   * bra 0x611d19b4 */
 .byte 0xcb,0xcb,0xcb
.section .hook_rsp,"ax"
 jmp rs_pos                       /* film test 9 stock 0x611c3cb5 (the held-OK reset's end): mov (20,sp),a0;
                                   * movhu (32,sp),d0; movhu d0,(88,a0) (the row's cursor position on screen) */
 .byte 0xcb,0xcb,0xcb
.section .hook_pmod,"ax"
 jmp fl_pmod                      /* stock 0x6129ba07: clr d3; mov 0x6037ec10,a2 (its first 5 bytes); v0.24 film test 6:
                                   * fl_pmod first (a COLOR holding a film), then ed_pmod */

/* ------------------------------------------------------------------ section-1 tail */
.section .ext1,"ax"
/* P validation: out a2 = P; uses d3, a2 only. */
 .macro PVAL miss
 movhu (STATE),d3
 add -1,d3
 cmp HMAX,d3
 bcc \miss
 btst 3,d3
 bne \miss
 mov d3,a2
 add POOL,a2
 mov (a2),d3
 cmp MAGIC,d3
 bne \miss
 .endm

/* PROFID miss: the facade id in d0 is the 12 o'clock id (928 + 12k) of the open editor on the Profiles page.
 * Uses d2, d3, a2 (a2 = P on a hit); d0, d1, a0, a1 kept. */
 .macro PROFID miss
 PVAL \miss
 movbu (AXIS,a2),d3
 cmp 4,d3
 bne \miss
 movbu (EDK,a2),d3
 cmp 4,d3
 bcc \miss
 mov d3,d2
 add d2,d2
 add d3,d2
 asl2 d2
 add 928,d2
 mov d0,d3
 exthu d3
 cmp d2,d3
 bne \miss
 .endm


/* in d0 = setting id; hit: a2 = P, d2 = 64*slot + sector, d3 = 0 Light / 1 Hue. Uses d2, d3, a2 only.
 * COLOR1..4 sector ids 928..975 (12 per profile, UI sector order), P valid, marker, axis 1 (Light) or 2 (Hue). */
 .macro WHERE miss
 mov d0,d2
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc \miss
 clr d3
81:
 cmp 12,d2
 bcs 82f
 add -12,d2
 add 64,d3
 bra 81b
82:
 add d3,d2
 PVAL \miss
 mov (EMARK,a2),d3
 cmp EMAGIC,d3
 bne \miss
 movbu (AXIS,a2),d3
 add -1,d3
 cmp 4,d3                         /* 1..4: Light, Hue, Extras, Film */
 bcc \miss
 .endm

/* after WHERE: a2 = the cell's address - 32 (read with (32,a2)); WB page: only Yellow (A-B, +26) and Green (G-M, +27),
 * any other slice -> \none. Uses d2, d3, a2. */
 .macro CELL none
 cmp 3,d3                         /* Looks page: only 12 o'clock -> the profile's look number P+LIDX+k */
 bne 76f
 mov d2,d3
 and 63,d3
 cmp 0,d3
 bne \none
 mov d2,d3
 lsr 6,d3
 add d3,a2
 add LIDX-32,a2
 bra 74f
76:
 cmp 2,d3                         /* v0.20 Extras page: slice 0..9 (1..10 clockwise from 12 o'clock) -> slot byte xt_tab */
 bne 71f
 mov d2,d3
 and 63,d3
 cmp 10,d3
 bcc \none
 and 0xc0,d2
 add a2,d2                        /* P + 64*slot */
 mov xt_tab,a2
 add d3,a2
 add d3,a2
 add d3,a2
 movbu (a2),d3
 cmp 0,d3
 beq \none
 mov d2,a2
 add d3,a2
 bra 74f
71:
 add d2,a2
 cmp 0,d3
 bne 74f
 add 12,a2
74:
 .endm

hl_pp:
 call color_builder,[d2,d3,a2,a3],96
 movhu (STATE),d0
 cmp 0,d0
 beq hl_out
 mov 63153,d0                     /* effective COLOR profile number (as capture population) */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 add -1,d0
 cmp 4,d0
 bcc hl_out                       /* not COLOR1..4 */
 mov d0,d1                        /* d1 = slot 0..3 */
 movhu (STATE),d0
 add -1,d0                        /* h - 1 */
 cmp HMAX,d0
 bcc hl_out                       /* 0 (-1 wraps), 0xFFFF and out-of-pool handles */
 btst 3,d0
 bne hl_out
 mov d0,a1
 add POOL,a1                      /* a1 = block (uncached) */
 mov (a1),d0
 cmp MAGIC,d0
 bne hl_out
 asl 6,d1
 add d1,a1
 add 32,a1                        /* a1 = slot entry */
 movbu (31,a1),d0
 btst 2,d0
 beq hl_out                       /* H/L not enabled for this slot */
 clr d1
hl_v:                             /* all 24 values -7..7 before any write */
 movbu (d1,a1),d0
 extb d0
 add 7,d0
 cmp 14,d0
 bhi hl_out
 inc d1
 cmp 24,d1
 bne hl_v
 add -12,sp
 mov d2,(0,sp)
 mov d3,(4,sp)
 mov a3,(8,sp)
 mov (12,a2),a0
 add 854,a0                       /* output record 0, hue field (+18) */
 mov hl_lut,a3
 clr d2
hl_w:
 mov d2,d3
 add 60,d3
 movbu (d3,a3),d0                 /* w = perm[r] (UI sector of record r) */
 movbu (d0,a1),d1
 extb d1
 add 7,d1
 add d1,d1
 movhu (d1,a3),d1                 /* hue LUT */
 movhu d1,(a0)
 add 12,d0
 movbu (d0,a1),d1
 extb d1
 add 7,d1
 add d1,d1
 add 30,d1
 movhu (d1,a3),d1                 /* lightness LUT */
 movhu d1,(4,a0)
 add 24,a0
 inc d2
 cmp 12,d2
 bne hl_w
 mov (0,sp),d2
 mov (4,sp),d3
 mov (8,sp),a3
 add 12,sp
hl_out:
 jmp color_resume

pr_hook:                          /* entered by jmp from 0x60415216; frame = 0x60415111's */
 call trig,[d2,d3,a2,a3],36       /* the displaced stock call */
 movhu (STATE),d0
 cmp 0,d0
 bne pr_ed                        /* already attempted this power-on */
 call pr_gate,[d2,d3,a2,a3],36
 bra pr_back
pr_ed:
 jmp lg_pr                        /* v0.27: ed_trig (save the edits when dirty) with the debug log around it */
pr_back:
 jmp trig_resume

pr_gate:                          /* frame 36: (12,sp) = tid out */
 mov (SECBITS),d0
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne pr_gout                      /* not all 10 sections copied */
 mov sp,a0
 add 12,a0
 call get_tid,[a2],4
 cmp 0,d0
 bne pr_gout                      /* not a task context */
 movhu (HLS_TID),d1
 cmp 0,d1
 beq pr_gout
 btst 0x8000,d1
 bne pr_gout                      /* HLS_EVENT not created yet */
 movhu (12,sp),d0
 cmp d1,d0
 bne pr_gout                      /* not the HLS_EVENT task */
 mov 61440,d1
 mov (MS_A),d0
 cmp d1,d0
 beq pr_go
 mov (MS_B),d0
 cmp d1,d0
 beq pr_go
 mov (MS_C),d0
 cmp d1,d0
 bne pr_gout                      /* no medium MOUNT OK: retry at the next shutter event */
pr_go:
 mov 0xffff,d0
 movhu d0,(STATE)                 /* one attempt per power-on */
 call sd_load,[d2,d3,a2,a3],36
pr_gout:
 ret [d2,d3,a2,a3],36

/* ed_trig (frame 36, (12,sp) = tid out): P valid + marker + dirty == 1 + the same context gate as pr_gate
 * -> dirty = 0, one ed_save, status byte = its result. */
ed_trig:
 PVAL t_out                       /* v0.21: no automatic capture into the selected looks (pf_wb gone): a look
                                     changes only when OK is held on the Looks page (lk_hold) */
 mov (EMARK,a2),d0
 cmp EMAGIC,d0
 bne 1f
 clr d0
 movbu d0,(AXIS,a2)               /* leaving for the shutter: other screens read Saturation again */
 mov -1,d0                        /* film test 8: -1 = the stock pictures (gd_sel puts "Color" back too) */
 call gd_set,[d2,a2],8
1:
 movbu (DIRTY,a2),d0
 cmp 1,d0
 bne t_out
 mov (SECBITS),d0
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne t_out
 mov sp,a0
 add 12,a0
 call get_tid,[a2],4
 cmp 0,d0
 bne t_out
 movhu (HLS_TID),d1
 cmp 0,d1
 beq t_out
 btst 0x8000,d1
 bne t_out
 movhu (12,sp),d0
 cmp d1,d0
 bne t_out
 mov 61440,d1
 mov (MS_A),d0
 cmp d1,d0
 beq t_go
 mov (MS_B),d0
 cmp d1,d0
 beq t_go
 mov (MS_C),d0
 cmp d1,d0
 bne t_out
t_go:
 clr d0
 movbu d0,(DIRTY,a2)              /* one attempt per batch of edits, whatever happens */
 call ed_save,[d2,d3,a2,a3],24
 movbu d0,(STATUS,a2)
 call fl_save,[d2,d3,a2,a3],24    /* v0.24: EDITS.BIN (when changed), then pf_save */
t_out:
 ret [d2,d3,a2,a3],36

/* ---------------------------------------------------------------- on-camera editor (Caduceus look editor
 * phase 1 design, cakelesscoder/caduceus-ep7 Apache-2.0; OM-3 addresses and OM-3 Color Profile editor).
 * Pages (axis byte P+AXIS): 0 Saturation (stock), 2 Hue, 1 Light. INFO in the COLOR1-4 editor:
 *   Saturation (single) -> stock (ALL on) ; ALL on -> stock (ALL off), then Hue ; Hue -> Light ; Light -> Saturation.
 * The H/L values live in the loaded table P (slot +0 hue, +12 light, flags +31 bit1), -5..5 in the editor.
 */

/* ed_get <- facade vtable +12 word 0x60e57480 (GetValue, stock 0x60b86de7). CALLS entry: d0 id, a0 facade,
 * a1 out; -> d0 0 and (a1) = value. Miss: every register and the stack as at entry, jmp stock. */
ed_get:
 cmp 0,a1
 beq g_stock
 movm [d2,d3,a2],(sp)
 mov d0,d2                        /* 916..927: "the selected slice" ids the readout next to Vivid reads */
 exthu d2
 add -916,d2
 cmp 12,d2
 bcc 1f
 PVAL g_miss
 movbu (AXIS,a2),d3               /* only on the Hue / Light / Extras / Film pages: else stock, id unchanged */
 add -1,d3
 cmp 4,d3
 bcc g_miss
 movbu (EDK,a2),d3                /* -> sector id 928 + 12k + slice of the open editor */
 cmp 4,d3
 bcc g_miss
 call vl_s,[d2,d3,a2,a3],20       /* v0.20: the dial label ("Vivid") names the Extras slice (code block) */
 mov d3,d0
 add d0,d0
 add d3,d0
 asl2 d0
 add d2,d0
 add 928,d0
1:
 WHERE g_miss
 CELL 4f
 movbu (32,a2),d0
 extb d0
 cmp -5,d0
 bge 2f
 mov -5,d0
2:
 cmp 5,d0
 ble 3f
 mov 5,d0
 bra 3f
4:
 clr d0                           /* WB page: the other slices read 0 */
3:
g_put:
 mov d0,(a1)
 movm (sp),[d2,d3,a2]
 clr d0
 rets
g_miss:
 movm (sp),[d2,d3,a2]
g_stock:
 jmp stock_get

/* ed_default <- facade vtable +156 word 0x60e57510 (GetDefault, stock 0x60b86e44): H/L default 0. */
ed_default:
 cmp 0,a1
 beq d_stock
 movm [d2,d3,a2],(sp)
 WHERE d_miss
 clr d0
 mov d0,(a1)
 movm (sp),[d2,d3,a2]
 rets
d_miss:
 movm (sp),[d2,d3,a2]
d_stock:
 jmp stock_default

/* ed_set <- 0x60b8798b `call 0x60bb528f,[d2,d3,a2,a3],68` in the facade SetValue (mode 0): entered exactly like
 * the settings manager (d0 id, d1 value, a0 inner, a1 mode; d2/d3/a2/a3 saved by the call; return address at
 * (68,sp)). H/L hit: value -5..5 into the table, slot H/L bit, dirty; then the manager runs for the id with its
 * unchanged Saturation value, so its listeners refresh the screen as after a stock edit. */
ed_set:
 WHERE s_stock
 cmp -5,d1
 blt s_bad
 cmp 5,d1
 bgt s_bad
 cmp 3,d3
 bne 1f
 jmp s_look                       /* Looks page (sec 3) */
1:
 cmp 2,d3
 beq s_x
 cmp 0,d3
 bne 4f
 add 12,d2                        /* Light */
4:
 add 32,d2
 movbu d1,(d2,a2)                 /* the value first ... */
 and 0xc0,d2                      /* 64*slot (32 + 12 + 11 < 64) */
 add 63,d2
 movbu (d2,a2),d1
 or 2,d1
 movbu d1,(d2,a2)                 /* ... then the slot's H/L enable bit ... */
s_dirty:                          /* test 16: hand edits belong to the selected bank profile (saved back at the half-press) */
s_dirty2:
 mov 1,d1
 movbu d1,(DIRTY,a2)              /* ... then dirty (saved to the card on the next half-press) */
 mov d0,d2
 mov a0,d3
 mov a1,a2
 add -4,sp                        /* the getter's return address goes below our frame */
 call sget,[],4                   /* d0 = the id's Saturation value (0x603f0111; keeps d2/d3/a2/a3) */
 add 4,sp
 mov d0,d1
 mov (68,sp),d0                   /* MDR = the setter's return address again, as the stock call left it */
 mov d0,mdr
 mov d2,d0
 mov d3,a0
 mov a2,a1
 jmp manager
s_x:                              /* Extras page: d2 = 64*slot + slice, d1 = value; a3 free (saved by the setter frame).
                                   * xt_tab {slot byte, min, max}; A-B / G-M also turn the slot's WB override on */
 mov d2,d3
 and 63,d3
 cmp 10,d3
 bcc s_bad
 mov xt_tab,a3
 add d3,a3
 add d3,a3
 add d3,a3
 movbu (a3),d3
 cmp 0,d3
 beq s_bad
 and 0xc0,d2
 add 32,d2
 add d3,d2                        /* 64*slot + 32 + byte */
 movbu (1,a3),d3                  /* (v0.21: the dial itself now stops at the cell's range, pf_cnt / pf_vbi) */
 extb d3
 cmp d3,d1
 blt s_bad
 movbu (2,a3),d3
 extb d3
 cmp d3,d1
 bgt s_bad
 movbu d1,(d2,a2)                 /* the value first ... */
 movbu (a3),d3
 cmp 28,d3
 bcc 7f                           /* not WB */
 and 0xc0,d2
 add 57,d2                        /* ... then wb_flags (+25): bit0 on, bit7 off */
 movbu (d2,a2),d1
 or 1,d1
 and 0x7f,d1
 movbu d1,(d2,a2)
7:
 bra s_dirty
s_bad:
 clr d0
 ret [d2,d3,a2,a3],68
s_stock:
 jmp manager

/* ed_init <- COLOR1-4 editor records +4 (stock 0x6122393a, CALLS, d0 = the editor key 0x1540..0x1543, a0 parent).
 * Test 18: with a profile bank, a new editor starts on the Profiles page (axis 4), else on Saturation. The page,
 * EDK (this editor's COLOR, from d0) and the first-use marker are set before the stock init, so the children build
 * their value lists for that page (count / value-by-index: Profiles 0..5). INFO order unchanged:
 * Profiles -> Saturation -> (All) -> Hue -> Light -> WB/BW -> Profiles. Registers as at entry for the stock init. */
ed_init:
 movm [d3,a2],(sp)
 PVAL i_out
 movm [other],(sp)                /* d0 (the key), d1, a0, a1 for the stock init */
 add -4,sp
 call ei_page,[],4
 add 4,sp
 movm (sp),[other]
i_out:
 movm (sp),[d3,a2]
 jmp stock_init


/* wb_get <- the 12 WB fine-tune reads (`mov 34041|38521,d0; mov 0,a0; clr d1; call 0x60063380,[d2,d3],12`): capture
 * WB resolution 0x60457982.., pipeline params 0x604631b2/c5, WB record 0x604876c3/d8. Entered with the getter's own
 * frame: d0 key, d1 idx, a0 0 -> d0 (type 9: sign-extended s8). Returns the stock value, plus the active COLOR
 * profile's A-B / G-M (slot +26 / +27 when wb_flags +25 & 0x81 == 1) clamped to -7..7 (additive, as asked). */
wb_get:
 mov d0,d2                        /* key (d2/d3 saved by the site's call) */
 call getter,[d2,d3],12           /* the stock value */
 mov d0,d3
 mov 38017,d0                     /* picture mode (6 -> 40209), as capture population reads it */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 cmp 6,d0
 bne 1f
 mov 40209,d0
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
1:
 cmp 11,d0                        /* COLOR profiles only */
 bne 9f
 mov 63153,d0
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 add -1,d0
 cmp 4,d0
 bcc 9f
 mov d0,d1                        /* slot 0..3 */
 movhu (STATE),d0
 add -1,d0
 cmp HMAX,d0
 bcc 9f
 btst 3,d0
 bne 9f
 mov d0,a1
 add POOL,a1
 mov (a1),d0
 cmp MAGIC,d0
 bne 9f
 asl 6,d1
 add d1,a1
 add 32,a1                        /* slot entry */
 movbu (25,a1),d0
 and 0x81,d0
 cmp 1,d0
 bne 9f
 movbu (26,a1),d0                 /* A-B: 34041, and the Auto WB ones 7401 / 7433 (v0.21) */
 cmp 34041,d2
 beq 2f
 cmp 7401,d2
 beq 2f
 cmp 7433,d2
 beq 2f
 movbu (27,a1),d0                 /* G-M: 38521, and the Auto WB ones 7417 / 7449 (v0.21) */
 cmp 38521,d2
 beq 2f
 cmp 7417,d2
 beq 2f
 cmp 7449,d2
 bne 9f
2:
 extb d0
 cmp -7,d0
 blt 9f
 cmp 7,d0
 bgt 9f
 extb d3
 add d0,d3
 cmp -7,d3
 bge 3f
 mov -7,d3
3:
 cmp 7,d3
 ble 9f
 mov 7,d3
9:
 mov d3,d0
 ret [d2,d3],12

/* pf_cnt <- facade vtable +28 word 0x60e57490 (count, stock 0x60b86e09): d0 id, a0 facade -> d0 count. COLOR1-4
 * cell ids 928..975 ask code block +96 (xb_cv: the Looks page's 12 o'clock 0..5; v0.21 an Extras cell its own range,
 * so the dial stops at the ends); anything else, or no answer: stock. */
pf_cnt:
 movm [d2,d3,a2],(sp)
 add -4,sp
 mov d0,d2
 exthu d0
 add -928,d0
 cmp 48,d0
 bcc 9f
 call xp,[],0
 beq 9f
 add 96,a1
 mov d2,d0
 calls (a1)                       /* -> d0 count, d1 1 hit / 0 miss */
 cmp 0,d1
 bne 8f
9:
 mov d2,d0
 add 4,sp
 movm (sp),[d2,d3,a2]
 jmp stock_cnt
8:
 add 4,sp
 movm (sp),[d2,d3,a2]
 rets

/* pf_vbi <- facade vtable +32 word 0x60e57494 (value by index, stock 0x60b87031): d0 id, d1 index, a0 facade,
 * a1 out (or 0) -> d0 value (-1 = no such index), (a1) = the same. Cell ids 928..975: code block +104 (xb_vb,
 * d3 = out); anything else, or no answer: stock. */
pf_vbi:
 movm [d2,d3,a2],(sp)
 add -4,sp
 mov d0,d2
 mov a1,d3
 mov d1,a2
 exthu d0
 add -928,d0
 cmp 48,d0
 bcc 9f
 call xp,[],0                     /* keeps d1 */
 beq 9f
 add 104,a1
 mov d2,d0
 calls (a1)                       /* d0 id, d1 index, d3 out -> d0 value, d1 1 hit / 0 miss */
 cmp 0,d1
 bne 8f
9:
 mov d2,d0
 mov a2,d1
 mov d3,a1
 add 4,sp
 movm (sp),[d2,d3,a2]
 jmp stock_vbi
8:
 add 4,sp
 movm (sp),[d2,d3,a2]
 rets

.balign 2
hl_lut:                           /* +0: hue raw[ui+7] (15 hw); +30: lightness raw[ui+7]; +60: perm[12] */
 .hword 7000,6000,5000,4000,3000,2000,1000,0,-1000,-2000,-3000,-4000,-5000,-6000,-7000
 .hword -300,-250,-200,-150,-100,-50,-25,0,25,50,100,150,200,250,300
 .byte 0,2,4,6,8,10,1,3,5,7,9,11
ext1_end:

/* ------------------------------------------------------------------ section-4 tail */
.section .ext4,"ax"
sd_load:                          /* frame 36 */
 mov 1024,d0
 call malloc,[],4
 mov a0,a2
 cmp 0,a2
 beq sd_out
 clr d0                           /* editor: the whole block starts at 0 (marker, page, dirty) */
 clr d2
sd_z:
 movbu d0,(d2,a2)
 inc d2
 cmp 1024,d2
 bne sd_z
 call sd_def,[d2],8               /* built-in defaults into the block */
 mov sd_path,a0
 mov sd_mode,a1
 call fopen,[],4
 mov a0,a3
 cmp 0,a3
 beq sd_pub                       /* no file: publish the defaults */
 mov a3,a0
 clr d0
 mov 1,d1                         /* whence 1 = END */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne sd_close
 mov a3,a0
 call ftell,[d2,a2,a3],16
 mov d0,d3                        /* file size */
 cmp FILE_LEN,d3
 bne sd_close
 mov a3,a0
 clr d0
 mov 2,d1                         /* whence 2 = SET */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne sd_close
 mov a2,a0
 mov 1,d0
 mov d3,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2                        /* bytes read */
 mov a3,a0
 call fclose,[d2,a2,a3],16
 cmp d3,d2
 bne sd_redef
 mov a2,a0
 call sd_check,[d2,d3,a2,a3],16
 cmp 0,d0
 beq sd_pub                       /* valid file: keep it */
 bra sd_redef
sd_close:
 mov a3,a0
 call fclose,[d2,a2,a3],16
sd_redef:
 call sd_def,[d2],8
sd_pub:
 clr d1
 mov d1,(LPTR,a2)                 /* no looks / look numbers 0 until lk_load publishes */
 mov d1,(LIDX,a2)
 mov a2,d0
 add NEG_POOL,d0                  /* buf - POOL */
 cmp HMAX,d0
 bcc sd_free                      /* block not wholly inside the class-1 pool */
 btst 3,d0
 bne sd_free                      /* not 4-aligned */
 inc d0
 movhu d0,(STATE)                 /* publish: the colour hook switches to the block */
 call gd_load,[d2,d3,a2,a3],28    /* editor guide pictures from C:\OM3MOD\GUIDES.BIN (optional) */
 call pf_load,[d2,d3,a2,a3],28    /* look bank from C:\OM3MOD\LOOKS.BIN (test 16; PROFILES.BIN before v0.19) */
 call nm_load,[d2,d3,a2,a3],36    /* profile name pictures from C:\OM3MOD\NAMES.BIN (test 17) */
 bra sd_out                       /* block kept for the rest of the power-on */
sd_free:
 mov a2,a0
 call free,[],4
sd_out:
 ret [d2,d3,a2,a3],36

sd_def:                           /* a2 = block: the built-in defaults (neutral): the header with its CRC, then 512 zero */
 mov sd_hdr,a0                    /* test 17: made here instead of copied from a 544-byte table (frees code space) */
 clr d2
sd_d1:
 clr d0
 cmp HDR_LEN,d2
 bcc 1f
 movbu (d2,a0),d0
1:
 movbu d0,(d2,a2)
 inc d2
 cmp FILE_LEN,d2
 bne sd_d1
 mov DEF_CRC,d0
 mov d0,(16,a2)
 ret [d2],8

/* sd_check (Caduceus v1): a0 = buffer -> d0 = 0 valid, 1 invalid. */
sd_check:
 mov a0,a2
 mov sd_hdr,a3
 clr d2
sd_h1:
 movbu (d2,a2),d0
 movbu (d2,a3),d1
 cmp d1,d0
 bne sd_bad
 inc d2
 cmp 16,d2
 bne sd_h1
 mov 20,d2
sd_h2:
 movbu (d2,a2),d0
 movbu (d2,a3),d1
 cmp d1,d0
 bne sd_bad
 inc d2
 cmp HDR_LEN,d2
 bne sd_h2
 mov -1,d0
 mov a2,a0
 mov 16,d1
 call sd_crc,[d2,d3],12
 mov a2,a0
 add 20,a0
 mov CRC_TAIL,d1
 call sd_crc,[d2,d3],12
 not d0
 clr d2
sd_c1:
 movbu (16,a2),d1
 mov d0,d3
 and 255,d3
 cmp d3,d1
 bne sd_bad
 lsr 8,d0
 inc a2
 inc d2
 cmp 4,d2
 bne sd_c1
 add -4,a2
 mov a2,a0
 add HDR_LEN,a0
 clr d2
sd_r1:
 movbu (d2,a0),d0
 extb d0
 mov d2,d1
 and 63,d1
 mov sd_lo,a1
 movbu (d1,a1),d3
 extb d3
 sub d3,d0
 mov sd_span,a1
 movbu (d1,a1),d3
 cmp d3,d0
 bhi sd_bad
 inc d2
 cmp PAYLOAD_LEN,d2
 bne sd_r1
 clr d0
 ret [d2,d3,a2,a3],16
sd_bad:
 mov 1,d0
 ret [d2,d3,a2,a3],16

/* sd_crc: d0 = running CRC, a0 = data, d1 = length (> 0) -> d0. */
sd_crc:
 movbu (a0),d2
 xor d2,d0
 mov 8,d3
sd_b1:
 btst 1,d0
 beq sd_b0
 lsr 1,d0
 xor 0xedb88320,d0
 bra sd_b2
sd_b0:
 lsr 1,d0
sd_b2:
 add -1,d3
 bne sd_b1
 inc a0
 add -1,d1
 bne sd_crc
 ret [d2,d3],12

/* ---------------------------------------------------------------- editor save (HLS_EVENT, from ed_trig)
 * a2 = P (validated) -> d0 status: 1 saved, 2 no memory, 3 .NEW failed, 4 .BIN failed (.NEW is good).
 * S = malloc(1664): image S+0 (544 B, header CRC-32 recomputed), old .BIN S+OLD, read-back S+RBD.
 * Order (Caduceus): BUNDLES.NEW (read back) -> old BUNDLES.BIN copied to BUNDLES.BAK -> BUNDLES.BIN (read back). */
ed_save:
 mov 1664,d0
 call malloc,[],4
 mov a0,a3
 mov 2,d0
 cmp 0,a3
 beq v_ret
 clr d2                           /* copy P[0..543] -> S */
1:
 movbu (d2,a2),d0
 movbu d0,(d2,a3)
 inc d2
 cmp FILE_LEN,d2
 bne 1b
 mov a3,a0                        /* v0.26.2: the image's slots: a byte outside sd_check's ranges <- 0, so a refused BUNDLES.BIN is never written */
 add HDR_LEN,a0
 call sd_san,[d2,d3],12
 mov -1,d0                        /* header CRC-32 of S[0..15] + S[20..543] at S+16 */
 mov a3,a0
 mov 16,d1
 call sd_crc,[d2,d3],12
 mov a3,a0
 add 20,a0
 mov CRC_TAIL,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(16,a3)
 mov ed_p_new,a0                  /* 1. BUNDLES.NEW, verified by read-back */
 mov a3,a1
 call ed_wfile,[d2,d3,a2,a3],28
 mov d0,d3
 mov 3,d0
 cmp 0,d3
 bne v_free
 mov sd_path,a0                   /* 2. old BUNDLES.BIN -> BUNDLES.BAK (only a 544-byte file) */
 mov sd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 3f
 mov a0,a2                        /* a2 = handle (P no longer needed) */
 mov a3,a0
 add OLD,a0
 mov 1,d0
 mov FILE_LEN,d1
 mov a2,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d3
 mov a2,a0
 call fclose,[d2,a2,a3],16
 cmp FILE_LEN,d3
 bne 3f
 mov ed_p_bak,a0
 mov a3,a1
 add OLD,a1
 call ed_wfile,[d2,d3,a2,a3],28   /* a .BAK failure does not stop the save */
3:
 mov sd_path,a0                   /* 3. BUNDLES.BIN, verified by read-back */
 mov a3,a1
 call ed_wfile,[d2,d3,a2,a3],28
 mov d0,d3
 mov 4,d0
 cmp 0,d3
 bne v_free
 mov 1,d0
v_free:
 mov d0,d2
 mov a3,a0
 call free,[],4
 mov d2,d0
v_ret:
 ret [d2,d3,a2,a3],24

/* ed_wfile: a0 path, a1 buf (FILE_LEN bytes), a3 = S -> d0 0 ok / 1 fail. Read-back into S+RBD.
 * Locals: (4,sp) buf, (8,sp) handle. */
ed_wfile:
 mov a0,a2
 mov a1,(4,sp)
 mov ed_m_w,a1
 call fopen,[],4
 cmp 0,a0
 beq w_fail
 mov a0,(8,sp)
 mov a0,a1                        /* fwrite(buf, 1, n, h) */
 mov FILE_LEN,d1
 mov 1,d0
 mov (4,sp),a0
 call fwrite,[d2,d3,a2,a3],24
 mov d0,d3
 mov (8,sp),a0
 call fclose,[d2,a2,a3],16
 cmp FILE_LEN,d3
 bne w_fail
 mov a2,a0                        /* read back */
 mov sd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq w_fail
 mov a0,(8,sp)
 mov a0,a1
 mov a3,a0
 add RBD,a0
 mov 1,d0
 mov FILE_LEN,d1
 call fread,[d2,d3,a2,a3],24
 mov d0,d3
 mov (8,sp),a0
 call fclose,[d2,a2,a3],16
 cmp FILE_LEN,d3
 bne w_fail
 mov (4,sp),a0
 mov a3,a1
 add RBD,a1
 mov FILE_LEN,d2
5:
 movbu (a0),d0
 movbu (a1),d1
 cmp d0,d1
 bne w_fail
 inc a0
 inc a1
 add -1,d2
 bne 5b
 clr d0
 ret [d2,d3,a2,a3],28
w_fail:
 mov 1,d0
 ret [d2,d3,a2,a3],28

ed_p_new:
 .asciz "C:\\OM3MOD\\BUNDLES.NEW"
ed_p_bak:
 .asciz "C:\\OM3MOD\\BUNDLES.BAK"
ed_m_w:
 .asciz "w"
sd_path:
 .asciz "C:\\OM3MOD\\BUNDLES.BIN"
sd_mode:
 .asciz "r"
.balign 4
 .include "data4.inc"            /* sd_hdr (32), sd_lo (64), sd_span (64); DEF_CRC (test 17) */
ext4_end:

/* ------------------------------------------------------------------ section-6 tail: editor INFO cycle, cursor read,
 * wheel outline (reached only from section-6/7 GUI code) */
.section .ext6,"ax"
/* ed_info <- COLOR1-4 editor records +44 (stock 0x6122661b; the router 0x61223ca6 sends INFO 0x9014 there).
 * CALLS entry: d0 event, d1 arg, a0 parent. Locals: (4) d1, (8) a1, (12) cursor id, (16) value, (20) P. */
ed_info:
 cmp 0x9014,d0
 beq k_go
 jmp stock_info
k_go:
 movm [d2,d3,a2,a3],(sp)
 add -24,sp
 mov d1,(4,sp)
 mov a1,(8,sp)
 mov a0,a3
 cmp 0,a3
 beq f_no
 movhu (96,a3),d0                 /* editor key 0x1540..0x1543 = COLOR1..4 */
 add -0x1540,d0
 cmp 4,d0
 bcc f_no
 mov d0,d1
 add 2197,d1
 mov d1,(12,sp)                   /* the editor's cursor setting 2197..2200 (255 = ALL) */
 mov d0,d2                        /* first sector id = 928 + 12k */
 asl2 d2
 mov d2,d1
 add d1,d1
 add d1,d2
 add 928,d2
 mov a3,a0                        /* children 1..12 present, ids in order */
 mov 12,d1
 mov d2,d0
5:
 mov (128,a0),a1
 cmp 0,a1
 beq f_no
 movhu (80,a1),d3
 cmp d0,d3
 bne f_no
 inc d0
 add 4,a0
 add -1,d1
 bne 5b
 PVAL f_no
 mov a2,(20,sp)
 mov (12,sp),d0                   /* the editor's profile k (for the readout's slice ids 916..927) */
 add -2197,d0
 movbu d0,(EDK,a2)
 mov (EMARK,a2),d0                /* first use since the load: marker, page Saturation */
 cmp EMAGIC,d0
 beq 6f
 clr d0
 movbu d0,(AXIS,a2)
 movbu d0,(STATUS,a2)             /* v0.25: DIRTY kept (a film chosen before this first use was never saved) */
 mov EMAGIC,d0
 mov d0,(EMARK,a2)
6:
 jmp k_open                       /* film test 10: the INFO that opens the wheel goes to Hue; else k_ad, then k_6b */
k_6b:
 mov (16,sp),d0
 cmp 255,d0
 beq k_all
 mov (20,sp),a2
 movbu (AXIS,a2),d1
 .if W_SONE == 0
 cmp 0,d1
 beq f_no                         /* Saturation, single: stock INFO turns ALL on */
 .endif
 bra k_step                       /* film test 11 (W_SONE): from one colour on to the next page */
k_all:
 mov a3,a0                        /* ALL on: the stock INFO handler turns it off */
 mov 0x9014,d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls stock_info                 /* keeps d2/d3/a2/a3 */
 mov d0,d2                        /* its result */
 call k_ad,[a2],8
 mov (16,sp),d0
 cmp 255,d0
 bne k_step
7:
 mov d2,d0                        /* stock left ALL on (or no value): its result, no page change */
 ret [d2,d3,a2,a3],40
k_step:
 mov (20,sp),a2
 movbu (AXIS,a2),d0               /* S -> H -> L -> Extras -> (Film, when LOOKS.BIN loaded) -> S; v0.24 film test 7
                                   * (owner): Extras and Film hidden (W_EXTRAS / W_FILM 0): S -> H -> L -> S; film test 10
                                   * (W_HSL): H -> S -> L -> H */
 .if W_HSL
 mov 1,d1
 cmp 0,d0
 beq 8f
 mov 2,d1
 cmp 1,d0
 beq 8f
 clr d1
 .else
 mov 2,d1
 cmp 0,d0
 beq 8f
 mov 1,d1
 cmp 2,d0
 beq 8f
 .if W_EXTRAS
 mov 3,d1
 .elseif W_TONE
 mov 5,d1
 .else
 clr d1
 .endif
 cmp 1,d0
 beq 8f
 .if W_TONE
 mov 6,d1
 cmp 5,d0
 beq 8f
 .endif
 clr d1
 cmp 3,d0
 bne 8f
 mov (LPTR,a2),d1
 cmp 0,d1
 beq 8f
 .if W_FILM
 mov 4,d1
 .else
 clr d1
 .endif
 .endif
8:
 movbu d1,(AXIS,a2)
 mov d1,d0
 call gd_set,[d2,a2],8            /* the guide picture for the new page */
 mov 128,d2                       /* refresh children 1..12 from the facade (stock 0x611b20ea) */
9:
 mov a3,a0
 add d2,a0
 mov (a0),a0
 call refresh,[d2,d3,a2,a3],68
 add 4,d2
 cmp 176,d2
 bne 9b
 call k_cur,[a2],8                  /* poke: the cursor setting re-written with its own value */
 cmp 0,d0
 bne 10f                          /* no value (yet): no poke */
 call facade,[],4
 mov (a0),a2
 mov (4,a2),a2                    /* SetValue(id, mode 0, value) */
 mov (16,sp),a1
 clr d1
 mov (12,sp),d0
 calls (a2)
10:
 jmp k_sall                       /* film test 8: on Saturation, all colours */
/* k_ad: `call k_ad,[a2],8` from ed_info's frame (as k_cur): (24,sp) <- the ALL state. The code block reads the stock
 * INFO handler's setting 2201 + k (0x615ac0b4) and, when that is not 255, the cursor 2197 + k (the camera shows ALL in
 * either, depending on the slice it was entered from). Without a code block: k_cur (2197 + k only). */
k_ad:
 call xp,[],0
 cmp 0,a1
 beq 9f
 add 40,a1
 jmp (a1)
9:
 jmp k_cur
f_no:
 mov a3,a0
 mov 0x9014,d0
 mov (4,sp),d1
 mov (8,sp),a1
 add 24,sp
 movm (sp),[d2,d3,a2,a3]
 jmp stock_info

.section .ext1,"ax"                /* v0.20 test 5: k_cur moved from the sec-6 tail (x_load) */
/* k_cur: `call k_cur,[a2],8` from ed_info's frame (sp = ed_info's sp - 8: its (12) is our (20), its (16) our (24)):
 * facade GetValue(cursor id, &value) -> d0 (0 = ok). Keeps d2/d3/a2/a3. */
k_cur:
 call facade,[],4
 mov (a0),a2
 mov (12,a2),a2
 mov sp,a1
 add 24,a1
 mov (20,sp),d0
 calls (a2)
 ret [a2],8

.section .ext8,"ax"                /* ed_poly moved from the sec-6 tail (test 12: CELL grew) */
/* ed_poly <- the 48 sector reads of the Color Profile wheel drawing (0x60b1d0ca..0x60b1d354, case 6: profile = setting 903,
 * cursor 2197.., 12 x `mov id,d0; call 0x603f039d,[],4; movbu d0,(160+i,sp)`). Entered `call ed_poly,[],4`, d0 = id.
 * Hue / Light page: the value the editor shows (-5..5), so the wheel outline follows the page.
 * Otherwise jmp 0x603f039d (the stock getter body) with every register as at entry. Keeps d2/d3/a2/a3. */
ed_poly:
 movm [d2,d3,a2],(sp)
 WHERE p_miss
 CELL 4f
 movbu (32,a2),d0
 extb d0
 cmp -5,d0
 bge 2f
 mov -5,d0
2:
 cmp 5,d0
 ble 3f
 mov 5,d0
 bra 3f
4:
 clr d0
3:
 movm (sp),[d2,d3,a2]
 ret [],4
p_miss:
 movm (sp),[d2,d3,a2]
 jmp aget

ext6_end:

/* ------------------------------------------------------------------ section-10 tail: editor guide pictures
 * GUIDES.BIN: 'OM3G' | u32 total | u32 CRC-32 of bytes 12.. | u16 175 | u16 50 | u32 s1 | u32 s2 | 8 zero |
 * Hue stream at +32 | Light stream at +32 + align4(s1). Streams = OM-3 OSD type 11, 175 x 50 (as the stock
 * "Color All [INFO]" picture, descriptor GDESC in the resource RAM). */
.section .ext10,"ax"
/* gd_load: `call gd_load,[d2,d3,a2,a3],28`, a2 = P. Locals (4) handle, (8) buffer. Stores: P+GPTR, the heap buffer. */
gd_load:
 clr d0
 mov d0,(GPTR,a2)
 mov d0,(XPTR,a2)                 /* v0.20: no code block until this load has one */
 mov gd_path,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 clr d0
 mov 1,d1                         /* END */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov (4,sp),a0
 call ftell,[d2,a2,a3],16
 mov d0,d3                        /* n */
 cmp 33,d3
 bcs 8f
 cmp 24577,d3                      /* test 12: up to 24 KB (5 pictures) */
 bcc 8f
 mov (4,sp),a0
 clr d0
 mov 2,d1                         /* SET */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov d3,d0
 call malloc,[],4
 cmp 0,a0
 beq 8f
 mov a0,(8,sp)
 mov 1,d0
 mov d3,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 cmp d3,d2
 bne 7f
 mov (8,sp),a0
 call gd_check,[d2,d3,a2,a3],16
 cmp 0,d0
 bne 7f
 mov (8,sp),d0
 mov d0,(GPTR,a2)                 /* published last */
 call x_load,[d2,d3],12           /* v0.20: the code block, if this file carries one for this firmware */
 bra 9f
7:
 mov (8,sp),a0
 call free,[],4
 bra 9f
8:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
9:
 ret [d2,d3,a2,a3],28

/* gd_check: a0 = buffer, d3 = n -> d0 0 valid / 1 invalid. */
gd_check:
 mov a0,a3
 mov (a3),d0
 cmp GMAGIC,d0
 bne 1f
 mov (4,a3),d0
 cmp d3,d0
 bne 1f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov d3,d1
 add -12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 1f
 movhu (12,a3),d0
 cmp 175,d0
 bne 1f
 movhu (14,a3),d0
 cmp 50,d0
 bne 1f
 mov (16,a3),d0                   /* s1 */
 cmp 9,d0
 bcs 1f
 mov (20,a3),d1                   /* s2 */
 cmp 9,d1
 bcs 1f
 add 3,d0
 and -4,d0
 mov d0,d2                        /* align4(s1) */
 add 32,d0
 add d1,d0
 cmp d3,d0
 bhi 1f                           /* streams inside the file */
 mov (32,a3),d0
 cmp GHDR,d0
 bne 1f
 mov a3,a0
 add d2,a0
 mov (32,a0),d0
 cmp GHDR,d0
 bne 1f
 mov (24,a3),d1                   /* s3: optional third (WB) stream */
 cmp 0,d1
 beq 2f
 cmp 9,d1
 bcs 1f
 mov (20,a3),d0
 add 3,d0
 and -4,d0
 add d2,d0
 add 32,d0                        /* its offset */
 mov d0,d2
 add d1,d0
 cmp d3,d0
 bhi 1f
 mov a3,a0
 add d2,a0
 mov (a0),d0
 cmp GHDR,d0
 bne 1f
 mov (28,a3),d0                   /* s4: optional fourth (Glow) stream, after s3 */
 cmp 0,d0
 beq 2f
 cmp 9,d0
 bcs 1f
 add 3,d1
 and -4,d1
 add d1,d2                        /* its offset = s3 offset + align4(s3) */
 add d2,d0
 cmp d3,d0
 bhi 1f
 mov a3,a0
 add d2,a0
 mov (a0),d0
 cmp GHDR,d0
 bne 1f
2:
 clr d0
 ret [d2,d3,a2,a3],16
1:
 mov 1,d0
 ret [d2,d3,a2,a3],16

/* gd_set: `call gd_set,[d2,a2],8`, a2 = P, d0 = page (2 Hue, 1 Light, else stock). Uses d1, a0, a1.
 * Only when the descriptor is the stock 14/175x50/8 one and its payload is the stock stream or one of ours. */
gd_set:
 add -4,sp                        /* v0.25: its slot (without it the call wrote over gd_set's saved a2, and ed_trig went
                                   * on with a2 = garbage: no half-press save after the editor's first use) */
 call gd_sel,[d2,d3,a2,a3],24     /* film test 8: the Saturation page's label and guide */
 add 4,sp
 mov GDESC,a0
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
 mov (GPTR,a2),a1
 mov (16,a0),d1
 add -4,sp
 call nm_own,[],0                 /* a name picture of ours: d1 = GSTOCK_P */
 add 4,sp
 mov (GPTR,a2),a1
 cmp GSTOCK_P,d1
 beq 1f
 cmp 0,a1
 beq 9f                           /* someone else's payload: leave it */
 mov a1,d2
 sub d2,d1                        /* payload - G */
 cmp 24576,d1
 bcc 9f
1:
 cmp 4,d0
 bne 1f
 add -4,sp
 call nm_pick,[],0                /* Profiles page: the selected profile's name picture, if NAMES.BIN has one */
 add 4,sp
 cmp 0,d0
 beq 9f
 mov 4,d0
 mov (GPTR,a2),a1
1:
 jmp tg_sel                       /* v0.26: Shadows / Highlights -> their pictures in TONES.BIN (tg_sel) */
gd_s11:
 cmp 0,a1
 beq 4f
 cmp 2,d0
 beq 2f
 cmp 1,d0
 beq 3f
 cmp 4,d0
 beq 6f
 cmp 3,d0
 bne 4f
 mov (24,a1),d1                   /* WB picture, if the file has one */
 cmp 0,d1
 bne 5f
4:
 jmp gd_s0                        /* film test 11: Saturation -> our guide, else the camera's */
2:
 mov (16,a1),d1
 mov d1,(12,a0)
 mov a1,d1
 add 32,d1
 mov d1,(16,a0)
 bra 9f
3:
 mov (20,a1),d1
 mov d1,(12,a0)
 mov (16,a1),d1
 add 3,d1
 and -4,d1
 add 32,d1
 mov a1,d2
 add d2,d1
 mov d1,(16,a0)
 bra 9f
5:
 mov d1,(12,a0)                   /* s3 */
 mov (16,a1),d1
 add 3,d1
 and -4,d1
 mov (20,a1),d2
 add 3,d2
 and -4,d2
 add d2,d1
 add 32,d1
 mov a1,d2
 add d2,d1
 mov d1,(16,a0)
9:
 ret [d2,a2],8
6:                                /* Glow picture (s4 at +28), if the file has one and an s3 */
 mov (28,a1),d1
 cmp 0,d1
 beq 4b
 mov (24,a1),d2
 cmp 0,d2
 beq 4b
 mov d1,(12,a0)                   /* s4 */
 mov (16,a1),d1
 add 3,d1
 and -4,d1
 add 3,d2
 and -4,d2
 add d2,d1                        /* align4(s1) + align4(s3) */
 mov (20,a1),d2
 add 3,d2
 and -4,d2
 add d2,d1                        /* + align4(s2) */
 add 32,d1
 mov a1,d2
 add d2,d1
 mov d1,(16,a0)
 bra 9b


/* ed_event <- COLOR1-4 editor records +36 (stock 0x61225d52; the router's catch-all, which handles the held-OK
 * reset 0x903e). CALLS: d0 event, d1 arg, a0 parent. Reset with a loaded table: the stock reset runs with the page
 * set to Saturation (so it resets the stock saturation), then the profile's Hue and Light are cleared, marked dirty
 * (saved on the next half-press), and the current page's children and screen refreshed. Locals as ed_info:
 * (4) d1, (8) a1, (12) cursor id, (16) value, (20) P, (24) event (0x903e wheel / 0xf881 COLOR n item). Everything else: jmp stock, registers intact. */
ed_event:
 cmp 0x903e,d0                    /* held OK on the wheel */
 beq 1f
 cmp 0xf881,d0                    /* held OK on the COLOR n item: the whole profile */
 beq 1f
 jmp stock_event
1:
 movm [d2,d3,a2,a3],(sp)
 add -28,sp
 mov d1,(4,sp)
 mov a1,(8,sp)
 mov d0,(24,sp)                   /* the event */
 mov a0,a3
 cmp 0,a3
 beq e_no
 movhu (96,a3),d0                 /* editor key 0x1540..0x1543 = COLOR1..4 */
 add -0x1540,d0
 cmp 4,d0
 bcc e_no
 mov d0,d1
 add 2197,d1
 mov d1,(12,sp)                   /* cursor setting id (for k_cur / the poke) */
 PVAL e_no
 mov a2,(20,sp)
 movbu (AXIS,a2),d2               /* the page the user is on */
 jmp lk_hold                      /* v0.21: code block +88 (the Looks page saves the look; the whole-profile reset
                                     also clears the look selection), else e_rst */
e_rst:
 clr d1
 movbu d1,(AXIS,a2)               /* stock reset on Saturation */
 mov a3,a0
 mov (24,sp),d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls stock_event                /* keeps d2/d3/a2/a3 */
 mov d0,d3                        /* its result */
 mov (20,sp),a2
 movbu d2,(AXIS,a2)               /* back to the user's page */
 mov (12,sp),d0                   /* slot k = cursor id - 2197 */
 add -2197,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0                        /* slot entry: hue[12] +0, light[12] +12 */
 clr d0
 mov 59,d1                        /* slot +0..58 (hue, light, WB, flags, Blacks/Whites, Extras glow/art/NR/VigFix/Grain/Sharp,
                                   * v0.26 split toning) */
2:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 2b
 mov 1,d0
 movbu d0,(DIRTY,a2)              /* saved to the card on the next half-press */
 cmp 0,d2
 beq 4f                           /* on Saturation the stock reset already redrew */
e_lk:
 mov 128,d2                       /* Hue/Light page: children 1..12 re-read (now 0) */
3:
 mov a3,a0
 add d2,a0
 mov (a0),a0
 cmp 0,a0
 beq 4f
 call refresh,[d2,d3,a2,a3],68
 add 4,d2
 cmp 176,d2
 bne 3b
 call k_cur,[a2],8                /* poke the cursor setting so the screen rebuilds */
 cmp 0,d0
 bne 4f
 call facade,[],4
 mov (a0),a2
 mov (4,a2),a2
 mov (16,sp),a1
 clr d1
 mov (12,sp),d0
 calls (a2)
4:
 jmp e_sall                       /* film test 8: after a reset on Saturation, all colours again */
e_ret:
 mov d3,d0
 ret [d2,d3,a2,a3],44
e_no:
 mov a3,a0
 mov (24,sp),d0
 mov (4,sp),d1
 mov (8,sp),a1
 add 28,sp
 movm (sp),[d2,d3,a2,a3]
 jmp stock_event

/* ed_pmod <- jmp from 0x6129ba07, stock "COLOR profile changed?" (d0 picture mode 54/55/56/64 = COLOR1/2/3/4; its 18
 * settings at 0x6037ec10/eca0/ed30/edc0, 8-byte entries, id at +4). The same loop as stock but through ed_isdef, so
 * the '*' after COLOR n and the look name also follow Hue, Light and WB. Frame: the caller's call [d2,d3,a2],16. */
ed_pmod:
 clr d3                           /* v0.21 lk11: '*' = anything differs from the factory defaults (look or not) */
 mov 0x6037ec10,a2
 cmp 54,d0
 beq 1f
 mov 0x6037eca0,a2
 cmp 55,d0
 beq 1f
 mov 0x6037ed30,a2
 cmp 56,d0
 beq 1f
 mov 0x6037edc0,a2
 cmp 64,d0
 bne 3f
1:
 clr d2
 inc4 a2
2:
 mov (a2),d0
 mov d0,d1
 add -904,d1                      /* v0.22: the stock Sharpness (904..907) is off the COLOR 1-4 screen and unused there */
 cmp 4,d1                         /* (the Sharp slice decides), so it never makes the '*' */
 bcs 4f
 call ed_isd0,[d2,d3,a2],24
 cmp d3,d0
 bne 4f
 mov 1,d3
 bra 3f
4:
 inc d2
 add 8,a2
 cmp 18,d2
 bcs 2b
3:
 mov d3,d0
 ret [d2,d3,a2],16

/* ed_isdef <- the nine calls of stock "is at default" 0x6129bad6 (call [d2,d3,a2],24; d0 id -> d0 1 default, 0 changed).
 * They drive the '*' after COLOR n / the look name and the "Reset [OK hold]" guide (v0.21: with a look selected,
 * ed_pmod asks the code block instead). Stock first; a COLOR1-4 sector
 * id that stock calls default is reported changed when its Hue or Light is non-zero, or when the profile's WB shift is
 * on and non-zero. Reads only. */
ed_isd0:                          /* lk11: ed_pmod's entry ('*'): the Looks page is compared too */
 mov 1,d1
 bra 86f
ed_isdef:
 clr d1
86:
 mov d0,d2
 PVAL 85f
 movbu (AXIS,a2),d3               /* stock compare on Saturation, whatever page is open ... */
 cmp 4,d3                         /* v0.21: the Looks page reads "at default": no "Reset [OK hold]" guide there */
 bne 87f                          /* (OK held there saves the look, it never resets) */
 cmp 0,d1
 beq 8f
87:
 clr d0
 movbu d0,(AXIS,a2)
 mov d2,d0
 call stock_isdef,[d2,d3,a2],24   /* keeps d2/d3/a2 */
 movbu d3,(AXIS,a2)               /* ... then the page back */
 cmp 0,d0
 beq 9f
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc 8f
 mov a2,a0
 add 32,a0                        /* slot 0 entry */
81:
 cmp 12,d2
 bcs 82f
 add -12,d2
 add 64,a0
 bra 81b
82:
 movbu (47,a0),d3                 /* Blacks, Whites, Extras Glow/Clarity, Art Effect, NR, VigFix: any non-zero */
 mov (48,a0),d1                   /* +48..51 (slot entries are 4-aligned: P + 32 + 64k) */
 or d1,d3
 movhu (52,a0),d1                 /* +52, +53: VigFix, Grain */
 or d1,d3
 movbu (54,a0),d1                 /* +54 Sharp (v0.26: +55, a split toning colour, alone is no change) */
 or d1,d3
 movbu (56,a0),d1                 /* v0.26: the split toning strengths +56, +58 */
 or d1,d3
 movbu (58,a0),d1
 or d1,d3
 cmp 0,d3
 bne 7f
 movbu (25,a0),d3                 /* WB on: bit0 set, bit7 clear */
 and 0x81,d3
 cmp 1,d3
 bne 83f
 movbu (26,a0),d3
 cmp 0,d3
 bne 7f
 movbu (27,a0),d3
 cmp 0,d3
 bne 7f
83:
 add d2,a0
 movbu (a0),d3                    /* hue */
 cmp 0,d3
 bne 7f
 movbu (12,a0),d3                 /* light */
 cmp 0,d3
 bne 7f
8:
 mov 1,d0
 bra 9f
7:
 clr d0
9:
 ret [d2,d3,a2],24
85:                               /* no table: stock as is */
 mov d2,d0
 call stock_isdef,[d2,d3,a2],24
 ret [d2,d3,a2],24

ext10_end:

.section .ext3,"ax"
gd_mode:                          /* v0.21: moved from the section-10 tail (room for the Looks-page guide test) */
 .asciz "r"

/* ------------------------------------------------------------------ section-5 tail: per-profile Blacks / Whites
 * Port of Caduceus E-P7 patches/tone_ends (cakelesscoder/caduceus-ep7, Apache-2.0, docs/TONE_ENDS.md) to OM-3.
 * Hook 0x605197d7 in the development stage list (0x605197cb COLOR stage, 0x605197d2 luminance-LUT builder
 * 0x60518db2 = E-P7 0x603b0a70): the 7-byte call keeps the stock register list, frame and return address
 * (0x605197de); tone replays `mov d3,a0` and jumps to 0x60518fa4, which returns there.
 * d3 = context C; C+4 = request R, C+12 = output O; O+3828 = active 256 x u16 luminance LUT (10-bit, E-P7 O+2608),
 * O+3832 = the job's own 512-B buffer (E-P7 O+2612); the stock tone step also clears O+0 bit 16 (E-P7 O+4 bit 8).
 * Gates: LUT present; idempotent (O+3828 == O+3832 is remapped only when the builder rebuilt it this pass: art
 * override R+1568 or C+60 & 0x4134063e, the builder's own test); request key 11 (COLOR); table P valid; some COLOR
 * slot has Blacks/Whites != 0; effective COLOR profile 1..4 (getter 63153, as hl_pp / wb_get); slot +47 Blacks,
 * +48 Whites, s8 -5..5 (outside counts as 0). Remap = Caduceus tools/ep7_tone.py remap(), bit-exact.
 * Stores: own stack frame, O+3832..O+4343, O+3828, O+0. */
.section .ext5,"ax"
tone:
 add -52,sp
 mov d0,(48,sp)              /* (0,sp) is the getter call's return word */
 mov d1,(4,sp)
 mov d2,(8,sp)
 mov d3,(12,sp)
 mov a1,(16,sp)
 mov a2,(20,sp)
 mov a3,(24,sp)
 mov mdr,d0
 mov d0,(28,sp)
 mov d3,a2                        /* a2 = context C */
 mov (12,a2),a3                   /* a3 = output O */
 mov (3828,a3),d0
 cmp 0,d0
 beq t9                           /* no LUT */
 mov a3,d1
 add 3832,d1
 cmp d1,d0
 bne t1
 mov (4,a2),a1
 mov (1568,a1),d1
 cmp 0,d1
 bne t1
 mov (60,a2),d1
 and 0x4134063e,d1
 beq t9                           /* last pass's output (ours): keep */
t1:
 mov (4,a2),a1                    /* request R */
 movhu (10,a1),d0                 /* key 11 (COLOR), or 12 with +1731 0 (a COLOR still taking the camera's grain; */
 cmp 11,d0                        /* MONO has 0xa0 there) */
 beq 1f
 cmp 12,d0
 bne t9
 movbu (1731,a1),d0
 cmp 0,d0
 bne t9
1:
 PVAL t9                          /* a2 = P (C no longer needed) */
 mov a2,a0
 add 32,a0
 clr d1                           /* any COLOR slot with Blacks/Whites? */
 mov 4,d2
t2:
 movbu (47,a0),d0
 or d0,d1
 movbu (48,a0),d0
 or d0,d1
 add 64,a0
 add -1,d2
 bne t2
 cmp 0,d1
 beq t9                           /* no getter call */
 mov 63153,d0                     /* effective COLOR profile number */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12           /* keeps a2/a3 */
 add -1,d0
 cmp 4,d0
 bcc t9
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0                        /* a0 = slot entry */
 movbu (47,a0),d0                 /* Blacks */
 extb d0
 add 5,d0
 cmp 11,d0
 bcs 3f
 mov 5,d0
3:
 add -5,d0
 movbu (48,a0),d1                 /* Whites */
 extb d1
 add 5,d1
 cmp 11,d1
 bcs 4f
 mov 5,d1
4:
 add -5,d1
 mov d0,d2
 or d1,d2
 beq t9                           /* B = W = 0: no copy, no store */
 clr d2                           /* lo = 8B (B > 0) */
 clr d3                           /* cB = -12B (B < 0) */
 cmp 0,d0
 blt 5f
 mov d0,d2
 asl 3,d2
 bra 6f
5:
 mov -12,d3
 mul d0,d3
6:
 mov d2,(32,sp)
 mov d3,(36,sp)
 mov 1023,d3                      /* hi = 1023 + 10W (W < 0) */
 clr d2                           /* cW = 12W (W > 0) */
 cmp 0,d1
 blt 7f
 mov 12,d2
 mul d1,d2
 bra 8f
7:
 mov 10,d0
 mul d1,d0
 add d0,d3
8:
 mov d2,(40,sp)
 mov (32,sp),d0
 sub d0,d3                        /* span = hi - lo */
 mov 1025,d0
 mul d0,d3
 mov d3,(44,sp)                   /* K = span * 1025 */
 mov a3,a0
 add 3832,a0                      /* a0 = O+3832 */
 mov (3828,a3),a1
 cmp a0,a1
 beq 1f
 clr d1
2:
 movhu (d1,a1),d0
 movhu d0,(d1,a0)
 add 2,d1
 cmp 512,d1
 bne 2b
 mov a0,(3828,a3)                 /* O+3828 = O+3832 */
1:
 mov (a3),d0
 and -65537,d0                    /* clear O+0 bit 16, as the stock tone step does */
 mov d0,(a3)
 mov a0,a1
 add 512,a1
 clr d3                           /* running max */
10:
 movhu (a0),d0
 cmp 1023,d0
 bls 11f
 mov 1023,d0
11:
 mov 1023,d1                      /* toe crush: y -= cB * ((t*t>>10)*t>>10) >> 10, t = 1023 - y */
 sub d0,d1
 mov d1,d2
 mul d1,d2
 lsr 10,d2
 mul d1,d2
 lsr 10,d2
 mov (36,sp),d1
 mul d1,d2
 lsr 10,d2
 sub d2,d0
 bge 12f
 clr d0
12:
 mov d0,d2                        /* shoulder push: y += cW * ((y*y>>10)*y>>10) >> 10 */
 mul d0,d2
 lsr 10,d2
 mul d0,d2
 lsr 10,d2
 mov (40,sp),d1
 mul d1,d2
 lsr 10,d2
 add d2,d0
 cmp 1023,d0
 bls 13f
 mov 1023,d0
13:
 mov (44,sp),d1                   /* y = lo + (y*K + 0xFFFFF) >> 20 */
 mul d1,d0
 add 1048575,d0
 lsr 20,d0
 mov (32,sp),d1
 add d1,d0
 cmp d3,d0                        /* running max */
 bcc 14f
 mov d3,d0
14:
 mov d0,d3
 movhu d0,(a0)
 add 2,a0
 cmp a1,a0
 bne 10b
t9:
 mov (28,sp),d0
 mov d0,mdr
 mov (48,sp),d0
 mov (4,sp),d1
 mov (8,sp),d2
 mov (12,sp),d3
 mov (16,sp),a1
 mov (20,sp),a2
 mov (24,sp),a3
 add 52,sp
 mov d3,a0                        /* displaced 0x605197d7 */
 jmp st_run                       /* split-tone probe st1 (ext11): ends with mov d3,a0; jmp tone_next */


/* ------------------------------------------------------------------ section-3 tail: look library page (test 14)
 * LOOKS.BIN (written by the OM-3 Look Lab web tool): 'OM3K' | u32 total | u32 CRC-32 of bytes 12.. | u16 version 1 |
 * u16 n (1..16) | 16 zero | n x 32-B looks | n x 16-B names (ignored here). Look: hue[12] +0, light[12] +12 (s8 -5..5,
 * UI sector order), +24 wb on (0/1), +25 A-B, +26 G-M, +27 Blacks, +28 Whites (s8 -5..5), +29..31 zero.
 * P+LPTR = the checked heap copy (0 = none), P+LIDX+k = profile k's look number (0 = "My own"), P+BKUP+64k = the
 * slot entry as it was when profile k left look 0 (put back on the way to 0). Hand edits (s_dirty) and the resets set
 * the number back to 0. Not saved: after a power cycle the saved slot simply is "My own".
 *
 * (test 14: lk_up / lk_down <- COLOR1-4 editor records; test 15: s_look below instead) +12 / +16 (stock Up 0x61223ef7 / Down 0x612241b6: main-dial steps;
 * CALLS, d1 arg, a0 parent; neither reads d0 or a1). On the Looks page (axis 4, P valid, marker, looks loaded): one
 * look forward / back with wrap 0..n, the slot rewritten, dirty, children re-read and the cursor poked (as ed_event),
 * -> d0 1. Anything else: every register as at entry, jmp stock. Locals as ed_event: (4) d1, (8) a1, (12) cursor id,
 * (16) cursor value, (20) P, (24) d0. Stores: the heap block P, own frame. */
.section .ext3,"ax"
s_look:                           /* after WHERE (a2 = P, d2 = 64k + slice, d3 = 3); d0 id, d1 value, a0 inner, a1 mode */
 mov d2,d3                        /* Profile bank: 12 o'clock value 1..5 = bank profile, anything else = 0 (neutral). */
 and 63,d3                        /* Every value is accepted (the dial widget keeps what it asked for). */
 cmp 0,d3
 bne 8f
 mov (LPTR,a2),a3
 cmp 0,a3
 beq 8f
 lsr 6,d2                         /* k */
 add -24,sp                       /* (0) call scratch, (4) id, (8) inner, (12) mode, (16) k, (20) new profile */
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 mov d2,(16,sp)
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0                          /* old value */
 movbu d1,(LIDX,a0)               /* new value: what the wheel and readout show */
 cmp 1,d1
 blt 1f
 cmp 5,d1
 ble 2f
1:
 clr d1
2:
 cmp 1,d0
 blt 1f
 cmp 5,d0
 ble 2f
1:
 clr d0
2:
 mov d1,(20,sp)
 cmp d0,d1
 beq 7f
 mov (16,sp),d2                   /* v0.21: leaving a look keeps it as saved (unsaved edits are dropped) */                   /* load the new one (0: neutral) into the slot and the camera's own settings */
 mov (20,sp),d3
 mov (8,sp),a0
 mov (12,sp),a1
 call fl_sw,[d2,d3,a2,a3],40     /* v0.24: the look being left keeps its changes, then pf_put */
 mov 4,d0
 call gd_set,[d2,a2],8            /* test 17: the name picture of the new profile (redrawn with the dial step) */
7:
 mov (4,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 add 24,sp
 jmp s_dirty2                     /* dirty, then the manager with the id's Saturation value (screen refresh) */
8:
 jmp s_bad

/* pf_cap: `call pf_cap,[d2,d3,a2,a3],28`, a2 = P, d2 = k (0..3), d3 = profile 1..5: the bank record <- COLOR k now
 * (slot hue/light/WB/Blacks/Whites + the camera's own 18 settings via the getter). Locals (0) scratch, (4) offset,
 * (8) k. Stores: the bank record only. */
pf_cap:
 mov d2,d0
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 asl 6,d0
 add 32,d0
 mov (LPTR,a2),a3
 add d0,a3                        /* a3 = record */
pf_capto:                         /* v0.21: the same into a3 (code block xb_lkd: a scratch record) */
 mov d2,(8,sp)
 mov d2,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0                        /* a0 = slot entry */
 mov a3,a1
 mov 24,d1
1:
 movbu (a0),d0
 movbu d0,(a1)
 inc a0
 inc a1
 add -1,d1
 bne 1b
 mov pf_bt,a1                     /* v0.26: the pf_bt pairs (a0 = slot + 24): WB on, A-B, G-M, Blacks, Whites, */
5:                                /* Glow, Art, NR, VigFix, Grain, Sharp, split toning -> record +36..+40, +47..+56 */
 movbu (a1),d1
 movbu (1,a1),d0
 movbu (d0,a0),d0
 movbu d0,(d1,a3)
 add 2,a1
 cmp pf_bt+30,a1
 bne 5b
 movbu (36,a3),d0
 and 1,d0                         /* WB on: bit 0 of the slot's WB flags */
 movbu d0,(36,a3)
 clr d3
2:
 mov pf_ids,a0
 mov d3,d0
 asl2 d0
 add d0,a0
 movbu (3,a0),d0
 mov d0,(4,sp)
 movbu (2,a0),d1
 mov (8,sp),d2
 mul d2,d1
 movhu (a0),d0
 add d1,d0                        /* id for COLOR k */
 call sget,[],4                   /* d0 = value (keeps d2/d3/a2/a3) */
 mov (4,sp),d1
 movbu d0,(d1,a3)
 inc d3
 cmp 18,d3
 bne 2b
 ret [d2,d3,a2,a3],28

/* pf_load: `call pf_load,[d2,d3,a2,a3],28` from sd_load after gd_load, a2 = P. Locals (4) handle, (8) buffer.
 * LOOKS.BIN (PF_LEN B; v0.19, before: PROFILES.BIN, read when there is no LOOKS.BIN) checked -> bank; no file -> a neutral bank (saved on the first half-press save);
 * a file that fails the check -> no bank (the file is left alone). P+LIDX+k = the saved selection. Stores: P+LPTR,
 * P+LIDX, the heap buffer, own frame. */
.section .ext8,"ax"
pf_load:
 clr d0
 mov d0,(TTAB,a2)                 /* v0.24: no film cell pictures until fl_mk publishes them */
 mov d0,(TORG,a2)
 mov d0,(STC,a2)
 mov d0,(SATB,a2)
 mov d0,(LVB,a2)
 mov PF_LEN + FL_SB,d0            /* v0.24: the file, then the film-name strings (fl_str) */
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(8,sp)
 call pf_open,[],4                /* LOOKS.BIN, else PROFILES.BIN (v0.19) */
 cmp 0,a0
 beq 5f                           /* no file: neutral bank */
 mov a0,(4,sp)
 mov (8,sp),a0
 mov 1,d0
 mov PF_LEN,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 cmp PF_LEN,d2
 bne 7f
 mov (8,sp),a0
 mov PF_LEN,d3
 call pf_check,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 7f
 mov (8,sp),a0
 clr d2
1:
 mov a0,a1
 add d2,a1
 movbu (16,a1),d0                 /* saved selection */
 mov a2,a1
 add d2,a1
 movbu d0,(LIDX,a1)
 inc d2
 cmp 4,d2
 bne 1b
 bra 6f
5:
 mov (8,sp),a0
 mov PF_LEN,d1
 clr d0
2:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 2b
 mov (8,sp),a0
 mov PFMAGIC,d0
 mov d0,(a0)
 mov PF_LEN,d0
 mov d0,(4,a0)
 mov 1,d0
 movhu d0,(12,a0)
 mov 20,d0
 movhu d0,(14,a0)
6:
 mov (8,sp),d0
 mov d0,(LPTR,a2)                 /* published last */
 call fl_mk2,[d2,d3,a2,a3],80     /* v0.24: the film list's cell pictures (v0.26: TONES.BIN first) */
 call dm_boot,[d2,d3,a2,a3],20    /* v0.27: the Creative Dial's mapping for the position it is on now */
 bra 9f
7:
 mov (8,sp),a0
 call free,[],4
9:
 ret [d2,d3,a2,a3],28

/* pf_check: `call pf_check,[d2,d3,a2,a3],20`, a0 = buffer, d3 = size -> d0 0 ok / 1 bad. Reads only.
 * PROFILES.BIN v1: 'OM3P' | u32 1632 | crc32(12..) | u16 1 | u16 20 | sel[4] 0..5 | 12 zero | 20 x 64-B records
 * (COLOR k profile v at 5k + v - 1) | 20 x 16-B names. Record: hue[12] +0, light[12] +12, sat[12] +24, +36 wb on,
 * +37 A-B, +38 G-M, +39 Blacks, +40 Whites, +41 Contrast, +42 Sharpness, +43 Shading, +44 Shadows, +45 Midtones,
 * +46 Highlights, +47..63 zero. */
.section .ext4,"ax"
pf_check:
 mov a0,a3
 mov (a3),d0
 cmp PFMAGIC,d0
 bne 9f
 mov (4,a3),d0
 cmp d3,d0
 bne 9f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov d3,d1
 add -12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 9f
 movhu (12,a3),d0
 cmp 1,d0
 bne 9f
 movhu (14,a3),d0
 cmp 20,d0
 bne 9f
 clr d2
2:
 mov a3,a0
 add d2,a0
 movbu (16,a0),d0
 cmp 5,d0
 bhi 9f
 inc d2
 cmp 4,d2
 bne 2b
 mov 1280,d1
 mov a3,a0
 add 32,a0
 mov pf_lo,a1
 clr d2
1:
 movbu (a0),d0
 extb d0
 movbu (a1),d3
 extb d3
 sub d3,d0
 cmp 0,d3
 blt 4f
 clr d3                           /* lo >= 0: span 1 for byte 36, else 0 */
 cmp 36,d2
 bne 5f
 mov 1,d3
 bra 5f
4:
 not d3                           /* lo < 0: span = -2 lo */
 inc d3
 add d3,d3
5:
 cmp d3,d0
 bhi 9f
 inc a0
 inc a1
 inc d2
 cmp 64,d2
 bne 3f
 clr d2
 mov pf_lo,a1
3:
 add -1,d1
 bne 1b
 clr d0
 ret [d2,d3,a2,a3],20
9:
 mov 1,d0
 ret [d2,d3,a2,a3],20


/* ------------------------------------------------------------------ section-9 tail: profile bank (test 16) */
.section .ext9,"ax"
/* pf_put: `call pf_put,[d2,d3,a2,a3],40` from s_look (inside the facade SetValue: a0 inner, a1 mode), a2 = P,
 * d2 = k, d3 = profile 1..5 or 0 (neutral): the slot entry <- the record, then the camera's own 18 settings of
 * COLOR k through the settings manager (as the GUI's own edits). Locals (0) scratch, (4) inner, (8) mode, (12) k,
 * (16) record or 0, (20) i. Stores: the slot entry, the camera's settings (manager), own frame. */
pf_put:
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov d2,(12,sp)
 mov 0,a3
 cmp 0,d3
 beq 1f
 mov d2,d0
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 asl 6,d0
 add 32,d0
 mov (LPTR,a2),a3
 add d0,a3
1:
pf_put1:                          /* v0.24 (fl_sw): (4) a0, (8) a1, (12) k set, a3 = the record to load */
 mov a3,(16,sp)
 mov d2,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0                        /* slot entry */
 mov a3,a1
 mov 24,d1
2:
 clr d0
 cmp 0,a1
 beq 3f
 movbu (a1),d0
 inc a1
3:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 2b
 mov pf_bt,a1                     /* rec +36..40, +47..52 -> slot +25..27, +47, +48, +49..54 (0 for neutral) */
8:
 movbu (a1),d2
 movbu (1,a1),d3
 clr d0
 cmp 0,a3
 beq 7f
 movbu (d2,a3),d0
7:
 movbu d0,(d3,a0)
 add 2,a1
 cmp pf_bt+30,a1
 bne 8b
 movbu (7,a0),d0
 or 2,d0
 movbu d0,(7,a0)                  /* +31 flags: H/L on */
 clr d0
 mov d0,(20,sp)
5:
 mov (20,sp),d3
 mov pf_ids,a0
 mov d3,d0
 asl2 d0
 add d0,a0
 movbu (2,a0),d1
 mov (12,sp),d2
 mul d2,d1
 movhu (a0),d0
 add d1,d0                        /* id */
 movbu (3,a0),d2                  /* record offset */
 mov (16,sp),a1
 cmp 0,a1
 bne 61f
 call pf_dflt,[d2,a3],16          /* lk11: neutral = the camera's factory default of this setting */
 bra 6f
61:
 movbu (d2,a1),d1
 extb d1
6:
 mov (4,sp),a0
 mov (8,sp),a1
 call manager,[d2,d3,a2,a3],68
 mov (20,sp),d3
 inc d3
 mov d3,(20,sp)
 cmp 18,d3
 bne 5b
 ret [d2,d3,a2,a3],40

.section .ext1,"ax"
/* lk_hold (v0.21) <- ed_event on the Looks page (axis 4), in its frame (a2 = P, a3 = parent, d2 = 4, (12,sp) cursor
 * id, (24,sp) event): code block +88 (xb_lkh) does it: OK held on the wheel with a look selected saves COLOR k into the
 * look (pf_cap, dirty, refresh: e_lk), no look: nothing (e_ret), OK held on "COLOR n" (0xf881): the reset (e_rst).
 * Without the code block: the reset. */
/* pf_dflt (lk11): `call pf_dflt,[d2,a3],16` from pf_put, d0 = setting id -> d1 = its factory default (the stock
 * GetDefault, facade +156, as the stock "is at default" check reads it on Saturation), d0 kept. */
pf_dflt:
 mov d0,d2
 clr d1
 mov d1,(4,sp)
 call facade,[],4                 /* a0 = the facade; its GetDefault without our page hook (ed_default reads 0 on */
 mov stock_default,a3             /* the Hue/Light/Looks pages) */
 mov sp,a1
 inc4 a1
 mov d2,d0
 calls (a3)
 mov (4,sp),d1
 mov d2,d0
 ret [d2,a3],16

lk_hold:
 call xp,[],0
 beq 7f
 add 88,a1
 jmp (a1)
7:
 jmp e_rst


.section .ext9,"ax"
/* pf_save: `call pf_save,[d2,d3,a2,a3],24` from ed_trig after ed_save, a2 = P: selection bytes, CRC, then
 * LOOKS.NEW and LOOKS.BIN (v0.19; PROFILES.* before), each read back. Locals (0) scratch, (4) read-back buffer. */
pf_save:
 mov (LPTR,a2),a3
 cmp 0,a3
 beq 9f
 clr d2
1:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp 1,d0
 blt 2f
 cmp 5,d0
 ble 3f
2:
 clr d0
3:
 mov a3,a0
 add d2,a0
 movbu d0,(16,a0)
 inc d2
 cmp 4,d2
 bne 1b
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov PF_LEN-12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(8,a3)
 mov PF_LEN,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a0,d2
 mov pf_pnew,a0
 call pf_w,[d2,d3,a2,a3],28
 cmp 0,d0
 bne 8f
 mov (4,sp),d2
 mov pf_pbin,a0
 call pf_w,[d2,d3,a2,a3],28
8:
 mov (4,sp),a0
 call free,[],4
9:
 mov (XPTR,a2),a1                 /* v0.21: code block +72 after each half-press save (HLS_EVENT task) */
 cmp 0,a1
 beq 7f
 add 72,a1
 calls (a1)
7:
 ret [d2,d3,a2,a3],24

.section .ext6,"ax"
/* pf_w: `call pf_w,[d2,d3,a2,a3],28`, a0 path, a3 bank (PF_LEN B), d2 read-back buffer -> d0 0 ok / 1 fail.
 * Locals (4) handle, (8) path. */
pf_w:
 mov a0,(8,sp)
 mov ed_m_w,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a0,a1
 mov PF_LEN,d1
 mov 1,d0
 mov a3,a0
 call fwrite,[d2,d3,a2,a3],24
 mov d0,d3
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 cmp PF_LEN,d3
 bne 9f
 mov (8,sp),a0
 mov sd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a0,a1
 mov d2,a0
 mov 1,d0
 mov PF_LEN,d1
 call fread,[d2,d3,a2,a3],24
 mov d0,d3
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 cmp PF_LEN,d3
 bne 9f
 mov a3,a0
 mov d2,a1
 mov PF_LEN,d3
5:
 movbu (a0),d0
 movbu (a1),d1
 cmp d0,d1
 bne 9f
 inc a0
 inc a1
 add -1,d3
 bne 5b
 clr d0
 ret [d2,d3,a2,a3],28
9:
 mov 1,d0
 ret [d2,d3,a2,a3],28

 .section .ext5,"ax"
 .balign 2
pf_ids:                           /* u16 id for COLOR1, u8 step per COLOR, u8 record offset */
 .irp s,0,1,2,3,4,5,6,7,8,9,10,11
 .hword 928+\s
 .byte 12, 24+\s
 .endr
 .hword 908
 .byte 1, 41                      /* Contrast */
 .hword 904
 .byte 1, 42                      /* Sharpness */
 .hword 912
 .byte 1, 43                      /* Shading */
 .hword 978
 .byte 3, 44                      /* Shadows */
 .hword 977
 .byte 3, 45                      /* Midtones */
 .hword 976
 .byte 3, 46                      /* Highlights */
.section .ext3,"ax"
pf_bt:                            /* record offset, slot offset - 24 (v0.26: moved here from the sec-9 tail) */
 .byte 36,1, 37,2, 38,3, 39,23, 40,24, 47,25, 48,26, 49,27, 50,28, 51,29, 52,30
 .byte 53,31, 54,32, 55,33, 56,34  /* v0.26: split toning, record +53..+56 <-> slot +55..+58 */
pf_lo:                            /* record byte i: lo; span = -2 lo for lo < 0, 1 for byte 36 (WB on 0/1), else 0
                                     (test 18: the span half of this table is computed, to make room) */
 .byte -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5, -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5, -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5
 .byte 0, -7,-7,-5,-5, -2,-2,-5, -7,-7,-7, -5,-5,-5, -1, -5, -5, -12,-5,-12,-5, 0,0,0,0,0,0,0   /* v0.26 +53..+56 split toning; v0.26.1 +37 / +38 WB -7..7 */
pf_pnew:
 .asciz "C:\\OM3MOD\\LOOKS.NEW"
pf_pbin:
 .asciz "C:\\OM3MOD\\LOOKS.BIN"

/* ------------------------------------------------------------------ Profiles page dial range 0..5 (test 16b)
 * The dial's value list is built from the facade's count (+28) and value-by-index (+32) every time the editor's
 * children are refreshed (editor open, each INFO page change). On the Profiles page the 12 o'clock id gets 6 values,
 * 0..5, so the dial stops at 0 and 5. Everything else: stock, registers as at entry. CALLS entries. */
.section .ext1,"ax"
/* ------------------------------------------------------------------ profile names (test 17)
 * NAMES.BIN v1 (written by the Look Lab with PROFILES.BIN): 'OM3N' | u32 total | u32 crc32(bytes 12..) | u16 1 |
 * u16 20 | u16 175 | u16 50 | 12 zero | 4 groups {u32 offset, u32 length} at 32 (group k = COLOR k's pictures,
 * contiguous from 144, each <= 16384 B) | 20 entries {u16 offset in its group, u16 length} at 64 (COLOR k profile v
 * at 5k + v - 1; length 0 = none) | group data. A picture = an OSD type-11 stream 175 x 50 (header GHDR).
 * P+NENT = the 20 entries, P+NPTR+4k = group k's heap copy (0 = none). */
.section .ext11,"ax"
/* nm_load: `call nm_load,[d2,d3,a2,a3],36` from sd_load (HLS task), a2 = P. Locals (4) handle, (8) CRC, (12) k,
 * (16) next offset. The 64-byte header is read into P+TBUF (the title buffers, not yet in use). Stores: P+NENT,
 * P+NPTR, heap buffers, own frame. */
nm_load:
 clr d0
 mov d0,(NPTR,a2)
 mov d0,(NPTR+4,a2)
 mov d0,(NPTR+8,a2)
 mov d0,(NPTR+12,a2)
 mov nm_path,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a2,a0
 add TBUF,a0
 mov 1,d0
 mov 64,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp 64,d0
 bne 7f
 mov (TBUF,a2),d0
 cmp NMAGIC,d0
 bne 7f
 mov (TBUF+12,a2),d0              /* u16 1 | u16 20 */
 cmp 0x00140001,d0
 bne 7f
 mov (TBUF+16,a2),d0              /* u16 175 | u16 50 */
 cmp 0x003200af,d0
 bne 7f
 mov a2,a0
 add NENT,a0
 mov 1,d0
 mov 80,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp 80,d0
 bne 7f
 mov -1,d0
 mov a2,a0
 add TBUF+12,a0
 mov 52,d1
 call sd_crc,[d2,d3],12
 mov a2,a0
 add NENT,a0
 mov 80,d1
 call sd_crc,[d2,d3],12
 mov d0,(8,sp)
 mov 144,d0
 mov d0,(16,sp)
 clr d3
1:
 mov d3,(12,sp)
 mov a2,a0
 asl2 d3
 asl d3
 add d3,a0                        /* a0 = P + 8k */
 mov (TBUF+32,a0),d0
 mov (16,sp),d1
 cmp d1,d0
 bne 7f                           /* groups must follow each other */
 mov (TBUF+36,a0),d2              /* length */
 cmp 0,d2
 beq 3f
 cmp 16385,d2
 bcc 7f
 mov d2,d0
 call malloc,[],4
 cmp 0,a0
 beq 7f
 mov (12,sp),d3
 mov a2,a1
 asl2 d3
 add d3,a1
 mov a0,(NPTR,a1)                 /* kept at once, so the failure path frees it */
 mov 1,d0
 mov d2,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp d2,d0
 bne 7f
 mov (12,sp),d3
 mov a2,a1
 asl2 d3
 add d3,a1
 mov (NPTR,a1),a0
 mov (8,sp),d0
 mov d2,d1
 call sd_crc,[d2,d3],12
 mov d0,(8,sp)
 mov (16,sp),d0
 add d2,d0
 mov d0,(16,sp)
3:
 mov (12,sp),d3
 inc d3
 cmp 4,d3
 bne 1b
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 mov (TBUF+4,a2),d0
 mov (16,sp),d1
 cmp d1,d0
 bne 8f
 mov (8,sp),d0
 not d0
 mov (TBUF+8,a2),d1
 cmp d1,d0
 bne 8f
 clr d3                           /* entries: in their group, 4-aligned, and a 175 x 50 picture */
5:
 mov a2,a1
 mov d3,d0
 asl2 d0
 add d0,a1                        /* a1 = P + 4i */
 movhu (NENT+2,a1),d2
 cmp 0,d2
 beq 6f
 movhu (NENT,a1),d1
 mov d3,d0                        /* k = i / 5 */
 mov 0,a0
4:
 cmp 5,d0
 bcs 2f
 add -5,d0
 inc a0
 bra 4b
2:
 mov a0,d0
 mov a2,a0
 asl2 d0
 add d0,a0                        /* a0 = P + 4k */
 asl d0                           /* 8k */
 mov a2,a3
 add d0,a3
 mov (TBUF+36,a3),d0              /* group length */
 btst 3,d1
 bne 4f
 add d1,d2
 cmp d0,d2
 bhi 4f
 mov (NPTR,a0),a0
 cmp 0,a0
 beq 4f
 add d1,a0
 mov (a0),d0
 cmp GHDR,d0
 beq 6f
4:
 clr d0
 movhu d0,(NENT+2,a1)             /* not usable: none */
6:
 inc d3
 cmp 20,d3
 bne 5b
 bra 9f
7:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
8:
 clr d3                           /* free whatever was kept */
1:
 mov a2,a1
 mov d3,d0
 asl2 d0
 add d0,a1
 mov (NPTR,a1),a0
 cmp 0,a0
 beq 2f
 clr d0
 mov d0,(NPTR,a1)
 call free,[],4
2:
 inc d3
 cmp 4,d3
 bne 1b
9:
 ret [d2,d3,a2,a3],36

/* nm_pick: `add -4,sp; call nm_pick,[],0; add 4,sp` from gd_set, a2 = P, a0 = GDESC: the name picture of the open
 * editor's COLOR (EDK) and its profile (LIDX) -> descriptor (12) size, (16) payload, d0 0; else d0 1, descriptor
 * untouched. Keeps a0, a2, a3, d3; uses d1, d2, a1. Returns through MDR. */
nm_pick:
 movm [d3],(sp)
 movbu (EDK,a2),d3
 cmp 4,d3
 bcc 9f
 mov a2,a1
 add d3,a1
 movbu (LIDX,a1),d2
 extb d2
 cmp 1,d2
 blt 9f
 cmp 5,d2
 bgt 9f
 mov d3,d1                        /* 4 * (5k + v - 1) */
 asl2 d1
 add d3,d1
 add d2,d1
 add -1,d1
 asl2 d1
 mov a2,a1
 add d1,a1
 movhu (NENT+2,a1),d2             /* length */
 cmp 0,d2
 beq 9f
 movhu (NENT,a1),d1               /* offset */
 asl2 d3
 mov a2,a1
 add d3,a1
 mov (NPTR,a1),d3
 cmp 0,d3
 beq 9f
 add d3,d1
 mov d2,(12,a0)
 mov d1,(16,a0)
 clr d0
 movm (sp),[d3]
 retf [],0
9:
 mov 1,d0
 movm (sp),[d3]
 retf [],0

.section .ext8,"ax"
/* nm_own: `add -4,sp; call nm_own,[],0; add 4,sp` from gd_set, a2 = P, d1 = the descriptor's payload: inside one of
 * our name buffers -> d1 = GSTOCK_P (so gd_set may switch it). Keeps d0, a0, a1, d3; uses d2. */
nm_own:
 movm [d3],(sp)
 clr d3
1:
 mov a2,a1                        /* a1 is reloaded by gd_set after this call */
 add d3,a1
 mov (NPTR,a1),d2
 cmp 0,d2
 beq 2f
 sub d1,d2                        /* d2 = buffer - payload ... */
 not d2
 inc d2                           /* ... negated: payload - buffer */
 cmp 16384,d2
 bcs 8f
2:
 add 4,d3
 cmp 16,d3
 bne 1b
 movm (sp),[d3]
 retf [],0
8:
 mov GSTOCK_P,d1
 movm (sp),[d3]
 retf [],0

.section .ext9,"ax"
gd_path:                          /* test 17: moved here from the section-10 tail (room for the name pictures) */
 .asciz "C:\\OM3MOD\\GUIDES.BIN"

.section .ext11,"ax"
nm_path:                          /* v0.21: moved from the section-9 tail (room for the pf_save block call) */
 .asciz "C:\\OM3MOD\\NAMES.BIN"

.section .ext3,"ax"
/* ei_page: `call ei_page,[],4` from ed_init (test 18), d0 = editor key 0x1540 + k, a2 = P: EDK = k, first-use
 * marker, page = Profiles (4) with a bank, else Saturation (0), and that page's guide picture. Uses d0..d3, a0, a1
 * (ed_init saved them). Stores: P+EDK, P+EMARK/DIRTY/STATUS (first use), P+AXIS, the guide descriptor (gd_set). */
ei_page:
 mov d0,d3
 exthu d3
 add -0x1540,d3
 cmp 4,d3
 bcc 9f                           /* not a COLOR editor key: leave it all */
 movbu d3,(EDK,a2)
 mov (EMARK,a2),d3
 cmp EMAGIC,d3
 beq 2f
 clr d3
 movbu d3,(STATUS,a2)             /* v0.25: DIRTY kept (as above) */
 mov EMAGIC,d3
 mov d3,(EMARK,a2)
2:
 mov (LPTR,a2),d3
 cmp 0,d3
 beq 3f
 .if W_FILM                       /* film test 7: the wheel opens on Saturation (the films are in the Picture Mode list) */
 mov 4,d3
 .else
 clr d3
 .endif
3:
 movbu d3,(AXIS,a2)
 mov d3,d0
 call ei_open,[d2,a2],8           /* film test 10: P+EOPEN = 1, then gd_set */
9:
 ret [],4

/* pf_open (v0.19): `call pf_open,[],4` -> a0 = fopen(LOOKS.BIN), or when there is none fopen(PROFILES.BIN), the
 * name before v0.19 (read once; the next save writes LOOKS.BIN), or 0. Uses d0, d1, a0, a1 (as fopen).
 * v0.20: moved to the section-7 tail (runs only from the gated half-press load). */
.section .ext7,"ax"
pf_open:                          /* v0.20: LOOKS.BIN only (a v0.17/v0.18 PROFILES.BIN: rename it, same format) */
 mov pf_pbin,a0
 mov gd_mode,a1
 call fopen,[],4
 ret [],4

/* vl_s: `call vl_s,[d2,d3,a2,a3],20` from ed_get's readout path, d2 = slice, a2 = P; keeps d0..d1? no: keeps a0, a1
 * (and the frame's d2, d3, a2, a3). Code block +48 does the work; without one, nothing. */
vl_s:
 mov a0,a3
 mov a1,d3
 call xp,[],0
 cmp 0,a1
 beq 9f
 add 48,a1
 jmp (a1)
9:
 mov a3,a0
 mov d3,a1
 ret [d2,d3,a2,a3],20

/* ------------------------------------------------------------------ v0.20 Extras (test 3)
 * Extras page (axis 5, INFO after WB/BW): 12 o'clock Glow/Clarity -5..5 at slot +49 (- = Glow; + = Clarity, not yet
 * rendered), 6 o'clock Frame at slot +50 (> 0 = on). Look records +47/+48. A COLOR still (no stock Art Effect)
 * gets job flag 0x80 (the stock Soft Focus passes at the stock weight 600) for Glow and 0x8000 (the Frame passes)
 * for Frame, in the Art Effect -> flag converter 0x60555e47 (test 2 showed both render on COLOR stills).
 * Stores: the slot bytes (editor), the job flag word in the converter's params block (as stock), own stack. */
.section .ext9,"ax"
xt_tab:                           /* Extras slices 1..10 clockwise from 12 o'clock: slot byte, min, max (0 = no cell).
                                   * v0.23 test 15: only Glow/Clarity (12 o'clock) and Art Effect (6 o'clock) stay on the
                                   * wheel; NR, A-B, G-M, Blacks, Whites, VigFix, Grain and Sharp are Picture Mode rows */
 .byte 49,-5,5                    /* 1 (12 o'clock) Glow (-) / Clarity (+) */
 .byte 0,0,0                      /* 2 */
 .byte 0,0,0                      /* 3 */
 .byte 0,0,0                      /* 4 */
 .byte 0,0,0                      /* 5 */
 .byte 0,0,0                      /* 6 */
 .byte 50,0,5                     /* 7 (6 o'clock) Art Effect: 0 Off, 1 Star Light, 2 Pin Hole, 3 -, 4 White Edge, 5 Frame */
 .byte 0,0,0                      /* 8 */
 .byte 0,0,0                      /* 9 */
 .byte 0,0,0                      /* 10 */

/* ------------------------------------------------------------------ v0.20 test 5: code block from the card
 * The Extras effects run from a code block at the end of GUIDES.BIN (built with this firmware; tag XTAG), loaded
 * with the guide pictures at the half-press load, relocated in its heap buffer by its own entry 0, and published at
 * P+XPTR (0 = none). Every hook below goes stock when there is no block. Stubs that run inside section-2 code live in
 * the section-2 tail (always loaded there). Block entries: +0 relocate, +8 capture flags, +16 live-view flags,
 * +24 Soft Focus weight, +32 stills NR read. Stores here: P+XPTR (x_load, gd_load) only. */
.section .hook_fx,"ax"
 jmp s_cap                        /* stock 0x60555e50: movbu (a1),d0; cmp 0,d0; blt 0x60555ebc */
 nop

/* 0x6046b8bb..0x6046b8d7 (record -> development request, Art Effect gate): the same checks in fewer bytes, plus
 * COLOR (picture mode 11) -> s_lv. Stock: (8,sp) = d2 here (record+234 == 1), record+644 = (396,a3). */
.section .hook_lv,"ax"
 cmp 1,d2
 beq lv_x                         /* 0x6046b8ee: bra 0x6046b94f (no Art Effect) */
 movbu (396,a3),d0
 cmp 1,d0
 beq lv_x
 movbu (a0),d0                    /* picture mode (record+250) */
 cmp 11,d0
 bne 1f
 jmp s_lv
1:
 cmp 100,d0
 blt lv_x
 nop
 nop                              /* -> 0x6046b8d8: movbu (4,a3),d0 (the Art Effect switch) */

.section .hook_wt,"ax"
 jmp s_wt                         /* stock 0x605048c1: mov (48,a0),a1; mov 600,d0 */
 nop

.section .hook_nr1,"ax"
 call s_nr,[d2,d3],12             /* stock 0x603c8038: call getter (0x9719 stills Noise Filter) */
.section .hook_cl,"ax"
 call s_cl,[d2,a2],12

.section .hook_nr2,"ax"
 call s_nr,[d2,d3],12             /* stock 0x603e7891 (capture +37674) */

.section .hook_sh,"ax"
 call s_nr,[d2,d3],12             /* v0.22 stock 0x603e767f: call getter (0x8119 Sharpness, capture +37648) */

.section .ext2,"ax"
/* xp: `call xp,[],0` -> a1 = the code block (relocated) or 0. Uses d0; returns through MDR. */
xp:                               /* also Z = (a1 == 0) for the ext2 stubs (v0.21) */
 movhu (STATE),d0
 add -1,d0
 mov 0,a1
 btst 3,d0
 bne 1f
 mov d0,a1
 add POOL,a1
 mov (XPTR,a1),a1
1:
 cmp 0,a1
 retf [],0

s_lv:                             /* d0 = 11, a2 = request, a3 = record+248; d3 live */
 call xp,[],0
 beq 9f
 add 16,a1
 jmp (a1)
9:
 jmp lv_skip                      /* 0x6046b94f */

s_nr:                             /* the site's `call ...,[d2,d3],12` frame; d0 key, d1, a0 as for the getter */
 mov d0,d3
 call xp,[],0
 mov d3,d0                        /* (mov keeps Z) */
 beq 9f
 add 32,a1
 jmp (a1)
9:
 jmp getter

s_cl:                             /* v0.21 grain: request configuration 0x604955f1 `call s_cl,[d2,a2],12`, a0 = context.
                                     Code block +64 marks a plain COLOR still for the camera's grain, then the selector */
 call xp,[],0
 beq 9f
 add 64,a1
 jmp (a1)
9:
 jmp SEL                          /* 0x6052cf39, in the same frame as the stock call */

.section .ext5,"ax"
s_wt:                             /* leaf: MDR = return, a0 = combiner context; keep a0 for the stock getter */
 mov (48,a0),a1
 cmp 11,a1                        /* job key 11: COLOR */
 bne 9f
 mov mdr,d1
 call xp,[],0
 mov d1,mdr
 cmp 0,a1
 beq 9f
 add 24,a1
 jmp (a1)
9:
 mov (48,a0),a1
 mov 600,d0
 jmp wt_back                      /* 0x605048c7: cmp 0x01010065,a1 */

.section .ext3,"ax"
g_sf:                             /* grain: the Soft Focus blend setup (work-list word 0x604b9288), `calls` */
 add -4,sp
 call xp,[],0
 add 4,sp
 cmp 0,a1
 beq 9f
 add 56,a1
 jmp (a1)
9:
 jmp sf_stock                     /* film test 9: a linker symbol (a bare number assembled as a relative jump) */

.section .ext8,"ax"
s_cap:                            /* a3 = capture, a2 = params+12 (flags), (-4,a2) = key */
 call xp,[],0
 cmp 0,a1
 beq 9f
 add 8,a1
 jmp (a1)
9:
 mov 38225,a1                     /* as stock 0x60555e4b */
 add a3,a1
 movbu (a1),d0
 jmp fx_back

.section .ext6,"ax"
/* x_load: `call x_load,[d2,d3],12` from gd_load after the pictures are published, a2 = P. Block at the end of the
 * file: ... code, relocations, {tag, end - code, code length, count}. */
x_load:
 mov (GPTR,a2),a0
 mov (4,a0),d0
 add d0,a0                        /* end */
 mov (-16,a0),d0
x_tagref:
 cmp XTAG,d0
 bne 9f
 mov (-12,a0),d0
 sub d0,a0                        /* code */
 calls (a0)                       /* relocate in place -> d0 = code */
 mov d0,(XPTR,a2)
9:
 ret [d2,d3],12

/* ------------------------------------------------------------------ section-6 extension (sliders, v0.23 test)
 * 0x60f49800..0x60f59800: build.py raises section 6's load end (word 0x60045e9c) by 64 KiB so the camera copies
 * this space into RAM at start-up (camera-proven by the GX2 probe, 2026-11-07). Never use the gaps between sections. */
.section .ext11,"ax"

/* pm_color <- the Picture Mode column builder 0x611bd814, its switch on the picture mode (table 0x61533520: the
 * COLOR 1-4 entries, stock 0x611bd8fd `mov 0x61530758,a3` and the shared `mov 6,d0`): our list, our count. */
pm_color:
 mov pm_list,a3
 mov PM_N,d0
 jmp pm_back                      /* 0x611bd90f: stores the count, copies the list */
.balign 4
pm_list:                          /* item ids, in the order the owner reads them (v0.23 test 15): the look (Picture Mode,
                                   * the colour wheel), tone (Contrast, Highlight & Shadow, Blacks, Whites), white balance
                                   * (A-B, G-M), detail (Sharpness, Noise Filter = NR), lens (Vignette Correction =
                                   * VigFix, Shading), finish (Film Grain Effect = Grain) */
 .long 111, 5397, 8, 5398, BK_IT, WH_IT, AB_IT, 7, NR_IT, VF_IT, 5399, GL_IT, 5400   /* v0.25: Shading back,
                                    Glow / Clarity and Frame rows; AB_IT = the WB grid (no G-M row) */
.set PM_N, (. - pm_list) / 4

/* Picture Mode rows of COLOR 1-4 that are Extras settings of the selected look (slot k = P + 32 + 64k):
 *   class 1 Sharp:  the stock Sharpness slider (item 7), slot +54, -5..+2; its bar is setting 904 + k (stock)
 *   class 2 Grain:  the camera's Film Grain Effect row (item 5400, MONO 1-4's), slot +53, 0..3 (Off/Low/Med/High)
 *   class 3 NR:     new choice row NR_IT "Noise Filter", slot +51 (0 Camera, 1 Std, 2 Low, 3 Off, 4 High) as the
 *                   camera's Noise Filter values -2 Off, -1 Low, 0 Standard, +1 High; Camera shows the camera's own
 *   class 4 VigFix: new choice row VF_IT "Vignette Correction", slot +52 (0 Camera, 1 Off) as 0 Off, 1 On (= Camera)
 *   class 5 Blacks, class 6 Whites: new slider rows BK_IT / WH_IT, slot +47 / +48, -5..+5 (bar like Shading's; the
 *                   left column our icons "Blk" / "Wht" (IC_BK / IC_WH) and the camera's own value, as the stock slider rows)
 * Ids: our setting ids GRB/NRB/VFB + k for the rows' bars (only our facade handlers take them), and the rows' own
 * left-column ids 7, 998 (Film Grain's), NR_IT, VF_IT, answered by picture mode (54/55/56/64 = COLOR 1-4).
 * The new rows are choice rows like Film Grain Effect: item table entries (it_tab, 23 entries, build.py copies the
 * stock 17) with their option lists, and entries in the column's 9 row switches (build.py: as item 5400's, except
 * where its case asks the Film Grain id: our stubs ch_* below). */
.set GRB, 0x7e00
.set NRB, 0x7e10
.set VFB, 0x7e20
.set BKB, 0x7e30
.set WHB, 0x7e40
.set ABB, 0x7e50                  /* A-B / G-M slider rows (v0.23 test 14): bar ids + k, classes 7 / 8, slot +26 / +27 */
.set GMB, 0x7e60
.set GLB, 0x7ea0                  /* v0.25 Glow / Clarity slider row (class 9, slot +49, -5 Glow .. +5 Clarity) */
.set WGB, 0x7ec0                  /* v0.25 WB grid row: its one option's id + k (class 11, value 0; the left cell draws
                                   * the values, wb_draw) */
.set FRB, 0x7eb0                  /* v0.25 Frame choice row (class 10, slot +50: 0 Off / 5 Frame) */
.set NR_IT, 5394
.set VF_IT, 5389
.set BK_IT, 5386
.set WH_IT, 5385
.set AB_IT, 5384
.set GM_IT, 5383
.set GL_IT, 5382
.set FR_IT, 5381
.set ST_VIG, 0x7f00               /* our string ids (st_get answers them; the camera's table has ~6000) */
.set ST_STD, 0x7f01
.set ST_BKS, 0x7f02                 /* "Blacks" */
.set ST_WHS, 0x7f03                 /* "Whites" */
.set ST_AB, 0x7f04                  /* "A-B" */
.set ST_GM, 0x7f05                  /* "G-M" */
.set ST_GLC, 0x7f06                 /* "Glow / Clarity" */
.set ST_FRM, 0x7f07                 /* "Frame" */
.set IC_BK, 0x7f80                /* our picture ids (ic_get answers them; the camera's table has ~20000 slots) */
.set IC_WH, 0x7f81
.set IC_AB, 0x7f82
.set IC_GM, 0x7f83
.set IC_V0, 0x7f84                /* "Vignette / Off", "Vignette / On" (left column, 100 x 76) */
.set IC_V1, 0x7f85
.set IC_N0, 0x7f86                /* "Noise / Off", "/ Low", "/ Std", "/ High" */
.set IC_N1, 0x7f87
.set IC_N2, 0x7f88
.set IC_N3, 0x7f89
.set IC_HSL, 0x7f8a               /* "HSL": the Color row's cell (film test 7, in place of the stock "Color / Vivid") */
.set IC_GL, 0x7f8b                /* v0.25 "Glow" slider icon, "Frame / Off", "Frame / On" (left column) */
.set IC_F0, 0x7f8c
.set IC_F1, 0x7f8d
.set IC_END, 0x7f8e
.set IC_WB, 0x7f8f                 /* v0.25 the WB grid row's left cell (wb_desc, drawn at run time) */
.set FV0, 100                     /* v0.24 film list: picture-mode values FV0 + j for film j (COLOR k = j / 5, look j % 5 + 1) */
.set NF, 20
.set FLB, 0x7e70                  /* FLB + j: "is film j there?" (the list's per-entry availability id) */
.set ST_F0, 0x7f10                /* ST_F0 + j: film j's name (the big title) */
.set IC_FM0, 0x7f90               /* IC_FM0 + j: film j's list cell picture "FILM" over its number (fl_mk draws them;
                                   * "FILM*" when film j is changed from how it was built) */
.set IC_FL0, 0x7fb0               /* IC_FL0 + j: the same for the row's left cell, never starred (the row adds its own) */
.set FL_BLK, 14336                /* fl_mk heap blocks (up to 3) */
.set ROW, 80                      /* fl_rc's row buffer (100 B) in its frame */
.set SROW, 64                     /* fl_sp's row buffer (160 B) in its frame */
.set SP_SLOT, 2600                /* fl_scp: one quick-menu picture */
.set TWO, 16 + 4 * 24 + 16 + 4 * SP_SLOT   /* the EDITS.BIN image in the P+TORG block */
.set TW_LEN, 16 + 24 * 68         /* EDITS.BIN: 'OM3T' | total | crc | valid mask | 24 x {record 64, check 4} */
.set TWMAGIC, 0x54334d4f
.set SP_BLK, TWO + TW_LEN + 4
.set STC, 824                     /* P+STC: the cell cache block (fl_cget) */
.set SATB, 828                    /* P+SATB: the Saturation page's pictures (fl_mk copies them, gd_sel shows them) */
.set LVB, 832                     /* P+LVB: the shooting screen's "FILM N" block (fl_lvp, film test 9) */
.set LV_SLOT, 2800                /* one picture there (build.py checks the largest) */
.set LV_BLK, 128 + 4 * LV_SLOT
.set SAT_SG, 8 + ((SLS + 3) & ~3)  /* the block: (0) SLS, (4) SGS, (8) the Saturation label, then the guide, the Hue */
.set SAT_HL, SAT_SG + ((SGS + 3) & ~3)  /* label, the Luminance label, each 4-aligned (as fl_slab.. in films.inc) */
.set SAT_LL, SAT_HL + ((HLS + 3) & ~3)
.set SAT_LEN, SAT_LL + LLS
.set EOPEN, 689                   /* P+EOPEN: 1 from the wheel's init to its first INFO (film test 10) */
.set LDESC, 0xa4cf61f8            /* the wheel's "Color" dial label, 70 x 30 */
.set LSTOCK_P, 0xa4cf5c70
.set LSTOCK_S, 1415
.set SDESC, 0xa49edf88            /* the "Color Select [INFO]" guide (shown with all colours), 180 x 50 */
.set SSTOCK_P, 0xa49ece10
.set SSTOCK_S, 4471
.set CC_SLOT, 2000
.set CC_BLK, 264 + 8 * CC_SLOT     /* + 2 flag bytes: EDITS.BIN to save, skip one capture (film reset) */
.set ST_N0, 0x7f30                /* ST_N0 + j: film j's cell label "FILM" over its number in the list (1, 2, ...) */
.set FL_SB, NF * 68               /* strings after the LOOKS.BIN copy: 20 names, then 20 cell labels (UTF-16, 17 shorts) */
.set VF_I0, 358                   /* the camera's "Off" icon (owner-approved 2026-11-07) */
.set VF_I1, 480                   /* the camera's "On" icon */

.balign 4
gr_tab:                           /* Film Grain Effect: picture mode -> setting id (stock MONO four first) */
 .long 57, 999, 58, 1000, 59, 1001, 65, 1002
 .long 54, GRB, 55, GRB + 1, 56, GRB + 2, 64, GRB + 3
nr_tab:
 .long 54, NRB, 55, NRB + 1, 56, NRB + 2, 64, NRB + 3
vf_tab:
 .long 54, VFB, 55, VFB + 1, 56, VFB + 2, 64, VFB + 3
bk_tab:
 .long 54, BKB, 55, BKB + 1, 56, BKB + 2, 64, BKB + 3
wh_tab:
 .long 54, WHB, 55, WHB + 1, 56, WHB + 2, 64, WHB + 3
ab_tab:
 .long 54, ABB, 55, ABB + 1, 56, ABB + 2, 64, ABB + 3
gm_tab:
 .long 54, GMB, 55, GMB + 1, 56, GMB + 2, 64, GMB + 3
wg_tab:
 .long 54, WGB, 55, WGB + 1, 56, WGB + 2, 64, WGB + 3
gl_tab:
 .long 54, GLB, 55, GLB + 1, 56, GLB + 2, 64, GLB + 3
fr_tab:
 .long 54, FRB, 55, FRB + 1, 56, FRB + 2, 64, FRB + 3
.balign 8
sw11_tab:                         /* the row switches 0x615511cc and 0x6155134c (16 entries, full with our rows) */
 .space 32 * 8                    /* re-hashed by build.py into 32 entries */
sw13_tab:
 .space 32 * 8
it_tab:                           /* the stock 17 item entries (filled by build.py), then ours (40 B each) */
 .space 17 * 40
 .long NR_IT, nr_title, nr_l0, 4, 0, nr_l1, 4, 0, nr_l2, 4    /* title, labels, two icon lists (as 5400's) */
 .long VF_IT, vf_title, vf_l0, 2, 0, vf_l1, 2, 0, vf_l2, 2
 .long BK_IT, 0, 0, 0, bk_title, 0, 5 << 16, 0, 0, 0           /* slider entries (as item 7's: +16 title, +26 the */
 .long WH_IT, 0, 0, 0, wh_title, 0, 6 << 16, 0, 0, 0           /* left icon: 5 / 6 = IC_BK / IC_WH in ic_list) */
 .long AB_IT, ab_title, wb_l0, 1, 0, wb_l1, 1, 0, wb_l2, 1      /* v0.25 WB grid row: one option (as test 12) */
 .long GM_IT, 0, 0, 0, gm_title, 0, 8 << 16, 0, 0, 0
 .long GL_IT, 0, 0, 0, gl_title, 0, 9 << 16, 0, 0, 0           /* v0.25: icon 9 = IC_GL */
 .long FR_IT, fr_title, fr_l0, 2, 0, fr_l1, 2, 0, fr_l2, 2      /* v0.25: as Vignette Correction */
bk_title:
 .short 4, ST_BKS
 .long 0x6154b480
wh_title:
 .short 4, ST_WHS
 .long 0x6154b480
ab_title:
 .short 4, ST_AB
 .long 0x6154b480
gm_title:
 .short 4, ST_GM
 .long 0x6154b480
gl_title:
 .short 4, ST_GLC
 .long 0x6154b480
fr_title:
 .short 4, ST_FRM
 .long 0x6154b480
nr_title:
 .short 4, 188                    /* string 188 "Noise Filter" */
 .long 0x6154b480
vf_title:
 .short 4, ST_VIG                 /* our string "Vignette Correction" (st_get); the camera's own would be 254 "Shading
 .long 0x6154b480                 * Comp.", too close to Shading (owner, 2026-11-07) */
/* option lists {value, type, id, 0x6154b480}: type 4 = string, 3 = icon. Noise Filter shows words (camera test 6:
 * the reversed grain icons carry the grain's words, so Off read "High"; the camera has no Low / Std / High word
 * icons, and type 4 entries draw the word in its font). Vignette Correction: the camera's Off / On icons (358 / 480). */
 .macro OPT v, t, id
 .long \v
 .short \t, \id
 .long 0x6154b480
 .endm
nr_l0:
 OPT -2, 4, 1845                  /* "Noise Filter Off" */
 OPT -1, 4, 1848                  /* "Noise Filter: Low" */
 OPT 0, 4, 1846                   /* "Noise Filter: Standard" */
 OPT 1, 4, 1847                   /* "Noise Filter: High" */
nr_l1:                            /* the left column (emulator test 15: l1 is the column, l2 the strip under the title):
                                   * our two-line pictures "Noise" over the value (owner: "Off" alone was unclear) */
 OPT -2, 3, IC_N0
 OPT -1, 3, IC_N1
 OPT 0, 3, IC_N2
 OPT 1, 3, IC_N3
nr_l2:                            /* the strip: words in the camera's font (type 4 draws a string) */
 OPT -2, 4, 1460                  /* "Off" */
 OPT -1, 4, 284                   /* "Low" */
 OPT 0, 4, ST_STD                 /* "Std" (ours: the camera's "Standard" is too wide for a cell) */
 OPT 1, 4, 267                    /* "High" */
vf_l0:
 OPT 0, 4, ST_VIG                 /* the title stays "Vignette Correction" */
 OPT 1, 4, ST_VIG
vf_l1:                            /* the left column: "Vignette" over Off / On */
 OPT 0, 3, IC_V0
 OPT 1, 3, IC_V1
vf_l2:                            /* the strip: the camera's Off / On icons */
 OPT 0, 3, VF_I0
 OPT 1, 3, VF_I1
fr_l0:                            /* v0.25 Frame: the title stays "Frame" */
 OPT 0, 4, ST_FRM
 OPT 1, 4, ST_FRM
fr_l1:                            /* the left column: "Frame" over Off / On */
 OPT 0, 3, IC_F0
 OPT 1, 3, IC_F1
fr_l2:                            /* the strip: the camera's Off / On icons */
 OPT 0, 3, VF_I0
 OPT 1, 3, VF_I1
wb_l0:                            /* v0.25 WB grid row: the title "WB" */
 OPT 0, 4, ST_AB
wb_l1:                            /* the left column: the WB± picture over the values (wb_draw) */
 OPT 0, 3, IC_WB
wb_l2:                            /* the strip (under the grid): the camera's WB± picture */
 OPT 0, 3, 12545
nr_s2v:                           /* NR slot value 1..4 (index 0..3) -> Noise Filter value; 0 Camera: the camera's own */
 .byte 0, -1, -2, 1
nr_v2s:                           /* Noise Filter value -2..+1 (index + 2) -> slot value */
 .byte 3, 2, 1, 4

/* gr_lc <- jmp from 0x611d1982 (the left column's item -> setting id lookup 0x611d1963, same frame; d0 item): Film
 * Grain Effect searches gr_tab (8 entries) instead of the stock MONO-only 0x6154cc80 (4); our rows nr_tab / vf_tab. */
gr_lc:
 cmp 5400,d0
 bne 1f
 mov gr_tab,a3
 mov 8,d2
 bra 9f
1:
 cmp NR_IT,d0
 bne 2f
 mov nr_tab,a3
 mov 4,d2
 bra 9f
2:
 cmp VF_IT,d0
 bne 3f
 mov vf_tab,a3
 mov 4,d2
 bra 9f
3:
 cmp BK_IT,d0
 bne 4f
 mov bk_tab,a3
 mov 4,d2
 bra 9f
4:
 cmp WH_IT,d0
 bne 5f
 mov wh_tab,a3
 mov 4,d2
 bra 9f
5:
 cmp AB_IT,d0
 bne 6f
 mov wg_tab,a3
 mov 4,d2
 bra 9f
6:
 cmp GM_IT,d0
 bne 7f
 mov gm_tab,a3
 mov 4,d2
 bra 9f
7:
 cmp GL_IT,d0
 bne 8f
 mov gl_tab,a3
 mov 4,d2
 bra 9f
8:
 cmp FR_IT,d0
 bne 9f
 mov fr_tab,a3
 mov 4,d2
9:
 jmp lc_back                      /* 0x611d19b4: cmp 0,a3 */

/* st_get <- jmp from the string getter 0x610f56a6 (its frame: `call ..,[d2],8`; d0 id -> a0 the UTF-16 string):
 * our own strings, else as stock (language index 0x610f56bd, then the table lookup at 0x610f56ac). */
st_get:
 cmp ST_VIG,d0
 bne 1f
 mov vig_str,a0
 ret [d2],8
1:
 cmp ST_STD,d0
 bne 2f
 mov std_str,a0
 ret [d2],8
2:
 cmp ST_BKS,d0
 bne 3f
 mov bks_str,a0
 ret [d2],8
3:
 cmp ST_WHS,d0
 bne 4f
 mov whs_str,a0
 ret [d2],8
4:
 cmp ST_AB,d0
 bne 1f
 mov abs_str,a0
 ret [d2],8
1:
 cmp ST_GM,d0
 bne 6f
 mov gms_str,a0
 ret [d2],8
6:
 cmp ST_GLC,d0
 bne 7f
 mov glc_str,a0
 ret [d2],8
7:
 cmp ST_FRM,d0
 bne 2f
 mov frm_str,a0
 ret [d2],8
2:
 cmp ST_F0,d0                     /* v0.24: film names */
 bcs 3f
 cmp ST_N0 + NF,d0
 bcc 3f
 jmp fl_str
3:
 cmp ST_DC0,d0                    /* v0.27 the Creative Dial rows' strings (dm_strs) */
 bcs 31f
 cmp ST_DF0 + 20,d0
 bcc 31f
 mov d0,d1
 add -ST_DC0,d1
 asl2 d1
 mov dm_strs,a0
 add d1,a0
 mov (a0),a0
 ret [d2],8
31:
 cmp 203,d0                       /* v0.24 film test 5: "Picture Mode" (the row's title) on the Picture Mode screen */
 bne 5f
 jmp fl_pm
5:
 cmp 2755,d0                      /* v0.24: "Color Profile 1..4" -> the film's name when COLOR k holds one */
 beq 4f
 cmp 2756,d0
 beq 4f
 cmp 2757,d0
 beq 4f
 cmp 4769,d0
 bne st_stk
4:
 jmp fl_tt
st_stk:
 mov d0,d2
 call str_lang,[],0
 jmp str_back
.balign 2
bks_str:
 .short 66, 108, 97, 99, 107, 115, 0
whs_str:
 .short 87, 104, 105, 116, 101, 115, 0
abs_str:                          /* v0.25 the WB grid row's title "WB" */
 .short 87, 66, 0
gms_str:                          /* "G-M" */
 .short 71, 45, 77, 0
glc_str:                          /* "Glow" (v0.25 owner: + Glow, - Clarity; the row is named for its + side) */
 .short 71, 108, 111, 119, 0
frm_str:                          /* "Frame" */
 .short 70, 114, 97, 109, 101, 0
 .balign 16
std_str:                          /* "Std" */
 .short 83, 116, 100, 0
vig_str:                          /* "Vignette Correction", UTF-16 */
 .short 86, 105, 103, 110, 101, 116, 116, 101, 32, 67, 111, 114, 114, 101, 99, 116, 105, 111, 110, 0

/* ch_id: `call ch_id,[d2,d3,a2],20`, d1 = our id base (NRB / VFB) -> d0 = base + k on COLOR 1-4 (picture modes
 * 54/55/56/64), else 0. As 0x611c308a (Film Grain's lookup) answers its callers. */
ch_id:
 mov d1,d2
 mov 111,d0
 call sget,[],4                   /* picture mode (keeps d2) */
 cmp 54,d0
 beq 3f
 inc d2
 cmp 55,d0
 beq 3f
 inc d2
 cmp 56,d0
 beq 3f
 inc d2
 cmp 64,d0
 beq 3f
 clr d0
 ret [d2,d3,a2],20
3:
 mov d2,d0
 ret [d2,d3,a2],20

/* Row-switch cases for our rows where Film Grain's case asks its own id (0x611c308a): the same, with ours.
 * 0x61536a2c..d2c (row actions: then the stock case from after its call), 0x61536f2c (the row's object). */
 .macro CHC name, base, back
\name:
 mov a3,a0
 mov \base,d1
 call ch_id,[d2,d3,a2],20
 jmp \back
 .endm
 CHC nr_a, NRB, cha_back
 CHC nr_b, NRB, chb_back
 CHC nr_c, NRB, chc_back
 CHC nr_d, NRB, chd_back
 CHC nr_f, NRB, chf_back
 CHC vf_a, VFB, cha_back
 CHC vf_b, VFB, chb_back
 CHC vf_c, VFB, chc_back
 CHC vf_d, VFB, chd_back
 CHC vf_f, VFB, chf_back
 CHC bk_f, BKB, f2c_obj           /* slider rows: as item 7's case (0x611c2ce8: the bar object with this id) */
 CHC wh_f, WHB, f2c_obj
 CHC gl_f, GLB, f2c_obj           /* v0.25 Glow / Clarity slider */
 CHC wg_a, WGB, cha_back          /* v0.25 WB grid row: as the Frame row, one option */
 CHC wg_b, WGB, chb_back
 CHC wg_c, WGB, chc_back
 CHC wg_d, WGB, chd_back
 CHC wg_f, WGB, chf_back
 CHC fr_a, FRB, cha_back          /* v0.25 Frame choice row */
 CHC fr_b, FRB, chb_back
 CHC fr_c, FRB, chc_back
 CHC fr_d, FRB, chd_back
 CHC fr_f, FRB, chf_back

/* lc_nr / lc_vf <- row switch 0x6155124c (the left column's cell): as Film Grain's case 0x611d0b57 (cell type 1, the
 * icon of the value from the item's list) but GetValue of our row's own id instead of 998 -> 0x611d0b72. */
lc_nr:
 mov NR_IT,d2
 bra 1f
lc_vf:
 mov VF_IT,d2
 bra 1f
lc_fr:
 mov FR_IT,d2
 bra 1f
lc_wg:
 mov AB_IT,d2
1:
 mov (20,sp),a3
 mov 1,d0
 add d1,a3
 movbu d0,(a3)
 call facade,[],4
 mov (a0),a2
 mov (40,sp),a1
 mov (12,a2),a2
 mov d2,d0
 calls (a2)                       /* GetValue(row id) -> (108,sp) */
 jmp lch_back                     /* 0x611d0b72 */

/* sl_slot: `call sl_slot,[d2,d3,a2],16`, d0 id -> a0 = slot k (P + 32 + 64k), d1 = class (1..4), or a0 = 0.
 * Bar ids (904 / GRB / NRB / VFB + k): k = id - base; left-column ids 7 / 998 / NR_IT / VF_IT: k by picture mode. */
sl_slot:
 mov d0,d3
 exthu d3
 mov 1,d1
 mov d3,d2
 add -904,d2
 cmp 4,d2
 bcs 2f
 mov 2,d1
 mov d3,d2
 add -GRB,d2
 cmp 4,d2
 bcs 2f
 mov 3,d1
 mov d3,d2
 add -NRB,d2
 cmp 4,d2
 bcs 2f
 mov 4,d1
 mov d3,d2
 add -VFB,d2
 cmp 4,d2
 bcs 2f
 mov 5,d1
 mov d3,d2
 add -BKB,d2
 cmp 4,d2
 bcs 2f
 mov 6,d1
 mov d3,d2
 add -WHB,d2
 cmp 4,d2
 bcs 2f
 mov 7,d1
 mov d3,d2
 add -ABB,d2
 cmp 4,d2
 bcs 2f
 mov 8,d1
 mov d3,d2
 add -GMB,d2
 cmp 4,d2
 bcs 2f
 mov 9,d1
 mov d3,d2
 add -GLB,d2
 cmp 4,d2
 bcs 2f
 mov 10,d1
 mov d3,d2
 add -FRB,d2
 cmp 4,d2
 bcs 2f
 mov 11,d1
 mov d3,d2
 add -WGB,d2
 cmp 4,d2
 bcs 2f
 mov 1,d1
 cmp 7,d3
 beq 1f
 mov 2,d1
 cmp 998,d3                       /* the left column's Film Grain Effect icon asks 998 (MONO: the mode's grain) */
 beq 1f
 mov 3,d1
 cmp NR_IT,d3
 beq 1f
 mov 4,d1
 cmp VF_IT,d3
 beq 1f
 mov 5,d1
 cmp BK_IT,d3
 beq 1f
 mov 6,d1
 cmp WH_IT,d3
 beq 1f
 mov 11,d1
 cmp AB_IT,d3
 beq 1f
 mov 8,d1
 cmp GM_IT,d3
 beq 1f
 mov 9,d1
 cmp GL_IT,d3
 beq 1f
 mov 10,d1
 cmp FR_IT,d3
 bne 8f
1:
 mov d1,d3                        /* the class, over the getter */
 mov 111,d0
 call sget,[],4                   /* picture mode (keeps d2, d3) */
 mov d3,d1
 clr d2
 cmp 54,d0
 beq 2f
 inc d2
 cmp 55,d0
 beq 2f
 inc d2
 cmp 56,d0
 beq 2f
 inc d2
 cmp 64,d0
 bne 8f
2:
 mov d1,a0                        /* PVAL uses d3, a2 */
 PVAL 8f
 mov a0,d1
 asl 6,d2
 add 32,d2
 add d2,a2
 mov a2,a0
 ret [d2,d3,a2],16
8:
 mov 0,a0
 ret [d2,d3,a2],16

/* sl_val: d1 class, a0 slot -> d0 the row's value (Sharp -5..+2, Grain 0..3, NR -2..+1, VigFix -1..0). */
 .macro SL_VAL
 cmp 11,d1
 bne 86f
 call wb_draw,[d2,d3,a2,a3],20    /* v0.25 WB grid row: draw its left cell from the look's A-B / G-M */
 clr d0
 bra 99f
86:
 cmp 9,d1
 bne 83f
 movbu (49,a0),d0                 /* v0.25 Glow -5..-1 / Clarity +1..+5 (the slot) */
 extb d0
 not d0                           /* the row shows it the other way: + Glow, - Clarity (owner) */
 inc d0
 bra 99f
83:
 cmp 10,d1
 bne 84f
 movbu (50,a0),d0                 /* v0.25 Frame: Art Effect 5 -> 1 On, anything else 0 Off */
 cmp 5,d0
 beq 85f
 clr d0
 bra 99f
85:
 mov 1,d0
 bra 99f
84:
 cmp 7,d1
 bne 81f
 movbu (26,a0),d0                 /* A-B */
 extb d0
 bra 99f
81:
 cmp 8,d1
 bne 82f
 movbu (27,a0),d0                 /* G-M */
 extb d0
 bra 99f
82:
 cmp 2,d1
 bne 91f
 movbu (53,a0),d0
 bra 99f
91:
 cmp 3,d1
 bne 92f
 movbu (51,a0),d0
 cmp 0,d0
 beq 94f                          /* Camera: the camera's own Noise Filter */
 cmp 5,d0
 bcc 94f
 add -1,d0
 add nr_s2v,d0
 mov d0,a0
 movbu (a0),d0
 extb d0
 bra 99f
94:
 mov 38681,d0                     /* key 0x9719, the stills Noise Filter (-2..+1) */
 clr d1
 mov 0,a0
 call nf_get,[d2,d3],12           /* the stock getter 0x60063380 (MDR: sl_get puts it back) */
 extb d0
 bra 99f
92:
 cmp 5,d1
 bne 95f
 movbu (47,a0),d0                 /* Blacks */
 extb d0
 bra 99f
95:
 cmp 6,d1
 bne 96f
 movbu (48,a0),d0                 /* Whites */
 extb d0
 bra 99f
96:
 cmp 4,d1
 bne 93f
 movbu (52,a0),d0
 and 1,d0
 xor 1,d0                         /* slot 0 Camera -> 1 On, 1 Off -> 0 Off */
 bra 99f
93:
 movbu (54,a0),d0
 extb d0
99:
 .endm

/* sl_get <- facade +12 word 0x60e57480 (CALLS: d0 id, a0 facade, a1 out -> d0 0, (a1) value); else ed_get. */
sl_get:
 cmp 0,a1
 beq 9f
 cmp 571,d0                       /* v0.27 the Creative Dial rows (dm_get) */
 beq 7f
 cmp 54,d0
 beq 7f
 cmp 55,d0
 beq 7f
 cmp 1966,d0
 bne 0f
7:
 jmp dm_get
0:
 cmp 2148,d0                      /* the Picture Mode column's row memory: the top row (111) every time (owner,
                                   * v0.25), but our row once after MENU from the WB fine-tune screen (gr_bk) */
 bne 1f
 mov 111,d1
 movbu (gr_bk),d0
 cmp 0,d0
 beq 2f
 movhu (gr_row),d1
2:
 mov d1,(a1)
 clr d0
 rets
1:
 jmp fl_get                       /* v0.24 film list: 901 for the list / left column, FLB + j (film j there?) */
sl_gb:
 movm [d2,d3,a2,a3],(sp)
 add -4,sp                        /* (0,sp): the return address slot of our own call */
 mov d0,d2
 mov a0,d3
 mov a1,a2
 mov mdr,d1
 mov d1,a3
 call gr_id,[d2,d3],12            /* v0.25 grid: its ids -> our A-B / G-M bars */
 call sl_slot,[d2,d3,a2],16       /* d0 = id still */
 mov a3,d0
 mov d0,mdr
 cmp 0,a0
 beq 8f
 SL_VAL
 mov d0,(a2)
 mov a3,d1
 mov d1,mdr                       /* again: SL_VAL may call the getter */
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 clr d0
 rets
8:
 mov d2,d0
 mov d3,a0
 mov a2,a1
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
9:
 jmp tn_get                       /* v0.26: the Shadows / Highlights wheel pages, else ed_get */

/* REAL miss: d0 = a bar id (904 / GRB / NRB / VFB + k) and P valid -> a3 = class 1..4, d2 = k, a2 = P.
 * Uses d2, d3, a2, a3. */
 .macro REAL miss
 mov 1,a3
 mov d0,d2
 exthu d2
 add -904,d2
 cmp 4,d2
 bcs 90f
 mov 2,a3
 mov d0,d2
 exthu d2
 add -GRB,d2
 cmp 4,d2
 bcs 90f
 mov 3,a3
 mov d0,d2
 exthu d2
 add -NRB,d2
 cmp 4,d2
 bcs 90f
 mov 4,a3
 mov d0,d2
 exthu d2
 add -VFB,d2
 cmp 4,d2
 bcs 90f
 mov 5,a3
 mov d0,d2
 exthu d2
 add -BKB,d2
 cmp 4,d2
 bcs 90f
 mov 6,a3
 mov d0,d2
 exthu d2
 add -WHB,d2
 cmp 4,d2
 bcs 90f
 mov 7,a3
 mov d0,d2
 exthu d2
 add -ABB,d2
 cmp 4,d2
 bcs 90f
 mov 8,a3
 mov d0,d2
 exthu d2
 add -GMB,d2
 cmp 4,d2
 bcs 90f
 mov 9,a3
 mov d0,d2
 exthu d2
 add -GLB,d2
 cmp 4,d2
 bcs 90f
 mov 10,a3
 mov d0,d2
 exthu d2
 add -FRB,d2
 cmp 4,d2
 bcs 90f
 mov 11,a3
 mov d0,d2
 exthu d2
 add -WGB,d2
 cmp 4,d2
 bcc \miss
90:
 PVAL \miss
 .endm

/* sl_cnt <- facade +28 word 0x60e57490 (d0 id, a0 -> d0 count); else pf_cnt. Sharp 8, Grain 4, NR 4, VigFix 2. */
sl_cnt:
 movm [d2,d3,a2,a3],(sp)
 mov mdr,d2                       /* v0.25 grid: the WB grid's ids -> our A-B / G-M bars (gr_id; MDR kept) */
 mov d2,a3
 add -4,sp                        /* its return address slot (else it lands on the saved d2: the choice strips broke) */
 call gr_id,[d2,d3],12
 add 4,sp
 mov a3,d2
 mov d2,mdr
 REAL 8f
 mov 1,d0                         /* v0.25: 11 the WB grid row's one option */
 cmp 11,a3
 beq 6f
 mov 11,d0                        /* v0.25: 9 Glow / Clarity -5..+5 */
 cmp 9,a3
 beq 6f
 mov 2,d0                         /* 10 Frame Off / On */
 cmp 10,a3
 beq 6f
 mov 15,d0                        /* 7 A-B, 8 G-M: -7..+7 */
 cmp 7,a3
 bcc 6f
 mov 8,d0
 cmp 1,a3
 beq 6f
 mov 11,d0
 cmp 5,a3
 bcc 6f                           /* 5 Blacks, 6 Whites: -5..+5 */
 mov 4,d0
 cmp 4,a3
 bne 6f
 mov 2,d0
6:
 movm (sp),[d2,d3,a2,a3]
 rets
8:
 movm (sp),[d2,d3,a2,a3]
 mov (gr_oid),d0
 jmp pf_cnt

/* the class's lowest value (d0) and count (d1) for index <-> value: Sharp -5/8, Grain 0/4, NR -2/4, VigFix -1/2 */
 .macro LOWCNT
 clr d0                           /* v0.25: 11 the WB grid row 0, 1 */
 mov 1,d1
 cmp 11,a3
 beq 99f
 mov -5,d0                        /* v0.25: 9 Glow / Clarity -5, 11; 10 Frame 0, 2 */
 mov 11,d1
 cmp 9,a3
 beq 99f
 clr d0
 mov 2,d1
 cmp 10,a3
 beq 99f
 mov -7,d0
 mov 15,d1
 cmp 7,a3
 bcc 99f                          /* A-B / G-M -7, 15 */
 mov -5,d0
 mov 8,d1
 cmp 1,a3
 beq 99f
 mov 11,d1
 cmp 5,a3
 bcc 99f                          /* Blacks / Whites -5, 11 */
 clr d0
 mov 4,d1
 cmp 2,a3
 beq 99f
 mov -2,d0
 cmp 3,a3
 beq 99f
 clr d0
 mov 2,d1
99:
 .endm

/* sl_vbi <- facade +32 word 0x60e57494 (d0 id, d1 index, a0, a1 out or 0 -> d0 value, -1 none); else pf_vbi. */
sl_vbi:
 movm [d2,d3,a2,a3],(sp)
 mov mdr,d2                       /* v0.25 grid: the WB grid's ids -> our A-B / G-M bars (gr_id; MDR kept) */
 mov d2,a3
 add -4,sp                        /* its return address slot (else it lands on the saved d2: the choice strips broke) */
 call gr_id,[d2,d3],12
 add 4,sp
 mov a3,d2
 mov d2,mdr
 REAL 8f
 mov d1,d2                        /* the index (REAL keeps d1) */
 LOWCNT
 cmp d1,d2
 bcs 1f
 mov -1,d0
 bra 2f
1:
 add d2,d0
2:
 cmp 0,a1
 beq 3f
 mov d0,(a1)
3:
 movm (sp),[d2,d3,a2,a3]
 rets
8:
 movm (sp),[d2,d3,a2,a3]
 mov (gr_oid),d0
 jmp pf_vbi

/* sl_sel <- facade +40 word 0x60e5749c (selectable: d0 id, d1 value, a0 -> d0 1 / 0); else stock 0x60b86a01. */
sl_sel:
 cmp 901,d0                       /* v0.24: the COLOR picture mode, our film values FV0 + j */
 bne sl_sel0
 cmp FV0,d1
 blt sl_sel0
 jmp fl_sel
sl_sel0:
 movm [d2,d3,a2,a3],(sp)
 mov mdr,d2                       /* v0.25 grid: the WB grid's ids -> our A-B / G-M bars (gr_id; MDR kept) */
 mov d2,a3
 add -4,sp                        /* its return address slot (else it lands on the saved d2: the choice strips broke) */
 call gr_id,[d2,d3],12
 add 4,sp
 mov a3,d2
 mov d2,mdr
 REAL 8f
 mov d1,d2                        /* value */
 LOWCNT
 sub d0,d2                        /* index */
 clr d0
 cmp d1,d2
 bcc 3f
 mov 1,d0
3:
 movm (sp),[d2,d3,a2,a3]
 rets
8:
 movm (sp),[d2,d3,a2,a3]
 mov (gr_oid),d0
 jmp stock_sel

/* sl_set <- .hook_set (the facade SetValue's manager call, entered as the manager: d0 id, d1 value, a0, a1 mode;
 * d2/d3/a2/a3 saved by the call, frame 68): our bar ids -> the slot byte, then ed_set's dirty + manager refresh. */
sl_set:
 cmp 2148,d0                      /* the column's row memory (the stock setting refuses our row ids 5381..5394) */
 bne 1f
 movbu (gr_hold),d2
 cmp 0,d2
 beq 4f
 clr d2
 movbu d2,(gr_hold)               /* after MENU from the fine-tune screen: keep our row once */
 mov 1,d2
 movbu d2,(gr_bk)
 bra 1f
4:
 clr d2
 movbu d2,(gr_bk)
 mov d1,d2
 exthu d2
 add -5381,d2
 cmp 14,d2
 bcc 2f
 mov d1,d2
 bra 3f
2:
 clr d2
3:
 movhu d2,(gr_row)
1:
 jmp sx_set                       /* v0.24 901 (films, COLOR 1-4) -> fl_set; v0.27 897 (the Creative Dial) -> dm_set */
sl_set0:
 mov mdr,d2                       /* v0.25 grid: the WB grid's ids -> our A-B / G-M bars (gr_id; MDR kept) */
 mov d2,a3
 add -4,sp                        /* its return address slot (else it lands on the saved d2: the choice strips broke) */
 call gr_id,[d2,d3],12
 add 4,sp
 mov a3,d2
 mov d2,mdr
 REAL 9f
 mov (gr_oid),d0                  /* the id as asked (s_dirty refreshes it) */
 asl 6,d2
 add a2,d2                        /* d2 = P + 64k */
 cmp 11,a3                        /* v0.25 WB grid row: nothing to store */
 beq 7f
 cmp 9,a3
 bne 12f
 cmp -5,d1                        /* v0.25 Glow / Clarity -5..+5 -> +49 */
 blt 7f
 cmp 5,d1
 bgt 7f
 not d1                           /* the row's + Glow / - Clarity -> the slot's - Glow / + Clarity */
 inc d1
 mov d2,a3
 movbu d1,(81,a3)
 jmp s_dirty
12:
 cmp 10,a3
 bne 13f
 cmp 0,d1                         /* v0.25 Frame 0 Off / 1 On -> +50 = 0 / 5 */
 blt 7f
 cmp 1,d1
 bgt 7f
 clr d3
 cmp 0,d1
 beq 14f
 mov 5,d3
14:
 mov d2,a3
 movbu d3,(82,a3)
 jmp s_dirty
13:
 cmp 7,a3
 bcs 10f
 cmp -7,d1                        /* A-B / G-M -7..+7 -> +26 / +27, then wb_flags (+25): bit0 on, bit7 off (as the
 blt 7f                           * Extras wheel) */
 cmp 7,d1
 bgt 7f
 mov 58,d3
 cmp 7,a3
 beq 11f
 mov 59,d3
11:
 add d2,d3
 mov d3,a3
 movbu d1,(a3)
 mov d2,a3
 movbu (57,a3),d3
 or 1,d3
 and 0x7f,d3
 movbu d3,(57,a3)
 call gr_now,[d2,d3,a2,a3],20     /* v0.25: the grid's dot and the title's numbers follow */
 jmp s_dirty
10:
 cmp 1,a3
 bne 2f
 cmp -5,d1                        /* Sharp -5..+2 -> +54 */
 blt 7f
 cmp 2,d1
 bgt 7f
 mov d2,a3
 movbu d1,(86,a3)
 jmp s_dirty
2:
 cmp 2,a3
 bne 3f
 cmp 0,d1                         /* Grain 0..3 -> +53 */
 blt 7f
 cmp 3,d1
 bgt 7f
 mov d2,a3
 movbu d1,(85,a3)
 jmp s_dirty
3:
 cmp 3,a3
 bne 4f
 cmp -2,d1                        /* NR -2..+1 -> +51 (3 Off, 2 Low, 1 Std, 4 High) */
 blt 7f
 cmp 1,d1
 bgt 7f
 mov d1,d3
 add 2,d3
 add nr_v2s,d3
 mov d3,a3
 movbu (a3),d3
 mov d2,a3
 movbu d3,(83,a3)
 jmp s_dirty
4:
 cmp 5,a3
 bcs 5f
 cmp -5,d1                        /* Blacks / Whites -5..+5 -> +47 / +48 */
 blt 7f
 cmp 5,d1
 bgt 7f
 add 79,d2                        /* P + 64k + 32 + 47 */
 cmp 5,a3
 beq 6f
 inc d2                           /* +48 */
6:
 mov d2,a3
 movbu d1,(a3)
 sub 79,d2                        /* (s_dirty needs no d2) */
 jmp s_dirty
5:
 cmp 0,d1                         /* VigFix 0 Off / 1 On -> +52 (1 Off, 0 Camera) */
 blt 7f
 cmp 1,d1
 bgt 7f
 mov d1,d3
 xor 1,d3
 mov d2,a3
 movbu d3,(84,a3)
 jmp s_dirty
7:
 clr d0
 ret [d2,d3,a2,a3],68
9:
 mov (gr_oid),d0
 jmp tn_set                       /* v0.26: the Shadows / Highlights wheel pages, else ed_set */

/* sl_rng <- jmp from 0x611d1041 (the slider bar setup 0x611d0f99, item 7 Sharpness; same frame): as stock, the value
 * of 7 into (24,sp), then the bar's ends a3 = min, d0 = max: -5..+2 on COLOR 1-4 (the Sharp slider), else -2..+2. */
sl_rng:
 call facade,[],4
 mov (a0),a2
 mov sp,a1
 mov (12,a2),a2
 add 24,a1
 mov 7,d0
 calls (a2)
 mov 7,d0
 call sl_slot,[d2,d3,a2],16
 mov -2,d0
 cmp 0,a0
 beq 1f
 mov -5,d0
1:
 mov d0,a3                        /* min: the "-" greys out there (and sl_dot knows the Sharp bar by it) */
 mov 2,d0
 jmp rng_back                     /* 0x611d1090: mov d0,(4,sp) */

/* rw_bar <- jmp from 0x611d1035 (bar setup, d0 = the row's item; stock: 59 -> 0x611d1057, 5399 -> 0x611d1074, else
 * 0x611d1092 = no value). Blacks / Whites: their value into (24,sp) (GetValue of the row's own id, as stock reads 7),
 * ends a3 = -5, d0 = +5. Keeps d2, d3 (the stock function's). */
rw_bar:
 cmp 59,d0
 bne 1f
 jmp bar_59
1:
 cmp 5399,d0
 bne 2f
 jmp bar_5399
2:
 cmp BK_IT,d0
 beq 3f
 cmp WH_IT,d0
 beq 3f
 cmp GL_IT,d0                     /* v0.25 Glow / Clarity: -5..+5 as Blacks / Whites */
 beq 3f
 cmp AB_IT,d0
 beq 4f
 cmp GM_IT,d0
 beq 4f
 jmp bar_none
3:
 mov d0,a3
 call facade,[],4
 mov (a0),a2
 mov sp,a1
 mov (12,a2),a2
 add 24,a1
 mov a3,d0
 calls (a2)                       /* GetValue(item) -> (24,sp) */
 mov -5,a3
 mov 5,d0
 jmp rng_back
4:                                /* A-B / G-M: -7..+7 */
 mov d0,a3
 call facade,[],4
 mov (a0),a2
 mov sp,a1
 mov (12,a2),a2
 add 24,a1
 mov a3,d0
 calls (a2)
 mov -7,a3
 mov 7,d0
 jmp rng_back

/* Picture Mode column paging (camera test 8: with 11 rows the second page drew 6 rows into 5 slots and left stale
 * highlights). Stock pages are rows 0-4 and 5..n-1 (n <= 10). Ours: pages of 5, as many as needed. */
/* pg_fix <- jmp from 0x611d07a4 (d2 = n rows, (104,sp) = cursor): d0 = first row shown, d2 = rows shown -> 0x611d07bd */
pg_fix:
 cmp 5,d2
 bgt 1f
 clr d0
 jmp pg_back
1:
 movhu (104,sp),d1
 clr d0
2:
 cmp 5,d1
 bcs 3f
 add -5,d1
 add 5,d0
 bra 2b
3:
 sub d0,d2                        /* rows left from this page's first */
 cmp 5,d2
 ble 4f
 mov 5,d2
4:
 jmp pg_back
/* pg_mod <- jmp from 0x611c3709 (d3 = cursor): the slot = cursor mod 5 in d0 and d3 -> 0x611c3710 */
pg_mod:
 cmp 5,d3
 bcs 1f
 add -5,d3
 bra pg_mod
1:
 mov d3,d0
 jmp pgm_back
/* pg_arw <- jmp from 0x611d0be0 (cursor >= 5, more than 5 rows): the up arrow, and the down arrow too while rows follow
 * this page -> 0x611d0be8 */
pg_arw:
 mov (20,sp),a0
 mov 1,d0
 movbu d0,(885,a0)
 movhu (104,sp),d1
 clr d0
1:
 cmp 5,d1
 bcs 2f
 add -5,d1
 add 5,d0
 bra 1b
2:
 add 5,d0                         /* the next page's first row */
 mov (84,sp),d1                   /* n */
 cmp d1,d0
 bcc 3f
 mov 1,d0
 movbu d0,(887,a0)
3:
 jmp arw_back

/* rv_chk <- jmp from 0x611b21e8 (a bar's value list: a2 = 1 builds it top-down, as the camera does for the ids in its
 * table 0x6152d6fe, 904 Sharpness among them; else bottom-up, so the arrows ran backwards on Blacks / Whites, camera
 * test 8). Our slider bar ids: a2 = 1 too. Then as stock: id 469 -> 0x611b21f2, else 0x611b2217. */
rv_chk:
 mov (16,sp),a0
 movhu (a0),d0
 add -BKB,d0
 cmp 4,d0
 bcs 1f
 movhu (a0),d0
 add -WHB,d0
 cmp 4,d0
 bcs 1f
 movhu (a0),d0
 add -GLB,d0
 cmp 4,d0
 bcc 2f
1:
 mov 1,a2
2:
 movhu (a0),d0
 cmp 469,d0
 bne 3f
 jmp rv_469
3:
 jmp rv_back

/* ic_get <- jmp from the picture lookup 0x610f5611 (`call ..,[],0`, d0 picture id -> a0 = its slot: a word holding
 * the picture's descriptor; 0 for id 0): our ids IC_BK .. IC_END - 1 -> their word in ic_ent, else as stock
 * ((0x60379740) + 4 id). */
ic_get:
 mov d0,d1
 exthu d1
 cmp 0,d1
 bne 1f
 mov 0,a0
 retf [],0
1:
 cmp IC_FM0,d1
 bcs 11f
 cmp IC_FL0 + NF,d1
 bcc 11f
 jmp fl_ic
11:
 cmp 15706,d1                     /* film test 9: the shooting screen's "COLOR1".."COLOR4" */
 bcs 13f
 cmp 15714,d1                     /* sd4: and 15710..15713, their '*' pictures (0x61234cca..: COLOR k itself changed) */
 bcc 13f
 jmp fl_lvp
13:
 cmp 15746,d1                     /* v0.24: the quick menu's "COLOR k" / "COLOR k*" pictures */
 bcs 12f
 cmp 15754,d1
 bcc 12f
 jmp fl_scp
12:
 cmp 16244,d1                     /* v0.25: the Shading icon, moved down (sh_build) */
 bne 13f
 mov (sh_desc + 12),a0
 cmp 0,a0
 beq 13f
 mov sh_slot,a0
 retf [],0
13:
 cmp IC_WB,d1                     /* v0.25: the WB grid row's left cell; the camera's WB± until it is drawn */
 bne 14f
 mov (wb_desc + 12),d1
 cmp 0,d1
 bne 15f
 mov 12545,d0
 bra ic_stk
15:
 mov wb_slot,a0
 retf [],0
14:
 cmp IC_BK,d1
 bcs ic_stk
 cmp IC_END,d1
 bcs 3f
ic_stk:
 mov (0x60379740),a0
 exthu d0
 asl2 d0
 add d0,a0
 retf [],0
3:
 add -IC_BK,d1
 asl2 d1
 mov ic_ent,a0
 add d1,a0
 retf [],0

/* The left column's slider icon (the "S" of Sharpness): each of the column's 5 row slots has a picture object whose
 * choices are a list of {0xffff, 7, 7, picture id} (16 B), and a slider row's item +26 picks choice +26 - 1 (cell
 * case 0x611d096e -> 0x61178939; 0x6128abe0 / 0x610dae2a ignore an index from the object's +131 on (the choice
 * count, from the layout record's byte before the list pointers). Stock lists 0x614548b4.. (5 slots): S, Contrast,
 * Saturation (count 3). build.py points the 5 slots' layout records (start, end, count 6) at ic_list: the stock three, S again
 * for 4 (item 5399's +26, Shading, which draws its own picture), then Blk 5, Wht 6. */
/* v0.25 WB grid row (owner 2026-11-08): one row (AB_IT, a one-option choice row as sliders test 12) for the look's
 * A-B / G-M. On it the Picture Mode screen shows the camera's WB grid (scene 498, element 24813) in the holder of its
 * bottom-bar layer 457 (sc_cap, gr_upd from the screen's update 0x611d04ec; property 256 via gr_pub, as sliders
 * test 13), and OK, left / right or a dial open the camera's own WB fine-tune screen (0x0408, pm_ev) with
 * gr_flag = look + 1: the facade answers its stills ids (A-B 1580..1592, G-M 1593..1605 by WB mode) from the look's
 * slot +26 / +27 (gr_id -> our ABB / GMB + k), so it shows and changes the look's values with the camera's own
 * directions and numbers. gx_map: MENU there comes back to our row (0x0417 -> 0x0418, gr_hold / gr_row), any other
 * way out or leaving Picture Mode clears the flag. The row's left cell is drawn from the values (wb_draw, xb_wbc). */
.set GLY, 456                     /* Picture Mode's bottom-bar layer: its holder takes the WB grid (498) on our row */
.balign 4
gr_flag:
 .long 0
gr_fine:                          /* 1 while the WB fine-tune screen is open from our row (pm_ev) */
 .long 0
gr_hold:                          /* 1 from MENU in it to Picture Mode's first row-memory write (as test 12) */
 .long 0
gr_row:                           /* the column's row memory (setting 2148) when it is one of our rows */
 .long 0
gr_wait:                          /* 1 from MENU back from the fine-tune screen until sc_cap has loaded the grid */
 .long 0
gr_bk:                            /* 1: the row memory answers gr_row (back from the fine-tune screen) */
 .long 0
gr_oid:
 .long 0
gx_d0:
 .long 0
gx_sh:
 .long 0
gr_cont:                          /* the holder of Picture Mode's layer 457, captured at start-up (sc_cap) */
 .long 0
gr_sv:
 .long 0, 0, 0, 0
gr_st:                            /* v0.26: the GUI state gx_map last sent the screen to */
 .long 0
gr_blk:                           /* the grid's block (property 256, 18 B, as the WB screen's +5188 from 0x611d257a):
                                   * B / A / G / M box states 3, flags, A-B line x, G-M line y, dot x / y */
 .byte 3, 3, 3, 3, 0, 0, 0, 0
 .short 0, 0, 0, 0, 0

/* wb_wtk / wb_wem: the WB cell drawer's (xblock xb_wbc) token reader and packer, here for the GUIDES.BIN size cap.
 * wb_v: +0 the source's next 64-bit word, +4 / +8 the current word, +12 the token in it (0..5), +16 the output's next
 * word, +20 / +24 the word being packed, +28 its token count, +32 the output room's end. */
/* wb_wtk: `call wb_wtk,[],4` -> d0 = the source picture's next 12-bit token. Uses d0, d1, a0. */
wb_wtk:
 mov (wb_v + 12),d1
 cmp 5,d1
 bcs 1f
 mov (wb_v),a0
 mov (a0),d0
 mov d0,(wb_v + 4)
 mov (4,a0),d0
 mov d0,(wb_v + 8)
 add 8,a0
 mov a0,(wb_v)
 clr d1
1:
 mov d1,d0
 inc d0
 mov d0,(wb_v + 12)
 mov (wb_v + 4),d0
 cmp 0,d1
 beq 9f
 lsr 12,d0
 cmp 1,d1
 beq 9f
 mov (wb_v + 8),a0
 cmp 2,d1
 bne 3f
 lsr 12,d0
 mov a0,d1
 asl 8,d1
 or d1,d0
 bra 9f
3:
 mov a0,d0
 lsr 4,d0
 cmp 3,d1
 beq 9f
 lsr 12,d0
9:
 and 0xfff,d0
 ret [],4

/* wb_wem: `call wb_wem,[],4`, d0 = a token -> packed; d0 = 0 when the room is full, else 1. Uses d0, d1, a0. */
wb_wem:
 mov (wb_v + 28),d1
 cmp 0,d1
 bne 1f
 mov d0,(wb_v + 20)
 clr d0
 mov d0,(wb_v + 24)
 bra 8f
1:
 cmp 1,d1
 bne 2f
 asl 12,d0
 bra 7f
2:
 cmp 2,d1
 bne 3f
 mov d0,d1
 lsr 8,d1
 mov d1,(wb_v + 24)
 asl 24,d0
7:
 mov (wb_v + 20),d1
 or d1,d0
 mov d0,(wb_v + 20)
 bra 8f
3:
 cmp 3,d1
 bne 4f
 asl 4,d0
 bra 6f
4:
 asl 16,d0
6:
 mov (wb_v + 24),d1
 or d1,d0
 mov d0,(wb_v + 24)
8:
 mov (wb_v + 28),d1
 inc d1
 cmp 5,d1
 bcs 9f
 mov (wb_v + 16),a0
 mov a0,d0
 add 8,d0
 mov (wb_v + 32),d1
 cmp d1,d0
 bhi 91f
 mov (wb_v + 20),d1
 mov d1,(a0)
 mov (wb_v + 24),d1
 mov d1,(4,a0)
 mov d0,(wb_v + 16)
 clr d1
9:
 mov d1,(wb_v + 28)
 mov 1,d0
 ret [],4
91:
 clr d0
 ret [],4
.balign 4
wb_v:
 .long 0, 0, 0, 0, 0, 0, 0, 0, 0

/* sh_build: `call sh_build,[d2,d3,a2,a3],20` (pu_hook, once): the Shading row's icon (the camera's picture 16244,
 * 46 x 46, type 11) moved down SH_DY rows into sh_desc (owner, v0.25: its number sat lower than the icon; the row's
 * own left cell puts the readout lower than the slider rows' cells do). ic_get answers 16244 with it. Uses the WB
 * cell drawer's token reader / packer (wb_wtk / wb_wem, wb_v). */
.set SH_DY, 6
sh_build:
 mov (sh_try),d0                  /* one try only */
 cmp 0,d0
 bne 9f
 mov 1,d0
 mov d0,(sh_try)
 mov (0x60379740),a0
 add 4 * 16244,a0
 mov (a0),a2                      /* its descriptor */
 cmp 0,a2
 beq 9f
 movhu (2,a2),d0
 cmp 46,d0
 bne 9f
 movhu (4,a2),d0
 cmp 46,d0
 bne 9f
 mov (16,a2),a3
 cmp 0,a3
 beq 9f
 movbu (3,a3),d0
 cmp 11,d0
 bne 9f
 mov 1024,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(sh_buf)
 mov (a3),d0                      /* the same header (46 x 46, type 11) */
 mov d0,(a0)
 add 4,a0
 mov a0,(wb_v + 16)
 add 1020,a0
 mov a0,(wb_v + 32)
 add 4,a3
 mov a3,(wb_v)
 mov 5,d0
 mov d0,(wb_v + 12)
 clr d0
 mov d0,(wb_v + 28)
 mov SH_DY * 3,d2                 /* SH_DY clear rows: 16 + 16 + 14 px */
 mov 2,d3
1:
 mov 0x00f,d0
 cmp 0,d3
 bne 2f
 mov 0x00d,d0
 mov 3,d3
2:
 add -1,d3
 call wb_wem,[],4
 cmp 0,d0
 beq 8f
 add -1,d2
 bne 1b
 mov 46 * (46 - SH_DY),d2         /* then the picture's first 46 - SH_DY rows */
3:
 call wb_wtk,[],4
 mov d0,d3
 and 15,d3
 inc d3
 call wb_wem,[],4
 cmp 0,d0
 beq 8f
 sub d3,d2
 bgt 3b
 mov (wb_v + 28),d0               /* the last word */
 cmp 0,d0
 beq 4f
 mov (wb_v + 16),a0
 mov (wb_v + 20),d0
 mov d0,(a0)
 mov (wb_v + 24),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(wb_v + 16)
4:
 mov (wb_v + 16),d0
 mov (sh_buf),d1
 sub d1,d0
 mov d0,(sh_desc + 12)
 mov d1,d0
 and 0xf0000000,d1
 cmp 0x60000000,d1                /* a cached address -> uncached, as the stock pictures' */
 bne 5f
 add 0x40000000,d0
5:
 mov d0,(sh_desc + 16)
8:
9:
 ret [d2,d3,a2,a3],20
.balign 4
sh_try:
 .long 0
sh_buf:
 .long 0
sh_slot:
 .long sh_desc
sh_desc:
 .short 14, 46, 46, 8, 0, 0
 .long 0, 0, 0

/* wb_draw: `call wb_draw,[d2,d3,a2,a3],20`, a0 = the look's slot: the WB grid row's left cell for its A-B (+26) /
 * G-M (+27), drawn by the code block (xb_wbc, +144) into its buffer, wb_desc pointing there; again only when the
 * values change. Without the block (or a drawing) the cell stays the camera's WB± picture (ic_get). */
wb_draw:
 movbu (26,a0),d2
 extb d2
 movbu (27,a0),d3
 extb d3
 mov d2,d0
 asl 8,d0
 or d3,d0
 exthu d0
 mov (wb_last),d1
 cmp d1,d0
 beq 9f
 mov d0,(wb_last)
 call xp,[],0
 beq 8f
 add 120,a1
 add 24,a1
 mov d2,d0
 mov d3,d1
 calls (a1)
 cmp 0,d0
 beq 8f
 mov wb_desc,a1
 mov d0,(12,a1)
 mov a0,d0
 mov d0,d1
 and 0xf0000000,d1
 cmp 0x60000000,d1                /* a cached address -> uncached, as the stock pictures' */
 bne 1f
 add 0x40000000,d0
1:
 mov d0,(16,a1)
 bra 9f
8:
 clr d0
 mov d0,(wb_desc + 12)
 mov -1,d0
 mov d0,(wb_last)                 /* try again next time */
9:
 ret [d2,d3,a2,a3],20
.balign 4
wb_last:
 .long -1
wb_slot:
 .long wb_desc
wb_desc:                          /* format 14, 100 x 76, as our cell pictures; size, payload from xb_wbc */
 .short 14, 100, 76, 8, 0, 0
 .long 0, 0, 0

/* gr_id: `call gr_id,[d2,d3],12`, d0 id -> d0: while the grid shows for look k (gr_flag = k + 1), its A-B ids
 * 1580..1592 -> ABB + k and G-M ids 1593..1605 -> GMB + k; else d0 kept. gr_oid = the id
 * as asked. Keeps d1, a0..a3 (not MDR: callers keep it). */
gr_id:
 mov d0,(gr_oid)
 movbu (gr_flag),d3
 cmp 0,d3
 beq 9f
 add -1,d3
 mov d0,d2
 exthu d2
 add -1580,d2
 cmp 13,d2
 bcs 1f
 add -13,d2
 cmp 13,d2
 bcc 9f
 mov GMB,d0
 bra 2f
1:
 mov ABB,d0
2:
 add d3,d0
9:
 ret [d2,d3],12

/* gr_now: `call gr_now,[d2,d3,a2,a3],20`: gr_pub and gr_ref, keeping d0, d1, a0, a1 (sl_set's s_dirty needs them). */
gr_now:
 mov d0,(gr_sv)
 mov d1,(gr_sv + 4)
 mov a0,(gr_sv + 8)
 mov a1,(gr_sv + 12)
 call gr_pub,[d2,d3,a2,a3],20
 call gr_ref,[d2,d3,a2,a3],20
 mov (gr_sv),d0
 mov (gr_sv + 4),d1
 mov (gr_sv + 8),a0
 mov (gr_sv + 12),a1
 ret [d2,d3,a2,a3],20

/* sc_cap <- jmp from 0x610cdf05 (a holder element gets its scene: a0 holder, d0 scene index; a1 free): remember the
 * start-up holder of scene 485, the camera's WB fine-tune grid. It is one of the GUI's top layers, which every screen
 * empties (-1) when it opens; on our row we load 485 into it again, and empty it when the row or the screen goes. */
sc_cap:
 cmp GLY,d0
 bne 1f
 mov (gr_st),d3                   /* v0.26 (camera: COLOR 1 after the drive mode screen restarted it): only Picture Mode's
                                   * load; other screens' bottom bars (e.g. the drive mode list) use 456 too and go away */
 cmp 0x0418,d3
 bne 1f
 movbu (gr_fine),d3               /* not while the fine-tune screen is open from our row (its own 457 holder goes away;
                                   * Picture Mode's stays) */
 cmp 0,d3
 bne 1f
 mov gr_cont,a1
 mov a0,(a1)
 movbu (gr_flag),d3               /* on our row (entering Picture Mode, back from the fine-tune screen: its first
                                   * update comes before it loads its bottom bar, 457) that load takes the grid (498) */
 cmp 0,d3
 beq 1f
 clr d3
 movbu d3,(gr_wait)
 mov a0,(gx_d0)
 mov d1,(gr_sv + 4)
 add -4,sp                        /* our call's slot (not the hooked frame's (0,sp)) */
 call gr_pub,[d2,d3,a2,a3],20
 add 4,sp
 mov (gr_sv + 4),d1
 mov (gx_d0),a0
 mov 498,d0
1:
 mov d0,a3
 mov a0,d3
 mov 1,d0
 jmp sc_back                      /* 0x610cdf0b */

/* gr_upd: `call gr_upd,[d2,d3,a2,a3],20`, a0 -> the Picture Mode screen's current item (u16). On our row on COLOR 1-4:
 * gr_flag = look + 1, publish the grid block (gr_pub) and load the camera's WB grid scene (485) into its top-layer
 * holder; else gr_flag = 0 and the holder is emptied. */
gr_upd:
 movhu (a0),d0
 cmp AB_IT,d0
 bne 8f
 mov 1,d1
 call ch_id,[d2,d3,a2],20         /* picture mode -> 1..4, else 0 */
 movbu d0,(gr_flag)
 cmp 0,d0
 beq 8f
 movbu (gr_wait),d0               /* back from the fine-tune screen: not before Picture Mode reloads its bottom bar
                                   * (loading 498 at its first update crashed; sc_cap swaps that load instead) */
 cmp 0,d0
 bne 9f
 mov (gr_cont),d0
 cmp 0,d0
 beq 9f
 call gr_pub,[d2,d3,a2,a3],20
 mov (gr_cont),a0
 call gr_is,[d2],8                /* d0 = 1: the holder already shows the grid */
 cmp 1,d0
 beq 7f
 mov (gr_cont),a0
 mov 498,d0
 call sc_set,[d2,d3,a2,a3],28     /* the holder takes the WB grid scene */
7:
 call gr_ref,[d2,d3,a2,a3],20
 bra 9f
8:
 clr d0
 movbu d0,(gr_flag)
 mov (gr_cont),a0
 call gr_is,[d2],8
 cmp 1,d0
 bne 9f
 mov (gr_cont),a0
 mov GLY,d0
 call sc_set,[d2,d3,a2,a3],28     /* back to its own layer (the bottom bar) */
9:
 ret [d2,d3,a2,a3],20

/* gr_is: `call gr_is,[d2],8`, a0 = the holder (or 0) -> d0 = 1 when its scene is the WB grid (element 24813) */
gr_is:
 clr d2
 cmp 0,a0
 beq 9f
 mov (776,a0),a0
 cmp 0,a0
 beq 9f
 movhu (4,a0),d0
 cmp 24813,d0
 bne 9f
 mov 1,d2
9:
 mov d2,d0
 ret [d2],8

/* gr_ref: `call gr_ref,[d2,d3,a2,a3],20`: the grid scene (the holder's +776) re-reads property 256 (its method
 * 0x61192d6c, as on a property change). */
gr_ref:
 mov gr_cont,a1
 mov (a1),a0
 call gr_is,[d2],8
 cmp 1,d0
 bne 9f
 mov gr_cont,a1
 mov (a1),a0
 mov (776,a0),a0
 mov sc_ref,a1
 calls (a1)
9:
 ret [d2,d3,a2,a3],20

/* gr_pub: `call gr_pub,[d2,d3,a2,a3],20`: with gr_flag = look + 1, fill the grid block from the look's A-B / G-M as
 * the WB screen does (0x611d257a: lines at 613 + 13 A-B / 299 - 13 G-M, dot at 594 + 13 A-B / 280 - 13 G-M, x + 80
 * when 0x611d2941 says 1) and publish it (property 256). */
gr_pub:
 call wb_shift,[d2,a2],24         /* 1: the layout 80 px to the right (keeps only d2, a2) */
 clr d1
 cmp 1,d0
 bne 4f
 mov 80,d1
4:
 mov d1,(gx_sh)
 movbu (gr_flag),d1
 cmp 0,d1
 beq 9f
 add -1,d1
 mov d1,d2                        /* k */
 PVAL 9f                          /* a2 = P (uses d3) */
 asl 6,d2
 add 32,d2
 add d2,a2                        /* the look's slot */
 movbu (26,a2),d2
 extb d2                          /* A-B */
 movbu (27,a2),d3
 extb d3                          /* G-M */
 mov gr_blk,a2
 clr d0
 cmp 0,d2
 beq 1f
 mov 1,d0
1:
 movbu d0,(6,a2)
 clr d0
 cmp 0,d3
 beq 2f
 mov 1,d0
2:
 movbu d0,(10,a2)
 clr d0
 movbu d0,(11,a2)
 mov (gx_sh),d1
 mov d2,d0
 asl 3,d0
 mov d2,a1
 add a1,a1
 add a1,a1
 add a1,d0
 add d2,d0                        /* 13 A-B */
 mov d0,a1
 add 613,d0
 add d1,d0
 movhu d0,(8,a2)
 mov a1,d0
 add 594,d0
 add d1,d0
 movhu d0,(14,a2)
 mov d3,d0
 asl 3,d0
 mov d3,a1
 add a1,a1
 add a1,a1
 add a1,d0
 add d3,d0                        /* 13 G-M */
 mov d0,a1
 mov 299,d0
 sub a1,d0
 movhu d0,(12,a2)
 mov 280,d0
 sub a1,d0
 movhu d0,(16,a2)
 mov 256,d0
 mov gr_blk,a0
 mov 18,d1
 mov 1,a1
 call prop_set,[d2,a2],16
9:
 ret [d2,d3,a2,a3],20

/* pu_hook <- jmp from 0x611d04ec (the Picture Mode screen's update, after its per-row case; (4,sp) -> the current
 * item; a3 = the screen): the WB grid for our row, then as stock `mov (0x6037a360),d0` -> 0x611d04f2. */
pu_hook:
 mov (4,sp),a0
 add -4,sp                        /* our calls' slot (the screen update's own (0,sp) stays) */
 mov (sh_desc + 12),d0            /* v0.25: the Shading icon moved down, once (sh_build) */
 cmp 0,d0
 bne 1f
 mov a0,(gx_d0)
 call sh_build,[d2,d3,a2,a3],20
 mov (gx_d0),a0
1:
 call gr_upd,[d2,d3,a2,a3],20
 add 4,sp
 mov (0x6037a360),d0
 jmp pu_back

/* pm_ev <- jmp from the Picture Mode handler 0x6125becc (calls: d0 event, d1, a0, a1): on our WB row on COLOR 1-4
 * (gr_flag set by gr_upd), the events that open the WB fine-tune screen from
 * the camera's WB± row (0x6125bc8b: 0x900c OK, 0x9031 / 0x9032 dials, 0xf83c, 0x9755 with code 9; and left / right
 * 0x9008 / 0x900a) -> gr_flag = look
 * + 1, gr_fine = 1, d0 = 0x0408 (as sliders test 12; on the camera OK was not 0x900c there); else stock. */
pm_ev:
 movm [d2,d3,a2,a3],(sp)
 add -40,sp                       /* (0,sp) our call's slot; d0, d1, a0, a1, mdr kept; (24..39) the event's data */
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 mov mdr,d2
 mov d2,(20,sp)
 movbu (gr_flag),d2               /* our row is the current one (gr_upd; the row list at (0x6037dfa0) + 0x51a0 is the
                                   * fine-tune screen's after MENU back from it) */
 cmp 0,d2
 beq 8f
 cmp 0x900c,d0
 beq 2f
 cmp 0x9008,d0                    /* left / right press: the same (no changes on the row itself) */
 beq 2f
 cmp 0x900a,d0
 beq 2f
 cmp 0x9031,d0
 beq 2f
 cmp 0x9032,d0
 beq 2f
 cmp 0xf83c,d0
 beq 2f
 cmp 0x9755,d0
 bne 8f
 mov sp,a0
 add 24,a0
 call ev_arg,[],0                 /* 0x6129b050: the event's data, (26,sp) its code */
 movhu (26,sp),d0
 cmp 9,d0
 bne 8f
2:
 mov 1,d1
 call ch_id,[d2,d3,a2],20         /* picture mode -> 1..4, else 0 */
 cmp 0,d0
 beq 8f
 movbu d0,(gr_flag)
 mov 1,d0
 movbu d0,(gr_fine)
 mov (20,sp),d2
 mov d2,mdr
 add 40,sp
 movm (sp),[d2,d3,a2,a3]
 mov 0x0408,d0
 mov 8,d1
 rets
8:
 mov (20,sp),d2
 mov d2,mdr
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 mov (16,sp),a1
 add 40,sp
 movm (sp),[d2,d3,a2,a3]
 movm [d2,a2,a3],(sp)
 add -60,sp
 jmp pme_back                     /* 0x6125bed1 */

/* gx_map <- jmp from 0x610f6016 (the state dispatcher, d0 = a handler's next state, (8,sp) -> the GUI state bytes
 * {parent, child}; a0 / a1 / d1 free here): a state change while in Picture Mode (0x0418) clears gr_flag. */
gx_map:
 mov d0,d1
 exthu d1
 cmp 0,d1
 beq 9f
 mov (8,sp),a0
 movhu (a0),d1
 cmp 0x0804,d1                    /* leaving the WB fine-tune screen (0x0408) */
 bne 5f
 movbu (gr_fine),d1
 cmp 0,d1
 beq 9f                           /* not opened from our row: stock */
 clr d1
 movbu d1,(gr_fine)
 mov d0,d1
 exthu d1
 cmp 0x0417,d1                    /* MENU: back to Picture Mode on our row, not to the WB screen */
 bne 4f
 mov 0x0418,d0
 mov 1,d1
 movbu d1,(gr_hold)
 movbu d1,(gr_wait)
 bra 9f
4:
 clr d1                           /* to anywhere else (OK, half-press: live view): Picture Mode and its holder are gone */
 movbu d1,(gr_flag)
 movbu d1,(gr_wait)
 mov d1,(gr_cont)
 bra 9f
5:
 cmp 0x1804,d1                    /* leaving Picture Mode (0x0418) */
 bne 9f
 movbu (gr_fine),d1
 cmp 0,d1
 bne 6f                           /* to the fine-tune screen from our row: keep the look */
 movbu d1,(gr_flag)
6:
 mov (gr_cont),a0                 /* and give the holder its own layer back */
 cmp 0,a0
 beq 9f
 mov d0,(gx_d0)
 add -4,sp
 call gr_is,[d2],8
 add 4,sp
 cmp 1,d0
 bne 8f
 mov (gr_cont),a0
 mov GLY,d0
 add -4,sp
 call sc_set,[d2,d3,a2,a3],28
 add 4,sp
8:
 mov (gx_d0),d0
 movbu (gr_fine),d1               /* to the fine-tune screen: Picture Mode and its holder stay (it comes back) */
 cmp 0,d1
 bne 9f
 mov d1,(gr_cont)                 /* else the holder may go with the screen: captured again when 457 loads */
9:
 mov d0,d1                        /* v0.26: the screen we go to (sc_cap takes the holder only for Picture Mode) */
 exthu d1
 cmp 0,d1
 beq 91f
 mov d1,(gr_st)
91:
 mov d0,d3
 exthu d3
 mov d3,d2
 asr 8,d2
 jmp gx_back                      /* 0x610f601c */

.balign 4
ic_list:
 .long 0xffff, 7, 7, 11416
 .long 0xffff, 7, 7, 11417
 .long 0xffff, 7, 7, 11418
 .long 0xffff, 7, 7, 11416
 .long 0xffff, 7, 7, IC_BK
 .long 0xffff, 7, 7, IC_WH
 .long 0xffff, 7, 7, 12545         /* v0.25: 7 = the camera's WB± picture (the WB grid row) */
 .long 0xffff, 7, 7, IC_GM
 .long 0xffff, 7, 7, IC_GL         /* v0.25: 9 = Glow / Clarity */
ic_lend:
ic_ent:                           /* the slot word of each of our pictures, in firmware/mkicons.py PICTURES order */
 .long ic_d0, ic_d1, ic_d2, ic_d3, ic_d4, ic_d5, ic_d6, ic_d7, ic_d8, ic_d9, ic_d10, ic_d11, ic_d12, ic_d13
/* descriptors <6H3I> as the stock pictures': format 14, w, h, 8, 0, 0, size, payload, flags; build.py fills w, h,
 * size and payload (the streams from firmware/mkicons.py, packed into ic_pay, by their uncached address 0xa...) */
 .macro ICD n
ic_d\n:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
 .endm
 ICD 0
 ICD 1
 ICD 2
 ICD 3
 ICD 4
 ICD 5
 ICD 6
 ICD 7
 ICD 8
 ICD 9
 ICD 10
 ICD 11
 ICD 12
 ICD 13
.balign 8
ic_pay:
 .space 14720                     /* v0.25: 14 pictures (build.py checks the fit; A-B / G-M, Frame blank now) */
ic_pend:

/* st_chk <- jmp from 0x611b201b (bar setup, a3 = the bar, (16,sp) -> its id): the bar's +116 says whether the arrows
 * stop at the ends (1) or wrap around (0); the camera sets 1 for the ids in its table 0x6152d520 (239 u16 ids, 904
 * Sharpness among them). Camera test 9: Blacks / Whites went from +5 round to -5. Our BKB / WHB ids: 1, then on past
 * the table search (0x611b2041, a0 = +116 kept). Else as stock: +116 = 0, the search from d0 = 0 (0x611b2021). */
st_chk:
 mov 116,a0
 add a3,a0
 mov (16,sp),a1
 movhu (a1),d0
 add -BKB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -WHB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -ABB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -GMB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -GLB,d0
 cmp 4,d0
 bcs 1f
 clr d0
 mov d0,(a0)
 jmp stp_back
1:
 mov 1,d0
 mov d0,(a0)
 jmp stp_end

/* rd_a / rd_b <- jmp from 0x611d16b4 / 0x611d1725 (the readout glyph lookups, d0 = item): 1011, 5397 (stock) and
 * Blacks / Whites take the 11-entry -5..+5 tables (0x611d16e6 / 0x611d1757), else none (0x611d16ee / 0x611d175f). */
rd_a:
 cmp AB_IT,d0                     /* A-B / G-M: our -7..+7 tables (sign, digit) into the stock search loop */
 beq 7f
 cmp GM_IT,d0
 bne 8f
7:
 mov rd15_a,a0
 mov 15,d3
 jmp rda_none
8:
 cmp 1011,d0
 beq 1f
 cmp 5397,d0
 beq 1f
 cmp BK_IT,d0
 beq 1f
 cmp WH_IT,d0
 beq 1f
 cmp GL_IT,d0
 beq 1f
 cmp 5399,d0                      /* v0.25 Shading: these glyphs, in line with its picture (owner: its number sat low) */
 beq 1f
 jmp rda_none
1:
 jmp rda_11
rd_b:
 cmp AB_IT,d0
 beq 7f
 cmp GM_IT,d0
 bne 8f
7:
 mov rd15_b,a0
 mov 15,d3
 jmp rdb_none
8:
 cmp 1011,d0
 beq 1f
 cmp 5397,d0
 beq 1f
 cmp BK_IT,d0
 beq 1f
 cmp WH_IT,d0
 beq 1f
 cmp GL_IT,d0
 beq 1f
 cmp 5399,d0                      /* v0.25 Shading (as rd_a) */
 beq 1f
 jmp rdb_none
1:
 jmp rdb_11

.balign 4
rd15_a:                           /* the readout's sign glyph for -7..+7 (as 0x6154caa0: 3 minus, 1 plus-minus, 2 plus) */
 .long -7, 3, -6, 3, -5, 3, -4, 3, -3, 3, -2, 3, -1, 3, 0, 1, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2, 6, 2, 7, 2
rd15_b:                           /* ... and its digit (as 0x6154caf8) */
 .long -7, 7, -6, 6, -5, 5, -4, 4, -3, 3, -2, 2, -1, 1, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7

/* sl_dot <- jmp from 0x611d10fb (same frame; a2 value, a3 min): the dot's x = centre (d2) + d1, stock value x 155 px
 * (a -2..+2 bar). The Sharp bar (min -5, from sl_rng) is split at 0, which stays on the centre mark: below 0 it steps
 * 62 px (-5 at the left end, like Shading's bar), above 0 the stock 155 px (+2 at the right end). Camera test 2: one
 * step size for the whole bar left +2 short of the end. */
sl_dot:
 mov (8,sp),a0
 mov a2,d1
 mov 44,d0                        /* A-B / G-M bar (min -7): 44 px a step (+-7 near the ends) */
 cmp -7,a3
 beq 1f
 mov 155,d0
 cmp -5,a3
 bne 1f
 mov (4,sp),d0                    /* max: 5 = Blacks / Whites (62 px a step, like Shading), 2 = Sharp */
 cmp 5,d0
 beq 2f
 cmp 0,a2
 bge 3f
2:
 mov 62,d0
 bra 1f
3:
 mov 155,d0
1:
 mul d0,d1
 jmp dot_back                     /* 0x611d1103: add d1,d2 */

/* ------------------------------------------------------------------ v0.24 film list (test 1)
 * The Picture Mode list on the COLOR position shows COLOR 1-4 and then every film (look) on the card, by name.
 * The list is setting 901's value table (0x6152f8a0: {setting, count, records}; COLOR 1-4 = 4 records of 20 B at
 * 0x6152f850 {value, availability id, value, 0, 0}). build.py points 901 at fl_rec (the stock four, then FV0 + j) and
 * item 111's three option lists (title, left column, strip) at fl_l0 / fl_l1 / fl_l2 (the stock 48, then type-4
 * strings ST_F0 + j). A film value is never stored: choosing it sets COLOR k and its look number (as the Film page),
 * and only the list and the left column (GetValue 901 from 0x611b32ae / 0x611d1869) read the film value back. */
.balign 4
fl_rec:
 .long 54, 1072, 54, 0, 0         /* the stock four (build.py checks them) */
 .long 55, 1073, 55, 0, 0
 .long 56, 1074, 56, 0, 0
 .long 64, 1075, 64, 0, 0
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .long FV0 + \j, FLB + \j, FV0 + \j, 0, 0
 .endr
 .macro FLOPT base
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .long FV0 + \j
 .short 4, \base + \j
 .long 0x6154b480
 .endr
 .endm
fl_l0:                            /* item 111's title list: the stock 48 (build.py), then the films */
 .space 48 * 12
 FLOPT ST_F0
fl_l1:                            /* the left column */
 .space 48 * 12
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .long FV0 + \j
 .short 3, IC_FL0 + \j
 .long 0x6154b480
 .endr
fl_l2:                            /* the strip */
 .space 48 * 12
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .long FV0 + \j
 .short 3, IC_FM0 + \j
 .long 0x6154b480
 .endr
fl_rtab:                          /* the held-OK reset's {picture mode, row count, rows} table (stock 0x61536324, 8
                                   * entries: MONO / COLOR 1-4), then the films with COLOR's rows (film test 4) */
 .space 8 * 8
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .short FV0 + \j, 1
 .long fl_rrow
 .endr
fl_rrow:                          /* a film: only the wheel row gets the event (its handler loads the whole film; the
                                   * stock rows would put their own settings back to the factory values after it) */
 .long 5397
fl_cvt:                           /* COLOR k -> picture mode value */
 .byte 54, 55, 56, 64
.balign 2
fl_none:                          /* "Film" (no bank) */
 .short 70, 105, 108, 109, 0

/* fl_k: `call fl_k,[],0`, d0 picture mode -> d0 COLOR k 0..3, else -1. */
fl_k:
 cmp 54,d0
 bne 1f
 clr d0
 ret [],0
1:
 cmp 55,d0
 bne 2f
 mov 1,d0
 ret [],0
2:
 cmp 56,d0
 bne 3f
 mov 2,d0
 ret [],0
3:
 cmp 64,d0
 bne 4f
 mov 3,d0
 ret [],0
4:
 mov -1,d0
 ret [],0

/* fl_has: `call fl_has,[],0`, d0 film j 0..19, a0 the LOOKS.BIN copy -> d0 1 when it has a name or any non-zero
 * byte (as the Control Panel's Empty), else 0. Uses d1, a1. */
fl_has:
 mov d0,d1
 asl 4,d1
 mov a0,a1
 add d1,a1
 movbu (1312,a1),d1
 cmp 0,d1
 bne 3f
 mov d0,d1
 asl 6,d1
 mov a0,a1
 add d1,a1
 add 32,a1
 mov 64,d1
1:
 movbu (a1),d0
 cmp 0,d0
 bne 3f
 inc a1
 add -1,d1
 bne 1b
 clr d0
 ret [],0
3:
 mov 1,d0
 ret [],0

/* fl_get <- sl_get (CALLS: d0 id, a0 facade, a1 out != 0, mdr return): FLB + j -> 1 / 0 (film j there?); 901 asked
 * by the list builder (0x611b32ae) while COLOR k has look n -> FV0 + 5k + n - 1.
 * Anything else: back to sl_gb with the registers as at entry. Stores: (a1), own frame. */
fl_get:
 movm [d2,d3,a2,a3],(sp)
 add -20,sp                       /* (0) call slot, (4) return, (8) a0, (12) a1, (16) d0 */
 mov mdr,d1
 mov d1,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 mov d0,(16,sp)
 mov d0,d2
 exthu d2
 PVAL 8f
 mov (LPTR,a2),a3
 cmp 0,a3
 beq 8f
 cmp 901,d2
 beq 1f
 cmp 111,d2                       /* film test 6: the Picture Mode row's left cell (0x611d08f4) shows the film too */
 bne 12f
 mov (4,sp),d1
 cmp 0x611d08f4,d1
 beq fl_g2
 cmp 0x611c6e79,d1                /* sd3: the super control panel's dial step (0x611c6e44) reads where it is: the film, so the next is the next film */
 beq fl_g2
 bra 8f
12:
 add -FLB,d2
 cmp NF,d2
 bcc 8f
 mov d2,d0
 mov a3,a0
 call fl_has,[],0
 bra 7f
1:
 mov (4,sp),d1
 cmp 0x611b32ae,d1                /* only the list builder (film test 4: 0x611d1869 is the "COLOR k changed?" check */
 bne 8f                           /* behind the Reset guide and the held-OK reset: it must see COLOR k) */
fl_g2:
 mov 111,d0
 call sget,[],4                   /* the picture mode (keeps d2, d3, a2, a3) */
 call fl_k,[],0
 cmp 0,d0
 blt 8f
 mov d0,d2                        /* k */
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d1
 extb d1
 cmp 1,d1
 blt 8f
 cmp 5,d1
 bgt 8f
 mov d2,d0
 asl2 d0
 add d2,d0
 add d1,d0
 add -1,d0                        /* j = 5k + n - 1 */
 mov d0,d2
 mov a3,a0
 call fl_has,[],0
 cmp 0,d0
 beq 8f
 mov d2,d0
 add FV0,d0
7:
 mov (12,sp),a1
 mov d0,(a1)
 mov (4,sp),d1
 mov d1,mdr
 add 20,sp
 movm (sp),[d2,d3,a2,a3]
 clr d0
 rets
8:
 mov (4,sp),d1
 mov d1,mdr
 mov (8,sp),a0
 mov (12,sp),a1
 mov (16,sp),d0
 add 20,sp
 movm (sp),[d2,d3,a2,a3]
 jmp sl_gb

/* fl_sel <- sl_sel (d0 901, d1 value >= FV0, a0; CALLS) -> d0 1 when film value - FV0 is there, else 0. */
fl_sel:
 movm [d2,d3,a2,a3],(sp)
 add -4,sp
 PVAL 8f
 mov mdr,d3
 mov (LPTR,a2),a0
 cmp 0,a0
 beq 8f
 add -FV0,d1
 cmp NF,d1
 bcc 8f
 mov d1,d0
 call fl_has,[],0
 mov d3,mdr
 bra 9f
8:
 clr d0
9:
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 rets

/* fl_set <- sl_set (as the settings manager: d0 901, d1 value, a0 inner, a1 mode; d2/d3/a2/a3 saved by the call,
 * frame 68, its return address at (68,sp)). A film FV0 + j: COLOR k = j / 5 gets look n = j % 5 + 1 (pf_put, as the
 * Film page), then the manager sets the picture mode to COLOR k. COLOR k itself: look 0 (none), then the manager.
 * A film that is not there -> refused. Stores: P+LIDX+k, P+DIRTY, the camera settings (pf_put), own frame. */
fl_set:
 PVAL 9f
 mov (LPTR,a2),a3
 cmp 0,a3
 beq 9f
 add -28,sp                       /* (0) call slot, (4) d0, (8) a0, (12) a1, (16) k, (20) n, (24) d1 */
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 mov d1,(24,sp)
 cmp FV0,d1
 bge 1f
 mov d1,d0                        /* COLOR k itself: no look */
 call fl_k,[],0
 cmp 0,d0
 blt 6f
 mov d0,(16,sp)
 clr d0
 mov d0,(20,sp)
 bra 3f
1:
 add -FV0,d1
 cmp NF,d1
 bcc 5f
 mov d1,(20,sp)
 mov d1,d0
 mov a3,a0
 call fl_has,[],0
 cmp 0,d0
 beq 5f
 mov (20,sp),d1
 clr d0
2:
 cmp 5,d1
 bcs 21f
 add -5,d1
 inc d0
 bra 2b
21:
 inc d1
 mov d0,(16,sp)                   /* k */
 mov d1,(20,sp)                   /* n */
3:
 mov (16,sp),d2
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp 1,d0
 blt 31f
 cmp 5,d0
 ble 32f
31:
 clr d0
32:
 mov (20,sp),d3
 movbu d3,(LIDX,a0)
 cmp d0,d3
 beq 4f
 mov (8,sp),a0
 mov (12,sp),a1
 call fl_sw,[d2,d3,a2,a3],40      /* the film being left keeps its changes; the look (0: neutral) into the slot */
 mov 1,d1
 movbu d1,(DIRTY,a2)
 movbu d1,(fl_scf)                /* sd3: the super control panel draws its cell again (fl_scw) */
 movbu d1,(fl_scf + 1)            /* ... and its title (fl_stw) */
4:
 mov (16,sp),d0
 mov fl_cvt,a0
 add d0,a0
 movbu (a0),d1                    /* COLOR k's picture mode */
 bra 7f
6:
 mov (24,sp),d1                   /* not COLOR: as stock */
7:
 mov (4,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 add 28,sp
 mov (68,sp),d2
 mov d2,mdr
 jmp manager
5:
 add 28,sp
 jmp s_bad
9:
 cmp FV0,d1
 blt 91f
 jmp s_bad
91:
 jmp manager

/* fl_str <- st_get (the string getter's frame: ret [d2],8; d0 = ST_F0 + j): film j's name as UTF-16 in its own
 * buffer after the LOOKS.BIN copy; a film without a name reads "Look n" (n = j + 1); no bank -> "Film". */
fl_str:
 add -8,sp
 mov d3,(0,sp)
 mov a2,(4,sp)
 mov d0,d2
 add -ST_F0,d2                    /* j (ST_N0 + j: + 32) */
 PVAL 8f
 mov (LPTR,a2),a0
 cmp 0,a0
 beq 8f
 cmp NF,d2
 bcs 10f
 add -(ST_N0 - ST_F0),d2
 jmp fl_lbl
10:
 mov d2,d1
 asl 5,d1
 add d2,d1
 add d2,d1                        /* 34 j */
 mov a0,a1
 add d1,a1
 add PF_LEN,a1                    /* out */
 mov d2,d1
 asl 4,d1
 add d1,a0
 add 1312,a0                      /* name */
 mov a1,a2                        /* keep the start */
 movbu (a0),d0
 cmp 0,d0
 beq 4f
 mov 15,d1
1:
 movbu (a0),d0
 cmp 0,d0
 beq 3f
 movhu d0,(a1)
 inc a0
 add 2,a1
 add -1,d1
 bne 1b
 bra 3f
4:                                /* "Look n" */
 mov 76,d0
 movhu d0,(a1)
 mov 111,d0
 movhu d0,(2,a1)
 movhu d0,(4,a1)
 mov 107,d0
 movhu d0,(6,a1)
 mov 32,d0
 movhu d0,(8,a1)
 add 10,a1
 inc d2                           /* n = j + 1 (1..20) */
 cmp 10,d2
 bcs 5f
 mov 49,d0                        /* "1" */
 cmp 20,d2
 bcs 6f
 mov 50,d0                        /* "2" */
 add -10,d2
6:
 add -10,d2
 movhu d0,(a1)
 add 2,a1
5:
 add 48,d2
 movhu d2,(a1)
 add 2,a1
3:
 clr d0
 movhu d0,(a1)
 mov a2,a0
 bra fl_sx
8:
 mov fl_none,a0
fl_sx:
 mov (0,sp),d3
 mov (4,sp),a2
 add 8,sp
 ret [d2],8

/* fl_lbl <- fl_str (its frame; d2 = j, a0 = the LOOKS.BIN copy): film j's cell label "FILM", a line break and its
 * number among the films there (1 = the first after COLOR 4), into its label buffer. Then fl_sx (a0 = the string). */
fl_lbl:
 mov a0,a2                        /* the LOOKS.BIN copy */
 add -12,sp                       /* (0) call slot, (4) i, (8) j */
 mov d2,(8,sp)
 clr d3                           /* films before j */
 clr d0
 mov d0,(4,sp)
1:
 mov (4,sp),d0
 mov (8,sp),d1
 cmp d1,d0
 bcc 2f
 mov a2,a0
 call fl_has,[],0
 add d0,d3
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 bra 1b
2:
 inc d3                           /* n = 1.. */
 mov (8,sp),d2
 mov d2,d1
 asl 5,d1
 add d2,d1
 add d2,d1                        /* 34 j */
 mov a2,a1
 add d1,a1
 add PF_LEN + NF * 34,a1          /* out */
 mov a1,a2                        /* keep the start */
 mov 70,d0                        /* "Film " */
 movhu d0,(a1)
 mov 105,d0
 movhu d0,(2,a1)
 mov 108,d0
 movhu d0,(4,a1)
 mov 109,d0
 movhu d0,(6,a1)
 mov 32,d0
 movhu d0,(8,a1)
 add 10,a1
 cmp 10,d3
 bcs 5f
 mov 49,d0                        /* "1" */
 cmp 20,d3
 bcs 6f
 mov 50,d0                        /* "2" */
 add -10,d3
6:
 add -10,d3
 movhu d0,(a1)
 add 2,a1
5:
 add 48,d3
 movhu d3,(a1)
 clr d0
 movhu d0,(2,a1)
 mov a2,a0
 add 12,sp
 jmp fl_sx

/* ------------------------------------------------------------------ v0.24 film cells (film test 2)
 * The list cell of film j is "FILM" over its number among the films there (1 = the first after COLOR 4), in the stock
 * "COLOR / 1" cell's size and style (firmware/mkicons.py, our own font). fl_mk draws the 20 pictures once, when the
 * films load (pf_load, HLS task): each row from fl_top (the "FILM" line, rows 0..39) or from the digit pictures fl_dig
 * (rows 40..75; one digit centred at x 40, two at x 31 and 49), then runs of up to 16 pixels (not past the row's end)
 * as OSD type-11 tokens, five to a 64-bit word. Heap: up to 3 blocks of FL_BLK; block 0 starts with 20 slot words
 * and 20 descriptors <6H3I>. P+TTAB = the slot words (0 = none). ic_get answers IC_FM0 + j through fl_ic. */
 .include "films.inc"             /* fl_top (100 x 40), fl_dig (10 x 20 x 36), 4 bits a pixel, low nibble first */

/* fl_emit: `call fl_emit,[],0` from fl_mk (its frame: (24) out, (32) tokens in the word, (36) / (40) the word),
 * d0 = token. Uses d0, d1, a0. */
fl_emit:
 mov (32,sp),d1
 cmp 0,d1
 bne 1f
 mov d0,(36,sp)
 bra 8f
1:
 cmp 1,d1
 bne 2f
 asl 12,d0
 mov (36,sp),d1
 or d0,d1
 mov d1,(36,sp)
 bra 8f
2:
 cmp 2,d1
 bne 3f
 mov d0,d1
 lsr 8,d1
 mov d1,(40,sp)
 asl 24,d0
 mov (36,sp),d1
 or d0,d1
 mov d1,(36,sp)
 bra 8f
3:
 cmp 3,d1
 bne 4f
 asl 4,d0
 mov (40,sp),d1
 or d0,d1
 mov d1,(40,sp)
 bra 8f
4:
 asl 16,d0
 mov (40,sp),d1
 or d0,d1
 mov (24,sp),a0
 mov (36,sp),d0
 mov d0,(a0)
 mov d1,(4,a0)
 add 8,a0
 mov a0,(24,sp)
 clr d0
 mov d0,(36,sp)
 mov d0,(40,sp)
 mov -1,d1
 mov d1,(32,sp)
8:
 mov (32,sp),d1
 inc d1
 mov d1,(32,sp)
 ret [],0

/* fl_dg2: `call fl_dg2,[],0` from fl_rc (its frame: (4) the layout, (28) row y), d0 digit, d1 x: the digit's row
 * (y - top rows) onto the row; a digit pixel replaces a clear or edge pixel. Uses d0..d3, a0, a1. */
fl_dg2:
 mov (4,sp),a0
 mov (28,a0),d2                   /* bytes a digit */
 mul d0,d2
 mov (28,sp),d0
 mov (8,a0),d3                    /* top rows */
 sub d3,d0
 mov (24,a0),d3                   /* bytes a digit row */
 mul d0,d3
 add d3,d2
 mov (20,a0),d0                   /* the digits */
 add d2,d0
 mov (24,a0),d3
 mov d0,a0
 mov sp,a1
 add ROW,a1
 add d1,a1
1:
 movbu (a0),d2
 mov d2,d0
 and 15,d0
 cmp 0,d0
 beq 2f
 movbu (a1),d1
 cmp 0,d1
 beq 3f
 cmp 7,d1
 bne 2f
3:
 movbu d0,(a1)
2:
 lsr 4,d2
 cmp 0,d2
 beq 4f
 movbu (1,a1),d1
 cmp 0,d1
 beq 5f
 cmp 7,d1
 bne 4f
5:
 movbu d2,(1,a1)
4:
 inc a0
 add 2,a1
 add -1,d3
 bne 1b
 ret [],0

/* film cell layouts (film test 8): {width, height, top rows, stream header, top picture, digit pictures, bytes a digit
 * row, bytes a digit, x of one digit, x of the first / second of two}; firmware/mkicons.py film_cell / film_lcell */
.balign 4
fl_L0:                            /* the list cell, 100 x 76 */
 .long 100, 76, 40, 0x0b06304b, fl_top, fl_dig, FDB, FDS, FX1, FX2, FX2B
fl_L1:                            /* the list cell of a changed film: "FILM*" */
 .long 100, 76, 40, 0x0b06304b, fl_tops, fl_dig, FDB, FDS, FX1, FX2, FX2B
fl_L2:                            /* the row's left cell, 82 x 62 */
 .long 82, 62, 30, 0x0b05103d, fl_ltop, fl_ldig, LDB, LDS, LX1, LX2, LX2B

/* fl_rc: `call fl_rc,[d2,d3,a2,a3],200`, a0 = a layout, d0 = the number 1..20, a1 = out -> d0 = the bytes written:
 * the cell as OSD type 11 (each row from the top picture or the digits, then runs of up to 16 pixels, not past the
 * row's end, five tokens to a 64-bit word: fl_emit). Frame: (0) call slot, (4) layout, (8) number, (12) units digit,
 * (24) out, (28) y, (32) / (36) / (40) the token word, (44) start, (52) width, (ROW) the row. */
fl_rc:
 mov a0,(4,sp)
 mov d0,(8,sp)
 mov a1,(44,sp)
 mov (a0),d0
 mov d0,(52,sp)
 mov (12,a0),d0                   /* the header */
 mov d0,(a1)
 add 4,a1
 mov a1,(24,sp)
 clr d0
 mov d0,(32,sp)
 mov d0,(36,sp)
 mov d0,(40,sp)
 mov d0,(28,sp)
10:                               /* row y */
 mov (4,sp),a0
 mov (28,sp),d0
 mov (8,a0),d1
 cmp d1,d0
 bcc 25f
 mov (52,sp),d2                   /* the top: its row y, two pixels a byte */
 lsr 1,d2
 mov d2,d1
 mul d0,d1
 mov (16,a0),d3
 add d1,d3
 mov d3,a0
 mov sp,a1
 add ROW,a1
21:
 movbu (a0),d0
 mov d0,d1
 and 15,d1
 movbu d1,(a1)
 lsr 4,d0
 movbu d0,(1,a1)
 inc a0
 add 2,a1
 add -1,d2
 bne 21b
 bra 30f
25:                               /* the number */
 mov (52,sp),d2
 mov sp,a1
 add ROW,a1
 clr d1
26:
 movbu d1,(a1)
 inc a1
 add -1,d2
 bne 26b
 mov (8,sp),d0
 cmp 10,d0
 bcc 27f
 mov (4,sp),a0
 mov (32,a0),d1
 call fl_dg2,[],0
 bra 30f
27:
 clr d1
28:
 cmp 10,d0
 bcs 29f
 add -10,d0
 inc d1
 bra 28b
29:
 mov d0,(12,sp)
 mov d1,d0
 mov (4,sp),a0
 mov (36,a0),d1
 call fl_dg2,[],0
 mov (12,sp),d0
 mov (4,sp),a0
 mov (40,a0),d1
 call fl_dg2,[],0
30:                               /* the row as runs: a1 the pixel, a2 the row's end */
 mov sp,a1
 add ROW,a1
 mov a1,a2
 mov (52,sp),d0
 add d0,a2
31:
 cmp a2,a1
 bcc 39f
 movbu (a1),d3
 mov 1,d1
 mov a1,a0
 inc a0
32:
 cmp 16,d1
 bcc 33f
 cmp a2,a0
 bcc 33f
 movbu (a0),d0
 cmp d3,d0
 bne 33f
 inc d1
 inc a0
 bra 32b
33:
 add d1,a1
 mov d3,d0
 asl 4,d0
 add d1,d0
 add -1,d0
 call fl_emit,[],0                /* keeps d3, a1, a2 */
 bra 31b
39:
 mov (28,sp),d0
 inc d0
 mov d0,(28,sp)
 mov (4,sp),a0
 mov (4,a0),d1
 cmp d1,d0
 bcc 40f
 jmp 10b
40:
 mov (32,sp),d0                   /* the last word */
 cmp 0,d0
 beq 41f
 mov (24,sp),a0
 mov (36,sp),d1
 mov d1,(a0)
 mov (40,sp),d1
 mov d1,(4,a0)
 add 8,a0
 mov a0,(24,sp)
41:
 mov (24,sp),d0
 mov (44,sp),d1
 sub d1,d0
 ret [d2,d3,a2,a3],200

/* fl_desc: `call fl_desc,[],0`, a1 = descriptor, a0 = layout, d0 = bytes, d1 = payload: the descriptor <6H3I> 14,
 * width, height, 8, 0, 0, size, payload, 0. Uses d0, d1. */
fl_desc:
 mov d0,(12,a1)
 mov d1,(16,a1)
 mov 14,d0
 movhu d0,(a1)
 mov (a0),d0
 movhu d0,(2,a1)
 mov (4,a0),d0
 movhu d0,(4,a1)
 mov 8,d0
 movhu d0,(6,a1)
 clr d0
 movhu d0,(8,a1)
 movhu d0,(10,a1)
 mov d0,(20,a1)
 ret [],0

/* fl_mk: `call fl_mk,[d2,d3,a2,a3],80` from pf_load, a2 = P: the 20 list cells (fl_rc, layout fl_L0) into heap blocks
 * of FL_BLK (block 0 starts with 20 slot words and 20 descriptors), P+TTAB; the cell cache (fl_cget) block, P+STC; the
 * quick menu block with the EDITS.BIN image, P+TORG. Frame: (0) call slot, (4) block cursor, (8) block end, (12)
 * blocks, (16) n, (20) block 0, (52) P, (56) / (60) / (64) EDITS.BIN load. Stores: the heap blocks, P+TTAB / STC /
 * TORG, own frame. */
fl_mk:
 mov a2,(52,sp)
 mov FL_BLK,d0
 call malloc,[],4
 cmp 0,a0
 bne 1f
 jmp 90f
1:
 mov a0,(20,sp)
 mov a0,d0
 add FL_BLK,d0
 mov d0,(8,sp)
 mov 1,d0
 mov d0,(12,sp)
 mov 20,d1
 clr d0
2:
 mov d0,(a0)                      /* slot words 0 */
 add 4,a0
 add -1,d1
 bne 2b
 mov (20,sp),a0
 add 20 * 4 + 20 * 24,a0
 mov a0,(4,sp)
 mov 1,d0
 mov d0,(16,sp)
10:                               /* cell n */
 mov (8,sp),d0
 mov (4,sp),d1
 sub d1,d0
 cmp 2400,d0
 bge 11f
 mov (12,sp),d0
 cmp 3,d0
 bcs 12f
 jmp 20f
12:
 mov FL_BLK,d0
 call malloc,[],4
 cmp 0,a0
 bne 13f
 jmp 20f
13:
 mov a0,(4,sp)
 mov a0,d0
 add FL_BLK,d0
 mov d0,(8,sp)
 mov (12,sp),d0
 inc d0
 mov d0,(12,sp)
11:
 mov fl_L0,a0
 mov (16,sp),d0
 mov (4,sp),a1
 call fl_rc,[d2,d3,a2,a3],200
 mov d0,d2                        /* bytes */
 mov (16,sp),d1
 add -1,d1
 mov d1,d3
 asl 4,d1
 asl 3,d3
 add d3,d1                        /* 24 (n - 1) */
 mov (20,sp),a1
 add 80,a1
 add d1,a1
 mov fl_L0,a0
 mov d2,d0
 mov (4,sp),d1
 call fl_desc,[],0
 mov (16,sp),d0
 add -1,d0
 asl2 d0
 mov (20,sp),a0
 add d0,a0
 mov a1,(a0)                      /* slot word -> descriptor */
 mov (4,sp),d0
 add d2,d0
 add 7,d0
 and 0xfffffff8,d0
 mov d0,(4,sp)
 mov (16,sp),d0
 inc d0
 mov d0,(16,sp)
 cmp 21,d0
 bcc 20f
 jmp 10b
20:
 mov (52,sp),a2
 mov (20,sp),d0
 mov d0,(TTAB,a2)                 /* published */
 mov CC_BLK,d0                    /* the cell cache */
 call malloc,[],4
 cmp 0,a0
 beq 90f
 clr d0
 mov d0,(a0)                      /* next victim */
 mov a0,a1
 add 228,a1
 mov 8,d1
21:
 mov d0,(a1)                      /* keys: empty */
 add 4,a1
 add -1,d1
 bne 21b
 mov (52,sp),a2
 mov a0,(STC,a2)
 mov SAT_LEN,d0                   /* film test 8: the Saturation page's pictures, into the heap (gd_sel) */
 call malloc,[],4
 cmp 0,a0
 beq 90f
 mov SLS,d0
 mov d0,(a0)
 mov SGS,d0
 mov d0,(4,a0)
 mov a0,a1
 add 8,a1
 mov fl_slab,a2
 mov SAT_LEN - 8,d1
22:
 movbu (a2),d0
 movbu d0,(a1)
 inc a1
 inc a2
 add -1,d1
 bne 22b
 mov (52,sp),a2
 mov a0,(SATB,a2)
 mov LV_BLK,d0                    /* film test 9: the shooting screen's "FILM N" block, no pictures yet */
 call malloc,[],4
 cmp 0,a0
 beq 90f
 clr d0
 mov 128 / 4,d1
 mov a0,a1
23:
 mov d0,(a1)
 add 4,a1
 add -1,d1
 bne 23b
 mov (52,sp),a2
 mov a0,(LVB,a2)
90:
 mov SP_BLK,d0                    /* the quick menu's pictures (fl_scp) and the EDITS.BIN image */
 call malloc,[],4
 cmp 0,a0
 bne 91f
 jmp 99f
91:
 mov a0,a1                        /* v0.26.2: the whole block zeroed (the heap does not: record bytes that were never written kept what the memory held) */
 mov SP_BLK / 4,d1
 clr d0
97:
 mov d0,(a1)
 add 4,a1
 add -1,d1
 bne 97b
 mov a0,a1
 mov d0,(a1)
 mov d0,(4,a1)
 mov d0,(8,a1)
 mov d0,(12,a1)
 add 16 + 4 * 24,a1
 mov d0,(a1)
 mov d0,(4,a1)
 mov d0,(8,a1)
 mov d0,(12,a1)
 mov a0,(56,sp)                   /* the block */
 add TWO,a0
 mov a0,(60,sp)                   /* the EDITS.BIN image: none valid until read */
 mov d0,(12,a0)
 movbu d0,(TW_LEN,a0)
 movbu d0,(TW_LEN + 1,a0)
 mov tw_path,a0
 mov sd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 95f
 mov a0,(64,sp)
 mov (60,sp),a0
 mov 1,d0
 mov TW_LEN,d1
 mov (64,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov (64,sp),a0
 call fclose,[d2,a2,a3],16
 cmp TW_LEN,d2
 bne 94f
 mov (60,sp),a3
 mov (a3),d0
 cmp TWMAGIC,d0
 bne 94f
 mov (4,a3),d0
 cmp TW_LEN,d0
 bne 94f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov TW_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d0,d1
 beq 96f
94:
 mov (60,sp),a0                   /* a bad file: nothing valid */
 clr d0
 mov d0,(12,a0)
 bra 95f
96:
 mov (60,sp),a0                   /* v0.26.2: a good file: out-of-range split toning in its records <- 0 */
 call tw_san,[d2,a2],12
95:
 mov (56,sp),a0
 mov (52,sp),a2
 mov a0,(TORG,a2)
99:
 mov (52,sp),a2
 ret [d2,d3,a2,a3],80

/* fl_cget: `call fl_cget,[d2,d3,a2,a3],40`, a2 = P, d0 = key (kind << 8 | n: kind 1 "FILM*" list cell, 2 left cell)
 * -> a0 = its slot word (0: none). P+STC block: (0) next victim, (4) 8 slot words, (36) 8 descriptors, (228) 8 keys,
 * (264) 8 pictures of CC_SLOT; a miss draws into the next slot round robin (8 >= the cells on screen at once).
 * Locals (4) key, (8) the picture, (12) layout. */
fl_cget:
 mov d0,(4,sp)
 mov (STC,a2),a3
 cmp 0,a3
 beq 9f
 clr d2
1:
 mov d2,d1
 asl2 d1
 mov a3,a0
 add 228,a0
 add d1,a0
 mov (a0),d1
 mov (4,sp),d0
 cmp d0,d1
 beq 5f
 inc d2
 cmp 8,d2
 bcs 1b
 mov (a3),d2                      /* miss: the next slot */
 mov d2,d0
 inc d0
 and 7,d0
 mov d0,(a3)
 mov CC_SLOT,d1
 mul d2,d1
 mov a3,a1
 add 264,a1
 add d1,a1
 mov a1,(8,sp)
 mov (4,sp),d0
 lsr 8,d0
 mov fl_L1,a0
 cmp 1,d0
 beq 2f
 mov fl_L2,a0
2:
 mov a0,(12,sp)
 mov (4,sp),d0
 and 0xff,d0
 call fl_rc,[d2,d3,a2,a3],200     /* keeps d2, a3 */
 mov d2,d1
 asl 3,d1
 mov a3,a1
 add 36,a1
 add d1,a1
 add d1,a1
 add d1,a1
 mov (12,sp),a0
 mov (8,sp),d1
 call fl_desc,[],0
 mov d2,d1
 asl2 d1
 mov a3,a0
 add 4,a0
 add d1,a0
 mov a1,(a0)
 mov a3,a0
 add 228,a0
 add d1,a0
 mov (4,sp),d0
 mov d0,(a0)
5:
 mov d2,d1
 asl2 d1
 mov a3,a0
 add 4,a0
 add d1,a0
 ret [d2,d3,a2,a3],40
9:
 mov 0,a0
 ret [d2,d3,a2,a3],40

/* fl_ic <- ic_get (d0 / d1 = IC_FM0 + j, the list cell, or IC_FL0 + j, the row's left cell; returns as ic_get: a0 =
 * the slot word, or 0): film j's number among the films there picks its picture; a list cell of a film changed from
 * how it was built (fl_fch) gets the "FILM*" one (slot 20 + n - 1) when it was drawn. Saves mdr (retf). */
fl_ic:
 movm [d2,d3,a2,a3],(sp)
 add -16,sp                       /* (0) call slot, (4) i, (8) the return address, (12) star allowed */
 mov mdr,d0
 mov d0,(8,sp)
 mov d1,d2
 clr d0
 cmp IC_FL0,d2
 bcs 1f
 add -(IC_FL0 - IC_FM0),d2
 bra 2f
1:
 mov 1,d0
2:
 mov d0,(12,sp)
 add -IC_FM0,d2                   /* j */
 cmp NF,d2
 bcc 8f
 PVAL 8f
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 8f
 mov (TTAB,a2),a3
 cmp 0,a3
 beq 8f
 clr d3
 clr d0
 mov d0,(4,sp)
3:
 mov (4,sp),d0
 cmp d2,d0
 bcc 4f
 mov (LPTR,a2),a0
 call fl_has,[],0
 add d0,d3
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 bra 3b
4:                                /* d3 = n - 1 */
 mov (12,sp),d0
 cmp 0,d0
 bne 41f
 mov d3,d0                        /* the row's left cell: the small cell (cache kind 2) */
 inc d0
 add 0x200,d0
 call fl_cget,[d2,d3,a2,a3],40
 cmp 0,a0
 bne 9f
 bra 8f
41:
 mov d2,d0
 call fl_fch,[d2,d3,a2,a3],28
 cmp 0,d0
 beq 6f
 mov d3,d0                        /* a changed film: "FILM*" (cache kind 1) */
 inc d0
 add 0x100,d0
 call fl_cget,[d2,d3,a2,a3],40
 cmp 0,a0
 bne 9f
6:
 asl2 d3
 mov a3,a0
 add d3,a0
 mov (a0),d0
 cmp 0,d0
 bne 9f
8:
 mov 0,a0
9:
 mov (8,sp),d0
 mov d0,mdr
 add 16,sp
 movm (sp),[d2,d3,a2,a3]
 retf [],0

/* ------------------------------------------------------------------ v0.24 film test 3 / 4
 * Changes are kept apart from the films as built: EDITS.BIN (C:\OM3MOD, written by the camera) holds record r = film j
 * (r = j, 0..19) or COLOR k's own settings (r = 20 + k), LOOKS.BIN format, each with a check (films: CRC-32 of the
 * LOOKS.BIN record it was made from; a film rebuilt in the Control Panel drops its old changes) and a valid bit.
 * fl_sw: `call fl_sw,[d2,d3,a2,a3],40` in place of pf_put's call (same frame and registers: a2 = P, d2 = k, d3 = the
 * new look 0..5, a0 / a1 the SetValue's inner / mode), d0 = the old look 0..5. What COLOR k is leaving (its own
 * settings for look 0, else that film) <- COLOR k now (pf_capto), then the new one loads: its saved changes when
 * valid, else the film as built (pf_put; look 0 without saved settings: the factory settings). A film reset skips
 * one capture (flag). Locals (4) a0, (8) a1, (12) new, (16) old / r, (20) the record (the rest of the frame is
 * pf_put's). Stores: the EDITS.BIN image, P+DIRTY, then pf_put's. */
fl_sw:
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov d3,(12,sp)
 mov d0,(16,sp)
 mov (TORG,a2),a3
 cmp 0,a3
 bne 10f
 jmp 90f
10:
 add TWO,a3
 cmp 0,d0                         /* 1. what is being left */
 bne 2f
 movbu (TW_LEN + 1,a3),d1
 cmp 0,d1
 beq 1f
 clr d1
 movbu d1,(TW_LEN + 1,a3)         /* a film reset: no capture */
 bra 5f
1:
 mov d2,d0
 add 20,d0                        /* COLOR k's own */
 bra 3f
2:
 cmp 5,d0
 bgt 5f
 mov d2,d1
 asl2 d1
 add d2,d1
 add d1,d0
 add -1,d0                        /* film j */
3:
 mov d0,(16,sp)
 mov d0,d1
 asl 6,d1
 asl2 d0
 add d0,d1
 add 16,a3
 add d1,a3
 mov a3,(20,sp)
 call pf_capto,[d2,d3,a2,a3],28   /* keeps d2, d3, a2, a3 */
 mov (16,sp),d1
 cmp 20,d1
 bcs 41f
 mov fl_cvt,a0                    /* COLOR k's own: is it changed from the factory? (its '*' while a film is on it) */
 add d2,a0
 movbu (a0),d0
 call ed_pmod,[d2,d3,a2],16
 mov (20,sp),a3
 movbu d0,(63,a3)
 clr d0
 bra 4f
41:
 clr d0
 mov (LPTR,a2),a0                 /* check: the film as built */
 asl 6,d1
 add d1,a0
 add 32,a0
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
4:
 mov (20,sp),a3
 mov d0,(64,a3)
 mov (TORG,a2),a3
 add TWO,a3
 mov (16,sp),d0
 mov 1,d1
 asl d0,d1
 mov (12,a3),d0
 or d1,d0
 mov d0,(12,a3)                   /* valid */
 mov 1,d0
 movbu d0,(TW_LEN,a3)             /* EDITS.BIN to save */
 movbu d0,(DIRTY,a2)
5:                                /* 2. what loads */
 mov (12,sp),d3
 mov (TORG,a2),a3
 add TWO,a3
 cmp 0,d3
 bne 6f
 mov d2,d0
 add 20,d0
 bra 7f
6:
 mov d2,d0
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
7:
 mov d0,(16,sp)
 mov 1,d1
 asl d0,d1
 mov (12,a3),d0
 and d1,d0
 beq 90f
 mov (16,sp),d0
 mov d0,d1
 asl 6,d1
 asl2 d0
 add d0,d1
 add 16,a3
 add d1,a3
 mov a3,(20,sp)
 mov (16,sp),d1
 cmp 20,d1
 bcc 8f
 mov (LPTR,a2),a0                 /* a film: only changes made from this build of it */
 asl 6,d1
 add d1,a0
 add 32,a0
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (20,sp),a3
 mov (64,a3),d1
 cmp d0,d1
 bne 90f
8:
 mov (20,sp),a3
 mov d2,(12,sp)
 jmp pf_put1
90:
 mov (12,sp),d3
 mov (4,sp),a0
 mov (8,sp),a1
 jmp pf_put

/* fl_save: `call fl_save,[d2,d3,a2,a3],24` in place of pf_save's call (ed_trig, a2 = P): EDITS.BIN when changed
 * (header, CRC, written whole), then pf_save. Locals (4) the handle. */
fl_save:
 mov (TORG,a2),a3
 cmp 0,a3
 beq 9f
 add TWO,a3
 movbu (TW_LEN,a3),d0
 cmp 0,d0
 beq 9f
 clr d0
 movbu d0,(TW_LEN,a3)
 mov TWMAGIC,d0
 mov d0,(a3)
 mov TW_LEN,d0
 mov d0,(4,a3)
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov TW_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(8,a3)
 mov tw_path,a0
 mov ed_m_w,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a0,a1
 mov TW_LEN,d1
 mov 1,d0
 mov a3,a0
 call fwrite,[d2,d3,a2,a3],24
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
9:
 jmp pf_save
tw_path:
 .asciz "C:\\OM3MOD\\EDITS.BIN"
 .balign 2

/* fl_film: `call fl_film,[],0`, a2 = P, d2 = COLOR k -> d0 = film j 0..19 when COLOR k holds look n 1..5 (whether it
 * is there: fl_has), else -1. Uses d0, d1, a1. */
fl_film:
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 mov a2,a1
 add d2,a1
 movbu (LIDX,a1),d1
 extb d1
 cmp 1,d1
 blt 9f
 cmp 5,d1
 bgt 9f
 mov d2,d0
 asl2 d0
 add d2,d0
 add d1,d0
 add -1,d0
 ret [],0
9:
 mov -1,d0
 ret [],0

/* fl_bl: `call fl_bl,[],0`, a0 = a part's row (4 bits a pixel), a1 = where it goes in the row buffer, d3 = its
 * bytes: every pixel that is not clear is written. Uses d0, d1, d3, a0, a1. */
fl_bl:
 movbu (a0),d0
 mov d0,d1
 and 15,d1
 cmp 0,d1
 beq 2f
 movbu d1,(a1)
2:
 lsr 4,d0
 cmp 0,d0
 beq 3f
 movbu d0,(1,a1)
3:
 inc a0
 add 2,a1
 add -1,d3
 bne fl_bl
 ret [],0

/* fl_sp: `call fl_sp,[d2,d3,a2,a3],240`, d0 = N 1..20, a0 = out, a1 = a layout -> d0 = the bytes written: "FILM N"
 * as one line, the word then the digits, centred (type 11). Layouts {width, height, stream header, word picture, its
 * bytes a row, its ink width, digit boxes, their bytes a row, bytes a box, digit ink widths, gap after the word, gap
 * between digits}: fl_LS the quick menu's 160 x 48 (mkicons sp_film), fl_LVL the shooting screen's 96 x 44 (lv_film;
 * film test 9). Frame: (0) call slot, (4) x0, (8) N, (12) first digit, (16) second digit or -1, (20) layout, (24) out,
 * (28) y, (32) / (36) / (40) the token word (fl_emit), (44) start, (48) digit x, (SROW) the row (160 B). */
fl_sp:
 mov d0,(8,sp)
 mov a0,(44,sp)
 mov a1,(20,sp)
 mov (8,a1),d0                    /* the header */
 mov d0,(a0)
 add 4,a0
 mov a0,(24,sp)
 clr d0
 mov d0,(32,sp)
 mov d0,(36,sp)
 mov d0,(40,sp)
 mov d0,(28,sp)
 mov -1,d1
 mov d1,(16,sp)
 mov (8,sp),d0
 cmp 10,d0
 bcs 1f
 clr d1
2:
 cmp 10,d0
 bcs 3f
 add -10,d0
 inc d1
 bra 2b
3:
 mov d1,(12,sp)
 mov d0,(16,sp)
 bra 4f
1:
 mov d0,(12,sp)
4:                                /* x0 = (width - ink) / 2 */
 mov (20,sp),a1
 mov (36,a1),a0
 mov (12,sp),d0
 add d0,a0
 movbu (a0),d1
 mov (20,a1),d0
 add d0,d1
 mov (40,a1),d0
 add d0,d1
 mov (16,sp),d0
 cmp 0,d0
 blt 5f
 mov (36,a1),a0
 add d0,a0
 movbu (a0),d0
 add d0,d1
 mov (44,a1),d0
 add d0,d1
5:
 mov (a1),d0
 sub d1,d0
 lsr 1,d0
 mov d0,(4,sp)
10:                               /* row y */
 mov (20,sp),a1
 mov (a1),d2
 mov sp,a1
 add SROW,a1
 clr d1
6:
 movbu d1,(a1)
 inc a1
 add -1,d2
 bne 6b
 mov (20,sp),a1                   /* the word */
 mov (28,sp),d0
 mov (16,a1),d1
 mul d0,d1
 mov (12,a1),a0
 add d1,a0
 mov (16,a1),d3
 mov sp,a1
 add SROW,a1
 mov (4,sp),d0
 add d0,a1
 call fl_bl,[],0
 mov (20,sp),a1                   /* the first digit */
 mov (4,sp),d0
 mov (20,a1),d1
 add d1,d0
 mov (40,a1),d1
 add d1,d0
 mov d0,(48,sp)
 mov (12,sp),d0
 call fl_spd,[],4
 mov (16,sp),d0                   /* the second digit */
 cmp 0,d0
 blt 20f
 mov (20,sp),a1
 mov (36,a1),a0
 mov (12,sp),d1
 add d1,a0
 movbu (a0),d1
 mov (44,a1),d2
 add d2,d1
 mov (48,sp),d2
 add d1,d2
 mov d2,(48,sp)
 call fl_spd,[],4
20:                               /* the row as runs: a1 the pixel, a2 the row's end */
 mov (20,sp),a0
 mov (a0),d0
 mov sp,a1
 add SROW,a1
 mov a1,a2
 add d0,a2
21:
 cmp a2,a1
 bcc 29f
 movbu (a1),d3
 mov 1,d1
 mov a1,a0
 inc a0
22:
 cmp 16,d1
 bcc 23f
 cmp a2,a0
 bcc 23f
 movbu (a0),d0
 cmp d3,d0
 bne 23f
 inc d1
 inc a0
 bra 22b
23:
 add d1,a1
 mov d3,d0
 asl 4,d0
 add d1,d0
 add -1,d0
 call fl_emit,[],0                /* keeps d3, a1, a2 */
 bra 21b
29:
 mov (28,sp),d0
 inc d0
 mov d0,(28,sp)
 mov (20,sp),a0
 mov (4,a0),d1
 cmp d1,d0
 bcc 30f
 jmp 10b
30:
 mov (32,sp),d0
 cmp 0,d0
 beq 31f
 mov (24,sp),a0
 mov (36,sp),d1
 mov d1,(a0)
 mov (40,sp),d1
 mov d1,(4,a0)
 add 8,a0
 mov a0,(24,sp)
31:
 mov (24,sp),d0
 mov (44,sp),d1
 sub d1,d0
 ret [d2,d3,a2,a3],240

/* fl_spd: `call fl_spd,[],4` from fl_sp (its frame one word down: (24) layout, (32) y, (52) digit x, (SROW + 4) the
 * row), d0 = the digit: its box row y onto the row at the digit x (fl_bl). Uses d0..d3, a0, a1. */
fl_spd:
 mov (24,sp),a1
 mov (32,a1),d1
 mul d0,d1
 mov (32,sp),d0
 mov (28,a1),d2
 mul d0,d2
 add d2,d1
 mov (24,a1),a0
 add d1,a0
 mov (28,a1),d3
 mov sp,a1
 add SROW + 4,a1
 mov (52,sp),d0
 add d0,a1
 call fl_bl,[],0                  /* our own call slot (0,sp) */
 ret [],4

.balign 4
fl_LS:                            /* the quick menu, 160 x 48 */
 .long 160, 48, 0x0b09f02f, fl_sfw, SFW / 2, SFWI, fl_sdg, SDB / 2, SDB * SPH / 2, fl_sdw, SP_GAP, SP_DGAP
fl_LVL:                           /* the shooting screen, 96 x 44 (film test 9) */
 .long 96, 44, 0x0b05f02b, fl_lvw, LVWB / 2, LVWI, fl_lvd, LVDB / 2, LVDB * 44 / 2, fl_lvdw, LV_GAP, LV_DGAP

/* fl_scp <- ic_get (d0 / d1 = 15746..15753: the quick menu's "COLOR k" / "COLOR k*", k = 0..3) and fl_lvp <- ic_get
 * (15706..15709: the shooting screen's "COLOR1".."COLOR4", film test 9): when COLOR k holds a film that is there,
 * "FILM N" (N its number in the list) from a block {4 slot words, 4 descriptors, 4 drawn numbers, 4 pictures} (P+TORG
 * with SP_SLOT pictures, layout fl_LS; P+LVB with LV_SLOT, fl_LVL), drawn (fl_sp) when N changes; else as stock
 * (ic_stk). Returns as ic_get (retf). Frame: (0) call slot, (4) i, (8) return, (12) id, (16) k, (20) j, (24) layout,
 * (28) slot size, (32) the block's place in P. */
fl_scp:
 movm [d2,d3,a2,a3],(sp)
 add -36,sp
 mov d0,(12,sp)
 mov mdr,d0
 mov d0,(8,sp)
 mov d1,d2
 add -15746,d2
 cmp 4,d2
 bcs 1f
 add -4,d2
1:
 mov fl_LS,d0
 mov d0,(24,sp)
 mov SP_SLOT,d0
 mov d0,(28,sp)
 mov TORG,d0
 mov d0,(32,sp)
 bra fl_pcp
fl_lvp:
 movm [d2,d3,a2,a3],(sp)
 add -36,sp
 mov d0,(12,sp)
 mov mdr,d0
 mov d0,(8,sp)
 mov d1,d2
 add -15706,d2
 and 3,d2                         /* sd4: the '*' pictures too (owner: a changed COLOR 1 hid "FILM N" on the screen) */
 mov fl_LVL,d0
 mov d0,(24,sp)
 mov LV_SLOT,d0
 mov d0,(28,sp)
 mov LVB,d0
 mov d0,(32,sp)
fl_pcp:
 mov d2,(16,sp)
 PVAL 80f
 mov (TORG,a2),d0
 cmp 0,d0
 beq 80f
 mov (32,sp),d0
 mov a2,a0
 add d0,a0
 mov (a0),d0                      /* the block */
 cmp 0,d0
 beq 80f
 call fl_film,[],0
 cmp 0,d0
 blt 80f
 mov d0,(20,sp)
 mov (LPTR,a2),a3
 mov a3,a0
 call fl_has,[],0
 cmp 0,d0
 beq 80f
 clr d3                           /* N = films before j, + 1 */
 clr d0
 mov d0,(4,sp)
2:
 mov (4,sp),d0
 mov (20,sp),d1
 cmp d1,d0
 bcc 3f
 mov a3,a0
 call fl_has,[],0
 add d0,d3
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 bra 2b
3:
 inc d3
 mov (32,sp),d0
 mov a2,a0
 add d0,a0
 mov (a0),a3                      /* the block */
 mov (16,sp),d2
 mov d2,d0
 asl2 d0
 mov a3,a1
 add d0,a1
 add 112,a1                       /* drawn number k */
 mov (a1),d0
 cmp d3,d0
 beq 5f
 mov (28,sp),d1
 mul d2,d1
 mov a3,a0
 add 128,a0
 add d1,a0                        /* picture k */
 mov a0,(4,sp)
 mov d3,d0
 mov (24,sp),a1
 call fl_sp,[d2,d3,a2,a3],240
 mov d2,d1                        /* descriptor k */
 asl 3,d1
 mov a3,a1
 add 16,a1
 add d1,a1
 add d1,a1
 add d1,a1
 mov (24,sp),a0
 mov 14,d1
 movhu d1,(a1)
 mov (a0),d1
 movhu d1,(2,a1)
 mov (4,a0),d1
 movhu d1,(4,a1)
 mov 8,d1
 movhu d1,(6,a1)
 clr d1
 movhu d1,(8,a1)
 movhu d1,(10,a1)
 mov d1,(20,a1)
 mov d0,(12,a1)                   /* size */
 mov (4,sp),d0
 mov d0,(16,a1)                   /* payload */
 mov d2,d0
 asl2 d0
 mov a3,a0
 add d0,a0
 mov a1,(a0)                      /* slot word k */
 add 112,a0
 mov d3,(a0)                      /* drawn number k */
5:
 mov d2,d0
 asl2 d0
 mov a3,a0
 add d0,a0
 mov (8,sp),d0
 mov d0,mdr
 add 36,sp
 movm (sp),[d2,d3,a2,a3]
 retf [],0
80:
 mov (8,sp),d1
 mov d1,mdr
 mov (12,sp),d0
 add 36,sp
 movm (sp),[d2,d3,a2,a3]
 jmp ic_stk

/* fl_tt <- st_get (the string getter's frame: ret [d2],8; d0 = 2755 / 2756 / 2757 / 4769, "Color Profile 1..4"):
 * when COLOR k holds a film that is there, its name (fl_str), else as stock (st_stk). */
fl_tt:
 add -16,sp                       /* (0) call slot, (4) d3, (8) a2, (12) id */
 mov d3,(4,sp)
 mov a2,(8,sp)
 mov d0,(12,sp)
 clr d2
 cmp 2755,d0
 beq 1f
 inc d2
 cmp 2756,d0
 beq 1f
 inc d2
 cmp 2757,d0
 beq 1f
 inc d2
1:
 PVAL 8f
 call fl_film,[],0
 cmp 0,d0
 blt 8f
 mov d0,d2
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 8f
 mov d2,d0
 add ST_F0,d0
 mov (4,sp),d3
 mov (8,sp),a2
 add 16,sp
 jmp fl_str
8:
 mov (12,sp),d0
 mov (4,sp),d3
 mov (8,sp),a2
 add 16,sp
 jmp st_stk

/* fl_pm <- st_get (the string getter's frame: ret [d2],8; d0 = 203, "Picture Mode"): on the Picture Mode screen (GUI
 * state 0x0418: the two bytes at the pointer 0x603713a4) with COLOR k selected, the title of what is selected, as when
 * it is chosen in the list (fl_tt: the film's name, or "Color Profile k"); the stock title moved to "Picture Mode"
 * when the row was reached with up / down (owner, film test 4: "the name goes away"). Else as stock. */
fl_pm:
 mov (0x603713a4),a0
 cmp 0,a0
 beq 9f
 movbu (a0),d1
 cmp 4,d1
 bne 9f
 movbu (1,a0),d1
 cmp 0x18,d1
 bne 9f
 add -4,sp
 mov 111,d0
 call sget,[],4                   /* the picture mode */
 add 4,sp
 mov d0,d1
 mov 2755,d0
 cmp 54,d1
 beq 8f
 mov 2756,d0
 cmp 55,d1
 beq 8f
 mov 2757,d0
 cmp 56,d1
 beq 8f
 mov 4769,d0
 cmp 64,d1
 bne 9f
8:
 jmp fl_tt
9:
 mov 203,d0
 jmp st_stk

/* fl_pmod <- .hook_pmod (stock 0x6129ba07 "COLOR profile changed?", the caller's call [d2,d3,a2],16; d0 picture
 * mode -> d0 1 changed): COLOR k holding a film that is there -> its own settings' flag (EDITS.BIN record 20 + k
 * valid and its byte +63, set by fl_sw when they were saved), so its '*' follows its own settings, not the film's;
 * else ed_pmod as before. Uses (0,sp) as the call slot of the leaves it calls. */
fl_pmod:
 mov mdr,d1
 mov d0,a1
 clr d2
 cmp 0x611d1837,d1                /* film test 6: 0x611d182f (the Picture Mode row's own '*' and Reset guide) */
 bne 10f
 mov 1,d2
10:
 call fl_k,[],0
 cmp 0,d0
 bge 1f
 mov a1,d0
 jmp ed_pmod
1:
 asl 8,d2
 or d0,d2                         /* k | row flag << 8 */
 PVAL 9f
 mov d2,d3
 lsr 8,d3                         /* the row flag */
 and 0xff,d2                      /* k */
 mov (TORG,a2),d0
 cmp 0,d0
 beq 9f
 call fl_film,[],0
 cmp 0,d0
 blt 9f
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 9f
 cmp 0,d3
 bne 20f
 mov (TORG,a2),a0                 /* the COLOR k cell: its own settings */
 add TWO,a0
 mov d2,d1
 add 20,d1                        /* r */
 mov 1,d3
 asl d1,d3
 mov (12,a0),d0
 and d3,d0
 beq 8f
 mov d1,d0
 asl 6,d0
 asl2 d1
 add d1,a0
 add d0,a0
 add 16,a0
 movbu (63,a0),d0
 ret [d2,d3,a2],16
8:
 clr d0
 ret [d2,d3,a2],16
20:                               /* the row: the film changed from how it was built? */
 call fl_live,[d2,d3,a2,a3],24
 ret [d2,d3,a2],16
9:
 and 0xff,d2
 mov fl_cvt,a0
 add d2,a0
 movbu (a0),d0
 jmp ed_pmod

/* film test 8 (owner): "rename Color All to Saturation and hide the color select wheel". The Saturation page always
 * shows all colours: INFO goes Saturation (all) -> Hue -> Light -> Saturation (all) (k_sall; the INFO that opens the
 * wheel turns all colours on, as stock: in the emulator, setting it before the stock init made that INFO step on to Hue);
 * its pictures there say Saturation: the "Color" dial label and the "Color Select [INFO]" guide (gd_sel). */

/* film test 10 (owner): "the HSL wheels in HSL order, Light renamed Luminance, so they read hue, saturation and
 * luminance". INFO: Hue -> Saturation (all colours) -> Luminance -> Hue (k_step), and the wheel opens on Hue: the INFO
 * that opens it reaches ed_info right after the init (emulator), so ei_open marks the init and k_open sends that
 * first INFO to Hue (all colours off first, as the stock INFO handler does from all colours). */

/* ei_open: `call ei_open,[d2,a2],8` from ei_page (gd_set's frame), a2 = P, d0 = page: P+EOPEN = 1, then gd_set. */
ei_open:
 .if W_HSL
 mov 1,d1
 movbu d1,(EOPEN,a2)
 .endif
 jmp gd_set

/* k_open <- jmp from ed_info (its frame: (4) / (8) its d1 / a1, (16) value, (20) P = a2, a3 the editor): the first
 * INFO after the init -> all colours off when on, then k_step from Light (-> Hue). Else k_ad and on (k_6b). */
k_open:
 .if W_HSL
 movbu (EOPEN,a2),d0
 cmp 0,d0
 beq 5f
 clr d0
 movbu d0,(EOPEN,a2)
 call k_ad,[a2],8
 cmp 0,d0
 bne 2f
 mov (16,sp),d0
 cmp 255,d0
 bne 2f
 mov a3,a0                        /* all colours on: the stock INFO handler turns them off */
 mov 0x9014,d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls stock_info                 /* keeps d2/d3/a2/a3 */
2:
 mov (20,sp),a2
 mov 1,d0
 movbu d0,(AXIS,a2)
 jmp k_step
5:
 .endif
 call k_ad,[a2],8
 jmp k_6b

/* k_sall <- jmp from k_step's end (ed_info's frame: (4) / (8) its d1 / a1, (16) value, (20) P, a3 the editor): on
 * Saturation with one colour, the stock INFO handler turns all colours on (as from the single page). -> d0 1. */
k_sall:
 .if W_SALL
 mov (20,sp),a2
 movbu (AXIS,a2),d0
 cmp 0,d0
 bne 9f
 call k_ad,[a2],8
 cmp 0,d0
 bne 9f                           /* no value: leave it */
 mov (16,sp),d0
 cmp 255,d0
 .if W_SONE
 bne 9f                           /* film test 11: all colours on -> off (one colour) */
 .else
 beq 9f
 .endif
 mov a3,a0
 mov 0x9014,d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls stock_info                 /* keeps d2/d3/a2/a3 */
 .endif
9:
 mov 1,d0
 ret [d2,d3,a2,a3],40

/* e_sall <- jmp from ed_event's end (its frame: (4) d1, (8) a1, (12) 2197 + k, (16) value, (20) P, (24) event; d3 its
 * result, a3 the editor): the held-OK reset on Saturation left one colour (the reset sets the cursor) -> the stock INFO
 * handler turns all colours on again. -> d0 = the result. */
e_sall:
 .if W_SALL && (W_SONE == 0)          /* film test 11: one colour: the reset's own state (one colour) stays */
 mov (24,sp),d0
 cmp 0x903e,d0
 bne 9f
 mov (20,sp),a2
 movbu (AXIS,a2),d0
 cmp 0,d0
 bne 9f
 call k_ad,[a2],8
 cmp 0,d0
 bne 9f
 mov (16,sp),d0
 cmp 255,d0
 beq 9f
 mov a3,a0
 mov 0x9014,d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls stock_info                 /* keeps d2/d3/a2/a3 */
 .endif
9:
 mov d3,d0
 ret [d2,d3,a2,a3],44

/* ed_l / ed_r <- COLOR1-4 editor records +20 / +24 (stock 0x6122471c / 0x61224c1c: left / right, events 0x9008 /
 * 0x900a, which move the colour cursor; CALLS, d0 event, d1 arg, a0 parent): on Saturation with all colours, nothing
 * (that would leave all colours for the hidden single-colour page) -> d0 1. Anything else: registers as at entry, jmp
 * stock. Frame as ed_info: (4) d1, (8) a1, (12) 2197 + k, (16) value, (20) d0, (24) a0. */
 .macro EDLR stock
 movm [d2,d3,a2,a3],(sp)
 add -28,sp
 mov d1,(4,sp)
 mov a1,(8,sp)
 mov d0,(20,sp)
 mov a0,(24,sp)
 .if W_SALL
 cmp 0,a0
 beq 8f
 movhu (96,a0),d2                 /* editor key 0x1540..0x1543 = COLOR1..4 */
 add -0x1540,d2
 cmp 4,d2
 bcc 8f
 add 2197,d2
 mov d2,(12,sp)
 PVAL 8f
 movbu (AXIS,a2),d0
 cmp 0,d0
 bne 8f
 call k_ad,[a2],8
 cmp 0,d0
 bne 8f
 mov (16,sp),d0
 cmp 255,d0
 bne 8f
 mov 1,d0
 ret [d2,d3,a2,a3],44
 .endif
8:
 mov (4,sp),d1
 mov (8,sp),a1
 mov (20,sp),d0
 mov (24,sp),a0
 add 28,sp
 movm (sp),[d2,d3,a2,a3]
 jmp \stock
 .endm
ed_l:
 EDLR stock_left
ed_r:
 EDLR stock_right

/* rs_pos <- .hook_rsp (the end of the held-OK reset 0x611c3b..; its frame: (20) the row, (32) the list's cursor index):
 * stock puts the cursor's place on screen (row +88) = its index, right for the camera's 4-cell COLOR list. With the
 * films the strip scrolls (row +86 the index, +88 its place, the first cell shown = +86 - +88), so after a film's reset
 * FILM 6 was off screen and the list showed COLOR 1.. (owner, film test 8). Keep the place when it still fits the
 * index (the reset does not move the cursor); else as stock. -> 0x611c3cbd. */
rs_pos:
 mov (20,sp),a0
 movhu (32,sp),d0
 movhu (88,a0),d1
 cmp d0,d1
 bls 1f                           /* place <= index: the first cell shown stays where it was */
 movhu d0,(88,a0)
1:
 jmp rsp_back

/* gd_s0 <- jmp from gd_set's stock-guide path (its frame, `ret [d2,a2],8`), a0 = GDESC, a2 = P, d0 = page: on
 * Saturation (W_SONE: one colour, the camera's "Color All [INFO]") our "Saturation [INFO]" (P+SATB), else the camera's. */
gd_s0:
 .if W_SALL && W_SONE
 cmp 0,d0
 bne 8f
 mov (SATB,a2),d1
 cmp 0,d1
 beq 8f
 add SAT_SG,d1
 mov d1,(16,a0)
 mov SGS,d1
 mov d1,(12,a0)
 ret [d2,a2],8
8:
 .endif
 mov GSTOCK_S,d1
 mov d1,(12,a0)
 mov GSTOCK_P,d1
 mov d1,(16,a0)
 ret [d2,a2],8

/* gd_sel: `call gd_sel,[d2,d3,a2,a3],24` from gd_set, a2 = P, d0 = page (0 Saturation, -1 the stock pictures): our
 * "Saturation" label / guide (P+SATB: (0) label size, (4) guide size, (8) label, then the guide 4-aligned) into the
 * camera's "Color" label and "Color Select [INFO]" descriptors on Saturation, the camera's own on any other page; only
 * while a descriptor holds the camera's picture or ours. d0 kept; uses d1, a0, a1. Local (4) page. */
gd_sel:
 mov d0,(4,sp)
 mov (tg_ptr),d1                  /* v0.26: a TONES.BIN picture in the guide: the camera's picture back first, so */
 cmp 0,d1                         /* gd_set takes the guide as stock again (and tg_sel puts the new page's in) */
 beq 13f
 mov GDESC,a0
 mov (16,a0),d2
 sub d1,d2
 cmp 16448,d2
 bcc 13f
 mov GSTOCK_S,d2
 mov d2,(12,a0)
 mov GSTOCK_P,d2
 mov d2,(16,a0)
13:
 .if W_SALL
 mov (SATB,a2),a3
 cmp 0,a3
 beq 9f
 .if W_SONE                       /* film test 11: our guide in the "Color All [INFO]" descriptor -> the camera's again, */
 mov GDESC,a0                     /* so gd_set treats it as stock (gd_s0 puts ours back on Saturation) */
 mov (16,a0),d1
 mov a3,d2
 add SAT_SG,d2
 cmp d2,d1
 bne 11f
 mov GSTOCK_S,d1
 mov d1,(12,a0)
 mov GSTOCK_P,d1
 mov d1,(16,a0)
11:
 .endif
 mov LDESC,a0                     /* the "Color" label */
 movhu (a0),d1
 cmp 14,d1
 bne 5f
 movhu (2,a0),d1
 cmp 70,d1
 bne 5f
 movhu (4,a0),d1
 cmp 30,d1
 bne 5f
 mov (16,a0),d1                   /* the camera's or ours (inside the block)? */
 cmp LSTOCK_P,d1
 beq 1f
 mov a3,d2
 sub d2,d1
 cmp SAT_LEN,d1
 bcc 5f                           /* someone else's: leave it */
1:
 mov (4,sp),d0
 mov SAT_SG,d2                    /* Saturation's ends at its guide: its size */
 add -8,d2
 mov 8,d3
 cmp 0,d0
 beq 3f
 .if W_HSL
 mov HLS,d2                       /* film test 10: Hue, Luminance */
 mov SAT_HL,d3
 cmp 2,d0
 beq 3f
 mov LLS,d2
 mov SAT_LL,d3
 cmp 1,d0
 beq 3f
 .endif
 mov LSTOCK_S,d1
 mov d1,(12,a0)
 mov LSTOCK_P,d1
 mov d1,(16,a0)
 bra 5f
3:
 cmp 8,d3
 bne 4f
 mov (a3),d2                      /* Saturation: its size from the block */
4:
 mov d2,(12,a0)
 mov a3,d1
 add d3,d1
 mov d1,(16,a0)
5:
 .if W_SONE                       /* film test 11: no all-colours page, its guide stays the camera's */
 bra 9f
 .endif
 mov SDESC,a0                     /* the "Color Select [INFO]" guide */
 movhu (a0),d1
 cmp 14,d1
 bne 9f
 movhu (2,a0),d1
 cmp 180,d1
 bne 9f
 movhu (4,a0),d1
 cmp 50,d1
 bne 9f
 mov (a3),d2
 add 3,d2
 and -4,d2
 add 8,d2
 mov a3,d1
 add d1,d2                        /* ours */
 mov (16,a0),d1
 cmp d2,d1
 beq 6f
 cmp SSTOCK_P,d1
 bne 9f
6:
 mov (4,sp),d0
 cmp 0,d0
 bne 7f
 mov (4,a3),d1
 mov d1,(12,a0)
 mov d2,(16,a0)
 bra 9f
7:
 mov SSTOCK_S,d1
 mov d1,(12,a0)
 mov SSTOCK_P,d1
 mov d1,(16,a0)
 .endif
9:
 mov (4,sp),d0
 ret [d2,d3,a2,a3],24

/* fl_isdef <- the seven calls of stock "is at default" (call [d2,d3,a2],24; d0 id -> d0 1 default, 0 changed; build.py
 * ISDEF_SITES): one of COLOR k's 18 settings (pf_ids: base + step x k, record offset) while COLOR k holds a film that
 * is there -> "default" when it equals the film as built (LOOKS.BIN record j; a Saturation sector also needs its Hue
 * and Light equal), so a film's '*' marks what was changed on it. Anything else: ed_isdef as before. Locals (4) id,
 * (8) record offset. */
fl_isdef:
 mov d0,(4,sp)
 PVAL 90f
 mov (LPTR,a2),d1
 cmp 0,d1
 beq 90f
 clr d2                           /* pf_ids entry */
1:
 mov pf_ids,a0
 mov d2,d1
 asl2 d1
 add d1,a0
 movhu (a0),d1
 mov (4,sp),d0
 exthu d0
 sub d1,d0                        /* id - base */
 blt 5f
 movbu (2,a0),d1                  /* step */
 clr d3
2:
 cmp 0,d0
 beq 3f
 sub d1,d0
 blt 5f
 inc d3
 cmp 4,d3
 bcs 2b
 bra 5f
3:
 movbu (3,a0),d0
 mov d0,(8,sp)
 mov d3,d2                        /* k */
 call fl_film,[],0
 cmp 0,d0
 blt 90f
 mov d0,d3                        /* j */
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 90f
 mov (4,sp),d0
 call sget,[],4                   /* now (keeps d2, d3, a2) */
 extb d0
 mov (LPTR,a2),a0
 mov d3,d1
 asl 6,d1
 add d1,a0
 add 32,a0
 mov (8,sp),d1
 add d1,a0
 movbu (a0),d1
 extb d1
 cmp d1,d0
 bne 7f
 mov (8,sp),d1                    /* a Saturation sector: its Hue and Light too */
 cmp 24,d1
 bcs 8f
 cmp 36,d1
 bcc 8f
 add -24,d1
 mov a2,a1
 mov d2,d0
 asl 6,d0
 add d0,a1
 add 32,a1
 add d1,a1
 mov (LPTR,a2),a0
 mov d3,d0
 asl 6,d0
 add d0,a0
 add 32,a0
 add d1,a0
 movbu (a1),d0
 movbu (a0),d1
 cmp d1,d0
 bne 7f
 movbu (12,a1),d0
 movbu (12,a0),d1
 cmp d1,d0
 bne 7f
8:
 mov 1,d0
 ret [d2,d3,a2],24
7:
 clr d0
 ret [d2,d3,a2],24
5:
 inc d2
 cmp 18,d2
 bcs 1b
 mov (4,sp),d0                    /* film test 8: our rows (Grain, NR, VigFix, Blacks, Whites, A-B, G-M: base + k) */
 exthu d0
 add -GRB,d0
 blt 90f
 cmp 0xc0,d0                      /* v0.25: + GLB (row 10), FRB (row 11); rows 7..9 are not ours (FLB films) */
 bcc 90f
 mov d0,d2
 and 15,d2                        /* k */
 cmp 4,d2
 bcc 90f
 lsr 4,d0                         /* the row */
 cmp 7,d0
 bcs 6f
 cmp 10,d0
 bcs 90f
6:
 mov fl_xr,a0
 add d0,a0
 add d0,a0
 movbu (1,a0),d1                  /* record offset | slot offset << 8 (bytes: the table is not aligned) */
 asl 8,d1
 movbu (a0),d0
 or d1,d0
 mov d0,(8,sp)
 call fl_film,[],0
 cmp 0,d0
 blt 90f
 mov d0,d3                        /* j */
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 90f
 mov (LPTR,a2),a0
 mov d3,d1
 asl 6,d1
 add d1,a0
 add 32,a0
 mov (8,sp),d1
 and 0xff,d1
 add d1,a0
 movbu (a0),d0                    /* as built */
 mov a2,a1
 mov d2,d1
 asl 6,d1
 add d1,a1
 add 32,a1
 mov (8,sp),d1
 lsr 8,d1
 add d1,a1
 movbu (a1),d1                    /* now */
 cmp d1,d0
 bne 7b
 jmp 8b
90:
 mov (4,sp),d0
 jmp ed_isdef
fl_xr:                            /* {record offset, slot offset} of the rows GRB, NRB, VFB, BKB, WHB, ABB, GMB (pf_bt),
                                     three unused (FLB), v0.25 GLB, FRB */
 .byte 51,53, 49,51, 50,52, 39,47, 40,48, 37,26, 38,27, 0,0, 0,0, 0,0, 47,49, 48,50

/* fl_live: `call fl_live,[d2,d3,a2,a3],24`, a2 = P, d2 = COLOR k holding film j -> d0 1 when COLOR k now differs from
 * film j as built: its 18 settings (fl_isdef) or the slot's WB shift, Blacks / Whites, Extras (pf_bt). */
fl_live:
 clr d3
21:
 mov pf_ids,a0
 mov d3,d1
 asl2 d1
 add d1,a0
 movbu (2,a0),d1
 mul d2,d1
 movhu (a0),d0
 add d1,d0
 call fl_isdef,[d2,d3,a2],24
 cmp 0,d0
 beq 28f
 inc d3
 cmp 18,d3
 bcs 21b
 call fl_film,[],0
 mov (LPTR,a2),a0
 asl 6,d0
 add d0,a0
 add 32,a0
 mov a2,a1
 mov d2,d0
 asl 6,d0
 add d0,a1
 add 56,a1                        /* slot + 24 */
 clr d3
22:
 mov pf_bt,a2
 add d3,a2
 add d3,a2
 movbu (a2),d0
 movbu (1,a2),d1
 movbu (d0,a0),d0
 movbu (d1,a1),d1
 cmp d1,d0
 bne 28f
 inc d3
 cmp 11,d3
 bcs 22b
 clr d0
 ret [d2,d3,a2,a3],24
28:
 mov 1,d0
 ret [d2,d3,a2,a3],24

/* fl_fch: `call fl_fch,[d2,d3,a2,a3],28`, a2 = P, d0 = film j -> d0 1 when it is changed from how it was built: on
 * its COLOR now (look number = its) -> fl_live; else its saved changes (EDITS.BIN record j, valid) differ from the
 * LOOKS.BIN record in bytes 0..52. Locals (4) j. */
fl_fch:
 mov d0,(4,sp)
 clr d2
 mov d0,d1
1:
 cmp 5,d1
 bcs 2f
 add -5,d1
 inc d2
 bra 1b
2:
 inc d1                           /* n; d2 = k */
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp d1,d0
 bne 5f
 call fl_live,[d2,d3,a2,a3],24
 ret [d2,d3,a2,a3],28
5:
 mov (TORG,a2),a1
 cmp 0,a1
 beq 8f
 add TWO,a1
 mov (4,sp),d0
 mov 1,d1
 asl d0,d1
 mov (12,a1),d3
 and d1,d3
 beq 8f
 mov (4,sp),d0
 mov d0,d1
 asl 6,d1
 asl2 d0
 add d0,d1
 add 16,d1
 add d1,a1                        /* its saved changes */
 mov (4,sp),d0
 asl 6,d0
 mov (LPTR,a2),a0
 add d0,a0
 add 32,a0                        /* as built */
 mov 53,d3
6:
 movbu (a0),d0
 movbu (a1),d1
 cmp d1,d0
 bne 7f
 inc a0
 inc a1
 add -1,d3
 bne 6b
8:
 clr d0
 ret [d2,d3,a2,a3],28
7:
 mov 1,d0
 ret [d2,d3,a2,a3],28


/* ---- ft1 (fast grain, texture route; experiment/fast-grain-log, 2026-11-08). The still set-up thunk 0x604b7730
 * (`call 0x604b97db,[d2,d3,a2,a3],136`, a0 = S = the still's context, called `call ..,[],4` from 0x604b5896) jumps
 * here: the stock set-up, then code block +112 (xb_su: a Grainy-Film-style grain texture for a COLOR still with
 * Grain, research/NOTES.md "Grainy Film's grain path in the firmware"). Result d0 kept. */
.section .hook_su,"ax"
 jmp xs_su                        /* stock 0x604b7730: call 0x604b97db,[d2,d3,a2,a3],136 */

.section .ext11,"ax"
xs_su:
 call xs_su2,[d2,a2],12
 exthu d0
 ret [],4
xs_su2:                           /* a0 = S, a1 = the set-up's second argument (kept) */
 mov a0,a2
 call su_stock,[d2,d3,a2,a3],136
 mov d0,d2
 call xp,[],0
 beq 9f
 add 112,a1
 mov a2,a0
 add -4,sp                        /* a fresh return slot for `calls` ((0,sp) is ours) */
 calls (a1)
 add 4,sp
9:
 mov d2,d0
 ret [d2,a2],12

/* ft3: the combiner set-up 0x60504b2b calls the selector itself (0x60504b5d); code block +120 (xb_sel2) answers
 * combiner 1 there for the textured COLOR development, so Grainy Film's blend is set up with COLOR's key. */
.section .hook_sel2,"ax"
 call s_sel2,[d2,a2],12           /* stock 0x60504b5d: call 0x6052cf39,[d2,a2],12 */

.section .ext11,"ax"
s_sel2:                           /* the selector's frame; a0 = context */
 call xp,[],0
 beq 9f
 add 120,a1
 jmp (a1)
9:
 jmp SEL

/* ft4: the end of the combiner set-up tail 0x605053ec (combiner 1's case and one other): `mov d0,(152,a2)` then
 * code block +128 (xb_c1e: COLOR's chroma back when flagged), then the stock `ret [d2,d3,a2,a3],28`. */
.section .hook_c1e,"ax"
 jmp s_c1e                        /* stock 0x605053cc: mov d0,(152,a2); ret [d2,d3,a2,a3],28 */
 nop
 nop

.section .ext11,"ax"
s_c1e:
 mov d0,(152,a2)
 call xp,[],0
 beq 9f
 add 120,a1
 add 8,a1
 calls (a1)
9:
 ret [d2,d3,a2,a3],28

/* ft8: the work-list builder 0x604b8cf7 reads the job's key (0x604b8d91: mov d3,a0; mov (a0),a0; mov (5352,a0),d2)
 * and picks the list by it; code block +136 (xb_wl) may give Grainy Film II's key for that pick only. */
.section .hook_wl,"ax"
 jmp s_wl                         /* stock 0x604b8d91: f1ec f000 fa08e814 */
 nop
 nop
 nop

.section .ext11,"ax"
s_wl:
 mov d3,a0
 mov (a0),a0
 mov (5352,a0),d2
 call xp,[],0
 beq 9f
 add 120,a1
 add 16,a1
 mov (4,sp),a0                    /* ft8b: S (the builder keeps it at (4,sp)) */
 calls (a1)
 cmp 0,d0
 beq 9f
 mov d0,d2
9:
 jmp wl_back

/* ------------------------------------------------------------------ split toning (v0.26)
 * research/NOTES.md "Split toning": the RGB gamma stage (0x60516ad9) copies the picture-mode curve into the job three
 * times (O+1252 R / +1892 G / +2532 B: 256 x u16 12-bit + 64 x u16 fine table, 640 B each) before the stage list that
 * holds our tone hook. st_run runs at tone's exit (same context C in d3, all registers as at the hook) and bends each
 * channel: t' = t + ((Ks ws + Kh wh) >> 8), ws = (t s >> 12) s >> 12, wh = (t t >> 12) s >> 12, s = 4095 - t
 * (research/splittone/model.py), clamped 0..4095 and kept rising (running max, the 256 and the 64 entries apart).
 * K = st_k[colour] x strength: the effective COLOR's slot +55 / +56 (Shadows colour 0..11, strength -5..5; minus =
 * the opposite colour) and +57 / +58 (Highlights). Camera-proven with fixed values (probe st1). Gates: COLOR still
 * (key 11, or 12 with +1731 0, as tone); P valid; a strength set; R, G and B tables identical before (stock COLOR
 * copies one curve three times: a repeated pass never bends twice and art curves are left alone).
 * Frame: (0) getter return, (4..28) registers, (32..52) Ks R G B, Kh R G B, (56) segment, (60) running max, (64) d0,
 * (68) Ks, (72) Kh of the segment.
 * Stores: own stack frame, O+1252..O+3171. */
.section .ext11,"ax"
st_run:
 add -76,sp
 mov d0,(64,sp)
 mov d1,(4,sp)
 mov d2,(8,sp)
 mov d3,(12,sp)
 mov a1,(16,sp)
 mov a2,(20,sp)
 mov a3,(24,sp)
 mov mdr,d0
 mov d0,(28,sp)
 mov d3,a2                        /* a2 = context C */
 mov (12,a2),a3                   /* a3 = output O */
 mov (4,a2),a1                    /* request R */
 movhu (10,a1),d0
 cmp 11,d0
 beq 1f
 cmp 12,d0
 bne s9
 movbu (1731,a1),d0
 cmp 0,d0
 bne s9
1:
 .if ST_STILL
 movhu (14,a1),d0                 /* sp2: still development only (R+14 0x1000, column 0 of the curve rows) */
 cmp 0x1000,d0
 bne s9
 .endif
 mov a3,d1                        /* the three curve pointers must be the job's own tables (the copier wrote them) */
 add 1252,d1
 mov (3172,a3),d0
 cmp d1,d0
 bne s9
 add 640,d1
 mov (3176,a3),d0
 cmp d1,d0
 bne s9
 add 640,d1
 mov (3180,a3),d0
 cmp d1,d0
 bne s9
 PVAL s9                          /* a2 = P (uses d3, a2) */
 clr d1                           /* any strength on COLOR 1-4? (else no getter call) */
 mov a2,a0
 mov 4,d2
12:
 movbu (88,a0),d0
 or d0,d1
 movbu (90,a0),d0
 or d0,d1
 add 64,a0
 add -1,d2
 bne 12b
 cmp 0,d1
 beq s9
 mov a2,(52,sp)                   /* P (the Kh B slot is written later) */
 mov 63153,d0                     /* effective COLOR profile number */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12           /* keeps a2/a3 */
 mov (52,sp),a2
 add -1,d0
 cmp 4,d0
 bcc s9
 mov d0,d2
 asl 6,d2
 add d2,a2                        /* a2 = P + 64k: the slot is at +32 */
 clr d2                           /* any strength? */
 mov sp,a1
 add 32,a1                        /* a1 = Ks R */
 mov 87,d3                        /* Shadows: slot +55 / +56 */
2:
 movbu (d3,a2),d0                 /* colour */
 inc d3
 movbu (d3,a2),d1                 /* strength */
 inc d3
 extb d1
 cmp 12,d0
 bcs 3f
 clr d1                           /* no colour: off */
3:
 cmp -5,d1
 bge 31f
 mov -5,d1
31:
 cmp 5,d1
 ble 32f
 mov 5,d1
32:
 or d1,d2
 mov d0,a0                        /* st_k + 3 colour */
 add d0,a0
 add d0,a0
 add st_k,a0
 movbu (a0),d0                    /* K = st_k x strength, per channel */
 extb d0
 mul d1,d0
 mov d0,(a1)
 movbu (1,a0),d0
 extb d0
 mul d1,d0
 mov d0,(4,a1)
 movbu (2,a0),d0
 extb d0
 mul d1,d0
 mov d0,(8,a1)
 add 12,a1
 cmp 91,d3                        /* then Highlights: slot +57 / +58 */
 bne 2b
 cmp 0,d2
 beq s9                           /* both strengths 0 */
 mov a3,a0
 add 1252,a0                      /* a0 = R table */
 mov a0,a1
 add 640,a1                       /* a1 = G table */
 clr d1
5:
 movhu (d1,a0),d0
 movhu (d1,a1),d2
 cmp d0,d2
 bne s9                           /* R != G: already toned, or not one curve */
 add 640,d1
 movhu (d1,a1),d2                 /* B (G + 640) */
 add -640,d1
 cmp d0,d2
 bne s9
 add 2,d1
 cmp 640,d1
 bne 5b
 clr d0
 mov d0,(56,sp)                   /* segment 0..5: channel = seg / 2, the 256 entries (even) or the 64 (odd) */
6:
 mov (56,sp),d0
 mov d0,d1
 lsr 1,d1                         /* channel */
 mov d1,d2
 asl2 d2
 mov sp,a1
 add d2,a1
 mov (32,a1),d2
 mov d2,(68,sp)                   /* Ks */
 mov (44,a1),d2
 mov d2,(72,sp)                   /* Kh */
 mov 640,d2
 mul d1,d2
 mov a3,a0
 add 1252,a0
 add d2,a0                        /* this channel's table */
 mov a0,a1
 add 512,a1
 btst 1,d0
 beq 7f
 mov a1,a0                        /* the 64-entry part */
 add 128,a1
7:
 clr d2
 mov d2,(60,sp)                   /* running max */
8:
 movhu (a0),d0                    /* t */
 mov 4095,d1
 sub d0,d1                        /* s */
 mov d0,d2
 mul d1,d2
 lsr 12,d2
 mul d1,d2
 lsr 12,d2                        /* ws */
 mov (68,sp),d3
 mul d3,d2                        /* Ks ws */
 mov d0,d3
 mul d0,d3
 lsr 12,d3
 mul d1,d3
 lsr 12,d3                        /* wh */
 mov (72,sp),d1
 mul d1,d3                        /* Kh wh */
 add d3,d2
 asr 8,d2
 add d2,d0
 bge 9f
 clr d0
9:
 cmp 4095,d0
 ble 10f
 mov 4095,d0
10:
 mov (60,sp),d1
 cmp d1,d0
 bge 11f
 mov d1,d0                        /* keep it rising */
11:
 mov d0,(60,sp)
 movhu d0,(a0)
 add 2,a0
 cmp a1,a0
 bne 8b
 mov (56,sp),d0
 inc d0
 mov d0,(56,sp)
 cmp 6,d0
 bne 6b
s9:
 mov (28,sp),d0
 mov d0,mdr
 mov (64,sp),d0
 mov (4,sp),d1
 mov (8,sp),d2
 mov (12,sp),d3
 mov (16,sp),a1
 mov (20,sp),a2
 mov (24,sp),a3
 add 76,sp
 mov d3,a0                        /* displaced 0x605197d7 */
 jmp tone_next                    /* 0x60518fa4; returns to 0x605197de */
st_k:                             /* K per strength step, R G B, for the wheel's 12 colours (4.8 Cb/Cr units at the
                                   * weight peak per step: up to 24 at 5, as Cross Process I) */
 .byte 7,7,-57          /* Yellow */
 .byte 26,-4,-47          /* Orange */
 .byte 37,-12,-33          /* Orange-red */
 .byte 43,-18,-18          /* Red */
 .byte 39,-26,29          /* Magenta */
 .byte 17,-19,53          /* Violet */
 .byte -11,-5,56          /* Blue */
 .byte -33,9,39          /* Blue-cyan */
 .byte -43,18,18          /* Cyan */
 .byte -45,24,-5          /* Green-cyan */
 .byte -36,25,-36          /* Green */
 .byte -13,17,-55          /* Yellow-green */
 .align 2

/* ------------------------------------------------------------------ split toning wheels (v0.26)
 * The HSL wheel gets two more pages after Luminance: axis 5 Shadows and axis 6 Highlights (INFO: Color -> Color All ->
 * Hue -> Luminance -> Shadows -> Highlights -> Color). On them the 12 colours are the tint's colour: the rear dial on
 * a colour sets its strength -5..5 (minus = the opposite colour) and makes it the page's colour; the other colours
 * read 0. Slot +55 / +56 (Shadows colour 0..11, strength), +57 / +58 (Highlights); LOOKS.BIN record +53..+56.
 * TONEP miss: P valid, the editor's marker, axis 5 or 6 -> a2 = P, d3 = axis. Uses d3, a2. */
 .macro TONEP miss
 PVAL \miss
 mov (EMARK,a2),d3
 cmp EMAGIC,d3
 bne \miss
 movbu (AXIS,a2),d3
 cmp 5,d3
 bcs \miss
 cmp 7,d3
 bcc \miss
 .endm
/* TONEV: d2 = sector id - 928 (12k + colour), a2 = P, d3 = axis -> d0 = the value shown (-5..5). Uses d2, d3, a2. */
 .macro TONEV
 clr d0
71:
 cmp 12,d2
 bcs 72f
 add -12,d2
 add 64,d0
 bra 71b
72:
 add d0,a2
 add -5,d3
 add d3,a2
 add d3,a2                        /* a2 = P + 64k + 2 (axis - 5) */
 movbu (87,a2),d0                 /* the page's colour */
 cmp d2,d0
 bne 73f
 movbu (88,a2),d0                 /* its strength */
 extb d0
 cmp -5,d0
 bge 74f
 mov -5,d0
74:
 cmp 5,d0
 ble 75f
 mov 5,d0
 bra 75f
73:
 clr d0
75:
 .endm
.section .ext11,"ax"
/* tn_get <- sl_get's miss (instead of ed_get): GetValue (CALLS entry: d0 id, a0 facade, a1 out). Sector ids
 * 928 + 12k + colour and the readout's 916..927 (the selected colour of the open editor, with the dial label) on a
 * Shadows / Highlights page; anything else: ed_get with every register as at entry. The page's name is its guide
 * picture under the wheel ("Shadows [INFO]" / "Highlights [INFO]", TONES.BIN: tg_load, tg_sel). */
tn_get:
 cmp 0,a1
 beq 9f
 movm [d2,d3,a2],(sp)
 TONEP 8f
 mov d0,d2
 exthu d2
 add -916,d2
 cmp 12,d2
 bcc 2f
 movbu (EDK,a2),d3                /* the readout: colour d2 of the open editor (the dial label stays the camera's, */
 cmp 4,d3                         /* "Vivid": owner, sp1) */
 bcc 8f
 mov d3,d0
 add d0,d0
 add d3,d0
 asl2 d0
 add d0,d2                        /* 12k + colour */
 bra 3f
2:
 add -12,d2                       /* 928.. -> 0.. */
 cmp 48,d2
 bcc 8f
3:
 movbu (AXIS,a2),d3
 TONEV
 mov d0,(a1)
 movm (sp),[d2,d3,a2]
 clr d0
 rets
8:
 movm (sp),[d2,d3,a2]
9:
 jmp ed_get

/* tn_set <- sl_set's miss (instead of ed_set), entered as ed_set (d0 id, d1 value, a0 inner, a1 mode; d2/d3/a2/a3
 * saved by the setter's call, frame 68). A sector id on a Shadows / Highlights page: value -5..5; not 0 -> this
 * colour and strength; 0 -> strength 0 if this is the page's colour. Then s_dirty (dirty, the manager's refresh). */
tn_set:
 TONEP 9f
 mov d0,d2
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc 9f
 cmp -5,d1
 blt 8f
 cmp 5,d1
 bgt 8f
 mov d0,a3                        /* keep the id */
 clr d0
1:
 cmp 12,d2
 bcs 2f
 add -12,d2
 add 64,d0
 bra 1b
2:
 add -5,d3
 add d3,d0
 add d3,d0                        /* 64k + 2 (axis - 5) */
 add 87,d0                        /* P offset of the page's colour byte */
 cmp 0,d1
 bne 3f
 movbu (d0,a2),d3
 cmp d2,d3
 bne 4f                           /* 0 on another colour: nothing to change */
 movbu d1,(d0,a2)                 /* off: colour 0 ... */
 inc d0
 movbu d1,(d0,a2)                 /* ... strength 0 */
 bra 4f
3:
 movbu d2,(d0,a2)                 /* colour ... */
 inc d0
 movbu d1,(d0,a2)                 /* ... and strength */
4:
 mov a3,d0
 jmp s_dirty
8:
 clr d0
 ret [d2,d3,a2,a3],68
9:
 jmp ed_set

/* tn_poly <- the 48 sector reads of the wheel drawing (build.py points them here instead of ed_poly), `call
 * tn_poly,[],4`, d0 = id: the value shown on a Shadows / Highlights page, else ed_poly. Keeps d2/d3/a2/a3. */
tn_poly:
 movm [d2,d3,a2],(sp)
 TONEP 8f
 mov d0,d2
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc 8f
 TONEV
 movm (sp),[d2,d3,a2]
 ret [],4
8:
 movm (sp),[d2,d3,a2]
 jmp ed_poly

/* ------------------------------------------------------------------ split toning page guides (v0.26 sp2)
 * TONES.BIN (card/mkguides.py): 'OM3S' | u32 total | u32 CRC-32 of bytes 12.. | u32 s1 | u32 s2 | the "Shadows [INFO]"
 * stream | pad 4 | the "Highlights [INFO]" stream (175 x 50, type 11, as GUIDES.BIN's; GUIDES.BIN has no room: its
 * malloc cap). Loaded once per power-on at the half-press load (fl_mk2, before the film list), kept at tg_ptr.
 * Owner (sp1): the guide names the page; the dial label stays the camera's "Vivid". */
.section .ext11,"ax"
.balign 4
tg_ptr:                           /* TONES.BIN heap copy (checked), 0 = none */
 .long 0
tg_path:
 .asciz "C:\\OM3MOD\\TONES.BIN"
.balign 2
/* fl_mk2: pf_load's `call fl_mk2,[d2,d3,a2,a3],80` (a2 = P): TONES.BIN, then fl_mk in the same frame. */
fl_mk2:
 call tg_load,[d2,d3,a2,a3],28
 jmp fl_mk
/* tg_load: `call tg_load,[d2,d3,a2,a3],28`. Locals (4) handle, (8) buffer. Stores: tg_ptr, the heap buffer. */
tg_load:
 mov (tg_ptr),d0
 cmp 0,d0
 bne 9f                           /* loaded already */
 mov tg_path,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 clr d0
 mov 1,d1                         /* END */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov (4,sp),a0
 call ftell,[d2,a2,a3],16
 mov d0,d3                        /* n */
 cmp 21,d3
 bcs 8f
 cmp 16449,d3
 bcc 8f
 mov (4,sp),a0
 clr d0
 mov 2,d1                         /* SET */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov d3,d0
 call malloc,[],4
 cmp 0,a0
 beq 8f
 mov a0,(8,sp)
 mov 1,d0
 mov d3,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp d3,d0
 bne 8f                           /* (a failed file leaves its buffer: once per power-on) */
 mov (8,sp),a2
 mov (a2),d0
 cmp 0x53334d4f,d0                /* 'OM3S' */
 bne 8f
 mov (4,a2),d0
 cmp d3,d0
 bne 8f
 mov (12,a2),d0                   /* 20 + align4(s1) + s2 <= n */
 add 3,d0
 and -4,d0
 mov (16,a2),d1
 add d1,d0
 add 20,d0
 cmp d3,d0
 bhi 8f
 mov -1,d0
 mov a2,a0
 add 12,a0
 mov d3,d1
 add -12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a2),d1
 cmp d1,d0
 bne 8f
 mov a2,(tg_ptr)                  /* published last */
8:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
9:
 ret [d2,d3,a2,a3],28

/* tg_sel <- gd_set (jmp, its frame: a0 = GDESC, a1 = P+GPTR's buffer, d0 = page): pages 5 / 6 with TONES.BIN ->
 * its picture into the guide's descriptor, gd_set's return; without the file -> stream 3 (empty: the camera's);
 * other pages -> back to gd_set (gd_s11). */
tg_sel:
 cmp 5,d0
 bcs 9f
 cmp 7,d0
 bcc 9f
 mov (tg_ptr),d1
 cmp 0,d1
 beq 7f
 mov d1,a1
 cmp 5,d0
 bne 1f
 mov (12,a1),d1                   /* Shadows: s1 at +20 */
 mov d1,(12,a0)
 mov a1,d1
 add 20,d1
 mov d1,(16,a0)
 ret [d2,a2],8
1:
 mov (16,a1),d1                   /* Highlights: s2 after align4(s1) */
 mov d1,(12,a0)
 mov (12,a1),d1
 add 3,d1
 and -4,d1
 add 20,d1
 mov a1,d2
 add d2,d1
 mov d1,(16,a0)
 ret [d2,a2],8
7:
 mov 3,d0
9:
 jmp gd_s11

/* ================================================================== automatic SD loading (v0.25 + SD-native worker)
 * Port of research/caduceus-sd-native-candidate/native2.s (OM-3 research, offline-qualified only): a worker task polls the
 * loader's section masks and the medium word, and wakes the HLS_EVENT task, which runs pr_gate (the same gate the
 * half-press hook uses) without any key. The OK trigger and the half-press hook stay as fallbacks (pr_gate is once per
 * power-on: STATE). Hooks: 0x60af0fb9 (HLS_EVENT entry) and 0x60af101c (its receive boundary), both stock calls.
 * nm_load / nm_pick / nm_path moved to .ext11 (they run only after pr_gate, when every section is loaded) to give this
 * code room in section 4.
 */
/* Placed, trimmed E147 native SD-load path (offline research; see REPORT.md).
 *
 * Linked into reclaimed main-image space in section 4, not into emulator scratch RAM. No data RAM of its own:
 * the worker keeps its state in a callee-saved register (d3) and on its own stack.
 *
 *   sdl_ready          leaf helper shared by the worker and the consumer: d0 = 0 when the loader's section masks and
 *                  the kind-4 media word allow a load, nonzero otherwise. Clobbers d0, d1.
 *   sdl_create_worker  HLS_EVENT task, called from sdl_boot_stub: heap stack, stock create wrapper, stock activate.
 *   sdl_boot_stub      patch site 0x60af0fb9 (HLS_EVENT entry after stock init, before its receive loop).
 *   sdl_worker_entry   task SDLOAD: poll, then one zero-timeout wake to the HLS queue; back off after each send.
 *   sdl_receive_probe  patch site 0x60af101c (HLS_EVENT receive boundary): private wake, tested OK trigger, stock sdl_classifier.
 *
 * Assembler switch (build.py --variant): --defsym NO_BOOT=1 builds the receive hook and consumer without the worker task
 * (the OK-trigger control). Without it the image is the full automatic path.
 */
  .equ SDL_TAG, 0x0100f7ed
  .equ SDL_SECTION_LOADED, 0xa32de590
  .equ SDL_SECTION_INIT, 0xa32de58c
  .equ SDL_MEDIA4, 0x60369308
  .equ SDL_MEDIA3, 0x60369300
  .equ SDL_MEDIA1, 0x603692f8
  .equ SDL_QUEUE, 0x60043180
  .equ SDL_POLL_TICKS, 100
  .equ SDL_WORKER_PRIORITY, 56
  .equ SDL_WORKER_STACK, 2048
  .equ SDL_REQ_LOADED, 0x3ff           /* all ten sections copied (as pr_gate) */
  .equ SDL_REQ_INIT, 0x2e9             /* the init mask bits the load needs (research/caduceus-sd-native-*) */
  .equ SDL_SEND_PERIOD, 10           /* polls skipped after every send attempt: one wake per SDL_SEND_PERIOD+1 polls */

/* Stock 0x60af0fb9: call 0x60af0fff,[d2,d3,a2,a3],24 (5 bytes). */
.section .hook_hb,"ax"
  jmp sdl_boot_stub

/* Stock 0x60af101c: call 0x60af10da,[],0 (5 bytes). */
.section .hook_hr,"ax"
  jmp sdl_receive_probe

.section .ext4,"ax"
sdl_ready:
  mov (SDL_SECTION_LOADED),d0
  not d0
  and SDL_REQ_LOADED,d0
  mov (SDL_SECTION_INIT),d1
  not d1
  and SDL_REQ_INIT,d1
  or d1,d0
  mov (SDL_MEDIA4),d1
  xor 0xf000,d1
  or d1,d0
  retf [],0

sdl_boot_stub:
  call sdl_create_worker,[a2],20
  call sdl_hls_loop,[d2,d3,a2,a3],24
  ret [],4

sdl_create_worker:
  mov a0,a2                       /* the HLS object the stock loop needs; a2 survives every call below */
  mov SDL_WORKER_STACK,d0
  mov sdl_heap_tag,a0
  mov 260,d1
  call sdl_heap_alloc,[],4
  cmp 0,a0
  beq sdl_create_done
  mov SDL_WORKER_PRIORITY,d0
  mov d0,(4,sp)
  mov SDL_WORKER_STACK,d0
  mov d0,(8,sp)
  mov a0,(12,sp)
  mov sdl_worker_name,a0
  clr d0
  mov d0,d1
  mov sdl_worker_entry,a1
  call sdl_task_create,[d2,d3,a2,a3],56
  cmp 0,d0
  blt sdl_create_done
  exth d0
  call sdl_task_start,[d2,d3,a2],16
sdl_create_done:
  mov a2,a0
  ret [a2],20

sdl_worker_entry:
  add -24,sp                      /* (0,sp) belongs to CALL: it writes the return address there */
  clr d0
  mov d0,(4,sp)                   /* wake message {0, SDL_TAG, 0} at 4, descriptor {message, 12} at 16 */
  mov d0,(12,sp)
  mov SDL_TAG,d0
  mov d0,(8,sp)
  mov sp,a0
  add 4,a0
  mov a0,(16,sp)
  mov 12,d0
  mov d0,(20,sp)
  clr d3                          /* d3: polls left before the next send */
sdl_worker_loop:
  mov SDL_POLL_TICKS,d0
  call sdl_dly_tsk,[d2,a2,a3],16
  movhu (STATE),d0
  cmp 0,d0
  bne sdl_worker_done                 /* the loader has begun (or the OK trigger won): stand down */
  cmp 0,d3
  beq sdl_worker_try
  add -1,d3
  bra sdl_worker_loop
sdl_worker_try:
  call sdl_ready,[],0
  cmp 0,d0
  bne sdl_worker_loop
  mov SDL_SEND_PERIOD,d3
  movhu (SDL_QUEUE),d0
  clr d1
  mov sp,a0
  add 16,a0
sdl_worker_send_call:
  call sdl_queue_send,[d2,d3,a2,a3],48
sdl_worker_send_result:
  bra sdl_worker_loop
sdl_worker_done:
  call sdl_ext_tsk,[a2],8
  ret [],24

sdl_worker_name:
  .asciz "SDLOAD"

.section .ext4,"ax"
sdl_receive_probe:
  cmp SDL_TAG,d0
  beq sdl_auto_event
  cmp 0x02000004,d0
  bne sdl_classify
  movhu (STATE),d1
  cmp 0,d1
  bne sdl_classify
  mov (SDL_MEDIA4),d1
  cmp 0xf000,d1
  beq sdl_ok_load
  mov (SDL_MEDIA3),d1
  cmp 0xf000,d1
  beq sdl_ok_load
  mov (SDL_MEDIA1),d1
  cmp 0xf000,d1
  bne sdl_classify
sdl_ok_load:
  /* CALL does not push the return address, but the loop owns (4,sp)..(12,sp): save the live registers below it. */
  add -16,sp
  mov d0,(4,sp)
  mov a0,(8,sp)
  mov a1,(12,sp)
sdl_ok_gate_call:
  call pr_gate,[d2,d3,a2,a3],36
  mov (4,sp),d0
  mov (8,sp),a0
  mov (12,sp),a1
  add 16,sp
sdl_classify:
  call sdl_classifier,[],0
  jmp sdl_resume

sdl_auto_event:
  movhu (STATE),d1
  cmp 0,d1
  bne sdl_consume
  call sdl_ready,[],0
  cmp 0,d0
  bne sdl_consume
  clr d0
  call sdl_drive_status,[d2,d3,a2,a3],20
sdl_consumer_drive_result:
  and 0x10bf,d0
  cmp 0x1080,d0
  bne sdl_consume
  call sdl_ready,[],0                 /* the status call can block: check the media word again before the load */
  cmp 0,d0
  bne sdl_consume
sdl_auto_gate_call:
  call pr_gate,[d2,d3,a2,a3],36
  call sdl_poke,[d2,d3,a2,a3],28     /* sd2: live view was built before the load: make it pick the look up now */
sdl_consume:
  jmp sdl_next_receive

/* ------------------------------------------------------------------ v0.26.2: no out-of-range bytes from EDITS.BIN into BUNDLES.BIN
 * Found and fixed by fernandezk26 (github.com/fernandezk26/camera-stuff, v0.26.3; Apache-2.0), ported here without the stored-WB parts.
 * Films saved by v0.24 / v0.25 hold whatever the heap held in record +53..+63 (the EDITS image block was not zeroed and
 * pf_capto did not write them); v0.26 reads +53..+56 as split toning, copies them into the live slot, and then writes a
 * BUNDLES.BIN its own sd_check refuses at the next power-on.
 * sd_san: `call sd_san,[d2,d3],12`, a0 = 8 slots x 64 B: every byte outside sd_check's range table (sd_lo / sd_span) <- 0
 * (0 is inside every range). Uses d0, d1, a0, a1. */
.section .ext11,"ax"
sd_san:
 clr d2
1:
 movbu (d2,a0),d0
 extb d0
 mov d2,d1
 and 63,d1
 mov sd_lo,a1
 movbu (d1,a1),d3
 extb d3
 sub d3,d0
 mov sd_span,a1
 movbu (d1,a1),d3
 cmp d3,d0
 bls 2f
 clr d0
 movbu d0,(d2,a0)
2:
 inc d2
 cmp PAYLOAD_LEN,d2
 bne 1b
 ret [d2,d3],12

/* tw_san: `call tw_san,[d2,a2],12` from fl_mk, a0 = the EDITS.BIN image after its CRC passed. Each of the 24 records
 * (+16 + 68 r): +53..+56 (split toning: colours 0..11, strengths -5..5) <- 0 as a group when a byte is out of range;
 * +57..+62 (unused) <- 0; +63 <- 0 on films (a COLOR's own record keeps its 0 / 1). Uses d0, d2, a0, a2. */
tw_san:
 add 16,a0
 mov a0,a2
 mov 24,d2
1:
 movbu (53,a2),d0
 cmp 11,d0
 bhi 2f
 movbu (54,a2),d0
 extb d0
 add 5,d0
 cmp 10,d0
 bhi 2f
 movbu (55,a2),d0
 cmp 11,d0
 bhi 2f
 movbu (56,a2),d0
 extb d0
 add 5,d0
 cmp 10,d0
 bls 3f
2:
 clr d0
 movbu d0,(53,a2)
 movbu d0,(54,a2)
 movbu d0,(55,a2)
 movbu d0,(56,a2)
3:
 clr d0
 movbu d0,(57,a2)
 movbu d0,(58,a2)
 movbu d0,(59,a2)
 movbu d0,(60,a2)
 movbu d0,(61,a2)
 movbu d0,(62,a2)
 cmp 4,d2
 bhi 6f                           /* d2 counts 24 .. 1: 24 .. 5 = films, 4 .. 1 = COLOR 1-4's own, whose +63 is their '*' (0 / 1) */
 movbu (63,a2),d0
 cmp 1,d0
 bls 7f
 clr d0
6:
 movbu d0,(63,a2)
7:
 add 68,a2
 add -1,d2
 bne 1b
 ret [d2,a2],12

/* sdl_poke: `call sdl_poke,[d2,d3,a2,a3],28` after the automatic load (HLS_EVENT task). Owner, sd1 on the camera: after
 * power-on live view showed the stock COLOR, not the film, until something rebuilt it (the half-press used to). When the
 * block is published and the picture mode is COLOR k: the wheel's cursor setting 2197 + k re-written with its own value,
 * the same poke the editor uses after every change (k_cur + SetValue), which is what makes live view take the slot. */
.section .ext11,"ax"
sdl_poke:
 movhu (STATE),d0
 cmp 0,d0
 beq 9f
 cmp 0xae81,d0
 bcc 9f                           /* 0xffff: tried, nothing published */
 mov 111,d0
 call sget,[],4
 call fl_k,[],0
 cmp 0,d0
 blt 9f
 add 2197,d0
 mov d0,d2
 call facade,[],4
 mov (a0),a2
 mov (12,a2),a2                   /* GetValue(id, &value) */
 mov sp,a1
 add 8,a1
 mov d2,d0
 calls (a2)
 cmp 0,d0
 bne 9f
 call facade,[],4
 mov (a0),a2
 mov (4,a2),a2                    /* SetValue(id, mode 0, value) */
 mov (8,sp),a1
 clr d1
 mov d2,d0
 calls (a2)
9:
 ret [d2,d3,a2,a3],28

/* sd3: the super control panel's Picture Mode cell steps with the dials through its own table (0x615384b4, 6 x {key, count,
 * default, records}; records 20 B {0, value, 0, 0, availability id}). Entry 5 (key 901: the COLOR position) had COLOR 1-4;
 * build.py points it here: the stock four, then the films FV0 + j with FLB + j (the step helpers skip a film that is
 * not there, as they skip a picture mode that is switched off). SetValue 901 <- FV0 + j is fl_set, as from the list. */
.section .ext11,"ax"
.balign 4
fl_scr:
 .long 0, 54, 0, 0, 1072
 .long 0, 55, 0, 0, 1073
 .long 0, 56, 0, 0, 1074
 .long 0, 64, 0, 0, 1075
 .irp j, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
 .long 0, FV0 + \j, 0, 0, FLB + \j
 .endr

/* fl_scw <- 0x61157d30 `call 0x6128abe0,[d2,a2],12` in the super control panel's update (a0 = the Picture Mode cell's
 * widget, d0 = its choice: 16..19 for COLOR 1-4), entered by the same call. The widget draws again only when its choice
 * changes, and a step from one film to the next on the same COLOR leaves it (emulator: no picture / title request). After
 * a film change (fl_scf, set by fl_set): the neighbouring choice first, then the stock call with the real one. */
.section .hook_ag,"ax"
 jmp ar_get                       /* v0.27 stock 0x610833b3 (the key dispatcher's value read): mov d0,d2; mov 3413,d1;
                                   * mov d1,d0 (5 bytes) */
.section .hook_ex,"ax"
 jmp ex_hook                      /* v0.27: the film's name in the photo's EXIF (ex_hook) */
 .byte 0xcb, 0xcb, 0xcb
.section .hook_dmg,"ax"
 cmp d2,d0                        /* v0.27: the dial handler always sets 897 (stock beq +0x16 skipped it when the */
 .byte 0xc8, 0x02                 /* family was unchanged; a mapped position must act even then): beq +2 = next */
.section .hook_scw,"ax"
 call fl_scw,[d2,a2],12
.section .ext11,"ax"
fl_scf:
 .long 0
fl_scw:
 movbu (fl_scf),d1
 cmp 0,d1
 beq 9f
 clr d1
 movbu d1,(fl_scf)
 add -12,sp
 mov a0,(4,sp)
 mov d0,(8,sp)
 xor 1,d0
 call scw_set,[d2,a2],12
 mov (4,sp),a0
 mov (8,sp),d0
 add 12,sp
 mov (sp),d1                      /* MDR = our caller's return address again (the nested call overwrote it) */
 mov d1,mdr
9:
 jmp scw_set

/* fl_stw <- jmp from 0x6128b1d3 `call 0x6128ab86,[],4; jmp 0x6128b2c6` (8 bytes; a text widget's string id <- d0, a0 = the widget; the super control
 * panel's title comes through here with 2755 / 2756 / 2757 / 4769 "Color Profile k", which fl_tt reads as the film's
 * name). The same string id draws nothing new, so after a film change (fl_scf + 1) another of the four first. */
.section .hook_stw,"ax"
 jmp fl_stw
 nop
 nop
 nop
.section .ext11,"ax"
fl_stw:
 movbu (fl_scf + 1),d1
 cmp 0,d1
 beq 9f
 mov 2756,d1
 cmp 2755,d0
 beq 1f
 mov 2755,d1
 cmp 2756,d0
 beq 1f
 cmp 2757,d0
 beq 1f
 cmp 4769,d0
 bne 9f
1:
 add -12,sp
 mov a0,(4,sp)
 mov d0,(8,sp)
 mov d1,d0
 clr d1
 movbu d1,(fl_scf + 1)
 call stw_set,[],4
 mov (4,sp),a0
 mov (8,sp),d0
 add 12,sp
9:
 call stw_set,[],4
 jmp stw_back


/* ---------------------------------------------------------------- v0.27 debug log (feature/debug-log)
 * Off unless the card holds OM3MOD/DEBUG.TXT (any content) (checked once, at the first gated half-press of a power-on).
 * When on, every shutter button event (half-press, release; after the editor's save) rewrites OM3MOD/CADLOG.TXT, a plain text report: the build,
 * counters, the picture mode, which card files are loaded, the last save result, and the last 32 half-presses.
 * Lives in ext12 (section 6 +256 KiB, camera-proven GX3, 2026-11-10); its variables are in the same loaded RAM
 * (power-on: all 0). Stores: its own variables and buffer, its own frames. Reads P (PVAL) and tg_ptr only. */
.section .ext12,"ax"
 .macro LGS s                     /* append the string at \s (uses d0, a0, a1) */
 mov \s,a0
 call lg_s,[],0
 .endm
 .macro LGD                       /* append d0 in decimal (uses d0, d1, a0, a1) */
 call lg_d,[d2,d3],12
 .endm
 .macro LGY                       /* append "yes" (d0 != 0) or "no" */
 call lg_y,[],0
 .endm
lg_pr:                            /* jmp from pr_ed, pr_hook's frame: as `call ed_trig; jmp trig_resume` there */
 call lg_pre,[d2,d3,a2,a3],36
 call ed_trig,[d2,d3,a2,a3],36
 call lg_write,[d2,d3,a2,a3],40
 jmp trig_resume
lg_pre:                           /* edits waiting before ed_trig (it saves them and clears DIRTY) */
 clr d0
 movbu d0,(lg_dty)
 PVAL 1f
 movbu (DIRTY,a2),d0
 movbu d0,(lg_dty)
1:
 ret [d2,d3,a2,a3],36

lg_write:                         /* frame 40: (0) call slot, (4) handle, (12) tid */
 mov (SECBITS),d0                 /* the card gate (as the loaders and the GX probes) */
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne lg_out
 mov sp,a0
 add 12,a0
 call get_tid,[a2],4
 cmp 0,d0
 bne lg_out
 movhu (HLS_TID),d1
 cmp 0,d1
 beq lg_out
 btst 0x8000,d1
 bne lg_out
 movhu (12,sp),d0
 cmp d1,d0
 bne lg_out
 mov 61440,d1
 mov (MS_A),d0
 cmp d1,d0
 beq 1f
 mov (MS_B),d0
 cmp d1,d0
 beq 1f
 mov (MS_C),d0
 cmp d1,d0
 bne lg_out
1:
 movbu (lg_on),d0                 /* 0 not checked yet, 1 on, 2 off */
 cmp 2,d0
 beq lg_out
 cmp 1,d0
 beq 2f
 mov 2,d0
 movbu d0,(lg_on)
 mov lg_pon,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq lg_out
 call fclose,[d2,a2,a3],16
 mov 1,d0
 movbu d0,(lg_on)
 call lg_chk,[d2,d3,a2,a3],40     /* dl6: the card files' presence and header checksums, once */
2:
 mov (lg_n),d2                    /* the event: number, picture mode, edits waiting, save result after */
 inc d2
 mov d2,(lg_n)
 mov d2,d1
 and 31,d1
 asl 4,d1
 mov lg_ring,a3
 add d1,a3
 mov d2,(a3)
 mov 111,d0
 call sget,[],4                   /* d0 = the picture mode setting (keeps d2/d3/a2/a3) */
 mov d0,(4,a3)
 mov 897,d0                       /* v0.27 research: the active picture-mode family (the Creative Dial) -> +12 */
 call sget,[],4
 mov d0,(12,a3)
 mov (4,a3),d0
 call fl_k,[],0                   /* dl5 (camera dl3: a film reads as its COLOR, 54): COLOR k, and its look n -> */
 movbu d0,(11,a3)                 /* +11 k (255 = not a COLOR), +10 film 5k + n (1..20, 0 = none), as fl_get */
 clr d1
 movbu d1,(10,a3)
 cmp 0,d0
 blt 13f
 PVAL 13f
 mov a2,a0
 add d0,a0
 movbu (LIDX,a0),d1
 extb d1
 cmp 1,d1
 blt 13f
 cmp 5,d1
 bgt 13f
 mov d0,d2
 asl2 d2
 add d0,d2
 add d1,d2
 movbu d2,(10,a3)
13:
 movbu (lg_dty),d0
 movbu d0,(8,a3)
 mov 255,d0
 movbu d0,(9,a3)
 PVAL 3f
 movbu (STATUS,a2),d0
 movbu d0,(9,a3)
3:
 mov (lg_w),d0
 inc d0
 mov d0,(lg_w)
 mov lg_buf,a0                    /* the text */
 mov a0,(lg_cur)
 LGS lg_t1
 LGS lg_ver
 LGS lg_t2
 mov (lg_n),d0
 LGD
 LGS lg_t3
 mov (lg_w),d0
 LGD
 LGS lg_t4
 mov (4,a3),d0
 LGD
 movbu (11,a3),d2
 cmp 4,d2
 bcc 4f
 LGS lg_t5
 mov d2,d0
 inc d0
 LGD
 movbu (10,a3),d2
 cmp 0,d2
 beq 4f
 LGS lg_t5b
 mov d2,d0
 LGD
4:
 LGS lg_d0                        /* the Creative Dial's family */
 mov (12,a3),d0
 call lg_fm,[d2,d3],12
 LGS lg_t6
 PVAL 5f
 LGS lg_found
 LGS lg_k1
 mov (LPTR,a2),d0
 LGY
 LGS lg_k2
 mov (XPTR,a2),d0
 LGY
 LGS lg_k3
 mov (GPTR,a2),d0
 LGY
 LGS lg_k4
 mov (tg_ptr),d0
 LGY
 LGS lg_k5
 mov (TORG,a2),d0
 LGY
 LGS lg_k6
 mov (NPTR,a2),d0
 LGY
 LGS lg_k7
 mov (EMARK,a2),d1
 clr d0
 cmp EMAGIC,d1
 bne 6f
 mov 1,d0
6:
 LGY
 LGS lg_k8
 movbu (DIRTY,a2),d0
 LGY
 LGS lg_k9
 movbu (STATUS,a2),d0
 call lg_st,[d2,d3],12
 bra 7f
5:
 LGS lg_miss
 movhu (STATE),d0
 LGD
 LGS lg_k0
7:
 PVAL 15f                         /* dl6: card files vs this firmware (a2 = P, or 0) */
 bra 16f
15:
 mov 0,a2
16:
 LGS lg_c0
 clr d2
 mov lg_ft,a3
 mov LG_NF,d3
17:
 call lg_vd,[],0
 cmp 1,d0
 bcs 18f
 cmp 5,d0
 bcc 18f
 inc d2                           /* verdicts 1..4: a mismatch */
18:
 add 20,a3
 add -1,d3
 cmp 0,d3
 bne 17b
 mov lg_c1,a0
 cmp 0,d2
 beq 19f
 mov lg_c2,a0
19:
 call lg_s,[],0
 mov lg_ft,a3
 mov LG_NF,d3
20:
 LGS lg_nl
 mov (a3),a0
 add 10,a0                        /* the name after C:\OM3MOD\ */
 call lg_s,[],0
 LGS lg_c3
 call lg_vd,[],0
 mov d0,d2
 asl2 d0
 mov lg_vt,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 cmp 3,d2
 bne 21f
 LGS lg_c4
 mov (16,a3),d0
 call lg_h,[],0
 LGS lg_c5
 mov (8,a3),d0
 call lg_h,[],0
 LGS lg_k0
21:
 add 20,a3
 add -1,d3
 cmp 0,d3
 bne 20b
 LGS lg_t7                        /* the last 32 events, oldest first */
 mov (lg_n),d2
 clr d3
 cmp 33,d2
 bcs 8f
 mov d2,d3
 add -32,d3
8:
 inc d3
9:
 cmp d3,d2
 bcs 10f
 mov d3,d1
 and 31,d1
 asl 4,d1
 mov lg_ring,a3
 add d1,a3
 LGS lg_e1
 mov (a3),d0
 LGD
 LGS lg_e2
 mov (4,a3),d0
 LGD
 movbu (10,a3),d0
 cmp 0,d0
 beq 14f
 LGS lg_t5b
 movbu (10,a3),d0
 LGD
14:
 LGS lg_d1
 mov (12,a3),d0
 call lg_fm,[d2,d3],12
 LGS lg_e3
 movbu (8,a3),d0
 LGY
 LGS lg_e4
 movbu (9,a3),d0
 call lg_st,[d2,d3],12
 LGS lg_nl
 inc d3
 bra 9b
10:
 mov (lg_cur),a0                  /* camera: fopen "w" does not truncate (dl3, 2026-11-10): always the same length, */
 mov lg_bend,a1                   /* spaces after the text, CR LF last */
 add -2,a1
 mov 32,d0
11:
 cmp a1,a0                        /* a0 - a1 */
 bcc 12f
 movbu d0,(a0)
 inc a0
 bra 11b
12:
 mov 13,d0
 movbu d0,(a1)
 mov 10,d0
 movbu d0,(1,a1)
 mov lg_plog,a0                   /* CADLOG.TXT */
 mov lg_mw,a1
 call fopen,[],4
 cmp 0,a0
 beq lg_out
 mov a0,(4,sp)
 mov (4,sp),a1
 mov lg_bend - lg_buf,d1
 mov 1,d0
 mov lg_buf,a0
 call fwrite,[d2,d3,a2,a3],24
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
lg_out:
 ret [d2,d3,a2,a3],40

lg_chk:                           /* `call lg_chk,[d2,d3,a2,a3],40`: each lg_ft file -> found 1 missing / 2 there, and
                                   * its header's CRC word (+8). Frame: (0) call slot, (4) handle */
 mov lg_ft,a3
 mov LG_NF,d3
1:
 mov (a3),a0
 mov lg_mr,a1
 call fopen,[],4
 mov 1,d0
 cmp 0,a0
 beq 2f
 mov a0,(4,sp)
 clr d0
 mov d0,(lg_hdr+8)
 mov 1,d0
 mov 16,d1
 mov lg_hdr,a0
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 mov (lg_hdr+8),d0
 mov d0,(16,a3)
 mov 2,d0
2:
 mov d0,(12,a3)
 add 20,a3
 add -1,d3
 cmp 0,d3
 bne 1b
 ret [d2,d3,a2,a3],40
lg_vd:                            /* `call lg_vd,[],0`: a3 = lg_ft row, a2 = P or 0 -> d0 verdict (lg_vt) */
 mov (12,a3),d0
 mov (4,a3),d1
 cmp 2,d0
 beq 1f
 mov 1,d0                         /* missing */
 cmp 4,d1
 bne 9f
 mov 7,d0                         /* the camera's own file: not made yet */
 bra 9f
1:
 cmp 4,d1
 bne 2f
 mov 6,d0
 bra 9f
2:
 cmp 3,d1
 bcc 4f
 cmp 0,d1
 beq 4f
 mov (16,a3),d0                   /* LABELS / TONES: the header checksum vs this build's copy (TONES loads only */
 mov (8,a3),d1                    /* after LOOKS, so its own content decides, not whether it is loaded) */
 cmp d1,d0
 beq 8f
 mov (4,a3),d1
 cmp 2,d1
 bne 3f
 mov (tg_ptr),d0                  /* a different TONES.BIN the camera refused */
 cmp 0,d0
 beq 7f
3:
 mov 3,d0
 bra 9f
4:
 cmp 0,a2
 bne 5f
 mov 8,d0
 bra 9f
5:
 cmp 3,d1
 bne 6f
 mov (LPTR,a2),d0                 /* LOOKS.BIN: loaded = valid */
 cmp 0,d0
 beq 7f
 mov 5,d0
 bra 9f
6:
 mov (GPTR,a2),d0                 /* GUIDES.BIN: pictures loaded = valid; code block = same build (x_load's tag) */
 cmp 0,d0
 beq 7f
 mov (XPTR,a2),d0
 cmp 0,d0
 bne 8f
 mov 2,d0
 bra 9f
7:
 mov 4,d0
 bra 9f
8:
 clr d0
9:
 ret [],0
lg_s:                             /* `call lg_s,[],0`: a0 = string -> appended (stops near the buffer's end) */
 mov (lg_cur),a1
1:
 mov lg_bend,d0
 cmp a1,d0                        /* d0 - a1 */
 bcs 2f
 movbu (a0),d0
 cmp 0,d0
 beq 2f
 movbu d0,(a1)
 inc a0
 inc a1
 bra 1b
2:
 mov a1,(lg_cur)
 ret [],0
lg_h:                             /* `call lg_h,[],0`: d0 -> 8 hex digits (uses d0, d1, a0, a1) */
 mov (lg_cur),a1
 mov lg_bend,d1
 cmp a1,d1
 bcs 3f
 mov 8,a0
1:
 mov d0,d1
 lsr 28,d1
 cmp 10,d1
 bcs 2f
 add 7,d1
2:
 add 48,d1
 movbu d1,(a1)
 inc a1
 asl 4,d0
 add -1,a0
 cmp 0,a0
 bne 1b
 mov a1,(lg_cur)
3:
 ret [],0
lg_y:                             /* `call lg_y,[],0`: d0 != 0 -> "yes", else "no" */
 mov lg_yes,a0
 cmp 0,d0
 bne lg_s
 mov lg_no,a0
 bra lg_s
lg_st:                            /* `call lg_st,[d2,d3],12`: d0 = a save result -> its number and meaning */
 mov d0,d2
 LGD
 cmp 5,d2
 bcc 1f
 asl2 d2
 mov lg_stt,a0
 add d2,a0
 mov (a0),a0
 call lg_s,[],0
1:
 ret [d2,d3],12
lg_fm:                            /* `call lg_fm,[d2,d3],12`: d0 = a sid-897 family -> its name (or the number) */
 mov lg_fmt,a0
1:
 mov (a0),d1
 cmp 0,d1
 beq 2f
 cmp d1,d0
 beq 3f
 add 8,a0
 bra 1b
2:
 jmp lg_d                         /* unknown: the number (lg_d's frame is the same) */
3:
 mov (4,a0),a0
 call lg_s,[],0
 ret [d2,d3],12
lg_d:                             /* `call lg_d,[d2,d3],12`: d0 -> unsigned decimal */
 mov (lg_cur),a1
 mov lg_bend,d1
 cmp a1,d1
 bcs 5f
 mov lg_p10,a0
 clr d3                           /* a digit seen */
1:
 mov (a0),d1
 clr d2
2:
 cmp d1,d0                        /* d0 - d1 */
 bcs 3f
 sub d1,d0
 inc d2
 bra 2b
3:
 or d2,d3
 cmp 1,d1
 beq 4f
 cmp 0,d3
 beq 6f
4:
 add 48,d2
 movbu d2,(a1)
 inc a1
6:
 inc4 a0
 cmp 1,d1
 bne 1b
 mov a1,(lg_cur)
5:
 ret [d2,d3],12

 .balign 4
lg_p10:
 .long 1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1
lg_stt:
 .long lg_s0, lg_s1, lg_s2, lg_s3, lg_s4
lg_n:                             /* events so far this power-on */
 .long 0
lg_w:                             /* CADLOG.TXT writes this power-on */
 .long 0
lg_cur:
 .long 0
lg_on:
 .byte 0
lg_dty:
 .byte 0
 .balign 4
lg_ft:                            /* {path, kind, this build's header CRC (build.py), found, header CRC} (20 B):
                                   * kind 0 GUIDES, 1 LABELS, 2 TONES, 3 LOOKS, 4 written by the camera */
 .long lg_f0, 0, 0, 0, 0
 .long lg_f1, 1, 0x4c475831, 0, 0
 .long lg_f2, 2, 0x4c475831, 0, 0
 .long lg_f3, 3, 0, 0, 0
 .long lg_f4, 4, 0, 0, 0
 .long lg_f5, 4, 0, 0, 0
 .set LG_NF, 6
lg_fmt:                           /* sid 897 family -> name */
 .long 901, lg_n1, 988, lg_n2, 899, lg_n3, 900, lg_n4, 898, lg_n5, 0
lg_vt:
 .long lg_v0, lg_v1, lg_v2, lg_v3, lg_v4, lg_v5, lg_v6, lg_v7, lg_v8
lg_hdr:
 .space 16
 .balign 16
lg_ring:                          /* 32 x {u32 number, u32 picture mode, u8 edits waiting, u8 save result (255 = no P),
                                   * u8 film 1..20 (0 = none), u8 COLOR k (255 = none)} */
 .space 32 * 16
lg_buf:
 .space 5120
lg_bend:                          /* lg_s / lg_d stop 64 bytes before the end */
 .space 64
lg_pon:
 .asciz "C:\\OM3MOD\\DEBUG.TXT"
lg_plog:
 .asciz "C:\\OM3MOD\\CADLOG.TXT"
lg_mr:
 .asciz "r"
lg_mw:
 .asciz "w"
 .include "lgver.inc"
lg_t1:
 .asciz "Caduceus for OM-3 debug log\r\nBuild: "
lg_t2:
 .asciz "\r\nShutter button events since power-on: "
lg_t3:
 .asciz "\r\nLog file writes (this one included): "
lg_t4:
 .asciz "\r\nPicture mode setting: "
lg_t5:
 .asciz " = COLOR "
lg_t5b:
 .asciz ", FILM "
lg_t6:
 .asciz "\r\n\r\nSettings block: "
lg_found:
 .asciz "found"
lg_miss:
 .asciz "missing (state "
lg_k0:
 .asciz ")"
lg_f0:
 .asciz "C:\\OM3MOD\\GUIDES.BIN"
lg_f1:
 .asciz "C:\\OM3MOD\\LABELS.BIN"
lg_f2:
 .asciz "C:\\OM3MOD\\TONES.BIN"
lg_f3:
 .asciz "C:\\OM3MOD\\LOOKS.BIN"
lg_f4:
 .asciz "C:\\OM3MOD\\EDITS.BIN"
lg_f5:
 .asciz "C:\\OM3MOD\\BUNDLES.BIN"
lg_d0:
 .asciz "\r\nCreative Dial family: "
lg_d1:
 .asciz "  dial "
lg_n1:
 .asciz "COLOR"
lg_n2:
 .asciz "MONO"
lg_n3:
 .asciz "ART"
lg_n4:
 .asciz "CRT"
lg_n5:
 .asciz "898 (8-value family, not a dial position)"
lg_c0:
 .asciz "\r\n\r\nCard files: "
lg_c1:
 .asciz "all match this firmware"
lg_c2:
 .asciz "MISMATCH - see the lines marked MISMATCH or MISSING"
lg_c3:
 .asciz ": "
lg_c4:
 .asciz " (its checksum "
lg_c5:
 .asciz ", this firmware's copy "
lg_v0:
 .asciz "matches this firmware"
lg_v1:
 .asciz "MISSING"
lg_v2:
 .asciz "MISMATCH - made for a different firmware build"
lg_v3:
 .asciz "MISMATCH - a different version, not the copy made for this firmware"
lg_v4:
 .asciz "MISMATCH - damaged or the wrong format (the camera refused it)"
lg_v5:
 .asciz "OK (your own films)"
lg_v6:
 .asciz "OK (written by the camera)"
lg_v7:
 .asciz "not made yet (normal: the camera makes it when you save edits)"
lg_v8:
 .asciz "not checked (no settings block)"
lg_k1:
 .asciz "\r\nLOOKS.BIN looks loaded: "
lg_k2:
 .asciz "\r\nGUIDES.BIN code block loaded: "
lg_k3:
 .asciz "\r\nGUIDES.BIN guide pictures loaded: "
lg_k4:
 .asciz "\r\nTONES.BIN loaded: "
lg_k5:
 .asciz "\r\nEDITS.BIN and film pictures loaded: "
lg_k6:
 .asciz "\r\nNAMES.BIN loaded (optional): "
lg_k7:
 .asciz "\r\nEditor opened since power-on: "
lg_k8:
 .asciz "\r\nEdits waiting to be saved: "
lg_k9:
 .asciz "\r\nLast save result: "
lg_t7:
 .asciz "\r\n\r\nLast 32 shutter button events (half-press and release), oldest first:\r\n"
lg_e1:
 .asciz "#"
lg_e2:
 .asciz "  picture mode "
lg_e3:
 .asciz "  edits waiting "
lg_e4:
 .asciz "  save result "
lg_nl:
 .asciz "\r\n"
lg_yes:
 .asciz "yes"
lg_no:
 .asciz "no"
lg_s0:
 .asciz " (none yet)"
lg_s1:
 .asciz " (saved)"
lg_s2:
 .asciz " (no memory)"
lg_s3:
 .asciz " (BUNDLES.NEW write failed)"
lg_s4:
 .asciz " (BUNDLES.BIN write failed)"

/* ---------------------------------------------------------------- v0.27 Creative Dial mapping (feature/v0.27-buttons)
 * The dial sets sid 897 (the picture-mode family) through the facade SetValue (camera dl8 + om-emu trace, 2026-11-10):
 * CRT 900, ART 899, COLOR 901, MONO 988. For a mapped position: 897 <- 901 (COLOR) through the manager, then 901 <- the
 * target through fl_set, as the Picture Mode list does (same SetValue: a0 inner, a1 mode; frame 68). Unmapped: stock.
 * dm_map per position (CRT, ART, COLOR, MONO): 0 stock, 1..4 COLOR k, 11..30 FILM 1..20.
 * Not yet: power-on (the start-up path sets 897 without the facade), MONO targets, the Control Panel setting. */
.section .ext12,"ax"
sx_set:                           /* from sl_set (entered as the manager: d0 id, d1 value, a0, a1; frame 68) */
 cmp 901,d0
 bne 1f
 mov a0,(dm_xa0)                  /* dr5: the dial position on COLOR keeps this choice (dm_rec) */
 mov a1,(dm_xa1)
 mov d1,(dm_xv)
 call dm_rec,[d2,d3,a2,a3],20
 mov (dm_xa0),a0
 mov (dm_xa1),a1
 mov 901,d0
 mov (dm_xv),d1
 jmp fl_set
1:
 cmp 897,d0
 beq 2f
 jmp sl_set0
2:
 clr d2
 mov dm_fam,a3
3:
 mov (a3),d3
 cmp d3,d1
 beq 4f
 inc4 a3
 inc d2
 cmp 4,d2
 bcs 3b
 jmp sl_set0                      /* not a dial family: stock (d0, d1 untouched) */
4:                                /* d2 = position 0..3 (CRT, ART, COLOR, MONO), a3 -> its family */
 call dm_ok,[],0                  /* films loaded? (uses d1) */
 cmp 0,d1
 bne 41f
40:
 mov 897,d0                       /* stock, with the family back in d1 */
 mov (a3),d1
 jmp sl_set0
41:                               /* v0.27 dr3 (owner): each position -> a mode (its own / CRT / ART / COLOR / MONO);
                                   * a position on COLOR keeps its own COLOR choice (dm_turn) */
 mov a0,(dm_xa0)
 mov a1,(dm_xa1)
 call dm_turn,[d2,d3,a2,a3],20    /* -> d0 = the mode 0..3 (CRT, ART, COLOR, MONO), d1 = its COLOR choice or 0 */
 mov (dm_xa0),a0
 mov (dm_xa1),a1
 cmp 2,d0
 beq 43f
 mov dm_fam,a3                    /* not COLOR: that mode's family, the stock way */
 asl2 d0
 add d0,a3
 mov 897,d0
 mov (a3),d1
 jmp sl_set0
43:
 mov d1,d3
 cmp 0,d3
 bne 55f
 mov 897,d0                       /* COLOR, nothing remembered yet: as it is */
 mov 901,d1
 jmp sl_set0
55:
 add -12,sp                       /* (0) call slot, (4) a0, (8) a1 */
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov 897,d0
 mov 901,d1
 call manager,[d2,d3,a2,a3],68    /* the family: COLOR */
 mov (4,sp),a0
 mov (8,sp),a1
 add 12,sp
 mov 901,d0
 cmp 11,d3
 bcc 6f
 add -1,d3                        /* COLOR k */
 and 3,d3
 mov fl_cvt,a3
 add d3,a3
 movbu (a3),d1
 jmp fl_set
6:
 add FV0 - 11,d3                  /* FILM n = code - 10 -> FV0 + n - 1 */
 mov d3,d1
 jmp fl_set
/* dm_turn: `call dm_turn,[d2,d3,a2,a3],20`, d2 = the position the dial is on now (0..3: CRT, ART, COLOR, MONO) ->
 * d0 = its mode (0..3), d1 = the COLOR choice it keeps (dm_cur code, 0 none). Reads only: no setting is written here
 * (dr4 on the camera: writing settings from the power-on path made the start slow and once froze it). The choices are
 * written when the owner changes the COLOR choice (dm_rec, from the SetValue(901) in sx_set). */
dm_turn:
 movbu d2,(dm_pos)
 mov d2,d3
 call dm_mode,[d2,d3],12
 mov d0,(dm_xmd)
 clr d1
 cmp 2,d0
 bne 9f
 mov dm_psid,a2                   /* its own COLOR choice */
 mov d2,d0
 asl2 d0
 add d0,a2
 mov (a2),d0
 call sget,[],4
 add -PV0,d0
 mov d0,d1
 cmp 1,d1
 bcs 8f
 cmp 5,d1
 bcs 9f
 cmp 11,d1
 bcs 8f
 cmp 31,d1
 bcs 9f
8:
 clr d1
9:
 mov (dm_xmd),d0
 ret [d2,d3,a2,a3],20

/* dm_rec: `call dm_rec,[d2,d3,a2,a3],20` from sx_set's SetValue(901, d1) before fl_set (a0 / a1 in dm_xa0 / dm_xa1):
 * when the dial's position (dm_pos, known after the first dial event or the power-on mapping) is on COLOR, its own
 * choice = this value (COLOR k -> k + 1, film j -> 11 + j), written to its dm_psid setting if it changed. */
dm_rec:
 movbu (dm_pos),d3
 cmp 4,d3
 bcc 9f
 mov d1,d2                        /* the value -> a dm_cur code */
 mov d1,d0
 call fl_k,[],0
 cmp 0,d0
 blt 1f
 add 1,d0
 bra 2f
1:
 mov d2,d0
 add -FV0,d0
 cmp 20,d0
 bcc 9f
 add 11,d0
2:
 mov d0,d2                        /* code */
 call dm_mode,[d2,d3],12          /* (d3 = the position) */
 cmp 2,d0
 bne 9f
 mov dm_psid,a2
 mov d3,d0
 asl2 d0
 add d0,a2
 mov (a2),d0
 call sget,[],4
 mov d2,d1
 add PV0,d1
 cmp d1,d0
 beq 9f
 mov (a2),d0
 call dm_put,[d2,d3,a2,a3],80
9:
 ret [d2,d3,a2,a3],20

/* dm_mode: `call dm_mode,[d2,d3],12`, d3 = a position 0..3 -> d0 = its mode 0..3 (its row: Normal = its own). Uses
 * a0, a1, d1. */
dm_mode:
 mov dm_sid,a0
 mov d3,d0
 asl2 d0
 add d0,a0
 mov (a0),d0
 call sget,[],4
 add -DV1,d0
 cmp 5,d0
 bcc 1f
 cmp 0,d0
 beq 1f
 add -1,d0
 ret [d2,d3],12
1:
 mov d3,d0
 ret [d2,d3],12

/* dm_put: `call dm_put,[d2,d3,a2,a3],80`, d0 = a setting, d1 = its value: through the manager, with the SetValue's
 * a0 / a1 (as sx_set's own family write) */
dm_put:
 mov (dm_xa0),a0
 mov (dm_xa1),a1
 call manager,[d2,d3,a2,a3],68
 ret [d2,d3,a2,a3],80

dm_cur:                           /* `call dm_cur,[d2,d3,a2,a3],12` -> d0 = the current COLOR choice as a dm_map
                                   * code (1..4 COLOR k, 11..30 FILM n), 0 if unknown. Uses a0, a1, d1. */
 mov 901,d0
 call sget,[],4                   /* COLOR k's picture mode value (kept while another family is on) */
 call fl_k,[],0
 cmp 0,d0
 blt 9f
 mov d0,d2
 PVAL 9f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d1
 extb d1
 cmp 1,d1
 blt 8f
 cmp 5,d1
 bgt 8f
 mov d2,d0                        /* FILM 5k + n = code 10 + 5k + n */
 asl2 d0
 add d2,d0
 add d1,d0
 add 10,d0
 ret [d2,d3,a2,a3],12
8:
 mov d2,d0                        /* COLOR k itself */
 inc d0
 ret [d2,d3,a2,a3],12
9:
 clr d0
 ret [d2,d3,a2,a3],12
 .balign 4
dm_a1:
 .long 0
dm_fam:
 .long 900, 899, 901, 988         /* CRT, ART, COLOR, MONO */
dm_ok:                            /* `call dm_ok,[],0` -> d1 1 when P is valid and the films are loaded, else 0
                                   * (PVAL's checks with d1 / a1; d0, a0 and a1 kept: a1 is the SetValue's mode) */
 mov a1,(dm_a1)
 movhu (STATE),d1
 add -1,d1
 cmp HMAX,d1
 bcc 9f
 btst 3,d1
 bne 9f
 mov d1,a1
 add POOL,a1
 mov (a1),d1
 cmp MAGIC,d1
 bne 9f
 mov (LPTR,a1),d1
 cmp 0,d1
 beq 9f
 mov 1,d1
 mov (dm_a1),a1
 ret [],0
9:
 clr d1
 mov (dm_a1),a1
 ret [],0
dm_own:                           /* the owner's own COLOR choice while a mapped position replaced it (0 = none) */
 .byte 0

/* v0.27 dial rows (owner, 2026-11-10: set in the camera's Button Function menu, as the other buttons). One row per
 * position: CRT -> sid 571, ART -> 54, COLOR -> 55, MONO -> 1966 (buttons of other OM bodies with row, item and picker
 * entries; 571's validator record is 1967's, an unused movie button). Values DV0 + code: 0 Normal (the position's own
 * mode), 1..4 COLOR k, 11..30 FILM 1..20. Pickers: variants of keys 9 / 11 / 12 / 13 with our 25 options (build.py). */
 .set DV0, 3800                   /* dr1 / dr2 values (read as Normal now) */
 .set DV1, 3900                   /* dr3: DV1 + 0 Normal, 1 CRT, 2 ART, 3 COLOR, 4 MONO */
 .set PV0, 4000
 .set LV0, 4100
 .set ST_DC0, 0x7f48              /* "CRT", "ART", "COLOR", "MONO" (dr3) */
 .set ST_DH, 0x7f4c               /* the options' help text */
 .set ST_DF0, 0x7f50              /* "FILM 1".."FILM 20" (cells and the row's value; the title has the film's name) */
 .balign 4
dm_sid:
 .long 571, 54, 55, 1966          /* CRT, ART, COLOR, MONO */
dm_psid:                          /* dr3: each position's own COLOR choice (PV0 + dm_cur code): unused movie buttons */
 .long 1958, 1277, 1275, 1284
dm_lsid:                          /* the position the dial was on last (LV0 + 0..3) */
 .long 1285
dm_xa0:
 .long 0
dm_xa1:
 .long 0
dm_xmd:
 .long 0
dm_xv:
 .long 0
dm_pos:                           /* the dial's position (0..3) once known this power-on, else 0xff */
 .byte 0xff
 .balign 4
dm_plist:                         /* their values: PV0 (none), PV0 + 1..4 (COLOR k), PV0 + 11..30 (FILM n) */
 .short PV0, PV0 + 1, PV0 + 2, PV0 + 3, PV0 + 4
 .short PV0 + 11, PV0 + 12, PV0 + 13, PV0 + 14, PV0 + 15, PV0 + 16, PV0 + 17, PV0 + 18, PV0 + 19, PV0 + 20
 .short PV0 + 21, PV0 + 22, PV0 + 23, PV0 + 24, PV0 + 25, PV0 + 26, PV0 + 27, PV0 + 28, PV0 + 29, PV0 + 30
dm_pend:
dm_llist:
 .short LV0, LV0 + 1, LV0 + 2, LV0 + 3
dm_llend:
 .balign 4
dm_boot:                          /* `call dm_boot,[d2,d3,a2,a3],20` from pf_load once the films are there (power-on,
                                   * HLS_EVENT task): the camera set the dial's family before the films loaded, so a
                                   * mapped position stayed stock until a turn (owner, dg3). Set the family again through
                                   * the facade, as the dial handler does (0x61085d05), so sx_set maps it now. */
 mov 897,d0
 call ar_getv,[d2,a2],24
 mov d0,d1
 cmp 900,d1
 beq 1f
 cmp 899,d1
 beq 1f
 cmp 988,d1
 beq 1f
 cmp 901,d1
 bne 9f
1:
 mov 897,d0
 call ar_setv,[d2,a2],20
9:
 ret [d2,d3,a2,a3],20
dm_get:                           /* from sl_get (d0 one of the four, a1 -> the value; `rets`): the stored value, any
                                   * value that is not one of ours (the other bodies' defaults) read as Normal */
 add -12,sp                       /* (0) call slot, (4) a1, (8) mdr */
 mov a1,(4,sp)
 mov mdr,d1
 mov d1,(8,sp)
 call sget,[],4
 mov (8,sp),d1
 mov d1,mdr
 mov (4,sp),a1
 add 12,sp
 mov d0,d1
 add -DV1,d1
 cmp 5,d1
 bcs 1f
 clr d1
1:
 add DV1,d1
 mov d1,(a1)
 clr d0
 rets
 .balign 4
dm_list:                          /* the options (validator list), in the picker's order */
 .short DV1, DV1 + 1, DV1 + 2, DV1 + 3, DV1 + 4
dm_lend:
 .balign 4
dm_lab:                           /* {value, string << 16 | 4, 0x61570e04}: Normal (616), COLOR k, film n's name */
 .space 12 * 25
dm_hlp:                           /* the same with the help text */
 .space 12 * 25
dm_tit:                           /* the same with the picker titles: film n's name (ST_F0 + n - 1) */
 .space 12 * 25
dm_strs:                          /* ST_DC0 .. ST_DF0 + 19 */
 .long dm_s1, dm_s2, dm_s3, dm_s4, dm_sh, dm_sh, dm_sh, dm_sh
 .long dm_f1, dm_f2, dm_f3, dm_f4, dm_f5, dm_f6, dm_f7, dm_f8, dm_f9, dm_f10, dm_f11, dm_f12, dm_f13, dm_f14, dm_f15, dm_f16, dm_f17, dm_f18, dm_f19, dm_f20
dm_f1:
 .short 70, 73, 76, 77, 32, 49, 0
dm_f2:
 .short 70, 73, 76, 77, 32, 50, 0
dm_f3:
 .short 70, 73, 76, 77, 32, 51, 0
dm_f4:
 .short 70, 73, 76, 77, 32, 52, 0
dm_f5:
 .short 70, 73, 76, 77, 32, 53, 0
dm_f6:
 .short 70, 73, 76, 77, 32, 54, 0
dm_f7:
 .short 70, 73, 76, 77, 32, 55, 0
dm_f8:
 .short 70, 73, 76, 77, 32, 56, 0
dm_f9:
 .short 70, 73, 76, 77, 32, 57, 0
dm_f10:
 .short 70, 73, 76, 77, 32, 49, 48, 0
dm_f11:
 .short 70, 73, 76, 77, 32, 49, 49, 0
dm_f12:
 .short 70, 73, 76, 77, 32, 49, 50, 0
dm_f13:
 .short 70, 73, 76, 77, 32, 49, 51, 0
dm_f14:
 .short 70, 73, 76, 77, 32, 49, 52, 0
dm_f15:
 .short 70, 73, 76, 77, 32, 49, 53, 0
dm_f16:
 .short 70, 73, 76, 77, 32, 49, 54, 0
dm_f17:
 .short 70, 73, 76, 77, 32, 49, 55, 0
dm_f18:
 .short 70, 73, 76, 77, 32, 49, 56, 0
dm_f19:
 .short 70, 73, 76, 77, 32, 49, 57, 0
dm_f20:
 .short 70, 73, 76, 77, 32, 50, 48, 0
dm_s1:
 .short 67, 82, 84, 0
dm_s2:
 .short 65, 82, 84, 0
dm_s3:
 .short 67, 79, 76, 79, 82, 0
dm_s4:
 .short 77, 79, 78, 79, 0
dm_sh:
 .short 84, 104, 101, 32, 112, 105, 99, 116, 117, 114, 101, 32, 109, 111, 100, 101, 32, 116, 104, 105, 115, 13, 10, 67, 114, 101, 97, 116, 105, 118, 101, 32, 68, 105, 97, 108, 32, 112, 111, 115, 105, 116, 105, 111, 110, 32, 117, 115, 101, 115, 46, 13, 10, 79, 110, 32, 67, 79, 76, 79, 82, 32, 105, 116, 32, 107, 101, 101, 112, 115, 32, 105, 116, 115, 32, 111, 119, 110, 32, 99, 104, 111, 105, 99, 101, 46, 0

/* ---------------------------------------------------------------- v0.27 arrow keys (feature/v0.27-buttons)
 * Owner (ak5): the camera's own Direct Function (▲ Exp comp, ◀ AF area, ▶ ▼ assignable) is replaced by ours: with
 * ✥ = Direct Function all four keys run their assigned functions, shown with our ▲◀▶▼ picture (Off / [·:·] grey the
 * four rows as stock).
 * All four arrow keys in the stills Button Function menu with one list (ar_list): the Fn buttons' functions without
 * the six that cannot work from an arrow (Magnify, Multi Function, HDR, High Res, Live ND, Live GND: PR #26 camera test
 * 2; they use the arrows themselves), plus the arrows' own Flash, Drive, Power Zoom and Touch Lock. build.py: the
 * validator records of ▶ (53) and ▼ (51) point at ar_list; ▲ (50) and ◀ (52) take the validator / row / picker entries
 * of sids 1957 and 572 (buttons of other OM bodies, not on the OM-3; ▲ as PR #26, camera-tested); the stills row list
 * and item-info records gain ▲ ◀; the ▲ / ◀ rules lose their Direct Function branch; 7 shooting states get the ▲ / ◀
 * release events (as PR #26 for ▲). Based on PR #26 by ryanbughuang (research/upkey, research/BUTTONS.md). */
.section .ext12,"ax"
ar_get:                           /* .hook_ag (the dispatcher's value read, frame `call ..,[d2],8`, d0 = the key's sid):
                                   * ▲ (50) / ◀ (52) by the arrow-pad mode (sid 158): Direct Function -> the assigned
                                   * function; [·:·] -> AF area (85); Off -> nothing (▲) / AF area (◀, as stock) */
 mov d0,d2
 cmp 50,d2
 beq 1f
 cmp 52,d2
 beq 1f
 mov 3413,d1                      /* the stock bytes */
 mov d1,d0
 jmp ar_vback
1:
 mov 158,d0
 call ar_getv,[d2,a2],24          /* d0 = the arrow-pad mode */
 cmp 2,d0
 beq 8f
 cmp 52,d2
 beq 7f
 cmp 1,d0
 bne 6f
7:
 mov 85,d0
 ret [d2],8
6:
 mov 3200,d0
 ret [d2],8
8:
 jmp ar_vget                      /* mov d2,d0; call the getter; ret [d2],8: the assigned value */
 .set DG0, 0x7fd0                 /* v0.27 polish 2 body diagrams (dg_get) */
 .set NDG, 9
 .set DGW, 422
 .set DGH, 446
 .set DGCAP, 65536
 .set DGBG, 33
ar_ic:                            /* .hook_ic: our ▲ / ◀ / ▲◀▶▼ pictures (AR_IC0 + 0..2), else ic_get */
 mov d0,d1
 exthu d1
 cmp DG0,d1                       /* v0.27 polish 2: the body diagrams (dg_get) */
 bcs 0f
 cmp DG0 + NDG,d1
 bcc 0f
 jmp dg_get
0:
 cmp AR_IC0,d1
 bcs 1f
 cmp AR_IC0 + 32,d1
 bcc 1f
 add -AR_IC0,d1
 asl2 d1
 mov ar_ent,a0
 add d1,a0
 retf [],0
1:
 jmp ic_get
 .set AR_IC0, 0x7fe0              /* clear of Caduceus' 0x7f80..0x7fc3 (PR #26's ▲ id) */
 .balign 4
ar_ent:
 .long ar_d0, ar_d1, ar_d2, ar_d3, ar_d4, ar_d5, ar_d6, ar_d7, ar_d8, ar_d9, ar_d10, ar_d11, ar_d12, ar_d13, ar_d14
 .long ar_d15, ar_d16, ar_d17, ar_d18, ar_d19, ar_d20, ar_d21, ar_d22, ar_d23, ar_d24, ar_d25, ar_d26, ar_d27, ar_d28
 .long ar_d29, ar_d30, ar_d31
ar_d0:                            /* <6H3I> descriptors, filled by build.py (firmware/mkicons.py arrow_streams) */
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
ar_d1:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
ar_d2:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
/* v0.27 dial rows (mkicons.dial_streams): 3..6 the icons CRT, ART, COLOR, MONO; 7..31 the value pictures Normal,
 * COLOR 1-4, FILM 1-20 (ids AR_IC0 + n) */
 .irp n, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
ar_d\n:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
 .endr
ar_l158:                          /* the arrow-pad mode's option labels (build.py: Direct Function's picture -> ours) */
 .space 12 * 3
ar_vp:                            /* the same for the ✥ choice screen's picture list (picker variant 0x61571c48) */
 .space 12 * 3
ar_list:                          /* the arrows' functions (codes; their names: research/NOTES.md "v0.27 arrow keys") */
 .short 3348, 3349, 3350, 3351, 3456, 44, 22, 9, 84, 6, 3341, 3437, 3428, 157, 3462, 1356, 266, 2136, 682, 1468
 .short 475, 90, 140, 216, 404, 856, 69, 88, 1327, 3450, 1712, 1175, 85, 3297, 567, 1898, 106, 2133, 36, 3408
 .short 452, 1108, 3279, 16, 3265, 3409, 425, 3200
ar_lend:
 .balign 4
ar_lab:                           /* value labels {code, string << 16 | type, ptr} for ar_list (build.py, from the Fn
                                   * buttons' and the arrows' label lists) */
 .space 12 * 48
ar_rows:                          /* the stills Button Function rows (build.py) */
 .space 2 * 16
 .balign 4
ar_items:                         /* their item-info records, 28 B each (build.py) */
 .space 28 * 16
ar_blk:                           /* the 7 shooting states' event blocks with ▲ / ◀ releases (build.py) */
 .space 3200
ar_pay:                           /* the ▲ / ◀ / ▲◀▶▼ / dial-row picture streams */
 .space 81920
ar_pend:

/* ---------------------------------------------------------------- v0.27: the film's name in the JPEG's EXIF
 * Owner (2026-11-09 / 11): the film in the photo's data, for sharing and sorting; JPEG is enough. The per-shot EXIF fill
 * (research/NOTES.md "EXIF research, step 2") copies Artist / Copyright into the image's EXIF block ((8,sp)) and then
 * reaches 0x60457578 (.hook_ex) in both cases. There, when the picture mode is COLOR k and k holds a film:
 *   ImageDescription (block + 0x5a8, 32 B, ASCII + NUL): "FILM n Name"   (n = the film's slot 1..20)
 *   UserComment (block + 3972: the 117 characters after its "ASCII" prefix, spaces as stock): "Caduceus OM-3: FILM n Name"
 * Otherwise both get the stock blank back (ImageDescription as first seen, UserComment spaces). */
ex_hook:                          /* jmp from 0x60457578 in the EXIF fill's frame: (8,sp) = the block */
 movm [d2,d3,a2,a3],(sp)
 add -20,sp                       /* (0) call slot, (4) mdr, (8) d1, (12) a1, (16) the block */
 mov mdr,d0
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a1,(12,sp)
 mov (44,sp),a0                   /* (8,sp) as it was: 20 + 16 + 8 */
 mov a0,(16,sp)
 call ex_fill,[d2,d3,a2,a3],20
 mov (4,sp),d0
 mov d0,mdr
 mov (8,sp),d1
 mov (12,sp),a1
 add 20,sp
 movm (sp),[d2,d3,a2,a3]
 mov (8,sp),a0                    /* the 8 bytes it replaced */
 movhu (37666,a0),d0
 jmp ex_back

/* ex_fill: `call ex_fill,[d2,d3,a2,a3],20`, a0 = the EXIF block */
ex_fill:
 mov a0,(ex_blk)
 movbu (ex_sok),d0                /* the stock ImageDescription, once */
 cmp 0,d0
 bne 1f
 mov a0,a1
 add 0x5a8,a1
 mov ex_snap,a2
 mov 32,d1
2:
 movbu (a1),d0
 movbu d0,(a2)
 add 1,a1
 add 1,a2
 add -1,d1
 bne 2b
 mov 1,d0
 movbu d0,(ex_sok)
1:
 mov 38017,d0                     /* the picture mode, as the capture side reads it (wb_get): 6 -> 40209; */
 clr d1                           /* 11 = COLOR, its number 63153 (1..4) */
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 cmp 6,d0
 bne 12f
 mov 40209,d0
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
12:
 cmp 11,d0
 bne 80f
 mov 63153,d0
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 add -1,d0
 cmp 4,d0
 bcc 80f
 mov d0,d2                        /* COLOR k */
 PVAL 80f                         /* (getter may use d3 / a2: P again) */
 call fl_film,[],0                /* -> film j */
 cmp 0,d0
 blt 80f
 mov d0,d3
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 80f
 mov ex_txt,a1                    /* "FILM n Name" */
 mov ex_film,a0
3:
 movbu (a0),d0
 cmp 0,d0
 beq 4f
 movbu d0,(a1)
 add 1,a0
 add 1,a1
 bra 3b
4:
 mov d3,d0                        /* n = j + 1 */
 add 1,d0
 cmp 10,d0
 bcs 5f
 mov 49,d1                        /* "1" */
 cmp 20,d0
 bcs 6f
 mov 50,d1                        /* "2" */
6:
 movbu d1,(a1)
 add 1,a1
 add -10,d0
 cmp 10,d0
 bcs 5f
 add -10,d0
5:
 add 48,d0
 movbu d0,(a1)
 add 1,a1
 mov (LPTR,a2),a0                 /* the name: 16 bytes at 1312 + 16 j, NUL-ended when shorter */
 mov d3,d0
 asl 4,d0
 add d0,a0
 add 1312,a0
 movbu (a0),d0
 cmp 0,d0
 beq 8f
 mov 32,d0
 movbu d0,(a1)
 add 1,a1
 mov 16,d1
7:
 movbu (a0),d0
 cmp 0,d0
 beq 8f
 cmp 32,d0                        /* printable ASCII only */
 bcs 71f
 cmp 127,d0
 bcc 71f
 movbu d0,(a1)
 add 1,a1
71:
 add 1,a0
 add -1,d1
 bne 7b
8:
 clr d0
 movbu d0,(a1)
 call ex_cd1,[d2,d3,a2,a3],20    /* the film's settings as a code, om3.1. (d3 = j, a2 = P still) */
 mov (ex_blk),a2                  /* ImageDescription: the text, zeros after it */
 add 0x5a8,a2
 mov ex_txt,a0
 mov 32,d1
 clr d2
9:
 movbu (a0),d0
 cmp 0,d2
 bne 91f
 cmp 0,d0
 bne 92f
 mov 1,d2
91:
 clr d0
92:
 movbu d0,(a2)
 add 1,a0
 add 1,a2
 add -1,d1
 bne 9b
 mov (ex_blk),a2                  /* UserComment: "Caduceus " + the text + " " + the code, spaces after it */
 add 3972,a2
 mov 117,d3
 mov ex_uc,a0
 call ex_put,[],0
 mov ex_txt,a0
 call ex_put,[],0
 mov ex_sp,a0
 call ex_put,[],0
 mov ex_code,a0
 call ex_put,[],0
 mov 32,d0
10:
 cmp 0,d3
 beq 11f
 movbu d0,(a2)
 add 1,a2
 add -1,d3
 bra 10b
11:
 ret [d2,d3,a2,a3],20
80:                               /* no film: the stock blanks */
 mov (ex_blk),a2
 add 0x5a8,a2
 mov ex_snap,a0
 mov 32,d1
81:
 movbu (a0),d0
 movbu d0,(a2)
 add 1,a0
 add 1,a2
 add -1,d1
 bne 81b
 mov (ex_blk),a2
 add 3972,a2
 mov 117,d1
 mov 32,d0
82:
 movbu d0,(a2)
 add 1,a2
 add -1,d1
 bne 82b
 ret [d2,d3,a2,a3],20

/* ex_cd1: `call ex_cd1,[d2,d3,a2,a3],20`, a2 = P, d3 = film j -> ex_code = "om3.1." + 43 characters: the film's
 * whole 64-byte LOOKS.BIN record (bytes 57..63 are spare: future settings go there, 0 = off, so older readers skip
 * them), one nibble each (value & 15), two to a byte (32 bytes), base64url (A-Z a-z 0-9 - _), no padding. The camera
 * is in the name so another body (E-P7) can have its own. The Control Panel turns it back into the film
 * (firmware/photocode.py is the reference). */
ex_cd1:
 mov (LPTR,a2),a0                 /* the record: 32 + 64 j */
 mov d3,d0
 asl 6,d0
 add d0,a0
 add 32,a0
 mov ex_nb,a1
 clr d2
1:
 movbu (a0),d0
 and 15,d0
 asl 4,d0
 movbu (1,a0),d1
 and 15,d1
 or d1,d0
 movbu d0,(a1)
 add 2,a0
 add 1,a1
 add 1,d2
 cmp 32,d2
 bcs 1b
 clr d0
 movbu d0,(a1)                    /* byte 32 = 0: eleven groups of 3, the 44th character dropped */
 mov ex_code,a1
 mov ex_cdp,a0
 mov 6,d3
3:
 movbu (a0),d0
 movbu d0,(a1)
 add 1,a0
 add 1,a1
 add -1,d3
 bne 3b
 mov ex_nb,a0
 mov ex_b64,a3
 mov 11,d3
4:
 movbu (a0),d0
 lsr 2,d0
 movbu (d0,a3),d1
 movbu d1,(a1)
 movbu (a0),d0
 and 3,d0
 asl 4,d0
 movbu (1,a0),d1
 lsr 4,d1
 or d1,d0
 movbu (d0,a3),d1
 movbu d1,(1,a1)
 movbu (1,a0),d0
 and 15,d0
 asl 2,d0
 movbu (2,a0),d1
 lsr 6,d1
 or d1,d0
 movbu (d0,a3),d1
 movbu d1,(2,a1)
 movbu (2,a0),d0
 and 63,d0
 movbu (d0,a3),d1
 movbu d1,(3,a1)
 add 3,a0
 add 4,a1
 add -1,d3
 bne 4b
 add -1,a1
 clr d0
 movbu d0,(a1)
 ret [d2,d3,a2,a3],20

/* ex_put: `call ex_put,[],0`, a0 = an ASCII text (NUL-ended) -> at a2 while d3 > 0 (both moved on). Uses d0. */
ex_put:
 movbu (a0),d0
 cmp 0,d0
 beq 9f
 cmp 0,d3
 beq 9f
 movbu d0,(a2)
 add 1,a0
 add 1,a2
 add -1,d3
 bra ex_put
9:
 ret [],0

ex_film:
 .asciz "FILM "
ex_uc:
 .asciz "Caduceus "
ex_sp:
 .asciz " "
ex_cdp:
 .ascii "om3.1."
ex_b64:
 .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
 .balign 4
ex_blk:
 .long 0
ex_sok:
 .byte 0
ex_snap:
 .space 32
ex_txt:
 .space 48
ex_nb:
 .space 36
ex_code:
 .space 48
 .balign 4

/* ---------------------------------------------------------------- v0.27 polish 2: body diagrams (firmware/diagrams.py)
 * The Button Function list shows a 422 x 446 body picture per row with the control highlighted and a line to the
 * row's place on its page. For ▲ ◀ ▶ ▼ L-Fn and the four dial rows the camera has none that fits, so dg_get composes
 * them from the camera's own pictures (ids 0x3f7b..0x3f83, unpacked at start-up) by the programs of
 * firmware/diagrams.py, row by row: the base picture's runs pass through as they are outside the span the ops touch;
 * inside it the base and up to two other pictures are decoded to pixels, rectangles copied, lines filled, our corners /
 * the dial highlight stamped, and the span encoded again (camera dg1: composing every pixel made the menu hang). Two 64 KB buffers keep the last two pictures.
 * Without a stock picture (or on overflow) the row shows a stock picture instead (dg_fb). */
dg_get:                           /* from ar_ic (jmp; the picture getter's frame: retf [],0, a0 -> slot), d1 = id */
 movm [d2,d3,a2,a3],(sp)
 add -12,sp                       /* (0) call slot, (4) mdr */
 mov mdr,d0
 mov d0,(4,sp)
 mov d1,d2
 add -DG0,d2                      /* k */
 mov d2,d3
 add 1,d3                         /* k + 1 */
 mov (dg_have),d0
 cmp d3,d0
 bne 1f
 mov dg_s0,a0
 bra 8f
1:
 mov (dg_have + 4),d0
 cmp d3,d0
 bne 2f
 mov dg_s1,a0
 bra 8f
2:
 mov (dg_next),d0
 mov d0,a3                        /* i: the buffer to use */
 xor 1,d0
 mov d0,(dg_next)
 mov a3,d1
 asl2 d1
 mov dg_have,a0
 add d1,a0
 clr d0
 mov d0,(a0)
 call dg_build,[d2,d3,a2,a3],20    /* d0 = 1 when made */
 cmp 0,d0
 beq 9f
 mov a3,d1
 asl2 d1
 mov dg_have,a0
 add d1,a0
 mov d3,(a0)
 mov dg_s0,a0
 add d1,a0
8:
 mov (4,sp),d0
 mov d0,mdr
 add 12,sp
 movm (sp),[d2,d3,a2,a3]
 retf [],0
9:
 mov d2,d0                        /* a stock picture instead */
 add d0,d0
 mov dg_fb,a0
 add d0,a0
 movhu (a0),d0
 mov (4,sp),d1
 mov d1,mdr
 add 12,sp
 movm (sp),[d2,d3,a2,a3]
 jmp ic_get

/* dg_build: `call dg_build,[d2,d3,a2,a3],20`, d2 = k, a3 = buffer index -> d0 1 made / 0 not. Uses everything.
 * dg3 (camera dg1 / dg2: the menu hung): the output is the base picture's stream itself, copied word by word, with
 * only the tokens of each row's span (the pixels the ops touch, widened to whole tokens) encoded again; the new span
 * gets as many tokens as the old one modulo 5 (runs split if needed), so everything after it stays word-aligned and
 * is copied as words again. Row starts come from dg_rix (made once per stock picture by dg_prep). */
dg_build:
 mov (dg_cnt),d0                  /* builds so far (diagnostics) */
 add 1,d0
 mov d0,(dg_cnt)
 mov d2,d0
 asl2 d0
 mov dg_pt,a0
 add d0,a0
 mov (a0),a2                      /* the program */
 mov a2,(dg_pg)
 movhu (a2),d3                    /* its sources ready (stock index = id - 0x3f7b) */
1:
 cmp 0,d3
 beq 2f
 add -1,d3
 mov d3,d0
 add d0,d0
 add 2,d0
 mov a2,a0
 add d0,a0
 movhu (a0),d0
 add -0x3f7b,d0
 call dg_prep,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 90f
 bra 1b
2:
 movhu (2,a2),d0                  /* the base */
 add -0x3f7b,d0
 mov d0,(dg_bi)
 asl2 d0
 mov dg_pay,a0
 add d0,a0
 mov (a0),d0
 mov d0,(dg_bp)
 mov d0,(dg_cw)                   /* the copy cursor: its first token */
 clr d0
 mov d0,(dg_csl)
 mov dg_b0,a0                     /* the output, written through the uncached alias */
 mov a3,d0
 cmp 0,d0
 beq 3f
 add DGCAP,a0
3:
 mov a0,d0
 add 0x40000000,d0
 mov d0,(dg_bs)
 mov d0,a0
 mov 0x0b1a51bd,d0                /* header: 446 rows, 422 wide, type 11 */
 mov d0,(a0)
 mov a0,d0
 add 4,d0
 mov d0,(dg_out)
 add DGCAP - 16,d0
 mov d0,(dg_end)
 clr d0
 mov d0,(dg_lo)
 mov d0,(dg_hi)
 mov d0,(dg_n)
 mov d0,(dg_ovf)
 mov d0,(dg_y)
4:                                /* each row: the span the ops touch, dg_xa .. dg_xb */
 mov DGW,d0
 mov d0,(dg_xa)
 clr d0
 mov d0,(dg_xb)
 mov (dg_pg),a2
 movhu (8,a2),d2
 mov a2,a3
 add 32,a3
40:
 cmp 0,d2
 beq 45f
 mov (dg_y),d1
 movhu (8,a3),d0
 cmp d0,d1
 bcs 44f
 movhu (10,a3),d0
 cmp d0,d1
 bcc 44f
 movhu (4,a3),d0
 movhu (6,a3),d1
 movhu (a3),d3
 cmp 4,d3                         /* a bridge also reads x0 - 1 and x1 */
 bne 41f
 add -1,d0
 add 1,d1
41:
 mov (dg_xa),d3
 cmp d3,d0
 bcc 42f
 mov d0,(dg_xa)
42:
 mov (dg_xb),d3
 cmp d3,d1
 bls 44f
 mov d1,(dg_xb)
44:
 add 16,a3
 add -1,d2
 bra 40b
45:
 mov (dg_xa),d0
 mov (dg_xb),d1
 cmp d0,d1
 bls 80f                          /* nothing on this row */
 cmp DGW,d1
 bls 46f
 mov DGW,d1
 mov d1,(dg_xb)
46:                               /* the base row's tokens: the first one ending past xa */
 mov (dg_bi),d0
 mov (dg_y),d1
 call dg_rowc,[],0                /* a1, d1 = the row's first token */
 clr d3                           /* x */
 mov (dg_xa),d0
 call dg_seek,[d2,d3,a2,a3],20
 mov (dg_sx),d3
 mov d3,(dg_xs)                   /* xa' */
 mov a1,a0                        /* copy the base up to that token */
 mov d1,d0
 call dg_copy,[d2,d3,a2,a3],20
 mov (dg_cw),a1                   /* decode tokens from there into row 0 until x >= xb: their count */
 mov (dg_csl),d1
 mov (dg_xs),d3
 clr d0
 mov d0,(dg_tc)
 mov dg_r0,a3
49:
 mov (dg_xb),d0
 cmp d0,d3
 bcc 50f
 call dg_tk,[d2],8
 mov (dg_tc),d2
 add 1,d2
 mov d2,(dg_tc)
 mov d0,d2
 lsr 4,d2
 and 15,d0
 add 1,d0
491:
 movbu d2,(d3,a3)
 add 1,d3
 add -1,d0
 bne 491b
 bra 49b
50:
 mov d3,(dg_xe)                   /* xb' */
 mov a1,(dg_cw)                   /* the base continues after the span */
 mov d1,(dg_csl)
 mov (dg_pg),a2                   /* the ops */
 movhu (8,a2),d2
 mov a2,a3
 add 32,a3
6:
 cmp 0,d2
 beq 7f
 mov (dg_y),d1
 movhu (8,a3),d0
 cmp d0,d1
 bcs 69f
 movhu (10,a3),d0
 cmp d0,d1
 bcc 69f
 call dg_op,[d2,d3,a2,a3],20
69:
 add 16,a3
 add -1,d2
 bra 6b
7:                                /* encode xa' .. xb' into dg_tq */
 mov dg_r0,a2
 mov dg_tq,a1
 mov (dg_xs),d3
 mov (dg_xe),a0
8:
 mov a0,d0
 cmp d0,d3
 bcc 89f
 movbu (d3,a2),d2
 mov d3,d1                        /* the run's limit: min(x + 16, xb') */
 add 16,d1
 cmp a0,d1
 bls 83f
 mov a0,d1
83:
 mov d1,a3
 mov d3,d1
 add 1,d1
81:
 cmp a3,d1
 bcc 82f
 movbu (d1,a2),d0
 cmp d2,d0
 bne 82f
 add 1,d1
 bra 81b
82:
 mov d2,d0                        /* value << 4 | run - 1 */
 asl 4,d0
 sub d3,d1
 add -1,d1
 or d1,d0
 movhu d0,(a1)
 add 2,a1
 add 1,d1
 add d1,d3
 bra 8b
89:
 mov a1,(dg_tqe)
 call dg_pad,[d2,d3,a2,a3],20     /* as many tokens as the old span, modulo 5 */
 cmp 0,d0
 beq 90f
 mov dg_tq,a2                     /* out */
891:
 mov (dg_tqe),d0
 mov a2,d1
 cmp d0,d1
 bcc 80f
 movhu (a2),d0
 add 2,a2
 call dg_put,[],0
 bra 891b
80:
 mov (dg_y),d0
 add 1,d0
 mov d0,(dg_y)
 cmp DGH,d0
 bcs 4b
 mov (dg_bi),d0                   /* the rest of the base */
 mov DGH,d1
 call dg_rowc,[],0
 mov a1,a0
 mov d1,d0
 call dg_copy,[d2,d3,a2,a3],20
 mov (dg_n),d0                    /* the last, partial word */
 cmp 0,d0
 beq 85f
 mov (dg_out),a0
 mov (dg_lo),d0
 mov d0,(a0)
 mov (dg_hi),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(dg_out)
85:
 mov (dg_ovf),d0
 cmp 0,d0
 bne 90f
 mov dg_d0,a0                     /* the descriptor */
 mov (dg_bs),d1
 mov dg_b0 + 0x40000000,d0
 cmp d0,d1
 beq 86f
 add 24,a0
86:
 mov (dg_out),d0
 sub d1,d0
 mov d0,(12,a0)
 mov d1,(16,a0)
 mov 1,d0
 ret [d2,d3,a2,a3],20
90:
 clr d0
 ret [d2,d3,a2,a3],20

/* dg_rowc: `call dg_rowc,[],0`, d0 = stock index, d1 = row 0..446 -> a1 = the word, d1 = the slot of the row's first
 * token (dg_rix entries: byte offset of the word | slot). Uses d0. */
dg_rowc:
 asl2 d0
 mov dg_rxp,a1
 add d0,a1
 mov (a1),a1
 add d1,d1
 add d1,a1
 movhu (a1),d1
 mov dg_pay,a1
 add d0,a1
 mov (a1),a1
 mov d1,d0
 and 0xfff8,d0
 add d0,a1
 and 7,d1
 ret [],0

/* dg_put: `call dg_put,[],0`, d0 = a token: 5 to a 64-bit word (dg_n tokens so far), written at dg_out while below
 * dg_end. Uses d1, a0. */
dg_put:
 mov (dg_n),d1
 cmp 0,d1
 bne 1f
 mov d0,(dg_lo)
 bra 8f
1:
 cmp 1,d1
 bne 2f
 asl 12,d0
 mov (dg_lo),d1
 or d0,d1
 mov d1,(dg_lo)
 bra 8f
2:
 cmp 2,d1
 bne 3f
 mov d0,d1
 lsr 8,d1
 mov d1,(dg_hi)
 asl 24,d0
 mov (dg_lo),d1
 or d0,d1
 mov d1,(dg_lo)
 bra 8f
3:
 cmp 3,d1
 bne 4f
 asl 4,d0
 mov (dg_hi),d1
 or d0,d1
 mov d1,(dg_hi)
 bra 8f
4:
 asl 16,d0
 mov (dg_hi),d1
 or d0,d1
 mov d1,(dg_hi)
 mov (dg_out),a0
 mov a0,d1
 mov (dg_end),d0
 cmp d0,d1
 bcc 5f
 mov (dg_lo),d0
 mov d0,(a0)
 mov (dg_hi),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(dg_out)
 bra 6f
5:
 mov 1,d0
 mov d0,(dg_ovf)
6:
 clr d0
 mov d0,(dg_lo)
 mov d0,(dg_hi)
 mov -1,d1
 mov d1,(dg_n)
8:
 mov (dg_n),d1
 add 1,d1
 mov d1,(dg_n)
 ret [],0

/* WSUM: d2 = the pixels of the 5 tokens of the word at a1 (their run nibbles: bits 0, 12, 24 of the low word, 4, 16
 * of the high, each + 1). Uses d0; d1 = 0 after (the word's first slot). */
 .macro WSUM
 mov (a1),d2
 and 0x0f00f00f,d2
 mov d2,d0
 lsr 12,d0
 add d0,d2
 lsr 12,d0
 add d0,d2
 and 0xfff,d2
 mov (4,a1),d0
 and 0x000f00f0,d0
 mov d0,d1
 lsr 12,d1
 add d1,d0
 lsr 4,d0
 and 0x3f,d0
 add d0,d2
 clr d1
 add 5,d2
 .endm

/* dg_seek: `call dg_seek,[d2,d3,a2,a3],20`, a1 / d1 = a token at x = d3, d0 = a target x (inside the row) ->
 * a1 / d1 = the first token from there that ends past the target, dg_sx = its x. Whole words (5 tokens) are skipped by
 * adding their 5 run lengths. */
dg_seek:
 mov d0,(dg_stg)
1:
 cmp 0,d1
 beq 2f
 mov a1,a2
 mov d1,a3
 call dg_tk,[d2],8
 and 15,d0
 add 1,d0
 add d3,d0
 mov (dg_stg),d2
 cmp d2,d0
 bhi 8f
 mov d0,d3
 bra 1b
2:
 WSUM
 add d3,d2                        /* x after the word */
 mov (dg_stg),d0
 cmp d0,d2
 bhi 3f
 mov d2,d3
 add 8,a1
 bra 2b
3:
 mov a1,a2
 mov d1,a3
 call dg_tk,[d2],8
 and 15,d0
 add 1,d0
 add d3,d0
 mov (dg_stg),d2
 cmp d2,d0
 bhi 8f
 mov d0,d3
 bra 3b
8:
 mov a2,a1
 mov a3,d1
 mov d3,(dg_sx)
 ret [d2,d3,a2,a3],20

/* dg_tk: `call dg_tk,[d2],8`, a1 = a token's word, d1 = its slot 0..4 -> d0 = the token; a1 / d1 moved to the next */
dg_tk:
 cmp 0,d1
 bne 1f
 mov (a1),d0
 and 0xfff,d0
 bra 8f
1:
 cmp 1,d1
 bne 2f
 mov (a1),d0
 lsr 12,d0
 and 0xfff,d0
 bra 8f
2:
 cmp 2,d1
 bne 3f
 mov (a1),d0
 lsr 24,d0
 mov (4,a1),d2
 and 15,d2
 asl 8,d2
 or d2,d0
 bra 8f
3:
 cmp 3,d1
 bne 4f
 mov (4,a1),d0
 lsr 4,d0
 and 0xfff,d0
 bra 8f
4:
 mov (4,a1),d0
 lsr 16,d0
 and 0xfff,d0
 add 8,a1
 clr d1
 ret [d2],8
8:
 add 1,d1
 ret [d2],8

/* dg_copy: `call dg_copy,[d2,d3,a2,a3],20`: the base's tokens from the copy cursor (dg_cw, dg_csl) up to a0 / d0
 * (word, slot) into the output: single tokens to a word boundary, then whole words as they are, then single tokens.
 * The output's slot equals the cursor's (dg_build keeps them in step). */
dg_copy:
 mov a0,a2
 mov d0,d3
 mov (dg_cw),a1
 mov (dg_csl),d1
1:
 cmp 0,d1
 beq 2f
 cmp a2,a1
 bne 11f
 cmp d3,d1
 beq 9f
11:
 call dg_tk,[d2],8
 mov d1,d2
 call dg_put,[],0
 mov d2,d1
 bra 1b
2:
 cmp a2,a1
 bcc 3f
 mov (dg_out),a0
 mov a0,d0
 mov (dg_end),d2
 cmp d2,d0
 bcc 21f
 mov (a1),d0
 mov d0,(a0)
 mov (4,a1),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(dg_out)
 add 8,a1
 bra 2b
21:
 mov 1,d0
 mov d0,(dg_ovf)
 add 8,a1
 bra 2b
3:
 cmp d3,d1
 bcc 9f
 call dg_tk,[d2],8
 mov d1,d2
 call dg_put,[],0
 mov d2,d1
 bra 3b
9:
 mov a1,(dg_cw)
 mov d1,(dg_csl)
 ret [d2,d3,a2,a3],20

/* dg_pad: `call dg_pad,[d2,d3,a2,a3],20`: dg_tq .. dg_tqe (the new span's tokens) grown by splitting runs until its
 * count is the old span's (dg_tc) modulo 5 -> d0 1, or 0 when no run can be split */
dg_pad:
1:
 mov (dg_tqe),d0
 mov dg_tq,d1
 sub d1,d0
 lsr 1,d0                         /* new count */
 mov (dg_tc),d1
 sub d0,d1                        /* old - new */
2:
 cmp 0,d1
 bge 3f
 add 5,d1
 bra 2b
3:
 cmp 5,d1
 bcs 4f
 add -5,d1
 bra 3b
4:
 cmp 0,d1
 beq 8f
 mov dg_tq,a2                     /* the longest run */
 clr d3
 mov 0,a3
5:
 mov (dg_tqe),d0
 mov a2,d1
 cmp d0,d1
 bcc 6f
 movhu (a2),d0
 and 15,d0
 cmp d3,d0
 bls 51f
 mov d0,d3
 mov a2,a3
51:
 add 2,a2
 bra 5b
6:
 cmp 0,d3                         /* run - 1 = 0: nothing to split */
 beq 9f
 mov (dg_tqe),a2                  /* make room after it */
 mov a3,a1
 add 2,a1
7:
 mov a2,d0
 mov a1,d1
 cmp d1,d0
 bls 71f
 add -2,a2
 movhu (a2),d0
 movhu d0,(2,a2)
 bra 7b
71:
 mov (dg_tqe),a2
 add 2,a2
 mov a2,(dg_tqe)
 movhu (a3),d0                    /* v, r -> v, r / 2 and v, r - r / 2 */
 mov d0,d2
 and 0xfff0,d2
 and 15,d0
 add 1,d0
 mov d0,d1
 lsr 1,d1
 sub d1,d0
 add -1,d1
 or d2,d1
 movhu d1,(a3)
 add -1,d0
 or d2,d0
 movhu d0,(2,a3)
 bra 1b
8:
 mov 1,d0
 ret [d2,d3,a2,a3],20
9:
 clr d0
 ret [d2,d3,a2,a3],20

/* dg_prep: `call dg_prep,[d2,d3,a2,a3],20`, d0 = stock index 0..8 -> d0 1 ready / 0 not: its payload (cached, past the
 * header) in dg_pay and its row starts in dg_rix, once (a full walk of its tokens) */
dg_prep:
 mov d0,(dg_pi)
 mov dg_rok,a0
 add d0,a0
 movbu (a0),d1
 cmp 0,d1
 bne 80f
 add 0x3f7b,d0
 asl2 d0
 mov (0x60379740),a0              /* the picture table */
 add d0,a0
 mov (a0),a0
 mov a0,d0
 cmp 0,d0
 beq 90f
 movhu (a0),d0
 cmp 14,d0
 bne 90f
 movhu (2,a0),d0
 cmp DGW,d0
 bne 90f
 movhu (4,a0),d0
 cmp DGH,d0
 bne 90f
 mov (16,a0),d0                   /* payload (uncached) -> cached, past the 4-byte header */
 mov d0,d1
 and 0xf0000000,d1
 cmp 0xa0000000,d1
 bne 1f
 add -0x40000000,d0
1:
 add 4,d0
 mov (dg_pi),d1
 asl2 d1
 mov dg_pay,a0
 add d1,a0
 mov d0,(a0)
 mov d0,a1
 mov d0,(dg_t1)
 mov dg_rxp,a0
 add d1,a0
 mov (a0),a3                      /* its 447 entries */
 clr d1
 clr d0
 movhu d0,(a3)
 add 2,a3
 clr d3                           /* x */
 mov 0,a2                         /* rows done */
2:
 cmp 0,d1                         /* a whole word inside the row: add its 5 runs */
 bne 21f
 WSUM
 add d3,d2
 cmp DGW,d2
 bcc 21f
 mov d2,d3
 add 8,a1
 bra 2b
21:
 call dg_tk,[d2],8
 and 15,d0
 add 1,d0
 add d0,d3
 cmp DGW,d3
 bcs 2b
 bhi 90f                          /* a run across a row's end: not ours to handle */
 clr d3
 mov a1,d0                        /* the next row's first token */
 mov (dg_t1),d2
 sub d2,d0
 cmp 0xfff8,d0
 bhi 90f
 or d1,d0
 movhu d0,(a3)
 add 2,a3
 add 1,a2
 mov a2,d0
 cmp DGH,d0
 bcs 2b
 mov dg_rok,a0
 mov (dg_pi),d1
 add d1,a0
 mov 1,d0
 movbu d0,(a0)
80:
 mov 1,d0
 ret [d2,d3,a2,a3],20
90:
 clr d0
 ret [d2,d3,a2,a3],20

/* dg_op: `call dg_op,[d2,d3,a2,a3],20`, a3 = an op {type, a, x0, x1, y0, y1, w, offset} for this row (dg_y) */
dg_op:
 movhu (a3),d0
 movhu (4,a3),d2
 movhu (6,a3),d3
 mov (dg_rp),a2
 cmp 1,d0
 bne 2f
 mov d2,(dg_ox0)                  /* 1: stock picture a's pixels x0 .. x1 of this row, straight into row 0 */
 mov d3,(dg_ox1)
 movhu (2,a3),d0
 mov (dg_y),d1
 call dg_rowc,[],0
 clr d3                           /* x */
 mov (dg_ox0),d0
 call dg_seek,[d2,d3,a2,a3],20    /* the token holding x0 */
 mov (dg_sx),d3
12:
 mov (dg_ox1),d0
 cmp d0,d3
 bcc 9f
 call dg_tk,[d2],8
 mov d0,d2
 lsr 4,d2                         /* value */
 and 15,d0
 add 1,d0
 add d3,d0                        /* its end */
 mov d1,(dg_osl)
 mov (dg_ox1),d1
 cmp d1,d0
 bls 13f
 mov d1,d0                        /* to min(end, x1) */
13:
 mov (dg_ox0),d1
 cmp d1,d3
 bcc 14f
 mov d1,d3                        /* from max(x, x0) */
14:
 cmp d0,d3
 bcc 15f
 movbu d2,(d3,a2)
 add 1,d3
 bra 14b
15:
 mov d0,d3
 mov (dg_osl),d1
 bra 12b
2:
 cmp 2,d0
 bne 3f
 movhu (2,a3),d1                  /* 2: fill with a */
21:
 cmp d3,d2
 bcc 9f
 movbu d1,(d2,a2)
 add 1,d2
 bra 21b
3:
 cmp 3,d0
 bne 4f
 mov (dg_y),d0                    /* 3: stamp: its row y - y0 (w bytes a row, at offset), 0 = clear */
 movhu (8,a3),d1
 sub d1,d0
 movhu (14,a3),d1
 mov dg_sb,a1
 add d1,a1
 movhu (12,a3),d1
32:
 cmp 0,d0
 beq 33f
 add d1,a1
 add -1,d0
 bra 32b
33:
 mov a1,d0
 sub d2,d0
 mov d0,a1
34:
 cmp d3,d2
 bcc 9f
 movbu (d2,a1),d0
 cmp 0,d0
 beq 35f
 movbu d0,(d2,a2)
35:
 add 1,d2
 bra 34b
4:
 mov d2,d0                        /* 4: bridge [x0, x1) when the pixels left of x0 and at x1 are drawn */
 add -1,d0
 movbu (d0,a2),d1
 cmp DGBG,d1
 beq 9f
 movbu (d3,a2),d0
 cmp DGBG,d0
 beq 9f
41:
 cmp d3,d2
 bcc 9f
 movbu d1,(d2,a2)
 add 1,d2
 bra 41b
9:
 ret [d2,d3,a2,a3],20

 .balign 4
dg_have:
 .long 0, 0                       /* k + 1 of the picture in buffer 0 / 1 */
dg_next:
 .long 0
dg_cnt:
 .long 0
dg_s0:
 .long dg_d0
dg_s1:
 .long dg_d1
dg_d0:
 .short 14, DGW, DGH, 8, 0, 0
 .long 0, 0, 0
dg_d1:
 .short 14, DGW, DGH, 8, 0, 0
 .long 0, 0, 0
dg_fb:                            /* a stock picture when ours cannot be made: ▲ ◀ ▶ ▼ -> ✥'s, L-Fn's, dials -> Fn's */
 .short 0x3f80, 0x3f80, 0x3f80, 0x3f80, 0x3f83, 0x3f7b, 0x3f7b, 0x3f7b, 0x3f7b
 .balign 4
dg_rp:
 .long dg_r0
dg_pg:
 .long 0
dg_ns:
 .long 0
dg_y:
 .long 0
dg_bs:
 .long 0
dg_out:
 .long 0
dg_end:
 .long 0
dg_lo:
 .long 0
dg_hi:
 .long 0
dg_n:
 .long 0
dg_ovf:
 .long 0
dg_xa:
 .long 0
dg_xb:
 .long 0
dg_xs:
 .long 0
dg_xe:
 .long 0
dg_bi:
 .long 0
dg_bp:
 .long 0
dg_cw:
 .long 0
dg_csl:
 .long 0
dg_t1:
 .long 0
dg_tc:
 .long 0
dg_tqe:
 .long 0
dg_pi:
 .long 0
dg_ox0:
 .long 0
dg_ox1:
 .long 0
dg_osl:
 .long 0
dg_stg:
 .long 0
dg_sx:
 .long 0
dg_pay:                           /* per stock picture 0..8: its tokens (cached), once dg_prep has seen it */
 .space 4 * 9
dg_rxp:
 .long dg_rix, dg_rix + 894, dg_rix + 2 * 894, dg_rix + 3 * 894, dg_rix + 4 * 894, dg_rix + 5 * 894
 .long dg_rix + 6 * 894, dg_rix + 7 * 894, dg_rix + 8 * 894
dg_rok:
 .space 12
dg_r0:
 .space 424
dg_tq:                            /* a span's new tokens (<= 422 + 4) */
 .space 1024
dg_rix:                           /* per stock picture: 447 row starts {word offset | slot} */
 .space 9 * 894
 .balign 4
dg_pt:                            /* the 9 programs (build.py, firmware/diagrams.py) */
 .space 4 * NDG
dg_pgs:
 .space 2048
dg_sb:                            /* the stamps */
 .space 2048
 .balign 8
dg_b0:                            /* two output buffers */
 .space 2 * DGCAP
dg_bend:

