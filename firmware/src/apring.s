/* Panasonic / DJI aperture ring (branch feature/aperture-ring, 2026-11-20). Port of p-eh's camera-tested ring1
 * (p-eh/caduceus-om3 feature/aperture-ring, c92db7a, on v0.27: "it works" with a Leica DG Summilux 15 mm f/1.7), with
 * the safety changes below. The protocol and the OM-3 sites were learned by p-eh from azqeurio/om-c-firmware 0.3.2
 * (`ring-native`, read as data), om-emu's analysis of it, cakelesscoder/caduceus-ep7 docs/APERTURE_RING.md and
 * fishcu/oly_fw_analysis PR #4 (PEN-F). Our own code; the stock sites re-read from the 1.1 image (research/APRING_PORT.md).
 *
 * What it does: a lens whose record says it has a ring (+1096 bit 7) is asked for its ring word (bit 0 of the reply's
 * option byte R+21, on the lens state queries 69 / 75 / 84 / 90). Its reply then carries a u16 at +12, before every
 * command-dependent field: 0x8000 = ring at A, else Av x 256. In stills A and M (C1..C5 saved in A / M too) the 0x80CA
 * "selected aperture" getter returns the ring's value while the ring is at a stop. Everything else stays stock.
 *
 * Changes from ring1 (safety):
 *  1. The expected reply length mirrors the stock parser's own conditions (0x602fc511): the R+21 0x80 / 0x10 / 0x20
 *     blocks count only when the lens record (+1676) and the two lens-info getters say the parser reads them, as the
 *     parser does. ring1 counted them from R+21 alone.
 *  2. Any short reply (exactly 2 short: the lens ignored the bit; other lengths: out of step) stops the asking for this
 *     lens until its ID changes, so at most one reply is read in doubt; that one is read as stock reads a short reply
 *     (bit cleared, the ring word not read). ring1 kept asking, so a lens out of step was misread at every poll. Not
 *     stock's error path with 0x6507 (om-c): the callback has reset stock's retry count (0x62996138, at 0x60304d4a)
 *     before this check, so a retried frame that is short again would be retried for ever.
 *  3. A ring word that is neither 0x8000 nor 0..0x1000 (not a ring word: a packet out of step) stops the asking too.
 *  4. The getter only reads our state (ring1 re-keyed it from the getter's task too), and checks the value's range
 *     itself, so a value written by the lens task in between can never give 0x8000 as an aperture.
 *  5. Live from switch-on (asked for in camera testing, 2026-11-20; the first test build waited for the first half-press). Before it, the ring does no card
 *     access, no settings write and starts no task: one bit in the lens request and 2 more bytes read, behind
 *     SEC_READY and the lens gate. The switch OM3MOD/NORING.TXT needs the card, so it is read at the first shutter event
 *     of a power-on behind the card gate hl_ok (ring1: the v0.26 power-on load, gone since v0.29) and turns the ring off
 *     from there; until then the ring is on.
 *  6. The debug log's NOW says what the ring did (counts), for the camera test.
 *  7. The stubs enter section 6 only behind SEC_READY (the camera's ready mask), not SECBITS (the copy bits).
 *
 * Section-1 stubs (.ext1): lens code runs before section 6 is in. Each stub tests SEC_READY bit 5 (section 6 ready,
 * the camera's own check) before entering ext13. Code and state in .ext13 (the debug log's area, in the GX4-proven
 * reserve after section 6 and loaded with it: build.py raises the loader's end word to cover ext13). */
 .set AP_RDY, 0xa32de58c          /* SEC_READY: bit (id - 1) once a section is in (set at 0x60046064) */
 .set AP_LREC, 0xa32c9c24         /* -> the lens record (+1096 flags, bit 7 = has a ring; +1100 / +1102 its ID; +1676
                                   * the parser's block bits) */
 .set AP_IDC, 0x62996006          /* the ID copy the `c1 f9` identity parser writes (2 halfwords) */
 .set AP_FIX, 0xa32d3d32          /* FIX DATA LENS byte: 1 = an electronic lens with data */

