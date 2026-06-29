
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

> **实际部署记录 (2026-06-27)**: 以下列出本指南执行过程中的关键偏差与经验，供后续执行者参考：
>
> **系统预装情况**：NVIDIA 驱动 610.62 / CUDA 13.3 (nvcc) / cuDNN v9.23 已预装，均高于指南最低要求，无需重复安装。
>
> **大文件下载超时**：PyTorch wheel (2.6GB) 和 Ollama 安装包 (1.32GB) 通过 `winget` / `uv` 下载均会因超时失败。解决方案：
> - PyTorch: 使用 `uv pip install` 配合 `--timeout 5400000` (90分钟超时)，或指定精确版本 `torch==2.11.0+cu128` 减少解析时间
> - 通用方案: 提示用户手动下载到 `D:\AI_Dev\tools\` 目录后通知 Agent 继续
>
> **cuDNN**: 新版 NVIDIA 提供的是 exe 安装包 (非 ZIP)，默认安装到 `C:\Program Files\NVIDIA\CUDNN\v9.23`。需将对应 CUDA 版本的 bin 目录（如 `C:\Program Files\NVIDIA\CUDNN\v9.23\bin\13.3\x64`）加入 PATH。
>
> **包冲突**：`aider-chat` 安装时会降级 `huggingface-hub` 到 1.4.1，导致 `transformers` 无法导入。需在安装 aider 后重新升级 `uv pip install "huggingface-hub>=1.21.0"`。
>
> **PowerShell 编码**：含中文的脚本块需注意编码问题。推荐验证脚本使用英文输出或确保 `-Encoding UTF8` 参数正确。
>
> **bitsandbytes / flash-attn / vLLM**: Windows 原生不支持，跳过安装。
>
> **OpenCode**: 此文档本身就是由 OpenCode 处理，无需额外安装 npm 包。
>
> **别名 'ai'**: 在 PowerShell Profile 中添加了 `Set-Alias -Name ai -Value "D:\AI_Dev\scripts\activate.ps1"`，后续可直接输入 `ai` 激活环境。

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

## 阶段 2：安装VS、CUDA Toolkit 与 cuDNN

> **RTX 5060 Ti (Blackwell 架构) 要求**: CUDA >= 12.8
> **注意**: 实际系统可能已预装更新的 CUDA 版本（如 13.3），Agent 应先通过 `nvcc --version` 和 `nvidia-smi` 检查，若已安装则跳过。

### 2.1 检查 CUDA 状态

```powershell
# 检查 CUDA Toolkit 是否已安装
$nvccCheck = Get-Command nvcc -ErrorAction SilentlyContinue
if ($nvccCheck) {
    $cudaVer = nvcc --version | Select-String "release"
    Write-Host "CUDA 已安装: $cudaVer" -ForegroundColor Green
} else {
    Write-Host "CUDA 未安装，开始下载安装..." -ForegroundColor Yellow
    # 下载 CUDA Toolkit 12.8 安装器
    $cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_561.17_windows.exe"
    $cudaInstaller = "$ENV:AI_DEV_ROOT\tools\cuda_12.8.0_installer.exe"
    Invoke-WebRequest -Uri $cudaUrl -OutFile $cudaInstaller -UseBasicParsing
    Start-Process -FilePath $cudaInstaller -ArgumentList "-s", "toolkit" -Wait -NoNewWindow
    Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
}
```

### 2.2 安装 cuDNN 9.x

> **重要变更**: cuDNN 新版使用 exe 安装包（非 ZIP），默认安装到 `C:\Program Files\NVIDIA\CUDNN\v9.23`。
> 下载需要 NVIDIA 开发者账号（免费注册）。

```powershell
# === 检查 cuDNN 是否已安装 ===
$cudnnDir = "C:\Program Files\NVIDIA\CUDNN"
if (Test-Path $cudnnDir) {
    Write-Host "cuDNN 已安装: $(Get-ChildItem $cudnnDir -Directory | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host @"
[手动操作 needed] cuDNN 未安装，请执行以下操作：
1. 访问 https://developer.nvidia.com/cudnn 下载安装包 exe
2. 运行安装程序，使用默认路径
3. 确认安装目录为: C:\Program Files\NVIDIA\CUDNN\v9.23
"@ -ForegroundColor Yellow
}

