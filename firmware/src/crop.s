/* Custom crop modes (feature/crop-modes, 2026-11-17): crop round 1 = the parts of feature/composition-guides c5 that
 * worked on the camera (c1..c6, 2026-11-13/14), with nothing of ours at start-up. research/NOTES.md "Crop modes ...".
 *
 * The camera's still aspect setting 269 gets three more values: 5 (5:4, the camera's own hidden ratio, native in every
 * size table), 6 (repurposed from 7:6 -> XPan 65:24) and 7 (repurposed from 6:5 -> 21:9), after Caduceus for the E-P7
 * (cakelesscoder, docs/ASPECT.md: ids 6 / 7 -> Panorama / Wide). Code and data here are ours, written for the OM-3 1.1
 * addresses; firmware/crop.py fills the tables and points the camera at them.
 *
 * Start-up (owner, 2026-11-13: nothing of ours while the camera starts): the camera's saved settings never hold 5 / 6 / 7
 * (cr_sin / cr_sbuf save the ratio the crop sits inside, and our tag), so the camera always starts on a stock ratio;
 * cr_rst puts the crop back and sets cr_on. #83 (2026-11-18): first at the GUI's first state change, the point where
 * v0.30's early load puts the films in (cr_el from gx_map, GUI task, photo modes only); the first shutter event stays
 * the fallback (cr_hp: from the half-press load nm_ex, or from lg_pr at a later shutter event). Until then every hook
 * here that runs while the camera draws (labels, the shooting screen's reads of 269) is the stock path plus one byte
 * read. Left out of c5's
 * build: the c4 / c5 run counters and the 0x6043900f counter hook, the playback label diagnosis, the SetValue hook
 * (cr_set: cr_rst's own check covers it), and c6's AF target lists (c6 was the only build with black screens). */

/* Round 7b (round 7 boot-looped the camera: research/NOTES.md "Crop round 7: the boot loop"). The firmware's sections
 * are copied 1..10 while the camera starts, and code in a section already in runs before the later ones arrive, so
 * nothing in sections 1..5 may reach .ext11..13 (section 6) unless section 6 is in (tools/test/static_check.py,
 * section-order). The two lists that section-2 records point to live in sections 1 / 2, and the two store-write hooks
 * (section 1) go through cr_g1 / cr_g2, which check the camera's own ready bit for section 6 first (SEC_READY, as
 * its check 0x60045e39 reads it; stock section 1 waits on it before calling section 9, 0x60062210). */
 .set SEC_READY, 0xa32de58c       /* bit id - 1: section id is in (set at 0x60046064) */
.section .ext2,"ax"
cr_vlist:                         /* validator list of 269 (stock 1,3,2,4,9 at 0x60616696; record 0x6061b670, section 2) */
 .byte 1, 3, 2, 4, 9, 5, 6, 7
.section .ext1,"ax"
 .balign 4                        /* as the stock map's (u16 pairs) */
cr_rmap:                          /* the stills rule's allowed values (stock 0x605d100c, 6 entries) + 5, 6, 7 (rule
                                     0x605d1134, section 2) */
 .space 9 * 4
cr_g1:                            /* jmp from 0x60061183 (d0 is free: 0x60060eff sets it) */
 mov (SEC_READY),d0
 and 0x20,d0
 beq 1f
 jmp cr_sin
1:
 mov a1,(12,sp)                   /* section 6 not in yet: the stock instructions */
 mov a0,a3
 call cr_ef,[],0
 jmp cr_sin_back
cr_g2:                            /* jmp from 0x6006120e (d0 is free: 0x60061214 clears it) */
 mov (SEC_READY),d0
 and 0x20,d0
 beq 1f
 jmp cr_sbuf
1:
 mov 0xa373d280,d3                /* the stock instruction (CR_BUF) */
 jmp cr_sb_back
.section .ext12,"ax"
 .balign 4
cr_stra:                          /* SCP strip lists A / B (stock 0x6155ea2c / 0x6155ea68, 5 x 12 B) + 3 entries */
 .space 8 * 12
cr_strb:
 .space 8 * 12
cr_on:                            /* 1 once cr_rst has run this power-on (at start-up, or the first half-press) */
 .byte 0
cr_dwh:                           /* #83: where cr_rst ran (the log): 1 at start-up (cr_el), 2 at a shutter event */
 .byte 0
cr_rch:                           /* crop83-2: 1 while cr_chk keeps the crop set at start-up (until the first shutter event) */
 .byte 0
cr_crp:                           /* crop83-2: the crop cr_rst set (5 / 6 / 7) */
 .byte 0
cr_usr:                           /* crop83-2: 1 once Image Aspect was set from the GUI task by anyone but us (a user's pick) */
 .byte 0
cr_self:                          /* crop83-2: 1 around our own ar_setv(269), so cr_sv does not count it */
 .byte 0
 .balign 2

/* Live view / preview boxes in CapThr_ThroughImage: six switches on the aspect id pick a box in the 640 class (7:6
 * 560 x 480, 6:5 576 x 480 in stock). Their jump-table entries for ids 6 / 7 come here: 640 x 240 (65:24) and 640 x 272
 * (21:9), heights in multiples of 16 as every size the camera makes. Each block sets the switch's width / height places
 * as the stock cases do and jumps to the stock code after them. (They run only behind a mode check: c4 counted none
 * while shooting; the live view itself takes ratioToConvertSize below.) */
/* getOutputSize (jump table 0x60e90f28): width -> (40,sp), height at 0x60c14d28 -> (44,sp) */
cr_os6:
 mov 640,d0
 mov d0,(40,sp)
 mov 240,d0
 jmp cr_os_j
cr_os7:
 mov 640,d0
 mov d0,(40,sp)
 mov 272,d0
 jmp cr_os_j
/* getTakeAreaSize (jump table 0x60e90f54): width -> (36,sp), height at 0x60c15156 -> (40,sp) */
cr_ta6:
 mov 640,d0
 mov d0,(36,sp)
 mov 240,d0
 jmp cr_ta_j
cr_ta7:
 mov 640,d0
 mov d0,(36,sp)
 mov 272,d0
 jmp cr_ta_j
/* switch after GetValue(269) at 0x60c066b7 (jump table 0x60e88188): width d3, height d2, then 0x60c0670e */
cr_sa6:
 mov 640,d3
 mov 240,d2
 jmp cr_sa_j
cr_sa7:
 mov 640,d3
 mov 272,d2
 jmp cr_sa_j
/* switch after GetValue(269) at 0x60c28c24 (jump table 0x60e9b0b8): width d1, height d0, then 0x60c28c7b */
cr_sb6:
 mov 640,d1
 mov 240,d0
 jmp cr_sb_j
cr_sb7:
 mov 640,d1
 mov 272,d0
 jmp cr_sb_j
/* switch after GetValue(269) at 0x60c2ab11 (jump table 0x60e9b678): width d0, height d1, then 0x60c2ab68 */
cr_sc6:
 mov 640,d0
 mov 240,d1
 jmp cr_sc_j
cr_sc7:
 mov 640,d0
 mov 272,d1
 jmp cr_sc_j
/* playback get_aspect_frame (jump table 0x60eac870): width a0, height d2, then 0x60c66889 */
cr_pb6:
 mov 640,a0
 mov 240,d2
 jmp cr_pb_j
cr_pb7:
 mov 640,a0
 mov 272,d2
 jmp cr_pb_j

/* cr_gv <- the shooting screen's own reads of 269 (`mov 269,d0; call 0x610fd8ef,[d2,d3,a2,a3],28`, a0 = where the
 * value goes; crop.py GV_SITES). Entered with that call's frame. They look positions up by aspect in lists that only
 * know 1, 2, 3, 4, 9 (10): AF frame, grid, layouts (a miss draws nothing: the AF frame vanished at 5 / 6 / 7 in om-emu).
 * So these reads get the ratio the crop sits inside: 5 (5:4) -> 1 (4:3), 6 / 7 (XPan, 21:9) -> 3 (16:9), as the
 * E-P7's issue #23 fix. The getter's own result (d0) is kept. Before the first half-press: the stock read alone. */
cr_gv:
 mov a0,(8,sp)                    /* the stock getter keeps a0 there too: our frame's slot */
 call cr_gv0,[d2,d3,a2,a3],28
 movbu (cr_on),d1
 cmp 0,d1
 beq 9f
 mov (8,sp),a0
 mov (a0),d1
 cmp 5,d1
 bne 1f
 mov 1,d1
 mov d1,(a0)
 bra 9f
1:
 cmp 6,d1
 beq 2f
 cmp 7,d1
 bne 9f
2:
 mov 3,d1
 mov d1,(a0)
9:
 ret [d2,d3,a2,a3],28

/* cr_gvl <- the two label reads among them (0x611d8467 the SCP cell, 0x612357fb the top bar) and the top bar's "show the
 * label?" (0x612356c0): each crop borrows a label slot of its own, so the camera redraws on every change, and 5:4
 * borrows 1:1's (the top bar hides 4:3's label): 5 -> 4, 6 -> 3, 7 -> 2. cr_ic then shows our picture there. */
cr_gvl:
 mov a0,(8,sp)
 call cr_gv0,[d2,d3,a2,a3],28
 movbu (cr_on),d1
 cmp 0,d1
 beq 9f
 mov (8,sp),a0
 mov (a0),d1
 cmp 5,d1
 bne 1f
 mov 4,d1
 bra 8f
1:
 cmp 6,d1
 bne 2f
 mov 3,d1
 bra 8f
2:
 cmp 7,d1
 bne 9f
 mov 2,d1
8:
 mov d1,(a0)
9:
 ret [d2,d3,a2,a3],28

