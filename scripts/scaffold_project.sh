#!/bin/bash
# Apple iCloud 状态墙 - 项目脚手架脚本
# 快速生成完整的项目目录结构和文件
set -e

PROJECT_NAME="${1:-apple-calendar-home}"
echo "🍎 创建 Apple iCloud 状态墙项目: $PROJECT_NAME"
echo "=================================================="

# 创建目录结构
mkdir -p "$PROJECT_NAME/status_wall"

# 创建 requirements.txt
cat > "$PROJECT_NAME/requirements.txt" << 'EOF'
caldav>=1.3.0
icalendar>=5.0.0
requests>=2.28.0

# 可选：启用 FindMy 定位功能时安装
# pyicloud>=1.0.0
EOF

# 创建 .gitignore
cat > "$PROJECT_NAME/.gitignore" << 'EOF'
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
*.egg-info/
dist/
build/
.eggs/
*.egg
.env
.status_wall.json
.status_wall_state.json
.status_wall.pid
.status_wall.log
.status_wall_cookies/
EOF

# 创建 __init__.py
cat > "$PROJECT_NAME/status_wall/__init__.py" << 'EOF'
"""
Apple iCloud 状态墙守护进程
聚合多平台日程到 iCloud 共享日历，可选 GPS 定位
"""

__version__ = "2.0.0"
__author__ = "Status Wall Assistant"
EOF

echo "✅ 项目脚手架已创建: $PROJECT_NAME/"
echo ""
echo "接下来需要创建以下源文件（参考 skill 的 references/source_code.md）:"
echo "  - $PROJECT_NAME/setup.py"
echo "  - $PROJECT_NAME/install.sh"
echo "  - $PROJECT_NAME/status_wall/config.py"
echo "  - $PROJECT_NAME/status_wall/cli.py"
echo "  - $PROJECT_NAME/status_wall/daemon.py"
echo "  - $PROJECT_NAME/status_wall/daemon_runner.py"
echo "  - $PROJECT_NAME/status_wall/external_calendar_sync.py  # 新增"
echo "  - $PROJECT_NAME/status_wall/calendar_reader.py"
echo "  - $PROJECT_NAME/status_wall/calendar_writer.py"
echo "  - $PROJECT_NAME/status_wall/location_service.py       # 可选：定位功能"
echo "  - $PROJECT_NAME/status_wall/amap_service.py           # 可选：定位功能"
echo "  - $PROJECT_NAME/status_wall/state_manager.py          # 可选：定位功能"
echo ""
echo "完成后运行: bash $PROJECT_NAME/install.sh"
