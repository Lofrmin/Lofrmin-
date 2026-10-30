"""重建 Keil 工程的 .uvoptx 文件索引（保持 <Group> 分组结构）。

背景
----
向 .uvprojx 增删源文件后，配套的 .uvoptx 不会同步，uVision 会报
"Internal DLL Error" / "Flash Download failed - Target DLL has been cancelled"。

更隐蔽的坑：.uvoptx 里的文件记录是**按 <Group> 分组**存放的，每个组有自己的
<GroupName>/<cbSel> 段落。直接把所有 <File> 平铺替换会破坏分组结构，Keil 5.14
同样会报 Internal DLL Error。本脚本按 uvprojx 的分组重建，保持结构完整。

用法:
  python tools/rebuild_uvoptx.py <目标工程.uvprojx> [模板.uvoptx]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def parse_groups(uv_text: str) -> list[tuple[str, list[tuple[str, str, str]]]]:
    """从 uvprojx 解析 [(组名, [(文件名, FileType, 文件路径), ...]), ...]。

    注意：uvoptx 的记录数必须与 uvprojx 的文件数**完全一致**——
    连 readme.txt（FileType=2）也要有一条记录，漏掉会让 Keil 报 Internal DLL Error。
    """
    groups: list[tuple[str, list[tuple[str, str, str]]]] = []
    for g in re.finditer(r"<Group>\s*<GroupName>([^<]+)</GroupName>.*?</Group>", uv_text, re.S):
        name = g.group(1)
        files = [
            (f.group(1), f.group(2), f.group(3))
            for f in re.finditer(
                r"<File>\s*<FileName>([^<]*)</FileName>\s*<FileType>(\d+)</FileType>\s*<FilePath>([^<]*)</FilePath>",
                g.group(0), re.S,
            )
        ]
        groups.append((name, files))
    return groups


def make_file_block(group_no: int, file_no: int, ftype: str, pwf: str, fname: str) -> str:
    return (
        "      <File>\n"
        f"        <GroupNumber>{group_no}</GroupNumber>\n"
        f"        <FileNumber>{file_no}</FileNumber>\n"
        f"        <FileType>{ftype}</FileType>\n"
        "        <tvExp>1</tvExp>\n"
        "        <tvExpOptDlg>0</tvExpOptDlg>\n"
        "        <bDave2>0</bDave2>\n"
        f"        <PathWithFileName>{pwf}</PathWithFileName>\n"
        f"        <FilenameWithoutPath>{fname}</FilenameWithoutPath>\n"
        "        <RteFlg>0</RteFlg>\n"
        "        <bShared>0</bShared>\n"
        "      </File>\n"
    )


def make_group_block(group_no: int, group_name: str, files: list[tuple[str, str, str]],
                     start_index: int) -> str:
    body = "".join(
        make_file_block(group_no, start_index + i, ftype, pwf, fname)
        for i, (fname, ftype, pwf) in enumerate(files)
    )
    return (
        "    <Group>\n"
        f"      <GroupName>{group_name}</GroupName>\n"
        "      <tvExp>1</tvExp>\n"
        "      <tvExpOptDlg>0</tvExpOptDlg>\n"
        f"      <cbSel>{group_no}</cbSel>\n"
        f"{body}"
        "      <RteFlg>0</RteFlg>\n"
        "    </Group>\n"
    )


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    project = Path(argv[0])
    if project.suffix.lower() != ".uvprojx":
        print(f"not a uvprojx: {project}")
        return 1
    optx = project.with_suffix(".uvoptx")

    template = Path(argv[1]) if len(argv) > 1 else None
    if template is None or not template.exists():
        print("a working template .uvoptx is required")
        return 1

    groups = parse_groups(project.read_text(encoding="utf-8", errors="ignore"))
    if not groups:
        print("no groups found in uvprojx")
        return 1

    base = template.read_text(encoding="utf-8", errors="ignore")

    # 模板里 <Group>...</Group> 块的整体范围（第一个开始到最后一个结束）
    blocks = list(re.finditer(r"[ \t]*<Group>\s*\n(?:.*?\n)*?[ \t]*</Group>\s*\n", base))
    if not blocks:
        print("template has no <Group> blocks")
        return 1

    rebuilt_groups = ""
    file_index = 1
    for gi, (gname, files) in enumerate(groups, 1):
        rebuilt_groups += make_group_block(gi, gname, files, file_index)
        file_index += len(files)

    rebuilt = base[: blocks[0].start()] + rebuilt_groups + base[blocks[-1].end():]
    optx.write_text(rebuilt, encoding="utf-8")

    print(f"{optx.name}: groups={len(re.findall(r'<Group>', rebuilt))}, "
          f"files={len(re.findall(r'<File>', rebuilt))}, "
          f"cbSel={len(re.findall(r'<cbSel>', rebuilt))}")
    for key in ("nTsel", "pMon"):
        m = re.search(rf"<{key}>([^<]*)</{key}>", rebuilt)
        print(f"  {key} = {m.group(1) if m else 'MISSING'}")
    print("  groups:", re.findall(r"<GroupName>([^<]*)</GroupName>", rebuilt))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
