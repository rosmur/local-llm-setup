#Requires -Version 5.1
<#
    setup-local-pi.ps1 - interactive Windows setup for a local coding agent:
      winget -> llama.cpp -> GGUF model -> Git Bash + Node.js -> pi -> pi models.json

    Nothing is installed or changed without an explicit "y" from you.

    Run it with:
      powershell -ExecutionPolicy Bypass -File .\setup-local-pi.ps1

    This is the Windows counterpart of setup-local-pi.sh (macOS).
#>

Set-StrictMode -Version Latest
# Native tools (winget, llama-cli, npm) write progress to stderr. Leaving this at
# 'Continue' keeps that visible instead of turning it into a terminating error;
# every external command below has its exit code checked explicitly.
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'   # Write-Progress bars mangle piped installers

function Say  { param([string]$Message = '') Write-Host $Message }
function Info { param([string]$Message)      Write-Host "    $Message"     -ForegroundColor DarkGray }
function Head { param([string]$Message)      Write-Host ''; Write-Host "==> $Message" -ForegroundColor White }
function Ok   { param([string]$Message)      Write-Host "    OK: $Message" -ForegroundColor Green }
function Warn { param([string]$Message)      Write-Host "    ! $Message"   -ForegroundColor Yellow }
function Die  { param([string]$Message)      Write-Host "    ERROR: $Message" -ForegroundColor Red; exit 1 }

# Ask "question" -> $true for yes, $false for no. Defaults to no on empty input.
function Ask {
    param([Parameter(Mandatory = $true)][string]$Question)
    Write-Host ''
    Write-Host "$Question [y/N] " -NoNewline -ForegroundColor White
    $reply = Read-Host
    # Read-Host hands back $null once input is exhausted (a redirected or closed
    # stdin). That is not a "yes", so it falls through to the same answer as empty.
    if ($null -eq $reply) { return $false }
    return ($reply -match '^\s*(y|yes)\s*$')
}

