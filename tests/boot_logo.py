"""boot logo helper: masks, composed PNGs in the theme's ink, theme colours, status."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

SCRIPT = Path(__file__).resolve().parents[1] / 'bin/boot-logo.py'
spec = importlib.util.spec_from_file_location('boot_logo', SCRIPT)
bl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bl)


def decode(data):
    """(w, h, rgba) of a PNG written by boot-logo.py (filter 0 rows)."""
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w, h = 8, b'', 0, 0
    while pos < len(data):
        n = struct.unpack('>I', data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        crc = struct.unpack('>I', data[pos + 8 + n:pos + 12 + n])[0]
        assert crc == zlib.crc32(kind + body) & 0xffffffff, kind
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            assert (depth, ctype) == (8, 6)
        elif kind == b'IDAT':
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    assert len(raw) == h * (1 + 4 * w)
    rows = [raw[y * (1 + 4 * w):(y + 1) * (1 + 4 * w)] for y in range(h)]
    assert all(r[0] == 0 for r in rows)
    return w, h, b''.join(r[1:] for r in rows)


class BootLogo(unittest.TestCase):
    def test_masks(self):
        for logo in bl.LOGOS:
            w, h, alpha = bl.read_mask(logo)
            self.assertEqual((w, h), (240, 240))
            ink = sum(1 for a in alpha if a > 127)
            self.assertGreater(ink, 10000, logo)
            # nothing touches the canvas edge (5 px margin for the antialiasing)
            for y in (0, h - 1):
                self.assertEqual(max(alpha[y * w:(y + 1) * w]), 0, logo)

    def test_compose_in_the_theme_ink(self):
        for logo in bl.LOGOS:
            w, h, data = bl.compose(logo, '#2b2924')
            dw, dh, rgba = decode(data)
            self.assertEqual((dw, dh), (w, h))
            _, _, alpha = bl.read_mask(logo)
            self.assertEqual(rgba[3::4], alpha, 'the mask unchanged')
            self.assertEqual(set(rgba[0::4]), {0x2b})
            self.assertEqual(set(rgba[1::4]), {0x29})
            self.assertEqual(set(rgba[2::4]), {0x24})
        with self.assertRaises(ValueError):
            bl.compose('arch', 'red')

    def test_theme_colors_and_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / 'colors.toml').write_text('accent = "#123456"\nbackground = "#dfdacb"\nforeground = "#2b2924"\n')
            self.assertEqual(bl.theme_colors(tmp), ('#dfdacb', '#2b2924'))
            state = tmp / 'state'; state.mkdir()
            _, _, data = bl.compose('nerdibeard', '#2b2924')
            (state / 'nerdibeard-papier-lavur.png').write_bytes(data)
            installed = tmp / 'logo.png'; installed.write_bytes(data)
            bl.STATE, bl.INSTALLED = state, installed
            self.assertEqual(bl.status(), 'nerdibeard (papier-lavur colours)')


if __name__ == '__main__':
    unittest.main()