/* framelines-1 (2026-11-18; owner: "Can we get the frame lines ... to match the crop mode like it does on the default
 * crop modes"). The shooting screen's aspect frame (the green lines at the picture's edges) comes from a style that
 * 0x6123853c writes into the screen object at +2962 from its read of 269 (0x612385d1; a3 points at the style, its
 * frame is [d2,d3,a2,a3],52), and the frame widget takes the style's rectangle from 0x60377760 (lookup 0x61176b7a).
 * Through cr_gv the crops got 16:9's / 4:3's style, so 16:9's lines. crop.py fills six unused entries with the
 * crops' rectangles. cr_gvf <- that read: as cr_gv, and with a crop set (cr_on, Image Aspect 5..7, a photo mode) it
 * sends the function's return (its 52 + this call's 28: (80,sp)) through cr_fst, which writes the crop's style over
 * the one just written. One at a time (cr_fra). Before the first restore of a power-on, and in video: as cr_gv.
 * In .ext13 (section 6 as .ext12, which is full). */
.section .ext13,"ax"
cr_gvf:
 mov a0,(8,sp)
 call cr_gv0,[d2,d3,a2,a3],28
 mov d0,d2                        /* the getter's result, kept */
 movbu (cr_on),d1
 cmp 0,d1
 beq 9f
 mov (8,sp),a0
 mov (a0),d1
 cmp 5,d1
 bcs 9f
 cmp 8,d1
 bcc 9f
 mov 1,d3                         /* as cr_gv: 5 -> 1, 6 / 7 -> 3 */
 cmp 5,d1
 beq 1f
 mov 3,d3
1:
 mov d3,(a0)
 mov (cr_fra),d1
 cmp 0,d1
 bne 9f
 call cr_pho,[],0
 cmp 0,d0
 beq 9f
 mov a3,(cr_fsp)                  /* where the style goes */
 mov (80,sp),d1
 mov d1,(cr_fra)
 mov cr_fst,d1
 mov d1,(80,sp)
9:
 mov d2,d0
 ret [d2,d3,a2,a3],28

/* cr_fst <- 0x6123853c's `ret [d2,d3,a2,a3],52` when cr_gvf sent it here: its caller's registers and sp. The style
 * it wrote -> the crop's (crop.py 4b): rear 16:9 (10) -> XPan 26, 21:9 27; rear 4:3 (8) -> 5:4 29; viewfinder 16:9
 * (16) -> XPan 30, 21:9 31; viewfinder 4:3 (32, no frame; (6916,this) 5) -> 5:4 22; any other style as it is. Back
 * to the caller through MDR (free after a call): d0, d1, a0, a1 as the function left them. */
cr_fst:
 mov d0,(cr_fsv)
 mov d1,(cr_fsv + 4)
 mov a0,(cr_fsv + 8)
 mov a1,(cr_fsv + 12)
 mov (cr_fsp),a0
 movhu (a0),d0
 movbu (CR_A1),d1
 cmp 5,d1
 beq 5f
 cmp 6,d1
 beq 6f
 cmp 7,d1
 bne 8f
 cmp 10,d0                        /* 21:9 */
 bne 1f
 mov 27,d0
 bra 7f
1:
 cmp 16,d0
 bne 8f
 mov 31,d0
 bra 7f
6:
 cmp 10,d0                        /* XPan */
 bne 1f
 mov 26,d0
 bra 7f
1:
 cmp 16,d0
 bne 8f
 mov 30,d0
 bra 7f
5:
 cmp 8,d0                         /* 5:4 */
 bne 1f
 mov 29,d0
 bra 7f
1:
 cmp 32,d0
 bne 8f
 mov a0,a1
 add -2962,a1
 mov (6916,a1),d1
 cmp 5,d1
 bne 8f
 mov 22,d0
7:
 movhu d0,(a0)
 mov (cr_nfr),d1
 inc d1
 mov d1,(cr_nfr)
8:
 mov (cr_fra),d0
 mov d0,mdr
 clr d0
 mov d0,(cr_fra)
 mov (cr_fsv),d0
 mov (cr_fsv + 4),d1
 mov (cr_fsv + 8),a0
 mov (cr_fsv + 12),a1
 retf [],0
 .balign 4
cr_fra:                           /* cr_fst's way back (0: none due), the style's place, the registers, the styles set */
 .long 0
cr_fsp:
 .long 0
cr_fsv:
 .space 16
cr_nfr:
 .long 0
.section .ext12,"ax"

/* The camera's saved settings never hold a crop. Store M (RAM image 0x62920700, 256 KiB) keeps 269 at +0x2c2 and
 * +0x32458. The camera saves M through 0x60061183 (a0 = the store, a1 = a callback): after a menu with a callback (the
 * image is copied to the buffer 0xa373d280 with its checksum, then written: cr_sbuf patches the buffer), at power-off
 * without one (compared with flash, then sealed and written from the RAM image: cr_sin patches the RAM image first; the
 * camera is shutting down). The saved copy gets the ratio the crop sits inside (5 -> 1, 6 / 7 -> 3) and our tag at
 * +0x39FF0 in M's unused tail ('C' 'R' 0 id, or 0); the buffer's 16-bit checksum (+2, the whole image sums to 0) is
 * corrected. The stock function reads only a0 / a3 and its stack after 0x60061183 (a1 is stored first; d0 comes from
 * 0x60060eff; d1 is set before use), so the registers used here are free. */
 .set CR_MH, 0xa32bb920           /* the store M handle (as 0x60063d73 reads it) */
 .set CR_A1, 0x629209c2           /* M + 0x2c2 */
 .set CR_A2, 0x62952b58           /* M + 0x32458 */
 .set CR_TG, 0x6295a6f0           /* M + 0x39ff0 (free: the films block starts at +0x3A000) */
 .set CR_UNC, 0x40000000          /* + this = the uncached alias */
 .set CR_BUF, 0xa373d280
 .set CR_TAGV, 0x43520000
 .set CR_DSP, 0xa32dd210          /* round 2: the live view display set-up's id (u8), +10 / +12 its picture area (u16) */
 .set CR_GUI, 0x603713a4          /* -> the GUI state (2 bytes: class, state; 0x0108 shooting, 0x0508 playback; om-emu) */
cr_sin:                           /* jmp from 0x60061183 (its frame; d2, d3, a2 not live yet) */
 mov a1,(12,sp)                   /* the stock instructions */
 mov a0,a3
 cmp 0,a1
 bne 9f                           /* a callback: the buffer is patched in cr_sbuf */
 mov (CR_MH),a1
 cmp a1,a0
 bne 9f
 mov (cr_nsin),d0                 /* the log counts these saves of M (crop83-3: all of them) */
 inc d0
 mov d0,(cr_nsin)
 movbu (CR_A1),d0
 cmp 5,d0
 bcs 8f
 cmp 8,d0
 bcc 8f
 mov d0,d2                        /* the crop */
 mov 1,d1
 cmp 5,d0
 beq 1f
 mov 3,d1
1:
 movbu d1,(CR_A1)
 movbu d1,(CR_A1 + CR_UNC)
 movbu d1,(CR_A2)
 movbu d1,(CR_A2 + CR_UNC)
 mov (cr_sra),d0                  /* crop83-3: the write returns through cr_sinr, which puts the crop back (once) */
 cmp 0,d0
 bne 2f
 movbu d1,(cr_sib)
 movbu d2,(cr_sic)
 mov (32,sp),d0                   /* the return address: the callers' `call 0x60061183,[d2,d3,a2,a3],32` */
 mov d0,(cr_sra)
 mov cr_sinr,d0
 mov d0,(32,sp)
2:
 mov CR_TAGV,d0
 or d2,d0
 bra 7f
8:
 clr d0
7:
 mov d0,(CR_TG)
 mov d0,(CR_TG + CR_UNC)
 mov d0,(cr_stg)                  /* crop83-3: the tag the last save wrote (the log) */
9:
 call cr_ef,[],0                  /* the stock call (a0 = the store) */
 jmp cr_sin_back

/* cr_sinr (crop83-3, 2026-11-18) <- the store write's `ret [d2,d3,a2,a3],32` after cr_sin patched a crop: the caller's
 * registers and sp, d0 = the write's result. Camera, test 8 (crop83-2): "save patches 2" in a power-on, and the next
 * start found no tag. The camera also saves M without a callback while it runs (not only at power-off), and that write
 * goes out of the RAM image itself (0x60061214: no buffer copy), so cr_sin has to patch the live value; until crop83-3
 * nothing put the crop back, Image Aspect stayed at the base (the screen showed 16:9) and the power-off save then
 * sealed no tag. Here the crop goes back into both copies as soon as the write returns, if the live value is still
 * the base cr_sin wrote. d1 / a0 / a1 / MDR are free (the callers keep nothing in them over the call). */
cr_sinr:
 mov d0,(cr_sir)
 movbu (CR_A1),d0
 movbu (cr_sib),d1
 cmp d1,d0
 bne 1f                           /* changed during the write: it stays */
 movbu (cr_sic),d0
 movbu d0,(CR_A1)
 movbu d0,(CR_A1 + CR_UNC)
 movbu d0,(CR_A2)
 movbu d0,(CR_A2 + CR_UNC)
 mov (cr_nsr),d0
 inc d0
 mov d0,(cr_nsr)
1:
 mov (cr_sra),a0
 clr d0
 mov d0,(cr_sra)
 mov (cr_sir),d0
 jmp (a0)

