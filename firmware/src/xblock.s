/* v0.24 film test 7 (owner): the Extras page is hidden and its Glow / Clarity and Art Effect read 0 wherever they act
 * (XB_FX 0); the code stays: set XB_FX 1 to bring them back. */
 .set XB_ART, 0                   /* v0.25 (owner): no Art Effect at all (Frame caused too many issues); 1 = Frame */
 .set XB_FX, 1                    /* ft5: Glow / Clarity / Art back on (grain by texture where the development allows) */
 .set XB_OWNOFF, 0                /* rc1: 1 = COLOR k's own Glow / Art Effect ignored (no rows then) */
 .set XB_LOG, 0                   /* v0.25: the fast-grain logger (GLOG.BIN) off */
 .set XB_SHG, 0                   /* film test 11's Shading check before the camera grain (1: on; rebooted on the camera) */
 .set XB_H0, 0                    /* v0.28 halation probe h0 (camera-tested 2026-11-12): off */
 .set XB_HL, 1                    /* v0.28: the Halation row (slot +30, 1..5) on our looks' stills (editor.s hl_run) */
/* Caduceus for OM-3 v0.20 test 5: the Extras code block (appended to GUIDES.BIN, our own code).
 *
 * Runs from its heap buffer (uncached pool, as the camera's malloc returns), relocated in place by entry 0. Linked at
 * XB_LINK; the build links it twice and lists every 32-bit field that moves (absolute: + delta, PC-relative to the
 * firmware: - delta). Entries are 8 bytes apart and reached from the firmware stubs with every register as the stub
 * documents. Slot entry S = P + 32 + 64k of the effective COLOR profile k+1: +49 Glow (-1..-5) / Clarity (+1..+5),
 * +50 Art Effect id (Caduceus: 1 Star Light, 2 Pin Hole, 4 White Edge, 5 Frame), +51 NR (1 Std, 2 Low, 3 Off), +52 VigFix (1: Shading Comp. reads Off).
 * Stores: the job flag word in the stock params / request (as the stock Art Effect code), own stack, the relocation
 * fields of this block (entry 0, once, before the block is published). No mul/div (MDR is the weight getter's return).
 */
 .am33_2
 .text
 .global _start
_start:
xb_base:
 jmp xb_reloc                     /* +0  relocate (called once by x_load: `calls`) */
 .balign 8
 jmp xb_cap                       /* +8  capture flags (s_cap) */
 .balign 8
 jmp xb_lv                        /* +16 live-view / movie request flags (s_lv) */
 .balign 8
 jmp xb_wt                        /* +24 Soft Focus weight (s_wt) */
 .balign 8
 jmp xb_nr                        /* +32 stills Noise Filter / Shading Comp. read (s_nr) */
 .balign 8
 jmp xb_kad                       /* +40 editor ALL state read (k_ad) */
 .balign 8
 jmp xb_vl                        /* +48 dial label of the Extras slice (vl_s) */
 .balign 8
 jmp xb_gs                        /* +56 grain, CPU route: Soft Focus blend setup wrapper (g_sf) */
 .balign 8
 jmp xb_dev                       /* +64 grain, camera route: request configuration (s_cl) */
 .balign 8
 jmp xb_lw                        /* +72 after each half-press save (ub_save, `calls`): fg1 writes GLOG.BIN */
 .balign 8
 jmp xb_lkd                       /* +80 the '*' with a look selected (lk_pm, `calls`; calls the firmware: uncached) */
 .balign 8
 jmp xb_lkh                       /* +88 OK held on the Looks page (lk_hold, jmp in ed_event's frame) */
 .balign 8
 jmp xb_cvc                       /* +96 count of a cell's dial list (pf_cnt, `calls`) */
 .balign 8
 jmp xb_vbc                       /* +104 value by index of a cell (pf_vbi, `calls`) */
 .balign 8
 jmp xb_su                        /* +112 ft1: after the still set-up (xs_su, `calls`, a0 = S): grain texture */
 .balign 8
 jmp xb_sel2                      /* +120 ft3: the combiner set-up's own selector call (s_sel2, frame [d2,a2],12) */
 .balign 8
 jmp xb_c1e                       /* +128 ft4: end of combiner 1's set-up (s_c1e, `calls`, a2 = register image) */
 .balign 8
 jmp xb_wl                        /* +136 ft8: the still's work list key (s_wl, `calls`, a0 = job) -> d0 key or 0 */
 .balign 8
 jmp xb_wbc                       /* +144 v0.25: the WB grid row's left cell picture (wb_draw, `calls`) */
 .balign 8
xb_nrel:
 .long 0                          /* relocation count (written by the build) */

/* xb_slot: `call xb_slot,[d2,d3],12` -> a1 = slot entry S of the effective COLOR1..4 profile, or 0. Uses d0, d1, a0. */
xb_slot:
 mov 63153,d0
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 add -1,d0
 cmp 4,d0
 bcc 9f
 mov d0,d2
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
 asl 6,d2
 add d2,a1
 add 32,a1
 ret [d2,d3],12
9:
 mov 0,a1
 ret [d2,d3],12

 .macro ARTB reg                  /* \reg = this look's Art Effect (S+50), 0 without XB_ART */
 .if XB_ART
 movbu (50,a1),\reg
 .else
 clr \reg
 .endif
 .endm
/* xb_art: d1 |= the job flags of S's Art Effect (a1 = S). Uses d0, a0; returns through MDR. */
xb_art:
 .if XB_FX
 ARTB d0
 .else
 clr d0
 .endif
 cmp 5,d0                         /* v0.25: Frame only (owner: Star Light slow, Pin Hole / White Edge = Shading) */
 bne 1f
 add d0,d0
 mov xb_ft,a0
 movhu (d0,a0),d0
 or d0,d1
1:
 retf [],0

/* capture (Art Effect -> flag converter 0x60555e47): a3 = capture, a2 = params+12 (flags), (-4,a2) = key.
 * Exit as stock: fx_back with d0 = the Art Effect id and a1 = its address, or fx_tail. */
xb_cap:
 .if XB_LOG
 call xb_mark,[d2,d3,a2,a3],20    /* fg1 log: a new slot for this capture */
 .endif
 clr d0
 movbu d0,(xb_ownf)
 clr d0
 movbu d0,(xb_gt)                 /* no camera grain unless a plain COLOR look with Grain below */
 mov 38225,a1
 add a3,a1
 movbu (a1),d0
 cmp 0,d0
 bne 8f                           /* the camera's own Art Effect: stock */
 mov (-4,a2),d0
 cmp 0x000b0000,d0                /* key bytes 0, 0, halfword 11: COLOR */
 bne 7f
 call xb_slot,[d2,d3],12
 cmp 0,a1
 beq 7f
 mov (a2),d1                      /* (data registers only: `movbu (d8,An),Am` misread on the camera) */
 .if XB_FX
 call xb_own,[],0                 /* v0.25: COLOR k's own Glow / Art Effect (no film) are not used: no row for them */
 movbu d0,(xb_ownf)
 cmp 0,d0
 bne 5f
 movbu (49,a1),d0
 .else
 clr d0
 .endif
 cmp 0,d0
 bne 2f                           /* Glow / Clarity: the Soft Focus passes (+ CPU grain if Grain) */
 .if XB_HL
 movbu (30,a1),d0                 /* v0.28: the Halation row alone -> the Soft Focus passes too (xb_wt: w 1024, no glow) */
 extb d0
 cmp 0,d0
 bgt 2f
 .endif
 .if XB_FX
 ARTB d0
 .else
 clr d0
 .endif
 cmp 0,d0
 bne 3f                           /* an Art Effect */
5:
 movbu (53,a1),d0                 /* plain: Grain 0..3 -> the camera's own grain (xb_dev) */
 cmp 0,d0
 beq 1f
 .if XB_SHG                        /* v0.24 camera (owner): High grain rebooted the camera; the likely cause is the
                                   * stock settings getter (AGET) called from the capture pipeline here: off */
 add -12,sp                       /* film test 11 (owner, camera): with Shading on, the camera's grain (its MONO route)
 mov d1,(4,sp)                     * made the picture monochrome -> then the CPU grain, as with an Art Effect */
 mov a1,(8,sp)
 mov 63153,d0                     /* the effective COLOR profile 1..4 (xb_slot found it) */
 clr d1
 mov 0,a0
 call getter,[d2,d3],12
 extbu d0
 add 911,d0                       /* its Shading: setting 912 + k */
 call AGET,[],4
 mov (4,sp),d1
 mov (8,sp),a1
 add 12,sp
 extb d0
 cmp 0,d0
 bne 2f
 .endif
 movbu (53,a1),d0
 cmp 3,d0
 bls 4f
 mov 3,d0
4:
 movbu d0,(xb_gt)
 bra 1f
3:
 movbu (53,a1),d0                 /* Art Effect + Grain: the Soft Focus passes for the CPU grain (w 1024), */
 cmp 0,d0
 beq 1f
 bra 1f                           /* ft8: Art Effects take the texture (Grainy Film's list) */
2:
 or 128,d1
1:
 movbu (xb_ownf),d0               /* v0.25: no Art Effect flags from COLOR k's own settings */
 cmp 0,d0
 bne 6f
 call xb_art,[],0
6:
 mov d1,(a2)
 jmp fx_tail
7:
 clr d0
8:
 jmp fx_back

/* live view / movie (record -> development request 0x6046b86c, COLOR, the stock Art Effect gates passed):
 * a2 = request (+12 flags), a3 = record+248, d3 live. Glow only (Clarity is invisible on combiner 12, as Caduceus). */
xb_lv:
 call xb_slot,[d2,d3],12
 cmp 0,a1
 beq 9f
 mov (12,a2),d1
 .if XB_FX
 call xb_own,[],0                 /* v0.25: COLOR k's own Glow / Art Effect are not used (no film) */
 cmp 0,d0
 bne 9f
 movbu (49,a1),d0
 .else
 clr d0
 .endif
 btst 0x80,d0
 beq 1f
 or 128,d1
1:
 call xb_art,[],0
 mov d1,(12,a2)
9:
 jmp lv_skip

/* Soft Focus weight (getter 0x605048c1, entered `call ...,[],0`): MDR = return (0x60504edb combiner 11, stills;
 * 0x60504f23 combiner 12), a0 = context, key 11 checked. d0 = w (Q10 weight of the sharp input); stock key 11: 600. */
xb_wt:
 mov mdr,d1
 add -8,sp
 mov d1,(4,sp)
 call xb_slot,[d2,d3],12
 mov 600,d0
 cmp 0,a1
 beq 8f
 .if XB_FX
 movbu (49,a1),d1
 .else
 clr d1
 .endif
 extb d1
 cmp 0,d1
 bne 1f
 mov 1024,d0                      /* no Glow / Clarity (Grain or v0.28 Halation alone): w 1024, the sharp image unchanged */
 bra 8f
1:
 blt 5f
 cmp 6,d1                         /* Clarity 1..5 */
 bcc 8f
 mov 1024,d0                      /* combiner 12 (live view classes): no negative gain */
 mov (4,sp),a0
 cmp c11_ret,a0
 bne 8f
 add -1,d1
 add d1,d1
 mov xb_cl,a0
 movhu (d1,a0),d0
 bra 8f
5:
 clr d0
 sub d1,d0                        /* Glow 1..5 */
 cmp 6,d0
 bcc 7f
 add -1,d0
 add d0,d0
 mov xb_gl,a0
 movhu (d0,a0),d0
 bra 8f
7:
 mov 600,d0
8:
 mov (4,sp),d1
 add 8,sp
 mov d1,mdr
 retf [],0

/* property reads (s_nr): the site's `call getter,[d2,d3],12` frame, d0 key, d1, a0 as for the getter. v0.22: key
 * 0x8119 (Sharpness, the capture read): the COLOR slot's Sharp (slot +54, -5..+2) after the real read, -5 sent as -7
 * (fully off for any picture-key class). Key 0x9719
 * (stills Noise Filter; capture and Exif sites): NR 1..4 -> the real read, then d0 = 0 Standard / -1 Low / -2 Off /
 * +1 High.
 * Key 0x8c21 (Shading Comp., sid 61; capture and lens-request sites, v0.21): VigFix 1 -> the real read, then d0 = 0
 * (Off, a stock value). Otherwise the getter as stock. */
