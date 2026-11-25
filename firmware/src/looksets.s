/* ------------------------------------------------------------------ look sets (feature/look-sets, ls1)
 * Film sets as files in C:\OM3MOD\LOOKS (NAME.BIN, 8.3 names, the LOOKS.BIN format), C:\OM3MOD\LOOKS.BIN the default.
 * A "Film Set" row at the end of the wrench tab's Card/Folder/File page (page 235, build.py) lists LOOKS.BIN, then
 * the folder's sets by name; a pick loads that set at the next shutter event (the half-press that closes the menu).
 * Design and edge cases: research/NOTES.md "Look sets".
 *
 * The row is setting LS_SID 1290 (the twin of 1288, PR #51's Bitrate: a movie button function of an accessory key the
 * OM-3 does not have). Entry k of the list has the value lsm_keys[k] (the first seven from 1290's stock list, 9 its
 * default, first: a fresh camera reads "LOOKS.BIN"). Invariant after every shutter event that ran ls_go with a medium:
 * the setting's entry names the set in use. Before the first one (no scan yet) the list is ls_init's: LOOKS.BIN, then
 * the set in use repeated up to the setting's entry, so the row reads right and only LOOKS.BIN is a real pick.
 *
 * Listing: the file debug shell's directory walk (ls_walk 0x608c864b; probe w1, research/NOTES.md), once per power-on
 * at the first shutter event with a medium. Loading: as el_card takes a new set (ls_rd, then nf_take: one store of
 * LPTR, the COLORs on changed films made again in every mode at the next GUI event; ub_put), but always (no seen-ring
 * test) and from the picked file. Same films as in use: nothing to take. A file that fails: the films stay and the
 * row goes back to the set in use.
 * The set in use (its 8.3 name, none = LOOKS.BIN) is kept in record 'OM3L' at M + 0x3B040 (free between 'OM3C' at
 * +0x3B000 (48 B) and 'OM3R' at +0x3B100), written as cm_wr writes 'OM3C'. While a set from the folder is in use (and
 * the films block is valid) the card's LOOKS.BIN is not taken by itself (ub_rd asks ls_auto); a pick of LOOKS.BIN
 * loads it. */
.set LS_SID, 1290
.set LS_MAX, 16                    /* list entries, LOOKS.BIN included */
.set LS_DRIVE, 0x60365ba8
.set LS_DESC, 0x6061a6a8           /* 1290's descriptor record (+12 u16 bytes of its value list; build.py sets the list) */
.set LR_C, 0x6295b740              /* M image 0x62920700 + 0x3B040 */
.set LR_U, 0xa295b740
.set LR_MAGIC, 0x4c334d4f          /* "OM3L" */
.set LR_LEN, 32                    /* +0 magic, +4 u16 1, +6 u16 32, +8 CRC-32 of 12.., +12 the 11-character name (zero:
                                    * LOOKS.BIN), +23..31 zero */
.section .ext15,"ax"                 /* as ext13, a part of section 6 (v0.40.3: ext13 is full) */

/* ls_init: `call ls_init,[d2,d3,a2,a3],20`, once per power-on (el_go in the GUI task after every section is in, or
 * ls_go): the record from M, and the list before the scan (no card access, no setting written). */
ls_init:
 movbu (ls_iok),d0
 cmp 0,d0
 bne 9f
 mov 1,d0
 movbu d0,(ls_iok)
 mov LR_C,a3
 mov (a3),d0
 cmp LR_MAGIC,d0
 bne 1f
 movhu (4,a3),d0
 cmp 1,d0
 bne 1f
 movhu (6,a3),d0
 cmp LR_LEN,d0
 bne 1f
 mov -1,d0
 mov a3,a0
 add 12,a0
 mov LR_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,a3),d1
 cmp d1,d0
 bne 1f
 mov ls_rec,a0
 mov a3,a1
 mov LR_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(ls_rok)
1:
 clr d2                           /* entry 0: LOOKS.BIN */
 mov ls_def,a1
 call ls_put,[d2,d3,a2,a3],20
 mov LS_SID,d0
 call sget,[],4
 call ls_key,[d2],8                 /* d0 = its entry, -1 none */
 mov d0,d3
 cmp 0,d3
 bge 2f
 clr d3
2:
 mov 1,d2                         /* entries 1..d3: the set in use, so the row reads it */
3:
 cmp d3,d2
 bgt 4f
 mov ls_rec + 12,a1
 call ls_put,[d2,d3,a2,a3],20
 inc d2
 bra 3b
