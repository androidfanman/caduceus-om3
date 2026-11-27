/* Global Video Sharpening Off: the tick on Information 1 is shared by all video/live-view requests.
 * SI's CRC-protected spare word holds bit 0; no per-film values or native Sharpness settings are changed.
 * The final YC helper store runs after every coefficient-table choice. Saved still development and unknown
 * request classes remain stock. A request with class 0x30/0x40 and no development high nibble is live processing.
 * This is emulator-tested configuration behavior, not camera-verified video output. */
.section .hook_vs,"ax"
 jmp vs_gate
 .byte 0xcb

.section .ext1,"ax"
vs_gate:
 mov d0,(4,sp)                   /* this local is dead at the helper's return; keep its output register */
 mov (SEC_READY),d0
 and 32,d0
 beq 1f
 jmp vs_gain
1:
 mov (4,sp),d0
 movhu d1,(4,a0)
 ret [d2,d3,a2,a3],88

.section .ext15,"ax"
vs_gain:
 mov (4,sp),d0
 add -24,sp
 mov d0,(4,sp)
 mov d1,(8,sp)
 mov a0,(12,sp)
 mov a1,(16,sp)
 mov mdr,d0
 mov d0,(20,sp)
 mov (60,sp),a0                  /* stock helper's request pointer at original sp +36 */
 movhu (14,a0),d0
 btst 0xf000,d0
 bne 9f
 and 0xf0,d0
 cmp 0x30,d0
 beq 1f
 cmp 0x40,d0
 bne 9f
1:
 call si_ld,[d2,d3,a2,a3],20
 mov (si_ram + 36),d0
 btst 1,d0
 beq 9f
 clr d0
 mov d0,(8,sp)
9:
 mov (20,sp),d0
 mov d0,mdr
 mov (16,sp),a1
 mov (12,sp),a0
 mov (8,sp),d1
 mov (4,sp),d0
 add 24,sp
 movhu d1,(4,a0)
 ret [d2,d3,a2,a3],88

/* The existing SI tick setter toggles modes 1..3; explicit mode 0 accepts only Stock 0 / Off 1. */
vs_sv:
 cmp 3,d1
 bhi 8f
 cmp 0,d1
 bne 1f
 mov a1,d0
 cmp 2,d0
 bcc 8f
 mov VSB,d0
1:
 jmp si_sv2
8:
 mov -268435434,d0
 rets

 .balign 2
vs_title:
 .short 86,105,100,101,111,32,83,104,97,114,112,101,110,105,110,103,32,79,102,102,0
 .balign 4