xb_nr:
 mov d1,d2
 mov a0,d3
 add -8,sp                        /* (0) call slot, (4) the key */
 mov d0,(4,sp)
 call xb_slot,[d2,d3],12
 mov (4,sp),d1                    /* d1 = key */
 add 8,sp
 cmp 0,a1
 beq 9f
 cmp 33049,d1                     /* v0.22 key 0x8119 Sharpness (capture): slot +54 Sharp -5..+2 */
 bne 4f
 movbu (54,a1),d0
 extb d0
 cmp 2,d0
 ble 3f
 mov 2,d0
3:
 cmp -5,d0
 bgt 6f
 mov -7,d0                        /* -5 = Off: below every class base, so the gain index is 0 */
 bra 6f
4:
 cmp 38681,d1
 bne 5f
 movbu (51,a1),d0                 /* NR 1..4 */
 add -1,d0
 cmp 4,d0
 bcc 9f
 mov xb_nm,a1
 movbu (d0,a1),d0
 extb d0
 bra 6f
5:
 movbu (52,a1),d0                 /* v0.21 VigFix 1: Shading Comp. reads 0 (Off) */
 cmp 1,d0
 bne 9f
 clr d0
6:
 mov d1,a1                        /* key */
 mov d2,d1
 mov d3,a0
 mov d0,d2                        /* the value to return */
 mov a1,d0
 call getter,[d2,d3],12
 mov d2,d0
 ret [d2,d3],12
9:
 mov d1,d0
 mov d2,d1
 mov d3,a0
 jmp getter

/* editor ALL state (k_ad, `call k_ad,[a2],8` frame, a stub jump): (24,sp) <- GetValue(2201 + k), and when that is not
 * 255, GetValue(2197 + k); (20,sp) = 2197 + k. As k_cur: keeps d2/d3/a3, returns through the frame. */
xb_kad:
 call facade,[],4
 mov (a0),a2
 mov (12,a2),a2
 mov sp,a1
 add 24,a1
 clr d0
 mov d0,(a1)
 mov (20,sp),d0
 add 4,d0
 calls (a2)
 mov (24,sp),d0
 cmp 255,d0
 beq 9f
 call facade,[],4
 mov (a0),a2
 mov (12,a2),a2
 mov sp,a1
 add 24,a1
 mov (20,sp),d0
 calls (a2)
9:
 ret [a2],8

/* ---- grain (v0.21 grain test 3; diagnostics gd1-gd4 measured on the camera, see om3/NOTES.md). The Soft Focus blend setup 0x604be2aa returns with its output, the new
 * buffer 0x1000 (YCbYCr 4:2:2, Y in the even bytes, 2 B/px, rows memHw x 2 B apart), complete in memory (camera
 * probe g2: a pattern written there after the setup is in the JPEG). On a COLOR1-4 still whose look has Grain 1..3
 * (slot +53), every Y byte becomes T[Y][h]: h a 31-level noise row (xb_p1: xorshift32, triangular, vertical IIR,
 * horizontal pair), T = clamp(Y + (((64 h - 945) G[Y] S + 2^17) >> 18)) with G midtone-weighted and S from xb_gstab.
 * The image is reached through this CPU's bus window, one row at a time under the firmware's lock (xb_open), and
 * the cache is flushed at the end. Work buffers: T (8192 B) and V + H (one row each), freed again.
 * grain/model.py is the same computation in Python. Stores: the image's Y bytes, the work buffer, xb_seed. */
xb_p:                             /* leaf: a1 = P or 0. Uses d0 */
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
 retf [],0
9:
 mov 0,a1
 retf [],0

xb_open:                          /* `call xb_open,[d2,d3,a2,a3],28`, d0 = bus address, d1 = length -> a0 = CPU address or 0,
                                     d0 = lock token (the lock is held: close it with xb_close), d1 = 1 window / 0.
                                     Bus 0xa0000000..0xb7ffffff is the DRAM the CPU sees uncached at the same address;
                                     anything else from 0x08000000 goes through this CPU's bus window (the firmware's
                                     own mapper, under the firmware's lock: no task switch, interrupts masked) when the
                                     d1 bytes stay inside the window's 128 MB. */
 mov d0,a3
 mov d1,d3
 clr d0
 call LOCK,[d2],8
 mov d0,a2                        /* token */
 clr d2
 mov a3,d0
 cmp 0x08000000,d0
 bcs 7f
 cmp 0xa0000000,d0
 bcs 3f
 cmp 0xb8000000,d0
 bcc 3f
 mov a3,a0                        /* main DRAM: direct */
 bra 8f
3:
 and 0x07ffffff,d0
 add d3,d0
 cmp 0x08000001,d0
 bcc 7f
 mov (0x8050),d1                  /* this CPU's window register: 0x98100058 + 0x400 cpu (cpu 3: + 0x1000) */
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
 mov a3,d0                        /* already ours (and nothing else runs here while the lock is held) */
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

xb_close:                         /* `call xb_close,[d2],8`, d0 = token */
 call UNLOCK,[d2],8
 ret [d2],8

xb_rec:                           /* `call xb_rec,[d2,d3],12`, a0 = job -> a1 = record of buffer 0x1000, or 0 */
 mov a0,d3
 mov 4096,d0
 call BUFIDX,[d2,d3],8
 exthu d0
 cmp 48,d0
 bcc 9f
 mov d0,d1
 asl 3,d1                         /* 8 i */
 mov d1,d2
 asl 2,d2                         /* 32 i */
 add d2,d1                        /* 40 i */
 asl 1,d2                         /* 64 i */
 add d2,d1                        /* 104 i */
 mov d3,a0
 mov (10276,a0),a1
 add d1,a1
 ret [d2,d3],12
9:
 mov 0,a1
 ret [d2,d3],12


 .set P_DIRTY, 685
 .set P_LPTR, 708
xb_gs:                            /* `calls` (0,sp) = return, a0 = job */
 movm [d2,d3,a2,a3],(sp)
 add -20,sp                       /* (0) call slot, (4) job, (8) level, (12) result, (16) halation 0..5 */
 mov a0,(4,sp)
 clr d0
 mov d0,(16,sp)
 call xb_slot,[d2,d3],12
 cmp 0,a1
 beq 90f
 .if XB_HL
 movbu (30,a1),d0                 /* v0.28: the Halation row 1..5 (slot +30; 0 and below: none) */
 extb d0
 cmp 0,d0
 ble 6f
 cmp 5,d0
 bls 7f
 mov 5,d0
7:
 mov d0,(16,sp)
6:
 .endif
 movbu (53,a1),d0                 /* Grain 1..3 (older 4, 5 -> 3) */
 cmp 0,d0
 beq 91f
 movbu (xb_tx),d1                 /* ft7: this still has a texture (development or conversion pass): no CPU grain */
 cmp 0,d1
 bne 91f
 cmp 3,d0
 bls 10f
 mov 3,d0
 bra 10f
91:                               /* no CPU grain on one of our looks */
 .if XB_H0
 clr d0                           /* h0: still the setup, then the probe (level 0 = no grain) */
 bra 10f
 .endif
 .if XB_HL
 mov (16,sp),d1                   /* h1: halation -> the setup, then the pass (level 0 = no CPU grain) */
 cmp 0,d1
 beq 90f
 clr d0
 bra 10f
 .endif
90:                               /* no grain: the stock setup, as if called directly */
 mov (4,sp),a0
 add 20,sp
 movm (sp),[d2,d3,a2,a3]
 jmp SF_ENT
10:
 mov d0,(8,sp)
 mov (4,sp),a0
 mov SF_ENT,a1
 calls (a1)
 mov d0,(12,sp)
 cmp 0,d0
 bne 20f
 mov (4,sp),a0
 call xb_rec,[d2,d3],12
 cmp 0,a1
 beq 20f
 .if XB_HL
 mov (16,sp),d0                   /* h1: halation first, so grain sits over the glow */
 cmp 0,d0
 beq 14f
 mov a1,(12,sp)
 mov a1,a0
 call HL_RUN,[d2,d3,a2,a3],124
 mov (4,sp),a0
 call xb_rec,[d2,d3],12
 clr d0
 mov d0,(12,sp)                   /* the setup's result was 0 to get here */
 cmp 0,a1
 beq 20f
14:
 .endif
 mov (8,sp),d0
 cmp 0,d0
 beq 15f
 mov a1,a0
 call xb_grain,[d2,d3,a2,a3],128
15:
 .if XB_H0
 mov (4,sp),a0
 call xb_rec,[d2,d3],12
 cmp 0,a1
 beq 20f
 mov a1,a0
 call xb_h0,[d2,d3,a2,a3],48
 .endif
20:
 mov (12,sp),d0
 ret [d2,d3,a2,a3],36

 .if XB_H0
/* xb_h0 (v0.28 halation probe h0, experiment): which odd byte of buffer 0x1000 is Cb and which Cr, and whether chroma
 * is offset-binary. Rows 0..H0_ROWS-1: in the left half every pixel pair's byte 1 = H0_VAL, in the right half every
 * pair's byte 3 = H0_VAL (pair = Y0 C0 Y1 C1; 128 = neutral if offset-binary). Expected if C0 = Cb, C1 = Cr (the E-P7's
 * camera result): left band blue, right band red / magenta. Swapped: left red, right blue. Two's complement: strong
 * opposite colours (yellow / green). Rows are written through the uncached view xb_open returns (no cache lines to
 * write back); a row across the window's edge is left as it is.
 * `call xb_h0,[d2,d3,a2,a3],48` (32 B of locals), a0 = record. Locals (0) call slot, (4) rec, (8) row, (12) pitch, (16) bus,
 * (20) pairs, (24) rows, (28) token. */
 .set H0_ROWS, 256
 .set H0_VAL, 168
xb_h0:
 mov a0,(4,sp)
 movhu (16,a0),d0                 /* format 0x0c02 only (as xb_grain) */
 cmp 0x0c02,d0
 bne 99f
 mov (4,a0),d0
 cmp 0,d0
 bne 99f
 movhu (20,a0),d0                 /* Hw: 8 .. 8192, a multiple of 4 */
 cmp 8,d0
 bcs 99f
 cmp 8193,d0
 bcc 99f
 btst 3,d0
 bne 99f
 movhu (18,a0),d1                 /* memHw >= Hw */
 cmp d0,d1
 bcs 99f
 add d1,d1
 mov d1,(12,sp)                   /* pitch in bytes */
 lsr 1,d0
 mov d0,(20,sp)                   /* pairs per row */
 movhu (22,a0),d1                 /* rows: min(Vw, H0_ROWS) */
 cmp 0,d1
 beq 99f
 cmp H0_ROWS,d1
 bls 1f
 mov H0_ROWS,d1
1:
 mov d1,(24,sp)
 mov (a0),d0
 mov d0,(16,sp)
 clr d0
 mov d0,(8,sp)
2:                                /* each row */
 mov (8,sp),d0
 mov (12,sp),d1
 mul d1,d0
 mov (16,sp),d1
 add d1,d0                        /* its bus address */
 mov (20,sp),d1
 asl2 d1                          /* its length: 4 B a pair */
 call xb_open,[d2,d3,a2,a3],28
 mov d0,(28,sp)
 cmp 0,a0
 beq 5f
 mov (20,sp),d2                   /* pairs */
 mov d2,d3
 lsr 1,d3                         /* left half: byte 1 */
 sub d3,d2                        /* right half: byte 3 */
 mov H0_VAL,d1
 cmp 0,d3
 beq 4f
3:
 movbu d1,(1,a0)
 add 4,a0
 add -1,d3
 bne 3b
4:
 cmp 0,d2
 beq 5f
6:
 movbu d1,(3,a0)
 add 4,a0
 add -1,d2
 bne 6b
5:
 mov (28,sp),d0
 call xb_close,[d2],8
 mov (8,sp),d0
 inc d0
 mov d0,(8,sp)
 mov (24,sp),d1
 cmp d1,d0
 bcs 2b
99:
 ret [d2,d3,a2,a3],48
 .endif