4:
 mov d2,d0
 call ls_cnt,[],0
9:
 ret [d2,d3,a2,a3],20

/* ls_auto: `call ls_auto,[d2,d3,a2,a3],20` from ub_rd -> d0 1 when the card's LOOKS.BIN must not be taken by itself: a
 * set from the folder is in use and the films block is valid. */
ls_auto:
 call ls_init,[d2,d3,a2,a3],20
 movbu (ls_rec + 12),d0
 cmp 0,d0
 beq 9f
 call ub_chk,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],20

/* ls_go: `call ls_go,[d2,d3,a2,a3],36` from lg_pr (HLS_EVENT task, every shutter event): a held record write; with a
 * medium: a pick, and once the list. */
ls_go:
 call ls_init,[d2,d3,a2,a3],20
 movbu (ls_wp),d0
 cmp 0,d0
 beq 1f
 call ls_wr,[d2,d3,a2,a3],20
1:
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f                           /* no medium (or not this task): a pick waits */
 call ls_pick,[d2,d3,a2,a3],48
 movbu (ls_done),d0
 cmp 0,d0
 bne 9f
 mov (rc_in),d0                   /* the list's order needs the setting written after it: not before the camera's
                                   * handle is known */
 cmp 0,d0
 beq 9f
 call ls_scan,[d2,d3,a2,a3],36
 call ls_fix,[d2,d3,a2,a3],48
9:
 ret [d2,d3,a2,a3],36

/* ls_pick: `call ls_pick,[d2,d3,a2,a3],48`: the setting's entry against the set in use; another set -> ls_load. Locals
 * (4) entry, (8) P. */
ls_pick:
 mov LS_SID,d0
 call sget,[],4
 call ls_key,[d2],8
 cmp 0,d0
 blt 9f
 movbu (ls_n),d1
 cmp d1,d0
 bcc 9f                           /* an entry past the list: not a set */
 mov d0,(4,sp)
 call ls_ent,[],0                 /* a0 = its name */
 mov ls_rec + 12,a1
 call ls_eq,[d2,d3],12
 cmp 0,d0
 bne 9f                           /* the set in use */
 PVAL 9f                          /* no films loaded yet: at a later event */
 mov a2,(8,sp)
 mov (4,sp),d0
 call ls_load,[d2,d3,a2,a3],48
 movbu d0,(ls_res)
 mov (4,sp),d0                    /* the pick's row text for the log */
 call ls_txp,[],0
 mov a0,a1
 mov ls_last,a0
 mov 12,d1
 call ub_cpy,[],0
 movbu (ls_res),d0
 cmp 3,d0
 bcc 5f
 mov (4,sp),d0                    /* taken (1) or the same films (2): this set is in use now */
 call ls_ent,[],0
 mov a0,a1
 mov ls_rec + 12,a0
 mov 12,d1
 call ub_cpy,[],0
 call ls_wr,[d2,d3,a2,a3],20
 mov (8,sp),a2                    /* its built-in curves and mix, for the films in use now (the COLORs made meanwhile
                                   * from the last set's follow: ck_fixall) */
 call ck_set,[d2,d3,a2,a3],24
 movbu (ck_st),d0
 movbu d0,(ls_cst)
 bra 9f
5:
 call ls_fix,[d2,d3,a2,a3],48     /* not taken: the row back to the set in use */
9:
 ret [d2,d3,a2,a3],48

/* ls_load: `call ls_load,[d2,d3,a2,a3],48`, d0 = an entry, a2 = P -> d0 1 taken, 2 the same films as in use, 3 no file,
 * 4 not valid, 5 no memory. Locals (4) buffer, (8) P, (12) entry. */
ls_load:
 mov d0,(12,sp)
 mov a2,(8,sp)
 call ls_path,[d2,d3,a2,a3],20    /* a0 = its path */
 mov a0,(16,sp)
 mov UB_PFL + FL_SB,d0
 call malloc,[],4
 cmp 0,a0
 bne 1f
 mov 5,d0
 ret [d2,d3,a2,a3],48
1:
 mov a0,(4,sp)
 mov (16,sp),a1
 call ls_rd,[d2,d3,a2,a3],32
 cmp 1,d0
 beq 2f
 mov 3,d2
 cmp 0,d0
 beq 8f
 mov 4,d2
 bra 8f
