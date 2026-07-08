#!/usr/bin/env python3
"""Repack an OpenMRS OMOD, replacing exactly one GSP fragment in place.

OMOD files are zip archives. The OpenMRS module loader walks zip *directory*
entries (names ending '/') to discover apps, so any structural drift silently
breaks app discovery (e.g. Find Patient disappears from the home page).

This repacker is a surgical single-entry replace: every original entry — file
OR directory — is copied through with its ZipInfo preserved exactly (name,
order, timestamp, external_attr, host system, compression), and only the target
GSP's bytes are substituted. Nothing is rebuilt from an os.walk, so there is no
way to lose entry order, directory entries, or attributes. A post-write check
asserts the namelist is byte-identical and that the target file is the only
content that changed (#28).

Usage:
    repack-omod.py SRC_OMOD NEW_GSP OUT_OMOD [--gsp-rel REL_PATH]

REL_PATH defaults to web/module/fragments/dashboardwidgets/fib4screening.gsp
"""
import argparse
import sys
import zipfile


DEFAULT_GSP_REL = "web/module/fragments/dashboardwidgets/fib4screening.gsp"


def repack(src_omod: str, new_gsp: str, out_omod: str, gsp_rel: str) -> None:
    with open(new_gsp, "rb") as f:
        new_bytes = f.read()

    with zipfile.ZipFile(src_omod, "r") as zin:
        if gsp_rel not in zin.namelist():
            sys.exit(f"ERROR: target not found in OMOD: {gsp_rel}")
        with zipfile.ZipFile(out_omod, "w") as zout:
            for info in zin.infolist():
                # Copy the original ZipInfo through unchanged so directory
                # entries, ordering, timestamps and attributes are preserved;
                # only swap the bytes of the one file we are patching.
                data = new_bytes if info.filename == gsp_rel else zin.read(info.filename)
                zout.writestr(info, data)

    # Verify: identical namelist and only the target's content changed.
    with zipfile.ZipFile(src_omod) as a, zipfile.ZipFile(out_omod) as b:
        if a.namelist() != b.namelist():
            sys.exit("ERROR: namelist drift — refusing to ship a broken OMOD")
        changed = [n for n in a.namelist() if a.read(n) != b.read(n)]
        total = len(a.namelist())
    if changed != [gsp_rel]:
        sys.exit(f"ERROR: expected only {gsp_rel} to change, but changed={changed}")
    print(f"Wrote {out_omod}: surgically replaced {gsp_rel}")
    print(f"Namelist identical ({total} entries); 1 file changed, 0 drift")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("src_omod")
    p.add_argument("new_gsp")
    p.add_argument("out_omod")
    p.add_argument("--gsp-rel", default=DEFAULT_GSP_REL)
    args = p.parse_args()
    repack(args.src_omod, args.new_gsp, args.out_omod, args.gsp_rel)


if __name__ == "__main__":
    main()
