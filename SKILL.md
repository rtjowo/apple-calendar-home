---
name: apple-calendar-home
description: "This skill should be used when the user wants to build an Apple iCloud Status Wall (iCloud 日历状态墙) project — an automated system that aggregates calendar events from multiple platforms (iCloud, WeCom/企业微信, Feishu/飞书) and syncs status to an iCloud shared calendar so family can see the user's real-time schedule. Core feature only requires Apple ID + app-specific password. Optional features include WeCom/Feishu calendar sync via CalDAV, and GPS location via iCloud Find My + AMap reverse geocoding with geofence-based commute detection."
---

# Apple iCloud 状态墙 (Status Wall) v2.0

## Overview

This skill provides the complete knowledge and implementation patterns for building an **Apple iCloud Status Wall** — an automated system that aggregates the user's calendar events from multiple platforms (iCloud, WeCom/企业微信, Feishu/飞书) and syncs status to an iCloud shared calendar. Family or friends can see the user's current status by subscribing to the shared calendar.

**v2.0 架构**: 模块化分层设计，仅 iCloud 日历为必填，企业微信/飞书同步和 GPS 定位均为可选功能。

## User Onboarding Guide

When a user activates this skill, the AI MUST present the following guide **in Chinese** and walk through step by step. Do NOT dump everything at once.

### Step 1: Welcome — explain what this does (ALWAYS show first)

```
🍎 iCloud 日历状态墙

嘿！这个工具可以帮你搞定一件事：

    让你的家人随时知道你在忙什么

原理很简单：它会读取你各个平台的日程（iCloud / 企业微信 / 飞书），
在一个 iCloud 共享日历里维护一个「置顶状态」，实时显示你当前在干嘛。
你的家人订阅这个日历，打开手机就能一眼看到：

  🚫 产品评审会 (勿扰)     ← 你 iPhone 日历里正在进行的会议
  📅 [飞书] 需求评审        ← 飞书上的日程（自动同步）
  📅 [企微] 部门周会        ← 企业微信的日程（自动同步）
  🏠 在家                   ← 没日程时，根据 GPS 定位显示（可选）
  ✅ 空闲                   ← 啥事都没有

判断优先级：iPhone日程 > 飞书/企微日程 > GPS定位 > 空闲
同步每 15 分钟自动刷新一次。

下面我一步步带你配置，很快的。
```

### Step 2: Collect credentials — what do you need and how to get it

After showing Step 1, the AI MUST say:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
我需要你提供一些信息来连接各个日历平台。
先告诉我你用哪些：

  ✅ iCloud 日历 — 必须的，这是基础
  📌 企业微信日历 — 可选，如果你公司用企微
  📌 飞书日历 — 可选，如果你公司用飞书

下面是每项需要的信息和获取方法👇
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【iCloud — 必填】

  ① Apple ID 邮箱
     就是你登录 iCloud 用的那个邮箱

  ② 应用专用密码（⚠️ 不是你的 Apple ID 登录密码！）
     这是 Apple 专门为第三方 App 生成的密码，获取方法：
       1. 打开 https://appleid.apple.com → 登录
       2. 找到「App 专用密码」(App-Specific Passwords)
       3. 点「生成」，名字随便填（比如"状态墙"）
       4. 复制生成的密码（格式：xxxx-xxxx-xxxx-xxxx）

【企业微信 — 可选】

  ① CalDAV 用户名
  ② CalDAV 密码
     获取方法：
       打开企业微信 App → 底部「工作台」→「日程」
       → 右上角 ⋯ →「设置」→「同步到系统日历」
       → 页面会显示用户名和密码，复制给我就行
     （服务器地址不用管，我知道是 caldav.wecom.work）

【飞书 — 可选】

  ① CalDAV 用户名
  ② CalDAV 密码
  ③ CalDAV 服务器地址
     获取方法：
       打开飞书 App → 头像 →「设置」→「日历」
       →「第三方日历管理」→「CalDAV 同步配置」
       → 页面会显示用户名、密码和服务器地址，都复制给我

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
准备好了就把上面这些信息发给我，
不用的平台直接跳过不填就行。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: After receiving credentials — generate project, test, and sync

