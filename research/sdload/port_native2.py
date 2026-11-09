#!/usr/bin/env python3
"""Turn research/caduceus-sd-native-candidate/native2.s into an assembler block for editor.s (v0.25 source).
Only renames symbols (sdl_ prefix), maps the sections onto editor.s's and drops the placement-only stubs.
usage: port_native2.py native2.s > block.s"""
import re, sys
src = open(sys.argv[1]).read().splitlines()
ren = ['ready','create_worker','boot_stub','worker_entry','worker_name','worker_loop','worker_try','worker_send_call',
       'worker_send_result','worker_done','create_done','receive_probe','ok_load','ok_gate_call','classify','auto_event',
       'consumer_drive_result','auto_gate_call','consume','hls_loop','gate','drive_status','classifier','resume',
       'next_receive','heap_alloc','heap_tag','task_create','task_start','dly_tsk','queue_send','ext_tsk',
       'TAG','POLL_TICKS','WORKER_PRIORITY','WORKER_STACK','SEND_PERIOD','REQ_LOADED','REQ_INIT',
       'SECTION_LOADED','SECTION_INIT','MEDIA1','MEDIA3','MEDIA4','QUEUE']
pat = re.compile(r'\b(' + '|'.join(ren) + r')\b')
out, skip, sect = [], False, None
for ln in src:
    s = ln.strip()
    if s.startswith('.section'):
        sect = s.split()[1].split(',')[0]
        if sect in ('.nmload_stub', '.nmpick_stub'):
            skip = True; continue
        skip = False
        out.append({'.bootpatch': '.section .hook_hb,"ax"', '.hookpatch': '.section .hook_hr,"ax"',
                    '.placed': '.section .ext4,"ax"', '.probe': '.section .ext4,"ax"'}[sect]); continue
    if skip or s in ('.ifndef NO_BOOT', '.endif') or s.startswith('.ifndef SEND_PERIOD'):
        continue
    if re.match(r'\.equ\s+(STATE|SECTION_LOADED|MEDIA|QUEUE|POLL|WORKER|SEND_PERIOD|TAG|SECTION_INIT)', s) and False:
        continue
    if re.match(r'\.equ\s+STATE\b', s): continue
    if s.startswith('/* Stock 0x60a8f5ac') or s.startswith('* already zero the four') or s.startswith('/* Stock 0x60a8f780'): continue
    out.append(pat.sub(lambda m: 'sdl_' + m.group(1) if not m.group(1).isupper() else 'SDL_' + m.group(1), ln))
print('\n'.join(out))