2:
 mov (4,sp),a0                    /* the same films (records and names) as in use: nothing to take */
 call ub_id,[d2,d3],12
 mov d0,d2
 mov (8,sp),a2
 mov (LPTR,a2),a0
 cmp 0,a0
 beq 3f
 call ub_id,[d2,d3],12
 cmp d2,d0
 bne 3f
 mov 2,d2
 bra 8f
3:
 mov (8,sp),a2
 mov (4,sp),a0                    /* the camera's selection per COLOR stays (as el_card) */
 mov (LPTR,a2),a1
 cmp 0,a1
 beq 4f
 mov (16,a1),d0
 mov d0,(16,a0)
4:
 call ss_photo,[],0               /* photo: each COLOR's changes kept with the film it is on (ls_cap), before the swap */
 cmp 0,d0
 beq 41f
 mov (8,sp),a2
 call ls_cap,[d2,d3,a2,a3],28
41:
 mov (8,sp),a2
 mov 1,d0
 movbu d0,(ub_src)
 mov (4,sp),a1
 call nf_take,[d2,d3,a2,a3],20    /* #86: one store of LPTR; the COLORs on changed films made again (newfilms.s) */
 mov (8,sp),a2
 call ub_put,[d2,d3,a2,a3],20
 clr d0                           /* the debug log's per-COLOR cache answers by film number: the films changed */
 movbu d0,(lg_lv)
 movbu d0,(lg_lv + 1)
 movbu d0,(lg_lv + 2)
 movbu d0,(lg_lv + 3)
 mov (ls_nld),d0
 inc d0
 mov d0,(ls_nld)
 mov 1,d0
 ret [d2,d3,a2,a3],48
8:
 mov (4,sp),a0
 call free,[],4
 mov d2,d0
 ret [d2,d3,a2,a3],48

/* ls_cap: `call ls_cap,[d2,d3,a2,a3],28`, a2 = P: each COLOR on a film keeps what it shows now in that film's EDITS
 * record, checked against the film it is on (fl_sw's capture when a film is left). A set switch leaves every film at
 * once; without this, changes not yet captured (they are captured when a film is left) stayed in the camera's values
 * and went over the new set's film. Only a film showing changes: one EDITS record serves film slot j in every set,
 * so capturing an unchanged film would drop another set's saved changes there. Locals (4) record r, (8) its address. */
ls_cap:
 mov (TORG,a2),d0
 cmp 0,d0
 beq 9f
 clr d2
1:
 mov a2,a0
 add d2,a0
 movbu (LIDX,a0),d3
 extb d3
 cmp 1,d3
 blt 8f
 cmp 5,d3
 bgt 8f
 call fl_live,[d2,d3,a2,a3],24    /* only a film with changes on it ('*'): a saved record of this slot made for
                                     another set's film stays for that set */
 cmp 0,d0
 beq 8f
 mov d2,d0                        /* r = 5 k + look - 1 */
 asl2 d0
 add d2,d0
 add d3,d0
 add -1,d0
 mov d0,(4,sp)
 mov d0,d1                        /* 68 r */
 asl 6,d1
 asl2 d0
 add d0,d1
 mov (TORG,a2),a3
 add TWO,a3
 add 16,a3
 add d1,a3
 mov a3,(8,sp)
 call pf_capto,[d2,d3,a2,a3],28   /* keeps d2, d3, a2, a3 */
 call cv_cap,[d2,d3,a2,a3],20
 mov (4,sp),d1                    /* check: the film as built (in use now) */
 mov (LPTR,a2),a0
 asl 6,d1
 add d1,a0
 add 32,a0
 mov -1,d0
 mov 64,d1
 call sd_crc,[d2,d3],12
 not d0
 mov (8,sp),a3
 mov d0,(64,a3)
 mov (TORG,a2),a3
 add TWO,a3
 mov (4,sp),d0
 mov 1,d1
 asl d0,d1
 mov (12,a3),d0
 or d1,d0
 mov d0,(12,a3)                   /* valid */
 mov 1,d0
 movbu d0,(TW_LEN,a3)             /* EDITS to save (ub_put after the swap writes them) */
 movbu d0,(DIRTY,a2)
8:
 inc d2
 cmp 4,d2
 bcs 1b
9:
 ret [d2,d3,a2,a3],28

/* ls_rd: `call ls_rd,[d2,d3,a2,a3],32`, a0 = a buffer of UB_PFL, a1 = a path -> d0 0 no file, 1 valid, 2 not valid
 * (as ub_rd, from any path). Locals (4) handle, (8) buffer, (12) result. */
