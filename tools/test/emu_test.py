#!/usr/bin/env python3
"""Emulator regression tests: each test boots a build in om-emu one or more times and checks the debug log.

    python3 tools/test/emu_test.py BUILD_DIR [--only NAME ...] [--jobs N] [--out DIR] [--repeat N] [--without BUILD_DIR]
                                   [--stock OLY_E_147_1100_0000_0000.BIN]

BUILD_DIR is a firmware/build.py --out folder (main.bin, GUIDES.BIN, LABELS.BIN). om-emu comes from $OM3_EMU
(research/setup.sh writes it to env.sh). The static:* tests are tools/test/static_check.py's checks and need the
stock firmware (--stock, else $OM3_STOCK, else $OM3_WORK/stock). --repeat N runs each test N times and fails if any run fails.
--without BUILD_DIR (needs --only) runs those tests on a build without the fix and exits 1 if any passes.
Exit 0 when every test passes, 1 otherwise.
"""
import argparse, concurrent.futures, datetime, functools, importlib.util, json, os, pathlib, re, shutil, struct, subprocess, sys, tempfile, zlib
from dataclasses import dataclass, field

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'firmware'))
import static_check  # noqa: E402
from provenance import source_digest  # noqa: E402
sys.path.insert(0, str(REPO / 'card'))
import mkcurves  # noqa: E402
import build as fwbuild  # noqa: E402
_spec = importlib.util.spec_from_file_location('curves_model', REPO / 'research/rgbcurves/model.py')
curves_model = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(curves_model)

DRIVER = REPO / 'tools/emulator/session_ed1.mjs'
DEBUG_TXT = REPO / 'debug-log/DEBUG.TXT'
MODEL = 'E147'
AUDIT = 'patch-audit'
# h7 (faster halation, 2026-11-16): the halation pass called directly on test frames must give every byte of
# research/halation/model.py (research/halation/emu_check.py). Small frames, about 10 s.
HALATION = 'halation-matches-the-model'
HALATION_CASES = ['fade3', 'odd2', 'small5', 'min5', 'w68', 'odd131', 'clamp5', 'random3', 'day5', 'dark5']
HALATION_CHECK = REPO / 'research/halation/emu_check.py'
# borders (2026-11-16): the border pass (editor.s bd_run) called directly on test frames must give every byte of
# research/border/model.py (research/border/emu_check.py). Small frames, a few seconds.
BORDER = 'border-matches-the-model'
BORDER_CHECK = REPO / 'research/border/emu_check.py'
ENGINE = 'look-tables-match-the-model'
DIAL = 'rgb-page-counts-every-click'
# #68: our looks are for photos only. A video pass after a photo pass, the same look (split toning and curves), must
# leave the camera's tables as they are (st_run: mx_photo 0). v0.30.3 kept split toning and the photo's curves.
VIDEO = 'video-keeps-the-stock-tables'
VIDEO_CASE = 'split-toning-and-curves'
VIDEO_MODE = 0x0a                                # the mode code of video and S&Q (rc_in + 24, ss_photo)
PHOTO_MODE = 0x01                                # P's mode code, so the photo pass does not rest on the snapshot's mode
# better grain g2c: combiner 1's set-up end (s_c1e -> the code block's xb_c1e) on a fake register image. The grain's
# Y mean (48 x 4) comes off on the texture's own input (+136, its Y clamp minimum +160 opened to -512), not as an
# output offset (+180): g1 / g2 put it there, after the clamp, and capped the highlights (camera, 2026-11-16).
GRAINMIX = 'grain-mix-keeps-the-highlights'
# crop round 5: cr_trim (the live histogram's main area at Set_Histogram_CalcMode's entry, crop.s cr_dhm) called
# directly with a crop set: the area is trimmed to the crop's shape, centred. om-emu does not run the live view.
CROPHIST = 'crop-histogram-area-trimmed'
CROPHIST_CASES = {   # name: (Image Aspect, area x, y, w, h asked, area kept)
    'xpan': (6, (0, 0, 640, 360), (0, 62, 640, 236)),
    '21-9': (7, (0, 0, 640, 360), (0, 43, 640, 274)),
    '5-4': (5, (0, 0, 640, 480), (20, 0, 600, 480)),
    '16-9-as-it-is': (3, (0, 0, 640, 360), (0, 0, 640, 360)),
}
# crop round 9c: the playback ratio label, by direct calls (om-emu's playback gives its photos no crop size). The
# camera's own shape sort (0x61101381), record-mode lookup (0x60c7c18a), label updates and label elements stay stock
# (rounds 9 / 9b changed them and the camera rebooted in image review); SimplePlayCommon's hook (cr_pbk1) notes the
# crop shape, and the picture getter (0x610f5611 -> ar_ic -> cr_ic) answers the label's 10930 / 10931 with ours in
# playback (GUI class 5..7) while that shape is noted.
CROPPL = 'crop-playback-label-and-quality'
CROPPL_STOCK = {(5184, 1920): 4, (5184, 2224): 4, (4864, 3888): 1, (5184, 2920): 4, (5184, 3888): 1}
CROPPL_QUALITY = {(1, 1, 5184, 2920): 1, (1, 1, 5184, 1920): 57, (0, 1, 4864, 3888): 57, (0, 1, 5184, 3888): 1}
CROPPL_KIND = {(5184, 1920): 7, (3200, 1184): 7, (5184, 2224): 8, (4864, 3888): 6, (3008, 2400): 6, (5184, 2920): 0,
               (5184, 3888): 0, (5184, 3456): 0, (3888, 3888): 0, (2912, 3888): 0, (5184, 0): 0}
CROPPL_PICTURE = {   # (GUI class, cr_pbk, picture id): our picture k (CR_IC0 + k), or None: the stock picture
    (5, 7, 10930): 4, (5, 8, 10930): 5, (5, 6, 10931): 3, (5, 6, 10930): None, (5, 7, 10931): None, (5, 0, 10930): None,
    (5, 8, 10933): None, (1, 7, 10930): None}
CROPPL_STOCK_BYTES = {0x611509bc: 'f0439828ff14', 0x611525b9: 'f0439828ff14', 0x61101393: '8003faca2e22'}
CROPPL_ELEMENTS = {0x613f8d08: 0x613f5afc, 0x613fe9cc: 0x613fb194, 0x6147d568: 0x6147bff8}
# crop round 10: the playback quality label, by direct calls (om-emu's playback does not run the play component's
# lookup). 0x60c7c18a's results stay stock (57 for a crop size) while cr_pqo notes the base size's code; SimplePlayCommon's
# quality lookup (cr_pqg at 0x611133cd) then asks 0x6110130d with that code instead of 57 for the noted pictureSize.
CROPQ = 'crop-playback-quality-label'
CROPQ_NOTE = {   # (class, compression, w, h): (the stock result, the note)
    (1, 1, 5184, 1920): (57, 1), (1, 1, 5184, 2224): (57, 1), (1, 5, 5184, 1920): (57, 2), (1, 1, 3200, 1184): (57, 5),
    (0, 1, 4864, 3888): (57, 1), (1, 1, 5184, 2920): (1, 0), (0, 1, 5184, 3888): (1, 0), (3, 1, 1000, 999): (57, 0)}
CROPQ_GUI = {   # (the record mode asked, w, h, the note's code, w, h): the record mode 0x6110130d gets
    (57, 5184, 1920, 1, 5184, 1920): 1, (57, 5184, 1920, 2, 5184, 1920): 2, (57, 5184, 2224, 1, 5184, 1920): 57,
    (57, 5184, 1920, 0, 5184, 1920): 57, (1, 5184, 2920, 5, 5184, 2920): 1}
CROPQ_PICTURE = {(5, 1): 16, (1, 1): 1, (5, 57): 0}   # 0x6110130d (file type, record mode): the quality picture code
GRAIN_GAINS = {1: (400, 175), 3: (1024, 448), 5: (1536, 672)}   # strength -> texture Y gain, Cb / Cr gain (xblock.s)
# fix/section-gates (2026-11-17): live view's picture set-up runs three section-2 sites that lead into section 6, also at
# power-on, while the camera may still be marking section 6 ready (research/NOTES.md "Section order audit"). Each site,
# called directly with the camera's ready word (SEC_READY) at 0x1f (sections 1..5) must reach the stock code; at 0x3f
# (section 6 too) our code. om-emu runs neither live view's set-up nor the load order, so the test calls the sites.
GATES = 'live-view-gates-wait-for-section-6'
SEC_READY = 0xa32de58c
SEC_NOT6, SEC_WITH6, SEC_OMEMU = 0x1f, 0x3f, 0x7f     # SEC_OMEMU: the word as om-emu leaves it (S-BOOTSTAGE)
MX_SITE, MX_ROW = 0x6051485a, 0x605144ef               # hook_mx; the camera's row scaling it calls
TONE_SITE = 0x605197d7                                 # hook_tone; the stock goes on at TONE_NEXT
LV_SITE, LV_SKIP, LV_X = 0x6046b8bb, 0x6046b94f, 0x6046b8ee   # hook_lv (a COLOR request); the stock: no flags
REAR_DIAL = 0x9032                               # the rear dial's event (cv_ev); a1 its signed clicks
# (name, a1): first no clicks (the value as it is), then a fast turn of 3, then one past the range.
DIAL_CASES = [('as-is', 0), ('up-3', -3), ('down-20', 20)]
CV_ESZ = 26                                      # a cv_ram slot (rgbcurves.inc CV_ESZ)
RGB_STAGE, TONE_NEXT = 0x60516ad9, 0x60518fa4   # the camera's RGB gamma stage; where our tone hook returns to
TABLE_ENTRIES, TABLE_BYTES = 320, 640            # one channel's table at O+1252: 256 + 64 u16
CV_LIVE, CV_SLOTS = 16, 4 * CV_ESZ               # cv_ram's live[0..3] (rgbcurves.inc CV_LV, CV_ESZ)
CRC_BYTES = 3336                                 # the curves record's CRC span (CV_MLEN - 12)
# COLOR 1's slot +55..+58 (Shadows colour, strength code, Highlights colour, strength code), Tone Balance, R / G / B
# curve values (value 1 unused). Each case runs st_all on a different path.
ENGINE_CASES = {
    'curves': (bytes([12, 0, 12, 0]), 0, [[0, 0, 2, 4, 2, 0], [-1, 0, -2, 0, 3, 1], [2, 0, 1, -3, 0, -2]]),
    'split-toning': (bytes([8, 5, 1, 5]), -3, [[0] * 6] * 3),
    'split-toning-and-curves': (bytes([3, 0xfd, 6, 2]), 2, [[0, 0, 7, -7, 7, -7], [0] * 6, [-7, 0, 0, 0, 0, 7]]),
}
STATIC_PREFIX = 'static:'
STATIC = [STATIC_PREFIX + n for n in static_check.CHECKS]
BOOT_TIMEOUT_S = 300
AUDIT_TOKENS = 'wait:100'
LOG_PATH = 'OM3MOD/CADLOG.TXT'
# A branch that changes these needs a suite pass on its HEAD before a pull request (tools/test/pr_gate.py).
TESTED_PATHS = ('firmware/', 'card/', 'tools/emulator/', 'tools/test/')
PASS_FILE = 'emu-test-pass.json'
EMU_PIN = REPO / 'tools/emulator/om-emu.pin'   # the om-emu commit the tests expect (research/TESTING.md)
EMU_PIN_LINE = re.compile(r'([0-9a-f]{40}) (\d{4}-\d{2}-\d{2})')
EMU_MAX_AGE_DAYS = 7                           # as tools/emulator/om_emu.sh
# Each session peaks at about 1.3 GB. 4 side by side ran clean on a 32 GB Mac. Runs killed with exit 137 had
# screenshots in them (research/TESTING.md).
DEFAULT_JOBS = 4
# Switch positions the driver sets before each boot (session_ed1.mjs PSET0, MODE0).
PHOTO_SWITCH_PHOTO = 2
MODE_DIAL_P = 2
MODE_DIAL_C1 = 7
MODE_DIAL_M = 9
MODE_DIAL_B = 8
UI_MODE_DIAL = 0xa32d9d0c    # the mode dial's position (cm_gnow)
# The movie position, set explicitly: om-emu 0819080 (2026-11-14) reads an unset switch as photo, so a test that left it
# unset ran in photo (v0.30 test 8, emulator).
PHOTO_SWITCH_VIDEO = 1

# From COLOR 1 on the shooting screen, picks FILM 2: the list runs COLOR 1-4, then the films.
# Keep in sync with FILM_2_LINE.
PICK_FILM_2 = 'ok wait ok wait right wait right wait right wait right wait right wait ok wait menu wait wait'
FILM_2_LINE = r'^Picture mode: COLOR \d+, FILM 2\b'   # debug log dl9 (v0.30 test 10): NOW's picture mode line

# In P: picks a film, assigns it to C1 (menu), then picks another film in P.
BOOT1_ASSIGN_C1 = ('s1 wait wait ok wait ok wait right wait right wait right wait right wait ok wait menu wait wait s1 wait wait menu wait right wait right wait right wait right wait right wait right wait right wait ok wait ok wait down wait ok wait ok wait menu wait menu wait menu wait wait ok wait ok wait right wait right wait right wait right wait right wait ok wait menu wait wait s1 wait wait poweroff')
C1_TURN_WHILE_OFF = 'wait wait wait s1 wait wait poweroff'
C1_TURN_BEFORE_HALF_PRESS = 'wait wait wait mode:7 wait wait wait s1 wait wait poweroff'
VIDEO_BOOT = 'wait wait wait s1 wait wait poweroff'
# Picture mode 54 = COLOR 1 is C1's film (FILM 1), 55 = COLOR 2 is the film picked last in P (FILM 6).
C1_FILM_LINE = r'^Picture mode: COLOR 1, FILM 1\b.*\(setting 111 = 54\)'
P_FILM_LINE = r'^Picture mode: COLOR 2, FILM 6\b.*\(setting 111 = 55\)'
C1_RECORD_LINE = r'^CUSTOM MODES \(records valid at the first look: custom modes yes'
GROUP_C1_LINE = r'^Now: group C1 \(last look: mode code 53\)'
# A live dial turn from M to C1, as the camera makes it (#54): first the dial moves while the camera's mode code is not
# yet a mode (the pokes: code 0, dial on C1, rc_go due at the next GUI event), then the real turn. Tokens name build
# symbols in braces (run_test fills in their addresses). A switch run before the real code writes a record with the
# dial's code 0xC0 | position on a later look (second byte below 0x80).
def live_turn(dial, check_hold=False):
    """One live dial turn to position dial, then a half-press. check_hold: lv_hold set during the wait, clear after."""
    hold = lambda v: f' expect:mem:{{lv_hold}}={v}' if check_hold else ''
    return (f'poke:{{rc_in}}+18*=00 poke:{UI_MODE_DIAL:x}={dial:02x} poke:{{rc_pend}}=01 wait wait wait{hold("01")} '
            f'mode:{dial} wait wait wait{hold("00")} s1 wait wait')