After the user provides credentials, the AI MUST:
1. Generate the project and write config file
2. Immediately test all connections (do NOT ask)
3. Immediately run sync (do NOT ask)
4. Report results

Then proceed to Step 4.

### Step 4: Shared calendar setup

After sync succeeds, the AI MUST say:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 连接和同步都成功了！

现在还差最后一步：创建一个共享日历，让你的家人能看到。

📱 iPhone 操作方法：
  1. 打开「日历」App
  2. 底部点「日历」（日历列表）
  3. 左下角点「添加日历」
  4. 给日历取个名字（比如「家庭共享」或「我的状态」）
  5. 创建后，点击这个日历右边的 ⓘ
  6. 往下找到「共享」→「添加人员」→ 输入家人的 Apple ID 邮箱
  7. 家人会收到一个日历订阅邀请，接受后就能看到了

💻 Mac 操作方法：
  1. 打开「日历」App
  2. 左侧栏右键 →「新建日历」
  3. 命名后，右键这个日历 →「共享日历」
  4. 添加家人的 Apple ID 邮箱

创建好后，把日历名字告诉我（比如「家庭共享」），我来配置写入目标。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: After receiving calendar name — configure and start daemon

After user provides the shared calendar name:
1. Update config: `shared_calendar_name` = user's calendar name
2. Run one more sync to verify writing to the correct calendar
3. Start the daemon automatically (every 15 minutes refresh)
4. Report final status

```
✅ 全部搞定！

你的日历状态墙已经在运行了：
  • 同步间隔：每 15 分钟自动刷新
  • 共享日历：「{calendar_name}」
  • 数据来源：iCloud{" + 企业微信" if wecom}" + 飞书" if feishu}

你的家人订阅「{calendar_name}」后，就能随时看到你的日程状态了。
```

### Step 6: GPS location (optional, only mention if user asks or everything else is done)

Only show this if the user specifically asks about location/GPS features, or after everything above is working perfectly. Lead with "大多数人不需要这个".

```
━━━━ GPS 定位（可选，大多数人不需要）━━━━

这个功能可以让共享日历显示你的实时位置状态：
  🏠 在家  /  🏢 搬砖中  /  🚗 正在下班途中，距离家 3.2km

但配置比较麻烦，需要 4 样东西：

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

💡 没有 GPS 定位时，没日程就显示「✅ 空闲」，够用了。
```

### AI behavior rules for onboarding

1. **Always show Step 1 first.** Let the user understand what this does before asking for anything.
2. **Then show Step 2 in full** — list ALL platforms (iCloud + WeCom + Feishu) at once with their credential requirements and how to get them. Do NOT split into multiple back-and-forth rounds. Let the user provide everything they have in one message.
3. **After receiving credentials → immediately generate project, test connections, and run sync.** Do NOT ask "要我帮你测试吗？" or "要我同步吗？". Just do it.
4. **After sync succeeds → show Step 4 (shared calendar setup).** Explain how to create a shared calendar on iPhone/Mac, then ask the user for the calendar name.
5. **After receiving calendar name → update config, run one more sync, start daemon.** The daemon syncs every 15 minutes.
6. **GPS/location (Step 6) — only mention if the user asks**, or after everything else is working perfectly. Lead with "大多数人不需要这个".
7. **Never skip the shared calendar step.** Without it, family can't see anything.
8. When displaying instructions, use the Chinese text from the Steps above, not English.

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
   - If Feishu is enabled: use RAW HTTP requests (`requests` library) with `calendar-multiget` to read events, then sync to iCloud. **Do NOT use the `caldav` library for Feishu — it will fail silently (GET 403).**
   - If WeCom is enabled: use RAW HTTP requests (`requests` library) with individual `GET` to read events, then sync to iCloud. **Do NOT use the `caldav` library for WeCom — root URL returns 403.**
   - Reports results

2. **After the user provides a shared calendar name**, update `shared_calendar_name` in config, then run sync once more to verify writing to the correct calendar.

