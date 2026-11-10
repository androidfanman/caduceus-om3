/* Placed, trimmed E147 native SD-load path (offline research; see REPORT.md).
 *
 * Linked into reclaimed main-image space in section 4, not into emulator scratch RAM. No data RAM of its own:
 * the worker keeps its state in a callee-saved register (d3) and on its own stack.
 *
 *   ready          leaf helper shared by the worker and the consumer: d0 = 0 when the loader's section masks and
 *                  the kind-4 media word allow a load, nonzero otherwise. Clobbers d0, d1.
 *   create_worker  HLS_EVENT task, called from boot_stub: heap stack, stock create wrapper, stock activate.
 *   boot_stub      patch site 0x60af0fb9 (HLS_EVENT entry after stock init, before its receive loop).
 *   worker_entry   task SDLOAD: poll, then one zero-timeout wake to the HLS queue; back off after each send.
 *   receive_probe  patch site 0x60af101c (HLS_EVENT receive boundary): private wake, tested OK trigger, stock classifier.
 *
 * Assembler switch (build.py --variant): --defsym NO_BOOT=1 builds the receive hook and consumer without the worker task
 * (the OK-trigger control). Without it the image is the full automatic path.
 */
  .equ TAG, 0x0100f7ed
  .equ STATE, 0x62b4dd16
  .equ SECTION_LOADED, 0xa32de590
  .equ SECTION_INIT, 0xa32de58c
  .equ MEDIA4, 0x60369308
  .equ MEDIA3, 0x60369300
  .equ MEDIA1, 0x603692f8
  .equ QUEUE, 0x60043180
  .equ POLL_TICKS, 100
  .equ WORKER_PRIORITY, 56
  .equ WORKER_STACK, 2048
  .ifndef SEND_PERIOD
  .equ SEND_PERIOD, 10           /* polls skipped after every send attempt: one wake per SEND_PERIOD+1 polls */
  .endif

/* Stock 0x60af0fb9: call 0x60af0fff,[d2,d3,a2,a3],24 (5 bytes). */
.ifndef NO_BOOT
.section .bootpatch,"ax"
  jmp boot_stub
.endif

/* Stock 0x60af101c: call 0x60af10da,[],0 (5 bytes). */
.section .hookpatch,"ax"
  jmp receive_probe

/* Stock 0x60a8f5ac..0x60a8f5af (first three bytes of "mov imm32,a0" in the middle of nm_load): the 25 bytes before it
 * already zero the four name-picture pointers, so returning here makes nm_load a stub. */
.section .nmload_stub,"ax"
  ret [d2,d3,a2,a3],36

/* Stock 0x60a8f780 nm_pick entry, called as "call nm_pick,[],0": with the four pointers zero the original returned
 * d0 = 1 on every path and left the descriptor untouched. */
.section .nmpick_stub,"ax"
  mov 1,d0
  retf [],0

.section .placed,"ax"
ready:
  mov (SECTION_LOADED),d0
  not d0
  and REQ_LOADED,d0
  mov (SECTION_INIT),d1
  not d1
  and REQ_INIT,d1
  or d1,d0
  mov (MEDIA4),d1
  xor 0xf000,d1
  or d1,d0
  retf [],0

.ifndef NO_BOOT
boot_stub:
  call create_worker,[a2],20
  call hls_loop,[d2,d3,a2,a3],24
  ret [],4

create_worker:
  mov a0,a2                       /* the HLS object the stock loop needs; a2 survives every call below */
  mov WORKER_STACK,d0
  mov heap_tag,a0
  mov 260,d1
  call heap_alloc,[],4
  cmp 0,a0
  beq create_done
  mov WORKER_PRIORITY,d0
  mov d0,(4,sp)
  mov WORKER_STACK,d0
  mov d0,(8,sp)
  mov a0,(12,sp)
  mov worker_name,a0
  clr d0
  mov d0,d1
  mov worker_entry,a1
  call task_create,[d2,d3,a2,a3],56
  cmp 0,d0
  blt create_done
  exth d0
  call task_start,[d2,d3,a2],16
create_done:
  mov a2,a0
  ret [a2],20

worker_entry:
  add -24,sp                      /* (0,sp) belongs to CALL: it writes the return address there */
  clr d0
  mov d0,(4,sp)                   /* wake message {0, TAG, 0} at 4, descriptor {message, 12} at 16 */
  mov d0,(12,sp)
  mov TAG,d0
  mov d0,(8,sp)
  mov sp,a0
  add 4,a0
  mov a0,(16,sp)
  mov 12,d0
  mov d0,(20,sp)
  clr d3                          /* d3: polls left before the next send */
worker_loop:
  mov POLL_TICKS,d0
  call dly_tsk,[d2,a2,a3],16
  movhu (STATE),d0
  cmp 0,d0
  bne worker_done                 /* the loader has begun (or the OK trigger won): stand down */
  cmp 0,d3
  beq worker_try
  add -1,d3
  bra worker_loop
worker_try:
  call ready,[],0
  cmp 0,d0
  bne worker_loop
  mov SEND_PERIOD,d3
  movhu (QUEUE),d0
  clr d1
  mov sp,a0
  add 16,a0
worker_send_call:
  call queue_send,[d2,d3,a2,a3],48
worker_send_result:
  bra worker_loop
worker_done:
  call ext_tsk,[a2],8
  ret [],24

worker_name:
  .asciz "SDLOAD"
.endif

.section .probe,"ax"
receive_probe:
  cmp TAG,d0
  beq auto_event
  cmp 0x02000004,d0
  bne classify
  movhu (STATE),d1
  cmp 0,d1
  bne classify
  mov (MEDIA4),d1
  cmp 0xf000,d1
  beq ok_load
  mov (MEDIA3),d1
  cmp 0xf000,d1
  beq ok_load
  mov (MEDIA1),d1
  cmp 0xf000,d1
  bne classify
ok_load:
  /* CALL does not push the return address, but the loop owns (4,sp)..(12,sp): save the live registers below it. */
  add -16,sp
  mov d0,(4,sp)
  mov a0,(8,sp)
  mov a1,(12,sp)
ok_gate_call:
  call gate,[d2,d3,a2,a3],36
  mov (4,sp),d0
  mov (8,sp),a0
  mov (12,sp),a1
  add 16,sp
classify:
  call classifier,[],0
  jmp resume

auto_event:
  movhu (STATE),d1
  cmp 0,d1
  bne consume
  call ready,[],0
  cmp 0,d0
  bne consume
  clr d0
  call drive_status,[d2,d3,a2,a3],20
consumer_drive_result:
  and 0x10bf,d0
  cmp 0x1080,d0
  bne consume
  call ready,[],0                 /* the status call can block: check the media word again before the load */
  cmp 0,d0
  bne consume
auto_gate_call:
  call gate,[d2,d3,a2,a3],36
consume:
  jmp next_receive
