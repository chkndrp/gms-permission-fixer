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

MISSING=""
for cmd in getprop pm grep read echo cut dumpsys printf awk appops am sleep; 
    do command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done

if [ -n "$MISSING" ]; 
    then 
        ui_print "[FAIL] Missing required commands: $MISSING"
        abort "[FAIL] Please install busybox/toybox, this script will now abort."
fi

SDK_VERSION=$(getprop ro.build.version.sdk)

if [ -z "$SDK_VERSION" ]; 
    then SDK_VERSION=$(getprop ro.system.build.version.sdk)
fi
if [ -z "$SDK_VERSION" ]; 
    then SDK_VERSION=$(getprop ro.bootimage.build.version.sdk)
fi
if [ -z "$SDK_VERSION" ]; 
    then SDK_VERSION=0
fi

ui_print "Fixing GApps permissions"
ui_print

pm list packages -a | grep "google" | while read -r PKG_LINE; 
    do
        PKG_NAME=$(echo "$PKG_LINE" | cut -d ':' -f 2)
        echo "--- Processing: $PKG_NAME ---"

        PACKAGE_DUMP=$(dumpsys package "$PKG_NAME")
        PERMISSIONS=$(printf '%s\n' "$PACKAGE_DUMP" | grep "android.permission" | awk '{print $1}')

        if [ "$SDK_VERSION" -ge 34 ];
            then
                if pm grant --all-permissions "$PKG_NAME" 2>/dev/null; 
                    then ui_print "[SUCCESS] Runtime bulk grant OK"
                    else ui_print "[FAIL] Runtime bulk grant failed"
                fi
            else
                PERMISSION_GRANTS=0
                PERMISSION_FAILURES=0

                for PERM in $PERMISSIONS;
                    do
                        if echo "$PERM" | grep -q "^android.permission";
                            then
                                if pm grant "$PKG_NAME" "$PERM" 2>/dev/null;
                                    then PERMISSION_GRANTS=$((PERMISSION_GRANTS + 1))
                                    else PERMISSION_FAILURES=$((PERMISSION_FAILURES + 1))
                                fi
                        fi
                done

                if [ "$PERMISSION_GRANTS" -ne 0 ] || [ "$PERMISSION_FAILURES" -ne 0 ];
                    then ui_print "[SUCCESS] Runtime Granted: $PERMISSION_GRANTS, failed: $PERMISSION_FAILURES"
                    else ui_print "[FAIL] No permissions found"
                fi
        fi

        if APP_OPS_OUTPUT=$(appops get "$PKG_NAME" 2>/dev/null); 
            then
                APP_OPS_GRANTED=0
                APP_OPS_FAILURES=0
                APP_OPS=$(printf '%s\n' "$APP_OPS_OUTPUT" | awk -F: '
                    {
                        op = $1
                        if (op == "Uid mode") {
                            op = $2
                        }
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", op)
                        if (op ~ /^[A-Z][A-Z0-9_]*$/ && !seen[op]++) {
                            print op
                        }
                    }
                ')

                if [ -z "$APP_OPS" ]; 
                    then ui_print "[WARN] No AppOps reported"
                fi

                for OP in $APP_OPS; 
                    do
                        if appops set "$PKG_NAME" "$OP" allow 2>/dev/null; 
                            then APP_OPS_GRANTED=$((APP_OPS_GRANTED + 1))
                            else APP_OPS_FAILURES=$((APP_OPS_FAILURES + 1))
                        fi
                done
 
                if [ -n "$APP_OPS" ];
                    then ui_print "[SUCCESS] AppOps Granted: $APP_OPS_GRANTED, failed: $APP_OPS_FAILURES"
                fi
            else ui_print "[FAIL] Could not read AppOps for $PKG_NAME"
        fi
done

ui_print "--- Restarting GMS ---"
am force-stop com.google.android.gms
sleep 5

ui_print "--- Finished processing all packages ---"
ui_print
abort "[SUCCESS] This script will now abort for a native cleanup."