LIVE_TURN_START = 'wait wait wait s1 wait wait'
# B has no mode code of its own (0 on the camera, 62 in om-emu), so a switch that waits for one never comes (#54).
LIVE_TURN_C1_TO_B = f'{LIVE_TURN_START} {live_turn(MODE_DIAL_B)} poweroff'
LIVE_TURN_M_TO_C1 = f'{LIVE_TURN_START} {live_turn(MODE_DIAL_C1)} poweroff'
# The same turn and back to M. The camera sets C1's picture mode during the turn, before rc_go looks at C1, and M
# must not keep it as its own choice.
LIVE_TURN_M_TO_C1_AND_BACK = f'{LIVE_TURN_START} {live_turn(MODE_DIAL_C1)} {live_turn(MODE_DIAL_M)} poweroff'
# The same turn and back, with the label's hold checked at each step: set while the switch waits for the mode code,
# clear once the mode is real (#54). om-emu's camera draws no label at a turn, so the byte stands for the picture.
LIVE_TURN_HOLDS_THE_LABEL = (f'{LIVE_TURN_START} {live_turn(MODE_DIAL_C1, True)} {live_turn(MODE_DIAL_M, True)} '
                             'poweroff')
# Debug log dl9 (v0.30): a switch at the dial's code prints "(dial position N)", a first look adds its note.
SWITCH_AT_DIAL_CODE = r'after event \d+: [^(]*\(dial position \d+\) -> (?!.*, first look after the films loaded)'
# Without the fix the switch writes C1's films into M's set, and C1 then differs from its own values ("*").
RESET_MODE_UNCHANGED_LINE = r"^Camera COLOR values that differed from a Reset custom mode's own: 0\b"
# The photo boot before it leaves the video boot with nothing put back and the photo switch read as video.
# rc_go does no film work in video (#53): no film switched, no record write. A build without the fix writes the record.
VIDEO_BOOT_LINES = [r'^Films put back after a shooting-mode change: 0 \(camera settings written: 0\)',
                    r'photo check: (switch position 1|mode code 10)\)$',    # the movie switch, or the video mode's code 10
                    r'^This power-on: Assigns \d+, films switched 0,',
                    r'^Custom-mode record \(OM3C\): writes 0,']   # PR #56's early load reads
                    # the dial position (el_ok -> cm_gnow) in video too, so group and code show it; no work follows

# Debug log (v0.30.3, #65's comment): the report is written at a half-press's release only, never at the half-press
# itself (it held the shutter up). Three clicks = six shutter events; the first half-press loads the films (not logged),
# so five are logged: three releases, three writes (before: five).
DEBUG_LOG_RELEASES_ONLY = (r'^Written at shutter button event 5 \(a half-press and its release count one each\); '
                           r'log writes this power-on: 3$')
# Noise Filter's row '*' (v0.30 test 13, owner 2026-11-16): a COLOR profile without a film, its Noise Filter on Camera
# (slot +51 = 0), shows the camera's own Noise Filter, and its row has no '*', whatever that setting is. Before the fix
# the row compared with Standard, so with the camera on Off the row was starred while the profile was not. The
# camera's own is key 0x9719 (-2 Off, -1 Low, 0 Standard, +1 High), read by the stock getter 0x60063380 from one byte,
# 0x6295942d in om-emu (traced 2026-11-16): the poke sets it to Off as the camera's menu would (a write through the
# settings manager from the driver does not return). Rows are asked through ed_isdef (the stock "is at default"
# calls); NRB + 1 = COLOR 2's row. Then Standard chosen on it (slot +51 = 1, P + 32 + 64 + 51) differs from the
# camera's Off: the row is starred, as the profile is.
NF_BYTE, NR_ROW_COLOR2, NR_SLOT_COLOR2 = 0x6295942d, 0x7e11, 32 + 64 + 51
NR_ROW_STAR = lambda star: f'expect:isdef:{{ed_isdef}}:{NR_ROW_COLOR2:x}={0 if star else 1}'
# The Blacks / Whites row (the eighth in Picture Mode) shows the camera's WB grid scene (element 24813) in the bottom
# bar's holder, and Contrast, the next row, gets the bar's own scene (element 24771) back. gr_end does that at the end
# of the screen update: a flash before it is camera-only (research/TESTING.md, "Past regressions").
HOLDER_SCENE = lambda element: f'expect:mem:{{gr_cont}}+0*+308*+4={element & 255:02x}{element >> 8:02x}'
GRID_ROW_AND_BACK = ('s1 wait wait ok wait ok wait ' + 'down wait ' * 7 + HOLDER_SCENE(24813) +
                     ' down wait ' + HOLDER_SCENE(24771) + ' up wait ' + HOLDER_SCENE(24813) + ' poweroff')
# WB Compensation (the sixth row) <-> Highlight & Shadow (the seventh): the holder's scene changes in the row refresh,
# not in the screen update. A scene set during the update makes the camera draw a pass without grid or curve before
# the refresh (research/NOTES.md, "the one-frame flash"). Hits: gr_upd / gr_end to the update's end (pe_back /
# pe_ret) holds no sc_set; each switch still sets the scene, which HOLDER_SCENE checks after each key.
WB_HS_SWITCH = ('s1 wait wait ok wait ok wait ' + 'down wait ' * 5 + HOLDER_SCENE(24813) +
                ' down wait ' + HOLDER_SCENE(24771) + ' up wait ' + HOLDER_SCENE(24813) +
                ' down up down wait ' + HOLDER_SCENE(24771) + ' up down up wait ' + HOLDER_SCENE(24813) + ' poweroff')
SCENE_IN_UPDATE = ('gr_upd', 'gr_end', 'sc_set', 'pe_back', 'pe_ret')


def no_scene_set_in_update(hits):
    """SCENE_IN_UPDATE hits: no sc_set between gr_upd or gr_end and the update's end."""
    inside, errors = False, []
    for n, _ in hits:
        if n in ('gr_upd', 'gr_end'):
            inside = True
        elif n in ('pe_back', 'pe_ret'):
            inside = False
        elif inside:
            errors.append('sc_set during the Picture Mode update')
    return errors


NOISE_FILTER_OFF_ROW = (f's1 wait wait {NR_ROW_STAR(False)} poke:{NF_BYTE:x}=fe wait {NR_ROW_STAR(False)} '
                        f'pokep:{NR_SLOT_COLOR2}=01 wait {NR_ROW_STAR(True)} poweroff')

# The wheel's dial label (#64) names the page: Saturation -> Hue -> Luminance -> Shadows -> Highlights -> Saturation.
# As on the camera, INFO on a single color turns ALL on, and the label stays Sat. The checks read a descriptor's
# stream size (+12), which differs per picture (worked out below from the drawing code).
U32 = lambda v: v.to_bytes(4, 'little').hex()
U16 = lambda v: v.to_bytes(2, 'little').hex()
VDESC = 0xa4cf688c                # the dial label ("Vivid"), 70 x 30
# The label and guide sizes come from the same drawing code as build.py: with and without Pillow's raqm text layout
# the pictures differ by a few bytes (the release builds use raqm, research/setup.sh), so they are worked out here.
import mkicons, mklabels  # noqa: E402
LABEL_SIZE = {t: len(mklabels.encode11(bytes(mklabels.render(mklabels.bitmap(t)).flatten()), 70, 30))
              for t in ('Sat', 'Hue', 'Lum', 'Tint')}
LABEL_IS = lambda name: f'expect:mem:{VDESC + 12:x}={U32(LABEL_SIZE[name])}'
OPEN_WHEEL = 's1 ok ok down down down wait'
WHEEL_PAGE_LABELS = (f'{OPEN_WHEEL} {LABEL_IS("Sat")} info wait {LABEL_IS("Sat")} info wait {LABEL_IS("Hue")} '
                     f'info wait {LABEL_IS("Lum")} info wait {LABEL_IS("Tint")} info wait {LABEL_IS("Tint")} '
                     f'info wait {LABEL_IS("Sat")} poweroff')
# On Saturation, GDESC (a single color) reads "Saturation [INFO]" and SDESC (ALL, 175 wide while ours) "Sat. All
# [INFO]", whether the dial or INFO turned ALL on. Off Saturation, SDESC is the camera's again.
GDESC, SDESC = 0xa49ecdf8, 0xa49edf88
_SAT_PICS = mkicons.sat_pictures()
SATURATION_GUIDE, SAT_ALL_GUIDE = (len(mkicons.encode11(bytes(a.flatten().tolist()), 175, 50)) for a in _SAT_PICS[1:])
SDESC_STOCK_SIZE = 4471
SDESC_IS = lambda width, size: f'expect:mem:{SDESC + 2:x}={U16(width)} expect:mem:{SDESC + 12:x}={U32(size)}'
WHEEL_SAT_GUIDES = (f'{OPEN_WHEEL} expect:mem:{GDESC + 12:x}={U32(SATURATION_GUIDE)} {SDESC_IS(175, SAT_ALL_GUIDE)} '
                    f'sub+1 wait expect:val:2197=255 {SDESC_IS(175, SAT_ALL_GUIDE)} sub-1 wait '
                    f'info wait {SDESC_IS(175, SAT_ALL_GUIDE)} info wait {SDESC_IS(180, SDESC_STOCK_SIZE)} poweroff')
# On Hue, ed_get calls the label code (vl_s). Its caller gets a2 back as it was. v0.20..v0.30.3 handed back the call's
# return address in a2: the call wrote it over ed_get's saved a2.
WHEEL_READOUT_KEEPS_A2 = f'keep:{{ed_get}}:{{g_ret}}:a2 {OPEN_WHEEL} info wait info wait wait expect:kept poweroff'
# The same on Shadows: tn_get calls the label code on its readout.
TONE_READOUT_KEEPS_A2 = (f'keep:{{tn_get}}:{{t_ret}}:a2 {OPEN_WHEEL} info wait info wait info wait info wait wait '
                         f'{LABEL_IS("Tint")} expect:kept poweroff')
# The front dial puts all colors (cursor 255) between slices 1 and 12. On Saturation it stops there, as stock. On Hue
# (as on Lum and Tint) it steps over: 1 -> 12 -> 1.
CURSOR = 2197                     # COLOR 1's wheel cursor: slice 1..12, 255 = all colors
WHEEL_DIAL_SKIPS_ALL = (f'{OPEN_WHEEL} sub+1 wait expect:val:{CURSOR}=255 sub-1 wait expect:val:{CURSOR}=1 '
                        f'info wait info wait {LABEL_IS("Hue")} sub+1 wait expect:val:{CURSOR}=12 '
                        f'sub-1 wait expect:val:{CURSOR}=1 poweroff')
# Left on Hue, the half-press puts the wheel back on Saturation and the camera's "Vivid" back for the other screens.
# The wheel opens again with Sat.
# A rear dial click on Hue and on Shadows: the screen refresh writes only COLOR 1's cursor, with its own value. The
# sector id's write before it re-checked 37 more settings (~375k of ~1.09M instructions a click). The screen follows
# each click, and a click back gives the same frame as before (om-emu does not draw the wheel itself). The first click
# on a page puts the '*' up, so the frames are compared from the second on.
WHEEL_STEP_WRITE = (f'main+1 wait fhash:a mids:{{manager}} main+1 wait expect:mids:{CURSOR} fhash:b '
                    f'expect:fdiff:a:b main-1 wait fhash:c expect:fsame:a:c')
WHEEL_STEP_WRITES_CURSOR = (f'{OPEN_WHEEL} info wait info wait {LABEL_IS("Hue")} {WHEEL_STEP_WRITE} '
                            f'info wait info wait {LABEL_IS("Tint")} {WHEEL_STEP_WRITE} poweroff')
# The same on the Extras page (P + AXIS = 3). INFO does not reach it in this build (W_EXTRAS 0), so the test puts the
# page byte there from Hue.
EXTRAS_STEP_WRITES_CURSOR = (f'{OPEN_WHEEL} info wait info wait {LABEL_IS("Hue")} pokep:0x{{AXIS}}=03 wait '
                             f'{WHEEL_STEP_WRITE} poweroff')
# The Mix page (the second row in Picture Mode) and the RGB page (the third): a dial click's refresh writes only the
# H&S panel's mode (2191) with its own value. The H&S id's write before it (976 / 978 + 3k) re-checked 37 more
# settings, ~355k of ~2.6M instructions a click. The picture follows each click, and a click back gives the frame
# before it. The first click on a page puts the '*' up, so the frames are compared from the second on.
OPEN_MIX = 's1 wait wait ok wait ok wait down wait'
PANEL_MODE = 2191
PANEL_STEP_WRITE = lambda dial: (f'{dial}+1 wait fhash:a mids:{{manager}} {dial}+1 wait expect:mids:{PANEL_MODE} '
                                 f'fhash:b expect:fdiff:a:b {dial}-1 wait fhash:c expect:fsame:a:c')