function Have-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# A program installed mid-script is not on this process's PATH, because PATH was
# copied from the registry when this window opened. Re-read it (plus winget's
# portable-link directory, which is where llama.cpp's binaries land) so the rest
# of the script can see what was just installed without opening a new terminal.
function Update-SessionPath {
    $parts = @()
    foreach ($scope in 'Machine', 'User') {
        $value = [Environment]::GetEnvironmentVariable('Path', $scope)
        if ($value) { $parts += $value }
    }
    $extras = @()
    if ($env:LOCALAPPDATA) { $extras += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') }
    if ($env:APPDATA)      { $extras += (Join-Path $env:APPDATA 'npm') }
    foreach ($extra in $extras) {
        if ((Test-Path -LiteralPath $extra) -and ($parts -join ';') -notlike "*$extra*") { $parts += $extra }
    }
    $env:Path = ($parts -join ';')
}

function Require-Windows {
    # PowerShell 7 defines $IsWindows; Windows PowerShell 5.1 does not (and only runs on Windows).
    $onWindows = $true
    if (Get-Variable -Name 'IsWindows' -Scope Global -ErrorAction SilentlyContinue) { $onWindows = $IsWindows }
    if (-not $onWindows) { Die 'This script is for Windows only. On macOS use setup-local-pi.sh instead.' }
}

function Format-Size {
    param([Parameter(Mandatory = $true)][double]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N0} MB' -f ($Bytes / 1MB)) }
    return ('{0:N0} KB' -f ($Bytes / 1KB))
}

# Write text as UTF-8 *without* a byte-order mark. Set-Content -Encoding UTF8 adds
# one in PowerShell 5.1, and a BOM breaks both Node's JSON.parse (which pi uses to
# read models.json) and cmd.exe's parsing of a .cmd file.
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
Write-Host 'Local coding agent setup' -ForegroundColor White
Say 'This script will walk through five steps and ask permission before each one:'
Say '  1. winget          - the package manager built into Windows'
Say '  2. llama.cpp       - runs AI models on your own PC (gives you "llama-server")'
Say '  3. a model         - you pick one; it is a multi-GB download from Hugging Face'
Say '  4. Git Bash + Node - the two things pi needs before it will run on Windows'
Say '  5. pi              - a terminal coding agent, pointed at your local model'
Say ''
Write-Host 'Nothing runs until you type "y". Ctrl-C quits at any time.' -ForegroundColor DarkGray

Require-Windows

# PROCESSOR_ARCHITECTURE reports the architecture of *this process*, so a 32-bit or
# emulated PowerShell on an ARM64 machine would report x86/AMD64 instead. Windows sets
# PROCESSOR_ARCHITEW6432 to the real one in exactly that case.
$osArchitecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($osArchitecture -eq 'ARM64') {
    Warn 'This PC reports an ARM64 processor (Snapdragon X / Surface Pro X class).'
    Info 'The winget llama.cpp package ships an x64 build only, so it will run under'
    Info 'emulation - noticeably slower, and without GPU offload. For native speed,'
    Info 'build llama.cpp from source instead: https://github.com/ggml-org/llama.cpp'
}

# --- Step 1: winget ---------------------------------------------------------
Head 'Step 1 of 5: winget'

if (-not (Have-Command 'winget')) { Update-SessionPath }

if (Have-Command 'winget') {
    Ok "winget is available ($((& winget --version) 2>$null))."
} else {
    Say 'winget was not found.'
    Info 'winget ships with Windows 11 and with Windows 10 1809+ that have received the'
    Info '"App Installer" update from the Microsoft Store. It cannot be safely bootstrapped'
    Info 'from a script, so this one step has to be done by hand.'
    Info 'Store page: https://apps.microsoft.com/detail/9nblggh4nns1'
    if (Ask 'Open the Microsoft Store page for App Installer now?') {
        Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
        Info 'Install it, then close and reopen PowerShell and run this script again.'
    }
    Die 'winget is required for the rest of this script. Nothing was changed.'
}

# --- Step 2: llama.cpp ------------------------------------------------------
Head 'Step 2 of 5: llama.cpp'

if (Have-Command 'llama-server') {
    Ok "llama-server is already installed ($((& llama-server --version 2>&1 | Select-Object -First 1)))."
} else {
    Say 'llama.cpp was not found.'
    Info 'The winget package is "ggml.llamacpp". It installs llama-cli.exe, llama-server.exe'
    Info 'and friends as portable binaries, and is rebuilt for every upstream release.'
    Info 'llama-server exposes an OpenAI-compatible API on your machine - that is what pi talks to.'
    Info 'The package is the Vulkan x64 build, so GPU offload works on any reasonably modern'
    Info 'NVIDIA, AMD or Intel GPU. It also pulls in the Visual C++ 2015+ x64 runtime.'
    Info 'Command: winget install --exact --id ggml.llamacpp'
    if (Ask 'Install llama.cpp now?') {
        & winget install --exact --id ggml.llamacpp --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Die "winget install ggml.llamacpp failed (exit code $LASTEXITCODE)." }
        Update-SessionPath
        if (-not (Have-Command 'llama-server')) {
            Warn 'llama.cpp installed, but llama-server is still not on this shell''s PATH.'
            Info 'winget links portable packages into %LOCALAPPDATA%\Microsoft\WinGet\Links using'
            Info 'symlinks, which Windows only allows for administrators or with Developer Mode on.'
            Info 'Fix: enable Developer Mode (Settings > System > For developers), or re-run the'
            Info 'winget command from an elevated PowerShell. Then open a new terminal and re-run this script.'
            Die 'Cannot continue without llama-server.'
        }
        Ok 'llama.cpp installed.'
    } else {
        Die 'llama.cpp is required. Nothing further was changed.'
    }
}

# --- Step 3: pick and download a model --------------------------------------
Head 'Step 3 of 5: choose a model'

