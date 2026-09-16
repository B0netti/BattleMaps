"""Build and verify a clean, reproducible BattleMaps release archive."""
import argparse
import hashlib
import re
import struct
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


def clean_tga(data):
    if len(data) < 18:
        raise ValueError("Truncated TGA")
    header = bytearray(data[:18])
    image_type = header[2]
    width, height = struct.unpack_from('<HH', header, 12)
    pixel_bytes = (header[16] + 7) // 8
    palette_entries = struct.unpack_from('<H', header, 5)[0]
    palette_bytes = palette_entries * ((header[7] + 7) // 8) if header[1] else 0
    start = 18 + header[0]
    pos = start + palette_bytes
    count = width * height
    if not count or not pixel_bytes:
        raise ValueError("Invalid TGA dimensions")
    if image_type in (1, 2, 3):
        pos += count * pixel_bytes
    elif image_type in (9, 10, 11):
        remaining = count
        while remaining:
            packet = data[pos]
            pos += 1
            pixels = (packet & 127) + 1
            if pixels > remaining:
                raise ValueError("Invalid TGA packet")
            pos += pixel_bytes if packet & 128 else pixels * pixel_bytes
            remaining -= pixels
    else:
        raise ValueError(f"Unsupported TGA type {image_type}")
    if pos > len(data):
        raise ValueError("Truncated TGA pixels")
    header[0] = 0
    return bytes(header) + data[start:pos] + b'\0' * 8 + b'TRUEVISION-XFILE.\0'


def audit(path, data):
    suffix = Path(path).suffix.lower()
    if suffix == '.tga':
        if clean_tga(data) != data:
            raise ValueError(f"TGA metadata remains in {path}")
        return
    if suffix not in ('.lua', '.xml', '.toc', '.md', '.txt'):
        return
    risky = rb'(?i)\b[A-Z]:[\\/]|/(?:Users|home)/|AppData[\\/]|-----BEGIN [A-Z ]*PRIVATE KEY-----|https://(?:canary\.|ptb\.)?discord\.com/api/webhooks/'
    if re.search(risky, data):
        raise ValueError(f"Private path or credential pattern in {path}")


def build(root, output, version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError("Use a three-part numeric release version, for example 3.1.0")
    toc_path = root / 'BattleMaps.toc'
    toc = toc_path.read_text(encoding='utf-8-sig')
    version_match = re.search(r'^## Version:\s*(.+)$', toc, re.M)
    if not version_match or version_match.group(1).strip() != version:
        raise ValueError("Release version must match BattleMaps.toc")
    if '## Author: Bonetti' not in toc:
        raise ValueError("Unexpected public author")

    files = set()

    def add_load_file(rel):
        path = (root / rel.replace('\\', '/')).resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            raise ValueError(f"Missing or unsafe load file: {rel}")
        relative = path.relative_to(root.resolve())
        if relative in files:
            return
        files.add(relative)
        if path.suffix.lower() == '.xml':
            for node in ET.parse(path).iter():
                child = node.get('file')
                if child:
                    add_load_file(str(relative.parent / child.replace('\\', '/')))

    for line in toc.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith('#'):
            add_load_file(stripped)

    for name in ('BattleMaps.toc', 'Bindings.xml', 'CHANGELOG.md', 'README.md'):
        path = root / name
        if path.is_file():
            files.add(Path(name))

    for path in (root / 'Libs').rglob('*'):
        if path.is_file() and path.name.lower().startswith('license'):
            files.add(path.relative_to(root))

    allowed_media = {'.tga', '.blp', '.png', '.ttf', '.otf', '.ogg', '.mp3'}
    media_root = root / 'Media'
    if media_root.is_dir():
        for path in media_root.rglob('*'):
            if path.is_file() and path.suffix.lower() in allowed_media:
                files.add(path.relative_to(root))

    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'BattleMaps-{version}.zip'
    if archive.exists():
        raise FileExistsError("Refusing to overwrite an existing archive")

    hashes = {}
    with tempfile.TemporaryDirectory(prefix='battlemaps-stage-') as temp:
        stage = Path(temp) / 'BattleMaps'
        for rel in sorted(files):
            source = root / rel
            data = source.read_bytes()
            if source.suffix.lower() == '.tga':
                data = clean_tga(data)
            elif source.suffix.lower() in ('.lua', '.xml', '.toc', '.md', '.txt'):
                data = data.replace(b'\r\n', b'\n')
            audit(rel, data)
            dest = stage / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            hashes['BattleMaps/' + rel.as_posix()] = hashlib.sha256(data).hexdigest()

        with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as zf:
            for name in sorted(hashes):
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                zf.writestr(info, (Path(temp) / name).read_bytes())

        extracted = Path(temp) / 'verified'
        with zipfile.ZipFile(archive) as zf:
            assert zf.namelist() == sorted(hashes)
            assert zf.testzip() is None
            zf.extractall(extracted)
        for name, expected in hashes.items():
            data = (extracted / name).read_bytes()
            assert hashlib.sha256(data).hexdigest() == expected, name
            audit(name, data)

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / f'{archive.name}.sha256').write_text(f'{digest}  {archive.name}\n', encoding='utf-8')
    (output / 'manifest.txt').write_text(
        '\n'.join(f'{hashes[name]}  {name}' for name in sorted(hashes)) + '\n',
        encoding='utf-8',
    )
    changelog = (root / 'CHANGELOG.md').read_text(encoding='utf-8-sig')
    match = re.search(r'^##\s+' + re.escape(version) + r'\s*\n(.*?)(?=^##\s+|\Z)', changelog, re.M | re.S)
    if not match:
        raise ValueError("Missing release notes")
    (output / 'release-notes.md').write_text(match.group(1).strip() + '\n', encoding='utf-8')
    print(f'Verified {len(hashes)} files: {archive.name}\nSHA256 {digest}')
    return archive


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    build(args.root.resolve(), args.output.resolve(), args.version)
