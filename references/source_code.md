# Apple Calendar Home - Complete Source Code Reference

This document contains the complete, production-quality source code for all modules of the Apple iCloud Status Wall project.

## setup.py

```python
#!/usr/bin/env python3
""" Status Wall - Apple iCloud 状态墙 """

from setuptools import setup, find_packages
from pathlib import Path

long_description = ""
readme_path = Path(__file__).parent / "README.md"
if readme_path.exists():
    long_description = readme_path.read_text(encoding="utf-8")

setup(
    name="status-wall",
    version="1.1.0",
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
    python_requires=">=3.8",
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

# 检查 Python 版本 >= 3.8
PYTHON_FULL_VERSION=$(python3 --version | cut -d' ' -f2)
PYTHON_MAJOR=$(echo "$PYTHON_FULL_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_FULL_VERSION" | cut -d'.' -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]; }; then
    echo "❌ 错误: 需要 Python 3.8 或更高版本, 当前版本: $PYTHON_FULL_VERSION"
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

__version__ = "1.1.0"
__author__ = "Status Wall Assistant"
```

## status_wall/config.py

```python
""" 配置管理模块 """
import getpass
import json
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)


class Config:
    """配置管理类 — 懒加载，首次 get/is_configured 时才读磁盘"""
    CONFIG_PATH = Path.home() / ".status_wall.json"

    # 默认配置
    _DEFAULTS = {
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
        "data_file": str(Path.home() / ".status_wall_state.json"),
        "cookie_directory": str(Path.home() / ".status_wall_cookies"),
    }

    def __init__(self):
        self._data = None  # 延迟加载

    @property
    def data(self):
        if self._data is None:
            self._data = dict(self._DEFAULTS)
            self._load()
        return self._data

    def _load(self):
        """加载配置文件"""
        if self.CONFIG_PATH.exists():
            try:
                with open(self.CONFIG_PATH, 'r', encoding='utf-8') as f:
                    loaded = json.load(f)
                    self._data.update(loaded)
            except json.JSONDecodeError as e:
                logger.error(f"配置文件格式错误: {e}")
            except Exception as e:
                logger.error(f"配置加载失败: {e}")

    def reload(self):
        """强制重新加载配置"""
        self._data = dict(self._DEFAULTS)
        self._load()

    def save(self):
        """保存配置"""
        try:
            with open(self.CONFIG_PATH, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
            os.chmod(self.CONFIG_PATH, 0o600)
            return True
        except Exception as e:
            logger.error(f"配置保存失败: {e}")
            return False

    def get(self, key, default=None):
        """获取配置项"""
        return self.data.get(key, default)

    def set(self, key, value):
        """设置配置项"""
        self.data[key] = value

    def is_configured(self):
        """检查必填项是否已配置"""
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
        self.data["icloud_password"] = getpass.getpass("> ")

        print("🔐 应用专用密码 (用于 CalDAV 日历):")
        print("  在 appleid.apple.com → 登录 → 应用专用密码 生成")
        self.data["icloud_app_password"] = getpass.getpass("> ")

        print("\n🗺️ 高德地图 Web 服务 API Key:")
        print("  在 https://lbs.amap.com 申请")
        self.data["amap_api_key"] = input("> ").strip()

        print("\n🏠 家位置 - 纬度:")
        self._input_float("home_location", "lat")
        print("🏠 家位置 - 经度:")
        self._input_float("home_location", "lon")
        print("🏠 家位置 - 围栏半径 (默认200米):")
        self._input_float("home_location", "radius", allow_empty=True)

        print("\n🏢 公司位置 - 纬度:")
        self._input_float("work_location", "lat")
        print("🏢 公司位置 - 经度:")
        self._input_float("work_location", "lon")
        print("🏢 公司位置 - 围栏半径 (默认200米):")
        self._input_float("work_location", "radius", allow_empty=True)

        print("\n📅 私人日历名称 (留空使用默认):")
        cal = input("> ").strip()
        if cal:
            self.data["private_calendar_name"] = cal

        print("\n📤 共享日历名称 (默认: Status Wall):")
        shared = input("> ").strip()
        if shared:
            self.data["shared_calendar_name"] = shared

        # 确保 cookie 目录存在
        cookie_dir = Path(self.data["cookie_directory"])
        cookie_dir.mkdir(parents=True, exist_ok=True)

        if self.save():
            print(f"\n✅ 配置已保存到 {self.CONFIG_PATH}")
        else:
            print("\n❌ 配置保存失败")

    def _input_float(self, section, key, allow_empty=False):
        """安全读取浮点数输入"""
        raw = input("> ").strip()
        if not raw and allow_empty:
            return
        try:
            self.data[section][key] = float(raw)
        except ValueError:
            print(f"  ⚠️ 输入无效，保持当前值: {self.data[section][key]}")


# 全局配置实例（懒加载，import 时不读磁盘）
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
import time
from pathlib import Path

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
            start_new_session=True,
        )
        # 等待一小段时间确认进程没有立即崩溃
        time.sleep(1)
        if process.poll() is not None:
            print(f"❌ 守护进程启动失败 (退出码: {process.returncode})")
        else:
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
        # 等待进程退出
        for _ in range(10):
            time.sleep(0.5)
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                print(f"✅ 守护进程已停止 (PID: {pid})")
                return
        # 超时后强制 kill
        os.kill(pid, signal.SIGKILL)
        print(f"⚠️ 守护进程已强制停止 (PID: {pid})")
    except ProcessLookupError:
        print("⚠️ 守护进程已不存在")
        # 清理残留 PID 文件
        StatusWallDaemon.cleanup_pid()
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

    state_file = Path(config.get("data_file", "")).expanduser()
    if state_file.is_file():
        import json
        try:
            with open(state_file, encoding='utf-8') as f:
                state = json.load(f)
            print(f"\n📊 最后状态: {state.get('last_display', 'N/A')}")
            print(f"  通勤模式: {'是' if state.get('commute_mode') else '否'}")
            print(f"  更新时间: {state.get('last_updated', 'N/A')}")
        except Exception:
            pass


def cmd_once(args):
    """单次执行"""
    if not config.is_configured():
        print("❌ 配置未完成，请先运行 'status_wall init'")
        return

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
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

    logging.basicConfig(
        level=logging.DEBUG if getattr(args, 'verbose', False) else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    )

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
  """,
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    init_parser = subparsers.add_parser('init', help='交互式初始化配置')
    init_parser.set_defaults(func=cmd_init)

    start_parser = subparsers.add_parser('start', help='启动守护进程')
    start_parser.add_argument('-f', '--foreground', action='store_true', help='前台运行')
    start_parser.set_defaults(func=cmd_start)

    stop_parser = subparsers.add_parser('stop', help='停止守护进程')
    stop_parser.set_defaults(func=cmd_stop)

    status_parser = subparsers.add_parser('status', help='查看运行状态')
    status_parser.set_defaults(func=cmd_status)

    once_parser = subparsers.add_parser('once', help='单次执行（调试）')
    once_parser.add_argument('-v', '--verbose', action='store_true', help='详细日志输出')
    once_parser.set_defaults(func=cmd_once)

    gps_parser = subparsers.add_parser('show-gps', help='显示当前 GPS 坐标 + 高德地名')
    gps_parser.add_argument('-v', '--verbose', action='store_true', help='详细日志输出')
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
from pathlib import Path
from datetime import datetime

from .config import config
from .calendar_reader import CalendarReader
from .calendar_writer import CalendarWriter
from .location_service import LocationService
from .amap_service import AMapService
from .state_manager import StateManager

logger = logging.getLogger(__name__)

# 连续失败后的最大退避间隔(秒)
MAX_BACKOFF = 300


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
        self._consecutive_failures = 0

        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """信号处理"""
        logger.info(f"收到信号 {signum}，正在退出...")
        self.running = False

    def _setup_logging(self):
        """配置日志"""
        log_level = getattr(logging, config.get("log_level", "INFO").upper(), logging.INFO)
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

        # 清除已有 handlers 避免重复
        root = logging.getLogger()
        root.setLevel(log_level)
        if not root.handlers:
            handler = logging.StreamHandler(sys.stdout)
            handler.setFormatter(logging.Formatter(log_format))
            root.addHandler(handler)

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
    def cleanup_pid(cls):
        """清理残留 PID 文件（供外部调用）"""
        try:
            if cls.PID_FILE.exists():
                cls.PID_FILE.unlink()
        except Exception:
            pass

    @classmethod
    def is_running(cls):
        """检查守护进程是否正在运行"""
        try:
            if not cls.PID_FILE.exists():
                return False
            with open(cls.PID_FILE, 'r') as f:
                content = f.read().strip()
                if not content:
                    return False
                pid = int(content)
            os.kill(pid, 0)
            return True
        except (ValueError, ProcessLookupError, FileNotFoundError, PermissionError):
            # PID 文件存在但进程已死，清理之
            cls.cleanup_pid()
            return False
        except Exception:
            return False

    @classmethod
    def get_pid(cls):
        """获取守护进程 PID"""
        try:
            with open(cls.PID_FILE, 'r') as f:
                return int(f.read().strip())
        except Exception:
            return None

    def _reset_connections(self):
        """重置所有连接，用于失败后重连"""
        logger.info("重置所有连接...")
        self.calendar_reader = CalendarReader()
        self.calendar_writer = CalendarWriter()
        self.location_service = LocationService()

    def run_once(self):
        """单次执行状态更新"""
        try:
            logger.info("-" * 40)
            logger.info("开始状态更新轮询")

            # 1. 获取当前日程 (P1)
            current_event = None
            try:
                current_event = self.calendar_reader.get_current_event()
            except Exception as e:
                logger.warning(f"读取日程异常(非致命): {e}")

            location = None

            if not current_event:
                # 2. 如果没有日程，获取位置 (P2)
                loc_data = self.location_service.get_current_location()
                if loc_data:
                    lat = loc_data.get("lat")
                    lon = loc_data.get("lon")
                    if lat is not None and lon is not None:
                        # 3. 获取位置名称
                        location_name = self.amap_service.get_location_name(lat, lon)
                        location = {
                            "lat": lat,
                            "lon": lon,
                            "name": location_name,
                        }
                        logger.info(f"当前位置: {location_name} ({lat:.6f}, {lon:.6f})")
                    else:
                        logger.warning("GPS 返回了空坐标")
                else:
                    logger.warning("无法获取位置信息")
            else:
                logger.info(f"当前日程: {current_event[0]}")

            # 4. 判断状态
            status = self.state_manager.determine_state(location, current_event)
            logger.info(f"当前状态: {status['display']}")

            # 5. 如果状态变化，写入日历
            if status['display'] != self.last_status:
                try:
                    if self.calendar_writer.write_status(status['display']):
                        self.last_status = status['display']
                        # 持久化 last_status 以便进程重启恢复
                        self.state_manager.set_last_display(status['display'])
                        logger.info("状态已同步到日历")
                    else:
                        logger.error("状态同步失败")
                except Exception as e:
                    logger.error(f"写入日历异常: {e}")
            else:
                logger.debug("状态未变化，跳过写入")

            self._consecutive_failures = 0
            return True, status
        except Exception as e:
            self._consecutive_failures += 1
            logger.exception(f"执行失败 (连续第{self._consecutive_failures}次): {e}")
            # 连续失败超过 3 次，重置连接
            if self._consecutive_failures >= 3:
                self._reset_connections()
                self._consecutive_failures = 0
            return False, None

    def run(self):
        """运行守护进程主循环"""
        self._setup_logging()

        if not config.is_configured():
            logger.error("配置未完成，请先运行 'status_wall init'")
            return False

        self._write_pid()
        self.running = True

        # 恢复上次状态
        self.last_status = self.state_manager.get_last_display()

        logger.info("=" * 50)
        logger.info("🍎 状态墙守护进程启动")
        logger.info(f"  轮询间隔: {config.get('polling_interval')}s / 通勤: {config.get('commute_polling_interval')}s")
        logger.info("=" * 50)

        try:
            while self.running:
                success, status = self.run_once()
                if not self.running:
                    break

                # 计算下次轮询时间
                if success:
                    interval = self.state_manager.get_polling_interval()
                else:
                    # 失败时使用退避策略
                    interval = min(60 * (2 ** self._consecutive_failures), MAX_BACKOFF)

                if status and status.get("commute_mode"):
                    logger.info(f"通勤模式，{interval}秒后再次检查...")
                else:
                    logger.info(f"正常模式，{interval}秒后再次检查...")

                # 分段睡眠以响应退出信号
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
            accuracy = loc_data.get("accuracy", 0)

            if lat is None or lon is None:
                print("\n❌ GPS 返回了空坐标")
                print("=" * 50)
                return

            print(f"\n📍 GPS 坐标:")
            print(f"  纬度: {lat:.6f}")
            print(f"  经度: {lon:.6f}")
            if accuracy:
                print(f"  精度: ±{accuracy:.0f}m")

            location_info = self.amap_service.reverse_geocode(lat, lon)
            if location_info:
                print(f"\n🏠 位置信息:")
                print(f"  地址: {location_info.get('formatted_address', 'N/A')}")
                print(f"  AOI: {location_info.get('aoi') or 'N/A'}")
                print(f"  POI: {location_info.get('poi') or 'N/A'}")
                print(f"  街道: {location_info.get('street') or 'N/A'}")
            else:
                print("\n❌ 无法获取位置名称")

            home_config = config.get("home_location", {})
            work_config = config.get("work_location", {})
            print(f"\n📏 围栏距离:")

            sm = self.state_manager
            if home_config.get("lat") and home_config.get("lon"):
                at_home, home_dist = sm._is_in_geofence(lat, lon, home_config)
                label = "✅ 围栏内" if at_home else f"{home_dist:.0f}m"
                print(f"  家: {label} (围栏半径: {home_config.get('radius', 200)}m)")

            if work_config.get("lat") and work_config.get("lon"):
                at_work, work_dist = sm._is_in_geofence(lat, lon, work_config)
                label = "✅ 围栏内" if at_work else f"{work_dist:.0f}m"
                print(f"  公司: {label} (围栏半径: {work_config.get('radius', 200)}m)")
        else:
            print("\n❌ 无法获取 GPS 位置")
            print("  请检查 iCloud 认证信息和网络连接")

        print("=" * 50)
```