# Where llama.cpp keeps downloaded weights. Recent builds use the standard
# Hugging Face hub cache; older ones used their own directory, which on Windows
# is %LOCALAPPDATA%\llama.cpp. Both are checked, in the same precedence order
# llama.cpp itself uses.
$CacheRoots = New-Object System.Collections.Generic.List[string]
function Add-CacheRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($CacheRoots -notcontains $full) { $CacheRoots.Add($full) }
}
Add-CacheRoot $env:LLAMA_CACHE
Add-CacheRoot $env:HF_HUB_CACHE
Add-CacheRoot $env:HUGGINGFACE_HUB_CACHE
if ($env:HF_HOME) { Add-CacheRoot (Join-Path $env:HF_HOME 'hub') }
Add-CacheRoot (Join-Path $HOME '.cache\huggingface\hub')
if ($env:LOCALAPPDATA) { Add-CacheRoot (Join-Path $env:LOCALAPPDATA 'llama.cpp') }

function Get-DirectorySize {
    param([Parameter(Mandatory = $true)][string]$Path)
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { return 0 }
    return [double]$sum
}

# Find-Cached <org> <repo> <legacy-name-fragment>
# Returns an object with .Size and .Path for the first match found, or $null.
# Two layouts are searched: the Hugging Face one (a models--org--repo directory)
# and the older flat one (a .gguf file whose name contains the model name).
function Find-Cached {
    param(
        [Parameter(Mandatory = $true)][string]$Org,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Fragment
    )
    foreach ($root in $CacheRoots) {
        $hfDir = Join-Path $root "models--$Org--$Repo"
        if (Test-Path -LiteralPath $hfDir -PathType Container) {
            return [pscustomobject]@{ Size = (Format-Size (Get-DirectorySize $hfDir)); Path = $hfDir }
        }
        $hit = Get-ChildItem -LiteralPath $root -Filter '*.gguf' -Recurse -Depth 3 -File -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like "*$Fragment*" } | Select-Object -First 1
        if ($hit) {
            return [pscustomobject]@{ Size = (Format-Size $hit.Length); Path = $hit.FullName }
        }
    }
    return $null
}

# Renders either an "already on disk" note or the download size.
function Get-StatusLine {
    param([string]$Org, [string]$Repo, [string]$Fragment, [string]$ApproxSize)
    $found = Find-Cached -Org $Org -Repo $Repo -Fragment $Fragment
    if ($found) { return [pscustomobject]@{ Text = "[on disk: $($found.Size)]"; Color = 'Green' } }
    return [pscustomobject]@{ Text = "[not downloaded, ~$ApproxSize]"; Color = 'DarkGray' }
}

function Write-ModelOption {
    param([string]$Number, [string]$Title, [string]$Detail, $Status, [string]$Repo)
    Write-Host "  $Number) " -NoNewline -ForegroundColor White
    Write-Host ('{0,-31}' -f $Title) -NoNewline
    Write-Host ('{0,-36}' -f $Detail) -NoNewline
    Write-Host $Status.Text -ForegroundColor $Status.Color
    Write-Host "     $Repo" -ForegroundColor DarkGray
}

# Download the weights WITHOUT dropping the user into an interactive chat.
#
# llama-cli auto-enables conversation mode whenever the model ships a chat
# template, which every model offered here does. -no-cnv is supposed to suppress
# that but is unreliable across builds, so three independent guards are used:
#   -st / --single-turn  documented to be non-interactive when -p is supplied
#   -no-cnv              legacy flag, still honoured by most builds
#   < NUL                the backstop: any prompt that appears gets EOF and exits
# Flags are probed against --help first so an older or newer llama-cli never
# aborts with "unknown argument".
#
# The command is run through a throwaway .cmd file rather than being invoked
# directly, because "< NUL" is a cmd.exe redirection - PowerShell has no
# equivalent for closing a native program's stdin.
function Get-Model {
    param([Parameter(Mandatory = $true)][string]$Repo)

    $help  = (& llama-cli --help 2>&1 | Out-String)
    $flags = @('-n', '1')
    if ($help -match '-no-cnv')      { $flags += '-no-cnv' }
    if ($help -match '--single-turn') { $flags += '-st' }
    if ($help -match '--no-warmup')   { $flags += '--no-warmup' }

    $exe = (Get-Command 'llama-cli' -ErrorAction Stop).Source
    $printable = "llama-cli -hf $Repo -p ok $($flags -join ' ') < NUL"
    Info "Running: $printable"

    # stdout is discarded (the single generated token); stderr is left alone so the
    # download progress bar stays visible.
    $tempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $script  = Join-Path $tempDir "fetch-model-$PID.cmd"
    $lines   = @(
        '@echo off',
        "`"$exe`" -hf `"$Repo`" -p ok $($flags -join ' ') < NUL > NUL"
    )
    Write-TextFile -Path $script -Content (($lines -join "`r`n") + "`r`n")
    try {
        # Out-Host, not a bare call: anything a native command writes to stdout would
        # otherwise become part of this function's return value, and a non-empty array
        # is truthy - which would make a failed download look like a successful one.
        & cmd.exe /c $script | Out-Host
        $exit = $LASTEXITCODE
        return ($exit -eq 0)
    } finally {
        Remove-Item -LiteralPath $script -Force -ErrorAction SilentlyContinue
    }
}

