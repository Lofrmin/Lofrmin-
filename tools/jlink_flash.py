"""用 J-Link Commander 烧录任意 hex/bin，绕过 Keil 的 Flash 算法配置问题。

用法:
  python tools/jlink_flash.py <hex路径> [设备名] [速度kHz]

示例:
  python tools/jlink_flash.py "E:\\Keil\\...\\OBJ\\Template.hex"
  python tools/jlink_flash.py build\\firmware.hex STM32F407VE 4000

说明:
  - 中文路径下 J-Link 打不开文件，脚本会先复制到纯英文临时目录再烧。
  - 需要 JLink.exe，默认在 D:\\Program Files\\SEGGER\\JLink_V988，可用环境变量
    JLINK_EXE 覆盖。
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

JLINK_CANDIDATES = [
    os.environ.get("JLINK_EXE", ""),
    r"D:\Program Files\SEGGER\JLink_V988\JLink.exe",
    r"C:\Program Files\SEGGER\JLink_V988\JLink.exe",
    r"C:\Program Files (x86)\SEGGER\JLink_V988\JLink.exe",
    r"C:\Program Files\SEGGER\JLink\JLink.exe",
]


def find_jlink() -> Path:
    for candidate in JLINK_CANDIDATES:
        if candidate and Path(candidate).exists():
            return Path(candidate)
    found = shutil.which("JLink.exe")
    if found:
        return Path(found)
    raise SystemExit("JLink.exe not found. Set JLINK_EXE to its full path.")


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    source = Path(argv[0])
    device = argv[1] if len(argv) > 1 else "STM32F407VE"
    speed = argv[2] if len(argv) > 2 else "4000"
    if not source.exists():
        print(f"file not found: {source}")
        return 1

    jlink = find_jlink()
    with tempfile.TemporaryDirectory(prefix="jlinkflash-") as work:
        # J-Link 无法打开含中文的路径，统一搬到纯英文临时目录。
        staged = Path(work) / source.name
        shutil.copyfile(source, staged)
        script = Path(work) / "flash.txt"
        script.write_text(
            f"device {device}\nsi SWD\nspeed {speed}\nconnect\n"
            f"loadfile {staged}\nr\ng\nexit\n",
            encoding="utf-8",
        )
        result = subprocess.run(
            [str(jlink), "-CommandFile", str(script)],
            capture_output=True, text=True, errors="replace",
        )
    output = (result.stdout or "") + (result.stderr or "")
    for line in output.splitlines():
        if any(token in line for token in (
            "O.K.", "Error", "error", "Failed", "Flash download",
            "Downloading file", "Programming", "Verified", "Target info",
            "Device:", "VTarget",
        )):
            print(line.rstrip())
    if "O.K." not in output:
        print("--- flash did not report O.K. ---")
        return 1
    print(f"flash ok: {source.name} -> {device}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