/* xb_dev (grain, camera route): s_cl jumps here in the frame of `call s_cl,[d2,a2],12` at 0x604955f1, a0 = context.
 * The development request of a plain COLOR still (kind 0, output 0x1000, key 11) with xb_gt = Grain 1..3 gets the
 * MONO key (request +10 and context +48 = 12) and the camera's grain level (+1751): the image processor then adds its
 * own film grain on the direct-to-JPEG route, colour kept (combiner 33 is not used). Then the stock selector.
 * Uses d0, d1, a1. */
xb_dev:
 movbu (xb_tx),d0                 /* ft1: 1 = a texture is ready for this still, 2 = attached to xb_rq,
                                     ft7: 3 = waiting for the conversion pass (the development has its own effect) */
 cmp 0,d0
 beq 5f
 mov (4,a0),a1
 cmp 0,a1
 beq 9f
 cmp 2,d0
 bne 1f
 mov (xb_rq),d1                   /* attached: the same request configured again -> combiner 1 again */
 cmp a1,d1
 bne 9f
 movbu (10,a1),d1                 /* rj1: only while it is still a COLOR request (the state now outlives other jobs) */
 cmp 11,d1
 bne 9f
 bra 3f
1:
 movhu (14,a1),d1
 cmp 0x1000,d1
 bne 9f
 movbu (16,a1),d1
 cmp 0,d1
 bne 2f
 movbu (10,a1),d1                 /* kind 0: the COLOR development */
 cmp 11,d1
 bne 9f
 movhu (1756,a1),d1               /* ft5: without its own effect: the texture here */
 cmp 0,d1
 bne 9f
 movbu (xb_tart),d1               /* ft8b: Frame only on Grainy Film's list (on COLOR's it restarted the camera) */
 cmp 5,d1
 bne 4f
 movbu (xb_sw),d1
 cmp 0,d1
 bne 4f
 bra 9f                           /* ft8: its own effect in the development (ft7's conversion-pass texture hung) */
2:
 bra 9f
4:
 mov 2,d0
 movbu d0,(xb_tx)
 mov a1,(xb_rq)
 clr d0
 movbu d0,(xb_gt)                 /* ft2: never the MONO key for this still */
 mov a0,a2                        /* (d2 / a2 are the s_cl frame's: free here) */
 mov a3,d2
 mov (xb_S),a0                    /* the stock hook 0x604bc0cf: a0 = S, a1 = request -> kind 0: +780, kind 3: +96;
                                     +12 = 0x0100 */
 mov TXATT,a3
 calls (a3)
 mov d2,a3
 mov a2,a0
 movbu (xb_k3),d0                 /* ft7: a conversion pass keeps its stage */
 cmp 0,d0
 beq 3f
 clr d0
 movbu d0,(xb_k3)
 mov (xb_rq),a1
 mov 0xf005,d0
 movhu d0,(12,a1)
3:
 mov 1,d0                         /* ft3: key stays 11; xb_lg answers combiner 1 instead of the selector */
 movbu d0,(xb_ck)
 jmp xb_lg
5:
 movbu (xb_gt),d0
 cmp 0,d0
 beq 9f
 mov (4,a0),a1
 cmp 0,a1
 beq 9f
 movbu (16,a1),d1
 cmp 0,d1
 bne 9f
 movhu (14,a1),d1
 cmp 0x1000,d1
 bne 9f
 movbu (10,a1),d1
 cmp 11,d1
 bne 9f
 movbu d0,(1751,a1)
 mov 12,d1
 movbu d1,(10,a1)
 mov d1,(48,a0)
9:
 jmp xb_lg                        /* fg1: the stock selector, then the log */

/* xb_su (ft1): `calls` from xs_su after the still set-up, a0 = S (S+4 the still's parameters, S+10276 the job,
 * S+10280 the resource manager). A COLOR still (job+5352 = 11) whose COLOR profile has Grain gets the texture object
 * Grainy Film gets (0x604cd921 with the same 6-byte block as 0x604b99c6..0x604b99f5, the same gate as 0x604b998b),
 * stored at job+8324 (released by the stock clean-up 0x604b9cd9); xb_dev then attaches it to the development. */
xb_su:
 movm [d2,d3,a2,a3],(sp)
 add -4,sp
 mov (10276,a0),a1                /* rj1 (2026-11-09): only a COLOR job touches the grain state. A RAW+JPEG shot runs
                                     a second job (key 2, 3200 x 2400: the RAW's preview, camera log lg1) whose set-up
                                     cleared xb_tx / moved xb_S while the JPEG's textured job was still running */
 cmp 0,a1
 beq 1f
 mov (5352,a1),d0
 cmp 11,d0
 bne 1f
 mov a0,(xb_S)
 clr d0
 movbu d0,(xb_tx)
 call xb_tex,[d2,d3,a2,a3],32     /* a0 = S */
1:
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 rets

/* xb_tex (ft8b): `call xb_tex,[d2,d3,a2,a3],32`, a0 = S. A COLOR still with Grain (no Glow / Clarity): the texture
 * object at job+8324 (made here, or already by xb_wl) -> xb_tx = 1, xb_tl = Grain, xb_art = Art Effect. */
xb_tex:
 mov a0,a2
 mov (10276,a2),a1
 cmp 0,a1
 beq 9f
 mov (5352,a1),d0
 cmp 11,d0                        /* COLOR */
 bne 9f
 mov (8324,a1),d0
 cmp 0,d0
 beq 2f
 mov 1,d0                         /* made already (xb_wl, before the set-up) */
 movbu d0,(xb_tx)
 bra 9f
2:
 call xb_slot,[d2,d3],12
 cmp 0,a1
 beq 9f
 movbu (53,a1),d0                 /* Grain 1..3 */
 cmp 0,d0
 beq 9f
 movbu (49,a1),d1                 /* rc2c: Glow / Clarity AND Frame with Grain: the camera wrote no picture (owner,
                                     PB081509..511): no texture there -> the CPU grain (slower), as v0.22 */
 cmp 0,d1
 beq 3f
 ARTB d1
 cmp 5,d1
 beq 9f
3:
 movbu d0,(xb_tl)                 /* ft9: Glow / Clarity too (Grainy Film's list) */
 ARTB d1
 movbu d1,(xb_tart)
 mov a2,a3
 add 4,a3                         /* the still's parameters */
 movhu (40,a3),d3
 mov d3,d0
 and 0xf0,d0
 cmp 16,d0
 beq 9f
 cmp 32,d0
 beq 9f
 cmp 64,d0
 beq 9f
 mov d3,d1
 and 0xf00,d1
 cmp 0x100,d1
 beq 9f
 cmp 48,d0
 bne 1f
 mov d3,d1
 and 15,d1
 cmp 0,d1
 beq 9f
 cmp 1,d1
 beq 9f
1:
 movhu d3,(4,sp)
 movbu (44,a3),d0
 movbu d0,(6,sp)
 mov d3,d0
 movbu (55,a3),d1
 call TXPF,[],4
 movbu d0,(7,sp)
 movbu (55,a3),d0
 movbu d0,(8,sp)
 clr d0
 movbu d0,(9,sp)
 mov (10280,a2),a0
 mov sp,a1
 add 4,a1
 call TXGET,[d2,d3,a2,a3],28
 cmp 0,a0
 beq 9f
 mov (10276,a2),a1
 mov a0,(8324,a1)
 mov 1,d0
 movbu d0,(xb_tx)
9:
 ret [d2,d3,a2,a3],32

/* xb_sel2 (ft3): jmp from s_sel2 = the selector call inside the combiner set-up 0x60504b2b (frame `call ..,[d2,a2],12`,
 * a0 = context). The textured COLOR development (xb_tx 2, request xb_rq) gets combiner 1 there too; else the stock
 * selector. */
xb_sel2:
 movbu (xb_tx),d0
 cmp 2,d0
 bne 9f
 mov (4,a0),d0
 mov (xb_rq),d1
 cmp d0,d1
 bne 9f
 mov d0,a2                        /* rj1: and still a COLOR request (a2 is the frame's: free, as in xb_dev) */
 movbu (10,a2),d0
 cmp 11,d0
 bne 9f
 movbu (xb_tl),d0                 /* ft4: put COLOR's chroma back at the end of combiner 1's set-up (and the gain) */
 movbu d0,(xb_fx1)
 mov 1,d0
 ret [d2,a2],12
9:
 jmp SEL

/* xb_c1e (ft4): `calls` from s_c1e at the end of the set-up 0x605053ec..0x605053d0 (combiner 1's case), a2 = its
 * register image (context+8)+7988. Combiner 1 writes +96 = 1024 and +100 = 0 where the default case writes
 * 0x04000400 and 1024 (guess: the main input's chroma gains, zero = Grainy Film's mono). Flagged by xb_sel2:
 * the default's values back (Grain Low); Grain High also +148 = 2048 (guess: the texture's gain, x2). */
xb_c1e:
 movbu (xb_fx1),d0
 cmp 0,d0
 beq 9f
 clr d1
 movbu d1,(xb_fx1)
 mov 0x04000400,d1
 mov d1,(96,a2)
 mov 1024,d1
 mov d1,(100,a2)
 cmp 3,d0                         /* ft5: the texture's gain (+148) by Grain: Low 512, Med 768, High 1024 (ft4: 1024 =
                                     even, 2048 = darker) */
 bls 1f
 mov 3,d0
1:
 add d0,d0
 mov xb_tgain-2,a0
 add d0,a0
 movhu (a0),d1
 mov d1,(148,a2)
 movhu (6,a0),d1                  /* rc2: the texture is not zero-mean: it lifted Y by ~0.026 x gain (8-bit) on every
                                     tone (owner test PB081496..499); the output's Y offset (+180 low half, 0 in
                                     combiner 1's set-up, guess) takes it back: -0.102 x gain (10-bit) */
 movhu d1,(180,a2)
9:
 rets
 .balign 2
xb_tgain:                         /* rc2: Low / Med / High (Med and High looked alike at 768 / 1024; 2048 went dark) */
 .hword 448, 832, 1280
xb_tbias:                         /* -(0.102 x gain) as 16 bits, the same order */
 .hword -46 & 0xffff, -85 & 0xffff, -131 & 0xffff

/* xb_wl (ft8): `calls` from s_wl in the work-list builder 0x604b8cf7, a0 = job, before it picks the list by the
 * job's key (job+5352). A COLOR still (11) that already has our texture (job+8324, made at the set-up) and whose
 * profile has Grain with Pin Hole (2), White Edge (4) or Frame (5) and no Glow / Clarity gets Grainy Film II's list
 * (handler 0x604b8ddc: development with the texture, then the effect as its own pass, as Grainy Film + Pin Hole /
 * Frame do on the camera). The job's key itself stays 11. d0 = the key to look up, 0 = keep. */
xb_wl:                            /* a0 = S (ft8b: the builder's (4,sp)) */
 movm [d2,d3,a2,a3],(sp)
 add -4,sp
 clr d2
 mov a0,a3
 mov (10276,a3),a2
 cmp 0,a2
 beq 9f
 mov (5352,a2),d0
 cmp 11,d0
 bne 9f
 movbu d2,(xb_sw)                 /* rj1: only a COLOR job resets it (see xb_su) */
 call xb_slot,[d2,d3],12
 cmp 0,a1
 beq 9f
 movbu (53,a1),d0
 cmp 0,d0
 beq 9f
 ARTB d0                 /* ft9: every Grain still but Star Light (fine on COLOR's list) takes Grainy Film's
                                     list: plain, Shading, Glow / Clarity, Pin Hole, White Edge, Frame */
 cmp 1,d0
 beq 9f
8:
 mov a3,a0                        /* ft8b: the list is built before the set-up: make the texture now */
 call xb_tex,[d2,d3,a2,a3],32
 mov (8324,a2),d0
 cmp 0,d0
 beq 9f                           /* no texture: keep COLOR's list (Grainy Film's hook would read it) */
 mov 1,d0
 movbu d0,(xb_sw)
 mov 0x01020068,d2
9:
 mov d2,d0
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 rets

xb_sv:                            /* `calls` from pf_save: (0,sp) = return */
 rets

