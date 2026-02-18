# 此项目为Windows快捷功能脚本。旨在简化部分日常操作

## 可以直接下载exe文件。也可以下载ps1脚本通过powershell执行

### 如需要打包为exe格式，参照以下方式执行

使用 PS2EXE（推荐，最稳定）

步骤 1：安装 PS2EXE 模块
以管理员身份打开 PowerShell，运行以下命令：

```shell
Install-Module -Name PS2EXE -Force
```

如果提示需要 NuGet 提供程序，输入 Y 确认安装。

步骤 2：打包脚本
将您的脚本保存为\*.ps1，然后在 PowerShell 中运行：

```shell
Invoke-PS2EXE -InputFile "C:\路径\*.ps1" -OutputFile "C:\路径\*.exe" -NoConsole -IconFile "C:\路径\*.ico"
```

***
**如需使用Windows系统自带图标，可以用图标导出工具**

- [Windows图标导出工具](https://link.zhihu.com/?target=https%3A//wwc.lanzouw.com/ikKpy0cq4q5e) 密码：i09q
