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
ENGINE = 'look-tables-match-the-model'
DIAL = 'rgb-page-counts-every-click'
# #68: our looks are for photos only. A video pass after a photo pass, the same look (split toning and curves), must
# leave the camera's tables as they are (st_run: mx_photo 0). v0.30.3 kept split toning and the photo's curves.
VIDEO = 'video-keeps-the-stock-tables'
VIDEO_CASE = 'split-toning-and-curves'
VIDEO_MODE = 0x0a                                # the mode code of video and S&Q (rc_in + 24, ss_photo)
PHOTO_MODE = 0x01                                # P's mode code, so the photo pass does not rest on the snapshot's mode
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

@dataclass
class Boot:
    tokens: str
    expect: list = field(default_factory=list)     # regexes, each must match a debug log line
    reject: list = field(default_factory=list)     # regexes no debug log line may match
    mode_dial: int = MODE_DIAL_P
    photo_switch: int = PHOTO_SWITCH_PHOTO    # None leaves PSET0 unset: the movie switch
    card: dict = field(default_factory=dict)   # OM3MOD file name -> a FIXTURES key put on the card before this boot,
                                               # or None to remove the file

# v0.30 test 9: CURVES.BIN (each film's built-in curves and mix, docs/FORMATS.md), made from the newest release's
# LOOKS.BIN. Film 1 (COLOR 1, look 2: PICK_FILM_2) gets values; B changes them; BAD has a wrong CRC.
FIXTURES = {
    'CURVES_A': lambda looks, names: mkcurves.build(looks, {names[1]: {'r': [1, 0, 0, 0, -1], 'mix': [1, 2, 0, 0, 0, 0]}}),
    'CURVES_B': lambda looks, names: mkcurves.build(looks, {names[1]: {'g': [0, 2, 0, 0, 0], 'mix': [0, 0, 0, 0, -1, 3]}}),
    'CURVES_BAD': lambda looks, names: (lambda b: b[:40] + bytes([b[40] ^ 1]) + b[41:])(FIXTURES['CURVES_A'](looks, names)),
}
# From the shooting screen: the RGB row (the third in Picture Mode), the rear dial once on Red's first point, out.
OPEN_RGB = 'ok wait ok wait down wait down wait'
EDIT_RGB = f'{OPEN_RGB} main+1 wait menu wait wait'


CK_WORDS = ['none', 'none (its film has some)', "its film's", 'changed']   # has values x 2 + differs from the built-in


def ck_line(mem, card, matches, on_builtin, with_values):
    """CADLOG's CURVES.BIN lines (debug log dl9, v0.30 test 10: START-UP's file line and NOW's line per COLOR):
    on_builtin / with_values are bit masks, bit k-1 for COLOR k."""
    words = [CK_WORDS[2 * (with_values >> k & 1) + (1 - (on_builtin >> k & 1))] for k in range(4)]
    return [rf"^CURVES\.BIN \(each film's built-in curves and mix\): in camera memory: {mem}; this power-on's card: {card}; "
            rf"films it matches: {matches}$",
            '^Curves / mix on COLOR 1-4: ' + re.escape(', '.join(words)) + '$']


# ISO Auto key (feature/iso-auto-key): Delete stands for a button set to the function. om-emu's Delete has no
# function and reads as Off (3200), so the test writes 3200 into ia_code: the state "this button's function is ISO
# Auto". Each press is followed by a half-press, whose log line shows the ISO setting: Auto at first, then the
# default manual value (ISO 200), Auto again, and the manual value again. One switch per press: two presses in a row
# end where they started, and five presses make five switches (ia_n).
ISO_AUTO_KEY = ('s1 wait wait poke:{ia_code}=800c delete wait s1 wait wait delete wait s1 wait wait '
                'delete wait s1 wait wait delete delete wait expect:mem:{ia_n}=05 s1 wait wait poweroff')
# The ISO Auto key's own Button Function entry, with no poke: Menu > Button Settings > Button Function, down to the
# Delete row (the 11th), its choice screen opens on Off (the last of 51), ISO Auto is one to the left; OK, back out to
# the shooting screen. A Delete press then switches the ISO, and the next one switches it back.
ISO_AUTO_FROM_MENU = ('s1 wait wait menu wait left left left left left wait ok wait ok wait '
                      'down down down down down down down down down down wait ok wait left wait ok wait '
                      'menu wait menu wait menu wait s1 wait wait delete wait s1 wait wait delete wait s1 wait wait '
                      'expect:mem:{ia_n}=02 poweroff')
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
    'iso-auto-key-switches-auto-and-manual': [
        Boot(ISO_AUTO_KEY, expect=[r'^#1 .* ISO Auto ', r'^#3 .* ISO 200 ', r'^#5 .* ISO Auto ', r'^#7 .* ISO 200 ',
                                   r'^#9 .* ISO 200 ']),
    ],
    'iso-auto-key-from-the-button-function-menu': [
        Boot(ISO_AUTO_FROM_MENU, expect=[r'^#3 .* ISO Auto ', r'^#5 .* ISO 200 ', r'^#7 .* ISO Auto ']),
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
    'grid-row-gives-the-bottom-bar-back': [
        Boot(GRID_ROW_AND_BACK),
    ],
    'debug-log-written-at-releases-only': [
        Boot('s1 wait wait s1 wait wait s1 wait wait poweroff', expect=[DEBUG_LOG_RELEASES_ONLY]),
    ],
    'noise-filter-row-follows-the-camera-setting': [
        Boot(NOISE_FILTER_OFF_ROW),
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
    return boot.tokens, boot.mode_dial, boot.photo_switch, tuple(sorted(boot.card.items()))


def run_boot(emu, build, d, i, boot, card, syms, fixtures=None):
    """Boot i in d, from card, with d/nv.bin as the camera's settings -> (next card, log lines or None, errors, a
    fatal error or None). syms caches the build's symbols for tokens that name them."""
    nxt = d / f'card{i}.omsd'
    if boot.card:
        card = put_card_files(emu, card, boot.card, fixtures, d / f'card{i}-in.omsd')
    tokens = boot.tokens
    if '{' in tokens:
        if not syms:
            syms.update({k: f'{v:x}' for k, v in elf_symbols(build / 'p.elf').items()})
        tokens = tokens.format_map(syms)
    env = {**os.environ, 'OM_EMU_MODEL': MODEL, 'NV_FILE': str(d / 'nv.bin'), 'MODE0': str(boot.mode_dial),
           'PSET0': str(boot.photo_switch)}
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
    return nxt, read_log(emu, nxt, d / f'cadlog{i}.txt'), errors, None


def check_log(i, boot, lines):
    """boot i's expect and reject against its log lines -> errors, and whether the test must stop."""
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


def newest_looks():
    def key(d):
        n, _, pre = d.name.lstrip('v').partition('-')
        return [int(x) for x in n.split('.')], pre == '', pre
    rel = max((d for d in (REPO / 'releases').iterdir() if d.name.startswith('v') and (d / 'LOOKS.BIN').exists()), key=key)
    return rel / 'LOOKS.BIN'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('build', type=pathlib.Path)
    ap.add_argument('--only', nargs='+', choices=sorted([*TESTS, AUDIT, HALATION, ENGINE, DIAL, VIDEO, *STATIC]))
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
    names = a.only or sorted([*TESTS, AUDIT, HALATION, ENGINE, DIAL, VIDEO, *STATIC])
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
            if n == ENGINE:
                return run_engine(emu, build, d, card0)
            if n == DIAL:
                return run_dial(emu, build, d, card0)
            if n == VIDEO:
                return run_video(emu, build, d, card0)
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
