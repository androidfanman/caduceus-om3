/* ================================================================== Our version on the Firmware Version screen (fwver 1, 2026-11-18)
 * Owner (2026-11-18): "getting our firmware version listed where you can see the other firmware version in the menu".
 * MENU > wrench tab 6 > Firmware Version > OK opens a page of up to 4 lines ("Body : 1.1", "Lens : ..", ..), made by
 * the camera's Menu_Version_Viewer (its build 0x6120af34; research/NOTES.md "Our version on the Firmware Version
 * screen"). The build fills a block at viewer + 2460 (the GUI copies its first 616 bytes for the page and picks the
 * page's layout by the line count, 1..4):
 *   +0 the line count; +4 + 124 k line k's record (its label, set by 0x611c782f from a label {u16 4, u16 string id});
 *   +516 + k, +560 + k the line's ":" and value looks; +520 + 10 k the value text (UTF-16, "%X.%X", 10 bytes a line,
 *   up to +560); +564 + k, +568 + 10 k a second value (off for ours); +608 + 2 k two style bytes.
 * Every path of the build ends at 0x6120b698 (mov (20,sp),a0; mov a3,d0; movbu d0,(a0): the count a3 into +0, then
 * ret [d2,d3,a2,a3],84). fv_add takes that spot: when the camera made 1..3 lines, it adds "Caduceus : vX" as the
 * next line as the build adds a line without an update (the "else if" branches: label and value only; the looks
 * bytes keep the build's start values, so the line is plain, never the highlighted "1.1 -> 1.2" look of a pending
 * update), with our label (st_get answers ST_FWV) and firmware/VERSION's first word (fv_ver, build.py) as the
 * value. The text runs on into the free value slots after ours (the GUI copies the whole block and reads the text up
 * to its 0): 14 letters with 1 camera line, 9 with 2. A name that does not fit is left out whole (never cut short): with 3 camera lines (Body, Lens, Flash) no
 * line of ours. The page then shows the camera's own layout for one more line (as with a lens on). Its value boxes
 * are 80 px wide (for "1.1"): build.py DATA widens the 7 plain ones to 300 px.
 * Runs only when the page opens (a menu key): nothing at start-up. MDR kept. */
.section .hook_fv,"ax"
 jmp fv_add                       /* stock 0x6120b698: mov (20,sp),a0; mov a3,d0; movbu d0,(a0) */
 nop

.section .ext13,"ax"
 .set FV_LMAX, 4                  /* the page's lines, at most */
 .set FV_REC, 124                 /* a line's record */
 .set FV_VAL, 520                 /* line k's value text at +520 + 10 k ... */
 .set FV_VEND, 560                /* ... up to here */
fv_add:
 mov mdr,d3                       /* d2, d3, a2, a3: the stock ret restores them */
 mov a3,d2
 exthu d2                         /* d2 = k, our line (the camera's count) */
 cmp 1,d2
 blt 9f
 cmp FV_LMAX,d2
 bge 9f
 mov (20,sp),a2                   /* a2 = the block (viewer + 2460) */
/* the value's room, from +520 + 10 k to +560 less its 0: is the whole name there? */
 mov d2,d0
 mov 10,d1
 mul d1,d0
 mov FV_VEND - FV_VAL - 2,d1
 sub d0,d1                        /* d1 = bytes for the letters */
 mov fv_ver,a0
1:
 movhu (a0),d0
 cmp 0,d0
 beq 2f
 add -2,d1
 blt 9f                           /* too long here: no line */
 add 2,a0
 bra 1b
2:
/* the record, our label, as the build sets a line without an update (its looks stay as the build's start set them) */
 mov d2,d0
 mov FV_REC,d1
 mul d1,d0
 add 4,d0
 add a2,d0
 mov (28,sp),a0                   /* the viewer */
 mov fv_lbl,a1
 call fv_lab,[d2,a2,a3],20        /* 0x611c782f (keeps d2, a2, a3; leaves d3 for a string id label) */
/* the value text */
 mov d2,d0
 mov 10,d1
 mul d1,d0
 add FV_VAL,d0
 add a2,d0
 mov d0,a0
 mov fv_ver,a1
3:
 movhu (a1),d0
 movhu d0,(a0)
 add 2,a0
 add 2,a1
 cmp 0,d0
 bne 3b
 inc d2
 mov d2,a3                        /* one line more */
9:
 mov d3,mdr
 mov (20,sp),a0                   /* the replaced stock instructions */
 mov a3,d0
 movbu d0,(a0)
 jmp fv_back                      /* 0x6120b69e: ret [d2,d3,a2,a3],84 */

/* fv_chk <- st_get's end (editor.s st_stk; the string getter's frame, ret [d2],8; d0 the id): our label's text,
 * else on to screeninfo.s si_str (rt1: the Remaining Movie Time row), then crop.s cr_str as before */
fv_chk:
 cmp ST_FWV,d0
 bne 1f
 mov fv_str,a0
 ret [d2],8
1:
 jmp si_str

 .balign 4
fv_lbl:                           /* a label as the camera's (0x615959d8 "Body": {4, 0x6c3}), our string id */
 .short 4, ST_FWV
 .long 0
 .balign 2
fv_str:                           /* "Caduceus" */
 .short 67, 97, 100, 117, 99, 101, 117, 115, 0
 .include "fvver.inc"             /* fv_ver: firmware/VERSION's first word, UTF-16 (build.py) */
 .balign 4
