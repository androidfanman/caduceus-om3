"""raw.py in SRC.jpg OUT.rgba WIDTH  -> RGBA bytes + OUT.rgba.json {w,h};  raw.py out IN.rgba OUT.jpg  -> JPEG"""
import json, sys
from PIL import Image
if sys.argv[1] == 'crop':                      # raw.py crop SRC.jpg OUT.rgba X Y W H  (full resolution)
    src, out = sys.argv[2], sys.argv[3]; x, y, w, h = map(int, sys.argv[4:8])
    im = Image.open(src).convert('RGB').crop((x, y, x + w, y + h)).convert('RGBA')
    open(out, 'wb').write(im.tobytes()); json.dump({'w': w, 'h': h}, open(out + '.json', 'w'))
elif sys.argv[1] == 'in':
    src, out, W = sys.argv[2], sys.argv[3], int(sys.argv[4])
    im = Image.open(src).convert('RGB'); H = round(im.height * W / im.width)
    im = im.resize((W, H), Image.LANCZOS).convert('RGBA')
    open(out, 'wb').write(im.tobytes()); json.dump({'w': W, 'h': H}, open(out + '.json', 'w'))
else:
    src, out = sys.argv[2], sys.argv[3]
    d = json.load(open(src + '.json'))
    Image.frombytes('RGBA', (d['w'], d['h']), open(src, 'rb').read()).convert('RGB').save(out, quality=80, optimize=True, progressive=True)
