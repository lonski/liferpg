"""Draws the Kurczaki theme's illustrations into assets/kurczaki/ (ported from the approved mockups).

Run from the repo root: python3 tools/theme_art/kurczaki_art.py
"""
import os

OUT = "assets/kurczaki"
os.makedirs(OUT, exist_ok=True)

INK = "#4A2A12"
LJ = 'stroke-linejoin="round"'
LC = 'stroke-linecap="round"'


def hen(body, tail, wing, comb, legs, *, feet=True, closed_eye=False,
        stroke=2.8, legs_color="#EE8A1E", cheek=True):
    eye = (f'<path d="M77 20c1.5-2 4.5-2 6 0" stroke="#3A2210" stroke-width="2.4" {LC} fill="none"/>'
           if closed_eye else
           '<circle cx="80" cy="20" r="3" fill="#3A2210"/><circle cx="81" cy="19" r="1" fill="#FFFFFF"/>')
    leg_path = ("M46 80v8M46 88l-4 3M46 88l4 3M60 80v8M60 88l-4 3M60 88l4 3"
                if feet else "M46 80v8M60 80v8")
    return f'''
<path d="M24 46c-10-4-18-16-12-26 4 6 8 8 12 9-3-8 0-15 7-17-1 8 3 13 8 17z" fill="{tail}" stroke="{INK}" stroke-width="2.6" {LJ}/>
<path d="M68 12c-2-6 4-10 8-5 1-6 9-6 9 0 5-2 8 3 4 7z" fill="{comb}" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M20 50c0-14 14-22 30-20 10 1 14-4 18-12 4-6 12-7 17-2 5 5 5 12 2 18-3 6-3 11-1 18 3 14-12 26-33 26S20 66 20 50z" fill="{body}" stroke="{INK}" stroke-width="{stroke}" {LJ}/>
<path d="M88 20l10 4-10 4z" fill="#EE8A1E" stroke="{INK}" stroke-width="2" {LJ}/>
<path d="M87 28c-2 4-1 9 3 9 2-3 1-7-3-9z" fill="{comb}" stroke="{INK}" stroke-width="2" {LJ}/>
{eye}
{'<circle cx="77" cy="28" r="3.5" fill="#F39C7A" fill-opacity="0.6"/>' if cheek else ''}
<path d="M34 52c8-7 24-7 32 2-4 11-17 15-27 10-5-3-7-8-5-12z" fill="{wing}" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M42 58c6 0 12 1 16 4" stroke="{INK}" stroke-width="1.8" {LC} fill="none"/>
{f'<path d="{leg_path}" stroke="{legs_color}" stroke-width="2.6" {LC}/>' if legs else ''}
'''


def svg(name, view_box, body):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}">{body}</svg>\n')


svg("hen.svg", "0 0 100 92", hen("#FFFDF6", "#FFFDF6", "#F3E3C0", "#E8432F", True))
svg("hen_brown.svg", "0 0 100 92", hen("#D98E4A", "#C9783A", "#B0622A", "#E8432F", True))
svg("hen_perched.svg", "0 0 100 92", hen("#FFFDF6", "#FFFDF6", "#F3E3C0", "#E8432F", True, feet=False))
# On the red app bar: a yellow comb and legs so they don't vanish.
svg("hen_logo.svg", "0 0 100 92", hen("#FFFDF6", "#FFFDF6", "#F3E3C0", "#FFC83D", True, stroke=3.2,
                                     legs_color="#FFC83D", cheek=False))

nest = f'''
<ellipse cx="22" cy="78" rx="6" ry="7.5" fill="#FFF8E7" stroke="{INK}" stroke-width="2"/>
<path d="M8 76c6 14 80 14 90 0 2 10-8 18-45 18S6 86 8 76z" fill="#E0B25A" stroke="#7A4A1E" stroke-width="2.4" {LJ}/>
<path d="M14 82l10-4M30 87l8-6M50 89l6-7M70 87l4-7M86 83l2-6M20 88l-8-2M62 90l12-2" stroke="#9C6A2A" stroke-width="1.8" {LC}/>
'''
svg("hen_nest.svg", "0 0 104 96",
    hen("#FFFDF6", "#FFFDF6", "#F3E3C0", "#E8432F", False, closed_eye=True) + nest)


