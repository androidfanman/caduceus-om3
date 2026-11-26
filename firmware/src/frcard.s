/* Film Rolls on the card (feature/film-rolls-card, 2026-11-24; FILM-ROLLS-ROADMAP.md tasks A1 / A2). The flashed part.
 *
 * Owner (2026-11-21 / 2026-11-24): Film Rolls lives on the SD card. A card holding OM3MOD/FILMROLL/FILMROLL.BIN has
 * Film Rolls; any other card is a normal camera. The flashed firmware only carries what must be flashed: this loader,
 * one small stub per place Film Rolls joins the camera (each: "is FILMROLL.BIN loaded? then its code, else as stock").
 * (Until the release tidy-up also a Film Roll row in Picture Mode; the length and the rewind are on the film selection
 * row now, through the card file's own hooks.) Everything else is the card file (frblock.s, built by build.py
 * make_frblock): Film Rolls v2 r2b + r3 (feature/film-rolls-2), moved there.
 *
 * Loading: once a power-on, at the first shutter event that may read the card (lg_pr -> fc_hp, hl_ok as the debug log:
 * every section in, the HLS_EVENT task, a medium mounted): never while the camera starts (the start-up rule). The file:
 * [code | relocations | {tag, end - code, code length, count}] as GUIDES.BIN's code block (make_xblock), in one malloc
 * block (<= 16448 B, the camera's largest pool). Its tag is 'F' + 3 bytes of this firmware image's SHA-256: a card
 * file built for another firmware is refused (fc_st 6), and nothing of it runs. Entry 0 relocates the block in place
 * and starts it (frblock.s fb_reloc), then fc_tab = the block: from then on the stubs go to it.
 *
 * fc_tab is in .ext4 (section 4, copied before the GUI's section 7 runs .hook_rv): 0 until the block is loaded. */
 .set FB_HP, 8                     /* the block's entries (frblock.s, 8 bytes apart): rl_hp */
 .set FB_FIX, 16                   /* rl_fix */
 .set FB_SHOT, 24                  /* rl_shot */
 .set FB_LK, 32                    /* rl_lk */
 .set FB_TXT, 40                   /* rl_txt */
 .set FB_UPD, 48                   /* rl_upd */
 .set FB_VS, 56                    /* rl_vs */
 .set FB_REL, 64                   /* rl_rel */
 .set FB_IDLE, 72                  /* rl_idle (B1) */

/* FRJ: if the block is loaded, on to its entry \off (same frame, same registers but \reg); else on after the macro */
 .macro FRJ name, off, reg
\name:
 mov (fc_tab),\reg
 cmp 0,\reg
 beq 8f
 add \off,\reg
 jmp (\reg)
8:
 .endm

 .section .ext4,"ax"
 .balign 4
fc_tab:                           /* the loaded block (its entry table), 0: Film Rolls off */
 .long 0
fc_rval:                          /* the length picked (0 None, 1..3: 24 / 36 / 72; while winding, the cursor): the card
                                   * file's (rl_sync, rl_row; the rear dial on the film selection row) */
 .byte 0
fc_did:                           /* 1 once the card was looked at this power-on */
 .byte 0
fc_path:                          /* (section 4: fc_load runs from the shutter hook; static:section-order) */
 .asciz "C:\\OM3MOD\\FILMROLL\\FILMROLL.BIN"
 .balign 4
fc_st:                            /* the load, for the debug log: 0 not looked, 1 loaded, 2 no file, 3 bad size, 4 no
                                   * memory, 5 short read, 6 built for another firmware */
 .byte 0
fc_lock:                          /* D1: 1 while a roll has frames shot and is not rewound (the block sets it): no Playback */
 .byte 0
 .balign 4
fc_npk:                           /* D1: Playback key events removed this power-on (the block's log line) */
 .long 0

/* rl_vg <- .hook_rv (jmp): the GUI variable setter 0x610cd5c4 at its start (`call ..,[d2,a2],16`: d0 the variable, a0
 * its value). Var 34 (shots left) with the block loaded: its rl_vs (uses d2, a2; ends with the stock 7 bytes and
 * rlv_back). Anything else, or no block: the 7 bytes .hook_rv replaced, and back. */
 .section .hook_rv,"ax"
 jmp rl_vg
 .byte 0xcb, 0xcb
 .section .ext4,"ax"
rl_vg:
 cmp 34,d0
 bne 9f
 mov (fc_tab),a2
 cmp 0,a2
 beq 9f
 add FB_VS,a2
 jmp (a2)
9:
 mov a0,a2
 mov (0x6036f6e4),a0
 jmp rlv_back