cr_sbuf:                          /* jmp from 0x6006120e (0x60061183's frame; a3 = the store, the buffer is filled) */
 mov (CR_MH),a1
 cmp a1,a3
 bne 9f
 mov (cr_nsb),d0                  /* crop83-3: the log counts these */
 inc d0
 mov d0,(cr_nsb)
 movbu (CR_BUF + 0x2c2),d0
 cmp 5,d0
 bcs 8f
 cmp 8,d0
 bcc 8f
 mov d0,d2                        /* the crop */
 mov 1,d3
 cmp 5,d0
 beq 1f
 mov 3,d3
1:
 movbu d3,(CR_BUF + 0x2c2)
 movbu d3,(CR_BUF + 0x32458)
 mov d3,d1                        /* the image's sum changes by 2 x (base - crop) (both bytes even: low halves) */
 sub d2,d1
 add d1,d1
 mov CR_TAGV,d0
 or d2,d0
 bra 7f
8:
 clr d1
 clr d0
7:
 mov (CR_BUF + 0x39ff0),d2        /* the tag: old -> new, and its two halves into the sum */
 mov d0,(CR_BUF + 0x39ff0)
 mov d0,(cr_stg)                  /* crop83-3: the tag the last save wrote (the log) */
 mov d0,d3
 exthu d3
 add d3,d1
 mov d0,d3
 lsr 16,d3
 add d3,d1
 mov d2,d3
 exthu d3
 sub d3,d1
 mov d2,d3
 lsr 16,d3
 sub d3,d1
 movhu (CR_BUF + 2),d0            /* the checksum takes the opposite */
 sub d1,d0
 movhu d0,(CR_BUF + 2)
9:
 mov CR_BUF,d3                    /* the stock instruction */
 jmp cr_sb_back

/* cr_hp: `call cr_hp,[d2,d3,a2,a3],20` from nm_ex (sd_load's last call) and from lg_pr (every later shutter event),
 * both in the HLS_EVENT task: once per power-on, at the first shutter event, cr_rst, unless cr_el already ran it at
 * start-up. sd_load also runs in the early load (el_go, GUI task, during start-up, el_nc 1): nothing then (cr_el
 * follows el_go in gx_map). */
cr_hp:
 movbu (el_nc),d0
 cmp 0,d0
 bne 9f
 movbu (cr_rch),d0                /* crop83-2: the first shutter event checks the start-up crop once more, then stops */
 cmp 0,d0
 beq 1f
 call cr_chk,[d2,d3,a2,a3],24
 clr d0
 movbu d0,(cr_rch)
1:
 movbu (cr_on),d0
 cmp 0,d0
 bne 9f
 mov 2,d0
 call cr_rst,[d2,d3,a2,a3],24     /* d0 = 2: at a shutter event */
9:
 ret [d2,d3,a2,a3],20

/* cr_el (#83, 2026-11-18): `call cr_el,[d2,d3,a2,a3],20` from gx_map (the GUI task) at a GUI state change while cr_on
 * is 0. The camera's first one comes at the end of its start-up, where v0.30's early load puts the films in (el_go,
 * just before this in gx_map; camera-tested since v0.30): the crop goes back there too, so the shooting screen comes
 * up in it with no half-press. As el_go: not before all ten sections are copied (the next state change tries again).
 * Photo modes only: the camera's settings written while video live view starts freeze its image (#53, rc_go's rule);
 * in video, a later state change in a photo mode or the first half-press (cr_hp) puts it back. The mode as el_ok
 * reads it (ss_photo once the manager's handle is seen, else the photo / movie / S&Q switch). */
cr_el:
 movbu (cr_on),d0
 cmp 0,d0
 bne 9f
 mov (SECBITS),d0
 and 0x3ff,d0
 cmp 0x3ff,d0
 bne 9f
 mov cr_gtid,a0                   /* crop83-2: the GUI task, for cr_sv */
 call get_tid,[a2],4
 call cr_pho,[],0
 cmp 0,d0
 beq 9f
 mov 1,d0
 call cr_rst,[d2,d3,a2,a3],24     /* d0 = 1: at start-up */
9:
 ret [d2,d3,a2,a3],20

/* cr_pho: `call cr_pho,[],0` -> d0 1 in a photo mode, as el_ok reads it: ss_photo once the manager's handle is seen,
 * else the photo / movie / S&Q switch (UI_PSW 2). Uses d1, a0. */
cr_pho:
 mov (rc_in),a0
 cmp 0,a0
 beq 1f
 jmp ss_photo                     /* its ret [],0 returns from here */
1:
 movbu (UI_PSW),d1
 clr d0
 cmp 2,d1
 bne 2f
 mov 1,d0
2:
 ret [],0

/* crop83-2 (2026-11-18). Camera, crop83-1: the start-up restore ran (3 -> 6) and later in the same power-on Image
 * Aspect read 3 again, with no half-press needed for it: something in the camera's own start-up put the base back
 * after us (om-emu does not show it: its start-up is over before the GUI's first state change, and it runs no live
 * view). cr_chk keeps the crop for the rest of the start-up: from si_upd (each pass of the shooting screen's updater,
 * GUI task, as cr_el) while cr_rch is 1, and once more from cr_hp at the first shutter event, which closes it; so does
 * the next GUI state change (gx_map: a screen the user opens; a ratio picked on the control panel does not reach
 * sx_set, om-emu, and the updater does not run while the panel is open). If
 * Image Aspect is back at the crop's base and nobody picked a ratio from the GUI since (cr_usr), it sets the crop
 * again (ar_setv, as cr_rst), at most CR_NRE times; a ratio that is neither the crop nor its base closes it. Notes
 * for the log: the passes checked, the pass and the tag in memory when the base was first seen back (the tag is
 * 4352000x again only if our own save patch cr_sin ran), the times set again. */
 .set CR_NRE, 3
cr_chk:                           /* `call cr_chk,[d2,d3,a2,a3],24` */
 movbu (cr_rch),d0
 cmp 0,d0
 beq 9f
 movbu (cr_usr),d0
 cmp 0,d0
 bne 8f                           /* a ratio picked since: it stays */
 mov (cr_npa),d0
 inc d0
 mov d0,(cr_npa)
 movbu (cr_crp),d2
 movbu (CR_A1),d0
 cmp d2,d0
 beq 9f                           /* the crop is in place */
 mov 1,d1
 cmp 5,d2
 beq 1f
 mov 3,d1
1:
 cmp d1,d0
 bne 8f                           /* neither the crop nor its base: leave it */
 mov (cr_rpa),d1                  /* the base is back: noted the first time */
 cmp 0,d1
 bne 2f
 mov (cr_npa),d1
 mov d1,(cr_rpa)
 mov (CR_TG),d1
 mov d1,(cr_rtg)
2:
 mov (cr_nre),d1
 cmp CR_NRE,d1
 bcc 8f                           /* set CR_NRE times already: stop */
 call cr_pho,[],0
 cmp 0,d0
 beq 9f                           /* not now in video (#53): a later pass */
 mov (cr_sra),d0                  /* crop83-3: not while a save of M goes out of RAM (cr_sinr due) */
 cmp 0,d0
 bne 9f
 mov (cr_nre),d1
 inc d1
 mov d1,(cr_nre)
 mov 1,d0
 movbu d0,(cr_self)
 mov 269,d0
 movbu (cr_crp),d1
 mov (SEC_READY),d3
 and 0x40,d3
 beq 7f
 call ar_setv,[d2,a2],20          /* d1 = the crop */
7:
 clr d0
 movbu d0,(cr_self)
 bra 9f
8:
 clr d0
 movbu d0,(cr_rch)
9:
 ret [d2,d3,a2,a3],24

/* cr_sv: `call cr_sv,[d2,d3,a2,a3],20` from sx_set when Image Aspect (269) is set through the facade, d1 = the value.
 * Not ours (cr_self): counted for the log with the value and the task; from the GUI task (cr_gtid, noted by cr_el)
 * it is a ratio picked by the user (menu, control panel, dial), so cr_chk leaves Image Aspect alone from then on. */
cr_sv:
 movbu (cr_self),d0
 cmp 0,d0
 bne 9f
 mov d1,(cr_owv)
 mov (cr_own),d0
 inc d0
 mov d0,(cr_own)
 mov cr_owt,a0
 call get_tid,[a2],4
 movhu (cr_owt),d0
 movhu (cr_gtid),d1
 cmp d1,d0
 bne 9f
 mov 1,d0
 movbu d0,(cr_usr)
9:
 ret [d2,d3,a2,a3],20

/* cr_rst: `call cr_rst,[d2,d3,a2,a3],24`, d0 = where (1 start-up, 2 a shutter event), from cr_el (GUI task, where the
 * dial handler makes the same ar_setv call) or cr_hp (HLS_EVENT task). Once per power-on: cr_on is claimed under LOCK
 * (the two tasks may get here at once). Our tag in M (loaded with the camera's settings) says the crop the camera was
 * saved in; if the setting still holds that crop's base, set the crop again. The tag is cleared either way (the next
 * save seals it). Local (4) the crop (#83: frame 24; it was 20, where (4) is a saved register's slot). */
cr_rst:
 mov d0,a2
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (cr_on),d0
 cmp 0,d0
 bne 6f
 mov 1,d0
 movbu d0,(cr_on)
 mov a2,d0
 movbu d0,(cr_dwh)
 mov d3,d0
 call UNLOCK,[d2],8
 mov (CR_TG),d0
 mov d0,(cr_dtg)
 mov d0,d1
 lsr 16,d1
 cmp CR_TAGV >> 16,d1
 bne 9f
 and 0xff,d0
 cmp 5,d0
 bcs 8f
 cmp 8,d0
 bcc 8f
 mov d0,(4,sp)                    /* the crop */
                                  /* v0.40 alpha: ar_getv / ar_setv are in section 7: each call waits for its ready
                                   * bit (0x40); not in yet: 7, the next shutter event tries again (cr_on back to
                                   * 0, the tag kept) */
 mov 269,d0
 mov (SEC_READY),d3
 and 0x40,d3
 beq 7f
 call ar_getv,[d2,a2],24
 mov d0,(cr_das)
 mov (4,sp),d1
 mov 1,d2
 cmp 5,d1
 beq 1f
 mov 3,d2