# === 查找 cuDNN 并加入 PATH ===
$cudaVer = (nvidia-smi | Select-String "CUDA Version").ToString()
$cudaMajorMinor = if ($cudaVer -match '(\d+\.\d+)') { $Matches[1] } else { "13.3" }
$cudnnBin = "C:\Program Files\NVIDIA\CUDNN\v9.23\bin\$cudaMajorMinor\x64"

if (Test-Path $cudnnBin) {
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$cudnnBin*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$cudnnBin", "User")
        $env:Path += ";$cudnnBin"
        Write-Host "cuDNN 路径已添加到 PATH: $cudnnBin" -ForegroundColor Green
    }
} else {
    Write-Host "[WARN] cuDNN 路径不存在: $cudnnBin，请确认 cuDNN 版本与 CUDA 版本匹配" -ForegroundColor Yellow
}
```

### 2.3 验证 cuDNN

```powershell
# 通过 Python + PyTorch 验证 cuDNN（需要先安装 PyTorch，见阶段 4）
python -c "import torch; print('cuDNN:', torch.backends.cudnn.is_available()); print('cuDNN ver:', torch.backends.cudnn.version() if torch.backends.cudnn.is_available() else 'N/A')"
# 期望输出: cuDNN: True, cuDNN ver: 9xxxx
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
> **下载注意事项**: PyTorch wheel (2.6GB) 下载可能超时，需设置 60-90 分钟超时，或指定精确版本减少解析时间。

```powershell
# 确保在虚拟环境中
# 先检查 PyTorch 官方最新的 CUDA 12 版本支持情况

# 方案 A: CUDA 12.8（推荐，指定精确版本减少超时风险）
uv pip install torch==2.11.0 torchvision==0.26.0 torchaudio==2.11.0 --index-url https://download.pytorch.org/whl/cu128

# 方案 B: 如果 cu128 不可用，使用 CUDA 12.6（向后兼容）
# uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# 验证 CUDA 是否可用
python -c "import torch; print(f'PyTorch {torch.__version__} | CUDA: {torch.cuda.is_available()} | GPU: {torch.cuda.get_device_name(0)}')"

# **若下载超时**: 告知用户手动下载到 D:\AI_Dev\tools\ 目录后通知 Agent
# cp312 + cu128 的 wheel 地址:
# https://download-r2.pytorch.org/whl/cu128/torch-2.11.0%2Bcu128-cp312-cp312-win_amd64.whl
```

### 4.3 安装 AI/ML 核心库

> **批量安装说明**: 为避免单次超时，建议分批安装。每批设置 10-20 分钟超时。

```powershell
# 第1批: 科学计算与可视化
uv pip install numpy scipy pandas matplotlib seaborn scikit-learn jupyter jupyterlab ipywidgets

# 第2批: HuggingFace 生态
uv pip install transformers datasets accelerate sentencepiece tokenizers huggingface_hub safetensors

# 第3批: PEFT/LLM 库（bitsandbytes/flash-attn/vllm 在 Windows 上不兼容，跳过）
uv pip install peft trl xformers openai anthropic google-generativeai langchain langchain-openai langchain-community

# 第4批: 向量数据库与工具
uv pip install chromadb faiss-cpu sentence-transformers pillow opencv-python aiohttp python-dotenv pyyaml tomli watchdog pyperclip

# 第5批: Web/API 框架
uv pip install fastapi uvicorn starlette pydantic requests flask gradio streamlit chainlit

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
uv pip install ruff mypy pytest pytest-asyncio black isort pre-commit ipdb py-spy

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

> **注意**: Winget 可能找不到 Cursor，且官网下载可能超时。推荐用户手动从 https://cursor.com 下载安装。

```powershell
# 检查 Cursor 是否已安装
if (Get-Command cursor -ErrorAction SilentlyContinue) {
    Write-Host "Cursor 已安装: $(cursor --version)" -ForegroundColor Green
} else {
    Write-Host "[手动操作] 请从 https://cursor.com/downloads 下载安装 Cursor" -ForegroundColor Yellow
}

