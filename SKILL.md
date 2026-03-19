---
name: apple-calendar-home
description: "This skill should be used when the user wants to build an Apple iCloud Status Wall (iCloud 日历状态墙) project — an automated system that aggregates calendar events from multiple platforms (iCloud, WeCom/企业微信, Feishu/飞书) and syncs status to an iCloud shared calendar so family can see the user's real-time schedule. Core feature only requires Apple ID + app-specific password. Optional features include WeCom/Feishu calendar sync via CalDAV, and GPS location via iCloud Find My + AMap reverse geocoding with geofence-based commute detection."
---

# Apple iCloud 状态墙 (Status Wall) v2.0

## Overview

This skill provides the complete knowledge and implementation patterns for building an **Apple iCloud Status Wall** — an automated system that aggregates the user's calendar events from multiple platforms (iCloud, WeCom/企业微信, Feishu/飞书) and syncs status to an iCloud shared calendar. Family or friends can see the user's current status by subscribing to the shared calendar.

**v2.0 架构**: 模块化分层设计，仅 iCloud 日历为必填，企业微信/飞书同步和 GPS 定位均为可选功能。

## User Onboarding Guide

When a user activates this skill, the AI MUST present the following guide **in Chinese** and wait for the user to provide the required credentials before generating any code. Do NOT dump all tiers at once — walk through them step by step.

### Step 1: Explain what this does (always show first)

```
🍎 Apple iCloud 状态墙

它能做什么？
把你的日程自动同步到一个 iCloud 共享日历里，你的家人订阅这个日历后，
就能随时看到你现在在忙什么。

例如：
  🚫 产品评审会 (勿扰)     ← 你的 iCloud 日程
  📅 [飞书] 需求评审        ← 自动从飞书同步过来的
  📅 [企微] 部门例会        ← 自动从企业微信同步过来的
  ✅ 空闲                   ← 没有日程时
  🏠 在家                   ← 开启 GPS 定位后（可选）
  🚗 正在下班途中，距离家 3.2km  ← 开启 GPS 定位后（可选）
```

### Step 2: Core setup (required, always ask)

```
━━━━ 第一步：iCloud 日历（必填）━━━━

需要你提供两样东西：

① Apple ID 邮箱
   就是你登录 iCloud 用的那个邮箱

② 应用专用密码（⚠️ 不是你的 Apple 登录密码！）
   这是 Apple 专门给第三方应用用的一次性密码
   获取方法：
     1. 打开 https://appleid.apple.com
     2. 登录你的 Apple ID
     3. 找到「App 专用密码」(英文叫 App-Specific Passwords)
     4. 点「生成」，给它取个名字（比如"状态墙"）
     5. 复制生成的密码（格式类似 xxxx-xxxx-xxxx-xxxx）

另外，你还需要提前做一件事：
   打开 iPhone/Mac 的「日历」App → 新建一个日历 → 命名（比如"家庭共享"）
   → 右键/长按 → 共享 → 邀请你的家人

准备好了就把 Apple ID 邮箱和应用专用密码给我。
```

### Step 3: External calendar sync (optional, ask after core is done)

```
━━━━ 第二步：工作日程同步（可选）━━━━

你用企业微信或飞书吗？可以把工作日程自动同步到苹果日历里，
这样家人也能看到你的工作安排。

📌 同步是单向的：只从企业微信/飞书读取 → 写入苹果日历，不会反向写入。

如果你用【企业微信】：
  打开企业微信 App → 底部「工作台」→「日程」
  → 右上角 ⋯ →「设置」→「同步到系统日历」
  → 页面会显示 CalDAV 的用户名和密码，把它们给我
  （服务器地址不用管，固定是 caldav.wecom.work）

如果你用【飞书】：
  打开飞书 App → 头像 →「设置」→「日历」
  →「第三方日历管理」→「CalDAV 同步配置」
  → 页面会显示用户名、密码、服务器地址，把它们给我

不用的话直接跳过就行。
```

### Step 4: Location features (optional, ask last)