3. **Auto-start the daemon with 15-minute polling interval.** The daemon should:
   - Sync external calendars (WeCom/Feishu) every 15 minutes
   - Read iCloud private calendar and determine current status every 15 minutes
   - Write status to the shared calendar
   - Config: `"polling_interval": 900` (900 seconds = 15 minutes)
   Do NOT ask "要我帮你启动守护进程吗？" — just start it.

4. **If the shared calendar doesn't exist yet**, tell the user how to create it (Step 4 from onboarding), but **don't treat it as a blocking error** — use any available calendar temporarily.

### ⚠️⚠️⚠️ CRITICAL: Do NOT use `caldav` library for Feishu or WeCom ⚠️⚠️⚠️

**Neither Feishu nor WeCom supports the standard CalDAV protocol properly.** The `caldav` Python library **WILL fail silently** — it will connect successfully but return 0 events.

- **Feishu**: GET .ics → 403, calendar-query calendar-data → 404. Only `calendar-multiget` works.
- **WeCom**: Root `/` → 403, calendar-multiget → 403. Only individual `GET .ics` works.

**You MUST use the raw HTTP implementations** (`_read_feishu_events_raw()` and `_read_wecom_events_raw()`) from `source_code.md`. These use the `requests` library directly with XML REPORT requests. The `caldav` library is ONLY used for iCloud CalDAV (which works fine with standard protocol).

### AI behavior rules for CalDAV code generation (CRITICAL)

When writing ANY code that interacts with CalDAV (connection test scripts, sync modules, etc.), the AI MUST follow these **exact patterns**. Deviating from these will cause silent failures.

#### 1. Feishu CalDAV requires RAW HTTP — do NOT use caldav library for Feishu (CRITICAL)

Feishu CalDAV has non-standard behavior that breaks most caldav library versions:
- `calendar-query` REPORT: returns event hrefs but **calendar-data returns 404**
- `GET` individual `.ics` files: returns **403 Forbidden**
- `calendar-multiget` REPORT: **this is the ONLY way** to get event data

Therefore, for Feishu, you MUST use raw HTTP requests (the `requests` library), NOT the `caldav` library. The `_read_feishu_events_raw()` method in `source_code.md` shows the exact implementation.

**The 3-step flow for Feishu:**
```
Step 1: PROPFIND → get calendar URLs
Step 2: calendar-query REPORT → get event href list (no data)
Step 3: calendar-multiget REPORT → get actual calendar-data ✅
```

#### 2. NEVER use `date_search()` — it is DEPRECATED

```python
# ❌ WRONG — will fail silently or return empty
events = calendar.date_search(start=start, end=end)

# ✅ CORRECT — use search() with event=True (for non-Feishu servers like WeCom)
events = calendar.search(start=start, end=end, event=True)
```

#### 3. Use a WIDE time range for reading events (±30 days minimum)

```python
# ❌ WRONG — too narrow, will miss events
start = datetime.now() - timedelta(hours=1)
end = datetime.now() + timedelta(days=7)

# ✅ CORRECT — wide range to ensure events are found
start = datetime.now() - timedelta(days=30)
end = now + timedelta(days=30)
```

#### 4. Feishu CalDAV server URL must have `https://` prefix

```python
server = config.get("feishu_caldav_server", "")
if not server.startswith("http"):
    server = f"https://{server}"
```

#### 5. Feishu CalDAV connection test template

When testing Feishu CalDAV, use EXACTLY this raw HTTP pattern (NOT the caldav library):