Say 'Checking which models you already have...'
$s1 = Get-StatusLine 'ggml-org' 'gemma-4-E4B-it-GGUF'         'gemma-4-E4B'            '4.6 GB'
$s2 = Get-StatusLine 'unsloth'  'gemma-4-26B-A4B-it-qat-GGUF' 'gemma-4-26B-A4B-it-qat' '15 GB'
$s3 = Get-StatusLine 'unsloth'  'Qwen3.5-35B-A3B-GGUF'        'Qwen3.5-35B-A3B'        '20 GB'

Say ''
Say 'Models are downloaded from Hugging Face and cached on disk. Re-running this'
Say 'script never re-downloads something you already have.'
Say 'Rule of thumb: the model should fit comfortably inside your RAM.'
Say ''
Write-ModelOption '1' 'Gemma 4 E4B (Q4_0)'      '8B params, small and fast'          $s1 'ggml-org/gemma-4-E4B-it-GGUF:Q4_0'
Write-ModelOption '2' 'Gemma 4 26B-A4B QAT'     'MoE, 4B active - fast for its size' $s2 'unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL'
Write-ModelOption '3' 'Qwen3.5 35B-A3B (Q4_K_M)' 'MoE, 3B active, strong at code'    $s3 'unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M'
Say ''

$totalRam = $null
try { $totalRam = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory } catch { }
if ($totalRam) {
    Info "This PC reports $([math]::Round($totalRam / 1GB)) GB of RAM."
} else {
    Info 'Could not read how much RAM this PC has.'
}
if ($CacheRoots.Count -gt 0) {
    Info "Cache directories searched: $($CacheRoots -join ' ')"
} else {
    Info 'No model cache directory exists yet - nothing has been downloaded before.'
}

$ModelRepo = ''; $ModelAlias = ''; $ModelLabel = ''; $ModelCtx = 32768
$ModelOrg  = ''; $ModelName  = ''; $ModelFrag  = ''
while (-not $ModelRepo) {
    Write-Host 'Choose 1, 2 or 3 (or q to quit): ' -NoNewline -ForegroundColor White
    $choice = Read-Host
    # A $null here means stdin is exhausted, not that the user typed nothing. Quitting
    # matches the macOS script's "read ... || choice=q" and avoids looping forever on
    # the prompt when the script is run with redirected input.
    if ($null -eq $choice) { Say ''; Say 'No input available. Nothing downloaded. Exiting.'; exit 0 }
    switch ($choice.Trim()) {
        '1' {
            $ModelRepo = 'ggml-org/gemma-4-E4B-it-GGUF:Q4_0';             $ModelAlias = 'gemma-4-e4b';         $ModelLabel = 'Gemma 4 E4B'
            $ModelOrg  = 'ggml-org'; $ModelName = 'gemma-4-E4B-it-GGUF';         $ModelFrag = 'gemma-4-E4B'
        }
        '2' {
            $ModelRepo = 'unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL'; $ModelAlias = 'gemma-4-26b-a4b-qat'; $ModelLabel = 'Gemma 4 26B-A4B QAT'
            $ModelOrg  = 'unsloth';  $ModelName = 'gemma-4-26B-A4B-it-qat-GGUF'; $ModelFrag = 'gemma-4-26B-A4B-it-qat'
        }
        '3' {
            $ModelRepo = 'unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M';            $ModelAlias = 'qwen3.5-35b-a3b';     $ModelLabel = 'Qwen3.5 35B-A3B'
            $ModelOrg  = 'unsloth';  $ModelName = 'Qwen3.5-35B-A3B-GGUF';        $ModelFrag = 'Qwen3.5-35B-A3B'
        }
        { $_ -in 'q', 'Q' } { Say 'Nothing downloaded. Exiting.'; exit 0 }
        default { Warn 'Please type 1, 2, 3 or q.' }
    }
}