```
━━━━ 第三步：GPS 定位（可选，大多数人不需要）━━━━

这个功能可以让共享日历显示你的实时位置状态，比如：
  🏠 在家  /  🏢 搬砖中  /  🚗 正在下班途中，距离家 3.2km

但配置比较麻烦，需要以下 4 样东西：

① Apple ID 登录密码（注意：这次是真正的登录密码，不是应用专用密码）
   用于通过 iCloud Find My 获取你 iPhone 的 GPS 坐标
   ⚠️ 首次使用会触发 Apple 双重认证，需要你手动输入验证码

② 高德地图 API Key
   获取方法：
     1. 打开 https://lbs.amap.com → 注册/登录
     2. 控制台 → 应用管理 → 创建新应用
     3. 添加 Key → 服务平台选「Web服务」
     4. 复制生成的 Key

③ 家的经纬度坐标
   打开 https://lbs.amap.com/tools/picker → 搜索你家地址
   → 地图上点击精确位置 → 右侧会显示经纬度，复制下来

④ 公司的经纬度坐标
   同上方法获取公司位置的经纬度

💡 如果你只想让家人看到日程状态，跳过这步就行。
   没有 GPS 定位时，没日程就显示「✅ 空闲」。
```

### AI behavior rules for onboarding

1. **Always start with Step 1 + Step 2**. Do NOT mention GPS/location unless the user asks or finishes Step 2.
2. After user provides Apple ID + app-specific password, **immediately generate the project and test the connection** before asking about Step 3.
3. For Step 3, ask "你用企业微信或飞书吗？" — only expand the detailed instructions for the platform the user says yes to.
4. For Step 4, only mention it if the user asks about location/GPS, or after Steps 2+3 are fully working. Lead with "大多数人不需要这个".
5. **Never ask for all credentials at once.** Walk through one step at a time.
6. When displaying the setup table, use the Chinese instructions above, not English.

### AI behavior rules for config file generation

When writing `~/.status_wall.json`, the AI MUST follow these rules:

1. **Always set feature flags explicitly.** If the user provided WeCom credentials, set `"wecom_enabled": true`. If the user provided Feishu credentials, set `"feishu_enabled": true`. If the user provided GPS-related info, set `"location_enabled": true`. **Do NOT omit these boolean flags** — the code checks them before attempting connections.

2. **Config file template** — the AI should generate exactly this structure (filling in user values, removing unused optional sections):

```json
{
  "icloud_username": "<user's Apple ID email>",
  "icloud_app_password": "<user's app-specific password>",
  "private_calendar_name": "",
  "shared_calendar_name": "Status Wall",
  "wecom_enabled": false,
  "wecom_caldav_username": "",
  "wecom_caldav_password": "",
  "wecom_calendar_name": "",
  "feishu_enabled": false,
  "feishu_caldav_username": "",
  "feishu_caldav_password": "",
  "feishu_caldav_server": "",
  "feishu_calendar_name": "",
  "location_enabled": false,
  "icloud_password": "",
  "amap_api_key": "",
  "home_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
  "work_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
  "polling_interval": 900,
  "commute_polling_interval": 60,
  "log_level": "INFO",
  "data_file": "~/.status_wall_state.json",
  "cookie_directory": "~/.status_wall_cookies"
}
```

Example: if user provided Feishu credentials, the config MUST have:
```json
{
  "feishu_enabled": true,
  "feishu_caldav_username": "u_xxx",
  "feishu_caldav_password": "xxx",
  "feishu_caldav_server": "caldav.feishu.cn"
}
```

### AI behavior rules for testing

After generating the project and writing the config:

1. **Immediately run a connection test** — do NOT ask the user "要我帮你测试吗？", just do it. Write and execute a small Python script that:
   - Connects to iCloud CalDAV and lists calendars
   - If Feishu is enabled: connects to Feishu CalDAV, reads events, syncs to iCloud
   - If WeCom is enabled: connects to WeCom CalDAV, reads events, syncs to iCloud
   - Reports results

