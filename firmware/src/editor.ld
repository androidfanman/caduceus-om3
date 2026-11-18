SECTIONS {
  .hook_color   0x60518615 : { *(.hook_color) }
  .hook_crs     0x60061183 : { *(.hook_crs) }   /* crop modes: the settings store write (power-off: M patched in RAM) */
  .hook_crb     0x6006120e : { *(.hook_crb) }   /* crop modes: the buffer before the write (after a menu) */
  .hook_crg     0x611cb24d : { *(.hook_crg) }   /* crop round 3: the GUI screen spec's ratio byte */
  .hook_crh     0x60dc4bb1 : { *(.hook_crh) }   /* crop round 5: the live histogram's area (Set_Histogram_CalcMode) */
  .hook_crk     0x6111341e : { *(.hook_crk) }   /* crop round 9c: the single frame's info build, after its label code */
  .hook_crq     0x60c7c18a : { *(.hook_crq) }   /* crop round 10: the play component's record-mode lookup (reads only) */
  .hook_crr     0x611133cd : { *(.hook_crr) }   /* crop round 10: SimplePlayCommon's quality lookup */
  .hook_shutter 0x60415216 : { *(.hook_shutter) }
  .ext1         0x6031e920 : { *(.ext1) }
  .ext4         0x60a8f100 : { *(.ext4) }
  .hook_set     0x60b8798b : { *(.hook_set) }
  .hook_pmod    0x6129ba07 : { *(.hook_pmod) }
  .hook_rsp     0x611c3cb5 : { *(.hook_rsp) }
  .hook_su      0x604b7730 : { *(.hook_su) }
  .hook_sel2    0x60504b5d : { *(.hook_sel2) }
  .hook_tch     0x612a8db3 : { *(.hook_tch) }     /* #75: a touch's idle re-arm, 30 s in Picture Mode */
  .hook_c1e     0x605053cc : { *(.hook_c1e) }
  .hook_wl      0x604b8d91 : { *(.hook_wl) }
  .hook_trs     0x604cf156 : { *(.hook_trs) }
  .hook_trl     0x604cf1a4 : { *(.hook_trl) }
  .hook_tone    0x605197d7 : { *(.hook_tone) }
  .hook_fx      0x60555e50 : { *(.hook_fx) }
  .hook_lv      0x6046b8bb : { *(.hook_lv) }
  .hook_wt      0x605048c1 : { *(.hook_wt) }
  .hook_ag      0x610833b3 : { *(.hook_ag) }
  .hook_dl      0x610ba015 : { *(.hook_dl) }
  .hook_dmg     0x6109355f : { *(.hook_dmg) }
  .hook_ex      0x60457578 : { *(.hook_ex) }
  .hook_scw     0x61157d30 : { *(.hook_scw) }
  .hook_stw     0x6128b1d3 : { *(.hook_stw) }
  .hook_nr1     0x603c8038 : { *(.hook_nr1) }
  .hook_nr2     0x603e7891 : { *(.hook_nr2) }
  .hook_sh      0x603e767f : { *(.hook_sh) }
  .hook_cl      0x604955f1 : { *(.hook_cl) }
  .hook_rng     0x611d1041 : { *(.hook_rng) }
  .hook_dot     0x611d10fb : { *(.hook_dot) }
  .hook_lc      0x611d1982 : { *(.hook_lc) }
  .hook_str     0x610f56a6 : { *(.hook_str) }
  .hook_pg      0x611d07a4 : { *(.hook_pg) }
  .hook_pg2     0x611c3709 : { *(.hook_pg2) }
  .hook_arw     0x611d0be0 : { *(.hook_arw) }
  .hook_rev     0x611b21e8 : { *(.hook_rev) }
  .hook_stp     0x611b201b : { *(.hook_stp) }
  .hook_ic      0x610f5611 : { *(.hook_ic) }
  .hook_gx      0x610f6016 : { *(.hook_gx) }
  .hook_pme     0x6125becc : { *(.hook_pme) }
  .hook_sc      0x610cdf05 : { *(.hook_sc) }
  .hook_pu      0x611d04ec : { *(.hook_pu) }
  .hook_pe      0x611d059c : { *(.hook_pe) }   /* the Picture Mode update's end: the bottom bar back off the grid rows */
  .hook_rr      0x611356e6 : { *(.hook_rr) }   /* the row refresh (property 275's handler): the holder's scene swap */
  .hook_inf     0x611c29c2 : { *(.hook_inf) }   /* rgb-curves: INFO goes to the row's panel for 5397 / 5398 / RG_IT */
  .hook_rsi     0x611c296f : { *(.hook_rsi) }   /* rgb-curves: the held-OK reset the same */
  .hook_mx      0x6051485a : { *(.hook_mx) }    /* colour mix: the matrix function's row-scaling call */
  .hook_bar     0x611d1035 : { *(.hook_bar) }
  .hook_rda     0x611d16b4 : { *(.hook_rda) }
  .hook_rdb     0x611d1725 : { *(.hook_rdb) }
  .hook_bga     0x6123825e : { *(.hook_bga) }   /* border preview: the grid builders' grid read -> bl_gv */
  .hook_bgb     0x611cb433 : { *(.hook_bgb) }
  .hook_bgc     0x611e44d7 : { *(.hook_bgc) }
  .hook_bgd     0x611eae1e : { *(.hook_bgd) }
  .hook_blk     0x611c7922 : { *(.hook_blk) }   /* border preview: the line lookup's loop end -> bl_tail */
  .ext2         0x607187a8 : { *(.ext2) }
  .ext7         0x6164afd0 : { *(.ext7) }
  .ext3         0x6081fe10 : { *(.ext3) }
  .ext8         0x617e45f0 : { *(.ext8) }
  .ext5         0x60adb5b0 : { *(.ext5) }
  .ext10        0x61aa4300 : { *(.ext10) }
  .ext6         0x60f49590 : { *(.ext6) }
  .ext9         0x619a9670 : { *(.ext9) }
  .ext11        0x60f49800 : { *(.ext11) }
  .ext12        0x60f59800 : { *(.ext12) }
  .ext13        0x60fac000 : { *(.ext13) }   /* v0.30 test 10: the debug log, after the RGB work area */
}
color_builder = 0x60518381;
pm_back       = 0x611bd90f;
stock_sel     = 0x60b86a01;
rng_back      = 0x611d1090;
dot_back      = 0x611d1103;
lc_back       = 0x611d19b4;
cha_back      = 0x611c2446;
chb_back      = 0x611c25a1;
chc_back      = 0x611c2705;
chd_back      = 0x611c2867;
chf_back      = 0x611c2d03;
lch_back      = 0x611d0b72;
HS_CASE       = 0x611d04e5;   /* rgb-curves: the column update's case for H&S (5398) */
LC_PICK       = 0x611c7785;   /* rgb-curves: the left cell's pick from an option list (lch_back's call) */
LC_DONE       = 0x611d0b90;
STAR_END      = 0x611d1acb;
INF_GO        = 0x611c29cf;   /* rgb-curves: the row event function (0x611c28xx): INFO to the row's panel */
INF_NO        = 0x611c29fb;   /* ... not */
RSI_GO        = 0x611c298e;   /* its held-OK reset to the row's panel */
RSI_111       = 0x611c29ad;   /* ... item 111's own */
RSI_NO        = 0x611c2a07;   /* ... nothing */   /* rgb-curves: the row-changed function's end (d2 1 -> 1, else 2) */   /* rgb-curves: lch_back after that call */
nf_get        = 0x60063380;
pg_back       = 0x611d07bd;
pgm_back      = 0x611c3710;
rsp_back      = 0x611c3cbd;
sf_stock      = 0x604be2aa;
wl_back       = 0x604b8d99;         /* ft8: after the work-list key read */
su_stock      = 0x604b97db;
prop_set      = 0x610cd5c4;
wb_shift      = 0x611d2941;
sc_back       = 0x610cdf0b;
sc_set        = 0x610cdf05;
sc_ref        = 0x61192d6c;
pu_back       = 0x611d04f2;
pe_back       = 0x611d05a2;
pe_ret        = 0x611d05b2;
rr_back       = 0x611356ec;
gx_back       = 0x610f601c;
pme_back      = 0x6125bed1;
ev_arg        = 0x6129b050;         /* ft1: the still set-up (Grainy Film's texture is made here) */
arw_back      = 0x611d0be8;
rv_469        = 0x611b21f2;
rv_back       = 0x611b2217;
stp_back      = 0x611b2021;
stp_end       = 0x611b2041;
str_lang      = 0x610f56bd;
str_back      = 0x610f56ac;
lc5_back      = 0x611d0a09;
f2c_obj       = 0x611c2ce8;
f2c_none      = 0x611c2d42;
bar_59        = 0x611d1057;
bar_5399      = 0x611d1074;
bar_none      = 0x611d1092;
rda_none      = 0x611d16ee;
rda_11        = 0x611d16e6;
rdb_none      = 0x611d175f;
rdb_11        = 0x611d1757;

