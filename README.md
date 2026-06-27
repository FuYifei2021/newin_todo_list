
# 如果系统是Windows 11，安装指南如下：

## 首先是人工准备阶段、部署一个AI Agent、这里选择OpenCode、人类读者可以换自己喜欢的
### precondition 1. 检查网络条件，安装过程需要访问github.com，部分地区没有条件的话，考虑从gitee.com或者gitcode.com寻找镜像项目。
### precondition 2. 安装git
#### 方式一: 通过winget安装
```powershell
winget install Git.Git --accept-package-agreements --accept-source-agreements
```
#### 方式二: 网页访问https://git-scm.com下载安装包,双击安装，过程中只用修改一个地方
```text
第三步 "Adjusting your PATH environment"
  ○ Use Git from Git Bash only        ← 默认，别选
  ○ Git from the command line and also from 3rd-party software  ← 选这个
  ○ Use Git and optional Unix tools from the Command Prompt     ← 别选（会覆盖 find/sort 等命令）
```
#### 其它安装方式自行查询
#### 安装完成之后，确认版本✅以及环境变量是否妥善设置
```powershell
git --version
where git
#预期
C:\Users\linzh>where git
  C:\Program Files\Git\cmd\git.exe
C:\Users\linzh>
#若提示无法找到，则手动添加
$gitPath = "C:\Program Files\Git\cmd"
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$gitPath*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$gitPath", "Machine")
    $env:Path += ";$gitPath"
    Write-Host "已添加到 PATH" -ForegroundColor Green
}
```
### precondition 3. 安装node、wsl
```powershell
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
wsl.exe --list --online
wsl.exe --install <Distro>
```
### precondition 4. 下载OpenCode: 从代码托管平台搜索OpenCode代码仓库，这里使用git@github.com:anomalyco/opencode.git
```powershell
#生成SSH key
C:\Users\linzh>ssh-keygen
#然后一路回车，完成后
C:\Users\linzh>type .ssh\id_ed*.pub
#拷贝终端显示出来的字符串，用于设置代码托管平台的用户SSH key

#新建目标文件夹
C:\users\linzh>makedir works
C:\users\linzh>cd works
#暂时浅克隆
C:\Users\linzh\works>git clone --depth=1 -b dev git@github.com:anomalyco/opencode.git opencode-dev
#后面要补全的话
# 第一步：取消"只跟踪 master"的限制，让 git 知道远程还有其他分支
git remote set-branches origin '*'

# 第二步：拉取完整历史 + 所有分支
git fetch --unshallow --all

C:\Users\linzh\works>cd opencode-dev\packages\opencode
#进入WSL,安装依赖包并构建
wsl

npm build
npm run build
#构建完成后，把dist目录下想要的目标exe文件拷贝到C:\windows\system32目录
#以后便可以在Terminal通过opencode命令打开，初次使用时会引导用户进行配置API
```

## 以下部分提供给AI Agents阅读并实施：

# Windows 11 AI Vibe Coding 环境配置手册

> **目标读者**: AI Agent（可直接按步骤顺序执行）
> **系统环境**: Windows 11 64bit | 64GB RAM | NVIDIA RTX 5060 Ti 16GB
> **核心目标**: 配置完整的 Python AI/ML 开发环境 + Vibe Coding 工具链

---

## 阶段 0：前置检查与系统准备

### 0.1 确认系统信息

```powershell
# 以管理员身份运行 PowerShell，执行以下命令收集系统信息
Write-Host "=== 系统信息 ===" -ForegroundColor Cyan
systeminfo | findstr /C:"OS" /C:"系统类型" /C:"物理内存量"
Write-Host "`n=== GPU 信息 ===" -ForegroundColor Cyan
nvidia-smi
Write-Host "`n=== 磁盘空间 ===" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Format-Table Name, @{N='Free(GB)';E={[math]::Round($_.Free/1GB,1)}}, @{N='Used(GB)';E={[math]::Round($_.Used/1GB,1)}} -AutoSize
```

**检查点**：
- `nvidia-smi` 能正常输出 GPU 信息（说明驱动已安装）
- 系统盘剩余空间 >= 80GB（CUDA + PyTorch + 模型缓存需要大量空间）
- 如果 `nvidia-smi` 报错，先跳到阶段 1 安装驱动

### 0.2 配置 PowerShell 执行策略

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Host "执行策略已设置" -ForegroundColor Green
```

### 0.3 设置环境变量（后续步骤依赖）

```powershell
# 定义全局路径变量，后续步骤统一引用
$ENV:AI_DEV_ROOT = "D:\AI_Dev"
$ENV:CONDA_DIR = "D:\AI_Dev\miniconda3"
$ENV:UV_DIR = "D:\AI_Dev\uv"

# 创建目录结构
$dirs = @(
    "$ENV:AI_DEV_ROOT",
    "$ENV:AI_DEV_ROOT\projects",
    "$ENV:AI_DEV_ROOT\models",
    "$ENV:AI_DEV_ROOT\cache",
    "$ENV:AI_DEV_ROOT\tools",
    "$ENV:AI_DEV_ROOT\scripts"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
Write-Host "目录结构创建完成: $ENV:AI_DEV_ROOT" -ForegroundColor Green
```

---

## 阶段 1：NVIDIA 驱动程序

### 1.1 检查当前驱动版本

```powershell
$nvidiaSmiOutput = nvidia-smi 2>&1
if ($LASTEXITCODE -eq 0) {
    $driverVersion = (nvidia-smi | Select-String "Driver Version").ToString().Trim()
    Write-Host "当前驱动: $driverVersion" -ForegroundColor Yellow
} else {
    Write-Host "未检测到 NVIDIA 驱动，需要安装" -ForegroundColor Red
}
```

