SECTIONS {
  .hook_color   0x60518615 : { *(.hook_color) }
  .hook_hb      0x60af0fb9 : { *(.hook_hb) }
  .hook_hr      0x60af101c : { *(.hook_hr) }
  .hook_shutter 0x60415216 : { *(.hook_shutter) }
  .ext1         0x6031e920 : { *(.ext1) }
  .ext4         0x60a8f100 : { *(.ext4) }
  .hook_set     0x60b8798b : { *(.hook_set) }
  .hook_pmod    0x6129ba07 : { *(.hook_pmod) }
  .hook_rsp     0x611c3cb5 : { *(.hook_rsp) }
  .hook_su      0x604b7730 : { *(.hook_su) }
  .hook_sel2    0x60504b5d : { *(.hook_sel2) }
  .hook_c1e     0x605053cc : { *(.hook_c1e) }
  .hook_wl      0x604b8d91 : { *(.hook_wl) }
  .hook_tone    0x605197d7 : { *(.hook_tone) }
  .hook_fx      0x60555e50 : { *(.hook_fx) }
  .hook_lv      0x6046b8bb : { *(.hook_lv) }
  .hook_wt      0x605048c1 : { *(.hook_wt) }
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
  .hook_bar     0x611d1035 : { *(.hook_bar) }
  .hook_rda     0x611d16b4 : { *(.hook_rda) }
  .hook_rdb     0x611d1725 : { *(.hook_rdb) }
  .ext2         0x607187a8 : { *(.ext2) }
  .ext7         0x6164afd0 : { *(.ext7) }
  .ext3         0x6081fe10 : { *(.ext3) }
  .ext8         0x617e45f0 : { *(.ext8) }
  .ext5         0x60adb5b0 : { *(.ext5) }
  .ext10        0x61aa4300 : { *(.ext10) }
  .ext6         0x60f49590 : { *(.ext6) }
  .ext9         0x619a9670 : { *(.ext9) }
  .ext11        0x60f49800 : { *(.ext11) }
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
trig          = 0x60415343;
trig_resume   = 0x6041521b;
get_tid       = 0x6003193e;
malloc        = 0x60024068;
free          = 0x6002409a;
fopen         = 0x608d4d22;
fclose        = 0x608d4d2b;
fseek         = 0x608d4fb1;
ftell         = 0x608d4f47;
fread         = 0x608d4eb7;
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
fwrite        = 0x608d4da9;
EMARK         = 680;
AXIS          = 684;
DIRTY         = 685;
STATUS        = 686;
EDK           = 687;
GLOW          = 688;
EMAGIC        = 0x45334d4f;
OLD           = 544;
RBD           = 1088;
aget          = 0x603f039d;
GPTR          = 700;
GMAGIC        = 0x47334d4f;
GHDR          = 0x0b0ae031;
GDESC         = 0xa49ecdf8;
GSTOCK_P      = 0xa49ebe40;
GSTOCK_S      = 4022;
stock_isdef   = 0x6129bad6;
tone_next     = 0x60518fa4;
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
