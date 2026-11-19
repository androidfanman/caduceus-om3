/* Halation Radius (owner, 2026-11-19): Tight / Medium / Wide beside Bloom (v0.40's pass, the default).
 *
 * The block's capture code calls HL_RUN = hl_sel. hl_sel sends Bloom (hr_rad = 0) to v0.40's hl_run as it is, so
 * Bloom stays byte for byte v0.40; any other radius runs hr_run, the same pass on 16 px cells with a peak-preserving
 * spread (research/halation-radius/hr_model.py is its exact model):
 *   A. every 4th row, Y0 of every pair (hr_pa): per 16 x 16 px cell (8 pairs) the excess over HL_T (Ef) and the Y0 >> 2
 *      sum (Qf); the cell's w = min(255, HL_WMUL (255 - 4 Qf / samples)) in place of Qf; Bloom's 64 px excess grid E6
 *      (2 x the sum of 4 x 4 cells) for the bright-frame decision, made as hl_run makes it (its blurs, mix and table)
 *   B. v = (32 Ef HR_GAIN + 128) >> 8; across every row, then down every column, forward and back:
 *      v[i] = max(v[i], (v[i -/+ 1] D) >> 8) (hr_dk; D by radius: the glow falls to 10 % at 32 / 64 / 128 px); one
 *      [1 2 1] pass (hl_blur); u by v0.40's table, g = (((u gmax) >> 8) sc) >> 8
 *   C. as hl_run's pass C on 16 px cells: bands of 16 rows (8 at the top), segments of 8 pairs (hr_bd / hr_row), the
 *      ends lerped down by hl_lp with wy x 4 (= /16) and across by hl_sp with the step x 4 (= /8): v0.40's paint
 * The grids live in a work area in the GX4-proven reserve after the debug log (build.py checks it is free and loads it),
 * through its cached view; FLUSH after zeroing and at the end. One pass at a time owns it (hr_busy, bset on the
 * uncached alias); a second pass at the same moment, or a frame with more than HR_MAXC cells, gets Bloom.
 * hr_run has hl_run's frame (`call ..,[d2,d3,a2,a3],124`) and the same locals, which hr_bd / hr_row read:
 * (4) rec, (8) gmax, (12) W, (16) H, (20) pitch, (24) bus, (28) pairs, (32) GW, (36) GH, (40) Ef / v / g, (44) the
 * list, (48) K / n_lo, (52) y, (56) token, (60) cached, (64) row address / sc, (68) pass C's rows per lock, (72) cells,
 * (76) rows in this group, (80) Qf / w, (84) B row - A row bytes, (88) n / the row estimate, (92) the band's end / cx,
 * (96) the band's A row bytes / cy, (100) n_hi / the list's length / sampled rows of a cell row, (104) E6's row. */

 .section .ext14,"ax"

 .set HR_WRK, 0x60fc4000          /* the work area (build.py: free in the image, loaded) */
 .set HR_MAXC, 81920              /* fine cells (5184 x 3888 = 78,732) */
 .set HR_MAXC6, 8192              /* 64 px cells */
 .set HR_EF, HR_WRK               /* Ef, then v, then g (u16) */
 .set HR_QF, HR_EF + 2 * HR_MAXC  /* Qf, then w (u16) */
 .set HR_E6, HR_QF + 2 * HR_MAXC  /* Bloom's 64 px excess, then its mix */
 .set HR_E6B, HR_E6 + 2 * HR_MAXC6 /* its broad copy */
 .set HR_LIST, HR_E6B + 2 * HR_MAXC6 /* the band's segments, (first pair, pairs) u16 pairs: GW + 1 <= 513 of them */
 .set HR_END, HR_LIST + 4096
 .set HR_GAIN, 66                 /* Medium's edge glow matched to Bloom's (research tune_one.py) */

/* hl_sel: `call hl_sel,[d2,d3,a2,a3],124`, as hl_run (a0 = buffer record, d0 = strength): by hr_rad. */
 .globl hl_sel
hl_sel:
 movbu (hr_rad),d1
 cmp 0,d1
 bne 1f
 jmp hl_run
1:
 jmp hr_run