ls_rd:
 mov a0,(8,sp)
 clr d0
 mov d0,(12,sp)
 mov a1,a0
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 9f
 mov a0,(4,sp)
 mov 2,d0
 mov d0,(12,sp)
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
 mov d0,(12,sp)
9:
 mov (12,sp),d0
 ret [d2,d3,a2,a3],32

/* ls_path: `call ls_path,[d2,d3,a2,a3],20`, d0 = an entry -> a0 = its path: C:\OM3MOD\LOOKS.BIN (entry name all 0),
 * else C:\OM3MOD\LOOKS\NAME.EXT in ls_pbuf (spaces trimmed) */
ls_path:
 call ls_ent,[],0
ls_pathn:                          /* as ls_path, a0 = the name */
 movbu (a0),d0
 cmp 0,d0
 bne 1f
 mov pf_pbin,a0
 ret [d2,d3,a2,a3],20
1:
 mov a0,d3                        /* the name */
 mov a0,a2
 mov ls_pbuf,a3
 mov ls_pdir,a1
2:
 movbu (a1),d0                    /* C:\OM3MOD\LOOKS\ */
 cmp 0,d0
 beq 3f
 movbu d0,(a3)
 inc a1
 inc a3
 bra 2b
3:
 mov 8,d2
4:
 movbu (a2),d0                    /* the base name */
 cmp 32,d0
 beq 5f
 movbu d0,(a3)
 inc a2
 inc a3
 add -1,d2
 bne 4b
5:
 mov 46,d0
 movbu d0,(a3)
 inc a3
 mov d3,a2
 add 8,a2
 mov 3,d2
6:
 movbu (a2),d0                    /* the extension */
 cmp 32,d0
 beq 7f
 movbu d0,(a3)
 inc a2
 inc a3
 add -1,d2
 bne 6b
7:
 clr d0
 movbu d0,(a3)
 mov ls_pbuf,a0
 ret [d2,d3,a2,a3],20

/* ck_set: `call ck_set,[d2,d3,a2,a3],24`, a2 = P (ck_card; ls_pick after a set was taken): the curves file of the set in
 * use (ls_rec) -> ck_st 0 none, 1 taken (valid and not what the camera has: kept in M, ck_wr), 2 the same, 3 not valid;
 * then ck_bi for the films P has now and COLOR 1..4 follow it. No file or not valid: what the camera has stays, and
 * gives values only to the films it was made for (their CRC). Read into ck_rb: ck_buf may hold a write that waits. */
ck_set:
 call ls_cvp,[d2,d3,a2,a3],20     /* a0 = its path */
 clr d0
 movbu d0,(ck_st)
 mov gd_mode,a1
 call fopen,[],4
 cmp 0,a0
 beq 6f
 mov a0,a3
 mov ck_rb,a0
 mov 1,d0
 mov CK_LEN + 1,d1
 mov a3,a1
 call fread,[d2,d3,a2,a3],24
 mov d0,d2
 mov a3,a0
 call fclose,[d2,a2,a3],16
 mov 3,d0
 movbu d0,(ck_st)
 cmp CK_LEN,d2
 bne 6f
 mov ck_rb,a0
 call ck_valid,[d2,d3,a2,a3],20
 cmp 0,d0
 beq 6f
 mov 2,d0
 movbu d0,(ck_st)
 movbu (ck_have),d0
 cmp 0,d0
 beq 2f
 call ck_img,[],0
 mov a0,a1
 mov ck_rb,a0
 mov CK_LEN,d1
 call ck_cmp,[d2],8
 cmp 0,d0
 beq 6f
2:
 mov ck_buf,a0
 mov ck_rb,a1
 mov CK_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(ck_st)
 movbu d0,(ck_have)
 call ck_wr,[d2,d3,a2,a3],20
6:
 movbu (ck_have),d0
 cmp 0,d0
 beq 9f
 call ck_img,[],0
 call ck_mk,[d2,d3,a2,a3],24
 call ck_fixall,[d2,d3,a2,a3],20
9:
 ret [d2,d3,a2,a3],24

/* ck_img: `call ck_img,[],0` -> a0 = the image the camera has: ck_buf while its write waits, else the copy in M. Uses
 * d0, a0. */
ck_img:
 movbu (ck_pend),d0
 cmp 0,d0
 beq 1f
 mov ck_buf,a0
 ret [],0
1:
 mov CK_C,a0
 ret [],0

