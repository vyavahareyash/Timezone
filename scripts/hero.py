#!/usr/bin/env python3
"""Draw the README hero, .github/hero.svg: the panel hanging from the menu bar, animated in a 16 s loop.

Run from anywhere: python3 scripts/hero.py
The story: following Now -> drag the bead through the afternoon -> type 9:00 into San Francisco -> back to Now.
GitHub shows README SVGs as <img>: no script, CSS animation only, so each clock state is its own text that fades in.
Reduce Motion shows the resolved answer (state b) as a still.
"""
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / ".github" / "hero.svg"

# The light sky from App/TimezoneApp.swift (skyLight): local hour -> colour. Keep in step with the app.
SKY = [(0, 0x28305A), (5, 0x28305A), (6.3, 0xB98AA6), (7.4, 0xF3C08B), (9.5, 0xA8D2F2),
       (16.5, 0xA8D2F2), (18.2, 0xF2B072), (19.4, 0x7A5D92), (21, 0x28305A), (24, 0x28305A)]

T = 16                      # loop seconds
X0, X1 = 566, 890           # strip extent inside the panel
NOW = 10 + 7 / 60           # Pune (Home) time of Now

# Late-November offsets from Pune (IST): Berlin CET, San Francisco PST, Auckland NZDT.
# Per state, each city's clock and day offset. States: now, d1-d3 while dragging, b after typing 9:00 in San Francisco.
STATES = ["now", "d1", "d2", "d3", "b"]
ZONES = [
    ("Pune", "IST", 0, {"now": ("10:07", ""), "d1": ("12:00", ""), "d2": ("15:00", ""), "d3": ("18:00", ""), "b": ("22:30", "")}),
    ("Berlin", "CET", -4.5, {"now": ("05:37", ""), "d1": ("07:30", ""), "d2": ("10:30", ""), "d3": ("13:30", ""), "b": ("18:00", "")}),
    ("San Francisco", "PST", -13.5, {"now": ("20:37", "−1"), "d1": ("22:30", "−1"), "d2": ("01:30", ""), "d3": ("04:30", ""), "b": ("09:00", "")}),
    ("Auckland", "NZDT", 7.5, {"now": ("17:37", ""), "d1": ("19:30", ""), "d2": ("22:30", ""), "d3": ("01:30", "+1"), "b": ("06:00", "+1")}),
]

# Visible spans in percent of the loop: (spans, shown under Reduce Motion, fade width).
SPANS = {
    "now": ([(0, 22), (93, 100)], 0, .4), "d1": ([(22, 28)], 0, .4), "d2": ([(28, 34)], 0, .4),
    "d3": ([(34, 62)], 0, .4), "d3sf": ([(34, 46)], 0, .4), "b": ([(62, 92)], 1, .4),
    "hdr-follow": ([(0, 16), (94, 100)], 0, .4), "hdr-back": ([(16, 93)], 1, .4),
    "field": ([(46, 62)], 0, .4), "t1": ([(48, 51)], 0, .4), "t2": ([(51, 54)], 0, .4),
    "t3": ([(54, 57)], 0, .4), "t4": ([(57, 62)], 0, .4),
    "cap-now": ([(0, 13), (95, 100)], 0, .4), "cap-drag": ([(14, 44)], 0, .4),
    "cap-type": ([(45, 62)], 0, .4), "cap-b": ([(63, 92)], 1, .4),
    "sky-dusk": ([(38, 64)], 0, 4), "sky-night": ([(62, 92)], 1, 4),
    "ptr-arrow": ([(12, 15), (36, 47)], 0, .4), "ptr-resize": ([(15, 36)], 0, .4),
}
BEAD = [(0, NOW), (16, NOW), (22, 12), (28, 15), (34, 18), (62, 18), (66, 22.5), (90, 22.5), (95, NOW), (100, NOW)]


def x_at(hour):
    """Pune (Home) hours -> x on the strips."""
    return X0 + (X1 - X0) * hour / 24


