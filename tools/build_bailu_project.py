"""重建「白鹭无人车综合」工程，使其可被 Keil 5.14 正常下载。

根因
----
Keil 5.14 的 .uvoptx 里 <nTsel> 与 .uvprojx 的 <TargetName> 绑定。
一旦改了 TargetName（例如 LED -> BailuCar），而 nTsel 没同步，
uVision 就报 "Internal DLL Error" / "Flash Download failed - Target DLL has been cancelled"。

本脚本的做法
------------
1. 用一个**已知可下载**的工程骨架（默认 LED 例程）整体替换 USER / OBJ，
   保证 TargetName 与 nTsel 的配对关系是 Keil 自己认可的那一份；
2. 把新增的硬件源码（OLED/SERVO/MOTOR/KEY）、标准库 tim.c 放回原位；
3. 把新源文件登记进 .uvprojx，并同步 IncludePath；
4. 同步重建 .uvoptx 的文件索引（保持 <Group> 分组结构）。

用法:
  python tools/build_bailu_project.py --target <工程目录> [--skeleton <可用工程目录>]
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

BACKSLASH = chr(92)

NEW_FILES = {
    "FWLIB": [("stm32f4xx_tim.c", "..\\FWLIB\\src\\stm32f4xx_tim.c")],
    "HARDWARE": [
        ("oled.c", "..\\HARDWARE\\OLED\\oled.c"),
        ("servo.c", "..\\HARDWARE\\SERVO\\servo.c"),
        ("motor.c", "..\\HARDWARE\\MOTOR\\motor.c"),
        ("key.c", "..\\HARDWARE\\KEY\\key.c"),
    ],
}

INCLUDE_TAIL = "..\\HARDWARE\\KEY;..\\HARDWARE\\OLED;..\\HARDWARE\\SERVO;..\\HARDWARE\\MOTOR;"


def add_files(xml: str, group: str, files: list[tuple[str, str]]) -> str:
    pat = re.compile(
        r"(<GroupName>" + re.escape(group) + r"</GroupName>.*?<Files>)(.*?)(</Files>)", re.S
    )
    m = pat.search(xml)
    if not m:
        return xml
    extra = ""
    for fname, fpath in files:
        if f"<FileName>{fname}</FileName>" in m.group(2):
            continue
        extra += (
            "\n            <File>\n"
            f"              <FileName>{fname}</FileName>\n"
            "              <FileType>1</FileType>\n"
            f"              <FilePath>{fpath}</FilePath>\n"
            "            </File>"
        )
    return xml[: m.start(2)] + m.group(2) + extra + xml[m.end(2):]


def rebuild_uvoptx(project: Path, template: Path) -> None:
    """按 uvprojx 的分组结构重建 uvoptx 的文件索引。"""
    uv_text = project.read_text(encoding="utf-8", errors="ignore")
    groups = []
    for g in re.finditer(r"<Group>\s*<GroupName>([^<]+)</GroupName>.*?</Group>", uv_text, re.S):
        files = [
            (f.group(1), f.group(2), f.group(3))
            for f in re.finditer(
                r"<File>\s*<FileName>([^<]*)</FileName>\s*<FileType>(\d+)</FileType>"
                r"\s*<FilePath>([^<]*)</FilePath>",
                g.group(0), re.S,
            )
        ]
        groups.append((g.group(1), files))

    base = template.read_text(encoding="utf-8", errors="ignore")
    blocks = list(re.finditer(r"[ \t]*<Group>\s*\n(?:.*?\n)*?[ \t]*</Group>\s*\n", base))
    if not blocks:
        raise SystemExit("template .uvoptx has no <Group> blocks")

    out = ""
    index = 1
    for gi, (gname, files) in enumerate(groups, 1):
        body = ""
        for fname, ftype, fpath in files:
            body += (
                "      <File>\n"
                f"        <GroupNumber>{gi}</GroupNumber>\n"
                f"        <FileNumber>{index}</FileNumber>\n"
                f"        <FileType>{ftype}</FileType>\n"
                "        <tvExp>1</tvExp>\n"
                "        <tvExpOptDlg>0</tvExpOptDlg>\n"
                "        <bDave2>0</bDave2>\n"
                f"        <PathWithFileName>{fpath}</PathWithFileName>\n"
                f"        <FilenameWithoutPath>{fname}</FilenameWithoutPath>\n"
                "        <RteFlg>0</RteFlg>\n"
                "        <bShared>0</bShared>\n"
                "      </File>\n"
            )
            index += 1
        out += (
            "    <Group>\n"
            f"      <GroupName>{gname}</GroupName>\n"
            "      <tvExp>1</tvExp>\n"
            "      <tvExpOptDlg>0</tvExpOptDlg>\n"
            f"      <cbSel>{gi}</cbSel>\n"
            f"{body}"
            "      <RteFlg>0</RteFlg>\n"
            "    </Group>\n"
        )

    rebuilt = base[: blocks[0].start()] + out + base[blocks[-1].end():]
    project.with_suffix(".uvoptx").write_text(rebuilt, encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="目标工程目录（含 USER/OBJ）")
    ap.add_argument("--skeleton", default=r"E:\Keil\STM32F407VE\_probe2",
                    help="已知可下载的骨架工程目录")
    ap.add_argument("--tim-src", default=r"E:\Keil\STM32F407VE\F407V核心板例程-库函数版本\例8 PWM输出\FWLIB\src\stm32f4xx_tim.c")
    ap.add_argument("--keep-user", action="store_true", help="保留目标 USER 目录")
    args = ap.parse_args(argv[1:])

    target = Path(args.target)
    skeleton = Path(args.skeleton)
    if not skeleton.exists():
        raise SystemExit(f"skeleton not found: {skeleton}")

    # 1) 备份目标工程里我们自己写的源码
    backup = target / "_src_backup"
    backup.mkdir(exist_ok=True)
    for rel in ("USER/main.c", "USER/JLinkSettings.ini",
                "HARDWARE/OLED", "HARDWARE/SERVO", "HARDWARE/MOTOR", "HARDWARE/KEY"):
        src = target / rel
        if not src.exists():
            continue
        dst = backup / rel
        if src.is_dir():
            if dst.exists():
                shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(src, dst)
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
    print(f"源码已备份到 {backup}")

    # 2) 用骨架替换 USER / OBJ
    if not args.keep_user:
        for sub in ("USER", "OBJ"):
            tgt = target / sub
            if tgt.exists():
                shutil.rmtree(tgt, ignore_errors=True)
            shutil.copytree(skeleton / sub, tgt)
            print(f"骨架已就位: {sub}")

    # 3) 放回新增源码
    for rel in ("HARDWARE/OLED", "HARDWARE/SERVO", "HARDWARE/MOTOR", "HARDWARE/KEY"):
        src = backup / rel
        if not src.exists():
            continue
        dst = target / rel
        if dst.exists():
            shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst)
        print(f"恢复源码: {rel}")
    if (backup / "USER/main.c").exists():
        shutil.copyfile(backup / "USER/main.c", target / "USER/main.c")
        print("恢复源码: USER/main.c")

    tim_src = Path(args.tim_src)
    if tim_src.exists():
        shutil.copyfile(tim_src, target / "FWLIB/src/stm32f4xx_tim.c")
        print("恢复源码: FWLIB/src/stm32f4xx_tim.c")

    # 4) 登记新文件 + IncludePath
    project = target / "USER" / "OLED.uvprojx"
    if not project.exists():
        cands = sorted((target / "USER").glob("*.uvprojx"))
        if not cands:
            raise SystemExit("no uvprojx in target USER")
        project = cands[0]
    text = project.read_text(encoding="utf-8", errors="ignore")
    for group, files in NEW_FILES.items():
        text = add_files(text, group, files)
    text = re.sub(
        r"<IncludePath>([^<]*)</IncludePath>",
        lambda m: "<IncludePath>" + m.group(1).replace(
            "..\\HARDWARE\\LED;", "..\\HARDWARE\\LED;" + INCLUDE_TAIL) + "</IncludePath>",
        text,
    )
    project.write_text(text, encoding="utf-8")
    print(f"工程文件已更新: {project.name}")

    # 5) 重建 uvoptx 索引
    template = project.with_suffix(".uvoptx")
    if template.exists():
        rebuild_uvoptx(project, template)
        print("uvoptx 索引已重建")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
