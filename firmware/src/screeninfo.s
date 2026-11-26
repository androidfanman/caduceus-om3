/* ---- Screen info (feature/screen-info, test build s1, 2026-11-14; research/NOTES.md "Screen info"). Owner's design:
 * show / hide single items on the photo Information displays, chosen on the camera's own Info Settings pages; INFO
 * cycles the displays as before. Build s1: the rear screen's photo Information 1 / 2 / 3 only (viewfinder, video and
 * playback untouched).
 *
 * Menu: build.py gives the pages Custom menu > 4. Information > Camera Info Settings > Information 1 / 2 / 3 (menu
 * item lists 0x10..0x12, row lists 0x15f..0x161) 14 more tick rows after the stock four, with our setting ids
 * SIB + 32 * page + k (k = item 0..16; s3 split three rows: AF Mode / Subject Detection, Exposure Comp. /
 * Exposure Level Meter, Record Mode / Image Aspect). Their values come only from here (sl_get / sl_set / sl_cnt / sl_vbi / sl_sel
 * / ed_default send them on): 1 shown (ticked, the default), 0 hidden.
 *
 * Kept in the unused tail of the camera's settings store M (as the films and custom-mode records are), at M + 0x3C000
 * ('OM3I', CRC): a 32-bit hide mask per display, bit k = item k hidden. No record or a bad one = nothing hidden (stock
 * screen). A tick writes the record into M (both aliases, dispatch held, only while the camera is not saving M;
 * else si_pend and again at the next screen update) and sets M's changed byte: the camera saves M itself at the
 * return to shooting and at power-off. We never write flash.
 *
 * Screen: .hook_si at 0x6123043d, in the shooting screen's updater (0x6122fb93), just before it compares each item
 * buffer with the previous update's copy and sends only the changed ones. Until the first shutter event after
 * switch-on (STATE 0, or el_hold set after v0.30's early load: the gate border preview uses) it does nothing at all
 * (owner's rule: leave the start-up alone). After it, on the
 * rear screen ((6916,this) != 5, as the camera's own split), photo only (setting 44 != 1 and (2116,this) != 1, as
 * 0x6123d16a), Information 1 / 2 / 3 ((6992,this) = 19 / 20 / 23), it clears the chosen items' fields in the buffers
 * to the values Image Only leaves there (0), so the screen draws them as not shown. Item fields: si_tab (om-emu map,
 * research/NOTES.md). Never cleared: warnings, battery, AF frame, grid, histogram / level (stock rows). */

.section .hook_si,"ax"
 jmp si_upd                       /* stock 0x6123043d: mov 0x62ceeb54,a0 (6 B) */
 .byte 0xcb

.section .ext12,"ax"

/* si_upd <- .hook_si (jmp; the updater's frame: `this` at (12,sp), item buffers at (slot,sp)). d0 / d1 / a0 / a1 are
 * free here (the stock code reloads them); d2 / d3 / a2 / a3 are kept (saved and restored). */
si_upd:
 movbu (cr_rch),d0                /* crop83-2: the crop set at start-up kept (crop.s cr_chk), before this hook's gates */
 cmp 0,d0
 beq 0f
 movm [d2,d3,a2,a3],(sp)
 add -8,sp                        /* (0) call slot, (4) MDR */
 mov mdr,d0
 mov d0,(4,sp)
 call cr_chk,[d2,d3,a2,a3],24
 mov (4,sp),d0
 mov d0,mdr
 add 8,sp
 movm (sp),[d2,d3,a2,a3]
0:
 movhu (STATE),d0
 cmp 0,d0
 beq 9f                           /* before the films load: nothing */
 movbu (el_hold),d0               /* v0.40: after an early load, not before the first shutter event (as bl_gv) */
 cmp 0,d0
 bne 9f
 movm [d2,d3,a2,a3],(sp)
 add -16,sp                       /* (0) call slot, (4) getter out, (8) MDR */
 mov mdr,d0
 mov d0,(8,sp)
 movbu (si_pend),d0
 cmp 0,d0
 beq 1f
 call si_wr,[d2,d3,a2,a3],20      /* a tick held back by the camera's own save of M */
