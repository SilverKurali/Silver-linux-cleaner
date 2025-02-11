#!/bin/bash

# Silver-Linux系统优化脚本 v0.12.List-Pro-preview_edition
# 作者：Silver
# 功能：CatOS-Linux优化增强脚本
# 描述：这个脚本是一个系统优化工具，可自动识别NVIDIA显卡，并清理显存，同时优化内存、提升系统性能。
# 日期：2025-02-11 10:55

# 定义脚本的Gitee仓库地址(用于更新)
GITEE_REPO_URL="https://gitee.com/AY77-OP/Silver-linux-cleaner/raw/master/Catos_cleaner.sh"

# 检测是否为CatOS
is_catos() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$NAME" == "CatOS" ]]; then
            return 0
        fi
    fi
    return 1
}

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
    echo -e "${YELLOW}[3/6] 关闭用户选择的后台进程...${NC}"

    # 获取用户可选择的进程列表
    get_processes() {
        local keyword=$1
        if [[ -z "$keyword" ]]; then
            ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk 'NR>1 {print NR-1, $0}'  # 添加序号并按CPU占用率排序
        else
            ps -eo pid,comm,%cpu,%mem --sort=-%cpu | grep "$keyword" | awk 'NR>1 {print NR-1, $0}'  # 添加序号并过滤
        fi
    }

    # 显示进程菜单
    show_processes_menu() {
        local keyword=$1
        local processes=$(get_processes "$keyword")
        echo "可选择结束的进程列表（输入关键字过滤）："
        echo "$processes"
    }

    # 用户输入关键字过滤进程
    local keyword=""
    while true; do
        read -p "请输入关键字过滤进程（直接回车显示所有进程）： " keyword
        show_processes_menu "$keyword"
        echo "请输入要关闭的进程序号（多个序号用空格分隔，输入'q'退出）："
        read -p "序号： " choices

        if [[ "$choices" == "q" ]]; then
            echo "取消操作。"
            return
        fi

        local valid_choices=()
        local max_index=$(get_processes "$keyword" | wc -l)
        for choice in $choices; do
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= max_index)); then
                valid_choices+=("$choice")
            else
                echo "无效的序号：$choice"
            fi
        done

        if [[ ${#valid_choices[@]} -eq 0 ]]; then
            echo "未选择任何有效序号，请重新输入。"
            continue
        fi

        # 根据用户选择的序号结束进程
        local processes=$(get_processes "$keyword")
        local count=0
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+ ]]; then
                ((count++))
                for choice in "${valid_choices[@]}"; do
                    if [[ "$choice" == "$count" ]]; then
                        local pid=$(echo "$line" | awk '{print $2}')
                        if kill -0 "$pid" 2>/dev/null; then
                            kill -9 "$pid"  # 强制结束进程
                            echo "已关闭进程：$(echo "$line" | cut -d' ' -f2-)"
                            echo "$(date): 已关闭进程：$(echo "$line" | cut -d' ' -f2-)" >> /var/log/silver-linux-cleaner.log
                        else
                            echo "进程不存在或无法结束：$(echo "$line" | cut -d' ' -f2-)"
                        fi
                    fi
                done
            fi
        done <<< "$processes"

        echo -e "${GREEN}用户选择关闭的进程已关闭。${NC}"
        break
    done
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

    # 针对CatOS的优化
    catos_optimization() {
        echo -e "${YELLOW}[7/6] 针对CatOS的优化...${NC}"
        if is_catos; then
            echo -e "${GREEN}检测到CatOS系统，执行CatOS特定优化。${NC}"
            # 示例：清理AUR缓存
            if command -v yay &> /dev/null; then
                echo -e "${YELLOW}清理AUR缓存...${NC}"
                yay -Sc --noconfirm
                echo -e "${GREEN}AUR缓存已清理。${NC}"
            else
                echo -e "${RED}未检测到yay，跳过AUR缓存清理。${NC}"
            fi
            # 示例：更新系统
            echo -e "${YELLOW}更新系统...${NC}"
            sudo pacman -Syu --noconfirm
            echo -e "${GREEN}系统更新完成。${NC}"
        else
            echo -e "${RED}未检测到CatOS系统，跳过CatOS特定优化。${NC}"
        fi
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

    # 针对CatOS的优化
    catos_optimization

    echo -e "${GREEN}===== 游戏前系统优化完成 =====${NC}"
    echo -e "优化后的内存状态："
    free -h

    # 显示优化后的CPU和GPU占用率
    echo -e "${YELLOW}优化后的CPU和GPU占用率：${NC}"
    show_usage

    echo -e "\n${GREEN}提示：${NC}"
    echo "1. NVIDIA显存重置可能需要重新启动图形界面。"
    echo "2. 建议在游戏开始前运行此脚本。"
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
    echo "CatOs官网:https://www.catos.info/"
    echo "作者SilverKurali__交流群:428382413"
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
