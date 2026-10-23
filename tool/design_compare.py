#!/usr/bin/env python3
"""Compare an app screenshot with a design image.

Writes three images next to each other in --out:
  <name>_side.png     design | screenshot
  <name>_overlay.png  50% blend of the two
  <name>_diff.png     amplified per-pixel difference (red = mismatch)

and prints a similarity summary per horizontal band so regressions are easy to spot.

Usage:
  tool/.venv/bin/python tool/design_compare.py \
      --design design-template/home.png --shot build/shots/home.png --out build/compare

  # order.png draws the phone screen inside a backdrop; pass the screen's x-range
  tool/.venv/bin/python tool/design_compare.py \
      --design design-template/order.png --design-frame 46,806 --shot build/shots/order.png

  # compare one region only (design pixel coordinates)
  ... --crop 0,180,841,560
"""

from __future__ import annotations

import argparse
import os
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit('Install the dev tools first: python3 -m venv tool/.venv && '
             'tool/.venv/bin/pip install pillow numpy')


def parse_box(value: str | None, n: int):
    if not value:
        return None
    parts = [int(float(p)) for p in value.split(',')]
    if len(parts) != n:
        raise argparse.ArgumentTypeError(f'expected {n} comma-separated numbers, got {value!r}')
    return tuple(parts)


def load_rgb(path: str) -> Image.Image:
    return Image.open(path).convert('RGB')


def fit_screenshot(design: Image.Image, shot: Image.Image, frame) -> tuple[Image.Image, Image.Image]:
    """Scale the screenshot so its width matches the design's phone screen."""
    if frame:
        x0, x1 = frame
        design = design.crop((x0, 0, x1, design.height))
    scale = design.width / shot.width
    shot = shot.resize((design.width, round(shot.height * scale)), Image.LANCZOS)
    height = min(design.height, shot.height)
    return design.crop((0, 0, design.width, height)), shot.crop((0, 0, design.width, height))


def label(img: Image.Image, text: str) -> Image.Image:
    bar = 28
    out = Image.new('RGB', (img.width, img.height + bar), (20, 24, 40))
    out.paste(img, (0, bar))
    draw = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype('Arial.ttf', 16)
    except OSError:
        font = ImageFont.load_default()
    draw.text((8, 5), text, fill=(255, 255, 255), font=font)
    return out


def diff_image(a: np.ndarray, b: np.ndarray, threshold: int) -> tuple[Image.Image, np.ndarray]:
    delta = np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2)
    mismatch = delta > threshold
    base = (a.astype(np.float32) * 0.25 + 190).clip(0, 255).astype(np.uint8)
    heat = base.copy()
    strength = np.clip(delta.astype(np.float32) * 3, 0, 255).astype(np.uint8)
    heat[..., 0] = np.where(mismatch, 255, base[..., 0])
    heat[..., 1] = np.where(mismatch, 255 - strength, base[..., 1])
    heat[..., 2] = np.where(mismatch, 255 - strength, base[..., 2])
    return Image.fromarray(heat), mismatch


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--design', required=True)
    parser.add_argument('--shot', required=True, help='device or golden screenshot (PNG)')
    parser.add_argument('--out', default='build/compare')
    parser.add_argument('--name', help='output file prefix (default: screenshot file name)')
    parser.add_argument('--design-frame', help='x0,x1 of the phone screen inside the design')
    parser.add_argument('--crop', help='x0,y0,x1,y1 region in fitted design coordinates')
    parser.add_argument('--shot-offset', type=int, default=0,
                        help='design px to shift the screenshot up, e.g. 20 when the device status bar '
                             'is taller than the one drawn in the design')
    parser.add_argument('--threshold', type=int, default=24, help='per-channel delta counted as mismatch')
    parser.add_argument('--bands', type=int, default=12, help='horizontal bands in the summary')
    args = parser.parse_args()

    frame = parse_box(args.design_frame, 2)
    crop = parse_box(args.crop, 4)

    design, shot = fit_screenshot(load_rgb(args.design), load_rgb(args.shot), frame)
    if args.shot_offset:
        shifted = Image.new('RGB', shot.size, (0, 0, 0))
        shifted.paste(shot, (0, -args.shot_offset))
        shot = shifted
    if crop:
        design, shot = design.crop(crop), shot.crop(crop)

    os.makedirs(args.out, exist_ok=True)
    name = args.name or os.path.splitext(os.path.basename(args.shot))[0]

    side = Image.new('RGB', (design.width * 2 + 12, design.height + 28), (20, 24, 40))
    side.paste(label(design, 'design'), (0, 0))
    side.paste(label(shot, 'app'), (design.width + 12, 0))
    side.save(os.path.join(args.out, f'{name}_side.png'))

    Image.blend(design, shot, 0.5).save(os.path.join(args.out, f'{name}_overlay.png'))

    a, b = np.asarray(design), np.asarray(shot)
    heat, mismatch = diff_image(a, b, args.threshold)
    heat.save(os.path.join(args.out, f'{name}_diff.png'))

    total = mismatch.mean() * 100
    print(f'{name}: {design.width}x{design.height}px, mismatch {total:.2f}% (threshold {args.threshold})')
    band = max(1, design.height // args.bands)
    for top in range(0, design.height, band):
        part = mismatch[top:top + band]
        if part.size:
            bar = '#' * int(round(part.mean() * 40))
            print(f'  y {top:5d}-{min(top + band, design.height):5d}  {part.mean() * 100:6.2f}%  {bar}')
    print(f'wrote {args.out}/{name}_side.png, _overlay.png, _diff.png')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