1:
 call si_ld,[d2,d3,a2,a3],20
 mov (SI_FR + 12,sp),a2           /* the updater's `this` */
 mov (6916,a2),d0
 cmp 5,d0
 beq 8f                           /* the viewfinder: not in s1 */
 mov (6992,a2),d0
 clr d2
 cmp 19,d0
 beq 2f
 mov 4,d2
 cmp 20,d0
 beq 2f
 mov 8,d2
 cmp 23,d0
 bne 8f                           /* Image Only and anything else: stock */
2:
 mov si_ram + 12,a0
 add d2,a0
 mov (a0),d3                      /* the hide mask */
 cmp 0,d3
 beq 8f
 mov (2116,a2),d0                 /* movie (as the camera's own split at 0x6123d173): stock */
 cmp 1,d0
 beq 8f
 clr d0
 mov d0,(4,sp)
 mov sp,a0
 add 4,a0
 mov 44,d0
 call si_get44,[d2,d3,a2,a3],28
 mov (4,sp),d0
 cmp 1,d0
 beq 8f
 mov si_tab,a3                    /* {u8 item, u8 buffer slot, u16 offset}, item 0xff ends (.ext11) */
3:
 movbu (a3),d0
 cmp 0xff,d0
 beq 8f
 mov d3,d1
 lsr d0,d1
 btst 1,d1
 beq 4f
 movbu (1,a3),d0
 mov sp,a0
 add d0,a0
 mov (SI_FR,a0),a0                /* the buffer */
 movhu (2,a3),d0
 add d0,a0
 clr d0
 movbu d0,(a0)
4:
 add 4,a3
 bra 3b
8:
 mov (8,sp),d0
 mov d0,mdr
 add 16,sp
 movm (sp),[d2,d3,a2,a3]
9:
 jmp fc_upd                       /* Film Rolls: the frames left (frcard.s -> the card file; else the 6 bytes and si_back) */

/* si_ld: `call si_ld,[d2,d3,a2,a3],20`: the record from M into si_ram, once per power-on (no record or a bad one:
 * zeros = nothing hidden). Reads only. */
