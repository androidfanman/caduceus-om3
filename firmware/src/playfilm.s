/* ================================================================== Playback: a photo's own film (#93, 2026-11-20)
 * The playback info screens label a photo's picture mode with the shooting screen's pictures 15706..15709 ("COLOR1"..
 * "COLOR4", the playback layouts' list at 0x613fac48), picked from the photo's own Exif (colorTone = COLOR k). fl_lvp
 * answers those with COLOR k's film now, so after COLOR 1 went from FILM 1 to FILM 3 every COLOR 1 photo in playback
 * read "FILM3" (issue #93, v0.40.2).
 * Each photo taken on a film carries "FILM n Name" in its ImageDescription (ex_fill, v0.27). The single frame's info
 * build (CPlaySingleFrame::SimplePlayCommon, GUI task) asks the play component for the photo's still info, and the
 * component reads the photo's Exif in that call through the camera's own tag read, 0x6042f92e (ex_tag: d0 the group,
 * 1 = IFD0 as for Orientation 0x112; d1 the tag; a0 a copy to make or 0; a1 its size -> a0 the tag's text in the play
 * module's copy of the photo's Exif, 0 when the photo shown has none). Right after that build's label code, at
 * crop's hook (cr_pbk1, 0x6111341e, camera-tested in crop round 9c), pb_note reads the photo's ImageDescription the
 * same way, no copy, and keeps its film in pb_fn: n (1..20), 0 for any other text (a photo with no film, another
 * camera's), 0xff when none was read. fl_lvp then (pb_lbl), in playback / image review (GUI state class 5..7) draws
 * "FILM n" for the photo's own n (no star), the camera's own "COLOR k" for a photo with no film, and as before when
 * nothing was read. Outside playback pb_fn is forgotten, so a new playback never starts from an old photo's film.
 * Nothing here runs at start-up: pb_note only in playback's info build, pb_lbl in the picture getter's chain (section 7,
 * after section 6). No new hook: the call rides crop's .hook_crk. */
.section .ext13,"ax"

pb_fn:
 .byte 0xff
pb_pre:
 .ascii "FILM "
 .balign 4

/* pb_note: `call pb_note,[d2,d3,a2,a3],24` from cr_pbk1 (in SimplePlayCommon's frame, GUI task) -> pb_fn. Keeps a1 too
 * (cr_pbk1 goes back into the stock code, which set mdr last by its own call just before); uses d0, d1, a0, mdr.
 * Frame: (0) call slot, (4) a1. */
pb_note:
 mov a1,(4,sp)
 mov 1,d0                         /* IFD0 */
 mov 270,d1                       /* ImageDescription (0x010e) */
 mov 0,a0                         /* no copy: the photo's own text */
 mov a0,a1
 call ex_tag,[d2,d3,a2,a3],80
 mov 0xff,d0
 cmp 0,a0
 beq 1f
 call pb_txt,[],4
1:
 movbu d0,(pb_fn)
 mov (4,sp),a1
 ret [d2,d3,a2,a3],24

/* pb_txt: `call pb_txt,[],4`, a0 = a photo's ImageDescription -> d0 = n for ours, "FILM n" (n 1..20, one or two
 * digits) then a space or its end, else 0. Uses d0, d1, a0, a1. */
pb_txt:
 mov pb_pre,a1
1:
 movbu (a1),d1
 movbu (a0),d0
 cmp d1,d0
 bne 8f
 inc a0
 inc a1
 cmp pb_pre + 5,a1
 bne 1b
 movbu (a0),d0                    /* the first digit */
 add -48,d0
 cmp 10,d0
 bcc 8f
 mov d0,d1
 inc a0
 movbu (a0),d0
 add -48,d0
 cmp 10,d0
 bcc 3f
 mov d1,a1                        /* a second digit: n = 10 n + it */
 asl2 d1
 add a1,d1
 add d1,d1
 add d0,d1
 inc a0
 movbu (a0),d0
 bra 4f
3:
 add 48,d0
4:
 cmp 0,d0                         /* then the text's end or a space */
 beq 5f
 cmp 32,d0
 bne 8f
5:
 mov d1,d0
 cmp 0,d0
 beq 8f
 cmp 21,d0
 bcc 8f
 ret [],4
8:
 clr d0
 ret [],4

/* pb_lbl: `call pb_lbl,[],4` from fl_lvp -> d0: in playback / image review (GUI state class 5..7) pb_fn as a number
 * (n, or 0: the photo has no film), -1 when nothing was read for it; outside playback -1, and pb_fn forgotten (0xff).
 * Uses d0, d1, a0. */
pb_lbl:
 mov (CR_GUI),a0
 cmp 0,a0
 beq 7f
 movbu (a0),d1
 cmp 5,d1
 bcs 7f
 cmp 8,d1
 bcc 7f
 movbu (pb_fn),d0
 cmp 21,d0
 bcc 8f
 ret [],4
7:
 mov 0xff,d0
 movbu d0,(pb_fn)
8:
 mov -1,d0
 ret [],4
