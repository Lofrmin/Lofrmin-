"""批量修复 Keil 工程的 J-Link 配置。

根因：工程原本锁死 ST-Link 驱动 + 1MB Flash 算法，且 JLinkSettings.ini 里
Device="UNSPECIFIED"，导致 J-Link 匹配不到 Flash 算法，报 "Erase Failed"。

修复内容：
  1. 调试器   ST-LINK SWO  ->  Segger\\JL2CM3.dll（J-Link）
  2. Flash    1024 算法   ->  512KB 算法（STM32F407VE 只有 512KB）
  3. 下载驱动 UL2CM3      ->  Segger\\JL2CM3.dll
  4. 器件名   F407VG/ZG   ->  F407VE
  5. JLinkSettings.ini 的 Device 设为真实器件名

用法:
  python tools/fix_keil_jlink.py "E:\\Keil\\STM32F407VE"
  python tools/fix_keil_jlink.py "E:\\Keil\\STM32F407VE" --device STM32F407VE
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

DRIVER_JLINK = "Segger" + chr(92) + "JL2CM3.dll"
DRIVER_STLINK = "STLink" + chr(92) + "ST-LINKIII-KEIL_SWO.dll"
FLASH_1024 = "STM32F4xx_1024"
FLASH_512 = "STM32F4xx_512"
DEFAULT_DEVICE = "STM32F407VE"


def _fix_driver_entry(body: str) -> str:
    """修正单个驱动注册项的 Name 内容。

    注意：Name 里含有 `$$Device:...$...` 这种带 `$` 的文本，且 Name 元素内部
    不含 `<` 或 `>`，所以用 `[^<]*` 精确匹配，避免 `.*?` 跨元素吞掉别的条目。
    """
    body = body.replace(FLASH_1024, FLASH_512).replace("-FL0100000", "-FL0080000")
    for wrong in ("STM32F407VGTx", "STM32F407ZG", "STM32F407ZGTx"):
        body = body.replace(wrong, DEFAULT_DEVICE)
    # 旧的 TCP/IP 调试会话参数会让 J-Link 去连 127.0.0.1:7997 而不是 USB 探头
    body = re.sub(r"-JU\d+", "", body)
    body = re.sub(r"-JI[^\s]+", "", body)
    body = re.sub(r"-JP\d+", "", body)
    body = re.sub(r"-L00\(\d+\)", "-L00(0)", body)
    body = re.sub(r"-TB\d+", "", body)
    body = re.sub(r"-TFE\d+", "", body)
    # 有些条目里 -FF0 只写了算法名、丢了 .FLM 后缀与 -FP0(...) 路径，
    # 这会让 Keil 报 "Internal DLL Error"。补全。
    if "-FF0STM32F4xx_512 " in body and "-FP0(" not in body:
        body = body.replace(
            "-FF0STM32F4xx_512 ",
            "-FF0STM32F4xx_512.FLM ",
        ) + ("-FP0($$Device:STM32F407VETx$CMSIS/Flash/STM32F4xx_512.FLM)")
    return re.sub(r"\s{2,}", " ", body)


def _fix_all_driver_entries(text: str) -> str:
    """修正 TargetDriverDllRegistry 里所有驱动条目的 Name。

    每个条目形如:
        <SetRegEntry><Number>0</Number><Key>JL2CM3</Key><Name>....</Name></SetRegEntry>
    Name 内不含 '<'，用 `[^<]*` 安全匹配。
    """
    def repl(match: re.Match) -> str:
        return "<Name>" + _fix_driver_entry(match.group(1)) + "</Name>"

    return re.sub(r"<Name>([^<]*)</Name>", repl, text)


def fix_project(path: Path, device: str) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text
    changes: list[str] = []

    if DRIVER_STLINK in text:
        text = text.replace(DRIVER_STLINK, DRIVER_JLINK)
        changes.append("debug driver -> J-Link")

    if FLASH_1024 in text:
        text = text.replace(FLASH_1024, FLASH_512)
        changes.append("flash algorithm -> 512KB")

    if "-FL0100000" in text:
        text = text.replace("-FL0100000", "-FL0080000")
        changes.append("flash length -> 512KB")

    if "<Flash2>BIN" + chr(92) + "UL2CM3.DLL</Flash2>" in text:
        text = text.replace("<Flash2>BIN" + chr(92) + "UL2CM3.DLL</Flash2>",
                            "<Flash2>" + DRIVER_JLINK + "</Flash2>")
        changes.append("flash download driver -> J-Link")

    for wrong in ("STM32F407VGTx", "STM32F407ZG", "STM32F407ZGTx"):
        if wrong in text:
            text = text.replace(wrong, device)
            changes.append(f"device {wrong} -> {device}")

    text = _fix_all_driver_entries(text)

    if text != original:
        path.write_text(text, encoding="utf-8")
    return changes


def fix_ini(path: Path, device: str) -> bool:
    """JLinkSettings.ini 的 Device 必须是具体器件名，否则匹配不到 Flash 算法。"""
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text
    if re.search(r'Device="[^"]*"', text):
        text = re.sub(r'Device="[^"]*"', f'Device="{device}"', text)
    else:
        text = text.replace("[FLASH]", f'[FLASH]\nDevice="{device}"', 1)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    device = DEFAULT_DEVICE
    if "--device" in argv:
        index = argv.index("--device")
        device = argv[index + 1] if index + 1 < len(argv) else DEFAULT_DEVICE
        args = [a for a in args if a != device]

    if not args:
        print(__doc__)
        return 1

    projects: list[Path] = []
    for item in args:
        path = Path(item)
        if path.is_dir():
            projects.extend(sorted(path.rglob("*.uvprojx")))
        elif path.suffix.lower() in (".uvprojx", ".uvoptx"):
            projects.append(path)
    if not projects:
        print("no project files found")
        return 1

    fixed = 0
    for project in projects:
        changes = fix_project(project, device)
        optx = project.with_suffix(".uvoptx")
        if optx.exists():
            changes += fix_project(optx, device)
        if fix_ini(project.parent / "JLinkSettings.ini", device):
            changes.append("JLinkSettings.ini Device")
        if changes:
            fixed += 1
        print(f"{project.name}: {', '.join(dict.fromkeys(changes)) or 'ok'}")
    print(f"done. {fixed} project(s) updated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
