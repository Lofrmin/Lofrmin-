# 用户认证现状与兼容性预研

> 审计日期：2026-10-31（Asia/Shanghai）。固定代码基线：`Lofrmin/Lofrmin-` 的 `feature/product-workspace`，Commit `7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176`。
> 【已由代码确认】指静态代码事实，不代表服务、凭据或设备已验证；【根据代码推测】表示推断；【需要队友确认】表示外部配置或产品决策缺失；【需要实机验证】表示运行及物理结果未知。代码事实一般为高置信度；未发现实现的结论只限于本次仓库版本。
> 接入限制：工作目录最初不是 Git 仓库。正常克隆因本机代理连接失败；单次停用代理后的克隆亦无法连接 GitHub 443。只读 GitHub 连接器成功读取固定 SHA 的完整目录树（未截断，297 个文件）和主要自有源码；没有本地克隆、origin 引用或个人分支。文档暂存于 outputs/docs，不能声称已写入个人分支。未运行项目、安装依赖、导入业务模块、执行测试、访问设备、调用业务第三方 API 或修改远端。
> 下文路径行号链接均指向固定 SHA；教程、README、HANDOFF 的历史描述只作辅助，运行源码优先。不复制任何 Secret 或凭据型 Webhook URL。


## 当前结论：C，尚无账号认证系统

【已由代码确认，高】前端未发现注册、登录、退出、当前用户请求、AuthStore或路由守卫；Node/Python未发现用户表、密码哈希、JWT/OAuth用户会话、认证中间件、Supabase/Firebase/Clerk/Auth.js。目录树和主要自有源码检索均未发现这些实现。结论仅限固定SHA，不覆盖仓库外服务。

