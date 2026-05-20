$repoPath = $PSScriptRoot
$branch   = "master"
$interval = 10  # segundos entre checks

Set-Location $repoPath
Write-Host "AutoPull iniciado en '$repoPath' (rama: $branch, intervalo: ${interval}s)"
Write-Host "Ctrl+C para detener.`n"

while ($true) {
    git fetch origin $branch --quiet 2>$null

    $local  = git rev-parse HEAD
    $remote = git rev-parse "origin/$branch"

    if ($local -ne $remote) {
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] Cambios detectados, haciendo pull..."

        $result = git pull origin $branch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$ts] Pull OK — Rojo actualizando Studio..."
        } else {
            Write-Host "[$ts] ERROR en pull (conflicto?): $result"
        }
    }

    Start-Sleep -Seconds $interval
}