1:
 cmp d2,d0
 beq 2f
 bra 8f                           /* the setting was changed since: leave it */
7:                                /* section 7 not in yet: as if this call had not come (the next one tries again); */
 clr d0                           /* here, in short reach of the three gates (static:section-order reads them) */
 movbu d0,(cr_on)
 movbu d0,(cr_dwh)
 movbu d0,(cr_self)
 ret [d2,d3,a2,a3],24
2:
 mov (cr_sra),d0                  /* crop83-3: not while a save of M goes out of RAM: as not ready, tried again */
 cmp 0,d0
 bne 7b
 mov d1,(cr_dst)
 movbu d1,(cr_crp)
 mov 1,d0
 movbu d0,(cr_self)
 mov 269,d0
 mov (SEC_READY),d3
 and 0x40,d3
 beq 7b
 call ar_setv,[d2,a2],20          /* d1 = the crop */
 clr d0
 movbu d0,(cr_self)
 movbu (cr_dwh),d0                /* crop83-2: set at start-up: cr_chk keeps it until the first shutter event */
 cmp 1,d0
 bne 3f
 movbu d0,(cr_rch)
3:
 mov 269,d0
 mov (SEC_READY),d3
 and 0x40,d3
 beq 7b
 call ar_getv,[d2,a2],24
 mov d0,(cr_daf)
8:
 clr d0
 mov d0,(CR_TG)
 mov d0,(CR_TG + CR_UNC)
9:
 ret [d2,d3,a2,a3],24
6:                                /* already claimed: nothing */
 mov d3,d0
 call UNLOCK,[d2],8
 ret [d2,d3,a2,a3],24

.section .hook_crs,"ax"
 jmp cr_g1                        /* stock 0x60061183: mov a1,(12,sp); mov a0,a3; call 0x60060eff,[],0 */
 .byte 0xcb, 0xcb, 0xcb
.section .hook_crb,"ax"
 jmp cr_g2                        /* stock 0x6006120e: mov 0xa373d280,d3 */
 .byte 0xcb
.section .ext12,"ax"

/* Labels for the new ratios. Pictures CR_IC0 + 0..8 (5:4, XPan, 21:9 for the SCP strip 100 x 76, the top bar 46 x 34
 * and the SCP cell 160 x 48; our drawing, firmware/mkicons.py crop_label_streams), answered here at the end of the
 * picture hook chain (ar_ic); strings CR_ST0 + 0..2 (the same words, for the menus' text lists) at the end of st_get's
 * chain. */
 .set CR_IC0, 0x7fc4              /* free: ours are 0x7f70.., 0x7f80..0x7fc3, 0x7fd0..0x7fd8, 0x7fe0..0x7fff */
 .set CR_NIC, 9
 .set CR_ST0, 0x7f68              /* free: our strings are 0x7f00..0x7f09, 0x7f10.., 0x7f30.., 0x7f48..0x7f63 */
cr_ic:                            /* d0 = the id, d1 = its exthu (ar_ic); a0 <- &descriptor word, retf as ar_ic */
 cmp CR_IC0,d1
 bcs 1f
 cmp CR_IC0 + CR_NIC,d1
 bcc 1f
 add -CR_IC0,d1
8:
 asl2 d1
 mov cr_ent,a0
 add d1,a0
 retf [],0
1:                                /* round 9c: in playback (GUI state classes 5..7) the label of the photo shown
                                   * (the info line's 10931 4:3 / 10930 16:9) -> ours while SimplePlayCommon found that
                                   * photo to be a 5:4 / XPan / 21:9 shape (cr_pbk) */
 mov (CR_GUI),a0
 cmp 0,a0
 beq 9f
 movbu (a0),d1
 cmp 5,d1
 bcs 2f
 cmp 8,d1
 bcc 9f
 movbu (cr_pbk),d1
 cmp 0,d1
 beq 9f
 mov d1,a0                        /* 6 5:4, 7 XPan, 8 21:9 */
 mov d0,d1
 exthu d1
 cmp 10931,d1
 beq 3f
 cmp 10930,d1
 bne 9f
 cmp 6,a0
 beq 9f
 mov a0,d1                        /* XPan 7 -> CR_IC0 + 4, 21:9 8 -> + 5 (the top bar's, drawn as 10930) */
 add -3,d1
 bra 8b
3:
 cmp 6,a0
 bne 9f
 mov 3,d1                         /* 5:4 -> CR_IC0 + 3 */
 bra 8b
2:                                /* the current value's label, asked through cr_gvl as 1:1 / 16:9 / 3:2 (top bar
                                   * 10934 / 10930 / 10932, SCP cell 5860 / 5859 / 5862) -> ours while 269 holds the
                                   * crop that borrows that slot (5 / 6 / 7); only on the shooting screens (GUI state
                                   * class below 5: playback shows a photo's own value through the same pictures) */
 movbu (cr_on),d1
 cmp 0,d1
 beq 9f
 mov (CR_GUI),a0
 cmp 0,a0
 beq 9f
 movbu (a0),d1
 cmp 5,d1
 bcc 9f
 cmp 3,d1
 beq 9f
 movbu (CR_A1),d1
 cmp 5,d1
 bcs 9f
 cmp 8,d1
 bcc 9f
 mov d1,a0                        /* the crop */
 mov d0,d1
 exthu d1
 cmp 10934,d1
 beq 5f
 cmp 10930,d1
 beq 6f
 cmp 10932,d1
 beq 7f
 cmp 5860,d1
 beq 51f
 cmp 5859,d1
 beq 61f
 cmp 5862,d1
 beq 71f
 bra 9f
5:
 cmp 5,a0
 bne 9f
 mov 3,d1
 bra 8b
6:
 cmp 6,a0
 bne 9f
 mov 4,d1
 bra 8b
7:
 cmp 7,a0
 bne 9f
 mov 5,d1
 bra 8b
51:
 cmp 5,a0
 bne 9f
 mov 6,d1
 bra 8b
61:
 cmp 6,a0
 bne 9f
 mov 7,d1
 bra 8b
71:
 cmp 7,a0
 bne 9f
 mov 8,d1
 bra 8b
9:
 mov d0,d1                        /* as ar_ic left it */
 exthu d1
 jmp ic_get
cr_str:                           /* st_get's frame, d0 = the id: a0 <- our UTF-16 string, ret [d2],8 as st_get */
 cmp CR_ST0,d0
 bcs 1f
 cmp CR_ST0 + 3,d0
 bcc 1f
 mov d0,d1
 add -CR_ST0,d1
 asl2 d1
 mov cr_strs,a0
 add d1,a0
 mov (a0),a0
 ret [d2],8
1:
 jmp cr_stk
 .balign 4
cr_strs:
 .long cr_s54, cr_sxp, cr_s219
cr_s54:
 .short 53, 58, 52, 0             /* "5:4" */
cr_sxp:
 .short 88, 80, 97, 110, 0        /* "XPan" */
cr_s219:
 .short 50, 49, 58, 57, 0         /* "21:9" */
 .balign 4
cr_ent:
 .long cr_d0, cr_d1, cr_d2, cr_d3, cr_d4, cr_d5, cr_d6, cr_d7, cr_d8
cr_d0:                            /* <6H3I> descriptors, filled by crop.py */
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d1:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d2:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d3:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d4:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d5:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d6:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d7:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_d8:
 .short 14, 0, 0, 8, 0, 0
 .long 0, 0, 0
cr_lst:                           /* the SCP strip's picture list (stock 0x615491c0, 5 x 12 B) + 3 entries */
 .space 8 * 12
cr_ml0:                           /* the three Image Aspect menu lists (stock 6 x 12 B) + 3 entries each */
 .space 9 * 12
cr_ml1:
 .space 9 * 12
cr_ml2:
 .space 9 * 12
 .balign 8
cr_pay:                           /* the picture streams (crop.py) */
 .space 12288
cr_pend:

/* The size text over the SCP strip ("5184x3888"): 0x6129fc29.. searches table 0x61600c10 (u16 ids 1,3,2,4,9, then 11
 * rows {u16 key, w[5], h[5]}); a ratio it does not know leaves the size unset (om-emu showed "36224x25159"). Our copy
 * with 8 columns (+ 5, 6, 7, filled by crop.py from the recorded-size lists), the function's constants changed to suit
 * (as the E-P7's v7 did for theirs). */
 .balign 4
cr_rtab:
 .space 16 + 11 * 34

/* The live view crop ratio (camera c1: live view showed no XPan strip). 0x60bf2cc8.. reads 269 (or the live view object's
 * +260) and picks the width : height pair through jump table 0x60e81df0 (index id - 1; 7:6 / 6:5 for ids 6 / 7), width
 * -> (24,sp), height at 0x60bf2d2b -> (28,sp) (= the E-P7's 0x60552d75 pair, their v5). */
cr_lr6:
 mov 65,d0
 mov d0,(24,sp)
 mov 24,d0
 jmp cr_lr_j
cr_lr7:
 mov 21,d0
 mov d0,(24,sp)
 mov 9,d0
 jmp cr_lr_j

