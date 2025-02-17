# Silver-Linux系统优化脚本

# 介绍
这个脚本是为CatOS系统量身定制的优化工具，具备自动检测NVIDIA显卡并清理显存的能力，同时对内存、显存进行清理优化，以提升整体性能。它简化了操作流程，易于上手，但需要root权限执行，且主要针对特定Linux发行版设计，可能需要调整以适应其他发行版系统环境。对于开发者而言，该脚本提供了一个优化系统性能的实用起点。

# 软件架构
该脚本采用模块化设计，主要分为以下几个部分：
- **依赖安装**：自动检测并安装必要的系统依赖。
- **内存管理**：智能管理交换空间和清理内核缓存。
- **GPU管理**：根据检测到的GPU类型（NVIDIA或AMD）进行显存重置。
- **系统优化**：执行针对CatOS的特定优化，包括文件系统和网络参数调整。

# 获取和使用教程
1. 克隆本仓库到本地：
   git clone https://gitee.com/AY77-OP/Silver-linux-cleaner.git
   git clone https://github.com/SilverKurali/Silver-linux-cleaner.git
   cd Silver-linux-cleaner
3. 赋予执行权限并运行脚本：
   chmod +x ./Catos_cleaner.sh
   sudo ./Catos_cleaner.sh
   注意:脚本名称可能会有变化
4. 关于catos_optimizer_gui.py文件
  - **环境安装**须要拥有python3环境
  - **依赖安装**
1. Debian/Ubuntu sudo apt install python3-tk
2. Arch/CatOS sudo pacman -Sy;sudo pacman -S tk

# 使用说明
1. 确保您以root用户身份运行脚本。
2. 脚本将自动执行内存和GPU优化。
3. 通过查看日志文件了解优化的详细过程和结果。
# 参与贡献
SilverKurali

# 该脚本的开源声明
禁止将该脚本修改后售卖，当然也不会有人买就是了。

# 关于
这个脚本是SilverKurali(Silver)闲着没事做出来的，可能会有一些BUG未处理，也许能顺利运行，也许可能没有任何效果。还请见谅！！！
可嘉企鹅交流群:731922824