.section .hook_rq,"ax"
 jmp ap_rq1                       /* stock 0x603049f6 asr 8,d0; mov d1,a0; movbu d0,(a0) */
 .byte 0xcb,0xcb
.section .hook_ps,"ax"
 jmp ap_ps1                       /* stock 0x602fc5ed extbu d2; mov d2,(24,sp); btst 2,d2 */
 .byte 0xcb
.section .hook_rl,"ax"
 jmp ap_rl1                       /* stock 0x60305322 mov d0,d2; mov d2,d3; call 0x603106eb,[],4 */
 .byte 0xcb,0xcb,0xcb,0xcb
.section .hook_av,"ax"
 jmp ap_av1                       /* stock 0x605ac5f1 call 0x60063380,[d2,d3],12 (the 0x80CA getter) */
 .byte 0xcb,0xcb
 /* code addresses (ap_rq_back, ap_ps_back, ap_rl_tgt, ap_rl_back, ap_mode, ap_ae, ap_lens, ap_f1, ap_f2):
  * editor.ld (a .set code address makes jmp / call encode the absolute as the displacement) */

.section .ext1,"ax"
/* Every stub enters ext13 only behind the camera's own ready mask for section 6 (SEC_READY bit 5, as stock 0x60045e39
 * reads it; tools/test/static_check.py section-order), in the form `mov (SEC_READY),dN; and 0x20,dN; beq stock; jmp`.
 * ring1 tested SECBITS 0xa32de590 (the copy bits) instead; crop round 7 boot-looped the camera reaching section 6
 * early (research/NOTES.md). The parser and length stubs also need R+21 bit 0, which only ap_rq sets. */
ap_rq1:                           /* .hook_rq, 0x603049f6 (frame builder: R+21 = p2 >> 8; d1 = R+21). The stock store
                                   * first; then d0 is free (stock reloads it at 0x603049fd) */
 asr 8,d0
 mov d1,a0
 movbu d0,(a0)
 mov (AP_RDY),d0
 and 0x20,d0
 beq 1f
 jmp ap_rq
1:
 jmp ap_rq_back
ap_ps1:                           /* .hook_ps, 0x602fc5ed (state parser: d2 = R+21 byte, a2 = reply cursor at +12; d0
                                   * free: reloaded at 0x602fc610 / by the call at 0x602fc5fc) */
 extbu d2
 mov d2,(24,sp)
 btst 1,d2
 beq 1f
 mov (AP_RDY),d0
 and 0x20,d0
 beq 1f
 jmp ap_ps
1:
 btst 2,d2
 jmp ap_ps_back
ap_rl1:                           /* .hook_rl, 0x60305322: entry of the count helper all six reply handlers call
                                   * (`call ..,[d2,d3],12`: d0 = R+20 byte, d1 = command id, the caller's (24,sp) = R;
                                   * d2, d3, a0 free: stock overwrites d2 / d3 next, every caller reloads a0) */
 mov (36,sp),a0
 btst 1,(21,a0)
 beq 1f
 mov (AP_RDY),d2
 and 0x20,d2
 beq 1f
 jmp ap_rl
1:
 mov d0,d2
 mov d2,d3
 call ap_rl_tgt,[],4
 jmp ap_rl_back
ap_av1:                           /* .hook_av, 0x605ac5f1 (the 0x80CA getter: call getter; exth d0; ret [],4; d1 free
                                   * after the call) */
 call getter,[d2,d3],12
 mov (AP_RDY),d1
 and 0x20,d1
 beq 1f
 jmp ap_av
1:
 exth d0
 ret [],4

