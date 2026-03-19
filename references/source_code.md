# Apple Calendar Home - Complete Source Code Reference

This document contains the complete source code for all modules of the Apple iCloud Status Wall project.

## setup.py

```python
#!/usr/bin/env python3
""" Status Wall - Apple iCloud 状态墙 """

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="status-wall",
    version="1.0.0",
    author="Status Wall Assistant",
    description="Apple iCloud 状态墙守护进程 - 自动更新用户状态到共享日历",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.7",
    install_requires=[
        "pyicloud>=1.0.0",
        "caldav>=1.3.0",
        "icalendar>=5.0.0",
    ],
    entry_points={
        "console_scripts": [
            "status_wall=status_wall.cli:main",
        ],
    },
)
```

## requirements.txt

```
pyicloud>=1.0.0
caldav>=1.3.0
icalendar>=5.0.0
```

## install.sh

```bash
#!/bin/bash
# Status Wall 安装脚本
set -e

echo "🍎 Apple iCloud 状态墙 - 安装脚本"
echo "=================================="

# 检查 Python
echo "检查 Python 环境..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 Python3，请先安装"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1)
if [ "$PYTHON_VERSION" -lt 3 ]; then
    echo "❌ 错误: 需要 Python 3.7 或更高版本"
    exit 1
fi

echo "✅ Python: $(python3 --version)"

# 创建虚拟环境
echo ""
echo "创建虚拟环境..."
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate

# 升级 pip
echo "升级 pip..."
pip install --upgrade pip

# 安装依赖
echo ""
echo "安装依赖..."
pip install -r requirements.txt

# 安装 status_wall
echo ""
echo "安装 status_wall..."
pip install -e .

# 创建启动脚本
echo ""
echo "创建快捷命令..."

SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    ALIAS_LINE="alias status_wall='$PROJECT_DIR/venv/bin/status_wall'"
    if ! grep -q "status_wall" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Status Wall" >> "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo "✅ 已添加 alias 到 $SHELL_RC"
    fi
fi

# 创建全局快捷方式（可选）
GLOBAL_BIN="/usr/local/bin/status_wall"
if [ -w "$(dirname "$GLOBAL_BIN")" ]; then
    cat > "$GLOBAL_BIN" << EOF
#!/bin/bash
source "$PROJECT_DIR/venv/bin/activate"
status_wall "\$@"
EOF
    chmod +x "$GLOBAL_BIN"
    echo "✅ 已创建全局命令: status_wall"
else
    echo "💡 提示: 可以通过以下方式运行:"
    echo "   $PROJECT_DIR/venv/bin/status_wall"
fi

echo ""
echo "=================================="
echo "✅ 安装完成!"
echo ""
echo "使用步骤:"
echo "  1. status_wall init       # 初始化配置"
echo "  2. status_wall start      # 启动守护进程"
echo "  3. status_wall status     # 查看状态"
echo ""
echo "其他命令:"
echo "  status_wall stop          # 停止守护进程"
echo "  status_wall once          # 单次执行（调试）"
echo "  status_wall show-gps      # 查看当前位置"
echo ""
echo "配置文件: ~/.status_wall.json"
echo ""
```

## status_wall/__init__.py

```python
"""
Apple iCloud 状态墙守护进程
自动更新用户状态到 iCloud 共享日历
"""

__version__ = "1.0.0"
__author__ = "Status Wall Assistant"
```

## status_wall/config.py