## status_wall/daemon_runner.py

```python
#!/usr/bin/env python3
""" 守护进程启动器（用于后台运行） """

import sys
import os
from pathlib import Path

# 添加项目根路径（status_wall 的上级目录）
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# 重定向日志到文件
log_file = Path.home() / ".status_wall.log"
try:
    log_fd = open(log_file, 'a', encoding='utf-8')
    sys.stdout = log_fd
    sys.stderr = log_fd
except Exception:
    pass

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
import time
from pathlib import Path

from .config import config

logger = logging.getLogger(__name__)

# pyicloud 可能未安装，延迟导入
PyiCloudService = None
PyiCloudFailedLoginException = None


def _ensure_pyicloud():
    global PyiCloudService, PyiCloudFailedLoginException
    if PyiCloudService is None:
        from pyicloud import PyiCloudService as _PCS
        from pyicloud.exceptions import PyiCloudFailedLoginException as _PFLE
        PyiCloudService = _PCS
        PyiCloudFailedLoginException = _PFLE


class LocationService:
    """位置服务 — 带会话持久化和重连机制"""

    def __init__(self):
        self.api = None
        self._last_connect_attempt = 0
        self._connect_cooldown = 60  # 连接失败后冷却 60s

    def connect(self):
        """连接到 iCloud（带冷却控制，避免频繁重试被锁定）"""
        now = time.time()
        if now - self._last_connect_attempt < self._connect_cooldown:
            logger.debug("连接冷却中，跳过")
            return False

        self._last_connect_attempt = now

        try:
            _ensure_pyicloud()

            username = config.get("icloud_username")
            password = config.get("icloud_password")
            if not username or not password:
                logger.error("缺少 iCloud 认证信息")
                return False

            # 使用 cookie_directory 持久化会话，避免每次都触发 2FA
            cookie_dir = config.get("cookie_directory", str(Path.home() / ".status_wall_cookies"))
            Path(cookie_dir).mkdir(parents=True, exist_ok=True)

            self.api = PyiCloudService(
                username,
                password,
                cookie_directory=cookie_dir,
            )

            # 检查是否需要双重认证
            if self.api.requires_2fa:
                logger.warning("需要双重认证 (2FA)")
                print("\n⚠️ 需要双重认证")
                code = input("请输入 Apple ID 验证码: ").strip()
                result = self.api.validate_2fa_code(code)
                if not result:
                    logger.error("2FA 验证失败")
                    return False
                # 信任本设备
                if not self.api.is_trusted_session:
                    self.api.trust_session()
                logger.info("2FA 验证成功")

            elif getattr(self.api, 'requires_2sa', False):
                logger.warning("需要两步验证 (2SA)")
                devices = self.api.trusted_devices
                if not devices:
                    logger.error("无可信设备用于 2SA")
                    return False
                device = devices[0]
                if not self.api.send_verification_code(device):
                    logger.error("发送验证码失败")
                    return False
                code = input(f"请输入发送到 {device.get('deviceName', '设备')} 的验证码: ").strip()
                if not self.api.validate_verification_code(device, code):
                    logger.error("2SA 验证失败")
                    return False
                logger.info("2SA 验证成功")

            logger.info("iCloud 连接成功")
            self._connect_cooldown = 60  # 成功后重置冷却
            return True

        except Exception as e:
            _ensure_pyicloud()
            if PyiCloudFailedLoginException and isinstance(e, PyiCloudFailedLoginException):
                logger.error(f"iCloud 登录失败: {e}")
            else:
                logger.error(f"iCloud 连接失败: {e}")
            self.api = None
            self._connect_cooldown = min(self._connect_cooldown * 2, 600)  # 退避
            return False

    def get_current_location(self):
        """
        获取当前 GPS 位置
        返回: {"lat": float, "lon": float, "accuracy": float, "timestamp": str} 或 None
        """
        try:
            if not self.api:
                if not self.connect():
                    return None

            devices = self.api.devices
            if not devices:
                logger.warning("未找到设备")
                return None

            # 优先选择 iPhone
            target_device = None
            for device in devices:
                try:
                    device_info = device.status()
                    device_name = device_info.get("name", "").lower()
                    if "iphone" in device_name:
                        target_device = device
                        break
                except Exception:
                    continue

            if not target_device:
                target_device = list(devices)[0] if devices else None

            if not target_device:
                logger.warning("无可用设备")
                return None

            # 获取位置 — pyicloud 的 location() 直接返回 dict
            location = target_device.location()
            if not location:
                logger.warning("设备未返回位置信息")
                return None

            # pyicloud 返回格式: {"latitude": ..., "longitude": ..., ...}
            # 兼容两种可能的返回格式
            lat = location.get("latitude")
            lon = location.get("longitude")

            # 有些版本 pyicloud 嵌套在 location 字段里
            if lat is None and "location" in location:
                inner = location["location"]
                lat = inner.get("latitude")
                lon = inner.get("longitude")

            if lat is None or lon is None:
                logger.warning(f"位置数据不完整: {location}")
                return None

            accuracy = location.get("horizontalAccuracy", 0)
            timestamp = location.get("timeStamp")

            result = {
                "lat": float(lat),
                "lon": float(lon),
                "accuracy": float(accuracy) if accuracy else 0,
                "timestamp": str(timestamp) if timestamp else "",
            }
            logger.info(f"获取位置: lat={result['lat']:.6f}, lon={result['lon']:.6f}")
            return result

        except Exception as e:
            logger.error(f"获取位置失败: {e}")
            # 连接可能已失效，下次重连
            self.api = None
            return None

    def get_devices(self):
        """获取所有设备列表"""
        try:
            if not self.api:
                if not self.connect():
                    return []

            device_list = []
            for device in self.api.devices:
                try:
                    info = device.status()
                    battery = info.get("batteryLevel")
                    device_list.append({
                        "name": info.get("name", "未知"),
                        "model": info.get("deviceDisplayName", "未知"),
                        "battery": round(battery * 100) if battery is not None else None,
                    })
                except Exception:
                    continue
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
from urllib.error import URLError, HTTPError

from .config import config

logger = logging.getLogger(__name__)

# 简单内存缓存，避免对同一坐标反复请求
_geocode_cache = {}
_CACHE_MAX_SIZE = 100


class AMapService:
    """高德地图服务 — 带缓存和重试"""
    GEOCODE_REVERSE_URL = "https://restapi.amap.com/v3/geocode/regeo"

    def __init__(self):
        self.api_key = None

    def _get_api_key(self):
        """获取 API Key"""
        if not self.api_key:
            self.api_key = config.get("amap_api_key")
        return self.api_key

    @staticmethod
    def _round_coord(val, precision=4):
        """坐标四舍五入（用于缓存 key，约 10m 精度）"""
        return round(val, precision)

    def reverse_geocode(self, lat, lon):
        """
        逆地理编码
        返回: {"formatted_address": str, "poi": str, "aoi": str, "district": str, "street": str} 或 None
        """
        # 检查缓存
        cache_key = (self._round_coord(lat), self._round_coord(lon))
        if cache_key in _geocode_cache:
            logger.debug("使用缓存的逆地理编码结果")
            return _geocode_cache[cache_key]

        try:
            api_key = self._get_api_key()
            if not api_key:
                logger.error("缺少高德 API Key")
                return None

            params = {
                "key": api_key,
                "location": f"{lon},{lat}",  # 高德使用 经度,纬度 格式
                "extensions": "all",
                "output": "json",
            }
            url = f"{self.GEOCODE_REVERSE_URL}?{urllib.parse.urlencode(params)}"

            req = urllib.request.Request(url, headers={
                'User-Agent': 'StatusWall/1.1',
            })

            with urllib.request.urlopen(req, timeout=10) as response:
                raw = response.read().decode('utf-8')
                data = json.loads(raw)

            if data.get("status") != "1":
                logger.warning(f"逆地理编码失败: {data.get('info', '未知错误')} (infocode={data.get('infocode')})")
                return None

            regeocode = data.get("regeocode", {})
            address_component = regeocode.get("addressComponent", {})

            result = {
                "formatted_address": regeocode.get("formatted_address", "未知位置"),
                "district": address_component.get("district", ""),
                "street": address_component.get("street", ""),
                "aoi": "",
                "poi": "",
            }

            # 提取 AOI
            aois = regeocode.get("aois")
            if isinstance(aois, list) and aois:
                result["aoi"] = aois[0].get("name", "")

            # 提取 POI
            pois = regeocode.get("pois")
            if isinstance(pois, list) and pois:
                result["poi"] = pois[0].get("name", "")

            logger.debug(f"逆地理编码: {result['formatted_address']}")

            # 写入缓存
            if len(_geocode_cache) >= _CACHE_MAX_SIZE:
                # 简单清理：全部清空
                _geocode_cache.clear()
            _geocode_cache[cache_key] = result

            return result

        except HTTPError as e:
            logger.error(f"HTTP 请求失败: {e.code} {e.reason}")
            return None
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
        """获取位置名称（简化版）"""
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
from datetime import datetime, timedelta, date, timezone
from caldav import DAVClient
from icalendar import Calendar as iCalendar
from .config import config

logger = logging.getLogger(__name__)


class CalendarReader:
    """日历读取器 — 带连接复用和健壮的时间处理"""

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
                password=password,
            )
            self.principal = self.client.principal()
            logger.info("CalDAV (Reader) 连接成功")
            return True
        except Exception as e:
            logger.error(f"CalDAV 连接失败: {e}")
            self.client = None
            self.principal = None
            return False

    def _ensure_connected(self):
        """确保已连接，失败时尝试重连"""
        if self.principal is not None:
            return True
        return self.connect()

    @staticmethod
    def _to_naive_datetime(dt_val):
        """
        将 date 或 datetime 统一转为无时区 datetime，
        解决全天事件返回 date 对象导致比较 TypeError 的问题。
        """
        if isinstance(dt_val, datetime):
            if dt_val.tzinfo is not None:
                # 先转到 UTC，再去掉时区信息以统一比较
                dt_val = dt_val.astimezone(timezone.utc).replace(tzinfo=None)
            return dt_val
        if isinstance(dt_val, date):
            return datetime(dt_val.year, dt_val.month, dt_val.day)
        return None

    def get_current_event(self):
        """
        获取当前正在进行的日程
        返回: (event_name: str, is_busy: bool) 或 None
        """
        try:
            if not self._ensure_connected():
                return None

            calendars = self.principal.calendars()
            if not calendars:
                logger.warning("未找到日历")
                return None

            # 查找目标日历
            target_name = config.get("private_calendar_name", "")
            private_cal = None
            shared_name = config.get("shared_calendar_name", "Status Wall").lower()

            for cal in calendars:
                cal_name = cal.name or ""
                # 精确匹配目标名称
                if target_name and target_name.lower() in cal_name.lower():
                    private_cal = cal
                    break
                # 跳过共享状态日历
                if not target_name and shared_name not in cal_name.lower():
                    private_cal = cal
                    break

            if not private_cal:
                # 最后兜底：第一个不是共享日历的
                for cal in calendars:
                    cal_name = (cal.name or "").lower()
                    if shared_name not in cal_name:
                        private_cal = cal
                        break
                if not private_cal:
                    private_cal = calendars[0]

            logger.debug(f"使用日历: {private_cal.name}")

            now = datetime.now()
            # 扩大搜索范围以覆盖全天事件
            start = now - timedelta(hours=24)
            end = now + timedelta(hours=24)

            try:
                events = private_cal.date_search(start=start, end=end)
            except Exception as e:
                logger.warning(f"搜索日程失败，尝试重连: {e}")
                self.principal = None
                if not self._ensure_connected():
                    return None
                calendars = self.principal.calendars()
                private_cal = calendars[0] if calendars else None
                if not private_cal:
                    return None
                events = private_cal.date_search(start=start, end=end)

            for event in events:
                try:
                    ical_data = event.data
                    cal = iCalendar.from_ical(ical_data)
                    for component in cal.walk():
                        if component.name != "VEVENT":
                            continue

                        event_start = component.get("dtstart")
                        event_end = component.get("dtend")
                        summary = str(component.get("summary", "")).strip()

                        if not event_start or not summary:
                            continue

                        dt_start = self._to_naive_datetime(event_start.dt)
                        if dt_start is None:
                            continue

                        # 如果没有 dtend，默认结束时间
                        if event_end:
                            dt_end = self._to_naive_datetime(event_end.dt)
                        else:
                            # 全天事件没有 dtend 时默认当天结束
                            dt_end = dt_start + timedelta(days=1)

                        if dt_end is None:
                            continue

                        # 全天事件：跳过（不应该显示为忙碌）
                        if isinstance(event_start.dt, date) and not isinstance(event_start.dt, datetime):
                            continue

                        # 检查当前时间是否在事件范围内
                        if dt_start <= now <= dt_end:
                            transp = str(component.get("transp", "OPAQUE")).upper()
                            is_busy = (transp == "OPAQUE")
                            logger.info(f"当前日程: {summary} (busy={is_busy})")
                            return (summary, is_busy)

                except Exception as e:
                    logger.debug(f"解析事件失败: {e}")
                    continue

            logger.debug("当前无进行中的日程")
            return None

        except Exception as e:
            logger.error(f"读取日程失败: {e}")
            # 标记连接失效
            self.principal = None
            return None

    def get_all_calendars(self):
        """获取所有日历列表"""
        try:
            if not self._ensure_connected():
                return []
            return [(cal.name or "未命名") for cal in self.principal.calendars()]
        except Exception as e:
            logger.error(f"获取日历列表失败: {e}")
            self.principal = None
            return []
```