/* The live view's own ratio (c5, camera-tested: the XPan / 21:9 strip). getOutputSize / getOutputSizeForFineZoom's
 * normal path asks ratioToConvertSize 0x60c0d30b (jump table 0x60e905b8 by id 0..10: 7:6 / 6:5 for 6 / 7) for w : h,
 * a1 -> the pair, the join 0x60c0d35f stores h at (4,a1) and retf (mdr untouched here); CapThr::
 * calculationOfDisplayAreaByAspect then fits it. */
cr_rc6:
 mov 65,d0
 mov d0,(a1)
 mov 24,d0
 jmp cr_rc_j
cr_rc7:
 mov 21,d0
 mov d0,(a1)
 mov 9,d0
 jmp cr_rc_j
/* getOutputAspect 0x60c14b28 (jump table 0x60e90efc by id 0..10): w -> (12,sp), h at the join 0x60c14b95 -> (16,sp) */
cr_oa6:
 mov 65,d0
 mov d0,(12,sp)
 mov 24,d0
 jmp cr_oa_j
cr_oa7:
 mov 21,d0
 mov d0,(12,sp)
 mov 9,d0
 jmp cr_oa_j

/* The debug log's CROP MODES line (cr_txt from lg_write): the tag cr_rst read and where it ran (#83: at start-up, or at
 * the first half-press), Image Aspect then, the value set, Image Aspect after, and now. */
 .balign 4
cr_dtg:
 .long 0
cr_das:
 .long 0
cr_dst:
 .long 0
cr_daf:
 .long 0
cr_npa:                           /* crop83-2: cr_chk's passes, the pass the base was first seen back (0 never), the tag */
 .long 0                          /* in memory then, the times set again, others' writes of 269 (count, last value), */
cr_rpa:                           /* cr_sin's patches of the live value */
 .long 0
cr_rtg:
 .long 0
cr_nre:
 .long 0
cr_own:
 .long 0
cr_owv:
 .long 0
cr_nsin:
 .long 0
cr_sra:                           /* crop83-3: cr_sinr's way back (0: none due), the result, the crop and base, put back */
 .long 0
cr_sir:
 .long 0
cr_nsr:
 .long 0
cr_nsb:                           /* crop83-3: saves through the buffer (after a menu), the tag the last save wrote */
 .long 0
cr_stg:
 .long 0
cr_sic:
 .byte 0
cr_sib:
 .byte 0
 .balign 2
cr_owt:                           /* the task of the last write of 269 by others; the GUI task */
 .hword 0xffff
cr_gtid:
 .hword 0xffff
cr_t1:
 .asciz "\r\n\r\nCROP MODES (crop round 15): tag "
cr_w0:
 .asciz " (not read yet)"
cr_w1:
 .asciz " at start-up"
cr_w2:
 .asciz " at the first half-press"
cr_t2:
 .asciz ", Image Aspect then "
cr_t3:
 .asciz ", set to "
cr_t4:
 .asciz ", after "
cr_t5:
 .asciz ", now "
cr_t6:                            /* round 2: the live view display set-up's id and picture area (0xa32dd210, 21a, 21c) */
 .asciz "; display "
cr_t7:
 .asciz ", "
cr_t8:
 .asciz " x "
cr_t14:
 .asciz "; screen specs mapped "
cr_t15:
 .asciz "; histogram area "
cr_t16:
 .asciz ", trimmed "
cr_t17:
 .asciz "; kept after start-up: checks "
cr_t18:
 .asciz ", base back at check "
cr_t19:
 .asciz " (tag in memory then "
cr_t20:
 .asciz "), set again "
cr_t21:
 .asciz "; others set Image Aspect "
cr_t22:
 .asciz " times (last "
cr_t23:
 .asciz ", task "
cr_t24:
 .asciz ", GUI task "
cr_t25:
 .asciz "); saves of M this power-on: from memory "
cr_t26:
 .asciz " (crop put back after "
cr_t27:
 .asciz "), after a menu "
cr_t28:
 .asciz ", last tag written "
cr_t29:
 .asciz "; frame lines set to the crop "
cr_t30:                           /* #97 */
 .asciz "; zoom reads given the base "
 .balign 2
cr_txt:                           /* `call cr_txt,[d2,d3,a2,a3],24` */
 LGS cr_t1
 mov (cr_dtg),d0
 call lg_h,[],0
 movbu (cr_dwh),d0
 mov cr_w0,a0
 cmp 1,d0
 bne 1f
 mov cr_w1,a0
1:
 cmp 2,d0
 bne 2f
 mov cr_w2,a0
2:
 call lg_s,[],0
 LGS cr_t2
 mov (cr_das),d0
 LGD
 LGS cr_t3
 mov (cr_dst),d0
 LGD
 LGS cr_t4
 mov (cr_daf),d0
 LGD
 LGS cr_t5
 movbu (CR_A1),d0
 LGD
 LGS cr_t6
 movbu (CR_DSP),d0
 LGD
 LGS cr_t7
 movhu (CR_DSP + 10),d0
 LGD
 LGS cr_t8
 movhu (CR_DSP + 12),d0
 LGD
 LGS cr_t14
 mov (cr_spn),d0
 LGD
 LGS cr_t15                       /* round 4: the histogram area asked (w x h), areas trimmed */
 mov (cr_hw),d0
 LGD
 LGS cr_t8
 mov (cr_hh),d0
 LGD
 LGS cr_t16
 mov (cr_hn),d0
 LGD
 LGS cr_t17                       /* crop83-2 */
 mov (cr_npa),d0
 LGD
 LGS cr_t18
 mov (cr_rpa),d0
 LGD
 LGS cr_t19
 mov (cr_rtg),d0
 call lg_h,[],0
 LGS cr_t20
 mov (cr_nre),d0
 LGD
 LGS cr_t21
 mov (cr_own),d0
 LGD
 LGS cr_t22
 mov (cr_owv),d0
 LGD
 LGS cr_t23
 movhu (cr_owt),d0
 LGD
 LGS cr_t24
 movhu (cr_gtid),d0
 LGD
 LGS cr_t25
 mov (cr_nsin),d0
 LGD
 LGS cr_t26                       /* crop83-3 */
 mov (cr_nsr),d0
 LGD
 LGS cr_t27
 mov (cr_nsb),d0
 LGD
 LGS cr_t28
 mov (cr_stg),d0
 call lg_h,[],0
 LGS cr_t29                       /* framelines-1 */
 mov (cr_nfr),d0
 LGD
 LGS cr_t30                       /* #97 */
 mov (cr_zn),d0
 LGD
 ret [d2,d3,a2,a3],24

/* ---- Grid lines inside the strip (crop round 2; camera c5: "the gridlines/guides do not match the framing"). The
 * shooting screen's grid reads 269 through cr_gv (a crop -> the ratio it sits in), so its lines are 16:9's (4:3's for
 * 5:4). With a crop set, the border preview's grid read (bl_gv, editor.s) also marks the grid value BL_C: the line
 * lookup misses it, and bl_tail copies the value's own lines (thirds, golden, 6x4) and jumps to cr_gx, which maps
 * them from the picture's place (the table's thirds record) into the crop's strip, centred in it (XPan / 21:9: full
 * width; 5:4: full height), and gives bl_tail the strip as the picture's place, so a Border's frame line sits inside
 * the strip too. Photo modes (mx_photo), stills grid (155 / 2047), after the first shutter event (cr_on). */
 .balign 4
cr_px:                            /* the picture's place (x0, y0, w, h) and the strip's (x0, y0, w, h) */
 .long 0
cr_py:
 .long 0
cr_pw:
 .long 0
cr_ph:
 .long 0
cr_sx:
 .long 0
cr_sy:
 .long 0
cr_sw:
 .long 0
cr_sh:
 .long 0

/* cr_gm: `call cr_gm,[d2,d3,a2,a3],28` from bl_gv (after its own work), a0 -> the grid value, a3 = bl_gv's mx_photo
 * (0: not the stills grid 155 / 2047, or not a photo mode): + BL_C when a crop is set and the value draws lines
 * (thirds 1, 6x4 5, golden 6, or a Border's value). */
cr_gm:
 movbu (cr_on),d0
 cmp 0,d0
 beq 9f
 movbu (CR_A1),d0
 cmp 5,d0
 bcs 9f
 cmp 8,d0
 bcc 9f
 mov a3,d0                        /* bl_gv's mx_photo */
 cmp 0,d0
 beq 9f
 mov a0,a2
 mov (a2),d0
 mov d0,d1
 and 0xffffff00,d1
 cmp BL_V,d1
 beq 2f                           /* a Border's value: its frame goes in the strip too */
 cmp 0,d1
 bne 9f
 cmp 1,d0
 beq 2f
 cmp 5,d0
 beq 2f
 cmp 6,d0
 bne 9f
2:
 or BL_C,d0
 mov d0,(a2)
9:
 ret [d2,d3,a2,a3],28

 .macro CRMAP off, p0, pn, s0, sn  /* the u16 at (\off,a0): from the picture's (\p0, \pn) to the strip's (\s0, \sn) */
 movhu (\off,a0),d0
 mov (\p0),d1
 sub d1,d0
 bcc 7771f
 clr d0                           /* (never left of / above the picture) */
7771:
 mov (\sn),d1
 mul d1,d0
 clr d1
 mov d1,mdr
 mov (\pn),d1
 divu d1,d0
 mov (\s0),d1
 add d1,d0
 movhu d0,(\off,a0)
 .endm

/* cr_gx <- jmp from bl_tail (its frame: no calls; it returns through the stack, so mdr is free): a2 = bl_r (5 + 3 line
 * rects {x0, y0, x1, y1}), a3 = bl_q (the picture's x0, x1, y0, y1). -> jmp bl_cgb with bl_q = the strip. */