```python
import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime, timedelta
from xml.etree import ElementTree as ET
from icalendar import Calendar as iCalendar

server = feishu_caldav_server
if not server.startswith("http"):
    server = f"https://{server}"

auth = HTTPBasicAuth(feishu_username, feishu_password)
ns = {"D": "DAV:", "C": "urn:ietf:params:xml:ns:caldav"}

# Step 1: PROPFIND 获取日历
principal_url = f"{server}/{feishu_username}/"
propfind_xml = '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/></D:prop></D:propfind>'
resp = requests.request("PROPFIND", principal_url, auth=auth, data=propfind_xml,
                        headers={"Content-Type": "application/xml", "Depth": "1"}, timeout=30)

root = ET.fromstring(resp.text)
calendar_urls = []
for response in root.findall(".//D:response", ns):
    href = response.find("D:href", ns)
    if href is not None and href.text and href.text != f"/{feishu_username}/":
        calendar_urls.append(href.text)
        print(f"  日历: {href.text}")

# Step 2: calendar-query 获取事件引用
now = datetime.utcnow()
start = (now - timedelta(days=30)).strftime("%Y%m%dT%H%M%SZ")
end = (now + timedelta(days=30)).strftime("%Y%m%dT%H%M%SZ")

for cal_path in calendar_urls:
    cal_url = f"{server}{cal_path}"
    query_xml = f'''<?xml version="1.0"?>
<C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
  <D:prop><D:getetag/></D:prop>
  <C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT">
    <C:time-range start="{start}" end="{end}"/>
  </C:comp-filter></C:comp-filter></C:filter>
</C:calendar-query>'''
    resp = requests.request("REPORT", cal_url, auth=auth, data=query_xml,
                            headers={"Content-Type": "application/xml", "Depth": "1"}, timeout=30)
    root = ET.fromstring(resp.text)
    hrefs = [r.find("D:href", ns).text for r in root.findall(".//D:response", ns)
             if r.find("D:href", ns) is not None and r.find("D:href", ns).text]

    if not hrefs:
        print("  无事件")
        continue

    # Step 3: calendar-multiget 获取实际数据
    href_els = "\n".join(f"  <D:href>{h}</D:href>" for h in hrefs)
    multiget_xml = f'''<?xml version="1.0"?>
<C:calendar-multiget xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
  <D:prop><D:getetag/><C:calendar-data/></D:prop>
{href_els}
</C:calendar-multiget>'''
    resp = requests.request("REPORT", cal_url, auth=auth, data=multiget_xml,
                            headers={"Content-Type": "application/xml", "Depth": "1"}, timeout=30)
    root = ET.fromstring(resp.text)
    for response in root.findall(".//D:response", ns):
        for propstat in response.findall("D:propstat", ns):
            cal_data = propstat.find(".//C:calendar-data", ns)
            if cal_data is not None and cal_data.text:
                ical = iCalendar.from_ical(cal_data.text)
                for c in ical.walk():
                    if c.name == "VEVENT":
                        print(f"    ✅ {c.get('summary')} ({c.get('dtstart').dt})")
```

#### 6. WeCom (企业微信) also requires RAW HTTP — different pattern from Feishu (CRITICAL)

WeCom CalDAV has its own non-standard behavior, different from Feishu:

| Operation | Feishu | WeCom |
|-----------|--------|-------|
| `calendar-query` with `calendar-data` | ❌ 404 | ❌ 404 |
| `GET` individual `.ics` | ❌ 403 | ✅ 200 |
| `calendar-multiget` | ✅ 200 | ❌ 403 |
| Root URL `/` | ✅ works | ❌ 403 (must use `/.well-known/caldav`) |

**WeCom 3-step flow (different from Feishu!):**
```
Step 1: PROPFIND /calendar/ Depth:1 → get calendar URLs
Step 2: calendar-query REPORT → get event href list (etag only, no data)
Step 3: GET each .ics file individually → get calendar data ✅
```

Do NOT use `calendar-multiget` for WeCom (returns 403). Do NOT use the caldav library for WeCom (root URL 403 breaks `principal()`).

See `_read_wecom_events_raw()` in `source_code.md` for the exact implementation.

## Core Architecture

