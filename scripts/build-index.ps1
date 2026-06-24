# 100일 노트에서 핵심 표현을 추출해 알파벳순 색인 사전(INDEX.md)을 생성한다.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$notesDir = Join-Path $root 'notes'
$outFile = Join-Path $root 'INDEX.md'

$entries = New-Object System.Collections.Generic.List[object]

$files = Get-ChildItem -Path $notesDir -Filter 'Day*.md' | Sort-Object Name
foreach ($f in $files) {
    $lines = Get-Content -Path $f.FullName -Encoding UTF8
    $dayNum = $null
    $titleEn = $null
    $titleKo = $null
    $inExtra = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^#\s*Day\s*(\d+)\s*[—\-]\s*(.+?)\s*$') {
            $dayNum = [int]$Matches[1]
            $titleEn = $Matches[2].Trim()
            continue
        }
        if (-not $titleKo -and $line -match '^>\s*\*\*(.+?)\*\*') {
            $titleKo = $Matches[1].Trim()
            # 제목 표현 자체를 색인 항목으로 추가
            $entries.Add([pscustomobject]@{
                En  = $titleEn
                Ko  = $titleKo
                Day = $dayNum
                IsTitle = $true
            })
            continue
        }
        if ($line -match '^##\s*기타표현 체크') { $inExtra = $true; continue }
        if ($inExtra -and $line -match '^##\s') { $inExtra = $false }

        if ($inExtra -and $line -match '^\s*-\s*\*\*(.+?)\*\*\s*(.*)$') {
            $en = $Matches[1].Trim()
            $ko = $Matches[2].Trim()
            $entries.Add([pscustomobject]@{
                En  = $en
                Ko  = $ko
                Day = $dayNum
                IsTitle = $false
            })
        }
    }
}

# 정렬 키: 선행 비문자 제거 후 소문자
function Get-SortKey([string]$s) {
    $k = $s -replace '^[^A-Za-z]+', ''
    return $k.ToLowerInvariant()
}

$sorted = $entries | Sort-Object @{Expression={Get-SortKey $_.En}}, @{Expression={$_.Day}}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# 표현 색인 사전')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 100일치 노트의 핵심 표현을 알파벳순으로 모은 색인입니다. 표현 옆 **Day NNN** 링크를 누르면 해당 노트로 이동합니다. ⭐ 표시는 그날의 대표 표현입니다.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("총 **$($sorted.Count)개** 표현 · 100일 · [README로 돌아가기](README.md)")
[void]$sb.AppendLine('')

$currentLetter = ''
foreach ($e in $sorted) {
    $key = Get-SortKey $e.En
    if ($key.Length -gt 0 -and $key[0] -match '[a-z]') {
        $letter = ([string]$key[0]).ToUpperInvariant()
    } else {
        $letter = '#'
    }
    if ($letter -ne $currentLetter) {
        $currentLetter = $letter
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("## $letter")
        [void]$sb.AppendLine('')
    }
    $dayStr = '{0:D3}' -f $e.Day
    $star = if ($e.IsTitle) { '⭐ ' } else { '' }
    $ko = if ($e.Ko) { " — $($e.Ko)" } else { '' }
    [void]$sb.AppendLine("- $star**$($e.En)**$ko · [Day $dayStr](notes/Day$dayStr.md)")
}

[void]$sb.AppendLine('')
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8)
Write-Host "Generated $outFile with $($sorted.Count) entries."