MIX_STEP_WRITES_MODE = (f'{OPEN_MIX} {PANEL_STEP_WRITE("main")} {PANEL_STEP_WRITE("sub")} down wait '
                        f'{PANEL_STEP_WRITE("main")} poweroff')
VIVID_SIZE = 1660                 # the camera's own dial label picture
WHEEL_RESET_LABEL = (f'{OPEN_WHEEL} info wait info wait {LABEL_IS("Hue")} menu wait menu wait s1 wait wait '
                     f'expect:mem:{VDESC + 12:x}={U32(VIVID_SIZE)} {OPEN_WHEEL} {LABEL_IS("Sat")} poweroff')
# Picture Mode closes after 30 s idle (#75, stock 8 s), counted again from each key or dial turn. The super control
# panel and the white balance screen keep 8 s. A dial turn every 12 s keeps the wheel open for 48 s.
WAITS = lambda n: 'wait ' * n     # a wait, a dial or an expect token runs 1.2 s, a key 1.35 s
PICTURE_MODE, SHOOTING = 'expect:gui:ID_ST_DIRECT_PICTUREMODE_ART', 'expect:gui:ID_ST_CA_REQ_DISP'
PANEL, WHITE_BALANCE = 'expect:gui:ID_ST_MENU_DTL_SCP', 'expect:gui:ID_ST_DIRECT_WB'
OPEN_PICTURE_MODE, OPEN_WHITE_BALANCE = 's1 wait wait ok wait ok wait', 's1 wait wait ok wait right wait ok wait'
PICTURE_MODE_IDLE_30S = (f'{OPEN_PICTURE_MODE} {WAITS(12)}{PICTURE_MODE} down {WAITS(14)}{PICTURE_MODE} '
                         f'{WAITS(11)}{SHOOTING} poweroff')
PANEL_IDLE_8S = f's1 wait wait ok {PANEL} {WAITS(8)}{SHOOTING} poweroff'
WHEEL_DIAL_KEEPS_OPEN = lambda dial: f'{OPEN_WHEEL} ' + f'{dial}+1 {WAITS(9)}' * 4 + f'{PICTURE_MODE} poweroff'
PICTURE_MODE_KEEPS_OPEN = lambda token: f'{OPEN_PICTURE_MODE} {token} {WAITS(9)}{PICTURE_MODE} poweroff'
WHITE_BALANCE_IDLE_8S = f'{OPEN_WHITE_BALANCE} {WHITE_BALANCE} down {WAITS(9)}{SHOOTING} poweroff'
# A touch re-arms the screen's idle time through shared code (0x612a8db3, our s_tch). In Picture Mode a tap on the
# COLOR 2 tab gives 30 s. A tap on the super control panel goes through the same code and keeps its 8 s.
COLOR2_TAB, PANEL_TAP = 'tap:393:550', 'tap:360:300'
TOUCH_ARM_KEPT = 'keep:{s_tch}:{TMR_ARM}:d1'   # the hook ran and left the time as it was
PICTURE_MODE_TOUCH_30S = (f'{OPEN_PICTURE_MODE} {COLOR2_TAB} {WAITS(16)}{PICTURE_MODE} {WAITS(9)}{SHOOTING} poweroff')
PANEL_TOUCH_8S = f's1 wait wait ok {PANEL} {TOUCH_ARM_KEPT} {PANEL_TAP} {WAITS(7)}expect:kept {SHOOTING} poweroff'
# Of the camera's 35 touch layouts only Picture Mode's re-arms id 500. A tap on the function screen (the panel, up,
# ok) reaches s_tch with its own timer, id 512 at 8000 ms, and the screen still closes after 8 s.
FUNCTION = 'expect:gui:ID_ST_MENU_FUNC_DIRECT'
FUNCTION_TOUCH_8S = (f's1 wait wait ok wait up wait ok {FUNCTION} hit:{{s_tch}}:d0=512,d1=8000 tap:150:100 '
                     f'{WAITS(4)}{FUNCTION} {WAITS(2)}expect:hit {SHOOTING} poweroff')

# A film switch writes only the camera settings it changes (pf_put): through the Picture Mode list from COLOR 1 to FILM 1,
# then FILM 2 and FILM 3, all three on COLOR 1. Each switch's writes of COLOR 1's 18 settings must equal the settings
# whose value changed. Before, all 18 were written each time. No '*' after, as before.
COLOR_1 = 0
FILM_WRITES = f'wcount:{{manager}}:{{pf_ids}}:{COLOR_1} right wait expect:wcount'
FILM_SWITCH_WRITES = ('wait wait s1 wait wait ok wait ok wait ' + 'right wait ' * 3 +
                      ' '.join([FILM_WRITES] * 3) + ' menu wait wait s1 wait wait poweroff')
FILM_3_LINE = r'^Picture mode: COLOR 1, FILM 3\b'
NO_STAR_LINE = r'^Films with changes \(a \* in the camera\): none$'

@dataclass
class Boot:
    tokens: str
    expect: list = field(default_factory=list)     # regexes, each must match a debug log line
    reject: list = field(default_factory=list)     # regexes no debug log line may match
    mode_dial: int = MODE_DIAL_P
    photo_switch: int = PHOTO_SWITCH_PHOTO    # None leaves PSET0 unset: the movie switch
    no_log: bool = False                           # no debug log may be on the card after this boot
    card: dict = field(default_factory=dict)   # OM3MOD file name -> a FIXTURES key put on the card before this boot,
                                               # or None to remove the file
    watch: tuple = ()                              # build symbols: each time the code reaches one is a hit
    hits: object = None                            # fn([(symbol, path at a0)] in run order) -> errors
    env: tuple = ()                                # (name, value) pairs added to the driver's environment

EDITS_MAGIC, EDITS_LEN = 0x54334d4f, 16 + 24 * 68    # TWMAGIC, TW_LEN in firmware/src/editor.s


def edits_file():
    """A valid EDITS.BIN with no record valid: magic, length, CRC-32 of the rest."""
    rest = bytes(EDITS_LEN - 12)
    return struct.pack('<III', EDITS_MAGIC, EDITS_LEN, zlib.crc32(rest)) + rest


# v0.30 test 9: CURVES.BIN (each film's built-in curves and mix, docs/FORMATS.md), made from the newest release's
# LOOKS.BIN. Film 1 (COLOR 1, look 2: PICK_FILM_2) gets values; B changes them; BAD has a wrong CRC.
FIXTURES = {
    'CURVES_A': lambda looks, names: mkcurves.build(looks, {names[1]: {'r': [1, 0, 0, 0, -1], 'mix': [1, 2, 0, 0, 0, 0]}}),
    'CURVES_B': lambda looks, names: mkcurves.build(looks, {names[1]: {'g': [0, 2, 0, 0, 0], 'mix': [0, 0, 0, 0, -1, 3]}}),
    'CURVES_BAD': lambda looks, names: (lambda b: b[:40] + bytes([b[40] ^ 1]) + b[41:])(FIXTURES['CURVES_A'](looks, names)),
    'BUNDLES_HUE': lambda looks, names: fwbuild.make_file({0: {'hue': [3] + [0] * 11, 'light': [0] * 12}}),
    'EDITS_EMPTY': lambda looks, names: edits_file(),
}
# From the shooting screen: the RGB row (the third in Picture Mode), the rear dial once on Red's first point, out.
OPEN_RGB = 'ok wait ok wait down wait down wait'
# borders: Picture Mode's Border row, the 18th (pm_list: after Film Grain and Grain Size, better grain g2); COLOR 1's
# slot +50 is P + 82
OPEN_BORDER = 'ok wait ok wait' + ' down wait' * 17
# border preview (2026-11-17): with a Border on the look, the shooting screen's grid shows the border's inner edge as
# a frame line. Rear screen 900 x 600, 4:3: the picture x 50..850, y 0..599; Border 3 is 26 px in (bd_run's width), so
# the left line is on x 75..76 and the top one on y 25..26. Each line is checked against a point beside it on om-emu's
# blank live view. In video (16:9, y 47..553) the left line would be on x 21..22.
BORDER_LINE_ON = 'expect:pxdiff:75,300,100,300 expect:pxdiff:200,25,200,40'
BORDER_LINE_OFF = 'expect:pxsame:75,300,100,300 expect:pxsame:200,25,200,40'
BORDER_LINE_OFF_VIDEO = 'expect:pxsame:22,250,40,250 expect:pxsame:75,300,100,300'
BORDER_TO_3 = f'{OPEN_BORDER}' + ' right wait' * 3 + ' expect:p:82=03 menu wait wait s1 wait wait'
BORDER_TO_0 = f'{OPEN_BORDER}' + ' left wait' * 3 + ' expect:p:82=00 menu wait wait s1 wait wait'
# border-dial-direction (2026-11-18): a dial click on the Border row steps it the way it steps the camera's own
# Contrast row (the 9th, COLOR 1's setting 908). From Contrast nine rows down to Border.
CONTRAST_COLOR_1 = 908
DIAL_AS_CONTRAST = (f's1 wait wait ok wait ok wait' + ' down wait' * 8 +
                    f' main+1 wait expect:val:{CONTRAST_COLOR_1}=1 sub+1 wait sub+1 wait expect:val:{CONTRAST_COLOR_1}=-1' +
                    ' down wait' * 9 + ' right wait right wait expect:p:82=02 main+1 wait expect:p:82=03'
                    ' sub+1 wait sub+1 wait expect:p:82=01 menu wait wait s1 wait wait poweroff')
# dial direction (2026-11-18): the same for Glow, Halation, Split Tone Balance and Film Grain. Contrast first, then
# the row (moves from Contrast, the 9th row): right twice, the rear dial once (+1), the front dial twice (-2). The
# values: COLOR 1's slot byte (P + 32 + slot) after each step. Glow keeps Glow as -1..-5 (the screen shows +1..+5).
# Film Grain's byte is its level (strength 2, 3, 1 -> 1, 2, 1), so its strength is also checked in the debug log.
CONTRAST_CLICKS = (f's1 wait wait ok wait ok wait' + ' down wait' * 8 + f' main+1 wait expect:val:{CONTRAST_COLOR_1}=1'
                   f' sub+1 wait sub+1 wait expect:val:{CONTRAST_COLOR_1}=-1')
BAR_DIAL = lambda moves, off, two, three, one: (
    f'{CONTRAST_CLICKS} {moves} right wait right wait expect:p:{off}={two} main+1 wait expect:p:{off}={three}'
    f' sub+1 wait sub+1 wait expect:p:{off}={one} menu wait wait s1 wait wait poweroff')
GLOW_DIAL = BAR_DIAL('down wait ' * 5, 81, 'fe', 'fd', 'ff')
HALATION_DIAL = BAR_DIAL('down wait ' * 6, 62, '02', '03', '01')
BALANCE_DIAL = BAR_DIAL('up wait ' * 4, 65, '02', '03', '01')
GRAIN_DIAL = BAR_DIAL('down wait ' * 7, 85, '01', '02', '01')
GRAIN_1_MEDIUM = '^Film Grain on COLOR 1-4: 1 Medium, Off, Off, Off$'
# better grain g2: the Film Grain strength row, the 16th (Grain Size under it); COLOR 1's level byte +53 is P + 85
OPEN_GRAIN = 'ok wait ok wait' + ' down wait' * 15
GRAIN_2_COARSE = '^Film Grain on COLOR 1-4: 2 Coarse, Off, Off, Off$'
EDIT_RGB = f'{OPEN_RGB} main+1 wait menu wait wait'


# crop modes: from 4:3 on the shooting screen, the super control panel's Image Aspect cell, the main dial n steps along
# the camera's list 4:3, 16:9, 3:2, 1:1, 3:4, then ours 5:4, XPan, 21:9 (n = 1 16:9, 6 XPan, 7 21:9).
def PICK_ASPECT(n):
    return 'ok down down right right' + ' main+1 wait' * n


# Custom menu > Grid Settings > Displayed Grid > thirds (the 4th row), back to shooting.
GRID_THIRDS = 'menu left ok wait down ok wait down wait down wait down wait ok wait s1 wait wait'


def CROP_LINE(tag, then, set_to, after, now):
    return (rf'^CROP MODES \(crop round \d+\w*\): tag at the first half-press {tag}, Image Aspect then {then}, set to {set_to}, '
            rf'after {after}, now {now};')


def CROP_ASPECT_IS(v):                           # Image Aspect in the camera's settings image (M + 0x2c2) is v
    return f'expect:mem:629209c2={v:02x}'


def CROP_NOW(now):
    return rf'^CROP MODES \(crop round \d+\w*\): .*, now {now};'


# A valid films block in camera memory: BUNDLES.BIN and EDITS.BIN on the card change nothing, their lines as without.
CARD_FILES_UNUSED_LINES = [
    r"^Films: from the camera's memory; films block in camera memory at power-on: valid",
    r'^Loaded: films \(LOOKS\) yes, film changes and pictures \(EDITS\) yes, TONES yes$',
    r'^Card files: all match this firmware$',
    r"^  EDITS\.BIN: on the card, not used \(kept in the camera's memory\)$",
    r"^  BUNDLES\.BIN: on the card, not used \(kept in the camera's memory\)$",
    r'^COLOR 1: its own settings, no film$',
]

CARD_FILE_READS = ('fopen',)
# The driver's own watch (tools/emulator/session_ed1.mjs): WBOOT arms it before the session's lab exists. A hit there
# with WTID read memory through readers not yet declared (ReferenceError, driver exit 1). The getter runs at start-up.
WATCH_FROM_START_UP = ('getter',)


def watch_hit_seen(hits):
    return [] if hits else ['no getter hit']


def no_card_file_reads(hits):
    """fopen hits: DEBUG.TXT asked (so the probe sees fopen), BUNDLES.BIN and EDITS.BIN never."""
    paths = [s or '' for _, s in hits]
    return ([] if any(p.endswith('DEBUG.TXT') for p in paths) else [f'no fopen of DEBUG.TXT seen: {paths}']) + \
        [f'fopen {p}' for p in paths if p.endswith(('BUNDLES.BIN', 'EDITS.BIN'))]