```
┌──────────────────────────────────────────────────────────┐
│              共享日历（家人可见）                            │
│   包含：① 置顶状态事件（实时更新）                          │
│         ② [企微] 日程（自动同步）                          │
│         ③ [飞书] 日程（自动同步）                          │
└────────────────────────▲─────────────────────────────────┘
                         │ ① 写入置顶状态  ② 写入同步日程
          ┌──────────────┴──────────────┐
          │                             │
┌─────────┴───────────┐    ┌───────────┴───────────────────┐
│  状态判断引擎        │    │  外部日历同步 (可选)            │
│  读取私人+共享日历   │    │  飞书 CalDAV → 写入共享日历     │
│                     │    │  企微 CalDAV → 写入共享日历     │
│  P1: 私人日历有日程  │    └─────────────────────────────────┘
│  P2: 共享日历有日程  │
│  P3: GPS定位(可选)  │
│  P4: 显示"空闲"     │
└──────▲──────────────┘
       │ 读取
┌──────┴──────────────────────────────┐
│           iCloud CalDAV              │
│  ┌────────────┐  ┌────────────────┐ │
│  │ 私人日历    │  │ 共享日历        │ │
│  │ (用户日程)  │  │ (同步+状态)    │ │
│  └────────────┘  └────────────────┘ │
└─────────────────────────────────────┘
```

### Feature Tiers

| 层级 | 功能 | 必填配置 | 说明 |
|------|------|----------|------|
| **核心层** | iCloud 日历读写 | Apple ID + 应用专用密码 | 读取私人日历，写入共享日历 |
| **可选层 A** | 企业微信/飞书同步 | CalDAV 账号密码 | 通过 CalDAV 读取外部日程，复制到 iCloud |
| **可选层 B** | FindMy 定位 | Apple ID 主密码 + 高德 API Key + 坐标 | GPS 位置、电子围栏、通勤检测 |

### Status Priority (CRITICAL — 4-tier priority)

The shared calendar ALWAYS has exactly ONE "pinned status" all-day event that reflects the user's current state. This event is updated every polling cycle (15 min). The status is determined by the following priority:

1. **P1 私人日历日程 (Private Calendar Events)** — Read user's iCloud private calendar. If there's an active event NOW, display it. These are the user's OWN events (iPhone 日历里的日程).
   - Format: `🚫 产品评审会 (勿扰)` / `📅 团队周会`
2. **P2 共享日历日程 (Shared Calendar Events)** — Read the shared calendar. If there's an active event tagged with `[企微]` or `[飞书]` (synced from external calendars), display it.
   - Format: `📅 [企微] 部门周会` / `📅 [飞书] 需求评审`
   - Note: The pinned status event itself (identified by emoji prefix) is excluded from this check.
3. **P3 GPS 定位 (Location-based, optional)** — If no event at all and location is enabled, use iCloud Find My to get GPS + AMap reverse geocoding.
   - `🏠 在家` / `🏢 搬砖中` / `📍 在中关村软件园` / `🚗 正在下班途中，距离家 X.Xkm`
4. **P4 空闲 (Fallback)** — No event AND no location → `✅ 空闲`

**Key architecture**: External calendar sync (飞书/企微) writes events directly into the **shared calendar**. The daemon reads **both** private calendar and shared calendar to determine status. This means family can see both the synced events AND the pinned status in one calendar.

### External Calendar Sync Flow (WeCom/Feishu)

```
企业微信/飞书 CalDAV 服务器
        │ CalDAV 读取
        ▼
  读取未来 30 天日程
        │
        ▼
  清理共享日历中旧的 [企微]/[飞书] 事件
        │
        ▼
  写入 iCloud 共享日历（带 [企微]/[飞书] 前缀标记）
        │
        ▼
  家人直接在共享日历看到飞书/企微日程
  状态引擎读取共享日历 → 用于 P2 优先级判断
```

**WeCom CalDAV 配置方法**: 企业微信 → 日程 → 更多 → 设置 → 同步到系统日历 → 获取用户名和密码，服务器为 `caldav.wecom.work`（代码中需使用 `https://caldav.wecom.work/.well-known/caldav`，根路径会 403）

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

Sync WeCom/Feishu events to user's iCloud **shared calendar** (NOT private calendar!) via CalDAV.