BERLIN_Y = 92 + 64 + 36  # middle of Berlin's strip, where the pointer drags
POINTER = [(0, 780, 300), (12, 770, 260), (15, x_at(NOW), BERLIN_Y), (16, x_at(NOW), BERLIN_Y), (22, x_at(12), BERLIN_Y),
           (28, x_at(15), BERLIN_Y), (34, x_at(18), BERLIN_Y), (37, x_at(18), BERLIN_Y), (44, 858, 236), (100, 858, 236)]


def sky(hour):
    for (h0, c0), (h1, c1) in zip(SKY, SKY[1:]):
        if h0 <= hour <= h1:
            t = (hour - h0) / (h1 - h0)
            return "#%02X%02X%02X" % tuple(round(((c0 >> s) & 255) * (1 - t) + ((c1 >> s) & 255) * t) for s in (16, 8, 0))
    raise ValueError(hour)


def window_keyframes(name, spans, edge):
    at = {0: 0}
    for s, e in spans:
        at.update({max(s - edge, 0): 0, s: 1, e: 1, min(e + edge, 100): 0})
    if spans[0][0] == 0:
        at[0] = 1
    at.setdefault(100, 0)
    if spans[-1][1] == 100:
        at[100] = 1
    return f"@keyframes k-{name}{{" + "".join(f"{p:g}%{{opacity:{o}}}" for p, o in sorted(at.items())) + "}"


def css():
    out = [
        "text{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Segoe UI',Helvetica,Arial,sans-serif;"
        "font-variant-numeric:tabular-nums}",
        ".mono{font-family:ui-monospace,SFMono-Regular,'SF Mono',Menlo,Consolas,monospace}",
    ]
    for name, (spans, base, edge) in SPANS.items():
        out.append(window_keyframes(name, spans, edge) + f".{name}{{opacity:{base};animation:k-{name} {T}s linear infinite}}")
    out.append("@keyframes k-bead{" + "".join(f"{p}%{{transform:translateX({x_at(h):.1f}px)}}" for p, h in BEAD) + "}"
               f".bead{{transform:translateX({x_at(22.5):.1f}px);animation:k-bead {T}s ease-in-out infinite}}")
    out.append("@keyframes k-ptr{" + "".join(f"{p}%{{transform:translate({x:.1f}px,{y}px)}}" for p, x, y in POINTER) + "}"
               f".ptr-move{{animation:k-ptr {T}s ease-in-out infinite}}")
    out.append("@keyframes breathe{from{opacity:1}to{opacity:.3}}.now-line{animation:breathe 1.2s ease-in-out infinite alternate}")
    out.append("@media (prefers-reduced-motion:reduce){*{animation:none!important}}")
    return "".join(out)