LOG_GATE = ('lg_write', 'hl_ok', 'lg_out')


def card_gate_first_event_only(hits):
    """lg_write to lg_out hits: the card gate hl_ok in the first event's write only (it finds DEBUG.TXT absent)."""
    gates, inside = [], False
    for n, _ in hits:
        if n == 'lg_write':
            gates.append(0)
            inside = True
        elif n == 'lg_out':
            inside = False
        elif inside:
            gates[-1] += 1
    if len(gates) < 2:
        return [f'lg_write ran {len(gates)} times, want 2 or more']
    return [f'hl_ok in lg_write after the first event, per event: {gates}'] if any(gates[1:]) else []


CK_WORDS = ['none', 'none (its film has some)', "its film's", 'changed']   # has values x 2 + differs from the built-in


def ck_line(mem, card, matches, on_builtin, with_values):
    """CADLOG's CURVES.BIN lines (debug log dl9, v0.30 test 10: START-UP's file line and NOW's line per COLOR):
    on_builtin / with_values are bit masks, bit k-1 for COLOR k."""
    words = [CK_WORDS[2 * (with_values >> k & 1) + (1 - (on_builtin >> k & 1))] for k in range(4)]
    return [rf"^CURVES\.BIN \(each film's built-in curves and mix\): in camera memory: {mem}; this power-on's card: {card}; "
            rf"films it matches: {matches}$",
            '^Curves / mix on COLOR 1-4: ' + re.escape(', '.join(words)) + '$']


TESTS = {
    'boot-smoke': [
        Boot('s1 wait wait poweroff', expect=[
            r'^Card files: all match this firmware$',
            r'^Loaded: films \(LOOKS\) yes,',
            r'^Loaded: GUIDES code block yes,',
            r'^Films: from the card',
            r'^Films block in camera memory: writes 1,',
        ]),
    ],
    'films-from-camera-memory': [
        Boot('s1 wait wait poweroff', expect=[r'^Films: from the card']),
        Boot('s1 wait wait poweroff', expect=[
            r'^Films: .*; films block in camera memory at power-on: valid',
            r'^Films: from the camera',
        ], reject=[r'^Films: from the card']),
    ],
    'film-kept-with-half-press-after-pick': [
        Boot('s1 wait wait poweroff'),
        Boot(f'wait wait s1 wait wait {PICK_FILM_2} s1 wait wait poweroff', expect=[FILM_2_LINE]),
        Boot('wait wait s1 wait wait poweroff', expect=[FILM_2_LINE]),
    ],
    'film-kept-with-no-half-press-after-pick': [
        Boot('s1 wait wait poweroff'),
        Boot(f'wait wait s1 wait wait {PICK_FILM_2} poweroff'),
        Boot('wait wait s1 wait wait poweroff', expect=[FILM_2_LINE]),
    ],
    'custom-mode-film-over-dial-turn-while-off': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(C1_TURN_WHILE_OFF, expect=[C1_FILM_LINE, C1_RECORD_LINE], mode_dial=MODE_DIAL_C1),
        Boot(C1_TURN_WHILE_OFF, expect=[P_FILM_LINE, C1_RECORD_LINE], mode_dial=MODE_DIAL_P),
    ],
    'dial-turn-before-first-half-press': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(C1_TURN_BEFORE_HALF_PRESS, expect=[GROUP_C1_LINE, C1_FILM_LINE], mode_dial=MODE_DIAL_M),
    ],
    'live-dial-turn-waits-for-the-mode-code': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(LIVE_TURN_M_TO_C1, expect=[GROUP_C1_LINE, C1_FILM_LINE, RESET_MODE_UNCHANGED_LINE],
             reject=[SWITCH_AT_DIAL_CODE],
             mode_dial=MODE_DIAL_M),
    ],
    'live-dial-turn-back-keeps-the-mode-choice': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(LIVE_TURN_M_TO_C1_AND_BACK, expect=[P_FILM_LINE, RESET_MODE_UNCHANGED_LINE], reject=[SWITCH_AT_DIAL_CODE],
             mode_dial=MODE_DIAL_M),
    ],
    'live-dial-turn-to-b-switches-the-films': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(LIVE_TURN_C1_TO_B, expect=[P_FILM_LINE], mode_dial=MODE_DIAL_C1),
    ],
    'live-dial-turn-holds-the-label': [
        Boot(BOOT1_ASSIGN_C1),
        Boot(LIVE_TURN_HOLDS_THE_LABEL, expect=[P_FILM_LINE], mode_dial=MODE_DIAL_M),
    ],
    # borders: the Border row steps 0..5 (right / left; no step past either end) into COLOR 1's slot +50, and the
    # value is kept over a power-off (saved at the half-press).
    'border-row-0-to-5-kept': [
        Boot(f's1 wait wait {OPEN_BORDER}' + ' right wait' * 7 + ' expect:p:82=05 left wait left wait expect:p:82=03'
             ' menu wait wait s1 wait wait poweroff'),
        Boot(f'wait wait s1 wait wait expect:p:82=03 {OPEN_BORDER}' + ' left wait' * 4 + ' expect:p:82=00'
             ' menu wait wait s1 wait wait poweroff'),
    ],
    # border-dial-direction: the rear and front dials step Border as they step Contrast (rear +1 up, front +1 down).
    'border-dial-steps-as-contrast': [Boot(DIAL_AS_CONTRAST)],
    # dial direction: the rear and front dials step Glow, Halation, Split Tone Balance and Film Grain as Contrast.
    'glow-dial-steps-as-contrast': [Boot(GLOW_DIAL)],
    'halation-dial-steps-as-contrast': [Boot(HALATION_DIAL)],
    'tone-balance-dial-steps-as-contrast': [Boot(BALANCE_DIAL)],
    'grain-dial-steps-as-contrast': [Boot(GRAIN_DIAL, expect=[GRAIN_1_MEDIUM])],
    # border preview: the frame line is there at Border 3 and gone at Border 0 (and not there before the Border).
    'border-preview-on-at-3-off-at-0': [
        Boot(f's1 wait wait {BORDER_LINE_OFF} {BORDER_TO_3} {BORDER_LINE_ON} {BORDER_TO_0} {BORDER_LINE_OFF} poweroff'),
    ],
    # border preview: after a power-off the line waits for the first half-press (the start-up rule), then shows.
    'border-preview-waits-for-the-first-half-press': [
        Boot(f's1 wait wait {BORDER_TO_3} {BORDER_LINE_ON} s1 wait wait poweroff'),
        Boot(f'wait wait {BORDER_LINE_OFF} s1 wait wait {BORDER_LINE_ON} poweroff'),
    ],
    # border preview: video keeps its grid as it is (no line with Border 3 on the look, after a half-press).
    'border-preview-not-in-video': [
        Boot(f's1 wait wait {BORDER_TO_3} {BORDER_LINE_ON} s1 wait wait poweroff'),
        Boot(f'wait wait s1 wait wait {BORDER_LINE_OFF_VIDEO} poweroff', photo_switch=PHOTO_SWITCH_VIDEO),
    ],
    # crop modes: XPan (Image Aspect 6) is saved as 16:9 with our tag, so the camera starts on 16:9; the first half-press
    # puts XPan back (the start-up rule: nothing of ours before it, not even with v0.30's early load of the films).
    'crop-xpan-starts-as-16-9-and-comes-back': [
        Boot(f's1 wait wait {PICK_ASPECT(6)} s1 wait wait poweroff', expect=[CROP_NOW(6)]),
        Boot(f'wait wait {CROP_ASPECT_IS(3)} expect:mem:{{cr_on}}=00 s1 wait wait {CROP_ASPECT_IS(6)} poweroff',
             expect=[CROP_LINE('43520006', 3, 6, 6, 6)]),
    ],
    # crop round 7b: the two store-write hooks sit in section 1 and their code in section 6, which is copied later while
    # the camera starts: they wait for the camera's own ready bit for section 6 (0xa32de58c bit 5). With it cleared
    # (bits for sections 1..5 left), a power-off saves Image Aspect as it is (XPan, 6): no base ratio, no tag.
    'crop-save-waits-for-section-6': [
        Boot(f's1 wait wait {PICK_ASPECT(6)} s1 wait wait poke:a32de58c=1f poweroff', expect=[CROP_NOW(6)]),
        Boot(f'wait wait {CROP_ASPECT_IS(6)} poweroff'),
    ],
    # crop modes: a stock ratio (16:9) is saved as it is, with no tag, and nothing is set at the first half-press.
    'crop-stock-ratio-left-alone': [
        Boot(f's1 wait wait {PICK_ASPECT(1)} s1 wait wait poweroff', expect=[CROP_NOW(3)]),
        Boot('wait wait s1 wait wait poweroff', expect=[CROP_LINE('00000000', 0, 0, 0, 3)]),
    ],
    # crop round 2: the live view display set-up's picture area (rear screen, id 6 = XPan: 900 x 332) and the AF point
    # grid (id 6: 16:9's 39 x 19) have rows for the crops. om-emu does not run that code, so this checks the tables.
    'crop-xpan-display-area-and-af-grid': [
        Boot('s1 wait wait expect:mem:602ed136=84034c01 expect:mem:60a3cd36=27001300 poweroff'),
    ],
    # crop round 2: at XPan the thirds sit in the strip (rear screen: 16:9 picture y 47..552, XPan strip y 134..465):
    # a vertical line at x 300 inside the strip, none above it; a horizontal one at y 243 (the strip's first third).
    'crop-grid-thirds-in-the-xpan-strip': [
        Boot(f's1 wait wait {PICK_ASPECT(6)} s1 wait wait {GRID_THIRDS} '
             'expect:pxdiff:300,300,310,300 expect:pxsame:300,120,310,120 expect:pxdiff:450,243,450,250 poweroff'),
    ],
    # crop round 2: a stock ratio keeps the camera's own thirds (16:9: the line at x 300 runs above y 134; y 215).
    'crop-grid-stock-ratio-unchanged': [
        Boot(f's1 wait wait {PICK_ASPECT(1)} s1 wait wait {GRID_THIRDS} '
             'expect:pxdiff:300,120,310,120 expect:pxdiff:450,215,450,225 poweroff'),
    ],
    # crop round 3: the AF target screen at XPan draws its area outline (x 2) and the Single target (x 506..532), as at
    # 16:9 (the pinned om-emu showed neither before: the GUI's screen spec held ratio 6, which no layout table has).
    'crop-af-target-drawn-at-xpan': [
        Boot(f's1 wait wait {PICK_ASPECT(6)} s1 wait wait left wait wait main-1 wait '
             'expect:pxdiff:2,300,10,300 expect:pxdiff:506,300,500,300 menu wait s1 wait wait poweroff'),
    ],
    # better grain g2: the Film Grain row steps 0..5 (no step past 5) and keeps the old level byte in step (5 -> High 3,
    # 2 -> Low 1); the Grain Size row (Medium -> Coarse); both kept over a power-off (the debug log's NOW line).
    'grain-rows-strength-and-size-kept': [
        Boot(f's1 wait wait {OPEN_GRAIN}' + ' right wait' * 7 + ' expect:p:85=03 left wait left wait left wait'
             ' expect:p:85=01 down wait right wait menu wait wait s1 wait wait poweroff', expect=[GRAIN_2_COARSE]),
        Boot('wait wait s1 wait wait expect:p:85=01 poweroff', expect=[GRAIN_2_COARSE]),
    ],
    'curves-file-kept-in-camera': [
        Boot(f's1 wait wait {PICK_FILM_2} s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_A'},
             expect=[FILM_2_LINE, *ck_line('yes', 'taken', 20, 15, 1)]),
        Boot('wait wait s1 wait wait poweroff', card={'CURVES.BIN': None},
             expect=[FILM_2_LINE, *ck_line('yes', 'none', 20, 15, 1)]),
        Boot('wait wait s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_A'},
             expect=[*ck_line('yes', 'the same', 20, 15, 1)]),
    ],
    'curves-file-new-values-follow-edits-stay': [
        Boot(f's1 wait wait {PICK_FILM_2} s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_A'},
             expect=[*ck_line('yes', 'taken', 20, 15, 1)]),
        Boot('wait wait s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_B'},
             expect=[*ck_line('yes', 'taken', 20, 15, 1)]),
        Boot(f'wait wait s1 wait wait {EDIT_RGB} s1 wait wait poweroff',
             expect=[*ck_line('yes', 'the same', 20, 14, 1)]),
        Boot('wait wait s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_A'},
             expect=[*ck_line('yes', 'taken', 20, 14, 1)]),
    ],
    'curves-file-none-or-not-valid': [
        Boot(f's1 wait wait {PICK_FILM_2} s1 wait wait poweroff',
             expect=[FILM_2_LINE, *ck_line('no', 'none', 0, 15, 0)]),
        Boot('wait wait s1 wait wait poweroff', card={'CURVES.BIN': 'CURVES_BAD'},
             expect=[*ck_line('no', 'not valid', 0, 15, 0)]),
    ],
    'card-edits-and-bundles-unused-with-films-in-camera': [
        Boot('s1 wait wait poweroff'),
        Boot('wait wait s1 wait wait poweroff', card={'BUNDLES.BIN': 'BUNDLES_HUE', 'EDITS.BIN': 'EDITS_EMPTY'},
             expect=CARD_FILES_UNUSED_LINES),
        Boot('wait wait s1 wait wait poweroff', card={'DEBUG.TXT': None}, no_log=True, watch=CARD_FILE_READS,
             hits=no_card_file_reads),
    ],
    'grid-row-gives-the-bottom-bar-back': [
        Boot(GRID_ROW_AND_BACK),
    ],
    'wb-to-highlight-shadow-sets-the-scene-in-the-row-refresh': [
        Boot(WB_HS_SWITCH, watch=SCENE_IN_UPDATE, hits=no_scene_set_in_update),
    ],
    'debug-log-written-at-releases-only': [
        Boot('s1 wait wait s1 wait wait s1 wait wait poweroff', expect=[DEBUG_LOG_RELEASES_ONLY]),
    ],
    'debug-log-off-writes-no-log': [
        Boot('s1 wait wait s1 wait wait s1 wait wait poweroff', card={'DEBUG.TXT': None}, no_log=True, watch=LOG_GATE,
             hits=card_gate_first_event_only),
    ],
    'noise-filter-row-follows-the-camera-setting': [
        Boot(NOISE_FILTER_OFF_ROW),
    ],
    # #72: switching films fast in the Picture Mode list rebooted the camera; the group's record (cm_hp) was kept at
    # every step. Now none while the list stays open (FILM 1 <-> FILM 2 and the films after), once as it closes (OK).
    'film-list-keeps-the-record-once-as-it-closes': [
        Boot('s1 wait wait ok wait ok wait' + ' right wait' * 5 + ' count:{cm_hp}:*' + ' left wait right wait' * 6 +
             ' right wait' * 6 + ' expect:count:{cm_hp}=0 ok wait wait expect:count:{cm_hp}=1 menu wait wait'
             ' s1 wait wait poweroff'),
    ],
    # #72: the super control panel's dials step the films too: no record keep while it stays open, one as it closes.
    'control-panel-dial-keeps-the-record-once-as-it-closes': [
        Boot('s1 wait wait ok wait count:{cm_hp}:*' + ' main+1 wait' * 8 + ' expect:count:{cm_hp}=0 menu wait wait'
             ' expect:count:{cm_hp}=1 s1 wait wait poweroff'),
    ],
    # border preview: with no Border on any COLOR, the grid read (bl_gv) asks the GUI for no picture mode (111): a
    # menu open and close makes the camera's own 25 reads, as stock (with the extra read: 50).
    'border-preview-grid-read-asks-only-what-it-needs': [
        Boot('s1 wait wait count:{gui_get}:6f menu wait wait menu wait wait expect:count:{gui_get}=25 poweroff'),
    ],
    'color-wheel-dial-label-follows-the-page': [
        Boot(WHEEL_PAGE_LABELS),
    ],
    'color-wheel-dial-label-resets-with-the-page': [
        Boot(WHEEL_RESET_LABEL),
    ],
    'color-wheel-readout-keeps-the-callers-a2': [
        Boot(WHEEL_READOUT_KEEPS_A2),
    ],
    'color-wheel-front-dial-skips-all-colors-off-saturation': [
        Boot(WHEEL_DIAL_SKIPS_ALL),
    ],
    'color-wheel-tone-readout-keeps-the-callers-a2': [
        Boot(TONE_READOUT_KEEPS_A2),
    ],
    'color-wheel-saturation-guide-names-the-page': [
        Boot(WHEEL_SAT_GUIDES),
    ],
    'picture-mode-closes-after-30-s-idle': [
        Boot(PICTURE_MODE_IDLE_30S),
    ],
    'super-control-panel-closes-after-8-s-idle': [
        Boot(PANEL_IDLE_8S),
    ],
    'picture-mode-rear-dial-restarts-the-idle-time': [
        Boot(WHEEL_DIAL_KEEPS_OPEN('main')),
    ],
    'picture-mode-front-dial-restarts-the-idle-time': [
        Boot(WHEEL_DIAL_KEEPS_OPEN('sub')),
    ],
    'picture-mode-up-key-restarts-the-idle-time': [
        Boot(PICTURE_MODE_KEEPS_OPEN('up')),
    ],
    'picture-mode-touch-restarts-the-idle-time': [
        Boot(PICTURE_MODE_TOUCH_30S),
    ],
    'super-control-panel-touch-keeps-8-s': [
        Boot(PANEL_TOUCH_8S),
    ],
    'function-screen-touch-keeps-8-s': [
        Boot(FUNCTION_TOUCH_8S),
    ],
    'white-balance-closes-after-8-s-idle': [
        Boot(WHITE_BALANCE_IDLE_8S),
    ],
    'color-wheel-dial-step-writes-the-cursor-only': [
        Boot(WHEEL_STEP_WRITES_CURSOR),
    ],
    'extras-dial-step-writes-the-cursor-only': [
        Boot(EXTRAS_STEP_WRITES_CURSOR),
    ],
    'mix-and-rgb-dial-step-writes-the-panel-mode-only': [
        Boot(MIX_STEP_WRITES_MODE),
    ],
    'driver-watch-from-start-up-reads-thread-ids': [
        Boot('wait poweroff', watch=WATCH_FROM_START_UP, env=(('WTID', '1'),), hits=watch_hit_seen),
    ],
    'film-switch-writes-only-changed-settings': [
        Boot('s1 wait wait poweroff'),
        Boot(FILM_SWITCH_WRITES, expect=[FILM_3_LINE, NO_STAR_LINE]),
    ],
    'video-boot-after-photo-boot': [
        Boot('s1 wait wait poweroff'),
        Boot(VIDEO_BOOT, expect=VIDEO_BOOT_LINES, photo_switch=PHOTO_SWITCH_VIDEO),
    ],
}

