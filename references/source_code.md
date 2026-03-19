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
    version="2.0.0",
    author="Status Wall Assistant",
    description="Apple iCloud 状态墙 - 聚合多平台日程到共享日历，可选 GPS 定位",
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
        "caldav>=1.3.0",
        "icalendar>=5.0.0",
        "requests>=2.28.0",
    ],
    extras_require={
        "location": [
            "pyicloud>=1.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "status_wall=status_wall.cli:main",
        ],
    },
)
```

## requirements.txt

```
caldav>=1.3.0
icalendar>=5.0.0
requests>=2.28.0

# 可选：启用 FindMy 定位功能时安装
# pyicloud>=1.0.0
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

# 询问是否安装定位功能
echo ""
echo "📍 是否启用 FindMy 定位功能？（需要 iCloud 主密码 + 高德 API Key）"
echo "  定位功能提供：GPS 位置、电子围栏、通勤检测、回家距离等"
echo "  如果你只需要日程同步，可以跳过"
read -p "启用定位功能？[y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pip install pyicloud>=1.0.0
    echo "✅ 定位功能已安装"
fi

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
echo "  2. status_wall sync       # 同步企业微信/飞书日程（如已配置）"
echo "  3. status_wall start      # 启动守护进程"
echo "  4. status_wall status     # 查看状态"
echo ""
echo "其他命令:"
echo "  status_wall stop          # 停止守护进程"
echo "  status_wall once          # 单次执行（调试）"
echo "  status_wall show-gps      # 查看当前位置（需定位功能）"
echo ""
echo "配置文件: ~/.status_wall.json"
echo ""
```

## status_wall/__init__.py

```python
"""
Apple iCloud 状态墙守护进程
聚合多平台日程到 iCloud 共享日历，可选 GPS 定位
"""

