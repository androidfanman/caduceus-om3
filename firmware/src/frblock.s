/* Film Rolls on the card (feature/film-rolls-card, 2026-11-24; FILM-ROLLS-ROADMAP.md A3 / A4): the card file
 * OM3MOD/FILMROLL/FILMROLL.BIN, our own code. Film Rolls v2 r2b + r3 (feature/film-rolls-2: load, lock, count, the
 * frames left, rewind by the row, the shutter stop at a roll's end), moved off the flashed firmware into this block.
 * The flashed part (frcard.s) loads it at the first shutter event that may read the card, checks its tag (this
 * firmware's), calls entry 0 (relocate in place, start), then sends its stubs here. Linked at FB_LINK twice by build.py
 * make_frblock (as GUIDES.BIN's code block): every 32-bit field that moves is in the relocation list. Its symbols from
 * the firmware come from the firmware's own link (p.elf). Entries are 8 bytes apart; each keeps the frame and the
 * registers its stub documents (frcard.s).
 *
 * The roll record stays in the camera's memory M as r2 (task B1 moves it to the card). Film Rolls is on while this
 * block is loaded (rl_on 1): no FILMROLL.TXT any more.
 *
 * r2b / r3's notes, as they were: */
/* Film Rolls v2 (feature/film-rolls-2, round 1, 2026-11-21). Owner (2026-11-21): a roll of film you load, shoot and
 * rewind, as strict as a real roll; it lives with the SD card: only a card holding OM3MOD/FILMROLL.TXT (any content)
 * has Film Rolls (checked once a power-on, at the first shutter event with the films in, as DEBUG.TXT).
 *
 * Loading: the "Film Roll" row at the end of Picture Mode on COLOR 1-4 (RL_IT, class 18, bars RLB + k): None / 24 /
 * 36 / 72 (the length can change, or go back to None, until the first photo). Each half-press with a roll loaded
 * and nothing shot notes the film and ISO now (rl_arm; ISO Auto -> ISO 400, set then); the first photo starts the
 * roll with them. From then on: the film (sx_set 901 -> rl_lk; rc_go -> rl_fix, the family COLOR too; a half-press that finds
 * another film asks rc_go) and the ISO (sx_set 6 -> rl_lk; rl_hp / rl_fix put it back through the manager) stay the
 * roll's, in photo modes. Video is free.
 * Counting: ex_hook -> rl_shot, one per photo, RAM only, nothing past the roll's end. Frames left on the shooting
 * screen and viewfinder in the camera's shots-left number (screeninfo.s si_upd -> rl_upd at its end).
 * Rewind: on the row, turn the dial: the row's values 1..12 are the rewind's steps (it only goes forward); at 12 the
 * roll is out and the film / ISO are free again.
 * Record 'OM3F' at M + 0x3C800 (after Screen Info's 'OM3I' at +0x3C000, 40 B): +0 magic, +4 u16 1, +6 u16 20, +8 CRC-32
 * of 12..19, +12 roll 0 none / 1..3 = 24 / 36 / 72, +13 the film (901 value), +14 u16 frames shot, +16 u16 the ISO
 * setting (6: Sv x 256), +18 rewind steps 0..11, +19 0 (on the card since B1: version 3, 28 B, +20.. below: Image
 * Review, the first photo's number, the ISO from before the roll). Written as cm_wr writes (LOCK, UB_BUSY, both aliases,
 * UB_DIRTY) at the row and at a half-press. Nothing before the first shutter event (rl_on 0): never at start-up. */
 .set RL_MAGIC, 0x46334d4f        /* "OM3F" */
 .set RL_VER, 3                   /* D2: version 2 adds RL_IR; version 3 (28 B) RL_I6 / RL_I17. rl_rd still reads a
                                   * version 2 record (24 B, no ISO kept): a roll on the card is not lost */
 .set RL_LEN, 28
 .set RL_IR, 20                   /* D2: u16 Image Review (setting 19) to put back + 1, 0 none */
 .set RL_F1, 22                   /* u16 the camera's file counter at the half-press before the roll's first photo,
                                   * 0 not known (the roll log's photo numbers; owner, 2026-11-24) */
 .set RL_I6, 24                   /* owner (2026-11-26): "when the roll finishes it should go back to the previous iso
                                   * (in this example auto iso)": u16 the ISO in use (setting 6, 0 Auto) before the roll
                                   * set its own + 1, 0 none (rl_arms keeps it, rl_ibk puts it back) */
 .set RL_I17, 26                  /* u16 the ISO as picked (1701, 0 Auto) then, with RL_I6 */
 .set PRM_FILE, 41298             /* the camera's settings: PRM_DCFNUM_FILE, PRM_DCFNUM_FOLDER (their own debug */
 .set FC_OFF, 0                   /* counter -> the next photo's number: the counter is the next number (om-emu:
                                   * 1 on a new camera; to check against a camera's file names) */
 .set PRM_FOLDER, 41282           /* print at 0x608d7170.., read through 0x60063380 as here) */
 .set RL_N, 12
 .set RL_CH, 13
 .set RL_S, 14
 .set RL_ISO, 16
 .set RL_P, 18


 .am33_2
 .include "frsyms.inc"            /* the build's: FV0, NF (from the firmware) */
 .include "frscreens.inc"         /* the build's (firmware/mkscreens.py): SCREENS.BIN entries, SC_PAGE */
 .text
 .global _start
 .macro LGS s                     /* as editor.s: append the string at \s (uses d0, a0, a1) */
 mov \s,a0
 call lg_s,[],0
 .endm
 .macro LGD                       /* append d0 in decimal (uses d0, d1, a0, a1, MDR) */
 call lg_d,[d2,d3],12
 .endm
 .macro PVAL miss                 /* as editor.s */
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
 .macro OPT v, t, id              /* as editor.s: an option list entry */
 .long \v
 .short \t, \id
 .long 0x6154b480
 .endm
_start:
fb_base:
 jmp fb_reloc                     /* +0  relocate in place and start (fc_load: `calls`, a2 = P) -> d0 = the block */
 .balign 8
 jmp rl_hp                        /* +8  fc_hp: every shutter event, [d2,d3,a2,a3],24 */
 .balign 8
 jmp rl_fix                       /* +16 fc_fix: rc_go, [d2,d3,a2,a3],24 */
 .balign 8
 jmp rl_shot                      /* +24 fc_shot: ex_hook, [],0 */
 .balign 8
 jmp rl_lk                        /* +32 fc_lk: sx_set, [d2,d3,a2,a3],32 */
 .balign 8
 jmp rl_txt                       /* +40 fc_txt: lg_now, [d2,d3,a2,a3],24 */
 .balign 8
 jmp rl_upd                       /* +48 fc_upd: si_upd's end (the updater's frame) */
 .balign 8
 jmp rl_vs                        /* +56 rl_vg: the GUI variable setter, var 34 */
 .balign 8
 jmp rl_rel                       /* +64 fc_rel: ctrlRelease's release check, [],12 */
 .balign 8
 jmp rl_idle                      /* +72 fc_idle: the log writer task's quiet poll (B1), [d2,d3,a2,a3],24 */
 .balign 8
fb_nrel:
 .long 0                          /* +80 relocation count (written by the build) */
fb_oram:
 .long rl_ram - fb_base           /* +84 tools/test: where the roll's record copy is (rl_ram) */
fb_orel0:
 .long rl_rel0 - fb_base          /* +88 tools/test: the shutter's refusal */
fb_ovs:
 .long rl_vs - fb_base            /* +92 tools/test: the variable setter's entry */

/* rl_ld: `call rl_ld,[d2,d3,a2,a3],20`: the record into rl_ram, once per power-on (a bad record: no roll) */
rl_ld:                            /* B1 (owner: the roll belongs to the card): OM3MOD/FILMROLL/ROLL.BIN, else its copy
                                   * ROLL2.BIN (a write torn by a battery pull leaves the other); neither valid: no roll */
 movbu (rl_ok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(rl_ok)
 mov rl_pa,a0
 call rl_rd,[d2,d3,a2,a3],24
 cmp 0,d0
 beq 1f
 mov rl_pb,a0
 call rl_rd,[d2,d3,a2,a3],24
 cmp 0,d0
 bne 8f
 mov 2,d0
 movbu d0,(rl_v0)                 /* the copy was read */
 bra 2f
1:
 mov 1,d0
 movbu d0,(rl_v0)
2:
 mov rl_ram,a0
 mov rl_tmp,a1
 mov RL_LEN,d1
 call ub_cpy,[],0
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 7f
 cmp 4,d0
 bcc 8f
 movbu (rl_ram + RL_P),d0         /* frames wound back (the crank), at most a roll's length */
 cmp 73,d0
 bcc 8f
 movhu (rl_ram + RL_S),d0         /* nothing shot yet: no film of its own yet */
 cmp 0,d0
 beq 7f
 movbu (rl_ram + RL_CH),d0
 call rl_cok,[],0
 cmp 0,d1
 bne 7f
8:
 mov rl_ram,a0
 mov RL_LEN,d1
 call ub_zero,[],0
7:
 call rl_sync,[],0
9:
 ret [d2,d3,a2,a3],20

/* rl_irv: `call rl_irv,[d2,d3,a2,a3],24` from rl_hp (a shutter event, the HLS_EVENT task, as rl_arms' ISO write).
 * D2, owner (Q3): "turn image review off. you can't preview shots on a real roll of film". Image Review is setting 19
 * (om-emu, its menu screen: Off 0, 0.3 s 3, 1 s 10, ... in tenths of a second, Auto 255). A roll loaded: when it is
 * not Off, the first value seen is kept in the roll's record (RL_IR = value + 1: on the card, not the camera) and Off
 * is set (again at each half-press if turned back on). No roll and a value kept: it goes back, and is forgotten. */
rl_irv:
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 5f
 mov 19,d0
 call sget,[],4
 cmp 0,d0
 beq 9f
 movhu (rl_ram + RL_IR),d1
 cmp 0,d1
 bne 2f
 add 1,d0
 movhu d0,(rl_ram + RL_IR)
 mov 1,d0
 movbu d0,(rl_dw)
2:
 mov 19,d0
 clr d1
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rl_nir),d0
 inc d0
 mov d0,(rl_nir)
 bra 9f
5:
 movhu (rl_ram + RL_IR),d1
 cmp 0,d1
 beq 9f
 add -1,d1
 mov 19,d0
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 clr d0
 movhu d0,(rl_ram + RL_IR)
 mov 1,d0
 movbu d0,(rl_dw)
 mov (rl_nirb),d0
 inc d0
 mov d0,(rl_nirb)
9:
 ret [d2,d3,a2,a3],24

/* rl_ibk: `call rl_ibk,[d2,d3,a2,a3],24` from rl_hp after rl_irv (a shutter event, the HLS_EVENT task, as rl_arms' ISO
 * write). Owner (2026-11-26): "when the roll finishes it should go back to the previous iso (in this example auto
 * iso)". No roll (rewound and out at this shutter event, or the length back to None) and an ISO kept by rl_arms, in a
 * photo mode: settings 6 and 1701 back as they were (through the manager, each only when it differs) and the ISO is
 * forgotten. A roll loaded straight after another keeps the first one's: the ISO from before the rolls comes back. */
rl_ibk:
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 bne 9f
 movhu (rl_ram + RL_I6),d0
 cmp 0,d0
 beq 9f
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 call rl_pho,[],0
 cmp 0,d3
 beq 9f
 mov 6,d0
 call sget,[],4
 movhu (rl_ram + RL_I6),d1
 add -1,d1
 cmp d1,d0
 beq 1f
 mov 6,d0
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
1:
 mov 1701,d0
 call sget,[],4
 movhu (rl_ram + RL_I17),d1
 cmp d1,d0
 beq 2f
 mov 1701,d0
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
2:
 clr d0
 movhu d0,(rl_ram + RL_I6)
 movhu d0,(rl_ram + RL_I17)
 mov 1,d0
 movbu d0,(rl_dw)
 mov (rl_nib),d0
 inc d0
 mov d0,(rl_nib)
9:
 ret [d2,d3,a2,a3],24

/* rl_rd: `call rl_rd,[d2,d3,a2,a3],24`, a0 = the file's path -> d0 0 when it holds a valid record (now in rl_tmp),
 * else 1. The record: +0 "OM3F", +4 u16 version, +6 u16 its length, +8 CRC-32 of 12.., +12 the roll (r2's camera
 * record, now a file). Version 3 (28 B), or 2 (24 B: read with no ISO kept, RL_I6 / RL_I17 0) */
rl_rd:
 mov a0,a2
 mov rl_tmp,a0                    /* a version 2 record leaves the new fields 0 */
 mov RL_LEN,d1
 call ub_zero,[],0
 mov a2,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq 8f
 mov a0,a3
 mov rl_tmp,a0
 mov 1,d0
 mov RL_LEN,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov a3,a0
 call fclose,[d2,a2,a3],16
 mov rl_tmp,a3
 mov (a3),d0
 cmp RL_MAGIC,d0
 bne 8f
 movhu (4,a3),d0
 movhu (6,a3),d1
 cmp RL_VER,d0
 beq 1f
 cmp 2,d0
 bne 8f
 cmp 24,d1
 bne 8f
 bra 2f
1:
 cmp RL_LEN,d1
 bne 8f
2:
 cmp d1,d2                        /* the bytes read are its length */
 bne 8f
 add -12,d1
 mov -1,d0
 mov a3,a0
 add 12,a0
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 8f
 clr d0
 ret [d2,d3,a2,a3],24
8:
 mov 1,d0
 ret [d2,d3,a2,a3],24

rl_cok:                           /* `call rl_cok,[],0`: d0 a 901 value -> d1 1 when COLOR 1..4 or a film, else 0 */
 mov 1,d1
 cmp 54,d0
 beq 9f
 cmp 55,d0
 beq 9f
 cmp 56,d0
 beq 9f
 cmp 64,d0
 beq 9f
 cmp FV0,d0
 bcs 8f
 cmp FV0 + NF,d0
 bcs 9f
8:
 clr d1
9:
 ret [],0