### 1.2 安装/更新 NVIDIA 驱动

> **注意**: 此步骤可能需要手动下载。RTX 5060 Ti 需要 >= 570.xx 版本驱动。

```powershell
# 方法 A: 使用 winget 尝试安装（如果可用）
winget install NVIDIA.Driver --accept-package-agreements --accept-source-agreements

# 方法 B: 如果 winget 不可用或版本不够新，手动下载
# 访问 https://www.nvidia.cn/Download/index.aspx?lang=cn
# 选择: GeForce -> GeForce RTX 50 Series -> RTX 5060 Ti -> Windows 11 -> 生产分支
# 下载并运行安装程序，选择"精简安装"
```

### 1.3 验证驱动安装

```powershell
nvidia-smi
# 确认输出中：
# - Driver Version >= 570.xx
# - CUDA Version 显示为 12.8+（这是驱动支持的最大 CUDA 版本，非实际安装版本）
```

---

## 阶段 2：CUDA Toolkit 与 cuDNN

> **RTX 5060 Ti (Blackwell 架构) 要求**: CUDA >= 12.8
> **策略**: 安装 CUDA 12.8，cuDNN 9.x

### 2.1 安装 CUDA Toolkit 12.8

```powershell
# 下载 CUDA Toolkit 12.8 安装器
$cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_561.17_windows.exe"
$cudaInstaller = "$ENV:AI_DEV_ROOT\tools\cuda_12.8.0_installer.exe"

Write-Host "正在下载 CUDA Toolkit 12.8.0 ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cudaUrl -OutFile $cudaInstaller -UseBasicParsing
Write-Host "下载完成，大小: $([math]::Round((Get-Item $cudaInstaller).Length/1MB, 1)) MB" -ForegroundColor Green

# 静默安装（仅安装 CUDA Toolkit，不覆盖驱动）
Write-Host "正在安装 CUDA Toolkit 12.8.0（静默安装，预计 5-10 分钟）..." -ForegroundColor Cyan
Start-Process -FilePath $cudaInstaller -ArgumentList "-s", "toolkit" -Wait -NoNewWindow
Write-Host "CUDA Toolkit 安装完成" -ForegroundColor Green

# 清理安装包
Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
```

### 2.2 验证 CUDA 安装

```powershell
# 重新加载环境变量（安装程序修改了 PATH，需要刷新）
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

nvcc --version
# 期望输出: Cuda compilation tools, release 12.8, V12.8.xx
```

### 2.3 安装 cuDNN 9.x

> **注意**: cuDNN 需要 NVIDIA 开发者账号登录下载，此步骤需要手动操作或提供已下载的文件。

```powershell
# === 手动下载方式（推荐）===
# 1. 访问 https://developer.nvidia.com/cudnn
# 2. 登录 NVIDIA 开发者账号（免费注册）
# 3. 下载 cuDNN v9.9.0 for CUDA 12.x -> ZIP Archive (Windows)
# 4. 将下载的 zip 文件放到 D:\AI_Dev\tools\cudnn.zip
# 然后执行下面的安装脚本：

$cudnnZip = "$ENV:AI_DEV_ROOT\tools\cudnn.zip"

if (Test-Path $cudnnZip) {
    Write-Host "正在解压 cuDNN ..." -ForegroundColor Cyan
    $cudnnTemp = "$ENV:AI_DEV_ROOT\tools\cudnn_temp"
    Expand-Archive -Path $cudnnZip -DestinationPath $cudnnTemp -Force

    # 查找解压后的 bin/include/lib 目录
    $cudnnSubDir = Get-ChildItem -Path $cudnnTemp -Directory | Select-Object -First 1
    $cudaBase = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"

    # 复制文件到 CUDA 目录
    $srcBin = Join-Path $cudnnSubDir.FullName "bin"
    $srcInclude = Join-Path $cudnnSubDir.FullName "include"
    $srcLib = Join-Path $cudnnSubDir.FullName "lib"

    if (Test-Path $srcBin) {
        Copy-Item "$srcBin\*" "$cudaBase\bin\" -Force
        Write-Host "cuDNN bin 文件已复制" -ForegroundColor Green
    }
    if (Test-Path $srcInclude) {
        Copy-Item "$srcInclude\*" "$cudaBase\include\" -Force
        Write-Host "cuDNN include 文件已复制" -ForegroundColor Green
    }
    if (Test-Path $srcLib) {
        # cuDNN 9.x 的 lib 目录下可能有 x64 子目录
        $libX64 = Join-Path $srcLib "x64"
        if (Test-Path $libX64) {
            Copy-Item "$libX64\*" "$cudaBase\lib\x64\" -Force
        } else {
            Copy-Item "$srcLib\*" "$cudaBase\lib\x64\" -Force
        }
        Write-Host "cuDNN lib 文件已复制" -ForegroundColor Green
    }

    # 清理
    Remove-Item $cudnnTemp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "cuDNN 安装完成" -ForegroundColor Green
} else {
    Write-Host @"
[手动操作 needed] cuDNN 文件未找到: $cudnnZip
请执行以下操作：
1. 访问 https://developer.nvidia.com/cudnn
2. 登录并下载 cuDNN v9.x for CUDA 12.x (Windows ZIP)
3. 将文件保存到: $cudnnZip
4. 重新运行此脚本段
"@ -ForegroundColor Yellow
}
```

### 2.4 验证 cuDNN