```python
""" 配置管理模块 """
import json
import os
from pathlib import Path

class Config:
    """配置管理类"""
    CONFIG_PATH = Path.home() / ".status_wall.json"

    def __init__(self):
        self.data = {
            "icloud_username": "",
            "icloud_password": "",
            "icloud_app_password": "",
            "amap_api_key": "",
            "home_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
            "work_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
            "private_calendar_name": "",
            "shared_calendar_name": "Status Wall",
            "polling_interval": 900,
            "commute_polling_interval": 60,
            "log_level": "INFO",
            "data_file": str(Path.home() / ".status_wall_state.json")
        }
        self.load()

    def load(self):
        """加载配置"""
        if self.CONFIG_PATH.exists():
            try:
                with open(self.CONFIG_PATH, 'r', encoding='utf-8') as f:
                    loaded = json.load(f)
                    self.data.update(loaded)
            except Exception as e:
                print(f"配置加载失败: {e}")

    def save(self):
        """保存配置"""
        try:
            with open(self.CONFIG_PATH, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
            os.chmod(self.CONFIG_PATH, 0o600)
            return True
        except Exception as e:
            print(f"配置保存失败: {e}")
            return False

    def get(self, key, default=None):
        """获取配置项"""
        return self.data.get(key, default)

    def set(self, key, value):
        """设置配置项"""
        self.data[key] = value

    def is_configured(self):
        """检查是否已配置"""
        required = ["icloud_username", "icloud_app_password", "amap_api_key"]
        return all(self.data.get(k) for k in required)

    def interactive_init(self):
        """交互式初始化配置"""
        print("=" * 50)
        print("🍎 Apple iCloud 状态墙 - 初始化配置")
        print("=" * 50)
        print()
        print("📧 Apple ID 邮箱:")
        self.data["icloud_username"] = input("> ").strip()
        print("\n🔑 Apple ID 主密码 (用于 Find My 定位):")
        self.data["icloud_password"] = input("> ").strip()
        print("\n🔐 应用专用密码 (用于 CalDAV 日历):")
        print("  在 appleid.apple.com 生成")
        self.data["icloud_app_password"] = input("> ").strip()
        print("\n🗺️ 高德地图 Web 服务 API Key:")
        print("  在 https://lbs.amap.com 申请")
        self.data["amap_api_key"] = input("> ").strip()
        print("\n🏠 家位置 - 纬度:")
        try:
            self.data["home_location"]["lat"] = float(input("> ").strip())
        except:
            pass
        print("🏠 家位置 - 经度:")
        try:
            self.data["home_location"]["lon"] = float(input("> ").strip())
        except:
            pass
        print("\n🏢 公司位置 - 纬度:")
        try:
            self.data["work_location"]["lat"] = float(input("> ").strip())
        except:
            pass
        print("🏢 公司位置 - 经度:")
        try:
            self.data["work_location"]["lon"] = float(input("> ").strip())
        except:
            pass
        print("\n📅 私人日历名称 (留空使用默认):")
        cal = input("> ").strip()
        if cal:
            self.data["private_calendar_name"] = cal
        print("\n📤 共享日历名称 (默认: Status Wall):")
        shared = input("> ").strip()
        if shared:
            self.data["shared_calendar_name"] = shared
        if self.save():
            print("\n✅ 配置已保存到", self.CONFIG_PATH)
            os.chmod(self.CONFIG_PATH, 0o600)
        else:
            print("\n❌ 配置保存失败")

# 全局配置实例
config = Config()
```

## status_wall/cli.py

