---
name: apple-calendar-home
description: "This skill should be used when the user wants to build an Apple iCloud Status Wall (iCloud 日历状态墙) project — an automated status update system that syncs real-time status (calendar events, GPS location, commute detection) to an iCloud shared calendar. It covers the full project architecture including iCloud Find My location, CalDAV calendar read/write, AMap reverse geocoding, geofence-based commute detection, and daemon process management."
---

# Apple iCloud 状态墙 (Status Wall)

## Overview

This skill provides the complete knowledge and implementation patterns for building an **Apple iCloud Status Wall** — an automated system that reads the user's real-time status (calendar events + GPS location) and syncs it to an iCloud shared calendar. Family or friends can see the user's current status by subscribing to the shared calendar.

## Core Architecture

The system follows a priority-based status determination pipeline:

```
P1: 日程读取 → 如有正在进行的日程，直接显示日程名称
P2: 物理锚点 → 获取 GPS → 逆地理编码 → 地理围栏判断 → 状态输出
```

### Status Priority

1. **P1 日程读取 (Calendar Events)** — Read the user's private calendar. If there's an active event, display it directly.
   - Format: `🚫 产品评审会 (勿扰)` (busy) or `📅 周会` (free)
2. **P2 物理锚点 (Location-based)** — Use iCloud Find My to get GPS, then AMap API for reverse geocoding.
   - `🏠 在家` — within home geofence
   - `🏢 搬砖中` — within work geofence
   - `📍 在中关村软件园` — at an AMap AOI location
   - `🚗 正在上班途中` / `🚗 正在下班途中，距离家 X.Xkm` — commuting

### Commute Detection Logic

- **Trigger**: Leave home/work geofence by `radius + 50m` → enter commute mode
- **End**: Enter destination geofence (within configured radius) → exit commute mode
- **Smart Polling**: Commute mode = 60s interval; Normal mode = 900s (15min) interval
- **Failure Recovery**: 3 consecutive failures → reset all connections; exponential backoff on sleep

## Project Structure

```
apple-calendar-home/
├── setup.py                    # Package setup, entry point: status_wall=status_wall.cli:main
├── install.sh                  # Automated install script (venv + deps + shell alias)
├── requirements.txt            # pyicloud>=1.0.0, caldav>=1.3.0, icalendar>=5.0.0
└── status_wall/
    ├── __init__.py             # Package init, version="1.1.0"
    ├── cli.py                  # CLI entry: init, start, stop, status, once, show-gps
    ├── config.py               # Config management (~/.status_wall.json)
    ├── daemon.py               # Main daemon loop with PID management
    ├── daemon_runner.py        # Background process launcher
    ├── calendar_reader.py      # CalDAV reader for private calendar
    ├── calendar_writer.py      # CalDAV writer for shared calendar (full-day events)
    ├── location_service.py     # iCloud Find My GPS via pyicloud
    ├── amap_service.py         # AMap reverse geocoding API
    └── state_manager.py        # State machine: geofence + commute logic
```

## Module Implementation Guide

### 1. Config Module (`config.py`)

Manage configuration stored at `~/.status_wall.json` with file permissions `0o600`.

**Critical design decisions:**
- **Lazy loading**: Config uses `@property` with `_data=None` pattern. Import does NOT trigger disk I/O — only first `get()`/`is_configured()` call reads the file. This prevents import-time failures if config is corrupted.
- **Password input**: Use `getpass.getpass()` for passwords (not plain `input()`), so they don't echo to terminal.
- **Cookie directory**: Include `cookie_directory` field (default `~/.status_wall_cookies`) for pyicloud session persistence.

**Required config fields:**

| Field | Description |
|-------|-------------|
| `icloud_username` | Apple ID email |
| `icloud_password` | Apple ID main password (for Find My) |
| `icloud_app_password` | App-specific password (for CalDAV) |
| `amap_api_key` | AMap Web Service API Key |
| `home_location` | `{"lat": float, "lon": float, "radius": 200}` |
| `work_location` | `{"lat": float, "lon": float, "radius": 200}` |
| `private_calendar_name` | Private calendar name to read events from |
| `shared_calendar_name` | Shared calendar name to write status (default: "Status Wall") |
| `polling_interval` | Normal polling interval in seconds (default: 900) |
| `commute_polling_interval` | Commute mode polling interval (default: 60) |
| `log_level` | Logging level (default: "INFO") |
| `data_file` | State persistence file path |
| `cookie_directory` | pyicloud session cookie directory (default: `~/.status_wall_cookies`) |

### 2. Location Service (`location_service.py`)

Use `pyicloud.PyiCloudService` to connect to iCloud and retrieve GPS location from Find My.

**Critical design decisions:**
- **Session persistence**: Pass `cookie_directory` to `PyiCloudService()` so sessions survive restarts. Without this, every restart triggers 2FA.
- **2FA + 2SA handling**: Check BOTH `requires_2fa` AND `requires_2sa` — they are different auth methods. Implement interactive code input and `trust_session()`.
- **Connection cooldown**: Track `_last_connect_attempt` with exponential backoff (60s → 120s → ... → 600s max) to avoid Apple rate-limiting/account lockout.
- **Device location format**: `device.location()` returns `{"latitude": ..., "longitude": ..., ...}` directly. Some pyicloud versions nest it under a `"location"` key — handle both cases.
- **Auto-reconnect**: Set `self.api = None` on failure so next call triggers reconnection.

### 3. AMap Service (`amap_service.py`)

Call AMap reverse geocoding API: `https://restapi.amap.com/v3/geocode/regeo`