/* ls_cvp: `call ls_cvp,[d2,d3,a2,a3],20` -> a0 = the path of the curves file of the set in use: C:\OM3MOD\CURVES.BIN
 * with LOOKS.BIN, else C:\OM3MOD\LOOKS\NAME.CRV (the CURVES.BIN format; the folder's list takes only .BIN) */
ls_cvp:
 movbu (ls_rec + 12),d0
 cmp 0,d0
 bne 1f
 mov ck_path,a0
 ret [d2,d3,a2,a3],20
1:
 mov ls_cnm,a0
 mov ls_rec + 12,a1
 mov 12,d1
 call ub_cpy,[],0
 mov 67,d0                        /* "CRV" */
 movbu d0,(ls_cnm + 8)
 mov 82,d0
 movbu d0,(ls_cnm + 9)
 mov 86,d0
 movbu d0,(ls_cnm + 10)
 mov ls_cnm,a0
 call ls_pathn,[d2,d3,a2,a3],20
 ret [d2,d3,a2,a3],20

/* ls_scan: `call ls_scan,[d2,d3,a2,a3],36`: the folder's sets into entries 1.., by name (ls_cb); LOOKS.BIN entry 0;
 * the set in use added when the card has no file of it. */
ls_scan:
 mov 1,d0
 movbu d0,(ls_done)
 mov (USCLK),d0
 mov d0,(ls_t0)
 clr d2
 mov ls_def,a1
 call ls_put,[d2,d3,a2,a3],20
 mov 1,d0
 movbu d0,(ls_n)
 mov ls_rq,a0
 mov 128,d1
 call ub_zero,[],0
 mov ls_rq,a0
 mov 1,d0
 movhu d0,(4,a0)
 movhu (LS_DRIVE),d0
 movhu d0,(6,a0)
 mov -1,d0
 mov d0,(8,a0)
 mov ls_dirf,d0
 mov d0,(12,a0)
 mov ls_pat,d0
 mov d0,(16,a0)
 mov ls_cb,d0
 mov d0,(52,a0)
 call ls_walk,[d2,d3,a2,a3],32
 mov d0,(ls_wres)
 movbu (ls_n),d0
 mov d0,(ls_nf)                   /* files listed (the log) */
 movbu (ls_rec + 12),d0           /* the set in use, when not listed: added (it is in the camera) */
 cmp 0,d0
 beq 7f
 mov ls_rec + 12,a0
 call ls_find,[d2,d3,a2,a3],20
 cmp 0,d0
 bge 7f
 movbu (ls_n),d2
 cmp LS_MAX,d2
 bcs 6f
 mov LS_MAX - 1,d2
6:
 mov ls_rec + 12,a1
 call ls_put,[d2,d3,a2,a3],20
 inc d2
 movbu d2,(ls_n)
7:
 movbu (ls_n),d0
 call ls_cnt,[],0
 mov (USCLK),d1
 mov (ls_t0),d0
 sub d1,d0                        /* USCLK counts down */
 mov d0,(ls_t0)
 ret [d2,d3,a2,a3],36

/* ls_cb: the walk's callback (`calls`), a1 = the entry -> d0 0 (go on). A file (not a directory, not the volume)
 * goes into entries 1.. in name order; with the list full the rest are left out. Local (4) the shift counter. */
ls_cb:
 movm [d2,d3,a2,a3],(sp)
 add -8,sp
 mov a1,a2
 mov a2,a0
 call ls_attr,[],0
 and 0x18,d0                      /* 0x10 directory, 0x08 volume label */
 bne 8f
 movbu (ls_n),d3
 cmp LS_MAX,d3
 bcc 8f
 mov (4,a2),a3                    /* the 11-character name */
 mov 1,d2                         /* its place: after the entries 1.. that sort before it */
1:
 cmp d3,d2
 bcc 3f
 mov d2,d0
 call ls_ent,[],0
 mov a3,a1
 call ls_cmp,[d2,d3],12           /* d0 < 0: entry d2 sorts first */
 cmp 0,d0
 bge 3f
 inc d2
 bra 1b
3:
 mov d3,(4,sp)                    /* entries d2 .. n-1 one down */
4:
 mov (4,sp),d0
 cmp d2,d0
 bls 5f
 add -1,d0
 mov d0,(4,sp)
 call ls_mv,[d2,d3,a2,a3],20
 bra 4b
5:
 mov a3,a1
 call ls_put,[d2,d3,a2,a3],20
 inc d3
 movbu d3,(ls_n)
8:
 clr d0
 ret [d2,d3,a2,a3],24

