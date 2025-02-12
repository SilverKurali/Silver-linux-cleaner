#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog
import subprocess
import os
import json
import threading
import re
import shutil
from datetime import datetime

# 配置文件路径
CONFIG_FILE = os.path.expanduser("~/.config/arch_cleaner.json")


class ArchCleanerPro:
    def __init__(self, root):
        """初始化应用"""
        self.root = root
        self.config = self.load_config()  # 加载配置
        self.setup_ui()  # 设置界面
        self.check_dependencies()  # 检查依赖

    def setup_ui(self):
        """设置主界面布局"""
        self.root.title("ArchCleaner Pro 2025")
        self.root.geometry("1000x700")

        # 设置主题样式
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TNotebook.Tab', font=('Helvetica', 10, 'bold'))

        # 选项卡容器
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill=tk.BOTH, expand=True)

        # 清理模块
        clean_frame = ttk.Frame(notebook)
        self.build_clean_section(clean_frame)
        notebook.add(clean_frame, text="智能清理")

        # 高级工具
        advanced_frame = ttk.Frame(notebook)
        self.build_advanced_section(advanced_frame)
        notebook.add(advanced_frame, text="高级工具")

        # 日志系统
        self.log_area = scrolledtext.ScrolledText(self.root, wrap=tk.WORD)
        self.log_area.pack(fill=tk.BOTH, expand=True)
        self.log_area.tag_config('error', foreground='red')
        self.log_area.tag_config('success', foreground='green')

        # 进度条
        self.progress = ttk.Progressbar(self.root, mode='determinate')
        self.progress.pack(fill=tk.X)

    def build_clean_section(self, parent):
        """构建智能清理模块布局"""
        cols = 3
        ttk.Button(parent, text="一键智能清理", command=lambda: self.smart_clean()).grid(row=0, column=0, padx=5)
        ttk.Button(parent, text="清理包缓存", command=lambda: self.clean_package_cache()).grid(row=0, column=1)
        ttk.Button(parent, text="删除旧内核", command=lambda: self.clean_old_kernels()).grid(row=0, column=2)
        ttk.Button(parent, text="清理用户缓存", command=lambda: self.clean_user_cache()).grid(row=1, column=0)
        ttk.Button(parent, text="查找大文件", command=lambda: self.find_large_files()).grid(row=1, column=1)
        ttk.Button(parent, text="清理日志", command=lambda: self.clean_logs()).grid(row=1, column=2)

    def build_advanced_section(self, parent):
        """构建高级工具模块"""
        ttk.Label(parent, text="自定义清理路径:").grid(row=0, column=0)
        self.custom_path = ttk.Entry(parent, width=40)
        self.custom_path.grid(row=0, column=1)
        ttk.Button(parent, text="浏览...", command=self.select_custom_path).grid(row=0, column=2)
        ttk.Button(parent, text="安全清理模式", command=self.safe_clean_mode).grid(row=1, column=0)
        ttk.Button(parent, text="清理Docker镜像", command=self.clean_docker).grid(row=1, column=1)

    def select_custom_path(self):
        """打开文件选择对话框，选择自定义路径"""
        path = filedialog.askdirectory()  # 打开文件夹选择对话框
        if path:  # 如果用户选择了路径
            self.custom_path.delete(0, tk.END)  # 清空输入框
            self.custom_path.insert(0, path)  # 将选择的路径插入输入框

    def safe_clean_mode(self):
        """安全清理模式"""
        messagebox.showinfo("安全清理模式", "安全清理模式已启动。\n此功能正在开发中，目前不执行任何操作。")

    def clean_docker(self):
        """清理Docker镜像"""
        cmds = [
            "docker system prune -f",  # 清理未使用的容器、网络、镜像等
            "docker image prune -a -f"  # 清理所有未使用的镜像
        ]
        self.run_cmds(cmds)
        self.log("Docker清理完成", 'success')

    # 核心功能实现 --------------------------------------------------
    def smart_clean(self):
        """智能清理流程"""
        tasks = [
            ('清理包缓存', self.clean_package_cache),
            ('清理用户缓存', self.clean_user_cache),
            ('删除旧内核', self.clean_old_kernels),
            ('清理系统日志', self.clean_logs)
        ]

        def execute_tasks():
            total = len(tasks)
            for idx, (name, task) in enumerate(tasks):
                self.update_progress((idx + 1) / total * 100)
                self.log(f"正在执行: {name}...", 'info')
                try:
                    task()
                except Exception as e:
                    self.log(f"错误: {str(e)}", 'error')
            self.log("智能清理完成!", 'success')

        threading.Thread(target=execute_tasks).start()

    def clean_package_cache(self):
        """优化后的包缓存清理"""
        keep = self.config.get('keep_versions', 2)
        cmds = [
            'pacman -Sc --noconfirm',
            f'paccache -rk{keep}'
        ]
        self.run_cmds(cmds)
        self.log("包缓存清理完成", 'success')

    def clean_old_kernels(self):
        """安全删除旧内核"""
        if not shutil.which('mhwd-kernel'):
            self.log("mhwd-kernel 未安装或不可用", 'error')
            self.show_warning("mhwd-kernel 未安装或不可用，请手动安装或使用其他工具管理内核。")
            return

        current = subprocess.check_output('uname -r', shell=True).decode().strip()
        try:
            kernels = subprocess.check_output('mhwd-kernel -l', shell=True).decode()
        except subprocess.CalledProcessError as e:
            self.log(f"执行失败: mhwd-kernel -l\n{e.output.decode()}", 'error')
            return

        to_remove = []
        for line in kernels.splitlines():
            if 'linux' in line and current not in line:
                match = re.search(r'linux\d+', line)
                if match:
                    to_remove.append(match.group())

        if to_remove:
            self.run_cmds([f'pacman -Rns {" ".join(to_remove)}'])

    def clean_user_cache(self):
        """清理用户级缓存"""
        dirs = [
            '~/.cache/*',
            '~/.thumbnails',
            '~/.local/share/Trash'
        ]
        expanded_dirs = [os.path.expanduser(d) for d in dirs]  # 展开路径
        cmds = [f'rm -rf {d}' for d in expanded_dirs]
        self.run_cmds(cmds)
        self.log("用户缓存清理完成", 'success')

    def find_large_files(self):
    """查找大文件"""
    # 示例：查找大于100MB的文件，排除某些系统目录，忽略错误信息
    cmd = r"find / -type f -size +100M ! -path '/proc/*' ! -path '/sys/*' ! -path '/run/*' ! -path '/usr/lib/*' -exec ls -lh {} \; 2>/dev/null"
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        self.log(result.stdout.decode(), 'info')
    except subprocess.CalledProcessError as e:
        self.log(f"执行失败: {cmd}\n{e.output.decode()}", 'error')
    self.log("大文件查找完成", 'success')

    # 辅助功能 -----------------------------------------------------
    def run_cmds(self, cmds):
        """执行命令列表"""
        if not shutil.which('pkexec'):
            self.log("pkexec 未安装或不可用", 'error')
            return

        for cmd in cmds:
            try:
                result = subprocess.run(
                    ['pkexec'] + cmd.split(),
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )
                self.log(result.stdout.decode(), 'info')
            except subprocess.CalledProcessError as e:
                self.log(f"执行失败: {cmd}\n{e.output.decode()}", 'error')

    def log(self, message, tag='info'):
        """增强日志系统"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.log_area.configure(state='normal')
        self.log_area.insert(tk.END, f"[{timestamp}] {message}\n", tag)
        self.log_area.configure(state='disabled')
        self.log_area.see(tk.END)

    def update_progress(self, value):
        """更新进度条"""
        self.progress['value'] = value
        self.root.update_idletasks()

    def show_warning(self, message):
        """显示警告消息"""
        messagebox.showwarning("警告", message)

    # 配置管理 -----------------------------------------------------
    def load_config(self):
        """加载用户配置"""
        default = {
            'keep_versions': 2,
            'max_log_size': 100,
            'exclude_dirs': ['/home', '/etc']
        }
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        try:
            with open(CONFIG_FILE) as f:
                return {**default, **json.load(f)}
        except:
            return default

    def save_config(self):
        """保存配置"""
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f)

    # 依赖检查 -----------------------------------------------------
    def check_dependencies(self):
        """检查必要依赖"""
        required = ['pacman-contrib', 'polkit', 'docker']
        missing = [pkg for pkg in required if not self.check_installed(pkg)]

        if missing:
            response = messagebox.askyesno(
                "依赖检查",
                f"缺少以下依赖：{', '.join(missing)}\n是否自动安装这些依赖？"
            )
            if response:
                for pkg in missing:
                    if not self.install_package(pkg):
                        messagebox.showerror("安装失败", f"安装 {pkg} 失败，请手动安装。")
                        return
                messagebox.showinfo("安装成功", "所有依赖已成功安装。")
            else:
                messagebox.showwarning("警告", "某些功能可能无法正常使用，因为缺少必要的依赖。")

    def check_installed(self, pkg):
        """检查软件包是否安装"""
        return subprocess.run(
            f"pacman -Qi {pkg}",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        ).returncode == 0

    def install_package(self, pkg):
        """安装软件包"""
        try:
            subprocess.run(
                f"sudo pacman -S --noconfirm {pkg}",
                shell=True,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False


if __name__ == "__main__":
    root = tk.Tk()
    app = ArchCleanerPro(root)
    root.mainloop()
