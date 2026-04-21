param(
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
}
Set-Location -LiteralPath $scriptRoot

$envPath = Join-Path -Path $scriptRoot -ChildPath ".env"
if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Fayl .env ne nayden v papke proekta."
}

function Get-EnvValue {
    param(
        [string]$Key,
        [string]$Default = ""
    )

    $pattern = "^\s*$([Regex]::Escape($Key))\s*=\s*(.*)\s*$"
    foreach ($line in Get-Content -LiteralPath $envPath -Encoding UTF8) {
        if ($line -match "^\s*#") {
            continue
        }
        if ($line -match $pattern) {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $Default
}

function Set-EnvValue {
    param(
        [string]$Key,
        [string]$Value
    )

    $lines = @()
    if (Test-Path -LiteralPath $envPath) {
        $lines = Get-Content -LiteralPath $envPath -Encoding UTF8
    }

    $pattern = "^\s*$([Regex]::Escape($Key))\s*="
    $updated = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $lines[$i] = "$Key=$Value"
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $lines += "$Key=$Value"
    }

    $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $envPath,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$cloudflaredCmd = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cloudflaredCmd) {
    throw "Ne nashol cloudflared. Ustanovi cloudflared i povtori zapusk."
}

$portRaw = Get-EnvValue -Key "MINI_APP_PORT" -Default "8080"
$port = 8080
[void][int]::TryParse($portRaw, [ref]$port)

$tunnelOut = Join-Path -Path $scriptRoot -ChildPath "miniapp_tunnel_out.log"
$tunnelErr = Join-Path -Path $scriptRoot -ChildPath "miniapp_tunnel_err.log"
if (Test-Path -LiteralPath $tunnelOut) { Remove-Item -LiteralPath $tunnelOut -Force }
if (Test-Path -LiteralPath $tunnelErr) { Remove-Item -LiteralPath $tunnelErr -Force }

$urlLocal = "http://127.0.0.1:$port"
$tunnelProc = $null

try {
    $tunnelProc = Start-Process `
        -FilePath $cloudflaredCmd.Source `
        -ArgumentList @("tunnel", "--url", $urlLocal, "--no-autoupdate") `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $tunnelOut `
        -RedirectStandardError $tunnelErr

    $regex = "https://[a-z0-9-]+\.trycloudflare\.com"
    $miniAppUrl = $null
    $deadline = (Get-Date).AddSeconds(60)

    while ((Get-Date) -lt $deadline -and -not $miniAppUrl) {
        Start-Sleep -Milliseconds 500

        foreach ($logPath in @($tunnelOut, $tunnelErr)) {
            if (-not (Test-Path -LiteralPath $logPath)) {
                continue
            }
            foreach ($line in Get-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue) {
                if ($line -match $regex) {
                    $miniAppUrl = $Matches[0]
                }
            }
        }

        if ($tunnelProc.HasExited -and -not $miniAppUrl) {
            break
        }
    }

    if (-not $miniAppUrl) {
        $outLogText = ""
        $errLogText = ""
        if (Test-Path -LiteralPath $tunnelOut) {
            $outLogText = Get-Content -LiteralPath $tunnelOut -Raw -Encoding UTF8
        }
        if (Test-Path -LiteralPath $tunnelErr) {
            $errLogText = Get-Content -LiteralPath $tunnelErr -Raw -Encoding UTF8
        }
        throw "Ne poluchilos poluchit public-ssylku Cloudflare.`nOUT:`n$outLogText`nERR:`n$errLogText"
    }

    Set-EnvValue -Key "MINI_APP_BASE_URL" -Value $miniAppUrl
    Write-Host "MINI_APP_BASE_URL obnovlen: $miniAppUrl"
    Write-Host "Zapusk bota..."

    & $PythonExe "main.py"
    exit $LASTEXITCODE
}
finally {
    if ($tunnelProc -and -not $tunnelProc.HasExited) {
        Stop-Process -Id $tunnelProc.Id -Force -ErrorAction SilentlyContinue
    }
}