```python
#!/usr/bin/env python3
""" 命令行入口 """

import argparse
import logging
import os
import sys
import signal
import subprocess
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from status_wall.config import config
from status_wall.daemon import StatusWallDaemon

def cmd_init(args):
    """初始化配置"""
    config.interactive_init()

def cmd_start(args):
    """启动守护进程"""
    if StatusWallDaemon.is_running():
        pid = StatusWallDaemon.get_pid()
        print(f"⚠️ 守护进程已在运行 (PID: {pid})")
        return

    if not config.is_configured():
        print("❌ 配置未完成，请先运行 'status_wall init'")
        return

    if args.foreground:
        daemon = StatusWallDaemon()
        daemon.run()
    else:
        script_path = Path(__file__).parent / "daemon_runner.py"
        env = os.environ.copy()
        env['PYTHONPATH'] = str(Path(__file__).parent.parent)
        process = subprocess.Popen(
            [sys.executable, str(script_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            env=env,
            start_new_session=True
        )
        print(f"✅ 守护进程已启动 (PID: {process.pid})")
        print(f"  使用 'status_wall status' 查看状态")
        print(f"  使用 'status_wall stop' 停止")

def cmd_stop(args):
    """停止守护进程"""
    if not StatusWallDaemon.is_running():
        print("⚠️ 守护进程未在运行")
        return

    pid = StatusWallDaemon.get_pid()
    try:
        os.kill(pid, signal.SIGTERM)
        print(f"✅ 守护进程已停止 (PID: {pid})")
    except ProcessLookupError:
        print("⚠️ 守护进程已不存在")
    except Exception as e:
        print(f"❌ 停止失败: {e}")

def cmd_status(args):
    """查看状态"""
    if StatusWallDaemon.is_running():
        pid = StatusWallDaemon.get_pid()
        print(f"✅ 守护进程运行中 (PID: {pid})")
    else:
        print("⚠️ 守护进程未运行")

    print(f"\n📁 配置文件: {config.CONFIG_PATH}")
    print(f"  用户名: {config.get('icloud_username', '未设置')}")
    print(f"  共享日历: {config.get('shared_calendar_name', 'Status Wall')}")

    state_file = Path(config.get("data_file", "~/.status_wall_state.json"))
    if state_file.exists():
        import json
        try:
            with open(state_file) as f:
                state = json.load(f)
            print(f"\n📊 最后状态: {state.get('last_state', 'N/A')}")
            print(f"  通勤模式: {'是' if state.get('commute_mode') else '否'}")
            print(f"  更新时间: {state.get('last_updated', 'N/A')}")
        except:
            pass

def cmd_once(args):
    """单次执行"""
    if not config.is_configured():
        print("❌ 配置未完成，请先运行 'status_wall init'")
        return

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    print("🔄 执行单次状态更新...")
    print("=" * 50)
    daemon = StatusWallDaemon()
    success, status = daemon.run_once()
    print("=" * 50)
    if success and status:
        print(f"✅ 状态: {status['display']}")
    else:
        print("❌ 执行失败")

def cmd_show_gps(args):
    """显示 GPS"""
    if not config.is_configured():
        print("❌ 配置未完成，请先运行 'status_wall init'")
        return

    daemon = StatusWallDaemon()
    daemon.show_gps()

def main():
    """主入口"""
    parser = argparse.ArgumentParser(
        prog='status_wall',
        description='🍎 Apple iCloud 状态墙守护进程',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
  示例:
    status_wall init                  # 交互式初始化配置
    status_wall start                 # 启动守护进程（后台）
    status_wall start -f              # 启动守护进程（前台）
    status_wall stop                  # 停止守护进程
    status_wall status                # 查看状态
    status_wall once                  # 单次执行
    status_wall once -v               # 单次执行（详细日志）
    status_wall show-gps              # 显示当前 GPS 位置
  """
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    init_parser = subparsers.add_parser('init', help='交互式初始化配置')
    init_parser.set_defaults(func=cmd_init)

    start_parser = subparsers.add_parser('start', help='启动守护进程')
    start_parser.add_argument('-f', '--foreground', action='store_true', help='前台运行（不调到后台）')
    start_parser.set_defaults(func=cmd_start)

    stop_parser = subparsers.add_parser('stop', help='停止守护进程')
    stop_parser.set_defaults(func=cmd_stop)

    status_parser = subparsers.add_parser('status', help='查看运行状态')
    status_parser.set_defaults(func=cmd_status)

    once_parser = subparsers.add_parser('once', help='单次执行（调试）')
    once_parser.add_argument('-v', '--verbose', action='store_true', help='详细日志输出')
    once_parser.set_defaults(func=cmd_once)

    gps_parser = subparsers.add_parser('show-gps', help='显示当前 GPS 坐标 + 高德地名')
    gps_parser.set_defaults(func=cmd_show_gps)

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return

    args.func(args)

if __name__ == '__main__':
    main()
```

## status_wall/daemon.py