cr_gx:
 movhu (0,a3),d0
 mov d0,(cr_px)
 movhu (2,a3),d1
 sub d0,d1
 mov d1,(cr_pw)
 movhu (4,a3),d0
 mov d0,(cr_py)
 movhu (6,a3),d3
 sub d0,d3
 mov d3,(cr_ph)
 movbu (CR_A1),d0
 cmp 5,d0
 bne 1f
 mov d3,(cr_sh)                   /* 5:4 in 4:3: full height, width h x 5 / 4 */
 mov d3,d0
 mov 5,d2
 mul d2,d0
 lsr 2,d0
 mov d0,(cr_sw)
 bra 3f
1:
 mov d1,(cr_sw)                   /* XPan / 21:9 in 16:9: full width, height w x 24 / 65 or w x 9 / 21 */
 mov d1,d2
 cmp 6,d0
 bne 2f
 mov 24,d0
 mov 65,d3
 bra 21f
2:
 mov 9,d0
 mov 21,d3
21:
 mul d2,d0
 clr d1
 mov d1,mdr
 divu d3,d0
 mov d0,(cr_sh)
3:
 mov (cr_sh),d0                   /* never larger than the picture */
 mov (cr_ph),d1
 cmp d1,d0
 bls 31f
 mov d1,(cr_sh)
31:
 mov (cr_sw),d0
 mov (cr_pw),d1
 cmp d1,d0
 bls 32f
 mov d1,(cr_sw)
32:
 mov (cr_pw),d0                   /* centred */
 mov (cr_sw),d1
 sub d1,d0
 lsr 1,d0
 mov (cr_px),d1
 add d1,d0
 mov d0,(cr_sx)
 mov (cr_ph),d0
 mov (cr_sh),d1
 sub d1,d0
 lsr 1,d0
 mov (cr_py),d1
 add d1,d0
 mov d0,(cr_sy)
 mov (cr_pw),d0
 cmp 0,d0
 beq 8f
 mov (cr_ph),d0
 cmp 0,d0
 beq 8f
 clr d3                           /* each line rect that is not empty */
4:
 mov a2,a0
 add d3,a0
 mov (a0),d0
 mov (4,a0),d1
 or d1,d0
 beq 7f
 CRMAP 0, cr_px, cr_pw, cr_sx, cr_sw
 CRMAP 2, cr_py, cr_ph, cr_sy, cr_sh
 CRMAP 4, cr_px, cr_pw, cr_sx, cr_sw
 CRMAP 6, cr_py, cr_ph, cr_sy, cr_sh
7:
 add 8,d3
 cmp 64,d3
 bcs 4b
8:
 mov (cr_sx),d0                   /* the strip -> bl_q */
 movhu d0,(0,a3)
 mov (cr_sw),d1
 add d1,d0
 movhu d0,(2,a3)
 mov (cr_sy),d0
 movhu d0,(4,a3)
 mov (cr_sh),d1
 add d1,d0
 movhu d0,(6,a3)
 jmp bl_cgb

/* ---- Crop round 3: the AF target (camera, round 2: still not drawn at XPan; camera, round 3: drawn and moved).
 * (A copy of the AF driver's live view pair at 0x60882acd was mapped too; the round 3 camera log showed it never ran,
 * so round 4 leaves it out.) */

/* (d) Round 3, the cause (pinned om-emu reproduces the camera): the GUI's screen spec builder (0x611cb1c4..) copies
 * Image Aspect (its facade read at 0x611cadba into the object's +1056) into the spec's ratio byte (+9, 0x611cb24d);
 * 0x611caf1d then picks the layout element from it (1, 2, 3, 4, 9 only; any other ratio keeps element 1), and the AF
 * target screen's layout search 0x61291206 looks up (element, ratio) in tables for ratios 1, 2, 3, 4, 9, 10: at XPan
 * (1, 6) found nothing, so no target and no area outline were drawn. cr_spec: a crop's ratio -> its base in the spec
 * (5 -> 1, 6 / 7 -> 3), after the first shutter event; the element and the layouts follow its base's. */
cr_spec:                          /* jmp from 0x611cb24d (a3 = the spec; d0 / a0 free) */
 mov (8,sp),a0                    /* the stock: mov (8,sp),a0; mov (a0),d0; movbu d0,(9,a3) */
 mov (a0),d0
 movbu d0,(9,a3)
 movbu (cr_on),d0
 cmp 0,d0
 beq 9f
 movbu (9,a3),d0
 cmp 5,d0
 bne 1f
 mov 1,d0
 bra 3f
1:
 cmp 6,d0
 beq 2f
 cmp 7,d0
 bne 9f
2:
 mov 3,d0
3:
 movbu d0,(9,a3)
 mov (cr_spn),d0
 inc d0
 mov d0,(cr_spn)
9:
 jmp cr_spec_back                 /* 0x611cb253 */
 .balign 4
cr_spn:                           /* specs mapped this power-on (the log) */
 .long 0
.section .hook_crg,"ax"
 jmp cr_spec                      /* stock 0x611cb24d: mov (8,sp),a0; mov (a0),d0; movbu d0,(9,a3) */
 .byte 0xcb
.section .ext12,"ax"

/* ---- Crop round 5: the live histogram (camera, round 3: at XPan "one tall spike at black above a low curve": the
 * dark bands above and below the strip counted; round 4's wrapper on 0x60c772c0 never ran: "histogram area 0 x 0").
 * The live histogram's area is handed to the display by Dev_HistogramFactory's Set_Histogram_CalcMode (0x60dc4bb1,
 * a method: entry `movm [d2,d3,a2,a3],(sp); add -256,sp`, d0 the mode, a1 -> the main area {x, y, w, h}, d1 -> the sub
 * area; it copies them for 0x6041847b). cr_dhm at its entry: the stock entry, then cr_trim on the main area, then the
 * stock body. cr_trim: with a crop set (after the first shutter event), an area larger than the crop is trimmed to
 * it, centred (XPan / 21:9: full width; 5:4: full height). Camera-only (om-emu does not run the live view). */
 .balign 4
cr_hw:                            /* the last main area asked (w, h), areas trimmed this power-on */
 .long 0
cr_hh:
 .long 0
cr_hn:
 .long 0
cr_dhm:                           /* jmp from 0x60dc4bb1 */
 movm [d2,d3,a2,a3],(sp)          /* the stock entry */
 add -256,sp
 cmp 0,a1
 beq 9f
 call cr_trim,[],0                /* d0, d1, a0, a1 kept (the method's inputs) */
9:
 jmp cr_dhm_back                  /* 0x60dc4bb7 */

cr_trim:                          /* `call cr_trim,[],0`, a1 -> {x, y, w, h} (u16); uses d2, d3, a2, mdr only */
 movhu (4,a1),d2
 mov d2,(cr_hw)
 movhu (6,a1),d2
 mov d2,(cr_hh)
 movbu (cr_on),d2
 cmp 0,d2
 beq 9f
 movbu (CR_A1),d3
 cmp 5,d3
 beq 5f
 cmp 6,d3
 beq 6f
 cmp 7,d3
 bne 9f
 mov 9,d2                         /* 21:9: h' = w x 9 / 21 */
 mov 21,a2
 bra 7f
6:
 mov 24,d2                        /* XPan: h' = w x 24 / 65 */
 mov 65,a2
7:
 movhu (4,a1),d3
 mul d2,d3
 clr d2
 mov d2,mdr
 mov a2,d2
 divu d2,d3                       /* d3 = h' */
 movhu (6,a1),d2                  /* h */
 cmp d2,d3
 bcc 9f                           /* not larger than the crop: as it is */
 movhu d3,(6,a1)
 sub d3,d2
 lsr 1,d2
 movhu (2,a1),d3
 add d2,d3
 movhu d3,(2,a1)                  /* y + (h - h') / 2 */
 bra 8f
5:
 movhu (6,a1),d3                  /* 5:4: w' = h x 5 / 4 */
 mov 5,d2
 mul d2,d3
 lsr 2,d3
 movhu (4,a1),d2
 cmp d2,d3
 bcc 9f
 movhu d3,(4,a1)
 sub d3,d2
 lsr 1,d2
 movhu (0,a1),d3
 add d2,d3
 movhu d3,(0,a1)                  /* x + (w - w') / 2 */
8:
 mov (cr_hn),d2
 inc d2
 mov d2,(cr_hn)
9:
 ret [],0
.section .hook_crh,"ax"
 jmp cr_dhm                       /* stock 0x60dc4bb1: movm [d2,d3,a2,a3],(sp); add -256,sp */
 .byte 0xcb
.section .ext12,"ax"

/* (Round 6's playback stack diagnosis found the label's widget path: 0x611509bc reads the photo info's ratio code
 * (+78) and shows entry code - 1 of the 5-entry list; research/NOTES.md. Removed in round 7.) */

