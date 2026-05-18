# claude-status-line installer
# Usage: irm https://raw.githubusercontent.com/marcosbrigante/claude-status-line/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoRaw     = 'https://raw.githubusercontent.com/marcosbrigante/claude-status-line/main'
$ScriptUrl   = "$RepoRaw/statusline.ps1"
$ClaudeDir   = Join-Path $HOME '.claude'
$ScriptPath  = Join-Path $ClaudeDir 'statusline.ps1'
$SettingsPath = Join-Path $ClaudeDir 'settings.json'

if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir | Out-Null
    Write-Host "Created $ClaudeDir"
}

Write-Host "Downloading statusline.ps1..."
$content = Invoke-RestMethod -Uri $ScriptUrl
Set-Content -LiteralPath $ScriptPath -Value $content -Encoding UTF8
Write-Host "Installed $ScriptPath"

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
if (-not $pwshPath) {
    Write-Warning "pwsh (PowerShell 7+) not found on PATH. The statusline uses unicode chars that need pwsh, not powershell.exe (5.1)."
    Write-Warning "Install from: https://aka.ms/powershell"
    $shellCmd = 'powershell'
} else {
    $shellCmd = 'pwsh'
}

$scriptPathForward = $ScriptPath.Replace('\','/')
$newStatusLine = [ordered]@{
    type    = 'command'
    command = "$shellCmd -NoProfile -ExecutionPolicy Bypass -File $scriptPathForward"
    padding = 0
}

if (Test-Path $SettingsPath) {
    $raw = Get-Content -LiteralPath $SettingsPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $settings = [ordered]@{}
    } else {
        $settings = $raw | ConvertFrom-Json -AsHashtable
        if ($settings -isnot [System.Collections.IDictionary]) {
            throw "Existing settings.json is not a JSON object."
        }
    }
} else {
    $settings = [ordered]@{}
}

$settings['statusLine'] = $newStatusLine

$json = $settings | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $SettingsPath -Value $json -Encoding UTF8
Write-Host "Patched $SettingsPath (statusLine key)"

Write-Host ""
Write-Host "Done. Restart your Claude Code session to see the statusline." -ForegroundColor Green