```python
""" 守护进程模块 """
import logging
import signal
import sys
import time
import os
import json
from pathlib import Path
from datetime import datetime

from .config import config
from .calendar_reader import CalendarReader
from .calendar_writer import CalendarWriter
from .location_service import LocationService
from .amap_service import AMapService
from .state_manager import StateManager

logger = logging.getLogger(__name__)

class StatusWallDaemon:
    """状态墙守护进程"""
    PID_FILE = Path.home() / ".status_wall.pid"

    def __init__(self):
        self.running = False
        self.calendar_reader = CalendarReader()
        self.calendar_writer = CalendarWriter()
        self.location_service = LocationService()
        self.amap_service = AMapService()
        self.state_manager = StateManager()
        self.last_status = None

        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """信号处理"""
        logger.info(f"收到信号 {signum}，正在退出...")
        self.running = False

    def _setup_logging(self):
        """配置日志"""
        log_level = getattr(logging, config.get("log_level", "INFO").upper())
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

        logging.basicConfig(
            level=log_level,
            format=log_format,
            handlers=[
                logging.StreamHandler(sys.stdout)
            ]
        )

    def _write_pid(self):
        """写入 PID 文件"""
        try:
            with open(self.PID_FILE, 'w') as f:
                f.write(str(os.getpid()))
        except Exception as e:
            logger.warning(f"写入 PID 文件失败: {e}")

    def _remove_pid(self):
        """删除 PID 文件"""
        try:
            if self.PID_FILE.exists():
                self.PID_FILE.unlink()
        except Exception as e:
            logger.warning(f"删除 PID 文件失败: {e}")

    @classmethod
    def is_running(cls):
        """检查守护进程是否正在运行"""
        try:
            if not cls.PID_FILE.exists():
                return False
            with open(cls.PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return True
        except (ValueError, ProcessLookupError, FileNotFoundError):
            return False
        except Exception:
            return False

    @classmethod
    def get_pid(cls):
        """获取守护进程 PID"""
        try:
            with open(cls.PID_FILE, 'r') as f:
                return int(f.read().strip())
        except:
            return None

    def run_once(self):
        """单次执行状态更新"""
        try:
            logger.info("=" * 50)
            logger.info("开始状态更新轮询")

            # 1. 获取当前日程 (P1)
            current_event = self.calendar_reader.get_current_event()
            location = None
            location_name = None

            if not current_event:
                # 2. 如果没有日程，获取位置 (P2)
                loc_data = self.location_service.get_current_location()
                if loc_data:
                    lat = loc_data.get("lat")
                    lon = loc_data.get("lon")
                    # 3. 获取位置名称
                    location_name = self.amap_service.get_location_name(lat, lon)
                    location = {
                        "lat": lat,
                        "lon": lon,
                        "name": location_name
                    }
                    logger.info(f"当前位置: {location_name} ({lat:.6f}, {lon:.6f})")
                else:
                    logger.warning("无法获取位置信息")
            else:
                logger.info(f"当前日程: {current_event[0]}")

            # 4. 判断状态
            status = self.state_manager.determine_state(location, current_event)
            logger.info(f"当前状态: {status['display']}")

            # 5. 如果状态变化，写入日历
            if status['display'] != self.last_status:
                if self.calendar_writer.write_status(status['display']):
                    self.last_status = status['display']
                    logger.info("状态已同步到日历")
                else:
                    logger.error("状态同步失败")
            else:
                logger.debug("状态未变化，跳过写入")

            return True, status
        except Exception as e:
            logger.exception(f"执行失败: {e}")
            return False, None

    def run(self):
        """运行守护进程主循环"""
        self._setup_logging()

        if not config.is_configured():
            logger.error("配置未完成，请先运行 'status_wall init'")
            return False

        self._write_pid()
        self.running = True
        logger.info("=" * 50)
        logger.info("🍎 状态墙守护进程启动")
        logger.info("=" * 50)

        try:
            while self.running:
                success, status = self.run_once()
                if not self.running:
                    break

                interval = self.state_manager.get_polling_interval()
                if status and status.get("commute_mode"):
                    logger.info(f"通勤模式，{interval}秒后再次检查...")
                else:
                    logger.info(f"正常模式，{interval}秒后再次检查...")

                slept = 0
                while slept < interval and self.running:
                    time.sleep(1)
                    slept += 1
        except Exception as e:
            logger.exception(f"守护进程异常: {e}")
        finally:
            self._remove_pid()
            logger.info("守护进程已退出")

        return True

    def show_gps(self):
        """显示当前 GPS 和位置"""
        self._setup_logging()
        print("=" * 50)
        print("🗺️ GPS 位置信息")
        print("=" * 50)

        loc_data = self.location_service.get_current_location()
        if loc_data:
            lat = loc_data.get("lat")
            lon = loc_data.get("lon")
            accuracy = loc_data.get("accuracy")
            print(f"\n📍 GPS 坐标:")
            print(f"  纬度: {lat:.6f}")
            print(f"  经度: {lon:.6f}")
            print(f"  精度: ±{accuracy:.0f}m")

            location_info = self.amap_service.reverse_geocode(lat, lon)
            if location_info:
                print(f"\n🏠 位置信息:")
                print(f"  地址: {location_info.get('formatted_address', 'N/A')}")
                print(f"  AOI: {location_info.get('aoi', 'N/A')}")
                print(f"  POI: {location_info.get('poi', 'N/A')}")
                print(f"  街道: {location_info.get('street', 'N/A')}")
            else:
                print("\n❌ 无法获取位置名称")

            home_config = config.get("home_location", {})
            work_config = config.get("work_location", {})
            print(f"\n📏 围栏距离:")

            if home_config.get("lat") and home_config.get("lon"):
                from .state_manager import StateManager
                sm = StateManager()
                at_home, home_dist = sm._is_in_geofence(lat, lon, home_config)
                status = "✅ 内" if at_home else f"{home_dist:.0f}m"
                print(f"  家: {status}")

            if work_config.get("lat") and work_config.get("lon"):
                from .state_manager import StateManager
                sm = StateManager()
                at_work, work_dist = sm._is_in_geofence(lat, lon, work_config)
                status = "✅ 内" if at_work else f"{work_dist:.0f}m"
                print(f"  公司: {status}")
        else:
            print("\n❌ 无法获取 GPS 位置")
            print("  请检查 iCloud 认证信息")

        print("=" * 50)
```

## status_wall/daemon_runner.py

```python
#!/usr/bin/env python3
""" 守护进程启动器（用于后台运行） """

import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from status_wall.daemon import StatusWallDaemon

def main():
    daemon = StatusWallDaemon()
    daemon.run()

if __name__ == '__main__':
    main()
```

## status_wall/location_service.py

