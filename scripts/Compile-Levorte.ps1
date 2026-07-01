# Сборка Levorte.exe из Levorte.ahk через Ahk2Exe
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localAhk2Exe = Join-Path $projectRoot 'tools\Ahk2Exe.exe'
$systemAhk2ExeDir = 'C:\Program Files\AutoHotkey\Compiler'
$systemAhk2Exe = Join-Path $systemAhk2ExeDir 'Ahk2Exe.exe'

$Ahk2Exe = $env:AHK2EXE
if (-not $Ahk2Exe) {
    if (Test-Path -LiteralPath $localAhk2Exe) {
        $Ahk2Exe = $localAhk2Exe
    }
    elseif (Test-Path -LiteralPath $systemAhk2Exe) {
        $Ahk2Exe = $systemAhk2Exe
    }
}

$src = Join-Path $projectRoot 'app\Levorte.ahk'
$dst = Join-Path $projectRoot 'build\Levorte.exe'
$icon = Join-Path $projectRoot 'app\icon.ico'
$buildDir = Split-Path -Parent $dst

if (-not (Test-Path -LiteralPath $src)) {
    throw "Не найден исходный скрипт: $src"
}

# Ahk2Exe не создаёт родительский каталог для /out — без папки exe не появится.
if (-not (Test-Path -LiteralPath $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

# Закрыть уже запущенный экземпляр (Ahk2Exe не сможет перезаписать exe, пока процесс держит файл)
$procName = [System.IO.Path]::GetFileNameWithoutExtension($dst)
$existing = Get-Process -Name $procName -ErrorAction SilentlyContinue
if ($existing) {
    try {
        $existing | Stop-Process -Force -ErrorAction Stop
    }
    catch {
        # Levorte обычно запущен с правами администратора — без UAC сеанс не может его завершить
        $killCmd = "Get-Process -Name '$procName' -ErrorAction SilentlyContinue | Stop-Process -Force"
        try {
            Start-Process -FilePath powershell.exe -Verb RunAs -Wait `
                -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $killCmd
        }
        catch {
            throw "Не удалось завершить процесс ""$procName"" с повышенными правами: $($_.Exception.Message)"
        }
    }
}
$waitTimeoutSec = 5
$deadline = (Get-Date).AddSeconds($waitTimeoutSec)
do {
    $stillRunning = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if (-not $stillRunning) {
        break
    }
    if ((Get-Date) -ge $deadline) {
        throw "Процесс ""$procName"" не завершился за $waitTimeoutSec с. Закройте его вручную и повторите сборку."
    }
    Start-Sleep -Milliseconds 150
} while ($true)

if (-not (Test-Path -LiteralPath $Ahk2Exe)) {
    throw "Ahk2Exe не найден: $Ahk2Exe (задайте путь в переменной окружения AHK2EXE)"
}

$ahk2ExeBase = $env:AHK2EXE_BASE
if (-not $ahk2ExeBase) {
    $baseCandidates = @(
        (Join-Path $systemAhk2ExeDir 'AutoHotkeySC.bin')
        (Join-Path $systemAhk2ExeDir 'Unicode 64-bit.bin')
        (Join-Path (Split-Path -Parent $Ahk2Exe) 'AutoHotkeySC.bin')
        (Join-Path (Split-Path -Parent $Ahk2Exe) 'Unicode 64-bit.bin')
    )
    foreach ($candidate in $baseCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $ahk2ExeBase = $candidate
            break
        }
    }
}
if (-not $ahk2ExeBase -or -not (Test-Path -LiteralPath $ahk2ExeBase)) {
    throw "Base-файл Ahk2Exe не найден. Укажите AHK2EXE_BASE или установите AutoHotkey Compiler."
}
# Принудительно удаляем предыдущий exe, чтобы исключить ситуацию с запуском старого бинарника.
if (Test-Path -LiteralPath $dst) {
    try {
        Remove-Item -LiteralPath $dst -Force -ErrorAction Stop
    }
    catch {
        throw "Не удалось удалить старый exe ($dst). Проверьте, что файл не занят: $($_.Exception.Message)"
    }
}

$compilerArgs = @(
    '/in', $src
    '/out', $dst
    '/base', $ahk2ExeBase
    '/silent'
)
if (Test-Path -LiteralPath $icon) {
    $compilerArgs += '/icon', $icon
}

& $Ahk2Exe @compilerArgs
# Локальный Ahk2Exe может не иметь настроенный base file.
$compileExit = $LASTEXITCODE
if ($null -ne $compileExit -and $compileExit -ne 0 -and $Ahk2Exe -eq $localAhk2Exe -and (Test-Path -LiteralPath $systemAhk2Exe)) {
    $Ahk2Exe = $systemAhk2Exe
    & $Ahk2Exe @compilerArgs
    $compileExit = $LASTEXITCODE
}
# Без явного кода выхода $LASTEXITCODE может быть $null; тогда ($null -ne 0) даёт $true и скрипт
# выходит ДО Start-Process — сборка визуально ок, exe не стартует.
if ($null -ne $compileExit -and $compileExit -ne 0) {
    exit $compileExit
}
$waitForExeTimeoutSec = 8
$waitForExeDeadline = (Get-Date).AddSeconds($waitForExeTimeoutSec)
while (-not (Test-Path -LiteralPath $dst)) {
    if ((Get-Date) -ge $waitForExeDeadline) {
        throw "После сборки не найден: $dst"
    }
    Start-Sleep -Milliseconds 200
}
# Start-Process принимает -FilePath (параметра -LiteralPath у него нет в Windows PowerShell)
Start-Process -FilePath $dst -WorkingDirectory (Split-Path -Parent $dst) -ErrorAction Stop