hr_run:
 mov a0,(4,sp)
 mov d0,(hr_lv)
 cmp 1,d0
 bcs 99f
 cmp 5,d0
 bhi 99f
 add -1,d0
 asl2 d0
 mov hl_gmax,a1
 add d0,a1
 mov (a1),d0
 mov d0,(8,sp)
 movhu (16,a0),d0                 /* format 0x0c02 only (as hl_run) */
 cmp 0x0c02,d0
 bne 99f
 mov (4,a0),d0
 cmp 0,d0
 bne 99f
 movhu (20,a0),d0                 /* W: 64 .. 8192, a multiple of 4 */
 cmp 64,d0
 bcs 99f
 cmp 8193,d0
 bcc 99f
 btst 3,d0
 bne 99f
 mov d0,(12,sp)
 lsr 1,d0
 mov d0,(28,sp)
 movhu (18,a0),d1                 /* memHw >= W */
 mov (12,sp),d0
 cmp d0,d1
 bcs 99f
 add d1,d1
 mov d1,(20,sp)
 movhu (22,a0),d1                 /* H >= 64 */
 cmp 64,d1
 bcs 99f
 mov d1,(16,sp)
 mov (a0),d0
 mov d0,(24,sp)
 mov (12,sp),d0                   /* GW, GH, cells (16 px) */
 add 15,d0
 lsr 4,d0
 mov d0,(32,sp)
 mov (16,sp),d1
 add 15,d1
 lsr 4,d1
 mov d1,(36,sp)
 mul d1,d0
 mov d0,(72,sp)
 cmp HR_MAXC,d0
 bhi 98f                          /* too many cells for the work area: Bloom */
 mov (12,sp),d0                   /* Bloom's 64 px grid */
 add 63,d0
 lsr 6,d0
 mov d0,(hr_gw6)
 mov (16,sp),d1
 add 63,d1
 lsr 6,d1
 mov d1,(hr_gh6)
 mul d1,d0
 mov d0,(hr_c6)
 cmp HR_MAXC6,d0
 bhi 98f
 asl 16,d1
 mov (hr_gw6),d0
 or d0,d1
 mov d1,(hr_d6)                   /* GW6 | GH6 << 16 */
 mov hr_busy + 0x40000000,a0      /* the work area: one pass at a time */
 mov 1,d0
 bset d0,(a0)
 bne 98f
 movbu (hr_rad),d0                /* D for the radius (1..3; anything else: Medium) */
 cmp 4,d0
 bcs 1f
 mov 2,d0
1:
 cmp 0,d0
 bne 2f
 mov 2,d0
2:
 asl2 d0
 mov hr_dtab,a0
 add d0,a0
 mov (a0),d0
 mov d0,(hr_d)
 mov HR_EF,d0
 mov d0,(40,sp)
 mov HR_LIST,d0
 mov d0,(44,sp)
 mov HR_QF,d0
 mov d0,(80,sp)
 mov (40,sp),a0                   /* zero Ef and Qf */
 mov (80,sp),a1
 mov (72,sp),d1
 clr d0
3:
 movhu d0,(a0)
 movhu d0,(a1)
 add 2,a0
 add 2,a1
 add -1,d1
 bne 3b
 call FLUSH,[d2,d3],16            /* our lines out, and no stale lines in the window's cached view */
 clr d0
 call hl_tk,[d2,d3],12

 /* ---- A. every 4th row, Y0 of every pair (hr_pa); K sampled rows per lock */
 mov (28,sp),d0                   /* K = max(1, HL_LOCKN / (HL_PA_PAIR pairs + HL_PA_CELL GW + 40)) */
 mov HL_PA_PAIR,d1
 mul d1,d0
 mov (32,sp),d1
 mov HL_PA_CELL,d2
 mul d2,d1
 add d1,d0
 add 40,d0
 mov d0,d1
 mov HL_LOCKN,d0
 call hl_div,[d2,d3,a2,a3],20
 cmp 1,d0
 bcc 5f
 mov 1,d0
5:
 mov d0,(48,sp)
 clr d0
 mov d0,(52,sp)
10:
 mov (16,sp),d1                   /* this group: min(K, the sampled rows left) */
 mov (52,sp),d0
 sub d0,d1
 add 3,d1
 lsr 2,d1
 mov (48,sp),d0
 cmp d0,d1
 bcc 11f
 mov d1,d0