def text(x, y, size, fill, body, cls="", **attrs):
    extra = "".join(f' {k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    c = f' class="{cls}"' if cls else ""
    return f'<text{c} x="{x:g}" y="{y:g}" font-size="{size}" fill="{fill}"{extra}>{body}</text>'


def strips():
    defs, rows, beads = [], [], []
    for i, (label, abbr, offset, clocks) in enumerate(ZONES):
        stops = "".join(f'<stop offset="{q / 96:.4f}" stop-color="{sky((q / 4 + offset) % 24)}"/>' for q in range(97))
        defs.append(f'<linearGradient id="sky{i}">{stops}</linearGradient>')
        top, sf = 92 + i * 64, label == "San Francisco"
        rows.append(text(X0, top + 18, 15, "#1d1d1f", label, font_weight=500))
        rows.append(text(X1 - 74, top + 18, 11.5, "#86868b", abbr, text_anchor="end"))
        clock = dict(font_weight=600, text_anchor="end")
        day_x = X1 - (len(abbr) * 8 + 84)
        for state in STATES:
            cls = "d3sf" if sf and state == "d3" else state  # San Francisco's clock gives way to the edit field
            time, day = clocks[state]
            rows.append(text(X1, top + 20, 22, "#1d1d1f", time, cls, **clock))
            if day:
                rows.append(text(day_x, top + 18, 11.5, "#86868b", day, cls, text_anchor="end"))
        if sf:
            rows.append(f'<rect class="field" x="{X1 - 66}" y="{top - 2}" width="70" height="30" rx="7" fill="#fff" '
                        'stroke="#0a84ff" stroke-width="2"/>')
            for n, typed in enumerate(["9", "9:", "9:0", "9:00"], 1):
                rows.append(text(X1 - 4, top + 20, 22, "#1d1d1f", typed, f"t{n}", **clock))
        y = top + 30
        rows.append(f'<rect x="{X0}" y="{y}" width="{X1 - X0}" height="12" rx="6" fill="url(#sky{i})"/>')
        rows.append(f'<rect class="now-line" x="{x_at(NOW) - 1:.1f}" y="{y}" width="2" height="12" rx="1" fill="#FF3B30"/>')
        beads.append(f'<rect x="-4" y="{y}" width="8" height="12" rx="4" fill="#fff" filter="url(#beadShadow)"/>'
                     f'<rect x="-1.25" y="{y + 2.5}" width="2.5" height="7" rx="1.25" fill="#000" fill-opacity=".55"/>')
    return "".join(defs), "\n".join(rows), "".join(beads)


STARS = [(92, 70, 1.2, .8), (210, 48, .9, .6), (318, 96, 1.1, .7), (402, 58, .8, .6), (470, 128, 1.3, .8),
         (160, 132, .8, .5), (512, 40, .9, .6), (934, 430, .9, .5), (38, 300, .8, .5), (440, 250, 1, .5)]


def build():
    sky_defs, rows, beads = strips()
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" opacity="{o}"/>' for x, y, r, o in STARS)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="960" height="460" viewBox="0 0 960 460" role="img" aria-label="Timezone's panel hanging from the menu bar. The bead is dragged through the afternoon and every city's clock follows; then 9:00 is typed into San Francisco and every city moves to that moment: Pune 22:30, Berlin 18:00, Auckland 06:00 the next day. The desktop sky follows Pune's time.">
<title>Timezone: see the sky over everyone you work with</title>
<style>{css()}</style>
<defs>
<clipPath id="card"><rect width="960" height="460" rx="14"/></clipPath>
<linearGradient id="morning" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#23497A"/><stop offset=".55" stop-color="#4F83B8"/><stop offset=".86" stop-color="#9CC6E8"/><stop offset="1" stop-color="#F3C08B"/></linearGradient>
<linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B3366"/><stop offset=".5" stop-color="#6A548A"/><stop offset=".82" stop-color="#E39A72"/><stop offset="1" stop-color="#F3C08B"/></linearGradient>
<linearGradient id="night" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0E1230"/><stop offset=".55" stop-color="#28305A"/><stop offset=".86" stop-color="#4A3863"/><stop offset="1" stop-color="#7A5D92"/></linearGradient>
<radialGradient id="glow" cx=".5" cy="1" r=".6"><stop offset="0" stop-color="#F3C08B" stop-opacity=".55"/><stop offset="1" stop-color="#F3C08B" stop-opacity="0"/></radialGradient>
<filter id="panelShadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#0B0E24" flood-opacity=".45"/></filter>
<filter id="beadShadow" x="-1" y="-1" width="3" height="3"><feDropShadow dx="0" dy="0" stdDeviation="1.5" flood-opacity=".4"/></filter>
{sky_defs}
</defs>
<g clip-path="url(#card)">
<rect width="960" height="460" fill="url(#morning)"/>
<rect width="960" height="460" fill="url(#glow)"/>
<rect class="sky-dusk" width="960" height="460" fill="url(#dusk)"/>
<g class="sky-night"><rect width="960" height="460" fill="url(#night)"/><g fill="#fff">{stars}</g></g>
<rect width="960" height="26" fill="#fff" fill-opacity=".16"/>
<g fill="#fff" fill-opacity=".75"><rect x="20" y="10" width="14" height="6" rx="3"/><rect x="46" y="10" width="34" height="6" rx="3"/><rect x="92" y="10" width="26" height="6" rx="3"/><rect x="130" y="10" width="30" height="6" rx="3"/><rect x="760" y="9" width="16" height="8" rx="2"/><rect x="788" y="9" width="12" height="8" rx="4"/></g>
<rect x="714" y="3" width="28" height="20" rx="5" fill="#fff" fill-opacity=".32"/>
<g transform="translate(719 4)" fill="none" stroke="#fff" stroke-width="1.35" stroke-linecap="round"><circle cx="9" cy="9" r="7"/><ellipse cx="9" cy="9" rx="3" ry="7"/><path d="M2 9h14M3.3 5.6c1.6.6 3.5.9 5.7.9s4.1-.3 5.7-.9M3.3 12.4c1.6-.6 3.5-.9 5.7-.9s4.1.3 5.7.9"/></g>
{text(940, 17.5, 12.5, "#fff", "Fri 27 Nov  10:07", text_anchor="end", font_weight=500)}
{text(64, 196, 60, "#fff", "Timezone", font_weight=700, letter_spacing=-1.5)}
{text(66, 238, 23, "#fff", "See the sky over everyone", fill_opacity=.92)}
{text(66, 268, 23, "#fff", "you work with.", fill_opacity=.92)}
<g fill-opacity=".88">
{text(66, 318, 13.5, "#fff", "Following now · 10:07 in Pune", "mono cap-now")}
{text(66, 318, 13.5, "#fff", "Drag the bead through the day…", "mono cap-drag")}
{text(66, 318, 13.5, "#fff", "…or type a time into any city", "mono cap-type")}
{text(66, 318, 13.5, "#fff", "9:00 in San Francisco is 22:30 in Pune", "mono cap-b")}
</g>
<rect x="548" y="34" width="360" height="370" rx="18" fill="#F6F7FA" fill-opacity=".94" stroke="#fff" stroke-opacity=".7" filter="url(#panelShadow)"/>
{text(566, 66, 14, "#86868b", "Following Now", "hdr-follow")}
<g class="hdr-back"><rect x="790" y="49" width="100" height="24" rx="12" fill="#fff" stroke="#d8dbe0"/>{text(840, 65.5, 12.5, "#1d1d1f", "Back to Now", text_anchor="middle", font_weight=500)}</g>
<rect x="556" y="84" width="344" height="58" rx="10" fill="#E3EFFB"/>
{rows}
<g class="bead" transform="translate({x_at(22.5):.1f} 0)">{beads}</g>
<rect x="566" y="356" width="40" height="28" rx="8" fill="#fff" stroke="#d8dbe0"/>
{text(586, 376, 20, "#1d1d1f", "+", text_anchor="middle")}
<g class="ptr-move">
<path class="ptr-arrow" d="M0 0v17l4.4-4 3.1 7.2 2.6-1.1-3-7h6z" fill="#111" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"/>
<path class="ptr-resize" d="M-10 0l5.5-5.5v3.3h9v-3.3L10 0l-5.5 5.5V2.2h-9v3.3z" fill="#111" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"/>
</g>
</g>
</svg>
'''


def with_resting_opacity(svg):
    """Give each animated element its Reduce Motion opacity as an attribute too, for renderers that skip CSS
    (Quick Look, image tools). CSS animation still overrides it in browsers."""
    def add(match):
        base = next((SPANS[c][1] for c in match[1].split() if c in SPANS), None)
        return match[0] if base is None else f'{match[0]} opacity="{base}"'
    return re.sub(r'class="([^"]*)"', add, svg)


if __name__ == "__main__":
    # Self-checks: the sky matches the app's keyframes, and every clock state is listed for every city.
    assert sky(0) == "#28305A" and sky(9.5) == "#A8D2F2" and sky(18.2) == "#F2B072"
    assert all(set(clocks) == set(STATES) for *_, clocks in ZONES)
    OUT.write_text(with_resting_opacity(build()))
    print(OUT.relative_to(OUT.parent.parent))
