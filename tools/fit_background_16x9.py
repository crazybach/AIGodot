from pathlib import Path

from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets" / "backgrounds" / "castle_lobby.png"
OUTPUT = PROJECT_ROOT / "assets" / "backgrounds" / "castle_lobby_16x9.png"
TARGET_SIZE = (1280, 720)


def resize_contain(image, size):
    scale = min(size[0] / image.width, size[1] / image.height)
    return image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.NEAREST)


def resize_cover(image, size):
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.NEAREST)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def main():
    source = Image.open(SOURCE).convert("RGBA")

    fill = resize_cover(source, TARGET_SIZE).filter(ImageFilter.BoxBlur(8))
    dim = Image.new("RGBA", TARGET_SIZE, (5, 10, 18, 118))
    fill = Image.alpha_composite(fill, dim)

    contained = resize_contain(source, TARGET_SIZE)
    x = (TARGET_SIZE[0] - contained.width) // 2
    y = (TARGET_SIZE[1] - contained.height) // 2
    fill.alpha_composite(contained, (x, y))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fill.save(OUTPUT)
    print(f"Saved {OUTPUT}")


if __name__ == "__main__":
    main()