11:
 mov d0,(76,sp)
12:
 mov (76,sp),d1                   /* rows y, y + 4, ..: 4 (K - 1) pitch + 4 pairs bytes */
 add -1,d1
 asl2 d1
 mov (20,sp),d0
 mul d0,d1
 mov (28,sp),d0
 asl2 d0
 add d0,d1
 mov (52,sp),d0
 mov (20,sp),d2
 mul d2,d0
 mov (24,sp),d2
 add d2,d0
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 bne 13f
 mov (76,sp),d0                   /* across the window's edge: one row at a time */
 cmp 1,d0
 beq 18f
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov 1,d0
 mov d0,(76,sp)
 bra 12b
13:
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 14f
 add -0x40000000,d0               /* the window's cached view */
 mov 1,d1
14:
 mov d1,(60,sp)
 mov d0,(64,sp)
15:
 mov (52,sp),d0                   /* this row's Ef and Qf rows */
 lsr 4,d0
 mov (32,sp),d1
 mul d1,d0
 add d0,d0
 mov (40,sp),a2
 add d0,a2
 mov (80,sp),a3
 add d0,a3
 mov (64,sp),a0
 mov (28,sp),d0
 call hr_pa,[d2,d3,a2,a3],24
 mov (20,sp),d1
 asl2 d1
 mov (64,sp),d0
 add d1,d0
 mov d0,(64,sp)
 mov (52,sp),d0
 add 4,d0
 mov d0,(52,sp)
 mov (76,sp),d0
 add -1,d0
 mov d0,(76,sp)
 bne 15b
 mov (60,sp),d0
 cmp 0,d0
 beq 17f
 call FLUSH,[d2,d3],16
17:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 bra 19f
18:                               /* a row across the window's edge: not counted (as hl_run) */
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov (52,sp),d0
 add 4,d0
 mov d0,(52,sp)
19:
 call hl_yld,[d2,d3,a2,a3],20     /* the CPU to the camera while the button is half-pressed (as hl_run) */
 mov (52,sp),d0
 mov (16,sp),d1
 cmp d1,d0
 bcs 10b
 mov 1,d0
 call hl_tk,[d2,d3],12

 /* ---- w in place of Qf (B = 4 Qf / samples, a full cell: Qf >> 3), and E6 += each cell's Ef */
 mov HR_E6,a0
 mov (hr_c6),d1
 clr d0
20:
 movhu d0,(a0)
 add 2,a0
 add -1,d1
 bne 20b
 mov (80,sp),a2
 mov (40,sp),a3
 clr d0
 mov d0,(96,sp)                   /* cy */
21:
 mov (96,sp),d0                   /* sampled rows of this cell row: (min(16, H - 16 cy) + 3) >> 2 */
 asl 4,d0
 mov (16,sp),d1
 sub d0,d1
 cmp 16,d1
 bls 22f
 mov 16,d1
22:
 add 3,d1
 lsr 2,d1
 mov d1,(100,sp)
 mov (96,sp),d0                   /* E6's row */
 lsr 2,d0
 mov (hr_gw6),d1
 mul d1,d0
 add d0,d0
 add HR_E6,d0
 mov d0,(104,sp)
 clr d0
 mov d0,(92,sp)                   /* cx */
23:
 mov (92,sp),d0                   /* E6[cy / 4][cx / 4] += Ef */
 lsr 2,d0
 add d0,d0
 mov (104,sp),a0
 add d0,a0
 movhu (a3),d0
 movhu (a0),d1
 add d1,d0
 movhu d0,(a0)
 add 2,a3
 mov (92,sp),d0                   /* pairs of this cell column: min(8, pairs - 8 cx) */
 asl 3,d0
 mov (28,sp),d1
 sub d0,d1
 cmp 8,d1
 bls 24f
 mov 8,d1
24:
 mov (100,sp),d0
 mul d0,d1                        /* samples */
 movhu (a2),d0
 cmp 32,d1
 bne 25f
 lsr 3,d0                         /* 4 Qf / 32 */
 bra 26f
25:
 asl2 d0
 call hl_div,[d2,d3,a2,a3],20     /* B */
26:
 mov 255,d1
 sub d0,d1
 mov HL_WMUL,d0
 mul d0,d1
 cmp 255,d1
 bls 27f
 mov 255,d1
