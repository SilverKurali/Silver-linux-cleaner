import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import sys
import datetime
import locale
import shutil  # 导入shutil模块

# 基础配置
LANG = "zh_CN.UTF-8"  # 默认中文，可改为"en_US.UTF-8"切换英文
LOG_FILE = "/var/log/catos_optimizer_gui.log"

# 国际化字符串
STRINGS = {
    "zh_CN.UTF-8": {
        "title": "CatOS 系统优化工具",
        "mem_clean": "清理内存缓存",
        "vram_clean": "清理NVIDIA显存",
        "kill_process": "结束进程",
        "perf_mode": "性能模式",
        "temp_clean": "清理临时文件",
        "disable_sleep": "禁用休眠",
        "catos_opt": "CatOS优化",
        "status": "状态: 就绪",
        "log": "操作日志",
        "about_content": """CatOS系统优化工具 v1.0
作者：Silver
功能：图形化系统优化工具
交流群：428382413""",
        "need_root": "需要root权限！"
    },
    "en_US.UTF-8": {
        "title": "CatOS System Optimizer",
        "mem_clean": "Clear Memory Cache",
        "vram_clean": "Clean NVIDIA VRAM",
        "kill_process": "Kill Processes",
        "perf_mode": "Performance Mode",
        "temp_clean": "Clean Temp Files",
        "disable_sleep": "Disable Sleep",
        "catos_opt": "CatOS Optimization",
        "status": "Status: Ready",
        "log": "Operation Log",
        "about_content": """CatOS System Optimizer v1.0
Author: Silver
Function: GUI System Optimization Tool
Group: 428382413""",
        "need_root": "Root privileges required!"
    }
}

class CatOSOptimizerGUI:
    def __init__(self, master):
        self.master = master
        self.setup_language()
        self.setup_ui()
        self.check_root()

    def setup_language(self):
        """设置本地化语言"""
        try:
            locale.setlocale(locale.LC_ALL, LANG)
            self.lang = STRINGS[LANG]
        except:
            self.lang = STRINGS["en_US.UTF-8"]

    def check_root(self):
        """检查root权限"""
        if os.geteuid() != 0:
            messagebox.showwarning(self.lang["title"], self.lang["need_root"])

    def setup_ui(self):
        """初始化界面"""
        self.master.title(self.lang["title"])
        self.master.geometry("800x600")

        # 控制面板
        control_frame = ttk.LabelFrame(self.master, text="功能控制")
        control_frame.pack(pady=10, fill="x")

        buttons = [
            (self.lang["mem_clean"], self.clean_memory),
            (self.lang["vram_clean"], self.clean_vram),
            (self.lang["kill_process"], self.show_process_manager),
            (self.lang["perf_mode"], self.set_performance_mode),
            (self.lang["temp_clean"], self.clean_temp_files),
            (self.lang["disable_sleep"], self.disable_sleep),
            (self.lang["catos_opt"], self.catos_optimization)
        ]

        for text, cmd in buttons:
            btn = ttk.Button(control_frame, text=text, command=cmd)
            btn.pack(side="left", padx=5)

        # 状态栏
        self.status = ttk.Label(self.master, text=self.lang["status"])
        self.status.pack(side="bottom", fill="x")

        # 日志区域
        log_frame = ttk.LabelFrame(self.master, text=self.lang["log"])
        log_frame.pack(pady=10, fill="both", expand=True)

        self.log_area = scrolledtext.ScrolledText(log_frame, wrap=tk.WORD)
        self.log_area.pack(fill="both", expand=True)

        # 菜单栏
        menubar = tk.Menu(self.master)
        self.master.config(menu=menubar)

        help_menu = tk.Menu(menubar, tearoff=0)
        help_menu.add_command(label="About/关于", command=self.show_about)
        help_menu.add_command(label="Check Update/检测更新", command=self.check_update)
        menubar.add_cascade(label="Help/帮助", menu=help_menu)

    def run_command(self, command, need_root=False):
        """执行系统命令"""
        try:
            if need_root and os.geteuid() != 0:
                self.log("需要sudo权限！")
                return None

            result = subprocess.run(command,
                                  shell=True,
                                  check=True,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  text=True)
            self.log(result.stdout)
            return result.stdout
        except subprocess.CalledProcessError as e:
            self.log(f"错误: {e.stderr}")
            return None

    def log(self, message):
        """记录日志"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.log_area.insert("end", f"[{timestamp}] {message}\n")
        self.log_area.see("end")

    def is_catos(self):
        """检测是否为CatOS系统"""
        try:
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if "ID=catos" in line:
                        return True
        except FileNotFoundError:
            pass
        return False

    def command_exists(self, command):
        """检测命令是否存在"""
        return shutil.which(command) is not None

    def clean_memory(self):
        """清理内存缓存"""
        self.run_command("sync && echo 3 > /proc/sys/vm/drop_caches", need_root=True)
        self.log("内存缓存已清理")

    def clean_vram(self):
        """清理NVIDIA显存"""
        output = self.run_command("nvidia-smi --query-compute-apps=pid,gpu_name,used_memory --format=csv")
        if "No running" not in output:
            self.run_command("nvidia-smi -i 0 -r")
            self.log("NVIDIA显存已重置")
        else:
            self.log("未发现显存残留")

    def show_process_manager(self):
        """进程管理窗口"""
        process_win = tk.Toplevel()
        process_win.title("进程管理")

        # 获取进程列表
        processes = subprocess.check_output(
            "ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu",
            shell=True).decode()

        # 显示进程列表
        text = scrolledtext.ScrolledText(process_win)
        text.insert("end", processes)
        text.pack(fill="both", expand=True)

        # 进程选择框
        pid_entry = ttk.Entry(process_win)
        pid_entry.pack(pady=5)

        # 结束进程按钮
        kill_btn = ttk.Button(process_win,
                            text="结束选中PID",
                            command=lambda: self.kill_process(pid_entry.get()))
        kill_btn.pack()

    def kill_process(self, pid):
        """结束指定进程"""
        if pid:
            self.run_command(f"kill -9 {pid}", need_root=True)
            self.log(f"已结束进程 {pid}")

    def set_performance_mode(self):
        """设置性能模式"""
        self.run_command("echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor", need_root=True)
        self.log("性能模式已启用")

    def clean_temp_files(self):
        """清理临时文件"""
        self.run_command("rm -rf /tmp/*", need_root=True)
        self.log("临时文件已清理")

    def disable_sleep(self):
        """禁用休眠"""
        self.run_command("systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target", need_root=True)
        self.log("休眠已禁用")

    def catos_optimization(self):
        """针对CatOS的优化"""
        self.log("[7/6] 针对CatOS的优化...")
        if self.is_catos():
            self.log("检测到CatOS系统，执行CatOS特定优化。")
            # 示例：清理AUR缓存
            if self.command_exists("yay"):
                self.log("清理AUR缓存...")
                self.run_command("yay -Sc --noconfirm", need_root=True)
                self.log("AUR缓存已清理。")
            else:
                self.log("未检测到yay，跳过AUR缓存清理。")

            # 示例：更新系统
            self.log("更新系统...")
            self.run_command("pacman -Syu --noconfirm", need_root=True)
            self.log("系统更新完成。")
        else:
            self.log("未检测到CatOS系统，跳过CatOS特定优化。")

    def check_update(self):
        """检查更新"""
        self.log("检查更新功能尚未实现")

    def show_about(self):
        """显示关于信息"""
        messagebox.showinfo("About", self.lang["about_content"])

if __name__ == "__main__":
    root = tk.Tk()
    app = CatOSOptimizerGUI(root)
    root.mainloop()
