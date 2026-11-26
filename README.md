# GMS Permission fixer

Simple flashable script to fix permissions 
needed for GMS, which may fix some random 
issues (e.g. Broken Fused location) after a 
GApps+ROM update.

In detail, after performing a check on each package,
this script grants all `com.google.*` apps
all requested runtime and appops permissions.

## How do i build this from source?
Just run the build script at the root of the repo. The minimum requirement for this is:

- Linux system
- Python 3.9+
- JDK 17+ (`javac`, `jar` in `$PATH`)
- Android SDK (`ANDROID_SDK_ROOT` & `ANDROID_HOME` set to it's path)

```shell
python build.py
```
```shell
# Created /home/user/module/build/gms-permission-fixer-x.x.x.zip
# Created /home/user/module/build/gms-permission-fixer.zip (for permalink purposes)
```

## Installation
- [Download module archive from releases](https://github.com/chkndrp/gms-permission-fixer/releases/latest/download/gmspermfix.zip). There is also a [mirror at SourceForge](https://sourceforge.net/projects/gms-permission-fixer)
- Flash it in any superuser manager, or FKM

## Requirements
- Android 9+
- Magisk 20.4+
- or any KernelSU/APatch/FKM version
