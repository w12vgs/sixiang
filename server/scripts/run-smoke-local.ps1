# Local smoke test for restricted sandbox / no-Docker environments.
# Uses the PG18 binaries bundled with @embedded-postgres/windows-x64 to run a
# temporary instance, executes the API smoke test, then cleans up.
# On normal dev machines just use: npm run smoke
# Usage (from server/): & .\scripts\run-smoke-local.ps1
$ErrorActionPreference = 'Continue'

$env:npm_config_cache = (Join-Path (Get-Location) '.npm-cache')
$bin = Join-Path (Get-Location) 'node_modules/@embedded-postgres/windows-x64/native/bin'
$pgdata = Join-Path (Get-Location) '.pgdata'
$log = Join-Path (Get-Location) 'initdb.log'

if (-not (Test-Path $bin)) { throw "PG binaries not found. Run npm install first." }
if (Test-Path $pgdata) { Remove-Item -Recurse -Force $pgdata }

# 1. Initialize data directory
& "$bin\initdb.exe" -D $pgdata -U postgres -A trust -E UTF8 --no-locale *> $log
if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 15; throw "initdb failed: $LASTEXITCODE" }
Write-Output "initdb OK"

# 2. Start postgres (paths with spaces must be quoted)
$quoted = '"' + $pgdata + '"'
$proc = Start-Process -FilePath "$bin\postgres.exe" -ArgumentList @('-D', $quoted, '-p', '5433') -PassThru -WindowStyle Hidden

try {
  $ready = $false
  foreach ($i in 1..15) {
    Start-Sleep -Seconds 1
    if ($proc.HasExited) { throw "postgres exited early: $($proc.ExitCode)" }
    try {
      $tcp = New-Object Net.Sockets.TcpClient
      $tcp.Connect('localhost', 5433)
      $tcp.Close()
      $ready = $true
      break
    } catch { }
  }
  if (-not $ready) { throw "postgres not ready" }
  Write-Output "postgres ready (TCP 5433)"

  # 3. Run smoke test
  $env:SIXIANG_DB_URL = 'postgresql://postgres@localhost:5433/postgres'
  node scripts/smoke.mjs
  if ($LASTEXITCODE -ne 0) { throw "smoke failed: $LASTEXITCODE" }
  Write-Output "SMOKE PASSED"
} finally {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $pgdata -ErrorAction SilentlyContinue
  Remove-Item $log -ErrorAction SilentlyContinue
}