__version__ = "2.0.0"
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

    # 默认配置 — 分层结构
    _DEFAULTS = {
        # ===== 核心配置（必填）=====
        "icloud_username": "",
        "icloud_app_password": "",          # Apple 应用专用密码（CalDAV 读写日历）
        "private_calendar_name": "",        # 读取的私人日历名称
        "shared_calendar_name": "Status Wall",  # 写入的共享日历名称

        # ===== 可选：企业微信日程同步 =====
        "wecom_enabled": False,
        "wecom_caldav_username": "",        # 企业微信日程设置中获取
        "wecom_caldav_password": "",        # 企业微信日程设置中获取
        "wecom_calendar_name": "",          # 要同步的企业微信日历名称（留空=全部）

        # ===== 可选：飞书日程同步 =====
        "feishu_enabled": False,
        "feishu_caldav_username": "",       # 飞书设置中生成的 CalDAV 用户名
        "feishu_caldav_password": "",       # 飞书设置中生成的 CalDAV 密码
        "feishu_caldav_server": "",         # 飞书 CalDAV 服务器地址
        "feishu_calendar_name": "",         # 要同步的飞书日历名称（留空=全部）

        # ===== 可选：FindMy 定位 + 地图 =====
        "location_enabled": False,          # 是否启用定位功能
        "icloud_password": "",              # Apple ID 主密码（仅 FindMy 需要）
        "amap_api_key": "",                 # 高德地图 API Key（仅定位需要）
        "home_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
        "work_location": {"lat": 0.0, "lon": 0.0, "radius": 200},
        "cookie_directory": str(Path.home() / ".status_wall_cookies"),

        # ===== 通用设置 =====
        "polling_interval": 900,
        "commute_polling_interval": 60,
        "log_level": "INFO",
        "data_file": str(Path.home() / ".status_wall_state.json"),
    }

    def __init__(self):
        self._data = None  # 延迟加载

    @property
    def data(self):
        if self._data is None:
            self._data = dict(self._DEFAULTS)
            # 深拷贝嵌套字典
            for k, v in self._DEFAULTS.items():
                if isinstance(v, dict):
                    self._data[k] = dict(v)
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
        self._data = None
        _ = self.data  # 触发重新加载

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
        """检查核心必填项是否已配置"""
        required = ["icloud_username", "icloud_app_password"]
        return all(self.data.get(k) for k in required)

    def is_location_enabled(self):
        """是否启用了定位功能"""
        return (
            self.data.get("location_enabled", False)
            and self.data.get("icloud_password")
            and self.data.get("amap_api_key")
        )

    def is_wecom_enabled(self):
        """是否启用了企业微信同步"""
        return (
            self.data.get("wecom_enabled", False)
            and self.data.get("wecom_caldav_username")
            and self.data.get("wecom_caldav_password")
        )

    def is_feishu_enabled(self):
        """是否启用了飞书同步"""
        return (
            self.data.get("feishu_enabled", False)
            and self.data.get("feishu_caldav_username")
            and self.data.get("feishu_caldav_password")
        )

    def interactive_init(self):
        """交互式初始化配置"""
        print()
        print("=" * 55)
        print("  🍎 Apple iCloud 状态墙 — 初始化配置")
        print("=" * 55)

        # ===== 核心配置 =====
        print()
        print("━━━━ 第一步：iCloud 日历（必填）━━━━")
        print()
        print("📧 Apple ID 邮箱（登录 iCloud 用的那个）:")
        self.data["icloud_username"] = input("  > ").strip()

        print()
        print("🔐 应用专用密码:")
        print("   ⚠️ 不是你的 Apple 登录密码！")
        print("   获取方法: appleid.apple.com → 登录 → App 专用密码 → 生成")
        print("   格式类似: xxxx-xxxx-xxxx-xxxx")
        self.data["icloud_app_password"] = getpass.getpass("  > ")

        print()
        print("📅 你想读取哪个日历的日程？")
        print("   留空 = 使用默认日历（大多数人直接回车就行）")
        cal = input("  > ").strip()
        if cal:
            self.data["private_calendar_name"] = cal

        print()
        print("📤 状态写入到哪个共享日历？")
        print("   这个日历需要提前创建好并分享给家人")
        print("   留空 = 使用 \"Status Wall\"")
        shared = input("  > ").strip()
        if shared:
            self.data["shared_calendar_name"] = shared

        # ===== 企业微信 =====
        print()
        print("━━━━ 第二步：工作日程同步（可选）━━━━")
        print()
        print("  可以把企业微信/飞书的日程同步到苹果日历，")
        print("  这样家人也能看到你的工作安排。")
        print("  同步是单向的：只读取，不会反向写入。")

        print()
        print("📱 你用企业微信吗？")
        print("   如果用，需要获取 CalDAV 同步信息:")
        print("   企业微信 App → 工作台 → 日程 → ⋯ → 设置 → 同步到系统日历")
        wecom = input("  启用企业微信同步？[y/N] ").strip().lower()
        if wecom in ('y', 'yes'):
            self.data["wecom_enabled"] = True
            print()
            print("  👤 企业微信 CalDAV 用户名（上述页面中显示的）:")
            self.data["wecom_caldav_username"] = input("  > ").strip()
            print("  🔑 企业微信 CalDAV 密码:")
            self.data["wecom_caldav_password"] = getpass.getpass("  > ")
            print("  📅 只同步某个日历？留空 = 全部同步:")
            wc = input("  > ").strip()
            if wc:
                self.data["wecom_calendar_name"] = wc

        print()
        print("📱 你用飞书吗？")
        print("   如果用，需要获取 CalDAV 同步信息:")
        print("   飞书 App → 头像 → 设置 → 日历 → 第三方日历管理 → CalDAV 同步")
        feishu = input("  启用飞书同步？[y/N] ").strip().lower()
        if feishu in ('y', 'yes'):
            self.data["feishu_enabled"] = True
            print()
            print("  👤 飞书 CalDAV 用户名:")
            self.data["feishu_caldav_username"] = input("  > ").strip()
            print("  🔑 飞书 CalDAV 密码:")
            self.data["feishu_caldav_password"] = getpass.getpass("  > ")
            print("  🌐 飞书 CalDAV 服务器地址（上述页面中显示的）:")
            self.data["feishu_caldav_server"] = input("  > ").strip()
            print("  📅 只同步某个日历？留空 = 全部同步:")
            fc = input("  > ").strip()
            if fc:
                self.data["feishu_calendar_name"] = fc

        # ===== FindMy 定位 =====
        print()
        print("━━━━ 第三步：GPS 定位（可选，大多数人不需要）━━━━")
        print()
        print("  开启后共享日历会显示位置状态，比如:")
        print("  🏠 在家 / 🏢 搬砖中 / 🚗 正在下班途中，距离家 3.2km")
        print()
        print("  需要额外提供:")
        print("  • Apple ID 登录密码（真正的登录密码，用于 Find My）")
        print("  • 高德地图 API Key（lbs.amap.com 申请）")
        print("  • 家和公司的经纬度坐标")
        print()
        print("  💡 不开启的话，没日程时会显示「✅ 空闲」，也完全够用")
        loc = input("  启用 GPS 定位？[y/N] ").strip().lower()
        if loc in ('y', 'yes'):
            self.data["location_enabled"] = True

            print()
            print("  🔑 Apple ID 登录密码（用于 iCloud Find My）:")
            print("     ⚠️ 这次是真正的登录密码，不是应用专用密码")
            print("     首次使用会触发双重认证，需要你手动输入验证码")
            self.data["icloud_password"] = getpass.getpass("  > ")

            print()
            print("  🗺️ 高德地图 Web 服务 API Key:")
            print("     获取: lbs.amap.com → 控制台 → 应用管理 → 创建应用 → 添加 Key")
            print("     服务平台选「Web服务」")
            self.data["amap_api_key"] = input("  > ").strip()

            print()
            print("  🏠 家的位置（在 lbs.amap.com/tools/picker 搜索地址后点击获取）")
            print("     纬度 (lat):")
            self._input_float("home_location", "lat")
            print("     经度 (lon):")
            self._input_float("home_location", "lon")
            print("     围栏半径（默认 200 米，直接回车跳过）:")
            self._input_float("home_location", "radius", allow_empty=True)

            print()
            print("  🏢 公司的位置（同样方法获取）")
            print("     纬度 (lat):")
            self._input_float("work_location", "lat")
            print("     经度 (lon):")
            self._input_float("work_location", "lon")
            print("     围栏半径（默认 200 米，直接回车跳过）:")
            self._input_float("work_location", "radius", allow_empty=True)

            # 确保 cookie 目录存在
            cookie_dir = Path(self.data["cookie_directory"])
            cookie_dir.mkdir(parents=True, exist_ok=True)

        # ===== 保存 =====
        print()
        print("=" * 55)
        if self.save():
            print(f"  ✅ 配置已保存到 {self.CONFIG_PATH}")
            print()
            self._print_summary()
            print()
            print("  接下来运行:")
            if self.is_wecom_enabled() or self.is_feishu_enabled():
                print("    status_wall sync    ← 同步外部日程")
            print("    status_wall start   ← 启动守护进程")
            print("    status_wall status  ← 查看运行状态")
        else:
            print("  ❌ 配置保存失败")

    def _print_summary(self):
        """打印配置摘要"""
        print("  📋 配置摘要:")
        print(f"     iCloud 账号:    {self.data['icloud_username']}")
        print(f"     共享日历:       {self.data['shared_calendar_name']}")
        wecom_status = "✅ 已启用" if self.is_wecom_enabled() else "—  未启用"
        feishu_status = "✅ 已启用" if self.is_feishu_enabled() else "—  未启用"
        location_status = "✅ 已启用" if self.is_location_enabled() else "—  未启用"
        print(f"     企业微信同步:   {wecom_status}")
        print(f"     飞书同步:       {feishu_status}")
        print(f"     GPS 定位:       {location_status}")

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