27:
 movhu d1,(a2)
 add 2,a2
 mov (92,sp),d0
 inc d0
 mov d0,(92,sp)
 mov (32,sp),d1
 cmp d1,d0
 bcs 23b
 mov (96,sp),d0
 inc d0
 mov d0,(96,sp)
 mov (36,sp),d1
 cmp d1,d0
 bcs 21b

 /* ---- Bloom's bright-frame decision on E6 (2 x the sums): its blurs, mix, table and count, as hl_run */
 mov HR_E6,a0
 mov HR_E6B,a1
 mov (hr_c6),d1
30:
 movhu (a0),d0
 add d0,d0
 movhu d0,(a0)
 movhu d0,(a1)
 add 2,a0
 add 2,a1
 add -1,d1
 bne 30b
 mov HR_E6,a0
 mov HL_BLUR,d0
 mov (hr_d6),d1
 call hl_blur,[d2,d3,a2,a3],44
 mov HR_E6B,a0
 mov HL_BLUR2,d0
 mov (hr_d6),d1
 call hl_blur,[d2,d3,a2,a3],44
 mov HR_E6,a0                     /* v6 = (E6 (256 - HL_MIX) + E6B HL_MIX + 128) >> 8; n = cells with u6 >= HL_COVU */
 mov HR_E6B,a1
 mov (hr_c6),d3
 mov 0,a2                         /* n */
31:
 movhu (a0),d0
 mov 256 - HL_MIX,d1
 mul d1,d0
 movhu (a1),d1
 mov HL_MIX,d2
 mul d2,d1
 add d1,d0
 add 128,d0
 lsr 8,d0
 cmp 1024,d0
 bcc 32f
 lsr 2,d0
 mov hl_lo,a3
 bra 34f
32:
 lsr 8,d0
 cmp 255,d0
 bls 33f
 mov 255,d0
33:
 mov hl_hi,a3
34:
 add d0,a3
 movbu (a3),d0                    /* u6 */
 cmp HL_COVU,d0
 bcs 35f
 inc a2
35:
 add 2,a0
 add 2,a1
 add -1,d3
 bne 31b
 mov a2,d0
 mov d0,(88,sp)
 mov (hr_c6),d0                   /* n_lo, n_hi = cells6 x HL_COVLO / 100, x HL_COVHI / 100 */
 mov HL_COVLO,d1
 mul d1,d0
 mov 100,d1
 call hl_div,[d2,d3,a2,a3],20
 mov d0,(48,sp)
 mov (hr_c6),d0
 mov HL_COVHI,d1
 mul d1,d0
 mov 100,d1
 call hl_div,[d2,d3,a2,a3],20
 mov d0,(100,sp)
 mov (88,sp),d2
 cmp d0,d2
 bcc 90f                          /* too much of the frame is bright: no halation (as Bloom) */
 mov 256,d0
 mov (48,sp),d1
 cmp d1,d2
 bls 36f
 mov (100,sp),d0                  /* sc = ((n_hi - n) 256) / (n_hi - n_lo) */
 sub d2,d0
 asl 8,d0
 mov (100,sp),d2
 sub d1,d2
 mov d2,d1
 call hl_div,[d2,d3,a2,a3],20
36:
 mov d0,(64,sp)

 /* ---- B. the spread: v = (32 Ef HR_GAIN + 128) >> 8, then hr_dk across every row and down every column, then one
  * [1 2 1] pass */
 mov (40,sp),a0
 mov (72,sp),d3
37:
 movhu (a0),d0
 mov 32 * HR_GAIN,d1
 mul d1,d0
 add 128,d0
 lsr 8,d0
 movhu d0,(a0)
 add 2,a0
 add -1,d3
 bne 37b
 clr d0
 mov d0,(96,sp)
38:
 mov (96,sp),d0                   /* row cy */
 mov (32,sp),d1
 mul d1,d0
 add d0,d0
 mov (40,sp),d1
 add d1,d0
 mov d0,a0
 mov (32,sp),d0
 mov 2,d1
 call hr_dk,[d2,d3,a2,a3],20
 mov (96,sp),d0
 inc d0
 mov d0,(96,sp)
 mov (36,sp),d1
 cmp d1,d0
 bcs 38b
 clr d0
 mov d0,(96,sp)
