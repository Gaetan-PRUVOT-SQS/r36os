#!/usr/bin/env python3
"""Emballe un cpio gzip dans l'en-tête legacy que le chargeur de la R36 Max attend."""

import gzip
import struct
import sys
import time
import zlib

IH_MAGIC = 0x27051956
IH_OS_LINUX = 5
IH_ARCH_ARM = 2
IH_TYPE_RAMDISK = 3
IH_COMP_GZIP = 1
NAME = b"uInitrd"


def main() -> None:
    if len(sys.argv) != 3:
        sys.stderr.write("usage: pack-uinitrd.py cpio uInitrd\n")
        sys.exit(2)
    raw = open(sys.argv[1], "rb").read()
    payload = gzip.compress(raw, mtime=0)
    header = bytearray(64)
    struct.pack_into(">IIIIIIIBBBB", header, 0,
                     IH_MAGIC, 0, int(time.time()), len(payload),
                     0, 0, zlib.crc32(payload) & 0xFFFFFFFF,
                     IH_OS_LINUX, IH_ARCH_ARM, IH_TYPE_RAMDISK, IH_COMP_GZIP)
    header[32:32 + len(NAME)] = NAME
    struct.pack_into(">I", header, 4, zlib.crc32(header) & 0xFFFFFFFF)
    open(sys.argv[2], "wb").write(header + payload)


if __name__ == "__main__":
    main()
