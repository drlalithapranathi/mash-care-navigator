#!/usr/bin/env python3
"""Repack an OpenMRS OMOD with a replaced GSP fragment.

OMOD files are zip archives. The OpenMRS module loader walks zip
*directory* entries (filenames ending '/') to discover apps. A naive
zipfile.write() loop emits only file entries and silently breaks app
discovery (e.g. Find Patient disappears from the home page). This
repacker preserves directory entries explicitly.

Usage:
    repack-omod.py SRC_OMOD NEW_GSP OUT_OMOD [--gsp-rel REL_PATH]

REL_PATH defaults to web/module/fragments/dashboardwidgets/fib4screening.gsp
"""
import argparse
import os
import shutil
import sys
import tempfile
import zipfile


DEFAULT_GSP_REL = "web/module/fragments/dashboardwidgets/fib4screening.gsp"


def repack(src_omod: str, new_gsp: str, out_omod: str, gsp_rel: str) -> None:
    work = tempfile.mkdtemp(prefix="omod-repack-")
    try:
        with zipfile.ZipFile(src_omod, "r") as z:
            z.extractall(work)

        target = os.path.join(work, gsp_rel)
        if not os.path.exists(target):
            sys.exit(f"ERROR: target not found in OMOD: {gsp_rel}")
        shutil.copy(new_gsp, target)

        files_count = 0
        dirs_count = 0
        with zipfile.ZipFile(out_omod, "w", zipfile.ZIP_DEFLATED) as z:
            for root, dirs, files in os.walk(work):
                for d in sorted(dirs):
                    rel = (
                        os.path.relpath(os.path.join(root, d), work).replace(os.sep, "/")
                        + "/"
                    )
                    info = zipfile.ZipInfo(rel)
                    info.external_attr = 0
                    z.writestr(info, b"")
                    dirs_count += 1
                for f in sorted(files):
                    rel = os.path.relpath(os.path.join(root, f), work).replace(
                        os.sep, "/"
                    )
                    z.write(os.path.join(root, f), rel)
                    files_count += 1

        with zipfile.ZipFile(src_omod, "r") as z:
            src_names = set(z.namelist())
        with zipfile.ZipFile(out_omod, "r") as z:
            new_names = set(z.namelist())

        missing = src_names - new_names
        extra = new_names - src_names
        print(f"Wrote {out_omod}: {files_count} files, {dirs_count} dirs")
        print(f"Diff vs source: missing={len(missing)} extra={len(extra)}")
        if missing or extra:
            sys.exit("ERROR: structure drift — refusing to ship a broken OMOD")
    finally:
        shutil.rmtree(work, ignore_errors=True)


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