rl_sync:                          /* `call rl_sync,[],0`: the row's count (4: None / 24 / 36 / 72) and value (the roll's
                                   * length, 0 None). Uses d0 */
 movbu (rl_ram + RL_N),d0
 movbu d0,(fc_rval)
 cmp 0,d0                         /* fc_lock: 0 no roll or nothing shot, 1 a roll with frames shot (D1: no Playback), */
 beq 1f                           /* 2 its end (D3: OK rewinds) */
 movhu (rl_ram + RL_S),d0
 cmp 0,d0
 beq 1f
 movm [d2,d3,a2],(sp)             /* (no call while they are on the stack: a call writes at (0,sp)) */
 movbu (rl_ram + RL_N),d2
 and 3,d2
 add rl_lens,d2
 mov d2,a2
 movbu (a2),d2                    /* the length */
 movhu (rl_ram + RL_S),d3
 cmp d2,d3
 mov 1,d0
 bcs 2f
 mov 2,d0
2:
 movbu (rl_ram + RL_P),d2         /* winding or rewound: the value is where the cursor is (rl_cur, rl_row) */
 cmp 0,d2
 beq 3f
 movbu (rl_cur),d2
 movbu d2,(fc_rval)
3:
 movm (sp),[d2,d3,a2]
1:
 movbu d0,(fc_lock)
 ret [],0

/* rl_wr: `call rl_wr,[d2,d3,a2,a3],20`: B1: the roll is to be written to the card; the log writer task does it
 * (rl_idle), never this task. Uses d0 */
rl_wr:
 mov 1,d0
 movbu d0,(rl_dw)
 ret [d2,d3,a2,a3],20

/* rl_idle <- fc_idle (`call fc_idle,[d2,d3,a2,a3],24` from lg_wk, task CADLOG, at a poll with the shutter button up
 * and no shutter event since the last one, #85's rule): when the roll changed (rl_dw), a copy taken under LOCK (rl_dw
 * cleared first, so a frame counted meanwhile marks it again), its header and CRC, then ROLL.BIN and its copy ROLL2.BIN
 * (20 B each, fixed size: the camera's "w" does not shorten a file). Only in OM3MOD/FILMROLL/. */
rl_idle:
 movbu (rl_dw),d0
 cmp 0,d0
 beq 9f
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 clr d0
 movbu d0,(rl_dw)
 mov rl_wbuf,a0
 mov rl_ram,a1
 mov RL_LEN,d1
 call ub_cpy,[],0
 mov d3,d0
 call UNLOCK,[d2],8
 mov RL_MAGIC,d0
 mov d0,(rl_wbuf)
 mov RL_VER,d0
 movhu d0,(rl_wbuf + 4)
 mov RL_LEN,d0
 movhu d0,(rl_wbuf + 6)
 mov -1,d0
 mov rl_wbuf + 12,a0
 mov RL_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(rl_wbuf + 8)
 mov rl_pa,a0
 call rl_wf,[d2,d3,a2,a3],20
 mov rl_pb,a0
 call rl_wf,[d2,d3,a2,a3],20
 mov (rl_nw),d0
 inc d0
 mov d0,(rl_nw)
9:
 movbu (rl_lw),d0                 /* B3: a finished roll for the log */
 cmp 0,d0
 beq 8f
 clr d0
 movbu d0,(rl_lw)
 call rl_log,[d2,d3,a2,a3],24
8:
 movbu (rl_on),d0                 /* the drawing: a rewind step or a roll's end changes it between shutter events */
 cmp 1,d0
 bne 7f
 call fb_art,[d2,d3,a2,a3],64
7:
 ret [d2,d3,a2,a3],24

/* rl_log: `call rl_log,[d2,d3,a2,a3],24` (the log writer task): B3, owner (Q6): the photos stay where the camera puts
 * them; OM3MOD/FILMROLL/ROLLS.TXT gets a line per finished roll ("Roll 005, FILM 15, ISO 400, 24 exp, 24 shot").
 * The file is read (up to RL_LB), the new line added, the oldest lines dropped when it would pass RL_LB, and written
 * back; never shorter than it was (padded with spaces: the camera's "w" does not shorten a file). d2 = its length. */
 .set RL_LB, 3072
rl_log:
 mov (rl_lbp),a0                  /* no heap buffer: no log line */
 cmp 0,a0
 bne 0f
 ret [d2,d3,a2,a3],24
0:
 mov rl_line,a1                   /* the line */
 mov rl_s_roll2,a0
 call rl_aa,[],0
 movbu (rl_ls + 6),d0
 mov 3,d1
 call rl_dd,[],0
 movbu (rl_ls + 1),d0
 cmp FV0,d0
 bcs 1f
 add -FV0 + 1,d0
 mov d0,(rl_lsv)
 mov rl_s_lfilm,a0
 call rl_aa,[],0
 bra 2f
1:
 mov a1,(rl_lsp)
 call fl_k,[],0
 mov (rl_lsp),a1
 add 1,d0
 mov d0,(rl_lsv)
 mov rl_s_lcol,a0
 call rl_aa,[],0
2:
 mov (rl_lsv),d0
 clr d1
 call rl_dd,[],0
 mov rl_s_liso,a0
 call rl_aa,[],0
 movhu (rl_ls + 4),d0
 mov a1,(rl_lsp)
 call rl_isov,[],0
 mov (rl_lsp),a1
 clr d1
 call rl_dd,[],0
 mov rl_s_sep2,a0
 call rl_aa,[],0
 movbu (rl_ls),d0
 and 3,d0
 add rl_lens,d0
 mov d0,a0
 movbu (a0),d0
 clr d1
 call rl_dd,[],0
 mov rl_s_lexp,a0
 call rl_aa,[],0
 movhu (rl_ls + 2),d0
 clr d1
 call rl_dd,[],0
 mov rl_s_lshot,a0
 call rl_aa,[],0
 movhu (rl_ls + 8),d0             /* the photos' numbers, when the counter was read before the first photo */
 cmp 0,d0
 beq 7f
 add -2,a1                        /* over the line's CR LF */
 mov rl_s_lph,a0
 call rl_aa,[],0
 movhu (rl_ls + 8),d0
 add FC_OFF,d0                    /* the first photo's own number (FC_OFF: counter -> number) */
 mov 4,d1
 call rl_dd,[],0
 mov rl_s_lto,a0
 call rl_aa,[],0
 movhu (rl_ls + 8),d0
 add FC_OFF - 1,d0
 movhu (rl_ls + 2),d1
 add d1,d0
 mov 4,d1
 call rl_dd,[],0
 mov rl_s_lfd,a0
 call rl_aa,[],0
 movhu (rl_ls + 10),d0
 clr d1
 call rl_dd,[],0
 mov rl_s_crlf,a0
 call rl_aa,[],0
7:
 mov a1,d0
 add -rl_line,d0
 mov d0,(rl_llen)
 clr d2                           /* the file as it is */
 mov rl_plog,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq 3f
 mov a0,a3
 mov (rl_lbp),a0
 mov 1,d0
 mov RL_LB,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov a3,a0
 call fclose,[d2,a2,a3],16
 cmp RL_LB + 1,d2
 bcs 3f
 clr d2
3:
 mov d2,(rl_lold)
4:                                /* room: drop the oldest line while the new one would not fit */
 mov (rl_llen),d0
 add d2,d0
 cmp RL_LB + 1,d0
 bcs 6f
 mov (rl_lbp),a0                   /* the first line's end */
 clr d3
5:
 cmp d2,d3
 bcc 51f
 movbu (a0),d0
 inc d3
 add 1,a0
 cmp 10,d0
 bne 5b
51:
 cmp 0,d3
 beq 6f
 mov (rl_lbp),a1                   /* the rest down to the start */
 mov d2,d0
 sub d3,d0
52:
 cmp 0,d0
 beq 53f
 movbu (a0),d1
 movbu d1,(a1)
 add 1,a0
 add 1,a1
 add -1,d0
 bra 52b
53:
 sub d3,d2
 bra 4b
6:
 mov (rl_lbp),a1                   /* the new line after the others */
 add d2,a1
 mov rl_line,a0
 mov (rl_llen),d0
 add d0,d2
61:
 cmp 0,d0
 beq 62f
 movbu (a0),d1
 movbu d1,(a1)
 add 1,a0
 add 1,a1
 add -1,d0
 bra 61b
62:
 mov (rl_lold),d0                 /* never shorter than it was */
 cmp d0,d2
 bcc 63f
 mov 32,d1
 movbu d1,(a1)
 add 1,a1
 inc d2
 bra 62b
63:
 mov rl_plog,a0
 mov lg_mw,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,a3
 mov (rl_lbp),a0
 mov 1,d0
 mov d2,d1
 mov a3,a1
 call fwrite,[d2,d3,a2,a3],24
 mov a3,a0
 call fclose,[d2,a2,a3],16
 mov (rl_nlg),d0
 inc d0
 mov d0,(rl_nlg)
9:
 ret [d2,d3,a2,a3],24

/* rl_aa: `call rl_aa,[],0`: the ASCII string at a0 copied to a1 (a1 left after it, no NUL). Uses d1 */
rl_aa:
 movbu (a0),d1
 cmp 0,d1
 beq 9f
 movbu d1,(a1)
 add 1,a0
 add 1,a1
 bra rl_aa
9:
 ret [],0
/* rl_dd: `call rl_dd,[],0`: d0 in decimal at a1, at least d1 digits (leading zeros), a1 left after it. Uses d0, d1,
 * a0, MDR */
rl_dd:
 mov d1,(rl_dmin)
 mov rl_dge2,a0
1:
 clr d1
 mov d1,mdr
 mov 10,d1
 divu d1,d0
 mov mdr,d1
 add 48,d1
 add -1,a0
 movbu d1,(a0)
 mov (rl_dmin),d1
 add -1,d1
 mov d1,(rl_dmin)
 cmp 0,d0
 bne 1b
 cmp 0,d1
 bgt 1b
2:
 movbu (a0),d1
 movbu d1,(a1)
 add 1,a1
 add 1,a0
 cmp rl_dge2,a0
 bne 2b
 ret [],0

/* rl_wf: `call rl_wf,[d2,d3,a2,a3],20`, a0 = the path: rl_wbuf written there (fopen "w", fwrite, fclose) */
rl_wf:
 mov lg_mw,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,a3
 mov rl_wbuf,a0
 mov 1,d0
 mov RL_LEN,d1
 mov a3,a1
 call fwrite,[d2,d3,a2,a3],24
 mov a3,a0
 call fclose,[d2,a2,a3],16
9:
 ret [d2,d3,a2,a3],20

/* rl_pho: `call rl_pho,[],0` -> d3 1 in a photo mode or a mode not known yet, else 0 (video). Uses d3, a3. The mode's
 * code (cm_gnow): P A S M B 1..5, C1..C5 53..57 */
rl_pho:
 mov (rc_in),a3
 cmp 0,a3
 beq 8f
 movbu (24,a3),d3
 cmp 0,d3
 beq 8f
 cmp 6,d3
 bcs 8f
 cmp 53,d3
 bcs 7f
 cmp 58,d3
 bcs 8f
7:
 clr d3
 ret [],0
8:
 mov 1,d3
 ret [],0

/* rl_act: `call rl_act,[],0` -> d3 1 when Film Rolls is on, a roll is in, the films are in (cm_init) and the camera
 * is in a photo mode, else 0. Uses d3, a3 */
rl_act:
 movbu (rl_on),d3
 cmp 1,d3
 bne 9f
 movbu (rl_ram + RL_N),d3
 cmp 0,d3
 beq 9f
 movhu (rl_ram + RL_S),d3         /* the lock starts with the first photo */
 cmp 0,d3
 beq 9f
 movbu (cm_init),d3
 cmp 0,d3
 beq 9f
 jmp rl_pho
9:
 clr d3
 ret [],0

/* rl_fcr: `call rl_fcr,[d2,d3,a2,a3],24` from rl_hp (every shutter event, a roll on): the camera's file counter and
 * folder (rl_fcn, rl_fdn). rl_shot keeps rl_fcn as the roll's first photo's (RL_F1). */
rl_fcr:
 mov PRM_FILE,d0
 clr d1
 mov 0,a0
 call nf_get,[d2,d3],12
 movhu d0,(rl_fcn)
 mov PRM_FOLDER,d0
 clr d1
 mov 0,a0
 call nf_get,[d2,d3],12
 movhu d0,(rl_fdn)
 ret [d2,d3,a2,a3],24

rl_clr:                           /* `call rl_clr,[],0`: the roll is out. Uses d0. B3: a roll with frames shot is noted
                                   * for the roll log (rl_ls; the log writer task writes the line, rl_idle) */
 movhu (rl_ram + RL_S),d0
 cmp 0,d0
 beq 1f
 movhu d0,(rl_ls + 2)
 movbu (rl_ram + RL_N),d0
 movbu d0,(rl_ls)
 movbu (rl_ram + RL_CH),d0
 movbu d0,(rl_ls + 1)
 movhu (rl_ram + RL_ISO),d0
 movhu d0,(rl_ls + 4)
 movbu (rl_ram + 19),d0
 movbu d0,(rl_ls + 6)
 movhu (rl_ram + RL_F1),d0
 movhu d0,(rl_ls + 8)
 movhu (rl_fdn),d0
 movhu d0,(rl_ls + 10)
 mov 1,d0
 movbu d0,(rl_lw)
1:
 clr d0
 movbu d0,(rl_ram + RL_N)
 movbu d0,(rl_ram + RL_CH)
 movhu d0,(rl_ram + RL_S)
 movhu d0,(rl_ram + RL_ISO)
 movbu d0,(rl_ram + RL_P)
 movhu d0,(rl_ram + RL_F1)
 mov (rl_ne),d0
 inc d0
 mov d0,(rl_ne)
 mov 1,d0
 movbu d0,(rl_dw)
 ret [],0

/* rl_shot: `call rl_shot,[],0` from ex_hook (once per photo, in the capture): a roll that is in counts a frame, in a
 * photo mode, until its end, not while it is being rewound. RAM only, no settings calls, no calls. Uses d0, d1, a0 */
