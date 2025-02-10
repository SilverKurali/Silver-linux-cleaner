#!/usr/bin/env bash

# Silver-Linux系统优化脚本 v0.1.62
# 作者：Silver
# 功能：CatOS专项优化增强脚本
# 描述：这个脚本是一个系统优化工具，可自动识别NVIDIA和AMD显卡，并清理显存，同时优化内存、网络和文件系统，提升系统性能。
# 日期：2025-02-10 17:39
# CatOS官网:https://www.catos.info/

#--------------------------
# 初始化配置
#--------------------------
set -o errexit -o nounset -o pipefail
shopt -s inherit_errexit 2>/dev/null || true
trap 'cleanup_on_exit 143' SIGTERM SIGINT

#--------------------------
# 配置参数（用户可修改）
#--------------------------
LOG_DIR="${HOME}/.cache/silver-optimize"
LOG_FILE="${LOG_DIR}/optimize-$(date +%Y%m%d).log"
SWAP_THRESHOLD=${1:-2048}      # 单位：MB，默认2048
GPU_PROCESS_CHECK=("nvidia-smi" "glxinfo") # 定义GPU进程检查数组

#--------------------------
# 日志系统（增强版）
#--------------------------
init_logging() {
    mkdir -p "$LOG_DIR"
    exec 3>>"$LOG_FILE" # 创建独立日志描述符文件
}

log() {
    local level=$1 color=$2
    shift 2
    printf "\033[;1%sm[%s]\033[0m[%(%T)T] %s\n" "$color" "$level" -1 "$*" | tee /dev/fd/3
}

log_info() { log "INFO" 32 "$@"; }
log_warning() { log "WARN" 33 "$@"; }
log_error() { log "ERROR" 31 "$@"; exit 1; }

#--------------------------
# 检查用户权限并自动提权
#--------------------------
check_and_elevate_privileges() {
    if [[ "$EUID" -ne 0 ]]; then
        log_info "当前用户非root，尝试自动提权..."
        sudo "$0" "$@"
        exit $?
    else
        log_info "当前用户已为root，继续执行..."
    fi
}