```powershell
# 检查关键 DLL 是否存在
$cudaBin = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin"
$cudnnDlls = @("cudnn64_9.dll", "cudnn_ops_infer64_9.dll", "cudnn_cnn_infer64_9.dll")
foreach ($dll in $cudnnDlls) {
    $path = Join-Path $cudaBin $dll
    if (Test-Path $path) {
        Write-Host "[OK] $dll" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $dll" -ForegroundColor Red
    }
}
```

---

## 阶段 3：Python 环境管理

> **策略**: 使用 `uv` 作为主力包管理器（极快），`miniconda` 作为备选（某些包需要）
> **Python 版本**: 3.12.x（AI 生态兼容性最佳）

### 3.1 安装 uv

```powershell
Write-Host "正在安装 uv ..." -ForegroundColor Cyan
$uvInstallUrl = "https://astral.sh/uv/install.ps1"
Invoke-RestMethod $uvInstallUrl | Invoke-Expression

# 刷新环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

uv --version
Write-Host "uv 安装完成" -ForegroundColor Green
```

### 3.2 安装 Miniconda（备选环境管理）

```powershell
Write-Host "正在下载 Miniconda ..." -ForegroundColor Cyan
$condaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$condaInstaller = "$ENV:AI_DEV_ROOT\tools\miniconda_installer.exe"

Invoke-WebRequest -Uri $condaUrl -OutFile $condaInstaller -UseBasicParsing

# 静默安装到指定目录
Write-Host "正在安装 Miniconda（静默安装，预计 3-5 分钟）..." -ForegroundColor Cyan
$condaArgs = "/S", "/InstallationType=JustMe", "/AddToPath=1", "/RegisterPython=0", "/D=$ENV:CONDA_DIR"
Start-Process -FilePath $condaInstaller -ArgumentList $condaArgs -Wait -NoNewWindow

# 清理
Remove-Item $condaInstaller -Force -ErrorAction SilentlyContinue

# 初始化 conda for PowerShell
$condaExe = "$ENV:CONDA_DIR\Scripts\conda.exe"
& $condaExe init powershell

# 刷新环境
$env:Path = "$ENV:CONDA_DIR\Scripts;$ENV:CONDA_DIR\condabin;$ENV:CONDA_DIR\Library\bin;" + $env:Path

conda --version
Write-Host "Miniconda 安装完成" -ForegroundColor Green
```

### 3.3 创建主开发虚拟环境（使用 uv）

```powershell
$projectEnv = "$ENV:AI_DEV_ROOT\projects\main-env"

# 创建虚拟环境，指定 Python 3.12
uv venv $projectEnv --python 3.12

# 激活环境
& "$projectEnv\Scripts\Activate.ps1"

# 验证
python --version
pip --version
Write-Host "主虚拟环境创建完成: $projectEnv" -ForegroundColor Green
```

---

## 阶段 4：核心 Python 包安装

### 4.1 配置 pip 镜像源（加速下载）

```powershell
# 创建 pip 配置文件
$pipConfDir = "$env:APPDATA\pip"
New-Item -ItemType Directory -Path $pipConfDir -Force | Out-Null

$pipConf = @"
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
"@

Set-Content -Path "$pipConfDir\pip.ini" -Value $pipConf -Encoding UTF8
Write-Host "pip 镜像源已配置为清华源" -ForegroundColor Green
```

### 4.2 安装 PyTorch（CUDA 12.8 版本）

> **重要**: RTX 5060 Ti 需要 CUDA 12.8 支持的 PyTorch 版本。
> 如果 PyTorch 官方尚未发布 CUDA 12.8 版本，使用 12.6 版本并配合新驱动通常也能兼容。

```powershell
# 确保在虚拟环境中
# 先检查 PyTorch 官方最新的 CUDA 12 版本支持情况
# 方案 A: CUDA 12.8 官方支持（如果已发布）
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 方案 B: 如果上面报错 404，使用 CUDA 12.6（向后兼容）
# uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

Write-Host "PyTorch 安装完成" -ForegroundColor Green
```

### 4.3 安装 AI/ML 核心库

```powershell
uv pip install `
    numpy `
    scipy `
    pandas `
    matplotlib `
    seaborn `
    scikit-learn `
    jupyter `
    jupyterlab `
    ipywidgets `
    transformers `
    datasets `
    accelerate `
    sentencepiece `
    tokenizers `
    huggingface_hub `
    safetensors `
    bitsandbytes `
    peft `
    trl `
    xformers `
    flash-attn `
    vllm `
    openai `
    anthropic `
    google-generativeai `
    langchain `
    langchain-openai `
    langchain-community `
    chromadb `
    faiss-cpu `
    sentence-transformers `
    pillow `
    opencv-python `
    tqdm `
    rich `
    typer `
    httpx `
    aiohttp `
    python-dotenv `
    pyyaml `
    tomli `
    watchdog `
    pyperclip

Write-Host "AI/ML 核心库安装完成" -ForegroundColor Green
```

### 4.4 安装 Web/API 开发库（Vibe Coding 常用）

```powershell
uv pip install `
    fastapi `
    uvicorn `
    starlette `
    pydantic `
    requests `
    flask `
    gradio `
    streamlit `
    chainlit `
    playwright

# 安装 playwright 浏览器（用于 Web 自动化测试）
playwright install chromium

Write-Host "Web/API 开发库安装完成" -ForegroundColor Green
```

### 4.5 安装代码质量与工具库

```powershell
uv pip install `
    ruff `
    mypy `
    pytest `
    pytest-asyncio `
    black `
    isort `
    pre-commit `
    ipdb `
    py-spy `
    memray

