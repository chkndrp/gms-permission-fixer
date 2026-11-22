#!/system/bin/sh

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

ui_print() { echo "$1"; }
abort() { echo "$1"; exit 1; }

export GMS_PERMISSION_FIX_ACTION=1
export MODDIR="${0%/*}"

if [ "$MODDIR" = "$0" ]; 
    then export MODDIR=.
fi

. "$MODDIR/customize.sh"
gms_permission_fix
