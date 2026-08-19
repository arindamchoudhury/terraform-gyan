"""Scan a saved plan file for canary strings, entry by entry.

    python scan-plan.py tfplan AKIALEAKCANARY01 s3cr3t-canary-value-9f2a

A plan file is a zip archive. Searching its bytes directly finds nothing,
because every entry is deflated; each entry has to be decompressed first.
"""
import sys, zipfile

path, canaries = sys.argv[1], [c.encode() for c in sys.argv[2:]]

with open(path, "rb") as fh:
    raw = fh.read()
print(f"{path}: {len(raw)} bytes")
print(f"raw byte search: {'FOUND' if any(c in raw for c in canaries) else 'nothing'}\n")

with zipfile.ZipFile(path) as z:
    for name in z.namelist():
        body = z.read(name)
        hits = [c.decode() for c in canaries if c in body]
        print(f"  {name:24} {len(body):6} B  {'LEAK: ' + ', '.join(hits) if hits else 'clean'}")
