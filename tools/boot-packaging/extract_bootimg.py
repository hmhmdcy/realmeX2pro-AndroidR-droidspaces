#!/usr/bin/env python3
"""Extract kernel, ramdisk, dtb from Android boot image (header v0/v1/v2)."""
import struct, sys, os

def round_up(v, page):
    return (v + page - 1) & ~(page - 1)

def extract_bootimg(path, out_dir):
    with open(path, 'rb') as f:
        magic = f.read(8)
        assert magic == b'ANDROID!', f'Bad magic: {magic}'

        f.seek(8)
        kernel_sz = struct.unpack('<I', f.read(4))[0]
        f.seek(0x10)
        ramdisk_sz = struct.unpack('<I', f.read(4))[0]
        f.seek(0x18)
        second_sz = struct.unpack('<I', f.read(4))[0]
        f.seek(0x24)
        page_sz = struct.unpack('<I', f.read(4))[0]
        f.seek(0x28)
        header_ver = struct.unpack('<I', f.read(4))[0]

        if header_ver == 0:
            header_sz = page_sz * 2
        elif header_ver == 1:
            header_sz = page_sz * 2
        elif header_ver == 2:
            # v2: dtb_offset + dtb_size at header offsets 0x30+0x38
            header_sz = page_sz * 2
            f.seek(0x30)
            dtb_load_addr = struct.unpack('<Q', f.read(8))[0]
            f.seek(0x38)
            dtb_sz = struct.unpack('<I', f.read(4))[0]
        else:
            print(f'Unsupported header version: {header_ver}')
            sys.exit(1)

        os.makedirs(out_dir, exist_ok=True)

        # Kernel
        off = header_sz
        with open(f'{out_dir}/kernel', 'wb') as k:
            f.seek(off)
            k.write(f.read(kernel_sz))
        sz_kb = kernel_sz / 1024
        print(f'kernel: {kernel_sz} bytes ({sz_kb:.0f} KB)')

        # Ramdisk
        off = round_up(off + kernel_sz, page_sz)
        with open(f'{out_dir}/ramdisk.cpio.gz', 'wb') as r:
            f.seek(off)
            r.write(f.read(ramdisk_sz))
        sz_kb = ramdisk_sz / 1024
        print(f'ramdisk: {ramdisk_sz} bytes ({sz_kb:.0f} KB)')

        # Second
        off = round_up(off + ramdisk_sz, page_sz)
        if second_sz > 0:
            with open(f'{out_dir}/second', 'wb') as s:
                f.seek(off)
                s.write(f.read(second_sz))
            print(f'second: {second_sz} bytes')
            off = round_up(off + second_sz, page_sz)

        # DTB (header v2)
        if header_ver == 2 and dtb_sz > 0:
            # In v2, dtb is right after second (or ramdisk if no second)
            off = round_up(off, page_sz)
            # But actually, the dtb offset is explicitly in the header
            # Let's use the page-aligned position after second
            if second_sz == 0:
                off = round_up(off, page_sz)
            else:
                off = round_up(off, page_sz)
            with open(f'{out_dir}/dtb', 'wb') as d:
                f.seek(off)
                d.write(f.read(dtb_sz))
            sz_kb = dtb_sz / 1024
            print(f'dtb: {dtb_sz} bytes ({sz_kb:.1f} KB)')

        print(f'\nExtracted to {out_dir}/')
        print(f'  kernel           — use for AK3 or boot.img repack')
        print(f'  ramdisk.cpio.gz  — keep, reuse for future repacks')
        print(f'  dtb              — keep for repack (header v2)')

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <boot.img> [out_dir]')
        sys.exit(1)
    extract_bootimg(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'boot_extracted')
