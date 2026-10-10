"""Draws the Lagotto theme's illustrations into assets/lagotto/.

Run from the repo root: python3 tools/theme_art/lagotto_art.py

Every fluffy outline is a 'scallop': an ellipse traced as a ring of small
outward arcs, which reads as a curly coat at any size.
"""
import math

INK = '#3B2A20'
NOSE = '#2B1D16'

# Coats: fur, shade (far legs / curls), patch (ears, eye patch), muzzle
COATS = {
    'bianco': dict(fur='#FBF3E4', shade='#E9D9BE', patch='#8A5634', muzzle='#FFFAF0', curl='#D9C3A0'),
    'marrone': dict(fur='#8A5634', shade='#6E4128', patch='#5E3720', muzzle='#9C6740', curl='#5E3720'),
    'arancio': dict(fur='#E6B47A', shade='#CF9558', patch='#B9763A', muzzle='#F0C892', curl='#B9763A'),
}


def n(x):
    s = f'{x:.1f}'
    return s[:-2] if s.endswith('.0') else s


def scallop(cx, cy, rx, ry, count, k=0.6, rot=0.0):
    pts = []
    for i in range(count):
        a = math.radians(rot + 360 * i / count)
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    d = f'M{n(pts[0][0])} {n(pts[0][1])}'
    for i in range(count):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % count]
        r = math.hypot(x2 - x1, y2 - y1) * k
        d += f'A{n(r)} {n(r)} 0 0 1 {n(x2)} {n(y2)}'
    return d + 'Z'


def blob(cx, cy, rx, ry, count, fill, sw=2.2, k=0.6, rot=0.0, stroke=INK, extra=''):
    return (f'<path d="{scallop(cx, cy, rx, ry, count, k, rot)}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}" stroke-linejoin="round"{extra}></path>')


def curls(points, color, sw=1.5):
    d = ''
    for x, y, s in points:
        d += f'M{n(x)} {n(y)}a{n(s)} {n(s)} 0 1 1 {n(s * 1.3)} {n(s * 0.5)}'
    return f'<path d="{d}" stroke="{color}" stroke-width="{sw}" fill="none" stroke-linecap="round"></path>'


def eye(x, y, r=2.6):
    return (f'<circle cx="{n(x)}" cy="{n(y)}" r="{n(r)}" fill="{NOSE}"></circle>'
            f'<circle cx="{n(x + r * 0.35)}" cy="{n(y - r * 0.35)}" r="{n(r * 0.36)}" fill="#FFFFFF"></circle>')


def nose(x, y, rx=4.2, ry=3.5):
    return (f'<ellipse cx="{n(x)}" cy="{n(y)}" rx="{n(rx)}" ry="{n(ry)}" fill="{NOSE}"></ellipse>'
            f'<ellipse cx="{n(x - rx * 0.3)}" cy="{n(y - ry * 0.4)}" rx="{n(rx * 0.32)}" ry="{n(ry * 0.25)}" fill="#FFFFFF" opacity=".55"></ellipse>')


# ---------------------------------------------------------------- dogs