rl_shot:
 movbu (rl_on),d0
 cmp 1,d0
 bne 9f
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 9f
 movbu (rl_ram + RL_P),d1
 cmp 0,d1
 bne 9f
 movhu (rl_ram + RL_S),d1         /* the first photo: the film and ISO noted at the half-press (none: not counted) */
 cmp 0,d1
 bne 2f
 movbu (rl_arm),d1
 cmp 0,d1
 beq 9f
2:
 and 3,d0
 mov rl_lens,a0
 add d0,a0
 movbu (a0),d1
 movhu (rl_ram + RL_S),d0
 cmp d1,d0
 bcc 9f
 mov (rc_in),a0
 cmp 0,a0
 beq 1f
 movbu (24,a0),d1
 cmp 0,d1
 beq 1f
 cmp 6,d1
 bcs 1f
 cmp 53,d1
 bcs 9f
 cmp 58,d1
 bcc 9f
1:
 cmp 0,d0
 bne 3f
 movbu (rl_ram + 19),d1          /* B3: the roll's number (record +19), kept over rewinds */
 inc d1
 movbu d1,(rl_ram + 19)
 movbu (rl_ach),d1
 movbu d1,(rl_ram + RL_CH)
 movhu (rl_aiso),d1
 movhu d1,(rl_ram + RL_ISO)
 movhu (rl_fcn),d1                /* the file counter noted at the half-press before this photo */
 movhu d1,(rl_ram + RL_F1)
 clr d1
 movbu d1,(rl_arm)
 mov (rl_nst),d1
 inc d1
 mov d1,(rl_nst)
3:
 inc d0
 movhu d0,(rl_ram + RL_S)
 mov 1,d1                         /* D1: from the first frame, no Playback until the rewind; D3: 2 at the end */
 movbu (rl_ram + RL_N),d1
 and 3,d1
 add rl_lens,d1
 mov d1,a0
 movbu (a0),d1                    /* the length; d0 = frames shot now */
 cmp d1,d0
 mov 1,d1
 bcs 4f
 mov 2,d1
4:
 movbu d1,(fc_lock)
 mov 1,d0
 movbu d0,(rl_dw)
 mov (rl_ns),d0
 inc d0
 mov d0,(rl_ns)
9:
 ret [],0

/* rl_lk: `call rl_lk,[d2,d3,a2,a3],32` from sx_set: d0 901 or 6, d1 the value -> d1 the value to set (the roll's film or
 * ISO while a roll holds them, else as it came); d0, a0, a1 kept. Locals (4) a0, (8) a1, (12) d0, (16) d1 */
rl_lk:
 mov a0,(4,sp)
 mov a1,(8,sp)
 mov d0,(12,sp)
 mov d1,(16,sp)
 call rl_act,[],0
 cmp 0,d3
 beq 8f
 mov (12,sp),d0
 cmp 6,d0
 bne 2f
 movhu (rl_ram + RL_ISO),d1
 bra 5f
2:
 movbu (rl_ram + RL_CH),d1
5:
 mov (16,sp),d0
 cmp d0,d1
 beq 9f
 mov (rl_nl),d0
 inc d0
 mov d0,(rl_nl)
 bra 9f
8:
 mov (16,sp),d1
9:
 mov (4,sp),a0
 mov (8,sp),a1
 mov (12,sp),d0
 ret [d2,d3,a2,a3],32

/* rl_iset: `call rl_iset,[d2,d3,a2,a3],20`: the camera's ISO back to the roll's when it differs (through the manager) */
rl_iset:
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 mov 6,d0
 call sget,[],4
 movhu (rl_ram + RL_ISO),d1
 cmp 0,d1
 beq 9f
 cmp d1,d0
 beq 8f
 mov 6,d0
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rl_ni),d0
 inc d0
 mov d0,(rl_ni)
8:
 movhu (rl_ram + RL_ISO),d1       /* and 1701, the ISO the camera shows as set (2026-11-25) */
 call rl_i17,[d2,d3,a2,a3],24
9:
 ret [d2,d3,a2,a3],20

/* rl_i17: `call rl_i17,[d2,d3,a2,a3],24`, d1 an ISO (Sv x 256): setting 1701 to it, through the manager, when it is not
 * already. Owner (test 8): "it does lock the iso at 400 but in the super control panel it displays auto 1792". The
 * camera keeps ISO twice: 6 (the one in use; what rl_arms / rl_iset wrote) and 1701, the one picked (0 = Auto): its own
 * ISO screen steps 1701 (SetValue(1701, mode 1) -> 0x603f038b) and the core sets both; om-emu, ISO 400 picked in the
 * super control panel: 6 = 1792, 1701 = 1792; a roll's write of 6 alone: 1701 = 0, so the panel shows Auto. Local (4) */
rl_i17:
 mov d1,(4,sp)
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 mov 1701,d0
 call sget,[],4
 mov (4,sp),d1
 cmp d1,d0
 beq 9f
 mov 1701,d0
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rl_n17),d0
 inc d0
 mov d0,(rl_n17)
9:
 ret [d2,d3,a2,a3],24

/* rl_fix: `call rl_fix,[d2,d3,a2,a3],24` from rc_go after cm_go (a2 = P, films in): a roll's ISO, family COLOR and
 * film back when something changed them (a custom mode, a reset, the Creative Dial). A film that is gone takes the
 * roll out (always a way out). */
rl_fix:
 call rl_act,[],0
 cmp 0,d3
 beq 9f
 call rl_iset,[d2,d3,a2,a3],20
 mov 897,d0
 call sget,[],4
 cmp 901,d0
 beq 05f
 mov 897,d0
 mov 901,d1
 mov (rc_in),a0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rl_nk),d0
 inc d0
 mov d0,(rl_nk)
05:
 call cm_val,[d2,d3,a2,a3],20
 movbu (rl_ram + RL_CH),d1
 cmp d1,d0
 beq 9f
 clr d2                           /* rl_l4 <- P+LIDX */
1:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d0
 mov rl_l4,a0
 add d2,a0
 movbu d0,(a0)
 inc d2
 cmp 4,d2
 bcs 1b
 movbu (rl_ram + RL_CH),d0
 cmp FV0,d0
 bcs 3f
 add -FV0,d0                      /* film j: COLOR k = j / 5 gets look j % 5 + 1, if the film is still there */
 mov d0,d3
 mov (LPTR,a2),a0
 call fl_has,[],0
 cmp 0,d0
 beq 7f
 mov d3,d0
 clr d2
2:
 cmp 5,d0
 bcs 21f
 add -5,d0
 inc d2
 bra 2b
21:
 inc d0
 bra 4f
3:
 call fl_k,[],0                   /* COLOR k itself: look 0 there */
 cmp 0,d0
 blt 7f
 mov d0,d2
 clr d0
4:
 mov rl_l4,a0
 add d2,a0
 movbu d0,(a0)
 mov rl_l4,a3
 movbu (rl_ram + RL_CH),d1
 call cm_load,[d2,d3,a2,a3],24
 mov (rl_nf),d0
 inc d0
 mov d0,(rl_nf)
 bra 9f
7:
 call rl_clr,[],0
 call rl_sync,[],0
9:
 ret [d2,d3,a2,a3],24

/* rl_hp: `call rl_hp,[d2,d3,a2,a3],24` from lg_pr (every shutter event, HLS_EVENT task): the card's FILMROLL.TXT once,
 * the record once, the ISO and film checks, the record into M */
rl_hp:
 call dm_ok,[],0
 cmp 0,d1
 beq 9f
 movbu (rl_on),d0
 cmp 1,d0
 bne 9f
 call rl_ld,[d2,d3,a2,a3],20
 movbu (rl_ram + RL_P),d0         /* at a shutter event: a rewound roll comes out; a crank not finished ends (the roll */
 cmp 0,d0                         /* stays, as before it) */
 beq 2f
 movhu (rl_ram + RL_S),d1
 cmp d1,d0
 bcs 3f
 call rl_clr,[],0
 bra 2f
3:
 clr d0
 movbu d0,(rl_ram + RL_P)
 mov 1,d0
 movbu d0,(rl_dw)
2:
 call rl_sync,[],0
 call rl_irv,[d2,d3,a2,a3],24     /* D2: Image Review off while a roll is in, back after it */
 call rl_ibk,[d2,d3,a2,a3],24     /* and the ISO from before the roll back after it (owner, 2026-11-26) */
 movbu (lg_on),d0                 /* B1: the roll is written by the log writer task (lg_wk); with the debug log off */
 cmp 2,d0                         /* (no DEBUG.TXT: lg_on 2, known from the second shutter event) and none made yet, */
 bne 1f                           /* make it here (this is the HLS_EVENT task, as lg_write's own lg_mkw) */
 mov (lg_tid),d0
 cmp 0,d0
 bne 1f
 call lg_mkw,[d2,d3,a2,a3],32
1:
 call rl_arms,[d2,d3,a2,a3],76
 call rl_fcr,[d2,d3,a2,a3],24     /* the file counter and folder, for the roll log */
 call fb_art,[d2,d3,a2,a3],64     /* E1: the roll's drawing for its film and length, or a screen */
 call rl_act,[],0
 cmp 0,d3
 beq 8f
 call rl_iset,[d2,d3,a2,a3],20
 PVAL 8f
 call cm_val,[d2,d3,a2,a3],20
 movbu (rl_ram + RL_CH),d1
 cmp d1,d0
 beq 8f
 mov 1,d0                         /* another film: rc_go puts the roll's back at the next GUI event (rl_fix) */
 movbu d0,(rc_pend)
 mov (rl_nq),d0
 inc d0
 mov d0,(rl_nq)
8:
 movbu (rl_dw),d0
 cmp 0,d0
 beq 9f
 call rl_wr,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],24

/* rl_arms: `call rl_arms,[d2,d3,a2,a3],76` from rl_hp: a roll loaded with nothing shot, in a photo mode on COLOR 1-4:
 * its film and ISO now are noted for the first photo (ISO Auto: set to ISO 400 now, the roll's box speed) */
rl_arms:
 clr d0
 movbu d0,(rl_arm)
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 9f
 movhu (rl_ram + RL_S),d0
 cmp 0,d0
 bne 9f
 call rl_pho,[],0
 cmp 0,d3
 beq 9f
 PVAL 9f
 call cm_val,[d2,d3,a2,a3],20
 mov d0,d2
 call rl_cok,[],0
 cmp 0,d1
 beq 9f
 movbu d2,(rl_ach)
 mov 1792,d3                      /* owner (2026-11-24): a roll's ISO is fixed: a film's box speed, never below 200;
                                   * COLOR 1-4: 400 (1792) */
 mov d2,d0
 add -FV0,d0
 cmp NF,d0
 bcc 2f
 mov d0,(4,sp)                    /* FILM j: its ISO from ROLLART.BIN's table (owner, 2026-11-25: LookLab's own films
                                   * carry their ISO). At 8 + 8 x 96: 'OM3I', then 24 u16, the ISO setting (Sv x 256) of
                                   * FILM 1..20, COLOR 1..4 (firmware/mkrollpath.py rollart; LookLab writes the same).
                                   * Locals (8..51) the tag and FILM 1..20 */
 mov fb_part,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq 2f
 mov a0,a3
 mov 8 + 8 * 96,d0
 mov 2,d1                         /* SET; a miss reads the file's start: not the tag */
 call fseek,[d2,d3,a2,a3],20
 mov sp,a0
 add 8,a0
 mov 1,d0
 mov 44,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov a3,a0
 call fclose,[d2,a2,a3],16
 mov 1792,d3                      /* no table, a short read or a value out of 200 .. 6400: 400 */
 cmp 44,d2
 bne 2f
 mov (8,sp),d0
 cmp 0x49334d4f,d0                /* 'OM3I' */
 bne 2f
 mov (4,sp),d0
 add d0,d0
 mov sp,a0
 add d0,a0
 movhu (12,a0),d0
 cmp 1536,d0
 bcs 2f
 cmp 2817,d0
 bcc 2f
 mov d0,d3
2:
 mov d3,(4,sp)
 mov (rc_in),a0                   /* no manager: nothing is set below either, so nothing to keep yet */
 cmp 0,a0
 beq 1f
 movhu (rl_ram + RL_I6),d0        /* the ISO before the roll, kept once on the card (owner, 2026-11-26), for rl_ibk */
 cmp 0,d0
 bne 1f
 mov 1701,d0
 call sget,[],4
 movhu d0,(rl_ram + RL_I17)
 mov 6,d0
 call sget,[],4
 add 1,d0
 movhu d0,(rl_ram + RL_I6)
 mov 1,d0
 movbu d0,(rl_dw)
1:
 mov 6,d0
 call sget,[],4
 mov (4,sp),d1
 cmp d1,d0
 beq 4f
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 mov 6,d0
 mov 0,a1
 call manager,[d2,d3,a2,a3],68
 mov (rl_ni),d0
 inc d0
 mov d0,(rl_ni)
4:
 mov (4,sp),d1                    /* and 1701 (rl_i17) */
 call rl_i17,[d2,d3,a2,a3],24
 mov (4,sp),d0
3:
 movhu d0,(rl_aiso)
 mov 1,d0
 movbu d0,(rl_arm)
9:
 ret [d2,d3,a2,a3],76

/* rl_row: `call rl_row,[d2,d3,a2,a3],40` from sl_set0 (class 18), d1 the new value -> d1 0 stored, 1 refused. Keeps
 * d0, a0, a1 (s_dirty reads them) and a2. Locals (4) d0, (8) a0, (12) a1, (16) the value */
rl_row:
 mov d0,(4,sp)
 mov a0,(8,sp)
 mov a1,(12,sp)
 mov d1,(16,sp)
 movbu (rl_on),d0
 cmp 1,d0
 bne 8f
 call rl_ld,[d2,d3,a2,a3],20
 mov (16,sp),d3
 cmp 4,d3                         /* r2 (owner): None / 24 / 36 / 72 */
 bcc 8f
 movhu (rl_ram + RL_S),d0
 cmp 0,d0
 bne 20f                          /* frames shot: the crank */
 movbu (rl_ram + RL_N),d0
 cmp d0,d3
 beq 7f