# Tests the current release fails, with the reason. They do not fail a run. Remove an entry once main passes it.
KNOWN_FAILURES = {}   # v0.30 test 8: 'film-kept-with-no-half-press-after-pick' passes with PR #56 (early load)
# Errors a test's runner turns into a failure of that test, not of the whole run.
RUNNER_ERRORS = (subprocess.TimeoutExpired, RuntimeError, OSError, ValueError, KeyError, IndexError)


def check_emu_pin(emu):
    """Exits unless om-emu is at the pinned commit. Warns when the pin is older than EMU_MAX_AGE_DAYS."""
    pin = EMU_PIN.relative_to(REPO)
    m = EMU_PIN_LINE.fullmatch(EMU_PIN.read_text().strip())
    if not m:
        sys.exit(f"{pin}: expected one line, 'COMMIT YYYY-MM-DD' with the full 40-character commit")
    pinned, checked = m.groups()
    emu_rev = git('rev-parse', 'HEAD', cwd=pathlib.Path(emu).parent) or '?'
    if emu_rev != pinned:
        sys.exit(f'om-emu is at {emu_rev[:7]}, but {pin} names {pinned[:7]}: run research/setup.sh')
    age = (datetime.date.today() - datetime.date.fromisoformat(checked)).days
    if age > EMU_MAX_AGE_DAYS:
        print(f'om-emu: the pin was last checked {age} days ago. Run tools/emulator/bump_om_emu.sh.', file=sys.stderr)


def git(*args, cwd=REPO):
    r = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def pass_path(cwd=REPO):
    d = git('rev-parse', '--absolute-git-dir', cwd=cwd)
    return pathlib.Path(d, PASS_FILE) if d else None


def read_pass(cwd=REPO):
    p = pass_path(cwd)
    try:
        return json.loads(p.read_text()) if p else None
    except (OSError, ValueError):
        return None


def record_pass(build):
    """Writes the pass that pr_gate.py checks, only for committed code: a dirty tree is not what a PR proposes."""
    head, dirty, p = git('rev-parse', 'HEAD'), git('status', '--porcelain'), pass_path()
    try:
        built = json.loads((build / 'build.json').read_text()).get('source_sha256')
    except (OSError, ValueError):
        built = None
    if built != source_digest(REPO):
        print('No pass recorded for the pull request check: the build is not from this checkout, build it again')
    elif head and dirty == '' and p:
        p.write_text(json.dumps({'head': head, 'build': str(build)}))
        print(f'Pass recorded on {head[:12]} for the pull request check')
    else:
        print('No pass recorded for the pull request check: commit your changes, then run the suite again')


def node(*args, env=None, timeout=BOOT_TIMEOUT_S):
    return subprocess.run(['node', *map(str, args)], env=env, capture_output=True, text=True, timeout=timeout)


def card_tool(emu, *args):
    r = node(f'{emu}/bin/card.mjs', *args)
    if r.returncode:
        raise RuntimeError(f'card.mjs {" ".join(map(str, args))}: {r.stderr.strip()}')


def make_card(emu, build, looks, path):
    card_tool(emu, 'new', path)
    card_tool(emu, 'mkdir', path, 'OM3MOD')
    for local, name in [(build / 'GUIDES.BIN', 'GUIDES.BIN'), (build / 'LABELS.BIN', 'LABELS.BIN'),
                        (looks, 'LOOKS.BIN'), (DEBUG_TXT, 'DEBUG.TXT')]:
        card_tool(emu, 'put', path, local, f'OM3MOD/{name}')


def read_log(emu, card, dest):
    """The boot's debug log, then removed from the card so the next boot cannot pass on a stale one."""
    r = node(f'{emu}/bin/card.mjs', 'get', card, LOG_PATH, dest)
    if r.returncode:
        return None
    card_tool(emu, 'rm', card, LOG_PATH)
    return [l.rstrip() for l in dest.read_bytes().decode('latin1').replace('\r', '').split('\n') if l.strip()]


def put_card_files(emu, card, files, fixtures, dest):
    """A copy of the card with each file put (from fixtures) or removed."""
    shutil.copy(card, dest)
    for fname, key in files.items():
        node(f'{emu}/bin/card.mjs', 'rm', dest, f'OM3MOD/{fname}')      # absent is fine
        if key is not None:
            card_tool(emu, 'put', dest, fixtures[key], f'OM3MOD/{fname}')
    return dest


def make_fixtures(out, looks):
    d = out / 'fixtures'
    d.mkdir(parents=True, exist_ok=True)
    data = looks.read_bytes()
    names = [data[1312 + 16 * j:1328 + 16 * j].rstrip(b'\0').decode('latin1') for j in range(20)]
    paths = {}
    for k, make in FIXTURES.items():
        paths[k] = d / f'{k}.BIN'
        paths[k].write_bytes(make(data, names))
    return paths


def elf_symbols(path):
    """name -> address, from an ELF32 little-endian file's symbol tables."""
    b = path.read_bytes()
    shoff, = struct.unpack_from('<I', b, 0x20)
    shentsize, shnum = struct.unpack_from('<HH', b, 0x2e)
    secs = [struct.unpack_from('<10I', b, shoff + i * shentsize) for i in range(shnum)]
    syms = {}
    for _, kind, _, _, off, size, link, *_ in secs:
        if kind != 2:    # SHT_SYMTAB
            continue
        names = secs[link][4]
        for o in range(off, off + size, 16):
            n, value = struct.unpack_from('<II', b, o)
            syms[b[names + n:b.index(b'\0', names + n)].decode()] = value
    return syms


def boot_key(boot):
    return boot.tokens, boot.mode_dial, boot.photo_switch, tuple(sorted(boot.card.items())), boot.watch, boot.hits, boot.env


def run_boot(emu, build, d, i, boot, card, syms, fixtures=None):
    """Boot i in d, from card, with d/nv.bin as the camera's settings -> (next card, log lines or None, errors, a
    fatal error or None). syms caches the build's symbols for tokens that name them."""
    nxt = d / f'card{i}.omsd'
    if boot.card:
        card = put_card_files(emu, card, boot.card, fixtures, d / f'card{i}-in.omsd')
    tokens = boot.tokens
    if '{' in tokens or boot.watch:
        if not syms:
            syms.update({k: f'{v:x}' for k, v in elf_symbols(build / 'p.elf').items()})
        tokens = tokens.format_map(syms)
    env = {**os.environ, 'OM_EMU_MODEL': MODEL, 'NV_FILE': str(d / 'nv.bin'), 'MODE0': str(boot.mode_dial),
           'PSET0': str(boot.photo_switch)}
    if boot.watch:
        env.update(WATCH=','.join(syms[n] for n in boot.watch), WSTR='1', WBOOT='1')
    env.update(boot.env)
    try:
        r = node(DRIVER, emu, build / 'main.bin', card, d / f'boot{i}.json', nxt, tokens, env=env)
    except subprocess.TimeoutExpired:
        return nxt, None, [], f'boot {i}: no result after {BOOT_TIMEOUT_S} s'
    (d / f'boot{i}.log').write_text(r.stdout + r.stderr)
    if r.returncode:
        return nxt, None, [], f'boot {i}: driver exit {r.returncode} (boot{i}.log)'
    if not nxt.exists():
        return nxt, None, [], f'boot {i}: driver saved no card (boot{i}.log)'
    errors = []
    if boot.tokens.split()[-1] == 'poweroff' and not json.loads((d / f'boot{i}.json').read_text())['log'][-1].get('power_off'):
        errors.append(f'boot {i}: the firmware did not power off (boot{i}.json)')
    if boot.hits:
        name = {int(syms[n], 16): n for n in boot.watch}
        hits = [(name[int(h['pc'], 16)], h.get('s')) for h in json.loads((d / f'boot{i}.json').read_text())['hits']]
        errors += [f'boot {i}: {e} (boot{i}.json)' for e in boot.hits(hits)]
    return nxt, read_log(emu, nxt, d / f'cadlog{i}.txt'), errors, None


def check_log(i, boot, lines):
    """boot i's expect and reject against its log lines -> errors, and whether the test must stop."""
    if boot.no_log:
        return ([f'boot {i}: unwanted {LOG_PATH} on the card'] if lines is not None else []), False
    if lines is None:
        return ([f'boot {i}: no {LOG_PATH} on the card'], True) if boot.expect or boot.reject else ([], False)
    return ([f'boot {i}: no line matches {p}' for p in boot.expect if not any(re.search(p, l) for l in lines)] +
            [f'boot {i}: unwanted line {l!r}' for p in boot.reject for l in lines if re.search(p, l)]), False


def run_shared(emu, build, d, boot, card0, fixtures=None):
    """A first boot that several tests share, run once in d -> run_boot's result, its errors naming d."""
    d.mkdir(parents=True, exist_ok=True)
    (d / 'nv.bin').unlink(missing_ok=True)
    try:
        nxt, lines, errors, fatal = run_boot(emu, build, d, 1, boot, card0, {}, fixtures)
    except RUNNER_ERRORS as e:
        nxt, lines, errors, fatal = None, None, [], f'boot 1: runner error: {e}'
    return nxt, lines, [f'{e}, shared boot in {d}' for e in errors], fatal and f'{fatal}, shared boot in {d}'