# 安装后将 Cursor 加入 PATH
$cursorBin = "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin"
if (Test-Path $cursorBin) {
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$cursorBin*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$cursorBin", "User")
    }
}
```

### 5.3 安装 VS Code / Cursor 扩展

> **注意**: VS Code 安装后需刷新 PATH 才能使用 `code` 命令。扩展安装可能较慢，建议先安装关键扩展（Continue + Python）。

```powershell
# 确保 code 命令可用
$codeBin = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
if (Test-Path $codeBin -and ($env:Path -notlike "*$codeBin*")) {
    $env:Path = "$codeBin;$env:Path"
}

# 关键扩展（先安装）
$criticalExts = @(
    "continue.continue",   # 开源 AI 编程助手（Vibe Coding 核心）
    "ms-python.python"     # Python 官方支持
)
foreach ($ext in $criticalExts) {
    Write-Host "安装扩展: $ext" -ForegroundColor DarkGray
    & code --install-extension $ext --force 2>$null
}

# 可选扩展（用户可后续在 IDE 中自行安装）
# ms-python.vscode-pylance / ms-python.debugpy / charliermarsh.ruff
# ms-toolsai.jupyter / esbenp.prettier-vscode / streetsidesoftware.code-spell-checker
# tamasfe.even-better-toml / yzhang.markdown-all-in-one / gruntfuggly.todo-tree

Write-Host "IDE 扩展(关键)安装完成" -ForegroundColor Green
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

> **注意**: Winget 下载 OllamaSetup.exe (1.32GB) 可能超时。推荐用户手动从 https://ollama.com/download/windows 下载安装。

```powershell
# 检查是否已安装
if (Get-Command ollama -ErrorAction SilentlyContinue) {
    Write-Host "Ollama 已安装: $(ollama --version)" -ForegroundColor Green
} else {
    Write-Host "[手动操作] 请从 https://ollama.com/download/windows 下载安装 Ollama" -ForegroundColor Yellow
    Write-Host "或使用 winget 下载（耗时较长，需设置 30 分钟以上超时）:"
    Write-Host "  winget install Ollama.Ollama --accept-package-agreements --accept-source-agreements"
}

# 添加到 PATH
$ollamaBin = "$env:LOCALAPPDATA\Programs\Ollama"
if (Test-Path $ollamaBin -and ($env:Path -notlike "*$ollamaBin*")) {
    $env:Path = "$ollamaBin;$env:Path"
}
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

### 7.1 OpenCode（本环境使用的 AI Agent）

OpenCode（anomalyco/opencode）已通过 Git 克隆并构建，无需额外安装。执行以下命令从源码构建：

```powershell
# 已在此环境中运行，无需重复安装
# 若需更新: git pull && cd packages/opencode && npm run build
```

### 7.2 安装 Gemini CLI（Google 官方，可选）

```powershell
# 可选，需要时运行
npm install -g @google/gemini-cli 2>$null
Write-Host "Gemini CLI 安装完成" -ForegroundColor Green
```

### 7.3 安装 aider（AI 结对编程 CLI）

```powershell
uv pip install aider-chat

# 注意: aider 会降级 huggingface-hub 到 1.4.1，需重新升级
uv pip install "huggingface-hub>=1.21.0"

Write-Host "aider 安装完成" -ForegroundColor Green
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
# 验证脚本写入文件而非 PowerShell here-string（避免编码问题）
$verifyScript = @"
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   AI Vibe Coding Environment Report" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

`$errors = 0
`$warnings = 0