2. **If "Status Wall" calendar doesn't exist**, tell the user to create it, but **don't treat it as a blocking error** — use any available calendar temporarily and mention the user needs to create the shared one.

3. **Auto-run sync on first deployment.** After the project is generated, if Feishu/WeCom is enabled, run `status_wall sync` or equivalent Python code automatically. Don't just say "you can run sync later".

4. **Auto-start the daemon.** After successful testing, start the daemon automatically. Don't ask "要我帮你启动守护进程吗？"

### AI behavior rules for CalDAV code generation (CRITICAL)

When writing ANY code that interacts with CalDAV (connection test scripts, sync modules, etc.), the AI MUST follow these **exact patterns**. Deviating from these will cause silent failures.

#### 1. NEVER use `date_search()` — it is DEPRECATED

```python
# ❌ WRONG — will fail silently or return empty
events = calendar.date_search(start=start, end=end)

# ✅ CORRECT — use search() with event=True
events = calendar.search(start=start, end=end, event=True)
```

`date_search()` is deprecated in caldav >= 1.x and may return empty results on some servers (including Feishu). Always use `calendar.search(start=start, end=end, event=True)`.

#### 2. Use a WIDE time range for reading events (±30 days minimum)

```python
# ❌ WRONG — too narrow, will miss events
start = datetime.now() - timedelta(hours=1)
end = datetime.now() + timedelta(days=7)

# ✅ CORRECT — wide range to ensure events are found
start = datetime.now() - timedelta(days=30)
end = datetime.now() + timedelta(days=30)
```

Feishu CalDAV may have timezone or date boundary issues with narrow ranges. Always use ±30 days for the initial test/sync to ensure events are found. The daemon can use a narrower range (7 days) for routine sync.

#### 3. Feishu CalDAV server URL must have `https://` prefix

```python
server = config.get("feishu_caldav_server", "")
if not server.startswith("http"):
    server = f"https://{server}"
```

Users may provide just `caldav.feishu.cn` without the protocol. The code MUST auto-prepend `https://`.

#### 4. Always try ALL calendars if calendar_name doesn't match

```python
calendars = principal.calendars()
target = None
if calendar_name:
    for cal in calendars:
        if cal.name and calendar_name.lower() in cal.name.lower():
            target = cal
            break
# If no match, search ALL calendars
if not target:
    for cal in calendars:
        events = cal.search(start=start, end=end, event=True)
        if events:
            # found events in this calendar
            ...
```

#### 5. Feishu CalDAV connection test template

When testing Feishu CalDAV, use EXACTLY this pattern:

```python
from caldav import DAVClient
from datetime import datetime, timedelta
from icalendar import Calendar as iCalendar

server = feishu_caldav_server
if not server.startswith("http"):
    server = f"https://{server}"

client = DAVClient(url=server, username=feishu_username, password=feishu_password, timeout=30)
principal = client.principal()
calendars = principal.calendars()
print(f"找到 {len(calendars)} 个飞书日历")

now = datetime.now()
start = now - timedelta(days=30)
end = now + timedelta(days=30)

total_events = 0
for cal in calendars:
    print(f"  日历: {cal.name}")
    events = cal.search(start=start, end=end, event=True)  # MUST use search(), NOT date_search()
    print(f"    事件数: {len(events)}")
    total_events += len(events)
    for ev in events:
        ical = iCalendar.from_ical(ev.data)
        for component in ical.walk():
            if component.name == "VEVENT":
                summary = component.get("summary", "")
                dtstart = component.get("dtstart")
                print(f"    - {summary} ({dtstart.dt if dtstart else 'N/A'})")

if total_events == 0:
    print("⚠️ 未找到事件，请确认飞书日历中有日程，且 CalDAV 同步已开启")
else:
    print(f"✅ 共找到 {total_events} 个飞书日程")
```

#### 6. DAVClient must set timeout=30

Feishu CalDAV can be slow. Always set `timeout=30`:

```python
client = DAVClient(url=server, username=username, password=password, timeout=30)
```

## Core Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    共享日历（家人可见）                      │
│              iCloud Shared Calendar                       │
└────────────────────────▲─────────────────────────────────┘
                         │ 写入状态
┌────────────────────────┴─────────────────────────────────┐
│                   状态判断引擎                             │
│  P1: 日程 → 直接显示日程名称                               │
│  P2: GPS定位(可选) → 地理围栏 → 在家/公司/通勤/在外         │
│  P3: 无日程+无定位 → 显示"空闲"                            │
└──────▲──────────────────────▲────────────────────────────┘
       │                      │
┌──────┴──────┐    ┌─────────┴─────────┐
│  日历读取    │    │  GPS 定位 (可选)   │
│  CalDAV     │    │  FindMy + 高德地图  │
│  iCloud     │    │  电子围栏 + 通勤    │
└──────▲──────┘    └───────────────────┘
       │
┌──────┴───────────────────────────────┐
│         外部日历同步 (可选)            │
│  企业微信 CalDAV → 复制到 iCloud 日历  │
│  飞书 CalDAV → 复制到 iCloud 日历     │
└──────────────────────────────────────┘
```

### Feature Tiers

| 层级 | 功能 | 必填配置 | 说明 |
|------|------|----------|------|
| **核心层** | iCloud 日历读写 | Apple ID + 应用专用密码 | 读取私人日历，写入共享日历 |
| **可选层 A** | 企业微信/飞书同步 | CalDAV 账号密码 | 通过 CalDAV 读取外部日程，复制到 iCloud |
| **可选层 B** | FindMy 定位 | Apple ID 主密码 + 高德 API Key + 坐标 | GPS 位置、电子围栏、通勤检测 |

### Status Priority

1. **P1 日程读取 (Calendar Events)** — Read user's private calendar (including synced WeCom/Feishu events). If there's an active event, display it directly.
   - Format: `🚫 产品评审会 (勿扰)` / `📅 [企微] 周会` / `📅 [飞书] 需求评审`
2. **P2 物理锚点 (Location-based, optional)** — Use iCloud Find My to get GPS, then AMap for reverse geocoding.
   - `🏠 在家` / `🏢 搬砖中` / `📍 在中关村软件园` / `🚗 正在下班途中，距离家 X.Xkm`
3. **P3 空闲 (Fallback)** — No event and no location → `✅ 空闲`

### External Calendar Sync Flow (WeCom/Feishu)

```
企业微信/飞书 CalDAV 服务器
        │ CalDAV 读取
        ▼
  读取未来 7 天日程
        │
        ▼
  清理 iCloud 中旧的 [企微]/[飞书] 事件
        │
        ▼
  写入 iCloud 私人日历（带 [企微]/[飞书] 前缀标记）
        │
        ▼
  CalendarReader 正常读取 → 被 StatusWall 感知
```

**WeCom CalDAV 配置方法**: 企业微信 → 日程 → 更多 → 设置 → 同步到系统日历 → 获取用户名和密码，服务器为 `caldav.wecom.work`

**Feishu CalDAV 配置方法**: 飞书 → 设置 → 日历 → 第三方日历管理 → CalDAV 同步 → 获取用户名、密码和服务器地址

## Project Structure

```
apple-calendar-home/
├── setup.py                    # Package setup, extras_require: location=[pyicloud]
├── install.sh                  # Automated install script (venv + deps + optional location)
├── requirements.txt            # Core deps: caldav, icalendar, requests
└── status_wall/
    ├── __init__.py             # version="2.0.0"
    ├── cli.py                  # CLI: init, sync, start, stop, status, once, show-gps
    ├── config.py               # Layered config: core required + wecom/feishu optional + location optional
    ├── daemon.py               # Main daemon: calendar-only or calendar+location mode
    ├── daemon_runner.py        # Background process launcher
    ├── external_calendar_sync.py  # NEW: WeCom/Feishu CalDAV → iCloud sync
    ├── calendar_reader.py      # CalDAV reader for private calendar
    ├── calendar_writer.py      # CalDAV writer for shared calendar
    ├── location_service.py     # (optional) iCloud Find My GPS
    ├── amap_service.py         # (optional) AMap reverse geocoding
    └── state_manager.py        # (optional) Geofence + commute logic