3:
 movbu d3,(rl_ram + RL_N)
 clr d0
 movbu d0,(rl_ram + RL_CH)
 movhu d0,(rl_ram + RL_S)
 movhu d0,(rl_ram + RL_ISO)
 movbu d0,(rl_ram + RL_P)
 movhu d0,(rl_ram + RL_F1)
 movbu d0,(rl_arm)
 mov (rl_nld),d0
 inc d0
 mov d0,(rl_nld)
6:
 mov 1,d0
 movbu d0,(rl_dw)
 mov (fb_req),d0                  /* test 12: the drawing to follow this value (fb_art's next run; fb_tr13 waits) */
 inc d0
 mov d0,(fb_req)
 call rl_wr,[d2,d3,a2,a3],20
7:
 call rl_sync,[],0
 clr d1
 bra 9f
8:
 mov 1,d1
9:
 mov (4,sp),d0
 mov (8,sp),a0
 mov (12,sp),a1
 ret [d2,d3,a2,a3],40
/* the crank (owner, 2026-11-25: "Crank, 3 clicks"; "make it based on the photos you took (24 times for 24 shots,
 * etc.)"; "the wind wind looks silly. perhaps we can hide that durning the winding?"; after it "it only displays none and
 * 24"): with frames shot every change of the row's value winds one frame back (RL_P, fb_art's rewind panel; the cells
 * blank meanwhile, rl_str), the value where the cursor is (rl_cur). The last frame leaves the roll rewound (RL_P =
 * shot): the cells None / 24 / 36 / 72 again, and the next change takes it out and loads that value (None: no roll);
 * a shutter event takes a rewound roll out too (rl_hp) */
20:
 movbu (rl_ram + RL_P),d0
 movhu (rl_ram + RL_S),d1
 cmp d1,d0
 bcc 23f
 movbu (rl_ram + RL_N),d1         /* the cursor: on the roll's length until the first click */
 cmp 0,d0
 beq 21f
 movbu (rl_cur),d1
21:
 cmp d1,d3
 beq 7b
 movbu d3,(rl_cur)
 add 2,d0                         /* owner (test 33): "can we have every click be worth 2 rewinds. so 24 would require */
 movhu (rl_ram + RL_S),d1         /* 12 clicks" (an odd count's last click: 1) */
 cmp d1,d0
 bls 22f
 mov d1,d0
22:
 movbu d0,(rl_ram + RL_P)
 bra 6b
23:
 movbu (rl_cur),d1                /* rewound: a value picked */
 cmp d1,d3
 beq 7b
 call rl_clr,[],0
 bra 3b

/* rl_def: fl_isdef's answer for our bars: always as built (no '*', no Reset guide). */

/* rl_upd <- jmp from screeninfo.s si_upd's end, the updater's frame as at .hook_si: on a roll in a photo mode, the
 * shots-left number (var 34 +8, u16; its buffer at (8,sp)) = the frames left, when the camera shows it (+12). Uses d0,
 * d1, a0 (the stock code reloads them). */
rl_upd:
 mov 1,d1
 movbu d1,(rl_ur)
 movhu (STATE),d0
 cmp 0,d0
 beq 9f
 movhu (LG_GUI),d0                /* r2b: the shooting screen only (GUI state 0x0801), as rl_vs */
 cmp 0x0801,d0
 bne 9f
 mov 2,d1
 movbu d1,(rl_ur)
 movbu (rl_on),d0
 cmp 1,d0
 bne 9f
 mov 3,d1
 movbu d1,(rl_ur)
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 9f
 mov 4,d1
 movbu d1,(rl_ur)
 mov (12,sp),a0                   /* the updater's `this`: (2116,this) 1 = movie (as Screen Info's split) */
 cmp 0,a0
 beq 9f
 mov (2116,a0),d1
 movbu d1,(rl_um)
 cmp 1,d1
 beq 9f
 mov 5,d1
 movbu d1,(rl_ur)
 and 3,d0
 mov rl_lens,a0
 add d0,a0
 movbu (a0),d0
 movhu (rl_ram + RL_S),d1
 sub d1,d0
 cmp 0,d0
 bge 2f
 clr d0
2:
 mov (8,sp),a0                    /* var 34's buffer */
 cmp 0,a0
 beq 9f
 mov 6,d1
 movbu d1,(rl_ur)
 movhu (8,a0),d1                  /* r2: the camera has a number there (Image Only clears the field; viewfinder Styles
                                   * 1 / 2 draw it with +12 at 0, so +12 is not the test) */
 cmp 0,d1
 beq 9f
 mov 7,d1
 movbu d1,(rl_ur)
 movhu d0,(8,a0)
 mov (rl_nu),d0
 inc d0
 mov d0,(rl_nu)
9:
 mov 0x62ceeb54,a0                /* the 6 bytes .hook_si replaced */
 jmp si_back

/* rl_vs <- .hook_rv (jmp), the GUI variable setter 0x610cd5c4 at its start (entered as `call ..,[d2,a2],16`: d0 the
 * variable, a0 its new value, a1 / d1 the setter's): for var 34 (the top row: shots left at +8, u16) with a roll in,
 * the frames left in place of the card's number when the camera has a number there. Every screen and viewfinder style
 * sets it through here (viewfinder Styles 1 / 2 too, where the shooting screen's updater, rl_upd, does not run: r1's
 * camera test). Uses d2, a2 only (the setter loads both itself after these 7 bytes). Nothing before the first
 * half-press (rl_on 0) or the films (STATE). The hook enters rl_vg in .ext4 (section 4), which runs only the stock
 * instructions for every other variable, and for var 34 before section 6 is in. */
rl_vs:
 movbu (rl_on),d2
 cmp 1,d2
 bne 9f
 movhu (LG_GUI),d2                /* r2b (r2 froze the camera in playback, owner): the shooting screen only, GUI state
                                   * 0x0801 (COMMON / 8; the viewfinder's styles too). Playback, menus and anything else
                                   * keep var 34 as the camera sets it (there it may mean something else) */
 cmp 0x0801,d2
 bne 9f
 movhu (STATE),d2
 cmp 0,d2
 beq 9f
 movhu (8,a0),d2                  /* the camera has a number there */
 cmp 0,d2
 beq 9f
 movbu (rl_ram + RL_N),d2
 cmp 0,d2
 beq 9f
 and 3,d2
 add rl_lens,d2
 mov d2,a2
 movbu (a2),d2                    /* the length */
 mov d2,a2
 movhu (rl_ram + RL_S),d2
 sub d2,a2                        /* a2 = the length - frames shot */
 mov a2,d2
 cmp 0,d2
 bge 1f
 clr d2
1:
 movhu d2,(8,a0)
 mov (rl_nv),d2
 inc d2
 mov d2,(rl_nv)
9:
 mov a0,a2                        /* the 7 bytes .hook_rv replaced */
 mov (0x6036f6e4),a0
 jmp rlv_back

/* rl_key <- fb_tpk (the camera application's key handler 0x610beb04, its call of 0x61089d28; frame [d2,a2],16; a0 the
 * key event, its code at (a0)). Uses d2, a2; keeps a0, d0, d1 for 0x61089d28. A removed key: its code and the
 * handler's copy ((16,sp) there, (32,sp) here) set to 0 and d0 0, as the camera's own removal does.
 *   D1 (owner: "you can't peek at film"): fc_lock 1 or 2 (frames shot, not rewound): Playback (0x01000022..25) removed.
 *   (D3, OK rewinding at the roll's end, taken out: owner, test 20, "i dont like the ok to rewind. I want to have to
 *   go the the roll and phyiscally rewind the roll": OK is the camera's own again; the roll is wound back on the Film
 *   Roll row.) om-emu: OK 0x0100001a / 1b, MENU 1e / 1f, Playback 22 / 23. */
rl_key:
 movbu (fc_lock),d2
 cmp 0,d2
 beq 9f
 mov (a0),d2
 cmp 0x01000022,d2
 bcs 2f
 cmp 0x01000026,d2
 bcc 2f
 mov (fc_npk),d2
 inc d2
 mov d2,(fc_npk)
7:
 clr d2
 mov d2,(a0)
 mov d2,(32,sp)
 clr d0
 ret [d2,a2],16
2:
 cmp 0x0100001a,d2                /* OK pressed (owner, test 21: "click ok and it opens to the film rewind roll */
 bne 9f                           /* setting"): at the roll's end on the shooting screen rl_wpm 1, else 0. The key */
 clr d2                           /* goes on as always: the camera application opens its control panel (its GUI */
 mov d2,(rl_wpm)                  /* request goes at the release), and fb_tpost turns that request into Picture */
 movbu (fc_lock),d2               /* Mode's, on its first row (the film selection row: the rear dial winds back */
 cmp 2,d2                         /* there, fb_tgui). Uses d2 only (pk_gate gets a0, d0, d1 as they came) */
 bne 9f
 movhu (LG_GUI),d2
 cmp 0x0801,d2
 bne 9f
 mov 1,d2
 mov d2,(rl_wpm)
9:
 jmp pk_gate

/* rl_rel <- .hook_rel: OlyHfwOpeShoot::ctrlRelease (0x60b0cd..) asks isCtrlReleaseEnable (0x60aeac53) at 0x60b0cdad
 * with `call ..,[],12`; that call now comes here (the same 7 bytes' form). Owner (2026-11-21, "Yes, stop it" / "Yes,
 * build it"): at a roll's end the shutter does not fire until the roll is rewound. Refuses (d0 0: the camera's own
 * "not ready" path, its log "isCtrlReleaseEnable API_ERROR_UNRESPONSIVE", return 0xF0000058, nothing released) only
 * when the request is a key release (ctrlRelease's key_1st, d2, not 0: a still's full press gives 2 / 3; the
 * photo / movie switch and a movie press give 0 / 0, om-emu WATCH), Film Rolls is on, the films are in and a roll's
 * frames are all shot. Anything else: the stock function, as a tail call in the same frame. Keeps d0 (the stock call
 * gets 0x60aeb02d's d0), d2, d3; uses d1, a0. The call site is in section 6 as this code. */
rl_rel:
 cmp 0,d2
 beq 9f
 movbu (rl_on),d1
 cmp 1,d1
 bne 9f
 movbu (cm_init),d1
 cmp 0,d1
 beq 9f
 movbu (rl_ram + RL_N),d1
 cmp 0,d1
 beq 9f
 and 3,d1
 add rl_lens,d1
 mov d1,a0
 movbu (a0),d1                    /* the length */
 mov d1,a0
 movhu (rl_ram + RL_S),d1
 cmp a0,d1                        /* frames shot < length: the shutter as stock */
 bcs 9f
rl_rel0:                          /* the refusal (tools/test watches it: never before the first look) */
 mov (rl_nrf),d1
 inc d1
 mov d1,(rl_nrf)
 clr d0
 ret [],12
9:
 jmp rel_ok

rl_as:                            /* `call rl_as,[],0`: ASCII at a0 -> UTF-16 at a1 (NUL written, a1 at it). Uses d1 */
 movbu (a0),d1
 movhu d1,(a1)
 cmp 0,d1
 beq 9f
 add 1,a0
 add 2,a1
 bra rl_as
9:
 ret [],0
rl_isov:                          /* `call rl_isov,[],0`: d0 the ISO setting (Sv x 256) -> d0 the nearest ISO. Uses d1, a0 */
 mov rl_isot,a0
1:
 mov (a0),d1
 add 42,d1
 cmp d1,d0
 bls 2f
 add 8,a0
 cmp rl_isoe,a0
 bne 1b
 add -8,a0
2:
 mov (4,a0),d0
 ret [],0

/* rl_txt: `call rl_txt,[d2,d3,a2,a3],24`: the debug log's FILM ROLL line (NOW) */
rl_txt:
 LGS rl_l1s
 movbu (rl_on),d0
 LGD
 LGS rl_l2s
 movbu (rl_ram + RL_N),d0
 LGD
 LGS rl_l3s
 movbu (rl_ram + RL_CH),d0
 LGD
 LGS rl_l4s
 movhu (rl_ram + RL_ISO),d0
 LGD
 LGS rl_l5s
 movhu (rl_ram + RL_S),d0
 LGD
 LGS rl_l6s
 movbu (rl_ram + RL_P),d0
 LGD
 LGS rl_l16s
 movbu (rl_arm),d0
 LGD
 LGS rl_l44s
 movhu (rl_fcn),d0
 LGD
 LGS rl_l45s
 movhu (rl_ram + RL_F1),d0
 LGD
 LGS rl_l46s
 movhu (rl_fdn),d0
 LGD
 LGS rl_l17s
 movbu (rl_ur),d0
 LGD
 LGS rl_l18s
 movbu (rl_um),d0
 LGD
 LGS rl_l7s
 mov (rl_ns),d0
 LGD
 LGS rl_l8s
 mov (rl_nld),d0
 LGD
 LGS rl_l19s
 mov (rl_nst),d0
 LGD
 LGS rl_l9s
 mov (rl_nl),d0
 LGD
 LGS rl_l10s
 mov (rl_ni),d0
 LGD
 LGS rl_l68s
 mov (rl_n17),d0
 LGD
 LGS rl_l41s
 LGS rl_l69s                      /* rl_ibk (owner, 2026-11-26) */
 mov (rl_nib),d0
 LGD
 LGS rl_l11s
 mov (rl_nf),d0
 LGD
 LGS rl_l12s
 mov (rl_nq),d0
 LGD
 LGS rl_l13s
 mov (rl_ne),d0
 LGD
 LGS rl_l14s
 mov (rl_nw),d0
 LGD
 LGS rl_l15s
 mov (rl_nu),d0
 LGD
 LGS rl_l20s
 mov (rl_nv),d0
 LGD
 LGS rl_l22s
 mov (rl_nrf),d0
 LGD
 LGS rl_l23s
 mov (fc_npk),d0
 LGD
 LGS rl_l25s
 mov (rl_nlg),d0
 LGD
 LGS rl_l26s
 movbu (fh_tpk + 13),d0
 LGD
 LGS rl_l29s                      /* the canister's renderer hook (fb_tr13) */
 movbu (fh_tr13 + 13),d0
 LGD
 LGS rl_l35s
 mov (fb_rc13),d0
 LGD
 LGS rl_l52s
 mov (fb_dn13),d0
 LGD
 LGS rl_l38s
 mov (fb_akey),d0
 LGD
 LGS rl_l39s
 mov (fb_alen),d0
 LGD
 LGS rl_l40s
 mov (fb_anl),d0
 LGD
 LGS rl_l41s
 LGS rl_l27s
 mov (rl_nir),d0
 LGD
 LGS rl_l28s
 mov (rl_nirb),d0
 LGD
 LGS rl_l47s                      /* C4 */
 movbu (fh_tic + 13),d0
 LGD
 LGS rl_l48s
 mov (fw_key),d0
 LGD
 LGS rl_l49s
 mov (fw_nl),d0
 LGD
 LGS rl_l50s
 mov (fw_nshow),d0
 LGD
 LGS rl_l41s
 LGS rl_l64s                      /* test 12 */
 movbu (fh_tcs + 13),d0
 LGD
 LGS rl_l65s
 mov (fb_ncs),d0
 LGD
 LGS rl_l66s
 mov (fb_nto),d0
 LGD
 LGS rl_l70s                      /* the end-of-roll slip */
 mov (fw_nslip),d0
 LGD
 LGS rl_l71s
 mov (fw_nbox),d0
 LGD
 LGS rl_l72s                      /* OK at the end: Picture Mode; the rear dial on the film selection row */
 movbu (fh_tpost + 13),d0
 LGD
 LGS rl_l73s
 mov (rl_nok),d0
 LGD
 LGS rl_l74s
 movbu (fh_tgui + 13),d0
 LGD
 LGS rl_l75s
 mov (fb_ngs),d0
 LGD
 LGS rl_l76s
 mov (fb_nrf),d0
 LGD
 LGS rl_l53s                      /* test 34: the burst limit (fb_tmx) */
 movbu (fh_tmx + 13),d0
 LGD
 LGS rl_l54s
 mov (fb_mxn),d0
 LGD
 LGS rl_l55s
 mov (fb_mxv),d0
 LGD
 LGS rl_l56s
 mov (fb_mxs),d0
 LGD
 LGS rl_l57s                      /* test 35 */
 mov (fb_mxc),d0
 LGD
 LGS rl_l41s
 ret [d2,d3,a2,a3],24

 .balign 4