def run_test(name, boots, emu, build, card0, out, first=None, fixtures=None):
    """first: run_shared's result for boots[0], used in its place."""
    d = out / name
    d.mkdir(parents=True, exist_ok=True)
    (d / 'nv.bin').unlink(missing_ok=True)
    card, errors, syms = card0, [], {}
    for i, boot in enumerate(boots, 1):
        if i == 1 and first:
            card, lines, errs, fatal = first
            if not fatal and (card.parent / 'nv.bin').exists():
                shutil.copy(card.parent / 'nv.bin', d / 'nv.bin')
        else:
            card, lines, errs, fatal = run_boot(emu, build, d, i, boot, card, syms, fixtures)
        if fatal:
            return name, [fatal]
        found, stop = check_log(i, boot, lines)
        errors += errs + found
        if stop:
            return name, errors
    return name, errors


def run_audit(emu, build, out):
    """om-emu's patch audit: no patched byte where the camera's boot does not load it, no task started at power-on."""
    d = out / AUDIT
    d.mkdir(parents=True, exist_ok=True)
    r = node(f'{emu}/bin/session.mjs', '--model', MODEL, '--main', build / 'main.bin', '--loaded', 'auto', AUDIT_TOKENS)
    (d / 'session.log').write_text(r.stdout + r.stderr)
    summary = next((json.loads(l) for l in r.stdout.splitlines() if l.startswith('{"summary"')), None)
    if r.returncode or not summary:
        return AUDIT, [f'session.mjs exit {r.returncode}, no summary (session.log)']
    audit = summary.get('patch_audit')
    if not isinstance(audit, dict) or not {'unloaded', 'tasks'} <= audit.keys():
        return AUDIT, ['no patch_audit unloaded and tasks in the summary (session.log)']
    return AUDIT, [f'{k}: {json.dumps(audit[k])}' for k in ('unloaded', 'tasks') if audit[k]]


def run_halation(emu, build, out, card):
    """hl_run on HALATION_CASES in om-emu: bit-exact with the model, registers and sp back, nothing past the frame."""
    d = out / HALATION
    r = subprocess.run([sys.executable, HALATION_CHECK, build, '--out', d, '--jobs', '1', '--card', card,
                        '--only', *HALATION_CASES], capture_output=True, text=True, timeout=BOOT_TIMEOUT_S,
                       env={**os.environ, 'OM3_EMU': emu})
    d.mkdir(parents=True, exist_ok=True)
    (d / 'check.log').write_text(r.stdout + r.stderr)
    if r.returncode == 0:
        return HALATION, []
    return HALATION, [l for l in r.stdout.splitlines() if l.startswith('DIFF')] or [f'emu_check.py exit {r.returncode} (check.log)']


def run_border(emu, build, out, card):
    """bd_run on research/border/emu_check.py's default cases in om-emu: bit-exact with the model, registers and sp
    back, nothing past the frame, levels 0 and 6 untouched."""
    d = out / BORDER
    r = subprocess.run([sys.executable, BORDER_CHECK, build, '--out', d, '--card', card], capture_output=True,
                       text=True, timeout=BOOT_TIMEOUT_S, env={**os.environ, 'OM3_EMU': emu})
    d.mkdir(parents=True, exist_ok=True)
    (d / 'check.log').write_text(r.stdout + r.stderr)
    if r.returncode == 0:
        return BORDER, []
    return BORDER, [l for l in r.stdout.splitlines() if l.startswith('DIFF')] or [f'emu_check.py exit {r.returncode} (check.log)']
def tone_strength(code):
    """a stored strength code -5..5 -> strength 0..10 (st_run; research/splittone/model.py strength)"""
    return 2 * code if code >= 0 else -2 * code - 1


def look_model(table, ks, kh, balance, curves):
    """st_run's R, G, B tables from one stock table: split toning (research/splittone/model.py bend28), plus each
    channel's curve delta (research/rgbcurves/model.py), then the clamp and each part's running max."""
    c = 2048 - 256 * balance
    f1, f2 = 134217728 // c, 134152192 // (4095 - c)
    out = []
    for ch in range(3):
        p = curves_model.prm(curves[ch]) if any(curves[ch]) else None
        for part in (table[:256], table[256:]):
            mx = 0
            for t in part:
                u = (t * f1) >> 16 if t < c else (((t - c) * f2) >> 16) + 2048
                s = 4095 - u
                d = (ks[ch] * (((u * s >> 12) * s) >> 12) + kh[ch] * (((u * u >> 12) * s) >> 12)) >> 9
                if p:
                    d += curves_model.d_at(p, t)
                mx = max(mx, max(0, min(4095, t + d)))
                out.append(mx)
    return out


def run_ncall(emu, build, d, card0, tokens, spec):
    """One boot of the driver in d: tokens ending in ncall, which runs spec's calls -> {name: result}, or an error."""
    (d / 'spec.json').write_text(json.dumps(spec))
    env = {**os.environ, 'OM_EMU_MODEL': MODEL, 'NCALL': str(d / 'spec.json'), 'NOUT': str(d / 'out.json')}
    r = node(DRIVER, emu, build / 'main.bin', card0, d / 'boot.json', d / 'card.omsd', tokens, env=env)
    (d / 'boot.log').write_text(r.stdout + r.stderr)
    if r.returncode or not (d / 'out.json').exists():
        return f'driver exit {r.returncode}, no ncall result (boot.log)'
    return {o['name']: o for o in json.loads((d / 'out.json').read_text())['out']}


def run_grainmix(emu, build, out, card0):
    """s_c1e on a register image as the init 0x605047c1 leaves it, for strengths 1 / 3 / 5 and a tile not written."""
    d = out / GRAINMIX
    d.mkdir(parents=True, exist_ok=True)
    sym, xb = elf_symbols(build / 'p.elf'), elf_symbols(build / 'xb10000000.elf')
    fx1 = f"W(P+{sym['XPTR']})+{xb['xb_fx1'] - 0x10000000:#x}"
    word = lambda v: (v & 0xffffffff).to_bytes(4, 'little').hex()
    image = {136: 0xfe000000, 160: 0xfe000000, 180: 0x02000000, 184: 512}    # the init's Y / Cb offsets and minima
    def case(name, strength, bad):
        mem = [['B', 'dd'], ['B+1', '=(B+0x10)-B'], ['B+5', 'f01c'], ['B+0x10', 'dc'],
               ['B+0x11', f"={sym['s_c1e']:#x}-(B+0x10)"], ['B+0x200', '00' * 0x100],
               *[[f'B+0x200+{o}', word(v)] for o, v in image.items()],
               [fx1, f'{strength:02x}'], [f"{sym['tg_bad']:#x}", '01' if bad else '00']]
        return {'name': name, 'pc': 'B', 'stop': ['B+7'], 'max': 20000, 'mem': mem,
                'regs': {'a2': 'B+0x200', 'd0': '1024'}, 'read': [['B+0x200', 0x100]],
                'restore': [[f"{sym['tg_bad']:#x}", '00']]}
    spec = [case(f'strength{s}', s, False) for s in GRAIN_GAINS] + [case('tile-not-written', 3, True)]
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return GRAINMIX, [res]
    errors = []
    for o in spec:
        r = res[o['name']]
        img = bytes.fromhex(r['mem'][0])
        at = lambda off: int.from_bytes(img[off:off + 4], 'little')
        if r['steps'] >= 20000:
            errors.append(f"{o['name']}: s_c1e did not return (out.json)")
            continue
        if o['name'] == 'tile-not-written':
            want = {148: 0, 152: 0, 136: image[136], 160: image[160], 180: image[180]}
        else:
            y, c = GRAIN_GAINS[int(o['name'][-1])]
            want = {96: 0x04000400, 100: 1024, 148: c << 16 | y, 152: c,
                    136: 0xfe00ff40, 160: 0xfe00fe00, 180: 0x02000000}
        for off, v in want.items():
            if at(off) != v:
                errors.append(f"{o['name']}: register image +{off} is {at(off):#010x}, not {v:#010x}")
    return GRAINMIX, errors


def run_crophist(emu, build, out, card0):
    """cr_trim for each CROPHIST_CASES entry: `call cr_trim,[],0` with a1 -> the area."""
    d = out / CROPHIST
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    hw = lambda v: b''.join(x.to_bytes(2, 'little') for x in v).hex()
    def case(name, aspect, area):
        mem = [['B', 'dd'], ['B+1', f"={sym['cr_trim']:#x}-B"], ['B+5', '0000'], ['B+0x400', hw(area)],
               ['0x629209c2', f'{aspect:02x}'], [f"{sym['cr_on']:#x}", '01']]
        return {'name': name, 'pc': 'B', 'stop': ['B+7'], 'max': 20000, 'mem': mem, 'regs': {'a1': 'B+0x400'},
                'read': [['B+0x400', 8]], 'restore': [[f"{sym['cr_on']:#x}", '00']]}
    spec = [case(n, a, area) for n, (a, area, _) in CROPHIST_CASES.items()]
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return CROPHIST, [res]
    errors = []
    for n, (_, _, want) in CROPHIST_CASES.items():
        r = res[n]
        if r['steps'] >= 20000:
            errors.append(f'{n}: cr_trim did not return (out.json)')
            continue
        got = bytes.fromhex(r['mem'][0])
        got = tuple(int.from_bytes(got[2 * i:2 * i + 2], 'little') for i in range(4))
        if got != want:
            errors.append(f'{n}: area {got}, not {want}')
    return CROPHIST, errors