39:
 mov (96,sp),d0                   /* column cx */
 add d0,d0
 mov (40,sp),d1
 add d1,d0
 mov d0,a0
 mov (36,sp),d0
 mov (32,sp),d1
 add d1,d1
 call hr_dk,[d2,d3,a2,a3],20
 mov (96,sp),d0
 inc d0
 mov d0,(96,sp)
 mov (32,sp),d1
 cmp d1,d0
 bcs 39b
 mov (36,sp),d1
 asl 16,d1
 mov (32,sp),d0
 or d0,d1
 mov (40,sp),a0
 mov 1,d0
 call hl_blur,[d2,d3,a2,a3],44

 /* ---- the map: u by v0.40's table, g = (((u gmax) >> 8) sc) >> 8 in place; OR of g */
 mov (40,sp),a0
 mov (72,sp),d3
 clr d2
40:
 movhu (a0),d0
 cmp 1024,d0
 bcc 41f
 lsr 2,d0
 mov hl_lo,a1
 bra 42f
41:
 lsr 8,d0
 cmp 255,d0
 bls 43f
 mov 255,d0
43:
 mov hl_hi,a1
42:
 add d0,a1
 movbu (a1),d0                    /* u */
 mov (8,sp),d1
 mul d1,d0
 lsr 8,d0
 mov (64,sp),d1
 mul d1,d0
 lsr 8,d0
 movhu d0,(a0)
 or d0,d2
 add 2,a0
 add -1,d3
 bne 40b
 mov 2,d0                         /* the map done (d2 kept) */
 call hl_tk,[d2,d3],12
 cmp 2,d2
 bcs 90f                          /* no g >= 2 anywhere: nothing changes */

 /* ---- C. bands of rows that share their cell rows: the top rows (y < 8: cell row 0 alone), then per cell row r0
  * the rows 8 + 16 r0 .. + 15 (r0 and r0 + 1, wy = (y - 8) & 15), then the last rows (cell row GH - 1 alone) */
 clr d0
 mov d0,(52,sp)
50:
 mov (52,sp),d0
 mov (16,sp),d1
 cmp d1,d0
 bcc 90f
 clr d1                           /* A: cell row 0 */
 mov 8,d2                         /* the band's end */
 clr d3                           /* B - A: none */
 cmp 8,d0
 bcs 53f
 add -8,d0
 lsr 4,d0                         /* r0 */
 mov (36,sp),d1
 add -1,d1
 mov (16,sp),d2
 cmp d1,d0
 bcc 53f                          /* r0 >= GH - 1: the last row alone, to the end */
 mov d0,d1
 asl 4,d0
 add 24,d0
 mov d0,d2
 mov (32,sp),d3
 add d3,d3
53:
 mov (16,sp),d0
 cmp d0,d2
 bls 54f
 mov d0,d2
54:
 mov d2,(92,sp)
 mov d3,(84,sp)
 mov (32,sp),d0
 mul d0,d1
 add d1,d1
 mov d1,(96,sp)
 mov sp,a0
 call hr_bd,[d2,d3,a2,a3],28      /* the list, its length (100), the estimate (88) */
 mov (100,sp),d0
 cmp 0,d0
 beq 69f                          /* nothing can glow in this band */
 mov (88,sp),d1                   /* rows per lock: max(1, HL_LOCKN / the estimate) */
 mov HL_LOCKN,d0
 call hl_div,[d2,d3,a2,a3],20
 cmp 1,d0
 bcc 55f
 mov 1,d0
55:
 mov d0,(68,sp)
56:
 mov (92,sp),d1                   /* this group: min(K, the band's rows left) */
 mov (52,sp),d0
 sub d0,d1
 mov (68,sp),d0
 cmp d0,d1
 bcc 57f
 mov d1,d0
57:
 mov d0,(76,sp)
58:
 mov (76,sp),d1                   /* rows y .. y + K - 1: (K - 1) pitch + 4 pairs bytes */
 add -1,d1
 mov (20,sp),d0
 mul d0,d1
 mov (28,sp),d0
 asl2 d0
 add d0,d1
 mov (52,sp),d0
 mov (20,sp),d2
 mul d2,d0
 mov (24,sp),d2
 add d2,d0
 call hl_open,[d2,d3,a2,a3],28
 mov d0,(56,sp)
 cmp 0,a0
 bne 60f
 mov (76,sp),d0                   /* across the window's edge: one row at a time */
 cmp 1,d0
 beq 66f
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov 1,d0
 mov d0,(76,sp)
 bra 58b