si_ld:
 movbu (si_ok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(si_ok)
 mov SI_C,a3
 mov (a3),d0
 cmp SI_MAGIC,d0
 bne 8f
 movhu (4,a3),d0
 cmp SI_VER,d0
 bne 8f
 movhu (6,a3),d0
 cmp SI_LEN,d0
 bne 8f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov SI_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 8f
 mov si_ram,a0
 mov a3,a1
 mov SI_LEN,d1
 call ub_cpy,[],0
 bra 9f
8:
 mov si_ram,a0
 mov SI_LEN,d1
 call ub_zero,[],0
9:
 ret [d2,d3,a2,a3],20

/* si_wr: `call si_wr,[d2,d3,a2,a3],20`: si_ram -> M (both aliases), as cm_wr writes its record */
si_wr:
 mov SI_MAGIC,d0
 mov d0,(si_ram)
 mov SI_VER,d0
 movhu d0,(si_ram + 4)
 mov SI_LEN,d0
 movhu d0,(si_ram + 6)
 mov -1,d0
 mov si_ram + 12,a0
 mov SI_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(si_ram + 8)
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 8f                           /* the camera is saving M: again at the next screen update */
 mov SI_C,a0
 mov si_ram,a1
 mov SI_LEN,d1
 call ub_cpy,[],0
 mov SI_U,a0
 mov si_ram,a1
 mov SI_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(UB_DIRTY)              /* M changed: the camera saves it at the next return to shooting or power-off */
 clr d0
 movbu d0,(si_pend)
 mov d3,d0
 call UNLOCK,[d2],8
 bra 9f
8:
 mov 1,d0
 movbu d0,(si_pend)
 mov d3,d0
 call UNLOCK,[d2],8
9:
 ret [d2,d3,a2,a3],20

/* si_bit: d0 = one of our ids -> a0 = its mask's address, d1 = its bit (1 << k), or d1 = 0 (no such item). Uses
 * d0, d1, a0. */
si_bit:
 exthu d0
 add -SIB,d0
 mov d0,d1
 lsr 5,d1                         /* page */
 and 31,d0                        /* k */
 mov si_ram + 12,a0
 asl2 d1
 add d1,a0
 clr d1
 cmp SI_K,d0
 bcc 9f
 mov 1,d1
 asl d0,d1
9:
 ret [],0

/* si_get <- sl_get (CALLS: d0 id, a0 facade, a1 out != 0, MDR the return) -> (a1) 1 shown / 0 hidden, d0 0 */
si_get:
 add -16,sp                       /* (0) call slot, (4) a1, (8) MDR, (12) d0 */
 mov a1,(4,sp)
 mov d0,(12,sp)
 mov mdr,d0
 mov d0,(8,sp)
 call si_ld,[d2,d3,a2,a3],20
 mov (12,sp),d0
 call si_bit,[],0
 cmp 0,d1
 beq 2f                           /* no such item: shown */
 mov (a0),d0
 and d1,d0
 beq 2f
 clr d0                           /* hidden */
 bra 1f
2:
 mov 1,d0                         /* shown */
1:
 mov (4,sp),a1
 mov d0,(a1)
 mov (8,sp),d0
 mov d0,mdr
 add 16,sp
 clr d0
 rets

/* si_sv <- facade +4 word 0x60e57478 (SetValue, stock 0x60b8781f; build.py), CALLS: d0 id, d1 mode, a1 value, a0 the
 * facade. Ours: mode 0 sets a1 (1 shown / 0 hidden), modes 1 / 2 / 3 (the tick rows' OK sends 3) toggle; d0 0. The
 * stock SetValue would refuse our ids (its id check at 0x60ae9c08) and never reach .hook_set. Anything else: stock. */
si_sv:
 cmp SIB,d0
 bcs 1f
 cmp SIB + SI_N,d0
 bcs 2f
1:
 jmp si_sv0
2:
 add -16,sp                       /* (0) call slot, (4) MDR */
 mov d0,(8,sp)
 mov mdr,d0
 mov d0,(4,sp)
 mov a1,d0
 cmp 0,d1
 beq 3f
 mov -1,d0                        /* toggle */
3:
 mov d0,d1
 mov (8,sp),d0
 call si_put,[d2,d3,a2,a3],20
 mov (4,sp),d0
 mov d0,mdr
 add 16,sp
 clr d0
 rets

/* si_put: `call si_put,[d2,d3,a2,a3],20`: d0 one of our ids, d1 1 shown / 0 hidden / -1 toggle: into the mask, then
 * the record into M when it changed */
si_put:
 mov d1,d2                        /* the value */
 mov d0,d3                        /* the id */
 call si_ld,[d2,d3,a2,a3],20
 mov d3,d0
 call si_bit,[],0
 cmp 0,d1
 beq 9f
 mov (a0),d0
 mov d0,a2                        /* the old mask */
 cmp -1,d2
 bne 1f
 xor d1,d0                        /* toggle */
 bra 3f
1:
 or d1,d0                         /* hidden ... */
 cmp 0,d2
 beq 3f
 not d1
 and d1,d0                        /* ... or shown */
3:
 mov d0,(a0)
 cmp a2,d0
 beq 9f
 call si_wr,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* si_cnt <- sl_cnt (d0 id -> d0 2: Off / On), si_vbi <- sl_vbi (d1 index, a1 out or 0 -> d0 index or -1),
 * si_sel <- sl_sel (d1 value -> d0 1 when 0 / 1), si_def <- ed_default (a1 out -> (a1) 1 shown, d0 0). CALLS. */
si_cnt:
 mov 2,d0
 rets
si_vbi:
 mov d1,d0
 cmp 2,d0
 bcs 1f
 mov -1,d0
1:
 cmp 0,a1
 beq 2f
 mov d0,(a1)
2:
 rets
si_sel:
 clr d0
 cmp 2,d1
 bcc 1f
 mov 1,d0
1:
 rets
si_dfl:                           /* <- facade +156 word 0x60e57510 (build.py; was cv_dflt): ours, else cv_dflt */
 SICHK si_def
 jmp cv_dflt                      /* v0.40: GetDefault goes cv_dflt -> ed_default */
si_def:
 cmp 0,a1
 beq 1f
 mov 1,d0
 mov d0,(a1)
 clr d0
 rets
1:
 mov -268435434,d0                /* as the stock GetValue answers without an out pointer */
 rets

 .balign 4
si_ram:                           /* the record (si_ld / si_wr) */
 .space SI_LEN
si_ok:
 .byte 0
si_pend:
 .byte 0
 .balign 4
si_rows0:                         /* build.py: the pages' item records (28 B: the stock four, then ours) */
 .space 28 * (4 + SI_K)
si_rows1:
 .space 28 * (4 + SI_K)
si_rows2:
 .space 28 * (4 + SI_K)
si_rend:
 .balign 4

.section .ext11,"ax"               /* s3: .ext12 is full (v0.40-beta); the row lists sit in .ext11's tail */
 .balign 4
si_ord0:                          /* build.py: the pages' row lists (u16 setting ids) */
 .space 2 * (4 + SI_K)
si_ord1:
 .space 2 * (4 + SI_K)
si_ord2:
 .space 2 * (4 + SI_K)
si_end:
 .balign 4

.section .ext13,"ax"               /* rt1: .ext12 is full (with Film Rolls .ext4 too): si_str beside fwver.s fv_chk, which
                                   * jumps to it (both section 6) */

/* si_str <- jmp from fwver.s fv_chk (st_get's chain; the string getter's frame, ret [d2],8; d0 the id): rt1's row
 * name, else on to crop.s cr_str as before */
si_str:
 cmp ST_RMT,d0
 bne 1f
 mov si_rmt,a0
 ret [d2],8
1:
 jmp cr_str

.section .ext11,"ax"               /* rt1 (with Film Rolls): si_tab beside the row lists; si_upd reads it by its address */

/* Item fields (om-emu, stock 1.1, rear screen; each byte as Image Only leaves it: 0). Slots: var 38 (4,sp),
 * var 33 (88,sp), var 32 (80,sp), var 34 (8,sp), var 31 (72,sp). */
 .macro SIF k, slot, off
 .byte \k, \slot
 .hword \off
 .endm
 .balign 4                        /* the walk reads the offsets as halfwords: never odd (s2: an odd si_tab faulted) */
si_tab:
 SIF 0, 4, 0                      /* 0 Shooting Mode: the mode icon (u16) */
 SIF 0, 4, 1
 SIF 1, 88, 0                     /* 1 Shutter Speed */
 SIF 1, 88, 4
 SIF 1, 88, 7
 SIF 2, 88, 24                    /* 2 Aperture Value */
 SIF 2, 88, 28
 SIF 3, 80, 5                     /* 3 Exposure Comp.: the value, its marker */
 SIF 3, 80, 6
 SIF 3, 80, 80
 SIF 15, 80, 84                   /* 15 Exposure Level Meter: the bar (s3; was under 3) */
 SIF 15, 80, 88
 SIF 4, 4, 2                      /* 4 ISO */
 SIF 5, 4, 39                     /* 5 WB: icon, block, Kelvin (u16) */
 SIF 5, 4, 401
 SIF 5, 4, 404
 SIF 5, 4, 405
 SIF 6, 4, 60                     /* 6 Picture Mode (and our FILM label; u16 picture id) */
 SIF 6, 4, 61
 SIF 7, 4, 38                     /* 7 Image Stabilizer */
 SIF 8, 4, 36                     /* 8 AF Mode */
 SIF 14, 4, 3                     /* 14 Subject Detection: face / eye / subject icon (s3; was under 8) */
 SIF 9, 4, 40                     /* 9 Drive Mode */
 SIF 10, 4, 35                    /* 10 Metering */
 SIF 16, 4, 48                    /* 16 Image Aspect (s3; was under 11) */
 SIF 11, 4, 49                    /* 11 Record Mode: still quality, movie quality */
 SIF 11, 4, 50
 SIF 12, 8, 8                     /* 12 Remaining Files: shots left (u16, its shown flag); rt1: the movie time left moved
                                   * to item 17 (owner, 2026-11-25: two separate choices) */
 SIF 12, 8, 9
 SIF 12, 8, 12
 SIF 17, 8, 16                    /* 17 Remaining Movie Time (rt1): the "[10:45]" beside the shots left, its shown flag */
 SIF 13, 72, 75                   /* 13 Touch screen: the touch-shutter icon */
 .byte 0xff, 0, 0, 0
 .balign 4
.section .ext13,"ax"
 .balign 2
si_rmt:                           /* rt1: "Remaining Movie Time", UTF-16 (beside the camera's own "Remaining Files") */
 .short 82, 101, 109, 97, 105, 110, 105, 110, 103, 32, 77, 111, 118, 105, 101, 32, 84, 105, 109, 101, 0
 .balign 4