```python
""" 位置服务模块 通过 Find My / pyicloud 获取 GPS 位置 """
import logging
from pyicloud import PyiCloudService
from pyicloud.exceptions import PyiCloudFailedLoginException
from .config import config

logger = logging.getLogger(__name__)

class LocationService:
    """位置服务"""
    def __init__(self):
        self.api = None

    def connect(self):
        """连接到 iCloud"""
        try:
            username = config.get("icloud_username")
            password = config.get("icloud_password")
            if not username or not password:
                logger.error("缺少 iCloud 认证信息")
                return False

            self.api = PyiCloudService(username, password)
            if self.api.requires_2fa:
                logger.warning("需要双重认证")
                return False

            logger.info("iCloud 连接成功")
            return True
        except PyiCloudFailedLoginException as e:
            logger.error(f"iCloud 登录失败: {e}")
            return False
        except Exception as e:
            logger.error(f"iCloud 连接失败: {e}")
            return False

    def get_current_location(self):
        """
        获取当前 GPS 位置
        返回: {"lat": float, "lon": float, "accuracy": float, "timestamp": str}
        """
        try:
            if not self.api:
                if not self.connect():
                    return None

            devices = self.api.devices
            if not devices:
                logger.warning("未找到设备")
                return None

            target_device = None
            for device in devices:
                device_info = device.status()
                device_name = device_info.get("name", "").lower()
                if "iphone" in device_name:
                    target_device = device
                    break

            if not target_device:
                target_device = devices[0]

            location = target_device.location()
            if location and location.get("locationFinished"):
                loc_data = location.get("location", {})
                result = {
                    "lat": loc_data.get("latitude"),
                    "lon": loc_data.get("longitude"),
                    "accuracy": loc_data.get("horizontalAccuracy", 0),
                    "timestamp": location.get("timeStamp")
                }
                logger.info(f"获取位置: lat={result['lat']:.6f}, lon={result['lon']:.6f}")
                return result
            else:
                logger.warning("无法获取有效位置")
                return None
        except Exception as e:
            logger.error(f"获取位置失败: {e}")
            return None

    def get_devices(self):
        """获取所有设备列表"""
        try:
            if not self.api:
                if not self.connect():
                    return []

            device_list = []
            for device in self.api.devices:
                info = device.status()
                device_list.append({
                    "name": info.get("name", "未知"),
                    "model": info.get("deviceDisplayName", "未知"),
                    "battery": info.get("batteryLevel", 0) * 100 if info.get("batteryLevel") else None
                })
            return device_list
        except Exception as e:
            logger.error(f"获取设备列表失败: {e}")
            return []
```

## status_wall/amap_service.py

```python
""" 高德地图服务模块 逆地理编码获取位置信息 """
import json
import logging
import urllib.request
import urllib.parse
from urllib.error import URLError

from .config import config

logger = logging.getLogger(__name__)


class AMapService:
    """高德地图服务"""
    GEOCODE_REVERSE_URL = "https://restapi.amap.com/v3/geocode/regeo"

    def __init__(self):
        self.api_key = None

    def _get_api_key(self):
        """获取 API Key"""
        if not self.api_key:
            self.api_key = config.get("amap_api_key")
        return self.api_key

    def reverse_geocode(self, lat, lon):
        """
        逆地理编码
        返回: {"address": str, "poi": str, "aoi": str, "district": str}
        """
        try:
            api_key = self._get_api_key()
            if not api_key:
                logger.error("缺少高德 API Key")
                return None

            params = {
                "key": api_key,
                "location": f"{lon},{lat}",  # 高德使用 经度,纬度 格式
                "extensions": "all",
                "output": "json"
            }
            url = f"{self.GEOCODE_REVERSE_URL}?{urllib.parse.urlencode(params)}"

            req = urllib.request.Request(url, headers={
                'User-Agent': 'StatusWall/1.0'
            })

            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))

            if data.get("status") != "1":
                logger.warning(f"逆地理编码失败: {data.get('info')}")
                return None

            regeocode = data.get("regeocode", {})
            address_component = regeocode.get("addressComponent", {})

            result = {
                "formatted_address": regeocode.get("formatted_address", "未知位置"),
                "district": address_component.get("district", ""),
                "street": address_component.get("street", ""),
                "aoi": "",
                "poi": ""
            }

            aois = regeocode.get("aois", [])
            if aois:
                result["aoi"] = aois[0].get("name", "")

            pois = regeocode.get("pois", [])
            if pois:
                result["poi"] = pois[0].get("name", "")

            logger.debug(f"逆地理编码: {result['formatted_address']}")
            return result

        except URLError as e:
            logger.error(f"网络请求失败: {e}")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"解析响应失败: {e}")
            return None
        except Exception as e:
            logger.error(f"逆地理编码异常: {e}")
            return None

    def get_location_name(self, lat, lon, prefer_aoi=True):
        """
        获取位置名称（简化版）
        返回: str
        """
        result = self.reverse_geocode(lat, lon)
        if not result:
            return "未知位置"

        if prefer_aoi and result.get("aoi"):
            return result["aoi"]

        if result.get("poi"):
            return result["poi"]

        return result.get("formatted_address", "未知位置")
```

