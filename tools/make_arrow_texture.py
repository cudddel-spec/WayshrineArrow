"""Draws the arrow textures (uncompressed 32-bit BGRA DDS):
  textures/arrow.dds       the arrow, white with a darker rim
  textures/arrow_body.dds  the same shape without rim, for the copies that form the side of the arrow

Usage (from the repository folder):  python tools/make_arrow_texture.py [preview.png]

The arrow is a navigation arrow pointing up (north), white with a darker rim, so the addon can tint it with
SetColor. It has no light direction drawn in: the texture is rotated freely, and a drawn highlight would turn
with it (seen from below when the arrow points backwards). The 3D look comes from the addon (tilt and copies).
"""
import os
import struct
import sys
import zlib

SIZE = 128
MIP_LEVELS = 2            # only the largest mipmaps: on a tilted control the game picks far too small ones
SAMPLES = 8               # supersampling per axis for smooth edges
RIM_WIDTH = 0.035         # width of the darker rim, relative to the texture size
RIM_GRAY = 0.35           # brightness of the rim (multiplied with the arrow color in game)

# tip, right corner, notch, left corner (x to the right, y down, 0..1)
POLYGON = [(0.5, 0.06), (0.84, 0.88), (0.5, 0.70), (0.16, 0.88)]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "textures", "arrow.dds")
OUTPUT_BODY = os.path.join(ROOT, "textures", "arrow_body.dds")


def centered(points):
    """Moves the polygon so that its area centroid lies in the middle: the texture rotates around it."""
    area = cx = cy = 0.0
    for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1]):
        cross = x1 * y2 - x2 * y1
        area += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    cx, cy = cx / (3 * area), cy / (3 * area)
    return [(x + 0.5 - cx, y + 0.5 - cy) for x, y in points]


def inside(points, x, y):
    result = False
    for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            result = not result
    return result


def edge_distance(points, x, y):
    best = 1.0
    for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1]):
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        px, py = x1 + t * dx - x, y1 + t * dy - y
        best = min(best, (px * px + py * py) ** 0.5)
    return best


def draw(points, rim_gray):
    """Returns rows of (gray, alpha) pairs, both 0..1."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    pixels = []
    for row in range(SIZE):
        line = []
        for col in range(SIZE):
            coverage = gray_sum = 0.0
            if min(xs) - 0.01 <= (col + 1) / SIZE and (col / SIZE) <= max(xs) + 0.01 \
                    and min(ys) - 0.01 <= (row + 1) / SIZE and (row / SIZE) <= max(ys) + 0.01:
                for sy in range(SAMPLES):
                    for sx in range(SAMPLES):
                        x = (col + (sx + 0.5) / SAMPLES) / SIZE
                        y = (row + (sy + 0.5) / SAMPLES) / SIZE
                        if inside(points, x, y):
                            coverage += 1
                            gray_sum += rim_gray if edge_distance(points, x, y) < RIM_WIDTH else 1.0
            n = SAMPLES * SAMPLES
            line.append((gray_sum / coverage if coverage else 0.0, coverage / n))
        pixels.append(line)
    return pixels


def downsample(pixels):
    size = len(pixels) // 2
    result = []
    for row in range(size):
        line = []
        for col in range(size):
            block = [pixels[2 * row + r][2 * col + c] for r in (0, 1) for c in (0, 1)]
            alpha = sum(a for _, a in block)
            gray = sum(g * a for g, a in block) / alpha if alpha else 0.0
            line.append((gray, alpha / 4))
        result.append(line)
    return result


def to_bgra(pixels):
    data = bytearray()
    for line in pixels:
        for gray, alpha in line:
            g = round(gray * 255)
            data += bytes((g, g, g, round(alpha * 255)))
    return bytes(data)


def write_dds(path, levels):
    size = len(levels[0])
    flags = 0x1 | 0x2 | 0x4 | 0x8 | 0x1000 | 0x20000      # caps, height, width, pitch, pixel format, mipmap count
    pixel_format = struct.pack("<8I", 32, 0x41, 0, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
    caps = 0x1000 | 0x8 | 0x400000                        # texture, complex, mipmap
    header = struct.pack("<7I", 124, flags, size, size, size * 4, 0, len(levels)) + b"\0" * 44 \
        + pixel_format + struct.pack("<5I", caps, 0, 0, 0, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"DDS " + header)
        for level in levels:
            f.write(to_bgra(level))


def write_png(path, pixels, background=(90, 120, 160)):
    """Preview on a colored background, tinted light blue like the known-wayshrine color."""
    tint = (0.45, 0.85, 1.0)
    raw = bytearray()
    for line in pixels:
        raw.append(0)
        for gray, alpha in line:
            for channel in range(3):
                value = gray * tint[channel] * 255 * alpha + background[channel] * (1 - alpha)
                raw.append(round(value))
    size = len(pixels)

    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    points = centered(POLYGON)
    for path, rim_gray in ((OUTPUT, RIM_GRAY), (OUTPUT_BODY, 1.0)):
        levels = [draw(points, rim_gray)]
        while len(levels) < MIP_LEVELS:
            levels.append(downsample(levels[-1]))
        write_dds(path, levels)
        print(f"Wrote {path} ({SIZE}x{SIZE}, {len(levels)} mipmap levels)")
        if path == OUTPUT and len(sys.argv) > 1:
            write_png(sys.argv[1], levels[0])
            print(f"Preview {sys.argv[1]}")


if __name__ == "__main__":
    main()
