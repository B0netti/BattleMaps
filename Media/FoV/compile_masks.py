"""Compile editable FoV mask TGAs into live rectangle geometry and test assets.

Run with the bundled/workspace Python environment, which provides Pillow:

    python Media/FoV/compile_masks.py --write-assets --check

The unsuffixed ``core_mask.tga`` and ``terrain_mask.tga`` files are authoring
inputs. Generated ``*_mask_live.tga`` files are exact binary-alpha rectangle
unions and are the assets Test Mode loads. The encoded Lua geometry drives the
equivalent clipped UnitPositionFrames in a live battleground.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageStat


ADDON_ROOT = Path(__file__).resolve().parents[2]
MASK_ROOT = ADDON_ROOT / "Media" / "FoV" / "Masks"
UNIT_PINS_PATH = ADDON_ROOT / "Pins" / "UnitPins.lua"
KINDS = ("core", "terrain")
GRID_CANDIDATES = (
    (24, 16),
    (32, 21),
    (40, 27),
    (48, 32),
    (56, 37),
    (64, 43),
)
MAX_RECTANGLES_PER_LAYER = 32
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_~"


@dataclass(frozen=True)
class Geometry:
    encoded: str
    summary: str
    columns: int
    rows: int
    rectangles: tuple[tuple[int, int, int, int], ...]


def compile_runs(alpha: Image.Image, columns: int, rows: int) -> list[list[int]]:
    source_width, source_height = alpha.size
    grid: list[list[bool]] = []
    for row in range(rows):
        y0 = round(row * source_height / rows)
        y1 = round((row + 1) * source_height / rows)
        values: list[bool] = []
        for column in range(columns):
            x0 = round(column * source_width / columns)
            x1 = round((column + 1) * source_width / columns)
            mean_alpha = ImageStat.Stat(alpha.crop((x0, y0, x1, y1))).mean[0]
            values.append(mean_alpha >= 127.5)
        grid.append(values)

    rectangles: list[list[int]] = []
    active: dict[tuple[int, int], list[int]] = {}
    for row, values in enumerate(grid):
        runs: list[tuple[int, int]] = []
        start = 0
        while start < columns:
            value = values[start]
            end = start + 1
            while end < columns and values[end] == value:
                end += 1
            if value:
                runs.append((start, end))
            start = end

        current: dict[tuple[int, int], list[int]] = {}
        for start, end in runs:
            key = (start, end)
            rectangle = active.pop(key, None)
            if rectangle is None:
                rectangle = [start, row, end - start, 1]
            else:
                rectangle[3] += 1
            current[key] = rectangle
        rectangles.extend(active.values())
        active = current
    rectangles.extend(active.values())
    return rectangles


def choose_geometry(alpha: Image.Image) -> tuple[int, int, list[list[int]]]:
    selected: tuple[int, int, list[list[int]]] | None = None
    for columns, rows in GRID_CANDIDATES:
        rectangles = compile_runs(alpha, columns, rows)
        if len(rectangles) <= MAX_RECTANGLES_PER_LAYER:
            selected = columns, rows, rectangles
    if selected is None:
        columns, rows = GRID_CANDIDATES[0]
        rectangles = compile_runs(alpha, columns, rows)
        raise ValueError(
            f"mask requires {len(rectangles)} rectangles at the minimum "
            f"{columns}x{rows} grid; maximum is {MAX_RECTANGLES_PER_LAYER}"
        )
    return selected


def encode_component(value: int) -> str:
    if value < 0 or value >= len(ALPHABET):
        raise ValueError(f"component {value} is outside the encoding alphabet")
    return ALPHABET[value]


def encode_geometry(columns: int, rows: int, rectangles: list[list[int]]) -> str:
    encoded_rectangles = "".join(
        "".join(encode_component(component) for component in rectangle)
        for rectangle in rectangles
    )
    return f"{columns}x{rows}:{encoded_rectangles}"


def compile_mask(path: Path) -> Geometry:
    alpha = Image.open(path).convert("RGBA").getchannel("A")
    extrema = alpha.getextrema()
    if extrema == (255, 255):
        return Geometry("full", "full/1 clip", 1, 1, ((0, 0, 1, 1),))
    if extrema == (0, 0):
        return Geometry("empty", "empty/0 clips", 1, 1, ())

    columns, rows, rectangle_lists = choose_geometry(alpha)
    if not rectangle_lists:
        return Geometry("empty", "empty/0 clips", 1, 1, ())
    if rectangle_lists == [[0, 0, columns, rows]]:
        return Geometry("full", "full/1 clip", 1, 1, ((0, 0, 1, 1),))

    rectangles = tuple(tuple(rectangle) for rectangle in rectangle_lists)
    encoded = encode_geometry(columns, rows, rectangle_lists)
    return Geometry(
        encoded,
        f"{len(rectangles)} clips @ {columns}x{rows}",
        columns,
        rows,
        rectangles,
    )


def write_runtime_mask(source_path: Path, geometry: Geometry) -> Path:
    with Image.open(source_path) as source:
        width, height = source.size

    output = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    draw = ImageDraw.Draw(output)
    for x, y, rectangle_width, rectangle_height in geometry.rectangles:
        x0 = round(x * width / geometry.columns)
        y0 = round(y * height / geometry.rows)
        x1 = round((x + rectangle_width) * width / geometry.columns)
        y1 = round((y + rectangle_height) * height / geometry.rows)
        draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill=(255, 255, 255, 255))

    output_path = source_path.with_name(source_path.stem + "_live.tga")
    output.save(output_path, compression="tga_rle")

    with Image.open(output_path) as generated:
        generated_alpha = generated.convert("RGBA").getchannel("A")
        generated_rectangles = tuple(
            tuple(rectangle)
            for rectangle in compile_runs(
                generated_alpha,
                geometry.columns,
                geometry.rows,
            )
        )
    if generated_rectangles != geometry.rectangles:
        raise RuntimeError(
            f"generated asset {output_path} does not reproduce its "
            f"{geometry.columns}x{geometry.rows} rectangle union"
        )
    return output_path


def read_embedded_geometry() -> dict[str, dict[str, str]]:
    unit_pins = UNIT_PINS_PATH.read_text(encoding="utf-8")
    source_block = unit_pins.split(
        "local PLAYER_FOV_LIVE_MASK_GEOMETRY_SOURCE = {", 1
    )[1].split("local function DecodePlayerFovLiveMaskGeometry", 1)[0]
    embedded: dict[str, dict[str, str]] = {}
    for set_name, body in re.findall(r"\s+(\w+)\s*=\s*\{(.*?)\n\s*\},", source_block, re.S):
        embedded[set_name] = dict(
            re.findall(r'(core|terrain)\s*=\s*"([^"]+)"', body)
        )
    return embedded


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write-assets",
        action="store_true",
        help="write binary-alpha *_mask_live.tga rectangle-union assets",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit unsuccessfully when the embedded Lua geometry differs",
    )
    args = parser.parse_args()

    expected: dict[str, dict[str, str]] = {}
    total_rectangles = 0
    print("local PLAYER_FOV_LIVE_MASK_GEOMETRY_SOURCE = {")
    for folder in sorted(path for path in MASK_ROOT.iterdir() if path.is_dir()):
        print(f"    {folder.name} = {{")
        summaries: list[str] = []
        expected[folder.name] = {}
        for kind in KINDS:
            source_path = folder / f"{kind}_mask.tga"
            geometry = compile_mask(source_path)
            expected[folder.name][kind] = geometry.encoded
            print(f'        {kind} = "{geometry.encoded}",')
            summaries.append(f"{kind}={geometry.summary}")
            total_rectangles += len(geometry.rectangles)
            if args.write_assets:
                write_runtime_mask(source_path, geometry)
        print("    },")
        print("    -- " + ", ".join(summaries))
    print("}")
    print(f"-- Total active native clips across every map definition: {total_rectangles}")

    embedded = read_embedded_geometry()
    matches = embedded == expected
    print("-- Embedded geometry:", "MATCH" if matches else "MISMATCH")
    if not matches:
        print("-- Embedded:", embedded)
        print("-- Expected:", expected)
    return 1 if args.check and not matches else 0


if __name__ == "__main__":
    raise SystemExit(main())