## status_wall/calendar_reader.py

```python
""" 日历读取模块 读取 iCloud 私人日历获取当前日程 """
import logging
from datetime import datetime, timedelta
from caldav import DAVClient
from icalendar import Calendar as iCalendar
from .config import config

logger = logging.getLogger(__name__)

class CalendarReader:
    """日历读取器"""
    def __init__(self):
        self.client = None
        self.principal = None

    def connect(self):
        """连接 CalDAV 服务器"""
        try:
            username = config.get("icloud_username")
            password = config.get("icloud_app_password")
            if not username or not password:
                logger.error("缺少日历认证信息")
                return False

            self.client = DAVClient(
                url="https://caldav.icloud.com",
                username=username,
                password=password
            )
            self.principal = self.client.principal()
            logger.info("CalDAV 连接成功")
            return True
        except Exception as e:
            logger.error(f"CalDAV 连接失败: {e}")
            return False

    def get_current_event(self):
        """
        获取当前正在进行的日程
        返回: (event_name, is_busy) 或 None
        """
        try:
            if not self.principal:
                if not self.connect():
                    return None

            calendars = self.principal.calendars()
            if not calendars:
                logger.warning("未找到日历")
                return None

            target_name = config.get("private_calendar_name", "")
            private_cal = None
            for cal in calendars:
                cal_name = cal.name or ""
                if target_name and target_name.lower() in cal_name.lower():
                    private_cal = cal
                    break
                if not target_name and "status" not in cal_name.lower():
                    private_cal = cal
                    break

            if not private_cal:
                private_cal = calendars[0]

            logger.debug(f"使用日历: {private_cal.name}")

            now = datetime.now()
            start = now - timedelta(hours=1)
            end = now + timedelta(hours=1)

            events = private_cal.date_search(start=start, end=end)

            for event in events:
                try:
                    ical_data = event.data
                    cal = iCalendar.from_ical(ical_data)
                    for component in cal.walk():
                        if component.name == "VEVENT":
                            event_start = component.get("dtstart")
                            event_end = component.get("dtend")
                            summary = str(component.get("summary", ""))

                            if event_start and event_end:
                                dt_start = event_start.dt
                                dt_end = event_end.dt

                                if hasattr(dt_start, 'tzinfo') and dt_start.tzinfo:
                                    dt_start = dt_start.replace(tzinfo=None)
                                if hasattr(dt_end, 'tzinfo') and dt_end.tzinfo:
                                    dt_end = dt_end.replace(tzinfo=None)

                                if dt_start <= now <= dt_end:
                                    transp = str(component.get("transp", "OPAQUE"))
                                    is_busy = (transp == "OPAQUE")
                                    logger.info(f"当前日程: {summary}")
                                    return (summary, is_busy)
                except Exception as e:
                    logger.debug(f"解析事件失败: {e}")
                    continue

            logger.debug("当前无进行中的日程")
            return None
        except Exception as e:
            logger.error(f"读取日程失败: {e}")
            return None

    def get_all_calendars(self):
        """获取所有日历列表"""
        try:
            if not self.principal:
                if not self.connect():
                    return []
            return [(cal.name or "未命名") for cal in self.principal.calendars()]
        except Exception as e:
            logger.error(f"获取日历列表失败: {e}")
            return []
```

## status_wall/calendar_writer.py

