# 🍎 Apple iCloud 状态墙 — CodeBuddy Skill

一个 [CodeBuddy](https://codebuddy.ai) Skill，让 AI 帮你一键搭建 **iCloud 日历状态墙** — 自动将你的实时状态同步到 iCloud 共享日历，家人朋友订阅即可随时查看。

## 效果展示

| 场景 | 日历显示 |
|------|---------|
| 正在开会 | 🚫 产品评审会 (勿扰) |
| 在家 | 🏠 在家 |
| 在公司 | 🏢 搬砖中 |
| 上班路上 | 🚗 正在上班途中（当前：望京西站） |
| 下班路上 | 🚗 正在下班途中，距离家 3.2km（当前：中关村软件园） |
| 在外面 | 📍 在朝阳大悦城 |

## 工作原理

```
┌─────────────────────────────────────────────────┐
│                 Status Wall 守护进程              │
│                                                   │
│  ① 读取私人日历 ──→ 有日程？──→ 显示日程名称      │
│                        │ 无                       │
│  ② iCloud Find My ──→ GPS 坐标                   │
│        │                                          │
│  ③ 高德逆地理编码 ──→ 位置名称                    │
│        │                                          │
│  ④ 地理围栏判断 ──→ 在家/公司/通勤/在外           │
│        │                                          │
│  ⑤ 写入共享日历 ──→ 家人朋友可见                  │
└─────────────────────────────────────────────────┘
```

**智能轮询**：通勤时 1 分钟刷新一次，平时 15 分钟一次。

## 如何使用

### 前置准备

| 准备项 | 获取方式 |
|--------|---------|
| Apple ID 邮箱 + 密码 | — |
| 应用专用密码 | [appleid.apple.com](https://appleid.apple.com) → 登录 → 应用专用密码 → 生成 |
| 高德地图 API Key | [lbs.amap.com](https://lbs.amap.com) → 控制台 → 创建应用 → Web 服务 Key |
| 家 & 公司经纬度 | [高德坐标拾取器](https://lbs.amap.com/tools/picker) |

### 方式一：在 CodeBuddy 中使用 Skill

1. 将本仓库作为 Skill 导入 CodeBuddy
2. 对 AI 说：**"帮我搭建一个 iCloud 日历状态墙项目"**
3. AI 会自动生成完整项目代码并指导你配置运行

### 方式二：直接使用源代码

项目源代码在 `references/source_code.md` 中，包含完整的 10 个 Python 模块。

```bash
# 快速脚手架
bash scripts/scaffold_project.sh my-status-wall

# 安装
cd my-status-wall
bash install.sh

# 初始化配置
status_wall init

# 启动
status_wall start

# 查看状态
status_wall status
```

### 可用命令

```
status_wall init          # 交互式配置（填写 Apple ID、API Key、坐标等）
status_wall start         # 后台启动守护进程
status_wall start -f      # 前台启动（调试用）
status_wall stop          # 停止
status_wall status        # 查看运行状态
status_wall once -v       # 单次执行（详细日志）
status_wall show-gps      # 查看当前 GPS + 高德地名 + 围栏距离
```

## 技术栈

- **Python 3.8+**
- **pyicloud** — iCloud Find My 定位
- **caldav** — CalDAV 日历读写
- **icalendar** — iCalendar 数据解析
- **高德地图 API** — 逆地理编码

## 项目结构

```
status_wall/
├── config.py           # 配置管理（懒加载，~/.status_wall.json）
├── cli.py              # 命令行入口
├── daemon.py           # 守护进程（自动重连 + 失败退避）
├── daemon_runner.py    # 后台进程启动器
├── location_service.py # iCloud GPS（会话持久化 + 2FA/2SA）
├── amap_service.py     # 高德逆地理编码（带缓存）
├── calendar_reader.py  # 私人日历读取（全天事件 + 时区处理）
├── calendar_writer.py  # 共享日历写入（UUID 去重）
└── state_manager.py    # 状态机（地理围栏 + 通勤检测）
```

## Skill 文件结构

```
apple-calendar-home/
├── SKILL.md                      # Skill 指令（架构设计 + 模块实现指南）
├── references/
│   └── source_code.md            # 完整源代码（10 个模块）
└── scripts/
    └── scaffold_project.sh       # 项目脚手架脚本
```

## 注意事项

- 首次运行需处理 Apple 双重认证，之后会话会持久化（cookie）
- 配置文件权限自动设为 `0600`（仅所有者可读写）
- 建议在 macOS 或 Linux 上运行
- 后台运行日志输出到 `~/.status_wall.log`

## License

MIT
