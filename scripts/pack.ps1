#!/usr/bin/env pwsh
<#
.SYNOPSIS
  把本插件打包成可分发的 zip。

.DESCRIPTION
  从 .claude-plugin/plugin.json 读取插件名与版本号，只收集插件运行所需的文件
  （清单 / 文档 / skills / commands / workflows / references），排除 .git、CI、
  构建脚本与临时产物，输出到 dist/<name>-<version>.zip。

  zip 内为单一顶层文件夹 <name>/，解压即得一个可直接作为本地插件目录使用的文件夹
  （其中含 .claude-plugin/plugin.json）。

  跨平台：在 Windows PowerShell 与 Linux/macOS 的 pwsh 下均可运行（CI 即用 pwsh）。

.EXAMPLE
  pwsh ./scripts/pack.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 仓库根目录 = 本脚本所在 scripts/ 的上一级
$RepoRoot = Split-Path -Parent $PSScriptRoot

# 读取插件清单
$manifestPath = Join-Path $RepoRoot '.claude-plugin/plugin.json'
if (-not (Test-Path $manifestPath)) {
    throw "找不到插件清单：$manifestPath"
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$name = $manifest.name
$version = $manifest.version
if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
    throw "plugin.json 缺少 name 或 version 字段"
}

# 要打进 zip 的内容（文件或目录），相对仓库根
$include = @(
    '.claude-plugin',
    'skills',
    'commands',
    'workflows',
    'references',
    'README.md',
    'LICENSE'
)

# 准备输出与暂存目录
$distDir = Join-Path $RepoRoot 'dist'
$stageRoot = Join-Path $distDir '.staging'
$stageDir = Join-Path $stageRoot $name
$zipPath = Join-Path $distDir "$name-$version.zip"

if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

# 拷贝纳入项到暂存目录，保留各自的文件/目录名
foreach ($item in $include) {
    $src = Join-Path $RepoRoot $item
    if (-not (Test-Path $src)) {
        Write-Warning "跳过缺失项：$item"
        continue
    }
    Copy-Item -Path $src -Destination $stageDir -Recurse -Force
}

# 压缩：以 <name>/ 作为 zip 内唯一顶层文件夹
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $stageDir -DestinationPath $zipPath -Force

# 清理暂存
Remove-Item $stageRoot -Recurse -Force

$sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host ""
Write-Host "✅ 打包完成：$zipPath ($sizeKB KB)"
Write-Host "   插件：$name  版本：$version"