#--------------------------
# 自动检测Linux发行版并安装依赖
#--------------------------
install_dependencies() {
    log_info "自动检测Linux发行版并安装脚本依赖..."
    local distro=$(lsb_release -is 2>/dev/null || cat /etc/*release 2>/dev/null | grep -oP '(?<=^ID=).+' | tr -d '"')

    # 检查 figlet 是否已安装
    if ! command -v figlet &>/dev/null; then
        log_info "figlet 未安装，开始安装..."
        case "$distro" in
            Ubuntu|Debian)
                log_info "检测到基于Debian的系统，使用apt-get安装依赖..."
                sudo apt-get update && sudo apt-get install -y figlet
                ;;
            Fedora|CentOS|RedHat)
                log_info "检测到基于Red Hat的系统，使用dnf或yum安装依赖..."
                if command -v dnf &>/dev/null; then
                    sudo dnf install -y figlet
                else
                    sudo yum install -y figlet
                fi
                ;;
            Arch|Manjaro)
                log_info "检测到基于Arch的系统，使用pacman安装依赖..."
                sudo pacman -S --noconfirm figlet
                ;;
            *)
                log_warning "无法识别的Linux发行版：$distro，跳过自动安装依赖。"
                ;;
        esac
    else
        log_info "figlet 已安装，跳过安装。"
    fi

    # 检查 rocm-smi 是否需要安装
    if ! command -v rocm-smi &>/dev/null; then
        log_info "rocm-smi 未安装，尝试安装..."
        case "$distro" in
            Ubuntu|Debian)
                sudo apt-get update && sudo apt-get install -y rocm-smi
                ;;
            Fedora|CentOS|RedHat)
                if command -v dnf &>/dev/null; then
                    sudo dnf install -y rocm-smi
                else
                    sudo yum install -y rocm-smi
                fi
                ;;
            Arch|Manjaro)
                sudo pacman -S --noconfirm rocm-smi
                ;;
            *)
                log_warning "无法识别的Linux发行版：$distro，跳过rocm-smi安装。"
                ;;
        esac
    else
        log_info "rocm-smi 已安装，跳过安装。"
    fi
}

#--------------------------
# 随机颜色生成函数
#--------------------------
generate_random_color() {
    local colors=("31" "32" "33" "34" "35" "36" "91" "92" "93" "94" "95" "96")
    local random_index=$((RANDOM % ${#colors[@]}))
    echo "${colors[$random_index]}"
}

#--------------------------
# 显示 ASCII 艺术字
#--------------------------
show_ascii_art() {
    if command -v figlet &>/dev/null; then
        local random_color=$(generate_random_color)
        figlet "Silver-CatOS-Cleaner" | sed "s/.*/\\033[1;${random_color}m&\\033[0m/"
    else
        log_warning "figlet 未安装，无法显示 ASCII 艺术字。"
    fi
}

#--------------------------
# CatOS专项优化模块
#--------------------------
optimize_catos() {
    [[ -f /etc/catos-release ]] || return 0

    log_info "🔄 执行CatOS专项优化🐱..."

    # 检查 systemd-oomd 是否安装
    if ! systemctl is-enabled systemd-oomd &>/dev/null; then
        log_warning "⚠️ systemd-oomd 未安装或未启用，跳过 OOM 保护策略配置。"
        return
    fi

    # 检查 systemd 版本是否支持 systemd-oomd
    if ! systemctl --version | grep -q 'systemd 248'; then
        log_warning "⚠️ systemd 版本低于 248，可能不支持 systemd-oomd。"
        return
    fi

    # BTRFS文件系统优化
    if mount | grep -q 'btrfs'; then
        log_info "🔧 BTRFS平衡操作..."
        sudo btrfs balance start -dusage=50 -musage=30 / 2>/dev/null
        sudo btrfs filesystem defragment -r -clzo /var 2>/dev/null
    fi

    # systemd-oomd优化
    log_info "🛡️ 配置OOM保护策略..."
    sudo mkdir -p /etc/systemd/oomd.conf.d/
    echo -e "[OOM]\nManagedOOMSwap=auto\nManagedOOMMemoryPressure=auto" | \
        sudo tee /etc/systemd/oomd.conf.d/catos-optimize.conf > /dev/null

    # 网络优化堆栈
    log_info "🌐 网络参数调优..."
    sudo tee /etc/sysctl.d/99-catos-optimize.conf <<EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_congestion_control=bbr
vm.swappiness=10
EOF
    sudo sysctl --system > /dev/null
}

#--------------------------
# 智能管理内存模块
#--------------------------
manage_memory() {
    local avail_mem=$(free -m | awk '/Mem/{print $7}')

    log_info "🧠 可用内存：${avail_mem}MB"

    # 智能交换空间管理
    if (( avail_mem < SWAP_THRESHOLD )); then
        log_warning "⚠️ 内存不足，保留swap空间"
        return
    fi

    log_info "🔄 刷新swap空间..."
    if ! sudo swapoff -a; then
        log_warning "⏳ 检测到swap占用进程..."
        sudo swapoff -av || log_error "无法关闭swap分区。"
    fi
    sudo swapon -a

    log_info "🧹 清理内核缓存..."
    sudo sync && sudo sysctl vm.drop_caches=3
}

#--------------------------
# 智能GPU管理模块
#--------------------------
manage_gpu() {
    log_info "🎮 智能GPU管理..."

    # NVIDIA GPU处理
    if command -v nvidia-smi &>/dev/null; then
        log_info "🎮 检测到NVIDIA GPU设备"
        if pgrep -x "${GPU_PROCESS_CHECK[@]}" >/dev/null; then
            log_warning "🚫 检测到运行中的GPU进程，跳过显存重置"
            return
        fi

        log_info "🧹 重置NVIDIA GPU显存..."
        sudo nvidia-smi --gpu-reset -i GPU_RESET -r || log_warning "⚠️ NVIDIA GPU重置失败"
    fi

    # AMD GPU处理
    if command -v rocm-smi &>/dev/null; then
        log_info "🎮 检测到AMD GPU设备"
        sudo rocm-smi --resetall || log_warning "⚠️ AMD GPU重置失败"
    fi
}

#--------------------------
# 输出系统资源占用率
#--------------------------
output_system_usage() {
    log_info "📊 当前系统资源占用率："
    echo -e "\033[1;32mCPU 使用率：\033[0m"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, * $[0-9.]*$ %* id.*/\1/" | awk '{print 100 - $1"%"}'
    echo -e "\033[1;32m内存使用率：\033[0m"
    free -m | awk '/Mem/{printf("%.2f%%\n", ($3/$2)*100)}'

    if command -v nvidia-smi &>/dev/null; then
        echo -e "\033[1;32mNVIDIA GPU 使用率：\033[0m"
        local gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
        if [[ -n "$gpu_usage" ]]; then
            echo "$gpu_usage%"
        else
            echo "无法获取 GPU 使用率"
        fi
    elif command -v rocm-smi &>/dev/null; then
        echo -e "\033[1;32mAMD GPU 使用率：\033[0m"
        local gpu_usage=$(rocm-smi --show-gpu-use | awk '/GPU/{print $2}')
        if [[ -n "$gpu_usage" ]]; then
            echo "$gpu_usage%"
        else
            echo "无法获取 GPU 使用率"
        fi
    else
        log_warning "未检测到 NVIDIA 或 AMD GPU 设备，请检查 GPU 驱动是否正确安装。"
    fi
}

#--------------------------
# 脚本主逻辑
#--------------------------
main() {
    check_and_elevate_privileges
    install_dependencies
    init_logging
    show_ascii_art
    optimize_catos
    manage_memory
    manage_gpu
    output_system_usage
    exec 3>&- # 关闭日志文件描述符
}

#--------------------------
# 执行主逻辑
#--------------------------
main