.section .ext13,"ax"
/* AGATE miss, rekey: ap_on 1, a ring lens record (pointer in a2000000..a3fffbae, 4-aligned, +1096 bit 7) whose ID
 * (+1100 / +1102) is the current ID copy, FIX DATA LENS 1, ID != 0. rekey 1 (the lens task, ap_rq): a new ID becomes
 * ours (ask again, no value). rekey 0 (the getter): the ID must already be ours. Uses d0, d1, a0. */
 .macro AGATE miss, rekey
 movbu (ap_on),d0
 cmp 1,d0
 bne \miss
 mov (AP_LREC),a0
 mov a0,d0
 add 0x5e000000,d0
 cmp 0x01fffbaf,d0
 bcc \miss
 btst 3,d0
 bne \miss
 movbu (1096,a0),d0
 btst 0x80,d0
 beq \miss
 movhu (1100,a0),d0
 movhu (AP_IDC),d1
 cmp d1,d0
 bne \miss
 movhu (1102,a0),d0
 movhu (AP_IDC+2),d1
 cmp d1,d0
 bne \miss
 movbu (AP_FIX),d0
 cmp 1,d0
 bne \miss
 movhu (AP_IDC+2),d0
 asl 16,d0
 movhu (AP_IDC),d1
 or d1,d0
 cmp 0,d0
 beq \miss
 mov (ap_id),d1
 cmp d1,d0
 beq 83f
 .if \rekey
 mov d0,(ap_id)
 clr d0
 movbu d0,(ap_ok)
 movbu d0,(ap_st)
 .else
 bra \miss
 .endif
83:
 .endm

 .macro AINC var                  /* (\var) += 1 (u32; uses d0) */
 mov (\var),d0
 inc d0
 mov d0,(\var)
 .endm

ap_rq:                            /* from ap_rq1 (the stock store done, d1 = a0 = R+21): R+21 |= 1 for 69 / 75 / 84 /
                                   * 90 when AGATE and this lens has not been stopped. Command id = the halfword at the
                                   * frame's (16,sp). Leaves d1 and a0 as stock does; stock reloads d0 next. */
 add -12,sp
 mov d1,(4,sp)
 mov a0,(8,sp)
 mov (28,sp),a0
 movhu (a0),d0
 cmp 69,d0
 beq 1f
 cmp 75,d0
 beq 1f
 cmp 84,d0
 beq 1f
 cmp 90,d0
 bne 9f
1:
 AGATE 9f, 1
 movbu (ap_st),d0
 cmp 2,d0
 beq 9f
 mov (8,sp),a0
 bset 1,(0,a0)
 AINC ap_nask
9:
 mov (4,sp),d1
 mov (8,sp),a0
 add 12,sp
 jmp ap_rq_back

ap_ps:                            /* from ap_ps1 (R+21 bit 0: we asked, and ap_rl found the reply long enough): the u16
                                   * at a2 -> ap_val / ap_ok, a2 += 2, then the stock `btst 2,d2` and back. Uses d0, d1
                                   * (stock reloads both). A valid stop: ap_val first, then ap_ok; anything else: ap_ok
                                   * cleared first. */
 movbu (1,a2),d0
 asl 8,d0
 movbu (a2),d1
 or d1,d0
 add 2,a2
 cmp 0x1001,d0
 bcc 1f
 movhu d0,(ap_val)                /* 0 .. 0x1000: a stop */
 mov 1,d0
 movbu d0,(ap_ok)
 AINC ap_nrng
 bra 3f
1:
 clr d1
 movbu d1,(ap_ok)
 movhu d0,(ap_val)
 cmp 0x8000,d0
 beq 2f                           /* the ring at A: the body's aperture */
 mov 2,d1                         /* not a ring word: stop asking this lens */
 movbu d1,(ap_st)
 AINC ap_nodd
 bra 3f
2:
 AINC ap_na
3:
 btst 2,d2
 jmp ap_ps_back

ap_rl:                            /* from ap_rl1 (R+21 bit 0): a0 = R, d0 = R+20 byte n, d1 = command id; the helper's
                                   * frame. Expected length E with the ring
                                   * word, as the stock parser reads 69 / 75 / 84 / 90: 12 + 2 (ring) + 2 * max(n, 1)
                                   * + 2 for 84 / 90, + 16 (R+21 0x02), + 4 (0x08), + 1 (0x80: record +1676 0x02,
                                   * 0x602f95f7(0) == 1 and 0x602f9616(0) >= 5130), + 1 (0x10: +1676 0x20), + 5 (0x20:
                                   * +1676 0x80). Received L = R+24. L >= E: ours. L == E - 2: the lens ignored the bit:
                                   * bit 0 cleared (stock parse), never asked again. Other L < E: the same (counted
                                   * apart). Then the stock helper.
                                   * Frame 16: (0) call slot, (4) n, (8) command id, (12) R. Uses d0..d3, a0, a1. */
 add -16,sp
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov d0,d2
 extbu d2
 cmp 0,d2
 bne 1f
 mov 1,d2