60:
 mov a0,d0
 clr d1
 cmp 0xb8000000,d0
 bcs 61f
 add -0x40000000,d0               /* the window's cached view */
 mov 1,d1
61:
 mov d1,(60,sp)
 mov d0,(64,sp)
62:
 clr d2                           /* wy x 4: ((y - 8) & 15) x 4 in a band of two cell rows, else 0 (hl_lp is /64) */
 mov (84,sp),d0
 cmp 0,d0
 beq 63f
 mov (52,sp),d2
 add -8,d2
 and 15,d2
 asl2 d2
63:
 mov (64,sp),a0
 mov sp,a1
 call hr_row,[d2,d3,a2,a3],72
 mov (64,sp),d0
 mov (20,sp),d1
 add d1,d0
 mov d0,(64,sp)
 mov (52,sp),d0
 inc d0
 mov d0,(52,sp)
 mov (76,sp),d0
 add -1,d0
 mov d0,(76,sp)
 bne 62b
 mov (60,sp),d0
 cmp 0,d0
 beq 65f
 call FLUSH,[d2,d3],16
65:
 mov (56,sp),d0
 call UNLOCK,[d2],8
 bra 67f
66:                               /* a row across the window's edge: left as it is (as hl_run) */
 mov (56,sp),d0
 call UNLOCK,[d2],8
 mov (52,sp),d0
 inc d0
 mov d0,(52,sp)
67:
 call hl_yld,[d2,d3,a2,a3],20
 mov (52,sp),d0
 mov (92,sp),d1
 cmp d1,d0
 bcs 56b
 jmp 50b
69:
 mov (92,sp),d0
 mov d0,(52,sp)
 jmp 50b
90:
 mov 3,d0                         /* the end */
 call hl_tk,[d2,d3],12
 call FLUSH,[d2,d3],16            /* our lines out of this CPU's cache: the next pass may run on another CPU */
 mov hr_busy + 0x40000000,a0
 clr d0
 movbu d0,(a0)
99:
 ret [d2,d3,a2,a3],124
98:                               /* Bloom for this photo */
 mov (4,sp),a0
 mov (hr_lv),d0
 jmp hl_run

/* hr_pa: `call hr_pa,[d2,d3,a2,a3],24`, a0 = the row's first pair, d0 = pairs, a2 / a3 = this row's Ef / Qf cells
 * (u16): per cell (8 pairs, fewer in the last column) Ef += sum of max(0, Y0 - HL_T), Qf += sum of Y0 >> 2. A full
 * cell: one run of eight Y0, ORed and compared once (HLA8); hl_x8 only when the OR is above HL_T.
 * Locals (0) call slot (hl_x8), (4) the row's end. */
hr_pa:
 asl2 d0
 add a0,d0
 mov d0,(4,sp)
1:
 mov (4,sp),d0
 mov a0,d1
 sub d1,d0                        /* bytes left in the row */
 beq 9f
 clr d2                           /* Y0 >> 2 sum */
 clr d3                           /* excess sum */
 cmp 32,d0
 bcs 5f
 HLA8 0
 add 32,a0
 bra 6f
5:                                /* the last column's part cell: one pair a turn */
 mov a0,a1
 add d0,a1
7:
 movbu (a0),d0
 mov d0,d1
 lsr 2,d1
 add d1,d2
 cmp HL_T,d0
 bls 8f
 add -HL_T,d0
 add d0,d3
8:
 add 4,a0
 cmp a1,a0
 bne 7b
6:
 movhu (a2),d0
 add d3,d0
 movhu d0,(a2)
 add 2,a2
 movhu (a3),d0
 add d2,d0
 movhu d0,(a3)
 add 2,a3
 bra 1b
9:
 ret [d2,d3,a2,a3],24

