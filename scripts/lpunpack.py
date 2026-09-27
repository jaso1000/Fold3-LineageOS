#!/usr/bin/env python3
"""Minimal lpunpack: extract logical partitions from a raw (non-sparse) Android super image.

Usage: lpunpack.py super.raw OUTDIR [partition ...]
Reads the primary LP metadata (geometry at 4096, metadata at 8192) and copies each partition's
linear extents out. Enough for Samsung's super.img (after simg2img).
"""
import os
import struct
import sys

LP_SECTOR = 512


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    wanted = set(sys.argv[3:])
    os.makedirs(outdir, exist_ok=True)
    with open(src, "rb") as f:
        f.seek(4096)
        geo = f.read(4096)
        magic, struct_size = struct.unpack_from("<II", geo, 0)
        assert magic == 0x616C4467, "no LP geometry"
        metadata_max_size, slot_count, logical_block_size = struct.unpack_from("<III", geo, 40)
        f.seek(4096 * 3)  # 2 geometry copies (4096 each) after the 4096 reserved
        hdr = f.read(metadata_max_size)
        magic, major, minor, header_size = struct.unpack_from("<IHHI", hdr, 0)
        assert magic == 0x414C5030, "no LP metadata header"
        # tables descriptor: offset, num_entries, entry_size (x4: partitions, extents, groups, devices)
        tbl = struct.unpack_from("<12I", hdr, 80)
        base = header_size
        p_off, p_num, p_sz = tbl[0:3]
        e_off, e_num, e_sz = tbl[3:6]
        parts = []
        for i in range(p_num):
            o = base + p_off + i * p_sz
            name = hdr[o:o + 36].split(b"\0")[0].decode()
            attrs, first_extent, num_extents, group = struct.unpack_from("<IIII", hdr, o + 36)
            parts.append((name, first_extent, num_extents))
        extents = []
        for i in range(e_num):
            o = base + e_off + i * e_sz
            num_sectors, target_type, target_data, target_source = struct.unpack_from("<QIQI", hdr, o)
            extents.append((num_sectors, target_type, target_data))
        for name, first, num in parts:
            size = sum(extents[first + k][0] for k in range(num)) * LP_SECTOR
            print(f"{name}: {size} bytes, {num} extent(s)")
            if wanted and name not in wanted:
                continue
            with open(os.path.join(outdir, name + ".img"), "wb") as out:
                for k in range(num):
                    sectors, ttype, tdata = extents[first + k]
                    if ttype == 0:  # LINEAR
                        f.seek(tdata * LP_SECTOR)
                        left = sectors * LP_SECTOR
                        while left:
                            chunk = f.read(min(left, 64 << 20))
                            out.write(chunk)
                            left -= len(chunk)
                    else:  # ZERO
                        out.write(b"\0" * (sectors * LP_SECTOR))


if __name__ == "__main__":
    main()