1:
 add d2,d2
 add 14,d2
 cmp 84,d1
 beq 2f
 cmp 90,d1
 bne 3f
2:
 add 2,d2
3:
 movbu (21,a0),d3
 btst 2,d3
 beq 4f
 add 16,d2
4:
 btst 8,d3
 beq 5f
 add 4,d2
5:
 btst 0x80,d3
 beq 6f
 mov (AP_LREC),a1
 mov (1676,a1),d0
 btst 2,d0
 beq 6f
 clr d0
 call ap_f1,[],0
 exthu d0
 cmp 1,d0
 bne 6f
 clr d0
 call ap_f2,[],0
 exthu d0
 cmp 5130,d0
 blt 6f
 inc d2
6:
 btst 0x10,d3
 beq 7f
 mov (AP_LREC),a1
 mov (1676,a1),d0
 btst 0x20,d0
 beq 7f
 inc d2
7:
 btst 0x20,d3
 beq 8f
 mov (AP_LREC),a1
 mov (1676,a1),d0
 btst 0x80,d0
 beq 8f
 add 5,d2
8:
 mov (12,sp),a0
 movhu (24,a0),d3
 cmp d2,d3
 bge 9f
 clr d0                           /* short: no value, never ask this lens again */
 movbu d0,(ap_ok)
 mov 2,d0
 movbu d0,(ap_st)
 bclr 1,(21,a0)                   /* the stock parse (the ring word not read) */
 add -2,d2
 cmp d2,d3
 bne 10f
 AINC ap_nign                     /* exactly 2 short: the stock layout */
 bra 9f
10:
 AINC ap_nbad                     /* any other short reply: as stock reads a short reply */
9:
 mov (4,sp),d0
 add 16,sp
 mov d0,d2
 mov d2,d3
 call ap_rl_tgt,[],4
 jmp ap_rl_back

ap_av:                            /* from ap_av1 after the stock getter (d0 = the body's aperture), section 6 loaded:
                                   * stills A / M (C1..C5 resolved through the effective AE), a lens connected, AGATE
                                   * (read only), a ring stop for this lens -> d0 = the ring's. Then the getter's own
                                   * tail (exth d0; ret [],4). Keeps d2, d3, a2, a3 (callees save their own). */
 add -8,sp
 mov d0,(4,sp)
 AGATE 8f, 0
 movbu (ap_ok),d0
 cmp 1,d0
 bne 8f
 call ap_mode,[d2],8
 exthu d0
 cmp 2,d0
 beq 2f
 cmp 4,d0
 beq 2f
 cmp 63,d0
 beq 1f
 add -53,d0
 cmp 4,d0
 bcc 8f
1:
 call ap_ae,[],4
 extbu d0
 cmp 4,d0
 beq 2f
 cmp 6,d0
 bne 8f
2:
 clr d0
 call ap_lens,[d2],8
 cmp 0,a0
 beq 8f
 movhu (ap_val),d0
 cmp 0x1001,d0                    /* the value's own range (a stop), whatever ap_ok said */
 bcc 8f
 mov d0,(4,sp)
 mov 1,d0
 movbu d0,(ap_used)
8:
 mov (4,sp),d0
 add 8,sp
 exth d0
 ret [],4

ap_chk:                           /* `call ap_chk,[d2,d3,a2,a3],20` from lg_pr (each shutter event, the HLS task):
                                   * once per power-on, behind the card gate: ap_on <- 2 when OM3MOD/NORING.TXT opens.
                                   * ap_n0 keeps the requests asked before it (start-up). No medium or the gate not
                                   * open: not checked (ap_ck 0), the ring stays on, tried again next event. */
 movbu (ap_ck),d0
 cmp 0,d0
 bne 9f
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f
 mov (ap_nask),d0
 mov d0,(ap_n0)
 mov 1,d0
 movbu d0,(ap_ck)
 mov ap_path,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 call fclose,[d2,a2,a3],16
 mov 2,d0
 movbu d0,(ap_on)