def _head_side(c, hx, hy, r, patch_eye=True, closed=False, tongue=False, ear_dx=-0.18):
    """A side head facing right, centred (hx, hy)."""
    out = ''
    out += blob(hx - r * 0.1, hy - r * 0.9, r * 0.55, r * 0.38, 8, c['fur'])          # topknot
    out += blob(hx, hy, r, r * 0.95, 12, c['fur'])                                       # skull
    out += blob(hx + r * 0.85, hy + r * 0.38, r * 0.62, r * 0.5, 9, c['muzzle'])        # muzzle
    out += blob(hx + r * 0.78, hy + r * 0.85, r * 0.4, r * 0.3, 7, c['muzzle'])         # beard
    if patch_eye:
        out += blob(hx + r * 0.42, hy - r * 0.12, r * 0.36, r * 0.33, 7, c['patch'], sw=0, stroke='none')
    if closed:
        out += (f'<path d="M{n(hx + r * 0.27)} {n(hy - r * 0.1)}q{n(r * 0.17)} {n(r * 0.16)} {n(r * 0.34)} 0" '
                f'stroke="{NOSE}" stroke-width="2.2" fill="none" stroke-linecap="round"></path>')
    else:
        out += eye(hx + r * 0.44, hy - r * 0.12, r * 0.16)
    out += nose(hx + r * 1.42, hy + r * 0.2, r * 0.25, r * 0.21)
    if tongue:
        out += (f'<path d="M{n(hx + r * 1.0)} {n(hy + r * 0.78)}q{n(r * 0.12)} {n(r * 0.42)} {n(r * 0.3)} 0" '
                f'fill="#E87A7A" stroke="{INK}" stroke-width="1.6"></path>')
    out += blob(hx + r * ear_dx, hy + r * 0.45, r * 0.46, r * 0.75, 10, c['patch'])        # ear
    out += curls([(hx - r * 0.45, hy - r * 0.35, r * 0.13), (hx + r * 0.05, hy - r * 0.55, r * 0.12)], c['curl'])
    return out


def dog_stand(coat='bianco', sniff=False, tongue=False):
    """Standing, side view facing right. viewBox 0 0 124 100."""
    c = COATS[coat]
    out = ''
    out += f'<g transform="rotate(-30 22 46)">{blob(20, 36, 6, 12, 9, c["fur"])}</g>'          # tail
    out += blob(31, 75, 7, 16, 10, c['shade'])                                                 # far hind
    out += blob(80, 75, 6.5, 16, 10, c['shade'])                                               # far fore
    out += blob(24, 76, 7.5, 16, 10, c['fur'])                                                 # near hind
    out += blob(73, 77, 7.5, 16, 10, c['fur'])                                                 # near fore
    out += blob(52, 54, 34, 19, 16, c['fur'], sw=2.4)                                          # body
    if coat == 'bianco':
        out += blob(44, 50, 12, 8, 8, c['patch'], sw=0, stroke='none')
    out += curls([(34, 52, 2.4), (52, 60, 2.4), (62, 48, 2.2), (40, 62, 2.2), (70, 58, 2)], c['curl'])
    head = _head_side(c, 88, 33, 17, patch_eye=coat == 'bianco', tongue=tongue)
    if sniff:
        head = f'<g transform="rotate(38 80 46)">{head}</g>'
    return out + head


def dog_lie(coat='bianco', closed=True):
    """Lying with the head on the paws, facing left. viewBox 0 0 140 72."""
    c = COATS[coat]
    out = ''
    out += f'<g transform="rotate(40 124 44)">{blob(124, 36, 6, 11, 9, c["fur"])}</g>'
    out += blob(80, 50, 46, 17, 18, c['fur'], sw=2.4)
    out += blob(104, 50, 17, 15, 11, c['fur'])                                                  # haunch
    if coat == 'bianco':
        out += blob(70, 44, 13, 8, 8, c['patch'], sw=0, stroke='none')
    out += curls([(60, 52, 2.4), (84, 56, 2.4), (96, 44, 2.2), (110, 52, 2.2), (48, 46, 2)], c['curl'])
    out += blob(108, 63, 13, 5, 9, c['fur'])                                                   # hind paw
    out += blob(30, 63, 15, 5.5, 10, c['fur'])                                                 # fore paws
    out += blob(42, 65, 14, 5, 10, c['fur'])
    head = _head_side(c, 0, 0, 19, patch_eye=False, closed=closed, ear_dx=-0.5)
    out += f'<g transform="translate(36 34) rotate(-8) scale(-1 1)">{head}</g>'
    return out


