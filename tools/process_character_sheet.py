from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "raw" / "Character.png"
OUTPUT = PROJECT_ROOT / "assets" / "characters" / "Character_processed.png"
SOURCE_COLUMNS = 8
SOURCE_ROWS = 8
OUTPUT_COLUMNS = 8
OUTPUT_ROWS = 6
CELL_SIZE = 128

# Frame allocation for the platform prototype:
# idle 0-7, left_walk 8-15, right_walk 16-23, jump 24-27,
# block 28-35, attack 36-47.
ANIMATION_PLAN = [
    ("idle", list(range(0, 8)), False),
    ("left_walk", list(range(0, 8)), True),
    ("right_walk", list(range(0, 8)), False),
    ("jump", [1, 5, 7, 15], False),
    ("block", list(range(24, 32)), False),
    ("attack", list(range(8, 20)), False),
]


def is_high_confidence_figure(pixel):
    r, g, b, a = pixel
    if a == 0:
        return False

    rgb = (r, g, b)
    brightness = max(rgb)
    saturation = max(rgb) - min(rgb)

    if brightness > 155:
        return True
    if saturation > 58 and not (b > r + 24 and b > g + 8):
        return True
    if r > 82 and r >= b - 12:
        return True
    if g > 82 and b > 70 and r < 80:
        return True

    return False


def keep_largest_figure_region(mask):
    width, height = mask.size
    source = mask.load()
    visited = set()
    best_component = []

    for start_y in range(height):
        for start_x in range(width):
            if source[start_x, start_y] == 0 or (start_x, start_y) in visited:
                continue

            component = []
            queue = deque([(start_x, start_y)])

            while queue:
                x, y = queue.popleft()
                if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
                    continue
                if source[x, y] == 0:
                    continue

                visited.add((x, y))
                component.append((x, y))
                queue.append((x + 1, y))
                queue.append((x - 1, y))
                queue.append((x, y + 1))
                queue.append((x, y - 1))

            if len(component) > len(best_component):
                best_component = component

    output = Image.new("L", mask.size, 0)
    output_pixels = output.load()
    for x, y in best_component:
        output_pixels[x, y] = 255

    return output


def remove_edge_connected_noise(mask):
    width, height = mask.size
    source = mask.load()
    visited = set()
    queue = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    output = mask.copy()
    output_pixels = output.load()

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
            continue

        visited.add((x, y))
        if source[x, y] == 0:
            continue

        output_pixels[x, y] = 0
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    return output


def fill_interior_mask_holes(alpha):
    width, height = alpha.size
    source = alpha.load()
    outside = Image.new("L", (width, height), 0)
    outside_pixels = outside.load()
    queue = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        if outside_pixels[x, y] or source[x, y] != 0:
            continue

        outside_pixels[x, y] = 255
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    result = Image.new("L", (width, height), 0)
    result_pixels = result.load()
    for y in range(height):
        for x in range(width):
            if source[x, y] != 0 or outside_pixels[x, y] == 0:
                result_pixels[x, y] = 255

    return result


def apply_figure_alpha(cell):
    cell = cell.convert("RGBA")
    alpha = Image.new("L", cell.size, 0)
    alpha_pixels = alpha.load()
    pixels = cell.load()

    for y in range(cell.height):
        for x in range(cell.width):
            if is_high_confidence_figure(pixels[x, y]):
                alpha_pixels[x, y] = 255

    alpha = alpha.filter(ImageFilter.MaxFilter(5))
    alpha = keep_largest_figure_region(alpha)
    alpha = fill_interior_mask_holes(alpha)
    alpha = alpha.filter(ImageFilter.MinFilter(5))
    alpha = remove_edge_connected_noise(alpha)
    alpha = fill_interior_mask_holes(alpha)

    output = cell.copy()
    output.putalpha(alpha)
    return output


def force_binary_alpha(cell):
    pixels = cell.load()
    for y in range(cell.height):
        for x in range(cell.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255 if a else 0)
    return cell


def trim_to_content(cell):
    alpha = cell.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return cell
    return cell.crop(bbox)


def normalize_cell(cell, mirror=False, bob_offset=0):
    if mirror:
        cell = cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    cell = apply_figure_alpha(cell)
    cell = trim_to_content(cell)

    max_width = 112
    max_height = 116
    scale = min(max_width / cell.width, max_height / cell.height, 1.0)
    if scale != 1.0:
        cell = cell.resize((round(cell.width * scale), round(cell.height * scale)), Image.Resampling.NEAREST)

    output = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    x = (CELL_SIZE - cell.width) // 2
    y = CELL_SIZE - cell.height - 6 + bob_offset
    output.alpha_composite(cell, (x, y))
    return force_binary_alpha(output)


def source_frame(source, frame_index):
    column = frame_index % SOURCE_COLUMNS
    row = frame_index // SOURCE_COLUMNS
    left = round(column * source.width / SOURCE_COLUMNS)
    top = round(row * source.height / SOURCE_ROWS)
    right = round((column + 1) * source.width / SOURCE_COLUMNS)
    bottom = round((row + 1) * source.height / SOURCE_ROWS)
    return source.crop((left, top, right, bottom))


def main():
    source = Image.open(SOURCE).convert("RGBA")
    output = Image.new("RGBA", (OUTPUT_COLUMNS * CELL_SIZE, OUTPUT_ROWS * CELL_SIZE), (0, 0, 0, 0))

    out_index = 0
    for animation_name, frames, mirror in ANIMATION_PLAN:
        for local_index, source_index in enumerate(frames):
            bob = 0
            if animation_name in ("left_walk", "right_walk"):
                bob = -3 if local_index in (1, 2, 5, 6) else 0
            if animation_name == "jump":
                bob = [-8, -14, -10, -4][local_index]

            cell = normalize_cell(source_frame(source, source_index), mirror=mirror, bob_offset=bob)
            x = (out_index % OUTPUT_COLUMNS) * CELL_SIZE
            y = (out_index // OUTPUT_COLUMNS) * CELL_SIZE
            output.alpha_composite(cell, (x, y))
            out_index += 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT)
    print(f"Saved {OUTPUT}")
    print("Frame ranges: idle 0-7, left_walk 8-15, right_walk 16-23, jump 24-27, block 28-35, attack 36-47")


if __name__ == "__main__":
    main()