/* hr_dk: `call hr_dk,[d2,d3,a2,a3],20`, a0 = first value (u16), d0 = n >= 1, d1 = stride in bytes, in place: forward
 * v[i] = max(v[i], (v[i - 1] D) >> 8) for i = 1..n-1, then back v[i] = max(v[i], (v[i + 1] D) >> 8) for i = n-2..0
 * (D = hr_d). */
hr_dk:
 mov d1,a2                        /* stride */
 mov (hr_d),d3
 mov d0,a3                        /* n */
 movhu (a0),d2                    /* prev */
 mov a0,a1
 mov a3,d1
 add -1,d1
 beq 9f
1:
 add a2,a1
 mov d2,d0
 mul d3,d0
 lsr 8,d0
 movhu (a1),d2
 cmp d2,d0
 bls 2f
 mov d0,d2
 movhu d2,(a1)
2:
 add -1,d1
 bne 1b
 mov a3,d1                        /* back from the last (d2 = its value) */
 add -1,d1
3:
 mov a1,d0
 mov a2,a0
 sub a0,d0
 mov d0,a1
 mov d2,d0
 mul d3,d0
 lsr 8,d0
 movhu (a1),d2
 cmp d2,d0
 bls 4f
 mov d0,d2
 movhu d2,(a1)
4:
 add -1,d1
 bne 3b
9:
 ret [d2,d3,a2,a3],20

/* hr_bd: hl_bd on 16 px cells: segment j = 0..GW covers the pairs [0, 4) (j = 0), [8 j - 4, min(8 j + 4, pairs))
 * (0 < j < GW), [8 GW - 4, pairs) (j = GW), between the cell columns L = max(j - 1, 0) and R = min(j, GW - 1); listed
 * when g >= 2 at L or R in the band's cell row A (96) or B (A + (84)). `call hr_bd,[d2,d3,a2,a3],28`, a0 = hr_run's
 * frame. Locals (0) call slot, (4) first pair, (8) end. */
hr_bd:
 mov a0,a2
 mov (44,a2),a3
 clr d0
 mov d0,(100,a2)
 mov HL_C_ROW,d0
 mov d0,(88,a2)
 clr d3                           /* j */
1:
 clr d0                           /* first pair, end */
 mov 4,d1
 cmp 0,d3
 beq 4f
 mov d3,d0
 asl 3,d0
 add -4,d0
 mov (28,a2),d1                   /* pairs */
 cmp d1,d0
 bcc 9f                           /* past the row: no more segments */
 mov (32,a2),d2
 cmp d2,d3
 bcc 4f                           /* j = GW: to the row's end */
 mov d0,d2
 add 8,d2
 cmp d1,d2
 bcc 4f
 mov d2,d1
4:
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov d3,d0                        /* L */
 cmp 0,d0
 beq 5f
 add -1,d0
5:
 add d0,d0
 mov (40,a2),a0
 mov (96,a2),d1
 add d1,a0
 add d0,a0
 mov (84,a2),d2
 movhu (a0),d0
 movhu (d2,a0),d1
 or d1,d0
 mov (32,a2),d1                   /* R */
 add -1,d1
 cmp d1,d3
 bcc 6f
 mov d3,d1
6:
 add d1,d1
 mov (40,a2),a0
 mov (96,a2),a1
 add a1,a0
 add d1,a0
 movhu (a0),d1
 or d1,d0
 movhu (d2,a0),d1
 or d1,d0
 cmp 2,d0
 bcs 8f                           /* g <= 1 at both ends in both cell rows */
 mov (4,sp),d0
 movhu d0,(a3)
 mov (8,sp),d1
 sub d0,d1
 movhu d1,(2,a3)
 add 4,a3
 mov (100,a2),d0
 inc d0
 mov d0,(100,a2)
 mov HL_C_PAIR,d0
 mul d1,d0
 add HL_C_SEG,d0
 mov (88,a2),d1
 add d1,d0
 mov d0,(88,a2)
8:
 inc d3
 mov (32,a2),d0
 cmp d0,d3
 bls 1b
9:
 ret [d2,d3,a2,a3],28

/* hr_row: hl_row on 16 px cells (`call hr_row,[d2,d3,a2,a3],72`, a0 = the row's first pair, a1 = hr_run's frame, d2 =
 * wy x 4): j = (first pair + 4) >> 3, and hl_sp's step x 4 (its /32 then lerps across 8 pairs). Same locals as
 * hl_row (hl_lp reads (HR_WY) and (HR_DB) of this frame). */