def dog_sit(coat='bianco', tongue=True):
    """Sitting, three-quarter side facing right. viewBox 0 0 104 112."""
    c = COATS[coat]
    out = ''
    out += f'<g transform="rotate(-70 18 96)">{blob(18, 92, 5.5, 11, 9, c["fur"])}</g>'
    out += blob(40, 82, 22, 20, 13, c['fur'], sw=2.4)                                          # haunch
    out += blob(60, 88, 6.5, 18, 10, c['shade'])                                               # far foreleg
    out += blob(52, 60, 20, 27, 14, c['fur'], sw=2.4)                                          # chest
    if coat == 'bianco':
        out += blob(38, 78, 11, 9, 8, c['patch'], sw=0, stroke='none')
    out += blob(68, 90, 7, 18, 10, c['fur'])                                                   # near foreleg
    out += blob(33, 104, 13, 5, 9, c['fur'])                                                   # hind foot
    out += curls([(44, 66, 2.4), (54, 50, 2.2), (30, 84, 2.4), (48, 92, 2.2)], c['curl'])
    out += _head_side(c, 62, 30, 18, patch_eye=coat == 'bianco', tongue=tongue)
    return out


def dog_face(coat='bianco', tongue=False):
    """Front-facing head. viewBox 0 0 64 64."""
    c = COATS[coat]
    out = ''
    out += blob(12, 37, 8.5, 14, 10, c['patch'])
    out += blob(52, 37, 8.5, 14, 10, c['patch'])
    out += blob(32, 14, 11, 6.5, 8, c['fur'])
    out += blob(32, 31, 19, 18, 14, c['fur'], sw=2.4)
    if coat == 'bianco':
        out += blob(24, 28, 6.5, 6, 7, c['patch'], sw=0, stroke='none')
    out += eye(24, 29, 3.1) + eye(40, 29, 3.1)
    out += blob(32, 42, 11, 8.5, 10, c['muzzle'])
    out += nose(32, 37.5, 4.8, 3.7)
    out += f'<path d="M27.5 44q4.5 3.4 9 0" stroke="{NOSE}" stroke-width="1.8" fill="none" stroke-linecap="round"></path>'
    if tongue:
        out += f'<path d="M30 45.5q2 5 4 0" fill="#E87A7A" stroke="{INK}" stroke-width="1.4"></path>'
    out += curls([(18, 20, 1.8), (41, 19, 1.8), (30, 9, 1.6)], c['curl'], 1.3)
    return out


def puppy(coat='arancio'):
    """Puppy standing facing right: big head, short legs. viewBox 0 0 70 56."""
    c = COATS[coat]
    out = ''
    out += f'<g transform="rotate(-35 12 28)">{blob(11, 22, 4, 7, 8, c["fur"], sw=1.8)}</g>'
    out += blob(20, 44, 5, 9, 9, c['shade'], sw=1.8)
    out += blob(42, 44, 5, 9, 9, c['shade'], sw=1.8)
    out += blob(15, 45, 5.5, 9, 9, c['fur'], sw=1.8)
    out += blob(37, 46, 5.5, 9, 9, c['fur'], sw=1.8)
    out += blob(28, 35, 19, 11, 13, c['fur'], sw=2)
    out += curls([(20, 34, 1.8), (30, 38, 1.8)], c['curl'], 1.3)
    out += f'<g transform="translate(46 21) scale(.72)">{_head_side(c, 0, 0, 17, patch_eye=coat == "bianco")}</g>'
    return out


# ---------------------------------------------------------------- props

def truffle(cx, cy, r, gold=False, sw=1.8):
    fill = 'url(#tGold)' if gold else '#4A3428'
    spot = '#F7DE9A' if gold else '#6E5242'
    out = blob(cx, cy, r, r * 0.9, 11, fill, sw=sw, k=0.56)
    out += (f'<circle cx="{n(cx - r * .35)}" cy="{n(cy - r * .2)}" r="{n(r * .14)}" fill="{spot}"></circle>'
            f'<circle cx="{n(cx + r * .25)}" cy="{n(cy + r * .25)}" r="{n(r * .12)}" fill="{spot}"></circle>'
            f'<circle cx="{n(cx + r * .3)}" cy="{n(cy - r * .35)}" r="{n(r * .1)}" fill="{spot}"></circle>')
    return out