/* ls_fix: `call ls_fix,[d2,d3,a2,a3],48`: the setting <- the entry of the set in use (the first one with its name), so
 * the row reads it. Needs the camera's handle (rc_in); without it, nothing. */
ls_fix:
 mov ls_rec + 12,a0
 call ls_find,[d2,d3,a2,a3],20
 cmp 0,d0
 bge 1f
 clr d0
1:
 mov lsm_keys,a0
 add d0,a0
 add d0,a0
 movhu (a0),d1
 mov (rc_in),a0
 cmp 0,a0
 beq 9f
 mov LS_SID,d0
 mov 0,a1
 call ls_sv,[d2,d3,a2,a3],36
9:
 ret [d2,d3,a2,a3],48

/* ls_sv: `call ls_sv,[d2,d3,a2,a3],36`, d0 = a setting id, d1 = the value, a0 / a1 the manager's handle / mode: the
 * manager writes it when the camera's value differs (as fw_wr until v0.40.2). Locals (4) id, (8) value, (12) a0, (16) a1. */
ls_sv:
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 call sget,[],4
 mov (8,sp),d1
 cmp d1,d0
 beq 9f
 mov (4,sp),d0
 mov (12,sp),a0
 mov (16,sp),a1
 call manager,[d2,d3,a2,a3],68
9:
 ret [d2,d3,a2,a3],36

/* ls_wr: `call ls_wr,[d2,d3,a2,a3],20`: ls_rec -> M (both aliases), as cm_wr; held while the camera saves M (ls_wp:
 * again at the next shutter event). */
ls_wr:
 mov LR_MAGIC,d0
 mov d0,(ls_rec)
 mov 1,d0
 movhu d0,(ls_rec + 4)
 mov LR_LEN,d0
 movhu d0,(ls_rec + 6)
 mov -1,d0
 mov ls_rec + 12,a0
 mov LR_LEN - 12,d1
 call sd_crc,[d2,d3],12
 not d0
 mov d0,(ls_rec + 8)
 clr d0
 call LOCK,[d2],8
 mov d0,d3
 movbu (UB_BUSY),d0
 cmp 0,d0
 bne 8f
 mov LR_C,a0
 mov ls_rec,a1
 mov LR_LEN,d1
 call ub_cpy,[],0
 mov LR_U,a0
 mov ls_rec,a1
 mov LR_LEN,d1
 call ub_cpy,[],0
 mov 1,d0
 movbu d0,(UB_DIRTY)
 clr d0
 movbu d0,(ls_wp)
 mov d3,d0
 call UNLOCK,[d2],8
 ret [d2,d3,a2,a3],20
8:
 mov 1,d0
 movbu d0,(ls_wp)
 mov d3,d0
 call UNLOCK,[d2],8
 ret [d2,d3,a2,a3],20

/* ---- small helpers */
/* ls_key: `call ls_key,[d2],8`, d0 = a value of 1290 -> d0 = its entry 0..LS_MAX-1, -1 none. Uses d1, a0, a1. */
ls_key:
 mov lsm_keys,a0
 clr d1
1:
 movhu (a0),d2
 cmp d2,d0
 beq 2f
 add 2,a0
 inc d1
 cmp LS_MAX,d1
 bcs 1b
 mov -1,d0
 ret [d2],8
2:
 mov d1,d0
 ret [d2],8

/* ls_ent / ls_txp: `call ls_ent,[],0`, d0 = an entry -> a0 = its name (12 bytes: 11 characters, 0; all 0 =
 * LOOKS.BIN) / its row text (ls_txp). Use d0, a0. */
ls_ent:
 asl2 d0
 mov d0,a0
 add d0,d0
 add a0,d0                        /* 12 x entry */
 mov ls_nm,a0
 add d0,a0
 ret [],0
ls_txp:
 asl2 d0
 mov d0,a0
 add d0,d0
 add a0,d0
 mov ls_tx,a0
 add d0,a0
 ret [],0

/* ls_eq: `call ls_eq,[d2,d3],12`, a0 / a1 two names -> d0 1 the same 11 characters, else 0. Uses d1, a0, a1. */
ls_eq:
 mov 11,d1
1:
 movbu (a0),d0
 movbu (a1),d2
 cmp d2,d0
 bne 8f
 inc a0
 inc a1
 add -1,d1
 bne 1b
 mov 1,d0
 ret [d2,d3],12
8:
 clr d0
 ret [d2,d3],12

/* ls_cmp: `call ls_cmp,[d2,d3],12`, a0 / a1 two names -> d0 < 0, 0, > 0 as a0's sorts before, with, after a1's. */
ls_cmp:
 mov 11,d1