hr_row:
 mov a1,(4,sp)
 mov a0,(8,sp)
 mov d2,(12,sp)
 mov (84,a1),d0
 mov d0,(16,sp)
 mov (44,a1),d0
 mov d0,(20,sp)
 mov (100,a1),d0
 mov d0,(24,sp)
 mov -2,d0
 mov d0,(28,sp)
1:
 mov (20,sp),a0
 movhu (a0),d3                    /* first pair */
 movhu (2,a0),d0
 add 4,a0
 mov a0,(20,sp)
 mov d0,(48,sp)
 mov d3,(52,sp)
 add 4,d3
 lsr 3,d3                         /* j */
 mov (4,sp),a1
 mov (28,sp),d0
 inc d0
 cmp d0,d3
 bne 2f
 mov (32,sp),d0                   /* follows the last one: its right end is this left end */
 mov d0,(40,sp)
 mov (36,sp),d0
 mov d0,(44,sp)
 bra 3f
2:
 mov d3,d0                        /* L = max(j - 1, 0) */
 cmp 0,d0
 beq 21f
 add -1,d0
21:
 add d0,d0
 mov d0,(32,sp)                   /* (2 L, for the w grid) */
 mov (40,a1),a0
 mov (96,a1),d1
 add d1,a0
 add d0,a0
 call hl_lp,[],0
 mov d0,(40,sp)
 mov (4,sp),a1
 mov (80,a1),a0
 mov (96,a1),d1
 add d1,a0
 mov (32,sp),d1
 add d1,a0
 call hl_lp,[],0
 mov d0,(44,sp)
 mov (4,sp),a1
3:
 mov (40,sp),d0                   /* R = min(j, GW - 1); R = L (j = 0 or j = GW): b = a */
 mov d0,(32,sp)
 mov (44,sp),d0
 mov d0,(36,sp)
 cmp 0,d3
 beq 4f
 mov (32,a1),d0
 cmp d0,d3
 bcc 4f
 mov d3,d0
 add d0,d0
 mov (40,a1),a0
 mov (96,a1),d1
 add d1,a0
 add d0,a0
 call hl_lp,[],0
 mov d0,(32,sp)
 mov (4,sp),a1
 mov (80,a1),a0
 mov (96,a1),d1
 add d1,a0
 mov d3,d1
 add d1,d1
 add d1,a0
 call hl_lp,[],0
 mov d0,(36,sp)
4:
 mov d3,(28,sp)
 mov (40,sp),d0                   /* g <= 1 at both ends: nothing changes */
 mov (32,sp),d1
 or d1,d0
 cmp 2,d0
 bcs 8f
 mov (44,sp),d2                   /* acc = (32 a_w + 16) << 16 | (32 a_g + 16), step = 4 ((b_w - a_w) << 16 + b_g - a_g) */
 mov (36,sp),d3
 sub d2,d3
 asl 16,d3
 mov (32,sp),d0
 mov (40,sp),d1
 sub d1,d0
 add d0,d3
 asl2 d3
 asl 5,d2
 add 16,d2
 asl 16,d2
 asl 5,d1
 add 16,d1
 or d1,d2
 mov (52,sp),d0
 asl2 d0
 mov (8,sp),a0
 add d0,a0
 mov (48,sp),d0
 call hl_sp,[d2,d3,a2,a3],28
8:
 mov (24,sp),d0
 add -1,d0
 mov d0,(24,sp)
 beq 9f
 jmp 1b
9:
 ret [d2,d3,a2,a3],72

 .balign 4
hr_dtab:                          /* D by radius: round(256 exp(-16 ln 10 / R)), R = 32, 64, 128 px */
 .long 144, 81, 144, 192
hr_lv:
 .long 0
hr_d:
 .long 0
hr_gw6:
 .long 0
hr_gh6:
 .long 0
hr_c6:
 .long 0
hr_d6:
 .long 0
 .globl hr_rad
hr_rad:                           /* 0 Bloom (v0.40's pass), 1 Tight, 2 Medium, 3 Wide */
 .byte 0
hr_busy:                          /* bit 0: hr_run has the work area (written through the uncached alias) */
 .byte 0
 .balign 4
