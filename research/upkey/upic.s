/* up_ic <- jmp from the picture lookup 0x610f5611 (replaces Caduceus' jmp ic_get): our ▲ picture UPIC -> a0 = its
 * slot (a word holding its descriptor), else on to ic_get as before. */
.set UPIC, 0x7fe0                  /* clear of Caduceus' picture ids 0x7f80..0x7fc3 (v0.26.2: 0x7f90 + j = film j's list cell) */
.section .upic, "ax"
up_ic:
 mov d0,d1
 exthu d1
 cmp UPIC,d1
 bne 1f
 mov up_slot,a0
 retf [],0
1:
 jmp ic_get
.balign 4
up_slot:
 .long up_desc
.section .hooki, "ax"
 jmp up_ic
