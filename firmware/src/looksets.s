/* ------------------------------------------------------------------ look sets, probe w1 (experiment/look-sets-walk)
 * Question: can our code list the files in C:\OM3MOD\LOOKS with the camera's own directory walk, from the HLS_EVENT
 * task at a half-press (where the loaders already read the card)?
 * The walk is the one the camera's file debug shell's `ls` uses (0x608d1013 builds its request, 0x608c864b runs it;
 * research/NOTES.md "Look sets"). Request block (128 B): +0 user word, +4 u16 1, +6 u16 the drive (0x60365ba8),
 * +8 the start directory (-1: the walk takes the drive's own), +12 the path (FAT form: each name 11 characters,
 * space-padded, joined by '/', no leading '/'; 0 = the start directory), +16 the 11-character pattern ('?' any),
 * +20 0, +52 the callback, entered with `calls`, a0 = the request, a1 = the entry; it returns d0 0 to go on.
 * Entry: (4,a1) the 11-character name; the attribute byte through 0x608c05ea (`call ..,[],0`, a0 = the entry).
 * This probe: once per power-on, at the first shutter event with a medium mounted (hl_ok), from lg_pr after
 * el_card; up to LS_MAX names into ls_nm; CADLOG gets a "Look sets:" line. Nothing else changes. */
.set LS_MAX, 16
.set LS_DRIVE, 0x60365ba8
.section .ext13,"ax"
/* ls_scan: `call ls_scan,[d2,d3,a2,a3],36` from lg_pr (HLS_EVENT task) */
ls_scan:
 movbu (ls_done),d0
 cmp 0,d0
 bne 9f
 call hl_ok,[a2],16
 cmp 0,d0
 bne 9f                           /* no medium yet: the next shutter event tries again */
 mov 1,d0
 movbu d0,(ls_done)
 mov (USCLK),d0
 mov d0,(ls_t0)
 clr d0
 movbu d0,(ls_n)
 mov ls_rq,a0                     /* the request block, zeroed */
 mov 128,d1
 call ub_zero,[],0
 mov ls_rq,a0
 mov 1,d0
 movhu d0,(4,a0)
 movhu (LS_DRIVE),d0
 movhu d0,(6,a0)
 mov -1,d0
 mov d0,(8,a0)
 mov ls_path,d0
 mov d0,(12,a0)
 mov ls_pat,d0
 mov d0,(16,a0)
 mov ls_cb,d0
 mov d0,(52,a0)
 call ls_walk,[d2,d3,a2,a3],32
 mov d0,(ls_res)
 mov (USCLK),d1
 mov (ls_t0),d0
 sub d1,d0                        /* USCLK counts down */
 mov d0,(ls_t0)
9:
 ret [d2,d3,a2,a3],36

/* ls_cb: the walk's callback (`calls`), a1 = the entry -> d0 0 (go on). Files only (not a directory or the volume). */
ls_cb:
 movm [d2,d3,a2,a3],(sp)
 add -8,sp
 mov a1,a2
 mov a2,a0
 call ls_attr,[],0
 and 0x18,d0                      /* 0x10 directory, 0x08 volume label */
 bne 8f
 movbu (ls_n),d0
 cmp LS_MAX,d0
 bcc 8f
 mov d0,d1
 inc d1
 movbu d1,(ls_n)
 mov d0,d1                        /* x 12 */
 add d1,d1
 add d0,d1
 asl 2,d1
 mov ls_nm,a0
 add d1,a0
 mov (4,a2),a1
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
8:
 clr d0
 ret [d2,d3,a2,a3],24

/* ls_txt: `call ls_txt,[d2,d3,a2,a3],24` from the debug log writer: "Look sets: scanned S, walk result R, N files
 * in OM3MOD\LOOKS (T us): NAME1 NAME2 ..." */
ls_txt:
 LGS lsl_1
 movbu (ls_done),d0
 LGD
 LGS lsl_2
 mov (ls_res),d0
 LGD
 LGS lsl_3
 movbu (ls_n),d0
 LGD
 LGS lsl_4
 mov (ls_t0),d0
 LGD
 LGS lsl_5
 clr d2
1:
 movbu (ls_n),d0
 cmp d0,d2
 bcc 9f
 mov d2,d1
 add d1,d1
 add d2,d1
 asl 2,d1
 mov ls_nm,a0
 add d1,a0
 call lg_s,[],0
 LGS lsl_6
 inc d2
 bra 1b
9:
 ret [d2,d3,a2,a3],24
lsl_1:
 .asciz "\r\nLook sets: scanned "
lsl_2:
 .asciz ", walk result "
lsl_3:
 .asciz ", files "
lsl_4:
 .asciz " in OM3MOD\\LOOKS ("
lsl_5:
 .asciz " us):"
lsl_6:
 .asciz " |"
ls_path:
 .ascii "OM3MOD     /LOOKS      "
 .byte 0
ls_pat:
 .ascii "????????BIN"
 .byte 0
 .balign 4
ls_res:
 .long 0
ls_t0:
 .long 0
ls_rq:
 .space 128
ls_nm:
 .space 12 * LS_MAX
ls_done:
 .byte 0
ls_n:
 .byte 0
 .balign 4