1:
 movbu (a0),d0
 movbu (a1),d2
 sub d2,d0
 bne 9f
 inc a0
 inc a1
 add -1,d1
 bne 1b
9:
 ret [d2,d3],12

/* ls_find: `call ls_find,[d2,d3,a2,a3],20`, a0 = a name -> d0 = the first entry with it, -1 none */
ls_find:
 mov a0,a3
 clr d2
1:
 movbu (ls_n),d0
 cmp d0,d2
 bcc 8f
 mov d2,d0
 call ls_ent,[],0
 mov a3,a1
 call ls_eq,[d2,d3],12
 cmp 0,d0
 bne 7f
 inc d2
 bra 1b
7:
 mov d2,d0
 ret [d2,d3,a2,a3],20
8:
 mov -1,d0
 ret [d2,d3,a2,a3],20

/* ls_put: `call ls_put,[d2,d3,a2,a3],20`, d2 = an entry, a1 = a name (11 characters; all 0 = LOOKS.BIN): the entry's
 * name and its row text ("LOOKS.BIN", or the base name without spaces and extension). */
ls_put:
 mov d2,d0
 call ls_ent,[],0
 mov 11,d1
1:
 movbu (a1),d0
 movbu d0,(a0)
 inc a1
 inc a0
 add -1,d1
 bne 1b
 clr d0
 movbu d0,(a0)
 mov d2,d0
 call ls_txp,[],0
 mov a0,a2
 mov d2,d0
 call ls_ent,[],0
 movbu (a0),d0
 cmp 0,d0
 bne 3f
 mov ls_deft,a0                   /* LOOKS.BIN */
2:
 movbu (a0),d0
 movbu d0,(a2)
 inc a0
 inc a2
 cmp 0,d0
 bne 2b
 ret [d2,d3,a2,a3],20
3:
 mov 8,d1
4:
 movbu (a0),d0
 cmp 32,d0
 beq 5f
 movbu d0,(a2)
 inc a0
 inc a2
 add -1,d1
 bne 4b
5:
 clr d0
 movbu d0,(a2)
 ret [d2,d3,a2,a3],20

/* ls_mv: `call ls_mv,[d2,d3,a2,a3],20`, d0 = an entry: its name and text -> the next entry's */
ls_mv:
 mov d0,d2
 call ls_ent,[],0
 mov a0,a1
 mov a0,a2
 add 12,a2
 mov 12,d1
1:
 movbu (a1),d0
 movbu d0,(a2)
 inc a1
 inc a2
 add -1,d1
 bne 1b
 mov d2,d0
 call ls_txp,[],0
 mov a0,a1
 mov a0,a2
 add 12,a2
 mov 12,d1
2:
 movbu (a1),d0
 movbu d0,(a2)
 inc a1
 inc a2
 add -1,d1
 bne 2b
 ret [d2,d3,a2,a3],20

/* ls_cnt: `call ls_cnt,[],0`, d0 = the entry count: the list's (ls_n), the row's value list (lsm_val's 1290 entry,
 * the fifth) and 1290's allowed values (its descriptor's byte count), so the dropdown lists that many. Uses d0. */
ls_cnt:
 movbu d0,(ls_n)
 movhu d0,(lsm_val + 8 * 4 + 2)
 add d0,d0
 movhu d0,(LS_DESC + 12)
 ret [],0

/* ls_txt: `call ls_txt,[d2,d3,a2,a3],24` from the debug log writer: "Film sets: in use NAME, list N (files F, walk
 * W, T us): A | B ..., picks loaded L, last pick NAME result R" (R: 1 taken, 2 the same films, 3 no file, 4 not
 * valid, 5 no memory; 0 none yet); "Film set curves: last pick NAME: none / taken / the same / not valid; films with
 * built-in curves or mix in use: N" (N: the films the curves the camera has were made for) */
ls_txt:
 LGS lsl_1
 mov ls_rec + 12,a0               /* the set in use: its row text when listed, else its 8.3 name */
 call ls_find,[d2,d3,a2,a3],20
 mov ls_rec + 12,a0
 cmp 0,d0
 blt 1f
 call ls_txp,[],0
1:
 call lg_s,[],0
 LGS lsl_2
 movbu (ls_n),d0
 LGD
 LGS lsl_3
 mov (ls_nf),d0
 add -1,d0
 LGD
 LGS lsl_4
 mov (ls_wres),d0
 LGD
 LGS lsl_5
 mov (ls_t0),d0
 LGD
 LGS lsl_6
 clr d2