/* ---- Crop round 7: the Border inside the crop (camera, round 6: "the borders get cropped off on the new crop
 * sizes"). bd_run (editor.s) paints the border on the finished buffer, which is the full 4:3 frame: the camera cuts the
 * photo it keeps out of it afterwards, so at any other ratio the border's top / bottom or sides fell outside.
 * 2026-11-18 (owner's camera, Border 5: the border cut off at 16:9, 3:2, 1:1 and 3:4, the camera's own ratios): the
 * same for every ratio, from one table by Image Aspect id (cr_bdt).
 * cr_bdc: `call cr_bdc,[d2,d3,a2,a3],28` from bd_run after its checks, d0 = W, a0 -> bd_run's locals ((8) P pairs,
 * (12) H, (16) pitch, (20) bus) -> d0 = the W to use (a0 kept). A ratio cut from the rows (3:2, 16:9, XPan, 21:9) keeps
 * the full width and Hc = ((W num + add) / (den << q)) << q rows, centred (y0 even); one cut from the sides (1:1, 5:4,
 * 3:4) keeps the full height and Wc = ((H num + add) / (den << q)) << q, centred; a buffer no larger is left as it is.
 * The width B then follows the crop's short side, as the live view frame line (round 2). The stock ratios' rounding
 * gives the camera's own photo sizes (0x606e60c0 / 0x606e6270) for every size of 4:3 frame they list (5184 x 3888:
 * 5184 x 3456, 5184 x 2920, 3888 x 3888, 2912 x 3888); 5:4, XPan and 21:9 as round 7. research/border/model.py
 * crop_area is the exact model. */
 .set CR_MR, 32                    /* 2026-11-18: the border goes this many rows / pairs past a crop's cut sides (as */
 .set CR_MP, 16                   /* far as the buffer goes): the camera cuts its 1600 px preview a few px wider */
 .balign 4
cr_mr:                            /* -> bd_run: rows past the cut top / bottom, pairs past the cut sides (0: no crop) */
 .long 0
cr_mp:
 .long 0
cr_bdt:                           /* by Image Aspect id 1..9: side (1 rows, 2 sides, 0 none), num, den, q; u16 add, 0 */
 .byte 0, 0, 0, 0
 .hword 0, 0                      /* 1 4:3 */
 .byte 1, 2, 3, 3
 .hword 23, 0                     /* 2 3:2: W 2 / 3 up to 8 */
 .byte 1, 9, 16, 3
 .hword 127, 0                    /* 3 16:9: W 9 / 16 up to 8 */
 .byte 2, 1, 1, 4
 .hword 0, 0                      /* 4 1:1: H down to 16 */
 .byte 2, 5, 4, 4
 .hword 32, 0                     /* 5 5:4: H 5 / 4 to the nearest 16 (round 7) */
 .byte 1, 24, 65, 4
 .hword 520, 0                    /* 6 XPan 65:24: W 24 / 65 to the nearest 16 (round 7) */
 .byte 1, 9, 21, 4
 .hword 168, 0                    /* 7 21:9: W 9 / 21 to the nearest 16 (round 7) */
 .byte 0, 0, 0, 0
 .hword 0, 0                      /* 8 7:5 (not offered) */
 .byte 2, 3, 4, 4
 .hword 32, 0                     /* 9 3:4: H 3 / 4 to the nearest 16 */
cr_bdc:
 clr d1
 mov d1,(cr_mr)
 mov d1,(cr_mp)
 mov a0,a3
 mov d0,a2                        /* W */
 movbu (CR_A1),d1
 add -1,d1
 cmp 9,d1
 bcc 9f                           /* not 1..9 */
 asl 3,d1
 mov cr_bdt,a0
 add d1,a0                        /* a0 -> the ratio's record */
 movbu (a0),d1                    /* side */
 cmp 0,d1
 beq 9f
 mov a2,d0                        /* rows: X = W */
 cmp 1,d1
 beq 1f
 mov (12,a3),d0                   /* sides: X = H */
1:
 movbu (1,a0),d1
 mul d1,d0                        /* X num */
 movhu (4,a0),d1
 add d1,d0                        /* + add */
 movbu (3,a0),d2                  /* q */
 movbu (2,a0),d1
 asl d2,d1                        /* den << q */
 clr d3
 mov d3,mdr
 divu d1,d0
 asl d2,d0                        /* Xc */
 movbu (a0),d1
 cmp 1,d1
 bne 5f
 mov (12,a3),d1                   /* H */
 cmp d1,d0
 bcc 9f
 mov d0,(12,a3)                   /* H = Hc */
 sub d0,d1
 lsr 1,d1
 and 0xfffffffe,d1                /* y0, even (the rows below: y0 or y0 + 1) */
 mov d1,d3                        /* rows past the cut: min(CR_MR, y0) */
 cmp CR_MR,d3
 bls 2f
 mov CR_MR,d3
2:
 mov d3,(cr_mr)
 mov (16,a3),d0
 mul d0,d1
 mov (20,a3),d0
 add d1,d0
 mov d0,(20,a3)                   /* bus + y0 pitch */
 bra 9f
5:
 mov a2,d1                        /* W */
 cmp d1,d0
 bcc 9f
 mov d0,a2                        /* W = Wc */
 sub d0,d1                        /* W - Wc = the left offset in bytes ((W - Wc) / 2 px, 2 bytes each) */
 mov d1,d3                        /* pairs past the cut: min(CR_MP, (W - Wc) / 4, the same on the right) */
 lsr 2,d3
 cmp CR_MP,d3
 bls 3f
 mov CR_MP,d3
3:
 mov d3,(cr_mp)
 mov (20,a3),d2
 add d1,d2
 mov d2,(20,a3)
 lsr 1,d0
 mov d0,(8,a3)                    /* P = Wc / 2 */
9:
 mov a2,d0
 mov a3,a0
 ret [d2,d3,a2,a3],28

/* ---- (Crop round 7's playback info diagnosis, cr_pbi at 0x6057fb1b, is removed: that hook sat in section 2 and jumped
 * into section 6's extension, and the camera boot-looped. research/NOTES.md "Crop round 7: the boot loop".) */

/* ---- Crop round 9c: the playback ratio label (2026-11-17). Playback sorts a photo by its shape into the five stock
 * ratios (the GUI's 0x61101381: w x 10000 / h against 8750 / 11667 / 14166 / 16389 -> codes 3, 5, 1, 2, else 4), so
 * XPan / 21:9 show 16:9's label (10930) and 5:4 4:3's (10931). Round 9 changed the camera's own values and 9b
 * patched the label elements to 8 states; both rebooted the camera in image review, 9b also for a plain 3:4 photo
 * (research/NOTES.md "Crop round 9b: the reboot"). Round 9c changes no stock value or layout: the single frame's info
 * build (CPlaySingleFrame::SimplePlayCommon, right after its 0x61101381 call at 0x61113417) notes the crop shape from
 * the photo's own w x h in cr_pbk (6 5:4, 7 XPan, 8 21:9, else 0), and cr_ic answers that label's picture request
 * with ours (the top bar's, drawn as 10930 / 10931) in playback. The widget asks the picture getter (0x610f5611,
 * our .hook_ic) at each draw and keeps no copy (0x610db0df: its 32 slots at +172 stay 0). The quality label stays
 * as stock (none for a crop). The hook is in section 7, the code in .ext12 (section 6, loaded before it). */
cr_pbk:
 .byte 0
 .balign 4
cr_pbsv:                          /* cr_pbk1: d0, d1; the label updates: d1 */
 .space 12
cr_pbk1:                          /* jmp from 0x6111341e (d0 = the stock code; a2 -> w, a3 -> h; d2 and a0 are set
                                     by the stock instructions next) */
 mov d0,(cr_pbsv)
 mov d1,(cr_pbsv + 4)
 clr d2
 movhu (a3),d1                    /* h */
 cmp 0,d1
 beq 8f
 mov d1,a0
 lsr 4,d1
 add a0,d1
 add a0,d1                        /* 2h + h/16 (2.0625) */
 movhu (a2),d0                    /* w */
 cmp d1,d0
 bls 4f
 mov a0,d1                        /* wide: XPan above 2h + h/2 + h/64 (2.5156), else 21:9 */
 lsr 6,d1
 add a0,d1
 add a0,d1
 mov a0,d2
 lsr 1,d2
 add d2,d1
 mov 7,d2
 cmp d1,d0
 bhi 8f
 mov 8,d2
 bra 8f
4:
 mov a0,d1                        /* 5:4: h + h/8 + h/32 + h/64 (1.1719) < w <= h + h/4 + h/32 + h/128 (1.2891) */
 lsr 3,d1
 add a0,d1
 mov a0,d2
 lsr 5,d2
 add d2,d1
 mov a0,d2
 lsr 6,d2
 add d2,d1
 clr d2
 cmp d1,d0
 bls 8f
 mov a0,d1
 lsr 2,d1
 add a0,d1
 mov a0,d2
 lsr 5,d2
 add d2,d1
 mov a0,d2
 lsr 7,d2
 add d2,d1
 clr d2
 cmp d1,d0
 bhi 8f
 mov 6,d2
8:
 movbu d2,(cr_pbk)
 add -8,sp                        /* #93: the photo's own film for its picture-mode label (playfilm.s pb_note); our */
 call pb_note,[d2,d3,a2,a3],24    /* own call slot below SimplePlayCommon's frame */
 add 8,sp
 mov (cr_pbsv),d0
 mov (cr_pbsv + 4),d1
 mov (2844,sp),d2                 /* the stock instructions */
 mov 78,a0
 jmp cr_pbk1_back                 /* 0x61113424 */
.section .hook_crk,"ax"
 jmp cr_pbk1                      /* stock 0x6111341e: mov (2844,sp),d2; mov 78,a0 */
 .byte 0xcb
.section .ext12,"ax"


/* ---- Crop round 10: the playback quality label (2026-11-17). The play component (Cmp_PlayComponentBase, section 6)
 * looks a photo's record mode up by its shape class and exact size (0x60c7c18a: {k, w, h, 0, code} per class); a
 * crop's size is in no table, so it gets 57, and the GUI's quality lookup (0x6110130d: file type d0, record mode d1
 * -> the quality picture code; SimplePlayCommon 0x611133cd -> item 197 + 260) has no entry for 57: no label. Round 9
 * changed 0x60c7c18a's result (and rebooted, most likely for its label elements). Round 10 changes no stock result:
 * cr_pqo only reads 0x60c7c18a's inputs and notes (cr_pqm / cr_pqw / cr_pqh) the code the crop's base size has (the
 * 16:9 entry of the same k and width for a wide crop, the 4:3 entry of the same k and height for a 5:4), and returns
 * into the stock function unchanged; cr_pqg gives SimplePlayCommon's quality lookup that code instead of 57 when the
 * photo's pictureSize is the noted one. Item 197 then holds the quality code a stock photo of the base size has. */
 .balign 4