def cmd_sync(args):
    """同步外部日历"""
    if not config.is_configured():
        print("❌ 配置未完成，请先运行 'status_wall init'")
        return

    from status_wall.external_calendar_sync import ExternalCalendarSync

    logging.basicConfig(
        level=logging.DEBUG if getattr(args, 'verbose', False) else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    )

    sync = ExternalCalendarSync()
    print("=" * 50)
    print("📅 外部日历同步")
    print("=" * 50)
    total = sync.sync_all()
    print("=" * 50)
    print(f"✅ 同步完成，共 {total} 个日程")


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
        time.sleep(1)
        if process.poll() is not None:
            print(f"❌ 守护进程启动失败 (退出码: {process.returncode})")
        else:
            print(f"✅ 守护进程已启动 (PID: {process.pid})")
            # 显示已启用的功能
            features = []
            if config.is_wecom_enabled():
                features.append("企业微信同步")
            if config.is_feishu_enabled():
                features.append("飞书同步")
            if config.is_location_enabled():
                features.append("FindMy定位")
            if features:
                print(f"  已启用: {', '.join(features)}")
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
        for _ in range(10):
            time.sleep(0.5)
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                print(f"✅ 守护进程已停止 (PID: {pid})")
                return
        os.kill(pid, signal.SIGKILL)
        print(f"⚠️ 守护进程已强制停止 (PID: {pid})")
    except ProcessLookupError:
        print("⚠️ 守护进程已不存在")
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
    print(f"  iCloud 用户: {config.get('icloud_username', '未设置')}")
    print(f"  共享日历: {config.get('shared_calendar_name', 'Status Wall')}")

    # 功能状态
    print(f"\n📋 功能状态:")
    print(f"  企业微信同步: {'✅ 已启用' if config.is_wecom_enabled() else '⬜ 未启用'}")
    print(f"  飞书同步: {'✅ 已启用' if config.is_feishu_enabled() else '⬜ 未启用'}")
    print(f"  FindMy 定位: {'✅ 已启用' if config.is_location_enabled() else '⬜ 未启用'}")

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
        description='🍎 Apple iCloud 状态墙 — 聚合多平台日程到共享日历',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
  示例:
    status_wall init                  # 交互式初始化配置
    status_wall sync                  # 同步企业微信/飞书日程到 iCloud
    status_wall start                 # 启动守护进程（后台）
    status_wall start -f              # 启动守护进程（前台）
    status_wall stop                  # 停止守护进程
    status_wall status                # 查看状态
    status_wall once                  # 单次执行
    status_wall once -v               # 单次执行（详细日志）
    status_wall show-gps              # 显示当前 GPS 位置（需启用定位）
  """,
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    init_parser = subparsers.add_parser('init', help='交互式初始化配置')
    init_parser.set_defaults(func=cmd_init)

    sync_parser = subparsers.add_parser('sync', help='同步企业微信/飞书日程到 iCloud')
    sync_parser.add_argument('-v', '--verbose', action='store_true', help='详细日志')
    sync_parser.set_defaults(func=cmd_sync)

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

    gps_parser = subparsers.add_parser('show-gps', help='显示当前 GPS 坐标 + 高德地名（需启用定位）')
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
from .external_calendar_sync import ExternalCalendarSync

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
        self.external_sync = ExternalCalendarSync()
        self.last_status = None
        self._consecutive_failures = 0
        self._last_sync_time = 0  # 上次外部日历同步时间

        # 定位相关（可选）
        self.location_service = None
        self.amap_service = None
        self.state_manager = None

        if config.is_location_enabled():
            self._init_location_services()

        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _init_location_services(self):
        """初始化定位相关服务（仅启用定位时调用）"""
        try:
            from .location_service import LocationService
            from .amap_service import AMapService
            from .state_manager import StateManager
            self.location_service = LocationService()
            self.amap_service = AMapService()
            self.state_manager = StateManager()
            logger.info("定位服务已初始化")
        except ImportError as e:
            logger.warning(f"定位依赖未安装: {e}")
            logger.warning("请运行 pip install pyicloud 以启用定位功能")
        except Exception as e:
            logger.warning(f"定位服务初始化失败: {e}")

    def _signal_handler(self, signum, frame):
        """信号处理"""
        logger.info(f"收到信号 {signum}，正在退出...")
        self.running = False

    def _setup_logging(self):
        """配置日志"""
        log_level = getattr(logging, config.get("log_level", "INFO").upper(), logging.INFO)
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

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
        if config.is_location_enabled():
            self._init_location_services()

    def _maybe_sync_external(self):
        """定期同步外部日历（每 30 分钟）"""
        now = time.time()
        sync_interval = 1800  # 30 分钟
        if now - self._last_sync_time >= sync_interval:
            if config.is_wecom_enabled() or config.is_feishu_enabled():
                try:
                    count = self.external_sync.sync_all()
                    logger.info(f"外部日历同步完成，共 {count} 个事件")
                except Exception as e:
                    logger.warning(f"外部日历同步失败: {e}")
            self._last_sync_time = now

    def run_once(self):
        """单次执行状态更新"""
        try:
            logger.info("-" * 40)
            logger.info("开始状态更新轮询")

            # 0. 定期同步外部日历
            self._maybe_sync_external()

            # 1. 获取当前日程 (P1)
            current_event = None
            try:
                current_event = self.calendar_reader.get_current_event()
            except Exception as e:
                logger.warning(f"读取日程异常(非致命): {e}")

            location = None

            # 2. 如果没有日程且定位已启用，获取位置 (P2)
            if not current_event and self.location_service and self.amap_service:
                loc_data = self.location_service.get_current_location()
                if loc_data:
                    lat = loc_data.get("lat")
                    lon = loc_data.get("lon")
                    if lat is not None and lon is not None:
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
            elif current_event:
                logger.info(f"当前日程: {current_event[0]}")

            # 3. 判断状态
            if self.state_manager:
                status = self.state_manager.determine_state(location, current_event)
            else:
                # 无定位模式：仅基于日程判断状态
                status = self._determine_calendar_only_state(current_event)

            logger.info(f"当前状态: {status['display']}")

            # 4. 如果状态变化，写入共享日历
            if status['display'] != self.last_status:
                try:
                    if self.calendar_writer.write_status(status['display']):
                        self.last_status = status['display']
                        if self.state_manager:
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
            if self._consecutive_failures >= 3:
                self._reset_connections()
                self._consecutive_failures = 0
            return False, None

    def _determine_calendar_only_state(self, current_event):
        """无定位模式下的状态判断（仅基于日程）"""
        if current_event:
            event_name, is_busy = current_event
            emoji = "🚫" if is_busy else "📅"
            suffix = " (勿扰)" if is_busy else ""
            return {
                "status": "busy" if is_busy else "event",
                "emoji": emoji,
                "display": f"{emoji} {event_name}{suffix}",
                "location": "",
                "commute_mode": False,
            }
        return {
            "status": "free",
            "emoji": "✅",
            "display": "✅ 空闲",
            "location": "",
            "commute_mode": False,
        }

    def run(self):
        """运行守护进程主循环"""
        self._setup_logging()

        if not config.is_configured():
            logger.error("配置未完成，请先运行 'status_wall init'")
            return False

        self._write_pid()
        self.running = True

        # 恢复上次状态
        if self.state_manager:
            self.last_status = self.state_manager.get_last_display()

        logger.info("=" * 50)
        logger.info("🍎 状态墙守护进程启动")
        features = []
        if config.is_wecom_enabled():
            features.append("企业微信")
        if config.is_feishu_enabled():
            features.append("飞书")
        if config.is_location_enabled():
            features.append("FindMy定位")
        feature_str = " + ".join(features) if features else "仅 iCloud 日程"
        logger.info(f"  已启用: {feature_str}")
        logger.info(f"  轮询间隔: {config.get('polling_interval')}s")
        logger.info("=" * 50)

        try:
            while self.running:
                success, status = self.run_once()
                if not self.running:
                    break

                if success:
                    if self.state_manager:
                        interval = self.state_manager.get_polling_interval()
                    else:
                        interval = config.get("polling_interval", 900)
                else:
                    interval = min(60 * (2 ** self._consecutive_failures), MAX_BACKOFF)

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

        if not config.is_location_enabled():
            print("⚠️ 定位功能未启用")
            print("  请运行 'status_wall init' 并启用 FindMy 定位选项")
            return

        if not self.location_service:
            print("❌ 定位服务未初始化")
            print("  请检查 pyicloud 是否已安装: pip install pyicloud")
            return

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

            if self.amap_service:
                location_info = self.amap_service.reverse_geocode(lat, lon)
                if location_info:
                    print(f"\n🏠 位置信息:")
                    print(f"  地址: {location_info.get('formatted_address', 'N/A')}")
                    print(f"  AOI: {location_info.get('aoi') or 'N/A'}")
                    print(f"  POI: {location_info.get('poi') or 'N/A'}")
                    print(f"  街道: {location_info.get('street') or 'N/A'}")
                else:
                    print("\n❌ 无法获取位置名称")

            if self.state_manager:
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
                events = private_cal.search(start=start, end=end, event=True)
            except Exception as e:
                logger.warning(f"搜索日程失败，尝试重连: {e}")
                self.principal = None
                if not self._ensure_connected():
                    return None
                calendars = self.principal.calendars()
                private_cal = calendars[0] if calendars else None
                if not private_cal:
                    return None
                events = private_cal.search(start=start, end=end, event=True)

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
                events = self.target_calendar.search(start=today, end=tomorrow, event=True)
            except Exception as e:
                logger.warning(f"搜索事件失败，尝试重连: {e}")
                self.target_calendar = None
                if not self._ensure_connected():
                    return False
                events = self.target_calendar.search(start=today, end=tomorrow, event=True)

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

## status_wall/external_calendar_sync.py

```python
"""
外部日历同步模块
将企业微信/飞书的日程通过 CalDAV 读取后，复制到用户的 iCloud 私人日历中。
家人通过共享日历即可看到聚合后的日程状态。
"""

import logging
import uuid
from datetime import datetime, timedelta, date, timezone
from xml.etree import ElementTree as ET

import requests as http_requests
from requests.auth import HTTPBasicAuth
from caldav import DAVClient
from icalendar import Calendar as iCalendar, Event
from .config import config

logger = logging.getLogger(__name__)

# 同步事件的标记前缀，用于识别和清理
SYNC_TAG_WECOM = "[企微]"
SYNC_TAG_FEISHU = "[飞书]"


class ExternalCalendarSync:
    """
    外部日历同步器

    工作流程:
    1. 通过 CalDAV 连接到企业微信/飞书日历服务器
    2. 读取指定时间范围内的日程
    3. 将这些日程作为事件写入用户的 iCloud 私人日历
    4. 事件标题加前缀标记来源（[企微] / [飞书]），方便识别和清理
    """

    def __init__(self):
        self.icloud_client = None
        self.icloud_principal = None

    def _connect_icloud(self):
        """连接到 iCloud CalDAV（用于写入同步事件）"""
        try:
            username = config.get("icloud_username")
            password = config.get("icloud_app_password")
            if not username or not password:
                logger.error("缺少 iCloud 认证信息")
                return False

            self.icloud_client = DAVClient(
                url="https://caldav.icloud.com",
                username=username,
                password=password,
            )
            self.icloud_principal = self.icloud_client.principal()
            return True
        except Exception as e:
            logger.error(f"iCloud CalDAV 连接失败: {e}")
            self.icloud_client = None
            self.icloud_principal = None
            return False

    def _get_icloud_calendar(self, calendar_name=""):
        """获取 iCloud 目标日历"""
        if not self.icloud_principal:
            if not self._connect_icloud():
                return None

        calendars = self.icloud_principal.calendars()
        if not calendars:
            logger.error("iCloud 中没有日历")
            return None

        target_name = calendar_name or config.get("private_calendar_name", "")
        shared_name = config.get("shared_calendar_name", "Status Wall").lower()

        # 精确匹配
        if target_name:
            for cal in calendars:
                if cal.name and target_name.lower() in cal.name.lower():
                    return cal

        # 排除共享日历后取第一个
        for cal in calendars:
            cal_name = (cal.name or "").lower()
            if shared_name not in cal_name:
                return cal

        return calendars[0] if calendars else None

    def _connect_external_caldav(self, server_url, username, password):
        """连接到外部 CalDAV 服务器"""
        try:
            client = DAVClient(
                url=server_url,
                username=username,
                password=password,
                timeout=30,
            )
            principal = client.principal()
            return principal
        except Exception as e:
            logger.error(f"外部 CalDAV 连接失败 ({server_url}): {e}")
            return None

    def _read_events_from_external(self, principal, calendar_name="", days_ahead=30):
        """从外部日历读取事件（默认 ±30 天宽范围）— 企业微信等标准 CalDAV 服务器使用"""
        events_list = []
        try:
            calendars = principal.calendars()
            if not calendars:
                logger.warning("外部日历账户中没有日历")
                return events_list

            target_calendars = []
            if calendar_name:
                for cal in calendars:
                    if cal.name and calendar_name.lower() in cal.name.lower():
                        target_calendars.append(cal)
                        break
            if not target_calendars:
                target_calendars = calendars

            now = datetime.now()
            start = now - timedelta(days=days_ahead)
            end = now + timedelta(days=days_ahead)

            for cal in target_calendars:
                try:
                    logger.info(f"读取日历: {cal.name}")
                    events = cal.search(start=start, end=end, event=True)
                    for event in events:
                        try:
                            ical_data = event.data
                            if not ical_data:
                                logger.debug(f"事件数据为空，跳过")
                                continue
                            ical = iCalendar.from_ical(ical_data)
                            for component in ical.walk():
                                if component.name != "VEVENT":
                                    continue
                                summary = str(component.get("summary", "")).strip()
                                dt_start = component.get("dtstart")
                                dt_end = component.get("dtend")
                                if not summary or not dt_start:
                                    continue

                                events_list.append({
                                    "summary": summary,
                                    "dtstart": dt_start.dt,
                                    "dtend": dt_end.dt if dt_end else None,
                                    "description": str(component.get("description", "")),
                                    "location": str(component.get("location", "")),
                                    "transp": str(component.get("transp", "OPAQUE")).upper(),
                                    "uid": str(component.get("uid", "")),
                                })
                        except Exception as e:
                            logger.debug(f"解析外部事件失败: {e}")
                            continue
                except Exception as e:
                    logger.warning(f"读取日历 {cal.name} 失败: {e}")
                    continue

        except Exception as e:
            logger.error(f"读取外部日程失败: {e}")

        return events_list

    def _read_feishu_events_raw(self, server_url, username, password, days_ahead=30):
        """
        用纯 HTTP 请求读取飞书 CalDAV 日程（不依赖 caldav 库版本）

        飞书 CalDAV 的特殊行为:
        - calendar-query REPORT 不返回 calendar-data（返回 404）
        - GET 单个 .ics 文件返回 403 Forbidden
        - calendar-multiget REPORT 能正确返回 calendar-data
        
        因此必须用两步走:
        1. PROPFIND 获取日历 URL + calendar-query 获取事件 href 列表
        2. calendar-multiget 批量获取事件数据
        
        注意: 飞书 CalDAV 服务器可能很慢，timeout 设为 60s，并带重试
        """
        events_list = []
        auth = HTTPBasicAuth(username, password)
        ns = {"D": "DAV:", "C": "urn:ietf:params:xml:ns:caldav"}
        TIMEOUT = 60  # 飞书 CalDAV 较慢，需要更长超时
        MAX_RETRIES = 2

        def _request_with_retry(method, url, **kwargs):
            """带重试的 HTTP 请求"""
            kwargs.setdefault("timeout", TIMEOUT)
            kwargs.setdefault("auth", auth)
            kwargs.setdefault("headers", {"Content-Type": "application/xml", "Depth": "1"})
            for attempt in range(MAX_RETRIES + 1):
                try:
                    return http_requests.request(method, url, **kwargs)
                except Exception as e:
                    if attempt < MAX_RETRIES:
                        logger.warning(f"飞书请求超时，重试 ({attempt+1}/{MAX_RETRIES}): {e}")
                        continue
                    raise

        try:
            # Step 1: PROPFIND 获取用户的日历集合
            principal_url = f"{server_url}/{username}/"
            propfind_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop><D:resourcetype/></D:prop>
</D:propfind>'''
            resp = _request_with_retry("PROPFIND", principal_url, data=propfind_xml)
            if resp.status_code != 207:
                logger.error(f"飞书 PROPFIND 失败: {resp.status_code}")
                return events_list

            root = ET.fromstring(resp.text)
            calendar_urls = []
            for response in root.findall(".//D:response", ns):
                href = response.find("D:href", ns)
                if href is not None and href.text and href.text != f"/{username}/":
                    calendar_urls.append(href.text)
                    logger.info(f"发现飞书日历: {href.text}")

            if not calendar_urls:
                logger.warning("未找到飞书日历")
                return events_list

            # Step 2: 对每个日历发 calendar-query 获取事件 href
            now = datetime.utcnow()
            start_str = (now - timedelta(days=days_ahead)).strftime("%Y%m%dT%H%M%SZ")
            end_str = (now + timedelta(days=days_ahead)).strftime("%Y%m%dT%H%M%SZ")

            for cal_path in calendar_urls:
                cal_url = f"{server_url}{cal_path}"

                query_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
  <D:prop><D:getetag/></D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT">
        <C:time-range start="{start_str}" end="{end_str}"/>
      </C:comp-filter>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>'''

                resp = _request_with_retry("REPORT", cal_url, data=query_xml)
                if resp.status_code != 207:
                    logger.warning(f"飞书 calendar-query 失败: {resp.status_code}")
                    continue

                root = ET.fromstring(resp.text)
                hrefs = []
                for response in root.findall(".//D:response", ns):
                    href = response.find("D:href", ns)
                    if href is not None and href.text:
                        hrefs.append(href.text)

                if not hrefs:
                    logger.info(f"飞书日历 {cal_path} 无事件")
                    continue

                logger.info(f"飞书日历 {cal_path} 找到 {len(hrefs)} 个事件引用")

                # Step 3: calendar-multiget 批量获取事件数据
                href_elements = "\n".join(f"  <D:href>{h}</D:href>" for h in hrefs)
                multiget_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<C:calendar-multiget xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
  <D:prop>
    <D:getetag/>
    <C:calendar-data/>
  </D:prop>
{href_elements}
</C:calendar-multiget>'''

                resp = _request_with_retry("REPORT", cal_url, data=multiget_xml)
                if resp.status_code != 207:
                    logger.warning(f"飞书 calendar-multiget 失败: {resp.status_code}")
                    continue

                root = ET.fromstring(resp.text)
                for response in root.findall(".//D:response", ns):
                    for propstat in response.findall("D:propstat", ns):
                        cal_data_el = propstat.find(".//C:calendar-data", ns)
                        if cal_data_el is None or not cal_data_el.text:
                            continue
                        try:
                            ical = iCalendar.from_ical(cal_data_el.text)
                            for component in ical.walk():
                                if component.name != "VEVENT":
                                    continue
                                summary = str(component.get("summary", "")).strip()
                                dt_start = component.get("dtstart")
                                dt_end = component.get("dtend")
                                if not summary or not dt_start:
                                    continue
                                events_list.append({
                                    "summary": summary,
                                    "dtstart": dt_start.dt,
                                    "dtend": dt_end.dt if dt_end else None,
                                    "description": str(component.get("description", "")),
                                    "location": str(component.get("location", "")),
                                    "transp": str(component.get("transp", "OPAQUE")).upper(),
                                    "uid": str(component.get("uid", "")),
                                })
                        except Exception as e:
                            logger.debug(f"解析飞书事件失败: {e}")
                            continue

        except Exception as e:
            logger.error(f"读取飞书日程失败: {e}")

        return events_list

    def _clean_synced_events(self, icloud_cal, tag):
        """清理 iCloud 日历中已同步的外部事件（按标记前缀）"""
        try:
            now = datetime.now()
            start = now - timedelta(hours=1)
            end = now + timedelta(days=8)
            events = icloud_cal.search(start=start, end=end, event=True)

            deleted = 0
            for event in events:
                try:
                    ical = iCalendar.from_ical(event.data)
                    for component in ical.walk():
                        if component.name == "VEVENT":
                            summary = str(component.get("summary", ""))
                            if summary.startswith(tag):
                                event.delete()
                                deleted += 1
                                break
                except Exception:
                    continue

            if deleted:
                logger.info(f"清理了 {deleted} 个 {tag} 旧同步事件")
        except Exception as e:
            logger.warning(f"清理同步事件失败: {e}")

    def _write_events_to_icloud(self, icloud_cal, events, tag):
        """将事件写入 iCloud 日历"""
        written = 0
        for evt in events:
            try:
                cal = iCalendar()
                cal.add('prodid', '-//Status Wall//External Sync 2.0//EN')
                cal.add('version', '2.0')

                event = Event()
                event.add('summary', f"{tag} {evt['summary']}")

                dt_start = evt['dtstart']
                dt_end = evt.get('dtend')

                # 处理全天事件
                if isinstance(dt_start, date) and not isinstance(dt_start, datetime):
                    event.add('dtstart', dt_start)
                    event.add('dtend', dt_end if dt_end else dt_start + timedelta(days=1))
                else:
                    event.add('dtstart', dt_start)
                    if dt_end:
                        event.add('dtend', dt_end)
                    else:
                        event.add('dtend', dt_start + timedelta(hours=1))

                event.add('dtstamp', datetime.utcnow())
                event.add('uid', f"sw-sync-{uuid.uuid4()}@status-wall")

                if evt.get('description'):
                    event.add('description', evt['description'])
                if evt.get('location'):
                    event.add('location', evt['location'])

                event.add('transp', evt.get('transp', 'OPAQUE'))

                cal.add_component(event)
                icloud_cal.add_event(cal.to_ical())
                written += 1

            except Exception as e:
                logger.warning(f"写入同步事件失败 ({evt.get('summary', '?')}): {e}")
                continue

        return written

    def _read_wecom_events_raw(self, username, password, days_ahead=30):
        """
        用纯 HTTP 请求读取企业微信 CalDAV 日程（不依赖 caldav 库版本）

        企业微信 CalDAV 的特殊行为:
        - 根路径 / 返回 403，必须用 /.well-known/caldav 进入
        - calendar-query REPORT 中 calendar-data 返回 404
        - calendar-multiget REPORT 返回 403
        - GET 单个 .ics 文件正常返回 200 ✅

        因此用三步走:
        1. PROPFIND /calendar/ Depth:1 → 获取日历 URL
        2. calendar-query REPORT → 获取时间范围内的事件 href
        3. GET 逐个获取 .ics 数据
        """
        events_list = []
        server = "https://caldav.wecom.work"
        auth = HTTPBasicAuth(username, password)
        ns = {"D": "DAV:", "C": "urn:ietf:params:xml:ns:caldav"}

        try:
            # Step 1: PROPFIND 获取日历列表
            propfind_xml = '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/><D:displayname/></D:prop></D:propfind>'
            resp = http_requests.request(
                "PROPFIND", f"{server}/calendar/", auth=auth, data=propfind_xml,
                headers={"Content-Type": "application/xml", "Depth": "1"}, timeout=30,
            )
            if resp.status_code != 207:
                logger.error(f"企业微信 PROPFIND 失败: {resp.status_code}")
                return events_list

            root = ET.fromstring(resp.text)
            calendar_urls = []
            for response in root.findall(".//D:response", ns):
                href = response.find("D:href", ns)
                # 寻找 CalDAV 日历资源（有 <calendar/> resourcetype）
                rt = response.find(".//C:calendar", {"C": "urn:ietf:params:xml:ns:caldav"})
                if rt is None:
                    # 尝试用 A 前缀（企微用 A 命名空间）
                    for propstat in response.findall("D:propstat", ns):
                        prop = propstat.find("D:prop", ns)
                        if prop is not None:
                            rt_el = prop.find("D:resourcetype", ns)
                            if rt_el is not None:
                                for child in rt_el:
                                    if "calendar" in child.tag.lower():
                                        rt = child
                                        break
                if href is not None and href.text and rt is not None:
                    # 排除 inbox/outbox/principal
                    if "inbox" not in href.text and "outbox" not in href.text:
                        calendar_urls.append(href.text)
                        logger.info(f"发现企业微信日历: {href.text}")

            if not calendar_urls:
                logger.warning("未找到企业微信日历")
                return events_list

            # Step 2: calendar-query 获取事件 href 列表
            now = datetime.utcnow()
            start_str = (now - timedelta(days=days_ahead)).strftime("%Y%m%dT%H%M%SZ")
            end_str = (now + timedelta(days=days_ahead)).strftime("%Y%m%dT%H%M%SZ")

            for cal_path in calendar_urls:
                cal_url = f"{server}{cal_path}"

                query_xml = f'''<?xml version="1.0"?>
<C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
  <D:prop><D:getetag/></D:prop>
  <C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT">
    <C:time-range start="{start_str}" end="{end_str}"/>
  </C:comp-filter></C:comp-filter></C:filter>
</C:calendar-query>'''

                resp = http_requests.request(
                    "REPORT", cal_url, auth=auth, data=query_xml,
                    headers={"Content-Type": "application/xml", "Depth": "1"}, timeout=30,
                )
                if resp.status_code != 207:
                    logger.warning(f"企业微信 calendar-query 失败: {resp.status_code}")
                    continue

                root = ET.fromstring(resp.text)
                hrefs = []
                for response in root.findall(".//D:response", ns):
                    href = response.find("D:href", ns)
                    if href is not None and href.text and href.text.endswith(".ics"):
                        hrefs.append(href.text)

                if not hrefs:
                    logger.info(f"企业微信日历 {cal_path} 无事件")
                    continue

                logger.info(f"企业微信日历 {cal_path} 找到 {len(hrefs)} 个事件")

                # Step 3: GET 逐个获取 .ics
                for href in hrefs:
                    try:
                        resp = http_requests.get(
                            f"{server}{href}", auth=auth, timeout=30,
                        )
                        if resp.status_code != 200:
                            logger.debug(f"GET {href} 失败: {resp.status_code}")
                            continue

                        ical = iCalendar.from_ical(resp.text)
                        for component in ical.walk():
                            if component.name != "VEVENT":
                                continue
                            summary = str(component.get("summary", "")).strip()
                            dt_start = component.get("dtstart")
                            dt_end = component.get("dtend")
                            if not summary or not dt_start:
                                continue
                            events_list.append({
                                "summary": summary,
                                "dtstart": dt_start.dt,
                                "dtend": dt_end.dt if dt_end else None,
                                "description": str(component.get("description", "")),
                                "location": str(component.get("location", "")),
                                "transp": str(component.get("transp", "OPAQUE")).upper(),
                                "uid": str(component.get("uid", "")),
                            })
                    except Exception as e:
                        logger.debug(f"获取/解析企微事件失败: {e}")
                        continue

        except Exception as e:
            logger.error(f"读取企业微信日程失败: {e}")

        return events_list

    def sync_wecom(self):
        """同步企业微信日程到 iCloud（使用纯 HTTP 方式）"""
        if not config.is_wecom_enabled():
            logger.debug("企业微信同步未启用")
            return 0

        print("🔄 同步企业微信日程...")
        username = config.get("wecom_caldav_username")
        password = config.get("wecom_caldav_password")

        events = self._read_wecom_events_raw(username, password)
        if not events:
            print("  📭 企业微信无待同步日程")
            return 0

        print(f"  📥 读取到 {len(events)} 个企业微信日程")
        icloud_cal = self._get_icloud_calendar()
        if not icloud_cal:
            print("❌ 无法获取 iCloud 日历")
            return 0

        # 先清理旧的同步事件，再写入新的
        self._clean_synced_events(icloud_cal, SYNC_TAG_WECOM)
        written = self._write_events_to_icloud(icloud_cal, events, SYNC_TAG_WECOM)

        print(f"  ✅ 同步了 {written} 个企业微信日程")
        return written

    def sync_feishu(self):
        """同步飞书日程到 iCloud（使用纯 HTTP 方式，不依赖 caldav 库版本）"""
        if not config.is_feishu_enabled():
            logger.debug("飞书同步未启用")
            return 0

        print("🔄 同步飞书日程...")
        username = config.get("feishu_caldav_username")
        password = config.get("feishu_caldav_password")
        server = config.get("feishu_caldav_server", "")
        calendar_name = config.get("feishu_calendar_name", "")

        if not server:
            print("❌ 飞书 CalDAV 服务器地址未配置")
            return 0

        # 确保 URL 格式
        if not server.startswith("http"):
            server = f"https://{server}"

        # 使用纯 HTTP 方式读取飞书日程（飞书 CalDAV 不支持标准 GET 和 calendar-query calendar-data）
        events = self._read_feishu_events_raw(server, username, password)
        if not events:
            print("  📭 飞书无待同步日程")
            return 0

        print(f"  📥 读取到 {len(events)} 个飞书日程")
        icloud_cal = self._get_icloud_calendar()
        if not icloud_cal:
            print("❌ 无法获取 iCloud 日历")
            return 0

        self._clean_synced_events(icloud_cal, SYNC_TAG_FEISHU)
        written = self._write_events_to_icloud(icloud_cal, events, SYNC_TAG_FEISHU)

        print(f"  ✅ 同步了 {written} 个飞书日程")
        return written

    def sync_all(self):
        """同步所有已启用的外部日历"""
        total = 0

        if config.is_wecom_enabled():
            total += self.sync_wecom()

        if config.is_feishu_enabled():
            total += self.sync_feishu()

        if total == 0 and not config.is_wecom_enabled() and not config.is_feishu_enabled():
            print("⚠️ 未启用任何外部日历同步")
            print("  请运行 'status_wall init' 配置企业微信或飞书")

        return total
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