rl_isot:                          /* {Sv x 256, ISO}: the camera's 1/3 stops */
 .long 1115, 64
 .long 1198, 80
 .long 1280, 100
 .long 1362, 125
 .long 1454, 160
 .long 1536, 200
 .long 1618, 250
 .long 1710, 320
 .long 1792, 400
 .long 1874, 500
 .long 1966, 640
 .long 2048, 800
 .long 2130, 1000
 .long 2213, 1250
 .long 2304, 1600
 .long 2386, 2000
 .long 2469, 2500
 .long 2560, 3200
 .long 2642, 4000
 .long 2725, 5000
 .long 2816, 6400
 .long 2898, 8000
 .long 2981, 10000
 .long 3072, 12800
 .long 3154, 16000
 .long 3237, 20000
 .long 3328, 25600
 .long 3410, 32000
 .long 3493, 40000
 .long 3584, 51200
 .long 3666, 64000
 .long 3749, 80000
 .long 3840, 102400
rl_isoe:
rl_tmp:                           /* B1: a record as read from the card */
 .space RL_LEN
rl_wbuf:                          /* B1: the record as written to the card */
 .space RL_LEN
rl_ram:
 .space 12
rl_rbody:                         /* +12: the record's body (tools/test pokes a roll here) */
 .space RL_LEN - 12
rl_ns:
 .long 0
rl_nl:
 .long 0
rl_nf:
 .long 0
rl_nq:
 .long 0
rl_ne:
 .long 0
rl_nw:
 .long 0
rl_nu:
 .long 0
rl_nv:
 .long 0
rl_nrf:
 .long 0
fb_artp:                          /* E1: the roll's drawing being shown (a heap buffer), 0 none */
 .long 0
fb_ab0:
 .long 0
fb_ab1:
 .long 0
fb_akey:                          /* its ROLLART.BIN entry, -1 none */
 .long -1
fb_alen:
 .long 0
fb_anl:                           /* drawings loaded */
 .long 0
fb_rc13:
 .long 0
fb_dn13:                          /* drawings in command 13 */
 .long 0
fb_nbz:                           /* loads put off while CPU 1 drew */
 .long 0
fb_ncs:                           /* test 12: the Film Roll row marked for the drawing view */
 .long 0
fb_kcs:                           /* fb_tcs: the row's key */
 .long 0
fb_req:                           /* the Film Roll row's values set (rl_row) / the last served by fb_art (fb_done) */
 .long 0
fb_reqc:
 .long 0
fb_done:
 .long 0
fb_nto:                           /* fb_tr13 gave up waiting */
 .long 0
fb_dbz:                           /* 1 while CPU 1 draws (fb_draw) */
 .byte 0
 .balign 4
 .balign 4
rl_nir:                           /* D2: Image Review set Off / put back */
 .long 0
rl_nirb:
 .long 0
rl_ls:                            /* B3: the finished roll for the log: N, film, u16 shot, u16 ISO, its number, -,
                                   * u16 the file counter before its first photo (0 not known), u16 the folder */
 .space 12
rl_fcn:                           /* the camera's file counter and folder at the last shutter event (rl_fcr) */
 .short 0
rl_fdn:
 .short 0
rl_lw:                            /* B3: a line waits for the log writer */
 .byte 0
 .balign 4
rl_nlg:                           /* B3: log lines written */
 .long 0
rl_llen:
 .long 0
rl_lold:
 .long 0
rl_dmin:
 .long 0
rl_lsv:                           /* rl_log's own (it runs in the log writer task, rl_str in the GUI's) */
 .long 0
rl_lsp:
 .long 0
rl_dg2:
 .space 12
rl_dge2:
 .balign 4
rl_line:                          /* the longest: "Roll 001, COLOR 1, ISO 1600, 72 exp, 72 shot, photos 9999 to
                                   * 10070, folder 999" + CR LF = 81 B */
 .space 96
rl_lbp:                           /* B3: ROLLS.TXT's buffer (malloc, fb_init: RL_LB + 96 B) */
 .long 0
rl_sbp:                           /* the row's strings (malloc, fb_init: 40 x 64 B, UTF-16, up to 31 characters) */
 .long 0
rl_nk:
 .long 0
rl_ni:
 .long 0
rl_n17:                           /* writes of 1701 (rl_i17) */
 .long 0
rl_nib:                           /* the ISO from before a roll put back (rl_ibk) */
 .long 0
rl_nld:
 .long 0
rl_nst:
 .long 0
rl_l4:
 .space 4
rl_ok:
 .byte 0
rl_arm:
 .byte 0
rl_cur:                           /* the crank: the row's cursor (rl_row) */
 .byte 0
rl_ach:
 .byte 0
rl_ur:
 .byte 0
rl_um:
 .byte 0
 .balign 2
rl_aiso:
 .short 0
rl_on:                            /* 0 not looked yet, 1 the card has FILMROLL.TXT, 2 it has not */
 .byte 0
rl_v0:
 .byte 0
rl_dw:
 .byte 0
rl_lens:
 .byte 0, 24, 36, 72
 .balign 4
rl_pa:
 .asciz "C:\\OM3MOD\\FILMROLL\\ROLL.BIN"
rl_pb:
 .asciz "C:\\OM3MOD\\FILMROLL\\ROLL2.BIN"
rl_l1s:
 .asciz "\r\nFilm Roll: on "
rl_l2s:
 .asciz "; roll (0 none, 1 = 24, 2 = 36, 3 = 72) "
rl_l3s:
 .asciz ", film "
rl_l4s:
 .asciz ", ISO setting "
rl_l5s:
 .asciz ", frames shot "
rl_l6s:
 .asciz ", rewind steps "
rl_l7s:
 .asciz "\r\nFilm Roll this power-on: frames counted "
rl_l8s:
 .asciz ", length picks "
rl_l9s:
 .asciz ", lock rewrites "
rl_l10s:
 .asciz ", ISO put back "
rl_l68s:
 .asciz " (1701: "
rl_l69s:
 .asciz ", ISO from before the roll back "
rl_l11s:
 .asciz ", film put back "
rl_l12s:
 .asciz ", put-back requests "
rl_l13s:
 .asciz ", rolls out "
rl_l14s:
 .asciz ", record writes "
rl_l16s:
 .asciz ", armed "
rl_l44s:
 .asciz ", file counter "
rl_l45s:
 .asciz " (before the roll's first photo "
rl_l46s:
 .asciz "), folder "
rl_l17s:
 .asciz "; screen hook stage "
rl_l18s:
 .asciz ", movie flag "
rl_l19s:
 .asciz ", rolls started "
rl_l22s:
 .asciz ", shutter refused at the end "
rl_l23s:
 .asciz ", playback refused "
rl_l25s:
 .asciz ", log lines "
rl_l26s:
 .asciz ", key hook (1 in) "
rl_l29s:
 .asciz ", drawing hook "
rl_l35s:
 .asciz "\r\nFilm Roll renderers (command 13): "
rl_l38s:
 .asciz ", roll drawing "
rl_l39s:
 .asciz " ("
rl_l40s:
 .asciz " B, loads "
rl_l41s:
 .asciz ")"
fb_part:
 .asciz "C:\\OM3MOD\\FILMROLL\\ROLLART.BIN"
rl_l27s:
 .asciz "; image review off "
rl_l28s:
 .asciz ", back "
rl_l47s:
 .asciz "; film window hook "
rl_l48s:
 .asciz ", window "
rl_l49s:
 .asciz " (loads "
rl_l50s:
 .asciz ", shown "
rl_l52s:
 .asciz ", drawn "
rl_l64s:
 .asciz "; Film Roll row view: hook "
rl_l65s:
 .asciz ", marked "
rl_l66s:
 .asciz ", gave up "
rl_l70s:
 .asciz "; end slip "
rl_l71s:
 .asciz " (box widened "
rl_l72s:
 .asciz "); OK: hook "
rl_l73s:
 .asciz ", PM "
rl_l74s:
 .asciz "; dial: hook "
rl_l75s:
 .asciz ", steps "
rl_l76s:
 .asciz ", redrawn "
rl_l53s:
 .asciz "; burst: hook "
rl_l54s:
 .asciz ", limit set "
rl_l55s:
 .asciz ", last "
rl_l56s:
 .asciz ", at frame "
rl_l57s:
 .asciz ", capped "
rl_plog:
 .asciz "C:\\OM3MOD\\FILMROLL\\ROLLS.TXT"
rl_s_roll2:
 .asciz "Roll "
rl_s_lfilm:
 .asciz ", FILM "
rl_s_lcol:
 .asciz ", COLOR "
rl_s_liso:
 .asciz ", ISO "
rl_s_sep2:
 .asciz ", "
rl_s_lexp:
 .asciz " exp, "
rl_s_lshot:
 .asciz " shot\r\n"
rl_s_lph:
 .asciz ", photos "
rl_s_lto:
 .asciz " to "
rl_s_lfd:
 .asciz ", folder "
rl_s_crlf:
 .asciz "\r\n"
rl_l20s:
 .asciz ", variable writes "
rl_l15s:
 .asciz "\r\nFilm Roll screen and shutter: screen writes "
 .balign 4

/* fb_reloc: entry 0, `calls` from fc_load (a2 = P): every listed field + or - the delta, then fb_init; d0 = the block.
 * Runs before its own fields are right: PC-relative and constants only, until 4. */
fb_reloc:
 add -4,sp
 call 1f,[],0                     /* MDR = the address of 1 */
1:
 mov mdr,d0
 add 4,sp
 add fb_base-1b,d0                /* d0 = the block's address */
 movm [d2,d3,a2,a3],(sp)
 mov d0,a2
 mov d0,d3
 add -FB_LINK,d3                  /* delta */
 mov a2,a3
 add fb_end-fb_base,a3            /* the relocation list */
 mov a2,a0
 add fb_nrel-fb_base,a0
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
 call fb_init,[d2,d3,a2,a3],20    /* relocated: absolute addresses and firmware calls are live now */
 mov a2,d0
 movm (sp),[d2,d3,a2,a3]
 rets

/* fb_init: `call fb_init,[d2,d3,a2,a3],20`: Film Rolls on; the Film Roll row's item entry (fc_it, flashed: the
 * Halation Radius lists until now) gets this block's option lists. */
fb_init:
 mov 40 * 64,d0                   /* the buffers, from the camera's heap (kept out of the file: its 16448 B cap) */
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(rl_sbp)
 mov RL_LB + 96,d0
 call malloc,[],4
 cmp 0,a0
 beq 9f
 mov a0,(rl_lbp)
 mov SC_PAGE,d0                   /* E1: two pages for the drawing (ROLLART.BIN / SCREENS.BIN) */
 call malloc,[],4
 call fb_unc,[],4
 mov a0,(fb_ab0)
 mov SC_PAGE,d0
 call malloc,[],4
 call fb_unc,[],4
 mov a0,(fb_ab1)
 mov FW_MAX,d0                    /* C4: two buffers for the film window (WINDOW.BIN) */
 call malloc,[],4
 mov a0,(fw_b0)
 mov FW_MAX,d0
 call malloc,[],4
 mov a0,(fw_b1)
 mov 1,d0
 movbu d0,(rl_on)
 call fb_hooks,[d2,d3,a2,a3],24   /* the hooks this file puts in itself (no flash needed for them) */
9:
 ret [d2,d3,a2,a3],20