```python
""" 日历写入模块 将状态写入 iCloud 共享日历 """
import logging
from datetime import datetime, timedelta
from caldav import DAVClient
from icalendar import Calendar as iCalendar, Event, vText
from .config import config

logger = logging.getLogger(__name__)

class CalendarWriter:
    """日历写入器"""
    def __init__(self):
        self.client = None
        self.principal = None
        self.target_calendar = None
        self.last_event_uid = None

    def connect(self):
        """连接 CalDAV 服务器"""
        try:
            username = config.get("icloud_username")
            password = config.get("icloud_app_password")
            if not username or not password:
                logger.error("缺少日历认证信息")
                return False

            self.client = DAVClient(
                url="https://caldav.icloud.com",
                username=username,
                password=password
            )
            self.principal = self.client.principal()

            calendar_name = config.get("shared_calendar_name", "Status Wall")
            calendars = self.principal.calendars()
            for cal in calendars:
                if cal.name == calendar_name:
                    self.target_calendar = cal
                    logger.info(f"找到日历: {calendar_name}")
                    break

            if not self.target_calendar:
                logger.warning(f"未找到日历 '{calendar_name}'，将使用第一个可用日历")
                if calendars:
                    self.target_calendar = calendars[0]
            return True
        except Exception as e:
            logger.error(f"CalDAV 连接失败: {e}")
            return False

    def clear_today_events(self):
        """清除今天的状态事件"""
        try:
            if not self.target_calendar:
                if not self.connect():
                    return False

            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            tomorrow = today + timedelta(days=1)
            events = self.target_calendar.date_search(start=today, end=tomorrow)

            for event in events:
                try:
                    ical_data = event.data
                    cal = iCalendar.from_ical(ical_data)
                    for component in cal.walk():
                        if component.name == "VEVENT":
                            summary = str(component.get("summary", ""))
                            if any(emoji in summary for emoji in ["🏠", "🏢", "🚗", "📍", "🚫", "📅", "❓"]):
                                event.delete()
                                logger.debug(f"删除旧事件: {summary}")
                except Exception as e:
                    logger.debug(f"删除事件失败: {e}")
                    continue
            return True
        except Exception as e:
            logger.error(f"清除事件失败: {e}")
            return False

    def write_status(self, status_display):
        """写入状态到日历 创建一个全天事件"""
        try:
            if not self.target_calendar:
                if not self.connect():
                    return False

            self.clear_today_events()

            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            cal = iCalendar()
            cal.add('prodid', '-//Status Wall//Status Wall 1.0//EN')
            cal.add('version', '2.0')

            event = Event()
            event.add('summary', status_display)
            event.add('dtstart', today.date())
            event.add('dtend', (today + timedelta(days=1)).date())
            event.add('dtstamp', datetime.now())
            event.add('created', datetime.now())
            event.add('description', f'自动更新的状态 - {datetime.now().strftime("%H:%M")}')
            event.add('transp', 'TRANSPARENT')

            uid = f"status-wall-{datetime.now().strftime('%Y%m%d%H%M%S')}@{config.get('icloud_username', 'localhost')}"
            event.add('uid', uid)
            self.last_event_uid = uid

            cal.add_component(event)

            self.target_calendar.add_event(cal.to_ical())
            logger.info(f"状态已写入日历: {status_display}")
            return True
        except Exception as e:
            logger.error(f"写入状态失败: {e}")
            return False
```

## status_wall/state_manager.py

