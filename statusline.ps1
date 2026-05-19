$ErrorActionPreference = 'SilentlyContinue'
$input_json = [Console]::In.ReadToEnd()
$ctx = $input_json | ConvertFrom-Json

$transcript = $ctx.transcript_path
$modelName  = $ctx.model.display_name
$cwd        = $ctx.workspace.current_dir
if (-not $cwd) { $cwd = $ctx.cwd }

# Pricing per million tokens (USD) — approximate, flat-rate
if     ($modelName -match 'Opus')   { $pIn=15;   $pOut=75;  $pCacheR=1.5;  $pCacheW=18.75 }
elseif ($modelName -match 'Sonnet') { $pIn=3;    $pOut=15;  $pCacheR=0.3;  $pCacheW=3.75 }
elseif ($modelName -match 'Haiku')  { $pIn=0.8;  $pOut=4;   $pCacheR=0.08; $pCacheW=1.0 }
else                                { $pIn=15;   $pOut=75;  $pCacheR=1.5;  $pCacheW=18.75 }

$limit = if ($modelName -match 'Opus') { 1000000 } else { 200000 }

$tokens  = 0
$cost    = 0.0
$firstTs = $null
$lastTs  = $null

if ($transcript -and (Test-Path $transcript)) {
    $allLines = [IO.File]::ReadAllLines($transcript)
    foreach ($line in $allLines) {
        try {
            $obj = $line | ConvertFrom-Json
            if ($obj.timestamp) {
                if (-not $firstTs) { $firstTs = $obj.timestamp }
                $lastTs = $obj.timestamp
            }
            $u = $obj.message.usage
            if ($u) {
                $i  = [int]$u.input_tokens
                $o  = [int]$u.output_tokens
                $cr = [int]$u.cache_read_input_tokens
                $cw = [int]$u.cache_creation_input_tokens
                $cost += ($i*$pIn + $o*$pOut + $cr*$pCacheR + $cw*$pCacheW) / 1000000.0
            }
        } catch {}
    }
    [Array]::Reverse($allLines)
    foreach ($line in $allLines) {
        try {
            $obj = $line | ConvertFrom-Json
            $u = $obj.message.usage
            if ($u) {
                $tokens = [int]$u.input_tokens + [int]$u.cache_creation_input_tokens + [int]$u.cache_read_input_tokens
                break
            }
        } catch {}
    }
}

$durStr = ""
if ($firstTs -and $lastTs) {
    try {
        $span = [DateTime]::Parse($lastTs) - [DateTime]::Parse($firstTs)
        if     ($span.TotalHours -ge 1)   { $durStr = "{0}h{1:00}m" -f [int]$span.TotalHours, $span.Minutes }
        elseif ($span.TotalMinutes -ge 1) { $durStr = "{0}m" -f [int]$span.TotalMinutes }
        else                              { $durStr = "{0}s" -f [int]$span.TotalSeconds }
    } catch {}
}

$branch = ""
$gitStatus = ""
if ($cwd -and (Test-Path $cwd)) {
    $gitMarker = Join-Path $cwd ".git"
    if (Test-Path $gitMarker) {
        $gitOut = (& git -C $cwd status --porcelain=v1 --branch 2>$null)
        if ($gitOut) {
            $lines = @($gitOut)
            $header = $lines[0]
            if ($header -match '^## (?:Initial commit on |No commits yet on )?(\S+?)(?:\.\.\.\S+)?(?: \[(.+)\])?$') {
                $branch = $matches[1]
                $tracking = $matches[2]
                if ($tracking) {
                    if ($tracking -match 'ahead (\d+)')  { $gitStatus += "+" + $matches[1] }
                    if ($tracking -match 'behind (\d+)') { $gitStatus += "-" + $matches[1] }
                }
            } elseif ($header -match '^## HEAD') {
                $branch = "detached"
            }
            if ($lines.Count -gt 1) { $gitStatus = "*" + $gitStatus }
        }
    }
}

$pct = if ($tokens -gt 0) { [math]::Round(($tokens / $limit) * 100, 1) } else { 0 }
$tok_k = if ($tokens -ge 1000) { "{0:N1}k" -f ($tokens / 1000) } else { "$tokens" }
$lim_k = if ($limit -ge 1000) { "{0}k" -f [int]($limit / 1000) } else { "$limit" }

$barFill = [int][math]::Floor($pct / 10)
if ($barFill -gt 10) { $barFill = 10 }
if ($barFill -lt 0)  { $barFill = 0 }
$bar = "[" + ("#" * $barFill) + ("." * (10 - $barFill)) + "]"

$esc = [char]27
$reset   = "$esc[0m"
$cyan    = "$esc[38;2;125;207;255m"  # #7dcfff
$magenta = "$esc[38;2;187;154;247m"  # #bb9af7
$dim     = "$esc[2m"
$bold    = "$esc[1m"

$color_pct = if ($pct -ge 60) { "$esc[38;2;187;154;247m" }   # purple
              elseif ($pct -ge 40) { "$esc[38;2;247;118;142m" }  # red
              elseif ($pct -ge 30) { "$esc[38;2;255;158;100m" }  # orange
              elseif ($pct -ge 20) { "$esc[38;2;224;175;104m" }  # yellow
              else { "$esc[38;2;158;206;106m" }                  # green

$dir = Split-Path -Leaf $cwd
$sep = "$cyan|$reset"

$parts = @()

$dirPart = "$cyan$dir$reset"
if ($branch) {
    $dirPart += " on $magenta$branch$gitStatus$reset"
}
$parts += $dirPart

$parts += "$bold$modelName$reset"

if ($cost -gt 0) {
    $costStr = if ($cost -ge 1) { "{0:N2}" -f $cost } else { "{0:N3}" -f $cost }
    $parts += "$cyan`$$costStr$reset"
}

if ($durStr) {
    $parts += "$dim$durStr$reset"
}

$parts += "$color_pct$tok_k/$lim_k $bar $pct%$reset"

$parts -join " $sep "