GOLD_DEFS = ('<defs><linearGradient id="tGold" x1="0" y1="0" x2="1" y2="1">'
             '<stop offset="0" stop-color="#FBE3A0"></stop><stop offset=".55" stop-color="#E0A23A"></stop>'
             '<stop offset="1" stop-color="#9C6414"></stop></linearGradient></defs>')


def paw_path(color, x=0, y=0, s=1.0):
    t = f' transform="translate({n(x)} {n(y)}) scale({s})"' if (x or y or s != 1) else ''
    return (f'<g{t} fill="{color}">'
            '<path d="M12 22.5c-4.2 0-7.2-2.1-7.2-5.1 0-3.4 3.4-6.7 7.2-6.7s7.2 3.3 7.2 6.7c0 3-3 5.1-7.2 5.1z"></path>'
            '<ellipse cx="4.2" cy="9.6" rx="2.5" ry="3.2" transform="rotate(-20 4.2 9.6)"></ellipse>'
            '<ellipse cx="9" cy="5.2" rx="2.5" ry="3.3" transform="rotate(-6 9 5.2)"></ellipse>'
            '<ellipse cx="15" cy="5.2" rx="2.5" ry="3.3" transform="rotate(6 15 5.2)"></ellipse>'
            '<ellipse cx="19.8" cy="9.6" rx="2.5" ry="3.2" transform="rotate(20 19.8 9.6)"></ellipse>'
            '</g>')


def oak_leaf_body(color='#7A9440', vein='#4E6527', sw=1.4):
    """A lobed oak leaf on a 24 x 14 grid, drawn in a square 26 box (the
    asset's viewBox) so it can be rotated without clipping its tips."""
    return (f'<path d="M1.5 7C2.5 4.5 4 5.5 4.5 3.5C5 1 7.5 1.5 8 4C8.5 0.5 11.5 0.5 12 3.5'
            f'C12.5 0.5 15.5 0.5 16 4C16.5 1.5 19 1 19.5 3.5C20 5.5 22 4.5 23 7C22 9.5 20 8.5 19.5 10.5C19 13 16.5 12.5 16 10'
            f'C15.5 13.5 12.5 13.5 12 10.5C11.5 13.5 8.5 13.5 8 10C7.5 12.5 5 13 4.5 10.5C4 8.5 2.5 9.5 1.5 7Z" fill="{color}" '
            f'stroke="{vein}" stroke-width="{sw}" stroke-linejoin="round"></path><path d="M1 7H20" stroke="{vein}" '
            f'stroke-width="1.1" stroke-linecap="round"></path>')


def acorn_path(x, y, s=1.0):
    return (f'<g transform="translate({n(x)} {n(y)}) scale({s})">'
            f'<path d="M3 9c0 6 3 10 6 10s6-4 6-10z" fill="#C98A4A" stroke="{INK}" stroke-width="1.6"></path>'
            f'<path d="M1.5 9.5c0-4 3.4-6 7.5-6s7.5 2 7.5 6z" fill="#7A5230" stroke="{INK}" stroke-width="1.6"></path>'
            f'<path d="M9 3.5V0.5" stroke="{INK}" stroke-width="1.8" stroke-linecap="round"></path>'
            f'<path d="M4 7.5h10" stroke="#5E3E22" stroke-width="1" stroke-dasharray="1.5 1.5"></path></g>')


def basket(x, y, s=1.0):
    """A wicker truffle basket, 60 x 40 before scaling."""
    weave = ''.join(f'M{x0} 21v15' for x0 in range(10, 52, 6))
    return (f'<g transform="translate({n(x)} {n(y)}) scale({s})">'
            f'<path d="M12 18C12 4 48 4 48 18" fill="none" stroke="#7A4A1E" stroke-width="3.2" stroke-linecap="round"></path>'
            + truffle(22, 17, 6.5) + truffle(34, 15, 7.5) + truffle(43, 18.5, 5) +
            f'<path d="M4 18h52l-5 20H9z" fill="#D9A15A" stroke="{INK}" stroke-width="2" stroke-linejoin="round"></path>'
            f'<path d="{weave}M7 26h46M8.5 32h43" stroke="#9C6A2A" stroke-width="1.4" stroke-linecap="round"></path>'
            f'<path d="M3 18h54" stroke="{INK}" stroke-width="3" stroke-linecap="round"></path></g>')