```python
""" 状态管理模块 处理状态判断和通勤逻辑 """

import json
import logging
import math
from datetime import datetime
from pathlib import Path

from .config import config

logger = logging.getLogger(__name__)


class StateManager:
    """状态管理器"""

    STATE_HOME = "home"
    STATE_WORK = "work"
    STATE_COMMUTE_TO_WORK = "commute_to_work"
    STATE_COMMUTE_TO_HOME = "commute_to_home"
    STATE_UNKNOWN = "unknown"

    def __init__(self):
        self.state_file = Path(config.get("data_file", "~/.status_wall_state.json"))
        self.state = self._load_state()

    def _load_state(self):
        """加载持久化状态"""
        default_state = {
            "last_location": None,
            "last_state": None,
            "commute_mode": False,
            "commute_start_time": None,
            "last_updated": None
        }
        if self.state_file.exists():
            try:
                with open(self.state_file, 'r') as f:
                    loaded = json.load(f)
                default_state.update(loaded)
            except Exception as e:
                logger.warning(f"加载状态文件失败: {e}")
        return default_state

    def _save_state(self):
        """保存状态"""
        try:
            self.state["last_updated"] = datetime.now().isoformat()
            with open(self.state_file, 'w') as f:
                json.dump(self.state, f, indent=2)
        except Exception as e:
            logger.warning(f"保存状态失败: {e}")

    def _calculate_distance(self, lat1, lon1, lat2, lon2):
        """
        计算两点间距离（米）
        使用 Haversine 公式
        """
        R = 6371000
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = (math.sin(delta_phi / 2) ** 2 +
             math.cos(phi1) * math.cos(phi2) *
             math.sin(delta_lambda / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    def _is_in_geofence(self, lat, lon, location_config):
        """检查是否在地理围栏内"""
        fence_lat = location_config.get("lat", 0)
        fence_lon = location_config.get("lon", 0)
        fence_radius = location_config.get("radius", 200)

        distance = self._calculate_distance(lat, lon, fence_lat, fence_lon)
        return distance <= fence_radius, distance

    def determine_state(self, location, current_event=None):
        """
        判断当前状态

        参数:
            location: {"lat": float, "lon": float}
            current_event: (event_name, is_busy) 或 None

        返回:
            {
                "status": str,
                "emoji": str,
                "display": str,
                "location": str,
                "commute_mode": bool
            }
        """
        # P1: 如果有日程，优先显示日程
        if current_event:
            event_name, is_busy = current_event
            emoji = "🚫" if is_busy else "📅"
            suffix = " (勿扰)" if is_busy else ""
            return {
                "status": "busy" if is_busy else "event",
                "emoji": emoji,
                "display": f"{emoji} {event_name}{suffix}",
                "location": "",
                "commute_mode": False
            }

        # P2: 物理位置判断
        if not location:
            return {
                "status": "unknown",
                "emoji": "❓",
                "display": "❓ 位置未知",
                "location": "",
                "commute_mode": False
            }

        lat = location.get("lat")
        lon = location.get("lon")

        home_config = config.get("home_location", {})
        work_config = config.get("work_location", {})

        at_home, home_dist = self._is_in_geofence(lat, lon, home_config)
        at_work, work_dist = self._is_in_geofence(lat, lon, work_config)

        last_state = self.state.get("last_state")
        commute_mode = self.state.get("commute_mode", False)

        COMMUTE_TRIGGER_DISTANCE = 200
        ARRIVE_DISTANCE = 100

        current_state = None
        display = ""
        emoji = ""
        location_name = ""

        if at_home:
            if commute_mode and last_state == self.STATE_COMMUTE_TO_HOME:
                logger.info("到达家，通勤结束")
                commute_mode = False
            current_state = self.STATE_HOME
            emoji = "🏠"
            display = "🏠 在家"
            location_name = "家"

        elif at_work:
            if commute_mode and last_state == self.STATE_COMMUTE_TO_WORK:
                logger.info("到达公司，通勤结束")
                commute_mode = False
            current_state = self.STATE_WORK
            emoji = "🏢"
            display = "🏢 搬砖中"
            location_name = "公司"

        else:
            location_name = location.get("name", "未知地点")

            if last_state == self.STATE_HOME and home_dist > COMMUTE_TRIGGER_DISTANCE:
                commute_mode = True
                current_state = self.STATE_COMMUTE_TO_WORK
                emoji = "🚗"
                display = f"🚗 正在上班途中（当前：{location_name}）"

            elif last_state == self.STATE_WORK and work_dist > COMMUTE_TRIGGER_DISTANCE:
                commute_mode = True
                current_state = self.STATE_COMMUTE_TO_HOME

                home_lat = home_config.get("lat")
                home_lon = home_config.get("lon")
                if home_lat and home_lon:
                    dist_to_home = self._calculate_distance(lat, lon, home_lat, home_lon)
                    dist_km = round(dist_to_home / 1000, 1)
                    display = f"🚗 正在下班途中，距离家 {dist_km}km（当前：{location_name}）"
                else:
                    display = f"🚗 正在下班途中（当前：{location_name}）"

            elif commute_mode:
                if last_state == self.STATE_COMMUTE_TO_WORK:
                    current_state = self.STATE_COMMUTE_TO_WORK
                    emoji = "🚗"
                    display = f"🚗 正在上班途中（当前：{location_name}）"
                else:
                    current_state = self.STATE_COMMUTE_TO_HOME
                    emoji = "🚗"
                    home_lat = home_config.get("lat")
                    home_lon = home_config.get("lon")
                    if home_lat and home_lon:
                        dist_to_home = self._calculate_distance(lat, lon, home_lat, home_lon)
                        dist_km = round(dist_to_home / 1000, 1)
                        display = f"🚗 正在下班途中，距离家 {dist_km}km（当前：{location_name}）"
                    else:
                        display = f"🚗 正在下班途中（当前：{location_name}）"
            else:
                current_state = self.STATE_UNKNOWN
                emoji = "📍"
                display = f"📍 在{location_name}"

        # 更新状态
        self.state["last_state"] = current_state
        self.state["commute_mode"] = commute_mode
        self.state["last_location"] = {"lat": lat, "lon": lon}

        if commute_mode and not self.state.get("commute_start_time"):
            self.state["commute_start_time"] = datetime.now().isoformat()
        elif not commute_mode:
            self.state["commute_start_time"] = None

        self._save_state()

        return {
            "status": current_state,
            "emoji": emoji,
            "display": display,
            "location": location_name,
            "commute_mode": commute_mode
        }

    def get_polling_interval(self):
        """获取当前轮询间隔"""
        if self.state.get("commute_mode"):
            return config.get("commute_polling_interval", 60)
        return config.get("polling_interval", 900)
```