Say ''
Write-Host "Selected: $ModelLabel  ($ModelRepo)" -ForegroundColor White

$cached = Find-Cached -Org $ModelOrg -Repo $ModelName -Fragment $ModelFrag
if ($cached) {
    Ok "Already on disk: $($cached.Path)  ($($cached.Size))"
    Info 'Skipping the download. This is the normal path when re-running the script.'
    Info 'Note: this check finds the model repository, but cannot always confirm which'
    Info 'compression level (quant) is present, or that the files are complete.'
    if (Ask 'Verify it anyway? (Fast if complete; resumes if a previous run was interrupted.)') {
        if (-not (Get-Model -Repo $ModelRepo)) { Die 'Verification failed.' }
        Ok 'Verified.'
    }
} else {
    Info 'This fetches the weights into the cache and exits on its own - it will NOT'
    Info 'drop you into a chat session, and needs no input from you while it runs.'
    Info 'It can take a long time. The exact command is printed below.'
    Info 'If it is interrupted, re-run this script - it resumes rather than starting over.'
    if (Ask 'Download the model now? (Say n to skip - llama-server will fetch it on first run.)') {
        if (-not (Get-Model -Repo $ModelRepo)) { Die 'Model download failed.' }
        Ok 'Model downloaded and cached.'
    } else {
        Warn 'Skipped. The first "llama-server" run will download it.'
    }
}

# --- Step 4: what pi needs first --------------------------------------------
Head 'Step 4 of 5: Git Bash and Node.js'

# Unlike on macOS, pi has two hard prerequisites on Windows that are worth
# installing up front rather than leaving to pi's installer:
#
#  * bash. pi shells out to bash for its command-running tool, and Windows has
#    none. It looks for shellPath in ~/.pi/agent/settings.json, then Git Bash at
#    "C:\Program Files\Git\bin\bash.exe", then any bash.exe on PATH. Git for
#    Windows is the recommended way to supply it.
#  * Node.js >= 22.19.0. On macOS pi's installer offers to install this via
#    Homebrew; on Windows winget does the job in one line and keeps the whole
#    thing inspectable.

# Built defensively: on a 32-bit or unusually configured Windows any of these
# environment variables can be unset, and Join-Path throws on a null path.
$bashPath  = $null
$bashRoots = @()
foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($root) { $bashRoots += (Join-Path $root 'Git') }
}
if ($env:LOCALAPPDATA) { $bashRoots += (Join-Path $env:LOCALAPPDATA 'Programs\Git') }
foreach ($root in $bashRoots) {
    $candidate = Join-Path $root 'bin\bash.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $bashPath = $candidate; break }
}
if (-not $bashPath) {
    $onPath = Get-Command 'bash.exe' -ErrorAction SilentlyContinue
    if ($onPath) { $bashPath = $onPath.Source }
}