**Critical design decisions:**
- AMap uses `经度,纬度` (lon,lat) format, NOT lat,lon
- **Memory cache**: Cache results keyed by rounded coordinates (4 decimal places ≈ 10m), clear when cache exceeds 100 entries. Prevents hammering AMap API during commute.
- Extract: `formatted_address`, `district`, `street`, `aoi` (from `aois[0].name`), `poi` (from `pois[0].name`)
- `get_location_name()` priority: AOI > POI > formatted_address
- Validate `aois`/`pois` are actually `list` type before indexing (AMap sometimes returns empty string instead of list)

### 4. Calendar Reader (`calendar_reader.py`)

Read private calendar via CalDAV to detect current events.

**Critical design decisions:**
- **All-day event handling**: `event_start.dt` returns `date` (not `datetime`) for all-day events. Comparing `date <= datetime` raises `TypeError`. Solution: `_to_naive_datetime()` converts both `date` and `datetime` uniformly. Skip all-day events entirely (they shouldn't show as "busy" status).
- **Timezone normalization**: Convert timezone-aware datetimes to UTC first, then strip tzinfo. Simple `replace(tzinfo=None)` is wrong for non-UTC timezones.
- **Search range**: Use `±24h` (not `±1h`) to catch all-day events that span the current time.
- **Auto-reconnect**: Set `self.principal = None` on failure, `_ensure_connected()` retries.
- **Calendar selection**: Skip the shared status calendar by name match, not just "status" keyword.

### 5. Calendar Writer (`calendar_writer.py`)

Write status to shared calendar as a full-day event.

**Critical design decisions:**
- **UUID-based UID**: Use `uuid.uuid4()` for event UID, NOT timestamp-based. Timestamp at second precision causes collisions during high-frequency commute polling (60s).
- **Connection reuse**: `_ensure_connected()` pattern — only reconnect when `target_calendar` is None.
- **Robust cleanup**: `clear_today_events()` uses `break` after `event.delete()` to avoid deleting the same event twice.
- Set `TRANSP=TRANSPARENT` so status events show as "free"
- Use `datetime.utcnow()` for `dtstamp`/`created`/`last-modified` per RFC 5545

### 6. State Manager (`state_manager.py`)

Core state machine with geofence and commute detection.

**Critical design decisions:**
- **Path expansion**: `Path(raw_path).expanduser()` — without this, `Path("~/.status_wall_state.json").exists()` is always `False`.
- **Atomic writes**: Write to `.tmp` file first, then `rename()` to prevent corruption on crash.
- **State recovery**: Store `last_display` in state file so daemon process restart can resume without re-writing unchanged status.
- **Null coordinate guard**: Return `(False, inf)` for unconfigured geofences (lat=0, lon=0) instead of false-positive matches.
- **Commute trigger**: Use `geofence_radius + 50m` margin instead of hard-coded 200m.
- **Emoji bug fix**: Original code missed setting `emoji = "🚗"` in the commute-to-home trigger branch; extracted `_commute_home_display()` helper to avoid duplication.
- Dynamic polling: `commute_mode=True` → 60s, else → 900s

### 7. Daemon (`daemon.py`)

Main daemon process with PID file management.

**Critical design decisions:**
- **Failure recovery**: Track `_consecutive_failures`; after 3 consecutive failures, call `_reset_connections()` to recreate all service instances. Use exponential backoff for sleep interval on failure.
- **PID cleanup**: `is_running()` cleans up stale PID files (process dead but file remains). Expose `cleanup_pid()` for CLI.
- **Status persistence**: Restore `last_status` from `state_manager.get_last_display()` on startup to avoid re-writing unchanged status.
- **Null-safe logging**: Guard `lat`/`lon` against `None` before `f"{lat:.6f}"` formatting.
- **Logging setup**: Check `if not root.handlers` to prevent duplicate log entries on repeated `_setup_logging()` calls.

### 8. CLI (`cli.py`)

Command-line interface using `argparse` with subcommands.

**Critical design decisions:**
- **Start verification**: After `Popen`, wait 1s and check `process.poll()` to detect immediate crash.
- **Graceful stop**: Wait up to 5s for SIGTERM, then SIGKILL. Clean up stale PID file.
- **State file path**: Use `.expanduser()` on state file path in `cmd_status`.

### 9. Daemon Runner (`daemon_runner.py`)

**Critical design decisions:**
- **Correct path**: `project_root = Path(__file__).parent.parent` (not `.parent`) — needs the project root, not the `status_wall/` package directory.
- **Log to file**: Redirect stdout/stderr to `~/.status_wall.log` so background process errors are debuggable.

## Installation

The `install.sh` script handles:
1. Check Python 3.8+ (validates both major AND minor version)
2. Create virtualenv in project directory
3. Install requirements + `pip install -e .`
4. Add shell alias to `.zshrc` or `.bashrc`
5. Optionally create `/usr/local/bin/status_wall` global command

## Dependencies

```
pyicloud>=1.0.0     # iCloud Find My location
caldav>=1.3.0       # CalDAV calendar read/write
icalendar>=5.0.0    # iCalendar data parsing
```

## Security Notes

- Store config file with `0o600` permissions (owner read/write only)
- Use app-specific passwords for CalDAV (not main Apple ID password)
- The main Apple ID password is needed for Find My (pyicloud limitation)
- First-time use requires handling Apple 2FA

## Resources

### references/

- `references/source_code.md` — Complete source code of all modules for reference when generating or modifying the project

### scripts/

- `scripts/scaffold_project.sh` — Shell script to quickly scaffold the complete project structure and generate all source files
