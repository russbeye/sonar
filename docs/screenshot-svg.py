#!/usr/bin/env python3
"""Draws sonar's real ANSI bar output inside Tokyo Night terminal frames, as one SVG.

Every character gets an explicit x position, so a glyph that the fallback font
draws wider or narrower than one cell cannot push the rest of the line out of place.
"""
import re, sys, html

OUT_DIR, SVG = sys.argv[1], sys.argv[2]
CW, LH, FS = 8.4, 22, 14          # cell width, line height, font size in px
PAD, GAP, TITLE = 18, 34, 30      # frame padding, gap between frames, title bar height
BG, BAR, FG, DIM = "#1a1b26", "#16161e", "#c0caf5", "#565f89"
# Browsers draw these as color emoji unless we ask for the text form.
TEXT_FORM = set("⚙⚠")
WIDE = set("⚙⚠⎇⧉")
# Symbol fonts follow the monospace ones so that glyphs such as ⚙ use a text font
# from Linux, macOS, or Windows before the browser falls back to color emoji.
FONT = ("'JetBrains Mono','JetBrainsMono Nerd Font','DejaVu Sans Mono',Menlo,Consolas,"
        "'Noto Sans Symbols','Apple Symbols','Segoe UI Symbol','DejaVu Sans',monospace")

# name, label, columns, history lines as (color, text) runs per line
PANELS = [
    ("calm", "Calm: clean tree, CI green", 140, [
        [(DIM, "~/c/ot4/calm "), (FG, "$ git pull --rebase")],
        [(DIM, "Already up to date.")]]),
    ("flow", "In flow: work in progress, servers up, an agent waiting", 140, [
        [(DIM, "~/c/ot4/proj/src/parser "), (FG, "$ pnpm test src/parser")],
        [("#9ece6a", " ✓ 38 passed"), (DIM, " (6.1s)")]]),
    ("trouble", "Trouble: prod context, failed command, CI red, wrong Node", 140, [
        [(DIM, "~/c/ot4/api "), (FG, "$ npm run migrate")],
        [("#f7768e", "npm error notsup Unsupported engine: wanted node 22, current node 20.11.1")]]),
    ("worktree-72", "Worktree in a 72-column split: the branch and dial shorten first", 72, [
        [(DIM, "~/.c/s/crc-calibration-larger-wins-baseline "), (FG, "$ pnpm test calibration")],
        [("#9ece6a", " ✓ 112 passed"), (DIM, " (3.4s)")]]),
]

def parse(line):
    """Yields (char, fg, bg, bold) for each visible character of an ANSI line."""
    fg, bg, bold = FG, None, False
    i = 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m|([^\x1b])", line):
        if m.group(2) is not None:
            yield m.group(2), fg, bg, bold
            continue
        p = [int(x) for x in m.group(1).split(";") if x] or [0]
        while p:
            c = p.pop(0)
            if c == 0: fg, bg, bold = FG, None, False
            elif c == 1: bold = True
            elif c == 22: bold = False
            elif c == 39: fg = FG
            elif c in (38, 48) and p[:1] == [2]:
                r, g, b = p[1:4]; p = p[4:]
                col = f"#{r:02x}{g:02x}{b:02x}"
                if c == 38: fg = col
                else: bg = col

def runs(cells):
    """Groups consecutive cells with the same style into (start, text, fg, bg, bold)."""
    out = []
    for i, (ch, fg, bg, bold) in enumerate(cells):
        if out and out[-1][2:] == (fg, bg, bold) and out[-1][0] + len(out[-1][1]) == i:
            out[-1] = (out[-1][0], out[-1][1] + ch, fg, bg, bold)
        else:
            out.append((i, ch, fg, bg, bold))
    return out

def text(x0, y, start, s, fill, bold=False):
    # Browsers collapse spaces inside SVG text even with xml:space="preserve", and
    # that shifts every later character left by one cell. So we never emit a
    # space. Each ASCII word and each symbol becomes its own element, pinned to its cells.
    w = ' font-weight="700"' if bold else ""
    out = []
    for m in re.finditer(r"[!-~]+|\S", s):
        tok, col = m.group(), start + m.start()
        if tok.isascii():
            xs = " ".join(f"{x0 + (col + k) * CW:.1f}" for k in range(len(tok)))
            out.append(f'<text x="{xs}" y="{y}" fill="{fill}"{w}>{html.escape(tok)}</text>')
            continue
        # A symbol can come from a proportional fallback font and be wider than a
        # cell. We center each symbol in its cell, and squeeze the wide ones to fit.
        fit = f' textLength="{CW * 0.95:.1f}" lengthAdjust="spacingAndGlyphs"' if tok in WIDE else ""
        sel = "\ufe0e" if tok in TEXT_FORM else ""
        out.append(f'<text x="{x0 + (col + 0.5) * CW:.1f}" y="{y}" fill="{fill}" text-anchor="middle"{w}{fit}>'
                   f'{html.escape(tok)}{sel}</text>')
    return "".join(out)

width = max(cols for *_, cols, _ in PANELS) * CW + 2 * PAD + 2
parts, y = [], 0
for name, label, cols, hist in PANELS:
    cells = list(parse(open(f"{OUT_DIR}/{name}.ansi").read().rstrip("\n")))
    fw = cols * CW + 2 * PAD
    fh = TITLE + PAD + (len(hist) + 1) * LH + LH + 14
    parts.append(f'<rect x="1" y="{y}" width="{fw}" height="{fh}" rx="10" fill="{BG}"/>')
    parts.append(f'<text x="{1 + fw / 2:.1f}" y="{y + 20}" fill="{DIM}" font-size="12.5" text-anchor="middle">{html.escape(label)}</text>')
    for k, c in enumerate(("#f7768e", "#e0af68", "#9ece6a")):
        parts.append(f'<circle cx="{19 + k * 18}" cy="{y + 15}" r="5.5" fill="{c}"/>')
    ty = y + TITLE + PAD + 4
    for line in hist:
        col = 0
        for fill, s in line:
            parts.append(text(PAD + 1, ty, col, s, fill)); col += len(s)
        ty += LH
    parts.append(text(PAD + 1, ty, 0, "$ ", FG) + text(PAD + 1, ty, 2, "▍", DIM))
    by = y + fh - LH - 14
    parts.append(f'<path d="M1 {by} h{fw} v{LH + 4} a10 10 0 0 1 -10 10 h{-(fw - 20)} a10 10 0 0 1 -10 -10 z" fill="{BAR}"/>')
    parts.append(f'<rect x="1" y="{by}" width="{fw}" height="1" fill="#24283b"/>')
    for start, s, fg, bg, bold in runs(cells):
        if bg:
            parts.append(f'<rect x="{PAD + 1 + start * CW:.1f}" y="{by + 5}" width="{len(s) * CW:.1f}" height="{LH + 2}" rx="3" fill="{bg}"/>')
        if s.strip():
            parts.append(text(PAD + 1, by + LH + 1, start, s, fg, bold))
    y += fh + GAP

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{y - GAP + 2:.0f}" '
       f'viewBox="0 0 {width:.0f} {y - GAP + 2:.0f}" font-family="{FONT}" font-size="{FS}" '
       f'xml:space="preserve" style="font-variant-ligatures:none;font-feature-settings:\'liga\' 0,\'calt\' 0">\n'
       + "\n".join(parts) + "\n</svg>\n")
open(SVG, "w").write(svg)