# A bash.exe sitting in System32 is the legacy WSL launcher, not a real bash. Compare
# normalised directories rather than matching the path as a string, because PATH
# entries vary in separator style and trailing slashes.
$bashIsWslStub = $false
if ($bashPath -and $env:SystemRoot) {
    try {
        $bashDir  = [System.IO.Path]::GetFullPath((Split-Path -Path $bashPath -Parent)).TrimEnd('\', '/')
        $system32 = [System.IO.Path]::GetFullPath((Join-Path $env:SystemRoot 'System32')).TrimEnd('\', '/')
        $bashIsWslStub = ($bashDir -ieq $system32)
    } catch { }
}

if ($bashPath -and -not $bashIsWslStub) {
    Ok "bash found at $bashPath"
} else {
    if ($bashPath) {
        Warn "The only bash on PATH is $bashPath - that is the WSL launcher, not Git Bash."
        Info 'pi can drive it, but paths and tools then come from inside your Linux distro,'
        Info 'which is rarely what you want for a Windows project. Git Bash is the safer choice.'
    } else {
        Say 'No bash was found, and pi needs one to run commands for you.'
    }
    Info 'Git for Windows supplies it at "C:\Program Files\Git\bin\bash.exe".'
    Info 'Command: winget install --exact --id Git.Git'
    if (Ask 'Install Git for Windows now?') {
        & winget install --exact --id Git.Git --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Die "winget install Git.Git failed (exit code $LASTEXITCODE)." }
        Update-SessionPath
        # Cleared first: it may still hold the System32 WSL launcher found above, which
        # would otherwise be reported back as though it were the Git Bash just installed.
        $bashPath = $null
        foreach ($root in $bashRoots) {
            $candidate = Join-Path $root 'bin\bash.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $bashPath = $candidate; break }
        }
        if ($bashPath) {
            Ok "Git Bash installed at $bashPath"
        } else {
            Warn 'Git installed, but bash.exe was not found in the expected location.'
            Info 'If pi later complains that it cannot find a shell, point it at yours by creating'
            Info '%USERPROFILE%\.pi\agent\settings.json containing: { "shellPath": "C:\\path\\to\\bash.exe" }'
        }
    } else {
        Warn 'Skipped. pi will install, but its command-running tool will not work until a bash exists.'
    }
}

Say ''
$nodeOk = $false
if (Have-Command 'node') {
    $nodeVersion = (& node --version) 2>$null
    if ("$nodeVersion" -match '^v(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -gt 22 -or ($major -eq 22 -and $minor -ge 19)) {
            $nodeOk = $true
            Ok "Node.js $nodeVersion meets pi's requirement (>= 22.19.0)."
        } else {
            Warn "Node.js $nodeVersion is older than pi's minimum of 22.19.0."
        }
    } else {
        Warn "Could not parse the output of 'node --version' ($nodeVersion)."
    }
} else {
    Say 'Node.js is not installed. pi is distributed as an npm package, so it is required.'
}

if (-not $nodeOk) {
    Info 'Command: winget install --exact --id OpenJS.NodeJS.LTS'
    Info 'This installs the current Node.js LTS release for all users, and puts node and npm'
    Info 'on your PATH. Existing Node installs are upgraded in place rather than duplicated.'
    if (Ask 'Install Node.js LTS now?') {
        & winget install --exact --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { Die "winget install OpenJS.NodeJS.LTS failed (exit code $LASTEXITCODE)." }
        Update-SessionPath
        if (Have-Command 'node') {
            $nodeOk = $true
            Ok "Node.js $((& node --version) 2>$null) installed."
        } else {
            Warn 'Node.js installed but is not on this shell''s PATH yet.'
            Info 'Close this window, open a new PowerShell, and re-run the script; it will skip ahead.'
        }
    } else {
        Warn 'Skipped. pi cannot be installed without Node.js; the remaining steps still write config files.'
    }
}

# --- Step 5: pi -------------------------------------------------------------
Head 'Step 5 of 5: pi coding agent'