Write-Host "工具库安装完成" -ForegroundColor Green
```

### 4.6 配置 Hugging Face 缓存目录

```powershell
# 将 HF 模型缓存指向大容量目录
[System.Environment]::SetEnvironmentVariable("HF_HOME", "$ENV:AI_DEV_ROOT\cache\huggingface", "User")
[System.Environment]::SetEnvironmentVariable("HUGGINGFACE_HUB_CACHE", "$ENV:AI_DEV_ROOT\cache\huggingface\hub", "User")
$env:HF_HOME = "$ENV:AI_DEV_ROOT\cache\huggingface"
$env:HUGGINGFACE_HUB_CACHE = "$ENV:AI_DEV_ROOT\cache\huggingface\hub"

New-Item -ItemType Directory -Path "$ENV:AI_DEV_ROOT\cache\huggingface\hub" -Force | Out-Null
Write-Host "Hugging Face 缓存目录已配置" -ForegroundColor Green
```

---

## 阶段 5：IDE 与编辑器配置

### 5.1 安装 VS Code

```powershell
winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements
Write-Host "VS Code 安装完成" -ForegroundColor Green
```

### 5.2 安装 Cursor（AI 代码编辑器 - Vibe Coding 核心）

```powershell
# Cursor 是基于 VS Code 的 AI 编辑器，Vibe Coding 的主力工具
winget install Cursor.Cursor --accept-package-agreements --accept-source-agreements

# 如果 winget 没有 Cursor，使用以下备用方式：
$cursorUrl = "https://downloader.cursor.sh/windows/nsis/x64"
$cursorInstaller = "$ENV:AI_DEV_ROOT\tools\cursor_setup.exe"
if (-not (Get-Command cursor -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri $cursorUrl -OutFile $cursorInstaller -UseBasicParsing
    Start-Process -FilePath $cursorInstaller -Wait
    Remove-Item $cursorInstaller -Force -ErrorAction SilentlyContinue
}
Write-Host "Cursor 安装完成" -ForegroundColor Green
```

### 5.3 安装 VS Code / Cursor 扩展

```powershell
# 定义扩展列表
$extensions = @(
    # Python 开发
    "ms-python.python",              # Python 官方扩展
    "ms-python.vscode-pylance",      # 类型检查
    "ms-python.debugpy",             # 调试器
    "ms-python.black-formatter",     # 代码格式化
    "charliermarsh.ruff",            # Ruff linting

    # AI 辅助
    "continue.continue",             # Continue - 开源 AI 编程助手
    "ms-python.ai-robot",            # GitHub Copilot (可选)

    # Jupyter
    "ms-toolsai.jupyter",            # Jupyter Notebook 支持

    # 通用工具
    "esbenp.prettier-vscode",        # 格式化
    "dbaeumer.vscode-eslint",        # JS linting
    "streetsidesoftware.code-spell-checker",  # 拼写检查
    "mkhl.direnv",                   # 环境变量管理
    "tamasfe.even-better-toml",      # TOML 支持
    "yzhang.markdown-all-in-one",    # Markdown 增强
    "humao.rest-client",             # REST API 测试
    "gruntfuggly.todo-tree",         # TODO 管理
    "usernamehw.errorlens",          # 错误高亮
)

$codeCmd = "code"
# 如果 Cursor 安装成功，也为其安装扩展
$cursorCmd = "cursor"

foreach ($ext in $extensions) {
    Write-Host "安装扩展: $ext" -ForegroundColor DarkGray
    & $codeCmd --install-extension $ext --force 2>$null
    & $cursorCmd --install-extension $ext --force 2>$null
}

Write-Host "IDE 扩展安装完成" -ForegroundColor Green
```

### 5.4 创建 VS Code / Cursor 工作区配置

```powershell
# 创建全局 settings.json（VS Code 和 Cursor 共享）
$vscodeDir = "$env:APPDATA\Code\User"
$cursorDir = "$env:APPDATA\Cursor\User"

$settings = @'
{
    "python.defaultInterpreterPath": "D:\\AI_Dev\\projects\\main-env\\Scripts\\python.exe",
    "python.terminal.activateEnvironment": true,
    "python.analysis.typeCheckingMode": "basic",
    "python.analysis.autoImportCompletions": true,
    "python.formatting.provider": "none",
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll": "explicit",
            "source.organizeImports": "explicit"
        },
        "editor.rulers": [88]
    },
    "ruff.lint.args": ["--config=pyproject.toml"],
    "ruff.format.args": ["--config=pyproject.toml"],
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "terminal.integrated.env.windows": {
        "HF_HOME": "D:\\AI_Dev\\cache\\huggingface",
        "PYTHONPATH": "${workspaceFolder}"
    },
    "editor.fontSize": 14,
    "editor.fontFamily": "'Cascadia Code', 'Fira Code', 'JetBrains Mono', Consolas, monospace",
    "editor.fontLigatures": true,
    "editor.minimap.enabled": false,
    "editor.lineNumbers": "on",
    "editor.renderWhitespace": "boundary",
    "editor.stickyScroll.enabled": true,
    "editor.bracketPairColorization.enabled": true,
    "workbench.colorTheme": "One Dark Pro",
    "workbench.productIconTheme": "fluent-icons",
    "continue.telemetryEnabled": false,
    "github.copilot.telemetry.enabled": false
}
'@