def oak_tree(x, y, s=1.0, g1='#6E8B3D', g2='#8FA852'):
    return (f'<g transform="translate({n(x)} {n(y)}) scale({s})">'
            f'<path d="M44 120V70l-8-14M44 82l12-14" stroke="#6B4A2E" stroke-width="9" stroke-linecap="round" fill="none"></path>'
            + blob(44, 46, 40, 32, 14, g1, sw=2.4, stroke='#3F5524')
            + blob(36, 40, 22, 17, 10, g2, sw=0, stroke='none')
            + acorn_path(62, 52, .7) + acorn_path(22, 56, .6) + '</g>')


def ground(width, height, soil='#B98A5A', moss='#8FA852', edge='#5E7A35', seed=0):
    """Forest floor: a mossy wavy band over soil, with fallen leaves."""
    w = width
    top = 14
    d = f'M0 {top}'
    x = 0
    i = seed
    while x < w:
        step = 30 + (i * 7) % 14
        d += f'q{n(step / 2)} {-8 if i % 2 else -4} {n(step)} {0}'
        x += step
        i += 1
    d += f'V{height}H0Z'
    return (f'<path d="M0 {top + 6}H{w}V{height}H0Z" fill="{soil}"></path>'
            f'<path d="{d}" fill="{moss}" stroke="{edge}" stroke-width="2"></path>'
            f'<path d="M0 {top + 10}H{w}V{height}H0Z" fill="{soil}"></path>'
            f'<path d="M0 {top + 10}H{w}" stroke="{edge}" stroke-width="2"></path>')


# ---------------------------------------------------------------- assets

def asset(vb, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">{body}</svg>\n'


ASSETS = {
    'dog_face': ('0 0 64 64', lambda: dog_face('bianco')),
    'dog_face_tongue': ('0 0 64 64', lambda: dog_face('bianco', tongue=True)),
    'dog_lie': ('0 0 140 72', lambda: dog_lie('bianco')),
    'dog_lie_brown': ('0 0 140 72', lambda: dog_lie('marrone')),
    'dog_sniff': ('0 0 124 100', lambda: dog_stand('marrone', sniff=True)),
    'dog_sit': ('0 0 104 112', lambda: dog_sit('bianco')),
    'dog_sit_brown': ('0 0 104 112', lambda: dog_sit('marrone')),
    'puppy': ('0 0 70 56', lambda: puppy('arancio')),
    'puppy_white': ('0 0 70 56', lambda: puppy('bianco')),
    'truffle': ('0 0 24 24', lambda: truffle(12, 12.5, 9.5, sw=1.6)),
    'truffle_gold': ('0 0 24 24', lambda: GOLD_DEFS + truffle(12, 12.5, 9.5, gold=True, sw=1.6)),
    'basket': ('0 0 60 40', lambda: basket(0, 0)),
    'paw': ('0 0 24 24', lambda: paw_path('#000000')),
    'oak_leaf': ('-1 -6 26 26', lambda: oak_leaf_body('#7A9440', '#4E6527')),
    'oak_leaf_brown': ('-1 -6 26 26', lambda: oak_leaf_body('#C98A4A', '#7A4A1E')),
    'oak_tree': ('0 0 90 124', lambda: oak_tree(2, 2)),
    'ground': ('0 0 400 56', lambda: ground(400, 56)),
}


if __name__ == '__main__':
    import os
    out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'lagotto')
    for name, (vb, draw) in ASSETS.items():
        with open(os.path.join(out, f'{name}.svg'), 'w') as f:
            f.write(asset(vb, draw()))
        print(name)