/* ---- Hooks from the card (owner, 2026-11-24: "flash once", the rest on the SD card, as OMKit). The camera runs its
 * code from a copy in DRAM; this file puts a jump into that copy when it is loaded (the first shutter event, never at
 * start-up), as OMKit does on the OM-5 II (camera-verified there): through the uncached view (0xa..., the code's
 * address + 0x40000000; the firmware's own write protection watches only 0x6...), under the firmware lock (no task of
 * this CPU runs the site meanwhile), bytes 1..4 first and the opcode last, a 5-byte `jmp (d32,pc)` that does not cross
 * a 16-byte instruction-cache line (a CPU that still holds the line runs the old instruction whole until it reloads
 * it). Every site's 5 stock bytes are checked first: anything else (another firmware, another patch) and nothing is
 * written. No card file, nothing is ever changed: the camera is stock. */
fb_hooks:                         /* `call fb_hooks,[d2,d3,a2,a3],24`: each fb_htab record */
 mov fb_htab,a2
1:
 mov (a2),d0
 cmp 0,d0
 beq 9f
 mov a2,a0
 call fb_hook,[d2,d3,a2,a3],24
 add 16,a2
 bra 1b
9:
 ret [d2,d3,a2,a3],24

/* fb_hook: `call fb_hook,[d2,d3,a2,a3],24`, a0 = a record {+0 site, +4 target, +8 the 5 stock bytes, +13 result:
 * 1 in, 2 stock bytes differ (not written), 3 would cross a cache line (not written)}. Local (4,sp): LOCK's token. */
fb_hook:
 mov a0,a3
 mov (a3),d2                      /* the site */
 mov d2,d0
 and 15,d0
 cmp 12,d0
 bcs 1f
 mov 3,d0
 movbu d0,(13,a3)
 bra 9f
1:
 mov d2,a2
 add 0x40000000,a2                /* its uncached view */
 clr d0
 call LOCK,[d2],8
 mov d0,(4,sp)
 clr d1
2:
 mov a2,a0
 add d1,a0
 movbu (a0),d0
 mov a3,a1
 add d1,a1
 movbu (8,a1),d3
 cmp d3,d0
 bne 7f
 inc d1
 cmp 5,d1
 bcs 2b
 mov (4,a3),d0                    /* the jump's displacement: target - site */
 sub d2,d0
 movbu d0,(1,a2)
 lsr 8,d0
 movbu d0,(2,a2)
 lsr 8,d0
 movbu d0,(3,a2)
 lsr 8,d0
 movbu d0,(4,a2)
 mov 0xdc,d0                      /* jmp (d32,pc), last */
 movbu d0,(a2)
 mov 1,d0
 movbu d0,(13,a3)
 bra 8f
7:
 mov 2,d0
 movbu d0,(13,a3)
8:
 mov (4,sp),d0
 call UNLOCK,[d2],8
9:
 ret [d2,d3,a2,a3],24

/* fb_tpk <- the hook at 0x610beb1a (D1, D3): the 7 bytes there were `call 0x61089d28,[d2,a2],16` (the key handler's
 * check before its removal predicate); now rl_key in that call's place, then back after it (0x610beb21) */
fb_tpk:
 call rl_key,[d2,a2],16
 jmp pk_ret

/* fb_tpost <- the hook at 0x6119a06b: the camera application's table post of a GUI event (`call gp_build,[d2,d3,a2,
 * a3],44`; d0 the event, d1 its parameter, a0 = a1 = 0, as the message's fields). OK on the shooting screen sends the
 * shooting screen's "open screen" event 0x9715 with 0 (the control panel; its handler 0x6124cf5d: 4 -> Picture Mode,
 * SS_MENU_LV / ID_ST_DIRECT_PICTUREMODE_ART). After OK at the roll's end (rl_wpm, rl_key) that one request asks for
 * Picture Mode: the camera application goes into its menu as for the panel, so its keys reach Picture Mode as there.
 * Anything else: as it was. Uses a0 (0 again after). */
fb_tpost:
 mov (rl_wpm),a0                  /* (only a0 / a1 are free here: both 0 at the site) */
 cmp 1,a0
 bne 9f
 cmp 0x9715,d0                    /* the panel's request only (other posts meanwhile go on) */
 bne 9f
 cmp 0,d1
 bne 9f
 mov 4,d1
 mov 0,a0
 mov a0,(rl_wpm)
 mov (rl_nok),a0
 inc a0
 mov a0,(rl_nok)
9:
 mov 0,a0
 call gp_build,[d2,d3,a2,a3],44
 jmp gp_ret

/* fb_tgui <- the hook at 0x610fd0f7: the GUI task's dispatch of an event (`call gui_disp,[d2,d3,a2,a3],48`; a0 the
 * machine, d0 the event, d1, a1 its parameters, as loaded from the loop's (396 / 412 / 408,sp)). Owner (test 26):
 * "combine it with the film selection row. so I could pick film 4, 36 shots on the same row" (the mock-up's rear dial:
 * the length). On Picture Mode's film selection row (GUI 6148, item 111) the rear dial (0x9031; a1 -1 / +1) steps the
 * Film Roll row's value (rl_row: the length, or a frame wound back during a roll) and goes no further: the strip does
 * not move. The rows are refreshed instead, as the camera does after a step on the strip (0x6124f6c7 calls the screen's
 * second widget's first method, 0x611d02a9, when the first one took the event): the film row's column update (key 105,
 * fb_tcs) asks for the canister's drawing. Test 33 (owner, test 32: "the rewind function still moves through the film
 * sims"): until then the dial's step went on to the strip and an arrow brought it back (tests 29..32), which the
 * owner could see, and quick turns could leave the strip on another film (test 31). Anything else: as it was. */
fb_tgui:
 cmp 0x9031,d0
 bne 8f
 movhu (LG_GUI),d1
 cmp 6148,d1
 bne 7f
 movhu (hb_item),d1
 cmp 111,d1
 bne 7f
 movbu (fc_rval),d1               /* the Film Roll row's value (None / 24 / 36 / 72; while winding, the cursor) one */
 mov a1,d0                        /* step on: rl_row (the length; a frame wound back during a roll) */
 add d0,d1
 and 3,d1
 call rl_row,[d2,d3,a2,a3],40
 mov (fb_ngs),d0
 inc d0
 mov d0,(fb_ngs)
 mov (0x6037dfa0),a0              /* Picture Mode's screen object; +4 its row widget (vtable 0x615513cc) */
 cmp 0,a0
 beq 9f
 mov (4,a0),a0
 cmp 0,a0
 beq 9f
 mov (a0),a1
 cmp 0x615513cc,a1
 bne 9f
 mov (a1),a1                      /* 0x611d02a9 (`movm` prologue: entered with calls), a0 = the widget */
 calls (a1)
 mov (fb_nrf),d0
 inc d0
 mov d0,(fb_nrf)
9:
 mov 500,d0                       /* and Picture Mode's idle timer armed again, as the strip's key handler does with */
 mov 30000,d1                     /* each key (0x611c28ac, our PM_IDLE_SITES: 30 s): else it closes 30 s after the */
 call TMR_ARM,[d2,d3],12          /* last event it saw (om-emu) */
 jmp gd_ret                       /* the loop loads its registers again (0x610fd0fc, 0x610fd112) */
7:
 mov (412,sp),d1
8:
 call gui_disp,[d2,d3,a2,a3],48
 jmp gd_ret

/* fb_tmx <- the hook at 0x60ceb800 (owner, test 33: "if i put it on fast burst it will take more than 24 photos. I
 * was able to take 55 photos after selecting 24 shots"). The shooting sequences' method 0x60ceb717 (9 vtables,
 * 0x60eca72c..) has just set the burst's limit, _continueMaxShootCount, u16 at (160,a2) (65535, or from setting 857 /
 * 1495), and is about to log it: `mov 0x60ecfa71,d0` (its format, 6 B) here. Test 34's probe on the camera: it runs at
 * every press (2 singles, 3 short bursts and a long one: 6 runs), the last at frame 15 of 36 (the long burst's start),
 * the limit then 4979. Test 35: with a roll in (not being wound back) and fewer frames left than the limit, the limit
 * becomes the frames left, so a burst stops at the roll's end; never 0 (at the end the release is refused, rl_rel).
 * Then the replaced instruction, and on (the method logs the limit as it is now). d1, a0 kept; d0 written next anyway;
 * the code after reads no flags before setting them. The capture's task: RAM only, no calls. */
fb_tmx:
 mov d1,(fb_mx1)
 mov a0,(fb_mx2)
 mov (fb_mxn),d0
 inc d0
 mov d0,(fb_mxn)
 movhu (160,a2),d1                /* the camera's limit */
 mov d1,(fb_mxv)
 movhu (rl_ram + RL_S),d0
 mov d0,(fb_mxs)
 movbu (rl_on),d0
 cmp 1,d0
 bne 9f
 movbu (rl_ram + RL_P),d0         /* not while being wound back */
 cmp 0,d0
 bne 9f
 movbu (rl_ram + RL_N),d0
 and 3,d0
 beq 9f
 mov rl_lens,a0
 add d0,a0
 movbu (a0),d0                    /* the length - frames shot: the frames left */
 movhu (rl_ram + RL_S),d1
 sub d1,d0
 cmp 0,d0
 ble 9f
 mov (fb_mxv),d1
 cmp d1,d0
 bcc 9f
 movhu d0,(160,a2)
 mov (fb_mxc),d0
 inc d0
 mov d0,(fb_mxc)
9:
 mov (fb_mx1),d1
 mov (fb_mx2),a0
 mov 0x60ecfa71,d0
 jmp mx_ret

/* fb_one: `call fb_one,[d2,d3,a2,a3],56` (CPU 1; 2026-11-25: was 48, so its locals (32) / (36) were the slots of the
 * caller's saved registers and fb_draw came back with a2 / a3 = the paint and path handles: test 8's restart, analysis): one colour group, d0 segments, d1 RGBA, a0 the segments, a1 the
 * coordinates (S_16 quarter pixels): a path and a paint, filled, destroyed. Locals (4..12) vgCreatePath's stack
 * arguments, (16) segments, (20) RGBA, (24) / (28) the pointers, (32) the path, (36) the paint */
fb_one:
 mov d0,(16,sp)
 mov d1,(20,sp)
 mov a0,(24,sp)
 mov a1,(28,sp)
 clr d0
 mov d0,(4,sp)
 mov d0,(8,sp)
 mov 0xfff,d0
 mov d0,(12,sp)
 clr d0
 mov 1,d1                         /* VG_PATH_DATATYPE_S_16, quarter pixels (scale 0.25), as OMKit's */
 mov 0x3e800000,a0
 mov 0,a1
 call vg_cpath,[d2,d3,a2,a3],40
 mov d0,(32,sp)
 mov (16,sp),d1
 mov (24,sp),a0
 mov (28,sp),a1
 call vg_append,[d2,d3,a2,a3],28
 call vg_cpaint,[d2],8
 mov d0,(36,sp)
 mov (20,sp),d1
 call vg_setcolor,[d2,d3],12
 mov (36,sp),d0
 mov 2,d1
 call vg_setpaint,[d2,d3],12
 mov (32,sp),d0
 mov 2,d1
 call vg_draw,[d2,d3,a2],20
 mov (32,sp),d0
 call vg_dpath,[d2,d3,a2,a3],28
 mov (36,sp),d0
 call vg_dpaint,[d2],8
 ret [d2,d3,a2,a3],56

/* fb_art: `call fb_art,[d2,d3,a2,a3],64` from rl_hp (HLS_EVENT task) and rl_idle (CADLOG task at a quiet poll): both
 * may read the card; fb_abz keeps them from running it together. What the renderer draws, as a page of up to 4
 * records (+0 count, +4 1: the roll's shared parts first, +8..+20 each record's offset in the page, the records from
 * +24; SC_PAGE bytes, heap, uncached; the renderer on CPU 1 reads the published one at each frame):
 *  - the loaded roll: its film and length's drawing from OM3MOD/FILMROLL/ROLLART.BIN (firmware/mkrollpath.py; entry 3 x
 *    i + (24 / 36 / 72 -> 0 / 1 / 2), i 0..19 FILM 1..20, 20..23 COLOR 1..4), after the shared parts;
 *  - (owner, 2026-11-24: the approved screens, firmware/mkscreens.py; with DRAW.TXT only until test 15) pieces of OM3MOD/FILMROLL/
 *    SCREENS.BIN (entry numbers: frscreens.inc): rewinding (row 1..11): the rewind panel (its roll, the frames still to
 *    wind back, the bar); the roll's end (fc_lock 2): the slip; DRAW.TXT starting with N and frames shot: Not developed.
 * Only when it changes: read into the buffer not being shown, then published (fb_artp). No roll, a film without a
 * drawing: nothing (fb_artp 0). A missing or bad file: not again for that choice. Locals: (4) the handle, (8) / (12)
 * {offset, length}, (16) the file (0 ROLLART, 1 SCREENS), (20) 1: the shared parts, (24) the count, (28..40) the
 * entries, (44) the page */
 .set SC_HEAD, 24
fb_art:
 clr d0
 call LOCK,[d2],8
 movbu (fb_abz),d1
 cmp 0,d1
 bne 1f
 mov 1,d1
 movbu d1,(fb_abz)
 clr d1
 bra 2f
1:
 mov 1,d1
2:
 mov d1,(4,sp)                    /* 1: busy (the other task is at it) */
 call UNLOCK,[d2],8
 mov (4,sp),d0
 cmp 0,d0
 beq 1f
 ret [d2,d3,a2,a3],64
1:
 movbu (fb_dbz),d0                /* 2026-11-25 (test 8 restarted): never write a page while CPU 1 draws (it may be
                                   * drawing the one not published); the next event loads it */
 cmp 0,d0
 beq 19f
 mov (fb_nbz),d0
 inc d0
 mov d0,(fb_nbz)
 clr d0
 movbu d0,(fb_abz)
 ret [d2,d3,a2,a3],64
19:
 mov (fb_req),d0                  /* test 12: the request this run serves (fb_done at its end) */
 mov d0,(fb_reqc)
 call fw_load,[d2,d3,a2,a3],48     /* the end-of-roll slip */
 call fb_sel,[],0                 /* test 24: on the film selection row, 1 (its choice below) */
 cmp 0,d0
 beq 5f
 movbu (rl_ram + RL_N),d0         /* the film selection row: the roll's length (none: 0, the roll without one) */
 mov d0,(44,sp)
 movhu (rl_ram + RL_S),d1         /* the roll's film once it started, else the one picked now (cm_val, as rl_hp) */
 cmp 0,d1
 beq 52f
 movbu (rl_ram + RL_CH),d1
 bra 53f