foreach ($dir in @($vscodeDir, $cursorDir)) {
    if (Test-Path $dir) {
        Set-Content -Path "$dir\settings.json" -Value $settings -Encoding UTF8
    }
}
Write-Host "IDE 配置完成" -ForegroundColor Green
```

---

## 阶段 6：本地 LLM 运行环境

### 6.1 安装 Ollama

```powershell
winget install Ollama.Ollama --accept-package-agreements --accept-source-agreements

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
```

### 6.2 配置 Ollama 模型存储路径

```powershell
# 将 Ollama 模型存储到 D 盘
[System.Environment]::SetEnvironmentVariable("OLLAMA_MODELS", "$ENV:AI_DEV_ROOT\models\ollama", "User")
$env:OLLAMA_MODELS = "$ENV:AI_DEV_ROOT\models\ollama"
New-Item -ItemType Directory -Path "$ENV:AI_DEV_ROOT\models\ollama" -Force | Out-Null
Write-Host "Ollama 模型目录已配置" -ForegroundColor Green
```

### 6.3 拉取推荐模型

> **注意**: 以下模型选择基于 16GB 显存的优化配置。
> Qwen3 系列和 DeepSeek 系列对 Vibe Coding 效果极好。

```powershell
# 启动 Ollama 服务（如果未运行）
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 5

# === Vibe Coding 专用模型（推荐按需拉取，每个几个GB）===

# 模型 1: Qwen3 8B - 中文 Vibe Coding 首选，16G 显存轻松运行
Write-Host "拉取 qwen3:8b ..." -ForegroundColor Cyan
ollama pull qwen3:8b

# 模型 2: DeepSeek-Coder-V2-Lite - 代码生成能力强
Write-Host "拉取 deepseek-coder-v2:16b ..." -ForegroundColor Cyan
ollama pull deepseek-coder-v2:16b

# 模型 3: Qwen2.5-Coder 7B - 轻量代码模型
Write-Host "拉取 qwen2.5-coder:7b ..." -ForegroundColor Cyan
ollama pull qwen2.5-coder:7b

# 模型 4: Llama 4 Scout (如果可用，16B 参数)
# ollama pull llama4-scout:16b

Write-Host "本地 LLM 模型拉取完成" -ForegroundColor Green
```

### 6.4 配置 Continue 插件使用本地模型

```powershell
# Continue 配置文件
$continueDir = "$env:APPDATA\Continue\config"
New-Item -ItemType Directory -Path $continueDir -Force | Out-Null

