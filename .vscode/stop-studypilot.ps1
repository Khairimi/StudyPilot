# Safety net: stops the Flutter server listening on port 5000 and its child
# processes. Pressing q in the Flutter terminal is the normal way to stop it.
# Anything on the port that is not a Flutter server is left alone.
$port = 5000

$listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)

if ($listeners.Count -eq 0) {
    Write-Host "StudyPilot: nothing is running on port $port."
    exit 0
}

foreach ($id in $listeners) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$id"
    if ($process.CommandLine -notmatch 'flutter_tools') {
        Write-Host "StudyPilot: port $port is used by $($process.Name) (PID $id), which is not a Flutter server. Left alone." -ForegroundColor Yellow
        continue
    }

    # Start from the outermost Flutter launcher so the whole tree stops.
    $top = $process
    while ($true) {
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($top.ParentProcessId)"
        if (-not $parent -or $parent.CommandLine -notmatch 'flutter') { break }
        $top = $parent
    }
    taskkill /PID $top.ProcessId /T /F | Out-Null
    Write-Host "StudyPilot: stopped the Flutter server on port $port."
}