def run_croppl(emu, build, out, card0):
    """The stock 0x61101381 / 0x60c7c18a results, the label sites and elements stock; cr_pbk1 for CROPPL_KIND; the
    picture getter for CROPPL_PICTURE."""
    d = out / CROPPL
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    word = lambda v: v.to_bytes(4, 'little').hex()
    half = lambda v: v.to_bytes(2, 'little').hex()
    pbk = f"{sym.get('cr_pbk', 0):#x}"
    spec = [{'name': 'gui class', 'pc': 'B', 'stop': ['B'], 'read': [['W(0x603713a4)', 2]] +
             [[hex(a), len(h) // 2] for a, h in CROPPL_STOCK_BYTES.items()] + [[hex(e), 12] for e in CROPPL_ELEMENTS]}]
    for (w, h), _ in CROPPL_STOCK.items():
        spec.append({'name': f'stock label {w}x{h}', 'pc': 'B', 'stop': ['B+7'], 'max': 5000,
                     'mem': [['B', 'dd'], ['B+1', '=0x61101381-B'], ['B+5', '8004']], 'regs': {'d0': str(w), 'd1': str(h)}})
    for (c, k, w, h), _ in CROPPL_QUALITY.items():
        spec.append({'name': f'quality {c} {k} {w}x{h}', 'pc': 'B', 'stop': ['B+7'], 'max': 5000,
                     'mem': [['B', 'dd'], ['B+1', '=0x60c7c18a-B'], ['B+5', 'f014'], ['SP+4', word(w)], ['SP+8', word(h)]],
                     'regs': {'d0': '1', 'd1': str(c), 'a1': str(k)}})
    for (w, h), _ in CROPPL_KIND.items():
        spec.append({'name': f'kind {w}x{h}', 'pc': 'B', 'stop': ['0x61113424'], 'max': 2000,
                     'mem': [['B', 'dc'], ['B+1', f"={sym.get('cr_pbk1', 0):#x}-B"], ['B+0x300', half(w) + half(h)],
                             ['SP+2844', '78563412']],
                     'regs': {'d0': '4', 'd1': '0x11', 'a2': 'B+0x300', 'a3': 'B+0x302'}, 'read': [[pbk, 1]]})
    for (g, k, pic), _ in CROPPL_PICTURE.items():
        spec.append({'name': f'picture {g} {k} {pic}', 'pc': 'B', 'stop': ['B+7'], 'max': 50000,
                     'mem': [['B', 'dd'], ['B+1', '=0x610f5611-B'], ['B+5', '0000'], ['W(0x603713a4)', f'{g:02x}'],
                             [pbk, f'{k:02x}']],
                     'regs': {'d0': str(pic)}, 'restore': [['W(0x603713a4)', '01'], [pbk, '00']]})
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return CROPPL, [res]
    errors = []
    ok = lambda r, n: r['steps'] < n
    reg = lambda r, k: int(r['regs'][k], 16)
    mem = res['gui class']['mem']
    if bytes.fromhex(mem[0])[0] != 1:
        errors.append(f'the GUI state at the calls is {mem[0]}, not shooting (class 1): the restore would be wrong')
    for (a, want), got in zip(CROPPL_STOCK_BYTES.items(), mem[1:1 + len(CROPPL_STOCK_BYTES)]):
        if got != want:
            errors.append(f'{a:#x} is {got}, not the stock {want}')
    for (e, lst), got in zip(CROPPL_ELEMENTS.items(), mem[1 + len(CROPPL_STOCK_BYTES):]):
        if bytes.fromhex(got) != bytes([2, 5, 0, 0]) + lst.to_bytes(4, 'little') + (lst + 80).to_bytes(4, 'little'):
            errors.append(f'element {e:#x} is {got}, not stock')
    for (w, h), want in CROPPL_STOCK.items():
        r = res[f'stock label {w}x{h}']
        got = reg(r, 'd0') if ok(r, 5000) else 'no return'
        if got != want:
            errors.append(f'the stock label code of {w} x {h}: {got}, not {want} (0x61101381 changed)')
    for (c, k, w, h), want in CROPPL_QUALITY.items():
        r = res[f'quality {c} {k} {w}x{h}']
        got = reg(r, 'd0') if ok(r, 5000) else 'no return'
        if got != want:
            errors.append(f'the stock record mode of class {c}, {w} x {h}: {got}, not {want} (0x60c7c18a changed)')
    for (w, h), want in CROPPL_KIND.items():
        r = res[f'kind {w}x{h}']
        if not ok(r, 2000):
            errors.append(f'cr_pbk1 {w} x {h}: did not reach 0x61113424')
            continue
        got = bytes.fromhex(r['mem'][0])[0]
        regs = (reg(r, 'd0'), reg(r, 'd1'), reg(r, 'd2'), reg(r, 'a0'))
        if got != want or regs != (4, 0x11, 0x12345678, 78):
            errors.append(f'cr_pbk1 {w} x {h}: kind {got} (not {want}), d0 d1 d2 a0 {[hex(x) for x in regs]}')
    ent = sym.get('cr_ent', 0)
    for (g, k, pic), want in CROPPL_PICTURE.items():
        r = res[f'picture {g} {k} {pic}']
        if not ok(r, 50000):
            errors.append(f'picture {pic} (GUI class {g}, kind {k}): the getter did not return')
            continue
        a0 = reg(r, 'a0')
        ours = (a0 - ent) // 4 if ent <= a0 < ent + 36 and (a0 - ent) % 4 == 0 else None
        if ours != want:
            errors.append(f'picture {pic} (GUI class {g}, kind {k}): {f"ours {ours}" if ours is not None else f"{a0:#x}"}, '
                          f'not {f"ours {want}" if want is not None else "the stock one"}')
    return CROPPL, errors


def run_cropq(emu, build, out, card0):
    """0x60c7c18a for CROPQ_NOTE (result and note), cr_pqg for CROPQ_GUI, 0x6110130d for CROPQ_PICTURE."""
    d = out / CROPQ
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    word = lambda v: v.to_bytes(4, 'little').hex()
    half = lambda v: v.to_bytes(2, 'little').hex()
    note = [[f"{sym.get(n, 0):#x}", s] for n, s in (('cr_pqm', 4), ('cr_pqw', 2), ('cr_pqh', 2))]
    spec = []
    for (c, k, w, h), _ in CROPQ_NOTE.items():
        spec.append({'name': f'lookup {c} {k} {w}x{h}', 'pc': 'B', 'stop': ['B+7'], 'max': 5000,
                     'mem': [['B', 'dd'], ['B+1', '=0x60c7c18a-B'], ['B+5', 'f014'], ['SP+4', word(w)], ['SP+8', word(h)],
                             [note[0][0], word(0)]],
                     'regs': {'d0': '1', 'd1': str(c), 'a1': str(k)}, 'read': [[a, s] for a, s in note]})
    for (mode, w, h, m, nw, nh), _ in CROPQ_GUI.items():
        spec.append({'name': f'gui {mode} {w}x{h} {m} {nw}x{nh}', 'pc': 'B', 'stop': ['0x611133d5'], 'max': 2000,
                     'mem': [['B', 'dc'], ['B+1', f"={sym.get('cr_pqg', 0):#x}-B"], ['SP+1012', word(5)],
                             ['SP+1016', word(mode)], ['SP+872', half(w) + half(h)],
                             [note[0][0], word(m)], [note[1][0], half(nw)], [note[2][0], half(nh)]]})
    for (ft, mode), _ in CROPQ_PICTURE.items():
        spec.append({'name': f'picture {ft} {mode}', 'pc': 'B', 'stop': ['B+7'], 'max': 50000,
                     'mem': [['B', 'dd'], ['B+1', '=0x6110130d-B'], ['B+5', 'e020']], 'regs': {'d0': str(ft), 'd1': str(mode)}})
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return CROPQ, [res]
    errors = []
    reg = lambda r, k: int(r['regs'][k], 16)
    for (c, k, w, h), (want, wnote) in CROPQ_NOTE.items():
        r = res[f'lookup {c} {k} {w}x{h}']
        if r['steps'] >= 5000:
            errors.append(f'0x60c7c18a class {c}, {w} x {h}: did not return')
            continue
        got = reg(r, 'd0')
        m = int.from_bytes(bytes.fromhex(r['mem'][0]), 'little')
        nw, nh = (int.from_bytes(bytes.fromhex(r['mem'][i]), 'little') for i in (1, 2))
        if got != want:
            errors.append(f'0x60c7c18a class {c}, compression {k}, {w} x {h}: {got}, not the stock {want}')
        if m != wnote or (wnote and (nw, nh) != (w, h)):
            errors.append(f'0x60c7c18a class {c}, compression {k}, {w} x {h}: noted {m} for {nw} x {nh}, not {wnote}')
    for (mode, w, h, m, nw, nh), want in CROPQ_GUI.items():
        r = res[f'gui {mode} {w}x{h} {m} {nw}x{nh}']
        got = (reg(r, 'd0'), reg(r, 'd1')) if r['steps'] < 2000 else 'no return'
        if got != (5, want):
            errors.append(f'cr_pqg: mode {mode}, {w} x {h}, noted {m} for {nw} x {nh}: d0 / d1 {got}, not (5, {want})')
    for (ft, mode), want in CROPQ_PICTURE.items():
        r = res[f'picture {ft} {mode}']
        got = reg(r, 'd0') if r['steps'] < 50000 else 'no return'
        if got != want:
            errors.append(f'0x6110130d file type {ft}, record mode {mode}: {got}, not {want}')
    return CROPQ, errors


def run_dial(emu, build, out, card0):
    """The RGB page open: one rear-dial event carrying several clicks (a fast turn on the camera) moves the selected
    value by all of them, clamped to -7..+7. om-emu's dial tokens send one click an event, so the test calls cv_ev."""
    d = out / DIAL
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    def call(name, clicks):
        return {'name': name, 'pc': hex(sym['cv_ev']), 'stop': [hex(sym['pm_ev'])], 'max': 200000,
                'regs': {'d0': hex(REAR_DIAL), 'a1': str(clicks)},
                'read': [[hex(sym['cv_k']), 4], [hex(sym['cv_c']), 2], [hex(sym['cv_ram'] + CV_LIVE), CV_SLOTS]]}
    res = run_ncall(emu, build, d, card0, f's1 wait wait {OPEN_RGB} ncall', [call(n, c) for n, c in DIAL_CASES])
    if isinstance(res, str):
        return DIAL, [res]
    def value(o):
        k, (c, p) = int.from_bytes(bytes.fromhex(o['mem'][0]), 'little'), bytes.fromhex(o['mem'][1])
        b = bytes.fromhex(o['mem'][2])[CV_ESZ * k + 6 * c + (p + 1 if p else 0)]
        return b - 256 if b > 127 else b
    errors, v = [], value(res[DIAL_CASES[0][0]])
    for name, clicks in DIAL_CASES[1:]:
        v = max(-7, min(7, v - clicks))     # the rear dial: a1 < 0 raises the value
        got = value(res[name])
        if got != v:
            errors.append(f'{name}: the value is {got}, {clicks} clicks from the last should give {v} (out.json)')
    return DIAL, errors


def engine_job(sym):
    """-> (the fake COLOR job's memory, its tables' read, cv_ram's live[0] address, a look's calls(name, look, mem))"""
    # The fake COLOR still of research/splittone/probe_test.py: at B the calls (stage, then tone), context C at B+0x200
    # (C+4 request R at B+0x400, C+12 output O at B+0x1000, C+48 11), R+8 its id with key 11 (COLOR), R+14 0x1000.
    job = [['B', 'dd'], ['B+1', f'={RGB_STAGE:#x}-B'], ['B+5', 'f010'],
           ['B+7', 'dd'], ['B+8', f'={sym["tone"]:#x}-(B+7)'], ['B+12', 'f038'],
           ['B+0x200', '00' * 0x100], ['B+0x400', '00' * 0x800], ['B+0x1000', '00' * 0x1000],
           ['B+0x204', '=B+0x400'], ['B+0x20c', '=B+0x1000'], ['B+0x230', '=11'],
           ['B+0x408', '00000b00'], ['B+0x40e', '0010'], ['B+0x400+1660', '40143018' * 2]]
    tables = ['B+0x1000+1252', 3 * TABLE_BYTES]
    live0 = f'{sym["cv_ram"] + CV_LIVE:#x}'
    def calls(name, look, extra=()):
        slot, balance, curves = look
        cv = bytes(v & 255 for ch in curves for v in ch) + bytes(CV_SLOTS - 18)
        mem = job + [['P+87', slot.hex()], ['P+65', f'{balance & 255:02x}'], [live0, cv.hex()], *extra]
        base = {'pc': 'B', 'regs': {'a0': 'B+0x200', 'd3': 'B+0x200'}, 'max': 5000000, 'mem': mem, 'read': [tables]}
        return [{**base, 'name': name + ':stage', 'stop': ['B+7']},
                {**base, 'name': name, 'stop': [hex(TONE_NEXT)], 'read': [tables, [f'{sym["st_k"]:#x}', 36]]}]
    return job, tables, live0, calls


u16s = lambda h: list(struct.unpack(f'<{len(h) // 4}H', bytes.fromhex(h)))


def run_engine(emu, build, out, card0):
    """The look engine in om-emu, called on a fake COLOR job: the camera's RGB stage, then our tone hook (st_run).
    The tables must match look_model, and sd_crc zlib's CRC-32."""
    d = out / ENGINE
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    job, tables, live0, calls = engine_job(sym)
    spec = [c for name, look in ENGINE_CASES.items() for c in calls(name, look)]
    spec.append({'name': 'reset', 'pc': 'B', 'stop': ['B'], 'max': 1,
                 'mem': [['P+87', '00000000'], ['P+65', '00'], [live0, bytes(CV_SLOTS).hex()]]})
    crc_data = bytes((i * 151 + 7) & 255 for i in range(CRC_BYTES))
    for n in (1, 5, CRC_BYTES):
        spec.append({'name': f'crc{n}', 'pc': 'B', 'stop': ['B+7'], 'max': 1000000,
                     'mem': [['B', 'dd'], ['B+1', f'={sym["sd_crc"]:#x}-B'], ['B+5', 'c00c'], ['B+0x100', crc_data.hex()]],
                     'regs': {'d0': '0xffffffff', 'd1': str(n), 'a0': 'B+0x100'}})
    res = run_ncall(emu, build, d, card0, 's1 ncall', spec)
    if isinstance(res, str):
        return ENGINE, [res]
    errors = []
    for name, (slot, balance, curves) in ENGINE_CASES.items():
        before, after = u16s(res[name + ':stage']['mem'][0]), u16s(res[name]['mem'][0])
        st_k = [b - 256 if b > 127 else b for b in bytes.fromhex(res[name]['mem'][1])]
        k = [[st_k[3 * col + ch] * tone_strength(code - 256 if code > 127 else code) if col < 12 else 0
              for ch in range(3)] for col, code in (slot[0:2], slot[2:4])]
        want = look_model(before[:TABLE_ENTRIES], *k, balance, curves)
        if after != want:
            bad = next(i for i in range(len(want)) if after[i] != want[i])
            errors.append(f'{name}: table entry {bad} is {after[bad]}, the model says {want[bad]} (out.json)')
    for n in (1, 5, CRC_BYTES):
        got, want = int(res[f'crc{n}']['regs']['d0'], 16), zlib.crc32(crc_data[:n]) ^ 0xffffffff
        if got != want:
            errors.append(f'sd_crc over {n} bytes: {got:08x}, CRC-32 {want:08x}')
    return ENGINE, errors


def run_video(emu, build, out, card0):
    """#68: a photo pass of a look with split toning and curves, then a video pass of it (rc_in pointing at a mode
    block with code 10). The video pass must leave the RGB stage's tables unchanged."""
    d = out / VIDEO
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    calls = engine_job(sym)[3]
    look = ENGINE_CASES[VIDEO_CASE]
    # the mode block in the free gap between context C (B+0x200, 0x100 B) and request R (B+0x400)
    mode = lambda code: [[f'{sym["rc_in"]:#x}', '=B+0x300'], ['B+0x300', '00' * 32], ['B+0x300+24', f'{code:02x}']]
    res = run_ncall(emu, build, d, card0, 's1 ncall',
                    calls('photo', look, mode(PHOTO_MODE)) + calls('video', look, mode(VIDEO_MODE)))
    if isinstance(res, str):
        return VIDEO, [res]
    errors = []
    before, after = u16s(res['video:stage']['mem'][0]), u16s(res['video']['mem'][0])
    if u16s(res['photo']['mem'][0]) == u16s(res['photo:stage']['mem'][0]):
        errors.append('the photo pass left the tables unchanged: the look did not run (out.json)')
    if after != before:
        bad = next(i for i in range(len(before)) if after[i] != before[i])
        errors.append(f'video: table entry {bad} is {after[bad]}, the camera wrote {before[bad]} (out.json)')
    return VIDEO, errors


def run_gates(emu, build, out, card0):
    """The three live-view gates, called at their hook sites: before section 6 is ready the stock path (and d0 = 11 at
    lv_skip, as the stock arrives there), once it is ready our code (mx_go, tone, s_lv6)."""
    d = out / GATES
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    word = lambda v: [f'{SEC_READY:#x}', v.to_bytes(4, 'little').hex()]
    sites = {   # name: (pc, regs, mem, stock stop, our stop)
        'mx': (MX_SITE, {'a0': 'B', 'd2': 'B', 'a1': 'B+0x40', 'a2': 'B+0x40'}, [], MX_ROW, sym['mx_go']),
        'tone': (TONE_SITE, {'d3': 'B'}, [], TONE_NEXT, sym['tone']),
        'lv': (LV_SITE, {'d2': '0', 'a3': 'B', 'a0': 'B+0x200'}, [['B', '00' * 0x200], ['B+0x200', '0b']], LV_SKIP,
               sym['s_lv6']),
    }
    spec = []
    for name, (pc, regs, mem, stock, ours) in sites.items():
        for case, v in (('not-ready', SEC_NOT6), ('ready', SEC_WITH6)):
            spec.append({'name': f'{name}:{case}', 'pc': hex(pc), 'regs': regs, 'mem': [*mem, word(v)],
                         'stop': [hex(stock), hex(ours), hex(LV_X)], 'max': 200, 'restore': [word(SEC_OMEMU)]})
    res = run_ncall(emu, build, d, card0, 'ncall', spec)
    if isinstance(res, str):
        return GATES, [res]
    errors = []
    for name, (pc, regs, mem, stock, ours) in sites.items():
        for case, want in (('not-ready', stock), ('ready', ours)):
            o = res[f'{name}:{case}']
            got = int(o['regs']['pc'], 16)
            if got != want:
                errors.append(f'{name}, section 6 {case.replace("-", " ")}: reached {got:#x}, not {want:#x} '
                              f'({"the stock code" if want == stock else "our code"}) (out.json)')
            elif name == 'lv' and case == 'not-ready' and int(o['regs']['d0'], 16) != 11:
                errors.append(f'lv, section 6 not ready: d0 {o["regs"]["d0"]} at lv_skip, the stock path has 11')
    return GATES, errors


WB_KEYS = {'A-B': 34041, 'G-M': 38521}           # wb_get's reads, shifted by slot +26 and +27
CALL_REGS_D2_D3 = 0xc0                           # a call's register list [d2,d3]


def call_spec(name, fn, imm, d0, mem=(), count=()):
    """An ncall of `call fn,[d2,d3],imm` at B with d0, d1 0, a0 0 (a getter call's registers), stopped after it.
    count: addresses, each one's hits during the call in the result's count."""
    stub = [['B', 'dd'], ['B+1', f'={fn:#x}-B'], ['B+5', f'{CALL_REGS_D2_D3:02x}{imm:02x}']]
    return {'name': name, 'pc': 'B', 'stop': ['B+7'], 'max': 200000, 'mem': stub + list(mem),
            'regs': {'d0': str(d0), 'd1': '0', 'a0': '0'}, 'count': list(count)}


s8 = lambda v: v - 256 if v > 127 else v
# wb_get adds the active COLOR's slot +26 (A-B) or +27 (G-M) to the stock read when its +25 & 0x81 == 1, clamped to
# -7..7. Each case: slot +25..+27 for COLOR 1..4. The test camera is on COLOR 1.
WB_CASES = [('none', [(0, 0, 0)] * 4),
            ('color-1', [(1, 3, 0xfe), (0, 0, 0), (0, 0, 0), (0, 0, 0)]),
            ('color-1-off', [(0x81, 3, 0xfe), (0, 0, 0), (0, 0, 0), (0, 0, 0)]),
            ('color-2-only', [(0, 0, 0), (1, 5, 5), (0, 0, 0), (0, 0, 0)])]
WB = 'wb-shift-reads-follow-the-look'


def run_wb(emu, build, out, card0):
    """wb_get on each WB_KEYS read, per WB_CASES look: the stock value, plus the shift when COLOR 1 (active) has one.
    With no slot's shift on, the stock read is wb_get's only getter call."""
    d = out / WB
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    spec = [call_spec('mode', sym['getter'], 12, 63153)]
    spec += [call_spec(f'stock:{k}', sym['getter'], 12, key) for k, key in WB_KEYS.items()]
    for name, slots in WB_CASES:
        mem = [[f'P+{32 + 64 * k + 25}', bytes(s).hex()] for k, s in enumerate(slots)]
        spec += [call_spec(f'{name}:{k}', sym['wb_get'], 12, key, mem, [sym['getter']]) for k, key in WB_KEYS.items()]
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return WB, [res]
    if int(res['mode']['regs']['d0'], 16) & 255 != 1:
        return WB, [f"the camera is not on COLOR 1 (getter 63153: {res['mode']['regs']['d0']}, out.json)"]
    errors = []
    for name, slots in WB_CASES:
        flag, ab, gm = slots[0]
        for i, k in enumerate(WB_KEYS):
            stock = s8(int(res[f'stock:{k}']['regs']['d0'], 16) & 255)
            want = max(-7, min(7, stock + s8((ab, gm)[i]))) if flag & 0x81 == 1 else stock
            got = s8(int(res[f'{name}:{k}']['regs']['d0'], 16) & 255)
            if got != want:
                errors.append(f'{name} {k}: wb_get gives {got}, want {want} (out.json)')
            calls, shift = res[f'{name}:{k}']['count'][0], any(f & 0x81 == 1 for f, _, _ in slots)
            if (calls > 1) != shift:
                errors.append(f'{name} {k}: wb_get calls the getter {calls} times, want {"more than " if shift else ""}1 (out.json)')
    return WB, errors


# hl_pp's per-hue Hue / Lightness (slot +0..+23, -7..7, on when +31 & 2) into the COLOR stage's 12 output records,
# entered at hl_pp_cb, after its color_builder call, on a fake context C at B+0x200, output O at B+0x1000.
# Keep HL_HUE, HL_LIGHT and HL_PERM in sync with hl_lut in firmware/src/editor.s.
HL = 'hue-lightness-follows-the-look'
HL_HUE = [7000 - 1000 * i for i in range(15)]
HL_LIGHT = [-300, -250, -200, -150, -100, -50, -25, 0, 25, 50, 100, 150, 200, 250, 300]
HL_PERM = [0, 2, 4, 6, 8, 10, 1, 3, 5, 7, 9, 11]
HL_REC, HL_REC_STEP, HL_FILL = 854, 24, 0x55     # O + 854: record 0's hue field, then lightness at +4
HL_LOOK = [(3 * i) % 15 - 7 for i in range(12)] + [7 - (2 * i) % 15 for i in range(12)]
HL_CASES = [('none', None), ('color-1', 0), ('color-2-only', 1)]


def run_hl(emu, build, out, card0):
    """hl_pp per HL_CASES (the H/L look on no slot, on COLOR 1 (active), on COLOR 2): the records get the look's LUT
    values only when COLOR 1 has it, else stay as they were. With no slot's H/L on, hl_pp calls no getter."""
    d = out / HL
    d.mkdir(parents=True, exist_ok=True)
    sym = elf_symbols(build / 'p.elf')
    span = HL_REC_STEP * 12
    look = bytes(v & 255 for v in HL_LOOK)
    spec = [call_spec('mode', sym['getter'], 12, 63153)]
    for name, slot in HL_CASES:
        mem = [['B+0x200', '00' * 0x100], ['B+0x20c', '=B+0x1000'], [f'B+0x1000+{HL_REC}', f'{HL_FILL:02x}' * span]]
        for k in range(4):
            mem += [[f'P+{32 + 64 * k}', (look if k == slot else bytes(24)).hex()],
                    [f'P+{32 + 64 * k + 31}', '02' if k == slot else '00']]
        spec.append({'name': name, 'pc': f'{sym["hl_pp_cb"]:#x}', 'stop': [hex(sym['color_resume'])],
                     'max': 200000, 'mem': mem, 'regs': {'a2': 'B+0x200'}, 'read': [[f'B+0x1000+{HL_REC}', span]],
                     'count': [sym['getter']]})
    res = run_ncall(emu, build, d, card0, 's1 wait wait ncall', spec)
    if isinstance(res, str):
        return HL, [res]
    if int(res['mode']['regs']['d0'], 16) & 255 != 1:
        return HL, [f"the camera is not on COLOR 1 (getter 63153: {res['mode']['regs']['d0']}, out.json)"]
    errors = []
    for name, slot in HL_CASES:
        want = bytearray([HL_FILL] * span)
        if slot == 0:
            for r, w in enumerate(HL_PERM):
                struct.pack_into('<H', want, HL_REC_STEP * r, HL_HUE[HL_LOOK[w] + 7] & 0xffff)
                struct.pack_into('<H', want, HL_REC_STEP * r + 4, HL_LIGHT[HL_LOOK[12 + w] + 7] & 0xffff)
        got = bytes.fromhex(res[name]['mem'][0])
        if res[name]['regs']['pc'] != f"{sym['color_resume']:x}":
            errors.append(f'{name}: hl_pp did not reach color_resume (out.json)')
        elif got != want:
            bad = next(i for i in range(span) if got[i] != want[i])
            errors.append(f'{name}: output byte {HL_REC + bad} is {got[bad]:02x}, want {want[bad]:02x} (out.json)')
        calls = res[name]['count'][0]
        if calls != (slot is not None):
            errors.append(f'{name}: hl_pp calls the getter {calls} times, want {int(slot is not None)} (out.json)')
    return HL, errors


# Tests that call our code directly through run_ncall: name -> runner(emu, build, out, card0).
DIRECT = {WB: run_wb, HL: run_hl}


def newest_looks():
    def key(d):
        n, _, pre = d.name.lstrip('v').partition('-')
        return [int(x) for x in n.split('.')], pre == '', pre
    rel = max((d for d in (REPO / 'releases').iterdir() if d.name.startswith('v') and (d / 'LOOKS.BIN').exists()), key=key)
    return rel / 'LOOKS.BIN'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('build', type=pathlib.Path)
    ap.add_argument('--only', nargs='+', choices=sorted([*TESTS, AUDIT, HALATION, BORDER, ENGINE, DIAL, VIDEO, GRAINMIX, CROPHIST, CROPPL, CROPQ, GATES, *DIRECT, *STATIC]))
    ap.add_argument('--jobs', type=lambda v: max(1, int(v)), default=DEFAULT_JOBS)
    ap.add_argument('--out', type=pathlib.Path)
    ap.add_argument('--looks', type=pathlib.Path)
    ap.add_argument('--repeat', type=lambda v: max(1, int(v)), default=1, help='runs per test, each in its own subfolder')
    ap.add_argument('--stock', help='official firmware file, for the static:* tests')
    ap.add_argument('--without', type=pathlib.Path, help='build without the fix: the --only tests must FAIL on it')
    a = ap.parse_args()
    if a.without and not a.only:
        sys.exit('--without needs --only: name the tests that must catch the bug')
    emu = os.environ.get('OM3_EMU')
    if not emu or not pathlib.Path(emu, 'bin/card.mjs').exists():
        sys.exit('OM3_EMU is not set to an om-emu emu/ folder: run research/setup.sh, then . $OM3_WORK/env.sh')
    check_emu_pin(emu)
    build = (a.without or a.build).resolve()
    if not (build / 'main.bin').exists():
        sys.exit(f'{build}: no main.bin (a firmware/build.py --out folder)')
    out = (a.out or pathlib.Path(tempfile.mkdtemp(prefix='emu-test-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    card0 = out / 'card0.omsd'
    looks = (a.looks or newest_looks()).resolve()
    make_card(emu, build, looks, card0)
    fixtures = make_fixtures(out, looks)
    names = a.only or sorted([*TESTS, AUDIT, HALATION, BORDER, ENGINE, DIAL, VIDEO, GRAINMIX, CROPHIST, CROPPL, CROPQ, GATES, *DIRECT, *STATIC])
    stock = static_check.find_stock(a.stock) if any(n in STATIC for n in names) else None
    runs = [(n, k) for n in names for k in range(1, a.repeat + 1)]
    print(f'{len(names)} tests{f" x {a.repeat}" if a.repeat > 1 else ""} on {build}, results in {out}')
    def run_dir(k):
        return out / f'run{k}' if a.repeat > 1 else out
    # A first boot that two or more tests share runs once per run folder, and each of those tests starts from its result.
    uses = {}
    for n, k in runs:
        if n in TESTS:
            uses.setdefault((k, boot_key(TESTS[n][0])), []).append(n)
    shared_keys = [key for key, ns in uses.items() if len(ns) > 1]
    shared = {}
    def one(run):
        n, k = run
        d = run_dir(k)
        try:
            if n in STATIC:
                return n, static_check.CHECKS[n[len(STATIC_PREFIX):]](build, stock)
            if n == AUDIT:
                return run_audit(emu, build, d)
            if n == HALATION:
                return run_halation(emu, build, d, card0)
            if n == BORDER:
                return run_border(emu, build, d, card0)
            if n == ENGINE:
                return run_engine(emu, build, d, card0)
            if n == DIAL:
                return run_dial(emu, build, d, card0)
            if n == VIDEO:
                return run_video(emu, build, d, card0)
            if n == GRAINMIX:
                return run_grainmix(emu, build, d, card0)
            if n == CROPHIST:
                return run_crophist(emu, build, d, card0)
            if n == CROPPL:
                return run_croppl(emu, build, d, card0)
            if n == CROPQ:
                return run_cropq(emu, build, d, card0)
            if n == GATES:
                return run_gates(emu, build, d, card0)
            if n in DIRECT:
                return DIRECT[n](emu, build, d, card0)
            first = shared.get((k, boot_key(TESTS[n][0])))
            return run_test(n, TESTS[n], emu, build, card0, d, first and first.result(), fixtures)
        except static_check.Skip as e:
            return n, [f'could not run: {e}']
        except RUNNER_ERRORS as e:
            return n, [f'runner error: {e}']
    with concurrent.futures.ThreadPoolExecutor(a.jobs) as pool:
        # Shared boots go in first: the pool starts them before any test that waits on one.
        shared.update((key, pool.submit(run_shared, emu, build, run_dir(key[0]) / 'shared' / str(i),
                                        TESTS[uses[key][0]][0], card0, fixtures)) for i, key in enumerate(shared_keys))
        done = list(pool.map(one, runs))
    results = {n: [] for n in names}
    for (n, k), (_, errors) in zip(runs, done):
        results[n] += [f'run {k}: {e}' if a.repeat > 1 else e for e in errors]
    failed = 0
    for name, errors in results.items():
        if a.without:
            print(f'{"caught" if errors else "MISSED":<7}{name}')
            for e in errors or ['passed on the build without the fix: the test does not catch the bug']:
                print(f'      {e}')
            failed += not errors
            continue
        known = KNOWN_FAILURES.get(name)
        print(f'{"pass" if not errors else "known" if known else "FAIL":<6}{name}')
        for e in errors:
            print(f'      {e}')
        if known:
            print(f'      {known}' if errors else '      listed in KNOWN_FAILURES but passed: remove it')
        failed += bool(errors) and not known
    (out / 'results.json').write_text(json.dumps(results, indent=1))
    if not a.only and not a.without:
        if failed:
            p = pass_path()
            if p:
                p.unlink(missing_ok=True)
        else:
            record_pass(build)
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