/* ---- fg1 (fast-grain log 1, 2026-11-08): how the Grainy Film Art Filter gets its grain, with and without an Art
 * Effect, next to a COLOR still and a MONO still (research; adapted from gl2d/gl8). GLOG.BIN = header 48 B ('GLG2',
 * total, marks, current mark, changed flag, selector calls, records, 0, four slot pointers) + 4 slots of LB_SLOT,
 * slot = mark & 3. Slot: +0 records, +4 / +8 / +12 copy A / B / C taken, +16 capture key (params+8), +20 flags
 * (params+12), +24 CPU id, +25..31 capture +37691, +37720, +37721, +37722, +37682, +38225, +37689; records from +32
 * (LB_NREC x 32 B: combiner, kind, stage, type +14, effect, context key +48, request key +8, CPU id, +12 B from
 * request +1744 (kind 0/15) / +1086 (kind 3)); copies (1856 B): A = first kind-0 stage-0 request at +1600, B = first
 * stage 0x09xx at +3456, C = first kind-3 stage-0 (final) at +5312. Live view (+14 0x0030 / 0x0130) skipped. */
 .set LB_SLOT, 7168
 .set LB_NSLOT, 8                 /* fg3: 8 slots (an Art photo takes two marks) */
 .set LB_HDR, 32 + 4 * LB_NSLOT
 .set LB_TOTAL, LB_HDR + LB_NSLOT * LB_SLOT
 .set LB_NREC, 48
 .set LB_A, 1600
 .set LB_B, 3456
 .set LB_C, 5312

xb_sbase:                         /* leaf: a0 = log header -> a3 = current slot or 0. Uses d0 */
 mov (12,a0),d0
 and LB_NSLOT - 1,d0
 asl 2,d0
 add 32,d0
 mov (d0,a0),a3
 retf [],0

xb_cpy:                           /* leaf: a0 dest, a1 source, d1 bytes (> 0). Uses d0 */
1:
 movbu (a1),d0
 movbu d0,(a0)
 inc a0
 inc a1
 add -1,d1
 bne 1b
 retf [],0

xb_mark:                          /* `call xb_mark,[d2,d3,a2,a3],20` from xb_cap: a3 = capture, a2 = params+12 */
 call xb_p,[],0                   /* P dirty: the next half-press saves (makes the buffers, writes the log) */
 cmp 0,a1
 beq 1f
 mov 1,d0
 movbu d0,(P_DIRTY,a1)
1:
 mov (xb_lbuf),a0                 /* the buffers come from the first half-press save (xb_lw) */
 cmp 0,a0
 beq 9f
 mov (8,a0),d0
 mov d0,(12,a0)
 inc d0
 mov d0,(8,a0)
 mov a3,d2
 call xb_sbase,[],0
 cmp 0,a3
 beq 9f
 clr d0
 mov d0,(a3)
 mov d0,(4,a3)
 mov d0,(8,a3)
 mov d0,(12,a3)
 mov (-4,a2),d0
 mov d0,(16,a3)
 mov (a2),d0
 mov d0,(20,a3)
 mov d2,a1
 movbu (0x8050),d0
 movbu d0,(24,a3)
 movbu (37691,a1),d0
 movbu d0,(25,a3)
 movbu (37720,a1),d0
 movbu d0,(26,a3)
 movbu (37721,a1),d0
 movbu d0,(27,a3)
 movbu (37722,a1),d0
 movbu d0,(28,a3)
 movbu (37682,a1),d0
 movbu d0,(29,a3)
 movbu (38225,a1),d0
 movbu d0,(30,a3)
 movbu (37689,a1),d0
 movbu d0,(31,a3)
 mov 1,d0
 mov d0,(16,a0)
9:
 ret [d2,d3,a2,a3],20

xb_lg:                            /* jmp from xb_dev in the frame of `call s_cl,[d2,a2],12`; a0 = context; d3/a3 live */
 mov a0,a2
 call SEL,[d2,a2],12              /* the stock selector (reads a0) */
 mov d0,d2                        /* its combiner */
 movbu (xb_ck),d0                 /* ft3: the textured COLOR development: combiner 1 (Grainy Film's blend) */
 cmp 0,d0
 beq 1f
 clr d0
 movbu d0,(xb_ck)
 mov 1,d2
1:
 .if XB_LOG
 movm [d3,a3],(sp)
 add -4,sp                        /* (0) call slot for the leaves (above it: the saved d3, a3) */
 mov xb_lhdr,a0
 mov (20,a0),d0
 inc d0
 mov d0,(20,a0)
 mov (xb_lbuf),a0
 cmp 0,a0
 beq 9f
 mov (8,a0),d0
 cmp 0,d0
 beq 9f                           /* no capture marked yet */
 call xb_sbase,[],0
 cmp 0,a3
 beq 9f
 mov (4,a2),a1
 cmp 0,a1
 beq 9f
 movhu (14,a1),d0                 /* skip live view (+14 = 0x0030 / 0x0130) */
 and 0xfeff,d0
 cmp 0x30,d0
 bne 1f
 jmp 9f
1:
 mov (24,a0),d0
 inc d0
 mov d0,(24,a0)
 mov (a3),d3
 cmp LB_NREC,d3
 bcc 5f
 mov d3,d0
 inc d3
 mov d3,(a3)
 asl 5,d0
 add 32,d0
 add a3,d0
 mov d0,a0
 movbu d2,(a0)
 movbu (16,a1),d0
 movbu d0,(1,a0)
 movhu (12,a1),d0
 movhu d0,(2,a0)
 movhu (14,a1),d0
 movhu d0,(4,a0)
 movbu (16,a1),d0
 cmp 3,d0
 beq 3f
 cmp 0,d0
 beq 2f
 cmp 15,d0
 bne 4f
2:
 movhu (1756,a1),d0
 mov 1744,d3
 bra 6f
3:
 movhu (1084,a1),d0
 mov 1086,d3
 bra 6f
4:
 clr d0
 mov 17,d3
6:
 movhu d0,(6,a0)
 mov (48,a2),d0
 mov d0,(8,a0)
 mov (8,a1),d0
 mov d0,(12,a0)
 movbu (0x8050),d0
 movbu d0,(16,a0)
 add 20,a0
 add d3,a1
 mov 12,d1
 call xb_cpy,[],0
5:
 mov (4,a2),a1                    /* fg3 copies: A first kind-0 request (any stage: Grainy Film develops in 0x0100),
                                     B first kind-3 stage 0x01xx (the Art pass), C first kind-3 stage 0 (final) */
 movbu (16,a1),d0
 cmp 0,d0
 bne 11f
 mov (4,a3),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 mov d0,(4,a3)
 mov LB_A,d1
 bra 8f
11:
 cmp 3,d0
 bne 9f
 movhu (12,a1),d0
 mov d0,d1
 and 0xff00,d1
 cmp 0x0100,d1
 bne 12f
 mov (8,a3),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 mov d0,(8,a3)
 mov LB_B,d1
 bra 8f
12:
 cmp 0,d0
 bne 9f
 mov (12,a3),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 mov d0,(12,a3)
 mov LB_C,d1
8:
 add a3,d1
 mov d1,a0
 mov 1856,d1
 call xb_cpy,[],0
 mov xb_lhdr,a0
 mov 1,d0
 mov d0,(16,a0)
9:
 add 4,sp
 movm (sp),[d3,a3]
 .endif
 mov d2,d0
 ret [d2,a2],12

xb_lw:                            /* `calls` from ub_save (the half-press save, HLS_EVENT task): (0,sp) = return */
 .if XB_LOG
 add -16,sp                       /* (0) call slot, (4) handle */
 mov (xb_lbuf),a3
 cmp 0,a3
 bne 5f
 mov xb_lhdr,a3                   /* first save: the four slot buffers (malloc fails during a capture) */
 clr d2
6:
 mov d2,d0
 asl 2,d0
 add 32,d0
 mov (d0,a3),a0
 cmp 0,a0
 bne 8f
 mov LB_SLOT,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f                           /* try again at the next save */
 mov a0,a1
 mov LB_SLOT / 4,d1
 clr d0
7:
 mov d0,(a1)
 add 4,a1
 add -1,d1
 bne 7b
 mov d2,d0
 asl 2,d0
 add 32,d0
 mov a0,(d0,a3)
8:
 inc d2
 cmp LB_NSLOT,d2
 bne 6b
 mov 0x33474c47,d0                /* fg3: 'GLG3' (8 slots, header LB_HDR) */
 mov d0,(a3)
 mov LB_TOTAL,d0
 mov d0,(4,a3)
 mov a3,(xb_lbuf)
 bra 9f
5:
 mov (16,a3),d0                   /* only when something new was logged */
 cmp 0,d0
 beq 9f
 clr d0
 mov d0,(16,a3)
 mov xb_glpath,a0
 mov xb_glmode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov a0,a1
 mov LB_HDR,d1
 mov 1,d0
 mov a3,a0
 call fwrite,[d2,d3,a2,a3],24
 clr d3
1:
 mov d3,d0
 asl 2,d0
 add 32,d0
 mov (d0,a3),a0
 mov (4,sp),a1
 mov LB_SLOT,d1
 mov 1,d0
 call fwrite,[d2,d3,a2,a3],24
 inc d3
 cmp LB_NSLOT,d3
 bne 1b
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
9:
 add 16,sp
 rets
 .else
 rets
 .endif

 .set P_LIDX, 712

/* xb_own (v0.25): leaf, a1 = slot entry (from xb_slot) -> d0 = 1 when COLOR k shows its own settings (no film
 * selected: P+LIDX+k not 1..5), else 0. Uses d0, a0 only; returns through MDR. */
xb_own:
 .if XB_OWNOFF
 mov (xb_pp),a0
 mov a1,d0
 sub a0,d0
 add -32,d0
 lsr 6,d0
 add d0,a0
 movbu (P_LIDX,a0),d0
 extb d0
 cmp 1,d0
 blt 1f
 cmp 5,d0
 bgt 1f
 clr d0
 retf [],0
1:
 mov 1,d0
 retf [],0
 .else
 clr d0                           /* v0.25 rc2: COLOR k's own Glow / Frame have rows now: used */
 retf [],0
 .endif
 .set P_TORG, 820                 /* v0.24: the film block (EDITS.BIN image at +TWO) */
/* xb_lkh (v0.21): jmp from lk_hold in ed_event's frame (after its movm and add -28: (12,sp) cursor id 2197 + k,
 * (24,sp) the event, a2 = P, a3 = the parent, d2 = 4). OK held on the wheel (0x903e) with a look selected for COLOR k:
 * that look <- COLOR k now (pf_cap), P dirty (written at the next half-press), -> ed_event e_lk (children re-read,
 * cursor poked, returns d3 = 1). No look selected: nothing (e_ret, d3 = 1). Any other event (the whole-profile reset
 * 0xf881 on "COLOR n", where the axis byte may read 4): the look selection of COLOR k cleared, then e_rst (the reset;
 * d2 = the page). OK held on any other page: e_rst. */
xb_lkh:
 movbu (24,sp),d0
 cmp 0x81,d0                      /* 0xf881: OK held on "COLOR n" = the whole-profile reset: also no look selected */
 beq 0f
 cmp 0x3e,d0                      /* film test 9: OK held on the wheel of a COLOR holding a film: the film as built too */
 bne 1f                           /* (it reset to the factory, so the film showed '*' after its reset) */
0:
 mov (12,sp),d3                   /* v0.24: COLOR k holding a film that is there -> the film as built */
 add -2197,d3
 mov a2,a0
 add d3,a0
 movbu (P_LIDX,a0),d0
 extb d0
 cmp 1,d0
 blt 20f
 cmp 5,d0
 bgt 20f
 mov (P_TORG,a2),d1
 cmp 0,d1
 beq 20f
 mov d3,d1
 asl2 d1
 add d3,d1
 add d0,d1
 add -1,d1                        /* film j */
 mov d1,(16,sp)
 mov d1,d0
 mov (P_LPTR,a2),a0
 call FL_HAS,[],0
 cmp 0,d0
 beq 20f
 mov (P_TORG,a2),a0               /* its saved changes dropped, the next capture skipped, look 0 ... */
 add TWO,a0
 mov (16,sp),d0
 mov 1,d1
 asl d0,d1
 not d1
 mov (12,a0),d0
 and d1,d0
 mov d0,(12,a0)
 mov 1,d0
 movbu d0,(TW_LEN,a0)
 movbu d0,(TW_LEN + 1,a0)
 mov a2,a0
 add d3,a0
 clr d0
 movbu d0,(P_LIDX,a0)
 call FACADE,[],4                 /* ... then SetValue(901, the film): fl_set -> fl_sw loads it as built */
 mov (a0),a2
 mov (4,a2),a2
 mov (16,sp),d0
 add FV0,d0
 mov d0,a1
 clr d1
 mov 901,d0
 calls (a2)
 mov 1,d3
 movbu (24,sp),d0
 cmp 0x3e,d0
 bne 21f
 jmp E_LK                         /* on the wheel: its values re-read, then all colours on Saturation (e_sall) */
