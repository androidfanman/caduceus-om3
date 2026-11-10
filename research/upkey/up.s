/* up key: the dispatcher's value read (0x610833b3, entered by `call ..,[d2],8`, d0 = key sid) answers the up key by
 * the arrow-pad mode, as the stock rule did: Direct Function -> the assigned function, [·:·] -> AF area (85), Off ->
 * none (3200). sid 50 / mode 158 (stills), sid 1280 / mode 1279 (movie). Other sids: the stock code. */
.section .upget,"ax"
.global up_get
up_get:
 mov d0,d2                        /* the stock first bytes: mov d0,d2; mov 3413,d1; mov d1,d0 */
 cmp 50,d2
 bne 1f
 mov 158,d0
 bra 3f
1:
 cmp 1280,d2
 bne 9f
 mov 1279,d0
3:
 call getter,[d2,a2],24           /* d0 = arrow-pad mode */
 cmp 2,d0
 beq 8f
 cmp 1,d0
 bne 7f
 mov 85,d0
 ret [d2],8
7:
 mov 3200,d0
 ret [d2],8
8:
 jmp vget                          /* 0x610834b1: mov d2,d0; call getter; ret [d2],8 */
9:
 mov 3413,d1
 mov d1,d0
 jmp vback                         /* 0x610833b8: cmp d1,d2 ... */
.section .hookv,"ax"
 jmp up_get
