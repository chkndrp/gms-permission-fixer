#!/usr/bin/env python3

"""Build script for the module/ directory and dex part."""

#  A flashable script that grants all runtime/appops permissions to
#  google apps to fix post-OTA GMS issues.
#
#  Copyright (C) 2026 chkndrp
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODULE_DIR = ROOT / "module"
SOURCE_FILE = ROOT / "dex" / "PackageCheck.java"
PACKAGE_FILES = ("LICENSE", "README.md")

MODULE_ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
VERSION_PATTERN = re.compile(r"v?[0-9]+(?:\.[0-9]+)*\Z")


def sdk_version(path: Path) -> tuple[int, ...]:
    """Returns the SDK version components."""

    return tuple(int(part) for part in re.findall(r"\d+", path.name))


def read_module_metadata() -> tuple[str, str]:
    """Reads and validates the module ID and version from module.prop."""

    module_prop = MODULE_DIR / "module.prop"
    if not module_prop.is_file():
        raise FileNotFoundError(f"Missing {module_prop}")

    properties: dict[str, list[str]] = {"id": [], "version": []}
    for line in module_prop.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        key = key.strip()

        if separator and key in properties:
            properties[key].append(value.strip())

    module_ids = properties["id"]
    if len(module_ids) != 1 or not MODULE_ID_PATTERN.fullmatch(module_ids[0]):
        raise ValueError(f"Invalid or missing ID in {module_prop}")

    versions = properties["version"]
    if len(versions) != 1 or not VERSION_PATTERN.fullmatch(versions[0]):
        raise ValueError(f"Invalid or missing version in {module_prop}")

    return module_ids[0], versions[0]


def build_dex(output_dir: Path, work_dir: Path) -> None:
    """Compiles PackageCheck into a DEX file in the output dir."""

    sdk_root_value = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not sdk_root_value:
        raise FileNotFoundError("Set ANDROID_SDK_ROOT or ANDROID_HOME to an installed Android SDK.")

    sdk_root = Path(sdk_root_value).expanduser()
    platforms_dir = sdk_root / "platforms"
    build_tools_dir = sdk_root / "build-tools"

    if not platforms_dir.is_dir() or not build_tools_dir.is_dir():
        raise FileNotFoundError("Set ANDROID_SDK_ROOT or ANDROID_HOME to an installed Android SDK.")

    android_jar = max(
        platforms_dir.glob("*/android.jar"),
        key=sdk_version,
        default=None,
    )
    d8 = max(
        build_tools_dir.glob("*/d8"),
        key=sdk_version,
        default=None,
    )

    if android_jar is None or d8 is None:
        raise FileNotFoundError("Could not find android.jar or d8 in the Android SDK.")
    if not SOURCE_FILE.is_file():
        raise FileNotFoundError(f"Missing {SOURCE_FILE}")

    javac = shutil.which("javac")
    jar = shutil.which("jar")

    if javac is None or jar is None:
        raise FileNotFoundError("Both javac and jar must be available in PATH.")

    classes_dir = work_dir / "classes"
    classes_dir.mkdir(parents=True)

    dex_dir = work_dir / "dex"
    dex_dir.mkdir()

    subprocess.run([javac,
            "--release",
            "17",
            "-classpath",
            str(android_jar),
            "-d",
            str(classes_dir),
            str(SOURCE_FILE),
        ],
        check=True,
    )

    jar_path = work_dir / "PackageCheck.jar"

    subprocess.run(
        [jar, "cf", str(jar_path), "-C", str(classes_dir), "."],
        check=True,
    )

    d8_command = [str(d8), "--min-api", "28", "--output", str(dex_dir), str(jar_path)]
    subprocess.run(d8_command, check=True)

    dex_file = dex_dir / "classes.dex"
    if not dex_file.is_file():
        raise FileNotFoundError(f"d8 did not create the DEX file: {dex_file}")

    output_dir.mkdir(parents=True, exist_ok=True)

    packaged_dex = output_dir / "PackageCheck.dex"
    shutil.copy2(dex_file, packaged_dex)


def main() -> None:
    """Builds the DEX file and an archive of the module directory."""

    if sys.platform != "linux":
        raise RuntimeError("This build script supports Linux only.")

    module_id, version = read_module_metadata()

    required_files = [ROOT / name for name in PACKAGE_FILES]
    missing_files = [path for path in required_files if not path.is_file()]

    if missing_files:
        missing = ", ".join(str(path) for path in missing_files)
        raise FileNotFoundError(f"Missing package file(s): {missing}")

    build_dir = ROOT / "build"
    build_dir.mkdir(exist_ok=True)

    archive_path = build_dir / f"{module_id}-{version}.zip"
    permalink_path = build_dir / f"{module_id}.zip"

    with tempfile.TemporaryDirectory(prefix=f"{module_id}-") as temp:
        temp_root = Path(temp)
        temp_dir = temp_root / "package"
        work_dir = temp_root / "work"

        temp_dir.mkdir()

        for item in MODULE_DIR.iterdir():
            destination = temp_dir / item.name

            if item.is_dir():
                shutil.copytree(item, destination)
            else:
                shutil.copy2(item, destination)

        build_dex(temp_dir / "dex", work_dir)

        for source in required_files:
            shutil.copy2(source, temp_dir / source.name)

        with zipfile.ZipFile(archive_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for path in sorted(temp_dir.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(temp_dir).as_posix())
                elif not any(path.iterdir()):
                    archive.write(path, path.relative_to(temp_dir).as_posix() + "/")

    shutil.copy2(archive_path, permalink_path)

    print(f"Created {archive_path}")
    print(f"Created {permalink_path} (for permalink purposes)")


if __name__ == "__main__":
    main()