52:
 PVAL 70f
 call cm_val,[d2,d3,a2,a3],20
 mov d0,d1
53:
 mov (44,sp),d0
 bra 2f
5:
 movbu (rl_ram + RL_N),d0
 cmp 0,d0
 beq 70f
 movhu (rl_ram + RL_S),d1         /* the roll's film once it started, else the one noted at the half-press */
 cmp 0,d1
 beq 1f
 movbu (rl_ram + RL_CH),d1
 bra 2f
1:
 movbu (rl_ach),d1
2:
 mov d1,d2
 add -FV0,d2
 cmp NF,d2                        /* FILM 1..20 -> 0..19 */
 bcs 3f
 mov 20,d2
 cmp 54,d1
 beq 3f
 mov 21,d2
 cmp 55,d1
 beq 3f
 mov 22,d2
 cmp 56,d1
 beq 3f
 mov 23,d2
 cmp 64,d1
 bne 70f
3:
 and 3,d0                         /* no length (the film selection row, no roll): the roll without one, 72 + film */
 bne 31f                          /* (owner, test 24: "since this hasnt been set yet, shouldnt that be blank?") */
 add 72,d2
 clr d3
 bra 32f
31:
 mov d2,d1                        /* d2 = 3 x film + length - 1 (the roll's drawing; its rewind roll in SCREENS.BIN) */
 add d2,d2
 add d1,d2
 add -1,d0
 mov d0,d3                        /* d3 = the length 0 / 1 / 2 */
 add d0,d2
32:
 clr d0
 mov d0,(16,sp)
 mov 1,d0
 mov d0,(20,sp)
 mov d0,(24,sp)
 mov d2,(28,sp)
 mov -1,d0
 mov d0,(32,sp)
 mov d0,(36,sp)
 mov d0,(40,sp)
 movbu (rl_ram + RL_P),d0         /* the screens (test 15, owner 2026-11-25 "Yes, start them": no longer only with
                                   * DRAW.TXT, the Film Roll row draws them): rewinding -> the panel, the end -> the slip */
 cmp 0,d0
 beq 10f
 mov 1,d1                         /* rewinding: the panel, its roll, the frames still to wind back, the bar */
 mov d1,(16,sp)
 clr d1
 mov d1,(20,sp)
 mov 4,d1
 mov d1,(24,sp)
 mov SC_RWB,d1
 mov d1,(28,sp)
 add SC_RWR,d2
 mov d2,(32,sp)
 mov 12,d1                        /* the bar: 12 x wound / shot (the crank, one click a frame) */
 mul d1,d0
 movhu (rl_ram + RL_S),d1
 divu d1,d0
 add SC_BAR,d0
 mov d0,(40,sp)
 movhu (rl_ram + RL_S),d2         /* the number: shot - wound */
 movbu (rl_ram + RL_P),d0
 sub d0,d2
 cmp 73,d2
 bcs 4f
 mov 72,d2
4:
 add SC_BIG,d2
 mov d2,(36,sp)
 bra 20f
10:
 movbu (fc_lock),d0
 cmp 2,d0
 bne 11f
 mov 1,d0                         /* the roll's end: the slip */
 mov d0,(16,sp)
 clr d0
 mov d0,(20,sp)
 mov d3,d0
 add SC_SLIP,d0
 mov d0,(28,sp)
 bra 20f
11:
20:
 mov sp,a0                        /* the same choice as the one shown or tried: nothing to do */
 add 16,a0
 mov fb_kc,a1
 mov 7,d0
 clr d1
21:
 mov (a0),d2
 mov (a1),d3
 cmp d2,d3
 beq 22f
 mov 1,d1
 mov d2,(a1)                      /* noted: not tried again */
22:
 add 4,a0
 add 4,a1
 add -1,d0
 bne 21b
 cmp 0,d1
 beq 90f
 mov (28,sp),d0                   /* for the log: the (first) entry, SCREENS.BIN's + 1000 */
 mov (16,sp),d1
 cmp 0,d1
 beq 23f
 add 1000,d0
23:
 mov d0,(fb_akey)
 mov (fb_ab0),a0                  /* the buffer not being shown */
 mov (fb_artp),a1
 cmp a0,a1
 bne 24f
 mov (fb_ab1),a0
24:
 cmp 0,a0
 beq 90f
 mov a0,(44,sp)
 mov fb_part,a0
 mov (16,sp),d0
 cmp 0,d0
 beq 25f
 mov fb_pscr,a0
25:
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 beq 90f
 mov a0,(4,sp)
 clr d2                           /* d2 the record, d3 where it goes in the page */
 mov SC_HEAD,d3
30:
 mov d2,d0                        /* its index entry */
 asl 2,d0
 mov sp,a0
 add d0,a0
 mov (28,a0),d0
 asl 3,d0
 add 8,d0
 mov (4,sp),a0
 mov 2,d1                         /* SET */
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 80f
 mov sp,a0
 add 8,a0
 mov 1,d0
 mov 8,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp 8,d0
 bne 80f
 mov (12,sp),d0                   /* its length: 20 .. what is left of the page */
 cmp 20,d0
 bcs 80f
 add d3,d0
 cmp SC_PAGE + 1,d0
 bcc 80f
 mov (4,sp),a0
 mov (8,sp),d0
 mov 2,d1
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 80f
 mov (44,sp),a0
 add d3,a0
 mov 1,d0
 mov (12,sp),d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov (12,sp),d1
 cmp d1,d0
 bne 80f
 mov (44,sp),a0                   /* a sane record: 1..16 groups */
 add d3,a0
 mov (a0),d0
 cmp 0,d0
 beq 80f
 cmp 17,d0
 bcc 80f
 mov d2,d0                        /* its offset in the page */
 asl 2,d0
 mov (44,sp),a0
 add d0,a0
 mov d3,(8,a0)
 mov (12,sp),d0
 add 3,d0
 and -4,d0
 add d0,d3
 inc d2
 mov (24,sp),d0
 cmp d0,d2
 bcs 30b
 mov (44,sp),a0
 mov (24,sp),d0
 mov d0,(a0)
 mov (20,sp),d0
 mov d0,(4,a0)
 mov a0,(fb_artp)                 /* published */
 mov d3,d0
 add -SC_HEAD,d0
 mov d0,(fb_alen)
 mov (fb_anl),d0
 inc d0
 mov d0,(fb_anl)
80:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 bra 90f
70:
 clr d0                           /* no roll, or no drawing for its film */
 mov d0,(fb_artp)
 mov -1,d0
 mov d0,(fb_akey)
 mov d0,(fb_kc)                   /* the next choice is new */
90:
 mov (fb_reqc),d0
 mov d0,(fb_done)
 clr d0
 movbu d0,(fb_abz)
 ret [d2,d3,a2,a3],64

 .balign 4
/* fb_sel: `call fb_sel,[],0` -> d0 1 in Picture Mode (GUI 6148) on its film selection row (item 111), else 0 */
fb_sel:
 clr d0
 movhu (LG_GUI),d1
 cmp 6148,d1
 bne 9f
 movhu (hb_item),d1
 cmp 111,d1
 bne 9f
 mov 1,d0
9:
 ret [],0

 .balign 4
fb_kc:                            /* the choice shown or tried: file, shared, count, 4 entries */
 .long -1, -1, -1, -1, -1, -1, -1
fb_abz:                           /* 1 while fb_art runs (two tasks call it) */
 .byte 0
fb_pscr:
 .asciz "C:\\OM3MOD\\FILMROLL\\SCREENS.BIN"
 .balign 4

/* ---- fb_tcs (test 12, owner 2026-11-25: "Yes, the Film Roll row"; test 23: on the film selection row): the
 * canister. Picture Mode shows its drawing view (C3D, 928 x 600, started when Picture Mode opens) only on the rows
 * whose case in the column update switch 0x615510cc marks the screen as the colour wheel's does (0x611d1308: screen +
 * 16 + 277 = 1 (byte), + 268 = 1 (word)); the GUI then asks for the view (0x60b1ced8 with d0 0 -> UPDATE -> job 13),
 * else hides it. The film selection row uses the choice rows' generic case (0x611d04af: `mov a3,a0; mov a0,a1; call
 * 0x611d0c7f,[d2,d3,a2,a3],88; bra 0x611d04ec`); this hook replaces its call, and on that row (key 105 = item 111 - 6)
 * adds the view's mark. a3 = the screen (kept by the call); d1 = the switch's key (hb_item is set only after this
 * update). GUI task only. (Until the release tidy-up the Film Roll row, key 5368, had it too; that row is gone.) */
fb_tcs:
 mov d1,(fb_kcs)
 call cs_choice,[d2,d3,a2,a3],88
 mov (fb_kcs),d0
 cmp 105,d0
 bne 9f
 mov a3,a0
 add 16,a0
 mov 1,d0                         /* test 13: only + 268 (the view: om-emu, 0x60b1ced8 d0 0 with it alone); + 277 */
 mov d0,(268,a0)                  /* is the wheel's layout (its dial label and guide over the row's text: test 12) */
 mov (fb_ncs),d0
 inc d0
 mov d0,(fb_ncs)
 mov (fb_req),d0                  /* arriving or a value changed: fb_tr13 waits for fb_art's page of it (the other */
 inc d0                           /* row's, or the film before, is not drawn meanwhile) */
 mov d0,(fb_req)
9:
 jmp cs_after

/* fb_tr13 <- the hook at 0x61050b52: the renderer of command 13 (dispatcher 0x6104fe2f; Picture Mode's view, the
 * 928 x 600 surface). 2026-11-25, camera (test 7): with Picture Mode open only this renderer runs. On the film
 * selection row (test 24) our drawing (fb_draw: the canister, the rewind panel or the slip; it ends with the swap, as
 * the stock code does), back to the dispatcher as the stock `ret [a2,a3],28`; anywhere else the stock renderer (the
 * colour wheel). d0 / d1 are written by the stock code before they are read; a1 by its first 7 bytes, replayed here. */
fb_tr13:
 mov (fb_rc13),a1
 add 1,a1
 mov a1,(fb_rc13)
 movhu (hb_item + 0x40000000),d0
 cmp 111,d0
 bne 9f
 mov (fb_req),d1                  /* a value just set on the row: its drawing is loaded by fb_art (CPU 0, task */
 mov 3000000,d0                   /* CADLOG, every 100 ms) after this job was sent; wait for it, at most ~0.5 s */
82:
 mov (fb_done),a1
 cmp d1,a1
 beq 8f
 add -1,d0
 bne 82b
 mov (fb_nto),d0
 inc d0
 mov d0,(fb_nto)
 bra 8f
8:
 mov (fb_dn13),d0
 inc d0
 mov d0,(fb_dn13)
 call fb_draw,[d2,d3,a2,a3],48
 ret [a2,a3],28
9:
 mov a0,a3
 mov 0x612e0a88,a1
 jmp cr13_back

/* fb_draw: `call fb_draw,[d2,d3,a2,a3],48` (C3D_MAIN, CPU 1). Locals: (4..12,sp) the stack arguments of vgCreatePath,
 * (16..28) the clear colour (4 floats, 0: clear), (32) the path, (36) the paint. VG constants: VG_MATRIX_MODE 0x1100,
 * VG_MATRIX_PATH_USER_TO_SURFACE 0x1400, VG_CLEAR_COLOR 0x1121, VG_PATH_DATATYPE_S_16 1 (scale 0.25, bias 0),
 * VG_PATH_CAPABILITY_ALL 0xfff, VG_FILL_PATH 2. Each fb_paths record {segments, *segments, *coordinates, RGBA}: one path
 * and one paint, drawn and destroyed. */
fb_draw:
 mov 1,d0                         /* CPU 1 at it (fb_art waits), set before the page is read */
 movbu d0,(fb_dbz)
 mov 0x1100,d0
 mov 0x1400,d1
 call vg_seti,[d2,d3],12
 call vg_ident,[],4
 mov (cc_w),d0                    /* the 256 x 256 drawing (OpenVG's origin is the bottom left); test 25 (owner: "can */
                                  /* they be on the right side of the screen?"): at the surface's right edge, 16 px */
                                  /* in (the roll where the colour wheel is), the middle in height */
 add -272,d0
 bge 2f
 clr d0
2:
 call fb_i2f,[],4
 mov d0,d2
 mov (cc_h),d0
 add -256,d0
 bge 2f
 clr d0
2:
 lsr 1,d0
 add 80,d0                        /* test 26 (owner: "the reset hold ok text over laps the film canister so it needs */
 call fb_i2f,[],4                 /* to be moved up a little bit"): 80 px above the middle (OpenVG: y up) */
 mov d0,d1
 mov d2,d0
 call vg_trans,[d2,d3],12
 clr d0                           /* cleared to nothing (0, 0, 0, 0) */
 mov d0,(16,sp)
 mov d0,(20,sp)
 mov d0,(24,sp)
 mov d0,(28,sp)
 mov 0x1121,d0
 mov 4,d1
 mov sp,a0
 add 16,a0
 call vg_setfv,[d2,d3,a2],20
 clr d0
 clr d1
 mov (cc_w),a0
 mov (cc_h),a1
 call vg_clear,[d2,d3,a2,a3],28
 mov (fb_artp),a2                 /* the page (fb_art): its records, after the shared parts when +4 says so; read */
 cmp 0,a2                         /* once (CPU 0 may publish another meanwhile) */
 beq 8f
 mov a2,(24,sp)
 mov (4,a2),d0
 cmp 0,d0
 beq 5f
 mov fb_paths,a3                  /* the parts every roll shares (frpaths.inc) */
1:
 mov (a3),d0
 cmp 0,d0
 beq 5f
 mov (12,a3),d1
 mov (4,a3),a0
 mov (8,a3),a1
 call fb_one,[d2,d3,a2,a3],56
 add 16,a3
 bra 1b
5:
 clr d0
 mov d0,(28,sp)                   /* the record */
