#!/usr/bin/env python3

# I love you, Dan <3
# Do note that this doesn't check if the files exist yet
# Didn't think it was needed for something that is hacked together

#from collections import namedtuple
import subprocess
import os

def write_size(handle, size):
    handle.write(size.to_bytes(4, byteorder="little"))

def write_bytes(handle, len, data = 0x00):
    handle.write(bytes([data] * len))

def check_padding(entry_len):
    # Check if we need to add any padding
    entry_padding = entry_len % 16
    if entry_padding != 0:
        entry_padding = 16 - entry_padding
    return entry_padding

def print_entry(file_name, current_address, tell):
    print("%s at %s (len = %s)" % (file_name.decode("utf-8"), hex(current_address), hex(tell - current_address)))

initial_files = [
"RESET.bin",
"ROMDIR.stub",
"ROMVER.txt",
"PILLGEN.elf"
]

romdir = open("romdir.bin", "wb")
rom = open("rom.bin", "wb")

romdir_stub_addr = -1
rom_stub_addr = -1

for file_path in initial_files:
    file_path = "bin/" + file_path

    file_split = os.path.splitext(os.path.basename(file_path))
    file_ext = file_split[1].lower()
    file_name = file_split[0].upper().encode("ascii")

    file_name_len = len(file_name)
    assert file_name_len < 11, "Filename is too long"

    # Calculate padding
    padding_len = 10 - file_name_len

    # Write filename
    romdir.write(file_name)
    write_bytes(romdir, padding_len)

    # Write unknown bytes
    write_bytes(romdir, 2)

    apparent_romdir_size = (len(initial_files) + 1) * 16

    # Write size
    if file_ext == ".txt" or file_ext == ".bin" or file_ext == ".elf": # We probably don't need this anymore but oh well
        current_address = rom.tell()
        file = open(file_path, "rb")

        # Append the entry to rom.bin
        # Files are going to be small enough to fit in ram
        # We also do not need to seek
        rom.write(file.read())
        file_len = file.tell()

        file.close()
        entry_padding = check_padding(file_len)
        write_bytes(rom, entry_padding, 0xFE)
        print_entry(file_name, current_address, rom.tell())
        write_size(romdir, file_len + entry_padding)
    elif file_ext == ".stub":
        romdir_stub_addr = romdir.tell()
        write_bytes(romdir, 4)
        rom_stub_addr = rom.tell()
        # Calculate the size of romdir.bin in advance and write the stub
        write_bytes(rom, apparent_romdir_size, 0xDD)
        print_entry(file_name, rom_stub_addr, rom.tell())
    else:
        print("Unrecognised file extension " + file_ext + " for " + file_path)
        write_bytes(romdir, 4)

# Write the final all-zero entry
write_bytes(romdir, 16)

if romdir_stub_addr == -1:
    print("WARNING: No ROMDIR stub was found in initial_files. It will be marked as having a size of 0x00")
else:
    # First, seek to the end to get the size of the finished file
    # We will be at the end...
    #romdir.seek(0, os.SEEK_END)
    romdir_size = romdir.tell()
    # Close the file and open as r+b
    romdir.close()
    romdir = open("romdir.bin", "r+b")
    # Then, seek to the stub and overwrite it
    romdir.seek(romdir_stub_addr)
    romdir.write(romdir_size.to_bytes(4, byteorder="little"))

    # Now do the same for romdir.bin in rom.bin
    rom.close()
    rom = open("rom.bin", "r+b")
    # Seek both files to prepare them
    rom.seek(rom_stub_addr)
    romdir.seek(0)
    # Write one to another
    rom.write(romdir.read())

rom.seek(0, os.SEEK_END)
# Pad to 0x400000
print("Used space: {} / {} bytes ({:3f}%)".format(rom.tell(), 0x400000, 100*rom.tell()/0x400000))
write_bytes(rom, 0x400000 - rom.tell())

rom.close()
romdir.close()
