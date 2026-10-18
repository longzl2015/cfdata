# 飞牛 fnOS .fpk 打包脚本（PowerShell 版，适用于 Windows）
# 用法: .\build.ps1
# 产物: cfdata-fpk\cfdata_1.0.0_x86.fpk

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$APP_DIR = Join-Path $ROOT "cfdata"
$FNOS_DIR = Join-Path $APP_DIR "fnos"
$STAGE_DIR = Join-Path $ROOT "stage"
$APP_TGZ = Join-Path $ROOT "cfdata-app.tgz"
$VERSION = "1.0.0"
$PLATFORM = "x86"

Write-Host "[INFO] 根目录: $ROOT" -ForegroundColor Green

# 1. 解码图标 (base64 -> PNG)
Write-Host "[INFO] 解码图标 ..." -ForegroundColor Green
foreach ($icon in @("ICON.PNG", "ICON_256.PNG")) {
    $b64Path = Join-Path $FNOS_DIR "$icon.b64"
    $pngPath = Join-Path $FNOS_DIR $icon
    if (!(Test-Path $b64Path)) {
        Write-Host "[ERROR] 缺少 $b64Path" -ForegroundColor Red
        exit 1
    }
    $b64 = Get-Content $b64Path -Raw | ForEach-Object { $_.Trim() }
    [System.IO.File]::WriteAllBytes($pngPath, [System.Convert]::FromBase64String($b64))
    Write-Host "  已生成 $pngPath"
}

# 2. 创建 app.tgz (将 cfdata-linux-amd64 打入 opt/cfdata/ 路径)
Write-Host "[INFO] 创建 app.tgz ..." -ForegroundColor Green
if (Test-Path $STAGE_DIR) { Remove-Item $STAGE_DIR -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $STAGE_DIR "opt/cfdata") -Force | Out-Null

$srcBin = Join-Path $ROOT "..\cfdata-linux-amd64"
$dstBin = Join-Path $STAGE_DIR "opt/cfdata/cfdata-linux-amd64"
if (!(Test-Path $srcBin)) {
    Write-Host "[ERROR] 找不到 cfdata-linux-amd64，请确保它在 $ROOT 上一级目录 ($srcBin)" -ForegroundColor Red
    exit 1
}
$srcBin = (Get-Item $srcBin).FullName
Copy-Item $srcBin $dstBin -Force

# 使用 tar 打包 (Windows 10/11 自带 tar.exe)
& tar -czf $APP_TGZ -C $STAGE_DIR opt/cfdata/cfdata-linux-amd64
if (!(Test-Path $APP_TGZ)) {
    Write-Host "[ERROR] app.tgz 生成失败" -ForegroundColor Red
    exit 1
}
$size = (Get-Item $APP_TGZ).Length
Write-Host "  已生成 $APP_TGZ ($size 字节)"

# 3. 计算 MD5 checksum
Write-Host "[INFO] 计算 MD5 checksum ..." -ForegroundColor Green
$md5 = [System.Security.Cryptography.MD5]::Create()
$stream = [System.IO.File]::OpenRead($APP_TGZ)
$hash = $md5.ComputeHash($stream)
$stream.Close()
$checksum = ($hash | ForEach-Object { $_.ToString("x2") }) -join ""
Write-Host "  checksum = $checksum"

# 4. 构建 fpk 包目录
Write-Host "[INFO] 构建 fpk 包目录 ..." -ForegroundColor Green
if (Test-Path (Join-Path $ROOT "pkg")) { Remove-Item (Join-Path $ROOT "pkg") -Recurse -Force }
$PKG_DIR = Join-Path $ROOT "pkg"
New-Item -ItemType Directory -Path (Join-Path $PKG_DIR "cmd") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $PKG_DIR "ui/images") -Force | Out-Null

# 复制 app.tgz
Copy-Item $APP_TGZ (Join-Path $PKG_DIR "app.tgz") -Force

# 复制 cmd 脚本
Get-ChildItem (Join-Path $FNOS_DIR "cmd") | ForEach-Object { Copy-Item $_.FullName (Join-Path $PKG_DIR "cmd") -Force }

# 复制 config
if (Test-Path (Join-Path $FNOS_DIR "config")) {
    Copy-Item (Join-Path $FNOS_DIR "config") (Join-Path $PKG_DIR "config") -Recurse -Force
}

# 复制 ui
if (Test-Path (Join-Path $FNOS_DIR "ui")) {
    Copy-Item (Join-Path $FNOS_DIR "ui") $PKG_DIR -Recurse -Force
}

# 复制图标
Copy-Item (Join-Path $FNOS_DIR "ICON.PNG") (Join-Path $PKG_DIR "ICON.PNG") -Force
Copy-Item (Join-Path $FNOS_DIR "ICON_256.PNG") (Join-Path $PKG_DIR "ICON_256.PNG") -Force

# 生成 ui/images/256.png
$uiImagesDir = Join-Path $PKG_DIR "ui/images"
if (!(Test-Path $uiImagesDir)) { New-Item -ItemType Directory -Path $uiImagesDir -Force | Out-Null }
Copy-Item (Join-Path $PKG_DIR "ICON_256.PNG") (Join-Path $uiImagesDir "256.png") -Force

# 5. 生成 manifest (严格按飞牛规范字段顺序)
Write-Host "[INFO] 生成 manifest ..." -ForegroundColor Green
$manifestContent = @"
appname        = cfdata
version        = $VERSION
display_name   = cfdata
service_port   = 8080
source         = local
platform       = $PLATFORM
checksum       = $checksum
"@
# 强制 Unix 换行符，无 BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $PKG_DIR "manifest"), $manifestContent, $utf8NoBom)

# 6. 验证：重新计算 app.tgz 的 checksum 并与 manifest 比对
$md5Check = [System.Security.Cryptography.MD5]::Create()
$streamCheck = [System.IO.File]::OpenRead((Join-Path $PKG_DIR "app.tgz"))
$hashCheck = $md5Check.ComputeHash($streamCheck)
$streamCheck.Close()
$checksumCheck = ($hashCheck | ForEach-Object { $_.ToString("x2") }) -join ""
if ($checksum -ne $checksumCheck) {
    Write-Host "[ERROR] checksum 不匹配！manifest=$checksum 实际=$checksumCheck" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] checksum 验证通过" -ForegroundColor Green

# 7. 确定输出文件名
$fpkName = "cfdata_" + $VERSION + "_" + $PLATFORM + ".fpk"
$fpkPath = Join-Path $ROOT $fpkName

# 8. 打包成 .fpk (tar.gz)
Write-Host "[INFO] 打包 $fpkName ..." -ForegroundColor Green
Push-Location $PKG_DIR
& tar -czf $fpkPath *
Pop-Location

# 9. 清理临时目录
Remove-Item $STAGE_DIR -Recurse -Force
Remove-Item $PKG_DIR -Recurse -Force

Write-Host "[SUCCESS] 构建完成: $fpkPath" -ForegroundColor Green
Write-Host "文件大小: $((Get-Item $fpkPath).Length) 字节" -ForegroundColor Green
Write-Host "`n安装方法：在飞牛 fnOS 应用中心 -> 左下角 '手动安装' -> 上传此 .fpk 文件`n" -ForegroundColor Cyan