function Check-Command {
    param([string]`$Name, [string]`$Command, [string]`$ExpectedPattern)
    try {
        `$output = & (Get-Command `$Command -ErrorAction Stop) 2>&1
        if (`$ExpectedPattern -and (`$output -notmatch `$ExpectedPattern)) {
            Write-Host "  [WARN] `$Name - version mismatch" -ForegroundColor Yellow
            `$script:warnings++
        } else {
            `$version = if (`$output -match '(\d+\.\d+[\.\d]*)') { `$Matches[1] } else { "OK" }
            Write-Host "  [OK]   `$Name - v`$version" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [FAIL] `$Name - not found" -ForegroundColor Red
        `$script:errors++
    }
}

function Check-Dir {
    param([string]`$Name, [string]`$Path)
    if (Test-Path `$Path) {
        Write-Host "  [OK]   `$Name - `$Path" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] `$Name - not found" -ForegroundColor Red
        `$script:errors++
    }
}

# --- System ---
Write-Host "--- System ---" -ForegroundColor White
Check-Command "nvidia-smi" "nvidia-smi" "."
Check-Command "Git" "git" "."
Check-Command "Node.js" "node" "v\d+"
Check-Command "uv" "uv" "\d+\.\d+"

# --- CUDA ---
Write-Host "`n--- CUDA ---" -ForegroundColor White
Check-Command "nvcc" "nvcc" "\d+\.\d+"

# --- Python ---
Write-Host "`n--- Python ---" -ForegroundColor White
`$mainEnv = "D:\AI_Dev\projects\main-env"
if (Test-Path "`$mainEnv\Scripts\python.exe") {
    `$ver = & "`$mainEnv\Scripts\python.exe" --version
    Write-Host "  [OK]   Main venv - `$ver" -ForegroundColor Green
} else { Write-Host "  [FAIL] Main venv" -ForegroundColor Red; `$script:errors++ }

# --- PyTorch (via .py file to avoid escaping issues) ---
Write-Host "`n--- PyTorch ---" -ForegroundColor White
try {
    `$torchScript = "D:\AI_Dev\scripts\check_torch.py"
    @'
import torch
print(f'PyTorch {torch.__version__} | CUDA: {torch.cuda.is_available()} | GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else "N/A"}')
print(f'cuDNN: {torch.backends.cudnn.is_available()} | cuDNN ver: {torch.backends.cudnn.version() if torch.backends.cudnn.is_available() else "N/A"}')
'@ | Set-Content -Path `$torchScript -Encoding UTF8
    & "`$mainEnv\Scripts\python.exe" `$torchScript
} catch { Write-Host "  [FAIL] PyTorch check" -ForegroundColor Red; `$script:errors++ }

# --- Libraries ---
Write-Host "`n--- Core Libraries ---" -ForegroundColor White
try { & "`$mainEnv\Scripts\python.exe" -c "import transformers, datasets, accelerate, langchain, fastapi, gradio, cv2; print('All core libs OK')" }
catch { Write-Host "  [WARN] Some libs failed" -ForegroundColor Yellow; `$script:warnings++ }

# --- Ollama ---
Write-Host "`n--- Local LLM ---" -ForegroundColor White
Check-Command "Ollama" "ollama" "."
try {
    `$models = ollama list 2>&1
    if (`$models -match "NAME") { Write-Host "  [OK]   Ollama running" -ForegroundColor Green }
    else { Write-Host "  [WARN] No models pulled" -ForegroundColor Yellow; `$script:warnings++ }
} catch { Write-Host "  [WARN] Ollama not running" -ForegroundColor Yellow; `$script:warnings++ }

# --- IDE ---
Write-Host "`n--- IDE ---" -ForegroundColor White
Check-Command "VS Code" "code" ""
Check-Command "Cursor" "cursor" ""
Check-Command "aider" "aider" ""

# --- Directories ---
Write-Host "`n--- Directories ---" -ForegroundColor White
Check-Dir "AI_DEV_ROOT" "D:\AI_Dev"
Check-Dir "Projects" "D:\AI_Dev\projects"
Check-Dir "Main Venv" "D:\AI_Dev\projects\main-env"

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
if (`$errors -eq 0) { Write-Host "   Ready! (`$warnings warnings)" -ForegroundColor Green }
else { Write-Host "   Issues: `$errors errors, `$warnings warnings" -ForegroundColor Red }
Write-Host "========================================`n" -ForegroundColor Cyan
"@

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

# 确保工具路径在 PATH 中
$extraPaths = @(
    "C:\Program Files\NVIDIA\CUDNN\v9.23\bin\13.3\x64",
    "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin",
    "$env:LOCALAPPDATA\Programs\Ollama",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
)
foreach ($p in $extraPaths) {
    if (Test-Path $p -and $env:Path -notlike "*$p*") { $env:Path = "$p;$env:Path" }
}

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

# 在 PowerShell Profile 中添加别名 'ai'
$aliasEntry = @"

# === AI Dev Environment ===
Set-Alias -Name ai -Value "D:\AI_Dev\scripts\activate.ps1" -ErrorAction SilentlyContinue
"@
if (-not (Select-String -Path $PROFILE -Pattern "Set-Alias.*ai.*activate" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $PROFILE -Value $aliasEntry -Encoding UTF8
    Write-Host "别名 'ai' 已添加到 PowerShell Profile" -ForegroundColor Green
}
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
| NVIDIA 驱动 | 610.62 (>= 570.xx) | GPU 基础驱动 |
| CUDA Toolkit | 13.3 (nvcc) | GPU 编译工具链 |
| cuDNN | v9.23 | 深度学习加速库 |
| Python (venv) | 3.12.13 (D:\AI_Dev\projects\main-env) | 主力开发语言 |
| uv | 0.11.25 | 极速包管理器 |
| Miniconda | 26.3.2 (D:\AI_Dev\miniconda3) | 备选环境管理 |
| PyTorch | 2.11.0+cu128 (CUDA 可用) | 深度学习框架 |
| Transformers | 5.12.1 | Hugging Face 模型库 |
| Ollama | 0.30.11 | 本地 LLM 运行时 |
| Cursor | 3.9.8 | AI 代码编辑器 (主力) |
| VS Code | 1.126.0 | 通用代码编辑器 |
| Continue | 2.0.0 | 开源 AI 编程助手插件 |
| OpenCode | anomalyco/opencode (dev) | AI Agent (本环境驱动) |
| aider | 0.86.2 | AI 结对编程 CLI |

---

## 附录 C：日常使用快速参考

```markdown
### 启动开发环境
  ai                                       # 别名（推荐）
  # 或
  . D:\AI_Dev\scripts\activate.ps1        # 完整路径

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

*文档版本: 1.1 | 生成时间: 2025-07-11 | 最后实际部署: 2026-06-27 | 适用 GPU: NVIDIA RTX 5060 Ti 16GB*
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

**实际部署经验 (2026-06-27)**：
- **大文件下载**：PyTorch (2.6GB) 和 Ollama (1.32GB) 极易超时。PyTorch 建议指定精确版本 `torch==2.11.0+cu128` 减少解析耗时，并设置 90 分钟超时。Ollama 和 Cursor 建议提示用户手动下载。
- **cuDNN 安装方式变更**：2025-2026 年的 cuDNN 改为 exe 安装包，安装到 `C:\Program Files\NVIDIA\CUDNN\v9.23`。Agent 需根据 CUDA 版本选择对应的 bin 子目录（如 `13.3\x64`）并加入 PATH。
- **包冲突**：`aider-chat` 安装后会降级 `huggingface-hub` 到 1.4.1（`transformers` 需要 >= 1.21.0），需在 aider 之后重新升级。建议 Agent 在安装完所有包后执行一次 `uv pip install "huggingface-hub>=1.21.0"`。
- **PowerShell 编码**：含中文的 heredoc (`@''@`) 在 PowerShell 中可能存在编码问题。推荐验证脚本使用英文输出或写入 .ps1 文件执行。
- **Windows 不兼容包**：`bitsandbytes`、`flash-attn`、`vLLM` 在 Windows 上无法安装，应跳过并告知用户可在 WSL2 中使用。
- **vs code 扩展安装**：逐个安装所有扩展耗时较大，建议只安装关键扩展 `continue.continue` + `ms-python.python`，其余让用户在 IDE 中自行安装。
