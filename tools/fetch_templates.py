"""Extract just Windows templates from the official remote ZIP using byte ranges."""
import io
import pathlib
import struct
import urllib.request
import zipfile
import zlib

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
OUT = pathlib.Path(__file__).resolve().parent

def get_range(url, start, end):
    request = urllib.request.Request(url, headers={'Range': f'bytes={start}-{end}', 'User-Agent': 'GravityFour-Build'})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f'Range not supported: {response.status}')
        return response.read(), response.headers.get('Content-Range'), response.url

# GitHub resolves the release asset to a signed CDN URL.
tail, content_range, direct_url = get_range(URL, 1281349702 - 65536, 1281349702 - 1)
eocd = tail.rfind(b'PK\x05\x06')
_, _, _, _, _, cd_size, cd_offset, _ = struct.unpack_from('<4s4H2IH', tail, eocd)
directory, _, _ = get_range(direct_url, cd_offset, cd_offset + cd_size - 1)
offset = 0
while offset < len(directory):
    header = struct.unpack_from('<4s6H3I5H2I', directory, offset)
    if header[0] != b'PK\x01\x02':
        raise RuntimeError('Invalid central directory')
    method, crc, compressed_size, uncompressed_size = header[4], header[7], header[8], header[9]
    name_len, extra_len, comment_len, local_offset = header[10], header[11], header[12], header[16]
    name = directory[offset + 46:offset + 46 + name_len].decode()
    if name.endswith(('windows_release_x86_64.exe', 'windows_debug_x86_64.exe')):
        local_header, _, _ = get_range(direct_url, local_offset, local_offset + 29)
        local_name_len, local_extra_len = struct.unpack_from('<HH', local_header, 26)
        data_start = local_offset + 30 + local_name_len + local_extra_len
        compressed, _, _ = get_range(direct_url, data_start, data_start + compressed_size - 1)
        data = zlib.decompress(compressed, -15) if method == 8 else compressed
        if len(data) != uncompressed_size or zlib.crc32(data) != crc:
            raise RuntimeError('Template checksum mismatch')
        target = OUT / pathlib.PurePosixPath(name).name
        target.write_bytes(data)
        print(f'Extracted {target.name}: {len(data)} bytes', flush=True)
    offset += 46 + name_len + extra_len + comment_len