```

## Module Implementation Guide

### 1. Config Module (`config.py`)

Manage layered configuration stored at `~/.status_wall.json` with file permissions `0o600`.

**Critical design decisions:**
- **Lazy loading**: Config uses `@property` with `_data=None` pattern. Import does NOT trigger disk I/O.
- **Deep copy defaults**: Nested dicts (home_location, work_location) are deep-copied to prevent shared reference bugs.
- **Layered init flow**: `interactive_init()` has clear sections — core (required), WeCom (optional), Feishu (optional), location (optional). Each section is gated by `[y/N]` prompt.
- **Feature flags**: `is_location_enabled()`, `is_wecom_enabled()`, `is_feishu_enabled()` check both the enabled flag AND required credentials.
- **Password input**: Use `getpass.getpass()` for all passwords.

**Required config fields (core):**

| Field | Description |
|-------|-------------|
| `icloud_username` | Apple ID email |
| `icloud_app_password` | App-specific password (for CalDAV) |
| `private_calendar_name` | Private calendar name (empty = default) |
| `shared_calendar_name` | Shared calendar name (default: "Status Wall") |

**Optional config fields (WeCom/Feishu):**

| Field | Description |
|-------|-------------|
| `wecom_enabled` | Boolean flag |
| `wecom_caldav_username` | From WeCom calendar settings |
| `wecom_caldav_password` | From WeCom calendar settings |
| `feishu_enabled` | Boolean flag |
| `feishu_caldav_username` | From Feishu calendar settings |
| `feishu_caldav_password` | From Feishu calendar settings |
| `feishu_caldav_server` | Feishu CalDAV server URL |

**Optional config fields (Location):**

| Field | Description |
|-------|-------------|
| `location_enabled` | Boolean flag |
| `icloud_password` | Apple ID main password (for Find My) |
| `amap_api_key` | AMap Web Service API Key |
| `home_location` | `{"lat": float, "lon": float, "radius": 200}` |
| `work_location` | `{"lat": float, "lon": float, "radius": 200}` |

### 2. External Calendar Sync (`external_calendar_sync.py`) — NEW

Sync WeCom/Feishu events to user's iCloud private calendar via CalDAV.

**Critical design decisions:**
- **Tag-based identification**: Synced events get `[企微]` or `[飞书]` prefix in summary. This enables clean-before-write pattern without affecting user's own events.
- **Clean-then-write**: Before writing new events, delete all existing events with matching tag prefix within the time range. Prevents duplicates.
- **UUID-based UID**: Each synced event gets `sw-sync-{uuid4}@status-wall` UID.
- **All-day event handling**: Properly handles both timed events and all-day events (date vs datetime).
- **Periodic sync**: Daemon calls `_maybe_sync_external()` every 30 minutes automatically.
- **WeCom CalDAV server**: `https://caldav.wecom.work`
- **Feishu CalDAV server**: User-provided (varies by organization). Code MUST auto-prepend `https://` if missing.
- **⚠️ MUST use `calendar.search(start=start, end=end, event=True)`** — NOT `date_search()` which is deprecated and returns empty on Feishu.
- **⚠️ Time range for reading**: Use ±30 days (NOT just 7 days forward). Feishu CalDAV may have timezone issues with narrow ranges.
- **⚠️ DAVClient timeout**: Always set `timeout=30` — Feishu CalDAV can be slow.

### 3. Daemon (`daemon.py`) — REFACTORED

Main daemon with optional location services.

**Critical design decisions:**
- **Conditional imports**: Location services (LocationService, AMapService, StateManager) are imported only when `config.is_location_enabled()`. Missing `pyicloud` won't crash the daemon.
- **Calendar-only mode**: When location is disabled, `_determine_calendar_only_state()` provides simple event/free status.
- **Automatic external sync**: `_maybe_sync_external()` runs every 30 minutes within the main loop.
- **Feature logging**: On startup, logs which features are enabled.