2:
 movbu (ls_n),d0
 cmp d0,d2
 bcc 3f
 mov d2,d0
 call ls_txp,[],0
 call lg_s,[],0
 LGS lsl_7
 inc d2
 bra 2b
3:
 LGS lsl_8
 mov (ls_nld),d0
 LGD
 LGS lsl_9
 mov ls_last,a0
 movbu (a0),d0
 cmp 0,d0
 bne 4f
 mov lsl_no,a0
4:
 call lg_s,[],0
 LGS lsl_10
 movbu (ls_res),d0
 LGD
 LGS lsl_11                       /* the pick's curves file */
 mov ls_last,a0
 movbu (a0),d0
 cmp 0,d0
 bne 5f
 mov lsl_no,a0
5:
 call lg_s,[],0
 LGS lsl_12
 movbu (ls_cst),d0
 mov lg_qst,a0
 call lg_nth,[],0
 call lg_s,[],0
 LGS lsl_13
 mov (ck_nm),d0
 LGD
 ret [d2,d3,a2,a3],24
lsl_1:
 .asciz "\r\nFilm sets: in use "
lsl_2:
 .asciz ", list "
lsl_3:
 .asciz " (files "
lsl_4:
 .asciz ", walk "
lsl_5:
 .asciz ", "
lsl_6:
 .asciz " us): "
lsl_7:
 .asciz " | "
lsl_8:
 .asciz "picks loaded "
lsl_9:
 .asciz ", last pick "
lsl_10:
 .asciz " result "
lsl_11:
 .asciz "\r\nFilm set curves: last pick "
lsl_12:
 .asciz ": "
lsl_13:
 .asciz "; films with built-in curves or mix in use: "
ls_deft:
 .asciz "LOOKS.BIN"
lsl_no:
 .asciz "none"
ls_pdir:
 .asciz "C:\\OM3MOD\\LOOKS\\"
ls_dirf:
 .ascii "OM3MOD     /LOOKS      "
 .byte 0
ls_pat:
 .ascii "????????BIN"
 .byte 0
 .balign 4
ls_def:                           /* LOOKS.BIN's name: all 0 */
 .space 12
ls_rec:                           /* the record ('OM3L'), as in M */
 .space LR_LEN
ls_last:
 .space 12
ck_rb:                            /* the card's curves file (one byte more is asked for, to see a longer file) */
 .space CK_LEN + 4
ls_cnm:                           /* the curves file's name (ls_cvp) */
 .space 12
ls_pbuf:
 .space 32
ls_wres:
 .long 0
ls_t0:
 .long 0
ls_nf:
 .long 0
ls_nld:
 .long 0
ls_rq:
 .space 128
ls_nm:
 .space 12 * LS_MAX
ls_tx:                            /* the row texts (lsm_vl points at them) */
 .asciz "LOOKS.BIN"
 .space 12 * LS_MAX - 10
ls_done:
 .byte 0
ls_n:
 .byte 1
ls_iok:
 .byte 0
ls_rok:
 .byte 0
ls_wp:
 .byte 0
ls_res:
 .byte 0
ls_cst:                           /* the last pick's curves file, as ck_st */
 .byte 0
 .balign 4

/* The menu row (build.py fills the page copies): page 235 "Card/Folder/File" gets "Film Set" (1290) at its end. */
lsm_lab:
 .space 7 * 12
lsm_hlp:
 .space 7 * 12
lsm_val:                          /* the page's value lists; 1290's (the fifth) count follows the list (ls_cnt) */
 .space 5 * 8
lsm_dd:                           /* the page's dropdown rows {14, sid, 0, 1} */
 .space 3 * 16
lsm_ro:                           /* the row order (cursor kind 239, sub 0) */
 .space 5 * 2
 .balign 4
lsm_keys:                         /* 1290's values: entry k = lsm_keys[k] (its descriptor points here: build.py) */
 .hword 9, 6, 3341, 425, 3409, 88, 3200, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009
 .balign 4
lsm_vl:                           /* the row's texts per value: {u32 value, u16 5 (literal), u16 0, u32 text} */
 .irp k, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
 .long 0
 .hword 5, 0
 .long ls_tx + 12 * \k
 .endr
lss_title:
 .asciz "Film Set"
lss_help:
 .asciz "The film set in use. Sets: OM3MOD\\LOOKS\\NAME.BIN (8 letters). Loads at the next half-press."
 .balign 4

