"""Primitivas de desenho dos efeitos de skill (pixel art feita por script, sem imagem de entrada).

Cada quadro e desenhado como um CAMPO DE INTENSIDADE (0..1) em supersample (SS x), reduzido para a
resolucao final e quantizado em faixas de uma rampa de cores (escuro -> branco). Resultado: formas
limpas, com faixas de cor duras de pixel art (nucleo branco, corpo saturado, borda escura que no
blend aditivo vira brilho suave). Pecas "solidas" (poeira, cristal, placas) ganham contorno de 1 px.
Nada aqui le imagens de outros jogos (GDD §0 regra 5)."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SS = 4


def hexc(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


class Ramp:
    """Rampa de cores: cores[k] a partir do limiar limiares[k] de intensidade."""

    def __init__(self, colors: list[str], thresholds: list[float], alphas: list[int] | None = None):
        assert len(colors) == len(thresholds)
        self.colors = [hexc(c) for c in colors]
        self.th = thresholds
        # Alfa por faixa: o halo escuro fica translucido (no blend normal vira sombra suave de contraste).
        self.alphas = alphas or [255] * len(colors)

    def index(self, i: np.ndarray) -> np.ndarray:
        out = np.full(i.shape, -1, dtype=np.int16)
        for k, t in enumerate(self.th):
            out[i >= t] = k
        return out


class Canvas:
    """Campo de intensidade em supersample. Coordenadas em pixels FINAIS (float)."""

    def __init__(self, w: int, h: int | None = None):
        self.w = w
        self.h = h or w
        self.f = np.zeros((self.h * SS, self.w * SS), dtype=np.float32)
        ys, xs = np.mgrid[0:self.h * SS, 0:self.w * SS].astype(np.float32)
        self.X = (xs + 0.5) / SS
        self.Y = (ys + 0.5) / SS

    # ------------------------------------------------------------- primitivas vetoriais
    def _mask_poly(self, pts) -> np.ndarray:
        img = Image.new("L", (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(img).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
        return np.asarray(img, dtype=np.float32) / 255.0

    def put(self, mask: np.ndarray, v: float, mode: str = "max") -> None:
        if mode == "max":
            np.maximum(self.f, mask * v, out=self.f)
        elif mode == "add":
            self.f += mask * v
        elif mode == "cut":  # apaga (mascara 1 -> zera)
            self.f *= (1.0 - mask)
        elif mode == "mul":
            self.f *= mask

    def poly(self, pts, v: float, mode: str = "max") -> None:
        if len(pts) >= 3:
            self.put(self._mask_poly(pts), v, mode)

    def ellipse(self, cx, cy, rx, ry, v: float, mode: str = "max", rot: float = 0.0) -> None:
        dx = self.X - cx
        dy = self.Y - cy
        if rot:
            c, s = math.cos(rot), math.sin(rot)
            dx, dy = dx * c + dy * s, -dx * s + dy * c
        m = ((dx / max(rx, 1e-3)) ** 2 + (dy / max(ry, 1e-3)) ** 2) <= 1.0
        self.put(m.astype(np.float32), v, mode)

    def circle(self, cx, cy, r, v: float, mode: str = "max") -> None:
        self.ellipse(cx, cy, r, r, v, mode)

    def ring(self, cx, cy, r, width, v: float, ry_scale: float = 1.0, mode: str = "max",
             a0: float | None = None, a1: float | None = None) -> None:
        dx = self.X - cx
        dy = (self.Y - cy) / ry_scale
        d = np.sqrt(dx * dx + dy * dy)
        m = np.abs(d - r) <= width * 0.5
        if a0 is not None:
            ang = np.arctan2(dy, dx)
            m &= _ang_in(ang, a0, a1)
        self.put(m.astype(np.float32), v, mode)

    def stroke(self, pts, widths, vals, mode: str = "max") -> None:
        """Traco com largura e intensidade por ponto (rastro que afina)."""
        n = len(pts)
        if n == 0:
            return
        if not hasattr(widths, "__len__"):
            widths = [widths] * n
        if not hasattr(vals, "__len__"):
            vals = [vals] * n
        for i in range(n - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            w0, w1 = widths[i] * 0.5, widths[i + 1] * 0.5
            dx, dy = x1 - x0, y1 - y0
            ln = math.hypot(dx, dy) or 1e-3
            nx, ny = -dy / ln, dx / ln
            quad = [(x0 + nx * w0, y0 + ny * w0), (x1 + nx * w1, y1 + ny * w1),
                    (x1 - nx * w1, y1 - ny * w1), (x0 - nx * w0, y0 - ny * w0)]
            v = max(vals[i], vals[i + 1])
            if w0 > 0.05 or w1 > 0.05:
                self.poly(quad, v, mode)
        for i in range(n):
            if widths[i] > 0.6:
                self.circle(pts[i][0], pts[i][1], widths[i] * 0.5, vals[i], mode)

    def star(self, cx, cy, r_out, r_in, points, rot, v: float, mode: str = "max") -> None:
        pts = []
        for k in range(points * 2):
            r = r_out if k % 2 == 0 else r_in
            a = rot + k * math.pi / points
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        self.poly(pts, v, mode)

    def spike(self, cx, cy, ang, r0, r1, width, v: float, mode: str = "max") -> None:
        """Losango fino radial (raio de luz / estilhaco)."""
        c, s = math.cos(ang), math.sin(ang)
        mid = r0 + (r1 - r0) * 0.3
        px, py = -s, c
        pts = [(cx + c * r0, cy + s * r0),
               (cx + c * mid + px * width * 0.5, cy + s * mid + py * width * 0.5),
               (cx + c * r1, cy + s * r1),
               (cx + c * mid - px * width * 0.5, cy + s * mid - py * width * 0.5)]
        self.poly(pts, v, mode)

    def glow(self, sigma: float, gain: float, cap: float) -> None:
        g = ndimage.gaussian_filter(self.f, sigma * SS) * gain
        np.maximum(self.f, np.minimum(g, cap), out=self.f)

    def noise_erode(self, amount: float, seed: int, scale: float = 3.0) -> None:
        """Esfarela: zera onde o ruido < amount (0 = intacto, 1 = some)."""
        if amount <= 0:
            return
        rng = np.random.default_rng(seed)
        small = rng.random((max(2, int(self.h / scale)) + 2, max(2, int(self.w / scale)) + 2))
        n = ndimage.zoom(small, (self.h * SS / (small.shape[0] - 2), self.w * SS / (small.shape[1] - 2)),
                         order=1)[: self.h * SS, : self.w * SS]
        self.f *= (n >= amount).astype(np.float32)

    # ------------------------------------------------------------- reducao
    def down(self) -> np.ndarray:
        return self.f.reshape(self.h, SS, self.w, SS).mean(axis=(1, 3))


def _ang_in(ang, a0, a1):
    a = np.mod(ang - a0, 2 * math.pi)
    return a <= np.mod(a1 - a0, 2 * math.pi)


class Frame:
    """Quadro final: indices de rampa por camada, pintados em ordem."""

    def __init__(self, w: int, h: int | None = None):
        self.w, self.h = w, h or w
        self.rgba = np.zeros((self.h, self.w, 4), dtype=np.uint8)

    def paint(self, intensity: np.ndarray, ramp: Ramp, min_band: int = 0, clean: bool = True) -> None:
        idx = ramp.index(intensity)
        if clean:
            idx = _clean_orphans(idx)
        for k, c in enumerate(ramp.colors):
            if k < min_band:
                continue
            m = idx == k
            self.rgba[m, 0:3] = c
            self.rgba[m, 3] = ramp.alphas[k]

    def paint_canvas(self, cv: Canvas, ramp: Ramp, clean: bool = True) -> None:
        self.paint(cv.down(), ramp, clean=clean)

    def outline(self, color: str, only_new: bool = True) -> None:
        """Contorno colorido de 1 px em volta do que ja foi pintado (pecas solidas)."""
        a = self.rgba[..., 3] > 0
        grown = ndimage.binary_dilation(a, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        ring = grown & ~a
        c = hexc(color)
        self.rgba[ring, 0:3] = c
        self.rgba[ring, 3] = 255

    def px(self, x: int, y: int, color) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            c = hexc(color) if isinstance(color, str) else color
            self.rgba[y, x, 0:3] = c
            self.rgba[y, x, 3] = 255

    def twinkle(self, x: float, y: float, size: int, core: str, arm: str, tip: str | None = None) -> None:
        """Brilho em cruz desenhado pixel a pixel (faisca nitida)."""
        x, y = int(round(x)), int(round(y))
        self.px(x, y, core)
        for k in range(1, size + 1):
            col = arm if k < size or tip is None else tip
            for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                self.px(x + dx, y + dy, col)
        if size >= 2:
            for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                self.px(x + dx, y + dy, arm if size >= 3 else (tip or arm))

    def image(self) -> Image.Image:
        return Image.fromarray(self.rgba, "RGBA")


def _clean_orphans(idx: np.ndarray) -> np.ndarray:
    """Remove pixels soltos (sem vizinho pintado em 4 direcoes) — evita "chuvisco"."""
    painted = idx >= 0
    nb = np.zeros(idx.shape, dtype=np.int8)
    nb[1:, :] += painted[:-1, :]
    nb[:-1, :] += painted[1:, :]
    nb[:, 1:] += painted[:, :-1]
    nb[:, :-1] += painted[:, 1:]
    out = idx.copy()
    out[painted & (nb == 0)] = -1
    return out


def sheet(frames: list[Frame]) -> Image.Image:
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        img.paste(fr.image(), (i * w, 0))
    return img


def ease_out(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** 3


def ease_in(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t


def lerp(a, b, t):
    return a + (b - a) * t


# ================================================================== registro das pecas (compartilhado)
# Todas as folhas geradas se registram aqui (gen_skill_fx.py e os modulos fx_*.py): nome -> quadros,
# pivo, blend ("add" = forma normal + brilho somado no jogo; "mix" = so a forma), plano, fps, laco e texel.
PIECES: dict[str, dict] = {}


def piece(name, frames, *, pivot, blend, plane, fps, loop=False, texel=1.0 / 48.0):
    PIECES[name] = dict(frames=frames, pivot=pivot, blend=blend, plane=plane, fps=fps, loop=loop, texel=texel)


def rng(seed):
    return np.random.default_rng(seed)


def layer(fr: "Frame", cv: Canvas, ramp: Ramp, line: str | None = None, clean: bool = True) -> None:
    """Pinta um campo com a sua rampa (e contorno proprio) POR CIMA do quadro — objetos de varias cores."""
    sub = Frame(fr.w, fr.h)
    sub.paint_canvas(cv, ramp, clean=clean)
    if line:
        sub.outline(line)
    m = sub.rgba[..., 3] > 0
    fr.rgba[m] = sub.rgba[m]


def under(fr: "Frame", cv: Canvas, ramp: Ramp, line: str | None = None) -> None:
    """Como layer, mas POR BAIXO do que ja foi pintado (halos, sombras)."""
    sub = Frame(fr.w, fr.h)
    sub.paint_canvas(cv, ramp)
    if line:
        sub.outline(line)
    m = (sub.rgba[..., 3] > 0) & (fr.rgba[..., 3] == 0)
    fr.rgba[m] = sub.rgba[m]


# ================================================================== sprites em pixel (desenho a mao)
class Spr:
    """Sprite desenhado a mao em texto (1 caractere = 1 pixel). pal: caractere -> "#rrggbb"; '.' e ' ' = vazio."""

    def __init__(self, a: np.ndarray):
        self.a = a

    @staticmethod
    def parse(text: str, pal: dict[str, str]) -> "Spr":
        rows = [r for r in text.strip("\n").split("\n")]
        rows = [r.rstrip() for r in rows]
        # remove a indentacao comum
        ind = min((len(r) - len(r.lstrip()) for r in rows if r.strip()), default=0)
        rows = [r[ind:] for r in rows]
        h, w = len(rows), max(len(r) for r in rows)
        a = np.zeros((h, w, 4), dtype=np.uint8)
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in ".  " or ch not in pal:
                    continue
                a[y, x, 0:3] = hexc(pal[ch])
                a[y, x, 3] = 255
        return Spr(a)

    @property
    def w(self) -> int:
        return self.a.shape[1]

    @property
    def h(self) -> int:
        return self.a.shape[0]

    def flip(self) -> "Spr":
        return Spr(self.a[:, ::-1].copy())

    def flipv(self) -> "Spr":
        return Spr(self.a[::-1].copy())

    def rot(self, deg: float) -> "Spr":
        if abs(deg) < 0.5:
            return self
        im = Image.fromarray(self.a, "RGBA").rotate(deg, resample=Image.NEAREST, expand=True)
        return Spr(np.asarray(im).copy())

    def scale(self, k: float) -> "Spr":
        if abs(k - 1.0) < 1e-3:
            return self
        w, h = max(1, round(self.w * k)), max(1, round(self.h * k))
        im = Image.fromarray(self.a, "RGBA").resize((w, h), Image.NEAREST)
        return Spr(np.asarray(im).copy())

    def squash(self, kx: float, ky: float) -> "Spr":
        w, h = max(1, round(self.w * kx)), max(1, round(self.h * ky))
        im = Image.fromarray(self.a, "RGBA").resize((w, h), Image.NEAREST)
        return Spr(np.asarray(im).copy())

    def recolor(self, mapping: dict[str, str]) -> "Spr":
        a = self.a.copy()
        for src, dst in mapping.items():
            s = np.array(hexc(src))
            m = (a[..., 3] > 0) & np.all(a[..., 0:3] == s, axis=-1)
            a[m, 0:3] = hexc(dst)
        return Spr(a)

    def outlined(self, color: str) -> "Spr":
        a = np.pad(self.a, ((1, 1), (1, 1), (0, 0)))
        on = a[..., 3] > 0
        grown = ndimage.binary_dilation(on, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        ring = grown & ~on
        a[ring, 0:3] = hexc(color)
        a[ring, 3] = 255
        return Spr(a)


def blit(fr: "Frame", spr: Spr, x: float, y: float, anchor=(0.5, 0.5), alpha: float = 1.0) -> None:
    """Cola o sprite com o ponto 'anchor' (fracao do sprite) em (x, y). alpha < 1 = pontilhado de pixel art
    (xadrez), nunca meio-tom borrado."""
    h, w = spr.h, spr.w
    x0 = int(round(x - anchor[0] * w))
    y0 = int(round(y - anchor[1] * h))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(w, fr.w - x0), min(h, fr.h - y0)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    src = spr.a[sy0:sy1, sx0:sx1]
    m = src[..., 3] > 0
    if alpha < 0.999:
        yy, xx = np.mgrid[sy0:sy1, sx0:sx1]
        if alpha <= 0.0:
            return
        # 0.75: tira 1 de cada 4; 0.5: xadrez; 0.25: 1 de cada 4
        pat = ((xx + yy) % 2 == 0) if alpha >= 0.5 else ((xx % 2 == 0) & (yy % 2 == 0))
        if alpha >= 0.75:
            pat = ~((xx % 2 == 0) & (yy % 2 == 0))
        m &= pat
    dst = fr.rgba[y0 + sy0:y0 + sy1, x0 + sx0:x0 + sx1]
    dst[m] = src[m]


def line_px(fr: "Frame", x0, y0, x1, y1, color) -> None:
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(n, 1)
        fr.px(int(round(lerp(x0, x1, t))), int(round(lerp(y0, y1, t))), color)
