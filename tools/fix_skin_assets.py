"""Clean ADV skin previews: cyan backdrop removal + edge defringe + resize."""
from __future__ import annotations

import argparse
import sys
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image
import numpy as np

BASE_URL = "https://adv-rp.com/media/roulette-prizes/skin-{id}.png"
SKIP_IDS = {74}
MAX_SIDE = 256


def is_backdrop(r: int, g: int, b: int, a: int) -> bool:
    if a < 12:
        return True
  # cyan / turquoise family (#00FFFF, #5ACEFF, light blue)
    if b >= 170 and g >= 130 and r <= 140:
        return True
    # pale spill on anti-aliased edges
    if b >= 200 and g >= 200 and r >= 200 and a < 220:
        return True
    return False


def is_fringe_spill(r: int, g: int, b: int, a: int) -> bool:
    if a <= 0 or a >= 252:
        return False
    if is_backdrop(r, g, b, a):
        return True
    # bluish/white halo from cyan backdrop (not neutral gray clothing)
    if r >= 200 and g >= 200 and b >= 228 and a < 210:
        return True
    return False


def floodfill_backdrop(rgba: np.ndarray) -> None:
    h, w, _ = rgba.shape
    visited = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()

    def try_seed(y: int, x: int) -> None:
        if y < 0 or x < 0 or y >= h or x >= w or visited[y, x]:
            return
        r, g, b, a = rgba[y, x]
        if not is_backdrop(int(r), int(g), int(b), int(a)):
            return
        visited[y, x] = True
        q.append((y, x))

    for x in range(w):
        try_seed(0, x)
        try_seed(h - 1, x)
    for y in range(h):
        try_seed(y, 0)
        try_seed(y, w - 1)

    while q:
        y, x = q.popleft()
        rgba[y, x, 3] = 0
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                r, g, b, a = rgba[ny, nx]
                if is_backdrop(int(r), int(g), int(b), int(a)):
                    visited[ny, nx] = True
                    q.append((ny, nx))


def defringe_edges(rgba: np.ndarray) -> None:
    h, w, _ = rgba.shape
    for y in range(h):
        for x in range(w):
            r, g, b, a = map(int, rgba[y, x])
            if a == 0:
                continue
            if is_fringe_spill(r, g, b, a):
                rgba[y, x, 3] = 0
                rgba[y, x, :3] = 0


def process_image(im: Image.Image, max_side: int) -> Image.Image:
    im = im.convert("RGBA")
    rgba = np.array(im, dtype=np.uint8)
    floodfill_backdrop(rgba)
    defringe_edges(rgba)
    out = Image.fromarray(rgba, "RGBA")

    w, h = out.size
    if max(w, h) > max_side:
        scale = max_side / float(max(w, h))
        nw = max(1, int(round(w * scale)))
        nh = max(1, int(round(h * scale)))
        out = out.resize((nw, nh), Image.Resampling.LANCZOS)

    # second pass on scaled image (resize reintroduces faint halos)
    rgba2 = np.array(out, dtype=np.uint8)
    defringe_edges(rgba2)
    return Image.fromarray(rgba2, "RGBA")


def download_skin(sid: int, dest: Path, timeout: float = 20.0) -> bool:
    url = BASE_URL.format(id=sid)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ReportDesk/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
        if len(data) < 500:
            return False
        dest.write_bytes(data)
        return True
    except Exception:
        return False


def process_file(src: Path, dst: Path, max_side: int, redownload: bool, sid: int) -> bool:
    tmp = src
    if redownload:
        if not download_skin(sid, src):
            return False
    if not src.is_file() or src.stat().st_size < 500:
        return False
    try:
        with Image.open(tmp) as im:
            im.load()
            out = process_image(im, max_side)
        dst.parent.mkdir(parents=True, exist_ok=True)
        out.save(dst, format="PNG", optimize=True)
        return dst.is_file() and dst.stat().st_size > 400
    except Exception as exc:
        print(f"  FAIL skin-{sid}: {exc}", file=sys.stderr)
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "res" / "report_desk_skins",
    )
    ap.add_argument("--from-id", type=int, default=1)
    ap.add_argument("--to-id", type=int, default=311)
    ap.add_argument("--max-side", type=int, default=MAX_SIDE)
    ap.add_argument("--redownload", action="store_true", help="fetch fresh PNG from ADV before processing")
    args = ap.parse_args()

    ok = fail = 0
    ids = [i for i in range(args.from_id, args.to_id + 1) if i not in SKIP_IDS]
    total = len(ids)
    for n, sid in enumerate(ids, 1):
        path = args.dir / f"skin-{sid}.png"
        if process_file(path, path, args.max_side, args.redownload, sid):
            ok += 1
        else:
            fail += 1
        if n % 50 == 0 or n == total:
            print(f"  {n}/{total} ...")
    print(f"Done: ok={ok} fail={fail} dir={args.dir}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