if (Have-Command 'pi') {
    Ok "pi is already installed at $((Get-Command 'pi').Source)."
    Info 'Nothing to do here; skipping to the configuration files.'
} elseif (-not $nodeOk) {
    Warn 'Skipping pi: Node.js is not available in this shell.'
    Info 'Install Node.js, then run:  npm install -g --ignore-scripts @earendil-works/pi-coding-agent'
} else {
    Say ''
    Say 'pi is not installed. There are two ways to do it, and you can pick either.'
    Info 'A) npm, which you already have because Node.js is installed:'
    Info '     npm install -g --ignore-scripts @earendil-works/pi-coding-agent'
    Info '   This is the whole install. --ignore-scripts blocks dependency lifecycle scripts;'
    Info '   pi does not need them. It lands in npm''s global prefix (%APPDATA%\npm), which the'
    Info '   Node installer already added to your PATH.'
    Info 'B) pi''s own installer, the equivalent of the curl one-liner used on macOS:'
    Info '     irm https://pi.dev/install.ps1 | iex'
    Info '   It ends up running much the same npm command, plus its own Node check and PATH'
    Info '   handling. It also means trusting the pi.dev server to serve an honest script.'
    Info '   To read it first, in another window:  irm https://pi.dev/install.ps1 | more'

    $piInstalled = $false
    if (Ask 'Install pi with npm (option A)?') {
        & npm install -g --ignore-scripts '@earendil-works/pi-coding-agent'
        if ($LASTEXITCODE -ne 0) { Warn "npm install exited with code $LASTEXITCODE." } else { $piInstalled = $true }
    } elseif (Ask 'Run pi''s own installer instead (option B)?') {
        try {
            # Windows PowerShell 5.1 can still default to TLS 1.0, which modern hosts
            # refuse. PowerShell 7 already negotiates properly, so this is a no-op there.
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
            Invoke-Expression ((Invoke-RestMethod -Uri 'https://pi.dev/install.ps1' -UseBasicParsing) | Out-String)
            $piInstalled = $true
        } catch {
            Warn "pi's installer could not be fetched or exited with an error: $($_.Exception.Message)"
        }
    } else {
        Warn 'Skipped. llama.cpp and the model are still set up; you can install pi later.'
    }

    if ($piInstalled) {
        Update-SessionPath
        if (Have-Command 'pi') {
            Ok "pi installed at $((Get-Command 'pi').Source)."
        } else {
            Warn 'pi was installed but is not on this shell''s PATH.'
            Info 'Check with:  dir "$env:APPDATA\npm\pi*"'
            Info 'Opening a new terminal usually resolves it. The remaining steps only write config files.'
        }
    }
}

# --- Step 5c: launcher script ----------------------------------------------
$launcherDir = Join-Path $HOME 'bin'
$launcher    = Join-Path $launcherDir "llama-serve-$ModelAlias.cmd"
if (-not (Test-Path -LiteralPath $launcherDir)) { New-Item -ItemType Directory -Path $launcherDir -Force | Out-Null }

Say ''
Say 'Next, a small launcher script that starts llama-server with your model.'
Info "It will be written to: $launcher"
Info "The --alias flag pins the model's API name to '$ModelAlias' so pi's config always matches."
Info 'A .cmd file is used rather than .ps1 so you can double-click it in Explorer and so'
Info 'PowerShell''s execution policy cannot get in the way.'
if (Ask 'Write the launcher script?') {
    $launcherLines = @(
        '@echo off',
        "REM Starts llama-server for $ModelLabel. Leave this window open while you use pi.",
        'llama-server ^',
        "  -hf $ModelRepo ^",
        "  --alias $ModelAlias ^",
        '  --host 127.0.0.1 --port 8080 ^',
        '  -ngl 99 ^',
        "  -c $ModelCtx ^",
        '  -fa on ^',
        '  --jinja',
        '',
        'REM Keep the window open if the server failed to start, so you can read why.',
        'if errorlevel 1 pause'
    )
    Write-TextFile -Path $launcher -Content (($launcherLines -join "`r`n") + "`r`n")
    Ok "Wrote $launcher"
} else {
    Warn 'Skipped launcher script.'
}

# --- Step 5d: pi models.json -----------------------------------------------
$piDir    = Join-Path $HOME '.pi\agent'
$piModels = Join-Path $piDir 'models.json'
if (-not (Test-Path -LiteralPath $piDir)) { New-Item -ItemType Directory -Path $piDir -Force | Out-Null }