color_resume  = 0x6051861a;
getter        = 0x60063380;
gui_get       = 0x610fd8ef;   /* border preview: the GUI's setting read (its cache, else the settings interface) */
gl_loop       = 0x611c78cc;   /* border preview: the line lookup's record loop */
gl_ret        = 0x611c7927;   /* and its retf */
trig          = 0x60415343;
trig_resume   = 0x6041521b;
get_tid       = 0x6003193e;
malloc        = 0x60024068;
free          = 0x6002409a;
LOCK          = 0x60075f73;   /* v0.28 halation: as the code block's xb_open */
UNLOCK        = 0x60075fbc;
WINMAP        = 0x60071018;
FLUSH         = 0x60070e69;
RES_SZ        = 0x601d7546;   /* better grain g1: the grain tile's size (resource 0x8001) */
RES_LD        = 0x604ce6c9;   /* its load into the texture builder's buffer */
TLD_BACK      = 0x604cf1a9;   /* after that call in the builder 0x604cf0b9 */
OS_FOPEN      = 0x608d4d22;
OS_FCLOSE     = 0x608d4d2b;
OS_FSEEK      = 0x608d4fb1;
OS_FTELL      = 0x608d4f47;
OS_FREAD      = 0x608d4eb7;
STATE         = 0x62b4dd16;
HLS_TID       = 0x62b4dd14;
SECBITS       = 0xa32de590;
MS_A          = 0x603692f8;
MS_B          = 0x60369300;
MS_C          = 0x60369308;
POOL          = 0xa2852000;
NEG_POOL      = 0x5d7ae000;
HMAX          = 0xae81;
MAGIC         = 0x42334d4f;
FILE_LEN      = 544;
HDR_LEN       = 32;
PAYLOAD_LEN   = 512;
CRC_TAIL      = 524;
stock_get     = 0x60b86de7;
stock_cnt     = 0x60b86e09;
stock_vbi     = 0x60b87031;
stock_default = 0x60b86e44;
manager       = 0x60bb528f;
sget          = 0x603f0111;
stock_init    = 0x6122393a;
stock_info    = 0x6122661b;
refresh       = 0x611b20ea;
facade        = 0x60b8696a;
cm_stock      = 0x60b8764c;   /* k2: the facade's Assign (entry 18), after cm_asg */
cm_rstock     = 0x60b871f3;   /* k6: the facade's Recall (entry 20), from cm_rcl */
cm_xstock     = 0x60b86aaf;   /* p2: the facade's Assign > Reset (entry 19), after cm_rst */
fwrite        = 0x608d4da9;
EMARK         = 680;
AXIS          = 684;
DIRTY         = 685;
STATUS        = 686;
EDK           = 687;
GLOW          = 688;
EMAGIC        = 0x45334d4f;
aget          = 0x603f039d;
GPTR          = 700;
GMAGIC        = 0x47334d4f;
GHDR          = 0x0b0ae031;
GDESC         = 0xa49ecdf8;
GSTOCK_P      = 0xa49ebe40;
GSTOCK_S      = 4022;
stock_isdef   = 0x6129bad6;
tone_next     = 0x60518fa4;
MX_BACK       = 0x6051485f;   /* colour mix: after the matrix function's row-scaling call */
MX_RET        = 0x605196fb;   /* colour mix: the matrix function's return in the development function (split toning's) */
mx_mul        = 0x60514290;   /* colour mix: the camera's 3 x 3 multiply (a0 out = a1 x d0, s16, 256 = 1.0) */
mx_row        = 0x605144ef;   /* colour mix: the camera's row scaling (a0 out <- a1, rows to 128) */
LPTR          = 708;
LIDX          = 712;
BKUP          = 720;
LKMAGIC       = 0x4b334d4f;
PFMAGIC       = 0x50334d4f;
PF_LEN        = 1632;
NMAGIC        = 0x4e334d4f;
NENT          = 720;
NPTR          = 800;
TTAB          = 816;
TORG          = 820;
TBUF          = 836;
stock_up      = 0x61223ef7;
stock_down    = 0x612241b6;
stock_event   = 0x61225d52;
stock_left    = 0x6122471c;
stock_right   = 0x61224c1c;
fx_back       = 0x60555e56;
fx_tail       = 0x60555ed6;
XPTR          = 692;
lv_x          = 0x6046b8ee;
lv_skip       = 0x6046b94f;
wt_back       = 0x605048c7;
XTAG          = 0x58000000;
SEL           = 0x6052cf39;
TMR_ARM       = 0x612970e8;   /* #75: start a timer (d0 id, d1 ms) */
sdl_hls_loop     = 0x60af0fff;
sdl_classifier   = 0x60af10da;
sdl_resume       = 0x60af1021;
sdl_next_receive = 0x60af10c6;
sdl_drive_status = 0x608e7b48;
sdl_heap_alloc   = 0x60dd92e0;
sdl_heap_tag     = 0x60de941d;
sdl_task_create  = 0x6004da3f;
sdl_task_start   = 0x60030899;
sdl_dly_tsk      = 0x60031581;
sdl_queue_send   = 0x6004d171;
sdl_ext_tsk      = 0x60031808;
scw_set       = 0x6128abe0;
stw_set       = 0x6128ab86;
stw_back      = 0x6128b2c6;
ar_getv       = 0x61085dbb;         /* v0.27: the key dispatcher's plain setting getter (GetValue) */
ar_setv       = 0x61085d05;         /* v0.27: its setter pair (SetValue through the facade, as the dial handler) */
ar_vget       = 0x610834b1;         /* v0.27: the dispatcher's value read, assigned value: mov d2,d0; call getter; ret */
ar_vback      = 0x610833b8;         /* v0.27: the value read after its first 5 bytes (.hook_ag) */
dl_mexp       = 0x610865c5;         /* #37: non-zero while a Multiple Exposure frame can be deleted */
dl_mx         = 0x610b8397;         /* #37: live view's stock Delete press handler (deletes that frame) */
dl_fn         = 0x610a2407;         /* #37: live view's AF-ON press handler (runs the button function) */
dl_walk       = 0x610b9fe0;         /* #37: the state block walk's loop start (clr d3) */
dl_hit        = 0x610ba01a;         /* #37: the walk's end after .hook_dl's 5 bytes, an entry with a handler */
dl_none       = 0x610ba054;         /* #37: the walk's return (d0 = found) */
ex_back       = 0x60457580;         /* v0.27 EXIF: after the hook's 8 bytes */
ds_get        = 0x610cd5ac;         /* #54: the camera's data store, read: a0 buffer, d0 item, d1 length (call [],4) */
ds_put        = 0x610cd5c4;         /* #54: and write, marking the item changed: a1 0 as the camera's (call [d2,a2],16) */
/* custom crop modes (crop.s): where the stock switch cases continue after setting width and height */
cr_os_j       = 0x60c14d28;
cr_ta_j       = 0x60c15156;
cr_sa_j       = 0x60c0670e;
cr_sb_j       = 0x60c28c7b;
cr_sc_j       = 0x60c2ab68;
cr_pb_j       = 0x60c66889;
cr_gv0        = 0x610fd8ef;         /* the GUI getter (d0 id, a0 out) */
cr_ef         = 0x60060eff;         /* the store write's first call (replayed by cr_sin) */
cr_sin_back   = 0x6006118b;
cr_sb_back    = 0x60061214;
cr_pbk1_back  = 0x61113424;         /* crop round 9b: SimplePlayCommon after mov (2844,sp),d2; mov 78,a0 */
cr_pq_back    = 0x60c7c18f;         /* crop round 10: the record-mode lookup after its first three */
cr_pqg_back   = 0x611133d5;         /* crop round 10: SimplePlayCommon's call 0x6110130d */
cr_lr_j       = 0x60bf2d2b;         /* the live view ratio switch: mov d0,(28,sp) (the height) */
cr_rc_j       = 0x60c0d35f;         /* ratioToConvertSize: mov d0,(4,a1); retf [],0 */
cr_oa_j       = 0x60c14b95;         /* getOutputAspect: mov d0,(16,sp) */
cr_spec_back  = 0x611cb253;         /* crop round 3: after the screen spec's ratio byte */
cr_dhm_back   = 0x60dc4bb7;         /* crop round 5: Set_Histogram_CalcMode after its entry */