**Critical design decisions:**
- **Writes to SHARED calendar**: Synced events go directly into the shared calendar so family can see them. The old design wrote to private calendar — this is changed.
- **`_get_shared_calendar()`**: Finds the shared calendar by name match (config `shared_calendar_name`). Replaces old `_get_icloud_calendar()`.
- **Tag-based identification**: Synced events get `[企微]` or `[飞书]` prefix in summary. This enables clean-before-write pattern.
- **Clean-then-write**: Before writing new events, delete all existing events with matching tag prefix within the time range. Prevents duplicates.
- **UUID-based UID**: Each synced event gets `sw-sync-{uuid4}@status-wall` UID.
- **All-day event handling**: Properly handles both timed events and all-day events (date vs datetime).
- **Periodic sync**: Daemon calls `_maybe_sync_external()` every 15 minutes automatically.
- **WeCom CalDAV server**: `https://caldav.wecom.work/.well-known/caldav` (root `/` returns 403, must use well-known endpoint)
- **Feishu CalDAV server**: User-provided (varies by organization). Code MUST auto-prepend `https://` if missing.
- **⚠️ Both Feishu and WeCom use RAW HTTP, not caldav library**: Neither server fully supports standard CalDAV protocol. Each has a dedicated `_read_xxx_events_raw()` method using pure `requests`.
- **⚠️ Feishu flow**: PROPFIND → calendar-query → **calendar-multiget** (Feishu blocks GET but supports multiget). **Timeout must be 120s** (not 30s or 60s) with 3 retries — Feishu CalDAV is extremely slow from cloud servers.
- **⚠️ WeCom flow**: PROPFIND /calendar/ → calendar-query → **GET each .ics** (WeCom blocks multiget but supports GET)
- **⚠️ WeCom root URL**: Must use `/.well-known/caldav` or `/calendar/` — root `/` returns 403
- **⚠️ Time range**: Use ±30 days. **⚠️ DAVClient timeout**: Always set `timeout=30`.

### 3. Daemon (`daemon.py`) — REFACTORED

Main daemon with 4-tier status priority and optional location services.

**Critical design decisions:**
- **4-tier status priority**: P1 native events → P2 synced events → P3 GPS location → P4 free. The daemon calls `calendar_reader.get_current_events()` which returns ALL active events with source classification, then applies priority.
- **Pinned status**: Every cycle, the daemon determines the current status and writes it to the shared calendar as a single all-day event. This is the "pinned status" that family always sees.
- **Conditional imports**: Location services (LocationService, AMapService, StateManager) are imported only when `config.is_location_enabled()`. Missing `pyicloud` won't crash the daemon.
- **Automatic external sync**: `_maybe_sync_external()` runs every 15 minutes within the main loop.
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

Read **both** private calendar and shared calendar via CalDAV to detect current events.

**Critical design decisions:**
- **Reads TWO calendars**: `get_current_events()` reads private calendar AND shared calendar separately, returns `{"private": [...], "shared": [...]}`.
- **Filters out status events**: Events written by CalendarWriter (identified by emoji prefix like `✅`, `🚫`, `📅` etc.) are excluded when reading the shared calendar, to avoid circular detection.
- **Source classification**: Private calendar events are `"native"`, shared calendar events with `[企微]`/`[飞书]` prefix are `"synced"`.
- **All-day event handling**: `_to_naive_datetime()` converts both `date` and `datetime`. Skip all-day events.
- **Timezone normalization**: Convert to UTC first, then strip tzinfo.
- **Search range**: `±24h` to catch spanning events.

### 7. Calendar Writer (`calendar_writer.py`)

Write the **pinned status** to shared calendar as a full-day event. The shared calendar ALWAYS has exactly one status event that reflects the user's current state.

**Critical design decisions:**
- **UUID-based UID**: `uuid.uuid4()` for event UID.
- **TRANSPARENT**: Status events show as "free" (won't block the user's schedule).
- **Clean before write**: Delete ALL old status events (identified by emoji prefix) before writing the new one. This ensures only ONE status event exists at any time — the "pinned" status.
- **Pinned status concept**: Family sees exactly one all-day event in the shared calendar that always shows the current status. This acts like a "pinned message" — always at the top, always current.

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
