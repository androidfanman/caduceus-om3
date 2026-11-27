/* #114 fix114-2 (owner, 2026-11-27: "skip them in art bracketing"): ART BKT does not take COLOR 1-4.
 * A film with Film Grain and ART BKT restarted the camera (reporter and owner's camera), and a COLOR in the bracket is
 * developed from the camera's own COLOR values anyway, not our film (owner's camera, 2026-11-27). So:
 * - the ART BKT Setting list has no COLOR 1-4 rows: its two list records (0x6163faf0 / 0x6163fafc: table 0x60380070,
 *   48 picture-mode codes) count 44, the four COLOR codes moved past the end (DATA in build.py);
 * - a COLOR 1-4 tick left from before (setting 35668, ART BKT ticks indexed by picture-mode code; COLOR 1-4 = codes
 *   0x417..0x41a; the camera's setter also clears its mirror, setting 63521) is cleared here at each shutter event,
 *   through the camera's own getter and setter, called as the ART BKT list's own get / set wrappers call them
 *   (0x60419834 / 0x6041985a). Nothing is written when no COLOR is ticked (the usual case). */
 .set AB_ID, 35668                /* ART BKT ticks */
 .set AB_STO, 0x62a90f44          /* its store pointer, as 0x60419849 / 0x60419871 load it; AB_GET / AB_SET: editor.ld */
 .set AB_MIR, 63521               /* its mirror (index = code - AB_C1 for COLOR 1-4) */
 .set AB_C1, 0x417                /* COLOR 1's picture-mode code; COLOR 2-4 follow */

.section .ext6,"ax"                /* section 6's tail: loaded with lg_pr's code (static:section-order) */
ab_clr:                           /* `call ab_clr,[d2,d3,a2,a3],20` from lg_pr (HLS_EVENT task, each shutter event) */
 mov AB_C1,d2
1:
 mov d2,d1
 mov AB_ID,d0
 mov (AB_STO),a0
 call AB_GET,[],4
 cmp 0,d0
 beq 2f
 mov d2,d1
 mov AB_ID,d0
 mov (AB_STO),a0
 clr d3
 mov d3,a1
 call AB_SET,[d2,d3,a2,a3],40
2:
 mov d2,d1                        /* its mirror, setting 63521, index 0..3, store 0: the camera writes it with the */
 add -AB_C1,d1                    /* tick (0x60063431 from 0x6006351d's path); the ART BKT screen's ticks show it */
 clr d0                           /* (om-emu: 35668 cleared alone, the screen kept the ticks) */
 mov d0,a0
 mov AB_MIR,d0
 call AB_GET,[],4
 cmp 0,d0
 beq 3f
 mov d2,d1
 add -AB_C1,d1
 clr d3
 mov d3,a0
 mov d3,a1
 mov AB_MIR,d0
 call AB_SET,[d2,d3,a2,a3],40
3:
 add 1,d2
 cmp AB_C1 + 4,d2
 bne 1b
 ret [d2,d3,a2,a3],20