### 4. Location Service (`location_service.py`) — OPTIONAL

Use `pyicloud.PyiCloudService` to connect to iCloud and retrieve GPS location from Find My.

**Critical design decisions:**
- **Session persistence**: Pass `cookie_directory` to `PyiCloudService()` so sessions survive restarts.
- **2FA + 2SA handling**: Check BOTH `requires_2fa` AND `requires_2sa`.
- **Connection cooldown**: Exponential backoff (60s → 120s → ... → 600s max).
- **Auto-reconnect**: Set `self.api = None` on failure so next call triggers reconnection.

### 5. AMap Service (`amap_service.py`) — OPTIONAL

Call AMap reverse geocoding API: `https://restapi.amap.com/v3/geocode/regeo`

**Critical design decisions:**
- AMap uses `经度,纬度` (lon,lat) format, NOT lat,lon
- **Memory cache**: Cache results keyed by rounded coordinates (4 decimal places ≈ 10m).
- `get_location_name()` priority: AOI > POI > formatted_address

### 6. Calendar Reader (`calendar_reader.py`)

Read private calendar via CalDAV to detect current events (including synced WeCom/Feishu events).

**Critical design decisions:**
- **All-day event handling**: `_to_naive_datetime()` converts both `date` and `datetime`. Skip all-day events.
- **Timezone normalization**: Convert to UTC first, then strip tzinfo.
- **Search range**: `±24h` to catch spanning events.
- **Picks up synced events**: Events tagged with `[企微]`/`[飞书]` are treated as normal events.

### 7. Calendar Writer (`calendar_writer.py`)

Write status to shared calendar as a full-day event.

**Critical design decisions:**
- **UUID-based UID**: `uuid.uuid4()` for event UID.
- **TRANSPARENT**: Status events show as "free".
- **Clean before write**: Delete old status events by emoji prefix.

### 8. State Manager (`state_manager.py`) — OPTIONAL

Core state machine with geofence and commute detection. Only loaded when location is enabled.

**Critical design decisions:**
- **Path expansion**: `Path(raw_path).expanduser()`
- **Atomic writes**: Write to `.tmp` then `rename()`.
- **Commute trigger**: `geofence_radius + 50m` margin.
- **Dynamic polling**: `commute_mode=True` → 60s, else → 900s.

### 9. CLI (`cli.py`)

Command-line interface with subcommands.

**Available commands:**
- `init` — Interactive config (layered: core → WeCom → Feishu → Location)
- `sync` — Manual trigger for WeCom/Feishu calendar sync
- `start [-f]` — Start daemon (background or foreground)
- `stop` — Stop daemon
- `status` — Show running status + feature flags
- `once [-v]` — Single execution for debugging
- `show-gps [-v]` — Show GPS position (requires location enabled)

### 10. Daemon Runner (`daemon_runner.py`)

**Critical design decisions:**
- **Correct path**: `project_root = Path(__file__).parent.parent`
- **Log to file**: Redirect stdout/stderr to `~/.status_wall.log`

## Dependencies

```
# Core (required)
caldav>=1.3.0       # CalDAV calendar read/write
icalendar>=5.0.0    # iCalendar data parsing
requests>=2.28.0    # HTTP requests

# Optional: Location features
pyicloud>=1.0.0     # iCloud Find My (pip install pyicloud)
```

## Security Notes

- Config file stored with `0o600` permissions
- Use app-specific passwords for CalDAV (not main Apple ID password)
- Main Apple ID password only needed for Find My (optional)
- WeCom/Feishu CalDAV passwords generated in respective apps
- First-time Find My use requires handling Apple 2FA

## Resources

### references/

- `references/source_code.md` — Complete source code of all modules

### scripts/

- `scripts/scaffold_project.sh` — Shell script to scaffold the project structure