## status_wall/calendar_writer.py

```python
""" 日历写入模块 将状态写入 iCloud 共享日历 """
import logging
import uuid
from datetime import datetime, timedelta
from caldav import DAVClient
from icalendar import Calendar as iCalendar, Event
from .config import config

logger = logging.getLogger(__name__)

# 状态事件 emoji 前缀，用于识别和清理
STATUS_EMOJIS = {"🏠", "🏢", "🚗", "📍", "🚫", "📅", "❓"}


class CalendarWriter:
    """日历写入器 — 带连接复用、UID 去重"""

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
                password=password,
            )
            self.principal = self.client.principal()

            calendar_name = config.get("shared_calendar_name", "Status Wall")
            calendars = self.principal.calendars()
            for cal in calendars:
                if cal.name and cal.name.strip() == calendar_name.strip():
                    self.target_calendar = cal
                    logger.info(f"找到日历: {calendar_name}")
                    break

            if not self.target_calendar:
                logger.warning(f"未找到日历 '{calendar_name}'，将使用第一个可用日历")
                if calendars:
                    self.target_calendar = calendars[0]
                else:
                    logger.error("账户中没有任何日历")
                    return False

            return True
        except Exception as e:
            logger.error(f"CalDAV (Writer) 连接失败: {e}")
            self.client = None
            self.principal = None
            self.target_calendar = None
            return False

    def _ensure_connected(self):
        """确保已连接"""
        if self.target_calendar is not None:
            return True
        return self.connect()

    def clear_today_events(self):
        """清除今天的状态事件"""
        try:
            if not self._ensure_connected():
                return False

            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            tomorrow = today + timedelta(days=1)

            try:
                events = self.target_calendar.date_search(start=today, end=tomorrow)
            except Exception as e:
                logger.warning(f"搜索事件失败，尝试重连: {e}")
                self.target_calendar = None
                if not self._ensure_connected():
                    return False
                events = self.target_calendar.date_search(start=today, end=tomorrow)

            deleted_count = 0
            for event in events:
                try:
                    ical_data = event.data
                    cal = iCalendar.from_ical(ical_data)
                    for component in cal.walk():
                        if component.name == "VEVENT":
                            summary = str(component.get("summary", ""))
                            if any(emoji in summary for emoji in STATUS_EMOJIS):
                                event.delete()
                                deleted_count += 1
                                logger.debug(f"删除旧事件: {summary}")
                                break  # 一个 event 只需要 delete 一次
                except Exception as e:
                    logger.debug(f"删除事件失败: {e}")
                    continue

            if deleted_count:
                logger.info(f"清除了 {deleted_count} 个旧状态事件")
            return True
        except Exception as e:
            logger.error(f"清除事件失败: {e}")
            return False

    def write_status(self, status_display):
        """写入状态到日历 — 创建一个全天事件"""
        try:
            if not self._ensure_connected():
                return False

            # 清除旧事件
            self.clear_today_events()

            today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
            cal = iCalendar()
            cal.add('prodid', '-//Status Wall//Status Wall 1.1//EN')
            cal.add('version', '2.0')

            event = Event()
            event.add('summary', status_display)
            event.add('dtstart', today.date())
            event.add('dtend', (today + timedelta(days=1)).date())
            event.add('dtstamp', datetime.utcnow())
            event.add('created', datetime.utcnow())
            event.add('last-modified', datetime.utcnow())
            event.add('description', f'自动更新的状态 - {datetime.now().strftime("%H:%M:%S")}')
            event.add('transp', 'TRANSPARENT')

            # 使用 UUID 避免 UID 冲突
            uid = f"status-wall-{uuid.uuid4()}@status-wall"
            event.add('uid', uid)
            self.last_event_uid = uid

            cal.add_component(event)

            self.target_calendar.add_event(cal.to_ical())
            logger.info(f"状态已写入日历: {status_display}")
            return True
        except Exception as e:
            logger.error(f"写入状态失败: {e}")
            # 标记连接失效
            self.target_calendar = None
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
    """状态管理器 — 地理围栏 + 通勤检测"""

    STATE_HOME = "home"
    STATE_WORK = "work"
    STATE_COMMUTE_TO_WORK = "commute_to_work"
    STATE_COMMUTE_TO_HOME = "commute_to_home"
    STATE_UNKNOWN = "unknown"

    def __init__(self):
        # 展开 ~ 路径
        raw_path = config.get("data_file", str(Path.home() / ".status_wall_state.json"))
        self.state_file = Path(raw_path).expanduser()
        self.state = self._load_state()

    def _load_state(self):
        """加载持久化状态"""
        default_state = {
            "last_location": None,
            "last_state": None,
            "last_display": None,
            "commute_mode": False,
            "commute_start_time": None,
            "last_updated": None,
        }
        if self.state_file.exists():
            try:
                with open(self.state_file, 'r', encoding='utf-8') as f:
                    loaded = json.load(f)
                default_state.update(loaded)
            except json.JSONDecodeError as e:
                logger.warning(f"状态文件格式错误，将重置: {e}")
            except Exception as e:
                logger.warning(f"加载状态文件失败: {e}")
        return default_state

    def _save_state(self):
        """保存状态（带异常保护）"""
        try:
            self.state["last_updated"] = datetime.now().isoformat()
            # 先写临时文件再重命名，防止写入中途崩溃导致文件损坏
            tmp_file = self.state_file.with_suffix('.tmp')
            with open(tmp_file, 'w', encoding='utf-8') as f:
                json.dump(self.state, f, indent=2, ensure_ascii=False)
            tmp_file.replace(self.state_file)
        except Exception as e:
            logger.warning(f"保存状态失败: {e}")

    def get_last_display(self):
        """获取上次的显示状态（用于进程重启恢复）"""
        return self.state.get("last_display")

    def set_last_display(self, display):
        """设置上次显示状态"""
        self.state["last_display"] = display
        self._save_state()

    @staticmethod
    def _calculate_distance(lat1, lon1, lat2, lon2):
        """
        计算两点间距离（米）
        使用 Haversine 公式
        """
        R = 6371000  # 地球半径（米）
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

        if fence_lat == 0 and fence_lon == 0:
            return False, float('inf')

        distance = self._calculate_distance(lat, lon, fence_lat, fence_lon)
        return distance <= fence_radius, distance

    def determine_state(self, location, current_event=None):
        """
        判断当前状态

        参数:
            location: {"lat": float, "lon": float, "name": str} 或 None
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
            result = {
                "status": "busy" if is_busy else "event",
                "emoji": emoji,
                "display": f"{emoji} {event_name}{suffix}",
                "location": "",
                "commute_mode": False,
            }
            # 有日程时不改变通勤状态（可能只是短暂会议）
            return result

        # P2: 物理位置判断
        if not location:
            return {
                "status": "unknown",
                "emoji": "❓",
                "display": "❓ 位置未知",
                "location": "",
                "commute_mode": self.state.get("commute_mode", False),
            }

        lat = location.get("lat")
        lon = location.get("lon")

        if lat is None or lon is None:
            return {
                "status": "unknown",
                "emoji": "❓",
                "display": "❓ 位置未知",
                "location": "",
                "commute_mode": self.state.get("commute_mode", False),
            }

        home_config = config.get("home_location", {})
        work_config = config.get("work_location", {})

        at_home, home_dist = self._is_in_geofence(lat, lon, home_config)
        at_work, work_dist = self._is_in_geofence(lat, lon, work_config)

        last_state = self.state.get("last_state")
        commute_mode = self.state.get("commute_mode", False)

        COMMUTE_TRIGGER_DISTANCE = home_config.get("radius", 200) + 50  # 围栏半径 + 50m 余量

        current_state = None
        display = ""
        emoji = ""
        location_name = ""

        if at_home:
            if commute_mode and last_state in (self.STATE_COMMUTE_TO_HOME, self.STATE_COMMUTE_TO_WORK):
                logger.info("到达家，通勤结束")
            commute_mode = False
            current_state = self.STATE_HOME
            emoji = "🏠"
            display = "🏠 在家"
            location_name = "家"

        elif at_work:
            if commute_mode and last_state in (self.STATE_COMMUTE_TO_WORK, self.STATE_COMMUTE_TO_HOME):
                logger.info("到达公司，通勤结束")
            commute_mode = False
            current_state = self.STATE_WORK
            emoji = "🏢"
            display = "🏢 搬砖中"
            location_name = "公司"

        else:
            location_name = location.get("name", "未知地点")

            if last_state == self.STATE_HOME and home_dist > COMMUTE_TRIGGER_DISTANCE:
                # 离开家，开始上班通勤
                commute_mode = True
                current_state = self.STATE_COMMUTE_TO_WORK
                emoji = "🚗"
                display = f"🚗 正在上班途中（当前：{location_name}）"

            elif last_state == self.STATE_WORK and work_dist > COMMUTE_TRIGGER_DISTANCE:
                # 离开公司，开始下班通勤
                commute_mode = True
                current_state = self.STATE_COMMUTE_TO_HOME
                emoji = "🚗"
                display = self._commute_home_display(lat, lon, home_config, location_name)

            elif commute_mode:
                # 持续通勤中
                if last_state == self.STATE_COMMUTE_TO_WORK:
                    current_state = self.STATE_COMMUTE_TO_WORK
                    emoji = "🚗"
                    display = f"🚗 正在上班途中（当前：{location_name}）"
                else:
                    current_state = self.STATE_COMMUTE_TO_HOME
                    emoji = "🚗"
                    display = self._commute_home_display(lat, lon, home_config, location_name)
            else:
                # 普通外部位置
                current_state = self.STATE_UNKNOWN
                emoji = "📍"
                display = f"📍 在{location_name}"

        # 更新持久化状态
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
            "commute_mode": commute_mode,
        }

    def _commute_home_display(self, lat, lon, home_config, location_name):
        """生成下班通勤的显示文本"""
        home_lat = home_config.get("lat")
        home_lon = home_config.get("lon")
        if home_lat and home_lon:
            dist_to_home = self._calculate_distance(lat, lon, home_lat, home_lon)
            dist_km = round(dist_to_home / 1000, 1)
            return f"🚗 正在下班途中，距离家 {dist_km}km（当前：{location_name}）"
        return f"🚗 正在下班途中（当前：{location_name}）"

    def get_polling_interval(self):
        """获取当前轮询间隔"""
        if self.state.get("commute_mode"):
            return config.get("commute_polling_interval", 60)
        return config.get("polling_interval", 900)
```
