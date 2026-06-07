"""Resize vehicle preview (JPEG/PNG/WebP) to PNG for Report Desk assets."""
import sys
from pathlib import Path

from PIL import Image


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: veh_image_convert.py <src> <dst.png> [max_width=256]", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    max_w = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    if not src.is_file() or src.stat().st_size < 400:
        return 1
    with Image.open(src) as im:
        im.load()
        if im.mode in ("P", "LA"):
            im = im.convert("RGBA")
        elif im.mode == "RGBA":
            pass
        else:
            im = im.convert("RGB")
        w, h = im.size
        if w > max_w:
            h = max(1, round(h * max_w / w))
            w = max_w
            im = im.resize((w, h), Image.Resampling.LANCZOS)
        dst.parent.mkdir(parents=True, exist_ok=True)
        im.save(dst, format="PNG", optimize=True)
    if not dst.is_file() or dst.stat().st_size < 1500:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
