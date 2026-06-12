param(
  [Parameter(Position = 0)]
  [string]$ExtensionId,

  [string]$ChromeExtensionId,

  [string]$EdgeExtensionId
)

$ErrorActionPreference = "Stop"

$HostName = "com.pi.annotate"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HostScript = Join-Path $ScriptDir "host.cjs"
$WrapperPath = Join-Path $ScriptDir "host-wrapper.cmd"
$ManifestPath = Join-Path $ScriptDir "$HostName.windows.json"
$ChromeRegistryPath = "HKCU\Software\Google\Chrome\NativeMessagingHosts\$HostName"
$EdgeRegistryPath = "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\$HostName"

if (![string]::IsNullOrWhiteSpace($ExtensionId)) {
  if ([string]::IsNullOrWhiteSpace($ChromeExtensionId)) {
    $ChromeExtensionId = $ExtensionId
  } elseif ($ChromeExtensionId -ne $ExtensionId) {
    throw "Do not pass both a positional extension id and a different -ChromeExtensionId."
  }
}

if ([string]::IsNullOrWhiteSpace($ChromeExtensionId) -and [string]::IsNullOrWhiteSpace($EdgeExtensionId)) {
  throw "Usage: .\install-windows.ps1 [-ChromeExtensionId <chrome-id>] [-EdgeExtensionId <edge-id>]"
}

if (!(Test-Path -LiteralPath $HostScript)) {
  throw "Could not find native host script: $HostScript"
}

$NodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if (!$NodeCommand) {
  throw "Could not find node.exe in PATH. Install Node.js or run this script from a shell where node.exe is available."
}

$NodePath = $NodeCommand.Source
Write-Host "Using node at: $NodePath"

$WrapperContent = @"
@echo off
"$NodePath" "$HostScript" %*
"@

Set-Content -LiteralPath $WrapperPath -Value $WrapperContent -Encoding ASCII
Write-Host "Created native host wrapper: $WrapperPath"

$AllowedOrigins = @($ChromeExtensionId, $EdgeExtensionId) |
  Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
  Select-Object -Unique |
  ForEach-Object { "chrome-extension://$_/" }

$Manifest = [ordered]@{
  name = $HostName
  description = "Pi Annotate native messaging host"
  path = $WrapperPath
  type = "stdio"
  allowed_origins = @($AllowedOrigins)
}

$ManifestJson = ($Manifest | ConvertTo-Json -Depth 4) + [Environment]::NewLine
$Utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
[System.IO.File]::WriteAllText($ManifestPath, $ManifestJson, $Utf8NoBom)
Write-Host "Created native host manifest: $ManifestPath"

if (![string]::IsNullOrWhiteSpace($ChromeExtensionId)) {
  & reg.exe add $ChromeRegistryPath /ve /t REG_SZ /d $ManifestPath /f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to write Chrome native messaging registry key: $ChromeRegistryPath"
  }
  Write-Host "Registered Chrome native host at: $ChromeRegistryPath"
}

if (![string]::IsNullOrWhiteSpace($EdgeExtensionId)) {
  & reg.exe add $EdgeRegistryPath /ve /t REG_SZ /d $ManifestPath /f | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to write Edge native messaging registry key: $EdgeRegistryPath"
  }
  Write-Host "Registered Edge native host at: $EdgeRegistryPath"
}

Write-Host ""
Write-Host "Fully quit and reopen the browser, then click the Pi Annotate icon to check the connection."