def rooster(body, wing, comb, tail2, crow):
    return f'''
<path d="M30 54C12 46 6 20 18 8c-2 16 6 28 16 34" fill="#2E7D4F" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M30 58C12 58 2 40 6 26c4 14 14 22 26 24" fill="{tail2}" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M32 50C22 36 24 14 36 6c-4 16 0 28 8 36" fill="#B83224" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M66 14c-3-8 4-13 8-7 0-8 10-8 10 0 5-4 11 1 7 7 4 0 5 6 0 8z" fill="{comb}" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M26 56c0-14 14-20 28-18 8 1 10-6 12-14 2-8 10-11 17-7 6 4 7 11 4 18-2 6-2 12 0 18 3 16-12 28-32 28S26 72 26 56z" fill="{body}" stroke="{INK}" stroke-width="2.8" {LJ}/>
<path d="M70 28c3 10 2 20-4 28" stroke="#EE8A1E" stroke-width="6" {LC} fill="none" stroke-opacity="0.85"/>
<path d="M86 22l12-5-10 8 10 5-12-2z" fill="#EE8A1E" stroke="{INK}" stroke-width="2" {LJ}/>
<path d="M85 32c-2 5-1 10 3 10 3-3 2-8-3-10z" fill="{comb}" stroke="{INK}" stroke-width="2" {LJ}/>
<circle cx="79" cy="20" r="3" fill="#3A2210"/>
<path d="M40 60c8-7 24-6 30 3-5 10-17 13-26 8-4-3-6-7-4-11z" fill="{wing}" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M48 88v8M48 96l-5 3M48 96l5 3M62 88v8M62 96l-5 3M62 96l5 3" stroke="#EE8A1E" stroke-width="3" {LC}/>
<path d="M102 12l7-5M104 22h8M102 31l7 4" stroke="{crow}" stroke-width="2.6" {LC}/>
'''


svg("rooster.svg", "0 0 112 100", rooster("#C9572B", "#8E3A1A", "#E8432F", "#EE8A1E", "#B83224"))
svg("rooster_light.svg", "0 0 112 100", rooster("#FFF5DC", "#F3E3C0", "#FFC83D", "#FFC83D", "#FFC83D"))

CHICK_BODY = f'''
<ellipse cx="19" cy="25" rx="13" ry="10" fill="#FFD23F" stroke="{INK}" stroke-width="2.2"/>
<circle cx="30" cy="15" r="8.5" fill="#FFD23F" stroke="{INK}" stroke-width="2.2"/>
<path d="M13 23c4-3 10-2 12 2-3 4-9 4-12-2z" fill="#F5B52E" stroke="{INK}" stroke-width="1.6" {LJ}/>
<path d="M37.5 14l5 2.2-5 2.2z" fill="#EE8A1E" stroke="{INK}" stroke-width="1.3" {LJ}/>
'''
svg("chick.svg", "0 0 44 42", f'''
<path d="M17 34v5M23 34v5M15 39h4M21 39h4" stroke="#EE8A1E" stroke-width="2" {LC}/>
{CHICK_BODY}
<circle cx="32" cy="13" r="1.8" fill="#3A2210"/>
<path d="M28 7c-1-3 1-5 3-3 0-2 3-2 3 0" stroke="{INK}" stroke-width="1.6" fill="none" {LC}/>
<circle cx="29" cy="18" r="2" fill="#F39C7A" fill-opacity="0.7"/>
''')
svg("chick_peck.svg", "0 0 44 42", f'''
<path d="M17 34v5M23 34v5" stroke="#EE8A1E" stroke-width="2" {LC}/>
{CHICK_BODY}
<path d="M30 13.5c1-1 3-1 4 0" stroke="#3A2210" stroke-width="1.8" {LC} fill="none"/>
''')
# Divider glyph: outlined in the accent so it reads on the eggshell card.
svg("chick_glyph.svg", "0 0 44 42", f'''
<path d="M17 34v5M23 34v5" stroke="#EE8A1E" stroke-width="2.4" {LC}/>
<ellipse cx="19" cy="25" rx="13" ry="10" fill="#FFD23F" stroke="#B83224" stroke-width="2.6"/>
<circle cx="30" cy="15" r="8.5" fill="#FFD23F" stroke="#B83224" stroke-width="2.6"/>
<circle cx="32" cy="13" r="2" fill="#3A2210"/>
<path d="M37.5 14l5 2.2-5 2.2z" fill="#EE8A1E"/>
''')
# Bottom band: a flat silhouette, no outline.
svg("chick_flat.svg", "0 0 44 42", '''
<ellipse cx="19" cy="25" rx="13" ry="10" fill="#FFD23F"/>
<circle cx="30" cy="15" r="8.5" fill="#FFD23F"/>
<circle cx="32" cy="13" r="2" fill="#3A2210"/>
<path d="M37.5 14l5 2.2-5 2.2z" fill="#EE8A1E"/>
''')
# Band label glyph: a round chick head, front-on.
svg("chick_head.svg", "0 0 64 64", f'''
<ellipse cx="32" cy="38" rx="20" ry="19" fill="#FFD23F" stroke="{INK}" stroke-width="4"/>
<circle cx="25" cy="34" r="3.5" fill="#3A2210"/>
<circle cx="39" cy="34" r="3.5" fill="#3A2210"/>
<path d="M27 39h10l-5 7z" fill="#EE8A1E"/>
<path d="M28 19c-1-6 4-8 5-3 2-5 8-3 5 3z" fill="#FFD23F" stroke="{INK}" stroke-width="3"/>
''')
# FAB face (the yellow disk is the button itself).
svg("chick_face.svg", "0 0 64 64", f'''
<path d="M27 12c-1-6 5-9 6-3 2-6 9-4 6 2" fill="#FFD23F" stroke="{INK}" stroke-width="3" {LC} {LJ}/>
<circle cx="23" cy="30" r="4" fill="#3A2210"/><circle cx="24.3" cy="28.7" r="1.3" fill="#FFFFFF"/>
<circle cx="41" cy="30" r="4" fill="#3A2210"/><circle cx="42.3" cy="28.7" r="1.3" fill="#FFFFFF"/>
<circle cx="17" cy="39" r="4" fill="#F39C7A" fill-opacity="0.75"/>
<circle cx="47" cy="39" r="4" fill="#F39C7A" fill-opacity="0.75"/>
<path d="M26 36h12l-6 8z" fill="#EE8A1E" stroke="{INK}" stroke-width="2.4" {LJ}/>
''')
svg("footprint.svg", "0 0 16 16",
    f'<path d="M8 15V8M8 8 3.5 2.5M8 8l4.5-5.5M8 8V1.5" stroke="#B83224" stroke-opacity="0.5" stroke-width="1.7" {LC} fill="none"/>')
