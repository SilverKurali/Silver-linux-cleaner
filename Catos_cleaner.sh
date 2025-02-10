#!/bin/bash

# 定义脚本的Gitee仓库地址
GITEE_REPO_URL="https://gitee.com/AY77-OP/Silver-linux-cleaner/raw/master/Catos_cleaner.sh"

# 清理模式函数
clean_mode() {
    echo "进入清理模式..."
    # 检查root权限
    if [ "$(id -u)" != "0" ]; then
        echo "请使用sudo运行此脚本！"
        return 1
    fi

    # 定义颜色代码
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # 重置颜色

    # 显示CPU和GPU占用率
    show_usage() {
        echo -e "${YELLOW}当前CPU和GPU占用率：${NC}"
        top -b -n1 | head -n 5
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi
        else
            echo "未检测到NVIDIA显卡或nvidia-smi命令不存在。"
        fi
    }

    # 内存清理函数
    clean_memory() {
        echo -e "${YELLOW}[1/6] 正在清理系统缓存...${NC}"
        sync
        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
        echo -e "${GREEN}系统缓存已清理完成。${NC}"
    }

    # NVIDIA显存清理函数
    clean_nvidia_vram() {
        echo -e "${YELLOW}[2/6] 检查NVIDIA显存残留...${NC}"
        if command -v nvidia-smi &> /dev/null; then
            zombie_process=$(nvidia-smi --query-compute-apps=pid,gpu_name,used_memory --format=csv | grep -v "No running processes found")
            if [ -n "$zombie_process" ]; then
                echo -e "${RED}检测到显存残留：${NC}"
                echo "$zombie_process"
                echo -e "${YELLOW}尝试重置GPU...${NC}"
                nvidia-smi -i 0 -r > /dev/null 2>&1
            else
                echo -e "${GREEN}未检测到显存残留${NC}"
            fi
        else
            echo -e "${YELLOW}未检测到NVIDIA显卡或nvidia-smi命令不存在。${NC}"
        fi
    }

    # 关闭用户选择的后台服务
    stop_selected_services() {
        echo -e "${YELLOW}[3/6] 关闭用户选择的后台服务...${NC}"
        local services=$(systemctl list-units --type=service --state=running --no-legend --full --all)
        echo "当前正在运行的服务："
        echo "$services" | while read -r service; do
            echo "$service"
        done
        read -p "请输入要关闭的服务名称（直接输入服务名称，多个服务用空格分隔）：" services_to_stop
        for service in $services_to_stop; do
            if systemctl is-active --quiet "$service"; then
                systemctl stop "$service"
                echo "已关闭服务：$service"
            else
                echo "服务未运行或名称错误：$service"
            fi
        done
        echo -e "${GREEN}用户选择关闭的服务已关闭。${NC}"
    }

    # 调整系统性能模式
    set_performance_mode() {
        echo -e "${YELLOW}[4/6] 设置系统性能模式为高性能...${NC}"
        sudo cpupower frequency-set -g performance 2>/dev/null
        echo -e "${GREEN}系统性能模式已设置为高性能。${NC}"
    }

    # 清理临时文件
    clean_temp_files() {
        echo -e "${YELLOW}[5/6] 清理系统临时文件...${NC}"
        sudo rm -rf /tmp/* 2>/dev/null
        sudo rm -rf /var/tmp/* 2>/dev/null
        echo -e "${GREEN}系统临时文件已清理完成。${NC}"
    }

    # 关闭屏幕保护程序和休眠功能
    disable_screensaver_and_sleep() {
        echo -e "${YELLOW}[6/6] 关闭屏幕保护程序和休眠功能...${NC}"
        xset s off 2>/dev/null
        xset -dpms 2>/dev/null
        sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null
        echo -e "${GREEN}屏幕保护程序和休眠功能已关闭。${NC}"
    }

    # 主程序
    echo -e "${GREEN}===== 游戏前系统优化开始 =====${NC}"
    echo -e "当前内存状态："
    free -h

    # 显示优化前的CPU和GPU占用率
    echo -e "${YELLOW}优化前的CPU和GPU占用率：${NC}"
    show_usage

    # 执行内存清理
    clean_memory

    # 检测NVIDIA显卡并清理显存
    clean_nvidia_vram

    # 关闭用户选择的后台服务
    stop_selected_services

    # 调整系统性能模式
    set_performance_mode

    # 清理临时文件
    clean_temp_files

    # 关闭屏幕保护程序和休眠功能
    disable_screensaver_and_sleep

    echo -e "${GREEN}===== 游戏前系统优化完成 =====${NC}"
    echo -e "优化后的内存状态："
    free -h

    # 显示优化后的CPU和GPU占用率
    echo -e "${YELLOW}优化后的CPU和GPU占用率：${NC}"
    show_usage

    echo -e "\n${GREEN}提示：${NC}"
    echo "1. NVIDIA显存重置可能需要重新启动图形界面。"
    echo "2. 建议在游戏开始前运行此脚本。"
    echo "3. 定时任务配置：sudo crontab -e 添加 ' * *0 * * /path/to/this/script.sh'，例如："
    echo "   * *0 * * /home/user/scripts/pre_game_optimization.sh"
}

# 检查更新函数
check_updates() {
    echo "正在检查更新..."
    # 获取当前脚本路径
    SCRIPT_PATH=$(realpath "$0")
    # 下载最新的脚本文件
    curl -s -o "$SCRIPT_PATH" "$GITEE_REPO_URL"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}更新成功！请重新运行脚本。${NC}"
    else
        echo -e "${RED}更新失败，请检查网络连接或仓库地址。${NC}"
    fi
}

# 关于函数
about() {
    echo "关于这个工具："
    echo "这是一个简单的Linux工具，用于清理、检查更新等操作。"
}

# 主菜单
while true; do
    echo "请选择操作："
    echo "1. 清理模式"
    echo "2. 检查更新"
    echo "3. 关于"
    echo "4. 退出"
    read -p "请输入选项[1-4]: " choice

    case $choice in
        1)
            clean_mode
            ;;
        2)
            check_updates
            ;;
        3)
            about
            ;;
        4)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入"
            ;;
    esac
done