/* rl_rel <- .hook_rel: ctrlRelease's `call isCtrlReleaseEnable,[],12` at 0x60b0cdad (r3). Keeps d0, d2, d3; uses a0. */
 .section .hook_rel,"ax"
 call fc_rel,[],12
 .section .ext4,"ax"
 FRJ fc_rel, FB_REL, a0
 jmp rel_ok

/* fc_hp: `call fc_hp,[d2,d3,a2,a3],24` from lg_pr (every shutter event). The block's rl_hp, or the loader. */
 FRJ fc_hp, FB_HP, a3
/* fc_load: the same frame (24: (4,sp) the read count). Uses d2 the size, d3 the buffer, a3 the handle. */
fc_load:
 movbu (fc_did),d0
 cmp 0,d0
 bne 9f
 call hl_ok,[a2],16               /* every section in, this task may read the card, a medium is there */
 cmp 0,d0
 bne 9f                           /* not yet: again at the next shutter event */
 mov 1,d0
 movbu d0,(fc_did)
fc_open:                          /* past the gates: the card is looked at now (tools/test watches it) */
 mov 2,d0
 movbu d0,(fc_st)
 mov fc_path,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,a3
 mov 3,d0
 movbu d0,(fc_st)
 clr d0
 mov 1,d1                         /* END */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov a3,a0
 call ftell,[d2,a2,a3],16
 mov d0,d2
 cmp 64,d2
 bcs 8f
 cmp 16449,d2                     /* the camera's largest malloc pool */
 bcc 8f
 mov a3,a0
 clr d0
 mov 2,d1                         /* SET */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov 4,d0
 movbu d0,(fc_st)
 mov d2,d0
 call malloc,[],4
 cmp 0,a0
 beq 8f
 mov a0,d3
 mov 5,d0
 movbu d0,(fc_st)
 mov 1,d0
 mov d2,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,(4,sp)
 mov a3,a0
 call fclose,[d2,a2,a3],16
 mov (4,sp),d0
 cmp d2,d0
 bne 7f
 mov 6,d0
 movbu d0,(fc_st)
 mov d3,a0
 add d2,a0                        /* the end */
 mov (-16,a0),d0
fc_tagref:
 cmp FRTAG,d0                     /* the build writes this firmware's tag here */
 bne 7f
 mov (-12,a0),d0
 sub d0,a0                        /* the code */
 cmp d3,a0
 bne 7f
 calls (a0)                       /* entry 0: relocate in place and start -> d0 = the block (a2 = P, as x_load) */
 mov 1,d1
 movbu d1,(fc_st)
 mov d0,(fc_tab)                  /* published last */
 mov d0,a3
 add FB_HP,a3
 jmp (a3)                         /* and this event's rl_hp, in this frame */
7:
 mov d3,a0
 call free,[],4
 bra 9f
8:
 mov a3,a0
 call fclose,[d2,a2,a3],16
9:
 ret [d2,d3,a2,a3],24

/* fc_shot: `call fc_shot,[],0` from ex_hook (in the capture). Uses d0, d1, a0. */
 FRJ fc_shot, FB_SHOT, a0
 ret [],0
/* fc_lk: `call fc_lk,[d2,d3,a2,a3],32` from sx_set: d0 901 or 6, d1 the value -> d1 the value to set; d0, a0, a1 kept. */
 FRJ fc_lk, FB_LK, a3
 ret [d2,d3,a2,a3],32

 .section .ext15,"ax"                /* stubs called only from section-6 code (rc_go, sl_set0), so section 6 too */
/* fc_fix: `call fc_fix,[d2,d3,a2,a3],24` from rc_go after cm_go (a2 = P). */
 FRJ fc_fix, FB_FIX, a3
 ret [d2,d3,a2,a3],24
/* fc_idle: `call fc_idle,[d2,d3,a2,a3],24` from lg_wk (task CADLOG) at a quiet poll: the roll to the card (B1) */
 FRJ fc_idle, FB_IDLE, a3
 ret [d2,d3,a2,a3],24
/* fc_upd <- jmp from screeninfo.s si_upd's end (the updater's frame). The block's rl_upd ends as this does. */
 FRJ fc_upd, FB_UPD, a0
 mov 0x62ceeb54,a0                /* the 6 bytes .hook_si replaced */
 jmp si_back
fc_l1s:                           /* (section 6, as lg_now; the numbers: fc_st) */
 .asciz "\r\nFilm Roll card file (1 = loaded) "
 .balign 4
/* fc_txt: `call fc_txt,[d2,d3,a2,a3],24` from lg_now: the load's result, then the block's lines. */
fc_txt:
 LGS fc_l1s
 movbu (fc_st),d0
 LGD
 FRJ fc_txt1, FB_TXT, a3
 ret [d2,d3,a2,a3],24