svg("egg_gold.svg", "0 0 16 16", f'''
<path d="M8 1.5C5.5 1.5 3.8 5.5 3.8 8.5a4.2 4.2 0 0 0 8.4 0c0-3-1.7-7-4.2-7z" fill="#FFC83D" stroke="#B5781A" stroke-width="1.2"/>
<path d="M6 6.5c.4-1 1-1.8 1.6-2.2" stroke="#FFF5DC" stroke-width="1.2" {LC} fill="none"/>
''')
svg("egg_plain.svg", "0 0 48 58", f'''
<path d="M24 2C11 2 3 24 3 37a21 21 0 0 0 42 0C45 24 37 2 24 2z" fill="#FFFDF6" stroke="{INK}" stroke-width="2"/>
<ellipse cx="14" cy="17" rx="2.6" ry="6" fill="#FFFFFF" fill-opacity="0.8" transform="rotate(22 14 17)"/>
''')
svg("feather.svg", "0 0 24 24",
    f'<g fill="none" stroke="#B83224" stroke-width="2.2" {LC} {LJ}><path d="M20 4C10 4 5 10 5 19"/><path d="M20 4c0 8-6 13-13 13"/><path d="M5 19l-2 2"/></g>')
svg("nest.svg", "0 0 52 13", f'''
<path d="M2 3c6 8 42 8 48 0 1 6-6 9-24 9S1 9 2 3z" fill="#E0B25A" stroke="#7A4A1E" stroke-width="1.6" {LJ}/>
<path d="M8 7l6-3M20 10l5-5M32 10l3-5M44 7l-5-3" stroke="#9C6A2A" stroke-width="1.3" {LC}/>
''')
svg("grain.svg", "0 0 34 10",
    ''.join(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#E0B25A"/>' for x, y in [(3, 5), (10, 7), (17, 4), (25, 6), (31, 3)]))
svg("grass.svg", "0 0 390 46", f'''
<path d="M0 18c20-10 30 6 50-2s30 8 55 0 35 6 60-2 30 8 55 0 35 6 60-2 30 8 55 0 30 4 55-2v34H0z" fill="#8FC04A" stroke="#5E8A2A" stroke-width="2"/>
<path d="M30 18l-3-8M34 18l1-9M120 16l-2-7M124 16l2-8M210 18l-3-8M300 16l2-8M296 16l-3-7" stroke="#5E8A2A" stroke-width="2" {LC}/>
''')
svg("fence.svg", "0 0 390 110", f'''
<rect x="0" y="40" width="390" height="10" rx="3" fill="#C98B4B" stroke="#7A4A1E" stroke-width="2"/>
<rect x="0" y="66" width="390" height="10" rx="3" fill="#C98B4B" stroke="#7A4A1E" stroke-width="2"/>
<path d="M20 110V30l10-10 10 10v80zM90 110V30l10-10 10 10v80zM160 110V30l10-10 10 10v80zM230 110V30l10-10 10 10v80zM300 110V30l10-10 10 10v80zM370 110V30l10-10 10 10v80z" fill="#DDA466" stroke="#7A4A1E" stroke-width="2" {LJ}/>
<path d="M0 96c20-10 30 6 50-2s30 8 55 0 35 6 60-2 30 8 55 0 35 6 60-2 30 8 55 0 30 4 55-2v20H0z" fill="#8FC04A" stroke="#5E8A2A" stroke-width="2"/>
''')
# The big hen on the login screen (facing left, front three-quarter).
svg("hen_hero.svg", "0 0 120 120", f'''
<path d="M44 30c-4-10 6-15 11-7 1-10 15-10 14 0 8-5 15 4 8 10z" fill="#E8432F" stroke="{INK}" stroke-width="3" {LJ}/>
<path d="M96 60c10-6 18 2 14 10 6 1 6 10-1 11 3 6-4 11-10 6z" fill="#FFF5DC" stroke="{INK}" stroke-width="3" {LJ}/>
<path d="M60 30c-22 0-36 18-36 40 0 22 16 36 38 36s36-14 36-34c0-12-6-20-14-24-4-12-12-18-24-18z" fill="#FFFDF6" stroke="{INK}" stroke-width="3.2" {LJ}/>
<path d="M50 76c8-4 22-4 30 4-4 10-16 14-26 9-4-3-6-8-4-13z" fill="#F3E3C0" stroke="{INK}" stroke-width="2.6" {LJ}/>
<path d="M58 82c6 0 12 1 16 4M56 89c5 1 10 1 14 0" stroke="{INK}" stroke-width="2" {LC} fill="none"/>
<circle cx="46" cy="52" r="4" fill="#3A2210"/>
<circle cx="47.4" cy="50.6" r="1.3" fill="#FFFFFF"/>
<circle cx="40" cy="62" r="5" fill="#F39C7A" fill-opacity="0.6"/>
<path d="M28 54l-12 5 12 5z" fill="#EE8A1E" stroke="{INK}" stroke-width="2.6" {LJ}/>
<path d="M29 64c-3 4-2 10 3 11 3-3 2-8-3-11z" fill="#E8432F" stroke="{INK}" stroke-width="2.4" {LJ}/>
<path d="M52 105v9M52 114l-5 3M52 114l5 3M70 105v9M70 114l-5 3M70 114l5 3" stroke="#EE8A1E" stroke-width="3" {LC}/>
''')
# Feeding: a heart floats up from a fed bird; grain lies in piles to drag.
svg("heart.svg", "0 0 24 22",
    f'<path d="M12 20.5C6 16 2 12.6 2 8.2 2 5 4.4 2.5 7.4 2.5c1.9 0 3.6 1 4.6 2.6 1-1.6 2.7-2.6 4.6-2.6 3 0 5.4 2.5 5.4 5.7 0 4.4-4 7.8-10 12.3z" fill="#E8432F" stroke="{INK}" stroke-width="1.6" {LJ}/>'
    '<ellipse cx="7.5" cy="7" rx="1.8" ry="2.6" fill="#FFFFFF" fill-opacity="0.55" transform="rotate(-25 7.5 7)"/>')


def grains(points, r=2.4):
    return "".join(
        f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 0.7:.2f}" fill="{c}" stroke="#9C6A2A" stroke-width="0.8" transform="rotate({a} {x} {y})"/>'
        for x, y, a, c in points)


PILE = [(8, 20, 20, "#E9BE63"), (14, 21, -15, "#E0B25A"), (20, 20.5, 35, "#E9BE63"), (26, 21, -30, "#E0B25A"),
        (32, 20, 10, "#E9BE63"), (11, 16.5, -40, "#E0B25A"), (17, 16, 25, "#F0CC78"), (23, 16.5, -10, "#E0B25A"),
        (29, 16.5, 40, "#E9BE63"), (14, 12.5, 15, "#F0CC78"), (20, 12, -30, "#E0B25A"), (26, 12.5, 20, "#E9BE63"),
        (17, 8.5, -20, "#E9BE63"), (23, 8.5, 30, "#F0CC78"), (20, 5, 0, "#E0B25A")]
svg("grain_pile.svg", "0 0 40 25",
    '<ellipse cx="20" cy="22.5" rx="18" ry="2.5" fill="#000000" fill-opacity="0.12"/>' + grains(PILE))
svg("grain_handful.svg", "0 0 40 30",
    grains([(8, 8, 20, "#E9BE63"), (18, 5, -30, "#E0B25A"), (29, 9, 40, "#F0CC78"), (12, 16, -10, "#E0B25A"),
            (23, 14, 25, "#E9BE63"), (33, 18, -35, "#E0B25A"), (6, 24, 30, "#F0CC78"), (17, 25, -20, "#E9BE63"),
            (27, 24, 10, "#E0B25A")], r=2.8))
print(sorted(os.listdir(OUT)))
