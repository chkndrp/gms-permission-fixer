#!/bin/sh

#  GMS Permission fixer
#  Copyright (C) 2025 chkndrp
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

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SDK_ROOT=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}

if [ -z "$SDK_ROOT" ] || [ ! -d "$SDK_ROOT/platforms" ] || [ ! -d "$SDK_ROOT/build-tools" ]; 
    then
        echo "Set ANDROID_SDK_ROOT or ANDROID_HOME to an installed Android SDK." >&2
        exit 1
fi

ANDROID_JAR=$(find "$SDK_ROOT/platforms" -mindepth 2 -maxdepth 2 -name android.jar | sort -V | tail -n 1)
BUILD_TOOLS=$(find "$SDK_ROOT/build-tools" -mindepth 2 -maxdepth 2 -name d8 | sort -V | tail -n 1)

if [ -z "$ANDROID_JAR" ] || [ -z "$BUILD_TOOLS" ]; 
    then
        echo "Could not find android.jar and d8 in the Android SDK." >&2
        exit 1
fi

OUTPUT=${1:-"$SCRIPT_DIR/PackageCheck.dex"}
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
mkdir -p "$WORK_DIR/classes" "$WORK_DIR/dex"

javac --release 17 -classpath "$ANDROID_JAR" \
    -d "$WORK_DIR/classes" "$SCRIPT_DIR/PackageCheck.java"

jar cf "$WORK_DIR/trust-checker.jar" -C "$WORK_DIR/classes" .
    "$BUILD_TOOLS" --min-api 28 --output "$WORK_DIR/dex" "$WORK_DIR/trust-checker.jar"

mv "$WORK_DIR/dex/classes.dex" "$OUTPUT"
