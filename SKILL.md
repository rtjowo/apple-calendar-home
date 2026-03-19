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

- **Trigger**: Leave home/work geofence by 200m → enter commute mode
- **End**: Enter destination geofence by 100m → exit commute mode
- **Smart Polling**: Commute mode = 60s interval; Normal mode = 900s (15min) interval

## Project Structure

```
apple-calendar-home/
├── setup.py                    # Package setup, entry point: status_wall=status_wall.cli:main
├── install.sh                  # Automated install script (venv + deps + shell alias)
├── requirements.txt            # pyicloud>=1.0.0, caldav>=1.3.0, icalendar>=5.0.0
└── status_wall/
    ├── __init__.py             # Package init, version="1.0.0"
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

Implement `interactive_init()` for guided setup and `is_configured()` to check required fields (`icloud_username`, `icloud_app_password`, `amap_api_key`).

### 2. Location Service (`location_service.py`)

Use `pyicloud.PyiCloudService` to connect to iCloud and retrieve GPS location from Find My.

**Key implementation details:**
- Handle 2FA requirement (`api.requires_2fa`)
- Iterate devices, prefer iPhone by checking device name
- Extract `latitude`, `longitude`, `horizontalAccuracy` from `device.location()`
- Return format: `{"lat": float, "lon": float, "accuracy": float, "timestamp": str}`

### 3. AMap Service (`amap_service.py`)

Call AMap reverse geocoding API: `https://restapi.amap.com/v3/geocode/regeo`

**Key implementation details:**
- AMap uses `经度,纬度` (lon,lat) format, NOT lat,lon
- Request with `extensions=all` to get AOI/POI info
- Extract: `formatted_address`, `district`, `street`, `aoi` (from `aois[0].name`), `poi` (from `pois[0].name`)
- `get_location_name()` priority: AOI > POI > formatted_address
- Use `urllib.request` (no extra deps), set `User-Agent: StatusWall/1.0`, timeout=10s

### 4. Calendar Reader (`calendar_reader.py`)

Read private calendar via CalDAV to detect current events.

**Key implementation details:**
- Connect to `https://caldav.icloud.com` with username + app-specific password
- Use `date_search(start=now-1h, end=now+1h)` to find current events
- Parse iCalendar VEVENT components, check if `dtstart <= now <= dtend`
- Handle timezone-aware and naive datetime objects
- Determine busy status from `TRANSP` property: `OPAQUE` = busy, `TRANSPARENT` = free
- Return format: `(event_name: str, is_busy: bool)` or `None`

### 5. Calendar Writer (`calendar_writer.py`)

Write status to shared calendar as a full-day event.

**Key implementation details:**
- Connect to CalDAV, find calendar matching `shared_calendar_name`
- Before writing, clear today's status events by checking emoji prefixes: `🏠🏢🚗📍🚫📅❓`
- Create full-day event with `dtstart=today.date()`, `dtend=tomorrow.date()`
- Set `TRANSP=TRANSPARENT` so status events show as "free"
- Generate unique UID: `status-wall-{timestamp}@{username}`
- Only write when status changes (compare with `last_status`)

### 6. State Manager (`state_manager.py`)

Core state machine with geofence and commute detection.

**Key implementation details:**
- Use Haversine formula for distance calculation (R=6371000m)
- Persist state to JSON file: `last_location`, `last_state`, `commute_mode`, `commute_start_time`
- State constants: `STATE_HOME`, `STATE_WORK`, `STATE_COMMUTE_TO_WORK`, `STATE_COMMUTE_TO_HOME`, `STATE_UNKNOWN`
- Commute trigger: leave geofence by 200m; Arrival: enter geofence by 100m
- During commute-to-home, calculate and display distance to home in km
- Dynamic polling: `commute_mode=True` → 60s, else → 900s

### 7. Daemon (`daemon.py`)

Main daemon process with PID file management.

**Key implementation details:**
- PID file at `~/.status_wall.pid`
- Signal handling: SIGTERM and SIGINT for graceful shutdown
- Main loop: `run_once()` → sleep for `get_polling_interval()` seconds
- Sleep in 1-second increments to respond to signals
- `run_once()` pipeline: read calendar → get location → get location name → determine state → write if changed

### 8. CLI (`cli.py`)

Command-line interface using `argparse` with subcommands.

**Commands:**
- `status_wall init` — Interactive configuration
- `status_wall start [-f]` — Start daemon (background/foreground)
- `status_wall stop` — Stop daemon via SIGTERM
- `status_wall status` — Show running status and config
- `status_wall once [-v]` — Single execution for debugging
- `status_wall show-gps` — Display current GPS + location info + geofence distances

Background start uses `subprocess.Popen` with `start_new_session=True` to launch `daemon_runner.py`.

## Installation

The `install.sh` script handles:
1. Check Python 3.7+
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