$continueConfig = @'
{
  "models": [
    {
      "title": "Qwen3 8B (Local)",
      "provider": "ollama",
      "model": "qwen3:8b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "DeepSeek Coder V2 (Local)",
      "provider": "ollama",
      "model": "deepseek-coder-v2:16b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Qwen2.5 Coder 7B (Local)",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen2.5 Coder 7B",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b",
    "apiBase": "http://localhost:11434"
  },
  "allowAnonymousTelemetry": false,
  "contextProviders": [
    {
      "name": "code",
      "params": {}
    },
    {
      "name": "docs",
      "params": {}
    },
    {
      "name": "folder",
      "params": {}
    },
    {
      "name": "codebase",
      "params": {}
    }
  ],
  "slashCommands": [
    {
      "name": "edit",
      "description": "Edit selected code"
    },
    {
      "name": "comment",
      "description": "Write comments for the selected code"
    },
    {
      "name": "share",
      "description": "Share the current conversation"
    }
  ]
}
'@

Set-Content -Path "$continueDir\config.json" -Value $continueConfig -Encoding UTF8
Write-Host "Continue 插件配置完成" -ForegroundColor Green
```

---

## 阶段 7：CLI AI 工具

### 7.1 安装 OpenCode

```powershell
# 需要 Node.js 环境
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 安装 Open Code
npm install -g @anthropic-ai/Open-code

Write-Host "Open Code 安装完成" -ForegroundColor Green
# 使用方式: 在项目目录运行 Open
# 需要 ANTHROPIC_API_KEY 环境变量
```

### 7.2 安装 Gemini CLI（Google 官方）

```powershell
npm install -g @anthropic-ai/Open-code 2>$null
npm install -g @google/gemini-cli 2>$null

Write-Host "Gemini CLI 安装完成" -ForegroundColor Green
# 使用方式: 在项目目录运行 gemini
```

### 7.3 安装 aider（AI 结对编程 CLI）

```powershell
uv pip install aider-chat

Write-Host "aider 安装完成" -ForegroundColor Green
# aider 可以连接本地 Ollama 模型
# 使用方式: aider --model ollama/qwen3:8b
```

---

## 阶段 8：Git 配置

### 8.1 安装 Git

```powershell
# check if git already exist.
git --version

# if not exist, then install it.
winget install Git.Git --accept-package-agreements --accept-source-agreements

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
```

### 8.2 配置 Git

```powershell
git config --global init.defaultBranch main
git config --global core.autocrlf true
git config --global core.safecrlf warn
git config --global pull.rebase false
git config --global diff.algorithm histogram
git config --global user.name "AI Developer"
git config --global user.email "ai-dev@local.dev"

# 配置 Git 凭据管理器
git config --global credential.helper manager-core

Write-Host "Git 配置完成" -ForegroundColor Green
```

### 8.3 配置 Git 全局 .gitignore

```powershell
$gitignore = @'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
*.egg-info/
dist/
build/
.eggs/
*.egg

# Virtual environments
.venv/
venv/
ENV/

# AI/ML
*.pt
*.pth
*.bin
*.safetensors
*.onnx
wandb/
runs/
outputs/
checkpoints/
*.ckpt

# Jupyter
.ipynb_checkpoints/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
desktop.ini

# Environment
.env
.env.local
.env.*.local
*.local

# Cache
.cache/
*.cache

# Models (large files)
*.gguf
*.ggml
models/
'@

$gitignorePath = "$env:USERPROFILE\.gitignore"
Set-Content -Path $gitignorePath -Value $gitignore -Encoding UTF8
git config --global core.excludesFile $gitignorePath
Write-Host "全局 .gitignore 配置完成" -ForegroundColor Green
```

---

## 阶段 9：项目模板初始化

### 9.1 创建标准项目结构

```powershell
$demoProject = "$ENV:AI_DEV_ROOT\projects\demo-vibe-project"
New-Item -ItemType Directory -Path $demoProject -Force | Out-Null

$projectDirs = @(
    "$demoProject\src",
    "$demoProject\src\core",
    "$demoProject\src\api",
    "$demoProject\src\utils",
    "$demoProject\tests",
    "$demoProject\notebooks",
    "$demoProject\scripts",
    "$demoProject\data",
    "$demoProject\output"
)
foreach ($d in $projectDirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
```

### 9.2 创建 pyproject.toml

```powershell
$pyproject = @'
[project]
name = "demo-vibe-project"
version = "0.1.0"
description = "AI Vibe Coding Demo Project"
requires-python = ">=3.12"
dependencies = [
    "torch>=2.0",
    "transformers>=4.40",
    "fastapi>=0.110",
    "uvicorn>=0.29",
    "rich>=13.0",
    "typer>=0.12",
    "python-dotenv>=1.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "ruff>=0.4",
    "mypy>=1.10",
    "pre-commit>=3.7",
]
notebook = [
    "jupyterlab>=4.0",
    "ipywidgets>=8.0",
]

[tool.ruff]
target-version = "py312"
line-length = 88
src = ["src"]

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B", "A", "SIM", "RUF"]
ignore = ["E501"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "ruff>=0.4",
]
'@

Set-Content -Path "$demoProject\pyproject.toml" -Value $pyproject -Encoding UTF8
```

### 9.3 创建 .env 模板

```powershell
$envTemplate = @'
# === API Keys（按需填写）===
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=

# === 本地模型 ===
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=qwen3:8b

# === Hugging Face ===
HF_HOME=D:\AI_Dev\cache\huggingface
HF_TOKEN=

# === 项目配置 ===
PROJECT_NAME=demo-vibe-project
DEBUG=true
LOG_LEVEL=DEBUG
'@

Set-Content -Path "$demoProject\.env.example" -Value $envTemplate -Encoding UTF8
Copy-Item "$demoProject\.env.example" "$demoProject\.env"
Write-Host "项目模板创建完成: $demoProject" -ForegroundColor Green
```

---

## 阶段 10：全局验证脚本

### 10.1 创建并运行完整验证

```powershell
$verifyScript = @'
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   AI Vibe Coding 环境验证报告" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$errors = 0
$warnings = 0

function Check-Command {
    param([string]$Name, [string]$Command, [string]$ExpectedPattern)
    try {
        $output = & (Get-Command $Command -ErrorAction Stop) 2>&1
        if ($ExpectedPattern -and ($output -notmatch $ExpectedPattern)) {
            Write-Host "  [WARN] $Name - 版本可能不符合预期" -ForegroundColor Yellow
            Write-Host "         输出: $output" -ForegroundColor DarkGray
            $script:warnings++
        } else {
            $version = if ($output -match '(\d+\.\d+[\.\d]*)') { $Matches[1] } else { "OK" }
            Write-Host "  [OK]   $Name - v$version" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [FAIL] $Name - 未找到" -ForegroundColor Red
        $script:errors++
    }
}

function Check-File {
    param([string]$Name, [string]$Path)
    if (Test-Path $Path) {
        $size = [math]::Round((Get-Item $Path).Length/1MB, 1)
        Write-Host "  [OK]   $Name - ${size}MB" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Name - $Path 不存在" -ForegroundColor Red
        $script:errors++
    }
}

function Check-Dir {
    param([string]$Name, [string]$Path)
    if (Test-Path $Path) {
        Write-Host "  [OK]   $Name - $Path" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Name - $Path 不存在" -ForegroundColor Red
        $script:errors++
    }
}

# --- 系统基础 ---
Write-Host "--- 系统基础 ---" -ForegroundColor White
Check-Command "NVIDIA 驱动" "nvidia-smi" "Driver Version"
Check-Command "Git" "git" "git version"
Check-Command "Node.js" "node" "v\d+"
Check-Command "npm" "npm" "\d+\.\d+"

# --- CUDA 工具链 ---
Write-Host "`n--- CUDA 工具链 ---" -ForegroundColor White
Check-Command "NVCC (CUDA Compiler)" "nvcc" "12\.8"
$cudaBin = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin"
Check-File "cuDNN DLL" "$cudaBin\cudnn64_9.dll"

# --- Python 环境 ---
Write-Host "`n--- Python 环境 ---" -ForegroundColor White
Check-Command "Python" "python" "3\.12"
Check-Command "uv" "uv" "\d+\.\d+"
Check-Command "pip" "pip" "\d+\.\d+"
Check-Command "conda" "conda" "\d+\.\d+"

# --- AI/ML 核心 ---
Write-Host "`n--- AI/ML 核心库 ---" -ForegroundColor White
Check-Command "PyTorch" "python" ""  # 特殊处理
try {
    $torchOutput = python -c "import torch; print(f'{torch.__version__}|{torch.cuda.is_available()}|{torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
    $parts = $torchOutput -split '\|'
    $torchVer = $parts[0]
    $cudaAvail = $parts[1]
    $gpuName = $parts[2]
    if ($cudaAvail -eq "True") {
        Write-Host "  [OK]   PyTorch $torchVer - CUDA 可用 - $gpuName" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] PyTorch $torchVer - CUDA 不可用！" -ForegroundColor Yellow
        $script:warnings++
    }
} catch {
    Write-Host "  [FAIL] PyTorch - 导入失败: $_" -ForegroundColor Red
    $script:errors++
}

Check-Command "Transformers" "python" ""
try {
    $hfVer = python -c "import transformers; print(transformers.__version__)"
    Write-Host "  [OK]   Transformers $hfVer" -ForegroundColor Green
} catch { Write-Host "  [FAIL] Transformers" -ForegroundColor Red; $script:errors++ }

Check-Command "vLLM" "python" ""
try {
    python -c "import vllm; print('OK')" 2>$null
    Write-Host "  [OK]   vLLM" -ForegroundColor Green
} catch { Write-Host "  [WARN] vLLM - 导入失败（Windows 上可能需要 WSL）" -ForegroundColor Yellow; $script:warnings++ }

# --- 本地 LLM ---
Write-Host "`n--- 本地 LLM ---" -ForegroundColor White
Check-Command "Ollama" "ollama" "ollama version"
try {
    $models = ollama list 2>&1
    $modelCount = ($models | Select-String "qwen|deepseek|coder").Count
    if ($modelCount -gt 0) {
        Write-Host "  [OK]   已拉取 $modelCount 个 AI 模型" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] 未检测到 AI 模型" -ForegroundColor Yellow
        $script:warnings++
    }
} catch { Write-Host "  [WARN] Ollama 服务可能未运行" -ForegroundColor Yellow; $script:warnings++ }

# --- IDE & 工具 ---
Write-Host "`n--- IDE & 工具 ---" -ForegroundColor White
Check-Command "VS Code" "code" ""
Check-Command "Cursor" "cursor" ""
Check-Command "Open Code" "Open" ""
try { npm list -g @anthropic-ai/Open-code 2>$null | Out-Null; Write-Host "  [OK]   Open Code CLI" -ForegroundColor Green }
catch { Write-Host "  [WARN] Open Code CLI" -ForegroundColor Yellow; $script:warnings++ }

Check-Command "aider" "aider" ""

# --- 目录结构 ---
Write-Host "`n--- 目录结构 ---" -ForegroundColor White
Check-Dir "AI 开发根目录" "D:\AI_Dev"
Check-Dir "项目目录" "D:\AI_Dev\projects"
Check-Dir "模型缓存" "D:\AI_Dev\cache\huggingface"
Check-Dir "Ollama 模型" "D:\AI_Dev\models\ollama"
Check-Dir "主虚拟环境" "D:\AI_Dev\projects\main-env"

# --- 总结 ---
Write-Host "`n========================================" -ForegroundColor Cyan
if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "   全部通过! 环境配置完美! " -ForegroundColor Green
} elseif ($errors -eq 0) {
    Write-Host "   基本就绪 ($warnings 个警告)" -ForegroundColor Yellow
} else {
    Write-Host "   存在问题 ($errors 个错误, $warnings 个警告)" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan
'@

$verifyPath = "$ENV:AI_DEV_ROOT\scripts\verify_env.ps1"
Set-Content -Path $verifyPath -Value $verifyScript -Encoding UTF8

# 运行验证
Write-Host "运行环境验证脚本..." -ForegroundColor Cyan
& $verifyPath
```

---

## 阶段 11：便捷启动脚本

### 11.1 创建一键激活脚本

```powershell
$activateScript = @'
# AI Dev 环境一键激活
# 使用方式: 在任意 PowerShell 中运行 . D:\AI_Dev\scripts\activate.ps1

Write-Host "`n  Activating AI Dev Environment..." -ForegroundColor Cyan

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 设置环境变量
$ENV:AI_DEV_ROOT = "D:\AI_Dev"
$ENV:HF_HOME = "D:\AI_Dev\cache\huggingface"
$ENV:OLLAMA_MODELS = "D:\AI_Dev\models\ollama"
$ENV:PYTHONPATH = "$ENV:AI_DEV_ROOT\projects"

# 激活主虚拟环境
if (Test-Path "D:\AI_Dev\projects\main-env\Scripts\Activate.ps1") {
    & "D:\AI_Dev\projects\main-env\Scripts\Activate.ps1"
}

# 设置 prompt
function prompt {
    $p = & { $env:CONDA_PROMPT_MODIFIER } + "AI> "
    "$p$(Get-Location)> "
}

# 快捷命令
function ai-new { param([string]$Name) uv venv "D:\AI_Dev\projects\$Name" --python 3.12 }
function ai-list { Get-ChildItem D:\AI_Dev\projects -Directory | Select-Object Name }
function ai-gpu { nvidia-smi }
function ai-models { ollama list }
function ai-verify { & "D:\AI_Dev\scripts\verify_env.ps1" }
function ai-note { jupyter lab --notebook-dir="D:\AI_Dev\projects" }
function ai-serve { param([string]$Model = "qwen3:8b") ollama run $Model }

Write-Host "  Environment ready!" -ForegroundColor Green
Write-Host "  Shortcuts: ai-gpu | ai-models | ai-list | ai-verify | ai-note | ai-serve`n" -ForegroundColor DarkGray
'@

Set-Content -Path "$ENV:AI_DEV_ROOT\scripts\activate.ps1" -Value $activateScript -Encoding UTF8
Write-Host "激活脚本创建完成: $ENV:AI_DEV_ROOT\scripts\activate.ps1" -ForegroundColor Green
```

### 11.2 创建 PowerShell Profile 自动加载（可选）

```powershell
$profileContent = @'

# === AI Dev Environment Auto-Load ===
if (Test-Path "D:\AI_Dev\scripts\activate.ps1") {
    # 取消下面的注释可以每次打开终端自动激活
    # . D:\AI_Dev\scripts\activate.ps1
}

# 常用别名（即使不激活环境也可用）
Set-Alias -Name ai-activate -Value "D:\AI_Dev\scripts\activate.ps1" -ErrorAction SilentlyContinue
'@

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
Add-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
Write-Host "PowerShell Profile 已配置" -ForegroundColor Green
```

---

## 附录 A：故障排查指南

```markdown
### A.1 nvidia-smi 报错 "无法识别的命令"
- 驱动未安装或损坏，重新运行阶段 1

### A.2 nvcc --version 报错
- CUDA Toolkit 未正确安装，检查 `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin` 是否在 PATH 中
- 重新运行阶段 2.1

### A.3 PyTorch 报 CUDA error / CUDA not available
- 确认 PyTorch 版本与 CUDA 版本匹配
- 运行: `python -c "import torch; print(torch.version.cuda)"`
- 如果显示 None，说明安装了 CPU 版本，重新执行阶段 4.2

### A.4 Ollama 拉取模型超时
- 配置代理: 设置 HTTP_PROXY / HTTPS_PROXY 环境变量
- 或手动下载模型: https://ollama.com/library

### A.5 vLLM 在 Windows 上无法运行
- vLLM 官方不支持 Windows 原生
- 替代方案: 使用 WSL2 安装 vLLM，或使用 Ollama 作为推理后端
- WSL2 安装命令: `wsl --install`

### A.6 flash-attn 安装失败
- Windows 上 flash-attn 需要预编译 wheel
- 替代方案: `pip install flash-attn --no-build-isolation` 或从 https://github.com/Dao-AILab/flash-attention/releases 下载 wheel

### A.7 RTX 5060 Ti 特定问题
- 确保驱动版本 >= 570.xx
- 如果 PyTorch CUDA 12.8 不可用，使用 12.6 版本（新驱动向后兼容）
- Blackwell 架构的 compute capability 为 sm_120，部分旧版本软件可能不识别
```

---

## 附录 B：环境总览

| 组件 | 版本/路径 | 用途 |
|------|-----------|------|
| NVIDIA 驱动 | >= 570.xx | GPU 基础驱动 |
| CUDA Toolkit | 12.8 | GPU 编译工具链 |
| cuDNN | 9.x | 深度学习加速库 |
| Python | 3.12.x | 主力开发语言 |
| uv | latest | 极速包管理器 |
| Miniconda | latest | 备选环境管理 |
| PyTorch | 2.x (CUDA 12.x) | 深度学习框架 |
| Transformers | 4.x | Hugging Face 模型库 |
| Ollama | latest | 本地 LLM 运行时 |
| Cursor | latest | AI 代码编辑器 (主力) |
| VS Code | latest | 通用代码编辑器 |
| Continue | latest | 开源 AI 编程助手插件 |
| Open Code | latest | Anthropic CLI 编程工具 |
| aider | latest | AI 结对编程 CLI |

---

## 附录 C：日常使用快速参考

```markdown
### 启动开发环境
  . D:\AI_Dev\scripts\activate.ps1

### 新建项目
  cd D:\AI_Dev\projects
  uv venv my-project --python 3.12
  cd my-project
  .\Scripts\Activate.ps1

### 在 Cursor 中开始 Vibe Coding
  1. 打开 Cursor
  2. File -> Open Folder -> 选择项目目录
  3. Ctrl+Shift+P -> "Continue: New Session"
  4. 选择本地模型 (Qwen3 8B) 开始对话

### 使用 Open Code
  cd D:\AI_Dev\projects\my-project
  Open

### 使用 aider + 本地模型
  cd D:\AI_Dev\projects\my-project
  aider --model ollama/qwen3:8b

### 运行 Jupyter Lab
  ai-note

### 查看 GPU 状态
  ai-gpu

### 查看已安装的本地模型
  ai-models
```

---

*文档版本: 1.0 | 生成时间: 2025-07-11 | 适用 GPU: NVIDIA RTX 5060 Ti 16GB*
```

---

这份文档的设计思路说明：

**为什么这样组织**：整个文件按照依赖关系从底层到上层排列——驱动 → CUDA → Python → 包 → IDE → LLM → 验证。AI Agent 可以严格按顺序执行，每一步的输入都依赖前一步的输出。

**关于 RTX 5060 Ti 的特殊处理**：
- 驱动版本要求 `>= 570.xx`（Blackwell 架构最低驱动）
- CUDA 版本推荐 `12.8`（50 系列首发支持版本）
- PyTorch 安装提供了 fallback 方案（如果 cu128 的 wheel 还没发布，回退到 cu126，新驱动向后兼容）
- `vLLM` 标注了 Windows 不兼容的警告，避免 Agent 在这上面浪费时间去排查必然失败的安装

**Vibe Coding 工具链覆盖**：Cursor（主力编辑器）+ Continue（开源 AI 插件，已预配本地模型）+ Ollama（本地 LLM）+ Open Code + aider，形成从 GUI 到 CLI 的完整 AI 辅助编程矩阵。模型选择上，Qwen3 8B 和 DeepSeek-Coder-V2 在 16GB 显存上可以流畅运行，中文编程场景效果很好。

**实际执行时的注意点**：阶段 2.3（cuDNN）需要手动下载，文档中已经明确标注了 `[手动操作 needed]`，Agent 执行到这里应该暂停并报告。阶段 6.3 的模型拉取每个几个 GB，Agent 应该告知用户预计时间和磁盘空间。