# Sets a property on a PSCustomObject whether or not it already exists, which is
# what makes the merge below a merge: every key that was already in the file and
# is not touched here survives untouched.
function Set-JsonProperty {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name, $Value)
    if (Test-JsonProperty $Object $Name) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}
# Indexing PSObject.Properties is deliberate: the more obvious
# "$Object.PSObject.Properties.Name -contains $Name" throws under Set-StrictMode
# when the object has no properties at all, which is the fresh-install case.
function Test-JsonProperty {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Object) { return $false }
    return ($null -ne $Object.PSObject.Properties[$Name])
}

Say ''
Say 'Finally, register the local server with pi.'
Info "File: $piModels"
Info "This adds a provider 'llama-cpp' at http://localhost:8080/v1 with model id '$ModelAlias'."
Info 'Existing providers and models in that file are preserved; a .bak backup is made.'
if (Ask "Update pi's models.json?") {
    $config = [pscustomobject]@{}
    if (Test-Path -LiteralPath $piModels) {
        Copy-Item -LiteralPath $piModels -Destination "$piModels.bak.$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
        Info 'Backup created.'
        $raw = Get-Content -LiteralPath $piModels -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try { $config = $raw | ConvertFrom-Json }
            catch { Die "Existing models.json is not valid JSON: $($_.Exception.Message)" }
        }
    }

    if (-not (Test-JsonProperty $config 'providers') -or $null -eq $config.providers) {
        Set-JsonProperty $config 'providers' ([pscustomobject]@{})
    }
    $providers = $config.providers

    $provider = [pscustomobject]@{}
    if ((Test-JsonProperty $providers 'llama-cpp') -and $providers.'llama-cpp') { $provider = $providers.'llama-cpp' }

    Set-JsonProperty $provider 'baseUrl' 'http://localhost:8080/v1'
    Set-JsonProperty $provider 'api'     'openai-completions'
    if (-not (Test-JsonProperty $provider 'apiKey') -or -not $provider.apiKey) {
        Set-JsonProperty $provider 'apiKey' 'none'
    }

    $models = @()
    if ((Test-JsonProperty $provider 'models') -and $provider.models) { $models = @($provider.models) }

    $entry = [pscustomobject]@{
        id            = $ModelAlias
        name          = "$ModelLabel (local)"
        contextWindow = $ModelCtx
        maxTokens     = 8192
        cost          = [pscustomobject]@{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }
    }

    $index = -1
    for ($i = 0; $i -lt $models.Count; $i++) {
        $m = $models[$i]
        if ($m -and (Test-JsonProperty $m 'id') -and $m.id -eq $entry.id) { $index = $i; break }
    }
    if ($index -ge 0) { $models[$index] = $entry } else { $models += $entry }

    Set-JsonProperty $provider 'models' @($models)
    Set-JsonProperty $providers 'llama-cpp' $provider

    # -Depth matters: PowerShell's default of 2 would silently flatten the nested
    # model entries into type names instead of objects.
    Write-TextFile -Path $piModels -Content (($config | ConvertTo-Json -Depth 20) + "`r`n")
    Ok "Updated $piModels"
} else {
    Warn 'Skipped. You can add the provider yourself later - see https://pi.dev/docs/latest/models'
}

# --- Done -------------------------------------------------------------------
Head 'Done'
Say 'To use it, open two terminal windows:'
Say ''
Write-Host "  Terminal 1 (leave running):   $launcher" -ForegroundColor White
Write-Host '  Terminal 2:                   cd C:\your\project; pi' -ForegroundColor White
Say ''
Write-Host "Inside pi, press Ctrl+L or type /model and pick '$ModelAlias'." -ForegroundColor White
Say ''
Info "If '$ModelAlias' does not appear in /model, pi has no saved credential for the"
Info 'provider. Run: pi --api-key none   (local servers ignore the key; pi just wants one.)'
Info 'Check the server is alive with: curl.exe http://localhost:8080/v1/models'
Info 'If either command is not found, open a new terminal so PATH is picked up.'
