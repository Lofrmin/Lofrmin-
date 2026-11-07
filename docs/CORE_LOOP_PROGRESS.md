# 核心体验实施记录

- 基线：远端 main 7e5fce1；本地源码一致，除已存在的 Godot 4.3 Basis 兼容修复与导入缓存。
- 原文件备份：工作区外层 backups/captain-core-20261106，不提交。
- GitHub 当前账号 Pricnd 权限 READ；用户已授权 main 上传，待仓库写权限。
- Ruling: 保留现有项目目录并接上远端 Git 历史，不新建 worktree；本地本是无 Git 的独立源码副本，避免分叉出另一份主工程。
- Ruling: 不新增剧情事实/存档字段；状态显示全部从已有 chapter/case_accepted/evidence 派生。
- Ruling: 第1题由点击两个身份字段提交替代选择题，其他谜题不变；未选满证据不能提交，数字键不能走旧答案捷径。
- Ruling: 地图第一批只做既有回路导向，不开新门；实际可达性由同一网格与A*验证。
- 测试隔离：测试fixture不调用 Profile.open，不读写玩家存档，不联网；使用真实游戏规则和场景构建。