cr_pqm:                           /* the base size's record mode for the last crop looked up (0: none) */
 .long 0
cr_pqw:
 .short 0
cr_pqh:
 .short 0
cr_pqsv:
 .space 12

cr_pqo:                           /* jmp from 0x60c7c18a ([d2,d3,a2,a3],20 frame, retf: mdr is the return, so no
                                     mul / div / call): d0 the mode, d1 the class (0 4:3, 1 16:9), a1 the compression,
                                     (24,sp) w, (28,sp) h. Reads only; d0 / d1 / a1 and the stack as they were. */
 mov d0,(cr_pqsv)
 mov d1,(cr_pqsv + 4)
 cmp 1,d0                         /* the modes the stock looks up */
 beq 1f
 cmp 5,d0
 bne 9f
1:
 movhu (28,sp),d3                 /* h */
 cmp 0,d3
 beq 8f
 movhu (24,sp),d2                 /* w */
 mov a1,d0                        /* k as the stock makes it: <= 3 0, <= 6 1, <= 8 2, else 3 */
 exthu d0
 mov 0,a3
 cmp 3,d0
 ble 2f
 mov 1,a3
 cmp 6,d0
 ble 2f
 mov 2,a3
 cmp 8,d0
 ble 2f
 mov 3,a3
2:
 cmp 1,d1
 bne 4f
 mov d3,d0                        /* 16:9 class: a wide crop when w > 2.0625 h */
 lsr 4,d0
 add d3,d0
 add d3,d0
 cmp d0,d2
 bls 8f
 mov 0x60ead1f8,a0                /* the 16:9 table (28): the entry of this k and width */
 mov 28,d1
3:
 movhu (a0),d0
 cmp a3,d0
 bne 31f
 movhu (2,a0),d0
 cmp d2,d0
 beq 7f
31:
 add 12,a0
 add -1,d1
 bne 3b
 bra 8f
4:
 cmp 0,d1
 bne 8f
 mov d3,d0                        /* 4:3 class: a 5:4 crop when w <= 1.28 h */
 lsr 5,d0
 add d3,d0
 mov d3,d1
 lsr 2,d1
 add d1,d0
 cmp d0,d2
 bhi 8f
 mov 0x60ead048,a0                /* the 4:3 table (36): the entry of this k and height */
 mov 36,d1
5:
 movhu (a0),d0
 cmp a3,d0
 bne 51f
 movhu (4,a0),d0
 cmp d3,d0
 beq 7f
51:
 add 12,a0
 add -1,d1
 bne 5b
 bra 8f
7:
 mov (8,a0),d0                    /* its code */
 mov d0,(cr_pqm)
 movhu d2,(cr_pqw)
 movhu d3,(cr_pqh)
 bra 9f
8:
 clr d0
 mov d0,(cr_pqm)
9:
 mov (cr_pqsv),d0
 mov (cr_pqsv + 4),d1
 mov d0,d3                        /* the stock instructions */
 mov 57,a3
 mov a3,(sp)
 jmp cr_pq_back                   /* 0x60c7c18f */
.section .hook_crq,"ax"
 jmp cr_pqo                       /* stock 0x60c7c18a: mov d0,d3; mov 57,a3; mov a3,(sp) */
.section .ext12,"ax"

cr_pqg:                           /* jmp from 0x611133cd (SimplePlayCommon: (1012,sp) the file type, (1016,sp) the
                                     record mode, (872,sp) / (874,sp) pictureSize; a0 / a1 free) */
 mov (1012,sp),d0                 /* the stock instructions */
 mov (1016,sp),d1
 cmp 57,d1                        /* the play component's miss */
 bne 9f
 mov d0,(cr_pqsv + 8)
 mov (cr_pqm),d0
 cmp 0,d0
 beq 8f
 movhu (872,sp),d0
 movhu (cr_pqw),d1
 cmp d1,d0
 bne 7f
 movhu (874,sp),d0
 movhu (cr_pqh),d1
 cmp d1,d0
 bne 7f
 mov (cr_pqm),d1                  /* the base size's record mode */
 bra 8f
7:
 mov 57,d1
8:
 mov (cr_pqsv + 8),d0
9:
 jmp cr_pqg_back                  /* 0x611133d5: call 0x6110130d */
.section .hook_crr,"ax"
 jmp cr_pqg                       /* stock 0x611133cd: mov (1012,sp),d0; mov (1016,sp),d1 */
 .byte 0xcb, 0xcb, 0xcb
.section .ext12,"ax"

/* ---- #97 (2026-11-20): Magnify in a crop, and the Image Aspect screen's sizes for 5:4 / XPan / 21:9.
 * (1) The live view's zoom (CapThr_ThroughImage, section 6) reads the ratio through its getAspectRatio 0x60c14644
 * (Image Aspect as it is: 6 at XPan; 10 / 1 / 3 in video and some scene modes) and turns it into a table row with a
 * compare chain for 1, 2, 3, 4, 9, 10 only. getZoomArea 0x60c15477 returns no area (0) for 5 / 6 / 7 and
 * adjustCoordinates 0x60c14581 reads the area's four limit bytes from address 0 without a check (om-emu, Magnify on
 * Delete at XPan: getZoomArea's miss 19 times per press); adjustZoomFrameLimitPos 0x60c13f91 takes 4:3's row. The two
 * getAspectRatio calls in those (hook_cz1 0x60c15483, hook_cz2 0x60c13f97) come here: the stock call, then cr_zm
 * gives the zoom tables the crop's base, 5:4 -> 4:3 (1), XPan / 21:9 -> 16:9 (3), as the AF target screen does
 * (cr_spec). getOutputSize / getOutputAspect / getTakeAreaSize, the other readers, keep the crop (round 1's cases).
 * Only in the zoom path (Magnify, MF assist); section 6 code into its own tail (ext6): no gate.
 * (2) The Image Aspect screen 0x611f9572 (Shooting Menu 1 > Image Aspect) shows the sizes of the ratio under its cursor
 * from 266-B records {u16 ratio, 11 UTF-16 sizes of 24 B} at 0x61577278, one each for 4:3, 16:9, 3:2, 1:1, 3:4: on 5:4 /
 * XPan / 21:9 nothing matched, so the sizes stayed the last ratio's and the row names (RAW, Large ...) went. hook_cz3
 * (0x611f965a, the loop's `add 0x61577278,a1`) hands the loop's first pass our record from the GUIDES.BIN code block
 * (xb_szr, made by crop.size_records from the camera's own size tables) for those three ratios; no block yet (before
 * the first half-press): the stock records, as before. Its name list is crop.py's (cr_ml0). */
 .set XB_SZO, 152                 /* xblock.s: the code block's word +152 = the offset of xb_szr */
.section .hook_cz1,"ax"
 jmp cr_za1                       /* stock 0x60c15483: call 0x60c14644,[d2],16 (getZoomArea) */
.section .hook_cz2,"ax"
 jmp cr_za2                       /* stock 0x60c13f97: call 0x60c14644,[d2],16 (adjustZoomFrameLimitPos) */
.section .hook_cz3,"ax"
 jmp cr_szr                       /* stock 0x611f965a: add 0x61577278,a1 */
 .byte 0xcb
.section .ext6,"ax"
cr_za1:
 call cr_gar,[d2],16              /* the stock call */
 call cr_zm,[],0
 jmp cr_za1_back                  /* 0x60c15488: mov d0,d2 */
cr_za2:
 call cr_gar,[d2],16
 call cr_zm,[],0
 jmp cr_za2_back                  /* 0x60c13f9c: mov d0,d2 */
cr_zm:                            /* d0 = the ratio -> the one the zoom tables have (d1 used: free after the call) */
 cmp 5,d0
 bne 1f
 mov 1,d0                         /* 5:4 -> 4:3 */
 bra 2f
1:
 cmp 6,d0
 bcs 9f
 cmp 8,d0
 bcc 9f
 mov 3,d0                         /* XPan / 21:9 -> 16:9 */
2:
 mov (cr_zn),d1
 inc d1
 mov d1,(cr_zn)
9:
 ret [],0
cr_szr:                           /* jmp from .hook_cz3, the frame of 0x611f9572: a1 = index x 266, d2 = the index,
                                   * (56,sp) = the ratio under the cursor; d0 / d1 / MDR free, a0 kept */
 cmp 0,d2
 bne 8f
 mov (56,sp),d0
 add -5,d0
 cmp 3,d0
 bcc 8f                           /* not 5:4 / XPan / 21:9 */
 mov d0,d1
 call xp,[],0                     /* a1 = the code block or 0 (uses d0, MDR) */
 beq 8f                           /* none: a1 = 0 = index x 266 */
 mov (XB_SZO,a1),d0               /* the block's +152: where its records are */
 add d0,a1
 mov 266,d0
 mul d1,d0
 add d0,a1                        /* our record (its ratio is the cursor's: the loop takes it) */
 jmp cr_szb
8:
 add cr_szt,a1                    /* the stock instruction */
 jmp cr_szb                       /* 0x611f9660 */
 .balign 4
cr_zn:                            /* zoom table reads given the crop's base (debug log) */
 .long 0
.section .ext12,"ax"