7:
 mov (24,sp),a2
 mov (28,sp),d0
 mov (a2),d1
 cmp 5,d1                         /* checks (2026-11-25): at most 4 records, each inside the page, 1..16 groups, */
 bcc 8f                           /* each at most 4096 segments with its data inside the page */
 cmp d1,d0
 bcc 8f
 asl 2,d0
 add a2,d0
 mov d0,a0
 mov (8,a0),d0
 cmp SC_PAGE,d0
 bcc 8f
 add d0,a2                        /* a2 the record */
 mov (a2),d2
 cmp 17,d2
 bcc 4f
 mov a2,a3
 add 4,a3
6:
 cmp 0,d2
 beq 4f
 mov (a3),d0
 cmp 4097,d0
 bcc 4f
 mov (4,a3),d1
 cmp SC_PAGE,d1
 bcc 4f
 mov (8,a3),d1
 cmp SC_PAGE,d1
 bcc 4f
 mov (12,a3),d1
 mov (4,a3),a0
 add a2,a0
 mov (8,a3),a1
 add a2,a1
 call fb_one,[d2,d3,a2,a3],56
 add 16,a3
 add -1,d2
 bra 6b
4:
 mov (28,sp),d0
 inc d0
 mov d0,(28,sp)
 bra 7b
8:
 call cc_swap,[],16
 clr d0
 movbu d0,(fb_dbz)
 ret [d2,d3,a2,a3],48

/* fb_i2f: `call fb_i2f,[],4`, d0 a whole number 0..2^31 -> d0 its IEEE single (OpenVG's floats); uses d1 */
fb_i2f:
 cmp 0,d0
 beq 9f
 mov 150,d1
1:
 cmp 0x01000000,d0
 bcs 2f
 lsr 1,d0
 inc d1
 bra 1b
2:
 cmp 0x00800000,d0
 bcc 3f
 asl 1,d0
 add -1,d1
 bra 2b
3:
 and 0x007fffff,d0
 asl 23,d1
 or d1,d0
9:
 ret [],4

/* fb_unc: `call fb_unc,[],4`, a0 a heap address (0: none) -> a0 its uncached view (as fw_load's pictures; CPU 1
 * reads what CPU 0 writes) */
fb_unc:
 mov a0,d0
 cmp 0,d0
 beq 1f
 cmp 0xa0000000,d0
 bcc 1f
 add 0x40000000,d0
 mov d0,a0
1:
 ret [],4

 .include "frpaths.inc"           /* the build's (firmware/mkrollpath.py): the roll as OpenVG paths */

/* ---- The end-of-roll slip (owner, 2026-11-25: "Build the end slip"). At the roll's end the shooting screen's
 * picture-mode name (pictures 15706..15713, the camera's "COLOR1".."COLOR4" and their '*' forms; our "FILM N", fl_lvp)
 * shows the slip of the roll's length (firmware/mkwindow.py, card file OM3MOD/FILMROLL/WINDOW.BIN; 'OM3W', u16 1, u16 n,
 * n x {offset, length}, OSD type-11 streams, entries 0..2 = 24 / 36 / 72). Until test 21 a film window ("Portra 400"
 * over "24 exp", C4) showed there during the whole roll; owner: "its pretty useless": the camera's own label now.
 * Not in Playback (GUI classes 5..7). Card file only: fb_tic is a hook this file puts in at our flashed ic_get
 * (0x60f4b434, 5 B in its 16-byte line). */
 .set FW_MAX, 6400                 /* the slips' streams are the largest (6,268 B) */
 .set FW_SW, 352                  /* the end-of-roll slip (firmware/mkwindow.py), WINDOW.BIN entries 72..74 */
 .set FW_SH, 64
fb_tic:                           /* <- ic_get (`calls`, returns with retf through MDR: MDR is not touched here) */
 mov d0,d1                        /* (test 19's clear bottom bar on the Film Roll row went with the row, test 28) */
 exthu d1
 cmp 15706,d1
 bcs 8f
 cmp 15714,d1
 bcc 8f
 mov (fw_slot),a0                 /* a window loaded */
 cmp 0,a0
 beq 8f
 movbu (rl_ram + RL_N),d1         /* a roll in */
 cmp 0,d1
 beq 7f
 movhu (LG_GUI),d1                /* not Playback */
 lsr 8,d1
 cmp 5,d1
 bcs 6f
 cmp 8,d1
 bcs 7f
6:
 mov (fw_slot),a1                 /* the end-of-roll slip (owner: "Build the end slip"), known by its width: only for */
 movhu (2,a1),d1                  /* the shooting screen's picture-mode label, its box widened to the slip's size */
 cmp FW_SW,d1                     /* (the same right edge and middle: a 44-high window or the camera's own label */
 bne 69f                          /* still lands where it always does); anyone else: the camera's own picture */
 mov mdr,d1                       /* the GUI's set-picture (0x6128ac0a): its widget in a2, drawn after this returns */
 cmp 0x6128ac22,d1
 bne 7f
 mov (a2),d1                      /* the label: a picture widget (0x6135993c), its id 0x01908003 */
 cmp 0x6135993c,d1
 bne 7f
 mov (4,a2),d1
 cmp 0x01908003,d1
 bne 7f
 movhu (12,a2),d1                 /* its box {x, y, w, h} at +8: rear screen 794, 365, 102, 44; viewfinder 694 */
 cmp FW_SW,d1
 beq 68f
 cmp 102,d1
 bne 7f
 movhu (14,a2),d1
 cmp 44,d1
 bne 7f
 movhu (10,a2),d1
 cmp 365,d1
 bne 7f
 movhu (8,a2),d1
 add 102 - FW_SW,d1
 movhu d1,(8,a2)
 mov 365 - (FW_SH - 44) / 2,d1
 movhu d1,(10,a2)
 mov FW_SW,d1
 movhu d1,(12,a2)
 mov FW_SH,d1
 movhu d1,(14,a2)
 mov (fw_nbox),d1
 inc d1
 mov d1,(fw_nbox)
68:
 movhu (14,a2),d1
 cmp FW_SH,d1
 bne 7f
 mov (fw_nslip),d1
 inc d1
 mov d1,(fw_nslip)
69:
 mov (fw_nshow),d1
 inc d1
 mov d1,(fw_nshow)
 mov fw_slot,a0
 retf [],0
7:
 mov d0,d1
 exthu d1
8:
 cmp 0,d1                         /* the 5 bytes replaced: mov d0,d1; exthu d1; cmp 0,d1; bne */
 bne 9f
 jmp ic_get + 6
9:
 jmp ic_get + 11

/* fw_load: `call fw_load,[d2,d3,a2,a3],48` from fb_art (its busy guard held: one task at a time): at the roll's end
 * the slip of its length, read into the buffer not shown, then published (fw_slot). Otherwise none. Locals: (4) the
 * handle, (8) / (12) {offset, length}, (16) the entry, (20) the buffer, (24) its descriptor */
fw_load:
 movbu (rl_ram + RL_N),d0
 and 3,d0
 cmp 0,d0
 beq 0f
 mov d0,d1                        /* the roll's end (all its frames shot): the slip of its length, entry N - 1 */
 add rl_lens,d1
 mov d1,a0
 movbu (a0),d1
 movhu (rl_ram + RL_S),d3
 cmp d1,d3
 bcc 3f
0:
 clr d0                           /* no roll, or frames left: no window (the camera's own label, as v0.41-beta; */
 mov d0,(fw_slot)                 /* owner, test 21: the film window "its pretty useless") */
 mov -1,d0
 mov d0,(fw_key)
 ret [d2,d3,a2,a3],48
3:
 mov d0,d2
 add -1,d2
31:
 mov (fw_key),d0
 cmp d0,d2
 bne 4f
 ret [d2,d3,a2,a3],48
4:
 mov d2,(fw_key)                  /* tried: not again for this entry */
 mov d2,(16,sp)
 mov (fw_b0),a0                   /* the buffer and descriptor not shown */
 mov fw_d0,a1
 mov (fw_slot),d0
 cmp a1,d0
 bne 5f
 mov (fw_b1),a0
 mov fw_d1,a1
5:
 cmp 0,a0
 bne 51f
 ret [d2,d3,a2,a3],48
51:
 mov a0,(20,sp)
 mov a1,(24,sp)
 mov fw_path,a0
 mov lg_mr,a1
 call fopen,[],4
 cmp 0,a0
 bne 52f
 ret [d2,d3,a2,a3],48
52:
 mov a0,(4,sp)
 mov (16,sp),d0
 asl 3,d0
 add 8,d0
 mov 2,d1
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov sp,a0
 add 8,a0
 mov 1,d0
 mov 8,d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 cmp 8,d0
 bne 8f
 mov (12,sp),d0                   /* its length: 12 .. FW_MAX */
 cmp 12,d0
 bcs 8f
 cmp FW_MAX + 1,d0
 bcc 8f
 mov (4,sp),a0
 mov (8,sp),d0
 mov 2,d1
 call fseek,[d2,d3,a2,a3],20
 cmp 0,d0
 bne 8f
 mov (20,sp),a0
 mov 1,d0
 mov (12,sp),d1
 mov (4,sp),a1
 call fread,[d2,d3,a2,a3],24
 mov (12,sp),d1
 cmp d1,d0
 bne 8f
 mov (20,sp),a0                   /* a type-11 stream: h - 1 (10 bits), w - 1 (10 bits), 11 */
 movbu (3,a0),d0
 cmp 11,d0
 bne 8f
 mov (24,sp),a1                   /* its descriptor: format 14, w x h from the stream, 8; the size; the picture */
 movbu (1,a0),d1
 mov d1,d0
 and 3,d0
 asl 8,d0
 movbu (a0),d2
 or d2,d0
 inc d0
 movhu d0,(4,a1)                  /* h */
 lsr 4,d1
 movbu (2,a0),d0
 and 63,d0
 asl 4,d0
 or d1,d0
 inc d0
 movhu d0,(2,a1)                  /* w */
 mov (12,sp),d0
 mov d0,(12,a1)
 mov (20,sp),d0
 cmp 0xa0000000,d0
 bcc 6f
 add 0x40000000,d0
6:
 mov d0,(16,a1)
 mov a1,(fw_slot)                 /* published */
 mov (fw_nl),d0
 inc d0
 mov d0,(fw_nl)
8:
 mov (4,sp),a0
 call fclose,[d2,a2,a3],16
 ret [d2,d3,a2,a3],48

 .balign 4
fw_slot:                          /* the window shown: its descriptor (ic_get's slot word), 0 none */
 .long 0
fw_d0:                            /* as lv_desc (editor.s): format 14, 96 x 44 */
 .short 14, 96, 44, 8, 0, 0
 .long 0, 0, 0
fw_d1:
 .short 14, 96, 44, 8, 0, 0
 .long 0, 0, 0
fw_b0:                            /* two FW_MAX buffers (fb_init) */
 .long 0
fw_b1:
 .long 0
fw_key:                           /* its WINDOW.BIN entry, -1 none */
 .long -1
fw_nl:                            /* windows loaded */
 .long 0
fw_nshow:                         /* the window given for the picture-mode name */
 .long 0
rl_nok:                           /* OK at the roll's end: Picture Mode asked for instead of the control panel */
 .long 0
rl_wpm:                           /* OK at the roll's end: 1 pressed (rl_key), 0 Picture Mode asked (fb_tpost) or */
 .long 0                          /* another OK */
fb_ngs:                           /* fb_tgui: rear dial steps on the film selection row */
 .long 0
fb_nrf:                           /* the rows refreshed for them (0x611d02a9) */
 .long 0
fb_mxn:                           /* fb_tmx: the burst limit's runs, the last limit, the roll's frames shot then */
 .long 0
fb_mxv:
 .long 0
fb_mxs:
 .long 0
fb_mxc:                           /* limits lowered to the frames left */
 .long 0
fb_mx1:                           /* d1, a0 over it */
 .long 0
fb_mx2:
 .long 0
fw_nslip:                         /* the slip given to the label */
 .long 0
fw_nbox:                          /* the label's box widened (once a screen) */
 .long 0
fw_path:
 .asciz "C:\\OM3MOD\\FILMROLL\\WINDOW.BIN"
 .balign 4

 .balign 4
fb_htab:                          /* the hooks this file puts in: {site, target, 5 stock bytes, result}, 0 ends */
fh_tpk:
 .long 0x610beb1a, fb_tpk
 .byte 0xdd, 0x0e, 0xb2, 0xfc, 0xff, 0
 .balign 4
fh_tr13:
 .long 0x61050b52, fb_tr13        /* the renderer of command 13 (Picture Mode's view; C3D_MAIN, CPU 1): the canister */
 .byte 0x93, 0xfc, 0xdd, 0x88, 0x0a, 0
 .balign 4
fh_tic:
 .long ic_get, fb_tic             /* C4: our flashed picture getter (mov d0,d1; exthu d1; cmp 0,d1; bne ..) */
 .byte 0x81, 0x1d, 0xa5, 0x00, 0xc9, 0
 .balign 4
fh_tcs:
 .long 0x611d04b1, fb_tcs         /* test 12: the choice rows' case in Picture Mode's column update (0x615510cc) */
 .byte 0xcd, 0xce, 0x07, 0xf0, 0x58, 0
 .balign 4
fh_tpost:
 .long 0x6119a06b, fb_tpost       /* OK at the roll's end: the camera application's table post of a GUI event */
 .byte 0xdd, 0x58, 0xa8, 0xf5, 0xff, 0
 .balign 4
fh_tgui:
 .long 0x610fd0f7, fb_tgui        /* the rear dial on the film selection row: the GUI task's dispatch of an event */
 .byte 0xcd, 0x96, 0x8e, 0xf0, 0x30, 0
 .balign 4
fh_tmx:
 .long 0x60ceb800, fb_tmx         /* test 34 / 35: a shooting sequence's burst limit just set (0x60ceb717) */
 .byte 0xfc, 0xcc, 0x71, 0xfa, 0xec, 0
 .balign 4
 .long 0

 .balign 4
fb_end:                           /* the build checks nothing past here but zeros; the relocations follow */