21:
 jmp E_RET
20:
 movbu (24,sp),d0                 /* no film there: the wheel as before, "COLOR n" the whole-profile reset */
 cmp 0x3e,d0
 beq 1f
 mov (12,sp),d0
 add -2197,d0
 mov a2,a0
 add d0,a0
 clr d0
 movbu d0,(P_LIDX,a0)
 jmp xb_rpre
1:
 cmp 4,d2                         /* the wheel on the Looks page */
 bne 7f
 cmp 0x3e,d0
 bne 7f
 mov (12,sp),d2
 add -2197,d2                     /* k */
 mov a2,a0
 add d2,a0
 movbu (P_LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 8f
 cmp 5,d3
 bgt 8f
 mov (P_LPTR,a2),d0
 cmp 0,d0
 beq 8f
 call PF_CAP,[d2,d3,a2,a3],28     /* keeps a2, a3 */
 mov 1,d0
 movbu d0,(P_DIRTY,a2)
 mov 1,d3
 jmp E_LK
8:
 mov 1,d3
 jmp E_RET
7:
 jmp xb_rpre

/* xb_rpre (lk12): every reset goes through here (jmp, ed_event's frame: a2 = P, a3 = the editor, d2 = the page).
 * Off the Saturation page the wheel's children still hold that page's dial lists (Looks 0..5, Extras ranges), and
 * the stock reset puts each profile's factory Saturation through them: a value outside the list (COLOR4's -4 at
 * 12 o'clock on the Looks page) came back clamped, so that setting missed its default ('*' stayed). So: the page
 * reads Saturation and children 1..12 are re-read with the stock lists first; e_rst puts the page back afterwards. */
xb_rpre:
 cmp 0,d2
 beq 9f
 clr d0
 movbu d0,(684,a2)
 mov 128,d3
1:
 mov a3,a0
 add d3,a0
 mov (a0),a0
 cmp 0,a0
 beq 9f
 call REFRESH,[d2,d3,a2,a3],68
 add 4,d3
 cmp 176,d3
 bne 1b
9:
 jmp E_RST

/* Cached-alias trampolines (v0.21): the UI asks these many times per screen change (switching to COLOR: a long freeze
 * when they ran from the block's uncached heap). Each continues at the cached alias of its function (heap
 * 0xa0000000..0xb7ffffff - 0x40000000; the block is never written after relocation). Uses a1 only. Only for code that
 * stays inside the block: its PC-relative calls / jumps into the firmware are relocated for the uncached address. */
 .macro CACHED target
 mov \target,a1
 cmp 0xa0000000,a1
 bcs 91f
 cmp 0xb8000000,a1
 bcc 91f
 add -0x40000000,a1
91:
 jmp (a1)
 .endm
xb_cvc:
 CACHED xb_cv
xb_vbc:
 CACHED xb_vb

/* xb_cv / xb_vb (v0.21): leaves for the dial lists of the wheel editor's cells, entered (`calls`, (0,sp) = return)
 * through the cached trampolines above. No stack of their own beyond one call slot (the camera asks these while
 * switching into COLOR, where the deeper frames of lk7 / lk9 made it restart). d2 = the facade id; for xb_vb a2 = the
 * index and d3 = the out pointer (or 0). They keep d2, d3, a2, a0, a3 and use d0, d1, a1. The Looks page (axis 4)
 * 12 o'clock id 928 + 12 EDK: 0..5. An Extras cell (axis 3, marker, 928 + 12k + slice, slice 0..8 with an xt_tab
 * entry): min..max. Anything else: d1 = 0. */
xb_cv:
 add -4,sp                        /* below the `calls` return word: xb_cell's call slot */
 call xb_cell,[],0                /* -> d1 0 none / 1 Looks / 2 Extras, d0 = max - min, a1 = min */
 add 4,sp
 cmp 0,d1
 beq 9f
 inc d0
 mov 1,d1
9:
 rets

xb_vb:
 add -4,sp
 call xb_cell,[],0
 add 4,sp
 cmp 0,d1
 beq 9f
 mov a2,d1                        /* index */
 exthu d1
 cmp d0,d1
 bls 1f
 mov -1,d0
 bra 2f
1:
 mov a1,d0
 add d1,d0                        /* min + index */
2:
 cmp 0,d3
 beq 3f
 mov d3,a1
 mov d0,(a1)
3:
 mov 1,d1
9:
 rets

/* xb_cell: leaf (`call xb_cell,[],0`, returns through MDR), d2 = facade id -> d1 0 not ours; 1 the Looks page's 12
 * o'clock (d0 = 5, a1 = 0); 2 an Extras cell (d0 = max - min, a1 = min). Uses d0, d1, a1 only. */
xb_cell:
 clr d1
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
 bne 9f                           /* a1 = P */
 movbu (AXIS,a1),d0
 cmp 4,d0
 beq 4f
 cmp 3,d0
 bne 9f
 mov (EMARK,a1),d0                /* Extras */
 cmp EMAGIC,d0
 bne 9f
 mov d2,d0
 exthu d0
 add -928,d0
 cmp 48,d0
 bcc 9f
1:
 cmp 12,d0
 bcs 2f
 add -12,d0
 bra 1b
2:
 cmp 10,d0
 bcc 9f
 mov XT_TAB,a1
 add d0,a1
 add d0,a1
 add d0,a1
 movbu (a1),d0
 cmp 0,d0
 beq 9f
 movbu (2,a1),d0
 extb d0
 movbu (1,a1),d1
 extb d1
 sub d1,d0                        /* max - min */
 mov d1,a1                        /* min */
 mov 2,d1
 retf [],0
4:
 movbu (EDK,a1),d0                /* the Looks page */
 cmp 4,d0
 bcc 9f
 mov d0,d1
 add d1,d1
 add d0,d1
 asl2 d1
 add 928,d1                       /* 928 + 12 EDK */
 mov d2,d0
 exthu d0
 cmp d1,d0
 bne 8f
 mov 5,d0
 mov 0,a1
 mov 1,d1
 retf [],0
8:
 clr d1
9:
 retf [],0

/* xb_lkd (v0.21): `calls` from lk_pm (ed_pmod, the camera's "COLOR profile changed?"), (0,sp) = return, d0 = picture
 * mode 54 / 55 / 56 / 64 = COLOR1..4 -> d0 1 when COLOR k now differs from its selected look, 0 when it matches, -1
 * when no look is selected (the stock test then). "Now" = pf_capto (the editor's own capture) into xb_lkbuf, which
 * starts as a copy of the look's record (bytes pf_capto does not write compare equal). */
xb_lkd:
 movm [d2,d3,a2,a3],(sp)
 add -16,sp                       /* (0) call slot, (4) record */
 mov d0,d1
 clr d2
 cmp 54,d1
 beq 1f
 mov 1,d2
 cmp 55,d1
 beq 1f
 mov 2,d2
 cmp 56,d1
 beq 1f
 mov 3,d2
 cmp 64,d1
 bne 8f
1:
 call xb_p,[],0
 cmp 0,a1
 beq 8f
 mov a1,a2                        /* P */
 mov (P_LPTR,a2),d0
 cmp 0,d0
 beq 8f
 mov a2,a0
 add d2,a0
 movbu (P_LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 8f
 cmp 5,d3
 bgt 8f
 mov d2,d0                        /* record 5k + v - 1 */
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 asl 6,d0
 add 32,d0
 mov (P_LPTR,a2),a1
 add d0,a1
 mov a1,(4,sp)
 mov xb_lkbuf,a0
 mov 64,d1
2:
 movbu (a1),d0
 movbu d0,(a0)
 inc a0
 inc a1
 add -1,d1
 bne 2b
 mov xb_lkbuf,a3
 call PF_CAPTO,[d2,d3,a2,a3],28   /* a2 = P, d2 = k, a3 = the scratch record (keeps d2/d3/a2/a3) */
 mov xb_lkbuf,a0
 mov (4,sp),a1
 mov 64,d1
3:
 movbu (a0),d0
 movbu (a1),d2
 cmp d0,d2
 bne 4f
 inc a0
 inc a1
 add -1,d1
 bne 3b
 clr d0
 bra 9f
4:
 mov 1,d0
 bra 9f
8:
 mov -1,d0
9:
 ret [d2,d3,a2,a3],32

/* xb_grain: `call xb_grain,[d2,d3,a2,a3],128` (112 B of locals), a0 = buffer record, d0 = level 1..3. The heavy
 * loops (xb_p1s, xb_p2s) run from the cached alias of this block (heap memory is uncached) on work buffers used
 * through their cached alias; image rows go through the bus window's cached view and are written back (FLUSH)
 * before the lock is released. K = 2 rows share one lock and one FLUSH.
 * Locals: (0) call slot, (4) rec, (8) S, (12) T (malloc), (16) row, (20) bus, (24) pitch, (28) words, (32) groups,
 * (36) V + 2 H (malloc), (40) token, (44) Hw, (48) Vw, (52) cached rows, (56) start time, (60) level, (92) K,
 * (96) rows this pass, (100) H0, (104) H1; loop parameters (64) V, (68) H, (72) groups, (76) r, (80) row, (84) words,
 * (88) T. */
xb_grain:
 mov a0,(4,sp)
 mov d0,(60,sp)
 mov 2,d1                         /* K = 2 rows per lock / FLUSH (gr4: 0.3 s faster than 1) */
 mov d1,(92,sp)
 add -1,d0
 add d0,d0
 mov xb_gstab,a1
 movhu (d0,a1),d0
 mov d0,(8,sp)                    /* S */
 movhu (16,a0),d0                 /* format 0x0c02 only */
 cmp 0x0c02,d0
 bne 99f
 mov (4,a0),d0                    /* 32-bit bus address */
 cmp 0,d0
 bne 99f
 movhu (20,a0),d0                 /* Hw: 4 .. 8192, a multiple of 4 */
 mov d0,(44,sp)
 cmp 4,d0
 bcs 99f
 cmp 8193,d0
 bcc 99f
 btst 3,d0
 bne 99f
 movhu (18,a0),d1                 /* memHw >= Hw */
 cmp d0,d1
 bcs 99f
 add d1,d1
 mov d1,(24,sp)
 movhu (22,a0),d1
 mov d1,(48,sp)
 cmp 0,d1
 beq 99f
 mov d0,d1
 lsr 1,d1
 mov d1,(28,sp)
 mov d1,(84,sp)
 lsr 1,d1
 mov d1,(32,sp)
 mov d1,(72,sp)
 mov (a0),d1
 mov d1,(20,sp)
 mov d0,d1                        /* V and two H rows */
 add d0,d0
 add d1,d0
 call malloc,[],4
 cmp 0,a0
 beq 99f
 mov a0,(36,sp)
 mov 8192,d0                      /* T: 256 Y x 32 h */
 call malloc,[],4
 cmp 0,a0
 bne 1f
 mov (36,sp),a0
 call free,[],4
 bra 99f
1:
 mov a0,(12,sp)
 call FLUSH,[d2,d3],16            /* no stale lines for the work buffers' cached aliases */
 mov (12,sp),d0
 call xb_cach,[],0
 mov a0,(88,sp)                   /* T, cached */
 mov (8,sp),d3
 mov xb_G,a1
 call xb_tbl,[d2,d3,a2,a3],16
 mov (36,sp),d0                   /* V = 15 */
 call xb_cach,[],0
 mov a0,(64,sp)
 mov (44,sp),d1
 mov a0,a1
 add d1,a1
 mov a1,(100,sp)                  /* H0 */
 add d1,a1
 mov a1,(104,sp)                  /* H1 */
 mov 15,d0
1:
 movbu d0,(a0)
 inc a0
 add -1,d1
 bne 1b
 mov xb_seed,a0
 mov (a0),d0
 cmp 0,d0
 bne 2f
 mov 0x12345678,d0
2:
 mov d0,(76,sp)
 clr d0
 mov d0,(16,sp)
3:                                /* pass loop: K rows (fewer at the end) */
 mov (48,sp),d0
 mov (16,sp),d1
 sub d1,d0                        /* rows left */
 mov (92,sp),d1
 cmp d1,d0
 bcc 1f
 mov d0,d1
1:
 mov d1,(96,sp)
 mov (100,sp),a0                  /* noise rows: H0 (and H1) */
 mov a0,(68,sp)
 mov xb_p1s,d0
 call xb_cach,[],0
 calls (a0)
 mov (96,sp),d0
 cmp 2,d0
 bcs 2f
 mov (104,sp),a0
 mov a0,(68,sp)
 mov xb_p1s,d0
 call xb_cach,[],0
 calls (a0)
2:
 mov (16,sp),d0
 mov (24,sp),d1
 mul d1,d0
 mov (20,sp),d1
 add d1,d0                        /* the first row's bus address */
 mov (96,sp),d1
 add -1,d1
 mov (24,sp),d2
 mul d2,d1
 mov (44,sp),d2
 add d2,d2
 add d2,d1                        /* the length of the rows */
 call xb_open,[d2,d3,a2,a3],28
 mov d0,(40,sp)
 cmp 0,a0
 beq 4f                           /* rows across the window's edge (at most one pass): left as they are */
 clr d1                           /* through the window: its cached view (0xb8.. -> 0x78..; camera gd4: 0.63
                                     against 1.08 ms a row), the rows' lines written back before the lock goes */
 mov a0,d0
 cmp 0xb8000000,d0
 bcs 9f
 add -0x40000000,d0
 mov d0,a0
 mov 1,d1
9:
 mov d1,(52,sp)
 mov a0,(80,sp)
 mov (100,sp),a1
 mov a1,(68,sp)
 mov xb_p2s,d0
 call xb_cach,[],0
 calls (a0)                       /* row 1: row, H, words, T at (80, 68, 84, 88,sp) */
 mov (96,sp),d0
 cmp 2,d0
 bcs 5f
 mov (80,sp),d0
 mov (24,sp),d1
 add d1,d0
 mov d0,(80,sp)
 mov (104,sp),a1
 mov a1,(68,sp)
 mov xb_p2s,d0
 call xb_cach,[],0
 calls (a0)                       /* row 2 */
5:
 mov (52,sp),d1
 cmp 0,d1
 beq 4f
 call FLUSH,[d2,d3],16            /* the rows' cached lines back to memory, under the lock */
4:
 mov (40,sp),d0
 call xb_close,[d2],8
 mov (16,sp),d0
 mov (96,sp),d1
 add d1,d0
 mov d0,(16,sp)
 mov (48,sp),d1
 cmp d1,d0
 bcs 3b
 mov xb_seed,a0
 mov (76,sp),d0
 mov d0,(a0)
 call FLUSH,[d2,d3],16            /* write back the work buffers, drop the cached lines */
 mov (12,sp),a0
 call free,[],4
 mov (36,sp),a0
 call free,[],4
99:
 ret [d2,d3,a2,a3],128

/* xb_cach: leaf, d0 = an address -> a0 = its cached alias (0xa0000000..0xb7ffffff -> - 0x40000000), else itself */
xb_cach:
 mov d0,a0
 cmp 0xa0000000,d0
 bcs 1f
 cmp 0xb8000000,d0
 bcc 1f
 add -0x40000000,d0
 mov d0,a0
1:
 retf [],0

/* xb_tbl: `call xb_tbl,[d2,d3,a2,a3],16`, a0 = T (4096 B), a1 = G, d3 = S. T[16 y + h] = clamp(y + delta). */
xb_tbl:
 clr d2
1:
 movbu (a1),d0
 inc a1
 mul d3,d0
 mov d0,a2                        /* G[y] S */
 mov -945,d1                      /* 64 h - 945 for h 0..30: centred on h's mean (grain/model.py) */
2:
 mov a2,d0
 mul d1,d0
 add 131072,d0
 asr 18,d0
 add d2,d0
 cmp 0,d0
 bge 3f
 clr d0
3:
 cmp 255,d0
 ble 4f
 mov 255,d0
4:
 movbu d0,(a0)
 inc a0
 add 64,d1
 cmp 1103,d1                     /* 32 entries per Y: 64 x 32 - 945 */
 bne 2b
 inc d2
 cmp 256,d2
 bne 1b
 ret [d2,d3,a2,a3],16

/* xb_p1s: `calls (a0)` from xb_grain (sp = its sp): V (64,sp), H (68), groups of 4 px (72), r (76, in and out).
 * Per px: n = lo + hi nibble of a random byte, v = (V + n) >> 1 -> V, h = (v + v_left + 1) >> 1 -> H (v_left = 15
 * at x 0). Four pixels at a time in one word (byte k = pixel 4i + k): n = (r & 0x0f..) + ((r >> 4) & 0x0f..),
 * v = (V & n) + (((V ^ n) & 0xfe..) >> 1), v_left = v << 8 | the previous word's v >> 24, h = ((v + v_left +
 * 0x01..) >> 1) & 0x7f..; no byte carries (bytes <= 61). Same values as grain/model.py. Uses d0..d3, a0..a3. */
xb_p1s:
 mov (64,sp),a0
 mov (68,sp),a1
 mov (72,sp),a2
 mov (76,sp),a3                   /* r stays in a3: the stack is uncached */
 mov 0x0f000000,d3                /* the previous word's v: 15 in byte 3 */
1:
 mov a3,d0                        /* xorshift32 */
 mov d0,d2
 asl 13,d2
 xor d2,d0
 mov d0,d2
 lsr 17,d2
 xor d2,d0
 mov d0,d2
 asl 5,d2
 xor d2,d0
 mov d0,a3
 mov d0,d1
 lsr 4,d1
 and 0x0f0f0f0f,d0
 and 0x0f0f0f0f,d1
 add d1,d0                        /* n */
 mov (a0),d1                      /* V */
 mov d1,d2
 and d0,d2                        /* V & n */
 xor d0,d1
 and 0xfefefefe,d1
 lsr 1,d1
 add d2,d1                        /* v */
 mov d1,(a0)
 add 4,a0
 lsr 24,d3
 mov d1,d2
 asl 8,d2
 or d3,d2                         /* v_left */
 mov d1,d3                        /* (the next word's previous) */
 add d1,d2
 add 0x01010101,d2
 lsr 1,d2
 and 0x7f7f7f7f,d2                /* h = (v + v_left + 1) >> 1, 0..30 */
 mov d2,(a1)
 add 4,a1
 add -1,a2
 cmp 0,a2
 bne 1b
 mov a3,(76,sp)
 rets

/* xb_p2s: `calls (a0)` from xb_grain: the row (80,sp), H (68), words (84), T (88). Y0, Y1 of each word -> T[Y][h].
 * Uses d0..d3, a0..a3. */
xb_p2s:
 mov (80,sp),a0
 mov (68,sp),a1
 mov (84,sp),a2
 mov (88,sp),a3
1:
 mov (a0),d0
 mov d0,d1
 and 0xff,d1
 asl 5,d1
 movbu (a1),d2
 or d2,d1
 movbu (d1,a3),d1                 /* Y0' */
 mov d0,d2
 lsr 16,d2
 and 0xff,d2
 asl 5,d2
 movbu (1,a1),d3
 or d3,d2
 movbu (d2,a3),d2                 /* Y1' */
 and 0xff00ff00,d0
 or d1,d0
 asl 16,d2
 or d2,d0
 mov d0,(a0)
 add 4,a0
 add 2,a1
 add -1,a2
 cmp 0,a2
 bne 1b
 rets

 .balign 4
xb_lkbuf:                         /* xb_lkd's scratch record */
 .space 64
xb_seed:
 .long 0

/* entry 0 (`calls`): relocate this block in place -> d0 = its address. Keeps d2, d3, a2, a3. */
xb_reloc:                         /* a2 = P (x_load) */
 add -4,sp
 call 1f,[],0                     /* MDR = the address of 1 (the call word goes to the new slot) */
1:
 mov mdr,d0
 add 4,sp
 add xb_base-1b,d0                /* d0 = the block's address */
 mov d0,a0
 add xb_pp-xb_base,a0
 mov a2,(a0)                      /* P, for the label loader */
 movm [d2,d3,a2,a3],(sp)
 mov d0,a2
 mov d0,d3
 add -XB_LINK,d3                  /* delta */
 mov a2,a3
 add xb_end-xb_base,a3            /* the relocation list */
 mov a2,a0
 add xb_nrel-xb_base,a0
 mov (a0),d2
2:
 cmp 0,d2
 beq 4f
 mov (a3),d1
 mov d1,d0
 and 0x7fffffff,d0
 mov a2,a0
 add d0,a0                        /* the field (any alignment: byte access) */
 mov d3,a1                        /* bit 31 set: absolute, + delta */
 cmp 0,d1
 blt 3f
 clr d0                           /* else PC-relative to the firmware: - delta */
 sub d3,d0
 mov d0,a1
3:
 movbu (3,a0),d0
 asl 8,d0
 movbu (2,a0),d1
 or d1,d0
 asl 8,d0
 movbu (1,a0),d1
 or d1,d0
 asl 8,d0
 movbu (a0),d1
 or d1,d0
 mov a1,d1
 add d1,d0
 movbu d0,(a0)
 lsr 8,d0
 movbu d0,(1,a0)
 lsr 8,d0
 movbu d0,(2,a0)
 lsr 8,d0
 movbu d0,(3,a0)
 add 4,a3
 add -1,d2
 bra 2b
4:
 call xb_lbl,[d2,d3,a2,a3],24     /* relocated: absolute addresses and firmware calls are live now */
 mov a2,d0
 movm (sp),[d2,d3,a2,a3]
 rets

/* ---- dial labels: OM3MOD/LABELS.BIN v2 = 'OM3V' | u32 total | u32 CRC-32 of bytes 12.. | u32 n (24) | n bitmaps
 * 30 rows x 9 bytes (70 px, MSB first, 1 = letter fill). One heap copy (XL_FILE B) and one 2 KB stream buffer; the
 * label is drawn and encoded (OSD type 11, 70 x 30) only when it changes. */
 .set XL_N, 27
 .include "wbglyph.inc"           /* the build's: XL_FILE, the WB cell's layout (WBC_*) */
 .set XL_BM, 270
 /* XL_FILE: the file's size, from the build (wbglyph.inc: v0.25 the WB cell glyphs after the bitmaps) */
 .set XL_OUT, 2048
/* xb_lbl: `call xb_lbl,[d2,d3,a2,a3],24` once, after relocation. Locals (4) handle, (8) file buffer. Stores: xb_lb,
 * xb_lo, xb_lc (this block), the heap buffers, own frame. Anything wrong: no labels (xb_lb = 0). */
xb_lbl:
 mov xb_lpath,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov XL_FILE+4,d0
 call malloc,[],4
 cmp 0,a0
 beq 8f
 mov a0,(8,sp)
 mov 1,d0
 mov XL_FILE+4,d1                 /* one more than the file: a longer file is refused */
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp XL_FILE,d0
 bne 8f
 mov (8,sp),a2
 mov (a2),d0
 cmp 0x56334d4f,d0                /* 'OM3V' */
 bne 8f
 mov (4,a2),d0
 cmp XL_FILE,d0
 bne 8f
 mov (12,a2),d0
 cmp XL_N,d0
 bne 8f
 mov -1,d0
 mov a2,a0
 add 12,a0
 mov XL_FILE-12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a2),d1
 cmp d1,d0
 bne 8f
 mov XL_OUT,d0
 call malloc,[],4
 cmp 0,a0
 beq 8f
 mov xb_lo,a1
 mov a0,(a1)
 mov -1,d0
 mov xb_lc,a1
 mov d0,(a1)                      /* nothing drawn yet */
 mov xb_lb,a1
 mov a2,(a1)                      /* published last */
8:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
9:
 ret [d2,d3,a2,a3],24

/* xb_px: `call xb_px,[],0`, d1 = x, d2 = y (any value), a3 = bitmap -> d0 = 1 letter fill, else 0. Uses d3, a0. */
xb_px:
 cmp 70,d1
 bcc 9f
 cmp 30,d2
 bcc 9f
 mov d2,d0
 asl 3,d0
 add d2,d0                        /* 9y */
 mov a3,a0
 add d0,a0
 mov d1,d0
 lsr 3,d0
 add d0,a0
 movbu (a0),d0
 mov d1,d3
 and 7,d3
 asl d3,d0
 and 128,d0
 lsr 7,d0
 retf [],0
9:
 clr d0
 retf [],0

/* xb_rend: `call xb_rend,[d2,d3,a2,a3],64`, d0 = label -> d0 = stream length in xb_lo. Locals: (4) x, (8) y, (12) out,
 * (16) bit buffer, (20) bits in it, (24) tokens in the word, (28) value, (32) run, (36) out end. */
 .macro XB_TOK                    /* d0 = token -> the stream (12 bits; after 5 tokens 4 zero bits) */
 mov (20,sp),d1
 asl d1,d0
 mov (16,sp),d2
 or d0,d2
 add 12,d1
 mov (24,sp),d0
 inc d0
 cmp 5,d0
 bne 1f
 clr d0
 add 4,d1
1:
 mov d0,(24,sp)
 mov (12,sp),a0
2:
 cmp 8,d1
 bcs 3f
 mov (36,sp),d0
 cmp d0,a0
 bcc 3f                           /* never past the buffer */
 movbu d2,(a0)
 inc a0
 lsr 8,d2
 add -8,d1
 bra 2b
3:
 mov a0,(12,sp)
 mov d2,(16,sp)
 mov d1,(20,sp)
 .endm
xb_rend:
 mov xb_lb,a0
 mov (a0),a3
 add 16,a3
 cmp 0,d0
 beq 2f
1:
 add XL_BM,a3
 add -1,d0
 bne 1b
2:
 mov xb_lo,a0
 mov (a0),a0
 mov a0,d0
 add XL_OUT,d0
 mov d0,(36,sp)
 mov 0x0b04501d,d0                /* stream header: 70 x 30, type 11 */
 mov d0,(a0)
 add 4,a0
 mov a0,(12,sp)
 clr d0
 mov d0,(16,sp)
 mov d0,(20,sp)
 mov d0,(24,sp)
 mov d0,(32,sp)
 mov d0,(8,sp)
10:
 clr d0
 mov d0,(4,sp)
11:
 mov (4,sp),d1                    /* class of (x, y) */
 mov (8,sp),d2
 call xb_px,[],0
 mov 10,a2
 cmp 0,d0
 bne 15f
 mov -1,a1                        /* 8 neighbours: dark edge 7 */
12:
 mov -1,a2
13:
 mov (4,sp),d1
 mov a2,d0
 add d0,d1
 mov (8,sp),d2
 mov a1,d0
 add d0,d2
 call xb_px,[],0
 cmp 0,d0
 bne 14f
 inc a2
 cmp 2,a2
 bne 13b
 inc a1
 cmp 2,a1
 bne 12b
 mov -2,a1                        /* out to 2 px: grey 8 */
16:
 mov -2,a2
17:
 mov (4,sp),d1
 mov a2,d0
 add d0,d1
 mov (8,sp),d2
 mov a1,d0
 add d0,d2
 call xb_px,[],0
 cmp 0,d0
 bne 18f
 inc a2
 cmp 3,a2
 bne 17b
 inc a1
 cmp 3,a1
 bne 16b
 mov 0,a2
 bra 15f
14:
 mov 7,a2
 bra 15f
18:
 mov 8,a2
15:
 mov a2,d0                        /* d0 = the class; extend the run or emit it */
 mov (32,sp),d1
 cmp 0,d1
 beq 19f
 mov (28,sp),d2
 cmp d2,d0
 bne 20f
 cmp 16,d1
 bcc 20f
 inc d1
 mov d1,(32,sp)
 bra 21f
20:
 mov d0,(40,sp)                   /* the new class (scratch) */
 mov (28,sp),d0
 asl 4,d0
 add -1,d1
 or d1,d0
 XB_TOK
 mov (40,sp),d0
19:
 mov d0,(28,sp)
 mov 1,d0
 mov d0,(32,sp)
21:
 mov (4,sp),d0
 inc d0
 mov d0,(4,sp)
 cmp 70,d0
 bne 11b
 mov (8,sp),d0
 inc d0
 mov d0,(8,sp)
 cmp 30,d0
 bne 10b
 mov (28,sp),d0                   /* the last run */
 asl 4,d0
 mov (32,sp),d1
 add -1,d1
 or d1,d0
 XB_TOK
22:
 mov (24,sp),d0                   /* zero tokens to the end of the word */
 cmp 0,d0
 beq 23f
 clr d0
 XB_TOK
 bra 22b
23:
 mov (12,sp),d0
 mov xb_lo,a0
 mov (a0),d1
 sub d1,d0
 ret [d2,d3,a2,a3],64

/* label vl (vl_s jump; frame [d2,d3,a2,a3],20 of vl_s): d2 = slice, a2 = P, a3 = the caller's a0, d3 its a1.
 * On the Extras page, slices 1..8: the "Vivid" picture's descriptor (VDESC, 70 x 30) shows the label for the slice
 * and its value; anywhere else the stock picture. Only a descriptor that is 70 x 30 with the stock payload or ours is
 * touched. Stores: VDESC +12 size, +16 payload (as gd_set does for the guide picture), xb_lc, the stream buffer. */
xb_vl:
 add -12,sp                       /* (0) call slot (xb_rend's return word), (4) the caller's a1, (8) its a0 */
 mov d3,(4,sp)
 mov a3,(8,sp)
 mov xb_lb,a0
 mov (a0),d0
 cmp 0,d0
 beq 9f                           /* no labels */
 mov VDESC,a0
 movhu (2,a0),d0
 cmp 70,d0
 bne 9f
 movhu (4,a0),d0
 cmp 30,d0
 bne 9f
 mov (16,a0),d0                   /* current payload: stock or ours? */
 cmp VSTOCK_P,d0
 beq 2f
 mov xb_lo,a1
 mov (a1),d1
 cmp d1,d0
 bne 9f
2:
 movbu (AXIS,a2),d3
 cmp 3,d3
 bne 7f
 cmp 10,d2
 bcc 7f
 movbu (EDK,a2),d3
 asl 6,d3
 add 32,d3
 add a2,d3
 mov d3,a1                        /* slot entry */
 mov xb_vt,a0
 add d2,a0
 add d2,a0
 add d2,a0
 add d2,a0                        /* {byte, mode, first label, max} */
 movbu (a0),d3
 cmp 0,d3
 beq 7f                           /* no cell on this slice (v0.23 test 15) */
 add d3,a1
 movbu (a1),d3
 extb d3                          /* the value */
 movbu (2,a0),d1                  /* first label */
 movbu (1,a0),d0                  /* mode */
 cmp 1,d0
 beq 4f
 bcs 3f
 cmp 3,d0
 bne 6f                           /* 2: fixed */
 cmp -5,d3                        /* 3: first, or first + 1 at -5 (v0.22 Sharp Off) */
 bne 6f
 inc d1
 bra 6f
3:
 cmp 0,d3                         /* 0: first + value, 0..max */
 blt 6f
 movbu (3,a0),d0
 cmp d0,d3
 bgt 6f
 add d3,d1
 bra 6f
4:
 cmp 0,d3                         /* 1: first + (negative 0, positive 1, zero 2) */
 blt 6f
 inc d1
 cmp 0,d3
 bgt 6f
 inc d1
6:
 mov xb_lc,a0                     /* label d1: draw it if it is not the one in the buffer */
 mov (a0),d0
 cmp d1,d0
 beq 5f
 mov d1,(a0)
 mov d1,d0
 call xb_rend,[d2,d3,a2,a3],64
 mov xb_ll,a0
 mov d0,(a0)
5:
 mov xb_ll,a0
 mov (a0),d0
 mov xb_lo,a0
 mov (a0),d1
 bra 8f
7:
 mov VSTOCK_S,d0                  /* the stock picture */
 mov VSTOCK_P,d1
8:
 mov VDESC,a0
 mov d0,(12,a0)
 mov d1,(16,a0)
9:
 mov (4,sp),a1
 mov (8,sp),a0
 add 12,sp
 ret [d2,d3,a2,a3],20

 .balign 4
xb_pp:
 .long 0                          /* P (written by xb_reloc) */
xb_lb:
 .long 0                          /* LABELS.BIN heap copy, 0 = none */
xb_lo:
 .long 0                          /* the stream buffer */
xb_lc:
 .long -1                         /* the label in it */
xb_ll:
 .long 0                          /* its length */
xb_vt:                            /* slice 1..10: slot byte, mode, first label, max (slot byte 0: no cell, stock picture);
                                   * v0.23 test 15: Glow/Clarity at 12 o'clock, Art Effect at 6 o'clock (as xt_tab) */
 .byte 49,1,5,0                   /* 1 Glow (-), Clarity (+), Glow/Clar. (0) */
 .byte 0,2,0,0                    /* 2 */
 .byte 0,2,0,0                    /* 3 */
 .byte 0,2,0,0                    /* 4 */
 .byte 0,2,0,0                    /* 5 */
 .byte 0,2,0,0                    /* 6 */
 .byte 50,0,14,5                  /* 7 Art Effect: Off, Star Light, Pin Hole, (Off), White Edge, Frame */
 .byte 0,2,0,0                    /* 8 */
 .byte 0,2,0,0                    /* 9 */
 .byte 0,2,0,0                    /* 10 */
xb_glpath:
 .asciz "C:\\OM3MOD\\GLOG.BIN"
xb_glmode:
 .asciz "w"
xb_lpath:
 .asciz "C:\\OM3MOD\\LABELS.BIN"
 .balign 2
xb_gt:                            /* camera-route grain level of the last capture (xb_cap -> xb_dev), 0 none */
 .byte 0
xb_tx:                            /* ft1: 1 = xb_su gave this still a texture, 2 = attached to xb_rq */
 .byte 0
xb_tl:                            /* ft2: that still's Grain level (1 / 3: combiner 1 with key 11, 2: with GF II's key) */
 .byte 0
xb_ck:                            /* ft3: 1 = xb_lg answers combiner 1 for this configuration */
 .byte 0
xb_fx1:                           /* ft4: Grain level when combiner 1's set-up gets COLOR's chroma back, 0 none */
 .byte 0
xb_k3:                            /* ft7: 1 = the texture goes to a conversion pass (keep its stage) */
 .byte 0
xb_ownf:                          /* v0.25: 1 = this capture's COLOR shows its own settings (xb_cap) */
 .byte 0
xb_sw:                            /* ft8b: 1 = this still got Grainy Film II's work list (xb_wl) */
 .byte 0
xb_tart:                          /* ft8b: this still's Art Effect (xb_tex) */
 .byte 0
 .balign 4
xb_rq:                            /* ft2: the development request the texture went to */
 .long 0
xb_S:                             /* ft1: the last still's context S (xb_su) */
 .long 0
xb_lbuf:                          /* fg1: the log header once its buffers exist, else 0 */
 .long 0
xb_lhdr:                          /* fg1: log header (fg3: LB_HDR B; +32 the slot buffers) */
 .space LB_HDR
 .balign 2
xb_gstab:                         /* Grain 1..3 -> S: the camera's Low / Medium / High in grain contrast (v0.21) */
 .hword 28, 68, 112
xb_G:                             /* grain weight by Y, 0..255 (grain/model.py: the MONO grain shape) */
 .byte 20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20
 .byte 20,20,20,20,20,20,20,20,20,20,21,21,21,22,23,25
 .byte 26,28,30,32,34,36,39,42,45,48,51,54,58,62,65,69
 .byte 73,77,81,85,90,94,99,103,108,112,117,121,126,131,135,140
 .byte 145,149,154,159,163,168,172,177,181,186,190,194,198,202,206,210
 .byte 214,217,221,224,228,231,234,236,239,241,244,246,248,249,251,252
 .byte 253,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
 .byte 255,255,255,255,255,255,255,255,255,255,255,254,254,254,253,252
 .byte 251,250,249,248,247,246,245,243,242,240,239,237,236,234,233,231
 .byte 229,227,226,224,222,221,219,217,215,214,212,210,209,207,206,204
 .byte 203,202,200,199,198,197,196,195,194,193,193,192,192,191,191,191
 .balign 2
xb_ft:                            /* Art Effect id -> job flags: -, Star Light, Pin Hole, -, White Edge, Frame */
 .hword 0, 0x40, 0x400, 0, 0x2000, 0x8000
xb_gl:                            /* Glow 1..5 -> w (Caduceus bloom LUT) */
 .hword 942, 881, 819, 748, 666
xb_cl:                            /* Clarity 1..5 -> w > 1024 on combiner 11 (unsharp mask, Caduceus) */
 .hword 1100, 1180, 1260, 1340, 1420
xb_nm:                            /* NR 1 Std, 2 Low, 3 Off, 4 High (v0.23) -> the stills Noise Filter value (stock -2..+1) */
 .byte 0, -1, -2, 1

/* xb_wbc (v0.25 WB grid row): `calls` from wb_draw, d0 = A-B, d1 = G-M (-7..+7) -> a0 = the left cell's picture
 * stream (100 x 76, OSD type 11), d0 = its length, or d0 = 0 (then the firmware shows the camera's WB± picture).
 * The cell is drawn as the camera's WB screen cell: the camera's own WB± picture (12545, 82 x 30, type 11, read from
 * its picture table at run time; WBC_IX / WBC_IY) over the values as the camera writes them ("A2.G2", "B1.0", blank
 * when both are 0), from our glyphs (LABELS.BIN v3 after its bitmaps: 0..7, A, B, G, M, '.'), centred, one
 * glyph's dark edge over the next's (2 px), an ink pixel replacing only clear or edge pixels. Row by row into
 * xb_wrow, each row's runs (<= 16, never past the row's end) packed five 12-bit tokens a 64-bit word into xb_wbp.
 * Static state in the block (no mul / div). */
.set WBC_W, 100
.set WBC_H, 76
.set WB_MAX, 3200
xb_wbc:
 movm [d2,d3,a2,a3],(sp)
 add -4,sp                        /* (0,sp): our calls' return address slot */
 mov d0,(xb_wtv)
 mov d1,(xb_wtv + 4)
 mov a0,d0
 mov d0,(xb_wmd)
 mov xb_wbp,a2                    /* this mode's stream buffer, once (malloc: uncached, as the stock pictures') */
 asl2 d0
 add d0,a2
 mov (a2),d0
 cmp 0,d0
 bne 1f
 mov WB_MAX + 112,d0
 call malloc,[],4
 cmp 0,a0
 beq 90f
 mov a0,(a2)
1:
 mov (a2),d0
 mov d0,(xb_wcur)
 add WB_MAX,d0                    /* the row buffer after the stream's room; the room's end for wb_wem */
 mov d0,(xb_wrw)
 mov d0,(WB_V + 32)
 mov (xb_lb),a0                   /* the glyphs: LABELS.BIN after its bitmaps, 'WBG1' | u16 offset[N] | u16 top
                                   * offset, length | u8 width[N] */
 cmp 0,a0
 beq 90f
 add 16 + XL_N * XL_BM,a0          /* 2-aligned only: halfword reads */
 movhu (a0),d0
 cmp 0x4257,d0                    /* 'WB' */
 bne 90f
 movhu (2,a0),d0
 cmp 0x3147,d0                    /* 'G1' */
 bne 90f
 mov a0,(xb_wsec)
 mov a0,(WB_V + 36)               /* for the firmware's Blacks / Whites symbols */
 mov (xb_wmd),d0                  /* the picture on top: 1 our "Blk/Wht" (LABELS.BIN), 0 the camera's WB± */
 cmp 0,d0
 beq 2f
 movhu (4 + 2 * WBC_N,a0),d0
 mov a0,a1
 add d0,a1
 bra 3f
2:
 mov (0x60379740),a0              /* the word at (0x60379740) + 4 x 12545 -> its descriptor {14, 82, 30, ...} */
 add 50180,a0
 mov (a0),a0
 cmp 0,a0
 beq 90f
 movhu (2,a0),d0
 cmp 82,d0
 bne 90f
 movhu (4,a0),d0
 cmp 30,d0
 bne 90f
 mov (16,a0),a1
 cmp 0,a1
 beq 90f
3:
 movbu (3,a1),d0
 cmp 11,d0
 bne 90f
 mov a1,(xb_wsrc)
 add 4,a1
 mov a1,(WB_V + 0)
 mov 5,d0
 mov d0,(WB_V + 12)
 /* the text: glyph indices into xb_wtx, count xb_wn */
 mov xb_wtx,a2
 clr d3
 mov (xb_wtv),d0
 mov (xb_wtv + 4),d1
 or d1,d0
 cmp 0,d0
 beq 20f
 mov xb_wtv,a1
 mov (xb_wmd),d0
 mov xb_wtl,a3
 cmp 0,d0
 beq 1f
 add 5,a3                         /* Blacks / Whites: '+' / '-' and '/' */
1:
 clr d2
1:
 mov (a1),d0
 cmp 0,d0
 bne 2f
 clr d1                           /* 0: the digit alone */
 movbu d1,(a2)
 inc a2
 inc d3
 bra 4f
2:
 blt 3f
 movbu (a3),d1                    /* A / G */
 bra 31f
3:
 movbu (1,a3),d1                  /* B / M */
 not d0
 inc d0
31:
 movbu d1,(a2)
 inc a2
 movbu d0,(a2)
 inc a2
 add 2,d3
4:
 cmp 0,d2
 bne 20f
 movbu (4,a3),d1                  /* '.' / '/' */
 movbu d1,(a2)
 inc a2
 inc d3
 inc d2
 add 4,a1
 add 2,a3
 bra 1b
20:
 mov d3,(xb_wn)
 /* glyph row pointers, widths, places: x0 = (100 - (sum (w - 2) + 2)) / 2 */
 mov xb_wtx,a2
 mov xb_wgp,a3
 clr d2                           /* i */
 mov 2,d3                         /* the width */
5:
 mov (xb_wn),d0
 cmp d0,d2
 bcc 6f
 movbu (a2),d0                    /* glyph index */
 mov (xb_wsec),a0
 mov d0,d1
 add d1,d1
 add 4,d1
 movhu (d1,a0),d1                 /* its offset */
 mov a0,a1
 add d1,a1
 mov a1,(a3)                      /* xb_wgp[i] */
 add 4 + 2 * WBC_N + 16,a0
 movbu (d0,a0),d0
 mov d0,(20,a3)                   /* xb_wgw[i] */
 add d0,d3
 add -2,d3
 inc a2
 add 4,a3
 inc d2
 bra 5b
6:
 mov WBC_W,d0
 sub d3,d0
 asr 1,d0                         /* x0 */
 mov xb_wgp,a3
 clr d2
7:
 mov (xb_wn),d1
 cmp d1,d2
 bcc 8f
 mov d0,(40,a3)                   /* xb_wgx[i] */
 mov (20,a3),d1
 add d1,d0
 add -2,d0
 add 4,a3
 inc d2
 bra 7b
8:
 /* the stream header (h - 1 | w - 1 << 12 | 11 << 24) and the token packer */
 mov (xb_wcur),a0
 mov 0x0b06304b,d0                /* 100 x 76: 75 | 99 << 12 | 11 << 24 */
 mov d0,(a0)
 add 4,a0
 mov a0,(WB_V + 16)
 clr d0
 mov d0,(WB_V + 28)
 mov d0,(WB_V + 20)
 mov d0,(WB_V + 24)
 clr d3                           /* y */
10:
 mov d3,(xb_wy)
 /* clear the row */
 mov (xb_wrw),a0
 clr d0
 mov 28,d1
11:
 mov d0,(a0)
 add 4,a0
 add -1,d1
 bne 11b
 /* the WB± picture's rows */
 mov d3,d0
 add -WBC_IY,d0
 cmp 30,d0
 bcc 14f
 mov (xb_wrw),a2
 add WBC_IX,a2
 clr d2                           /* x */
12:
 cmp 82,d2
 bcc 14f
 call wb_wtk,[],4                 /* d0 = the next token */
 mov d0,d1
 lsr 4,d1                         /* palette index */
 and 15,d0
 inc d0                           /* run */
13:
 movbu d1,(a2)
 inc a2
 inc d2
 add -1,d0
 bne 13b
 bra 12b
14:
 /* the text's rows */
 mov d3,d0
 add -WBC_TY,d0
 cmp WBC_GH,d0
 bcc 18f
 mov xb_wgp,a3
 clr d2                           /* i */
15:
 mov (xb_wn),d0
 cmp d0,d2
 bcc 18f
 mov (a3),a0                      /* this row of glyph i */
 mov (20,a3),d1                   /* w */
 mov a0,d0
 add d1,d0
 mov d0,(a3)                      /* the next row */
 mov (xb_wrw),a1
 mov (40,a3),d0
 add d0,a1                        /* its place in the row */
16:
 movbu (a0),d0
 cmp 0,d0
 beq 17f
 cmp 7,d0
 bne 161f
 movbu (a1),d0                    /* an edge pixel: only over clear / edge */
 cmp 0,d0
 beq 160f
 cmp 7,d0
 bne 17f
160:
 mov 7,d0
161:
 movbu d0,(a1)
17:
 inc a0
 inc a1
 add -1,d1
 bne 16b
 add 4,a3
 inc d2
 bra 15b
18:
 /* the row's runs */
 mov (xb_wrw),a2
 clr d2                           /* x */
19:
 cmp WBC_W,d2
 bcc 30f
 movbu (a2),d1                    /* v */
 mov 1,d0                         /* r */
21:
 cmp 16,d0
 bcc 22f
 mov d2,a0
 add d0,a0
 cmp WBC_W,a0
 bcc 22f
 mov a2,a1
 add d0,a1
 movbu (a1),d3
 cmp d1,d3
 bne 22f
 inc d0
 bra 21b
22:
 add d0,d2
 add d0,a2
 asl 4,d1
 add -1,d0
 or d1,d0
 call wb_wem,[],4                 /* d0 = the token; d0 = 0: the buffer is full */
 cmp 0,d0
 beq 90f
 bra 19b
30:
 mov (xb_wy),d3
 inc d3
 cmp WBC_H,d3
 bcs 10b
 /* the last, partly filled word */
 mov (WB_V + 28),d0
 cmp 0,d0
 beq 31f
 mov (WB_V + 16),a0
 mov (WB_V + 20),d0
 mov d0,(a0)
 mov (WB_V + 24),d0
 mov d0,(4,a0)
 add 8,a0
 mov a0,(WB_V + 16)
31:
 mov (WB_V + 16),d0
 mov (xb_wcur),a0
 mov a0,d1
 sub d1,d0
 mov (xb_wsrc),a1                 /* and the top picture (for the fine-tune screen's title) */
 mov (xb_wsec),a2
 movhu (4 + 2 * WBC_N + 2,a2),d1
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 rets
90:
 clr d0
 mov 0,a0
 add 4,sp
 movm (sp),[d2,d3,a2,a3]
 rets

 .balign 4
xb_wtv:                           /* A-B, G-M */
 .long 0, 0
xb_wtl:                           /* WB: A, B, G, M, '.'; Blacks / Whites: '+', '-', '+', '-', '/' */
 .byte 8, 9, 10, 11, 12, 13, 14, 13, 14, 15
 .balign 4
xb_wtx:                           /* the text's glyph indices */
 .byte 0, 0, 0, 0, 0, 0, 0, 0
xb_wn:
 .long 0
xb_wbp:                           /* the stream buffers (malloc), WB and Blacks / Whites */
 .long 0, 0
xb_wcur:
 .long 0
xb_wmd:
 .long 0
xb_wsrc:
 .long 0
xb_wsec:                          /* the glyphs in LABELS.BIN */
 .long 0
xb_wrw:                           /* the row buffer (112 B after the stream's room) */
 .long 0
xb_wy:
 .long 0
xb_wgp:                           /* per glyph: row pointer (+0), width (+20), x (+40) */
 .long 0, 0, 0, 0, 0
 .long 0, 0, 0, 0, 0
 .long 0, 0, 0, 0, 0
 .balign 4
xb_end:
