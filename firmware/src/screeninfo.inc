/* Screen info (feature/screen-info): ids and the id check, used by sl_get / sl_set / sl_cnt / sl_vbi / sl_sel /
 * ed_default before screeninfo.s (included at the end of editor.s) defines the handlers. */
 .set SIB, 0x7d00                 /* our setting ids SIB + 32 * page + k (clear of 0x7e00.. and the string ids) */
 .set SI_N, 96                    /* 3 pages x 32 (s3; s2 had 16) */
 .set SI_K, 17                    /* items per page (s3: 14 + subject detection, exposure meter, aspect) */
 .set VSB, 0x7d60                 /* one global Video Sharpening Off tick, not a per-display hide bit */
 .set ST_VS, 0x7f75
 .set SI_C, 0x6295c700            /* M image 0x62920700 + 0x3C000 */
 .set SI_U, 0xa295c700
 .set SI_MAGIC, 0x49334d4f        /* "OM3I" */
 .set SI_VER, 1
 .set SI_LEN, 40                  /* +0 magic, +4 u16 ver, +6 u16 len, +8 CRC-32 of 12.., +12 rear Information 1 / 2 /
                                   * 3 masks, +24 viewfinder 1 / 2 / 3 (not used in s1), +36 bit 0 video sharpening Off */
 .set SI_FR, 32                   /* our pushes below the updater's frame: movm 16 + 16 */

 .macro SICHK to                  /* d0 one of our ids -> jmp \to (flags only) */
 cmp VSB,d0
 beq 76f
 cmp SIB,d0
 bcs 77f
 cmp SIB + SI_N,d0
 bcc 77f
76:
 jmp \to
77:
 .endm

