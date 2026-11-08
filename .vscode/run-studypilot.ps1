# Runs the full StudyPilot app on localhost:5000 in this terminal (r = hot
# reload, R = hot restart, q = quit). Once the app has compiled, it opens one
# tab in Chrome Profile 1 (student.uitm.edu.my) if no StudyPilot tab exists, or
# tells you to refresh the existing tab.
#
# Refuses to start if port 5000 is already taken, so it cannot create a
# duplicate server.
#
# Chrome is only looked at, through Windows UI Automation: tab titles are read
# from the tab strip, and pages, cookies and focus are not touched. Windows can
# see titles but not URLs, so a tab counts as StudyPilot when its title is
# exactly "StudyPilot" (or "localhost", Chrome's title when the server was down).
# Existing tabs are never refreshed automatically: that would need focus and
# keystrokes, which could land in the wrong tab or the ChatGPT sidebar.

$port = 5000
$url = "http://localhost:$port"

Set-Location (Split-Path $PSScriptRoot -Parent)

if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "StudyPilot: port $port is already in use, so no new server was started." -ForegroundColor Yellow
    Write-Host "Use the running server, or run the task 'StudyPilot: stop server (port $port)' first." -ForegroundColor Yellow
    exit 1
}

# Runs alongside Flutter inside this process, so it can write to this terminal
# and ends together with it, leaving nothing behind.
$helper = [powershell]::Create().AddScript({
    param($url)

    function Write-Status($text) { [Console]::WriteLine("StudyPilot: $text") }

    # Returns the number of StudyPilot tabs, or -1 if Chrome could not be read.
    function Get-StudyPilotTabCount {
        Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
        $element = [System.Windows.Automation.AutomationElement]
        $controlType = [System.Windows.Automation.ControlType]
        $treeWalker = [System.Windows.Automation.TreeWalker]::ControlViewWalker

        $chromeIds = @{}
        Get-Process chrome -ErrorAction SilentlyContinue | ForEach-Object { $chromeIds[$_.Id] = $true }
        $isChromeWindow = New-Object System.Windows.Automation.PropertyCondition($element::ClassNameProperty, 'Chrome_WidgetWin_1')
        $windows = @($element::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $isChromeWindow) |
            Where-Object { $chromeIds[$_.Current.ProcessId] -and $_.Current.Name })
        if ($windows.Count -eq 0) { return 0 }

        $script:allTabs = 0
        $script:matchingTabs = 0
        function Search-Tabs($parent, $depth) {
            if ($depth -gt 14) { return }
            $child = $treeWalker.GetFirstChild($parent)
            while ($child) {
                $type = $child.Current.ControlType
                if ($type -eq $controlType::TabItem) {
                    $script:allTabs++
                    if ($child.Current.Name -match '^(StudyPilot|localhost)$') { $script:matchingTabs++ }
                } elseif ($type -ne $controlType::Document) {
                    # Web page content is skipped: only the browser's tab strip is read.
                    Search-Tabs $child ($depth + 1)
                }
                $child = $treeWalker.GetNextSibling($child)
            }
        }
        foreach ($window in $windows) { Search-Tabs $window 0 }

        if ($script:allTabs -eq 0) { return -1 }
        return $script:matchingTabs
    }

    # Wait until the app has compiled. Until then Flutter answers this file
    # with 404, or other paths with HTML, which would leave a blank page.
    $ready = $false
    $deadline = (Get-Date).AddMinutes(3)
    while (-not $ready -and (Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri "$url/packages/study_app/main.dart.lib.js" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200 -and $response.Headers['Content-Type'] -match 'javascript') {
                $ready = $true
            } else {
                Start-Sleep -Milliseconds 500
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $ready) {
        Write-Status "the app was not ready after 3 minutes, so Chrome was left unchanged."
        return
    }

    try { $tabCount = Get-StudyPilotTabCount } catch { $tabCount = -1 }

    if ($tabCount -eq 0) {
        $chrome = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
        Start-Process -FilePath $chrome -ArgumentList '--profile-directory="Profile 1"', $url
        Write-Status "app compiled. Opened one tab in Chrome School."
    } elseif ($tabCount -eq 1) {
        Write-Status "app compiled. Press Ctrl+Shift+R in your existing StudyPilot tab to load it."
    } elseif ($tabCount -gt 1) {
        Write-Status "app compiled. Found $tabCount StudyPilot tabs: press Ctrl+Shift+R in one and close the others."
    } else {
        Write-Status "app compiled, but Chrome's tabs could not be read, so none were opened."
        Write-Status "Refresh your StudyPilot tab, or open $url in Chrome School."
    }
}).AddArgument($url)
[void]$helper.BeginInvoke()

Write-Host "StudyPilot: starting on $url. You will see a message here when the app has compiled."
Write-Host "Click in this terminal, then press r (hot reload), R (hot restart) or q (quit)."

flutter run -d web-server --web-port $port --web-hostname localhost
exit $LASTEXITCODE
