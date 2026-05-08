$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$Version = (Get-Content (Join-Path $RootDir "VERSION") -Raw).Trim()
$ProjectPath = Join-Path $RootDir "Windows/HealthReminder.Windows/HealthReminder.Windows.csproj"
$PublishDir = Join-Path $RootDir "build/windows/win-x64"
$ReleaseDir = Join-Path $RootDir "release"
$ZipPath = Join-Path $ReleaseDir "HealthReminder-$Version-win-x64.zip"

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
if (Test-Path $PublishDir) {
    Remove-Item -Recurse -Force $PublishDir
}
if (Test-Path $ZipPath) {
    Remove-Item -Force $ZipPath
}

dotnet publish $ProjectPath `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $PublishDir `
    /p:PublishSingleFile=true `
    /p:DebugType=None `
    /p:DebugSymbols=false

Compress-Archive -Path (Join-Path $PublishDir "*") -DestinationPath $ZipPath
Write-Output $ZipPath
