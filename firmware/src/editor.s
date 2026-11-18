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
 .set HL_FAIL, 1                  /* hl_ok: not the gate's context */
 .set HL_NOMED, 2                 /* hl_ok: the gate's context, no medium mounted */
 .set UI_PSW, 0xa32d9d0d          /* the photo / movie / S&Q switch byte (UI_IN), 2 = photo */
 .set UI_DIAL, 0xa32d9d0c         /* the mode dial's position (UI_IN) */
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
 call cv_sv,[d2,d3,a2,a3],68      /* stock: call 0x60bb528f,[d2,d3,a2,a3],68 (settings manager); cv_sv (rgb-curves page) -> sl_set -> ed_set */
.section .hook_tone,"ax"
 call tn_g,[d2,d3,a2,a3],56       /* stock 0x605197d7: mov d3,a0; call 0x60518fa4,[d2,d3,a2,a3],56. tn_g: tone once section 6 is in */
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
 jmp cv_ev                        /* rgb-curves cv_ev, then pm_ev. v0.25 stock 0x6125becc (Picture Mode's event handler): movm [d2,a2,a3],(sp);
                                   * add -60,sp */
.section .hook_gx,"ax"
 jmp cv_gx                        /* rgb-curves cv_gx, then gx_map. v0.25 grid (as test 13): stock 0x610f6016 (after a screen handler: d0 = next
                                   * state): mov d0,d3; exthu d3; mov d3,d2; asr 8,d2 */
 .byte 0xcb
.section .hook_sc,"ax"
 jmp sc_cap                       /* stock 0x610cdf05 (a holder gets its scene): mov d0,a3; mov a0,d3; mov 1,d0 */
 .byte 0xcb
.section .hook_pu,"ax"
 jmp cv_pu                        /* rgb-curves cv_pu, then pu_hook. stock 0x611d04ec (Picture Mode update): mov (0x6037a360),d0 */
 .byte 0xcb
.section .hook_pe,"ax"
 jmp gr_end                       /* stock 0x611d059c (Picture Mode update's end): mov (12,sp),d0; cmp 0,d0; bne 0x611d05b2 */
 .byte 0xcb
.section .hook_rr,"ax"
 jmp rr_g                         /* stock 0x611356e6 (property 275's handler, the row refresh): movm [d2,a2,a3],(sp);
                                   * add -16,sp; mov a0,a2 */
 .byte 0xcb
.section .hook_ic,"ax"
 jmp cv_ic                        /* rgb-curves cv_ic, then v0.27: ar_ic (▲ / ◀ pictures), then ic_get. v0.23 stock 0x610f5611 (picture id -> its slot in the picture table): mov d0,d1;
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

 .set SEC_READY, 0xa32de58c       /* bit id - 1: section id is ready (crop.s sets the same) */

hl_pp:
 call color_builder,[d2,d3,a2,a3],96
hl_pp_cb:                         /* tools/test/emu_test.py enters here */
 mov 0x202,d1                     /* want 2 << 8 | mask 2 */
 mov 32 + 31,a0
 mov (SEC_READY),d0               /* section 6 (slot_any) ready? Before it STATE is 0: the same exit */
 and 0x20,d0
 beq 8f                           /* short, so the gate stays right before the call; Z still set at 8 */
 call slot_any,[d2,d3,a2],16      /* P valid and some COLOR slot with H/L on (+31 & 2)? Else no getter call */
 cmp 0,d0
8:
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
 movhu (STATE),d0                 /* P, valid since slot_any: STATE and the header change only before publish */
 add -1,d0
 mov d0,a1
 add POOL,a1                      /* a1 = block (uncached) */
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

pr_gate:                          /* frame 36 */
 call hl_ok,[a2],16
 cmp HL_FAIL,d0
 beq pr_gout
 cmp 0,d0
 beq pr_go
 jmp pr_nmd                       /* v0.29.1 (#38): no medium MOUNT OK: pr_nmd (ext12) loads from the camera's memory */
pr_go:
 call st_claim,[d2,d3],12         /* one attempt per power-on, also against el_go (GUI task) */
 cmp 0,d0
 beq pr_gout
 call sd_load,[d2,d3,a2,a3],36
pr_gout:
 ret [d2,d3,a2,a3],36

/* ed_trig (frame 36): P valid + marker + dirty == 1 + hl_ok (card mounted)
 * -> dirty = 0, one ub_save, status byte = its result. */
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
 mov -1,d2                        /* #64: the camera's dial label back for the other screens (the wheel puts Sat */
 call vl_s,[d2,d3,a2,a3],20       /* in when it opens) */
1:
 movbu (DIRTY,a2),d0
 cmp 1,d0
 bne t_out
 call hl_ok,[a2],16
 cmp 0,d0
 bne t_out
 clr d0
 movbu d0,(DIRTY,a2)              /* one attempt per batch of edits, whatever happens */
 call ub_save,[d2,d3,a2,a3],24    /* films in camera memory: films, edits and Extras into store M (no card copies) */
 movbu d0,(STATUS,a2)
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
 movbu (AXIS,a2),d3               /* sector ids only on the Hue / Light / Extras / Film pages: else 5f */
 add -1,d3
 cmp 4,d3
 bcc 5f
 movbu (EDK,a2),d3                /* -> sector id 928 + 12k + slice of the open editor */
 cmp 4,d3
 bcc g_miss
 add -4,sp                        /* the call's return slot: it would overwrite the saved a2 */
 call vl_s,[d2,d3,a2,a3],20       /* v0.20: the dial label ("Vivid") names the Extras slice (code block) */
 add 4,sp
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
g_ret:                            /* emu_test: the caller's d2, d3, a2 are back here */
 rets
5:                                /* axis 0 or 5..: the dial label names the page, then stock */
 movbu (EDK,a2),d3
 cmp 4,d3
 bcc g_miss
 mov d0,d3                        /* the entry's d0, d1 through vl_s (it keeps d2, d3): g_miss passes them on */
 mov d1,d2
 mov mdr,d0
 add -8,sp                        /* (0) the call's return slot, (4) the entry's MDR, as stock_get expects it */
 mov d0,(4,sp)
 call vl_s,[d2,d3,a2,a3],20
 mov (4,sp),d0
 mov d0,mdr
 add 8,sp
 mov d3,d0
 mov d2,d1
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
 jmp vf_def

/* ed_set <- 0x60b8798b `call 0x60bb528f,[d2,d3,a2,a3],68` in the facade SetValue (mode 0): entered exactly like
 * the settings manager (d0 id, d1 value, a0 inner, a1 mode; d2/d3/a2/a3 saved by the call; return address at
 * (68,sp)). H/L hit: value -5..5 into the table, slot H/L bit, dirty; then the manager runs for COLOR k's cursor
 * 2197 + k with its unchanged value (s_cur), so its listeners refresh the screen. */
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
s_cur:                            /* wheel pages: d2 = P offset of a byte in slot k, 64k + 32 + x (x < 64) -> the refresh */
 mov d2,d0                        /* writes COLOR k's cursor 2197 + k (~17k instructions; the sector id's write re-checks */
 add -32,d0                       /* 37 more settings, ~375k). The cursor write redraws the wheel (k_cur's poke). */
 lsr 6,d0
 add 2197,d0
s_dirty:                        /* test 16: hand edits belong to the selected bank profile (saved back at the half-press) */
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
 bra s_cur
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
 mov 0x181,d1                     /* want 1 << 8 | mask 0x81 */
 mov 32 + 25,a0
 mov (SEC_READY),d0               /* section 6 (slot_any) ready? Before it STATE is 0: the same exit */
 and 0x20,d0
 beq 8f                           /* short, so the gate stays right before the call; Z still set at 8 */
 call slot_any,[d2,d3,a2],16      /* P valid and some COLOR slot with the WB flag? (else no more getter calls) */
 cmp 0,d0
8:
 beq 9f
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
 movhu (STATE),d0                 /* P, valid since slot_any: STATE and the header change only before publish */
 add -1,d0
 mov d0,a1
 add POOL,a1
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
 mov (SEC_READY),d0               /* section 6 (ub_chk) ready? Else the read, as before */
 and 0x20,d0
 beq 7f
 call ub_chk,[d2,d3,a2,a3],20     /* a valid block: ub_bun overwrites the whole file, so no read */
 cmp 0,d0
 bne sd_pub
7:
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
 call ub_bun,[d2,d3,a2,a3],20     /* films in camera memory: the Extras settings from the camera when it has them */
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
 call ub_pfl,[d2,d3,a2,a3],28     /* the films: the camera's, or new ones from C:\OM3MOD\LOOKS.BIN (films in camera memory) */
 call nm_ex,[d2,d3,a2,a3],36      /* profile name pictures from C:\OM3MOD\NAMES.BIN (test 17); v0.28 pc1: then ex_live */
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

/* sd_crc: d0 = running CRC, a0 = data, d1 = length (> 0) -> d0. CRC-32 (reflected, 0xedb88320), a nibble at a time
 * from sd_nib. Keeps a1. */
sd_crc:
 add -4,sp
 mov a1,(sp)
 mov sd_nib,a1
1:
 movbu (a0),d2
 xor d2,d0
 mov d0,d2
 and 15,d2
 asl2 d2
 mov (d2,a1),d2
 lsr 4,d0
 xor d2,d0
 mov d0,d2
 and 15,d2
 asl2 d2
 mov (d2,a1),d2
 lsr 4,d0
 xor d2,d0
 inc a0
 add -1,d1
 bne 1b
 mov (sp),a1
 add 4,sp
 ret [d2,d3],12
 .balign 4
sd_nib:                           /* the CRC of each nibble value, 4 steps of 0xedb88320 */
 .long 0x00000000,0x1db71064,0x3b6e20c8,0x26d930ac,0x76dc4190,0x6b6b51f4,0x4db26158,0x5005713c
 .long 0xedb88320,0xf00f9344,0xd6d6a3e8,0xcb61b38c,0x9b64c2b0,0x86d3d2d4,0xa00ae278,0xbdbdf21c

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
 mov (12,sp),d0                   /* rgb-curves: COLOR k's curves flat too */
 add -2197,d0
 call cv_zk,[d2],8
 mov (12,sp),d0                   /* colour mix: and its mix off */
 add -2197,d0
 call mx_zk,[d2],8
 mov (12,sp),d0                   /* g2: and its Film Grain strength / size follow the level (0 now): G 0 */
 add -2197,d0
 call gs_zk,[d2],8
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
 * id that stock calls default is reported changed when its Hue, Light or split toning is non-zero. Through ed_isd0
 * (the profile's '*') also when any other setting in the slot is, WB shift included. Reads only. */
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
 asl 8,d1                         /* the ed_isd0 flag into d3 bit 8: stock_isdef keeps d3, not d1 */
 or d1,d3
 mov d2,d0
 call stock_isdef,[d2,d3,a2],24   /* keeps d2/d3/a2 */
 movbu d3,(AXIS,a2)               /* ... then the page back */
 cmp 0,d0
 beq 9f
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc 70f
 mov a2,a0
 add 32,a0                        /* slot 0 entry */
81:
 cmp 12,d2
 bcs 82f
 add -12,d2
 add 64,a0
 bra 81b
82:
 mov d3,d1
 clr d3
 btst 0x100,d1                    /* the HSL row's '*' (ed_isdef): its own settings only; the profile's (ed_isd0): all */
 beq 84f
 movbu (47,a0),d3                 /* Blacks, Whites, Extras Glow/Clarity, Art Effect, NR, VigFix: any non-zero */
 mov (48,a0),d1                   /* +48..51 (slot entries are 4-aligned: P + 32 + 64k) */
 or d1,d3
 movhu (52,a0),d1                 /* +52, +53: VigFix, Grain */
 or d1,d3
 movbu (54,a0),d1                 /* +54 Sharp (v0.26: +55, a split toning colour, alone is no change) */
 or d1,d3
 movbu (30,a0),d1                 /* v0.28 Halation */
 or d1,d3
 movbu (33,a0),d1                 /* v0.28 Tone Balance (its own row, so a change shows on the profile too) */
 or d1,d3
 movbu (25,a0),d1                 /* WB on (bit0 set, bit7 clear) and shifted: the WB row's, not the HSL row's */
 and 0x81,d1
 cmp 1,d1
 bne 84f
 movhu (26,a0),d1
 or d1,d3
84:
 movbu (56,a0),d1                 /* v0.26: the split toning strengths +56, +58 */
 or d1,d3
 movbu (58,a0),d1
 or d1,d3
 cmp 0,d3
 bne 7f
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
70:                               /* the WB and Blacks / Whites grid rows (their one option reads 0): the slot's values */
 add 928,d2
 mov d2,d1
 add -BWB,d1
 cmp 4,d1
 bcs 72f
 mov d2,d1
 add -WGB,d1
 cmp 4,d1
 bcc 8b
 asl 6,d1
 mov a2,a0
 add d1,a0
 movbu (57,a0),d3                 /* slot +25: WB on (bit0 set, bit7 clear), then +26 / +27 */
 and 0x81,d3
 cmp 1,d3
 bne 8b
 movhu (58,a0),d3
 bra 73f
72:
 asl 6,d1
 mov a2,a0
 add d1,a0
 movbu (79,a0),d3                 /* slot +47 Blacks, +48 Whites */
 movbu (80,a0),d1
 or d1,d3
73:
 cmp 0,d3
 bne 7b
 bra 8b
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
 * +48 Whites, s8 -7..7 (v0.28; was -5..5; outside counts as 0). Remap = Caduceus tools/ep7_tone.py remap(), bit-exact.
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
 add 7,d0                         /* v0.28 g2: -7..+7 (was -5..+5), the same step */
 cmp 15,d0
 bcs 3f
 mov 7,d0
3:
 add -7,d0
 movbu (48,a0),d1                 /* Whites */
 extb d1
 add 7,d1
 cmp 15,d1
 bcs 4f
 mov 7,d1
4:
 add -7,d1
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
 cmp pf_bt+42,a1
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

.section .ext8,"ax"

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
 call cv_rec,[d2,d3,a2,a3],20     /* rgb-curves: the record's curves into COLOR k's */
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
 cmp pf_bt+42,a1
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
 call pf_eq,[d2,d3,a2,a3],28      /* the camera's value already this one: no write (as rc_put) */
 cmp 0,a0
 beq 62f
 mov (4,sp),a0
 mov (8,sp),a1
 call manager,[d2,d3,a2,a3],68
62:
 mov (20,sp),d3
 inc d3
 mov d3,(20,sp)
 cmp 18,d3
 bne 5b
 ret [d2,d3,a2,a3],40

/* pf_eq: `call pf_eq,[d2,d3,a2,a3],28` from pf_put, d0 = setting id, d1 = value -> d0, d1 kept, a0 = 0 when the
 * camera's value (sget) is already d1. Locals (4) id, (8) value. */
pf_eq:
 mov d0,(4,sp)
 mov d1,(8,sp)
 call sget,[],4
 mov (8,sp),d1
 sub d1,d0
 mov d0,a0
 mov (4,sp),d0
 ret [d2,d3,a2,a3],28

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
 .byte 57,6                        /* v0.28: halation, record +57 <-> slot +30 */
 .byte 58,9                        /* v0.28: split-tone balance, record +58 <-> slot +33 */
 .byte 59,10, 60,11, 61,12, 62,13  /* v0.28 film WB: record +59..+62 <-> slot +34..+37 (fw_keep / fw_apply) */
pf_lo:                            /* record byte i: lo; span = -2 lo for lo < 0, 1 for byte 36 (WB on 0/1), else 0
                                     (test 18: the span half of this table is computed, to make room) */
 .byte -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5, -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5, -5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5
 .byte 0, -7,-7,-7,-7, -2,-2,-5, -7,-7,-7, -5,-5,-5, -1, -5, -5, -12,-5,-12,-5, -5,-5,-5,-5,-5,-5,0   /* v0.26 +53..+56 split toning; v0.26.1 +37 / +38 WB -7..7; v0.28 +57 halation, +58 balance, +59..+62 film WB */
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

/* vl_s: `call vl_s,[d2,d3,a2,a3],20`, d2 = slice (-1: the camera's picture), a2 = P; keeps d0..d1? no: keeps a0, a1
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
 jmp lv_g                         /* #68: the body is in .ext11 (.ext2 is full), s_lv6, through lv_g (section 6 in) */

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

/* ---- Section gates (fix/section-gates, 2026-11-17; research/NOTES.md "Section order audit"). Live view's picture
 * set-up runs these three section-2 sites, also at power-on, and they lead into section 6 (.ext11 / .ext12). The loader
 * copies the sections while the camera starts and the camera marks each one ready (SEC_READY, bit id - 1, set at
 * 0x60046064); no stock wait puts live view's first set-up after section 6's. Each gate tests section 6's bit and,
 * until it is set, runs the stock instructions: the same picture as now (our looks need the films, which load
 * later). d0 is free at all three sites (each target writes it before reading it). Section 1's tail: always in. */
.section .ext1,"ax"
mx_g:                             /* G1: jmp from .hook_mx (0x6051485a), in the matrix function's frame */
 mov (SEC_READY),d0
 and 0x20,d0
 beq 1f
 jmp mx_go
1:
 call mx_row,[d2,d3,a2,a3],20     /* the stock instruction at 0x6051485a */
 jmp MX_BACK
tn_g:                             /* G2: `call tn_g,[d2,d3,a2,a3],56` from .hook_tone (0x605197d7); tone (section 5) */
 mov (SEC_READY),d0               /* always ends in st_run (section 6) */
 and 0x20,d0
 beq 1f
 jmp tone
1:
 mov d3,a0                        /* the stock 0x605197d7: mov d3,a0, then 0x60518fa4 in this call's frame */
 jmp tone_next
rr_g:                             /* G5: jmp from .hook_rr (section 7); rr_go reads section 6 */
 mov (SEC_READY),d0               /* d0 is free: the handler clears it before reading it */
 and 0x20,d0
 beq rr_st
 jmp rr_go
rr_st:                            /* the stock 0x611356e6 */
 movm [d2,a2,a3],(sp)
 add -16,sp
 mov a0,a2
 jmp rr_back
lv_g:                             /* G3: jmp from s_lv (the live view / movie request at a COLOR mode, d0 = 11) */
 mov (SEC_READY),d0
 and 0x20,d0
 beq 1f
 jmp s_lv6
1:
 mov 11,d0                        /* the stock path: picture mode 11 (< 100) -> 0x6046b94f with d0 = 11 */
 jmp lv_skip

.section .ext5,"ax"
s_wt:                            /* leaf: MDR = return, a0 = combiner context; keep a0 for the stock getter */
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
 .long 111, MX_IT, RG_IT, 5397, TB_IT, AB_IT, 5398, BK_IT, 8, 7, NR_IT, VF_IT, 5399, GL_IT, HL_IT, GS_IT, SZ_IT, FR_IT   /* better grain g2: Film Grain Effect (5400, Off / Low / Med / High) -> our strength slider GS_IT and the Grain Size row SZ_IT. borders: + Border (last).  colour menu (test 7, owner-approved spec): pages of five: the film and its colour in the camera's order (mix, curves, wheel, split tone balance), white balance and tone, detail / lens / light, grain. v0.25: Shading back,
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
.set FRB, 0x7eb0                  /* borders: the Border slider row (class 10, slot +50, 0..5; v0.25..v0.30 the Frame
                                   * choice row on the same byte: 0 Off / 5 Frame) */
.set NR_IT, 5394
.set VF_IT, 5389
.set BK_IT, 5386
.set WH_IT, 5385
.set AB_IT, 5384
.set GM_IT, 5383
.set GL_IT, 5382
.set FR_IT, 5381                  /* borders: the Border row (was Frame's) */
.set HL_IT, 5380                  /* v0.28 Halation slider row (class 12, slot +30, 0..5) */
.set HLB, 0x7ed0                  /* its bar ids + k (row 13; row 12 is WGB) */
.set TB_IT, 5379                  /* v0.28 split-tone Balance slider row (class 13, slot +33, -5..+5) */
.set GS_IT, 5388                  /* better grain g2: the Film Grain strength slider (class 15, 0..5; gs_eff / gs_wr) */
.set SZ_IT, 5387                  /* g2: the Grain Size choice row (class 16: 0 Fine, 1 Medium, 2 Coarse) */
.set GSB, 0x7e90                  /* g2: their bar ids + k (row 9: the films' FLB rows end at 0x7e83) */
.set SZB, 0x7e98
.set RG_IT, 5378                  /* rgb-curves: the RGB curves row (the H&S row's cases; rgbcurves.inc) */
.set MX_IT, 5377                  /* colour mix: the Mix row (the H&S row's cases too; colourmix.inc) */
.set TBB, 0x7ee0                  /* its bar ids + k (row 14) */
.set BWB, 0x7ef0                  /* v0.28 Blacks / Whites grid row (BK_IT): its one option's id + k (row 15, class 14) */
.set IC_BWG, 0x7f70               /* v0.28 our 8 pictures for the camera's WB grid while it is the Blacks / Whites grid */
.set IC_BW, 0x7f7f                 /* v0.28 g2 the Blacks / Whites row's left cell with its values (bw_desc, wb_draw) */
.set ST_VIG, 0x7f00               /* our string ids (st_get answers them; the camera's table has ~6000) */
.set ST_STD, 0x7f01
.set ST_BKS, 0x7f02                 /* "Blacks" */
.set ST_WHS, 0x7f03                 /* "Whites" */
.set ST_AB, 0x7f04                  /* "A-B" */
.set ST_GM, 0x7f05                  /* "G-M" */
.set ST_GLC, 0x7f06                 /* "Glow / Clarity" */
.set ST_BDR, 0x7f07                 /* borders: "Border" (was "Frame") */
.set ST_HAL, 0x7f08                 /* v0.28 "Halation" */
.set ST_TBL, 0x7f09                 /* v0.28 "Tone Balance" */
.set ST_GZT, 0x7f0a                 /* g2: "Grain Size", then "Grain Size: Fine" / "... Medium" / "... Coarse", "Coarse" (the last one
                                   * only the tail of the "Coarse" title) */
.set ST_GZ0, 0x7f0b
.set ST_CRS, 0x7f0e
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
.set IC_HL, IC_F0                 /* v0.28 "Halo" slider icon (mkicons PICTURES[12], Frame's old place) */
.set IC_TB, IC_F1                 /* v0.28 "Bal" slider icon (mkicons PICTURES[13], Frame On's old place) */
.set IC_BD, IC_GM                 /* borders: the Border icon (mkicons border_icon, PICTURES[3], G-M's unused place),
                                   * ic_list 8. b1b tried the camera's Frame picture 832: 82 x 62, too big for the 46 x 46
                                   * slot (owner: "too large and already cut off"); the camera has no smaller one */
.set IC_END, 0x7f8e
.set IC_GR, 0x7f78                /* g2: the Film Grain slider icon (mkicons PICTURES[14]): ic_ent entry 14 */
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
.set SAT_AG, SAT_LL + ((LLS + 3) & ~3)  /* then #64's "Sat. All [INFO]" guide (SDESC), copied from fl_sagd */
.set SAS4, (SAS + 3) & ~3
.set SAT_LEN, SAT_AG + SAS4
.set EOPEN, 689                   /* P+EOPEN: 1 from the wheel's init to its first INFO (film test 10) */
.set LDESC, 0xa4cf61f8            /* the wheel's "Color" dial label, 70 x 30 */
.set LSTOCK_P, 0xa4cf5c70
.set LSTOCK_S, 1415
.set SDESC, 0xa49edf88            /* the "Color Select [INFO]" guide (shown with all colours), 180 x 50 */
.set SSTOCK_P, 0xa49ece10
.set SSTOCK_S, 4471
.set SDESC_W, 180                 /* SDESC's width, the camera's picture */
.set SAT_GW, 175                  /* our guide's width (P+SATB) */
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
bw_tab:
 .long 54, BWB, 55, BWB + 1, 56, BWB + 2, 64, BWB + 3
wh_tab:
 .long 54, WHB, 55, WHB + 1, 56, WHB + 2, 64, WHB + 3
gm_tab:
 .long 54, GMB, 55, GMB + 1, 56, GMB + 2, 64, GMB + 3
wg_tab:
 .long 54, WGB, 55, WGB + 1, 56, WGB + 2, 64, WGB + 3
gl_tab:
 .long 54, GLB, 55, GLB + 1, 56, GLB + 2, 64, GLB + 3
fr_tab:
 .long 54, FRB, 55, FRB + 1, 56, FRB + 2, 64, FRB + 3
hl_tab:
 .long 54, HLB, 55, HLB + 1, 56, HLB + 2, 64, HLB + 3
tb_tab:
 .long 54, TBB, 55, TBB + 1, 56, TBB + 2, 64, TBB + 3
gs_tab:                           /* g2 */
 .long 54, GSB, 55, GSB + 1, 56, GSB + 2, 64, GSB + 3
sz_tab:
 .long 54, SZB, 55, SZB + 1, 56, SZB + 2, 64, SZB + 3
.balign 8
sw11_tab:                         /* the row switches 0x615511cc and 0x6155134c (16 entries, full with our rows) */
 .space 32 * 8                    /* re-hashed by build.py into 32 entries */
sw13_tab:
 .space 32 * 8
it_tab:                           /* the stock 17 item entries (filled by build.py), then ours (40 B each) */
 .space 17 * 40
 .long NR_IT, nr_title, nr_l0, 4, 0, nr_l1, 4, 0, nr_l2, 4    /* title, labels, two icon lists (as 5400's) */
 .long VF_IT, vf_title, vf_l0, 2, 0, vf_l1, 2, 0, vf_l2, 2
 .long BK_IT, bk_title, bw_l0, 1, 0, bw_l1, 1, 0, bw_l2, 1      /* v0.28 the Blacks / Whites grid row (as the WB row; */
 .long WH_IT, 0, 0, 0, wh_title, 0, 6 << 16, 0, 0, 0           /* left icon: 5 / 6 = IC_BK / IC_WH in ic_list) */
 .long AB_IT, ab_title, wb_l0, 1, 0, wb_l1, 1, 0, wb_l2, 1      /* v0.25 WB grid row: one option (as test 12) */
 .long GM_IT, 0, 0, 0, gm_title, 0, 8 << 16, 0, 0, 0
 .long GL_IT, 0, 0, 0, gl_title, 0, 9 << 16, 0, 0, 0           /* v0.25: icon 9 = IC_GL */
 .long FR_IT, 0, 0, 0, fr_title, 0, 8 << 16, 0, 0, 0          /* borders: a slider as Halation; icon 8 = IC_BD (was the
                                                                   * Frame choice row, as Vignette Correction) */
 .long HL_IT, 0, 0, 0, hl_title, 0, 10 << 16, 0, 0, 0          /* v0.28: icon 10 = IC_HL */
 .long TB_IT, 0, 0, 0, tb_title, 0, 11 << 16, 0, 0, 0          /* v0.28: icon 11 = IC_TB */
 .long GS_IT, 0, 0, 0, gs_title, 0, 12 << 16, 0, 0, 0          /* g2: a slider as Halation; icon 12 = IC_GR */
 .long SZ_IT, sz_title, sz_l0, 3, 0, sz_l1, 3, 0, sz_l2, 3    /* g2: a choice row as Noise Filter */
 .long RG_IT, 0, 0, 0, 0x6154bd18, 0x1b, 0, 0, 0, 0             /* rgb-curves: as H&S's entry (item 5398) */
 .long MX_IT, 0, 0, 0, 0x6154bd18, 0x1b, 0, 0, 0, 0             /* colour mix: the same */
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
 .short 4, ST_BDR
 .long 0x6154b480
hl_title:
 .short 4, ST_HAL
 .long 0x6154b480
tb_title:
 .short 4, ST_TBL
 .long 0x6154b480
gs_title:                         /* g2: the camera's own "Film Grain Effect" (string 2778), the row's title until now */
 .short 4, 2778
 .long 0x6154b480
sz_title:
 .short 4, ST_GZT
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
bw_l0:                            /* v0.28 Blacks / Whites grid row: the title "Blacks / Whites" */
 OPT 0, 4, ST_BKS
bw_l1:                            /* the left column: "Blk/Wht" over the values (wb_draw; before it: "Blk" / "Wht") */
 OPT 0, 3, IC_BW
bw_l2:
 OPT 0, 3, IC_BW
wb_l0:                            /* v0.25 WB grid row: the title "WB" */
 OPT 0, 4, ST_AB
wb_l1:                            /* the left column: the WB± picture over the values (wb_draw) */
 OPT 0, 3, IC_WB
wb_l2:                            /* the strip (under the grid): the camera's WB± picture */
 OPT 0, 3, 12545
sz_l0:                            /* g2 Grain Size: the title with its value */
 OPT 0, 4, ST_GZ0
 OPT 1, 4, ST_GZ0 + 1
 OPT 2, 4, ST_GZ0 + 2
sz_l1:                            /* the left column: Film Grain Effect's own Low / Med / High pictures (item 5400's lists,
                                     the row these replace; owner, 2026-11-16: "reuse the current grain pictures for low,
                                     med, high"): Fine = Low, Medium = Med, Coarse = High */
 OPT 0, 3, 14561
 OPT 1, 3, 14563
 OPT 2, 3, 14565
sz_l2:                            /* the strip: the same row's strip pictures */
 OPT 0, 3, 14562
 OPT 1, 3, 14564
 OPT 2, 3, 14566
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
 mov bw_tab,a3
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
 bne 10f
 mov fr_tab,a3
 mov 4,d2
 bra 9f
10:
 cmp HL_IT,d0                     /* v0.28 Halation */
 bne 11f
 mov hl_tab,a3
 mov 4,d2
 bra 9f
11:
 cmp TB_IT,d0                     /* v0.28 Tone Balance */
 bne 12f
 mov tb_tab,a3
 mov 4,d2
 bra 9f
12:
 cmp GS_IT,d0                     /* g2 Film Grain strength */
 bne 13f
 mov gs_tab,a3
 mov 4,d2
 bra 9f
13:
 cmp SZ_IT,d0                     /* g2 Grain Size */
 bne 9f
 mov sz_tab,a3
 mov 4,d2
9:
 jmp lc_back                      /* 0x611d19b4: cmp 0,a3 */

/* st_get <- jmp from the string getter 0x610f56a6 (its frame: `call ..,[d2],8`; d0 id -> a0 the UTF-16 string):
 * our own strings, else as stock (language index 0x610f56bd, then the table lookup at 0x610f56ac). */
st_get:
 cmp ST_GZT,d0                    /* g2: "Grain Size" .. "Coarse" (gs_strs) */
 bcs 50f
 cmp ST_CRS + 1,d0
 bcc 50f
 mov d0,d2
 add -ST_GZT,d2
 asl2 d2
 mov gs_strs,a0
 add d2,a0
 mov (a0),a0
 ret [d2],8
50:
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
 cmp ST_BDR,d0                    /* borders */
 bne 8f
 mov bdr_str,a0
 ret [d2],8
8:
 cmp ST_HAL,d0                    /* v0.28 */
 bne 9f
 mov hal_str,a0
 ret [d2],8
9:
 cmp ST_TBL,d0                    /* v0.28 */
 bne 2f
 mov tbl_str,a0
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
 jmp cr_str                        /* crop modes: our labels (crop.s), then cr_stk */
cr_stk:
 mov d0,d2
 call str_lang,[],0
 jmp str_back
.balign 2
bks_str:                          /* "Blacks / Whites" (v0.28 the grid row) */
 .short 66, 108, 97, 99, 107, 115, 32, 47, 32, 87, 104, 105, 116, 101, 115, 0
whs_str:
 .short 87, 104, 105, 116, 101, 115, 0
abs_str:                          /* v0.25 the WB grid row's title; colour menu (test 7): "WB Compensation" */
 .short 87, 66, 32, 67, 111, 109, 112, 101, 110, 115, 97, 116, 105, 111, 110, 0
gms_str:                          /* "G-M" */
 .short 71, 45, 77, 0
glc_str:                          /* "Glow" (v0.25 owner: + Glow, - Clarity; the row is named for its + side); test 7 "Glow Effect" */
 .short 71, 108, 111, 119, 32, 69, 102, 102, 101, 99, 116, 0
bdr_str:                          /* borders: "Border" (was "Frame") */
 .short 66, 111, 114, 100, 101, 114, 0
hal_str:                          /* v0.28 "Halation"; colour menu (test 7): "Halation Effect" */
 .short 72, 97, 108, 97, 116, 105, 111, 110, 32, 69, 102, 102, 101, 99, 116, 0
tbl_str:                          /* v0.28 "Tone Balance"; colour menu (test 7): "Split Tone Balance" */
 .short 83, 112, 108, 105, 116, 32, 84, 111, 110, 101, 32, 66, 97, 108, 97, 110, 99, 101, 0
gzt_str:                          /* g2: "Grain Size", then ": Fine" / ": Medium" / ": Coarse", "Coarse" */
 .short 71, 114, 97, 105, 110, 32, 83, 105, 122, 101, 0
gz0_str:
 .short 71, 114, 97, 105, 110, 32, 83, 105, 122, 101, 58, 32, 70, 105, 110, 101, 0
gz1_str:
 .short 71, 114, 97, 105, 110, 32, 83, 105, 122, 101, 58, 32, 77, 101, 100, 105, 117, 109, 0
gz2_str:
 .short 71, 114, 97, 105, 110, 32, 83, 105, 122, 101, 58, 32
crs_str:
 .short 67, 111, 97, 114, 115, 101, 0
 .balign 4
gs_strs:
 .long gzt_str, gz0_str, gz1_str, gz2_str, crs_str
 .balign 2
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
 CHC hl_f, HLB, f2c_obj           /* v0.28 Halation slider */
 CHC tb_f, TBB, f2c_obj           /* v0.28 Tone Balance slider */
 CHC fr_f, FRB, f2c_obj           /* borders: the Border slider (was the Frame choice row) */
 CHC gs_f, GSB, f2c_obj           /* g2: the Film Grain strength slider */
 CHC sz_a, SZB, cha_back          /* g2: the Grain Size choice row (as Noise Filter) */
 CHC sz_b, SZB, chb_back
 CHC sz_c, SZB, chc_back
 CHC sz_d, SZB, chd_back
 CHC sz_f, SZB, chf_back
 CHC bw_a, BWB, cha_back          /* v0.28 Blacks / Whites grid row: as the WB grid row */
 CHC bw_b, BWB, chb_back
 CHC bw_c, BWB, chc_back
 CHC bw_d, BWB, chd_back
 CHC bw_f, BWB, chf_back
 CHC wg_a, WGB, cha_back          /* v0.25 WB grid row: as the Frame row, one option */
 CHC wg_b, WGB, chb_back
 CHC wg_c, WGB, chc_back
 CHC wg_d, WGB, chd_back
 CHC wg_f, WGB, chf_back

/* lc_nr / lc_vf <- row switch 0x6155124c (the left column's cell): as Film Grain's case 0x611d0b57 (cell type 1, the
 * icon of the value from the item's list) but GetValue of our row's own id instead of 998 -> 0x611d0b72. */
lc_nr:
 mov NR_IT,d2
 bra 1f
lc_vf:
 mov VF_IT,d2
 bra 1f
lc_wg:
 mov AB_IT,d2
 bra 1f
lc_bw:
 mov BK_IT,d2
 bra 1f
lc_sz:                            /* g2 Grain Size */
 mov SZ_IT,d2
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
 mov 12,d1                        /* v0.28 Halation */
 mov d3,d2
 add -HLB,d2
 cmp 4,d2
 bcs 2f
 mov 13,d1                        /* v0.28 Tone Balance */
 mov d3,d2
 add -TBB,d2
 cmp 4,d2
 bcs 2f
 mov 14,d1                        /* v0.28 Blacks / Whites grid row */
 mov d3,d2
 add -BWB,d2
 cmp 4,d2
 bcs 2f
 mov 15,d1                        /* g2 Film Grain strength, Grain Size */
 mov d3,d2
 add -GSB,d2
 cmp 4,d2
 bcs 2f
 mov 16,d1
 mov d3,d2
 add -SZB,d2
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
 mov 14,d1                        /* v0.28: the Blacks / Whites grid row */
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
 beq 1f
 mov 12,d1                        /* v0.28 Halation */
 cmp HL_IT,d3
 beq 1f
 mov 15,d1                        /* g2 */
 cmp GS_IT,d3
 beq 1f
 mov 16,d1
 cmp SZ_IT,d3
 beq 1f
 mov 13,d1                        /* v0.28 Tone Balance */
 cmp TB_IT,d3
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
 cmp 15,d1                        /* g2: Film Grain strength 0..5 / Grain Size 0..2 (gs_eff: the slot's level and the
                                     curves record's spare byte) */
 bcs 80f
 cmp 17,d1
 bcc 80f
 mov d1,d3
 call gs_eff,[d2,d3,a2],16        /* keeps a3; d0 strength, d1 size */
 cmp 15,d3
 beq 99f
 mov d1,d0
 bra 99f
80:
 cmp 14,d1                        /* v0.28 Blacks / Whites grid row: draw its left cell (mode 1); value 0 */
 bne 85f
 mov 1,d0
 call wb_draw,[d2,d3,a2,a3],20
 clr d0
 bra 99f
85:
 cmp 11,d1
 bne 86f
 clr d0                           /* mode 0: the WB grid row */
 call wb_draw,[d2,d3,a2,a3],20    /* v0.25 WB grid row: draw its left cell from the look's A-B / G-M */
 clr d0
 bra 99f
86:
 cmp 12,d1
 bne 88f
 movbu (30,a0),d0                 /* v0.28 Halation 0..5 (slot +30) */
 extb d0
 bra 99f
88:
 cmp 13,d1
 bne 87f
 movbu (33,a0),d0                 /* v0.28 Tone Balance -5..+5 (slot +33) */
 extb d0
 bra 99f
87:
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
 movbu (50,a0),d0                 /* borders: Border 0..5 (slot +50; v0.25 Frame's byte) */
 extb d0
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
 cmp DL_SID,d0
 beq 5f
 cmp DL_MSID,d0
 bne 6f
5:
 jmp dl_get
6:
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
 jmp vf_get                       /* Vignette Correction before the load, else tn_get (v0.26: the Shadows / Highlights
                                   * wheel pages, else ed_get) */

/* REAL miss: d0 = a bar id (904 / GRB / NRB / VFB + k) and P valid -> a3 = class 1..4, d2 = k, a2 = P.
 * REAL miss, 0: the class alone, also before the table loads (count, index, selectable need no P). Class 1 still
 * needs P: its bar 904 + k is the stock Sharpness, whose getter and setter stay the camera's (-2..+2) until then.
 * Uses d2, d3, a2, a3. */
 .macro REAL miss, p=1
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
 bcs 90f
 mov 12,a3                        /* v0.28 Halation */
 mov d0,d2
 exthu d2
 add -HLB,d2
 cmp 4,d2
 bcs 90f
 mov 13,a3                        /* v0.28 Tone Balance */
 mov d0,d2
 exthu d2
 add -TBB,d2
 cmp 4,d2
 bcs 90f
 mov 14,a3                        /* v0.28 Blacks / Whites grid row */
 mov d0,d2
 exthu d2
 add -BWB,d2
 cmp 4,d2
 bcs 90f
 mov 15,a3                        /* g2 Film Grain strength */
 mov d0,d2
 exthu d2
 add -GSB,d2
 cmp 4,d2
 bcs 90f
 mov 16,a3                        /* g2 Grain Size */
 mov d0,d2
 exthu d2
 add -SZB,d2
 cmp 4,d2
 bcc \miss
90:
 .if \p
 PVAL \miss
 .else
 cmp 1,a3
 bne 91f
 PVAL \miss
91:
 .endif
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
 REAL 8f, 0
 mov 1,d0                         /* v0.25: 11 the WB grid row's one option; v0.28 14 Blacks / Whites */
 cmp 11,a3
 beq 6f
 cmp 14,a3
 beq 6f
 mov 6,d0                         /* v0.28: 12 Halation 0..5; g2: 15 Film Grain 0..5 */
 cmp 12,a3
 beq 6f
 cmp 15,a3
 beq 6f
 mov 3,d0                         /* g2: 16 Grain Size Fine / Medium / Coarse */
 cmp 16,a3
 beq 6f
 mov 11,d0                        /* v0.28: 13 Tone Balance -5..+5 */
 cmp 13,a3
 beq 6f
 mov 11,d0                        /* v0.25: 9 Glow / Clarity -5..+5 */
 cmp 9,a3
 beq 6f
 mov 6,d0                         /* borders: 10 Border 0..5 */
 cmp 10,a3
 beq 6f
 mov 15,d0                        /* 7 A-B, 8 G-M: -7..+7 */
 cmp 7,a3
 bcc 6f
 mov 8,d0
 cmp 1,a3
 beq 6f
 mov 15,d0
 cmp 5,a3
 bcc 6f                           /* 5 Blacks, 6 Whites: -7..+7 (v0.28 g2: 7 steps, as the WB grid; was -5..+5) */
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
 clr d0                           /* v0.25: 11 the WB grid row 0, 1; v0.28 14 Blacks / Whites */
 mov 1,d1
 cmp 11,a3
 beq 99f
 cmp 14,a3
 beq 99f
 clr d0                           /* v0.28: 12 Halation 0, 6; g2: 15 Film Grain 0, 6 */
 mov 6,d1
 cmp 12,a3
 beq 99f
 cmp 15,a3
 beq 99f
 mov 3,d1                         /* g2: 16 Grain Size 0, 3 */
 cmp 16,a3
 beq 99f
 mov -5,d0                        /* v0.28: 13 Tone Balance -5, 11 */
 mov 11,d1
 cmp 13,a3
 beq 99f
 mov -5,d0                        /* v0.25: 9 Glow / Clarity -5, 11; borders: 10 Border 0, 6 */
 mov 11,d1
 cmp 9,a3
 beq 99f
 clr d0
 mov 6,d1
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
 mov -7,d0
 mov 15,d1
 cmp 5,a3
 bcc 99f                          /* Blacks / Whites -7, 15 (v0.28 g2) */
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
 REAL 8f, 0
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

/* (v0.40 alpha: pf_cnt and pf_vbi moved here from .ext1, to make room there for the section gates. Only sl_cnt /
 * sl_vbi, just above in section 6, reach them; the facade words point at sl_cnt / sl_vbi.) */
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
 REAL 8f, 0
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
 cmp 14,a3                        /* v0.28 Blacks / Whites grid row: nothing either */
 beq 7f
 cmp 15,a3                        /* g2 Film Grain strength / Grain Size -> gs_row */
 bcs 41f
 cmp 17,a3
 bcc 41f
 call gs_row,[d2,d3,a2,a3],40     /* keeps d0, a0, a1, a2 -> d1 0 stored */
 cmp 0,d1
 bne 7f
 jmp s_dirty
41:
 cmp 12,a3
 bne 14f
 cmp 0,d1                         /* v0.28 Halation 0..5 -> +30 */
 blt 7f
 cmp 5,d1
 bgt 7f
 mov d2,a3
 movbu d1,(62,a3)
 jmp s_dirty
14:
 cmp 13,a3
 bne 15f
 cmp -5,d1                        /* v0.28 Tone Balance -5..+5 -> +33 */
 blt 7f
 cmp 5,d1
 bgt 7f
 mov d2,a3
 movbu d1,(65,a3)
 jmp s_dirty
15:
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
 cmp 0,d1                         /* borders: Border 0..5 -> +50 (v0.25 Frame's byte) */
 blt 7f
 cmp 5,d1
 bgt 7f
 mov d2,a3
 movbu d1,(82,a3)
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
 mov d0,(gr_sv)                   /* s_dirty reads d0, a0, a1: kept across nf_get as gr_now keeps them */
 mov a0,(gr_sv + 8)
 mov a1,(gr_sv + 12)
 mov d1,d3
 mov 38681,d0                     /* key 0x9719, the stills Noise Filter (-2..+1) */
 clr d1
 mov 0,a0
 call nf_get,[d2,d3],12
 extb d0
 cmp d3,d0                        /* the camera's own value -> 0 Camera, as after a reset, so no '*' */
 beq 48f
 add 2,d3
 add nr_v2s,d3
 mov d3,a3
 movbu (a3),d3
 bra 49f
48:
 clr d3
49:
 mov d2,a3
 movbu d3,(83,a3)
 mov (gr_sv),d0
 mov (gr_sv + 8),a0
 mov (gr_sv + 12),a1
 jmp s_dirty
4:
 cmp 5,a3
 bcs 5f
 cmp -7,d1                        /* Blacks / Whites -7..+7 -> +47 / +48 (v0.28 g2; was -5..+5) */
 blt 7f
 cmp 7,d1
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
 mov a3,d2                        /* the grids (Blacks, Whites, A-B, G-M) before the films load: refuse, as gr_oid is the */
 add -5,d2                        /* camera's WB shift and ed_set would change the camera's own WB */
 cmp 4,d2
 bcs 7b
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
 cmp HL_IT,d0                     /* v0.28 Halation: 0..5 (h6: its own ends, so the bar starts at the left) */
 beq 5f
 cmp FR_IT,d0                     /* borders: Border 0..5, as Halation */
 beq 5f
 cmp GS_IT,d0                     /* g2: Film Grain 0..5, as Halation */
 beq 5f
 cmp TB_IT,d0                     /* v0.28 Tone Balance: -5..+5 */
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
5:                                /* Halation: 0..5 (the "-" greys out at 0; sl_dot spreads 0..5 over the bar) */
 mov d0,a3
 call facade,[],4
 mov (a0),a2
 mov sp,a1
 mov (12,a2),a2
 add 24,a1
 mov a3,d0
 calls (a2)
 clr d0
 mov d0,a3
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
 bcs 4f
 movhu (a0),d0
 add -HLB,d0
 cmp 4,d0
 bcs 4f
 movhu (a0),d0
 add -TBB,d0
 cmp 4,d0
 bcs 4f
 movhu (a0),d0
 add -GSB,d0                      /* g2: the Film Grain bar */
 cmp 4,d0
 bcs 4f
 movhu (a0),d0
 add -FRB,d0                      /* borders: the Border bar */
 cmp 4,d0
 bcc 2f
4:                                /* dial direction: Glow, Halation, Tone Balance, Film Grain and Border */
 mov (24,sp),a0                   /* border-dial-direction: the bar's control +152 = 1, as 0x611b77b2 sets it for */
 mov 1,d0                         /* the camera's own sliders: a dial click steps it as on Contrast (else the dial */
 mov d0,(152,a0)                  /* step 0x611b41f8 takes the list's way, reversed by setting 307) */
 mov (16,sp),a0
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
 cmp IC_BW,d1                     /* v0.28 g2: the Blacks / Whites row's left cell; our "Blk / Wht" until it is drawn */
 bne 21f
 mov (bw_desc + 12),a0
 cmp 0,a0
 beq 22f
 mov bw_slot,a0
 retf [],0
22:
 mov IC_BK,d1
 mov d1,d0
 bra 20f
21:
 mov (gr_flag),a0                 /* v0.28: the camera's WB grid while it is the Blacks / Whites grid -> our pictures */
 cmp 0,a0
 beq 17f
 mov (gr_mode),a0
 cmp 0,a0
 beq 17f
 mov 11218,a0                     /* the header's WB mode title (11218..11248, 44 px tall: each mode, with and */
 cmp a0,d1                        /* without its '*') -> "Blk/Wht" */
 bcs 15f
 mov 11248,a0
 cmp a0,d1
 bhi 15f
 mov IC_BWG + 7,d1
 bra 18f
15:
 mov bwg_swap,a0
16:
 movhu (a0),d0
 cmp 0,d0
 beq 18f
 cmp d0,d1
 beq 19f
 add 4,a0
 bra 16b
19:
 movhu (2,a0),d1                  /* ours */
18:
 mov d1,d0
17:
 cmp IC_BWG,d1
 bcs 20f
 cmp IC_BWG + 8,d1
 bcc 20f
 add -IC_BWG,d1
 asl2 d1
 mov bwg_ent,a0
 add d1,a0
 retf [],0
20:
 cmp IC_GR,d1                     /* g2: IC_GR -> ic_ent entry 14 */
 bcs 24f
 cmp IC_GR + 1,d1
 bcc 24f
 add 14 - IC_GR,d1
 asl2 d1
 mov ic_ent,a0
 add d1,a0
 retf [],0
24:
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

/* v0.28 Blacks / Whites grid (owner, look D): {the camera's WB grid picture, ours} while gr_flag and gr_mode = 1: the
 * square 10904 (coloured bands -> black left / right, white top / bottom), the boxes' letters A 10327 -> '+' and
 * B 10325 -> '-' on black, G 10324 -> '+' and M 10328 -> '-' on white, the header's letters A / G -> '+', B / M -> '-',
 * its WB mode title (11218..11248: "WBAuto" 11223 / "WBAuto*" 11240 and the other modes, ic_get) -> "Blk/Wht". Our pictures: mkicons.bwg_pictures (build.py bwg.inc: bwg_ent, descriptors). */
.balign 4
bwg_swap:
 .short 10904, IC_BWG, 10327, IC_BWG + 1, 10325, IC_BWG + 2, 10324, IC_BWG + 3, 10328, IC_BWG + 4
 .short 10813, IC_BWG + 5, 10814, IC_BWG + 5, 10817, IC_BWG + 5, 10818, IC_BWG + 5
 .short 10815, IC_BWG + 6, 10816, IC_BWG + 6, 10819, IC_BWG + 6, 10820, IC_BWG + 6, 11240, IC_BWG + 7
 .long 0
.section .ext12,"ax"
 .include "bwg.inc"
.section .ext11,"ax"

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
gr_mode:                          /* v0.28: 0 the WB row, 1 the Blacks / Whites row (gr_upd) */
 .long 0
gr_lmode:                         /* the mode the holder's grid was loaded for */
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
gr_due:                           /* the scene the holder takes in the next row refresh (rr_go), 0: none. Set only in
                                   * Picture Mode, cleared when it closes */
 .long 0
rr_sv:
 .long 0, 0, 0, 0
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
wb_v:                             /* ... +36 the glyph section in LABELS.BIN (xb_wbc; v0.28 g2) */
 .long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

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

/* wb_draw: `call wb_draw,[d2,d3,a2,a3],20`, a0 = the look's slot, d0 = 0 the WB grid row (A-B +26 / G-M +27 ->
 * wb_desc) or 1 the Blacks / Whites grid row (v0.28 g2: +47 / +48 -> bw_desc, "Blk/Wht" over "+2/-1"): the left cell
 * drawn by the code block (xb_wbc, +144) into its buffer, the descriptor pointing there; again only when the values
 * change (descriptor +24). Without the block (or a drawing) ic_get answers the camera's WB± picture / our "Blk / Wht".
 * g4 (owner): at 0 / 0 no drawing: the descriptor points to our bigger, centred icon alone (zc_tab: 0 "WB", 1 "B/W"). */
wb_draw:
 mov d0,a3
 cmp 0,d0
 bne 1f
 movbu (26,a0),d2
 movbu (27,a0),d3
 bra 2f
1:
 movbu (47,a0),d2
 movbu (48,a0),d3
2:
 extb d2
 extb d3
 mov wb_desc,a2
 cmp 0,a3
 beq 3f
 mov bw_desc,a2
3:
 mov d2,d0
 asl 8,d0
 mov d3,d1
 and 255,d1                       /* a negative G-M / Whites must not hide A-B / Blacks */
 or d1,d0
 exthu d0
 mov (24,a2),d1                   /* the values it was drawn for */
 cmp d1,d0
 beq 9f
 mov d0,(24,a2)
 cmp 0,d0                         /* g4 (owner): at 0 / 0 the icon alone, bigger and centred (zc_tab, build.py) */
 bne 5f
 mov a3,d0
 asl 3,d0
 mov zc_tab,a0
 add d0,a0
 mov (a0),d0
 mov d0,(12,a2)
 mov (4,a0),d0
 mov d0,(16,a2)
 bra 9f
5:
 call xp,[],0
 beq 8f
 add 120,a1
 add 24,a1
 mov d2,d0
 mov d3,d1
 mov a3,a0                        /* the mode */
 calls (a1)                       /* -> a0 / d0 the cell */
 cmp 0,d0
 beq 8f
 mov d0,(12,a2)
 mov a0,d0
 mov d0,d1
 and 0xf0000000,d1
 cmp 0x60000000,d1                /* a cached address -> uncached, as the stock pictures' */
 bne 4f
 add 0x40000000,d0
4:
 mov d0,(16,a2)
 bra 9f
8:
 clr d0
 mov d0,(12,a2)
 mov -1,d0
 mov d0,(24,a2)                   /* try again next time */
9:
 ret [d2,d3,a2,a3],20
.balign 4
wb_slot:
 .long wb_desc
bw_slot:
 .long bw_desc
wb_desc:                          /* format 14, 100 x 76, as our cell pictures; size, payload from xb_wbc; +24 drawn for */
 .short 14, 100, 76, 8, 0, 0
 .long 0, 0, 0, -1
bw_desc:                          /* v0.28 g2: the Blacks / Whites row's cell */
 .short 14, 100, 76, 8, 0, 0
 .long 0, 0, 0, -1

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
 mov (gr_mode),d2                 /* v0.28 Blacks / Whites: BKB / WHB + k (slot +47 / +48, -5..+5) */
 cmp 0,d2
 beq 9f
 add BKB - ABB,d0
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
 * holder; else gr_flag = 0 (gr_end gives the holder its bottom bar back). */
gr_upd:
 movhu (a0),d0
 clr d1
 cmp AB_IT,d0                     /* the WB row: gr_mode 0; v0.28 the Blacks / Whites row: 1 */
 beq 6f
 mov 1,d1
 cmp BK_IT,d0
 bne 8f
6:
 mov d1,(gr_mode)
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
 bne 71f
 mov (gr_lmode),d0                /* ... for the other grid row: again (its pictures) */
 mov (gr_mode),d1
 cmp d1,d0
 beq 7f
71:
 mov (gr_mode),d0
 mov d0,(gr_lmode)
 mov 498,d0                       /* the holder takes the WB grid scene in the row refresh: a swap here draws a pass
                                   * without grid or curve before the refresh */
 mov d0,(gr_due)
 bra 9f
7:
 clr d0
 mov d0,(gr_due)
 call gr_ref,[d2,d3,a2,a3],20
 bra 9f
8:
 clr d0
 movbu d0,(gr_flag)
9:
 ret [d2,d3,a2,a3],20

/* gr_end <- jmp from 0x611d059c, the end of the Picture Mode update, after it publishes the new row's values. Off our
 * row, the holder gets its bottom bar back only here: loaded any earlier, the bar shows the last row's values until
 * the publish, and the camera can display that frame. */
gr_end:
 add -4,sp                        /* our calls' slot (the screen update's own (0,sp) stays) */
 movbu (gr_flag),d0
 cmp 0,d0
 bne 1f
 mov (gr_cont),a0
 call gr_is,[d2],8
 cmp 0,d0
 beq 3f
 mov GLY,d0                       /* in the row refresh (rr_go), as gr_upd's grid */
3:
 mov d0,(gr_due)
1:
 add 4,sp
 mov (12,sp),d0
 cmp 0,d0
 beq 2f
 jmp pe_ret
2:
 jmp pe_back

/* rr_go <- jmp from rr_g, the row refresh's entry with section 6 ready: the holder takes the scene gr_upd / gr_end
 * left due, then the stock entry. The camera draws once after the refresh, so that pass has the new scene. */
rr_go:
 mov (gr_due),d0
 cmp 0,d0
 bne 1f
 jmp rr_st
1:
 mov d1,(rr_sv)
 mov a0,(rr_sv + 4)
 mov a1,(rr_sv + 8)
 mov mdr,d0
 mov d0,(rr_sv + 12)
 add -4,sp                        /* our call's slot (the handler's return address stays at (0,sp)) */
 call rr_set,[d2,d3,a2,a3],20
 add 4,sp
 mov (rr_sv + 12),d0
 mov d0,mdr
 mov (rr_sv),d1
 mov (rr_sv + 4),a0
 mov (rr_sv + 8),a1
 jmp rr_st

rr_set:
 mov (gr_due),d2
 clr d0
 mov d0,(gr_due)                  /* before sc_set: a refresh inside it takes rr_go's stock path */
 mov (gr_cont),a0
 cmp 0,a0
 beq 9f
 mov d2,d0
 call sc_set,[d2,d3,a2,a3],28
 cmp 498,d2
 bne 9f
 call gr_ref,[d2,d3,a2,a3],20
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
 mov (gr_mode),d0                 /* v0.28 Blacks / Whites: +47 / +48 */
 cmp 0,d0
 beq 5f
 add 21,a2
5:
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
 movhu (STATE),d1                 /* films loaded: el_go has nothing to do */
 cmp 0,d1
 bne 2f
 mov d0,d1
 exthu d1
 cmp 0,d1
 beq 2f
 mov mdr,d3
 add -16,sp
 mov d3,(4,sp)
 mov d0,(8,sp)
 mov a1,(12,sp)
 call el_go,[d2,d3,a2,a3],36      /* L1: the films from the camera's memory, before the shooting screen draws */
 mov (12,sp),a1
 mov (8,sp),d0
 mov (4,sp),d3
 mov d3,mdr
 add 16,sp
2:
 movbu (rc_pend),d1               /* v0.30-dev k1 (#41): the shooting mode changed with the films in: put each */
 cmp 0,d1                         /* COLOR's film back into the camera's settings (GUI task, between events) */
 bne 01f
 movbu (cm_pend),d1               /* k2: a custom-mode record write held back by the camera's own save */
 cmp 0,d1
 bne 01f
 movbu (cm_init),d1               /* k2: once after the films are in (never before: STATE 0 until the first */
 cmp 0,d1                         /* half-press), so a dial moved while the camera was off is handled */
 bne 0f
 movbu (el_hold),d1               /* L1: after the early load, wait for the first shutter event */
 cmp 0,d1
 bne 0f
 movhu (STATE),d1
 cmp 0,d1
 beq 0f
01:
 mov mdr,d2                       /* d2, d3 are free here (the stock code sets both right after gx_back) */
 mov a1,d3
 mov d0,(rc_d0)
 add -4,sp
 call rc_go,[d2,d3,a2,a3],24
 add 4,sp
 mov d2,mdr
 mov d3,a1
 mov (rc_d0),d0
0:
 movbu (el_pk),d1                 /* after a picture-mode change, once the first look is done: the group keeps */
 cmp 0,d1                         /* what it shows now (cm_hp, as at a shutter event), so a power-off keeps it */
 beq 03f
 mov (8,sp),a0                    /* v0.30.4 (#72): not while the Picture Mode list (0x0418) or the super control */
 movhu (a0),d1                    /* panel (0x0403, its dials step the films too) stays open (no state change, or */
 cmp 0x1804,d1                    /* one between the two): at every step it changed a COLOR's film in the record */
 beq 77f                          /* many times a second and rebooted the camera (probe J, camera: none without */
 cmp 0x0304,d1                    /* it). It runs once as they close (OK, MENU, a half-press). */
 bne 76f
77:
 mov d0,d1
 exthu d1
 cmp 0,d1
 beq 03f
 cmp 0x0418,d1
 beq 03f
 cmp 0x0403,d1
 beq 03f
76:
 movbu (cm_init),d1
 cmp 0,d1
 beq 03f
 movbu (rc_pend),d1
 cmp 0,d1
 bne 03f
 clr d1
 movbu d1,(el_pk)
 mov mdr,d2
 mov a1,d3
 mov d0,(rc_d0)
 add -4,sp
 call cm_hp,[d2,d3,a2,a3],24
 add 4,sp
 mov d2,mdr
 mov d3,a1
 mov (rc_d0),d0
03:
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
 mov mdr,d2                       /* save the edits (pm_save); d2, d3 free here as for rc_go */
 mov d0,d3
 add -4,sp
 call pm_save,[d2,d3,a2,a3],24
 add 4,sp
 mov d2,mdr
 mov d3,d0
 movbu (gr_fine),d1
 cmp 0,d1
 bne 6f                           /* to the fine-tune screen from our row: keep the look */
 movbu d1,(gr_flag)
6:
 clr d1
 mov d1,(gr_due)
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
 .long 0xffff, 7, 7, IC_BD         /* borders: 8 = Border (G-M's slider icon before v0.25) */
 .long 0xffff, 7, 7, IC_GL         /* v0.25: 9 = Glow / Clarity */
 .long 0xffff, 7, 7, IC_HL         /* v0.28: 10 = Halation */
 .long 0xffff, 7, 7, IC_TB         /* v0.28: 11 = Tone Balance */
 .long 0xffff, 7, 7, IC_GR         /* g2: 12 = Film Grain */
ic_lend:
ic_ent:                           /* the slot word of each of our pictures, in firmware/mkicons.py PICTURES order */
 .long ic_d0, ic_d1, ic_d2, ic_d3, ic_d4, ic_d5, ic_d6, ic_d7, ic_d8, ic_d9, ic_d10, ic_d11, ic_d12, ic_d13
 .long ic_d14                     /* g2: id IC_GR (ic_get) */
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
 ICD 14
.balign 8
/* ------------------------------------------------------------------ v0.28 film WB (w3)
 * Owner: a film (and each COLOR's own settings) remembers the camera's WB last used with it, as its HSL does; one
 * that never had one gets Auto. The camera's own WB controls are the UI. Settings 1578 = stills WB mode (the 13-mode
 * table 0x615d1944 {mode, A-B id, movie id}: 0 Auto .. 9 CWB), 107 = Custom WB Kelvin (2000..14000); camera-proven
 * (probes w1 / w2). Slot +34 / +35: Kelvin, v = (K - 2000) / 100 - 60 (CWB only, else 0); +36 / +37: mode code = the
 * mode's index in the table (0 = Auto: none). Each as balanced base-11 digits v = lo + 11 hi (lo, hi -5..5): zero
 * bytes mean none, and every firmware's range checks pass. LOOKS / EDITS record +59..+62 (pf_bt). */
.section .ext12,"ax"
 .balign 4
fw_chg:                           /* 1: fl_set saw a change (fw_keep) and applies the new look's WB (fw_apply) */
 .byte 0
 .balign 2
 .macro FWENC                     /* d0 = v (-60..60) -> d0 = lo, d1 = hi (v = lo + 11 hi, both -5..5) */
 clr d1
91:
 cmp 5,d0
 ble 92f
 add -11,d0
 inc d1
 bra 91b
92:
 cmp -5,d0
 bge 93f
 add 11,d0
 add -1,d1
 bra 92b
93:
 .endm
 .macro FWDEC                     /* d0 = lo, d1 = hi (s8) -> d0 = lo + 11 hi. Uses d1, d2 */
 mov 11,d2
 mul d2,d1
 add d1,d0
 .endm
/* fw_keep: `call fw_keep,[d2,d3,a2,a3],48` from fl_set (inside the manager's 901 call), a2 = P, d0 = k (the COLOR
 * picked), d1 = its new look n, d2 = its look before -> d0 1 when the look or the picture mode changes, else 0 (the
 * camera writes 901 again at each half-press). On a change from COLOR 1-4, the camera's WB first goes into the slot of
 * the COLOR being left (then fl_sw saves a film being left on COLOR k with it). Locals (4) k, (8) changed, (12) 64 x
 * the COLOR left, (16) mode code, (20) Kelvin v, (24) P (locals stay below the 16 B of saved registers at the
 * frame's top). Stores: that slot's +34..+37, P+DIRTY. */
fw_keep:
 mov d0,(4,sp)
 mov a2,(24,sp)                   /* P (sget does not keep a2) */
 clr d3
 cmp d1,d2
 beq 1f
 mov 1,d3
1:
 mov d3,(8,sp)
 mov 111,d0
 call sget,[],4                   /* the picture mode now (keeps d2, d3) */
 mov fl_cvt,a0
 clr d1
2:
 movbu (d1,a0),d2
 cmp d2,d0
 beq 3f
 inc d1
 cmp 4,d1
 bne 2b
 mov 1,d0                         /* not on COLOR 1-4 now: a change, nothing to keep */
 ret [d2,d3,a2,a3],48
3:
 mov (4,sp),d2
 cmp d1,d2
 beq 4f
 mov 1,d3
 mov d3,(8,sp)                    /* another COLOR */
4:
 mov (8,sp),d3
 cmp 0,d3
 bne 5f
 clr d0                           /* the same look on the same COLOR */
 ret [d2,d3,a2,a3],48
5:
 asl 6,d1
 mov d1,(12,sp)
 mov 1578,d0
 call sget,[],4                   /* the camera's WB mode */
 mov 0x615d1944,a0
 clr d2
6:
 mov (a0),d1
 cmp d1,d0
 beq 7f
 add 12,a0
 inc d2
 cmp 13,d2
 bne 6b
 clr d2                           /* not in the table: none */
7:
 mov d2,(16,sp)
 clr d1
 mov d1,(20,sp)
 cmp 9,d0                         /* CWB: its Kelvin too */
 bne 8f
 mov 107,d0
 call sget,[],4
 add -2000,d0
 mov 100,d1
 ext d0
 div d1,d0
 cmp 0,d0
 bge 71f
 clr d0
71:
 cmp 120,d0
 ble 72f
 mov 120,d0
72:
 add -60,d0
 mov d0,(20,sp)
8:
 mov (12,sp),d2
 add 66,d2                        /* P + 32 + 64 k + 34 */
 mov (24,sp),a2
 mov a2,a0
 add d2,a0
 mov (20,sp),d0
 FWENC
 movbu d0,(a0)
 movbu d1,(1,a0)
 mov (16,sp),d0
 FWENC
 movbu d0,(2,a0)
 movbu d1,(3,a0)
 mov 1,d0
 movbu d0,(DIRTY,a2)
 ret [d2,d3,a2,a3],48
/* fw_apply: `call fw_apply,[d2,d3,a2,a3],32` from fl_set after a change, a2 = P, d0 = k, a0 inner, a1 mode: COLOR k's
 * slot (the new look, put there by fl_sw) -> the camera's WB through the settings manager (as pf_put): Kelvin first
 * for CWB, then the mode; none -> Auto. Locals (4) a0, (8) a1, (12) mode. */
fw_apply:
 mov a0,(4,sp)
 mov a1,(8,sp)
 asl 6,d0
 add 66,d0
 mov a2,a0
 add d0,a0                        /* slot +34 of COLOR k */
 movbu (2,a0),d0
 extb d0
 movbu (3,a0),d1
 extb d1
 FWDEC                            /* mode code */
 clr d2                           /* Auto */
 cmp 1,d0
 blt 1f
 cmp 13,d0
 bge 1f
 mov d0,d1
 asl2 d1
 mov d1,d2
 add d1,d1
 add d2,d1                        /* 12 x code */
 mov 0x615d1944,a1
 add d1,a1
 mov (a1),d2                      /* the mode */
1:
 mov d2,(12,sp)
 cmp 9,d2
 bne 2f
 movbu (a0),d0
 extb d0
 movbu (1,a0),d1
 extb d1
 FWDEC
 add 60,d0
 mov 100,d1
 mul d1,d0
 add 2000,d0
 mov d0,(12,sp)                   /* K in the mode's local (the mode is CWB, 9, here) */
 mov d0,d1
 mov 1632,d0                      /* the stills CWB Kelvin too: OK on CWB in the WB screen loads it into 107 (before:
                                     the camera's old Kelvin came back and the film got a '*') */
 mov (4,sp),a0
 mov (8,sp),a1
 call manager,[d2,d3,a2,a3],68
 mov (12,sp),d1
 mov 107,d0
 mov (4,sp),a0
 mov (8,sp),a1
 call manager,[d2,d3,a2,a3],68
 mov 9,d0
 mov d0,(12,sp)                   /* the mode back */
2:
 mov 1578,d0
 mov (12,sp),d1
 mov (4,sp),a0
 mov (8,sp),a1
 call manager,[d2,d3,a2,a3],68
 ret [d2,d3,a2,a3],32

.section .ext13,"ax"               /* g2: moved to ext13 (the GX4-proven reserve; ext12 is nearly full); v0.28: out of the full ext11 */
 .balign 8
ic_pay:
 .space 18024                     /* v0.25: 14 pictures (build.py checks the fit; A-B blank; v0.28: "Halo" in Frame's place; colour menu test 7: + 256 for the pictures; borders: + 512 for the Border icon in G-M's place); g2: + 872 for the Film Grain icon */
ic_pend:
.section .ext11,"ax"

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
 movhu (a1),d0
 add -HLB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -TBB,d0
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -FRB,d0                      /* borders: the Border bar */
 cmp 4,d0
 bcs 1f
 movhu (a1),d0
 add -GSB,d0                      /* g2: the Film Grain bar */
 cmp 4,d0
 bcs 1f
 clr d0
 mov d0,(a0)
 jmp stp_back
1:
 mov 1,d0
 mov d0,(a0)
 jmp stp_end

/* TONEPG miss: the open editor is on a Shadows / Highlights page (P valid, marker, axis 5 or 6). Uses d3, a2. */
 .macro TONEPG miss
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
/* rd_a / rd_b <- jmp from 0x611d16b4 / 0x611d1725 (the readout glyph lookups, d0 = item): 1011, 5397 (stock) and
 * Blacks / Whites take the 11-entry -5..+5 tables (0x611d16e6 / 0x611d1757), else none (0x611d16ee / 0x611d175f). */
rd_a:
 cmp 5397,d0                      /* v0.28 t2: the wheel's readout on a Shadows / Highlights page: 0..10 */
 bne 5f
 movm [a2],(sp)
 TONEPG 4f                        /* uses d3, a2 (d3: the stock path sets it again) */
 movm (sp),[a2]
 mov rd10_a,a0
 mov 11,d3
 jmp rda_none
4:
 movm (sp),[a2]
 clr d3
5:
 cmp HL_IT,d0                     /* v0.28 h6 Halation 0..5: +-0, then +1..+5 (no -1..-5 entries) */
 beq 51f
 cmp GS_IT,d0                     /* g2: Film Grain 0..5, as Halation */
 beq 51f
 cmp FR_IT,d0                     /* borders: Border 0..5, as Halation */
 bne 6f
51:
 mov rd6_a,a0
 mov 6,d3
 jmp rda_none
6:
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
 cmp TB_IT,d0                     /* v0.28 Tone Balance */
 beq 1f
 cmp 5399,d0                      /* v0.25 Shading: these glyphs, in line with its picture (owner: its number sat low) */
 beq 1f
 jmp rda_none
1:
 jmp rda_11
rd_b:
 cmp 5397,d0                      /* v0.28 t2: the tone pages (as rd_a) */
 bne 5f
 movm [a2],(sp)
 TONEPG 4f
 movm (sp),[a2]
 mov rd10_b,a0
 mov 11,d3
 cmp 5,a1                         /* strength 10 (dial +5): "+10" does not fit the readout's 3 characters (the */
 bne 7f                           /* text at record +2..+7, then its flags): rd10_a gives sign 0 (the caller writes */
 mov mdr,d2                       /* nothing) and we write "10" there, for the wheel readout's caller only */
 cmp 0x611d1433,d2                /* (MDR = its return address; a3 = its record) */
 bne 7f
 mov 49,d2
 movhu d2,(2,a3)
 mov 48,d2
 movhu d2,(4,a3)
 clr d2
 movhu d2,(6,a3)
7:
 jmp rdb_none
4:
 movm (sp),[a2]
 clr d3
5:
 cmp HL_IT,d0                     /* v0.28 h6 Halation (as rd_a) */
 beq 51f
 cmp GS_IT,d0                     /* g2: Film Grain (as rd_a) */
 beq 51f
 cmp FR_IT,d0                     /* borders: Border (as rd_a) */
 bne 6f
51:
 mov rd6_b,a0
 mov 6,d3
 jmp rdb_none
6:
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
 cmp TB_IT,d0                     /* v0.28 Tone Balance */
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
rd10_a:                           /* v0.28 t2 the tone pages: dial -5..+5 -> strength "+-0", "+1" .. "+9", "10" */
 .long -5, 1, -4, 2, -3, 2, -2, 2, -1, 2, 0, 2, 1, 2, 2, 2, 3, 2, 4, 2, 5, 0   /* 10: sign 0, rd_b writes "10" */
rd10_b:
 .long -5, 0, -4, 1, -3, 2, -2, 3, -1, 4, 0, 5, 1, 6, 2, 7, 3, 8, 4, 9, 5, 10
rd6_a:                            /* v0.28 h6 Halation 0..5: "+-0" (sign 1; sign 0 would hide the number: the callers */
 .long 0, 1, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2   /* draw 1 "+-%d", 2 "+%d", 3 "-%d", else nothing), then +1..+5 */
rd6_b:
 .long 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5

/* sl_dot <- jmp from 0x611d10fb (same frame; a2 value, a3 min): the dot's x = centre (d2) + d1, stock value x 155 px
 * (a -2..+2 bar). The Sharp bar (min -5, from sl_rng) is split at 0, which stays on the centre mark: below 0 it steps
 * 62 px (-5 at the left end, like Shading's bar), above 0 the stock 155 px (+2 at the right end). Camera test 2: one
 * step size for the whole bar left +2 short of the end. */
sl_dot:
 mov (8,sp),a0
 mov a2,d1
 cmp 0,a3                         /* v0.28 h6: a 0..5 bar (Halation): 0 at the left end, 5 at the right end, 124 px a */
 bne 4f                           /* step (the -5..+5 bars' ends are -310 / +310 px) */
 mov (4,sp),d0
 cmp 5,d0
 bne 4f
 clr d0                           /* no centre mark: 0 is the left end (block +8 shows it; the setup set it to 1) */
 movbu d0,(8,a0)
 mov 124,d0
 mul d0,d1
 add -310,d1
 jmp dot_back
4:
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
 mov d0,(24,sp)                   /* v0.28 film WB: the look before (the COLOR path no longer needs the value) */
 mov (16,sp),d0
 mov (20,sp),d1
 mov d0,d2
 mov (24,sp),d2
 call fw_keep,[d2,d3,a2,a3],48    /* a change? then the camera's WB into the slot of the COLOR being left */
 movbu d0,(fw_chg)
 mov (16,sp),d2
 mov a2,a0
 add d2,a0
 mov (24,sp),d0
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
 movbu (fw_chg),d0                /* v0.28 film WB: after a change, the new look's WB to the camera */
 cmp 0,d0
 beq 41f
 clr d0
 movbu d0,(fw_chg)
 mov (16,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 call fw_apply,[d2,d3,a2,a3],32
41:
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
 * films load (ub_pfl, HLS task): each row from fl_top (the "FILM" line, rows 0..39) or from the digit pictures fl_dig
 * (rows 40..75; one digit centred at x 40, two at x 31 and 49), then runs of up to 16 pixels (not past the row's end)
 * as OSD type-11 tokens, five to a 64-bit word. Heap: up to 3 blocks of FL_BLK; block 0 starts with 20 slot words
 * and 20 descriptors <6H3I>. P+TTAB = the slot words (0 = none). ic_get answers IC_FM0 + j through fl_ic. */
 .include "films.inc"             /* fl_top (100 x 40), fl_dig (10 x 20 x 36), 4 bits a pixel, low nibble first */
 .include "wheeldef.inc"           /* WLL, XL_W0 (build.py) */

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

/* fl_mk: `call fl_mk,[d2,d3,a2,a3],80` from fl_mk2, a2 = P: the 20 list cells (fl_rc, layout fl_L0) into heap blocks
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
 mov (52,sp),a2
 mov a0,(SATB,a2)
 mov SLS,d0
 mov d0,(a0)
 mov SGS,d0
 mov d0,(4,a0)
 add 8,a0
 mov fl_slab,a1
 mov SAT_AG - 8,d1
 call ub_cpy,[],0                 /* a0 -> the block + SAT_AG */
 mov fl_sagd,a1                   /* #64: "Sat. All [INFO]" sits in .ext13 (no room in this section) */
 mov SAS4,d1
 call ub_cpy,[],0
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
 movbu (ub_ok),d0                 /* a valid block: ub_pfl overwrites the whole image, so no read */
 cmp 0,d0
 bne 95f
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
 mov WLL,d0                       /* #64: the wheel pages' dial labels, into the heap (a picture in flash blanked */
 call malloc,[],4                 /* the camera menu), last: the blocks above matter more. None: wl_blk stays 0 */
 cmp 0,a0                         /* and xb_vl draws the labels */
 beq 99f
 mov a0,d2
 mov wl_tab,a1
 mov WLL,d1
 call ub_cpy,[],0
 mov d2,(wl_blk)
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
 call cv_cap,[d2,d3,a2,a3],20     /* rgb-curves: COLOR k's curves kept with the record */
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
 mov (48,a1),d0                   /* v0.28: a trailing picture ('*') and its gap */
 cmp 0,d0
 beq 7f
 mov (56,a1),d0
 add d0,d1
 mov (60,a1),d0
 add d0,d1
7:
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
20:                               /* v0.28: the trailing picture after the last digit */
 mov (20,sp),a1
 mov (48,a1),d0
 cmp 0,d0
 beq 25f
 mov (16,sp),d0                   /* the last digit */
 cmp 0,d0
 bge 24f
 mov (12,sp),d0
24:
 mov (36,a1),a0
 add d0,a0
 movbu (a0),d1
 mov (48,sp),d0
 add d1,d0
 mov (60,a1),d1
 add d1,d0
 mov d0,d2                        /* its x */
 mov (28,sp),d0
 mov (52,a1),d1
 mul d0,d1
 mov (48,a1),a0
 add d1,a0
 mov (52,a1),d3
 mov sp,a1
 add SROW,a1
 add d2,a1
 call fl_bl,[],0
25:                               /* the row as runs: a1 the pixel, a2 the row's end */
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
 .long 0, 0, 0, 0                 /* v0.28: {trailing picture, its bytes a row, ink width, gap before}: none */
fl_LS1:                           /* v0.28: the quick menu's changed film, "FILM N*" (owner) */
 .long 160, 48, 0x0b09f02f, fl_sfw, SFW / 2, SFWI, fl_sdg, SDB / 2, SDB * SPH / 2, fl_sdw, SP_GAP, SP_DGAP
 .long fl_sst, SSTB / 2, SSTI, SP_DGAP
fl_LVL:                           /* the shooting screen, 96 x 44 (film test 9) */
 .long 96, 44, 0x0b05f02b, fl_lvw, LVWB / 2, LVWI, fl_lvd, LVDB / 2, LVDB * 44 / 2, fl_lvdw, LV_GAP, LV_DGAP
 .long 0, 0, 0, 0
fl_LVL1:                          /* the shooting screen's changed film, "FILM N*" */
 .long 96, 44, 0x0b05f02b, fl_lvw, LVWB / 2, LVWI, fl_lvd, LVDB / 2, LVDB * 44 / 2, fl_lvdw, LV_GAP, LV_DGAP
 .long fl_lvst, LVSTB / 2, LVSTI, LV_SGAP

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
 mov d1,d0
 movm [d2,d3,a2,a3],(sp)
 add -36,sp
 mov d0,(12,sp)
 mov mdr,d0
 mov d0,(8,sp)
 call lv_chk,[],4                 /* #54: no picture while the dial's mode is not the one whose films are in */
 cmp 0,d0
 beq 78f
 mov (8,sp),d0
 mov d0,mdr
 add 36,sp
 movm (sp),[d2,d3,a2,a3]
 mov lv_slot,a0
 retf [],0
78:
 mov (12,sp),d1
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
 mov (24,sp),d0                   /* v0.28: the quick menu's "FILM N*" when the film is changed (as the list's cell) */
 mov fl_LS1,d1
 cmp fl_LS,d0
 beq 40f
 mov fl_LVL1,d1                   /* and the shooting screen's, as its "COLOR1*" */
 cmp fl_LVL,d0
 bne 6f
40:
 mov d1,(4,sp)                    /* the starred layout (fl_fch keeps no d1) */
 mov (20,sp),d0
 call fl_fch,[d2,d3,a2,a3],28
 cmp 0,d0
 beq 6f
 or 0x100,d3                      /* the drawn key: N | star << 8 */
 mov (4,sp),d0
 mov d0,(24,sp)
6:
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
 and 0xff,d0                      /* N (the key may carry the star) */
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
 * 0x900a, which move the colour cursor; the front dial sends them too; CALLS, d0 event, d1 arg, a0 parent): W_SALL, on
 * Saturation with all colours, nothing (that would leave all colours for the hidden single-colour page) -> d0 1. Else
 * on every page but Saturation, a step that lands on all colours (between slices 1 and 12) takes one step more: all
 * colours means nothing there. The dial reaches all colours only from slices 1 and 12, so only 2197 + k says 255. Anything else: registers as at entry, jmp stock. Frame as ed_info: (4) d1, (8) a1,
 * (12) 2197 + k, (16) value, (20) d0, (24) a0. */
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
 .else
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
 beq 8f                           /* Saturation: all colours stay one step of the dial, as stock */
 mov 2,d3                         /* steps left: on all colours, one more */
7:
 mov (24,sp),a0
 mov (20,sp),d0
 mov (4,sp),d1
 mov (8,sp),a1
 calls \stock                     /* keeps d2/d3/a2/a3 */
 mov d0,d2                        /* its result */
 add -1,d3
 beq 9f
 clr d0
 mov d0,(16,sp)                   /* no value read: not all colours */
 call k_cur,[a2],8                /* (16,sp) <- the cursor 2197 + k, 255 = all colours; keeps d2, d3 */
 mov (16,sp),d0
 cmp 255,d0
 beq 7b
9:
 mov d2,d0
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
 * Saturation (W_SONE: one colour, the camera's "Color All [INFO]") our "Saturation [INFO]" (P+SATB), and without W_SALL
 * our "Sat. All [INFO]" in SDESC; else the camera's. */
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
 .elseif !W_SALL                  /* gd_sel puts SDESC back only without W_SALL */
 cmp 0,d0                         /* #64: "Saturation [INFO]" in this descriptor (one colour), "Sat. All [INFO]" */
 bne 8f                           /* in SDESC (all colours, 175 wide as ours) */
 mov (SATB,a2),d1
 cmp 0,d1
 beq 8f
 mov d1,d2
 add SAT_SG,d1
 mov d1,(16,a0)
 mov SGS,d1
 mov d1,(12,a0)
 mov SDESC,a0
 movhu (a0),d1
 cmp 14,d1
 bne 7f
 movhu (2,a0),d1
 cmp SDESC_W,d1
 bne 7f
 movhu (4,a0),d1
 cmp 50,d1
 bne 7f
 mov (16,a0),d1
 cmp SSTOCK_P,d1
 bne 7f                           /* someone else's: leave it */
 add SAT_AG,d2
 mov d2,(16,a0)
 mov SAS,d1
 mov d1,(12,a0)
 mov SAT_GW,d1
 movhu d1,(2,a0)
7:
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
 .if !W_SALL
 mov (SATB,a2),d1                 /* #64: our pictures in either guide (gd_s0) -> the camera's, so gd_set takes the */
 cmp 0,d1                         /* guide as stock again */
 beq 15f
 mov GDESC,a0
 mov (16,a0),d2
 sub d1,d2
 cmp SAT_LEN,d2
 bcc 14f
 mov GSTOCK_S,d2
 mov d2,(12,a0)
 mov GSTOCK_P,d2
 mov d2,(16,a0)
14:
 mov SDESC,a0
 mov (16,a0),d2
 sub d1,d2
 cmp SAT_LEN,d2
 bcc 15f
 mov SSTOCK_S,d2
 mov d2,(12,a0)
 mov SSTOCK_P,d2
 mov d2,(16,a0)
 mov SDESC_W,d2
 movhu d2,(2,a0)
15:
 .endif
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
 mov (4,sp),d0                    /* g2: the Film Grain / Grain Size bars -> gs_def */
 exthu d0
 mov d0,d1
 add -GSB,d1
 cmp 4,d1
 bcs 46f
 add GSB - SZB,d1
 cmp 4,d1
 bcc 47f
46:
 call gs_def,[d2,d3,a2,a3],28
 ret [d2,d3,a2],24
47:
 mov (4,sp),d0                    /* film test 8: our rows (Grain, NR, VigFix, Blacks, Whites, A-B, G-M: base + k) */
 exthu d0
 add -GRB,d0
 blt 90f
 cmp 0x100,d0                     /* v0.25: + GLB (row 10), FRB (row 11); v0.28 HLB (row 13), TBB (14); rows 7..9 (FLB films)
                                     are not ours; 12 (WGB) and 15 (BWB) are the WB and Blacks / Whites grids */
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
 clr d1                           /* (8,sp): one {record, slot} pair, or two (the grids: A-B + G-M, Blacks + Whites) */
 cmp 12,d0
 bne 61f
 mov 5,d0
 mov 6,d1
 bra 62f
61:
 cmp 15,d0
 bne 63f
 mov 3,d0
 mov 4,d1
62:
 mov fl_xr,a0
 add d1,a0
 add d1,a0
 movbu (1,a0),d1
 asl 8,d1
 movbu (a0),d3
 or d3,d1
 asl 16,d1
63:
 mov d1,(8,sp)
 mov fl_xr,a0
 add d0,a0
 add d0,a0
 movbu (1,a0),d1                  /* record offset | slot offset << 8 (bytes: the table is not aligned) */
 asl 8,d1
 movbu (a0),d0
 or d1,d0
 mov (8,sp),d1
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
64:
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
 and 0xff,d1
 add d1,a1
 movbu (a1),d1                    /* now */
 cmp d1,d0
 bne 7b
 mov (8,sp),d0                    /* the second pair, if any */
 lsr 16,d0
 mov d0,(8,sp)
 cmp 0,d0
 bne 64b
 jmp 8b
90:
 mov (4,sp),d0
 jmp ed_isdef
fl_xr:                            /* {record offset, slot offset} of the rows GRB, NRB, VFB, BKB, WHB, ABB, GMB (pf_bt),
                                     three unused (FLB), v0.25 GLB, FRB */
 .byte 51,53, 49,51, 50,52, 39,47, 40,48, 37,26, 38,27, 0,0, 0,0, 0,0, 47,49, 48,50, 0,0, 57,30, 58,33   /* v0.28 HLB, TBB */

/* fl_live: `call fl_live,[d2,d3,a2,a3],24`, a2 = P, d2 = COLOR k holding film j -> d0 1 when COLOR k now differs from
 * film j as built: its 18 settings (fl_isdef) or the slot's WB shift, Blacks / Whites, Extras (pf_bt). */
fl_live:
 call cv_kset,[d2,d3,a2,a3],20    /* rgb-curves: a curve point set on COLOR k counts too */
 cmp 0,d0
 beq 20f
 ret [d2,d3,a2,a3],24
20:
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
 cmp 21,d3                        /* v0.28: all 21 pf_bt pairs (+ split toning, halation, balance, film WB) */
 bcs 22b
 clr d0
 ret [d2,d3,a2,a3],24
28:
 mov 1,d0
 ret [d2,d3,a2,a3],24

/* fl_fch: `call fl_fch,[d2,d3,a2,a3],28`, a2 = P, d0 = film j -> d0 1 when it is changed from how it was built: on
 * its COLOR now (look number = its) -> fl_live; else its saved changes (EDITS.BIN record j, valid) differ from the
 * LOOKS.BIN record in bytes 0..62 (v0.28; was 0..52). Locals (4) j. */
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
 mov (4,sp),d0                    /* rgb-curves: its saved curves count too */
 call cv_jset,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 7f
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
 mov 63,d3                        /* v0.28: bytes 0..62 (+ split toning, halation, balance, film WB) */
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

/* #75: a touch re-arms the open screen's idle timer through shared code (0x612a8db3), with the screen's own id and
 * time. Only Picture Mode's touch layout gives id 500 at 8000 ms. In Picture Mode (GUI state 0x0418) it gets 30000 ms, as Picture Mode's own arms. */
.section .hook_tch,"ax"
 call s_tch,[d2,d3],12            /* stock 0x612a8db3: call 0x612970e8,[d2,d3],12 (d0 timer id, d1 ms) */

.section .ext11,"ax"
s_tch:                            /* the timer start's frame; d2 / d3 are saved by it */
 cmp 500,d0
 bne 9f
 cmp 8000,d1
 bne 9f
 mov a0,d2
 mov (0x603713a4),a0              /* the GUI state's two bytes {parent, child}, as fl_pm */
 cmp 0,a0
 beq 8f
 movbu (a0),d3
 cmp 4,d3
 bne 8f
 movbu (1,a0),d3
 cmp 0x18,d3
 bne 8f
 mov 30000,d1
8:
 mov d2,a0
9:
 jmp TMR_ARM

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

/* ---- better grain g1 (2026-11-15, feature/better-grain): our own grain tile, in colour, for the fast route.
 * The texture builder 0x604cf0b9 (TXGET's cache miss) loads the camera's grain tile (resource 0x8001: 1536 x 1536,
 * format 0x0c04 = grey) into a fresh buffer and lets the image processor repeat it over the whole texture.
 * While the code block's xb_tex asks for our texture (tg_own = size 1..5), two call sites in the builder are ours:
 * 0x604cf156 (the tile's size: ours is 1536 x 1536 in 0x0c02, YCbYCr, 3072 B a row, and the source format becomes
 * 0x0c02) and 0x604cf1a4 (the load: tg_fill writes our tile into the buffer instead). Grainy Film's own texture and
 * every other caller are untouched (tg_own 0 -> the stock calls). research/NOTES.md "Better grain g1". */
 .set TG_BYTES, 1536 * 1536 * 2   /* our tile: 1536 x 1536, 0x0c02 */
 .set TG_YM, 48                   /* our tile's Y mid level (the blend adds texture Y as it is: rc1 / rc2a) */
 .set USCLK, 0x98900284           /* the us counter (grain diagnostics gd1-gd4) */
.section .hook_trs,"ax"
 call tr_sz,[d2,d3,a2],16         /* stock 0x604cf156: call 0x601d7546,[d2,d3,a2],16 (the tile's size) */

.section .hook_trl,"ax"
 jmp tr_ld                        /* stock 0x604cf1a4: call 0x604ce6c9,[d2,d3,a2,a3],24 (load the tile) */

.section .ext12,"ax"
tr_sz:                            /* 0x601d7546's frame: the builder's (k,sp) = (16 + k,sp) */
 movbu (tg_own),d2
 cmp 0,d2
 beq 9f
 mov 0x0c02,d2
 movhu d2,(120,sp)                /* the builder's (104,sp): the source's format (0x0c04 grey -> 0x0c02 colour) */
 mov TG_BYTES,d0
 ret [d2,d3,a2],16
9:
 jmp RES_SZ

tr_ld:
 call tr_ld2,[d2,d3,a2,a3],24
 jmp TLD_BACK
tr_ld2:                           /* 0x604ce6c9's frame: the builder's (4,sp) / (8,sp) = (28,sp) / (32,sp), the
                                     buffer's bus address (lo / hi); returns it in d0 / d1 as the stock load does */
 movbu (tg_own),d2
 cmp 0,d2
 bne 1f
 jmp RES_LD
1:
 mov (28,sp),d0
 mov (32,sp),d1
 cmp 0,d1
 bne 2f
 call tg_fill,[d2,d3,a2,a3],104
 bra 3f
2:
 mov 1,d0
 movbu d0,(tg_bad)
3:
 mov (28,sp),d0
 mov (32,sp),d1
 ret [d2,d3,a2,a3],24

/* tg_fill: `call tg_fill,[d2,d3,a2,a3],104`, d0 = the tile buffer's 32-bit bus address. Our tile: Y = 48 + noise
 * (sigma 16), Cb / Cr = 128 + noise (sigma 16), each a w x w box of uniform random bytes (w = tg_own for Y, (w + 1) / 2
 * for Cb / Cr, which are half width and here also half height), seamless: rows repeat every 768 (row y + 768 = row
 * y), columns every 1536. The box sums: column sums C (one per pixel, kept from row to row: + the row entering,
 * - the row leaving, both made again from their own seed, tg_seed) and a running sum along the row (tg_row). Rows go
 * to the buffer through the bus window (hl_open; tg_put). tg_bad = 1 when anything fails (the code block then gives
 * the texture no weight: no grain rather than a wrong one). Time (1/1024 s units, about ms) -> tg_ms, count tg_n.
 * Locals: (0) call slot, (4) bus, (8) work (malloc), (12) R row (cached), (16) CY, (20) CB, (24) CR (cached),
 * (28) y, (32) w, (36) wc, (40) start, (44) failed; (48) Y params, (64) chroma params (tg_row: N, w, K, add),
 * (80) counter, (84) a seed. */
 .set TG_ROWB, 3072
 .set TG_WORK, 3072 + 2 * (1536 + 8) + 4 * (768 + 8)
 .set TG_CYB, 2 * (1536 + 8)
 .set TG_CBB, 2 * (768 + 8)
 .set TG_SUMW, (TG_WORK - TG_ROWB) / 4
 .set TG_HALF, 768 * TG_ROWB
 .set TG_YADD, (TG_YM << 16) + 32768
 .set TG_CADD, (128 << 16) + 32768
tg_fill:
 mov d0,(4,sp)
 clr d0
 mov d0,(8,sp)
 mov d0,(28,sp)
 mov d0,(44,sp)
 movbu d0,(tg_bad)
 mov (USCLK),d0
 mov d0,(40,sp)
 mov (tg_n),d1
 xor d1,d0
 mov 0x9e3779b9,d1
 mul d1,d0
 mov d0,(tg_sb)
 movbu (tg_own),d0
 cmp 6,d0
 bcs 1f
 mov 5,d0
1:
 cmp 0,d0
 bne 1f
 mov 1,d0
1:
 mov d0,(32,sp)
 movbu d0,(tg_w)
 inc d0
 lsr 1,d0
 mov d0,(36,sp)
 mov sp,a2                        /* Y params: N 1536, w, K = 14189 / w (sigma 16 from w^2 bytes of sigma 73.9),
                                     add = (48 << 16) + 32768 - 127.5 w^2 K */
 add 48,a2
 mov (32,sp),d0
 call tg_par,[d2,d3],12
 mov 1536,d0
 mov d0,(a2)
 mov (12,a2),d1
 add TG_YADD,d1
 mov d1,(12,a2)
 mov sp,a2                        /* chroma params: N 768, wc, its K, add = (128 << 16) + 32768 - 127.5 wc^2 K */
 add 64,a2
 mov (36,sp),d0
 call tg_par,[d2,d3],12
 mov 768,d0
 mov d0,(a2)
 mov (12,a2),d1
 add TG_CADD,d1
 mov d1,(12,a2)

 mov TG_WORK,d0
 call malloc,[],4
 cmp 0,a0
 beq 90f
 mov a0,(8,sp)
 call FLUSH,[d2,d3],16            /* no stale lines for the work buffer's cached alias */
 mov (8,sp),d0
 cmp 0xa0000000,d0
 bcs 1f
 cmp 0xb8000000,d0
 bcc 1f
 add -0x40000000,d0
1:
 mov d0,(12,sp)                   /* R: the row, 3072 B */
 add TG_ROWB,d0
 mov d0,(16,sp)                   /* CY: 1536 + 8 halfwords */
 add TG_CYB,d0
 mov d0,(20,sp)                   /* CB: 768 + 8 */
 add TG_CBB,d0
 mov d0,(24,sp)                   /* CR: 768 + 8 */
 mov (16,sp),a0                   /* the sums start at 0 */
 mov TG_SUMW,d1
 clr d0
2:
 mov d0,(a0)
 inc4 a0
 add -1,d1
 bne 2b
 clr d0                           /* the first w rows into CY */
 mov d0,(80,sp)
3:
 mov (80,sp),d0
 clr d1
 call tg_seed,[],0
 mov d0,d2
 clr d3
 mov (16,sp),a0
 mov 1536,d1
 call tg_col,[d2,d3,a2,a3],16
 mov (80,sp),d0
 inc d0
 mov d0,(80,sp)
 mov (32,sp),d1
 cmp d1,d0
 bcs 3b
 clr d0                           /* the first wc chroma rows into CB and CR */
 mov d0,(80,sp)
4:
 mov (80,sp),d0
 mov 1,d1
 call tg_seed,[],0
 mov d0,d2
 clr d3
 mov (20,sp),a0
 mov 768,d1
 call tg_col,[d2,d3,a2,a3],16
 mov (80,sp),d0
 mov 2,d1
 call tg_seed,[],0
 mov d0,d2
 clr d3
 mov (24,sp),a0
 mov 768,d1
 call tg_col,[d2,d3,a2,a3],16
 mov (80,sp),d0
 inc d0
 mov d0,(80,sp)
 mov (36,sp),d1
 cmp d1,d0
 bcs 4b

10:                               /* row y = 0 .. 767 */
 mov (28,sp),d0
 btst 1,d0
 bne 20f
 mov (20,sp),a0                   /* even y: Cb / Cr from chroma row y / 2 (odd y keeps them) */
 mov (12,sp),a1
 add 1,a1
 mov sp,a2
 add 64,a2
 call tg_row,[d2,d3,a2,a3],16
 mov (24,sp),a0
 mov (12,sp),a1
 add 3,a1
 mov sp,a2
 add 64,a2
 call tg_row,[d2,d3,a2,a3],16
 mov 1,d0
 mov d0,(80,sp)
11:                               /* Cb (1), Cr (2): + chroma row (y / 2 + wc) mod 384, - chroma row y / 2 */
 mov (28,sp),d0
 lsr 1,d0
 mov (36,sp),d1
 add d1,d0
 cmp 384,d0
 bcs 12f
 add -384,d0
12:
 mov (80,sp),d1
 call tg_seed,[],0
 mov d0,(84,sp)
 mov (28,sp),d0
 lsr 1,d0
 mov (80,sp),d1
 call tg_seed,[],0
 mov d0,d3
 mov (84,sp),d2
 mov (20,sp),a0
 mov (80,sp),d0
 cmp 1,d0
 beq 13f
 mov (24,sp),a0
13:
 mov 768,d1
 call tg_col,[d2,d3,a2,a3],16
 mov (80,sp),d0
 inc d0
 mov d0,(80,sp)
 cmp 3,d0
 bcs 11b
20:
 mov (16,sp),a0                   /* Y of row y */
 mov (12,sp),a1
 mov sp,a2
 add 48,a2
 call tg_row,[d2,d3,a2,a3],16
 mov (28,sp),d0                   /* + row (y + w) mod 768, - row y */
 mov (32,sp),d1
 add d1,d0
 cmp 768,d0
 bcs 21f
 add -768,d0
21:
 clr d1
 call tg_seed,[],0
 mov d0,(84,sp)
 mov (28,sp),d0
 clr d1
 call tg_seed,[],0
 mov d0,d3
 mov (84,sp),d2
 mov (16,sp),a0
 mov 1536,d1
 call tg_col,[d2,d3,a2,a3],16
 mov (28,sp),d0                   /* the row to tile rows y and y + 768 */
 mov TG_ROWB,d1
 mul d1,d0
 mov (4,sp),d1
 add d1,d0
 mov d0,d2
 mov (12,sp),a0
 mov TG_ROWB,d1
 call tg_put,[d2,d3,a2,a3],40
 cmp 0,d0
 bne 80f
 mov d2,d0
 add TG_HALF,d0
 mov (12,sp),a0
 mov TG_ROWB,d1
 call tg_put,[d2,d3,a2,a3],40
 cmp 0,d0
 bne 80f
 mov (28,sp),d0
 inc d0
 mov d0,(28,sp)
 cmp 768,d0
 bcs 10b
 bra 85f
80:
 mov 1,d0
 mov d0,(44,sp)
85:
 call FLUSH,[d2,d3],16            /* the work buffer's lines out of the cache before it goes back */
 mov (8,sp),a0
 call free,[],4
 mov (44,sp),d0
 cmp 0,d0
 bne 90f
 mov (40,sp),d0                   /* g1b: the start; 0x98900284 counts DOWN (NOTES, timing 2026-11-14), so the time */
 mov (USCLK),d1                   /* is start - end (g1 logged end - start: 2^22 - 380 on the camera, 2026-11-16) */
 sub d1,d0
 and 0x7fffffff,d0                /* a 31-bit counter (the firmware's clock = 0x7fffffff - it) */
 lsr 4,d0
 mov 1049,d1
 mul d1,d0                        /* (us / 16) x 1049 / 65536 = us / 999.6: milliseconds (to 65 s) */
 lsr 16,d0
 mov d0,(tg_ms)
 mov (tg_n),d0
 inc d0
 mov d0,(tg_n)
 ret [d2,d3,a2,a3],104
90:
 mov 1,d0
 movbu d0,(tg_bad)
 mov (tg_nb),d0
 inc d0
 mov d0,(tg_nb)
 ret [d2,d3,a2,a3],104

/* tg_par: `call tg_par,[d2,d3],12`, d0 = box width w (1..5), a2 = params -> +4 w, +8 K = 14189 / w,
 * +12 = -(127.5 w^2 K) (the caller adds its base and the rounding). */
tg_par:
 mov d0,(4,a2)
 mov d0,d2
 add -1,d0
 asl2 d0
 mov tg_kt,a0
 add d0,a0
 mov (a0),d0
 mov d0,(8,a2)
 mov d2,d1
 mul d2,d1                        /* w^2 */
 mul d0,d1                        /* w^2 K */
 mov 255,d0
 mul d0,d1
 asr 1,d1                         /* 127.5 w^2 K */
 clr d0
 sub d1,d0
 mov d0,(12,a2)
 ret [d2,d3],12

/* tg_seed: `call tg_seed,[],0`, d0 = row, d1 = channel (0 Y, 1 Cb, 2 Cr) -> d0 = that row's stream seed, never 0
 * (a 0 stream stays 0: tg_col's "no row leaving"). Uses d0, d1 and MDR (so `ret`, not `retf`). */
tg_seed:
 asl 28,d1
 xor d1,d0
 mov 0x9e3779b9,d1
 mul d1,d0
 mov (tg_sb),d1
 xor d1,d0
 mov d0,d1
 lsr 16,d1
 xor d1,d0
 mov 0x7feb352d,d1
 mul d1,d0
 mov d0,d1
 lsr 15,d1
 xor d1,d0
 mov 0x846ca68b,d1
 mul d1,d0
 mov d0,d1
 lsr 16,d1
 xor d1,d0
 cmp 0,d0
 bne 1f
 mov 1,d0
1:
 ret [],0

/* tg_col: `call tg_col,[d2,d3,a2,a3],16`, a0 = sums (halfwords), d1 = N (a multiple of 4), d2 = the entering row's
 * stream, d3 = the leaving row's (0: none). sums[x] += byte_in(x) - byte_out(x); bytes = xorshift32 words, low byte
 * first. */
tg_col:
 add d1,d1
 mov a0,d0
 add d0,d1
 mov d1,a1                        /* the end */
1:
 mov d2,d0
 asl 13,d0
 xor d0,d2
 mov d2,d0
 lsr 17,d0
 xor d0,d2
 mov d2,d0
 asl 5,d0
 xor d0,d2
 mov d3,d0
 asl 13,d0
 xor d0,d3
 mov d3,d0
 lsr 17,d0
 xor d0,d3
 mov d3,d0
 asl 5,d0
 xor d0,d3
 mov d2,d0
 extbu d0
 mov d3,d1
 extbu d1
 sub d1,d0
 movhu (a0),d1
 add d0,d1
 movhu d1,(a0)
 mov d2,d0
 lsr 8,d0
 extbu d0
 mov d3,d1
 lsr 8,d1
 extbu d1
 sub d1,d0
 movhu (2,a0),d1
 add d0,d1
 movhu d1,(2,a0)
 mov d2,d0
 lsr 16,d0
 extbu d0
 mov d3,d1
 lsr 16,d1
 extbu d1
 sub d1,d0
 movhu (4,a0),d1
 add d0,d1
 movhu d1,(4,a0)
 mov d2,d0
 lsr 24,d0
 mov d3,d1
 lsr 24,d1
 sub d1,d0
 movhu (6,a0),d1
 add d0,d1
 movhu d1,(6,a0)
 add 8,a0
 cmp a1,a0
 bcs 1b
 ret [d2,d3,a2,a3],16

/* tg_row: `call tg_row,[d2,d3,a2,a3],16`, a0 = sums (N + 8 halfwords), a1 = the first output byte, a2 = params
 * {N, w, K, add}: out[x] = clamp((K * (sums[x] + .. + sums[x + w - 1]) + add) >> 16) for x < N (wrapping round:
 * sums[N + i] = sums[i] first), every 2nd byte for N = 1536 (Y), every 4th for N = 768 (Cb / Cr). */
tg_row:
 mov (0,a2),d0
 add d0,d0
 mov a0,a3
 add d0,a3                        /* &sums[N] */
 mov (4,a2),d1
 clr d2
1:
 movhu (d2,a0),d0
 movhu d0,(d2,a3)
 add 2,d2
 add -1,d1
 bne 1b
 clr d2                           /* s = sums[0] + .. + sums[w - 1] */
 mov (4,a2),d1
 mov a0,a3
2:
 movhu (a3),d0
 add d0,d2
 add 2,a3
 add -1,d1
 bne 2b
 mov (8,a2),d3                    /* K */
 mov (0,a2),d1
 cmp 1536,d1
 bne 30f
 add d1,d1
 mov a0,d0
 add d0,d1                        /* the end of the sums */
 mov (12,a2),a2                   /* add */
3:
 mov d2,d0
 mul d3,d0
 add a2,d0
 asr 16,d0
 cmp 0,d0
 bge 4f
 clr d0
4:
 cmp 255,d0
 ble 5f
 mov 255,d0
5:
 movbu d0,(a1)
 add 2,a1
 movhu (a3),d0
 add d0,d2
 movhu (a0),d0
 sub d0,d2
 add 2,a0
 add 2,a3
 mov a0,d0
 cmp d1,d0
 bcs 3b
 ret [d2,d3,a2,a3],16
30:
 add d1,d1
 mov a0,d0
 add d0,d1
 mov (12,a2),a2
31:
 mov d2,d0
 mul d3,d0
 add a2,d0
 asr 16,d0
 cmp 0,d0
 bge 32f
 clr d0
32:
 cmp 255,d0
 ble 33f
 mov 255,d0
33:
 movbu d0,(a1)
 add 4,a1
 movhu (a3),d0
 add d0,d2
 movhu (a0),d0
 sub d0,d2
 add 2,a0
 add 2,a3
 mov a0,d0
 cmp d1,d0
 bcs 31b
 ret [d2,d3,a2,a3],16

/* tg_put: `call tg_put,[d2,d3,a2,a3],40`, d0 = bus address, a0 = source (cached), d1 = bytes (a multiple of 4)
 * -> d0 = 0 written / 1 not. Through hl_open (the firmware's lock and this CPU's bus window), the window's cached
 * view and FLUSH, as halation; pieces split at the window's 128 MB edges. Locals: (4) bus, (8) source, (12) left,
 * (16) token, (20) this piece. */
tg_put:
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov d1,(12,sp)
1:
 mov (12,sp),d0
 cmp 0,d0
 beq 8f
 mov (4,sp),d1
 and 0x07ffffff,d1
 mov 0x08000000,d2
 sub d1,d2                        /* room before the edge */
 cmp d0,d2
 bls 2f
 mov d0,d2
2:
 mov d2,(20,sp)
 mov (4,sp),d0
 mov d2,d1
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(16,sp)
 cmp 0,a0
 beq 7f
 clr d3
 mov a0,d0
 cmp 0xb8000000,d0
 bcs 3f
 add -0x40000000,d0               /* the window's cached view */
 mov d0,a0
 mov 1,d3
3:
 mov (8,sp),a1
 mov (20,sp),d1
 lsr 2,d1
4:
 mov (a1),d0
 inc4 a1
 mov d0,(a0)
 inc4 a0
 add -1,d1
 bne 4b
 cmp 0,d3
 beq 5f
 call FLUSH,[d2,d3],16
5:
 mov (16,sp),d0
 call UNLOCK,[d2],8
 mov (20,sp),d0
 mov (4,sp),d1
 add d0,d1
 mov d1,(4,sp)
 mov (8,sp),d1
 add d0,d1
 mov d1,(8,sp)
 mov (12,sp),d1
 sub d0,d1
 mov d1,(12,sp)
 bra 1b
7:
 mov (16,sp),d0
 call UNLOCK,[d2],8
 mov 1,d0
 ret [d2,d3,a2,a3],40
8:
 clr d0
 ret [d2,d3,a2,a3],40

 .balign 4
tg_kt:                            /* K by box width 1..5: 16 / (73.9 w) x 65536 */
 .long 14189, 7094, 4730, 3547, 2838
tg_sb:                            /* this tile's seed */
 .long 0
tg_n:                             /* tiles made this power-on */
 .long 0
tg_nb:                            /* tiles that failed */
 .long 0
tg_ms:                            /* the last tile's time in ms (g1b; g1 logged end - start >> 10, wrong way round) */
 .long 0
tg_own:                           /* set by the code block's xb_tex around TXGET: our tile's size 1..5, 0 = stock */
 .byte 0
tg_bad:                           /* 1: the last tile was not written (the code block gives the texture no weight) */
 .byte 0
tg_w:                             /* the last tile's size */
 .byte 0
 .balign 4
tg_l1:
 .asciz "\r\nGrain tiles (better grain g2): made "
tg_l2:
 .asciz ", failed "
tg_l3:
 .asciz ", last size "
tg_l4:
 .asciz ", last time (ms) "
 .balign 4

/* ------------------------------------------------------------------ better grain g2: the Film Grain and Grain Size rows
 * Owner (2026-11-15, the mockup): Film Grain a slider Off, 1..5 (replacing Off / Low / Med / High) and a Grain Size row
 * Fine / Medium / Coarse under it; films saved with Low / Med / High become 2 / 3 / 5. Per COLOR k and so per film:
 * - slot +53 (record +51) = the old level 0 Off, 1 Low, 2 Med, 3 High, kept in step (gs_lv): older firmware, the CPU
 *   grain, LookLab and the photo code read it as before, and BUNDLES / EDITS stay in their ranges for going back;
 * - G = the curves record's spare byte (rgbcurves.inc: a slot's 8 kept bytes, the last one zero until now), live[k]
 *   +25 in cv_ram: it goes wherever COLOR k's curves go (EDITS records ed[r], the per-mode sets, the record in M), and
 *   firmware up to v0.30.3 copies it along without reading it. G = 0: the strength from the level (gs_dv: Low 2, Med 3,
 *   High 5) and Medium; else 0x80 | size << 3 | strength. gs_wr writes 0 whenever the level gives the same, so a film
 *   as built has G = 0 (and its '*' counts G != 0 as a change: ck_kset / ck_jset). */
gs_lv:                            /* strength 0..5 -> level */
 .byte 0, 1, 1, 2, 3, 3
gs_dv:                            /* level 0..3 -> strength */
 .byte 0, 2, 3, 5
 .balign 2

/* gs_ga: `call gs_ga,[d2,d3,a2],16`, a1 = a slot (P + 32 + 64k) -> a0 = &G (cv_ram live[k] +25), or 0 when there is
 * no settings block or a1 is not COLOR k's slot. Uses d0, d1, a0. */
gs_ga:
 mov 0,a0
 PVAL 9f
 mov a1,d0
 sub a2,d0
 add -32,d0
 cmp 256,d0
 bcc 9f
 btst 63,d0
 bne 9f
 lsr 6,d0                         /* k */
 mov d0,d1
 asl 4,d1
 mov d0,d2
 asl 3,d2
 add d2,d1
 add d0,d1
 add d0,d1                        /* 26 k (CV_ESZ) */
 mov cv_ram + CV_LV + 25,a0
 add d1,a0
9:
 ret [d2,d3,a2],16

/* gs_eff: `call gs_eff,[d2,d3,a2],16`, a0 = COLOR k's slot -> d0 strength 0..5 (0: the level is Off), d1 size 0 Fine,
 * 1 Medium, 2 Coarse. Uses a0, a1 (keeps a3). Also the code block's xb_tex (GS_EFF). */
gs_eff:
 mov a0,a1
 call gs_ga,[d2,d3,a2],16
 movbu (53,a1),d2                 /* the level */
 mov 1,d1                         /* Medium */
 clr d3                           /* G */
 cmp 0,a0
 beq 2f
 movbu (a0),d3
 btst 0x80,d3
 bne 1f
 clr d3
 bra 2f
1:
 mov d3,d1
 lsr 3,d1
 and 3,d1
 cmp 3,d1
 bcs 2f
 mov 1,d1
2:
 clr d0
 cmp 0,d2
 beq 9f                           /* Off */
 mov d3,d0
 and 7,d0
 cmp 0,d0
 beq 3f
 cmp 6,d0
 bcs 9f                           /* G's strength 1..5 */
3:
 cmp 4,d2                         /* else the level's: Low 2, Med 3, High 5 (an older 4 / 5: 5) */
 bcs 4f
 mov 3,d2
4:
 mov gs_dv,a0
 add d2,a0
 movbu (a0),d0
9:
 ret [d2,d3,a2],16

/* gs_wr: `call gs_wr,[d2,d3,a2],16`, a0 = COLOR k's slot, d0 strength 0..5, d1 size 0..2 (the callers check them):
 * slot +53 <- its level; G <- 0 when the level gives the same strength and the size is Medium, else 0x80 | size << 3 |
 * strength. Uses d0, d1, a0, a1. */
gs_wr:
 mov a0,a1
 mov d0,d2
 mov d1,d3
 mov gs_lv,a0
 add d2,a0
 movbu (a0),d0
 movbu d0,(53,a1)
 mov gs_dv,a0
 add d0,a0
 movbu (a0),d0
 clr d1
 cmp d2,d0
 bne 1f
 cmp 1,d3
 beq 2f
1:
 mov d3,d1
 asl 3,d1
 or d2,d1
 or 0x80,d1
2:
 mov d1,d3
 call gs_ga,[d2,d3,a2],16
 cmp 0,a0
 beq 9f
 movbu d3,(a0)
9:
 ret [d2,d3,a2],16

/* gs_row: `call gs_row,[d2,d3,a2,a3],40` from sl_set0, a3 class 15 (Film Grain 0..5) / 16 (Grain Size 0..2), d1 the
 * new value, d2 = P + 64k -> d1 0 stored, 1 out of range. Keeps d0, a0, a1 (s_dirty reads them) and a2. Locals (4) d0,
 * (8) a0, (12) a1, (16) the value, (20) the slot. */
gs_row:
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 mov d1,(16,sp)
 add 32,d2
 mov d2,(20,sp)
 mov d2,a0
 call gs_eff,[d2,d3,a2],16        /* d0 strength, d1 size now */
 cmp 15,a3
 bne 2f
 mov (16,sp),d0
 cmp 6,d0
 bcc 8f
 bra 3f
2:
 mov (16,sp),d1
 cmp 3,d1
 bcc 8f
3:
 mov (20,sp),a0
 call gs_wr,[d2,d3,a2],16
 clr d1
 bra 9f
8:
 mov 1,d1
9:
 mov (4,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 ret [d2,d3,a2,a3],40

/* gs_def: `call gs_def,[d2,d3,a2,a3],28` (fl_isdef: the row's '*' and Reset guide), d0 = GSB + k or SZB + k, a2 = P
 * -> d0 1 when the row is as built: Film Grain = its film's level as a strength (no film there: Off), Grain Size =
 * Medium; else 0. Locals (4) 0 Film Grain / 1 Grain Size, (8) k, (12) strength now. */
gs_def:
 exthu d0
 clr d1
 add -GSB,d0
 cmp 4,d0
 bcs 1f
 add GSB - SZB,d0
 mov 1,d1
1:
 mov d1,(4,sp)
 mov d0,(8,sp)
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0
 call gs_eff,[d2,d3,a2],16
 mov d0,(12,sp)
 mov (4,sp),d0
 cmp 0,d0
 beq 3f
 clr d0                           /* Grain Size: Medium */
 cmp 1,d1
 bne 9f
 mov 1,d0
 bra 9f
3:
 mov (8,sp),d2
 call fl_film,[],0                /* d0 = film j, or -1 */
 clr d1                           /* no film: Off */
 cmp 0,d0
 blt 5f
 mov d0,d3
 mov (LPTR,a2),a0
 call fl_has,[],0
 clr d1
 cmp 0,d0
 beq 5f
 mov (LPTR,a2),a0
 mov d3,d0
 asl 6,d0
 add d0,a0
 movbu (32 + 51,a0),d1            /* the film's level as built (its LOOKS record +51) */
 cmp 4,d1
 bcs 4f
 mov 3,d1
4:
 mov gs_dv,a0
 add d1,a0
 movbu (a0),d1
5:
 mov (12,sp),d2
 clr d0
 cmp d1,d2
 bne 9f
 mov 1,d0
9:
 ret [d2,d3,a2,a3],28

/* gs_zk: `call gs_zk,[d2],8`, d0 = k: COLOR k's G <- 0 (e_rst, the whole-profile reset: the level is 0 by then). */
gs_zk:
 mov d0,d1
 asl 4,d1
 mov d0,d2
 asl 3,d2
 add d2,d1
 add d0,d1
 add d0,d1
 mov cv_ram + CV_LV + 25,a0
 add d1,a0
 clr d0
 movbu d0,(a0)
 ret [d2],8
 .balign 4

/* ------------------------------------------------------------------ split toning (v0.26)
 * research/NOTES.md "Split toning": the RGB gamma stage (0x60516ad9) copies the picture-mode curve into the job three
 * times (O+1252 R / +1892 G / +2532 B: 256 x u16 12-bit + 64 x u16 fine table, 640 B each) before the stage list that
 * holds our tone hook. st_run runs at tone's exit (same context C in d3, all registers as at the hook) and bends each
 * channel: t' = t + ((Ks ws + Kh wh) >> 9), ws = (u s >> 12) s >> 12, wh = (u u >> 12) s >> 12, s = 4095 - u
 * (research/splittone/model.py), clamped 0..4095 and kept rising (running max, the 256 and the 64 entries apart).
 * v0.28: u = t moved by the Tone Balance b (slot +33, -5..+5): the hand-over point c = 2048 - 256 b, u = t 2048 / c
 * below c, 2048 + (t - c) 2047 / (4095 - c) above (b = 0: u = t); + = the highlight colour covers more.
 * K = st_k[colour] x strength: the effective COLOR's slot +55 / +56 (Shadows colour 0..11, strength) and +57 / +58
 * (Highlights). v0.28 t2: strength s 0..10 in half the v0.26 step (>> 9; 10 = v0.26's 5), stored as a code -5..5
 * (v >= 0: s = 2v, so v0.26 values keep their strength; v < 0: s = -2v - 1), inside every firmware's range checks.
 * Camera-proven with fixed values (probe st1). Gates: COLOR still
 * (key 11, or 12 with +1731 0, as tone); P valid; a strength set; R, G and B tables identical before (stock COLOR
 * copies one curve three times: a repeated pass never bends twice and art curves are left alone).
 * Frame: (0) getter return, (4..28) registers, (32..52) Ks R G B, Kh R G B (st_all reads them, keep in sync), (56)
 * strengths / curves mask, (64) d0, v0.28 (76) c, (80) f1 = 2^27 / c, (84) f2 = 2047 << 16 / (4095 - c),
 * rgb-curves (96) k, then the COLOR's curved channels (rgbcurves.inc:
 * each entry also gets its channel's curve delta D(t); a COLOR with curves and no split toning runs with K = 0).
 * Stores: own stack frame, O+1252..O+3171, cv_pb / cv_pp. */
.section .ext11,"ax"
/* s_lv6: s_lv's body. #68: no Glow / Art Effect flags in video or S&Q (recording, its live view), as mx_photo. */
s_lv6:
 call mx_photo,[],0
 cmp 0,d0
 beq 9f
 call xp,[],0
 beq 9f
 add 16,a1
 jmp (a1)
9:
 jmp lv_skip                      /* 0x6046b94f */

/* slot_any: `call slot_any,[d2,d3,a2],16`, d1 want << 8 | mask, a0 byte offset in the block -> d0 1 when P is valid
 * and some COLOR slot k (0..3) has (P + a0 + 64k) & mask == want, else 0. Uses d0, d1. Used by wb_get and hl_pp, each
 * behind a SEC_READY gate right before the call (d0 is the gate's register, so the arguments are in d1 and a0). */
slot_any:
 mov d1,d0
 lsr 8,d0                         /* want */
 extbu d1                         /* mask */
 PVAL 9f
 add a0,a2
 mov 4,d2
1:
 movbu (a2),d3
 and d1,d3
 cmp d0,d3
 beq 2f
 add 64,a2
 add -1,d2
 bne 1b
9:
 clr d0
 ret [d2,d3,a2],16
2:
 mov 1,d0
 ret [d2,d3,a2],16

st_run:
 add -100,sp
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
 call mx_photo,[],0               /* #68: photo modes only; video (recording, its live view) stays stock */
 cmp 0,d0
 beq s9
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
 bne 13f
 call cv_any,[d2],8               /* rgb-curves: or a curve point set on any COLOR */
 cmp 0,d0
 beq s9
13:
 mov a2,(52,sp)                   /* P (the Kh B slot is written later) */
 mov 63153,d0                     /* effective COLOR profile number */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12           /* keeps a2/a3 */
 mov (52,sp),a2
 add -1,d0
 cmp 4,d0
 bcc s9
 mov d0,(96,sp)                   /* rgb-curves: k */
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
 cmp 0,d1                         /* v0.28 t2: the stored code -5..5 -> strength s 0..10 (v >= 0: 2v, so a v0.26 */
 bge 31f                          /* value keeps its strength; v < 0: -2v - 1, the odd steps) */
 not d1
 add d1,d1
 inc d1
 bra 35f
31:
 add d1,d1
35:
 cmp 10,d1
 ble 32f
 mov 10,d1
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
 mov d2,(56,sp)                   /* rgb-curves: COLOR k's curves (blocks, cv_pp), as a mask */
 mov (96,sp),d0
 call cv_set,[d2,d3,a2,a3],20
 mov d0,(96,sp)
 mov (56,sp),d2
 or d0,d2
 cmp 0,d2
 beq s9                           /* both strengths 0 and no curve */
 movbu (65,a2),d1                 /* v0.28 Tone Balance b (slot +33), -5..+5 */
 extb d1
 cmp -5,d1
 bge 33f
 mov -5,d1
33:
 cmp 5,d1
 ble 34f
 mov 5,d1
34:
 asl 8,d1
 mov 2048,d0
 sub d1,d0                        /* c = 2048 - 256 b: 768..3328 */
 mov d0,(76,sp)
 mov d0,d1
 mov 134217728,d0                 /* f1 = 2048 << 16 / c */
 ext d0
 div d1,d0
 mov d0,(80,sp)
 mov 4095,d1
 mov (76,sp),d0
 sub d0,d1                        /* 4095 - c */
 mov 134152192,d0                 /* f2 = 2047 << 16 / (4095 - c) */
 ext d0
 div d1,d0
 mov d0,(84,sp)
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
 mov sp,a0                        /* the table pass (rgbcurves.inc), with this frame's K, c, f1, f2 */
 call st_all,[d2,d3,a2,a3],132
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
 add 100,sp
 mov d3,a0                        /* displaced 0x605197d7 */
 jmp tone_next                    /* 0x60518fa4; returns to 0x605197de */
st_k:                             /* K per strength step, R G B, for the wheel's 12 colours (v0.26: 4.8 Cb/Cr units at
                                   * the weight peak per step; v0.28 >> 9: 2.4 a step, up to 24 at 10) */
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
 * a colour sets its strength (v0.28 t2: 0..10 on the dial's -5..+5, stored as a code -5..5, see st_run; v0.26 had
 * -5..5, minus = the opposite colour) and makes it the page's colour; the other colours
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
/* TONEV: d2 = sector id - 928 (12k + colour), a2 = P, d3 = axis -> d0 = the value shown, s - 5 (-5..5 on the camera's
 * dial = strength 0..10; another colour: -5, its 0). Uses d2, d3, a2. */
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
 movbu (88,a2),d0                 /* its strength code (st_run: v >= 0 -> 2v, v < 0 -> -2v - 1) */
 extb d0
 cmp 0,d0
 bge 74f
 not d0
 add d0,d0
 inc d0
 bra 76f
74:
 add d0,d0
76:
 cmp 10,d0
 ble 77f
 mov 10,d0
77:
 add -5,d0                        /* v0.28 t2: strength 0..10 on the dial's -5..+5 (no hidden count below 0) */
 bra 75f
73:
 mov -5,d0                        /* another colour: strength 0 */
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
 movbu (EDK,a2),d3                /* the readout: colour d2 of the open editor, the dial label the page's */
 cmp 4,d3
 bcc 8f
 add -4,sp                        /* the call's return slot: it would overwrite the saved a2 */
 call vl_s,[d2,d3,a2,a3],20
 add 4,sp
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
t_ret:                            /* emu_test: the caller's d2, d3, a2 are back here */
 clr d0
 rets
8:
 movm (sp),[d2,d3,a2]
9:
 jmp ed_get

/* tn_set <- sl_set's miss (instead of ed_set), entered as ed_set (d0 id, d1 value, a0 inner, a1 mode; d2/d3/a2/a3
 * saved by the setter's call, frame 68). A sector id on a Shadows / Highlights page: value -5..5; not 0 -> this
 * colour and strength; 0 -> strength 0 if this is the page's colour. Then s_cur (dirty, the refresh through the cursor). */
tn_set:
 TONEP 9f
 mov d0,d2
 exthu d2
 add -928,d2
 cmp 48,d2
 bcc 9f
 cmp -5,d1                        /* v0.28 t2: the dial's -5..+5 = strength 0..10 (the wheels only add a colour) */
 blt 8f
 cmp 5,d1
 bgt 8f
 add 5,d1                         /* s 0..10 -> the stored code: even s -> s / 2, odd s -> -(s + 1) / 2 */
 btst 1,d1
 beq 5f
 inc d1
 asr 1,d1
 not d1
 inc d1
 bra 6f
5:
 asr 1,d1
6:
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
 mov d0,a3                        /* kept for s_cur */
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
 mov a3,d2
 jmp s_cur
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
/* fl_mk2: ub_pfl's `call fl_mk2,[d2,d3,a2,a3],80` (a2 = P): TONES.BIN, then fl_mk in the same frame. */
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

/* experiment/no-autoload (owner, 2026-11-11): the two hooks are left out, so 0x60af0fb9 / 0x60af101c stay stock: no
 * SDLOAD worker, no OK trigger, no sdl_poke. The films load at the first half-press (pr_gate from the shutter hook), as
 * in v0.26.1. The sdl_* code below stays in the build, unreachable. Stock 0x60af0fb9: call 0x60af0fff,[d2,d3,a2,a3],24;
 * stock 0x60af101c: call 0x60af10da,[],0. */

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
 * +57..+62 (v0.28: Halation, Tone Balance, film WB; were "unused" and always cleared, so a film saved here lost them
 * at every power-on, owner w3) <- 0 each when outside -5..5; +63 <- 0 on films (a COLOR's own record keeps its 0 / 1).
 * Uses d0, d1, d2, a0, a2. */
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
 mov a2,a0
 add 57,a0
 mov 6,d1
31:
 movbu (a0),d0
 extb d0
 add 5,d0
 cmp 10,d0
 bls 32f
 clr d0
 movbu d0,(a0)
32:
 inc a0
 add -1,d1
 bne 31b
 clr d0
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
.section .hook_dl,"ax"
 jmp dl_look                      /* #37 stock 0x610ba015 (the state block walk's end): cmp 0,a2; beq; mov sp,a0 */
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


/* ---------------------------------------------------------------- debug log (v0.27; the report redone in dl8 / dl9, 2026-11-15)
 * Off unless the card holds OM3MOD/DEBUG.TXT (any content) (checked once, at the first gated half-press of a power-on).
 * When on, every shutter button event (half-press, release; after the editor's save) rewrites OM3MOD/CADLOG.TXT, a
 * plain text report of a fixed 9216 B (v0.30 test 10; dl9 8192) (the camera's fopen "w" does not truncate): the build and SUMMARY; START-UP (the
 * settings block, where the films came from, what loaded, the card files against this firmware); NOW (shooting mode,
 * picture mode and film, the film on each COLOR, the films with changes); CAMERA (the camera's own settings); SAVES;
 * CUSTOM MODES; BUTTONS AND DIALS; the last 32 events, newest first (so a full report loses the oldest). Lives in
 * ext13 (v0.30 test 10: the GX4-proven reserve after the RGB work area, 0x60fac000; build.py raises the loader's end
 * word to cover it); its variables are in the same loaded RAM. Stores: its own variables and buffers, its own frames, and one counter in ex_fill
 * (lg_np). Reads only: P (PVAL), the getter (sget), tg_ptr, the films-block / custom-mode / per-mode variables, the
 * mode's code (rc_in + 24), the mode dial / photo-movie-S&Q switch bytes (0xa32d9d0c / d) and the GUI state (LG_GUI).
 * No settings writes, nothing at start-up. research/NOTES.md, "Debug log dl8" and "dl9". */
.section .ext13,"ax"
 .macro LGS s                     /* append the string at \s (uses d0, a0, a1) */
 mov \s,a0
 call lg_s,[],0
 .endm
 .macro LGD                       /* append d0 in decimal (uses d0, d1, a0, a1, MDR) */
 call lg_d,[d2,d3],12
 .endm
 .macro LGY                       /* append "yes" (d0 != 0) or "no" */
 call lg_y,[],0
 .endm
 .macro LGT col                   /* spaces up to column \col of the line begun by LGN (uses d0, d1, a0, a1) */
 mov \col,d0
 call lg_tab,[],0
 .endm
 .macro LGN                       /* CR LF; the next line starts (uses d0, a0, a1) */
 call lg_nl,[],0
 .endm
 .set LSLOT, 100                  /* dl8: one stored event line (lg_lines): up to 98 characters, CR LF */
 .set LG_GUI, 0x62ce5864          /* dl8: the GUI state {parent, child} (0x610fcf81 loads it; gx_map's (8,sp)) */
 .set LG_NC, 63                   /* dl8: lg_cid / lg_cv entries */
 .set CI_KEL, 62
 .set CI_TVS, 17                  /* lg_cv indexes (lg_cid's order) */
 .set CI_AVS, 18
 .set CI_MET, 5
 .set CI_FL, 6
 .set CI_FC, 7
 .set CI_IS, 8
 .set CI_ASP, 9
 .set CI_FACE, 10
 .set CI_AFT, 11
 .set CI_VQ, 12
 .set CI_HS, 13
 .set CI_MWB, 14
 .set CI_LEV, 15
 .set CI_PAD, 16
 .set CI_MPAD, 19
 .set CI_BTN, 20
 .set CI_DROW, 31
 .set CI_MBTN, 35
 .set CI_DIAL, 46
 .set KST_W, 26                   /* dl8: key words of START-UP, CUSTOM MODES, BUTTONS AND DIALS */
 .set KCM_W, 40
 .set KBT_W, 42                   /* lg_cv[CI_BTN .. CI_DIAL + 15] */
lg_pr:                            /* jmp from pr_ed, pr_hook's frame: as `call ed_trig; jmp trig_resume` there */
 movbu (18,sp),d0                 /* v0.30.3: the shutter handler's event word (16,sp) {0x0100 half-press, 0x0101 its
                                   * release} (om-emu trace at 0x60415216, 2026-11-17): byte 18 is 1 at the release */
 movbu d0,(lg_rel)
 clr d0                           /* L1: the first shutter event releases the hooks held since the early load */
 movbu d0,(el_hold)
 call lg_pre,[d2,d3,a2,a3],36
 call ed_trig,[d2,d3,a2,a3],36
 call ub_try,[d2,d3,a2,a3],36     /* films in camera memory: a block write held back by the camera's own save */
 call el_card,[d2,d3,a2,a3],36
 call ck_card,[d2,d3,a2,a3],24    /* v0.30 test 9: CURVES.BIN, after el_card's films */
 call cr_hp,[d2,d3,a2,a3],20      /* crop modes: the first shutter event after an early load (crop.s) */
 call cm_hp,[d2,d3,a2,a3],24      /* k4: in P / A / S / M, their films and choice now (kept in M) */
 call lg_write,[d2,d3,a2,a3],40
 call ex_live,[d2,d3,a2,a3],48    /* v0.28 pc1: the film's settings now, for the next photo's code */
 jmp trig_resume
lg_pre:                           /* edits waiting before ed_trig (it saves them and clears DIRTY) */
 clr d0
 movbu d0,(lg_dty)
 PVAL 1f
 movbu (DIRTY,a2),d0
 movbu d0,(lg_dty)
1:
 ret [d2,d3,a2,a3],36

lg_write:                         /* frame 40: (0) call slot, (4) handle */
 movbu (lg_on),d0                 /* 0 not checked yet, 1 on, 2 off */
 cmp 2,d0
 beq lg_out                       /* off: before the card gate, so no card work at all */
 call hl_ok,[a2],16               /* the card gate (as the loaders and the GX probes) */
 cmp 0,d0
 bne lg_out
 movbu (lg_on),d0
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
 mov (lg_n),d2                    /* the event (lg_ring) */
 inc d2
 mov d2,(lg_n)
 mov d2,d1
 and 31,d1
 asl 4,d1
 mov d1,d0
 add d1,d1
 add d0,d1                        /* x 48 (dl8: was 16) */
 mov lg_ring,a3
 add d1,a3
 mov d2,(a3)
 mov 111,d0
 call sget,[],4                   /* d0 = the picture mode setting (keeps d2/d3/a2/a3) */
 mov d0,(4,a3)
 mov 897,d0                       /* v0.27 research: the active picture-mode family (the Creative Dial) */
 call sget,[],4
 movhu d0,(12,a3)
 call lg_mode,[],0                /* dl2: the shooting mode */
 movbu d0,(14,a3)
 movbu d1,(15,a3)
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
 movbu (lg_dty),d0                /* dl2: edits saved at shutter events (ed_trig had them waiting) */
 cmp 1,d0
 bne 3f
 mov (lg_ns),d0
 inc d0
 mov d0,(lg_ns)
3:
 call lg_cam,[d2,d3,a2,a3],24     /* dl8: the camera's own values at this event (a3 = the entry) */
 call lg_crf,[d2,d3,a2,a3],24     /* dl8: a few cached reads (buttons, dials, the rest of the camera) */
 call lg_line,[d2,d3,a2,a3],24    /* dl8: this event's line, made once */
 call lg_due,[],0                 /* v0.30.3: write the file now? (d0; uses d0, d1) */
 cmp 0,d0
 bne 18f
 jmp lg_out                       /* noted in memory only; the next write has it */
18:
 mov (lg_w),d0
 inc d0
 mov d0,(lg_w)
 mov lg_buf,a0                    /* the text */
 mov a0,(lg_cur)
 mov a0,(lg_ls)
 mov lg_bend,a0
 mov a0,(lg_lim)
 call lg_sum,[d2,d3,a2,a3],24     /* the build, SUMMARY */
 call lg_stc,[d2,d3,a2,a3],24     /* START-UP (kept text while its inputs are the same) */
 call lg_now,[d2,d3,a2,a3],24     /* NOW (ours) */
 call lg_cnow,[d2,d3,a2,a3],24    /* CAMERA */
 call lg_svt,[d2,d3,a2,a3],24     /* SAVES */
 call lg_cmc,[d2,d3,a2,a3],24     /* CUSTOM MODES (the same) */
 call lg_btc,[d2,d3,a2,a3],24     /* BUTTONS AND DIALS (the same) */
 call cr_txt,[d2,d3,a2,a3],24     /* CROP MODES (crop.s) */
 call lg_evt,[d2,d3,a2,a3],24     /* the last 32 events, newest first */
 mov (lg_cur),a0                  /* camera: fopen "w" does not truncate (dl3, 2026-11-10): always the same length, */
 mov lg_bend,a1                   /* spaces after the text, CR LF last; dl8: only up to where the last report's text */
 add -2,a1                        /* ended (lg_pend; 0 at the first write: all), the rest is spaces already */
 mov (lg_pend),d0
 mov a0,(lg_pend)
 cmp 0,d0
 beq 17f
 cmp a1,d0
 bcc 17f
 mov d0,a1
17:
 mov 32,d0
11:
 cmp a1,a0                        /* a0 - a1 */
 bcc 12f
 mov a0,d1
 and 3,d1
 beq 14f
 movbu d0,(a0)
 inc a0
 bra 11b
14:
 mov 0x20202020,d0                /* dl2: whole words */
15:
 mov a0,d1
 add 4,d1
 cmp a1,d1                        /* d1 - a1 */
 bhi 16f
 mov d0,(a0)
 inc4 a0
 bra 15b
16:
 cmp a1,a0
 bcc 12f
 movbu d0,(a0)
 inc a0
 bra 16b
12:
 mov lg_bend - 2,a1
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

/* lg_top: `call lg_top,[d2,d3,a2,a3],24`: START-UP and the card files. */
lg_top:
 LGS lg_t4
 PVAL 5f
 LGS lg_found
 LGS lg_u1                        /* the films: from where */
 movbu (ub_st),d0
 cmp 0,d0
 bne 1f
 LGS lg_u0
 bra 2f
1:
 movbu (ub_src),d0
 asl2 d0
 mov lg_srt,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 LGS lg_u2
 movbu (ub_ok0),d0
 cmp 0,d0
 bne 3f
 LGS lg_u3
 bra 2f
3:
 LGS lg_u4
 mov (ub_gen0),d0
 LGD
2:
 LGS lg_k1
 mov (LPTR,a2),d0
 LGY
 LGS lg_k5
 mov (TORG,a2),d0
 LGY
 LGS lg_k4
 mov (tg_ptr),d0
 LGY
 LGS lg_k2
 mov (XPTR,a2),d0
 LGY
 LGS lg_k3
 mov (GPTR,a2),d0
 LGY
 LGS lg_k6
 mov (NPTR,a2),d0
 LGY
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
 LGS lg_c6
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
 LGS lg_q9                        /* v0.30 test 10: CURVES.BIN (curvesfile.inc), as test 9's ck_txt */
 movbu (ck_have),d0
 LGY
 LGS lg_qa
 movbu (ck_st),d0
 mov lg_qst,a0
 call lg_nth,[],0
 call lg_s,[],0
 LGS lg_qb
 mov (ck_nm),d0
 LGD
 ret [d2,d3,a2,a3],24

/* lg_now: `call lg_now,[d2,d3,a2,a3],24`: NOW: the shooting mode (and a custom mode's Save Settings), the picture mode
 * and its film, the film on each COLOR, the films with changes (fl_fch: the camera's '*'), the editor. */
lg_now:
 LGS lg_w0
 call lg_mode,[],0
 mov d0,d2
 mov d1,d3
 call lg_mn,[d2,d3],12
 LGS lg_w1
 mov d2,d0
 LGD
 LGS lg_w2
 mov d3,d0
 and 15,d0
 LGD
 LGS lg_w3
 mov d3,d0
 lsr 4,d0
 LGD
 LGS lg_k0
 cmp 53,d2                        /* a photo custom mode: its Save Settings (1880..1884) */
 bcs 1f
 cmp 58,d2
 bcc 1f
 LGS lg_w4
 mov d2,d0
 add -53,d0
 asl2 d0
 mov lg_cv,a0                     /* dl8: the cached 1880 + n */
 add d0,a0
 mov (a0),d0
 call lg_rh,[d2,d3],12
1:
 call lg_gp,[d3],8                /* a2 = P or 0 */
 LGS lg_w5
 mov 111,d0
 call sget,[],4
 mov d0,d2
 call fl_k,[],0
 mov d0,d3
 cmp 0,d3
 blt 4f
 LGS lg_col
 mov d3,d0
 inc d0
 LGD
 mov lg_cm,a3
 mov d3,d0
 call lg_kf,[d2,d3,a3],16
 bra 5f
4:
 LGS lg_pmn
 mov d2,d0
 LGD
5:
 LGS lg_w6
 mov d2,d0
 LGD
 LGS lg_w7
 mov 897,d0
 call sget,[],4
 call lg_fm,[d2,d3],12
 cmp 0,a2
 beq 9f
 mov (LPTR,a2),d0
 cmp 0,d0
 bne 6f
 LGS lg_w8                        /* no films */
 bra 8f
6:
 clr d2                           /* COLOR 1..4 */
7:
 LGS lg_w9
 mov d2,d0
 inc d0
 LGD
 LGS lg_c3
 mov 0,a3
 mov d2,d0
 call lg_kf,[d2,d3,a3],16
 cmp 0,d0
 bge 71f
 LGS lg_wa
71:
 inc d2
 cmp 4,d2
 bcs 7b
 LGS lg_wb                        /* the films with changes (lg_chg) */
 clr d2
 clr d3
72:
 mov d2,d0
 call lg_chg,[d2,d3,a2,a3],24
 cmp 0,d0
 beq 74f
 cmp 0,d3
 beq 73f
 LGS lg_cm
73:
 inc d3
 mov d2,d0
 inc d0
 LGD
74:
 inc d2
 cmp 20,d2
 bcs 72b
 cmp 0,d3
 bne 8f
 LGS lg_none
8:
 LGS lg_k7
 mov (EMARK,a2),d1
 clr d0
 cmp EMAGIC,d1
 bne 81f
 mov 1,d0
81:
 LGY
 call lg_ckn,[d2,d3,a2,a3],24     /* v0.30 test 10: curves / mix */
 call lg_gsn,[d2,d3,a2,a3],24     /* better grain g2: each COLOR's Film Grain strength and Grain Size */
9:
 ret [d2,d3,a2,a3],24

/* lg_svt: `call lg_svt,[d2,d3,a2,a3],24`: SAVES. */
lg_svt:
 call lg_gp,[d3],8
 LGS lg_x0
 cmp 0,a2
 beq 1f
 movbu (DIRTY,a2),d0
 LGY
 LGS lg_k9
 movbu (STATUS,a2),d0
 call lg_st,[d2,d3],12
 bra 2f
1:
 LGS lg_nb
2:
 LGS lg_x1
 mov (lg_ns),d0
 LGD
 LGS lg_x2
 mov (ub_nw),d0
 LGD
 LGS lg_x3
 mov (ub_gen),d0
 LGD
 LGS lg_x4
 movbu (ub_pend),d0
 LGY
 LGS lg_x5
 movbu (UB_DIRTY),d0
 LGD
 LGS lg_k0
 LGS lg_x6
 mov (cm_nw),d0
 LGD
 LGS lg_x7
 movbu (cm_pend),d0
 LGY
 LGS lg_x8
 mov (ss_nw),d0
 LGD
 LGS lg_x9
 movbu (ss_dirty),d0
 LGY
 LGS lg_xa
 mov (rc_n),d0
 LGD
 LGS lg_xb
 mov (rc_w),d0
 LGD
 LGS lg_xc
 movbu (rc_pend),d0
 LGY
 LGS lg_qc                        /* v0.30 test 10: CURVES.BIN */
 mov (ck_nw),d0
 LGD
 LGS lg_x7
 movbu (ck_pend),d0
 LGY
 ret [d2,d3,a2,a3],24

/* cm_txt: `call cm_txt,[d2,d3,a2,a3],24`: CUSTOM MODES: a row per group (P / A / S / M / B, C1..C5): Save Settings,
 * its films (OM3C), its picture mode choice, its own copy (OM3S); then the counters and the last 8 mode changes. */
cm_txt:
 LGS cm_s1
 movbu (cm_v0),d0
 LGY
 LGS cm_s2
 movbu (ss_v0),d0
 LGY
 LGS lg_k0
 LGN
 LGS cm_s3
 mov 5,d2                         /* P group first, then C1..C5 */
1:
 LGN
 mov d2,d0
 call lg_gn,[d2,d3],12
 LGT 11
 cmp 5,d2
 bne 2f
 LGS lg_dash
 mov cm_ram + CM_P,a3
 mov cm_ram + CM_PM,a2
 bra 3f
2:
 mov d2,d0
 asl2 d0
 mov lg_cv,a0                     /* dl8: the cached 1880 + n */
 add d0,a0
 mov (a0),d0
 call lg_rh,[d2,d3],12
 mov d2,d0
 asl2 d0
 mov cm_ram + CM_S,a3
 add d0,a3
 mov cm_ram + CM_SPM,a2
 add d2,a2
3:
 LGT 26
 mov 0x80,d1                      /* the group's flag: bit n (Cn+1), bit 7 the P group */
 cmp 5,d2
 beq 32f
 mov 1,d1
 asl d2,d1
32:
 movbu (cm_ram + CM_FL),d0
 and d1,d0
 bne 4f
 mov cm_s4,a0                     /* no films of ours kept */
 cmp 5,d2
 bne 31f
 mov cm_s5,a0
31:
 call lg_s,[],0
 LGT 46
 LGS lg_dash
 bra 6f
4:
 clr d3
5:
 cmp 0,d3
 beq 51f
 LGS lg_sp
51:
 mov a3,a0
 add d3,a0
 movbu (a0),d1
 mov d3,d0
 call lg_lk,[d2,d3],12
 inc d3
 cmp 4,d3
 bcs 5b
 LGT 46
 movbu (a2),d0
 call lg_ch,[d2,d3],12
6:
 LGT 59
 mov 1,d1                         /* the per-mode set */
 asl d2,d1
 mov lg_kept,a0
 movbu (ss_ram + 12),d0
 and d1,d0
 bne 7f
 mov cm_s6,a0
 movbu (ss_ram + 13),d0
 and d1,d0
 bne 7f
 mov cm_s7,a0
7:
 call lg_s,[],0
 cmp 5,d2
 bne 8f
 clr d2
 bra 1b
8:
 inc d2
 cmp 5,d2
 bcs 1b
 LGS cm_s8                        /* now */
 movbu (cm_ram + CM_LAST),d0
 call lg_gn,[d2,d3],12
 movbu (cm_code),d2               /* the code, or 0xc0 | the mode dial's position */
 mov cm_s9,a0
 cmp 0xc0,d2
 bcs 60f
 mov cm_s9b,a0
 and 15,d2
60:
 call lg_s,[],0
 mov d2,d0
 LGD
 LGS cm_sa
 movbu (ss_cur),d0
 call lg_gn,[d2,d3],12
 movbu (ss_ph),d2                 /* the code, or 0xc0 | the photo / movie / S&Q switch */
 mov cm_sb,a0
 cmp 0xc0,d2
 bcs 61f
 mov cm_sbb,a0
 and 15,d2
61:
 call lg_s,[],0
 mov d2,d0
 LGD
 LGS lg_k0
 LGS cm_sc                        /* counters */
 mov (cm_na),d0
 LGD
 LGS cm_sd
 mov (cm_sw),d0
 LGD
 LGS cm_se
 mov (cm_pms),d0
 LGD
 LGS ss_s6
 mov (ss_ntr),d0
 LGD
 LGS ss_s7
 mov (ss_nl),d0
 LGD
 LGS ss_s8
 mov (ss_ng),d0
 LGD
 LGS ss_s9
 mov (ss_np),d0
 LGD
 LGS ss_s11
 mov (ss_nab),d0
 LGD
 LGS ss_s14
 mov (ss_ne),d0
 LGD
 LGS ss_s12
 mov (ss_nm),d0
 LGD
 mov (ss_nm),d0
 cmp 0,d0
 beq 9f
 LGS ss_s13                       /* ss_ml: set << 24 | k << 16 | id */
 mov (ss_ml),d0
 lsr 24,d0
 call lg_gn,[d2,d3],12
 LGS ss_s15
 mov (ss_ml),d0
 lsr 16,d0
 and 255,d0
 inc d0
 LGD
 LGS ss_s16
 mov (ss_ml),d0
 and 0xffff,d0
 LGD
 LGS lg_k0
9:
 LGS cm_sf                        /* rc_tr: the last 8 cm_go runs, newest first */
 clr d2
10:
 movbu (rc_ti),d0
 sub d2,d0
 add -1,d0
 and 7,d0
 asl2 d0
 mov rc_tr,a3
 add d0,a3
 mov (a3),d0
 cmp 0,d0
 beq 19f
 LGN
 LGS cm_sg                        /* "  after event N" (the low 8 bits kept: the nearest number) */
 movbu (a3),d1
 mov (lg_n),d0
 sub d1,d0
 and 255,d0
 mov (lg_n),d1
 sub d0,d1
 mov d1,d0
 LGD
 LGS lg_c3
 movbu (1,a3),d0                  /* the code, or 0xc0 | the mode dial's position */
 cmp 0xc0,d0
 bcs 11f
 and 15,d0
 mov d0,d1
 or 0x20,d1
 clr d0
 call lg_mn,[d2,d3],12
 LGS cm_sh
 movbu (1,a3),d0
 and 15,d0
 LGD
 bra 12f
11:
 mov 0x2f,d1
 call lg_mn,[d2,d3],12
 LGS lg_w1b
 movbu (1,a3),d0
 LGD
12:
 LGS cm_si
 movbu (2,a3),d0
 and 0x7f,d0
 call lg_gn,[d2,d3],12
 movbu (2,a3),d0
 btst 0x80,d0
 beq 13f
 LGS cm_sj
13:
 LGS cm_sk
 movbu (3,a3),d0
 and 0x7f,d0
 LGD
 movbu (3,a3),d0
 btst 0x80,d0
 beq 19f
 LGS cm_sl
19:
 inc d2
 cmp 8,d2
 bcs 10b
 ret [d2,d3,a2,a3],24

/* lg_evt: `call lg_evt,[d2,d3,a2,a3],24`: the last 32 events, newest first: their stored lines (lg_line, LSLOT B
 * each, CR LF included), copied by words (spaces before the header's CR LF bring lg_cur to a 4-byte boundary); only
 * whole lines, while they fit before lg_bend. */
lg_evt:
 LGS lg_t7
 LGN
 LGS lg_e0
 mov (lg_cur),a1
 mov (lg_lim),d1
 cmp d1,a1
 bcc 9f
 mov 32,d0
1:
 mov a1,d1
 add 2,d1
 and 3,d1
 beq 2f
 movbu d0,(a1)
 inc a1
 bra 1b
2:
 mov 13,d0
 movbu d0,(a1)
 mov 10,d0
 movbu d0,(1,a1)
 add 2,a1
 mov a1,(lg_cur)
 mov (lg_n),d2
 clr d3
 cmp 33,d2
 bcs 3f
 mov d2,d3
 add -32,d3
3:
 cmp d3,d2                        /* d2 - d3 */
 bls 9f
 mov (lg_cur),a1
 mov a1,d0
 add LSLOT,d0
 cmp lg_bend,d0
 bhi 9f
 mov d2,d0
 and 31,d0
 mov LSLOT,d1
 mul d1,d0
 mov lg_lines,a0
 add d0,a0
 mov LSLOT / 4,d1
4:
 mov (a0),d0
 mov d0,(a1)
 inc4 a0
 inc4 a1
 add -1,d1
 bne 4b
 mov a1,(lg_cur)
 add -1,d2
 bra 3b
9:
 ret [d2,d3,a2,a3],24

/* lg_cam: `call lg_cam,[d2,d3,a2,a3],24`, a3 = this event's lg_ring entry: the camera's own values now (getter only):
 * shutter / aperture as the AE left them (4000 / 4001, APEX x 256), ISO (6), exp comp (2), WB (1578, movie 1579), Custom
 * WB (107, K; read only when WB is Custom), the screen (LG_GUI), photos so far; drive (3265), AF mode (289), image
 * quality (861) cost ~2k instructions each, so one of them is read per event (lg_fv, at most 3 events old). */
lg_cam:
 mov 4000,d0
 call sget,[],4
 movhu d0,(16,a3)
 mov 4001,d0
 call sget,[],4
 movhu d0,(18,a3)
 movhu (16,a3),d1                 /* both 0: no exposure worked out yet -> 0x8000 ("-") */
 or d1,d0
 exthu d0
 cmp 0,d0
 bne 0f
 mov 0x8000,d0
 movhu d0,(16,a3)
 movhu d0,(18,a3)
0:
 mov 6,d0
 call sget,[],4
 movhu d0,(20,a3)
 mov 2,d0
 call sget,[],4
 movhu d0,(22,a3)
 movbu (0xa32d9d0d),d1            /* the photo / movie / S&Q switch: 2 photo */
 mov 1578,d0
 cmp 2,d1
 beq 1f
 mov 1579,d0
1:
 call sget,[],4
 movbu d0,(24,a3)
 clr d1
 movbu d1,(25,a3)
 cmp 9,d0                         /* Custom WB: its Kelvin */
 bne 2f
 mov 107,d0
 call sget,[],4
 clr d1
 mov d1,mdr
 mov 100,d1
 divu d1,d0
 movbu d0,(25,a3)
2:
 movbu (lg_fi),d2                 /* one of drive / AF mode / quality */
 mov d2,d0
 add d0,d0
 mov lg_fid,a0
 add d0,a0
 movhu (a0),d0
 call sget,[],4
 mov d2,d1
 asl2 d1
 mov lg_fv,a0
 add d1,a0
 mov d0,(a0)
 inc d2
 cmp 3,d2
 bcs 3f
 clr d2
3:
 movbu d2,(lg_fi)
 mov (lg_fv),d0
 movhu d0,(26,a3)
 mov (lg_fv + 4),d0
 movhu d0,(28,a3)
 mov (lg_fv + 8),d0
 movhu d0,(30,a3)
 movhu (LG_GUI),d0
 movhu d0,(32,a3)
 mov (lg_np),d0
 movhu d0,(34,a3)
 ret [d2,d3,a2,a3],24

/* lg_crf: `call lg_crf,[d2,d3,a2,a3],24`: the next 4 of lg_cid into lg_cv, so each is at most 16 events old (-1 until
 * first read: shown as "-"). */
lg_crf:
 mov 4,d3
 mov (lg_cr),d2
2:
 mov d2,d0
 add d0,d0
 mov lg_cid,a0
 add d0,a0
 movhu (a0),d0
 call sget,[],4
 mov d2,d1
 asl2 d1
 mov lg_cv,a0
 add d1,a0
 mov d0,(a0)
 inc d2
 cmp LG_NC,d2
 bcs 3f
 clr d2
 mov 1,d0
 mov d0,(lg_cful)
3:
 add -1,d3
 bne 2b
 mov d2,(lg_cr)
 ret [d2,d3,a2,a3],24

/* lg_line: `call lg_line,[d2,d3,a2,a3],24`, a3 = this event's lg_ring entry -> its line in lg_lines (LSLOT B: the
 * text, spaces, CR LF), made in lg_tl once, so a write only copies the 32 lines. */
lg_line:
 mov lg_tl,a0
 mov a0,(lg_cur)
 mov a0,(lg_ls)
 add LSLOT - 4,a0
 mov a0,(lg_lim)
 LGS lg_e1
 mov (a3),d0
 LGD
 LGT 7
 movbu (14,a3),d0
 movbu (15,a3),d1
 call lg_mn,[d2,d3],12
 LGT 16
 movhu (32,a3),d0
 call lg_scr,[d2,d3],12
 LGT 24
 movhu (16,a3),d0
 exth d0
 call lg_tv,[d2,d3],12
 LGT 32
 movhu (18,a3),d0
 exth d0
 call lg_av,[d2,d3],12
 LGT 38
 movhu (20,a3),d0
 call lg_iso,[d2,d3],12
 LGT 48
 movhu (22,a3),d0
 exth d0
 call lg_ev,[d2,d3],12
 LGT 53
 movbu (24,a3),d0
 movbu (25,a3),d1
 call lg_wbn,[d2,d3],12
 LGT 64
 mov a3,a0
 call lg_pic,[d2,d3],12
 LGT 73
 movhu (26,a3),d0
 call lg_dvh,[d2,d3],12
 LGS lg_sl
 movhu (28,a3),d0
 call lg_dvh,[d2,d3],12
 LGS lg_sl
 movhu (30,a3),d0
 call lg_dvh,[d2,d3],12
 LGT 86
 movbu (8,a3),d0
 LGY
 LGT 90
 movbu (9,a3),d0
 cmp 255,d0
 bne 1f
 LGS lg_dash
 bra 2f
1:
 LGD
2:
 LGT 93
 movhu (34,a3),d0
 LGD
 mov (a3),d0                      /* the slot */
 and 31,d0
 mov LSLOT,d1
 mul d1,d0
 mov lg_lines,a1
 add d0,a1
 mov lg_tl,a0
 mov (lg_cur),d2
 mov LSLOT - 2,d3
3:
 mov 32,d0
 cmp d2,a0                        /* a0 - the text's end */
 bcc 4f
 movbu (a0),d0
4:
 movbu d0,(a1)
 inc a0
 inc a1
 add -1,d3
 bne 3b
 mov 13,d0
 movbu d0,(a1)
 mov 10,d0
 movbu d0,(1,a1)
 ret [d2,d3,a2,a3],24

/* lg_new: `call lg_new,[],0` -> a3 = the newest lg_ring entry (uses d0, d1). */
lg_new:
 mov (lg_n),d0
 and 31,d0
 asl 4,d0
 mov d0,d1
 add d0,d0
 add d1,d0
 mov lg_ring,a3
 add d0,a3
 ret [],0

 .macro LGF s                     /* SUMMARY's "Look at": ", " before all but the first (d3 counts) */
 cmp 0,d3
 beq 1f
 LGS lg_cm
1:
 LGS \s
 inc d3
 .endm
 .macro LGC i                     /* append lg_cv[\i] in decimal, "-" when not read yet */
 mov (lg_cv + 4 * \i),d0
 call lg_dv,[d2,d3],12
 .endm
 .macro LGCB i                    /* append " [" lg_cv[\i] "]" */
 LGS lg_lb
 LGC \i
 LGS lg_rb
 .endm

/* lg_sum: `call lg_sum,[d2,d3,a2,a3],24`: the build, the counters, SUMMARY (now, films, saves, photos, what to look at). */
lg_sum:
 LGS lg_t1
 LGS lg_ver
 LGS lg_t2
 mov (lg_n),d0
 LGD
 LGS lg_t3
 mov (lg_w),d0
 LGD
 LGS tg_l1                        /* better grain g1: our grain tiles */
 mov (tg_n),d0
 LGD
 LGS tg_l2
 mov (tg_nb),d0
 LGD
 LGS tg_l3
 movbu (tg_w),d0
 LGD
 LGS tg_l4
 mov (tg_ms),d0
 LGD
 LGS lg_y0                        /* now: mode, exposure, WB, picture, screen */
 call lg_new,[],0
 movbu (14,a3),d0
 movbu (15,a3),d1
 call lg_mn,[d2,d3],12
 LGS lg_cm
 movhu (16,a3),d0
 exth d0
 call lg_tv,[d2,d3],12
 LGS lg_sp
 movhu (18,a3),d0
 exth d0
 call lg_av,[d2,d3],12
 LGS lg_sp
 movhu (20,a3),d0
 call lg_iso,[d2,d3],12
 LGS lg_y1
 movhu (22,a3),d0
 exth d0
 call lg_ev,[d2,d3],12
 LGS lg_y2
 movbu (24,a3),d0
 movbu (25,a3),d1
 call lg_wbn,[d2,d3],12
 LGS lg_y3
 mov a3,a0
 call lg_pic,[d2,d3],12
 LGS lg_y4
 movhu (32,a3),d0
 call lg_scr,[d2,d3],12
 call lg_gp,[d3],8                /* a2 = P or 0; the card files that do not match -> lg_mm */
 clr d2
 mov lg_ft,a3
 mov LG_NF,d3
1:
 call lg_vd,[],0
 cmp 1,d0
 bcs 2f
 cmp 5,d0
 bcc 2f
 inc d2
2:
 add 20,a3
 add -1,d3
 cmp 0,d3
 bne 1b
 mov d2,(lg_mm)
 LGS lg_y5                        /* films, card files, saves */
 movbu (ub_st),d0
 mov lg_u0,a0
 cmp 0,d0
 beq 3f
 movbu (ub_src),d0
 asl2 d0
 mov lg_srt,a0
 add d0,a0
 mov (a0),a0
3:
 call lg_s,[],0
 LGS lg_y6
 mov (lg_mm),d0
 cmp 0,d0
 bne 4f
 LGS lg_c1
 bra 5f
4:
 LGD
 LGS lg_y6b
5:
 LGS lg_y7
 mov (lg_ns),d0
 LGD
 LGS lg_y8                        /* photos, mode changes, custom modes with films */
 mov (lg_np),d0
 LGD
 LGS lg_y9
 movbu (rc_ti),d0
 LGD
 LGS lg_ya
 clr d3
 clr d2
6:
 movbu (cm_ram + CM_FL),d0
 mov 1,d1
 asl d2,d1
 and d1,d0
 beq 8f
 cmp 0,d3
 beq 7f
 LGS lg_sp
7:
 inc d3
 LGS lg_mC
 mov d2,d0
 inc d0
 LGD
8:
 inc d2
 cmp 5,d2
 bcs 6b
 cmp 0,d3
 bne 10f
 LGS lg_none
10:
 LGS lg_yb                        /* what to look at (d3 counts) */
 clr d3
 cmp 0,a2
 bne 21f
 LGF lg_la0
21:
 mov (lg_mm),d0
 cmp 0,d0
 beq 22f
 LGF lg_la1
22:
 movbu (ub_st),d0
 cmp 0,d0
 beq 23f
 movbu (ub_src),d0
 cmp 3,d0
 bne 23f
 LGF lg_la2
23:
 movbu (ub_pend),d0
 cmp 0,d0
 beq 24f
 LGF lg_la3
24:
 movbu (cm_pend),d0
 cmp 0,d0
 beq 25f
 LGF lg_la4
25:
 movbu (ss_dirty),d0
 cmp 0,d0
 beq 26f
 LGF lg_la5
26:
 movbu (rc_pend),d0
 cmp 0,d0
 beq 27f
 LGF lg_la6
27:
 mov (ss_nm),d0
 cmp 0,d0
 beq 28f
 LGF lg_la7
28:
 cmp 0,d3
 bne 29f
 LGS lg_la8
29:
 ret [d2,d3,a2,a3],24

/* lg_cnow: `call lg_cnow,[d2,d3,a2,a3],24`: CAMERA: the newest event's values (lg_cam) and the cached ones (lg_crf). */
lg_cnow:
 call lg_new,[],0
 LGS lg_z0
 movhu (16,a3),d0
 exth d0
 call lg_tv,[d2,d3],12
 LGS lg_sp
 movhu (18,a3),d0
 exth d0
 call lg_av,[d2,d3],12
 LGS lg_z1
 mov (lg_cv + 4 * CI_TVS),d0
 mov lg_tv,a0
 call lg_gxv,[d2,d3],12
 LGS lg_z1b
 mov (lg_cv + 4 * CI_AVS),d0
 mov lg_av,a0
 call lg_gxv,[d2,d3],12
 LGS lg_z2
 movhu (20,a3),d0
 call lg_iso,[d2,d3],12
 LGS lg_z2b
 movhu (22,a3),d0
 exth d0
 call lg_ev,[d2,d3],12
 LGS lg_z2c
 mov (lg_cv + 4 * CI_FC),d0
 mov lg_ev,a0
 call lg_gxv,[d2,d3],12
 LGS lg_z3                        /* white balance */
 movbu (24,a3),d0
 movbu (25,a3),d1
 call lg_wbn,[d2,d3],12
 LGS lg_lb
 movbu (24,a3),d0
 LGD
 LGS lg_z3b
 LGC CI_KEL
 LGS lg_z3c
 LGC CI_MWB
 LGS lg_rb
 LGS lg_z4                        /* the rest, as the camera's codes */
 movhu (26,a3),d0
 call lg_dvh,[d2,d3],12
 LGS lg_z4b
 movhu (28,a3),d0
 call lg_dvh,[d2,d3],12
 LGS lg_z4c
 LGC CI_AFT
 LGS lg_z4d
 LGC CI_FACE
 LGS lg_z4e
 LGC CI_MET
 LGS lg_z5
 LGC CI_FL
 LGS lg_z5b
 LGC CI_IS
 LGS lg_z5c
 LGC CI_ASP
 LGS lg_z5d
 movhu (30,a3),d0
 call lg_dvh,[d2,d3],12
 LGS lg_z5e
 LGC CI_VQ
 LGS lg_z5f
 LGC CI_HS
 LGS lg_rb
 LGS lg_z6                        /* the Fn lever, the arrow pad */
 LGC CI_LEV
 LGS lg_z6b
 mov (lg_cv + 4 * CI_PAD),d0
 call lg_pad,[d2,d3],12
 LGS lg_z6c
 mov (lg_cv + 4 * CI_MPAD),d0
 call lg_pad,[d2,d3],12
 LGS lg_z7                        /* the screen */
 movhu (32,a3),d0
 mov d0,d2
 call lg_scr,[d2,d3],12
 LGS lg_lb
 mov d2,d0
 call lg_h4,[],0
 LGS lg_rb
 ret [d2,d3,a2,a3],24

/* lg_btn: `call lg_btn,[d2,d3,a2,a3],24`: BUTTONS AND DIALS from lg_cv: photo and video buttons, our Creative Dial
 * rows, the dial functions in P / A / S / M for both Fn lever positions. */
lg_btn:
 LGS lg_b0
 mov CI_BTN,d2                    /* photo buttons */
 mov lg_bn,a3
 mov 11,d3
 call lg_bl,[d2,d3,a2,a3],24
 LGS lg_b1                        /* video buttons */
 mov CI_MBTN,d2
 mov lg_bn,a3
 mov 11,d3
 call lg_bl,[d2,d3,a2,a3],24
 LGS lg_b2                        /* the Creative Dial rows (ours: DV1 + 0 Normal, 1 CRT, 2 ART, 3 COLOR, 4 MONO) */
 clr d2
1:
 cmp 0,d2
 beq 2f
 LGS lg_cm
2:
 mov d2,d0
 asl2 d0
 mov lg_dpn,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 LGS lg_sp
 mov d2,d0
 add CI_DROW,d0
 asl2 d0
 mov lg_cv,a0
 add d0,a0
 mov (a0),d0
 mov lg_dash,a0
 cmp -1,d0
 beq 4f
 add -3900,d0                     /* DV1: 0 Normal, 1 CRT, 2 ART, 3 COLOR, 4 MONO */
 cmp 5,d0
 bcs 3f
 clr d0
3:
 asl2 d0
 mov lg_dvn,a0
 add d0,a0
 mov (a0),a0
4:
 call lg_s,[],0
 inc d2
 cmp 4,d2
 bcs 1b
 LGS lg_b3                        /* dials, lever position 1, then 2 */
 mov CI_DIAL,d2
 call lg_dl,[d2,d3,a2,a3],24
 LGS lg_b4
 mov CI_DIAL + 2,d2
 call lg_dl,[d2,d3,a2,a3],24
 ret [d2,d3,a2,a3],24

/* lg_bl: `call lg_bl,[d2,d3,a2,a3],24`, d2 = the first lg_cv index, a3 = the names (pointers), d3 = how many ->
 * "Name function, ..." */
lg_bl:
 mov 0,a2                         /* a2: 0 before the first */
1:
 cmp 0,a2
 beq 2f
 LGS lg_cm
2:
 mov 1,a2
 mov (a3),a0
 call lg_s,[],0
 LGS lg_sp
 mov d2,d0
 asl2 d0
 mov lg_cv,a0
 add d0,a0
 mov (a0),d0
 call lg_fn,[d2,d3],12
 inc d2
 inc4 a3
 add -1,d3
 bne 1b
 ret [d2,d3,a2,a3],24

/* lg_dl: `call lg_dl,[d2,d3,a2,a3],24`, d2 = lg_cv index of P's front dial at this lever position -> "P a / b, A ...,
 * S ..., M ..." (lg_cid: P, A, S, M, each 1 front, 1 rear, 2 front, 2 rear). */
lg_dl:
 clr d3
1:
 cmp 0,d3
 beq 2f
 LGS lg_cm
2:
 mov d3,d0
 asl2 d0
 mov lg_dmn,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 LGS lg_sp
 mov d2,d0
 asl2 d0
 mov lg_cv,a0
 add d0,a0
 mov (a0),d0
 call lg_fn,[d2,d3],12
 LGS lg_sl2
 mov d2,d0
 inc d0
 asl2 d0
 mov lg_cv,a0
 add d0,a0
 mov (a0),d0
 call lg_fn,[d2,d3],12
 add 4,d2
 inc d3
 cmp 4,d3
 bcs 1b
 ret [d2,d3,a2,a3],24

/* lg_pic: `call lg_pic,[d2,d3],12`, a0 = an lg_ring entry -> "FILM n", "COLOR k", or the dial family and the picture
 * mode's number. */
lg_pic:
 mov a0,d2
 movbu (11,a0),d0
 cmp 4,d0
 bcc 3f
 movbu (10,a0),d3
 cmp 0,d3
 beq 2f
 LGS lg_film0
 mov d3,d0
 LGD
 bra 9f
2:
 LGS lg_col
 mov d2,a0
 movbu (11,a0),d0
 inc d0
 LGD
 bra 9f
3:
 movhu (12,a0),d0
 call lg_fm,[d2,d3],12
 LGS lg_sp
 mov d2,a0
 mov (4,a0),d0
 LGD
9:
 ret [d2,d3],12

/* lg_scr: `call lg_scr,[d2,d3],12`, d0 = the GUI state (child << 8 | parent, as LG_GUI) -> a short name. */
lg_scr:
 mov d0,d2
 mov d0,d1
 lsr 8,d1
 and 255,d0
 mov lg_g7,a0
 cmp 1,d0
 bne 1f
 mov lg_g1b,a0
 cmp 8,d1
 bne 8f
 mov lg_g1,a0
 bra 8f
1:
 cmp 2,d0
 bne 2f
 mov lg_g2,a0
 bra 8f
2:
 cmp 3,d0
 beq 21f
 cmp 11,d0
 bne 3f
21:
 mov lg_g3,a0
 bra 8f
3:
 cmp 4,d0
 bne 4f
 mov lg_g4,a0
 cmp 0x18,d1
 bne 31f
 mov lg_g4p,a0
 bra 8f
31:
 cmp 0x17,d1
 bne 32f
 mov lg_g4w,a0
 bra 8f
32:
 cmp 0x16,d1
 bne 8f
 mov lg_g4q,a0
 bra 8f
4:
 cmp 5,d0
 bcs 5f
 cmp 8,d0
 bcc 5f
 mov lg_g5,a0
 bra 8f
5:
 cmp 12,d0
 bne 8f
 mov lg_g6,a0
8:
 call lg_s,[],0
 ret [d2,d3],12

/* lg_nth: `call lg_nth,[],0`, a0 = NUL-separated strings, d0 = an index -> a0 = that string (uses d0, d1). */
lg_nth:
1:
 cmp 0,d0
 beq 3f
2:
 movbu (a0),d1
 inc a0
 cmp 0,d1
 bne 2b
 add -1,d0
 bra 1b
3:
 ret [],0

/* lg_tv: `call lg_tv,[d2,d3],12`, d0 = shutter as APEX Tv x 256 (signed) -> the nearest 1/3 step, 60" .. 1/32000. */
lg_tv:
 mov d0,d2
 cmp -32768,d2                    /* 0x8000: not worked out yet */
 bne 0f
 LGS lg_dash
 bra 9f
0:
 mov d0,d1
 add d1,d0
 add d1,d0
 add 128,d0
 asr 8,d0
 add 18,d0
 cmp 64,d0
 bcc 8f
 mov lg_tvs,a0
 call lg_nth,[],0
 call lg_s,[],0
 bra 9f
8:
 LGS lg_q
 mov d2,d0
 exthu d0
 LGD
9:
 ret [d2,d3],12

/* lg_av: `call lg_av,[d2,d3],12`, d0 = aperture as APEX Av x 256 (signed) -> "f/" the nearest 1/3 step, 1.0 .. 32. */
lg_av:
 mov d0,d2
 cmp -32768,d2
 bne 0f
 LGS lg_dash
 bra 9f
0:
 mov d0,d1
 add d1,d0
 add d1,d0
 add 128,d0
 asr 8,d0
 cmp 31,d0
 bcc 8f
 mov d0,d3
 LGS lg_fs
 mov d3,d0
 mov lg_avs,a0
 call lg_nth,[],0
 call lg_s,[],0
 bra 9f
8:
 LGS lg_fq
 mov d2,d0
 exthu d0
 LGD
9:
 ret [d2,d3],12

/* lg_iso: `call lg_iso,[d2,d3],12`, d0 = the ISO setting (6): 0 Auto, else APEX Sv x 256 (ISO 100 = 1280) -> "ISO n". */
lg_iso:
 mov d0,d2
 LGS lg_iso0
 cmp 0,d2
 bne 1f
 LGS lg_auto
 bra 9f
1:
 mov d2,d0
 add -1280,d0
 mov d0,d1
 add d1,d0
 add d1,d0
 add 128,d0
 asr 8,d0
 add 2,d0
 cmp 33,d0
 bcc 8f
 asl2 d0
 mov lg_isot,a0
 add d0,a0
 mov (a0),d0
 LGD
 bra 9f
8:
 LGS lg_q
 mov d2,d0
 LGD
9:
 ret [d2,d3],12

/* lg_ev: `call lg_ev,[d2,d3],12`, d0 = EV x 256 (signed) -> "+0.3", "-1.0", "0.0". */
lg_ev:
 mov d0,d2
 cmp 0,d2
 beq 3f
 blt 1f
 LGS lg_plus
 bra 3f
1:
 LGS lg_minus
 clr d0
 sub d2,d0
 mov d0,d2
3:
 mov d2,d0
 asl 3,d0
 add d2,d0
 add d2,d0
 add 128,d0
 lsr 8,d0
 clr d1
 mov d1,mdr
 mov 10,d1
 divu d1,d0
 mov mdr,d3
 LGD
 LGS lg_dot
 mov d3,d0
 LGD
 ret [d2,d3],12

/* lg_wbn: `call lg_wbn,[d2,d3],12`, d0 = the WB mode (1578: lg_wbt; 9 Custom), d1 = Custom WB / 100 K -> its name. */
lg_wbn:
 mov d0,d2
 mov d1,d3
 cmp 9,d2
 bne 1f
 LGS lg_cwb
 mov d3,d0
 mov 100,d1
 mul d1,d0
 LGD
 LGS lg_kk
 bra 9f
1:
 mov lg_wbt,a0
2:
 mov (a0),d1
 cmp -1,d1
 beq 3f
 cmp d1,d2
 beq 4f
 add 8,a0
 bra 2b
3:
 LGS lg_wbq
 mov d2,d0
 LGD
 bra 9f
4:
 mov (4,a0),a0
 call lg_s,[],0
9:
 ret [d2,d3],12

/* lg_fn: `call lg_fn,[d2,d3],12`, d0 = a button / dial function code -> its name (lg_fnt), else "[n]". */
lg_fn:
 mov d0,d2
 cmp -1,d2
 bne 0f
 LGS lg_dash
 bra 9f
0:
 mov lg_fnt,a0
1:
 mov (a0),d1
 cmp 0,d1
 beq 2f
 cmp d1,d2
 beq 3f
 add 8,a0
 bra 1b
2:
 LGS lg_lb0
 mov d2,d0
 LGD
 LGS lg_rb
 bra 9f
3:
 mov (4,a0),a0
 call lg_s,[],0
9:
 ret [d2,d3],12

/* lg_pad: `call lg_pad,[d2,d3],12`, d0 = the arrow-pad mode (158 / 1279): 0 Off, 1 [.:.] (AF target), 2 Direct. */
lg_pad:
 mov d0,d2
 cmp -1,d2
 bne 0f
 LGS lg_dash
 bra 9f
0:
 cmp 3,d2
 bcc 8f
 mov d2,d0
 mov lg_pads,a0
 call lg_nth,[],0
 call lg_s,[],0
 bra 9f
8:
 LGS lg_lb0
 mov d2,d0
 LGD
 LGS lg_rb
9:
 ret [d2,d3],12

/* lg_dv: `call lg_dv,[d2,d3],12`, d0 -> decimal, "-" for -1 (not read yet). lg_dvh: the same for a u16 (0xffff). */
lg_dv:
 cmp -1,d0
 bne 1f
 LGS lg_dash
 bra 9f
1:
 LGD
9:
 ret [d2,d3],12
lg_dvh:
 cmp 0xffff,d0
 bne 1f
 LGS lg_dash
 bra 9f
1:
 LGD
9:
 ret [d2,d3],12

/* lg_gx: `call lg_gxv,[d2,d3],12`, d0 = a cached value (-1: not read yet), a0 = lg_tv, lg_av or lg_ev -> that, or "-". */
lg_gxv:
 cmp -1,d0
 bne 1f
 LGS lg_dash
 bra 9f
1:
 exth d0
 cmp lg_tv,a0
 bne 2f
 call lg_tv,[d2,d3],12
 bra 9f
2:
 cmp lg_av,a0
 bne 3f
 call lg_av,[d2,d3],12
 bra 9f
3:
 call lg_ev,[d2,d3],12
9:
 ret [d2,d3],12

/* Kept section text (dl8): START-UP, CUSTOM MODES and BUTTONS AND DIALS change rarely, so each is made only when its
 * inputs (a key of words: lg_kstb / lg_kcmb / lg_kbtb) differ from the last time, and otherwise copied by words from
 * its kept text (ext11). A section starts and ends on a 4-byte boundary (spaces at the ends of lines). */
lg_al4:                           /* `call lg_al4,[],0`: spaces up to a 4-byte boundary (uses d0, d1, a1) */
 mov (lg_cur),a1
 mov 32,d0
1:
 mov a1,d1
 and 3,d1
 beq 2f
 movbu d0,(a1)
 inc a1
 bra 1b
2:
 mov a1,(lg_cur)
 ret [],0
lg_kw:                            /* `call lg_kw,[],0`: d1 words from a0 to a1 (uses d0, d1, a0, a1) */
 cmp 0,d1
 beq 2f
1:
 mov (a0),d0
 mov d0,(a1)
 inc4 a0
 inc4 a1
 add -1,d1
 bne 1b
2:
 ret [],0

/* lg_kc: `call lg_kc,[d2,d3,a2,a3],24`, a3 = a section record {+0 key words, +4 saved key, +8 kept text, +12 room,
 * +16 kept length (0: none)}, lg_key = the key now -> d0 1 when the kept text was copied; else 0 (lg_scs = here). */
lg_kc:
 call lg_al4,[],0
 mov (lg_cur),a1
 mov a1,(lg_scs)
 mov (16,a3),d2
 cmp 0,d2
 beq 8f
 mov (a3),d3
 mov (4,a3),a0
 mov lg_key,a2
1:
 mov (a0),d0
 mov (a2),d1
 cmp d1,d0
 bne 8f
 inc4 a0
 inc4 a2
 add -1,d3
 bne 1b
 mov a1,d0
 add d2,d0
 cmp lg_bend - 8,d0
 bhi 8f
 mov (8,a3),a0
 mov d2,d1
 lsr 2,d1
 call lg_kw,[],0
 mov a1,(lg_cur)
 mov 1,d0
 ret [d2,d3,a2,a3],24
8:
 clr d0
 ret [d2,d3,a2,a3],24

/* lg_ks: `call lg_ks,[d2,d3,a2,a3],24`, a3 = the section record: keeps the text made since lg_scs and lg_key (not when
 * it reached the buffer's end or is longer than its room). */
lg_ks:
 call lg_al4,[],0
 clr d0
 mov d0,(16,a3)
 mov (lg_cur),d2
 cmp lg_bend - 8,d2
 bcc 9f
 mov (lg_scs),a0
 mov a0,d0
 sub d0,d2                        /* its length */
 mov (12,a3),d0
 cmp d0,d2
 bhi 9f
 mov (8,a3),a1
 mov d2,d1
 lsr 2,d1
 call lg_kw,[],0
 mov lg_key,a0
 mov (4,a3),a1
 mov (a3),d1
 call lg_kw,[],0
 mov d2,(16,a3)
9:
 ret [d2,d3,a2,a3],24

lg_stc:                           /* `call lg_stc,[d2,d3,a2,a3],24`: START-UP (lg_top), kept */
 call lg_kstb,[d2,d3,a2,a3],24
 mov lg_sst,a3
 call lg_kc,[d2,d3,a2,a3],24
 cmp 0,d0
 bne 9f
 call lg_top,[d2,d3,a2,a3],24
 mov lg_sst,a3
 call lg_ks,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],24
lg_cmc:                           /* `call lg_cmc,[d2,d3,a2,a3],24`: CUSTOM MODES (cm_txt), kept */
 call lg_kcmb,[d2,d3,a2,a3],24
 mov lg_scm,a3
 call lg_kc,[d2,d3,a2,a3],24
 cmp 0,d0
 bne 9f
 call cm_txt,[d2,d3,a2,a3],24
 mov lg_scm,a3
 call lg_ks,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],24
lg_btc:                           /* `call lg_btc,[d2,d3,a2,a3],24`: BUTTONS AND DIALS (lg_btn), kept; a line only until
                                   * lg_crf has read them all once (else the text changed at every event meanwhile) */
 mov (lg_cful),d0
 cmp 0,d0
 bne 1f
 LGS lg_b5
 bra 9f
1:
 mov lg_cv + 4 * CI_BTN,a0
 mov lg_key,a1
 mov KBT_W,d1
 call lg_kw,[],0
 mov lg_sbt,a3
 call lg_kc,[d2,d3,a2,a3],24
 cmp 0,d0
 bne 9f
 call lg_btn,[d2,d3,a2,a3],24
 mov lg_sbt,a3
 call lg_ks,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],24

/* lg_kstb: `call lg_kstb,[d2,d3,a2,a3],24`: START-UP's inputs -> lg_key (KST_W words): STATE, P's LOOKS / EDITS /
 * code block / guide pictures / NAMES pointers, tg_ptr, the films block's state, each card file's {found, CRC}. */
lg_kstb:
 mov lg_key,a3
 movhu (STATE),d0
 mov d0,(a3)
 call lg_gp,[d3],8
 clr d0
 mov d0,(4,a3)
 mov d0,(8,a3)
 mov d0,(12,a3)
 mov d0,(16,a3)
 mov d0,(20,a3)
 cmp 0,a2
 beq 1f
 mov (LPTR,a2),d0
 mov d0,(4,a3)
 mov (TORG,a2),d0
 mov d0,(8,a3)
 mov (XPTR,a2),d0
 mov d0,(12,a3)
 mov (GPTR,a2),d0
 mov d0,(16,a3)
 mov (NPTR,a2),d0
 mov d0,(20,a3)
1:
 mov (tg_ptr),d0
 mov d0,(24,a3)
 movbu (ub_st),d0
 mov d0,(28,a3)
 movbu (ub_src),d0
 mov d0,(32,a3)
 movbu (ub_ok0),d0
 mov d0,(36,a3)
 movbu (ub_ok),d0
 mov d0,(40,a3)
 mov (ub_gen0),d0
 mov d0,(44,a3)
 mov lg_ft,a0
 add 48,a3
 mov LG_NF,d1
2:
 mov (12,a0),d0
 mov d0,(a3)
 mov (16,a0),d0
 mov d0,(4,a3)
 add 20,a0
 add 8,a3
 add -1,d1
 bne 2b
 movbu (ck_have),d0               /* v0.30 test 10: CURVES.BIN */
 movbu (ck_st),d1
 asl 8,d1
 or d1,d0
 mov d0,(a3)
 mov (ck_nm),d0
 mov d0,(4,a3)
 ret [d2,d3,a2,a3],24

/* lg_kcmb: `call lg_kcmb,[d2,d3,a2,a3],24`: CUSTOM MODES' inputs -> lg_key (KCM_W words): the records' flags, the
 * Save Settings read, OM3C in RAM, OM3S's kept / to-build bytes, the counters, the last 8 mode changes. (Its "after
 * event N" also follows lg_n, which only matters past 256 events.) */
lg_kcmb:
 mov lg_key,a1
 movbu (cm_v0),d0
 movbu (ss_v0),d1
 asl 8,d1
 or d1,d0
 movbu (ss_cur),d1
 asl 16,d1
 or d1,d0
 movbu (ss_ph),d1
 asl 24,d1
 or d1,d0
 mov d0,(a1)
 movbu (cm_code),d0
 movbu (rc_ti),d1
 asl 8,d1
 or d1,d0
 mov d0,(4,a1)
 add 8,a1
 mov lg_cv,a0                     /* Save Settings C1..C5 */
 mov 5,d1
 call lg_kw,[],0
 mov cm_ram,a0
 mov 12,d1                        /* CM_LEN / 4 */
 call lg_kw,[],0
 mov (ss_ram + 12),d0
 mov d0,(a1)
 mov (cm_na),d0
 mov d0,(4,a1)
 mov (cm_sw),d0
 mov d0,(8,a1)
 mov (cm_pms),d0
 mov d0,(12,a1)
 mov (ss_ntr),d0
 mov d0,(16,a1)
 mov (ss_nl),d0
 mov d0,(20,a1)
 mov (ss_ng),d0
 mov d0,(24,a1)
 mov (ss_np),d0
 mov d0,(28,a1)
 mov (ss_nab),d0
 mov d0,(32,a1)
 mov (ss_ne),d0
 mov d0,(36,a1)
 mov (ss_nm),d0
 mov d0,(40,a1)
 mov (ss_ml),d0
 mov d0,(44,a1)
 clr d0                           /* v0.30 test 12: was our first #54 fix's count (rc_turn), replaced by PR #59 */
 mov d0,(48,a1)
 add 52,a1
 mov rc_tr,a0
 mov 8,d1
 call lg_kw,[],0
 ret [d2,d3,a2,a3],24

/* lg_gsn: `call lg_gsn,[d2,d3,a2,a3],24` (better grain g2): NOW's "Film Grain on COLOR 1-4: Off, 3 Medium, ..." (each
 * COLOR's strength 1..5 and Grain Size from gs_eff; Off when its level is 0). */
lg_gsn:
 LGS lg_gz0
 PVAL 9f
 clr d3
1:
 cmp 0,d3
 beq 2f
 LGS lg_cm
2:
 mov d3,d0
 asl 6,d0
 add 32,d0
 mov a2,a0
 add d0,a0
 call gs_eff,[d2,d3,a2],16        /* d0 strength, d1 size */
 cmp 0,d0
 bne 3f
 LGS lg_gz1
 bra 4f
3:
 mov d1,d2
 LGD
 LGS lg_sp
 mov d2,d0
 mov lg_gw,a0
 call lg_nth,[],0
 call lg_s,[],0
4:
 inc d3
 cmp 4,d3
 bcs 1b
9:
 ret [d2,d3,a2,a3],24

/* lg_ckn: `call lg_ckn,[d2,d3,a2,a3],24` (v0.30 test 10): NOW's curves and mix: each COLOR's slot against the
 * built-in of its film (CURVES.BIN, ck_bik; as test 9's ck_txt), then the picture mode's COLOR's 15 curve values (R, G,
 * B x 5 points), its 6 mix values and whether each part follows its film's built-in (the slot's flags). */
lg_ckn:
 LGS lg_q0
 clr d2
1:
 cmp 0,d2
 beq 2f
 LGS lg_cm
2:
 mov d2,d0
 call ck_bik,[],4
 mov a0,a3
 mov d2,d0
 call cv_lk,[],0
 mov a0,a2
 mov a3,a1
 mov CK_BSZ,d1
 call ck_cmp,[d2],8
 mov d0,d3                        /* 1: differs from its film's built-in */
 mov a2,a0
 mov CK_BSZ,d1
 call ck_nz,[],0                  /* 1: has values */
 add d0,d0
 add d3,d0
 mov lg_qw,a0
 call lg_nth,[],0
 call lg_s,[],0
 inc d2
 cmp 4,d2
 bcs 1b
 call lg_new,[],0                 /* the picture mode's COLOR */
 movbu (11,a3),d2
 cmp 4,d2
 bcc 9f
 LGS lg_q1
 mov d2,d0
 inc d0
 LGD
 mov d2,d0
 call cv_lk,[],0
 mov a0,a2
 clr d3
3:
 mov lg_sp,a0
 cmp 0,d3
 bne 31f
 mov lg_q2,a0
 bra 34f
31:
 cmp 5,d3
 bne 32f
 mov lg_q3,a0
 bra 34f
32:
 cmp 10,d3
 bne 33f
 mov lg_q4,a0
 bra 34f
33:
 cmp 15,d3
 bne 34f
 mov lg_q5,a0
34:
 call lg_s,[],0
 mov lg_qo,a0
 add d3,a0
 movbu (a0),d0
 mov a2,a0
 add d0,a0
 movbu (a0),d0
 extb d0
 call lg_sd,[d2,d3],12
 inc d3
 cmp 21,d3
 bcs 3b
 movbu (24,a2),d2                 /* the flags: bit 0 the curves, bit 1 the mix follow the film; bit 7 set */
 btst 0x80,d2
 bne 35f
 LGS lg_q8
 bra 9f
35:
 LGS lg_q6
 mov d2,d0
 and 1,d0
 LGY
 LGS lg_q7
 mov d2,d0
 and 2,d0
 LGY
9:
 ret [d2,d3,a2,a3],24

/* lg_sd: `call lg_sd,[d2,d3],12`, d0 (signed) -> decimal with a "-" when below 0. */
lg_sd:
 cmp 0,d0
 bge 1f
 mov d0,d2
 LGS lg_minus
 clr d0
 sub d2,d0
1:
 LGD
 ret [d2,d3],12

/* lg_h4: `call lg_h4,[],0`: d0 -> 4 hex digits (uses d0, d1, a0, a1). */
lg_h4:
 mov (lg_cur),a1
 mov (lg_lim),d1
 cmp d1,a1
 bcc 3f
 asl 16,d0
 mov 4,a0
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
 mov (4,a3),d1                    /* films in camera memory: LOOKS / EDITS / BUNDLES when the camera has its block */
 cmp 3,d1
 bcs 20f
 movbu (ub_ok),d0
 cmp 0,d0
 beq 20f
 mov (12,a3),d0
 cmp 2,d0
 beq 21f
 mov 9,d0                         /* not on the card: normal */
 ret [],0
21:
 mov 10,d0                        /* LOOKS.BIN on the card */
 cmp 3,d1
 beq 22f
 mov 11,d0                        /* EDITS / BUNDLES on the card: not used */
22:
 ret [],0
20:
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

/* lg_mode: `call lg_mode,[],0` -> d0 the mode's code (the settings object +24 behind the manager's handle: P 1, A 2,
 * S 3, M 4, B 62, C1..C5 53..57, video / S&Q 10 (om-emu); 0 not known yet), d1 the mode dial's position (0 S, 1 A, 2 P,
 * 3..7 C5..C1, 8 B, 9 M) | the photo / movie / S&Q switch (2 / 1 / 0) << 4. Reads only. Uses d0, d1, a0. */
lg_mode:
 movbu (0xa32d9d0d),d1
 asl 4,d1
 movbu (0xa32d9d0c),d0
 and 15,d0
 or d0,d1
 clr d0
 mov (rc_in),a0
 cmp 0,a0
 beq 1f
 movbu (24,a0),d0
1:
 ret [],0

/* lg_mn: `call lg_mn,[d2,d3],12`: d0 = a mode's code, d1 = as lg_mode -> its name: from the code when it names one,
 * else from the mode dial's position; " video" / " S&Q" after it by the switch. */
lg_mn:
 mov d0,d2
 mov d1,d3
 cmp 53,d2
 bcs 1f
 cmp 58,d2
 bcc 1f
 LGS lg_mC
 mov d2,d0
 add -52,d0
 LGD
 bra 5f
1:
 cmp 1,d2
 bcs 3f
 cmp 5,d2
 bcc 2f
 mov d2,d0
 add -1,d0
 asl2 d0
 mov lg_cpt,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 bra 5f
2:
 cmp 62,d2
 bne 3f
 LGS lg_mB
 bra 5f
3:
 mov d3,d0
 and 15,d0
 cmp 10,d0
 bcc 4f
 asl2 d0
 mov lg_dpt,a0
 add d0,a0
 mov (a0),a0
 call lg_s,[],0
 bra 5f
4:
 cmp 10,d2
 bne 41f
 LGS lg_mvq
 bra 6f
41:
 LGS lg_q
5:
 mov d3,d0
 lsr 4,d0
 cmp 1,d0
 bne 51f
 LGS lg_mv
 bra 6f
51:
 cmp 0,d0
 bne 6f
 LGS lg_mq
6:
 ret [d2,d3],12

/* lg_gn: `call lg_gn,[d2,d3],12`: d0 = a group (0..4 C1..C5, 5 P / A / S / M / B, else none) -> its name. */
lg_gn:
 cmp 5,d0
 bcs 1f
 bne 2f
 LGS lg_gP
 bra 9f
2:
 LGS lg_gx
 bra 9f
1:
 mov d0,d2
 LGS lg_mC
 mov d2,d0
 inc d0
 LGD
9:
 ret [d2,d3],12

/* lg_rh: `call lg_rh,[d2,d3],12`: d0 = a custom mode's Save Settings (1880 + n) -> Reset / Hold (else the number). */
lg_rh:
 cmp -1,d0
 bne 0f
 LGS lg_dash
 bra 9f
0:
 cmp 0,d0
 bne 1f
 LGS lg_rst
 bra 9f
1:
 cmp 1,d0
 bne 2f
 LGS lg_hld
 bra 9f
2:
 LGD
9:
 ret [d2,d3],12

/* lg_lk: `call lg_lk,[d2,d3],12`: d0 = COLOR k, d1 = a look (LIDX: 1..5 film 5k + n, 0 its own) -> the film's number,
 * "own", or "-". */
lg_lk:
 extb d1
 cmp 0,d1
 bne 1f
 LGS lg_own
 bra 9f
1:
 cmp 1,d1
 blt 2f
 cmp 5,d1
 bgt 2f
 mov d0,d2
 asl2 d2
 add d0,d2
 add d1,d2
 mov d2,d0
 LGD
 bra 9f
2:
 LGS lg_dash
9:
 ret [d2,d3],12

/* lg_ch: `call lg_ch,[d2,d3],12`: d0 = a group's choice (OM3C: the 901 value, FV0 + j film j, 54 / 55 / 56 / 64
 * COLOR k's own, 0 none) -> "FILM n", "COLOR k", "-" (else the number). */
lg_ch:
 mov d0,d2
 cmp 0,d2
 bne 1f
 LGS lg_dash
 bra 9f
1:
 mov d2,d0
 add -FV0,d0
 cmp 20,d0
 bcc 2f
 mov d0,d3
 LGS lg_film0
 mov d3,d0
 inc d0
 LGD
 bra 9f
2:
 mov d2,d0
 call fl_k,[],0
 cmp 0,d0
 blt 3f
 mov d0,d3
 LGS lg_col
 mov d3,d0
 inc d0
 LGD
 bra 9f
3:
 mov d2,d0
 LGD
9:
 ret [d2,d3],12

/* lg_kf: `call lg_kf,[d2,d3,a3],16`: d0 = COLOR k, a2 = P or 0, a3 = a string to put first (0: none) -> when COLOR k
 * holds a film (LIDX 1..5): a3's string, "FILM n" and its name (LOOKS +1312 + 16 j); d0 = the film j, else -1. */
lg_kf:
 mov d0,d2
 mov -1,d3
 cmp 0,a2
 beq 9f
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d1
 extb d1
 cmp 1,d1
 blt 9f
 cmp 5,d1
 bgt 9f
 mov d2,d3
 asl2 d3
 add d2,d3
 add d1,d3
 add -1,d3                        /* j = 5k + n - 1 */
 cmp 0,a3
 beq 1f
 mov a3,a0
 call lg_s,[],0
1:
 LGS lg_film0
 mov d3,d0
 inc d0
 LGD
 mov (LPTR,a2),a0
 mov d3,d0
 asl 4,d0
 add d0,a0
 add 1312,a0
 movbu (a0),d0
 cmp 0,d0
 beq 9f
 mov (lg_cur),a1
 mov (lg_lim),d1
 cmp d1,a1
 bcc 9f
 mov 32,d0
 movbu d0,(a1)
 inc a1
 mov 16,d1
2:
 movbu (a0),d0
 cmp 0,d0
 beq 3f
 cmp 32,d0                        /* printable ASCII only */
 bcs 21f
 cmp 127,d0
 bcc 21f
 movbu d0,(a1)
 inc a1
21:
 inc a0
 add -1,d1
 bne 2b
3:
 mov a1,(lg_cur)
9:
 mov d3,d0
 ret [d2,d3,a3],16

/* lg_chg: `call lg_chg,[d2,d3,a2,a3],24`, a2 = P (films in), d0 = film j -> d0 1 when it is changed from how it was
 * built, as fl_fch (the camera's '*'): a film on its COLOR k -> fl_live (the camera's values now), else lg_fc (its
 * saved changes). fl_live reads the camera's 18 settings (up to ~11k instructions when nothing differs), so one COLOR
 * per write is asked again (k = lg_w & 3) and the others give their last answer for the same film (at most 3 events
 * old); a film newly on a COLOR is asked at once. */
lg_chg:
 mov d0,a3
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
 beq 3f
 mov a3,d0
 call lg_fc,[d2,d3],12
 ret [d2,d3,a2,a3],24
3:
 mov lg_lv,a0
 add d2,a0
 movbu (a0),d0
 mov a3,d1
 inc d1
 cmp d1,d0
 bne 4f
 mov (lg_w),d0
 and 3,d0
 cmp d2,d0
 beq 4f
 mov lg_lr,a0
 add d2,a0
 movbu (a0),d0
 ret [d2,d3,a2,a3],24
4:
 call fl_live,[d2,d3,a2,a3],24
 mov lg_lr,a0
 add d2,a0
 movbu d0,(a0)
 mov lg_lv,a0
 add d2,a0
 mov a3,d1
 inc d1
 movbu d1,(a0)
 ret [d2,d3,a2,a3],24

/* lg_fc: `call lg_fc,[d2,d3],12`, a2 = P, d0 = film j -> d0 1 when its saved changes (EDITS record j, valid) differ
 * from the film as built in bytes 0..62: fl_fch's own test for a film not on its COLOR, by words when aligned. */
lg_fc:
 mov (TORG,a2),a1
 cmp 0,a1
 beq 8f
 add TWO,a1
 mov 1,d1
 asl d0,d1
 mov (12,a1),d2
 and d1,d2
 beq 8f
 mov d0,d1
 asl 6,d1
 mov d0,d2
 asl2 d2
 add d2,d1
 add 16,d1
 add d1,a1                        /* its saved changes */
 asl 6,d0
 mov (LPTR,a2),a0
 add d0,a0
 add 32,a0                        /* as built */
 mov 63,d3
 mov a0,d0
 mov a1,d1
 or d1,d0
 and 3,d0
 bne 5f
 mov 15,d3                        /* bytes 0..59 by words, then 60..62 */
1:
 mov (a0),d0
 mov (a1),d1
 cmp d1,d0
 bne 7f
 inc4 a0
 inc4 a1
 add -1,d3
 bne 1b
 mov 3,d3
5:
 movbu (a0),d0
 movbu (a1),d1
 cmp d1,d0
 bne 7f
 inc a0
 inc a1
 add -1,d3
 bne 5b
8:
 clr d0
 ret [d2,d3],12
7:
 mov 1,d0
 ret [d2,d3],12

/* lg_gp: `call lg_gp,[d3],8` -> a2 = P (the settings block), or 0. */
lg_gp:
 PVAL 1f
 ret [d3],8
1:
 mov 0,a2
 ret [d3],8

lg_s:                             /* `call lg_s,[],0`: a0 = string -> appended (uses d0, d1, a0, a1); nothing once lg_cur
                                   * is at lg_lim, so a full report never creeps into lg_pon / lg_plog (a string begun
                                   * before it may run on: lg_bend's 256 B, lg_tl's 64; the longest is 120 B) */
 mov (lg_cur),a1
 mov (lg_lim),d1
 cmp d1,a1
 bcc 2f
1:
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
lg_nl:                            /* `call lg_nl,[],0`: CR LF, and the next line starts (uses d0, a0, a1) */
 mov (lg_cur),a1
 mov (lg_lim),d0
 cmp d0,a1
 bcc 1f
 mov 13,d0
 movbu d0,(a1)
 mov 10,d0
 movbu d0,(1,a1)
 add 2,a1
 mov a1,(lg_cur)
1:
 mov a1,(lg_ls)
 ret [],0
lg_tab:                           /* `call lg_tab,[],0`: d0 = a column -> spaces up to it in the line, at least one (uses
                                   * d0, d1, a0, a1) */
 mov (lg_ls),a0
 add d0,a0
 mov (lg_lim),d1
 cmp d1,a0
 bls 1f
 mov d1,a0
1:
 mov (lg_cur),a1
 mov 32,d0
 cmp d1,a1
 bcc 3f
 movbu d0,(a1)
 inc a1
2:
 cmp a0,a1                        /* a1 - a0 */
 bcc 3f
 movbu d0,(a1)
 inc a1
 bra 2b
3:
 mov a1,(lg_cur)
 ret [],0
lg_h:                             /* `call lg_h,[],0`: d0 -> 8 hex digits (uses d0, d1, a0, a1) */
 mov (lg_cur),a1
 mov (lg_lim),d1
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
 cmp 2,d2
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
lg_d:                             /* `call lg_d,[d2,d3],12`: d0 -> unsigned decimal (dl2: by divu; uses d0, d1, a0, a1,
                                   * MDR) */
 mov (lg_cur),a1
 mov (lg_lim),d1
 cmp d1,a1
 bhi 5f
 mov lg_dg + 12,a0                /* the digits, last first */
 mov 10,d2
1:
 clr d1
 mov d1,mdr
 divu d2,d0
 mov mdr,d1
 add 48,d1
 add -1,a0
 movbu d1,(a0)
 cmp 0,d0
 bne 1b
2:
 movbu (a0),d1
 movbu d1,(a1)
 inc a0
 inc a1
 cmp lg_dg + 12,a0
 bcs 2b
 mov a1,(lg_cur)
5:
 ret [d2,d3],12

 .balign 4
lg_stt:
 .long lg_s0, lg_s1
lg_n:                             /* events so far this power-on */
 .long 0
lg_w:                             /* CADLOG.TXT writes this power-on */
 .long 0
/* lg_due (v0.30.3, issue #65's comment by flrvr: with DEBUG.TXT on, the shutter fired late and bursts went on after
 * release, because the whole report was built and written to the card at every half-press and release, in the
 * shutter's own task): `call lg_due,[],0` -> d0 1 to write the file now. Every event is still noted in memory (the
 * ring, the camera's values); the file is written only at a release (never at a half-press, so the shutter is not
 * held up), and not at the release that ends a burst (2 or more photos since that half-press: the burst's end is not
 * held up either); the next qualifying release writes it, with everything noted meanwhile. Uses d0, d1. */
lg_due:
 movbu (lg_rel),d0
 cmp 0,d0
 bne 1f
 mov (lg_np),d0                   /* a half-press: no write; the photo count it starts from */
 mov d0,(lg_npp)
 clr d0
 retf [],0
1:
 mov (lg_np),d0
 mov (lg_npp),d1
 sub d1,d0
 cmp 2,d0
 bcs 2f
 clr d0                           /* a burst's release: no write */
 retf [],0
2:
 mov 1,d0
 retf [],0
 .balign 4
lg_npp:                           /* lg_np at the last half-press */
 .long 0
lg_rel:                           /* this shutter event: 0 half-press, 1 release (lg_pr) */
 .byte 0
 .balign 4
lg_ns:                            /* dl2: saves at shutter events (edits waiting before ed_trig, settings block there) */
 .long 0
lg_cur:
 .long 0
lg_lim:                           /* dl8: where lg_s / lg_d / lg_nl / lg_tab / lg_h / lg_kf stop (lg_bend, or lg_tl's) */
 .long 0
lg_np:                            /* dl8: photos this power-on (ex_fill, once per photo's EXIF) */
 .long 0
lg_cr:                            /* dl8: the next lg_cid entry lg_crf reads */
 .long 0
lg_ls:                            /* dl2: where the line began (lg_nl), for lg_tab */
 .long 0
lg_dg:
 .space 12
lg_lv:                            /* dl2: per COLOR k, the film j + 1 that lg_lr[k] answers for (0: none yet) */
 .space 4
lg_lr:                            /* dl2: per COLOR k, fl_live's last answer */
 .space 4
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
 .long lg_v0, lg_v1, lg_v2, lg_v3, lg_v4, lg_v5, lg_v6, lg_v7, lg_v8, lg_v9, lg_v10, lg_v11
lg_srt:                           /* ub_src: where the films came from */
 .long lg_r0, lg_r1, lg_r2, lg_r3
lg_cpt:                           /* mode codes 1..4 */
 .long lg_mP, lg_mA, lg_mS, lg_mM
lg_dpt:                           /* the mode dial's positions 0..9 */
 .long lg_mS, lg_mA, lg_mP, lg_mC5, lg_mC4, lg_mC3, lg_mC2, lg_mC1, lg_mB, lg_mM
lg_mm:                            /* dl8: card files that do not match (lg_sum) */
 .long 0
lg_fv:                            /* dl8: drive (3265), AF mode (289), image quality (861), -1 until read (lg_cam) */
 .long -1, -1, -1
lg_fid:
 .short 3265, 289, 861
lg_fi:
 .byte 0
 .balign 4
lg_scs:                           /* dl8: where the section being made began (lg_kc / lg_ks) */
 .long 0
lg_pend:                          /* dl8: where the last report's text ended (0: no report yet) */
 .long 0
lg_cful:                          /* dl8: lg_crf has read every lg_cid once */
 .long 0
lg_sst:                           /* dl8: section records {key words, saved key, text, room, cached length} */
 .long KST_W, lg_kst, lg_tst, 1024, 0
lg_scm:
 .long KCM_W, lg_kcm, lg_tcm, 2048, 0
lg_sbt:
 .long KBT_W, lg_kbt, lg_tbt, 1024, 0
lg_cid:                           /* dl8: the settings lg_crf reads into lg_cv, a few per event (sget, read only):
                                   * 0..4 Save Settings C1..C5 (1880..1884); 5 metering (1), 6 flash (16), 7 flash comp
                                   * (17), 8 stabiliser (157), 9 aspect (269), 10 face / eye (1712), 11 AF target (85),
                                   * 12 video quality (2236), 13 the quick panel's item 1714, 14 movie WB (1579), 15 the
                                   * Fn lever (534), 16 / 19 the arrow pad photo / video (158 / 1279), 17 / 18 shutter /
                                   * aperture as set (1699 / 1697); 20.. photo buttons Fn, REC, |o|, CP, AF-ON, up, left,
                                   * right, down, Delete, L-Fn; 31.. the Creative Dial rows CRT, ART, COLOR, MONO; 35..
                                   * video buttons (same order); 46.. dials P, A, S, M x {lever 1 front, rear, lever 2
                                   * front, rear} (research/BUTTONS.md) */
 .short 1880, 1881, 1882, 1883, 1884, 1, 16, 17, 157, 269, 1712, 85, 2236, 1714, 1579, 534, 158, 1699, 1697, 1279
 .short 47, 48, 1292, 49, 1964, 50, 52, 53, 51, 570, 56
 .short 571, 54, 55, 1966
 .short 1272, 1273, 1278, 1274, 1965, 1280, 1282, 1283, 1281, 1276, 1291
 .short 70, 71, 1302, 1303, 72, 73, 1306, 1307, 74, 75, 1304, 1305, 76, 77, 1308, 1309
 .short 107                       /* 62: Custom WB, K */
 .balign 4
lg_cv:                            /* -1 = not read yet (loaded with the image at power-on) */
 .fill LG_NC, 4, 0xffffffff
lg_bn:                            /* button names, lg_cid's order */
 .long lg_bn0, lg_bn1, lg_bn2, lg_bn3, lg_bn4, lg_bn5, lg_bn6, lg_bn7, lg_bn8, lg_bn9, lg_bn10
lg_dpn:                           /* the Creative Dial's positions */
 .long lg_n4, lg_n3, lg_n1, lg_n2
lg_dvn:                           /* a dial row's choice (DV1 + 0..4) */
 .long lg_dv0, lg_n4, lg_n3, lg_n1, lg_n2
lg_dmn:                           /* the modes of the dial functions */
 .long lg_mP, lg_mA, lg_mS, lg_mM
lg_wbt:                           /* WB (1578 / 1579) -> name (research/NOTES.md, "Film WB"); 9 Custom: lg_wb */
 .long 0, lg_wb0, 1, lg_wb1, 3, lg_wb3, 6, lg_wb6, 7, lg_wb7, 8, lg_wb8, 13, lg_wb13, 14, lg_wb14, 15, lg_wb15
 .long 16, lg_wb16, 17, lg_wb17, 18, lg_wb18, -1
lg_fnt:                           /* button / dial function codes -> name (research/BUTTONS.md; the rest as numbers) */
 .long 3200, lg_fn0, 3333, lg_fn0, 3341, lg_fn1, 9, lg_fn2, 6, lg_fn3, 16, lg_fn4, 3265, lg_fn5, 88, lg_fn6
 .long 85, lg_fn7, 3409, lg_fn8, 425, lg_fn9, 1356, lg_fn10, 3348, lg_mC1, 3457, lg_mC1, 86, lg_fn11
 .long 1697, lg_fn13, 1699, lg_fn12, 2, lg_fn1, 17, lg_fn14, 1701, lg_fn2, 1578, lg_fn3, 0
lg_isot:                          /* ISO in 1/3 steps from 64 (Sv x 256 - 1280) x 3 / 256 + 2 */
 .long 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000, 40000, 51200, 64000, 80000, 102400
lg_tvs:                           /* shutter in 1/3 steps, 60" (Tv -6) .. 1/32000 (Tv 15) */
 .ascii "60\"\00050\"\00040\"\00030\"\00025\"\00020\"\00015\"\00013\"\00010\"\0008\"\0006\"\0005\"\0004\"\0003.2\"\0002.5\"\0002\"\0001.6\"\0001.3\"\0001\"\0001/1.3\0001/1.6\0001/2\0001/2.5\0001/3\0001/4\0001/5\0001/6\0001/8\0001/10\0001/13\0001/15\0001/20\0001/25\0001/30\0001/40\0001/50\0001/60\0001/80\0001/100\0001/125\0001/160\0001/200\0001/250\0001/320\0001/400\0001/500\0001/640\0001/800\0001/1000\0001/1250\0001/1600\0001/2000\0001/2500\0001/3200\0001/4000\0001/5000\0001/6400\0001/8000\0001/10000\0001/12800\0001/16000\0001/20000\0001/25600\0001/32000\000"
lg_avs:                           /* f-number in 1/3 steps, f/1.0 (Av 0) .. f/32 (Av 10) */
 .ascii "1.0\0001.1\0001.2\0001.4\0001.6\0001.8\0002.0\0002.2\0002.5\0002.8\0003.2\0003.5\0004.0\0004.5\0005.0\0005.6\0006.3\0007.1\0008.0\0009.0\00010\00011\00013\00014\00016\00018\00020\00022\00025\00029\00032\000"
 .balign 4
lg_hdr:
 .space 16
 .balign 16
lg_ring:                          /* 32 x 48 B {u32 number, u32 picture mode, u8 edits waiting, u8 save result (255 =
                                   * no P), u8 film 1..20 (0 = none), u8 COLOR k (255 = none), u16 the Creative Dial's
                                   * family (897), u8 the mode's code, u8 the mode dial's position | the switch << 4
                                   * (lg_mode); dl8 (lg_cam): +16 s16 shutter (4000) and +18 aperture (4001) at the
                                   * half-press, +20 ISO (6), +22 exp comp (2), +24 u8 WB (1578 / movie 1579), +25 Custom
                                   * WB / 100 K (107), +26 drive (3265), +28 AF mode (289), +30 image quality (861), +32
                                   * the screen (GUI state), +34 photos so far (lg_np)} */
 .space 32 * 48
lg_buf:
 .space 9216                       /* v0.30 test 10: 8192 -> 9216 (curves / CURVES.BIN / #54 lines) */
lg_bend:                          /* lg_s / lg_d / lg_kf / lg_h / lg_nl / lg_tab write nothing once at lg_bend; one
                                   * begun before it may run on, at most 117 B (lg_s's longest string) */
 .space 256
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
 .asciz "\r\nWritten at shutter button event "
lg_t3:
 .asciz " (a half-press and its release count one each); log writes this power-on: "
lg_t4:
 .asciz "\r\n\r\nSTART-UP (this power-on)\r\nSettings block: "
lg_found:
 .asciz "found"
lg_miss:
 .asciz "missing (state "
lg_k0:
 .asciz ")"
lg_u1:
 .asciz "\r\nFilms: "
lg_u0:
 .asciz "not read yet (the first half-press loads them)"
lg_r0:
 .asciz "from the camera's memory"
lg_r1:
 .asciz "from the card (films the camera never had)"
lg_r2:
 .asciz "from the card (first time: nothing in the camera yet)"
lg_r3:
 .asciz "none (no films on the card or in the camera)"
lg_u2:
 .asciz "; films block in camera memory at power-on: "
lg_u3:
 .asciz "none or not valid"
lg_u4:
 .asciz "valid, generation "
lg_k1:
 .asciz "\r\nLoaded: films (LOOKS) "
lg_k5:
 .asciz ", film changes and pictures (EDITS) "
lg_k4:
 .asciz ", TONES "
lg_k2:
 .asciz "\r\nLoaded: GUIDES code block "
lg_k3:
 .asciz ", guide pictures "
lg_k6:
 .asciz ", NAMES.BIN (optional) "
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
lg_n1:
 .asciz "COLOR"
lg_n2:
 .asciz "MONO"
lg_n3:
 .asciz "ART"
lg_n4:
 .asciz "CRT"
lg_n5:
 .asciz "898 (not a dial position)"
lg_c0:
 .asciz "\r\nCard files: "
lg_c1:
 .asciz "all match this firmware"
lg_c2:
 .asciz "MISMATCH - see the lines marked MISMATCH or MISSING"
lg_c6:
 .asciz "\r\n  "
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
lg_v9:
 .asciz "not needed (kept in the camera's memory)"
lg_v10:
 .asciz "on the card (the camera takes only films it never had)"
lg_v11:
 .asciz "on the card, not used (kept in the camera's memory)"
lg_w0:
 .asciz "\r\n\r\nNOW\r\nShooting mode: "
lg_w1:
 .asciz " (mode code "
lg_w1b:
 .asciz " (code "
lg_w2:
 .asciz ", mode dial position "
lg_w3:
 .asciz ", photo / movie / S&Q switch "
lg_w4:
 .asciz "; Save Settings: "
lg_w5:
 .asciz "\r\nPicture mode: "
lg_col:
 .asciz "COLOR "
lg_cm:
 .asciz ", "
lg_pmn:
 .asciz "picture mode "
lg_w6:
 .asciz " (setting 111 = "
lg_w7:
 .asciz "); Creative Dial: "
lg_w8:
 .asciz "\r\nCOLOR 1-4: no films loaded"
lg_w9:
 .asciz "\r\nCOLOR "
lg_wa:
 .asciz "its own settings, no film"
lg_wb:
 .asciz "\r\nFilms with changes (a * in the camera): "
lg_none:
 .asciz "none"
lg_k7:
 .asciz "\r\nEditor opened since power-on: "
lg_x0:
 .asciz "\r\n\r\nSAVES (this power-on)\r\nEdits waiting to be saved: "
lg_k9:
 .asciz "; last save result: "
lg_nb:
 .asciz "- (no settings block)"
lg_x1:
 .asciz "; saves at shutter events: "
lg_x2:
 .asciz "\r\nFilms block in camera memory: writes "
lg_x3:
 .asciz ", generation now "
lg_x4:
 .asciz "; held back for the camera's own save: "
lg_x5:
 .asciz " (its changed byte: "
lg_x6:
 .asciz "\r\nCustom-mode record (OM3C): writes "
lg_x7:
 .asciz ", held back: "
lg_x8:
 .asciz "; per-mode record (OM3S): writes "
lg_x9:
 .asciz ", not written yet: "
lg_xa:
 .asciz "\r\nFilms put back after a shooting-mode change: "
lg_xb:
 .asciz " (camera settings written: "
lg_xc:
 .asciz "); waiting for the next screen event: "
cm_s1:
 .asciz "\r\n\r\nCUSTOM MODES (records valid at the first look: custom modes "
cm_s2:
 .asciz ", per-mode settings "
cm_s3:
 .asciz "Mode       Save Settings  Films on COLOR 1-4  Picture mode Own copy"
cm_s4:
 .asciz "not assigned"
cm_s5:
 .asciz "not kept yet"
cm_s6:
 .asciz "to build from the films"
cm_s7:
 .asciz "not yet"
lg_kept:
 .asciz "kept"
lg_dash:
 .asciz "-"
lg_sp:
 .asciz " "
lg_own:
 .asciz "own"
cm_s8:
 .asciz "\r\nNow: group "
cm_s9:
 .asciz " (last look: mode code "
cm_s9b:
 .asciz " (last look: mode dial position "
cm_sa:
 .asciz "); per-mode set "
cm_sb:
 .asciz " (photo check: mode code "
cm_sbb:
 .asciz " (photo check: switch position "
cm_sc:
 .asciz "\r\nThis power-on: Assigns "
cm_sd:
 .asciz ", films switched "
cm_se:
 .asciz ", picture modes set "
ss_s6:
 .asciz "\r\nPer-mode settings: entries on the camera's own values "
ss_s7:
 .asciz ", sets made "
ss_s8:
 .asciz ", COLOR rows put back "
ss_s9:
 .asciz ", sets saved "
ss_s11:
 .asciz ", built from the films "
ss_s14:
 .asciz ", film changes swapped in "
ss_s12:
 .asciz "\r\nCamera COLOR values that differed from a Reset custom mode's own: "
ss_s13:
 .asciz " (last: set "
ss_s15:
 .asciz ", COLOR "
ss_s16:
 .asciz ", setting "
cm_sf:
 .asciz "\r\nLast shooting-mode changes (newest first):"
cm_sg:
 .asciz "  after event "
cm_sh:
 .asciz " (dial position "
cm_si:
 .asciz ") -> "
cm_sj:
 .asciz ", first look after the films loaded"
cm_sk:
 .asciz ", films switched "
cm_sl:
 .asciz ", picture mode set"
lg_t7:
 .asciz "\r\n\r\nLAST 32 SHUTTER BUTTON EVENTS (newest first; Drv/AF/Qual: camera codes; Ed: edits waiting; Sv: save result, 1 saved)"
lg_e0:
 .asciz "#      Mode     Screen  Shutter Aper. ISO       EC   WB         Picture  Drv/AF/Qual  Ed  Sv Photos"
lg_e1:
 .asciz "#"
lg_film:
 .asciz " FILM "
lg_film0:
 .asciz "FILM "
lg_yes:
 .asciz "yes"
lg_no:
 .asciz "no"
lg_s0:
 .asciz " (none yet)"
lg_s1:
 .asciz " (saved)"
lg_mC:
 .asciz "C"
lg_mP:
 .asciz "P"
lg_mA:
 .asciz "A"
lg_mS:
 .asciz "S"
lg_mM:
 .asciz "M"
lg_mB:
 .asciz "B"
lg_mC1:
 .asciz "C1"
lg_mC2:
 .asciz "C2"
lg_mC3:
 .asciz "C3"
lg_mC4:
 .asciz "C4"
lg_mC5:
 .asciz "C5"
lg_mv:
 .asciz " video"
lg_mq:
 .asciz " S&Q"
lg_mvq:
 .asciz "video / S&Q"
lg_q:
 .asciz "?"
lg_gP:
 .asciz "P/A/S/M/B"
lg_gx:
 .asciz "none"
lg_rst:
 .asciz "Reset"
lg_q0:
 .asciz "\r\nCurves / mix on COLOR 1-4: "
lg_gz0:                           /* better grain g2 */
 .asciz "\r\nFilm Grain on COLOR 1-4: "
lg_gz1:
 .asciz "Off"
lg_gw:
 .ascii "Fine\000Medium\000Coarse\000"
lg_qw:
 .ascii "none\000none (its film has some)\000its film's\000changed\000"
lg_q1:
 .asciz "\r\nCOLOR "
lg_q2:
 .asciz " curves R "
lg_q3:
 .asciz ", G "
lg_q4:
 .asciz ", B "
lg_q5:
 .asciz "; mix "
lg_q6:
 .asciz "; following its film's built-in: curves "
lg_q7:
 .asciz ", mix "
lg_q8:
 .asciz " (a slot from before test 9: no follow marks)"
lg_q9:
 .asciz "\r\nCURVES.BIN (each film's built-in curves and mix): in camera memory: "
lg_qa:
 .asciz "; this power-on's card: "
lg_qb:
 .asciz "; films it matches: "
lg_qc:
 .asciz "\r\nCURVES.BIN: writes to camera memory "
lg_qst:
 .ascii "none\000taken\000the same\000not valid\000"
lg_qo:                            /* the slot's bytes of the 15 curve values (curvesfile.inc ck_map), then the 6 mix */
 .byte 0, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
lg_hld:
 .asciz "Hold"
lg_y0:
 .asciz "\r\n\r\nSUMMARY\r\nNow: "
lg_y1:
 .asciz ", exp comp "
lg_y2:
 .asciz ", WB "
lg_y3:
 .asciz "; "
lg_y4:
 .asciz "; screen: "
lg_y5:
 .asciz "\r\nFilms: "
lg_y6:
 .asciz "; card files: "
lg_y6b:
 .asciz " not matching this firmware (START-UP)"
lg_y7:
 .asciz "; saves at shutter events: "
lg_y8:
 .asciz "\r\nPhotos taken this power-on: "
lg_y9:
 .asciz "; shooting-mode changes: "
lg_ya:
 .asciz "; custom modes with films: "
lg_yb:
 .asciz "\r\nLook at: "
lg_la0:
 .asciz "no settings block"
lg_la1:
 .asciz "card files"
lg_la2:
 .asciz "no films"
lg_la3:
 .asciz "films block write held back"
lg_la4:
 .asciz "custom-mode record held back"
lg_la5:
 .asciz "per-mode record not written yet"
lg_la6:
 .asciz "films waiting to be put back"
lg_la7:
 .asciz "a Reset custom mode's values differ"
lg_la8:
 .asciz "nothing unusual"
lg_z0:
 .asciz "\r\n\r\nCAMERA (its own settings, read only; [n] = the camera's own code)\r\nExposure at the last half-press: "
lg_z1:
 .asciz "; as set: shutter "
lg_z1b:
 .asciz ", aperture "
lg_z2:
 .asciz "\r\n"
lg_z2b:
 .asciz ", exp comp "
lg_z2c:
 .asciz ", flash comp "
lg_z3:
 .asciz "\r\nWhite balance: "
lg_z3b:
 .asciz "], Custom WB setting "
lg_z3c:
 .asciz " K; video WB ["
lg_z4:
 .asciz "\r\nDrive ["
lg_z4b:
 .asciz "], AF mode ["
lg_z4c:
 .asciz "], AF target ["
lg_z4d:
 .asciz "], face / eye ["
lg_z4e:
 .asciz "], metering ["
lg_z5:
 .asciz "]\r\nFlash ["
lg_z5b:
 .asciz "], stabiliser ["
lg_z5c:
 .asciz "], aspect ["
lg_z5d:
 .asciz "], image quality ["
lg_z5e:
 .asciz "], video quality ["
lg_z5f:
 .asciz "], quick-panel item 1714 ["
lg_z6:
 .asciz "\r\nFn lever ["
lg_z6b:
 .asciz "] (8 = position 2); arrow pad: photo "
lg_z6c:
 .asciz ", video "
lg_z7:
 .asciz "\r\nScreen at this event: "
lg_b0:
 .asciz "\r\n\r\nBUTTONS AND DIALS (read a few at each event, each at most 16 events old)\r\nPhoto buttons: "
lg_b1:
 .asciz "\r\nVideo buttons: "
lg_b5:
 .asciz "\r\n\r\nBUTTONS AND DIALS: not all read yet (a few at each event, all by the 16th)"
lg_b2:
 .asciz "\r\nCreative Dial rows (ours): "
lg_b3:
 .asciz "\r\nDials (front / rear), Fn lever position 1: "
lg_b4:
 .asciz "\r\nDials (front / rear), Fn lever position 2: "
lg_bn0:
 .asciz "Fn"
lg_bn1:
 .asciz "REC"
lg_bn2:
 .asciz "|o|"
lg_bn3:
 .asciz "CP"
lg_bn4:
 .asciz "AF-ON"
lg_bn5:
 .asciz "Up"
lg_bn6:
 .asciz "Left"
lg_bn7:
 .asciz "Right"
lg_bn8:
 .asciz "Down"
lg_bn9:
 .asciz "Delete"
lg_bn10:
 .asciz "L-Fn"
lg_dv0:
 .asciz "Normal"
lg_fn0:
 .asciz "Off"
lg_fn1:
 .asciz "Exp comp"
lg_fn2:
 .asciz "WB"
lg_fn3:
 .asciz "ISO"
lg_fn4:
 .asciz "Flash"
lg_fn5:
 .asciz "Drive"
lg_fn6:
 .asciz "MF"
lg_fn7:
 .asciz "AF area"
lg_fn8:
 .asciz "e-zoom"
lg_fn9:
 .asciz "Touch lock"
lg_fn10:
 .asciz "Focus stacking"
lg_fn11:
 .asciz "Ps"
lg_fn12:
 .asciz "Aperture"
lg_fn13:
 .asciz "Shutter"
lg_fn14:
 .asciz "Flash comp"
lg_wb0:
 .asciz "Auto"
lg_wb1:
 .asciz "Tungsten"
lg_wb3:
 .asciz "Fluorescent"
lg_wb6:
 .asciz "Sunny"
lg_wb7:
 .asciz "Cloudy"
lg_wb8:
 .asciz "Shade"
lg_wb13:
 .asciz "1-touch 1"
lg_wb14:
 .asciz "1-touch 2"
lg_wb15:
 .asciz "1-touch 3"
lg_wb16:
 .asciz "1-touch 4"
lg_wb17:
 .asciz "Flash"
lg_wb18:
 .asciz "Underwater"
lg_cwb:
 .asciz "CWB "
lg_kk:
 .asciz "K"
lg_wbq:
 .asciz "WB "
lg_iso0:
 .asciz "ISO "
lg_auto:
 .asciz "Auto"
lg_fs:
 .asciz "f/"
lg_fq:
 .asciz "f/?"
lg_plus:
 .asciz "+"
lg_minus:
 .asciz "-"
lg_dot:
 .asciz "."
lg_sl:
 .asciz "/"
lg_sl2:
 .asciz " / "
lg_lb:
 .asciz " ["
lg_lb0:
 .asciz "["
lg_rb:
 .asciz "]"
lg_pads:
 .ascii "Off\000[.:.]\000Direct Function\000"
lg_g1:
 .asciz "shoot"
lg_g1b:
 .asciz "camera"
lg_g2:
 .asciz "set"
lg_g3:
 .asciz "menu"
lg_g4:
 .asciz "panel"
lg_g4p:
 .asciz "picmode"
lg_g4w:
 .asciz "WB"
lg_g4q:
 .asciz "quality"
lg_g5:
 .asciz "play"
lg_g6:
 .asciz "edit"
lg_g7:
 .asciz "other"

/* dl8: the 32 stored event lines and the line being made (v0.30 test 10: all of the log in ext13) */
 .balign 4
lg_lines:
 .space 32 * LSLOT
lg_tl:
 .space LSLOT + 64
lg_key:                           /* dl8: the key being built (lg_kst / lg_kcm / lg_kbt) */
 .space 4 * 64
lg_kst:
 .space 4 * KST_W
lg_kcm:
 .space 4 * KCM_W
lg_kbt:
 .space 4 * KBT_W
lg_tst:                           /* the kept text of START-UP, CUSTOM MODES, BUTTONS AND DIALS */
 .space 1024
lg_tcm:
 .space 2048
lg_tbt:
 .space 1024
.section .ext12,"ax"

/* ---------------------------------------------------------------- v0.27 Creative Dial mapping (feature/v0.27-buttons)
 * The dial sets sid 897 (the picture-mode family) through the facade SetValue (camera dl8 + om-emu trace, 2026-11-10):
 * CRT 900, ART 899, COLOR 901, MONO 988. For a mapped position: 897 <- 901 (COLOR) through the manager, then 901 <- the
 * target through fl_set, as the Picture Mode list does (same SetValue: a0 inner, a1 mode; frame 68). Unmapped: stock.
 * dm_map per position (CRT, ART, COLOR, MONO): 0 stock, 1..4 COLOR k, 11..30 FILM 1..20.
 * Not yet: power-on (the start-up path sets 897 without the facade), MONO targets, the Control Panel setting. */
.section .ext12,"ax"
sx_set:                           /* from sl_set (entered as the manager: d0 id, d1 value, a0, a1; frame 68) */
 mov a0,(rc_in)                   /* v0.30-dev k1 (#41): the manager's own handle (one per power-on), for rc_put */
 cmp 1440,d0                      /* k2: 1440 closes every mode-dial change (om-emu: ... 682, [162], 2188, 1440, */
 bne 0f                           /* 2136 / 2137), after the camera swapped COLOR 1..4's settings for the mode's own
                                   * (a photo C mode assigned in P keeps 162 at P's 76: k1's 162 missed it); with the
                                   * films in, rc_go re-applies them */
 mov d1,d2                        /* the value (d2 / d3 are free here, as below) */
 mov a1,d3                        /* the mode */
 clr d0                           /* a mode-dial turn: the camera's start-up is over (it writes no 1440 before the */
 movbu d0,(el_hold)               /* first shutter event, bp1), so the films follow the dial now */
 call dm_ok,[],0                  /* films loaded? (d1; d0, a0, a1 kept) */
 cmp 0,d1
 beq 01f
 call rc_go,[d2,d3,a2,a3],24      /* k4: now, in the camera's own mode-change step (task 165, where dm_turn already
                                   * switches films at 897), not at a later GUI event: on the camera the GUI got no
                                   * event until a half-press (k3: "it switches after a half-press") */
01:
 mov 1440,d0
 mov d2,d1
 mov (rc_in),a0
 mov d3,a1
 mov (68,sp),d2                   /* MDR = the setter's return address again, as fl_set leaves it */
 mov d2,mdr
 jmp sl_set0                      /* 1440 itself: stock */
0:
 cmp 901,d0
 bne 1f
 mov 1,d2                         /* a picture-mode change: the group's settings are kept at the next GUI event */
 movbu d2,(el_pk)                 /* (gx_map), not only at the next shutter event */
 movbu (cm_ram + CM_LAST),d2      /* k3 / k6: the group's choice now (the picture mode the camera sets is not the */
 cmp 0xff,d2                      /* mode's own after a dial change: noted here, as it is set, not afterwards) */
 beq 02f
 mov d1,d3
 add -8,sp                        /* (0) call slot, (4) a0 */
 mov a0,(4,sp)
 call cm_gnow,[],0
 mov (4,sp),a0
 add 8,sp
 mov d3,d1
 cmp d2,d0
 bne 04f                          /* a live dial turn not yet looked at (rc_go waits for the code, #54): the camera
                                   * sets the new mode's picture mode, which is not the group's choice */
 movbu d1,(cm_gpm)
 bra 03f
04:
 call lv_due,[d2,d3],12           /* #54: and the label shows no picture until the switch (d1, a0, a1 kept) */
03:
 mov 901,d0
02:
 add -16,sp                       /* dr5: the dial position on COLOR keeps this choice (dm_rec); */
 mov a0,(4,sp)                    /* dr6: all on the stack (the camera's dial handler and the power-on */
 mov a1,(8,sp)                    /* mapping may run here at the same time) */
 mov d1,(12,sp)
 call dm_rec,[d2,d3,a2,a3],36     /* a0 / a1 / d1 as they are */
 mov (4,sp),a0
 mov (8,sp),a1
 mov (12,sp),d1
 add 16,sp
 mov 901,d0
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
 add -16,sp                       /* (0) call slot, (4) a0, (8) a1, (12) the position before (k5) */
 mov a0,(4,sp)
 mov a1,(8,sp)
 movbu (dm_pos),d0
 mov d0,(12,sp)
 call dm_turn,[d2,d3,a2,a3],24    /* -> d0 = the mode 0..3 (CRT, ART, COLOR, MONO), d1 = its COLOR choice or 0 */
 mov (4,sp),a0
 mov (8,sp),a1
 mov (12,sp),d3
 add 16,sp
 cmp 2,d0
 beq 43f
 mov dm_fam,a3                    /* not COLOR: that mode's family, the stock way */
 asl2 d0
 add d0,a3
 mov 897,d0
 mov (a3),d1
 jmp sl_set0
43:
 cmp 0,d1
 beq 44f                          /* COLOR, nothing remembered yet: as it is */
 cmp d2,d3                        /* k5 (#41): its choice comes back only when the Creative Dial really moved: 897 is */
 beq 44f                          /* also written at every half-press and mode-dial change, where it put its old film */
 cmp 0xff,d3                      /* back over the custom mode's; the first 897 after a power-on: as before, unless */
 bne 45f                          /* the custom modes keep films (theirs decide then) */
 add -12,sp
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov d1,d3
 call cm_ld,[d2,d3,a2,a3],20
 mov (4,sp),a0
 mov (8,sp),a1
 add 12,sp
 mov d3,d1
 movbu (cm_ram + CM_FL),d0
 cmp 0,d0
 bne 44f
45:
 mov d1,d3
 bra 55f
44:
 mov 897,d0
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
/* dm_turn: `call dm_turn,[d2,d3,a2,a3],24`, d2 = the position the dial is on now (0..3: CRT, ART, COLOR, MONO) ->
 * d0 = its mode (0..3), d1 = the COLOR choice it keeps (dm_cur code, 0 none). Reads only: no setting is written here
 * (dr4 on the camera: writing settings from the power-on path made the start slow and once froze it). The choices are
 * written when the owner changes the COLOR choice (dm_rec, from the SetValue(901) in sx_set). */
dm_turn:                          /* frame 24: (4) the mode */
 movbu d2,(dm_pos)
 mov d2,d3
 call dm_mode,[d2,d3],12
 mov d0,(4,sp)
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
 mov (4,sp),d0
 ret [d2,d3,a2,a3],24

/* dm_rec: `call dm_rec,[d2,d3,a2,a3],36` from sx_set's SetValue(901, d1) before fl_set (a0 / a1 its own):
 * when the dial's position (dm_pos, known after the first dial event or the power-on mapping) is on COLOR, its own
 * choice = this value (COLOR k -> k + 1, film j -> 11 + j), written to its dm_psid setting if it changed. */
dm_rec:                           /* frame 36: (4) a0, (8) a1 of the SetValue, (12) tid, (16) d1 */
 mov a0,(4,sp)
 mov a1,(8,sp)
 movbu (el_hold),d0               /* after the early load, before the first shutter event: a menu pick (GUI task) only, */
 cmp 0,d0                         /* never a camera start-up write */
 beq 01f
 mov d1,(16,sp)
 mov sp,a0
 add 12,a0
 call get_tid,[a2],4
 mov (16,sp),d1
 cmp 0,d0
 bne 9f
 movhu (12,sp),d0
 movhu (el_tid),d3
 cmp d3,d0
 bne 9f
 mov 1,d0
 movbu d0,(el_pick)
 clr d0                           /* a menu pick: the camera's start-up is over, the first look (gx_map) need not */
 movbu d0,(el_hold)               /* wait for a shutter event */
01:
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
 mov (4,sp),a0
 mov (8,sp),a1
 call dm_put,[d2,d3,a2,a3],80
9:
 ret [d2,d3,a2,a3],36

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

/* dm_put: `call dm_put,[d2,d3,a2,a3],80`, d0 = a setting, d1 = its value, a0 / a1 = the SetValue's: through the
 * manager (as sx_set's own family write) */
dm_put:
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
                                   * (PVAL's checks with d1 / a1; d0, a0 and a1 kept: a1 is the SetValue's mode).
                                   * dr6: a1 on the stack, not in a global (two tasks may be here at once) */
 add -4,sp
 mov a1,(0,sp)
 movbu (el_hold),d1               /* L1: not after the early load until the first shutter event (the camera's own */
 cmp 0,d1                         /* start-up writes) */
 bne 9f
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
 mov (0,sp),a1
 add 4,sp
 ret [],0
9:
 clr d1
 mov (0,sp),a1
 add 4,sp
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
/* dm_boot (dr3..dr6: the power-on mapping) removed in dr7: with the dial moved while off, every version of it hung
 * the camera at power-on (dr3 / dr5 / dr6 on the camera). A half-press or a dial turn applies the mapping. */
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
 .set NDG, 12
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
 jmp cr_ic                        /* crop modes: our labels (crop.s), then ic_get */
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
ar_pay:                           /* the ▲ / ◀ / ▲◀▶▼ / dial-row picture streams (build.py fills them: 19061 B in v0.27.1;
                                   * v0.28 space: was 81920, sized to fit, build.py asserts they still fit) */
 .space 20480
ar_pend:
 .balign 4
dl_keys:                          /* the stock key table plus Delete's record (build.py fills it) */
 .space 16 * 29
dl_kend:
dl_full:                          /* the stock full-button press list plus Delete's (build.py fills it) */
 .space 4 * 16
dl_fend:
dl_oks:                           /* the stills Button Function's OK entries plus Delete's (build.py fills it) */
 .space 24 * 16
dl_moks:                          /* the movie Button Function's OK entries plus Delete's (build.py fills it) */
 .space 24 * 16
dl_mitems:                        /* the movie rows' item-info records plus Delete's, 28 B each (build.py) */
 .space 28 * 10
dl_mrows:                         /* the movie Button Function rows plus Delete's (build.py) */
 .space 2 * 10
 .balign 4
 .set DL_SID, 570
 .set DL_MSID, 1276
 .set DL_PRESS, 0x1000026          /* Delete's press event (its release is + 1) */
 .set DL_IC, 14135                /* the camera's trash picture, as on its name-entry screens */
 .set DL_OTHER, 3333              /* the other body's default, no function and not in Fn's list */
dl_get:                           /* from sl_get (d0 DL_SID / DL_MSID, a1 -> the value; `rets`): DL_OTHER reads
                                   * None, so the picker finds the value in its list */
 add -12,sp                       /* (0) call slot, (4) a1, (8) mdr */
 mov a1,(4,sp)
 mov mdr,d1
 mov d1,(8,sp)
 call sget,[],4
 mov (8,sp),d1
 mov d1,mdr
 mov (4,sp),a1
 add 12,sp
 cmp DL_OTHER,d0
 bne 1f
 mov 3200,d0
1:
 mov d0,(a1)
 clr d0
 rets
dl_lv:                            /* live view's Delete press handler (a0, a1 as the state machine passes them): a
                                   * Multiple Exposure frame to delete -> stock; else the button function, as AF-ON */
 add -16,sp                       /* (0) call slot, (4) a0, (8) a1, (12) mdr */
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov mdr,d0
 mov d0,(12,sp)
 call dl_mexp,[d2,d3,a2],28
 mov (12,sp),d1
 mov d1,mdr
 mov (8,sp),a1
 mov (4,sp),a0
 add 16,sp
 cmp 0,d0
 beq 1f
 jmp dl_mx
1:
 jmp dl_fn
dl_look:                          /* .hook_dl (a3 = found, a2 = its handler, d0 = the event, a1 = the block's end,
                                   * d1 = its length): a shooting state with no entry for a Delete press / release
                                   * walks its block again for AF-ON's, so Delete leaves a function's state as AF-ON
                                   * does. Playback (0x57xx) keeps its own. */
 cmp 0,a3
 bne 8f
 cmp DL_PRESS,d0
 beq 1f
 cmp DL_PRESS + 1,d0
 bne 9f
1:
 mov (40,sp),a0                   /* the state machine; (188) = the current state */
 mov (188,a0),d2
 add -0x5100,d2
 cmp 0x600,d2                     /* 0x5100..0x56ff */
 bcs 2f
 add -0x700,d2
 cmp 0x400,d2                     /* 0x5800..0x5bff */
 bcc 9f
2:
 add 12,d0                        /* AF-ON's press / release */
 mov d1,d2
 asl2 d2
 asl2 d2
 sub d2,a1
 jmp dl_walk
8:
 cmp 0,a2
 beq 9f
 mov sp,a0
 jmp dl_hit
9:
 jmp dl_none

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
 mov (lg_np),d0                   /* dl8: photos this power-on, for the debug log (our RAM only) */
 inc d0
 mov d0,(lg_np)
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

/* ex_cd1: `call ex_cd1,[d2,d3,a2,a3],20`, a2 = P, d2 = COLOR k, d3 = film j -> ex_code = "om3.1." + 43 characters:
 * a 64-byte LOOKS.BIN record of the film, one nibble each (value & 15), two to a byte (32 bytes), base64url
 * (A-Z a-z 0-9 - _), no padding. The camera is in the name so another body (E-P7) can have its own. The Control Panel
 * turns it back into the film (firmware/photocode.py is the reference).
 * v0.28 pc1: the film as it is set when the photo is taken (ex_rec: COLOR k's settings and the camera's WB at the
 * half-press before the shot, ex_live), else as built (its LOOKS.BIN record). Bytes 57..62 carry Halation, Tone
 * Balance and the WB (spare until v0.28: older readers skip them). Split toning stays in v0.26 steps for older
 * readers: the strength code v < 0 (an odd number of half steps, 2 |v| - 1) is written as |v| - 1 with its half step
 * in byte 63 (bit 0 Shadows, bit 1 Highlights). */
ex_cd1:
 mov (ex_rk),d0
 cmp d2,d0
 bne 1f
 mov ex_rec,a0                    /* COLOR k now */
 bra 2f
1:
 mov (LPTR,a2),a0                 /* the record as built: 32 + 64 j */
 mov d3,d0
 asl 6,d0
 add d0,a0
 add 32,a0
2:
 mov ex_out,a1
 mov 63,d1
3:
 movbu (a0),d0
 movbu d0,(a1)
 inc a0
 inc a1
 add -1,d1
 bne 3b
 mov ex_out,a0
 clr d1                           /* byte 63: the half steps */
 movbu (54,a0),d0
 extb d0
 cmp 0,d0
 bge 4f
 not d0                           /* v -> -v - 1 */
 movbu d0,(54,a0)
 or 1,d1
4:
 movbu (56,a0),d0
 extb d0
 cmp 0,d0
 bge 5f
 not d0
 movbu d0,(56,a0)
 or 2,d1
5:
 movbu d1,(63,a0)
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
ex_code:                          /* "om3.1." + 43 characters + NUL = 50 bytes (v0.28 pc1: was 48, 2 in the padding) */
 .space 52
 .balign 4
ex_rk:                            /* v0.28 pc1: ex_rec holds COLOR ex_rk (-1: none) */
 .long -1
ex_rec:                           /* COLOR k's settings at the last half-press (ex_live) */
 .space 64
ex_out:                           /* the record as coded (ex_cd1) */
 .space 64

/* nm_ex (v0.28 pc1): sd_load's last call (the first half-press of a power-on, ext1 is full): nm_load, then ex_live. */
nm_ex:
 call nm_load,[d2,d3,a2,a3],36
 call ex_live,[d2,d3,a2,a3],48
 call cr_hp,[d2,d3,a2,a3],20      /* crop modes: at a half-press load, cr_on and the crop back (crop.s) */
 ret [d2,d3,a2,a3],36

/* ex_live: `call ex_live,[d2,d3,a2,a3],48` at each half-press (the first: sd_load via nm_ex; then lg_pr after the editor's save),
 * in the HLS_EVENT task only (the gate of pr_gate / lg_write; the settings getter is safe there, not in the capture:
 * v0.24): when the camera is on COLOR k, its settings now (pf_capto) and the camera's WB now (1578 mode -> its index in
 * table 0x615d1944, Custom WB also 107 Kelvin -> v, as fw_keep) -> ex_rec +0..+62, ex_rk = k; else ex_rk = -1.
 * Locals (16) P, (20) k, (24) mode index, (28) Kelvin v (below the 16 B of saved registers). */
ex_live:
 mov -1,d0
 mov d0,(ex_rk)
 call hl_ok,[a2],16
 cmp HL_FAIL,d0
 beq 9f                           /* with or without a medium */
 PVAL 9f
 mov a2,(16,sp)
 mov 111,d0
 call sget,[],4                   /* the picture mode (sget does not keep a2) */
 mov (16,sp),a2
 mov fl_cvt,a0
 clr d2
1:
 movbu (d2,a0),d1
 cmp d1,d0
 beq 2f
 inc d2
 cmp 4,d2
 bne 1b
 bra 9f                           /* not COLOR 1-4 */
2:
 mov d2,(20,sp)
 mov ex_rec,a3
 call pf_capto,[d2,d3,a2,a3],28   /* COLOR k now -> ex_rec (keeps d2, d3, a2, a3) */
 mov 1578,d0
 call sget,[],4                   /* the camera's WB mode */
 mov 0x615d1944,a0
 clr d3
3:
 mov (a0),d1
 cmp d1,d0
 beq 4f
 add 12,a0
 inc d3
 cmp 13,d3
 bne 3b
 clr d3                           /* not in the table: none */
4:
 mov d3,(24,sp)
 clr d1
 mov d1,(28,sp)
 cmp 9,d0                         /* Custom WB: its Kelvin too */
 bne 6f
 mov 107,d0
 call sget,[],4
 add -2000,d0
 mov 100,d1
 ext d0
 div d1,d0
 cmp 0,d0
 bge 5f
 clr d0
5:
 cmp 120,d0
 ble 51f
 mov 120,d0
51:
 add -60,d0
 mov d0,(28,sp)
6:
 mov ex_rec,a1
 mov (28,sp),d0
 FWENC
 movbu d0,(59,a1)
 movbu d1,(60,a1)
 mov (24,sp),d0
 FWENC
 movbu d0,(61,a1)
 movbu d1,(62,a1)
 mov (20,sp),d0
 mov d0,(ex_rk)
9:
 ret [d2,d3,a2,a3],48

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
dg_pt:                            /* the programs (build.py, firmware/diagrams.py) */
 .space 4 * NDG
dg_pgs:
 .space 2560
dg_sb:                            /* the stamps */
 .space 2560
 .balign 8
dg_b0:                            /* two output buffers */
 .space 2 * DGCAP
dg_bend:



/* ================================================================== v0.28 halation (h2; h7 2026-11-16: faster, same bytes)
 * Our own code. The method follows Caduceus for the E-P7's halation by cakelesscoder (credited in NOTICE / README);
 * the numbers are ours (firmware/halation.py -> hl_tab.inc) and research/halation/model.py is the exact model.
 * Called by the code block's xb_gs after the Soft Focus blend (buffer 0x1000 complete: YCbYCr 4:2:2, byte 1 = Cb,
 * byte 3 = Cr, offset-binary: camera probe h0). Runs in the capture job's task; three mallocs per call (several CPUs
 * may process stills at once), freed again. Image rows through this CPU's bus window under the firmware's lock, as
 * xb_grain (camera-proven): the window's cached view, written back (FLUSH) before the lock goes.
 *   A. every 2nd row, every pair's Y0: e = Y0 - T (if > 0) summed into u16 64 x 64 px cells (E), and Y0 >> 2 summed
 *      into a second grid (Q); the cell's mean B = 4 Q / samples
 *   B. E: [1 2 1] / 4 (rounded, edges repeated), HL_BLUR times across, HL_BLUR times down; a broad copy HL_BLUR2 times
 *      (h4), mixed: v0 = (tight (256 - HL_MIX) + broad HL_MIX + 128) >> 8
 *   map: u by table (hl_lo / hl_hi); n = cells with u(v0) >= HL_COVU: none at n >= HL_COVHI % of the cells, full
 *      strength up to HL_COVLO %, faded between (sc). h8 (owner, v0.30.3 test 1: "the halation at 5 kinda just ends"):
 *      the broad copy blurred HL_BLUR3 times more (wide), v = v0 + ((wide HL_WIDE + 128) >> 8): a long, even tail
 *      (the bright-frame count n stays on v0). g = (((u(v) gmax) >> 8) sc) >> 8; w = min(255, HL_WMUL (255 - B))
 *   C. per row g and w lerped between the two nearest cell rows, then per pair between cell centres:
 *      Y += ((255 - Y) g HL_KY) >> 16 per pixel; with c = (g w) >> 8: Cb / Cr += (c HL_KCB / HL_KCR) >> 8 (floor,
 *      clamped). h2 (camera h1: the fast grain is in the image before this pass): the chroma weight w comes from the
 *      cell's mean brightness, not each pixel's, so grain and thin lines don't speckle the tint.
 * h7 (the ideas of Caduceus for the E-P7's faster halation, docs/HALATION_RED.md section 23, applied to our pass; the
 * same bytes, checked against the model in om-emu, research/halation/emu_check.py):
 *   A: eight Y0 ORed and compared once (no excess when the OR is <= T), a full cell's 32 pairs in one run (hl_pa);
 *      a full cell's B = Q >> 8 (1024 samples), no division.
 *   B: the blur in place (hl_b1 keeps the old left value).
 *   C: a pair with g <= 1 is left as it is (Y: 255 KY < 2^16; chroma: c = (w) >> 8 = 0), so rows are taken in bands
 *      that share their two cell rows, and per band only the segments (between cell centres) whose ends can reach
 *      g >= 2 (hl_bd); per row their ends lerped (hl_row), then only the pairs from the first to the last g >= 2
 *      (g is monotonic along a segment), 8 pairs a loop turn, g and w in one accumulator, the chroma change by table
 *      (hl_cb / hl_cr: one clamp each, Cb only falls, Cr only rises), g KY once per pair and Y left out while
 *      g < GY (hl_sp).
 *   Several rows per lock (and per FLUSH): as many as an estimate of the work keeps under HL_LOCKN instructions with
 *   interrupts masked (the old pass reached ~133 K on one 20 MP row). A group across the window's edge is retried one
 *   row at a time; the one row across it is left as it is, as before. */
.section .ext12,"ax"
 .include "hl_tab.inc"
 .balign 4
 .set HL_LOCKN, 120000            /* h7: instructions under one lock, at most (by the estimate) */
 .set HL_PA_PAIR, 10              /* h7: pass A's estimate per pair and per cell (the slow path included) */
 .set HL_PA_CELL, 20
 .set HL_C_PAIR, 44               /* h7: pass C's estimate per pair, per segment and per row (hl_sp, hl_row) */
 .set HL_C_SEG, 120
 .set HL_C_ROW, 100

/* hl_run: `call hl_run,[d2,d3,a2,a3],124`, a0 = buffer record, d0 = strength 1..5 (124 = 16 for the saved registers
 * + 108 of locals; a callee's frame is likewise 16 + its locals).
 * Locals: (0) call slot, (4) rec, (8) gmax, (12) W, then GW | GH << 16, (16) H, (20) pitch, (24) bus, (28) pairs,
 * (32) GW, (36) GH, (40) mem1 = E then G (u16 GW x GH), (44) the band's list ((first pair, pairs) u16 pairs, in mem1
 * after the grid: the old blur temp and two lines, max(GW, GH) + 2 + 2 GW u16), (48) pass A's rows per lock, then
 * n_lo, (52) y, (56) token, (60) cached, (64) the row's CPU address (passes A, C) / sc, (68) any / pass C's rows per
 * lock in the band, (72) cells, (76) rows in this group, (80) mem2 = Q then w, (84) the band's B row - A row in bytes
 * (2 GW, or 0 in a band of one cell row), (88) n / an estimate of a row's instructions in the band, (92) the band's end
 * row, (96) the band's A row in bytes, (100) n_hi / the list's length, (104) mem3 = the broad layer (h4). hl_bd and
 * hl_row read these through the frame pointer. */
hl_run:
 mov a0,(4,sp)
 cmp 1,d0
 bcs 99f
 cmp 5,d0
 bhi 99f
 add -1,d0
 asl2 d0
 mov hl_gmax,a1
 add d0,a1
 mov (a1),d0
 mov d0,(8,sp)
 movhu (16,a0),d0                 /* format 0x0c02 only (as xb_grain) */
 cmp 0x0c02,d0
 bne 99f
 mov (4,a0),d0
 cmp 0,d0
 bne 99f
 movhu (20,a0),d0                 /* W: 64 .. 8192, a multiple of 4 */
 cmp 64,d0
 bcs 99f
 cmp 8193,d0
 bcc 99f
 btst 3,d0
 bne 99f
 mov d0,(12,sp)
 lsr 1,d0
 mov d0,(28,sp)
 movhu (18,a0),d1                 /* memHw >= W */
 mov (12,sp),d0
 cmp d0,d1
 bcs 99f
 add d1,d1
 mov d1,(20,sp)
 movhu (22,a0),d1                 /* H >= 64 */
 cmp 64,d1
 bcs 99f
 mov d1,(16,sp)
 mov (a0),d0
 mov d0,(24,sp)
 mov (12,sp),d0
 add 63,d0
 lsr 6,d0
 mov d0,(32,sp)                   /* GW */
 mov (16,sp),d1
 add 63,d1
 lsr 6,d1
 mov d1,(36,sp)                   /* GH */
 mul d1,d0
 mov d0,(72,sp)                   /* cells */
 add d0,d0                        /* grid bytes */
 mov d0,d2
 mov (32,sp),d0
 mov (36,sp),d1
 cmp d1,d0
 bcc 1f
 mov d1,d0
1:
 add 2,d0
 add d0,d0                        /* the old blur temp's bytes: the list's room starts here */
 mov d0,d3
 mov (32,sp),d0
 asl2 d0                          /* two lines (the list's room too) */
 add d2,d0
 add d3,d0
 add 3,d0
 and -4,d0
 cmp 16384,d0
 bhi 99f
 call malloc,[],4
 cmp 0,a0
 beq 99f
 mov a0,(40,sp)
 mov a0,d0
 add d2,d0
 mov d0,(44,sp)                   /* the list */
 mov d2,d0
 call malloc,[],4                 /* Q / w grid */
 cmp 0,a0
 bne 2f
 mov (40,sp),a0
 call free,[],4
 bra 99f
2:
 mov a0,(80,sp)
 mov d2,d0
 call malloc,[],4                 /* h4: the broad layer's copy of E */
 cmp 0,a0
 bne 4f
 mov (80,sp),a0
 call free,[],4
 mov (40,sp),a0
 call free,[],4
 bra 99f
4:
 mov a0,(104,sp)
 mov (80,sp),a0
 mov (72,sp),d1                   /* zero both grids */
 mov (40,sp),a1
 clr d0
3:
 movhu d0,(a0)
 movhu d0,(a1)
 add 2,a0
 add 2,a1
 add -1,d1
 bne 3b
 call FLUSH,[d2,d3],16            /* no stale lines in the window's cached view */

 /* ---- A. the grids: every 2nd row, Y0 of every pair (hl_pa); K sampled rows per lock */
 mov (28,sp),d0                   /* K = max(1, HL_LOCKN / (HL_PA_PAIR pairs + HL_PA_CELL GW + 40)) */
 mov HL_PA_PAIR,d1
 mul d1,d0
 mov (32,sp),d1
 mov HL_PA_CELL,d2
 mul d2,d1
 add d1,d0
 add 40,d0
 mov d0,d1
 mov HL_LOCKN,d0
 call hl_div,[d2,d3,a2,a3],20
 cmp 1,d0
 bcc 5f
 mov 1,d0
5:
 mov d0,(48,sp)
 clr d0
 mov d0,(52,sp)
10:
 mov (16,sp),d1                   /* this group: min(K, the sampled rows left) */
 mov (52,sp),d0
 sub d0,d1
 add 1,d1
 lsr 1,d1
 mov (48,sp),d0
 cmp d0,d1
 bcc 11f
 mov d1,d0
11:
 mov d0,(76,sp)
12:
 mov (76,sp),d1                   /* rows y, y + 2, ..: 2 (K - 1) pitch + 4 pairs bytes */
 add -1,d1
 add d1,d1
 mov (20,sp),d0
 mul d0,d1
 mov (28,sp),d0
 asl2 d0
 add d0,d1
 mov (52,sp),d0
 mov (20,sp),d2
 mul d2,d0
 mov (24,sp),d2
 add d2,d0
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 bne 13f
 mov (76,sp),d0                   /* across the window's edge: one row at a time */
 cmp 1,d0
 beq 18f
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov 1,d0
 mov d0,(76,sp)
 bra 12b
13:
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 14f
 add -0x40000000,d0               /* the window's cached view */
 mov 1,d1
14:
 mov d1,(60,sp)
 mov d0,(64,sp)
15:
 mov (52,sp),d0                   /* this row's E and Q rows */
 lsr 6,d0
 mov (32,sp),d1
 mul d1,d0
 add d0,d0
 mov (40,sp),a2
 add d0,a2
 mov (80,sp),a3
 add d0,a3
 mov (64,sp),a0
 mov (28,sp),d0
 call hl_pa,[d2,d3,a2,a3],24
 mov (64,sp),d0
 mov (20,sp),d1
 add d1,d0
 add d1,d0
 mov d0,(64,sp)
 mov (52,sp),d0
 add 2,d0
 mov d0,(52,sp)
 mov (76,sp),d0
 add -1,d0
 mov d0,(76,sp)
 bne 15b
 mov (60,sp),d0
 cmp 0,d0
 beq 17f
 call FLUSH,[d2,d3],16
17:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 bra 19f
18:                               /* a row across the window's edge: not counted (as before) */
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov (52,sp),d0
 add 2,d0
 mov d0,(52,sp)
19:
 mov (52,sp),d0
 mov (16,sp),d1
 cmp d1,d0
 bcs 10b

 /* ---- w: each cell's mean B = 4 Q / samples (a full cell: Q >> 8), w = min(255, HL_WMUL (255 - B)), in place of Q */
 mov (80,sp),a2
 clr d0
 mov d0,(96,sp)                   /* cy */
20:
 mov (96,sp),d0                   /* sampled rows of this cell row: (min(64, H - 64 cy) + 1) >> 1 */
 asl 6,d0
 mov (16,sp),d1
 sub d0,d1
 cmp 64,d1
 bls 21f
 mov 64,d1
21:
 add 1,d1
 lsr 1,d1
 mov d1,(100,sp)
 clr d0
 mov d0,(92,sp)                   /* cx */
22:
 mov (92,sp),d0                   /* pairs of this cell column: min(32, pairs - 32 cx) */
 asl 5,d0
 mov (28,sp),d1
 sub d0,d1
 cmp 32,d1
 bls 23f
 mov 32,d1
23:
 mov (100,sp),d0
 mul d0,d1                        /* samples */
 movhu (a2),d0
 cmp 1024,d1
 bne 25f
 lsr 8,d0                         /* h7: 4 Q / 1024 */
 bra 26f
25:
 asl2 d0
 call hl_div,[d2,d3,a2,a3],20     /* B */
26:
 mov 255,d1
 sub d0,d1
 mov HL_WMUL,d0
 mul d0,d1
 cmp 255,d1
 bls 24f
 mov 255,d1
24:
 movhu d1,(a2)
 add 2,a2
 mov (92,sp),d0
 inc d0
 mov d0,(92,sp)
 mov (32,sp),d1
 cmp d1,d0
 bcs 22b
 mov (96,sp),d0
 inc d0
 mov d0,(96,sp)
 mov (36,sp),d1
 cmp d1,d0
 bcs 20b

 /* ---- B. blur E: a tight layer (HL_BLUR passes) and a broad one (HL_BLUR2, on a copy), mixed (h4) */
 mov (40,sp),a0
 mov (104,sp),a1
 mov (72,sp),d1
30:
 movhu (a0),d0
 movhu d0,(a1)
 add 2,a0
 add 2,a1
 add -1,d1
 bne 30b
 mov (36,sp),d1
 asl 16,d1
 mov (32,sp),d0
 or d0,d1                         /* GW | GH << 16 */
 mov d1,(12,sp)
 mov (40,sp),a0
 mov HL_BLUR,d0
 call hl_blur,[d2,d3,a2,a3],44
 mov (104,sp),a0
 mov HL_BLUR2,d0
 mov (12,sp),d1
 call hl_blur,[d2,d3,a2,a3],44
 mov (40,sp),a0                   /* E = (E (256 - HL_MIX) + E2 HL_MIX + 128) >> 8 */
 mov (104,sp),a1
 mov (72,sp),d3
31:
 movhu (a0),d0
 mov 256 - HL_MIX,d1
 mul d1,d0
 movhu (a1),d1
 mov HL_MIX,d2
 mul d2,d1
 add d1,d0
 add 128,d0
 lsr 8,d0
 movhu d0,(a0)
 add 2,a0
 add 2,a1
 add -1,d3
 bne 31b

 /* ---- the bright-frame count n: cells whose h4 mix gives u >= HL_COVU (h8: counted as before, u not kept) */
 mov (40,sp),a0
 mov (72,sp),d3
 clr d2
40:
 movhu (a0),d0
 cmp 1024,d0
 bcc 41f
 lsr 2,d0
 mov hl_lo,a1
 bra 42f
41:
 lsr 8,d0
 cmp 255,d0
 bls 43f
 mov 255,d0
43:
 mov hl_hi,a1
42:
 add d0,a1
 movbu (a1),d0                    /* u of the h4 mix */
 cmp HL_COVU,d0
 bcs 44f
 inc d2
44:
 add 2,a0
 add -1,d3
 bne 40b
 mov d2,(88,sp)
 mov (72,sp),d0                   /* n_lo, n_hi = cells x HL_COVLO / 100, x HL_COVHI / 100 */
 mov HL_COVLO,d1
 mul d1,d0
 mov 100,d1
 call hl_div,[d2,d3,a2,a3],20
 mov d0,(48,sp)
 mov (72,sp),d0
 mov HL_COVHI,d1
 mul d1,d0
 mov 100,d1
 call hl_div,[d2,d3,a2,a3],20
 mov d0,(100,sp)
 mov (88,sp),d2
 cmp d0,d2
 bcc 90f                          /* too much of the frame is bright: no halation */
 mov 256,d0
 mov (48,sp),d1
 cmp d1,d2
 bls 45f
 mov (100,sp),d0                  /* sc = ((n_hi - n) 256) / (n_hi - n_lo) */
 sub d2,d0
 asl 8,d0
 mov (100,sp),d2
 sub d1,d2
 mov d2,d1
 call hl_div,[d2,d3,a2,a3],20
45:
 mov d0,(64,sp)
 /* ---- h8: the wide layer = the broad one blurred HL_BLUR3 more times (in place); the curve, u in place of E, from
  * v = the h4 mix + ((wide HL_WIDE + 128) >> 8) (up to ~70 K: 32-bit, the hl_hi index clamped as before) */
 mov (104,sp),a0
 mov HL_BLUR3,d0
 mov (12,sp),d1                   /* GW | GH << 16 */
 call hl_blur,[d2,d3,a2,a3],44
 mov (40,sp),a0
 mov (104,sp),a2
 mov (72,sp),d3
47:
 movhu (a2),d0
 mov HL_WIDE,d1
 mul d1,d0
 add 128,d0
 lsr 8,d0
 movhu (a0),d1
 add d1,d0                        /* v */
 cmp 1024,d0
 bcc 48f
 lsr 2,d0
 mov hl_lo,a1
 bra 49f
48:
 lsr 8,d0
 cmp 255,d0
 bls 1f
 mov 255,d0
1:
 mov hl_hi,a1
49:
 add d0,a1
 movbu (a1),d0                    /* u */
 movhu d0,(a0)
 add 2,a0
 add 2,a2
 add -1,d3
 bne 47b
 mov (40,sp),a0                   /* g = (((u gmax) >> 8) sc) >> 8 */
 mov (72,sp),d3
 clr d2                           /* OR of g */
46:
 movhu (a0),d0
 mov (8,sp),d1
 mul d1,d0
 lsr 8,d0
 mov (64,sp),d1
 mul d1,d0
 lsr 8,d0
 movhu d0,(a0)
 or d0,d2
 add 2,a0
 add -1,d3
 bne 46b
 cmp 2,d2
 bcs 90f                          /* no g >= 2 anywhere: nothing changes (h7; was: all g = 0) */

 /* ---- C. bands of rows that share their cell rows: the top rows (y < 32: cell row 0 alone), then per cell row r0
  * the rows 32 + 64 r0 .. + 63 (r0 and r0 + 1, wy = (y - 32) & 63), then the last rows (cell row GH - 1 alone) */
 clr d0
 mov d0,(52,sp)
50:
 mov (52,sp),d0
 mov (16,sp),d1
 cmp d1,d0
 bcc 90f
 clr d1                           /* A: cell row 0 */
 mov 32,d2                        /* the band's end */
 clr d3                           /* B - A: none */
 cmp 32,d0
 bcs 53f
 add -32,d0
 lsr 6,d0                         /* r0 */
 mov (36,sp),d1
 add -1,d1
 mov (16,sp),d2
 cmp d1,d0
 bcc 53f                          /* r0 >= GH - 1: the last row alone, to the end */
 mov d0,d1
 asl 6,d0
 add 96,d0
 mov d0,d2
 mov (32,sp),d3
 add d3,d3
53:
 mov (16,sp),d0
 cmp d0,d2
 bls 54f
 mov d0,d2
54:
 mov d2,(92,sp)
 mov d3,(84,sp)
 mov (32,sp),d0
 mul d0,d1
 add d1,d1
 mov d1,(96,sp)
 mov sp,a0
 call hl_bd,[d2,d3,a2,a3],28      /* the list, its length (100), the estimate (88) */
 mov (100,sp),d0
 cmp 0,d0
 beq 69f                          /* nothing can glow in this band */
 mov (88,sp),d1                  /* rows per lock: max(1, HL_LOCKN / the estimate) */
 mov HL_LOCKN,d0
 call hl_div,[d2,d3,a2,a3],20
 cmp 1,d0
 bcc 55f
 mov 1,d0
55:
 mov d0,(68,sp)
56:
 mov (92,sp),d1                   /* this group: min(K, the band's rows left) */
 mov (52,sp),d0
 sub d0,d1
 mov (68,sp),d0
 cmp d0,d1
 bcc 57f
 mov d1,d0
57:
 mov d0,(76,sp)
58:
 mov (76,sp),d1                   /* rows y .. y + K - 1: (K - 1) pitch + 4 pairs bytes */
 add -1,d1
 mov (20,sp),d0
 mul d0,d1
 mov (28,sp),d0
 asl2 d0
 add d0,d1
 mov (52,sp),d0
 mov (20,sp),d2
 mul d2,d0
 mov (24,sp),d2
 add d2,d0
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 bne 60f
 mov (76,sp),d0                   /* across the window's edge: one row at a time */
 cmp 1,d0
 beq 66f
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov 1,d0
 mov d0,(76,sp)
 bra 58b
60:
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 61f
 add -0x40000000,d0               /* the window's cached view */
 mov 1,d1
61:
 mov d1,(60,sp)
 mov d0,(64,sp)
62:
 clr d2                           /* wy: (y - 32) & 63 in a band of two cell rows, else 0 */
 mov (84,sp),d0
 cmp 0,d0
 beq 63f
 mov (52,sp),d2
 add -32,d2
 and 63,d2
63:
 mov (64,sp),a0
 mov sp,a1
 call hl_row,[d2,d3,a2,a3],72
 mov (64,sp),d0
 mov (20,sp),d1
 add d1,d0
 mov d0,(64,sp)
 mov (52,sp),d0
 inc d0
 mov d0,(52,sp)
 mov (76,sp),d0
 add -1,d0
 mov d0,(76,sp)
 bne 62b
 mov (60,sp),d0
 cmp 0,d0
 beq 65f
 call FLUSH,[d2,d3],16
65:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 bra 67f
66:                               /* a row across the window's edge: left as it is (as before) */
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov (52,sp),d0
 inc d0
 mov d0,(52,sp)
67:
 mov (52,sp),d0
 mov (92,sp),d1
 cmp d1,d0
 bcs 56b
 jmp 50b
69:
 mov (92,sp),d0
 mov d0,(52,sp)
 jmp 50b
90:
 mov (104,sp),a0
 call free,[],4
 mov (80,sp),a0
 call free,[],4
 mov (40,sp),a0
 call free,[],4
99:
 ret [d2,d3,a2,a3],124

/* hl_pa (h7, pass A): `call hl_pa,[d2,d3,a2,a3],24`, a0 = the row's first pair, d0 = pairs, a2 / a3 = this row's E / Q
 * cells (u16): per cell (32 pairs, fewer in the last column) E += sum of max(0, Y0 - HL_T), Q += sum of Y0 >> 2.
 * A full cell: four runs of eight Y0, each ORed and compared once; hl_x8 only when the OR is above HL_T.
 * Locals (0) call slot (hl_x8), (4) the row's end. */
 .macro HLA8 o                    /* eight pairs at \o: d2 += Y0 >> 2; their OR in d1 */
 clr d1
 .irp k, 0, 4, 8, 12, 16, 20, 24, 28
 movbu (\o+\k,a0),d0
 or d0,d1
 lsr 2,d0
 add d0,d2
 .endr
 cmp HL_T,d1
 bls 96f
 mov a0,a1
 add \o,a1
 call hl_x8,[],0
96:
 .endm
hl_pa:
 asl2 d0
 add a0,d0
 mov d0,(4,sp)
1:
 mov (4,sp),d0
 mov a0,d1
 sub d1,d0                        /* bytes left in the row */
 beq 9f
 clr d2                           /* Y0 >> 2 sum */
 clr d3                           /* excess sum */
 cmp 128,d0
 bcs 5f
 HLA8 0
 HLA8 32
 HLA8 64
 HLA8 96
 add 128,a0
 bra 6f
5:                                /* the last column's part cell: one pair a turn */
 mov a0,a1
 add d0,a1
7:
 movbu (a0),d0
 mov d0,d1
 lsr 2,d1
 add d1,d2
 cmp HL_T,d0
 bls 8f
 add -HL_T,d0
 add d0,d3
8:
 add 4,a0
 cmp a1,a0
 bne 7b
6:
 movhu (a2),d0
 add d3,d0
 movhu d0,(a2)
 add 2,a2
 movhu (a3),d0
 add d2,d0
 movhu d0,(a3)
 add 2,a3
 bra 1b
9:
 ret [d2,d3,a2,a3],24

/* hl_x8: `call hl_x8,[],0` (leaf), a1 = eight pairs: d3 += sum of max(0, Y0 - HL_T); d0 used. */
hl_x8:
 .irp k, 0, 4, 8, 12, 16, 20, 24, 28
 movbu (\k,a1),d0
 cmp HL_T,d0
 bls 95f
 add -HL_T,d0
 add d0,d3
95:
 .endr
 retf [],0

/* hl_bd (h7): `call hl_bd,[d2,d3,a2,a3],28`, a0 = hl_run's frame: the band's segments that can glow, as (first pair,
 * pairs) u16 pairs in the list (44), their number in (100), an estimate of a row's instructions in (88). Segment
 * j = 0..GW covers the pairs [0, 16) (j = 0), [32 j - 16, min(32 j + 16, pairs)) (0 < j < GW), [32 GW - 16, pairs)
 * (j = GW), between the cell columns L = max(j - 1, 0) and R = min(j, GW - 1); it can glow only when g >= 2 at L or R
 * in the band's cell row A (96) or B (A + (84)): a lerp stays between its ends. Locals (0) call slot, (4) first pair,
 * (8) end. */
hl_bd:
 mov a0,a2
 mov (44,a2),a3
 clr d0
 mov d0,(100,a2)
 mov HL_C_ROW,d0
 mov d0,(88,a2)
 clr d3                           /* j */
1:
 clr d0                           /* first pair, end */
 mov 16,d1
 cmp 0,d3
 beq 4f
 mov d3,d0
 asl 5,d0
 add -16,d0
 mov (28,a2),d1                   /* pairs */
 cmp d1,d0
 bcc 9f                           /* past the row: no more segments */
 mov (32,a2),d2
 cmp d2,d3
 bcc 4f                           /* j = GW: to the row's end */
 mov d0,d2
 add 32,d2
 cmp d1,d2
 bcc 4f
 mov d2,d1
4:
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov d3,d0                        /* L */
 cmp 0,d0
 beq 5f
 add -1,d0
5:
 add d0,d0
 mov (40,a2),a0
 mov (96,a2),d1
 add d1,a0
 add d0,a0
 mov (84,a2),d2
 movhu (a0),d0
 movhu (d2,a0),d1
 or d1,d0
 mov (32,a2),d1                   /* R */
 add -1,d1
 cmp d1,d3
 bcc 6f
 mov d3,d1
6:
 add d1,d1
 mov (40,a2),a0
 mov (96,a2),a1
 add a1,a0
 add d1,a0
 movhu (a0),d1
 or d1,d0
 movhu (d2,a0),d1
 or d1,d0
 cmp 2,d0
 bcs 8f                           /* g <= 1 at both ends in both cell rows */
 mov (4,sp),d0
 movhu d0,(a3)
 mov (8,sp),d1
 sub d0,d1
 movhu d1,(2,a3)
 add 4,a3
 mov (100,a2),d0
 inc d0
 mov d0,(100,a2)
 mov HL_C_PAIR,d0
 mul d1,d0
 add HL_C_SEG,d0
 mov (88,a2),d1
 add d1,d0
 mov d0,(88,a2)
8:
 inc d3
 mov (32,a2),d0
 cmp d0,d3
 bls 1b
9:
 ret [d2,d3,a2,a3],28

/* hl_row (h7): `call hl_row,[d2,d3,a2,a3],72`, a0 = the row's first pair (CPU address), a1 = hl_run's frame, d2 = wy
 * (0..63; 0 in a band of one cell row). For each segment in the band's list: g and w at its ends (hl_lp; the right
 * end carried to the next segment when it follows), then hl_sp over its pairs when an end has g >= 2.
 * Locals (0) call slot, (4) frame, (8) row, (12) wy, (16) B - A bytes, (20) next entry, (24) entries left,
 * (28) previous j, (32) b_g, (36) b_w, (40) a_g, (44) a_w, (48) pairs, (52) first pair. */
 .set HR_WY, 12
 .set HR_DB, 16
hl_row:
 mov a1,(4,sp)
 mov a0,(8,sp)
 mov d2,(12,sp)
 mov (84,a1),d0
 mov d0,(16,sp)
 mov (44,a1),d0
 mov d0,(20,sp)
 mov (100,a1),d0
 mov d0,(24,sp)
 mov -2,d0
 mov d0,(28,sp)
1:
 mov (20,sp),a0
 movhu (a0),d3                    /* first pair */
 movhu (2,a0),d0
 add 4,a0
 mov a0,(20,sp)
 mov d0,(48,sp)
 mov d3,(52,sp)
 add 16,d3
 lsr 5,d3                         /* j */
 mov (4,sp),a1
 mov (28,sp),d0
 inc d0
 cmp d0,d3
 bne 2f
 mov (32,sp),d0                   /* follows the last one: its right end is this left end */
 mov d0,(40,sp)
 mov (36,sp),d0
 mov d0,(44,sp)
 bra 3f
2:
 mov d3,d0                        /* L = max(j - 1, 0) */
 cmp 0,d0
 beq 21f
 add -1,d0
21:
 add d0,d0
 mov d0,(32,sp)                   /* (2 L, for the w grid) */
 mov (40,a1),a0
 mov (96,a1),d1
 add d1,a0
 add d0,a0
 call hl_lp,[],0
 mov d0,(40,sp)
 mov (4,sp),a1
 mov (80,a1),a0
 mov (96,a1),d1
 add d1,a0
 mov (32,sp),d1
 add d1,a0
 call hl_lp,[],0
 mov d0,(44,sp)
 mov (4,sp),a1
3:
 mov (40,sp),d0                   /* R = min(j, GW - 1); R = L (j = 0 or j = GW): b = a */
 mov d0,(32,sp)
 mov (44,sp),d0
 mov d0,(36,sp)
 cmp 0,d3
 beq 4f
 mov (32,a1),d0
 cmp d0,d3
 bcc 4f
 mov d3,d0
 add d0,d0
 mov (40,a1),a0
 mov (96,a1),d1
 add d1,a0
 add d0,a0
 call hl_lp,[],0
 mov d0,(32,sp)
 mov (4,sp),a1
 mov (80,a1),a0
 mov (96,a1),d1
 add d1,a0
 mov d3,d1
 add d1,d1
 add d1,a0
 call hl_lp,[],0
 mov d0,(36,sp)
4:
 mov d3,(28,sp)
 mov (40,sp),d0                   /* g <= 1 at both ends: nothing changes */
 mov (32,sp),d1
 or d1,d0
 cmp 2,d0
 bcs 8f
 mov (44,sp),d2                   /* acc = (32 a_w + 16) << 16 | (32 a_g + 16), step = (b_w - a_w) << 16 + b_g - a_g */
 mov (36,sp),d3
 sub d2,d3
 asl 16,d3
 mov (32,sp),d0
 mov (40,sp),d1
 sub d1,d0
 add d0,d3
 asl 5,d2
 add 16,d2
 asl 16,d2
 asl 5,d1
 add 16,d1
 or d1,d2
 mov (52,sp),d0
 asl2 d0
 mov (8,sp),a0
 add d0,a0
 mov (48,sp),d0
 call hl_sp,[d2,d3,a2,a3],28
8:
 mov (24,sp),d0
 add -1,d0
 mov d0,(24,sp)
 beq 9f
 jmp 1b
9:
 ret [d2,d3,a2,a3],72

/* hl_lp (h7): `call hl_lp,[],0` from hl_row (the call leaves sp as it is, so hl_row's wy and B - A are read through its
 * frame), a0 = A's value (u16) -> d0 = (64 A + (B - A) wy + 32) >> 6, B at a0 + (B - A); d1, d2 used. mul writes
 * MDR, so `ret`, not `retf`. */
hl_lp:
 movhu (a0),d0
 mov (HR_DB,sp),d1
 movhu (d1,a0),d1
 sub d0,d1
 mov (HR_WY,sp),d2
 mul d2,d1
 asl 6,d0
 add d1,d0
 add 32,d0
 lsr 6,d0
 ret [],0

/* hl_sp (h7): `call hl_sp,[d2,d3,a2,a3],28`, a0 = first pair, d0 = pairs >= 1, d2 = acc = (32 w + 16) << 16 |
 * (32 g + 16) at the first pair, d3 = its step per pair ((dw << 16) + dg; both parts of acc stay in 0..8191). Per
 * pair g = (acc & 0xffe0) >> 5, w = acc >> 21. The leading pairs with g <= 1 are skipped, and the segment ends at the
 * next g <= 1 (g is monotonic along it). Locals (0) call slot, (4) the end, (8) the end of the 8-pair runs. */
 .macro HLP o                     /* one pair at \o (a0 + \o): g >= 2 or out to 9f; a1 = hl_cb */
 mov a2,d0
 and 0xffe0,d0                    /* 32 g */
 cmp 64,d0
 bcc 94f
 jmp 9f                           /* g <= 1: this pair and the rest of the segment stay as they are */
94:
 mov a2,d1
 lsr 21,d1                        /* w */
 mul d0,d1
 lsr 13,d1                        /* c = (g w) >> 8 */
 movbu (d1,a1),d2                 /* Cb += (c HL_KCB) >> 8 (<= 0): - hl_cb[c], clamped at 0 */
 movbu (\o+1,a0),d3
 sub d2,d3
 bcc 97f
 clr d3
97:
 movbu d3,(\o+1,a0)
 add 256,d1
 movbu (d1,a1),d2                 /* Cr += (c HL_KCR) >> 8 (>= 0): hl_cr[c], clamped at 255 */
 movbu (\o+3,a0),d3
 add d2,d3
 cmp 255,d3
 bls 98f
 mov 255,d3
98:
 movbu d3,(\o+3,a0)
 cmp HL_GY32,d0
 bcs 99f                          /* g < GY: ((255 - Y) g HL_KY) >> 16 = 0 */
 mov HL_KY,d2
 mul d2,d0                        /* 32 g HL_KY */
 movbu (\o,a0),d2                 /* Y0 += ((255 - Y0) 32 g HL_KY) >> 21 */
 mov d2,d3
 xor 255,d3
 mul d0,d3
 lsr 21,d3
 add d3,d2
 movbu d2,(\o,a0)
 movbu (\o+2,a0),d2               /* Y1 */
 mov d2,d3
 xor 255,d3
 mul d0,d3
 lsr 21,d3
 add d3,d2
 movbu d2,(\o+2,a0)
99:
 add a3,a2
 .endm
hl_sp:
 mov d2,a2
 mov d3,a3
1:                                /* leading pairs with g <= 1 (a rising segment's start) */
 mov a2,d1
 and 0xffc0,d1
 bne 2f
 add a3,a2
 add 4,a0
 add -1,d0
 bne 1b
 bra 9f
2:
 mov hl_cb,a1
 asl2 d0
 mov a0,d1
 add d0,d1
 mov d1,(4,sp)
 and -32,d0
 beq 5f                           /* fewer than 8 pairs */
 mov a0,d1
 add d0,d1
 mov d1,(8,sp)
3:
 HLP 0
 HLP 4
 HLP 8
 HLP 12
 HLP 16
 HLP 20
 HLP 24
 HLP 28
 add 32,a0
 mov (8,sp),d0
 cmp d0,a0
 beq 5f
 jmp 3b
5:
 mov (4,sp),d0
 cmp d0,a0
 beq 9f
6:
 HLP 0
 add 4,a0
 mov (4,sp),d0
 cmp d0,a0
 beq 9f
 jmp 6b
9:
 ret [d2,d3,a2,a3],28

/* hl_div: `call hl_div,[d2,d3,a2,a3],20`, d0 / d1 (unsigned, d1 > 0) -> d0, shift and subtract. */
hl_div:
 mov d0,d2
 mov d1,d3
 clr d0
 clr d1
 mov 32,a2
1:
 asl 1,d1
 cmp 0,d2
 bge 2f
 or 1,d1
2:
 asl 1,d2
 asl 1,d0
 cmp d3,d1
 bcs 3f
 sub d3,d1
 or 1,d0
3:
 add -1,a2
 cmp 0,a2
 bne 1b
 ret [d2,d3,a2,a3],20


/* hl_blur: `call hl_blur,[d2,d3,a2,a3],44` (h4; h7: in place, no temp), a0 = grid (u16 GW x GH), d0 = passes >= 1,
 * d1 = GW | GH << 16: passes [1 2 1] across every row, then passes down every column.
 * Locals (0) call slot, (4) grid, (8) passes, (12) GW, (16) GH, (20) row / column, (24) passes left. */
hl_blur:
 mov a0,(4,sp)
 mov d0,(8,sp)
 mov d1,d0
 and 0xffff,d0
 mov d0,(12,sp)
 lsr 16,d1
 mov d1,(16,sp)
 mov (8,sp),d0
 mov d0,(24,sp)
1:
 clr d0
 mov d0,(20,sp)
2:
 mov (20,sp),d0
 mov (12,sp),d1
 mul d1,d0
 add d0,d0
 mov (4,sp),d1
 add d1,d0
 mov d0,a0
 mov (12,sp),d0
 mov 2,d1
 call hl_b1,[d2,d3,a2,a3],20
 mov (20,sp),d0
 inc d0
 mov d0,(20,sp)
 mov (16,sp),d1
 cmp d1,d0
 bcs 2b
 mov (24,sp),d0
 add -1,d0
 mov d0,(24,sp)
 bne 1b
 mov (8,sp),d0
 mov d0,(24,sp)
3:
 clr d0
 mov d0,(20,sp)
4:
 mov (20,sp),d0
 add d0,d0
 mov (4,sp),d1
 add d1,d0
 mov d0,a0
 mov (16,sp),d0
 mov (12,sp),d1
 add d1,d1
 call hl_b1,[d2,d3,a2,a3],20
 mov (20,sp),d0
 inc d0
 mov d0,(20,sp)
 mov (12,sp),d1
 cmp d1,d0
 bcs 4b
 mov (24,sp),d0
 add -1,d0
 mov d0,(24,sp)
 bne 3b
 ret [d2,d3,a2,a3],44

/* hl_b1: `call hl_b1,[d2,d3,a2,a3],20`, a0 = first value (u16), d0 = n >= 1, d1 = stride in bytes, in place (h7):
 * v[i] = (t[i] + 2 t[i+1] + t[i+2] + 2) >> 2 with t = v[0], v[0..n-1], v[n-1]; the old v[i - 1] is kept in d1. */
hl_b1:
 mov d1,d3                        /* stride */
 add -1,d0
 mul d3,d0
 mov a0,d1
 add d0,d1
 mov d1,a1                        /* the last value */
 movhu (a0),d2                    /* cur */
 mov d2,d1                        /* prev (t[0] = v[0]) */
 cmp a1,a0
 beq 3f
1:
 movhu (d3,a0),d0                 /* next */
 add d2,d1
 add d2,d1
 add d0,d1
 add 2,d1
 lsr 2,d1
 movhu d1,(a0)
 mov d2,d1
 mov d0,d2
 add d3,a0
 cmp a1,a0
 bne 1b
3:                                /* the last: next = itself */
 add d2,d1
 add d2,d1
 add d2,d1
 add 2,d1
 lsr 2,d1
 movhu d1,(a0)
 ret [d2,d3,a2,a3],20

/* hl_open: as the block's xb_open: `call hl_open,[d2,d3,a2,a3],28`, d0 = bus address, d1 = length -> a0 = CPU
 * address or 0, d0 = lock token (held: give it back with `call UNLOCK,[d2],8`), d1 = 1 window / 0. */
hl_open:
 mov d0,a3
 mov d1,d3
 clr d0
 call LOCK,[d2],8
 mov d0,a2
 clr d2
 mov a3,d0
 cmp 0x08000000,d0
 bcs 7f
 cmp 0xa0000000,d0
 bcs 3f
 cmp 0xb8000000,d0
 bcc 3f
 mov a3,a0
 bra 8f
3:
 and 0x07ffffff,d0
 add d3,d0
 cmp 0x08000001,d0
 bcc 7f
 mov (0x8050),d1
 mov 0x98100058,a0
 cmp 0,d1
 beq 4f
 add 0x400,a0
 cmp 1,d1
 beq 4f
 add 0x400,a0
 cmp 2,d1
 beq 4f
 add 0x800,a0
4:
 mov (a0),d1
 lsr 24,d1
 mov a3,d0
 lsr 27,d0
 cmp d0,d1
 bne 5f
 mov a3,d0
 and 0x07ffffff,d0
 or 0xb8000000,d0
 mov d0,a0
 mov 1,d2
 bra 8f
5:
 mov a3,a0
 call WINMAP,[d2,d3,a2,a3],28
 mov 1,d2
 bra 8f
7:
 mov 0,a0
8:
 mov a2,d0
 mov d2,d1
 ret [d2,d3,a2,a3],28


/* ================================================================== borders (2026-11-16; feature/image-borders)
 * Our own code. A white border (Y 255, Cb = Cr = 128) painted over the photo's outer edge, the same width on all four
 * sides, on our looks' stills with the Border row 1..5 (slot +50). Called by the code block's xb_gs after halation
 * and grain (buffer 0x1000 complete: YCbYCr 4:2:2 as hl_run takes it), so no glow, halo or grain on the border.
 * The JPEG keeps its size; the photo's outer B pixels are covered. RAW files are not touched.
 *   B = (S bd_tab[level - 1]) >> 16 rows top and bottom, S = min(W, H) (1.5 / 3 / 4.5 / 6 / 7.5 % of the short side,
 *   at least 1); left and right in whole pairs: Bp = (B + 1) / 2 pairs (2 Bp px; a pair shares its Cb / Cr).
 * Rows through hl_open as hl_run: several rows per lock (at most BD_LOCKN instructions by the estimate), written
 * through the window's cached view and FLUSHed before the lock goes; a group across the window's edge is retried one
 * row at a time, and a row across it one pair at a time (a pair that cannot be mapped is left as it is).
 * research/border/model.py is the exact model (research/border/emu_check.py: bit-exact in om-emu). */
 .set BD_LOCKN, 120000            /* instructions under one lock, at most (by the estimate), as HL_LOCKN */
 .set BD_PAIR, 4                  /* the estimate: per pair written, and per row */
 .set BD_ROW, 60
 .set BD_WORD, 0x80ff80ff         /* Y0 255, Cb 128, Y1 255, Cr 128 */
 .balign 4
bd_tab:                           /* the width per level, in 1 / 65536 of the short side: 1.5, 3, 4.5, 6, 7.5 % */
 .long 983, 1966, 2949, 3932, 4915

/* bd_run: `call bd_run,[d2,d3,a2,a3],88`, a0 = buffer record, d0 = level 1..5 (anything else: nothing).
 * Locals: (0) call slot, (4) rec, (8) P = W / 2 pairs, (12) H, (16) pitch, (20) bus, (24) B rows, (28) Bp pairs,
 * (32) y, (36) the band's end row, (40) a: pairs from the left, (44) b: the right span's first pair (P - b pairs),
 * (48) K rows per lock, (52) rows in this group, (56) token, (60) cached, (64) the row's CPU address, (68) band 0..2.
 * d2 = BD_WORD throughout (the callee-saved registers are ours: xb_gs's call saves them). */
bd_run:
 mov a0,(4,sp)
 cmp 1,d0
 bcs 99f
 cmp 5,d0
 bhi 99f
 add -1,d0
 asl2 d0
 mov bd_tab,a1
 add d0,a1
 mov (a1),d3                      /* d3 = the level's width factor */
 movhu (16,a0),d0                 /* format 0x0c02 only (as hl_run) */
 cmp 0x0c02,d0
 bne 99f
 mov (4,a0),d0
 cmp 0,d0
 bne 99f
 movhu (20,a0),d0                 /* W: 64 .. 8192, a multiple of 4 */
 cmp 64,d0
 bcs 99f
 cmp 8193,d0
 bcc 99f
 btst 3,d0
 bne 99f
 mov d0,a2                        /* a2 = W */
 lsr 1,d0
 mov d0,(8,sp)                    /* P */
 movhu (18,a0),d1                 /* memHw >= W */
 cmp a2,d1
 bcs 99f
 add d1,d1
 mov d1,(16,sp)                   /* pitch */
 movhu (22,a0),d1                 /* H >= 64 */
 cmp 64,d1
 bcs 99f
 mov d1,(12,sp)
 mov (a0),d0
 mov d0,(20,sp)                   /* bus */
 mov a2,d0                        /* crop modes: a crop's own area of the buffer (crop.s cr_bdc) */
 mov sp,a0
 call cr_bdc,[d2,d3,a2,a3],28
 mov d0,a2
 mov (12,sp),d1
 mov a2,d0                        /* S = min(W, H) */
 cmp d1,d0
 bls 1f
 mov d1,d0
1:
 mul d3,d0
 lsr 16,d0                        /* B */
 cmp 0,d0
 bne 2f
 mov 1,d0
2:
 mov d0,(24,sp)
 add 1,d0
 lsr 1,d0
 mov d0,(28,sp)                   /* Bp */
 mov BD_WORD,d2
 clr d0
 mov d0,(68,sp)                   /* band 0: rows 0 .. B - 1, the whole width */
 mov d0,(32,sp)

10:                               /* ---- a band: y (32), its end (36), the spans (40) / (44), K (48) */
 mov (68,sp),d0
 cmp 1,d0
 beq 11f
 mov (8,sp),d1                    /* bands 0 and 2: the whole row (a = P, b = P) */
 mov d1,(40,sp)
 mov d1,(44,sp)
 mov (24,sp),d1                   /* band 0 ends at B, band 2 at H */
 cmp 0,d0
 beq 12f
 mov (12,sp),d1
 bra 12f
11:
 mov (28,sp),d1                   /* band 1: rows B .. H - B - 1, Bp pairs on each side */
 mov d1,(40,sp)
 mov (8,sp),d0
 sub d1,d0
 mov d0,(44,sp)
 mov (12,sp),d1
 mov (24,sp),d0
 sub d0,d1
12:
 mov d1,(36,sp)
 mov (40,sp),d0                   /* K = max(1, BD_LOCKN / (BD_PAIR (a + P - b) + BD_ROW)) */
 mov (8,sp),d1
 add d1,d0
 mov (44,sp),d1
 sub d1,d0
 asl2 d0                          /* BD_PAIR = 4 */
 add BD_ROW,d0
 mov d0,d1
 mov BD_LOCKN,d0
 call hl_div,[d2,d3,a2,a3],20
 cmp 1,d0
 bcc 13f
 mov 1,d0
13:
 mov d0,(48,sp)

20:                               /* ---- a group: min(K, the band's rows left) */
 mov (32,sp),d0
 mov (36,sp),d1
 cmp d1,d0
 bcc 40f                          /* the band is done */
 sub d0,d1
 mov (48,sp),d0
 cmp d0,d1
 bcc 21f
 mov d1,d0
21:
 mov d0,(52,sp)
22:
 mov (52,sp),d1                   /* (k - 1) pitch + 4 P bytes from row y */
 add -1,d1
 mov (16,sp),d0
 mul d0,d1
 mov (8,sp),d0
 asl2 d0
 add d0,d1
 mov (32,sp),d0
 mov (16,sp),d3
 mul d3,d0
 mov (20,sp),d3
 add d3,d0
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 bne 23f
 mov (56,sp),d0                   /* across the window's edge */
 call UNLOCK,[d2],8
 mov (52,sp),d0
 cmp 1,d0
 beq 30f                          /* one row: a pair at a time */
 mov 1,d0
 mov d0,(52,sp)
 bra 22b
23:
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 24f
 add -0x40000000,d0               /* the window's cached view */
 mov 1,d1
24:
 mov d1,(60,sp)
 mov d0,(64,sp)
25:                               /* each row: a pairs from the left, then pairs b .. P - 1 */
 mov (64,sp),a0
 mov (40,sp),d0
 cmp 0,d0
 beq 27f
26:
 mov d2,(a0)
 add 4,a0
 add -1,d0
 bne 26b
27:
 mov (8,sp),d0
 mov (44,sp),d1
 sub d1,d0
 beq 29f
 mov (64,sp),a0
 asl2 d1
 add d1,a0
28:
 mov d2,(a0)
 add 4,a0
 add -1,d0
 bne 28b
29:
 mov (64,sp),d0
 mov (16,sp),d1
 add d1,d0
 mov d0,(64,sp)
 mov (32,sp),d0
 inc d0
 mov d0,(32,sp)
 mov (52,sp),d0
 add -1,d0
 mov d0,(52,sp)
 bne 25b
 mov (60,sp),d0
 cmp 0,d0
 beq 291f
 call FLUSH,[d2,d3],16
291:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 bra 20b

30:                               /* ---- a row across the window's edge: each pair on its own (a3 = pair x) */
 clr d0
 mov d0,a3
31:
 mov (40,sp),d0                   /* x < a, or b <= x < P */
 cmp d0,a3
 bcs 32f
 mov (44,sp),d0
 cmp d0,a3
 bcs 34f                          /* the gap: jump to b */
 mov (8,sp),d0
 cmp d0,a3
 bcc 39f                          /* the row is done */
32:
 mov (32,sp),d0                   /* bus + y pitch + 4 x, 4 bytes */
 mov (16,sp),d1
 mul d1,d0
 mov (20,sp),d1
 add d1,d0
 mov a3,d1
 asl2 d1
 add d1,d0
 mov 4,d1
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 beq 33f                          /* not even this pair: left as it is */
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 35f
 add -0x40000000,d0
 mov 1,d1
35:
 mov d0,a0
 mov d2,(a0)
 cmp 0,d1
 beq 33f
 call FLUSH,[d2,d3],16
33:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 inc a3
 bra 31b
34:
 mov (44,sp),a3
 bra 31b
39:
 mov (32,sp),d0
 inc d0
 mov d0,(32,sp)
 bra 20b

40:                               /* ---- the next band */
 mov (68,sp),d0
 inc d0
 mov d0,(68,sp)
 cmp 3,d0
 bcc 99f
 cmp 2,d0
 bne 10b
 mov (12,sp),d1                   /* band 2 starts at H - B */
 mov (24,sp),d0
 sub d0,d1
 mov d1,(32,sp)
 bra 10b
99:
 ret [d2,d3,a2,a3],88

/* ---------------------------------------------------------------- films in camera memory, step 1 (2026-11-13)
 * The user's films (LOOKS.BIN image), on-camera edits (EDITS.BIN image) and Extras settings (BUNDLES.BIN image) live in
 * a block in the unused tail of the camera's settings store M, which the camera saves itself (issue #35, design by iancw
 * in PR #36; camera probe mp1 2026-11-13: the tail is kept over battery pulls). Owner, 2026-11-13: the camera takes a
 * card's films only when it never had that set before; no copies are written to the card.
 * Block at M image + 0x3A000 (RAM 0x6295a700, uncached 0xa295a700), UB_LEN bytes:
 *   +0 'OM3U' | +4 u16 version 1 | +6 u16 length | +8 CRC-32 of 16.. | +12 generation (+1 per write) | +16 seen-ring
 *   index | +20 0 | +24 16 x u32 seen identities (CRC-32 of a LOOKS image's bytes 32..: records and names) |
 *   +UB_LK LOOKS.BIN image | +UB_ED EDITS.BIN image | +UB_BN BUNDLES.BIN image.
 * Load (first gated half-press, sd_load): block valid -> the Extras and edits from it; the films from it, unless the
 * card's LOOKS.BIN is valid and its identity is not in the ring (new films: taken, with the camera's selection, the
 * camera's edits kept: changes of a film whose record changed drop by their own check). No valid block -> the card's
 * files as before, written into the block at once (migration). Save (ed_trig, a half-press after edits): the block
 * instead of BUNDLES / EDITS / LOOKS on the card. A write builds the block in ub_stg, then, with dispatch held (LOCK),
 * copies it into M (cached and uncached) and sets the changed byte 0xa32bfb32, only while the camera's save of M is not
 * running (its busy byte 0xa32a9904, set by 0x60063d73 before the checksum, cleared when the flash write is done);
 * else, or while the other task writes (ub_run), ub_pend and again at the next shutter event (ub_try). The camera
 * saves M at the return to shooting after a menu and at power-off (om-emu S-NVRAM + S-SHUTDOWN, 2026-11-13). We
 * never write flash.
 * Frames: a function that calls another keeps (0,sp) free for the call's return address (f2: ub_chk / ub_bun / ub_put
 * were 16 with four registers saved, so each call overwrote a saved register; harmless for their callers in f1). */
.section .ext12,"ax"
 .set UB_C, 0x6295a700             /* M image 0x62920700 + 0x3A000 */
 .set CV_STU, 0xa0fa9000           /* rgb-curves 2b: the curves record's buffers for ub_wr / ss_wr (rgbcurves.inc CW_SU / */
 .set CV_STS, 0xa0faa000           /* CW_SS in its work area; checked there) */
 .set UB_U, 0xa295a700
 .set UB_DIRTY, 0xa32bfb32
 .set UB_BUSY, 0xa32a9904
 .set UB_MAGIC, 0x55334d4f         /* "OM3U" */
 .set UB_PFL, 1632                 /* PF_LEN, FILE_LEN, HDR_LEN, CRC_TAIL (editor.ld) as numbers for .set / .space */
 .set UB_FL, 544
 .set UB_HDR, 32
 .set UB_CT, 524
 .set UB_LK, 88
 .set UB_ED, UB_LK + UB_PFL
 .set UB_BN, UB_ED + TW_LEN
 .set UB_LEN, UB_BN + UB_FL

ub_cpy:                           /* `call ub_cpy,[],0`: d1 bytes (a multiple of 4, > 0) from a1 to a0; uses d0, d1, a0, a1 */
 mov (a1),d0
 mov d0,(a0)
 add 4,a1
 add 4,a0
 add -4,d1
 bne ub_cpy
 ret [],0

ub_zero:                          /* `call ub_zero,[],0`: d1 bytes (a multiple of 4, > 0) at a0 <- 0; uses d0, d1, a0 */
 clr d0
1:
 mov d0,(a0)
 add 4,a0
 add -4,d1
 bne 1b
 ret [],0

ub_id:                            /* `call ub_id,[d2,d3],12`: a0 = a LOOKS image -> d0 = its films' identity (CRC-32 of 32..) */
 add 32,a0
 mov -1,d0
 mov UB_PFL - 32,d1
 call sd_crc,[d2,d3],12
 not d0
 ret [d2,d3],12

ub_chk:                           /* `call ub_chk,[d2,d3,a2,a3],20` -> d0 = ub_ok; the block is checked once per power-on */
 movbu (ub_st),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(ub_st)
 mov UB_C,a3
 mov (a3),d0
 cmp UB_MAGIC,d0
 bne 9f
 movhu (4,a3),d0
 cmp 1,d0
 bne 9f
 movhu (6,a3),d0
 cmp UB_LEN,d0
 bne 9f
 mov -1,d0
 mov a3,a0
 add 16,a0
 mov UB_LEN - 16,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 9f
 mov (12,a3),d0
 mov d0,(ub_gen0)
 mov d0,(ub_gen)
 mov 1,d0
 movbu d0,(ub_ok)
 movbu d0,(ub_ok0)
9:
 movbu (ub_ok),d0
 ret [d2,d3,a2,a3],20

ub_bun:                           /* `call ub_bun,[d2,d3,a2,a3],20` from sd_load before P is published, a2 = P */
 call ub_chk,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 mov a2,a0
 mov UB_C + UB_BN,a1
 mov UB_FL,d1
 call ub_cpy,[],0
9:
 ret [d2,d3,a2,a3],20

ub_pfl:                           /* `call ub_pfl,[d2,d3,a2,a3],28` from sd_load, a2 = P.
                                   * Local (8) buffer. With the block (above). */
 clr d0
 mov d0,(TTAB,a2)
 mov d0,(TORG,a2)
 mov d0,(STC,a2)
 mov d0,(SATB,a2)
 mov d0,(LVB,a2)
 movbu d0,(ub_new)
 movbu d0,(ub_cv)                 /* the card's LOOKS.BIN: 0 none, 1 valid, 2 there but not valid */
 mov 3,d0
 movbu d0,(ub_src)
 mov UB_PFL + FL_SB,d0
 call malloc,[],4
 cmp 0,a0
 bne 1f
 jmp 99f
1:
 mov a0,(8,sp)
 call ub_rd,[d2,d3,a2,a3],28
 call ub_chk,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 30f
 movbu (ub_cv),d0                 /* a valid block: the card's films only when the camera never had them */
 cmp 1,d0
 bne 20f
 mov (8,sp),a0
 call ub_kn,[d2,d3],12
 cmp 0,d0
 bne 20f                          /* had them: the camera's films */
 mov 1,d0                         /* new films: taken, with the camera's selection */
 movbu d0,(ub_src)
 movbu d0,(ub_new)
 mov (8,sp),a0
 mov (UB_C + UB_LK + 16),d0
 mov d0,(16,a0)
 bra 40f
20:
 mov (8,sp),a0
 mov UB_C + UB_LK,a1
 mov UB_PFL,d1
 call ub_cpy,[],0
 clr d0
 movbu d0,(ub_src)
 bra 40f
30:
 movbu (ub_cv),d0                 /* no block: the card's films as before, then kept in the camera */
 cmp 1,d0
 bne 31f
 mov 2,d0
 movbu d0,(ub_src)
 mov 1,d0
 movbu d0,(ub_new)
 bra 40f
31:
 cmp 2,d0
 beq 98f                          /* a file that fails the check and no block: no bank */
 mov (8,sp),a0                    /* no file and no block: a neutral bank (not written into the block) */
 mov UB_PFL,d1
 call ub_zero,[],0
 mov (8,sp),a0
 mov PFMAGIC,d0
 mov d0,(a0)
 mov UB_PFL,d0
 mov d0,(4,a0)
 mov 1,d0
 movhu d0,(12,a0)
 mov 20,d0
 movhu d0,(14,a0)
40:
 mov (8,sp),a0                    /* the selection -> P+LIDX */
 clr d2
41:
 mov a0,a1
 add d2,a1
 movbu (16,a1),d0
 mov a2,a1
 add d2,a1
 movbu d0,(LIDX,a1)
 inc d2
 cmp 4,d2
 bne 41b
 mov (8,sp),d0
 mov d0,(LPTR,a2)                 /* published last */
 call fl_mk2,[d2,d3,a2,a3],80     /* film pictures, TONES.BIN, the card's EDITS.BIN */
 movbu (ub_ok),d0                 /* a valid block: the camera's edits instead */
 cmp 0,d0
 beq 42f
 mov (TORG,a2),a0
 cmp 0,a0
 beq 42f
 add TWO,a0
 mov UB_C + UB_ED,a1
 mov TW_LEN,d1
 call ub_cpy,[],0
42:
 call cv_load,[d2,d3,a2,a3],20    /* rgb-curves: the curves record, with this block only */
 movbu (ub_new),d0                /* new or first films: into the block now */
 cmp 0,d0
 beq 99f
 call ub_put,[d2,d3,a2,a3],20
 bra 99f
98:
 mov (8,sp),a0
 call free,[],4
99:
 ret [d2,d3,a2,a3],28

ub_rd:                            /* `call ub_rd,[d2,d3,a2,a3],28`, a0 = a buffer of UB_PFL: the card's LOOKS.BIN into it
                                   * -> ub_cv (0 on entry). Locals (4) handle, (8) buffer. */
 mov a0,(8,sp)
 call pf_open,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov 2,d0
 movbu d0,(ub_cv)
 mov (8,sp),a0
 mov 1,d0
 mov UB_PFL,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 cmp UB_PFL,d2
 bne 9f
 mov (8,sp),a0
 mov UB_PFL,d3
 call pf_check,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(ub_cv)
9:
 ret [d2,d3,a2,a3],28

ub_kn:                            /* `call ub_kn,[d2,d3],12`, a0 = a LOOKS image -> d0 1 when the block's ring holds its
                                   * films' identity, else 0. Stores ub_cid. */
 call ub_id,[d2,d3],12
 mov d0,(ub_cid)
 mov UB_C + 24,a0
 mov 16,d1
1:
 mov (a0),d2
 cmp d2,d0
 beq 2f
 add 4,a0
 add -1,d1
 bne 1b
 clr d0
 ret [d2,d3],12
2:
 mov 1,d0
 ret [d2,d3],12

ub_put:                           /* `call ub_put,[d2,d3,a2,a3],20`, a2 = P: films, edits and Extras now -> the block
                                   * -> d0 1 written, 0 not (no films loaded; or the camera saving M, or a write
                                   * already running in another task: ub_pend). ed_trig (HLS_EVENT task) and pm_save
                                   * (GUI task) both build the block in ub_stg, so one at a time (ub_run). */
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (ub_run),d0
 mov d0,a3
 mov 1,d0
 movbu d0,(ub_run)
 mov d3,d0
 call UNLOCK,[d2],8
 mov a3,d0
 cmp 0,d0
 bne 8f
 call ub_wr,[d2,d3,a2,a3],20
 clr d1
 movbu d1,(ub_run)
 ret [d2,d3,a2,a3],20
8:
 mov 1,d0
 movbu d0,(ub_pend)
 clr d0
 ret [d2,d3,a2,a3],20

ub_wr:                            /* ub_put's write, with ub_run held */
 mov (LPTR,a2),a3
 cmp 0,a3
 bne 1f
 clr d0
 ret [d2,d3,a2,a3],20
1:
 clr d2                           /* LOOKS: the selection bytes and the CRC */
2:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp 1,d0
 blt 3f
 cmp 5,d0
 ble 4f
3:
 clr d0
4:
 mov a3,a0
 add d2,a0
 movbu d0,(16,a0)
 inc d2
 cmp 4,d2
 bne 2b
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov UB_PFL - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(8,a3)
 mov ub_stg + UB_LK,a0
 mov a3,a1
 mov UB_PFL,d1
 call ub_cpy,[],0
 mov (TORG,a2),a3                 /* EDITS: header and CRC */
 cmp 0,a3
 beq 6f
 add TWO,a3
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
 mov ub_stg + UB_ED,a0
 mov a3,a1
 mov TW_LEN,d1
 call ub_cpy,[],0
 bra 8f
6:
 mov ub_stg + UB_ED,a0            /* no film block: the camera's edits as they were, or none */
 mov TW_LEN,d1
 movbu (ub_ok),d0
 cmp 0,d0
 beq 7f
 mov UB_C + UB_ED,a1
 call ub_cpy,[],0
 bra 8f
7:
 call ub_zero,[],0
8:
 mov ub_stg + UB_BN,a0            /* Extras: P[0..543], slots in range, header CRC */
 mov a2,a1
 mov UB_FL,d1
 call ub_cpy,[],0
 mov ub_stg + UB_BN + UB_HDR,a0
 call sd_san,[d2,d3],12
 mov -1,d0
 mov ub_stg + UB_BN,a0
 mov 16,d1
 call sd_crc,[d2,d3],12
 mov ub_stg + UB_BN + 20,a0
 mov UB_CT,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(ub_stg + UB_BN + 16)
 mov ub_stg + 16,a0               /* the seen ring and generation: the block's, or new */
 mov 72,d1
 movbu (ub_ok),d0
 cmp 0,d0
 beq 9f
 mov UB_C + 16,a1
 call ub_cpy,[],0
 mov (UB_C + 12),d0
 bra 10f
9:
 call ub_zero,[],0
 clr d0
10:
 inc d0
 mov d0,(ub_stg + 12)
 mov ub_stg + UB_LK,a0            /* these films' identity into the ring (once) */
 call ub_id,[d2,d3],12
 mov d0,d2
 mov ub_stg + 24,a0
 mov 16,d1
11:
 mov (a0),d0
 cmp d2,d0
 beq 12f
 add 4,a0
 add -1,d1
 bne 11b
 mov (ub_stg + 16),d0
 mov d0,d1
 and 15,d1
 asl2 d1
 mov ub_stg + 24,a0
 add d1,a0
 mov d2,(a0)
 inc d0
 mov d0,(ub_stg + 16)
12:
 mov UB_MAGIC,d0                  /* header and CRC */
 mov d0,(ub_stg)
 mov 1,d0
 movhu d0,(ub_stg + 4)
 mov UB_LEN,d0
 movhu d0,(ub_stg + 6)
 clr d0
 mov d0,(ub_stg + 20)
 mov -1,d0
 mov ub_stg + 16,a0
 mov UB_LEN - 16,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(ub_stg + 8)
 mov (ub_stg + 12),d0             /* rgb-curves: the curves record goes with this block (packed here, before LOCK) */
 mov CV_STU,a0
 call cv_hdr,[d2,d3,a2,a3],20
 clr d0                           /* into M with dispatch held, only while the camera is not saving it */
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 20f
 mov UB_C,a0
 mov ub_stg,a1
 mov UB_LEN,d1
 call ub_cpy,[],0
 mov UB_U,a0
 mov ub_stg,a1
 mov UB_LEN,d1
 call ub_cpy,[],0
 mov CV_STU,a1                    /* rgb-curves 2b: only a copy with interrupts off */
 call cv_put,[d2],8
 mov 1,d0
 movbu d0,(UB_DIRTY)              /* M changed: the camera saves it at the next return to shooting or power-off */
 mov d3,d0
 call UNLOCK,[d2],8
 mov 1,d0
 movbu d0,(ub_ok)
 clr d0
 movbu d0,(ub_pend)
 mov (ub_stg + 12),d0
 mov d0,(ub_gen)
 mov (ub_nw),d0
 inc d0
 mov d0,(ub_nw)
 mov 1,d0
 ret [d2,d3,a2,a3],20
20:
 mov d3,d0
 call UNLOCK,[d2],8
 mov 1,d0
 movbu d0,(ub_pend)
 clr d0
 ret [d2,d3,a2,a3],20

pm_save:                          /* `call pm_save,[d2,d3,a2,a3],24` from gx_map leaving Picture Mode (GUI task):
                                   * edits not saved yet -> the block in M now, so a power-off without a half-press
                                   * keeps them (the camera saves M at the return to shooting and at power-off) */
 PVAL 9f
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (DIRTY,a2),d0
 mov d0,a3
 clr d0
 movbu d0,(DIRTY,a2)              /* taken here; ed_trig reads it unlocked, so at worst both save (harmless) */
 mov d3,d0
 call UNLOCK,[d2],8
 mov a3,d0
 cmp 1,d0
 bne 9f
 call ub_put,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov 1,d0                         /* not written (held back, or the other task's write): ed_trig tries again */
 movbu d0,(DIRTY,a2)
 bra 9f
8:
 call ss_pm,[d2,d3,a2,a3],20      /* per-mode settings p1: the set's copy too */
9:
 ret [d2,d3,a2,a3],24

ub_save:                          /* `call ub_save,[d2,d3,a2,a3],24` from ed_trig (owner,
                                   * 2026-11-13: no card copies), a2 = P -> d0 status 1 */
 call ub_put,[d2,d3,a2,a3],20
 mov (XPTR,a2),a1                 /* code block +72 after each half-press save */
 cmp 0,a1
 beq 7f
 add 72,a1
 calls (a1)
7:
 mov 1,d0
 ret [d2,d3,a2,a3],24

ub_try:                           /* `call ub_try,[d2,d3,a2,a3],36` from lg_pr after ed_trig: a held-back write again,
                                   * with ed_trig's gate (card mounted, HLS_EVENT task, shooting state) */
 movbu (ub_pend),d0
 cmp 0,d0
 beq 9f
 PVAL 9f
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f
 call ub_put,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],36


 .balign 4
ub_cid:
 .long 0
ub_gen0:
 .long 0
ub_gen:
 .long 0
ub_nw:
 .long 0
ub_st:
 .byte 0
ub_ok:
 .byte 0
ub_ok0:
 .byte 0
ub_cv:
 .byte 0
ub_src:
 .byte 3
ub_new:
 .byte 0
ub_pend:
 .byte 0
ub_run:
 .byte 0
 .balign 4
ub_stg:
 .space UB_LEN

 .balign 4


/* ---------------------------------------------------------------- films in camera memory, step 2 (2026-11-13)
 * GUIDES.BIN (guide pictures and the code block), LABELS.BIN and TONES.BIN are built into the firmware: build.py puts
 * them in the GX4-proven reserve after ext12 (0x60f99800.., camera-tested 2026-11-12) and raises the loader's end word
 * to cover them; bf_tab holds their addresses and sizes. Every fopen / fread / fseek / ftell / fclose of ours (and of
 * the code block: build.py links it to these) goes through the wrappers below: a read of one of the three names gets a
 * handle on the built-in copy, anything else goes to the camera's own functions (OS_*, editor.ld). So a card without
 * OM3MOD works in full, and the card's copies of these files are never read. Handles: a pool of VF_SLOTS
 * {in use, address, size, position} in ext12 RAM (taken with dispatch held). */
.section .ext12,"ax"
 .set VF_N, 3
 .set VF_SLOTS, 4
 .macro VFCHK reg, notours        /* \reg not one of our handles -> \notours (flags only) */
 cmp bf_pool,\reg
 bcs \notours
 cmp bf_pool + 16 * VF_SLOTS,\reg
 bcc \notours
 .endm

fopen:                            /* `call fopen,[],4`: a0 path, a1 mode -> a0 handle or 0 */
 call vf_find,[d2,d3,a2,a3],16
 cmp 0,d0
 blt 1f
 call vf_new,[d2,d3,a2,a3],20
 ret [],4
1:
 movbu (el_nc),d0                 /* L1: the early load takes nothing from the card */
 cmp 0,d0
 beq 2f
 mov 0,a0
 ret [],4
2:
 call OS_FOPEN,[],4
 ret [],4

vf_find:                          /* `call vf_find,[d2,d3,a2,a3],16`: a0 path, a1 mode -> d0 = the bf_tab row of a read
                                   * of a built-in file, else -1; keeps a0, a1 */
 mov a0,a2
 mov a1,a3
 mov -1,d3
 movbu (a3),d0
 cmp 114,d0                       /* 'r' */
 bne 9f
 clr d2
1:
 mov d2,d0
 mov d0,d1
 asl 3,d0
 asl2 d1
 add d1,d0
 mov bf_tab,a0
 add d0,a0
 mov (8,a0),d0                    /* not built in (size 0): the card */
 cmp 0,d0
 beq 3f
 mov (a0),a0
 mov a2,a1
2:
 movbu (a0),d0
 movbu (a1),d1
 cmp d0,d1
 bne 3f
 cmp 0,d0
 beq 8f
 inc a0
 inc a1
 bra 2b
3:
 inc d2
 cmp VF_N,d2
 bne 1b
 bra 9f
8:
 mov d2,d3
9:
 mov d3,d0
 mov a2,a0
 mov a3,a1
 ret [d2,d3,a2,a3],16

vf_new:                           /* `call vf_new,[d2,d3,a2,a3],20`: d0 = bf_tab row -> a0 = a handle on it, 0 if none free */
 mov d0,d2
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 mov bf_pool,a2
 mov VF_SLOTS,d1
1:
 mov (a2),d0
 cmp 0,d0
 beq 2f
 add 16,a2
 add -1,d1
 bne 1b
 mov 0,a2
 bra 3f
2:
 mov 1,d0
 mov d0,(a2)
3:
 mov d3,d0
 call UNLOCK,[d2],8
 cmp 0,a2
 beq 9f
 mov d2,d0
 mov d0,d1
 asl 3,d0
 asl2 d1
 add d1,d0
 mov bf_tab,a0
 add d0,a0
 mov (4,a0),d0
 mov d0,(4,a2)
 mov (8,a0),d0
 mov d0,(8,a2)
 clr d0
 mov d0,(12,a2)
9:
 mov a2,a0
 ret [d2,d3,a2,a3],20

fread:                            /* `call fread,[d2,d3,a2,a3],24`: a0 buffer, d0 item size, d1 count, a1 handle -> d0 items */
 VFCHK a1, 1f
 mov d0,d2
 mov d1,d3
 clr d0
 cmp 0,d2
 beq 8f
2:
 cmp 0,d3                         /* bytes wanted = size x count */
 beq 3f
 add d2,d0
 add -1,d3
 bra 2b
3:
 mov (8,a1),d3                    /* bytes left = size - position */
 mov (12,a1),d1
 sub d1,d3
 cmp d3,d0
 bls 4f
 mov d3,d0
4:
 mov d0,d3                        /* d3 = bytes to copy */
 mov (4,a1),a2
 add d1,a2
 cmp 0,d0
 beq 6f
5:
 movbu (a2),d1
 movbu d1,(a0)
 inc a2
 inc a0
 add -1,d0
 bne 5b
6:
 mov (12,a1),d1
 add d3,d1
 mov d1,(12,a1)
 mov d3,d0                        /* items = bytes / size */
 cmp 1,d2
 beq 8f
 clr d1
7:
 cmp d2,d0
 bcs 71f
 sub d2,d0
 inc d1
 bra 7b
71:
 mov d1,d0
8:
 ret [d2,d3,a2,a3],24
1:
 call OS_FREAD,[d2,d3,a2,a3],24
 ret [d2,d3,a2,a3],24

fseek:                            /* `call fseek,[d2,d3,a2,a3],20`: a0 handle, d0 offset, d1 whence (0 here, 1 end, 2 start) -> d0 0 */
 VFCHK a0, 1f
 cmp 2,d1
 beq 3f
 cmp 1,d1
 bne 2f
 mov (8,a0),d1
 add d1,d0
 bra 3f
2:
 mov (12,a0),d1
 add d1,d0
3:
 cmp 0,d0
 blt 4f
 mov (8,a0),d1
 cmp d1,d0
 bgt 4f
 mov d0,(12,a0)
 clr d0
 ret [d2,d3,a2,a3],20
4:
 mov -1,d0
 ret [d2,d3,a2,a3],20
1:
 call OS_FSEEK,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20

ftell:                            /* `call ftell,[d2,a2,a3],16`: a0 handle -> d0 position */
 VFCHK a0, 1f
 mov (12,a0),d0
 ret [d2,a2,a3],16
1:
 call OS_FTELL,[d2,a2,a3],16
 ret [d2,a2,a3],16

fclose:                           /* `call fclose,[d2,a2,a3],16`: a0 handle */
 VFCHK a0, 1f
 clr d0
 mov d0,(a0)
 ret [d2,a2,a3],16
1:
 call OS_FCLOSE,[d2,a2,a3],16
 ret [d2,a2,a3],16

 .balign 4
bf_tab:                           /* {name, address, size} x VF_N; address and size: build.py (0 = not built in) */
 .long lg_f0, 0, 0                /* GUIDES.BIN */
 .long lg_f1, 0, 0                /* LABELS.BIN */
 .long lg_f2, 0, 0                /* TONES.BIN */
bf_pool:
 .space 16 * VF_SLOTS

pr_nmd:                           /* v0.29.1 (#38): jmp from pr_gate (its frame) when no medium is mounted. With a valid
                                   * block the films come from the camera's memory: load now, so a camera with no card
                                   * gets its films too (v0.29 waited for a card for ever). A card's new LOOKS.BIN, if
                                   * its card was not mounted yet at this shutter event, is then taken at the next
                                   * power-on. No block: wait for a card as before. */
 call ub_chk,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 1f
 jmp pr_go
1:
 jmp pr_gout

/* ---- Films and the shooting mode (v0.30-dev k1, #41). Turning the mode dial (P / A / S / M / B / C1..C5) makes the
 * camera swap COLOR 1..4's own settings (saturation, contrast, tone and the rest of a film's 18 camera settings) for
 * that mode's saved ones in one block, past the settings manager (om-emu: P -> C2 gave COLOR 3 +4 saturation on every
 * colour, C2's own; back to P restored P's). Our film choice (P+LIDX) does not change, so the camera then shot the film
 * mixed with those settings, and the next film switch captured them into the film being left (its '*'). sx_set notes a
 * shooting-mode write (id 162) while the films are in; at the next GUI event rc_go puts each COLOR's film (its saved
 * changes when valid, else as built: fl_sw's own choice) back with pf_put1, through the manager with its own handle,
 * as a film pick does. Nothing is captured and nothing is marked to save. COLOR k on its own settings: left as the
 * mode has them (stock). */
rc_go:                            /* `call rc_go,[d2,d3,a2,a3],24` from sx_set's 1440 (k4) or gx_map (GUI task) */
 clr d0
 movbu d0,(rc_pend)
 clr d0                           /* k4: one at a time (two tasks may get here); a busy one is retried by gx_map */
 call LOCK,[d2],8
 mov d0,d3
 movbu (rc_busy),d0
 cmp 0,d0
 beq 02f
 mov d3,d0
 call UNLOCK,[d2],8
 mov 1,d0
 movbu d0,(rc_pend)
 ret [d2,d3,a2,a3],24
02:
 mov 1,d0
 movbu d0,(rc_busy)
 mov d3,d0
 call UNLOCK,[d2],8
 mov (rc_in),d0
 cmp 0,d0
 beq 9f                           /* no manager handle seen yet */
 call ss_photo,[],0
 cmp 0,d0
 beq 9f                           /* video / S&Q: no film work. Films are photo only, and the camera's settings written
                                   * while video live view starts freeze its image (#53); the next photo look does it */
 movbu (cm_init),d0
 cmp 0,d0
 beq 03f                          /* the first look: the dial stands for the code still 0 after a power-on */
 call cm_gnow,[],0
 movbu (cm_code),d0
 cmp 0xc0,d0
 bcs 03f
 mov 1,d0                         /* a live dial turn: the dial has moved and the camera's code has not. The camera
                                   * still holds the old mode's settings, so wait for the real code (gx_map, #54) */
 movbu d0,(rc_pend)
 movbu d0,(lv_hold)               /* #54: the label shows no picture until then */
 bra 91f
03:
 PVAL 9f
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 mov (TORG,a2),d0
 cmp 0,d0
 beq 9f
 movbu (cm_pend),d0
 cmp 0,d0
 beq 01f
 call cm_wr,[d2,d3,a2,a3],20      /* k2: a held-back record write */
01:
 call ss_pre,[d2,d3,a2,a3],24     /* p1: per-mode settings, before the films switch */
 call cm_go,[d2,d3,a2,a3],24      /* k2: the custom mode's films (film saved with Assign), a2 = P */
 call ss_post,[d2,d3,a2,a3],24    /* p1: the set's own rows; ss_mask = the COLORs still put back */
 clr d2
1:
 mov 1,d0                         /* p1: only the COLORs ss_post left to put back */
 asl d2,d0
 movbu (ss_mask),d1
 and d1,d0
 beq 2f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 2f
 cmp 5,d3
 bgt 2f                           /* COLOR k on its own settings: as the mode has them */
 call rc_put,[d2,d3,a2,a3],40
 mov (rc_n),d0
 inc d0
 mov d0,(rc_n)
2:
 inc d2
 cmp 4,d2
 bcs 1b
 clr d0
 movbu d0,(rc_ab)
 call ss_wr,[d2,d3,a2,a3],20      /* p1 */
9:
 call lv_end,[],4                 /* #54: every way out but the wait: the label back, redrawn */
91:
 clr d0
 movbu d0,(rc_busy)
 ret [d2,d3,a2,a3],24

rc_put:                           /* `call rc_put,[d2,d3,a2,a3],40`, a2 = P, d2 = k, d3 = look 1..5: COLOR k's 18
                                   * camera settings (pf_ids) <- that film (its saved changes when valid, else as built:
                                   * fl_sw's choice), each only when the camera's value differs (a P <-> A turn writes
                                   * nothing). Our slot is not touched (the camera's swap leaves it alone). Locals
                                   * (4) k, (8) the record, (12) i, (16) id, (20) the film's value (frame 40: the four
                                   * saved registers sit above them, at (24..39)). */
 mov d2,(4,sp)
 call rc_rec,[d2,d3,a2],20       /* p1: the record choice moved to rc_rec */
 mov a3,(8,sp)
 clr d0
 mov d0,(12,sp)
1:
 mov (12,sp),d3
 mov pf_ids,a0
 mov d3,d0
 asl2 d0
 add d0,a0
 movbu (2,a0),d1
 mov (4,sp),d2
 mul d2,d1
 movhu (a0),d0
 add d1,d0                        /* id */
 mov d0,(16,sp)
 movbu (3,a0),d2                  /* record offset */
 mov (8,sp),a1
 movbu (d2,a1),d1
 extb d1
 mov d1,(20,sp)
 call sget,[],4                   /* d0 = the camera's value now (keeps d2, d3, a2, a3) */
 mov (20,sp),d1
 cmp d1,d0
 beq 2f
 mov (16,sp),d0
 mov (rc_in),a0                   /* the manager's handle and mode 0, as every write the camera makes (om-emu) */
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rc_w),d0
 inc d0
 mov d0,(rc_w)
2:
 mov (12,sp),d3
 inc d3
 mov d3,(12,sp)
 cmp 18,d3
 bcs 1b
 ret [d2,d3,a2,a3],40

 .balign 4
rc_in:
 .long 0
rc_d0:
 .long 0
rc_n:
 .long 0
rc_w:
 .long 0
rc_pend:
 .byte 0

/* ---- The shooting screen's label during a live dial turn (#54, owner 2026-11-15: no picture while the switch waits).
 * The camera sets the new mode's picture mode at the turn and draws the label from the films still loaded, so it
 * showed the old looks' "COLOR1*" until the switch. lv_hold is set while rc_go waits for the mode's code (its wait,
 * and the 901 hook when the camera writes first), and fl_lvp then answers lv_slot, a picture with no ink. Every other
 * way out of rc_go clears it (lv_end). The label is drawn only when the shooting screen's record (data item 38, 464 B)
 * is written: the camera writes it (0x6122fb93) only when its contents differ (0x61230448), so neither a same-value
 * 901 write nor none at all redraws it. lv_end writes the record back as it is, as the camera does, which marks it
 * changed, and the screen then asks the label again. */
 .set LV_ITEM, 38                 /* the shooting screen's record in the camera's data store (0x6036f6e4) */
 .set LV_RLEN, 464
lv_due:                           /* `call lv_due,[d2,d3],12` from sx_set's 901: lv_hold <- 1 when a photo mode's switch
                                   * waits (rc_pend) or the mode's code is not yet a mode (cm_code 0xC0..). Keeps d1, a0,
                                   * a1. Only with the films in: without them no rc_go runs to clear the hold, and the
                                   * camera's own label would stay blank. */
 mov d1,d2
 mov a0,d3
 call dm_ok,[],0                  /* films loaded? (d1; d0, a0, a1 kept) */
 cmp 0,d1
 beq 9f
 movbu (rc_pend),d0
 cmp 0,d0
 bne 1f
 movbu (cm_code),d0
 cmp 0xc0,d0
 bcs 9f
1:
 call ss_photo,[],0
 cmp 0,d0
 beq 9f
 mov 1,d0
 movbu d0,(lv_hold)
9:
 mov d2,d1
 mov d3,a0
 ret [d2,d3],12

lv_end:                           /* `call lv_end,[],4` from rc_go: lv_hold <- 0; when it was set, the shooting screen's
                                   * record written back (the label redrawn). Uses d0, d1, a0, a1. */
 movbu (lv_hold),d0
 cmp 0,d0
 beq 9f
 clr d0
 movbu d0,(lv_hold)
 mov lv_rec,a0
 mov LV_ITEM,d0
 mov LV_RLEN,d1
 call ds_get,[],4
 cmp 0,d0
 beq 9f
 mov lv_rec,a0
 mov LV_ITEM,d0
 mov LV_RLEN,d1
 mov 0,a1
 call ds_put,[d2,a2],16
9:
 ret [],4

lv_chk:                           /* `call lv_chk,[],4` from fl_lvp -> d0 1 for no picture: lv_hold set, or a photo
                                   * look after the first whose dial mode (cm_gnow) is not the group the films are in
                                   * (CM_LAST). The camera can change the picture mode at a turn with no 901 write and
                                   * read as video until the mode's code comes (DS3d), so rc_go cannot hold it. Sets
                                   * lv_hold, so the switch's lv_end redraws. Uses d0, d1, a0, a1. */
 movbu (lv_hold),d0
 cmp 0,d0
 bne 8f
 movbu (cm_init),d0
 cmp 0,d0
 beq 9f
 movbu (UI_PSW),d0
 cmp 2,d0
 bne 7f
 call dm_ok,[],0
 cmp 0,d1
 beq 7f
 call cm_gnow,[],0
 movbu (cm_ram + CM_LAST),d1
 cmp d1,d0
 beq 7f
 mov 1,d0
 movbu d0,(lv_hold)
8:
 mov 1,d0
 ret [],4
7:
 clr d0
9:
 ret [],4

lv_hold:
 .byte 0
 .balign 4
lv_slot:                          /* a slot word, as ic_get answers */
 .long lv_desc
lv_desc:                          /* as fl_lvp's: format 14, 96 x 44, the picture by its uncached address */
 .short 14, 96, 44, 8, 0, 0
 .long lv_pend - lv_pic, lv_pic + 0x40000000, 0
 .balign 8
lv_pic:                           /* type-11 stream (mkicons.encode11): 96 x 44 of color 0, as "FILM N" around its ink */
 .byte 43, 0xf0, 5, 11
 .rept 52
 .long 0x0f00f00f, 0x000f00f0     /* 5 runs of 16 */
 .endr
 .long 0x0f00f00f, 0x000000f0     /* the last 4 */
lv_pend:
 .balign 4
lv_rec:
 .space LV_RLEN

/* ---- Custom modes keep their own films (v0.30-dev k2, #41, owner 2026-11-14: "film saved with Assign"). Assign
 * (Shooting menu 1 > Custom Mode > Cn > Assign > Set) calls the facade's entry 18 (vtable word 0x60e574bc, stock
 * 0x60b8764c) with d0 = n - 1 (C1..C5 = 0..4), d1 = 0 (om-emu, menu 0x611a93be); cm_asg notes the films in use then
 * (P+LIDX, one look per COLOR) for that custom mode. At each mode-dial change (rc_go, after the camera's own swap) the
 * mode's code (the settings object's byte +24, behind the manager's handle: P 1, A 2, C1..C5 53..57) picks the group;
 * on a group change P / A / S / M / B's films are kept when leaving them, and the new group's come back: a custom mode
 * its Assign films, P / A / S / M / B theirs (a custom mode's changes are forgotten, the camera's "Save Settings:
 * Reset"; "Keep" is not followed yet). A film switch here is fl_sw's own (its no-capture reset flag: the camera's
 * settings already hold the new mode's, so nothing is captured into the film being left). Kept in M's free tail at
 * +0x3B000 ('OM3C', CRC), written as ub_put writes its block. The first GUI event after the films are in looks once,
 * so a dial moved while the camera was off is handled then (not at start-up: STATE is 0 until the first half-press). */
 .set CM_C, 0x6295b700            /* M image + 0x3B000 */
 .set CM_U, 0xa295b700
 .set CM_MAGIC, 0x43334d4f        /* "OM3C" */
 .set CM_LEN, 48                  /* +0 magic, +4 u16 2, +6 u16 len, +8 crc(12..), +12 flags (bit n: Cn+1 set, bit 7: P
                                   * group's films kept), +13 last group (0..4 C1..C5, 5 P group, 0xff none), +14 the P
                                   * group's choice, +16 the P group's 4 looks, +20 C1..C5's 4 looks each, +40 C1..C5's
                                   * choice. A choice (k3) = the picture mode's 901 value: FV0 + j for film j, else
                                   * COLOR k's own picture mode (54, 55, 56, 64); 0 = not COLOR 1..4 (left alone) */
 .set CM_VER, 2                   /* k3: v1 records (k2, no choice) are not read */
 .set CM_FL, 12
 .set CM_LAST, 13
 .set CM_PM, 14
 .set CM_P, 16
 .set CM_S, 20
 .set CM_SPM, 40

cm_asg:                           /* facade entry 18 (Assign), entered by `calls`: d0 slot, d1 0 Set, a0 the facade */
 movm [d2,d3,a2,a3],(sp)
 add -16,sp                       /* (0) call slot, (4) d0, (8) d1, (12) a0 */
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 call cm_rec,[d2,d3,a2,a3],20     /* d0, d1 as entered */
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 add 16,sp
 movm (sp),[d2,d3,a2,a3]
 jmp cm_stock                     /* the camera's own Assign (0x60b8764c, editor.ld) */

cm_rst:                           /* per-mode p2: facade entry 19 (Assign > Reset; vtable word 0x60e574c0, stock 0x60b86aaf,
                                   * om-emu: the menu's Reset > OK calls it with d0 = the custom mode 0..4; Set is entry 18),
                                   * entered by `calls`: no films of ours for it any more, and its rows built from the
                                   * films as built at its next entry (cm_rec's clear path, ss_rst); then the camera's own */
 movm [d2,d3,a2,a3],(sp)
 add -20,sp                       /* (0) call slot, (4) d0, (8) d1, (12) a0, (16) a1 */
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 mov 1,d1
 call cm_rec,[d2,d3,a2,a3],20
 mov (4,sp),d0
 mov (8,sp),d1
 mov (12,sp),a0
 mov (16,sp),a1
 add 20,sp
 movm (sp),[d2,d3,a2,a3]
 jmp cm_xstock

cm_rec:                           /* `call cm_rec,[d2,d3,a2,a3],20`: d0 = slot 0..4, d1 = 0 (Set) or other (clear) */
 mov d0,d2
 mov d1,d3
 cmp 5,d2
 bcc 9f
 call cm_ld,[d2,d3,a2,a3],20
 movbu (cm_ram + CM_FL),d0
 mov 1,d1
 asl d2,d1
 cmp 0,d3
 beq 1f
 not d1                           /* not Set: no films for that custom mode */
 and d1,d0
 movbu d0,(cm_ram + CM_FL)
 mov d2,d0
 call ss_rst,[d2,d3,a2,a3],20     /* p1: its rows built from the films at its next entry */
 bra 8f
1:
 PVAL 9f
 mov (LPTR,a2),a0
 cmp 0,a0
 beq 9f                           /* no films loaded: nothing to keep */
 movbu (cm_ram + CM_FL),d0
 mov 1,d1
 asl d2,d1
 or d1,d0
 movbu d0,(cm_ram + CM_FL)
 mov d2,d0
 asl2 d0
 mov cm_ram + CM_S,a0
 add d0,a0
 mov a2,a1
 add LIDX,a1
 mov 4,d1
 call ub_cpy,[],0
 call cm_val,[d2,d3,a2,a3],20     /* k3: the picture mode chosen, too */
 mov cm_ram + CM_SPM,a0
 movbu d0,(d2,a0)
 mov (cm_na),d0
 inc d0
 mov d0,(cm_na)
 mov d2,d0
 call ss_asg,[d2,d3,a2,a3],20     /* p1: its rows <- the mode now */
8:
 call cm_wr,[d2,d3,a2,a3],20
 call ss_wr,[d2,d3,a2,a3],20      /* p1 */
9:
 ret [d2,d3,a2,a3],20

cm_go:                            /* `call cm_go,[d2,d3,a2,a3],24` from rc_go, a2 = P (films in). The group now
                                   * (cm_gnow); the first look after the films are in enters it whatever came before; a
                                   * change saves the group being left when it keeps its changes (P / A / S / M always,
                                   * a custom mode set to Save Settings: Hold, k6) and enters the new one (its kept
                                   * films and choice, cm_load). A Recall (cm_force, k6) loads that custom mode's films
                                   * into the group now and keeps them there when the group keeps its changes. */
 call cm_ld,[d2,d3,a2,a3],20
 movbu (cm_init),d0
 movbu d0,(cm_first)              /* 0: the first look */
 mov 1,d0
 movbu d0,(cm_init)
 mov (cm_sw),d0
 mov d0,(cm_sw0)
 clr d0
 movbu d0,(cm_pmw)
 call cm_gnow,[],0
 movbu d0,(cm_grp)
 movbu (cm_ram + CM_LAST),d1
 movbu d1,(cm_lst)
 movbu d0,(cm_ram + CM_LAST)
 movbu (cm_force),d1
 cmp 0,d1
 beq 1f
 clr d0                           /* a Recall of C(d1): its films into the group now */
 movbu d0,(cm_force)
 add -1,d1
 mov d1,d0
 call cm_src,[d2,d3,a2],16
 cmp 0,a3
 beq 8f
 call cm_load,[d2,d3,a2,a3],24
 movbu (cm_grp),d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 8f
 movbu (cm_grp),d0
 call cm_save,[d2,d3,a2,a3],20
 bra 8f
1:
 movbu (cm_first),d1
 cmp 0,d1
 beq 05f                          /* the first look: enter the group now */
 movbu (cm_lst),d1
 movbu (cm_grp),d0
 cmp d0,d1
 bne 2f
 jmp 90f                          /* the same group: nothing */
2:
 mov d1,d0                        /* leaving cm_lst: kept when that group keeps its changes */
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 3f
 movbu (cm_lst),d0
 call cm_save,[d2,d3,a2,a3],20
3:
 movbu (cm_grp),d0                /* entering cm_grp */
 call cm_src,[d2,d3,a2],16
 cmp 0,a3
 bne 4f
 call cm_val,[d2,d3,a2,a3],20     /* nothing kept for it: as it is (P keeps this from now) */
 movbu d0,(cm_gpm)
 movbu (cm_grp),d0
 cmp 5,d0
 bne 8f
 call cm_save,[d2,d3,a2,a3],20
 bra 8f
05:
 movbu (el_pick),d1               /* a film or COLOR picked after the early load, before this look: what is shown stays */
 cmp 0,d1
 beq 3b
 bra 8f
4:
 call cm_load,[d2,d3,a2,a3],24
8:
 call cm_wr,[d2,d3,a2,a3],20
90:
 movbu (rc_ti),d0                 /* the trace: shutter events, code, group | first, switched | picture mode */
 and 7,d0
 asl2 d0
 mov rc_tr,a0
 add d0,a0
 mov (lg_n),d0
 movbu d0,(a0)
 movbu (cm_code),d0
 movbu d0,(1,a0)
 movbu (cm_grp),d0
 movbu (cm_first),d1
 cmp 0,d1
 bne 98f
 or 0x80,d0
98:
 movbu d0,(2,a0)
 mov (cm_sw),d0
 mov (cm_sw0),d1
 sub d1,d0
 movbu (cm_pmw),d1
 or d1,d0
 movbu d0,(3,a0)
 movbu (rc_ti),d0
 inc d0
 movbu d0,(rc_ti)
 ret [d2,d3,a2,a3],24

/* cm_src (k6): `call cm_src,[d2,d3,a2],16`, d0 = a group -> a3 = its kept 4 looks (0: none), d1 = its choice. */
cm_src:
 movbu (cm_ram + CM_FL),d1
 mov 0,a3
 cmp 5,d0
 bne 1f
 btst 0x80,d1
 beq 9f
 mov cm_ram + CM_P,a3
 movbu (cm_ram + CM_PM),d1
 ret [d2,d3,a2],16
1:
 cmp 5,d0
 bcc 9f
 mov 1,d2
 asl d0,d2
 and d2,d1
 beq 9f
 mov d0,d2
 asl2 d0
 mov cm_ram + CM_S,a3
 add d0,a3
 mov cm_ram + CM_SPM,a0
 movbu (d2,a0),d1
 ret [d2,d3,a2],16
9:
 clr d1
 ret [d2,d3,a2],16

/* cm_hold (k6): `call cm_hold,[d2,d3,a2,a3],20`, d0 = a group -> d0 = 1 when it keeps its changes: P / A / S / M /
 * B always, a custom mode when its Save Settings is Hold (settings 1880..1884 for C1..C5: 0 Reset, 1 Hold; om-emu). */
cm_hold:
 cmp 5,d0
 beq 1f
 bcc 8f
 add 1880,d0
 call sget,[],4
 cmp 1,d0
 beq 1f
8:
 clr d0
 ret [d2,d3,a2,a3],20
1:
 mov 1,d0
 ret [d2,d3,a2,a3],20

/* cm_save (k6): `call cm_save,[d2,d3,a2,a3],20`, d0 = a group, a2 = P: its kept looks <- P+LIDX, its choice <- cm_gpm,
 * its flag set -> d0 = 1 when anything changed. */
cm_save:
 clr d3
 cmp 5,d0
 bne 1f
 mov cm_ram + CM_P,a3
 mov cm_ram + CM_PM,a1
 mov 0x80,d2
 bra 2f
1:
 mov d0,d2
 asl2 d0
 mov cm_ram + CM_S,a3
 add d0,a3
 mov cm_ram + CM_SPM,a1
 add d2,a1
 mov 1,d0
 asl d2,d0
 mov d0,d2
2:
 movbu (cm_ram + CM_FL),d0
 mov d0,d1
 or d2,d1
 cmp d0,d1
 beq 3f
 movbu d1,(cm_ram + CM_FL)
 mov 1,d3
3:
 movbu (cm_gpm),d0
 movbu (a1),d1
 cmp d0,d1
 beq 4f
 movbu d0,(a1)
 mov 1,d3
4:
 clr d2
5:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 movbu (d2,a3),d1
 cmp d0,d1
 beq 6f
 movbu d0,(d2,a3)
 mov 1,d3
6:
 inc d2
 cmp 4,d2
 bcs 5b
 mov d3,d0
 ret [d2,d3,a2,a3],20

/* cm_load (k6, k3..k5's switch): `call cm_load,[d2,d3,a2,a3],24`, a2 = P, a3 = 4 looks, d1 = their choice: each
 * COLOR whose look differs switches with fl_sw's no-capture flag; then the choice's picture mode through the manager
 * when it differs or a film switched (the camera redraws), then the Creative Dial position's memory (dm_rec). cm_gpm =
 * the choice after. Local (4) the choice. */
cm_load:
 mov d1,(4,sp)
 clr d2
7:
 movbu (d2,a3),d3
 extb d3
 cmp 0,d3
 blt 8f
 cmp 5,d3
 bgt 8f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp d3,d0
 beq 8f
 movbu d3,(LIDX,a0)               /* what the wheel and readout show */
 movbu (ss_tm),d0                 /* p1: a trusted set: the camera already holds its values; only our slot */
 cmp 0,d0
 beq 81f
 call ss_lib,[d2,d3,a2,a3],20
 bra 82f
81:
 mov (TORG,a2),a0
 add TWO,a0
 mov 1,d0
 movbu d0,(TW_LEN + 1,a0)         /* fl_sw: no capture (the camera's settings now are the new mode's) */
 clr d0
 mov (rc_in),a0
 mov 0,a1
 call fl_sw,[d2,d3,a2,a3],40
82:
 mov 1,d0
 movbu d0,(DIRTY,a2)              /* the selection saved at the next half-press */
 mov (cm_sw),d0
 inc d0
 mov d0,(cm_sw)
8:
 inc d2
 cmp 4,d2
 bcs 7b
 mov (4,sp),d1
 cmp 0,d1
 bne 91f
 call cm_val,[d2,d3,a2,a3],20     /* no choice kept: the one now */
 movbu d0,(cm_gpm)
 ret [d2,d3,a2,a3],24
91:
 movbu d1,(cm_gpm)
 mov d1,d0                        /* -> COLOR k's own picture mode */
 cmp FV0,d0
 blt 93f
 add -FV0,d0
 clr d2
94:
 cmp 5,d0
 bcs 95f
 add -5,d0
 inc d2
 bra 94b
95:
 mov fl_cvt,a0
 add d2,a0
 movbu (a0),d0
93:
 mov d0,d3
 mov 111,d0
 call sget,[],4
 cmp d3,d0
 bne 96f
 mov (cm_sw),d0
 mov (cm_sw0),d1
 cmp d1,d0
 beq 97f
96:
 mov 901,d0
 mov d3,d1
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (cm_pms),d0
 inc d0
 mov d0,(cm_pms)
 mov 0x80,d0
 movbu d0,(cm_pmw)
97:
 call dm_know,[d2],8              /* the Creative Dial position if the dial code doesn't know it yet (k5) */
 mov (4,sp),d1
 mov (rc_in),a0
 mov 0,a1
 call dm_rec,[d2,d3,a2,a3],36
 ret [d2,d3,a2,a3],24

/* dm_know: `call dm_know,[d2],8`: dm_pos <- the Creative Dial's position from its family (897) when it is not known
 * yet. Reads only. Uses d0, d1, a0. */
dm_know:
 movbu (dm_pos),d0
 cmp 4,d0
 bcs 9f
 mov 897,d0
 call sget,[],4
 mov dm_fam,a0
 clr d1
1:
 mov (a0),d2
 cmp d2,d0
 beq 2f
 inc4 a0
 inc d1
 cmp 4,d1
 bcs 1b
 bra 9f
2:
 movbu d1,(dm_pos)
9:
 ret [d2],8

/* cm_val: `call cm_val,[d2,d3,a2,a3],20`, a2 = P -> d0 = the choice now (FV0 + j for a film on the picture mode's
 * COLOR k, else COLOR k's picture mode; 0 when the picture mode is not COLOR 1..4). */
cm_val:
 mov 111,d0
 call sget,[],4
 mov d0,d3
 call fl_k,[],0
 cmp 0,d0
 blt 8f
 mov d0,d2
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d1
 extb d1
 cmp 1,d1
 blt 7f
 cmp 5,d1
 bgt 7f
 mov d2,d0
 asl2 d0
 add d2,d0
 add d1,d0
 add FV0 - 1,d0
 ret [d2,d3,a2,a3],20
7:
 mov d3,d0
 ret [d2,d3,a2,a3],20
8:
 clr d0
 ret [d2,d3,a2,a3],20

cm_ld:                            /* `call cm_ld,[d2,d3,a2,a3],20`: the record into cm_ram, once per power-on */
 movbu (cm_ok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(cm_ok)
 mov CM_C,a3
 mov (a3),d0
 cmp CM_MAGIC,d0
 bne 8f
 movhu (4,a3),d0
 cmp CM_VER,d0
 bne 8f
 movhu (6,a3),d0
 cmp CM_LEN,d0
 bne 8f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov CM_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 8f
 mov cm_ram,a0
 mov a3,a1
 mov CM_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(cm_v0)
 bra 9f
8:
 mov cm_ram,a0
 mov CM_LEN,d1
 call ub_zero,[],0
 mov 0xff,d0
 movbu d0,(cm_ram + CM_LAST)
9:
 ret [d2,d3,a2,a3],20

cm_wr:                            /* `call cm_wr,[d2,d3,a2,a3],20`: cm_ram -> M (both aliases), as ub_put writes */
 mov CM_MAGIC,d0
 mov d0,(cm_ram)
 mov CM_VER,d0
 movhu d0,(cm_ram + 4)
 mov CM_LEN,d0
 movhu d0,(cm_ram + 6)
 mov -1,d0
 mov cm_ram + 12,a0
 mov CM_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(cm_ram + 8)
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 8f                           /* the camera is saving M: again at the next GUI event */
 mov CM_C,a0
 mov cm_ram,a1
 mov CM_LEN,d1
 call ub_cpy,[],0
 mov CM_U,a0
 mov cm_ram,a1
 mov CM_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(UB_DIRTY)              /* M changed: the camera saves it at the next return to shooting or power-off */
 clr d0
 movbu d0,(cm_pend)
 mov (cm_nw),d0
 inc d0
 mov d0,(cm_nw)
 mov d3,d0
 call UNLOCK,[d2],8
 bra 9f
8:
 mov 1,d0
 movbu d0,(cm_pend)
 mov d3,d0
 call UNLOCK,[d2],8
9:
 ret [d2,d3,a2,a3],20


 .balign 4
cm_na:
 .long 0
cm_sw:
 .long 0
cm_nw:
 .long 0
cm_ram:
 .space CM_LEN
cm_ok:
 .byte 0
cm_v0:
 .byte 0
cm_init:
 .byte 0
cm_pend:
 .byte 0
cm_code:
 .byte 0
cm_pm:
 .byte 0
cm_gpm:
 .byte 0
cm_grp:
 .byte 0
rc_busy:
 .byte 0
rc_ti:
 .byte 0
 .balign 4
cm_sw0:
 .long 0
rc_tr:                            /* k4: the last 8 cm_go runs {shutter events & 255, code, group | 0x80 first look,
                                   * films switched | 0x80 picture mode written} */
 .space 32
 .balign 4
cm_pms:
 .long 0

cm_hp:                            /* k4..k6: `call cm_hp,[d2,d3,a2,a3],24` from lg_pr (every shutter event with the
                                   * films in, HLS_EVENT task): the group now keeps its films and choice when it keeps its
                                   * changes (P / A / S / M / B; a custom mode set to Hold, k6), so they are right when
                                   * the camera next leaves it, also over a power-off. Not before the first look, not
                                   * while rc_go runs, only when the last look was this group. */
 movbu (cm_init),d0
 cmp 0,d0
 beq 9f
 call cm_gnow,[],0
 mov d0,d2
 movbu (cm_ram + CM_LAST),d1
 cmp d2,d1
 bne 9f
 PVAL 9f                          /* (d2 kept) */
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 9f
 mov d2,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 clr d0                           /* rc_go's busy flag: not while it runs */
 call LOCK,[d2],8
 mov d0,d3
 movbu (rc_busy),d0
 cmp 0,d0
 beq 2f
 mov d3,d0
 call UNLOCK,[d2],8
 bra 9f
2:
 mov 1,d0
 movbu d0,(rc_busy)
 mov d3,d0
 call UNLOCK,[d2],8
 call cm_val,[d2,d3,a2,a3],20
 movbu d0,(cm_gpm)
 mov d2,d0
 call cm_save,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 7f
 call cm_wr,[d2,d3,a2,a3],20
 mov (cm_nhp),d0
 inc d0
 mov d0,(cm_nhp)
7:
 call ss_hp,[d2,d3,a2,a3],20      /* p1: and its rows (d2 = the set) */
 clr d0
 movbu d0,(rc_busy)
9:
 ret [d2,d3,a2,a3],24

/* cm_rcl (k6): the facade's entry 18 + 2 = 20 (Recall; vtable word 0x60e574c4, stock 0x60b871f3, om-emu: the menu's
 * Recall > Yes calls it with d0 = the custom mode 0..4), entered by `calls`: the camera's own Recall first, then that
 * custom mode's films into the mode now (cm_force, rc_go), and once more at the next GUI event (rc_pend, compare only)
 * in case the camera applies its part later. */
cm_rcl:
 movm [d2,d3,a2,a3],(sp)
 add -16,sp                       /* (0) call slot, (4) d0, (8) the result */
 mov d0,(4,sp)
 call cm_rstock,[],0              /* d0, d1, a0 as entered */
 mov d0,(8,sp)
 mov (4,sp),d0
 cmp 5,d0
 bcc 1f
 call dm_ok,[],0                  /* films loaded? (d1; d0 kept) */
 cmp 0,d1
 beq 1f
 inc d0
 movbu d0,(cm_force)
 call rc_go,[d2,d3,a2,a3],24
 mov 1,d0
 movbu d0,(rc_pend)
1:
 mov (8,sp),d0
 add 16,sp
 movm (sp),[d2,d3,a2,a3]
 rets

 .balign 4
cm_nhp:
 .long 0
cm_first:
 .byte 0
cm_pmw:
 .byte 0
cm_lst:
 .byte 0
cm_force:
 .byte 0

/* cm_gnow (k5): `call cm_gnow,[],0` -> d0 = the group now: C1..C5 0..4, P / A / S / M / B 5. The mode's code (the
 * settings object's byte +24: 1..5 P A S M B, 53..57 C1..C5) when it is one of those; else the mode dial's position
 * (UI_IN's index at 0xa32d9d0c, om-emu E147: 0 S, 1 A, 2 P, 3..7 C5..C1, 8 B, 9 M), since on the camera the code
 * read 0 at the first look after a power-on (k4's CADLOG: "code 0", so P's films went onto a custom mode). Notes the
 * code in cm_code, or 0xc0 | the position when the position decided. Uses d0, d1, a0. */
 .set MC_B, 62                    /* #54: B's code in om-emu. On the camera B's code reads 0 (DS4 CADLOG, dial 8) */
 .set DIAL_B, 8
cm_gnow:
 mov (rc_in),a0
 cmp 0,a0
 beq 2f
 movbu (24,a0),d0
 movbu d0,(cm_code)
 cmp MC_B,d0                      /* #54: B is a mode with no code of 1..5, so it counts as P / A / S / M / B */
 beq 4f
 cmp 0,d0
 bne 5f
 movbu (UI_DIAL),d1
 cmp DIAL_B,d1
 bne 5f
4:
 mov 5,d0
 ret [],0
5:
 cmp 53,d0
 bcs 1f
 cmp 58,d0
 bcc 2f
 add -53,d0
 ret [],0
1:
 cmp 1,d0
 bcs 2f
 cmp 6,d0
 bcc 2f
 mov 5,d0
 ret [],0
2:
 movbu (0xa32d9d0c),d0
 mov d0,d1
 or 0xc0,d1
 movbu d1,(cm_code)
 cmp 3,d0
 bcs 3f
 cmp 8,d0
 bcc 3f
 mov 7,d1
 sub d0,d1
 mov d1,d0
 ret [],0
3:
 mov 5,d0
 ret [],0

/* ---- Per-mode settings, p1 (feature/per-mode-settings, owner 2026-11-14: "Every setting in each custom mode should be
 * independant of the other custom modes and the apsm modes"). The camera already keeps COLOR 1..4's 18 settings per
 * set (P / A / S / M / B one set, C1..C5 one each; om-emu, stock firmware) with its own Save Settings: Reset / Hold.
 * Our rows live in COLOR k's slot (P+32+64k), one copy only. p1 gives each set its own copy of the four slots (and the
 * looks they belong to), swapped in RAM at the dial change, and stops putting the films' shared records over the
 * camera's own values (rc_put) when the camera holds them for the set. Sets: 0..4 C1..C5, 5 P group. A set is
 * "trusted" (the camera's values belong to its films) for P and for a custom mode with films of its own (Assign);
 * a custom mode without (never assigned through us, or after Assign > Reset) is put back as before every time it is
 * entered (after Assign > Reset: the films as built, neutral rows). Video / S&Q (mode code 10): no film work (rc_go).
 * Record 'OM3S' in M's free tail at +0x3D000 (the films block is at +0x3A000, 'OM3C' at +0x3B000, other branches use
 * +0x3C000): +0 magic, +4 u16 1, +6 u16 len, +8 CRC-32 of 12.., +12 sets kept (bit n), +13 sets to build from the films
 * after Assign > Reset (bit n), +14 zero, +16 6 sets x 332 B {+0 looks[4], +4 slots[256], +260 the camera's 18
 * settings x 4 when the set was made (Assign, or its first entry; only for the Reset check below), +332 the set's own
 * film changes (an EDITS image: every film's and COLOR k's own saved changes; owner 2026-11-15: Assign copies every
 * setting, and nothing done in another mode, edits or a film reset, changes a custom mode's copy)}. */
 .set SS_C, 0x6295d700            /* M image 0x62920700 + 0x3D000 */
 .set SS_U, 0xa295d700
 .set SS_MAGIC, 0x53334d4f        /* "OM3S" */
 .set SS_VER, 1
 .set SS_SZ, 332 + TW_LEN         /* + the set's own film changes (an EDITS image, 1648 B) */
 .set SS_LEN, 16 + 6 * SS_SZ      /* 11896: ends at M + 0x3FE78 */

/* rc_rec: `call rc_rec,[d2,d3,a2],20`, a2 = P, d2 = k, d3 = look 1..5 -> a3 = that film's record: its saved changes
 * when valid and made from this build of the film, else the film as built (as built always while rc_ab). rc_put's
 * own choice before p1. Uses d0, d1, a0, a1. Local (4) the saved record. */
rc_rec:
 mov d2,d0                        /* r = 5k + look - 1 */
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 mov d0,d1
 asl 6,d1
 add 32,d1
 mov (LPTR,a2),a3
 add d1,a3                        /* the film as built */
 movbu (rc_ab),d1
 cmp 0,d1
 bne 8f
 mov (TORG,a2),a1
 add TWO,a1
 mov 1,d1
 asl d0,d1
 mov (12,a1),d3
 and d1,d3
 beq 8f                           /* no saved changes: as built */
 mov d0,d1                        /* the saved record: TWO + 16 + 68 r, its check at +64 */
 asl 6,d1
 asl2 d0
 add d0,d1
 add 16,d1
 add d1,a1
 mov a1,(4,sp)
 mov a3,a0                        /* only changes made from this build of the film (fl_sw's test) */
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (4,sp),a1
 mov (64,a1),d1
 cmp d0,d1
 bne 8f
 mov a1,a3
8:
 ret [d2,d3,a2],20

/* ss_slot: `call ss_slot,[d2,d3,a2,a3],20`, a2 = P, d2 = k, a3 = a record (0 = neutral): COLOR k's slot <- the record,
 * as pf_put1 fills it, without the camera's 18 settings (no settings-manager call). */
ss_slot:
 call cv_rec,[d2,d3,a2,a3],20     /* rgb-curves: the record's curves into COLOR k's */
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
 mov pf_bt,a1
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
 cmp pf_bt+42,a1
 bne 8b
 movbu (7,a0),d0
 or 2,d0
 movbu d0,(7,a0)                  /* +31 flags: H/L on */
 ret [d2,d3,a2,a3],20

/* ss_lib: `call ss_lib,[d2,d3,a2,a3],20`, a2 = P, d2 = k, d3 = look 0..5: COLOR k's slot <- that film's record
 * (rc_rec), or neutral for look 0. No settings-manager call. */
ss_lib:
 mov 0,a3
 cmp 0,d3
 beq 1f
 call rc_rec,[d2,d3,a2],20
1:
 call ss_slot,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20

/* ss_ld: `call ss_ld,[d2,d3,a2,a3],20`: the record into ss_ram, once per power-on (none valid: all zero). */
ss_ld:
 movbu (ss_ok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(ss_ok)
 mov SS_C,a3
 mov (a3),d0
 cmp SS_MAGIC,d0
 bne 8f
 movhu (4,a3),d0
 cmp SS_VER,d0
 bne 8f
 movhu (6,a3),d0
 cmp SS_LEN,d0
 bne 8f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov SS_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 8f
 mov ss_ram,a0
 mov a3,a1
 mov SS_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(ss_v0)
 bra 9f
8:
 mov ss_ram,a0
 mov SS_LEN,d1
 call ub_zero,[],0
9:
 ret [d2,d3,a2,a3],20

/* ss_wr: `call ss_wr,[d2,d3,a2,a3],20`: when ss_dirty, ss_ram -> M (both aliases), as cm_wr writes; held back while
 * the camera saves M (cm_pend: gx_map runs rc_go again, which ends with ss_wr). */
ss_wr:
 movbu (ss_dirty),d0
 cmp 0,d0
 beq 9f
 mov SS_MAGIC,d0
 mov d0,(ss_ram)
 mov SS_VER,d0
 movhu d0,(ss_ram + 4)
 mov SS_LEN,d0
 movhu d0,(ss_ram + 6)
 mov -1,d0
 mov ss_ram + 12,a0
 mov SS_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(ss_ram + 8)
 mov (ub_gen),d0                  /* rgb-curves: the curves record (the sets' curves), with the block in M now */
 mov CV_STS,a0
 call cv_hdr,[d2,d3,a2,a3],20
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 8f
 mov SS_C,a0
 mov ss_ram,a1
 mov SS_LEN,d1
 call ub_cpy,[],0
 mov SS_U,a0
 mov ss_ram,a1
 mov SS_LEN,d1
 call ub_cpy,[],0
 mov CV_STS,a1                    /* rgb-curves 2b: only a copy with interrupts off */
 call cv_put,[d2],8
 mov 1,d0
 movbu d0,(UB_DIRTY)              /* M changed: the camera saves it at the next return to shooting or power-off */
 clr d0
 movbu d0,(ss_dirty)
 mov (ss_nw),d0
 inc d0
 mov d0,(ss_nw)
 mov d3,d0
 call UNLOCK,[d2],8
 bra 9f
8:
 mov 1,d0
 movbu d0,(cm_pend)
 mov d3,d0
 call UNLOCK,[d2],8
9:
 ret [d2,d3,a2,a3],20

/* ss_photo: `call ss_photo,[],0` -> d0 1 when the mode now is a photo mode: the mode's code 1..5 / 53..57, or, while
 * the code is still 0 after a power-on, the photo / movie / S&Q switch (UI_IN index 0xa32d9d0d, beside the mode
 * dial's 0xa32d9d0c: 2 photo, 1 movie, 0 S&Q; om-emu). Video / S&Q read 10. Notes ss_ph. Uses d0, d1, a0. */
ss_photo:
 mov (rc_in),a0
 cmp 0,a0
 beq 8f
 movbu (24,a0),d0
 movbu d0,(ss_ph)
 cmp 0,d0
 beq 3f
 cmp 6,d0
 bcs 1f
 cmp MC_B,d0                      /* #54: B */
 beq 1f
 cmp 53,d0
 bcs 8f
 cmp 58,d0
 bcc 8f
1:
 mov 1,d0
 ret [],0
3:
 movbu (UI_PSW),d0
 mov d0,d1
 or 0xc0,d1
 movbu d1,(ss_ph)
 cmp 2,d0
 beq 1b
8:
 clr d0
 ret [],0

/* ss_trust: `call ss_trust,[],0`, d0 = a set -> d0 1 when the camera's values belong to its films: P group, or a
 * custom mode with films of its own (OM3C flag). Uses d0, d1. */
ss_trust:
 cmp 5,d0
 beq 1f
 bcc 8f
 mov 1,d1
 asl d0,d1
 movbu (cm_ram + CM_FL),d0
 and d1,d0
 beq 8f
1:
 mov 1,d0
 ret [],0
8:
 clr d0
 ret [],0

/* ss_base: `call ss_base,[],0`, d0 = a set -> a0 = its 332 bytes in ss_ram. Uses d0, d1, a0 (and MDR). */
ss_base:
 mov SS_SZ,d1
 mul d1,d0
 mov ss_ram + 16,a0
 add d0,a0
 ret [],0

/* ss_cc: `call ss_cc,[d2],8`: d1 bytes from a1 to a0, ss_chg = 1 when any differed. Uses d0, d1, a0, a1. */
ss_cc:
1:
 movbu (a1),d0
 movbu (a0),d2
 cmp d0,d2
 beq 2f
 movbu d0,(a0)
 mov 1,d2
 movbu d2,(ss_chg)
2:
 inc a0
 inc a1
 add -1,d1
 bne 1b
 ret [d2],8

/* ss_id: `call ss_id,[],0`, d2 = k, d3 = i 0..17 -> d0 = COLOR k's camera setting i (pf_ids). Uses d0, d1, a0. */
ss_id:
 mov pf_ids,a0
 mov d3,d0
 asl2 d0
 add d0,a0
 movbu (2,a0),d1
 mul d2,d1
 movhu (a0),d0
 add d1,d0
 ret [],0

/* ss_put: `call ss_put,[d2,d3,a2,a3],32`, a2 = P, d0 = a set, d1 = 1: also note the camera's 18 settings x 4 now.
 * The set <- P+LIDX and the four slots; kept bit set; ss_dirty when anything changed. Locals (4) set, (8) flag,
 * (12) its base. */
ss_put:
 mov d0,(4,sp)
 mov d1,(8,sp)
 call ss_ld,[d2,d3,a2,a3],20
 clr d0
 movbu d0,(ss_chg)
 mov (4,sp),d0
 call ss_base,[],0
 mov a0,(12,sp)
 mov a2,a1
 add LIDX,a1
 mov 4,d1
 call ss_cc,[d2],8
 mov (12,sp),a0
 add 4,a0
 mov a2,a1
 add 32,a1
 mov 256,d1
 call ss_cc,[d2],8
 mov (TORG,a2),a1                 /* the film changes in use (live EDITS image) */
 cmp 0,a1
 beq 4f
 add TWO,a1
 mov (12,sp),a0
 add 332,a0
 mov TW_LEN,d1
 call ss_cc,[d2],8
4:
 mov (4,sp),d0                    /* rgb-curves: the set's curves */
 call cv_sput,[d2,d3,a2,a3],20
 mov (8,sp),d0
 cmp 0,d0
 beq 5f
 clr d2
1:
 clr d3
2:
 call ss_id,[],0
 call sget,[],4                   /* d0 = the camera's value now (keeps d2, d3, a2, a3) */
 and 255,d0
 mov (12,sp),a0
 add 260,a0
 mov d2,d1
 asl 4,d1
 add d1,a0
 add d2,a0
 add d2,a0                        /* + 18 k */
 add d3,a0
 movbu (a0),d1
 cmp d0,d1
 beq 3f
 movbu d0,(a0)
 mov 1,d0
 movbu d0,(ss_chg)
3:
 inc d3
 cmp 18,d3
 bcs 2b
 inc d2
 cmp 4,d2
 bcs 1b
5:
 mov (4,sp),d0
 mov 1,d1
 asl d0,d1
 movbu (ss_ram + 12),d0
 mov d0,d2
 or d1,d0
 cmp d0,d2
 beq 6f
 movbu d0,(ss_ram + 12)
 mov 1,d0
 movbu d0,(ss_chg)
6:
 movbu (ss_chg),d0
 cmp 0,d0
 beq 7f
 movbu d0,(ss_dirty)
 mov (ss_np),d0
 inc d0
 mov d0,(ss_np)
7:
 ret [d2,d3,a2,a3],32

/* ss_get: `call ss_get,[d2,d3,a2,a3],24`, a2 = P, d0 = a set -> d1 1 when it is kept (else d0 = d1 = 0); then each
 * COLOR k whose look now (P+LIDX) is the set's gets the set's slot; d0 = those COLORs (bit k). Locals (4) set,
 * (8) its base. */
ss_get:
 mov d0,(4,sp)
 call ss_ld,[d2,d3,a2,a3],20
 mov (4,sp),d0
 mov 1,d1
 asl d0,d1
 movbu (ss_ram + 12),d0
 and d1,d0
 bne 1f
 clr d0
 clr d1
 ret [d2,d3,a2,a3],24
1:
 mov (4,sp),d0
 call ss_base,[],0
 mov a0,(8,sp)
 clr d2
 clr d3
2:
 mov (8,sp),a0
 movbu (d2,a0),d0
 mov a2,a1
 add d2,a1
 movbu (LIDX,a1),d1
 cmp d0,d1
 bne 3f
 mov d2,d0
 asl 6,d0
 mov (8,sp),a1
 add 4,a1
 add d0,a1
 mov a2,a0
 add 32,a0
 add d0,a0
 mov 64,d1
 call ub_cpy,[],0
 mov (4,sp),d0                    /* rgb-curves: and its curves */
 call cv_sget,[d2,d3,a2,a3],20
 mov 1,d0
 asl d2,d0
 or d0,d3
 mov (ss_ng),d0
 inc d0
 mov d0,(ss_ng)
3:
 inc d2
 cmp 4,d2
 bcs 2b
 mov d3,d0
 mov 1,d1
 ret [d2,d3,a2,a3],24

/* ss_chk: `call ss_chk,[d2,d3,a2,a3],36`, d0 = a custom mode on Reset, d1 = its COLORs put back: each of their 18
 * camera settings now against the values noted when the set was made; a difference counts in ss_nm, the last in
 * ss_ml (set << 24 | k << 16 | id). Diagnostic only (CADLOG). Locals (4) set, (8) COLORs, (12) base, (16) id. */
ss_chk:
 mov d0,(4,sp)
 mov d1,(8,sp)
 call ss_base,[],0
 mov a0,(12,sp)
 clr d2
1:
 mov (8,sp),d0
 mov 1,d1
 asl d2,d1
 and d1,d0
 beq 5f
 clr d3
2:
 call ss_id,[],0
 mov d0,(16,sp)
 call sget,[],4
 and 255,d0
 mov (12,sp),a0
 add 260,a0
 mov d2,d1
 asl 4,d1
 add d1,a0
 add d2,a0
 add d2,a0
 add d3,a0
 movbu (a0),d1
 cmp d0,d1
 beq 3f
 mov (ss_nm),d0
 inc d0
 mov d0,(ss_nm)
 mov (4,sp),d0
 asl 8,d0
 or d2,d0
 asl 16,d0
 mov (16,sp),d1
 or d1,d0
 mov d0,(ss_ml)
3:
 inc d3
 cmp 18,d3
 bcs 2b
5:
 inc d2
 cmp 4,d2
 bcs 1b
 ret [d2,d3,a2,a3],36

/* ss_pre: `call ss_pre,[d2,d3,a2,a3],24` from rc_go before cm_go, a2 = P: photo or not, Recall or not; the set the
 * slots belong to (ss_cur) is kept when leaving it, if the camera's values belong to it and it holds its changes
 * (P group always, a custom mode on Hold); ss_tm = the set entered is trusted (cm_load then switches films without the
 * camera's 18 settings). Photo only (rc_go). */
ss_pre:
 clr d0
 movbu d0,(ss_tm)
 movbu d0,(rc_ab)
 mov 0x0f,d0
 movbu d0,(ss_mask)
 mov 0xff,d0
 movbu d0,(ss_fn)
 call cm_ld,[d2,d3,a2,a3],20
 call ss_ld,[d2,d3,a2,a3],20
 movbu (cm_force),d1
 cmp 0,d1
 beq 2f
 add -1,d1                        /* a Recall of C(d1 + 1): its film changes now, as before, then its rows */
 movbu d1,(ss_fn)
 mov d1,d0
 call ss_ed,[d2,d3,a2,a3],20
 bra 9f
2:
 call cm_gnow,[],0
 mov d0,d2
 movbu (ss_cur),d3
 cmp 6,d3
 bcc 5f
 cmp d2,d3
 beq 5f
 mov d3,d0
 call ss_trust,[],0
 cmp 0,d0
 beq 5f
 mov d3,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 5f
 mov d3,d0                        /* leaving a set that holds: its slots and looks now (our slots are not swapped by */
 clr d1                           /* the camera, and cm_go has not switched the films yet) */
 call ss_put,[d2,d3,a2,a3],32
5:
 mov d2,d0
 call ss_trust,[],0
 movbu d0,(ss_tm)
 cmp 0,d0
 beq 9f
 cmp d2,d3
 beq 9f
 mov d2,d0                        /* entering another trusted set: its own film changes before cm_go switches films */
 call ss_ed,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],24

/* ss_post: `call ss_post,[d2,d3,a2,a3],24` from rc_go after cm_go, a2 = P: ss_mask = the COLORs rc_put still puts
 * back (0x0f = all, as before p1). Photo, a set change: trusted -> the set's slots where its looks are the films now
 * (first time for the set: the set made from what is shown now), nothing put back; a custom mode on Reset is checked
 * against its noted camera values (CADLOG). Untrusted custom mode: as before; after Assign > Reset its films as built
 * and neutral rows (rc_ab). The same set again (P <-> A, a GUI retry): nothing. Recall: as before, then the custom
 * mode's slots, kept when the mode now holds. Photo only (rc_go). */
ss_post:
 movbu (ss_fn),d0
 cmp 0xff,d0
 beq 3f
 call ss_get,[d2,d3,a2,a3],24
 movbu (cm_grp),d0
 mov d0,d2
 movbu d0,(ss_cur)
 call ss_trust,[],0
 cmp 0,d0
 beq 9f
 mov d2,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 mov d2,d0
 clr d1
 call ss_put,[d2,d3,a2,a3],32
 bra 9f
3:
 movbu (cm_grp),d0
 mov d0,d2
 movbu (ss_cur),d1
 cmp d1,d0
 bne 4f
 clr d0
 movbu d0,(ss_mask)
 bra 9f
4:
 movbu d2,(ss_cur)
 movbu (ss_tm),d0
 cmp 0,d0
 beq 6f
 clr d0
 movbu d0,(ss_mask)
 mov (ss_ntr),d0
 inc d0
 mov d0,(ss_ntr)
 mov d2,d0
 call ss_get,[d2,d3,a2,a3],24
 cmp 0,d1
 bne 5f
 mov d2,d0                        /* the set's first time: made from what it shows now */
 mov 1,d1
 call ss_put,[d2,d3,a2,a3],32
 mov (ss_nl),d0
 inc d0
 mov d0,(ss_nl)
 bra 9f
5:
 mov d0,d3
 cmp 5,d2
 bcc 9f
 mov d2,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 9f
 mov d2,d0
 mov d3,d1
 call ss_chk,[d2,d3,a2,a3],36
 bra 9f
6:
 movbu (ss_ram + 13),d0
 mov 1,d1
 asl d2,d1
 and d1,d0
 beq 9f
 mov 1,d0
 movbu d0,(rc_ab)
 mov (ss_nab),d0
 inc d0
 mov d0,(ss_nab)
 mov (TORG,a2),a0                 /* the films as built: no saved changes in use while in it */
 cmp 0,a0
 beq 70f
 add TWO,a0
 clr d0
 mov d0,(12,a0)
 mov 1,d0
 movbu d0,(TW_LEN,a0)
 movbu d0,(DIRTY,a2)
70:
 clr d2
7:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 71f
 cmp 5,d3
 ble 72f
71:
 clr d3
72:
 call ss_lib,[d2,d3,a2,a3],20
 inc d2
 cmp 4,d2
 bcs 7b
9:
 ret [d2,d3,a2,a3],24

/* ss_hp: `call ss_hp,[d2,d3,a2,a3],20` from cm_hp (a set that holds, its films just kept), d2 = the set, a2 = P:
 * photo, the slots belong to it and it is trusted -> its slots and looks kept (written when changed). */
ss_hp:
 call ss_photo,[],0
 cmp 0,d0
 beq 9f
 movbu (ss_cur),d0
 cmp d2,d0
 bne 9f
 mov d2,d0
 call ss_trust,[],0
 cmp 0,d0
 beq 9f
 mov d2,d0
 clr d1
 call ss_put,[d2,d3,a2,a3],32
 call ss_wr,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* ss_ed: `call ss_ed,[d2,d3,a2,a3],20`, a2 = P, d0 = a set: when it is kept, its film changes become the ones in use
 * (live EDITS image <- the set's; to be saved with the films block). */
ss_ed:
 mov d0,d2
 call ss_ld,[d2,d3,a2,a3],20
 mov 1,d1
 asl d2,d1
 movbu (ss_ram + 12),d0
 and d1,d0
 beq 9f
 mov (TORG,a2),a3
 cmp 0,a3
 beq 9f
 mov d2,d0
 call ss_base,[],0
 mov a0,a1
 add 332,a1
 mov a3,a0
 add TWO,a0
 mov TW_LEN,d1
 call ub_cpy,[],0
 mov d2,d0                        /* rgb-curves: and their curves */
 call cv_sed,[d2,d3,a2,a3],20
 mov a3,a0
 add TWO,a0
 mov 1,d0
 movbu d0,(TW_LEN,a0)             /* EDITS image to save */
 movbu d0,(DIRTY,a2)
 mov (ss_ne),d0
 inc d0
 mov d0,(ss_ne)
9:
 ret [d2,d3,a2,a3],20

/* ss_pm: `call ss_pm,[d2,d3,a2,a3],20` from pm_save after the films block was written (leaving Picture Mode, GUI
 * task), a2 = P: the set now keeps its slots and film changes when it holds (as at a half-press), so a power-off
 * without a half-press finds them at the next start. Not before the first look, not while rc_go runs. */
ss_pm:
 movbu (cm_init),d0
 cmp 0,d0
 beq 9f
 call cm_gnow,[],0
 mov d0,d2
 movbu (ss_cur),d1
 cmp d2,d1
 bne 9f
 mov d2,d0
 call cm_hold,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (rc_busy),d0
 cmp 0,d0
 beq 2f
 mov d3,d0
 call UNLOCK,[d2],8
 bra 9f
2:
 mov 1,d0
 movbu d0,(rc_busy)
 mov d3,d0
 call UNLOCK,[d2],8
 call ss_hp,[d2,d3,a2,a3],20
 clr d0
 movbu d0,(rc_busy)
9:
 ret [d2,d3,a2,a3],20

/* ss_asg / ss_rst: `call ss_asg,[d2,d3,a2,a3],20` (Assign > Set of C(d0 + 1), a2 = P): the set <- the mode now, its
 * camera values noted, built-from-films bit cleared. `call ss_rst,[d2,d3,a2,a3],20` (Assign > Reset): not kept, built
 * from the films at its next entry. */
ss_asg:
 mov d0,d2
 mov 1,d1
 call ss_put,[d2,d3,a2,a3],32
 mov 1,d1
 asl d2,d1
 not d1
 movbu (ss_ram + 13),d0
 and d1,d0
 movbu d0,(ss_ram + 13)
 mov 1,d0
 movbu d0,(ss_dirty)
 ret [d2,d3,a2,a3],20

ss_rst:
 mov d0,d2
 call ss_ld,[d2,d3,a2,a3],20
 mov 1,d1
 asl d2,d1
 mov d1,d3
 not d3
 movbu (ss_ram + 12),d0
 and d3,d0
 movbu d0,(ss_ram + 12)
 movbu (ss_ram + 13),d0
 or d1,d0
 movbu d0,(ss_ram + 13)
 mov 1,d0
 movbu d0,(ss_dirty)
 ret [d2,d3,a2,a3],20


 .balign 4
ss_ram:
 .space SS_LEN
ss_ntr:
 .long 0
ss_nl:
 .long 0
ss_ng:
 .long 0
ss_np:
 .long 0
ss_nw:
 .long 0
ss_nab:
 .long 0
ss_nm:
 .long 0
ss_ne:
 .long 0
ss_ml:
 .long 0
ss_ok:
 .byte 0
ss_v0:
 .byte 0
ss_cur:
 .byte 0xff
ss_dirty:
 .byte 0
ss_chg:
 .byte 0
ss_tm:
 .byte 0
ss_mask:
 .byte 0x0f
ss_ph:
 .byte 0
ss_fn:
 .byte 0xff
rc_ab:
 .byte 0
 .balign 2

/* gd_s11 (moved here from ext10 for room): the Saturation / WB / Glow guide pictures, as before */
.section .ext11,"ax"
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

/* vf_def: ed_default's miss (CALLS, d0 id, a1 out): Vignette Correction's rows (VFB + k) default to 1 On, the
 * camera's own correction, so On shows no '*'. Noise Filter's rows (NRB + k) default to the camera's own Noise
 * Filter (v0.30 test 13, owner 2026-11-16): the setter stores 0 (Camera) when the choice equals it, and the profile's
 * '*' counts that byte, so the row now agrees (the row's '*' compared with Std, 0, from stock_default: with the
 * camera's own Noise Filter on Off, Off starred the row and Std the profile). Anything else: stock_default, registers
 * as at entry. */
vf_def:
 cmp 0,a1
 beq 2f
 movm [d2],(sp)
 mov d0,d2
 exthu d2
 add -VFB,d2
 cmp 4,d2
 bcs 1f
 add VFB - NRB,d2
 cmp 4,d2
 bcs 3f
 movm (sp),[d2]
2:
 jmp stock_default
1:
 movm (sp),[d2]
 mov 1,d0
 mov d0,(a1)
 clr d0
 rets
3:                                /* Noise Filter: the camera's own, as the row shows for slot +51 = 0 */
 movm (sp),[d2]
 movm [d2,d3,a2,a3],(sp)
 add -4,sp                        /* (0,sp): our call's return address slot */
 mov a1,a2
 mov mdr,d0
 mov d0,a3                        /* MDR back after the getter, as sl_gb keeps it */
 mov 38681,d0                     /* key 0x9719, the stills Noise Filter (-2..+1) */
 clr d1
 mov 0,a0
 call nf_get,[d2,d3],12           /* the stock getter 0x60063380, as the row's own read (sl_get, label 94) */
 extb d0
 mov d0,(a2)
 mov a3,d0
 mov d0,mdr
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 clr d0
 rets

/* vf_get: sl_gb's miss before the table loads (CALLS, d0 id, a1 out): VFB + k read 1 On, as vf_def, so the row
 * shows no '*' then, and the left column's VF_IT reads On too. Anything else: tn_get, registers as at entry. */
vf_get:
 cmp 0,a1
 beq 3f
 cmp VF_IT,d0
 bne 4f
 mov 1,d0
 mov d0,(a1)
 clr d0
 rets
4:
 movm [d2],(sp)
 mov d0,d2
 exthu d2
 add -VFB,d2
 cmp 4,d2
 bcs 5f
 movm (sp),[d2]
3:
 jmp tn_get
5:
 movm (sp),[d2]
 mov 1,d0
 mov d0,(a1)
 clr d0
 rets

/* ---- Early load: the films from the camera's memory at the GUI's first state change, which comes
 * after the camera's start-up writes and before the shooting screen asks for its label. The card is
 * not read (el_nc). Hooks that react to the camera's own writes wait for the first shutter event (el_hold): dm_ok
 * and gx_map's first look. No valid block in memory: the first half-press loads as before. */
.section .ext12,"ax"
el_go:                            /* `call el_go,[d2,d3,a2,a3],36` from gx_map (GUI task), STATE 0 */
 mov (SECBITS),d0
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne 9f                           /* not all 10 sections copied: the next state change tries again */
 call ub_chk,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 call el_ok,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 9f
 movbu d0,(el_pm)
 mov 1,d0
 movbu d0,(el_hold)
 call st_claim,[d2,d3],12
 cmp 0,d0
 bne 1f
 movbu d0,(el_hold)               /* the half-press load (HLS task) has it */
 bra 9f
1:
 movbu d0,(el_nc)
 call sd_load,[d2,d3,a2,a3],36
 clr d0
 movbu d0,(el_nc)
 mov 1,d0
 movbu d0,(el_cd)
 mov el_tid,a0                    /* the GUI task: dm_rec's only writer until the first shutter event */
 call get_tid,[a2],4
 call dm_know,[d2],8              /* dm_rec keeps a film picked before the first half-press, which dm_turn
                                     would otherwise replace with the dial's old choice */
 movbu (el_pm),d0
 cmp 2,d0
 bne 9f
 PVAL 9f
 call el_pre,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],36

/* el_ok: `call el_ok,[d2,d3,a2,a3],20` from el_go -> d0 = 0 no early load, 1 the films block as it is, 2 then el_pre.
 * The first look (rc_go) may change only what el_pre can do first in RAM: photo in a trusted set. Elsewhere the block
 * must already show what the first look keeps: the same group, or a group with no films of its own. Reads only. */
el_ok:
 call cm_ld,[d2,d3,a2,a3],20
 call ss_ld,[d2,d3,a2,a3],20
 call cm_gnow,[],0
 mov d0,d2
 movbu d0,(el_g)
 mov (rc_in),a0                   /* ss_photo reads "not photo" until the manager handle is seen */
 cmp 0,a0
 beq 1f
 call ss_photo,[],0
 bra 2f
1:
 movbu (UI_PSW),d1
 clr d0
 cmp 2,d1
 bne 2f
 mov 1,d0
2:
 cmp 0,d0
 beq 3f
 mov d2,d0
 call ss_trust,[],0
 cmp 0,d0
 beq 3f
 mov 2,d0
 ret [d2,d3,a2,a3],20
3:
 movbu (cm_ram + CM_LAST),d1
 cmp d2,d1
 beq 4f
 mov d2,d0
 call cm_src,[d2,d3,a2],16
 cmp 0,a3
 beq 4f
 clr d0
 ret [d2,d3,a2,a3],20
4:
 mov 1,d0
 ret [d2,d3,a2,a3],20

/* el_pre: `call el_pre,[d2,d3,a2,a3],24` from el_go after sd_load, a2 = P: the RAM half of the first look's entry
 * into the trusted set el_g (ss_pre's ss_ed, cm_load's ss_lib, ss_post's ss_get), with no settings-manager call and no
 * block write. The camera already recalled the set's own 18 values. ss_cur = el_g when the set is kept, so the first
 * look finds the films and rows in place and keeps an edit made before it. Local (4) the set. */
el_pre:
 movbu (el_g),d0
 mov d0,(4,sp)
 clr d0                           /* rc_go's lock and busy flag */
 call LOCK,[d2],8
 mov d0,d3
 movbu (rc_busy),d0
 cmp 0,d0
 beq 1f
 mov d3,d0
 call UNLOCK,[d2],8
 ret [d2,d3,a2,a3],24
1:
 mov 1,d0
 movbu d0,(rc_busy)
 mov d3,d0
 call UNLOCK,[d2],8
 mov (LPTR,a2),d0
 cmp 0,d0
 beq 8f
 mov (TORG,a2),d0
 cmp 0,d0
 beq 8f
 mov (4,sp),d0
 call ss_ed,[d2,d3,a2,a3],20
 mov (4,sp),d0
 call cm_src,[d2,d3,a2],16
 cmp 0,a3
 beq 5f
 clr d2
2:
 movbu (d2,a3),d3
 extb d3
 cmp 0,d3
 blt 4f
 cmp 5,d3
 bgt 4f
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 extb d0
 cmp d3,d0
 beq 4f
 movbu d3,(LIDX,a0)
 call ss_lib,[d2,d3,a2,a3],20
 mov 1,d0
 movbu d0,(DIRTY,a2)              /* the selection saved at the next half-press, as cm_load does */
4:
 inc d2
 cmp 4,d2
 bcs 2b
5:
 mov (4,sp),d0
 call ss_get,[d2,d3,a2,a3],24
 cmp 0,d1
 beq 8f
 mov (4,sp),d0
 movbu d0,(ss_cur)
8:
 clr d0
 movbu d0,(rc_busy)
 ret [d2,d3,a2,a3],24
/* el_card: `call el_card,[d2,d3,a2,a3],36` from lg_pr: after the early load, the card at the first half-press with a
 * card: NAMES.BIN, and LOOKS.BIN when its films are new to the camera. Each is built aside and then published, so no
 * reader sees half of it. The old films buffer is never freed: a heap record of the camera's points at it. Locals (4)
 * buffer, (8) P. */
el_card:
 movbu (el_cd),d0
 cmp 0,d0
 beq 9f
 PVAL 9f
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f                           /* no card yet: the next half-press tries again */
 clr d0
 movbu d0,(el_cd)
 mov a2,(8,sp)
 mov 1024,d0                      /* NAMES.BIN into a scratch P: nm_load also uses P+TBUF, the titles by now */
 call malloc,[],4
 cmp 0,a0
 beq 20f
 mov a0,(4,sp)
 mov a0,a2
 add NENT,a0                      /* no NAMES.BIN: P+NENT reads 0, as after sd_load */
 mov 80,d1
 call ub_zero,[],0
 call nm_load,[d2,d3,a2,a3],36
 mov (8,sp),a2
 mov (4,sp),a3
 mov a2,a0
 add NENT,a0
 mov a3,a1
 add NENT,a1
 mov 80,d1
 call ub_cpy,[],0
 mov a2,a0                        /* NPTR after NENT: a reader takes a group only with its entries */
 add NPTR,a0
 mov a3,a1
 add NPTR,a1
 mov 16,d1
 call ub_cpy,[],0
 mov a3,a0
 call free,[],4
20:
 mov (8,sp),a2
 mov UB_PFL + FL_SB,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 clr d0
 movbu d0,(ub_cv)
 mov (4,sp),a0
 call ub_rd,[d2,d3,a2,a3],28
 movbu (ub_cv),d0
 cmp 1,d0
 bne 8f
 mov (4,sp),a0
 call ub_kn,[d2,d3],12
 cmp 0,d0
 bne 8f
 mov 1,d0
 movbu d0,(ub_src)
 mov (8,sp),a2
 mov (4,sp),d0
 mov d0,(LPTR,a2)                 /* one store: a reader has the old films or the new */
 call ub_put,[d2,d3,a2,a3],20
 bra 9f
8:
 mov (4,sp),a0
 call free,[],4
9:
 ret [d2,d3,a2,a3],36

/* hl_ok: `call hl_ok,[a2],16` -> d0 0 when all 10 sections are copied, this is the HLS_EVENT task and a medium is
 * mounted; 2 with no medium; else 1. Local (4) tid. */
hl_ok:
 mov (SECBITS),d0
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne 8f
 mov sp,a0
 add 4,a0
 call get_tid,[a2],4
 cmp 0,d0
 bne 8f
 movhu (HLS_TID),d1
 cmp 0,d1
 beq 8f
 btst 0x8000,d1
 bne 8f
 movhu (4,sp),d0
 cmp d1,d0
 bne 8f
 mov 61440,d1
 mov (MS_A),d0
 cmp d1,d0
 beq 1f
 mov (MS_B),d0
 cmp d1,d0
 beq 1f
 mov (MS_C),d0
 cmp d1,d0
 beq 1f
 mov HL_NOMED,d0
 ret [a2],16
1:
 clr d0
 ret [a2],16
8:
 mov HL_FAIL,d0
 ret [a2],16
/* st_claim: `call st_claim,[d2,d3],12` -> d0 1 when STATE was 0 and is now 0xffff (this task loads), else 0. Under
 * LOCK: el_go (GUI task) and pr_go (HLS task) may test it at once. */
st_claim:
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movhu (STATE),d0
 cmp 0,d0
 bne 1f
 mov 0xffff,d0
 movhu d0,(STATE)
 mov d3,d0
 call UNLOCK,[d2],8
 mov 1,d0
 ret [d2,d3],12
1:
 mov d3,d0
 call UNLOCK,[d2],8
 clr d0
 ret [d2,d3],12
el_cd:                            /* 1: the card pass is due (el_card) */
 .byte 0
el_nc:
 .byte 0
el_hold:
 .byte 0
el_pm:                            /* el_ok's answer */
 .byte 0
el_g:                             /* the group at the early load */
 .byte 0
el_pick:                          /* 1: a menu pick before the first look (dm_rec) */
 .byte 0
el_pk:                            /* 1: a picture-mode change not yet kept for the group (sx_set -> gx_map) */
 .byte 0
 .balign 2
el_tid:                           /* the GUI task's id, noted by el_go */
 .hword 0xffff

 .include "rgbcurves.inc"           /* rgb-curves: engine, storage */
 .include "colourmix.inc"           /* colour mix: the per-film 3 x 3 matrix (m1) */
 .include "curvesfile.inc"          /* v0.30 test 9: CURVES.BIN, each film's built-in curves and mix */

.section .ext13,"ax"
 .include "wheel.inc"             /* wl_tab (build.py): fl_mk copies it into wl_blk */
.section .ext12,"ax"
.balign 4
wl_blk:                           /* the heap copy of wl_tab (fl_mk), 0 = none */
 .long 0

/* ---- Border preview in live view (feature/border-live-view, owner 2026-11-17: "borders don't show up in live view"
 * -> "Add a live view preview"). With a Border 1..5 on the look on screen (a COLOR picture mode, its slot +50), the
 * shooting screen's grid shows the border's inner edge as a frame line: where the photo's white border will start
 * (bd_run's width, 1.5 / 3 / 4.5 / 6 / 7.5 % of the picture's short side). Drawn by the camera's own grid layer on
 * every screen it has (the four grid builders; the rear screen one at 0x612380bf), at the picture's place for the
 * aspect (the table's thirds record), so nothing is drawn by us and nothing in live view or capture changes.
 * Displayed Grid: thirds and golden keep their lines with the frame; Off, 6x4, scale, diagonal and the 16:9 frame show
 * the frame alone while a Border is set. Photo modes only (mx_photo), after the first shutter event (STATE and
 * el_hold: the start-up rule); video, S&Q and the movie grid (446) stay stock. research/NOTES.md "Border preview".
 *
 * bl_gv <- `call bl_gv,[d2,d3,a2,a3],28` at the four builders' grid read (stock: the GUI's setting read gui_get,
 * d0 = 155 or 2047 (stills grid) / 446 (movie grid), a0 -> the value; d0 = 0 when read). After the stock read, with a
 * Border L the value v (0..15) becomes BL_V | L << 4 | v: a line grid (kind 1) that no table holds, so the line lookup
 * misses and bl_tail draws it. Frame: (0) call slot, (4) id, then the picture mode, (8) -> the value. */
 .set BL_V, 0x100
 .set BL_C, 0x200                 /* crop modes (crop.s cr_gm): the lines fit the crop's strip */
.section .ext12,"ax"
bl_gv:
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov 0,a3                         /* mx_photo's answer, for cr_gm (crop.s): 0 not asked */
 call gui_get,[d2,d3,a2,a3],28    /* the stock read */
 mov d0,d2                        /* its answer, given back */
 mov (4,sp),d0
 cmp 155,d0
 beq 1f
 cmp 2047,d0
 bne 9f
1:
 call mx_photo,[],0               /* photo modes only (#68): video and S&Q keep their grid */
 mov d0,a3
 cmp 0,d0
 beq 9f
 movbu (el_hold),d0               /* after the early load: not before the first shutter event */
 cmp 0,d0
 bne 9f
 PVAL 9f                          /* a2 = P (STATE is 0 until the films load) */
 mov a2,a1                        /* some COLOR slot with a Border 1..5 (+50)? Else no picture mode read */
 mov 4,d1
4:
 movbu (32 + 50,a1),d0
 add -1,d0
 cmp 5,d0
 bcs 5f
 add 64,a1
 add -1,d1
 bne 4b
 bra 9f
5:
 mov 111,d0                       /* the picture mode, through the GUI's own read (ex_live's id) */
 mov sp,a0
 add 4,a0
 call gui_get,[d2,d3,a2,a3],28    /* keeps d2, d3, a2, a3 */
 cmp 0,d0
 bne 9f
 mov (4,sp),d0
 mov fl_cvt,a0                    /* COLOR k's picture mode value */
 clr d1
2:
 movbu (d1,a0),d3
 cmp d3,d0
 beq 3f
 inc d1
 cmp 4,d1
 bcs 2b
 bra 9f                           /* not COLOR 1..4 */
3:
 asl 6,d1
 add 32,d1
 add d1,a2                        /* COLOR k's slot */
 movbu (50,a2),d0                 /* the Border 1..5 (as xb_gs) */
 cmp 0,d0
 beq 9f
 cmp 6,d0
 bcc 9f
 mov (8,sp),a0
 mov (a0),d1                      /* the grid chosen */
 cmp 16,d1
 bcc 9f
 asl 4,d0
 or d1,d0
 or BL_V,d0
 mov d0,(a0)
9:
 mov (8,sp),a0                    /* crop modes: a crop's grid lines go inside the strip (crop.s cr_gm, BL_C) */
 call cr_gm,[d2,d3,a2,a3],28
 mov d2,d0
 ret [d2,d3,a2,a3],28

/* bl_tail <- jmp from the line lookup's loop end 0x611c7922 (`inc d3; add 68,a1; cmp d1,d3; lcs`; frame-lines' hook
 * site; the lookup 0x611c78c7 runs in its caller's `call ..,[d2,d3,a2,a3],16`, ending with retf). Reached after each
 * record that is not the value: d0 the value, d1 the count, d3 the index, a1 the record, (20,sp) -> the grid's 5 "V"
 * rects, (24,sp) -> its 3 "H" rects ({x0, y0, x1, y1} u16; each draws a line from (x0, y0) to (x1, y1), 2 px wide,
 * om-emu). The loop goes on as stock; at its end a value of ours (BL_V | L << 4 | v) gets: v's lines when v is thirds
 * (1) or golden (6), then the frame B inside the picture (the thirds record's V[0] y0..y1 and H[0] x0..x1),
 * B = max(1, min(w, h) 983 L >> 16) as bd_run, in the first empty slots. No calls (the frame has no free word);
 * returns through the stack (mul uses mdr). */
bl_tail:
 inc d3
 add 68,a1
 cmp d1,d3
 bcc 1f
 jmp gl_loop                      /* 0x611c78cc: the next record */
1:
 mov d0,d2
 and 0xfffffc00,d2                /* ours: only bits 8 (BL_V, a Border) and 9 (BL_C, a crop: crop.s cr_gm) above v, L */
 bne 0f
 mov d0,d2
 and 0x300,d2
 bne 2f
0:
 jmp gl_ret                       /* 0x611c7927: retf (a miss writes nothing, as stock) */
2:
 mov d0,(bl_v)
 mov d1,d3                        /* back to the first record (count >= 1 here) */
3:
 add -68,a1
 add -1,d3
 bne 3b
 mov bl_r,a2
 clr d2
 clr d3
4:
 mov d2,(d3,a2)
 add 4,d3
 cmp 64,d3
 bcs 4b
 mov (bl_v),d2
 and 15,d2
 cmp 1,d2
 beq 5f
 cmp 6,d2
 beq 5f
 cmp 5,d2                         /* crop modes: 6x4 too (a crop's value always misses its own record) */
 bne 6f
 mov (bl_v),d0
 and BL_C,d0
 beq 6f
5:
 mov a1,a0                        /* v's record -> bl_r */
 mov d1,d3
51:
 mov (a0),d0
 cmp d2,d0
 beq 52f
 add 68,a0
 add -1,d3
 bne 51b
 bra 6f
52:
 add 4,a0
 clr d3
53:
 mov (d3,a0),d0
 mov d0,(d3,a2)
 add 4,d3
 cmp 64,d3
 bcs 53b
6:
 mov a1,a0                        /* the thirds record: the picture's place */
 mov d1,d3
61:
 mov (a0),d0
 cmp 1,d0
 beq 62f
 add 68,a0
 add -1,d3
 bne 61b
 bra 8f                           /* none: no frame */
62:
 movhu (44,a0),d0                 /* x0 */
 movhu (48,a0),d1                 /* x1 */
 movhu (6,a0),d2                  /* y0 */
 movhu (10,a0),d3                 /* y1 */
 mov bl_q,a3
 movhu d0,(0,a3)
 movhu d1,(2,a3)
 movhu d2,(4,a3)
 movhu d3,(6,a3)
 mov (bl_v),d0                    /* crop modes: the lines and the picture's place -> the crop's strip (crop.s cr_gx) */
 and BL_C,d0
 beq bl_cgb
 jmp cr_gx
bl_cgb:                           /* (back from cr_gx: the strip in bl_q) */
 movhu (0,a3),d0
 movhu (2,a3),d1
 movhu (4,a3),d2
 movhu (6,a3),d3
 sub d0,d1                        /* w */
 sub d2,d3                        /* h */
 cmp d1,d3
 bcc 63f
 mov d3,d1                        /* the short side */
63:
 mov (bl_v),d0
 lsr 4,d0
 and 15,d0
 bne 66f
 jmp 8f                           /* crop modes: no Border (L 0), no frame */
66:
 mov 983,d2
 mul d2,d0
 mul d1,d0
 lsr 16,d0
 cmp 0,d0
 bne 64f
 mov 1,d0                         /* B */
64:
 movhu (6,a3),d1                  /* yb = y1 - B (kept where the bottom line's y1 goes) */
 sub d0,d1
 movhu d1,(30,a3)
 movhu (0,a3),d1                  /* xl = x0 + B, xr = x1 - B, yt = y0 + B */
 add d0,d1
 movhu (2,a3),d2
 sub d0,d2
 movhu (4,a3),d3
 add d0,d3
 movhu (30,a3),d0                 /* d1 xl, d2 xr, d3 yt, d0 yb */
 movhu d1,(0,a3)                  /* bl_q: the 4 lines {left, right, top, bottom} */
 movhu d3,(2,a3)
 movhu d1,(4,a3)
 movhu d0,(6,a3)
 movhu d2,(8,a3)
 movhu d3,(10,a3)
 movhu d2,(12,a3)
 movhu d0,(14,a3)
 movhu d1,(16,a3)
 movhu d3,(18,a3)
 movhu d2,(20,a3)
 movhu d3,(22,a3)
 movhu d1,(24,a3)
 movhu d0,(26,a3)
 movhu d2,(28,a3)
 movhu d0,(30,a3)
 clr d2                           /* line i * 8 */
71:
 clr d3                           /* slot k * 8: the first empty one */
72:
 mov a2,a1
 add d3,a1
 mov (a1),d0
 mov (4,a1),d1
 or d1,d0
 beq 73f
 add 8,d3
 cmp 64,d3
 bcs 72b
 bra 8f                           /* no empty slot left */
73:
 mov a3,a0
 add d2,a0
 mov (a0),d0
 mov d0,(a1)
 mov (4,a0),d0
 mov d0,(4,a1)
 add 8,d2
 cmp 32,d2
 bcs 71b
8:
 mov (20,sp),a1                   /* bl_r -> the grid's 5 + 3 rects (halfwords, as the stock lookup) */
 clr d0
81:
 movhu (d0,a2),d1
 movhu d1,(d0,a1)
 add 2,d0
 cmp 40,d0
 bcs 81b
 mov (24,sp),a1
 add 40,a2
 clr d0
82:
 movhu (d0,a2),d1
 movhu d1,(d0,a1)
 add 2,d0
 cmp 24,d0
 bcs 82b
 ret [d2,d3,a2,a3],16
 .balign 4
bl_r:                             /* the grid's lines: 5 "V" then 3 "H" rects */
 .space 64
bl_q:                             /* the picture's x0 x1 y0 y1, then the frame's 4 lines */
 .space 32
bl_v:                             /* the value */
 .long 0

.section .hook_bga,"ax"
 call bl_gv,[d2,d3,a2,a3],28      /* stock 0x6123825e: call 0x610fd8ef,[d2,d3,a2,a3],28 (grid builder 0x612380bf) */
.section .hook_bgb,"ax"
 call bl_gv,[d2,d3,a2,a3],28      /* stock 0x611cb433: the same read (grid builder 0x611cb359) */
.section .hook_bgc,"ax"
 call bl_gv,[d2,d3,a2,a3],28      /* stock 0x611e44d7: the same read (grid builder 0x611e4221) */
.section .hook_bgd,"ax"
 call bl_gv,[d2,d3,a2,a3],28      /* stock 0x611eae1e: the same read (grid builder 0x611eab68) */
.section .hook_blk,"ax"
 jmp bl_tail                      /* stock 0x611c7922: inc d3; add 68,a1; cmp d1,d3; lcs */

 .include "crop.s"                /* custom crop modes (feature/crop-modes) */