存在三类容易混淆的概念：
- product-workspace.profile：nd-service-profile的name/location本机偏好，默认称呼也只是UI数据。[web/src/app/product-workspace.js:73](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L73)、[web/src/app/product-workspace.js:126](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/src/app/product-workspace.js#L126)。
- FastAPI verify_auth：共享商户Bearer凭据，不关联任何User。[server/bailu_coffee_adapter.py:243](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/server/bailu_coffee_adapter.py#L243)。
- Electron session.defaultSession：Chromium权限/浏览器存储会话；getLoginItemSettings是操作系统登录后自启动，不是用户登录。[web/desktop/main.cjs:218](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L218)、[web/desktop/main.cjs:232](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L232)。
EEGPlayer.session是数据回放，Chat.history是应用内对话，都不是身份Session。

## 推荐方案及备选（建议，尚未实施）

【根据代码推测，中】符合现有技术的建议：增加**独立的FastAPI身份服务/模块 + 服务端可撤销的随机Session + 新用户数据库**，Electron前端通过新增的独立Auth桥接访问。身份服务与当前白鹭演示网关生命周期分开：用户可能运行瑞幸模式而根本不启动白鹭网关，因此不能假定“把认证加进白鹭启动链”就覆盖所有用户。

身份服务要实现跨电脑登录，必须由团队选定可信共享部署；仅本地SQLite/本地服务只能算单机账号演示。推荐演示可用独立SQLite，真正多人多设备采用团队维护的共享数据库（如PostgreSQL）。均为**新增**存储，不改现有订单JSON、IndexedDB表或字段，不迁移历史数据。本轮不创建DB或迁移。

| 方案 | 收益 | 代价与边界 |
|---|---|---|
| 建议：FastAPI + 服务端Session | 与已有Python技术匹配；退出、过期、撤销直接明确 | 需部署身份服务、数据库与凭据保管；团队确定网络拓扑 |
| 备选：团队已有托管身份服务/OIDC | 可复用账号、重置密码等能力 | 当前仓库无配置，需队友确认租户/费用/回调及桌面登录方式；不自动引入Provider |
| JWT自管 | 可无状态验签 | 保持登录和即时退出仍需刷新/撤销设计，对此规模没明显简化；不作为默认选择 |

推荐Session属性为随机不可预测ID、服务器只存其哈希、登录轮换、闲置/绝对过期、退出撤销；浏览器模式用HttpOnly/Secure/SameSite cookie并防CSRF。依据：[OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)。密码使用专门密码哈希（建议Argon2），不存明文/可逆密码；参考[FastAPI密码哈希文档](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/)。这些是推荐原则，具体超时、库版本和策略需设计确认。

## 桌面与网页必须分别设计

【已由代码确认】现桌面页面是本机HTTP origin，CSP connect-src只含self/ws/wss，远程HTTP API由Node主进程调用；Electron IPC按窗口sender限制。直接在renderer fetch远程Auth会涉及CSP、CORS、cookie third-party/SameSite等约束。[web/desktop/main.cjs:99](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L99)、[web/desktop/main.cjs:123](https://github.com/Lofrmin/Lofrmin-/blob/7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176/web/desktop/main.cjs#L123)。

**桌面建议**：新增独立auth IPC白名单（新名字空间），主进程通过HTTPS访问身份服务，在独立cookie jar/会话存储中保管会话，renderer只拿 {id,displayName,…} 和auth状态。不要将SessionID暴露给localStorage或前端日志；持久化需系统受保护存储/平台凭据能力，不假设Node fetch会自动持久保存Set-Cookie。身份请求、凭据存储、退出清理单独设计；不得为了新增桥接改现有IPC签名或allowed窗口。此步骤会触及受保护main/preload，因此必须后续团队明确批准**新增Auth接口**后实施。

**网页建议**：团队若要支持真正网站登录，优先HTTPS同站身份服务/BFF+HttpOnly cookie。当前Vite预览不等于部署网站，也不能把localhost:8001历史代理当已存在身份后端。CSRF校验、精确CORS origin、credentials、cookie scope需确定。不得把Secure cookie直接假定适配当前loopback HTTP，也不放宽全局CSP。

**保持登录**：桌面重启由主进程恢复独立会话并调用me验证，失效回访客；网页登录由受保护cookie维持。不能仅把isLoggedIn=true存localStorage就当安全认证。

## 拟新增接口（全部是未来提案）

这些URL和结构**不是现有API清单**，可由团队定稿；不会修改既有AI/商户/硬件请求。

| 未来方法/路径 | 建议请求 | 建议响应/行为 |
|---|---|---|
| POST /auth/register | email或username、password、displayName? | 201 {user}；是否立即登录需团队定；重复/校验错误受控 |
| POST /auth/login | identifier、password | {user} + 安全Session；通用失败信息/限流；轮换session |
| GET /auth/me | 仅独立Auth Session | {user} 或401 |
| POST /auth/logout | Auth Session + 浏览器CSRF保护 | 撤销当前session，清除凭据；幂等退出 |
| 可选 /auth/sessions | 团队确认后增加 | 设备会话列出/撤销，不在本轮实现 |

新增独立用户存储建议：users(id,唯一identifier,password_hash,display_name,created_at,disabled_at?)；sessions(id/session_hash,user_id,created_at,last_seen_at,expires_at,revoked_at)。这不是现有表，不得把这些字段自动加到旧订单或改订单归属。密码策略、注册限流、重置密码、邮箱验证、隐私保留与运营责任【需要队友确认】。

## 前端拟议流程

1. 初始auth状态unknown → loading → me成功authenticated或401访客；网络失败显示可重试，不能误判密码失效。
2. 注册/登录独立表单，字段校验、提交禁用、可读错误；成功只更新新Auth状态和头像/称呼显示。
3. 原有本地检测、宠物、工位预览、旧API继续走原链。访客能力、哪些新页面要求登录由团队确定，不能自动给全应用加路由守卫。
4. 退出只撤销/清理认证会话；不删除旧订单、pending幂等key、第三方Token、自定义宠物或业务数据；不自动调用硬件断连/停止，也不擅自触发旧chat-clear等业务行为。共享电脑上聊天/资料如何隐藏由团队另行定义。
5. 保持登录、跨窗口同步仅新增user/session状态事件；不复用monitor snapshot或pet mood字段。

## 对现有API和硬件的影响

兼容目标：**不影响**。DeepSeek API Key仍由既有主进程逻辑使用，不换成用户JWT；商户Authorization Bearer不复用Auth Session；MQTT payload不加userId/token；UDP/UART消息完全不变。旧接口不自动返回401、不改body或response、不改数据库/订单结构。

如果团队希望登录后限制AI用量、订单权限或设备控制，这属于新的服务端授权需求：要另设受保护的新门面/版本接口、独立权限校验与兼容过渡策略，先评审数据所有权、旧客户端行为、设备绑定及迁移方案。不得静默把新中间件套在现有路由，也不得向外部Provider发送用户密码/Session。旧商户共享凭据不能保护“不同用户互不可见”的订单边界。

## 团队依赖与后续验收

【需要队友确认】
- 单机演示账号还是跨设备共享身份？Auth服务谁部署、域名与HTTPS如何安排？
- 是否已有团队身份平台，账号字段/验证/重置密码负责人是谁？
- 登录只关联偏好，还是未来关联订单/AI额度/设备？后者需独立权限项目。
- 访客能做什么、退出后聊天/地址的显示策略、历史本地数据如何处理？
- 新增auth bridge和存储的批准范围；保持现有P0契约的评审负责人。

未来验收建议：注册/登录/错误/过期/重启恢复/退出撤销、跨窗口同步、CSRF/限流/口令哈希、凭据不进renderer/log、现有API参数完全一致、无登录情况下旧功能基线不变。当前只完成预研；未开发页面、接口、middleware或数据库。