9:
 ret [d2,d3,a2,a3],20

/* lg_apn: `call lg_apn,[d2,d3,a2,a3],24`: NOW's "Aperture ring: on|off (NORING.TXT)[, card not read]; ring lens
 * yes|no; asked N (M before the first half-press), stops N, at A N, ignored N, short N, odd N; last word W, used in
 * A/M yes|no". */
lg_apn:
 LGS lg_ap0
 movbu (ap_on),d0
 mov lg_apw,a0
 call lg_nth,[],0
 call lg_s,[],0
 movbu (ap_ck),d0
 cmp 0,d0
 bne 2f
 LGS lg_apc
2:
 LGS lg_ap1
 clr d0
 mov (AP_LREC),a0
 mov a0,d1
 add 0x5e000000,d1
 cmp 0x01fffbaf,d1
 bcc 1f
 btst 3,d1
 bne 1f
 movbu (1096,a0),d1
 btst 0x80,d1
 beq 1f
 mov 1,d0
1:
 LGY
 LGS lg_ap2
 mov (ap_nask),d0
 LGD
 LGS lg_apb
 mov (ap_n0),d0
 LGD
 LGS lg_ap3
 mov (ap_nrng),d0
 LGD
 LGS lg_ap4
 mov (ap_na),d0
 LGD
 LGS lg_ap5
 mov (ap_nign),d0
 LGD
 LGS lg_ap6
 mov (ap_nbad),d0
 LGD
 LGS lg_ap7
 mov (ap_nodd),d0
 LGD
 LGS lg_ap8
 movhu (ap_val),d0
 LGD
 LGS lg_ap9
 movbu (ap_used),d0
 LGY
 ret [d2,d3,a2,a3],24

 .balign 4
ap_id:                            /* the lens ID our state belongs to (0 = none) */
 .long 0
ap_nask:                          /* requests with the ring bit */
 .long 0
ap_nrng:                          /* replies with a ring stop */
 .long 0
ap_na:                            /* replies with the ring at A */
 .long 0
ap_nign:                          /* replies exactly 2 short (the lens ignored the bit) */
 .long 0
ap_nbad:                          /* replies short by other than 2 (read as stock, asking stopped) */
 .long 0
ap_nodd:                          /* ring words that are not one (stopped asking) */
 .long 0
ap_n0:                            /* ap_nask when ap_chk ran: the requests before the first half-press */
 .long 0
ap_val:                           /* the last ring word (0x8000 = A) */
 .hword 0
ap_on:                            /* 1 on (from switch-on), 2 off (NORING.TXT, from the first shutter event) */
 .byte 1
ap_st:                            /* 0 ask, 2 this lens is not asked again */
 .byte 0
ap_ok:                            /* 1: ap_val is a stop for this lens */
 .byte 0
ap_used:                          /* 1: the getter has given the ring's value at least once this power-on */
 .byte 0
ap_ck:                            /* 1: ap_chk has read the card this power-on */
 .byte 0
ap_path:
 .asciz "C:\\OM3MOD\\NORING.TXT"
lg_ap0:
 .asciz "\r\nAperture ring: "
lg_apw:
 .ascii "not checked\000on\000off (NORING.TXT)\000"
lg_ap1:
 .asciz "; ring lens "
lg_ap2:
 .asciz "; asked "
lg_apb:
 .asciz " ("
lg_apc:
 .asciz ", card not read"
lg_ap3:
 .asciz " before the first half-press), stops "
lg_ap4:
 .asciz ", at A "
lg_ap5:
 .asciz ", ignored "
lg_ap6:
 .asciz ", short "
lg_ap7:
 .asciz ", odd "
lg_ap8:
 .asciz "; last word "
lg_ap9:
 .asciz ", used in A/M "
 .balign 4
