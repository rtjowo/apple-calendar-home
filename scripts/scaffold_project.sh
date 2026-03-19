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
pyicloud>=1.0.0
caldav>=1.3.0
icalendar>=5.0.0
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
EOF

# 创建 __init__.py
cat > "$PROJECT_NAME/status_wall/__init__.py" << 'EOF'
"""
Apple iCloud 状态墙守护进程
自动更新用户状态到 iCloud 共享日历
"""

__version__ = "1.0.0"
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
echo "  - $PROJECT_NAME/status_wall/calendar_reader.py"
echo "  - $PROJECT_NAME/status_wall/calendar_writer.py"
echo "  - $PROJECT_NAME/status_wall/location_service.py"
echo "  - $PROJECT_NAME/status_wall/amap_service.py"
echo "  - $PROJECT_NAME/status_wall/state_manager.py"
echo ""
echo "完成后运行: bash $PROJECT_NAME/install.sh"
