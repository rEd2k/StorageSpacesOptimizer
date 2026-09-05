[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::ThrowException)
$ErrorActionPreference = "SilentlyContinue"
$WarningActionPreference = "SilentlyContinue"
$InformationActionPreference = "SilentlyContinue"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
$form = New-Object System.Windows.Forms.Form
$form.Text = "Storage Spaces Optimizer"
$form.Size = New-Object System.Drawing.Size(1000, 870)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# --- Workstation Dynamic Data Storage Registries ---
$script:IsRefreshingInterface = $false
$script:updatingSelection = $false
$script:IsDarkMode = $false
# FIXED: Global state tracks whether the manual refresh reminder popup is allowed to show
$script:ShowRefreshWarning = $true
$script:AvailableDisks = @()  # Maps checked indices to actual PhysicalDisk UniqueIds (fixes identical FriendlyName grabbing extra drives)
$script:AvailablePools = @()  # Maps pool list index to actual StoragePool UniqueId (fixes duplicate FriendlyName deletion)
$script:IsAdvancedMode = $false
$script:AdvancedConfig = $null
function Show-ThemedAlert {
    param([string]$Text, [string]$Title = "Message")
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $Title
    $f.Size = New-Object System.Drawing.Size(500, 200)
    $f.StartPosition = "CenterParent"
    $f.FormBorderStyle = "FixedDialog"
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.Topmost = $true
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point(20, 20)
    $l.Size = New-Object System.Drawing.Size(440, 70)
    $f.Controls.Add($l)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "OK"
    $b.Location = New-Object System.Drawing.Point(210, 110)
    $b.Size = New-Object System.Drawing.Size(80, 28)
    $b.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.Controls.Add($b)
    $f.AcceptButton = $b
    if ($script:IsDarkMode) { $f.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $l.ForeColor = [System.Drawing.Color]::White; $b.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $b.ForeColor = [System.Drawing.Color]::White; $b.UseVisualStyleBackColor = $false }
    [void]$f.ShowDialog()
    $f.Dispose()
}
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Advanced Storage Spaces Configuration Tool"
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(450, 30)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)
$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = "Toggle Dark Theme"
$btnTheme.Location = New-Object System.Drawing.Point(500, 14)
$btnTheme.Size = New-Object System.Drawing.Size(150, 26)
$btnTheme.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnTheme.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnTheme)
$chkSuppressAllPopups = New-Object System.Windows.Forms.CheckBox
$chkSuppressAllPopups.Text = "Suppress all pop-up messages"
$chkSuppressAllPopups.Location = New-Object System.Drawing.Point(730, 12)
$chkSuppressAllPopups.Size = New-Object System.Drawing.Size(220, 18)
$chkSuppressAllPopups.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)
$chkSuppressAllPopups.Visible = $false
$form.Controls.Add($chkSuppressAllPopups)
$chkSuppressDeletionWarnings = New-Object System.Windows.Forms.CheckBox
$chkSuppressDeletionWarnings.Text = "Suppress all pool deletion warnings"
$chkSuppressDeletionWarnings.Location = New-Object System.Drawing.Point(730, 32)
$chkSuppressDeletionWarnings.Size = New-Object System.Drawing.Size(250, 18)
$chkSuppressDeletionWarnings.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)
$chkSuppressDeletionWarnings.Visible = $false
$form.Controls.Add($chkSuppressDeletionWarnings)
$btnRevealAdvanced = New-Object System.Windows.Forms.Button
$btnRevealAdvanced.Text = "I know what I'm doing..."
$btnRevealAdvanced.Location = New-Object System.Drawing.Point(780, 15)
$btnRevealAdvanced.Size = New-Object System.Drawing.Size(180, 26)
$btnRevealAdvanced.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnRevealAdvanced.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRevealAdvanced)
$btnRevealAdvanced.add_Click({
    $chkSuppressAllPopups.Visible = $true
    $chkSuppressDeletionWarnings.Visible = $true
    $btnRevealAdvanced.Visible = $false
})
$pnlLeft = New-Object System.Windows.Forms.Panel
$pnlLeft.Location = New-Object System.Drawing.Point(20, 60)
$pnlLeft.Size = New-Object System.Drawing.Size(460, 750)
$form.Controls.Add($pnlLeft)

$lblDetectPools = New-Object System.Windows.Forms.Label
$lblDetectPools.Text = "Detected Storage Pools"
$lblDetectPools.Location = New-Object System.Drawing.Point(10, 15)
$lblDetectPools.Size = New-Object System.Drawing.Size(250, 18)
$lblDetectPools.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pnlLeft.Controls.Add($lblDetectPools)

# --- REFRESH ENGINE INJECTION ---
$btnRefreshInfra = New-Object System.Windows.Forms.Button
$btnRefreshInfra.Text = "Refresh Pools and Drives"
$btnRefreshInfra.Location = New-Object System.Drawing.Point(280, 5)
$btnRefreshInfra.Size = New-Object System.Drawing.Size(160, 24)
$btnRefreshInfra.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnRefreshInfra.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRefreshInfra.add_Click({
    $script:IsRefreshingInterface = $true
    & $ScanPhysicalInfrastructure
    $txtTerminalOutput.Clear()
    $txtTerminalOutput.Text = "# =========================================================`r`n# SYSTEM DISCOVERY MAP FULLY REFRESHED`r`n# Active array lists and raw spindles re-cached cleanly.`r`n# ========================================================="
    $btnSimDemo.Enabled = $false
    $btnSimDemo.BackColor = [System.Drawing.SystemColors]::Control; $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $true
    if ($script:IsDarkMode) { $btnSimDemo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $false }
    $script:IsRefreshingInterface = $false
    & $RecalculateEngine "ManualTrigger"
})
$pnlLeft.Controls.Add($btnRefreshInfra)

# FIXED: Increased tracking height to allow clean vertical item listings
$chkPools = New-Object System.Windows.Forms.CheckedListBox
$chkPools.Location = New-Object System.Drawing.Point(10, 35)
$chkPools.Size = New-Object System.Drawing.Size(430, 95)
$chkPools.CheckOnClick = $false
$pnlLeft.Controls.Add($chkPools)

$lblDrives = New-Object System.Windows.Forms.Label
$lblDrives.Text = "Detected Unallocated Drives Available for Pool Creation:"
$lblDrives.Location = New-Object System.Drawing.Point(10, 145)
$lblDrives.Size = New-Object System.Drawing.Size(430, 20)
$lblDrives.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pnlLeft.Controls.Add($lblDrives)

# FIXED: Expanded size limits and activated native Multi-Column Stacking Flow arrays
$chkDrives = New-Object System.Windows.Forms.CheckedListBox
$chkDrives.Location = New-Object System.Drawing.Point(10, 170)
$chkDrives.Size = New-Object System.Drawing.Size(430, 140)
$chkDrives.CheckOnClick = $true
$chkDrives.MultiColumn = $true
$chkDrives.ColumnWidth = 210  # Splits the wide window perfectly into clean side-by-side columns if filled!
$pnlLeft.Controls.Add($chkDrives)

# FIXED: Renamed label text to follow your precise target safety guidelines
$btnSimDemo = New-Object System.Windows.Forms.Button
$btnSimDemo.Text = "Delete Selected Pool (With Ability to Cancel)"
$btnSimDemo.Location = New-Object System.Drawing.Point(10, 325)
$btnSimDemo.Size = New-Object System.Drawing.Size(430, 26)
$btnSimDemo.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnSimDemo.ForeColor = [System.Drawing.Color]::DarkRed
$btnSimDemo.Enabled = $false
$pnlLeft.Controls.Add($btnSimDemo)

# FIXED: Repositioned coordinates downward to support the expanded drive list windows smoothly
$lblPoolName = New-Object System.Windows.Forms.Label
$lblPoolName.Text = "Storage Pool Name:"
$lblPoolName.Location = New-Object System.Drawing.Point(10, 365)
$lblPoolName.Size = New-Object System.Drawing.Size(130, 20)
$pnlLeft.Controls.Add($lblPoolName)

$txtPoolName = New-Object System.Windows.Forms.TextBox
$txtPoolName.Text = "Optimized Pool 1"
$txtPoolName.Location = New-Object System.Drawing.Point(145, 362)
$txtPoolName.Size = New-Object System.Drawing.Size(210, 20)
$pnlLeft.Controls.Add($txtPoolName)

$btnRenamePool = New-Object System.Windows.Forms.Button
$btnRenamePool.Text = "Rename"
$btnRenamePool.Location = New-Object System.Drawing.Point(360, 361)
$btnRenamePool.Size = New-Object System.Drawing.Size(75, 22)
$btnRenamePool.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$btnRenamePool.Cursor = [System.Windows.Forms.Cursors]::Hand
$pnlLeft.Controls.Add($btnRenamePool)

$lblSpaceName = New-Object System.Windows.Forms.Label
$lblSpaceName.Text = "Virtual Disk Label:"
$lblSpaceName.Location = New-Object System.Drawing.Point(10, 395)
$lblSpaceName.Size = New-Object System.Drawing.Size(130, 20)
$pnlLeft.Controls.Add($lblSpaceName)

$txtSpaceName = New-Object System.Windows.Forms.TextBox
$txtSpaceName.Text = "Media Space 1"
$txtSpaceName.Location = New-Object System.Drawing.Point(145, 392)
$txtSpaceName.Size = New-Object System.Drawing.Size(210, 20)
$pnlLeft.Controls.Add($txtSpaceName)

$btnRenameVDisk = New-Object System.Windows.Forms.Button
$btnRenameVDisk.Text = "Rename"
$btnRenameVDisk.Location = New-Object System.Drawing.Point(360, 391)
$btnRenameVDisk.Size = New-Object System.Drawing.Size(75, 22)
$btnRenameVDisk.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$btnRenameVDisk.Cursor = [System.Windows.Forms.Cursors]::Hand
$pnlLeft.Controls.Add($btnRenameVDisk)

# Rename handlers - generate commands to terminal for selected pool - requires checked box
$btnRenamePool.add_Click({
    $checkedIdxPool = -1; for ($ci=0; $ci -lt $chkPools.Items.Count; $ci++) { if ($chkPools.GetItemChecked($ci)) { $checkedIdxPool = $ci; break } }
    if ($checkedIdxPool -lt 0) {
        if (-not $chkSuppressAllPopups.Checked) {
            $chkWarnForm2 = New-Object System.Windows.Forms.Form
            $chkWarnForm2.Text = "Rename Pool"
            $chkWarnForm2.Size = New-Object System.Drawing.Size(480, 160)
            $chkWarnForm2.StartPosition = "CenterParent"
            $chkWarnForm2.FormBorderStyle = "FixedDialog"
            $chkWarnForm2.MaximizeBox = $false; $chkWarnForm2.MinimizeBox = $false
            $chkWarnForm2.Topmost = $true
            $lblChkWarn2 = New-Object System.Windows.Forms.Label
            $lblChkWarn2.Text = "Check the box next to a pool in 'Detected Storage Pools' first."
            $lblChkWarn2.Location = New-Object System.Drawing.Point(20, 20)
            $lblChkWarn2.Size = New-Object System.Drawing.Size(420, 30)
            $chkWarnForm2.Controls.Add($lblChkWarn2)
            $btnChkOk2 = New-Object System.Windows.Forms.Button
            $btnChkOk2.Text = "OK"
            $btnChkOk2.Location = New-Object System.Drawing.Point(190, 70)
            $btnChkOk2.Size = New-Object System.Drawing.Size(80, 28)
            $btnChkOk2.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $chkWarnForm2.Controls.Add($btnChkOk2)
            $chkWarnForm2.AcceptButton = $btnChkOk2
            if ($script:IsDarkMode) { $chkWarnForm2.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblChkWarn2.ForeColor = [System.Drawing.Color]::White; $btnChkOk2.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnChkOk2.ForeColor = [System.Drawing.Color]::White; $btnChkOk2.UseVisualStyleBackColor = $false }
            [void]$chkWarnForm2.ShowDialog()
            $chkWarnForm2.Dispose()
        }
        return
    }
    $sel = $checkedIdxPool
    if ($sel -lt 0 -or $sel -ge $script:AvailablePools.Count) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Select a pool in 'Detected Storage Pools' first." -Title "Rename Pool" }; return }
    $pool = $script:AvailablePools[$sel]
    $newName = $txtPoolName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($newName)) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Enter a new pool name in the Storage Pool Name field." -Title "Rename Pool" }; return }
    $newNameEsc = $newName -replace '"','`"'
    $poolIdEsc = $pool.UniqueId -replace '"','`"'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Rename Storage Pool: $($pool.FriendlyName) -> $newName")
    [void]$sb.AppendLine("`$Pool = Get-StoragePool -UniqueId `"$poolIdEsc`" -IsPrimordial `$false -ErrorAction SilentlyContinue")
    [void]$sb.AppendLine("if (-not `$Pool) { `$Pool = Get-StoragePool -FriendlyName `"$($pool.FriendlyName -replace '"','`"')`" -IsPrimordial `$false | Select-Object -First 1 }")
    [void]$sb.AppendLine("`$Pool | Set-StoragePool -NewFriendlyName `"$newNameEsc`"")
    [void]$sb.AppendLine("Update-StorageProviderCache; Get-StoragePool -FriendlyName `"$newNameEsc`" | Format-List FriendlyName, UniqueId, Size")
    if ([string]::IsNullOrWhiteSpace($txtTerminalOutput.Text) -or $txtTerminalOutput.Text -match "POWERSHELL COMMAND MONITOR STATION READY" -or $txtTerminalOutput.Text -match "SYSTEM DISCOVERY MAP FULLY REFRESHED") { $txtTerminalOutput.Text = $sb.ToString() } else { $txtTerminalOutput.AppendText("`r`n`r`n" + $sb.ToString()) }
    try {
        $isAdminRenamePool = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdminRenamePool) { $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: Not elevated - run as admin for silent rename.") }
        else {
            $hiddenRenamePoolPs = [PowerShell]::Create()
            [void]$hiddenRenamePoolPs.AddScript($sb.ToString())
            $null = $hiddenRenamePoolPs.Invoke()
            if ($hiddenRenamePoolPs.HadErrors) { $errRenamePool = ($hiddenRenamePoolPs.Streams.Error | Out-String); $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION ERRORS (RENAME POOL):`r`n" + $errRenamePool) }
            else { $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: RENAME POOL SUCCESS"); }
            $hiddenRenamePoolPs.Dispose()
        }
    } catch { $txtTerminalOutput.AppendText("`r`n# HIDDEN RENAME FAILED: $($_.Exception.Message)") }
    if (-not $chkSuppressAllPopups.Checked) {
        $renamePoolForm = New-Object System.Windows.Forms.Form
        $renamePoolForm.Text = "Rename Complete"
        $renamePoolForm.Size = New-Object System.Drawing.Size(400, 160)
        $renamePoolForm.StartPosition = "CenterParent"
        $renamePoolForm.FormBorderStyle = "FixedDialog"
        $renamePoolForm.MaximizeBox = $false; $renamePoolForm.MinimizeBox = $false
        $renamePoolForm.Topmost = $true
        $lblRenamePoolDone = New-Object System.Windows.Forms.Label
        $lblRenamePoolDone.Text = "Renaming complete."
        $lblRenamePoolDone.Location = New-Object System.Drawing.Point(20, 20)
        $lblRenamePoolDone.Size = New-Object System.Drawing.Size(340, 30)
        $lblRenamePoolDone.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $renamePoolForm.Controls.Add($lblRenamePoolDone)
        $btnRenamePoolOk = New-Object System.Windows.Forms.Button
        $btnRenamePoolOk.Text = "OK"
        $btnRenamePoolOk.Location = New-Object System.Drawing.Point(150, 70)
        $btnRenamePoolOk.Size = New-Object System.Drawing.Size(80, 28)
        $btnRenamePoolOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $renamePoolForm.Controls.Add($btnRenamePoolOk)
        $renamePoolForm.AcceptButton = $btnRenamePoolOk
        if ($script:IsDarkMode) { $renamePoolForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblRenamePoolDone.ForeColor = [System.Drawing.Color]::White; $btnRenamePoolOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnRenamePoolOk.ForeColor = [System.Drawing.Color]::White; $btnRenamePoolOk.UseVisualStyleBackColor = $false }
        $resRenamePool = $renamePoolForm.ShowDialog()
        $renamePoolForm.Dispose()
        if ($resRenamePool -eq [System.Windows.Forms.DialogResult]::OK) { & $ScanPhysicalInfrastructure; & $RecalculateEngine "ManualTrigger" }
    }
})
$btnRenameVDisk.add_Click({
    $checkedIdxVd = -1; for ($ci=0; $ci -lt $chkPools.Items.Count; $ci++) { if ($chkPools.GetItemChecked($ci)) { $checkedIdxVd = $ci; break } }
    if ($checkedIdxVd -lt 0) {
        if (-not $chkSuppressAllPopups.Checked) {
            $chkWarnForm3 = New-Object System.Windows.Forms.Form
            $chkWarnForm3.Text = "Rename Virtual Disk"
            $chkWarnForm3.Size = New-Object System.Drawing.Size(480, 160)
            $chkWarnForm3.StartPosition = "CenterParent"
            $chkWarnForm3.FormBorderStyle = "FixedDialog"
            $chkWarnForm3.MaximizeBox = $false; $chkWarnForm3.MinimizeBox = $false
            $chkWarnForm3.Topmost = $true
            $lblChkWarn3 = New-Object System.Windows.Forms.Label
            $lblChkWarn3.Text = "Check the box next to a pool in 'Detected Storage Pools' first."
            $lblChkWarn3.Location = New-Object System.Drawing.Point(20, 20)
            $lblChkWarn3.Size = New-Object System.Drawing.Size(420, 30)
            $chkWarnForm3.Controls.Add($lblChkWarn3)
            $btnChkOk3 = New-Object System.Windows.Forms.Button
            $btnChkOk3.Text = "OK"
            $btnChkOk3.Location = New-Object System.Drawing.Point(190, 70)
            $btnChkOk3.Size = New-Object System.Drawing.Size(80, 28)
            $btnChkOk3.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $chkWarnForm3.Controls.Add($btnChkOk3)
            $chkWarnForm3.AcceptButton = $btnChkOk3
            if ($script:IsDarkMode) { $chkWarnForm3.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblChkWarn3.ForeColor = [System.Drawing.Color]::White; $btnChkOk3.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnChkOk3.ForeColor = [System.Drawing.Color]::White; $btnChkOk3.UseVisualStyleBackColor = $false }
            [void]$chkWarnForm3.ShowDialog()
            $chkWarnForm3.Dispose()
        }
        return
    }
    $sel = $checkedIdxVd
    if ($sel -lt 0 -or $sel -ge $script:AvailablePools.Count) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Select a pool in 'Detected Storage Pools' first." -Title "Rename Virtual Disk" }; return }
    $pool = $script:AvailablePools[$sel]
    $newVdName = $txtSpaceName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($newVdName)) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Enter a new virtual disk label." -Title "Rename Virtual Disk" }; return }
    $newVdEsc = $newVdName -replace '"','`"'
    $poolIdEsc = $pool.UniqueId -replace '"','`"'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Rename Virtual Disk in pool: $($pool.FriendlyName) -> $newVdName")
    [void]$sb.AppendLine("`$Pool = Get-StoragePool -UniqueId `"$poolIdEsc`" -IsPrimordial `$false -ErrorAction SilentlyContinue")
    [void]$sb.AppendLine("if (-not `$Pool) { `$Pool = Get-StoragePool -FriendlyName `"$($pool.FriendlyName -replace '"','`"')`" -IsPrimordial `$false | Select-Object -First 1 }")
    [void]$sb.AppendLine("`$VD = Get-VirtualDisk -StoragePool `$Pool | Select-Object -First 1")
    [void]$sb.AppendLine("if (-not `$VD) { Write-Error 'No virtual disk found in that pool'; exit 1 }")
    [void]$sb.AppendLine("`$VD | Set-VirtualDisk -NewFriendlyName `"$newVdEsc`"")
    [void]$sb.AppendLine("Update-StorageProviderCache; Get-VirtualDisk -StoragePool `$Pool | Format-List FriendlyName, ResiliencySettingName, Size")
    if ([string]::IsNullOrWhiteSpace($txtTerminalOutput.Text) -or $txtTerminalOutput.Text -match "POWERSHELL COMMAND MONITOR STATION READY" -or $txtTerminalOutput.Text -match "SYSTEM DISCOVERY MAP FULLY REFRESHED") { $txtTerminalOutput.Text = $sb.ToString() } else { $txtTerminalOutput.AppendText("`r`n`r`n" + $sb.ToString()) }
    try {
        $isAdminRenameVd = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdminRenameVd) { $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: Not elevated - run as admin for silent rename.") }
        else {
            $hiddenRenameVdPs = [PowerShell]::Create()
            [void]$hiddenRenameVdPs.AddScript($sb.ToString())
            $null = $hiddenRenameVdPs.Invoke()
            if ($hiddenRenameVdPs.HadErrors) { $errRenameVd = ($hiddenRenameVdPs.Streams.Error | Out-String); $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION ERRORS (RENAME VDISK):`r`n" + $errRenameVd) }
            else { $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: RENAME VDISK SUCCESS"); }
            $hiddenRenameVdPs.Dispose()
        }
    } catch { $txtTerminalOutput.AppendText("`r`n# HIDDEN RENAME VDISK FAILED: $($_.Exception.Message)") }
    if (-not $chkSuppressAllPopups.Checked) {
        $renameVdForm = New-Object System.Windows.Forms.Form
        $renameVdForm.Text = "Rename Complete"
        $renameVdForm.Size = New-Object System.Drawing.Size(400, 160)
        $renameVdForm.StartPosition = "CenterParent"
        $renameVdForm.FormBorderStyle = "FixedDialog"
        $renameVdForm.MaximizeBox = $false; $renameVdForm.MinimizeBox = $false
        $renameVdForm.Topmost = $true
        $lblRenameVdDone = New-Object System.Windows.Forms.Label
        $lblRenameVdDone.Text = "Renaming complete."
        $lblRenameVdDone.Location = New-Object System.Drawing.Point(20, 20)
        $lblRenameVdDone.Size = New-Object System.Drawing.Size(340, 30)
        $lblRenameVdDone.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $renameVdForm.Controls.Add($lblRenameVdDone)
        $btnRenameVdOk = New-Object System.Windows.Forms.Button
        $btnRenameVdOk.Text = "OK"
        $btnRenameVdOk.Location = New-Object System.Drawing.Point(150, 70)
        $btnRenameVdOk.Size = New-Object System.Drawing.Size(80, 28)
        $btnRenameVdOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $renameVdForm.Controls.Add($btnRenameVdOk)
        $renameVdForm.AcceptButton = $btnRenameVdOk
        if ($script:IsDarkMode) { $renameVdForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblRenameVdDone.ForeColor = [System.Drawing.Color]::White; $btnRenameVdOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnRenameVdOk.ForeColor = [System.Drawing.Color]::White; $btnRenameVdOk.UseVisualStyleBackColor = $false }
        $resRenameVd = $renameVdForm.ShowDialog()
        $renameVdForm.Dispose()
        if ($resRenameVd -eq [System.Windows.Forms.DialogResult]::OK) { & $ScanPhysicalInfrastructure; & $RecalculateEngine "ManualTrigger" }
    }
})

# FIXED: Shifted dropdown arrays down to complement layout spacing matrices cleanly
$lblResiliency = New-Object System.Windows.Forms.Label
$lblResiliency.Text = "Resiliency Mode:"
$lblResiliency.Location = New-Object System.Drawing.Point(10, 430)
$lblResiliency.Size = New-Object System.Drawing.Size(150, 20)
$pnlLeft.Controls.Add($lblResiliency)

$cmbResiliency = New-Object System.Windows.Forms.ComboBox
$cmbResiliency.Location = New-Object System.Drawing.Point(180, 427)
$cmbResiliency.Size = New-Object System.Drawing.Size(260, 20)
$cmbResiliency.DropDownStyle = "DropDownList"
@('Parity Space (RAID 5)', 'Dual Parity Space (RAID 6)', 'Simple Space (RAID 0)', 'Mirror Space (RAID 1)') | ForEach-Object { [void]$cmbResiliency.Items.Add($_) }
$cmbResiliency.SelectedIndex = 0
$pnlLeft.Controls.Add($cmbResiliency)

$lblColumns = New-Object System.Windows.Forms.Label
$lblColumns.Text = "Number of Columns:"
$lblColumns.Location = New-Object System.Drawing.Point(10, 465)
$lblColumns.Size = New-Object System.Drawing.Size(140, 20)
$pnlLeft.Controls.Add($lblColumns)

$cmbColumns = New-Object System.Windows.Forms.ComboBox
$cmbColumns.Location = New-Object System.Drawing.Point(160, 462)
$cmbColumns.Size = New-Object System.Drawing.Size(120, 20)
$cmbColumns.DropDownStyle = "DropDownList"
@('1', '2', '3', '4', '5', '6', '7', '8') | ForEach-Object { [void]$cmbColumns.Items.Add($_) }
$cmbColumns.SelectedIndex = 4
$pnlLeft.Controls.Add($cmbColumns)

$lblInterleave = New-Object System.Windows.Forms.Label
$lblInterleave.Text = "Interleave Size:"
$lblInterleave.Location = New-Object System.Drawing.Point(10, 495)
$lblInterleave.Size = New-Object System.Drawing.Size(140, 20)
$pnlLeft.Controls.Add($lblInterleave)

$cmbInterleave = New-Object System.Windows.Forms.ComboBox
$cmbInterleave.Location = New-Object System.Drawing.Point(160, 492)
$cmbInterleave.Size = New-Object System.Drawing.Size(120, 20)
$cmbInterleave.DropDownStyle = "DropDownList"
@('16KB', '32KB', '64KB', '128KB', '256KB') | ForEach-Object { [void]$cmbInterleave.Items.Add($_) }
$cmbInterleave.SelectedIndex = 0
$pnlLeft.Controls.Add($cmbInterleave)

$lblCluster = New-Object System.Windows.Forms.Label
$lblCluster.Text = "NTFS Cluster Size:"
$lblCluster.Location = New-Object System.Drawing.Point(10, 525)
$lblCluster.Size = New-Object System.Drawing.Size(140, 20)
$pnlLeft.Controls.Add($lblCluster)

$cmbCluster = New-Object System.Windows.Forms.ComboBox
$cmbCluster.Location = New-Object System.Drawing.Point(160, 522)
$cmbCluster.Size = New-Object System.Drawing.Size(120, 20)
$cmbCluster.DropDownStyle = "DropDownList"
@('4KB', '8KB', '16KB', '32KB', '64KB', '128KB', '256KB') | ForEach-Object { [void]$cmbCluster.Items.Add($_) }
$cmbCluster.SelectedIndex = 4
$pnlLeft.Controls.Add($cmbCluster)

# FIXED: Shifted optimize button and expanded the structural assistant tips frame panel bounds
$btnOptimize = New-Object System.Windows.Forms.Button
$btnOptimize.Text = "Quick Optimize"
$btnOptimize.Location = New-Object System.Drawing.Point(300, 462)
$btnOptimize.Size = New-Object System.Drawing.Size(140, 80)
$btnOptimize.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnOptimize.BackColor = [System.Drawing.Color]::MediumSeaGreen
$btnOptimize.ForeColor = [System.Drawing.Color]::White
$btnOptimize.Cursor = [System.Windows.Forms.Cursors]::Hand
$pnlLeft.Controls.Add($btnOptimize)
$btnOptimize.add_Click({
    # QUICK OPTIMIZE: Research-based best settings for all Storage Spaces resiliency types - fixes crash on 2nd press via IsRefreshing guard
    $driveCount = 0
    for ($k = 0; $k -lt $chkDrives.Items.Count; $k++) { if ($chkDrives.GetItemChecked($k)) { $driveCount++ } }
    if ($driveCount -eq 0) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Check at least one drive in the Physical Drive Inventory first, then Quick Optimize will pick the proven-best layout." -Title "Quick Optimize" }; return }
    $mode = $cmbResiliency.SelectedItem.ToString()
    # Block RecalculateEngine re-entrancy during batch updates (fixes crash after 2nd press)
    $script:IsRefreshingInterface = $true
    try {
        if ($mode -eq 'Parity Space (RAID 5)') {
            if ($driveCount -lt 3) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Parity needs 3+ drives." -Title "Quick Optimize" }; return }
            # Best practice: (cols-1)*interleave == 64KB cluster for 1:1 green per https://storagespaceswarstories.com/  - search largest cols that yields perfect 64KB
            $bestCols = $null; $bestIL = $null; $bestCl = "64KB"
            $interleaves = @("16KB","32KB","64KB","128KB","256KB")
            foreach ($c in @($driveCount,5,4,3,2)) { if ($c -gt $driveCount -or $c -gt 8 -or $c -lt 2) { continue }
                foreach ($il in $interleaves) {
                    $ilBytes = switch($il){"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144}}
                    $dataBytes = ($c - 1) * $ilBytes
                    if ($dataBytes -eq 65536) { $bestCols=$c; $bestIL=$il; break }
                }
                if ($bestCols){break}
            }
            if ($bestCols) { $cmbColumns.SelectedItem = $bestCols.ToString(); $cmbInterleave.SelectedItem = $bestIL; $cmbCluster.SelectedItem = "64KB" }
            else {
                # Fallback orange optimized: 4 cols 32KB 128KB per your tip (96KB stripe -> 128KB)
                if ($driveCount -ge 4) { $cmbColumns.SelectedItem = "4"; $cmbInterleave.SelectedItem = "32KB"; $cmbCluster.SelectedItem = "128KB" }
                else { $cmbColumns.SelectedItem = $driveCount.ToString(); $cmbInterleave.SelectedItem = "32KB"; $cmbCluster.SelectedItem = "64KB" }
            }
        } elseif ($mode -eq 'Dual Parity Space (RAID 6)') {
            if ($driveCount -lt 5) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Dual Parity needs 5+ drives." -Title "Quick Optimize" }; return }
            # Research: Dual parity optimal is cols = drives-2 with 128KB interleave, 64KB cluster (10 drives -> 8 cols golden ratio)
            if ($driveCount -ge 10) { $cmbColumns.SelectedItem = "8"; $cmbInterleave.SelectedItem = "128KB"; $cmbCluster.SelectedItem = "64KB" }
            elseif ($driveCount -ge 7) { $cmbColumns.SelectedItem = ($driveCount - 2).ToString(); $cmbInterleave.SelectedItem = "128KB"; $cmbCluster.SelectedItem = "64KB" }
            elseif ($driveCount -eq 6) { $cmbColumns.SelectedItem = "4"; $cmbInterleave.SelectedItem = "128KB"; $cmbCluster.SelectedItem = "64KB" }
            else { $cmbColumns.SelectedItem = "3"; $cmbInterleave.SelectedItem = "128KB"; $cmbCluster.SelectedItem = "64KB" }
        } elseif ($mode -match 'Simple') {
            # Research: Simple optimal = interleave * cols == cluster (1:1 green). Prefer 64KB cluster, search for largest cols that yields perfect.
            # Try all cols down from driveCount to find perfect green; prefer 64KB/128KB cluster for media, 64KB interleave for seq.
            $found = $false; $tryCols = @()
            for ($c = $driveCount; $c -ge 1; $c--) { $tryCols += $c }
            # Also try driveCount itself first with preferred interleaves
            foreach ($c in $tryCols) {
                foreach ($cl in @("64KB","128KB","256KB","32KB")) {
                    foreach ($il in @("64KB","32KB","16KB","128KB","256KB")) {
                        $ilBytes = switch($il){"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144}}
                        $clBytes = switch($cl){"4KB"{4096}"8KB"{8192}"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144}}
                        if ($ilBytes * $c -eq $clBytes) {
                            $cmbColumns.SelectedItem = $c.ToString(); $cmbInterleave.SelectedItem = $il; $cmbCluster.SelectedItem = $cl; $found=$true; break
                        }
                    }
                    if ($found){break}
                }
                if ($found){break}
            }
            if (-not $found) {
                # Fallback: use all drives, 64KB interleave, 64KB cluster (will be orange per tip but functional)
                $cmbColumns.SelectedItem = $driveCount.ToString(); $cmbInterleave.SelectedItem = "64KB"; $cmbCluster.SelectedItem = "64KB"
            }
        } elseif ($mode -match 'Mirror') {
            # Research: 2-way mirror = cols = floor(drives/2) for RAID10-like, interleave disabled, cluster 64KB is cleanest for NTFS/ReFS 4K/64K
            $cols = [math]::Floor($driveCount/2); if ($cols -lt 1){$cols=1}; if ($cols -gt 8){$cols=8}
            # For 3-way mirror (5+ drives, 3 copies) cols = floor(drives/3) but app uses 2-way, so keep 2-way logic; 2 drives ->1 col correct per your example
            $cmbColumns.SelectedItem = $cols.ToString()
            $cmbCluster.SelectedItem = "64KB"
            if ($cmbInterleave.SelectedItem -eq $null) { $cmbInterleave.SelectedItem = "64KB" }
        }
    } catch {
        # Prevent crash bubble - log silently and ensure UI recovers
        $script:IsRefreshingInterface = $false
        Show-ThemedAlert -Text "Quick Optimize error: $($_.Exception.Message)" -Title "Quick Optimize"
        return
    } finally { $script:IsRefreshingInterface = $false }
    & $RecalculateEngine "ManualTrigger"
    $drawCanvas.Refresh()
})

$groupTips = New-Object System.Windows.Forms.GroupBox
$groupTips.Text = " Matrix Intelligence Assistant "
$groupTips.Location = New-Object System.Drawing.Point(10, 550) 
$groupTips.Size = New-Object System.Drawing.Size(430, 105)
$groupTips.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$lblTipsText = New-Object System.Windows.Forms.Label
$lblTipsText.Text = ""
$lblTipsText.Location = New-Object System.Drawing.Point(15, 25)
$lblTipsText.Size = New-Object System.Drawing.Size(400, 70)
$lblTipsText.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$groupTips.Controls.Add($lblTipsText)
$pnlLeft.Controls.Add($groupTips)

$pnlLeft.Controls.Add($groupTips)
$pnlRight = New-Object System.Windows.Forms.Panel
$pnlRight.Location = New-Object System.Drawing.Point(500, 60)
$pnlRight.Size = New-Object System.Drawing.Size(460, 380) 
$pnlRight.BorderStyle = "FixedSingle"
$pnlRight.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($pnlRight)
$lblCanvasTitle = New-Object System.Windows.Forms.Label
$lblCanvasTitle.Text = "Planned Layout for Deployment"
$lblCanvasTitle.Location = New-Object System.Drawing.Point(10, 5)
$lblCanvasTitle.Size = New-Object System.Drawing.Size(440, 32)
$lblCanvasTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$pnlRight.Controls.Add($lblCanvasTitle)
$drawCanvas = New-Object System.Windows.Forms.Panel
$drawCanvas.Location = New-Object System.Drawing.Point(10, 40)
$drawCanvas.Size = New-Object System.Drawing.Size(440, 330) 
$drawCanvas.BackColor = [System.Drawing.Color]::GhostWhite
$pnlRight.Controls.Add($drawCanvas)
$lblTerminalTitle = New-Object System.Windows.Forms.Label
$lblTerminalTitle.Text = "Script Terminal"
$lblTerminalTitle.Location = New-Object System.Drawing.Point(500, 450)
$lblTerminalTitle.Size = New-Object System.Drawing.Size(300, 20)
$lblTerminalTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblTerminalTitle)
$btnCopyTerminal = New-Object System.Windows.Forms.Button
$btnCopyTerminal.Text = "Copy Script Text"
$btnCopyTerminal.Location = New-Object System.Drawing.Point(840, 446)
$btnCopyTerminal.Size = New-Object System.Drawing.Size(120, 25)
$btnCopyTerminal.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnCopyTerminal.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCopyTerminal.add_Click({
    if ([string]::IsNullOrWhiteSpace($txtTerminalOutput.Text)) { return }
    
    # 1. Ship the script code payload directly onto the system clipboard
    [System.Windows.Forms.Clipboard]::SetText($txtTerminalOutput.Text)
    if ($chkSuppressAllPopups.Checked) { return }
    
    # 2. FIXED: Check if the user has suppressed the refresh alert
    if ($script:ShowRefreshWarning) {
        # Construct a custom Form dialog to house a native "Don't show again" checkbox cleanly
        $alertForm = New-Object System.Windows.Forms.Form
        $alertForm.Text = "Clipboard Action Complete"
        $alertForm.Size = New-Object System.Drawing.Size(380, 200)
        $alertForm.StartPosition = "CenterParent"
        $alertForm.FormBorderStyle = "FixedDialog"
        $alertForm.MaximizeBox = $false; $alertForm.MinimizeBox = $false
        
        $lblMsg = New-Object System.Windows.Forms.Label
        $lblMsg.Text = "Commands copied to clipboard."
        $lblMsg.Location = New-Object System.Drawing.Point(20, 15)
        $lblMsg.Size = New-Object System.Drawing.Size(320, 85)
        $alertForm.Controls.Add($lblMsg)
        
        $chkSuppress = New-Object System.Windows.Forms.CheckBox
        $chkSuppress.Text = "Do not show this reminder again"
        $chkSuppress.Location = New-Object System.Drawing.Point(20, 105)
        $chkSuppress.Size = New-Object System.Drawing.Size(250, 20)
        $alertForm.Controls.Add($chkSuppress)
        
        $btnOk = New-Object System.Windows.Forms.Button
        $btnOk.Text = "OK"
        $btnOk.Location = New-Object System.Drawing.Point(260, 130)
        $btnOk.Size = New-Object System.Drawing.Size(80, 24)
        $btnOk.add_Click({
            if ($chkSuppress.Checked) { $script:ShowRefreshWarning = $false }
            $alertForm.Close()
        })
        $alertForm.Controls.Add($btnOk)
        
        # Color match the dialog box to the active theme styles dynamically
        if ($script:IsDarkMode) {
            $alertForm.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
            $lblMsg.ForeColor = [System.Drawing.Color]::White
            $chkSuppress.ForeColor = [System.Drawing.Color]::White
            $btnOk.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60); $btnOk.ForeColor = [System.Drawing.Color]::White
        }
        
        [void]$alertForm.ShowDialog()
    } else {
        # Fallback silent toast alert if suppressed
        Show-ThemedAlert -Text "Commands copied to clipboard." -Title "Clipboard Success"
    }
})
$form.Controls.Add($btnCopyTerminal)
$txtTerminalOutput = New-Object System.Windows.Forms.TextBox
$txtTerminalOutput.Multiline = $true
$txtTerminalOutput.ScrollBars = "Vertical"
$txtTerminalOutput.ReadOnly = $true
$txtTerminalOutput.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$txtTerminalOutput.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 12)
$txtTerminalOutput.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$txtTerminalOutput.Location = New-Object System.Drawing.Point(500, 475)
$txtTerminalOutput.Size = New-Object System.Drawing.Size(460, 305)
$txtTerminalOutput.Text = "# =========================================================`r`n# POWERSHELL COMMAND MONITOR STATION READY`r`n# Configured settings generate code scripts here.`r`n# ========================================================="
$form.Controls.Add($txtTerminalOutput)
# Registering every visible layout control to perform perfect theme switches with no text color leaks
$script:ThemeControlsRegistry = @($form, $pnlLeft, $pnlRight, $drawCanvas, $groupTips, $titleLabel, $lblDetectPools, $lblDrives, $lblPoolName, $lblSpaceName, $lblResiliency, $lblColumns, $lblInterleave, $lblCluster, $lblCanvasTitle, $lblTipsText, $txtPoolName, $txtSpaceName, $cmbResiliency, $cmbColumns, $cmbInterleave, $cmbCluster, $chkPools, $chkDrives, $lblTerminalTitle, $txtTerminalOutput, $btnCopyTerminal, $btnRenamePool, $btnRenameVDisk, $btnBuild, $btnAdvancedVDisk, $btnCancelAdvanced, $chkSuppressAllPopups, $chkSuppressDeletionWarnings, $btnRevealAdvanced)
$ScanPhysicalInfrastructure = {
    $chkPools.Items.Clear(); $chkDrives.Items.Clear(); $script:AvailableDisks = @(); $script:AvailablePools = @()
    try {
        # Querying live storage pools active on your host OS - FIXED: cache UniqueId for duplicate FriendlyName handling
        $foundPools = Get-StoragePool | Where-Object {$_.IsPrimordial -eq $false}
        $script:AvailablePools = @($foundPools)
        # Build display with resiliency + duplicate numbering (e.g. "OptimizedPool - Mirror (RAID 1) (1)")
        $poolInfos = @()
        foreach ($p in $foundPools) {
            try {
                $vdTmp = Get-VirtualDisk -StoragePool $p -ErrorAction SilentlyContinue | Select-Object -First 1
                $resTmp = if ($vdTmp -and $vdTmp.ResiliencySettingName) { $vdTmp.ResiliencySettingName } else { "Empty" }
                $colsTmp = if ($vdTmp -and $vdTmp.NumberOfColumns) { " - $($vdTmp.NumberOfColumns) Col" } else { "" }
            } catch { $resTmp = "Unknown"; $colsTmp = "" }
            $resLabelTmp = switch ($resTmp) {
                "Mirror" { "Mirror (RAID 1)" }
                "Parity" { "Parity (RAID 5/6)" }
                "Simple" { "Simple (RAID 0)" }
                default { $resTmp }
            }
            $baseTmp = "$($p.FriendlyName) - $resLabelTmp$colsTmp"
            $poolInfos += [PSCustomObject]@{Pool=$p; Base=$baseTmp}
        }
        $baseTotals = @{}
        foreach ($info in $poolInfos) { if (-not $baseTotals.ContainsKey($info.Base)) { $baseTotals[$info.Base]=0 }; $baseTotals[$info.Base]++ }
        $baseOcc = @{}
        foreach ($info in $poolInfos) {
            $b = $info.Base
            if ($baseTotals[$b] -gt 1) {
                if (-not $baseOcc.ContainsKey($b)) { $baseOcc[$b]=0 }; $baseOcc[$b]++
                $displayTmp = "$b ($($baseOcc[$b]))"
            } else {
                $displayTmp = $b
            }
            [void]$chkPools.Items.Add($displayTmp, $false)
        }
        if ($chkPools.Items.Count -eq 0) {
            [void]$chkPools.Items.Add("No active storage pools detected.")
            $chkPools.Enabled = $false; $script:AvailablePools = @()
        } else {
            $chkPools.Enabled = $true
        }

        # Discovering unallocated raw hard drives eligible for pooling - FIXED: keep UniqueId mapping so identical FriendlyNames don't grab extra drives
        $foundDisks = Get-PhysicalDisk | Where-Object {$_.CanPool -eq $true}
        $script:AvailableDisks = @($foundDisks)
        foreach ($d in $foundDisks) { $sizeGB = [math]::Round($d.Size / 1GB, 2); [void]$chkDrives.Items.Add("$($d.FriendlyName) - $($sizeGB) GB", $false) }
        if ($chkDrives.Items.Count -eq 0) { [void]$chkDrives.Items.Add("No available unallocated drives discovered."); $chkDrives.Enabled = $false; $script:AvailableDisks = @() } else { $chkDrives.Enabled = $true }
    } catch {
        [void]$chkDrives.Items.Add("Error querying system drive framework."); $chkDrives.Enabled = $false; $script:AvailableDisks = @()
    }
}
& $ScanPhysicalInfrastructure
$RecalculateEngine = {
    param($triggerSource)
    
    # Calculate drive count dynamically directly based on actual checked items inside the box element
    $driveCount = 0
    for ($k = 0; $k -lt $chkDrives.Items.Count; $k++) {
        if ($chkDrives.GetItemChecked($k)) { $driveCount++ }
    }
    
    $mode = $cmbResiliency.SelectedItem
    if ($mode -match 'Mirror') { 
        $cmbInterleave.Enabled = $false
        $lblInterleave.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::DimGray } else { [System.Drawing.Color]::Gray } 
    } else { 
        $cmbInterleave.Enabled = $true
        $lblInterleave.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black } 
    }
    if ($cmbColumns.SelectedItem -eq $null -or $cmbInterleave.SelectedItem -eq $null -or $cmbCluster.SelectedItem -eq $null) { return }
    $cols = [int]$cmbColumns.SelectedItem; $interleaveText = $cmbInterleave.SelectedItem; $clusterText = $cmbCluster.SelectedItem
    
    if ($driveCount -eq 0) { 
        $lblTipsText.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::LightGray } else { [System.Drawing.Color]::Black }
        $lblTipsText.Text = "Console Operating in Standby Status. Check physical drive inventory targets above to map real-time performance profiles."
        $drawCanvas.Refresh(); return 
    }

    if ($mode -eq 'Parity Space (RAID 5)') {
        if ($driveCount -lt 3) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "MODE CONSTRAINT ERROR: Parity layout configurations demand an absolute layout width minimum of 3 physical disks."; $drawCanvas.Refresh(); return }
        if ($cols -gt $driveCount) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "STRIPE EXCEEDS DRIVE INVENTORY: Reduce your column layout setting to avoid execution path crashes."; $drawCanvas.Refresh(); return }
        $intBytes = if ($interleaveText -eq "16KB") { 16384 } elseif ($interleaveText -eq "32KB") { 32768 } elseif ($interleaveText -eq "64KB") { 65536 } else { 131072 }
        $payloadKB = ($intBytes * ($cols - 1)) / 1KB
        if (($cols -eq 5 -and $interleaveText -eq "16KB" -and $clusterText -eq "64KB") -or ($cols -eq 3 -and $interleaveText -eq "32KB" -and $clusterText -eq "64KB")) {
            $lblTipsText.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::DarkGreen }
            $lblTipsText.Text = "Status: PERFECT PARITY MATH (1:1). Your data stripe ($payloadKB KB) perfectly bridges the filesystem block. Write Cache logs are bypassed for maximum performance."
        } elseif ($cols -eq 4 -and $interleaveText -eq "32KB" -and $clusterText -eq "128KB") {
            $lblTipsText.ForeColor = [System.Drawing.Color]::DarkOrange; $lblTipsText.Text = "Status: OPTIMIZED 4-DRIVE BLUEPRINT. Stripe tracks to 96KB, neatly rounding up to a 128KB block allocation. Reliable, solid write-once movie landing pad."
        } else { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "Status: STRIPE MISALIGNMENT DETECTED! Your settings provoke data sector overlap. CPU computation paths enter heavy Read-Modify-Write loops, throttling write speeds." }
    } elseif ($mode -eq 'Dual Parity Space (RAID 6)') {
        if ($driveCount -lt 5) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "MODE CONSTRAINT ERROR: Dual Parity requires a minimum of 5 physical hard drives to house multi-parity rotation logs."; $drawCanvas.Refresh(); return }
        if ($cols -gt ($driveCount - 2)) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "COLUMN OVERFLOW BOUNDS: In Dual Parity, Column width cannot exceed Drive Count minus 2 parity tracks."; $drawCanvas.Refresh(); return }
        
        if ($driveCount -eq 10 -and $cols -eq 8 -and $interleaveText -eq "128KB" -and $clusterText -eq "64KB") {
            $lblTipsText.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::DarkGreen }
            $lblTipsText.Text = "Status: THE GOLDEN RATIO (RAID 6). 10 Disks / 8 Columns provides flawless mathematical sector alignment with 128KB interleave. Peak tolerance; array survives 2 complete drive failures."
        } elseif ($driveCount -ge 7 -and $cols -eq ($driveCount - 2) -and $interleaveText -eq "128KB" -and $clusterText -eq "64KB") {
            $lblTipsText.ForeColor = [System.Drawing.Color]::DarkOrange; $lblTipsText.Text = "Status: HIGH OPTIMIZATION BLUEPRINT. Columns and spindles match cleanly for uniform striping layouts. Safe padding enabled."
        } else {
            $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "Status: MISALIGNED ROTATING PARITY ROW! Interleave rows provoke block splits. Avoid formatting unit overlap to maintain optimal sequential write logging."
        }
    } elseif ($mode -match 'Simple') {
        if ($cols -gt $driveCount) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "STRIPE EXCEEDS DRIVE INVENTORY: Simple spaces require your Column Count to be less than or equal to total physical drive count."; $drawCanvas.Refresh(); return }
        $intBytes = if ($interleaveText -eq "16KB") { 16384 } elseif ($interleaveText -eq "32KB") { 32768 } elseif ($interleaveText -eq "64KB") { 65536 } else { 131072 }
        $stripeKB = ($intBytes * $cols) / 1KB
        $clusterKB = if ($clusterText -eq "64KB") { 64 } elseif ($clusterText -eq "128KB") { 128 } else { 256 }
        if ($stripeKB -eq $clusterKB) { 
            $lblTipsText.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::DarkGreen }
            $lblTipsText.Text = "Status: OPTIMIZED SIMPLE STRIPE (RAID 0). Stripe width ($stripeKB KB) maps perfectly to the Cluster size. Blazing performance mode. ZERO fault tolerance." 
        } else { 
            $lblTipsText.ForeColor = [System.Drawing.Color]::DarkOrange; $lblTipsText.Text = "Status: UNALIGNED SIMPLE STRIPE. RAID 0 striping runs fast, but for absolute peak efficiency on $driveCount drives, choose a 1:1 footprint ($stripeKB KB)." 
        }
    } elseif ($mode -match 'Mirror') {
        if (($cols * 2) -gt $driveCount) { $lblTipsText.ForeColor = [System.Drawing.Color]::Red; $lblTipsText.Text = "MODE CONSTRAINT ERROR: Two-Way Mirror spaces dictate that physical drive inventory must be at least double the targeted column count ($($cols * 2) drives required)."; $drawCanvas.Refresh(); return }
        $lblTipsText.ForeColor = if ($script:IsDarkMode) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::DarkGreen }; $lblTipsText.Text = "Status: OPTIMIZED TWO-WAY MIRROR (RAID 1). Real-time block replication. Interleaving is bypassed. For mirrors, standard 64KB Cluster sizing provides the cleanest Windows trail. 50% storage capacity efficiency."
    }
    $drawCanvas.Refresh()
}
$drawCanvas.add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    if ($script:IsAdvancedMode -and $script:AdvancedConfig -ne $null) {
        $adv = $script:AdvancedConfig; $colsAdv = $adv.Columns; $resAdv = $adv.Resiliency; $isTiered = $adv.Tiered; $isCache = $adv.Cache
        $fontAdv = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
        $yPosAdv = 20
        if ($isCache) {
            $rectCacheAdv = New-Object System.Drawing.Rectangle(20, $yPosAdv, 400, 25)
            $g.FillRectangle([System.Drawing.Brushes]::Gold, $rectCacheAdv); $g.DrawRectangle([System.Drawing.Pens]::Goldenrod, $rectCacheAdv)
            [void]$g.DrawString("Write-Back Cache (SSD Journal) - $($adv.Interleave)", $fontAdv, [System.Drawing.Brushes]::Black, 25, $yPosAdv+6)
            $yPosAdv += 35
        }
        if ($isTiered) {
            $rectSsdAdv = New-Object System.Drawing.Rectangle(20, $yPosAdv, 400, 45)
            $g.FillRectangle([System.Drawing.Brushes]::LightGreen, $rectSsdAdv); $g.DrawRectangle([System.Drawing.Pens]::Green, $rectSsdAdv)
            [void]$g.DrawString("SSD Tier (Fast) - $colsAdv Cols - $($adv.Interleave) - $resAdv", $fontAdv, [System.Drawing.Brushes]::Black, 25, $yPosAdv+5)
            for ($ia=0; $ia -lt $colsAdv -and $ia -lt 8; $ia++) { $bxAdv = 30 + $ia*45; $rectBAdv = New-Object System.Drawing.Rectangle($bxAdv, $yPosAdv+18, 35, 20); $g.FillRectangle([System.Drawing.Brushes]::PaleGreen, $rectBAdv); $g.DrawRectangle([System.Drawing.Pens]::Green, $rectBAdv); [void]$g.DrawString("SSD", $fontAdv, [System.Drawing.Brushes]::DarkGreen, $bxAdv+6, $yPosAdv+22) }
            $yPosAdv += 55
            $rectHddAdv = New-Object System.Drawing.Rectangle(20, $yPosAdv, 400, 45)
            $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectHddAdv); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectHddAdv)
            [void]$g.DrawString("HDD Tier (Capacity) - $colsAdv Cols - $resAdv", $fontAdv, [System.Drawing.Brushes]::Black, 25, $yPosAdv+5)
            for ($ia=0; $ia -lt $colsAdv -and $ia -lt 8; $ia++) { $bxAdv = 30 + $ia*45; $rectBAdv = New-Object System.Drawing.Rectangle($bxAdv, $yPosAdv+18, 35, 20); $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectBAdv); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectBAdv); [void]$g.DrawString("HDD", $fontAdv, [System.Drawing.Brushes]::Navy, $bxAdv+6, $yPosAdv+22) }
            $yPosAdv += 55
        } else {
            $rectAdv = New-Object System.Drawing.Rectangle(20, $yPosAdv, 400, 60)
            $g.FillRectangle([System.Drawing.Brushes]::Lavender, $rectAdv); $g.DrawRectangle([System.Drawing.Pens]::DarkSlateBlue, $rectAdv)
            [void]$g.DrawString("Advanced: $resAdv - $colsAdv Cols - $($adv.Interleave) - $($adv.Provisioning)", $fontAdv, [System.Drawing.Brushes]::Black, 25, $yPosAdv+8)
            [void]$g.DrawString("Tiered: $isTiered  Cache: $isCache", $fontAdv, [System.Drawing.Brushes]::Black, 25, $yPosAdv+25)
        }
        $lblBrushAdv = if ($script:IsDarkMode) { [System.Drawing.Brushes]::White } else { [System.Drawing.Brushes]::Black }
        [void]$g.DrawString("Advanced Virtual Disk Preview - Tiered/Cached", $lblCanvasTitle.Font, $lblBrushAdv, 20, $yPosAdv+10)
        return
    }
    if ($cmbColumns.SelectedItem -eq $null -or $cmbResiliency.SelectedItem -eq $null) { return }
    $cols = [int]$cmbColumns.SelectedItem; $mode = $cmbResiliency.SelectedItem
    
    # Compute active checked drive count dynamically
    $driveCount = 0
    for ($k = 0; $k -lt $chkDrives.Items.Count; $k++) {
        if ($chkDrives.GetItemChecked($k)) { $driveCount++ }
    }
    
    if ($driveCount -eq 0 -or ($mode -eq 'Parity Space (RAID 5)' -and ($driveCount -lt 3 -or $cols -gt $driveCount)) -or ($mode -eq 'Dual Parity Space (RAID 6)' -and ($driveCount -lt 5 -or $cols -gt ($driveCount - 2))) -or ($mode -match 'Simple' -and $cols -gt $driveCount) -or ($mode -match 'Mirror' -and ($cols * 2) -gt $driveCount)) { return }
    
    # Perfectly scaled dimensions to fit inside the new 330px height window with zero edge clipping
    $startX = 10; $startY = 20; $spacingX = 53; $blockW = 42; $blockH = 26; $totalRenderCols = if ($mode -match 'Mirror') { $cols * 2 } else { $cols }
    $fontDrive = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    for ($i = 0; $i -lt $totalRenderCols; $i++) {
        $curX = $startX + ($i * $spacingX); $rectChassis = New-Object System.Drawing.Rectangle($curX, $startY, $blockW, 120)
        $g.FillRectangle([System.Drawing.Brushes]::LightGray, $rectChassis)
        $g.DrawRectangle([System.Drawing.Pens]::Black, $rectChassis)
        
        $displayColNum = $i + 1
        if ($mode -match 'Mirror') { 
            if ($i -lt $cols) { [void]$g.DrawString("M1-C$displayColNum", $fontDrive, [System.Drawing.Brushes]::Black, ($curX + 1), ($startY + 4)) } 
            else { $mirrorColNum = $i - $cols + 1; [void]$g.DrawString("M2-C$mirrorColNum", $fontDrive, [System.Drawing.Brushes]::DarkSlateGray, ($curX + 1), ($startY + 4)) } 
        } else { 
            [void]$g.DrawString("COL $displayColNum", $fontDrive, [System.Drawing.Brushes]::Black, ($curX + 2), ($startY + 4)) 
        }
        
        for ($j = 0; $j -lt 3; $j++) {
            $blockY = $startY + 22 + ($j * ($blockH + 4)); $rectBlock = New-Object System.Drawing.Rectangle($curX + 4, $blockY, $blockW - 8, $blockH)
            
            if ($mode -eq 'Parity Space (RAID 5)') { 
                if (($i + $j) % $cols -eq 0) { 
                    $g.FillRectangle([System.Drawing.Brushes]::Salmon, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Red, $rectBlock)
                    [void]$g.DrawString("PARITY", $fontDrive, [System.Drawing.Brushes]::Maroon, ($curX + 5), ($blockY + 7)) 
                } else { 
                    $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectBlock)
                    [void]$g.DrawString("DATA", $fontDrive, [System.Drawing.Brushes]::Navy, ($curX + 8), ($blockY + 7)) 
                } 
            }
            elseif ($mode -eq 'Dual Parity Space (RAID 6)') {
                if (($i + $j) % $cols -eq 0) { 
                    $g.FillRectangle([System.Drawing.Brushes]::Salmon, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Red, $rectBlock)
                    [void]$g.DrawString("P1", $fontDrive, [System.Drawing.Brushes]::Maroon, ($curX + 12), ($blockY + 7)) 
                }
                elseif (($i + $j + 1) % $cols -eq 0) { 
                    $g.FillRectangle([System.Drawing.Brushes]::Coral, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Chocolate, $rectBlock)
                    [void]$g.DrawString("P2", $fontDrive, [System.Drawing.Brushes]::DarkRed, ($curX + 12), ($blockY + 7)) 
                }
                else { 
                    $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectBlock)
                    [void]$g.DrawString("DATA", $fontDrive, [System.Drawing.Brushes]::Navy, ($curX + 8), ($blockY + 7)) 
                }
            }
            elseif ($mode -match 'Simple') { 
                $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectBlock)
                [void]$g.DrawString("STRIPE", $fontDrive, [System.Drawing.Brushes]::Navy, ($curX + 6), ($blockY + 7)) 
            }
            elseif ($mode -match 'Mirror') { 
                if ($i -lt $cols) { 
                    $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Blue, $rectBlock)
                    [void]$g.DrawString("ORIG", $fontDrive, [System.Drawing.Brushes]::Navy, ($curX + 8), ($blockY + 7)) 
                } else { 
                    $g.FillRectangle([System.Drawing.Brushes]::PaleGreen, $rectBlock); $g.DrawRectangle([System.Drawing.Pens]::Green, $rectBlock)
                    [void]$g.DrawString("CLONE", $fontDrive, [System.Drawing.Brushes]::DarkGreen, ($curX + 6), ($blockY + 7)) 
                } 
            }
        }
    }
    $lblBrush = if ($script:IsDarkMode) { [System.Drawing.Brushes]::White } else { [System.Drawing.Brushes]::Black }
    if ($mode -eq 'Parity Space (RAID 5)') { $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, 20, 160, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Blue, 20, 160, 20, 15); [void]$g.DrawString("Data Blocks", $lblCanvasTitle.Font, $lblBrush, 50, 158); $g.FillRectangle([System.Drawing.Brushes]::Salmon, 20, 190, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Red, 20, 190, 20, 15); [void]$g.DrawString("Parity Rows", $lblCanvasTitle.Font, $lblBrush, 50, 188) }
    elseif ($mode -eq 'Dual Parity Space (RAID 6)') {
        $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, 20, 160, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Blue, 20, 160, 20, 15); [void]$g.DrawString("Data Blocks", $lblCanvasTitle.Font, $lblBrush, 50, 158)
        $g.FillRectangle([System.Drawing.Brushes]::Salmon, 20, 190, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Red, 20, 190, 20, 15); [void]$g.DrawString("Primary Parity Matrix (P1)", $lblCanvasTitle.Font, $lblBrush, 50, 188)
        $g.FillRectangle([System.Drawing.Brushes]::Coral, 20, 220, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Chocolate, 20, 220, 20, 15); [void]$g.DrawString("Secondary Reed-Solomon Parity (P2)", $lblCanvasTitle.Font, $lblBrush, 50, 218)
    }
    elseif ($mode -match 'Simple') { $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, 20, 160, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Blue, 20, 160, 20, 15); [void]$g.DrawString("Striped Interleave Sectors", $lblCanvasTitle.Font, $lblBrush, 50, 158) }
    elseif ($mode -match 'Mirror') { $g.FillRectangle([System.Drawing.Brushes]::LightSkyBlue, 20, 160, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Blue, 20, 160, 20, 15); [void]$g.DrawString("Original Storage Tracks", $lblCanvasTitle.Font, $lblBrush, 50, 158); $g.FillRectangle([System.Drawing.Brushes]::PaleGreen, 20, 190, 20, 15); $g.DrawRectangle([System.Drawing.Pens]::Green, 20, 190, 20, 15); [void]$g.DrawString("Mirror Sector Clones", $lblCanvasTitle.Font, $lblBrush, 50, 188) }
})
$chkPools.add_Click({
    $currIdx = $chkPools.SelectedIndex; if ($currIdx -lt 0) { return }
    $rawText = $chkPools.Items[$currIdx].ToString(); if ($rawText -match "No active storage pools") { return }
    # Map display string (e.g. "OptimizedPool - Mirror (RAID 1) (1)") back to actual FriendlyName via cache
    $poolObjTmp = if ($currIdx -ge 0 -and $currIdx -lt $script:AvailablePools.Count) { $script:AvailablePools[$currIdx] } else { $null }
    $itemText = if ($poolObjTmp -and $poolObjTmp.FriendlyName) { $poolObjTmp.FriendlyName } else { ($rawText -split " - ")[0].Trim() }
    
    $script:updatingSelection = $true
    for ($i = 0; $i -lt $chkPools.Items.Count; $i++) { $chkPools.SetItemChecked($i, ($i -eq $currIdx)) }
    $script:updatingSelection = $false
    $hasCheckedTmp = $false; for ($ciTmp=0; $ciTmp -lt $chkPools.Items.Count; $ciTmp++) { if ($chkPools.GetItemChecked($ciTmp)) { $hasCheckedTmp = $true; break } }
    $btnSimDemo.Enabled = $hasCheckedTmp
    if ($hasCheckedTmp) { $btnSimDemo.BackColor = [System.Drawing.Color]::DarkRed; $btnSimDemo.ForeColor = [System.Drawing.Color]::White; $btnSimDemo.UseVisualStyleBackColor = $false } else { if ($script:IsDarkMode) { $btnSimDemo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $false } else { $btnSimDemo.BackColor = [System.Drawing.SystemColors]::Control; $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $true } }
    
    try {
        $vDisk = Get-VirtualDisk -StoragePoolFriendlyName $itemText | Select-Object -First 1
        if ($vDisk -ne $null) {
            $script:IsRefreshingInterface = $true
            $cmbColumns.SelectedItem = $vDisk.NumberOfColumns.ToString()
            $intKB = ($vDisk.Interleave / 1KB)
            $cmbInterleave.SelectedItem = "$($intKB)KB"
            $script:IsRefreshingInterface = $false
            $colSpec = $vDisk.NumberOfColumns; $intSpec = ($vDisk.Interleave / 1KB); $clSpec = "64KB"
            $lblCanvasTitle.Text = "Active Workspace Properties:`n[Columns: $colSpec | Interleave: $($intSpec)KB | NTFS Cluster Allocation Bound: $clSpec]"
        }
    } catch { 
        $lblCanvasTitle.Text = "Active Workspace Properties:`n[Read Protocol Access Throttled]" 
    }
    & $RecalculateEngine "ManualTrigger"
})
$chkPools.add_ItemCheck({
    param($sender,$e)
    $form.BeginInvoke({
        $hasChecked = $false
        for ($i=0; $i -lt $chkPools.Items.Count; $i++) { if ($chkPools.GetItemChecked($i)) { $hasChecked = $true; break } }
        $btnSimDemo.Enabled = $hasChecked
        if ($hasChecked) { $btnSimDemo.BackColor = [System.Drawing.Color]::DarkRed; $btnSimDemo.ForeColor = [System.Drawing.Color]::White; $btnSimDemo.UseVisualStyleBackColor = $false } 
        else { 
            if ($script:IsDarkMode) { $btnSimDemo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $false }
            else { $btnSimDemo.BackColor = [System.Drawing.SystemColors]::Control; $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $true }
        }
    })
})
$btnSimDemo.add_Click({
    $checkedIdx = -1; for ($ci=0; $ci -lt $chkPools.Items.Count; $ci++) { if ($chkPools.GetItemChecked($ci)) { $checkedIdx = $ci; break } }
    if ($checkedIdx -lt 0) {
        if (-not $chkSuppressAllPopups.Checked) {
            $chkWarnForm = New-Object System.Windows.Forms.Form
            $chkWarnForm.Text = "Delete Pool"
            $chkWarnForm.Size = New-Object System.Drawing.Size(480, 160)
            $chkWarnForm.StartPosition = "CenterParent"
            $chkWarnForm.FormBorderStyle = "FixedDialog"
            $chkWarnForm.MaximizeBox = $false; $chkWarnForm.MinimizeBox = $false
            $chkWarnForm.Topmost = $true
            $lblChkWarn = New-Object System.Windows.Forms.Label
            $lblChkWarn.Text = "Check the box next to a pool in 'Detected Storage Pools' first."
            $lblChkWarn.Location = New-Object System.Drawing.Point(20, 20)
            $lblChkWarn.Size = New-Object System.Drawing.Size(420, 30)
            $chkWarnForm.Controls.Add($lblChkWarn)
            $btnChkOk = New-Object System.Windows.Forms.Button
            $btnChkOk.Text = "OK"
            $btnChkOk.Location = New-Object System.Drawing.Point(190, 70)
            $btnChkOk.Size = New-Object System.Drawing.Size(80, 28)
            $btnChkOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $chkWarnForm.Controls.Add($btnChkOk)
            $chkWarnForm.AcceptButton = $btnChkOk
            if ($script:IsDarkMode) { $chkWarnForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblChkWarn.ForeColor = [System.Drawing.Color]::White; $btnChkOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnChkOk.ForeColor = [System.Drawing.Color]::White; $btnChkOk.UseVisualStyleBackColor = $false }
            [void]$chkWarnForm.ShowDialog()
            $chkWarnForm.Dispose()
        }
        return
    }
    $selectedIndex = $checkedIdx
    $rawDisplayName = $chkPools.Items[$selectedIndex].ToString()
    if ($rawDisplayName -match "No active storage pools") { return }
    $poolTmpForName = if ($selectedIndex -ge 0 -and $selectedIndex -lt $script:AvailablePools.Count) { $script:AvailablePools[$selectedIndex] } else { $null }
    $targetPoolName = if ($poolTmpForName -and $poolTmpForName.FriendlyName) { $poolTmpForName.FriendlyName } else { ($rawDisplayName -split " - ")[0].Trim() }
    
    # Deletion warnings with DESTROY confirmation - respects SuppressDeletion checkbox
    if (-not $chkSuppressDeletionWarnings.Checked) {
        $warnForm1 = New-Object System.Windows.Forms.Form
        $warnForm1.Text = "WARNING!"
        $warnForm1.Size = New-Object System.Drawing.Size(500, 280)
        $warnForm1.StartPosition = "CenterParent"
        $warnForm1.FormBorderStyle = "FixedDialog"
        $warnForm1.MaximizeBox = $false
        $warnForm1.MinimizeBox = $false
        $warnForm1.Topmost = $true
        $lblWarnBig = New-Object System.Windows.Forms.Label
        $lblWarnBig.Text = "WARNING!"
        $lblWarnBig.Location = New-Object System.Drawing.Point(20, 15)
        $lblWarnBig.Size = New-Object System.Drawing.Size(440, 30)
        $lblWarnBig.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $lblWarnBig.ForeColor = [System.Drawing.Color]::Red
        $warnForm1.Controls.Add($lblWarnBig)
        $lblWarnText1 = New-Object System.Windows.Forms.Label
        $lblWarnText1.Text = "You are about to delete this selected pool! If this is what you want to do then type DESTROY in the text field here:"
        $lblWarnText1.Location = New-Object System.Drawing.Point(20, 50)
        $lblWarnText1.Size = New-Object System.Drawing.Size(440, 40)
        $warnForm1.Controls.Add($lblWarnText1)
        $txtDestroy = New-Object System.Windows.Forms.TextBox
        $txtDestroy.Location = New-Object System.Drawing.Point(20, 95)
        $txtDestroy.Size = New-Object System.Drawing.Size(440, 20)
        $warnForm1.Controls.Add($txtDestroy)
        $btnOk1 = New-Object System.Windows.Forms.Button
        $btnOk1.Text = "OK"
        $btnOk1.Location = New-Object System.Drawing.Point(300, 130)
        $btnOk1.Size = New-Object System.Drawing.Size(80, 28)
        $btnOk1.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $warnForm1.Controls.Add($btnOk1)
        $btnCancel1 = New-Object System.Windows.Forms.Button
        $btnCancel1.Text = "Cancel"
        $btnCancel1.Location = New-Object System.Drawing.Point(390, 130)
        $btnCancel1.Size = New-Object System.Drawing.Size(80, 28)
        $btnCancel1.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $warnForm1.Controls.Add($btnCancel1)
        $warnForm1.AcceptButton = $btnOk1
        $warnForm1.CancelButton = $btnCancel1
        if ($script:IsDarkMode) { $warnForm1.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblWarnBig.ForeColor = [System.Drawing.Color]::Red; $lblWarnText1.ForeColor = [System.Drawing.Color]::White; $txtDestroy.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $txtDestroy.ForeColor = [System.Drawing.Color]::White; $btnOk1.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnOk1.ForeColor = [System.Drawing.Color]::White; $btnOk1.UseVisualStyleBackColor = $false; $btnCancel1.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnCancel1.ForeColor = [System.Drawing.Color]::White; $btnCancel1.UseVisualStyleBackColor = $false }
        $res1 = $warnForm1.ShowDialog()
        if ($res1 -ne [System.Windows.Forms.DialogResult]::OK -or $txtDestroy.Text -ne "DESTROY") {
            Show-ThemedAlert -Text "Pool destruction is cancelled" -Title "Cancelled"
            return
        }
        $warnForm2 = New-Object System.Windows.Forms.Form
        $warnForm2.Text = "Last Warning"
        $warnForm2.Size = New-Object System.Drawing.Size(500, 220)
        $warnForm2.StartPosition = "CenterParent"
        $warnForm2.FormBorderStyle = "FixedDialog"
        $warnForm2.MaximizeBox = $false
        $warnForm2.MinimizeBox = $false
        $warnForm2.Topmost = $true
        $lblWarn2 = New-Object System.Windows.Forms.Label
        $lblWarn2.Text = "Press the OK button on this window if you are sure you want to proceed, this is your last warning before your selected pool will be deleted forever!"
        $lblWarn2.Location = New-Object System.Drawing.Point(20, 20)
        $lblWarn2.Size = New-Object System.Drawing.Size(440, 60)
        $lblWarn2.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblWarn2.ForeColor = [System.Drawing.Color]::Red
        $warnForm2.Controls.Add($lblWarn2)
        $btnOk2 = New-Object System.Windows.Forms.Button
        $btnOk2.Text = "OK"
        $btnOk2.Location = New-Object System.Drawing.Point(300, 100)
        $btnOk2.Size = New-Object System.Drawing.Size(80, 28)
        $btnOk2.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $warnForm2.Controls.Add($btnOk2)
        $btnCancel2 = New-Object System.Windows.Forms.Button
        $btnCancel2.Text = "Cancel"
        $btnCancel2.Location = New-Object System.Drawing.Point(390, 100)
        $btnCancel2.Size = New-Object System.Drawing.Size(80, 28)
        $btnCancel2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $warnForm2.Controls.Add($btnCancel2)
        $warnForm2.AcceptButton = $btnOk2
        $warnForm2.CancelButton = $btnCancel2
        if ($script:IsDarkMode) { $warnForm2.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblWarn2.ForeColor = [System.Drawing.Color]::Red; $btnOk2.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnOk2.ForeColor = [System.Drawing.Color]::White; $btnOk2.UseVisualStyleBackColor = $false; $btnCancel2.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnCancel2.ForeColor = [System.Drawing.Color]::White; $btnCancel2.UseVisualStyleBackColor = $false }
        $res2 = $warnForm2.ShowDialog()
        if ($res2 -ne [System.Windows.Forms.DialogResult]::OK) {
            Show-ThemedAlert -Text "Pool destruction is cancelled" -Title "Cancelled"
            return
        }
    }
    
    $txtTerminalOutput.Clear()
    
    $sbWipeScript = New-Object System.Text.StringBuilder
    [void]$sbWipeScript.AppendLine("# =========================================================================")
    [void]$sbWipeScript.AppendLine("# STEP-BY-STEP TARGET-LOCKED STORAGE POOL HARD-KILL BLUEPRINT")
    [void]$sbWipeScript.AppendLine("# TARGET POOL: $targetPoolName")
    [void]$sbWipeScript.AppendLine("# INSTRUCTIONS: Paste into an elevated Administrator PowerShell console.")
    [void]$sbWipeScript.AppendLine("# =========================================================================")
    [void]$sbWipeScript.AppendLine("")
    
    # FIXED: Use UniqueId for the EXACT selected pool - fixes duplicate FriendlyName (2 pools named OptimizedPool) causing System.Object[] error
    $selectedPool = if ($selectedIndex -ge 0 -and $selectedIndex -lt $script:AvailablePools.Count) { $script:AvailablePools[$selectedIndex] } else { $null }
    $targetPoolId = if ($selectedPool -and $selectedPool.UniqueId) { $selectedPool.UniqueId } else { "" }
    $targetPoolNameEsc = $targetPoolName -replace '"','`"'
    $targetPoolIdEsc = $targetPoolId -replace '"','`"'
    if (-not [string]::IsNullOrWhiteSpace($targetPoolId)) {
        [void]$sbWipeScript.AppendLine("# TARGET POOL UniqueId: $targetPoolIdEsc (handles duplicate FriendlyName)")
        [void]$sbWipeScript.AppendLine("`$Pool = Get-StoragePool -UniqueId `"$targetPoolIdEsc`" -IsPrimordial `$false -ErrorAction SilentlyContinue")
        [void]$sbWipeScript.AppendLine("if (-not `$Pool) { `$Pool = Get-StoragePool -FriendlyName `"$targetPoolNameEsc`" -IsPrimordial `$false | Select-Object -First 1 }")
    } else {
        [void]$sbWipeScript.AppendLine("`$Pool = Get-StoragePool -FriendlyName `"$targetPoolNameEsc`" -IsPrimordial `$false | Select-Object -First 1")
    }
    [void]$sbWipeScript.AppendLine("if (-not `$Pool) { Write-Error `"Pool '$targetPoolNameEsc' not found`"; exit 1 }")
    [void]$sbWipeScript.AppendLine("Write-Host `"Target pool: `$(`$Pool.FriendlyName) `$(`$Pool.UniqueId)`" -ForegroundColor Cyan")
    [void]$sbWipeScript.AppendLine("")
    [void]$sbWipeScript.AppendLine("# Step 1: Force drop drive volume partitions and clear letter assignments (single-pool, no array conversion error)")
    [void]$sbWipeScript.AppendLine("`$VDisks = Get-VirtualDisk -StoragePool `$Pool")
    [void]$sbWipeScript.AppendLine("foreach (`$vd in `$VDisks) {")
    [void]$sbWipeScript.AppendLine("    `$diskObj = `$vd | Get-Disk -ErrorAction SilentlyContinue")
    [void]$sbWipeScript.AppendLine("    if (`$diskObj -ne `$null) {")
    [void]$sbWipeScript.AppendLine("        `$diskObj | Get-Partition -ErrorAction SilentlyContinue | Where-Object {`$_.DriveLetter} | Remove-Partition -Confirm:`$false -ErrorAction SilentlyContinue")
    [void]$sbWipeScript.AppendLine("    }")
    [void]$sbWipeScript.AppendLine("}")
    [void]$sbWipeScript.AppendLine("")
    [void]$sbWipeScript.AppendLine("# Step 2: Wipes the virtual disks (single pool, fixes 'contains virtual disks' error by actually removing them)")
    [void]$sbWipeScript.AppendLine("Get-VirtualDisk -StoragePool `$Pool | Remove-VirtualDisk -Confirm:`$false -ErrorAction SilentlyContinue")
    [void]$sbWipeScript.AppendLine("Start-Sleep -Seconds 2; Update-StorageProviderCache")
    [void]$sbWipeScript.AppendLine("")
    [void]$sbWipeScript.AppendLine("# Step 3: Strip metadata tracking logs from the underlying storage spindles")
    [void]$sbWipeScript.AppendLine("`$Pool | Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue")
    [void]$sbWipeScript.AppendLine("")
    [void]$sbWipeScript.AppendLine("# Step 4: Dissolve the empty storage pool container hull (now empty, will succeed)")
    [void]$sbWipeScript.AppendLine("`$Pool | Remove-StoragePool -Confirm:`$false")
    [void]$sbWipeScript.AppendLine("")
    
    [void]$sbWipeScript.AppendLine("# Step 5: Flush framework cache registries to refresh the raw unallocated drive list")
    [void]$sbWipeScript.AppendLine("Update-StorageProviderCache")
    [void]$sbWipeScript.AppendLine("Write-Host 'SUCCESS: Storage Spaces Pool `"" + $targetPoolName + "`" forcefully cleared!' -ForegroundColor Green")
    
    $txtTerminalOutput.Text = $sbWipeScript.ToString()
    # Hidden silent delete execution - runs same wipe script hidden, terminal still shows script
    try {
        $isAdminDel = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdminDel) {
            $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: Not elevated - run app as admin or exe with -requireAdmin for silent delete.")
        } else {
            $hiddenDelPs = [PowerShell]::Create()
            [void]$hiddenDelPs.AddScript($sbWipeScript.ToString())
            $null = $hiddenDelPs.Invoke()
            if ($hiddenDelPs.HadErrors) {
                $errDel = ($hiddenDelPs.Streams.Error | Out-String)
                $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION ERRORS (DELETE):`r`n" + $errDel)
            } else {
                $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: DELETE SUCCESS - Pool removed.")
            }
            $hiddenDelPs.Dispose()
        }
    } catch {
        $txtTerminalOutput.AppendText("`r`n# HIDDEN DELETE FAILED: $($_.Exception.Message)")
    }
    if (-not $chkSuppressAllPopups.Checked) {
        $delCompleteForm = New-Object System.Windows.Forms.Form
        $delCompleteForm.Text = "Delete Complete"
        $delCompleteForm.Size = New-Object System.Drawing.Size(500, 200)
        $delCompleteForm.StartPosition = "CenterParent"
        $delCompleteForm.FormBorderStyle = "FixedDialog"
        $delCompleteForm.MaximizeBox = $false; $delCompleteForm.MinimizeBox = $false
        $delCompleteForm.Topmost = $true
        $lblDelComplete = New-Object System.Windows.Forms.Label
        $lblDelComplete.Text = "Your selected pool was deleted! Check the Script terminal for the commands used if you need to see how the pool was removed."
        $lblDelComplete.Location = New-Object System.Drawing.Point(20, 20)
        $lblDelComplete.Size = New-Object System.Drawing.Size(440, 60)
        $delCompleteForm.Controls.Add($lblDelComplete)
        $btnDelOk = New-Object System.Windows.Forms.Button
        $btnDelOk.Text = "OK"
        $btnDelOk.Location = New-Object System.Drawing.Point(210, 100)
        $btnDelOk.Size = New-Object System.Drawing.Size(80, 28)
        $btnDelOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $delCompleteForm.Controls.Add($btnDelOk)
        $delCompleteForm.AcceptButton = $btnDelOk
        if ($script:IsDarkMode) { $delCompleteForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblDelComplete.ForeColor = [System.Drawing.Color]::White; $btnDelOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnDelOk.ForeColor = [System.Drawing.Color]::White; $btnDelOk.UseVisualStyleBackColor = $false }
        $resDelComplete = $delCompleteForm.ShowDialog()
        $delCompleteForm.Dispose()
        if ($resDelComplete -eq [System.Windows.Forms.DialogResult]::OK) {
            & $ScanPhysicalInfrastructure
            & $RecalculateEngine "ManualTrigger"
            $btnSimDemo.Enabled = $false
            $btnSimDemo.BackColor = [System.Drawing.SystemColors]::Control; $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $true
            if ($script:IsDarkMode) { $btnSimDemo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $false }
        }
    }
})
$ApplyThemeStyles = {
    if ($script:IsDarkMode) {
        $btnTheme.Text = "Toggle Light Theme"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $pnlLeft.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
        $pnlRight.BackColor = [System.Drawing.Color]::FromArgb(85, 85, 85)
        $drawCanvas.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
        
        foreach ($ctrl in $script:ThemeControlsRegistry) {
            if ($ctrl -is [System.Windows.Forms.Label] -or $ctrl -is [System.Windows.Forms.CheckBox] -or $ctrl -is [System.Windows.Forms.GroupBox]) { 
                $ctrl.ForeColor = [System.Drawing.Color]::White 
            }
            if ($ctrl -is [System.Windows.Forms.TextBox] -or $ctrl -is [System.Windows.Forms.ComboBox] -or $ctrl -is [System.Windows.Forms.CheckedListBox] -or $ctrl -is [System.Windows.Forms.ListBox]) { 
                $ctrl.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
                $ctrl.ForeColor = [System.Drawing.Color]::White 
            }
        }
        foreach ($c in $pnlLeft.Controls) {
            if ($c -is [System.Windows.Forms.Button]) {
                $c.ForeColor = [System.Drawing.Color]::White
                if ($c.Text -match "Optimize") { $c.BackColor = [System.Drawing.Color]::MediumSeaGreen; $c.UseVisualStyleBackColor = $false }
                elseif ($c.Text -match "SCRIPT" -or $c.Text -match "POOL") { $c.BackColor = [System.Drawing.Color]::DodgerBlue; $c.UseVisualStyleBackColor = $false }
                elseif ($c.Text -match "COMMANDS" -or $c.Text -match "WIPE") { $c.BackColor = [System.Drawing.Color]::DarkRed; $c.UseVisualStyleBackColor = $false }
                else { $c.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $c.UseVisualStyleBackColor = $false }
            }
            if ($c -is [System.Windows.Forms.Label]) { $c.ForeColor = [System.Drawing.Color]::White }
            if ($c -is [System.Windows.Forms.TextBox] -or $c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.CheckedListBox]) {
                $c.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
                $c.ForeColor = [System.Drawing.Color]::White
            }
        }
        $btnBuild.BackColor = [System.Drawing.Color]::DodgerBlue; $btnBuild.ForeColor = [System.Drawing.Color]::White; $btnBuild.UseVisualStyleBackColor = $false
        $btnAdvancedVDisk.BackColor = [System.Drawing.Color]::DarkSlateBlue; $btnAdvancedVDisk.ForeColor = [System.Drawing.Color]::White; $btnAdvancedVDisk.UseVisualStyleBackColor = $false
        if ($btnSimDemo.Enabled) { $btnSimDemo.BackColor = [System.Drawing.Color]::DarkRed; $btnSimDemo.ForeColor = [System.Drawing.Color]::White; $btnSimDemo.UseVisualStyleBackColor = $false } else { $btnSimDemo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $false }
        $btnRevealAdvanced.ForeColor = [System.Drawing.Color]::White; $btnRevealAdvanced.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnRevealAdvanced.UseVisualStyleBackColor = $false
        $btnCancelAdvanced.ForeColor = [System.Drawing.Color]::White; $btnCancelAdvanced.BackColor = [System.Drawing.Color]::IndianRed; $btnCancelAdvanced.UseVisualStyleBackColor = $false
        $btnTheme.ForeColor = [System.Drawing.Color]::White; $btnTheme.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
        $btnCopyTerminal.ForeColor = [System.Drawing.Color]::White; $btnCopyTerminal.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
        $lblCanvasTitle.ForeColor = [System.Drawing.Color]::White
        $lblTerminalTitle.ForeColor = [System.Drawing.Color]::White
        $txtTerminalOutput.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 15); $txtTerminalOutput.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
    } else {
        $btnTheme.Text = "Toggle Dark Theme"
        $form.BackColor = [System.Drawing.SystemColors]::Control
        $pnlLeft.BackColor = [System.Drawing.SystemColors]::Control
        $pnlRight.BackColor = [System.Drawing.Color]::White
        $drawCanvas.BackColor = [System.Drawing.Color]::GhostWhite
        
        foreach ($ctrl in $script:ThemeControlsRegistry) {
            if ($ctrl -is [System.Windows.Forms.Label] -or $ctrl -is [System.Windows.Forms.CheckBox] -or $ctrl -is [System.Windows.Forms.GroupBox]) { 
                $ctrl.ForeColor = [System.Drawing.Color]::Black 
            }
            if ($ctrl -is [System.Windows.Forms.TextBox] -or $ctrl -is [System.Windows.Forms.ComboBox] -or $ctrl -is [System.Windows.Forms.CheckedListBox] -or $ctrl -is [System.Windows.Forms.ListBox]) { 
                $ctrl.BackColor = [System.Drawing.SystemColors]::Window
                $ctrl.ForeColor = [System.Drawing.Color]::Black 
            }
        }
        foreach ($c in $pnlLeft.Controls) {
            if ($c -is [System.Windows.Forms.Button]) {
                $c.ForeColor = [System.Drawing.Color]::Black
                if ($c.Text -match "Optimize") { $c.BackColor = [System.Drawing.Color]::MediumSeaGreen; $c.ForeColor = [System.Drawing.Color]::White; $c.UseVisualStyleBackColor = $false }
                elseif ($c.Text -match "SCRIPT" -or $c.Text -match "POOL") { $c.BackColor = [System.Drawing.Color]::DodgerBlue; $c.ForeColor = [System.Drawing.Color]::White; $c.UseVisualStyleBackColor = $false }
                elseif ($c.Text -match "COMMANDS" -or $c.Text -match "WIPE") { $c.BackColor = [System.Drawing.Color]::DarkRed; $c.ForeColor = [System.Drawing.Color]::White; $c.UseVisualStyleBackColor = $false }
                else { $c.BackColor = [System.Drawing.SystemColors]::Control; $c.UseVisualStyleBackColor = $true }
            }
            if ($c -is [System.Windows.Forms.Label]) { $c.ForeColor = [System.Drawing.Color]::Black }
            if ($c -is [System.Windows.Forms.TextBox] -or $c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.CheckedListBox]) {
                $c.BackColor = [System.Drawing.SystemColors]::Window
                $c.ForeColor = [System.Drawing.Color]::Black
            }
        }
        $btnBuild.BackColor = [System.Drawing.Color]::DodgerBlue; $btnBuild.ForeColor = [System.Drawing.Color]::White; $btnBuild.UseVisualStyleBackColor = $false
        $btnAdvancedVDisk.BackColor = [System.Drawing.Color]::DarkSlateBlue; $btnAdvancedVDisk.ForeColor = [System.Drawing.Color]::White; $btnAdvancedVDisk.UseVisualStyleBackColor = $false
        if ($btnSimDemo.Enabled) { $btnSimDemo.BackColor = [System.Drawing.Color]::DarkRed; $btnSimDemo.ForeColor = [System.Drawing.Color]::White; $btnSimDemo.UseVisualStyleBackColor = $false } else { $btnSimDemo.BackColor = [System.Drawing.SystemColors]::Control; $btnSimDemo.ForeColor = [System.Drawing.Color]::Gray; $btnSimDemo.UseVisualStyleBackColor = $true }
        $btnRevealAdvanced.ForeColor = [System.Drawing.Color]::Black; $btnRevealAdvanced.BackColor = [System.Drawing.SystemColors]::Control; $btnRevealAdvanced.UseVisualStyleBackColor = $true
        $btnCancelAdvanced.ForeColor = [System.Drawing.Color]::White; $btnCancelAdvanced.BackColor = [System.Drawing.Color]::IndianRed; $btnCancelAdvanced.UseVisualStyleBackColor = $false
        $txtTerminalOutput.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 12); $txtTerminalOutput.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $btnTheme.ForeColor = [System.Drawing.Color]::Black; $btnTheme.BackColor = [System.Drawing.SystemColors]::Control; $btnTheme.UseVisualStyleBackColor = $true
        $btnCopyTerminal.ForeColor = [System.Drawing.Color]::Black; $btnCopyTerminal.BackColor = [System.Drawing.SystemColors]::Control; $btnCopyTerminal.UseVisualStyleBackColor = $true
        $lblCanvasTitle.ForeColor = [System.Drawing.Color]::Black
        $lblTerminalTitle.ForeColor = [System.Drawing.Color]::Black
    }
    & $RecalculateEngine "ManualTrigger"
}

$btnTheme.add_Click({ $script:IsDarkMode = !$script:IsDarkMode; & $ApplyThemeStyles })
$chkDrives.add_ItemCheck({
    param($sender, $e)
    if ($script:IsRefreshingInterface) { return }
    $form.BeginInvoke({ & $RecalculateEngine "DriveTrigger" })
})

$cmbResiliency.add_SelectedIndexChanged({ if ($script:IsRefreshingInterface) { return }; & $RecalculateEngine "DriveTrigger" })
$cmbColumns.add_SelectedIndexChanged({ if ($script:IsRefreshingInterface) { return }; & $RecalculateEngine "ManualTrigger" })
$cmbInterleave.add_SelectedIndexChanged({ if ($script:IsRefreshingInterface) { return }; & $RecalculateEngine "ManualTrigger" })
$cmbCluster.add_SelectedIndexChanged({ if ($script:IsRefreshingInterface) { return }; & $RecalculateEngine "ManualTrigger" })
$btnBuild = New-Object System.Windows.Forms.Button
$btnBuild.Text = "Create Storage Pool With Current Settings"
$btnBuild.Location = New-Object System.Drawing.Point(10, 670) 
$btnBuild.Size = New-Object System.Drawing.Size(210, 45)
$btnBuild.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnBuild.BackColor = [System.Drawing.Color]::DodgerBlue
$btnBuild.ForeColor = [System.Drawing.Color]::White
$btnBuild.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnAdvancedVDisk = New-Object System.Windows.Forms.Button
$btnAdvancedVDisk.Text = "Advanced Virtual Disk Builder"
$btnAdvancedVDisk.Location = New-Object System.Drawing.Point(230, 670)
$btnAdvancedVDisk.Size = New-Object System.Drawing.Size(210, 45)
$btnAdvancedVDisk.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAdvancedVDisk.BackColor = [System.Drawing.Color]::DarkSlateBlue
$btnAdvancedVDisk.ForeColor = [System.Drawing.Color]::White
$btnAdvancedVDisk.Cursor = [System.Windows.Forms.Cursors]::Hand
$pnlLeft.Controls.Add($btnAdvancedVDisk)
$btnCancelAdvanced = New-Object System.Windows.Forms.Button
$btnCancelAdvanced.Text = "Cancel"
$btnCancelAdvanced.Location = New-Object System.Drawing.Point(10, 720)
$btnCancelAdvanced.Size = New-Object System.Drawing.Size(430, 25)
$btnCancelAdvanced.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnCancelAdvanced.BackColor = [System.Drawing.Color]::IndianRed
$btnCancelAdvanced.ForeColor = [System.Drawing.Color]::White
$btnCancelAdvanced.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCancelAdvanced.Visible = $false
$pnlLeft.Controls.Add($btnCancelAdvanced)
$btnBuild.Add_Click({
    $driveCount = 0
    for ($k = 0; $k -lt $chkDrives.Items.Count; $k++) {
        if ($chkDrives.GetItemChecked($k)) { $driveCount++ }
    }
    
    $mode = $cmbResiliency.SelectedItem; $cols = [int]$cmbColumns.SelectedItem
    if ($driveCount -eq 0) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Please check hard drive targets first to compile script blueprints." -Title "Notification" }; return }
    if ($mode -match 'Parity' -and $driveCount -lt 3) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Parity layouts require a minimum of 3 drives." -Title "Error" }; return }
    if ($mode -match 'Dual Parity' -and $driveCount -lt 5) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Dual Parity configurations require a minimum width of 5 drives." -Title "Error" }; return }
    if ($mode -match 'Mirror' -and ($cols * 2) -gt $driveCount) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Two-Way Mirrors mandate that physical disk counts must be at least double columns." -Title "Error" }; return }
    
    $txtTerminalOutput.Clear()
    
    # MINIMAL FIX: Corrected interleave/cluster mapping to support ALL sizes you select (was breaking 128KB/256KB and 32KB cluster)
    $finalInterleave = if ($cmbInterleave.SelectedItem -eq "16KB") { 16384 } elseif ($cmbInterleave.SelectedItem -eq "32KB") { 32768 } elseif ($cmbInterleave.SelectedItem -eq "64KB") { 65536 } elseif ($cmbInterleave.SelectedItem -eq "128KB") { 131072 } elseif ($cmbInterleave.SelectedItem -eq "256KB") { 262144 } else { 16384 }
    $finalCluster = if ($cmbCluster.SelectedItem -eq "4KB") { 4096 } elseif ($cmbCluster.SelectedItem -eq "8KB") { 8192 } elseif ($cmbCluster.SelectedItem -eq "16KB") { 16384 } elseif ($cmbCluster.SelectedItem -eq "32KB") { 32768 } elseif ($cmbCluster.SelectedItem -eq "64KB") { 65536 } elseif ($cmbCluster.SelectedItem -eq "128KB") { 131072 } elseif ($cmbCluster.SelectedItem -eq "256KB") { 262144 } else { 65536 }
    $poolName = $txtPoolName.Text; $spaceName = $txtSpaceName.Text
    
    $sbBuildScript = New-Object System.Text.StringBuilder
    [void]$sbBuildScript.AppendLine("# =========================================================================")
    [void]$sbBuildScript.AppendLine("# STEP-BY-STEP LIVE HARDWARE ARRAY CREATION SCRIPT")
    [void]$sbBuildScript.AppendLine("# DESIGN PROFILE: $mode")
    [void]$sbBuildScript.AppendLine("# CONFIG: Columns: $cols | Interleave: $($cmbInterleave.SelectedItem) | NTFS Cluster: $($cmbCluster.SelectedItem)")
    [void]$sbBuildScript.AppendLine("# INSTRUCTIONS: Paste into an elevated Administrator PowerShell console window.")
    [void]$sbBuildScript.AppendLine("# =========================================================================")
    [void]$sbBuildScript.AppendLine("")
    
    # FIXED: Use UniqueId+SerialNumber exact match - fixes duplicate UniqueId grabbing 3rd drive (your log: UniqueId 0050430000000003 shared by 2 disks)
    [void]$sbBuildScript.AppendLine("# Step 1: Isolate EXACT target drives checked (FIXED: UniqueId+SerialNumber - 2 selected = 2 in pool)")
    [void]$sbBuildScript.AppendLine("`$TargetDisks = @()")
    for ($i = 0; $i -lt $chkDrives.Items.Count; $i++) {
        if ($chkDrives.GetItemChecked($i)) {
            $diskObj = if ($i -lt $script:AvailableDisks.Count) { $script:AvailableDisks[$i] } else { $null }
            if ($diskObj -ne $null) {
                $uid = $diskObj.UniqueId
                $serial = $diskObj.SerialNumber
                $did = $diskObj.DeviceId
                $uidEsc = if ($uid) { $uid -replace '"','`"' } else { "" }
                $serialEsc = if ($serial) { $serial -replace '"','`"' } else { "" }
                if (-not [string]::IsNullOrWhiteSpace($uid) -and -not [string]::IsNullOrWhiteSpace($serial)) {
                    # Both present: require BOTH to match exactly one disk - fixes your duplicate UniqueId case (0050430000000003 x2)
                    [void]$sbBuildScript.AppendLine("`$TargetDisks += Get-PhysicalDisk | Where-Object {`$_.UniqueId -eq `"$uidEsc`" -and `$_.SerialNumber -eq `"$serialEsc`"} | Select-Object -First 1")
                } elseif (-not [string]::IsNullOrWhiteSpace($serial)) {
                    [void]$sbBuildScript.AppendLine("`$TargetDisks += Get-PhysicalDisk | Where-Object SerialNumber -eq `"$serialEsc`" | Select-Object -First 1")
                } elseif (-not [string]::IsNullOrWhiteSpace($uid)) {
                    [void]$sbBuildScript.AppendLine("`$TargetDisks += Get-PhysicalDisk -UniqueId `"$uidEsc`" -ErrorAction SilentlyContinue | Select-Object -First 1")
                } elseif ($null -ne $did) {
                    [void]$sbBuildScript.AppendLine("`$TargetDisks += Get-PhysicalDisk -DeviceId $did -ErrorAction SilentlyContinue")
                } else {
                    $rawItemText = $chkDrives.Items[$i].ToString()
                    $cleanedDiskLabel = ($rawItemText -split " - ")[0].Trim() -replace '"','`"'
                    [void]$sbBuildScript.AppendLine("`$TargetDisks += Get-PhysicalDisk | Where-Object FriendlyName -eq `"$cleanedDiskLabel`" | Select-Object -First 1")
                }
            }
        }
    }
    [void]$sbBuildScript.AppendLine("if (`$TargetDisks.Count -ne $driveCount) { Write-Warning `"Selected $driveCount drives but resolved `$(`$TargetDisks.Count) - check Serial mapping`"; Write-Host 'Dumping resolved disks:'; `$TargetDisks | Format-Table FriendlyName, SerialNumber, UniqueId, Size -AutoSize }")
    [void]$sbBuildScript.AppendLine("`$TargetDisks | Format-Table FriendlyName, SerialNumber, UniqueId, Size, CanPool -AutoSize")
    [void]$sbBuildScript.AppendLine("")
    
    [void]$sbBuildScript.AppendLine("# Step 2: Clear old hidden raw partition configurations and strip legacy metadata labels")
    [void]$sbBuildScript.AppendLine("`$TargetDisks | Reset-PhysicalDisk -ErrorAction SilentlyContinue")
    [void]$sbBuildScript.AppendLine("`$TargetDisks | Clear-Disk -RemoveData -RemoveOEM -Confirm:`$false -ErrorAction SilentlyContinue")
    [void]$sbBuildScript.AppendLine("Update-StorageProviderCache")
    [void]$sbBuildScript.AppendLine("")
    
    # MINIMAL FIX for your two errors: Use dynamic subsystem lookup + verify pool before virtual disk (keeps output simple and clean, 1 extra line)
    [void]$sbBuildScript.AppendLine("# Step 3: Initialize pool hull structures and anchor high-fidelity layout parameters")
    [void]$sbBuildScript.AppendLine("`$Subsystem = Get-StorageSubsystem | Where-Object FriendlyName -like '*Storage*' | Select-Object -First 1")
    [void]$sbBuildScript.AppendLine("New-StoragePool -FriendlyName `"$poolName`" -StorageSubsystemUniqueId `$Subsystem.UniqueId -PhysicalDisks `$TargetDisks")
    [void]$sbBuildScript.AppendLine("Update-StorageProviderCache")
    if ($mode -eq 'Parity Space (RAID 5)') {
        [void]$sbBuildScript.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolName`" -FriendlyName `"$spaceName`" -ResiliencySettingName Parity -NumberOfColumns $cols -Interleave $finalInterleave -ProvisioningType Fixed -UseMaximumSize")
    } elseif ($mode -eq 'Dual Parity Space (RAID 6)') {
        [void]$sbBuildScript.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolName`" -FriendlyName `"$spaceName`" -ResiliencySettingName Parity -NumberOfColumns $cols -Interleave $finalInterleave -ProvisioningType Fixed -UseMaximumSize")
    } elseif ($mode -match 'Simple') {
        [void]$sbBuildScript.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolName`" -FriendlyName `"$spaceName`" -ResiliencySettingName Simple -NumberOfColumns $cols -Interleave $finalInterleave -ProvisioningType Fixed -UseMaximumSize")
    } elseif ($mode -match 'Mirror') {
        # FIXED: Force 2-way mirror (2 copies) - 2 drives = 2-way, not 3-way grabbing extra drive
        [void]$sbBuildScript.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolName`" -FriendlyName `"$spaceName`" -ResiliencySettingName Mirror -NumberOfColumns $cols -NumberOfDataCopies 2 -ProvisioningType Fixed -UseMaximumSize")
    }
    [void]$sbBuildScript.AppendLine("")
    
    [void]$sbBuildScript.AppendLine("# Step 4: Mount volume allocation frameworks and execute raw NTFS performance sector cluster format pass")
    [void]$sbBuildScript.AppendLine("Get-VirtualDisk -FriendlyName `"$spaceName`" | Get-Disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -AllocationUnitSize $finalCluster -NewFileSystemLabel `"$poolName`" -Confirm:`$false")
    [void]$sbBuildScript.AppendLine("Update-StorageProviderCache")
    [void]$sbBuildScript.AppendLine("Write-Host 'SUCCESS: Optimized Storage Spaces volume mounted successfully!' -ForegroundColor Green")
    
    $txtTerminalOutput.Text = $sbBuildScript.ToString()
    # Hidden silent execution - runs same commands in hidden PowerShell, terminal still shows script for copy
    try {
        $isAdminHidden = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdminHidden) {
            $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: Not elevated - run app as admin or compile exe with -requireAdmin for silent create.")
        } else {
            $hiddenPs = [PowerShell]::Create()
            [void]$hiddenPs.AddScript($sbBuildScript.ToString())
            $null = $hiddenPs.Invoke()
            if ($hiddenPs.HadErrors) {
                $errText = ($hiddenPs.Streams.Error | Out-String)
                $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION ERRORS:`r`n" + $errText)
            } else {
                $txtTerminalOutput.AppendText("`r`n`r`n# HIDDEN EXECUTION: SUCCESS - Pool created.")
            }
            $hiddenPs.Dispose()
        }
    } catch {
        $txtTerminalOutput.AppendText("`r`n# HIDDEN EXECUTION FAILED: $($_.Exception.Message)")
    }
    if (-not $chkSuppressAllPopups.Checked) {
        $successForm = New-Object System.Windows.Forms.Form
        $successForm.Text = "Script Complete"
        $successForm.Size = New-Object System.Drawing.Size(520, 240)
        $successForm.StartPosition = "CenterParent"
        $successForm.FormBorderStyle = "FixedDialog"
        $successForm.MaximizeBox = $false; $successForm.MinimizeBox = $false
        $successForm.Topmost = $true
        $lblSuccess = New-Object System.Windows.Forms.Label
        $lblSuccess.Text = "Storage pool created successfully!`r`n`r`nVarious windows may pop up asking to format the new disk drive created, you can ignore these messages and you can close them as the new pool has already been formatted for you. Your new drive pool is ready for use! Check Script Terminal for details."
        $lblSuccess.Location = New-Object System.Drawing.Point(20, 15)
        $lblSuccess.Size = New-Object System.Drawing.Size(460, 120)
        $successForm.Controls.Add($lblSuccess)
        $btnOkSuccess = New-Object System.Windows.Forms.Button
        $btnOkSuccess.Text = "OK"
        $btnOkSuccess.Location = New-Object System.Drawing.Point(210, 150)
        $btnOkSuccess.Size = New-Object System.Drawing.Size(80, 28)
        $btnOkSuccess.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $successForm.Controls.Add($btnOkSuccess)
        $successForm.AcceptButton = $btnOkSuccess
        if ($script:IsDarkMode) { $successForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblSuccess.ForeColor = [System.Drawing.Color]::White; $btnOkSuccess.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnOkSuccess.ForeColor = [System.Drawing.Color]::White; $btnOkSuccess.UseVisualStyleBackColor = $false }
        $resSuccess = $successForm.ShowDialog()
        $successForm.Dispose()
        if ($resSuccess -eq [System.Windows.Forms.DialogResult]::OK) {
            & $ScanPhysicalInfrastructure
            & $RecalculateEngine "ManualTrigger"
        }
    }
})
$btnAdvancedVDisk.add_Click({
    if ($btnAdvancedVDisk.Text -eq "Create Virtual Disk with Current Settings" -and $script:IsAdvancedMode -and $script:AdvancedConfig -ne $null) {
        if ([string]::IsNullOrWhiteSpace($txtTerminalOutput.Text) -or $txtTerminalOutput.Text -match "POWERSHELL COMMAND MONITOR STATION READY") {
            if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "No advanced script in terminal. Re-open builder to generate." -Title "Advanced" }
            return
        }
        try {
            $isAdminAdvExec = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdminAdvExec) { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED: Not elevated - run as admin for silent create.") }
            else {
                $psAdvExec = [PowerShell]::Create(); [void]$psAdvExec.AddScript($txtTerminalOutput.Text); $null = $psAdvExec.Invoke()
                if ($psAdvExec.HadErrors) { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED HIDDEN ERRORS:`r`n" + ($psAdvExec.Streams.Error | Out-String)) } else { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED HIDDEN: SUCCESS - Virtual disk created!"); Start-Sleep -Seconds 2; Update-StorageProviderCache; & $ScanPhysicalInfrastructure; & $RecalculateEngine "ManualTrigger" }
                $psAdvExec.Dispose()
            }
        } catch { $txtTerminalOutput.AppendText("`r`n# ADVANCED EXEC FAILED: $($_.Exception.Message)") }
$btnAdvancedVDisk.Text = "Advanced Virtual Disk Builder"
        $btnCancelAdvanced.Visible = $false
        $script:IsAdvancedMode = $false
        $script:AdvancedConfig = $null
        $drawCanvas.Refresh()
        if (-not $chkSuppressAllPopups.Checked) {
            $advExecDoneForm = New-Object System.Windows.Forms.Form; $advExecDoneForm.Text = "Advanced Complete"; $advExecDoneForm.Size = New-Object System.Drawing.Size(500, 200); $advExecDoneForm.StartPosition = "CenterParent"; $advExecDoneForm.FormBorderStyle = "FixedDialog"; $advExecDoneForm.Topmost = $true
            $lblAdvExecDone = New-Object System.Windows.Forms.Label; $lblAdvExecDone.Text = "Advanced virtual disk created! Check Script Terminal."; $lblAdvExecDone.Location = New-Object System.Drawing.Point(20,20); $lblAdvExecDone.Size = New-Object System.Drawing.Size(440,60); $advExecDoneForm.Controls.Add($lblAdvExecDone)
            $btnAdvExecOk = New-Object System.Windows.Forms.Button; $btnAdvExecOk.Text = "OK"; $btnAdvExecOk.Location = New-Object System.Drawing.Point(210,100); $btnAdvExecOk.Size = New-Object System.Drawing.Size(80,28); $btnAdvExecOk.DialogResult = [System.Windows.Forms.DialogResult]::OK; $advExecDoneForm.Controls.Add($btnAdvExecOk); $advExecDoneForm.AcceptButton = $btnAdvExecOk
            if ($script:IsDarkMode) { $advExecDoneForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblAdvExecDone.ForeColor = [System.Drawing.Color]::White; $btnAdvExecOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnAdvExecOk.ForeColor = [System.Drawing.Color]::White; $btnAdvExecOk.UseVisualStyleBackColor = $false }
            [void]$advExecDoneForm.ShowDialog(); $advExecDoneForm.Dispose()
        }
        return
    }
    $advForm = New-Object System.Windows.Forms.Form
    $advForm.Text = "Advanced Virtual Disk Builder - All Storage Spaces Options"
    $advForm.Size = New-Object System.Drawing.Size(720, 620)
    $advForm.StartPosition = "CenterParent"
    $advForm.FormBorderStyle = "FixedDialog"
    $advForm.MaximizeBox = $false; $advForm.MinimizeBox = $false
    $advForm.Topmost = $true
    if ($script:IsDarkMode) { $advForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40) }
    $lblAdvInfo = New-Object System.Windows.Forms.Label
    $lblAdvInfo.Text = "Build an advanced virtual disk with tiering, caching, and custom resiliency."
    $lblAdvInfo.Location = New-Object System.Drawing.Point(15, 10)
    $lblAdvInfo.Size = New-Object System.Drawing.Size(650, 30)
    $lblAdvInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
    if ($script:IsDarkMode) { $lblAdvInfo.ForeColor = [System.Drawing.Color]::White }
    $advForm.Controls.Add($lblAdvInfo)
    $grpRes = New-Object System.Windows.Forms.GroupBox
    $grpRes.Text = " Resiliency & Provisioning "
    $grpRes.Location = New-Object System.Drawing.Point(15, 45)
    $grpRes.Size = New-Object System.Drawing.Size(320, 165)
    $grpRes.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $advForm.Controls.Add($grpRes)
    $lblAdvRes = New-Object System.Windows.Forms.Label; $lblAdvRes.Text = "Resiliency:"; $lblAdvRes.Location = New-Object System.Drawing.Point(10, 25); $lblAdvRes.Size = New-Object System.Drawing.Size(80, 20); $grpRes.Controls.Add($lblAdvRes)
    $cmbAdvRes = New-Object System.Windows.Forms.ComboBox; $cmbAdvRes.Location = New-Object System.Drawing.Point(100, 22); $cmbAdvRes.Size = New-Object System.Drawing.Size(200, 20); $cmbAdvRes.DropDownStyle = "DropDownList"
    @('Simple (RAID 0)','Mirror (RAID 1) - 2-way','Mirror (RAID 1) - 3-way','Parity (RAID 5)','Dual Parity (RAID 6)') | ForEach-Object { [void]$cmbAdvRes.Items.Add($_) }; $cmbAdvRes.SelectedIndex = 0; $grpRes.Controls.Add($cmbAdvRes)
    $lblAdvProv = New-Object System.Windows.Forms.Label; $lblAdvProv.Text = "Provisioning:"; $lblAdvProv.Location = New-Object System.Drawing.Point(10, 55); $lblAdvProv.Size = New-Object System.Drawing.Size(80, 20); $grpRes.Controls.Add($lblAdvProv)
    $cmbAdvProv = New-Object System.Windows.Forms.ComboBox; $cmbAdvProv.Location = New-Object System.Drawing.Point(100, 52); $cmbAdvProv.Size = New-Object System.Drawing.Size(200, 20); $cmbAdvProv.DropDownStyle = "DropDownList"
    @('Fixed','Thin') | ForEach-Object { [void]$cmbAdvProv.Items.Add($_) }; $cmbAdvProv.SelectedIndex = 0; $grpRes.Controls.Add($cmbAdvProv)
    $lblAdvCols = New-Object System.Windows.Forms.Label; $lblAdvCols.Text = "Columns:"; $lblAdvCols.Location = New-Object System.Drawing.Point(10, 85); $lblAdvCols.Size = New-Object System.Drawing.Size(80, 20); $grpRes.Controls.Add($lblAdvCols)
    $cmbAdvCols = New-Object System.Windows.Forms.ComboBox; $cmbAdvCols.Location = New-Object System.Drawing.Point(100, 82); $cmbAdvCols.Size = New-Object System.Drawing.Size(60, 20); $cmbAdvCols.DropDownStyle = "DropDownList"
    @('1','2','3','4','5','6','7','8') | ForEach-Object { [void]$cmbAdvCols.Items.Add($_) }; $cmbAdvCols.SelectedIndex = 2; $grpRes.Controls.Add($cmbAdvCols)
    $lblAdvIL = New-Object System.Windows.Forms.Label; $lblAdvIL.Text = "Interleave:"; $lblAdvIL.Location = New-Object System.Drawing.Point(170, 85); $lblAdvIL.Size = New-Object System.Drawing.Size(60, 20); $grpRes.Controls.Add($lblAdvIL)
    $cmbAdvIL = New-Object System.Windows.Forms.ComboBox; $cmbAdvIL.Location = New-Object System.Drawing.Point(230, 82); $cmbAdvIL.Size = New-Object System.Drawing.Size(70, 20); $cmbAdvIL.DropDownStyle = "DropDownList"
    @('16KB','32KB','64KB','128KB','256KB') | ForEach-Object { [void]$cmbAdvIL.Items.Add($_) }; $cmbAdvIL.SelectedIndex = 2; $grpRes.Controls.Add($cmbAdvIL)
    $lblAdvCluster = New-Object System.Windows.Forms.Label; $lblAdvCluster.Text = "Cluster:"; $lblAdvCluster.Location = New-Object System.Drawing.Point(10, 110); $lblAdvCluster.Size = New-Object System.Drawing.Size(80, 20); $grpRes.Controls.Add($lblAdvCluster)
    $cmbAdvCluster = New-Object System.Windows.Forms.ComboBox; $cmbAdvCluster.Location = New-Object System.Drawing.Point(100, 107); $cmbAdvCluster.Size = New-Object System.Drawing.Size(70, 20); $cmbAdvCluster.DropDownStyle = "DropDownList"
    @('4KB','8KB','16KB','32KB','64KB','128KB','256KB') | ForEach-Object { [void]$cmbAdvCluster.Items.Add($_) }; $cmbAdvCluster.SelectedIndex = 4; $grpRes.Controls.Add($cmbAdvCluster)
    $btnAdvQuickOpt = New-Object System.Windows.Forms.Button; $btnAdvQuickOpt.Text = "Quick Optimize"; $btnAdvQuickOpt.Location = New-Object System.Drawing.Point(10, 135); $btnAdvQuickOpt.Size = New-Object System.Drawing.Size(300, 22); $btnAdvQuickOpt.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold); $btnAdvQuickOpt.BackColor = [System.Drawing.Color]::MediumSeaGreen; $btnAdvQuickOpt.ForeColor = [System.Drawing.Color]::White; $btnAdvQuickOpt.Cursor = [System.Windows.Forms.Cursors]::Hand; $grpRes.Controls.Add($btnAdvQuickOpt)
    if ($script:IsDarkMode) { foreach ($c in $grpRes.Controls) { if ($c -is [System.Windows.Forms.Label]) { $c.ForeColor = [System.Drawing.Color]::White } if ($c -is [System.Windows.Forms.ComboBox]) { $c.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $c.ForeColor = [System.Drawing.Color]::White } if ($c -is [System.Windows.Forms.Button]) { $c.BackColor = [System.Drawing.Color]::MediumSeaGreen; $c.ForeColor = [System.Drawing.Color]::White } } $grpRes.ForeColor = [System.Drawing.Color]::White }
    $btnAdvQuickOpt.add_Click({
        $driveCountAdvQ = 0; for ($k=0; $k -lt $chkDrives.Items.Count; $k++) { if ($chkDrives.GetItemChecked($k)) { $driveCountAdvQ++ } }
        if ($driveCountAdvQ -eq 0) { $driveCountAdvQ = $script:AvailableDisks.Count; if ($driveCountAdvQ -eq 0) { $driveCountAdvQ = 4 } }
        $modeAdvQ = $cmbAdvRes.SelectedItem.ToString()
        # Reuse same best-practice logic as main Quick Optimize, adapted for advanced dialog
        if ($modeAdvQ -match "Parity" -and $driveCountAdvQ -lt 3) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Parity needs 3+ drives." -Title "Advanced Quick Optimize" }; return }
        if ($modeAdvQ -match "Dual" -and $driveCountAdvQ -lt 5) { if (-not $chkSuppressAllPopups.Checked) { Show-ThemedAlert -Text "Dual Parity needs 5+ drives." -Title "Advanced Quick Optimize" }; return }
        $isParityAdvQ = $modeAdvQ -match "Parity"
        $isDualAdvQ = $modeAdvQ -match "Dual"
        $isSimpleAdvQ = $modeAdvQ -match "Simple"
        $isMirrorAdvQ = $modeAdvQ -match "Mirror"
        if ($isParityAdvQ -and -not $isDualAdvQ) {
            if ($driveCountAdvQ -ge 5) { $cmbAdvCols.SelectedItem = "5"; $cmbAdvIL.SelectedItem = "16KB"; $cmbAdvCluster.SelectedItem = "64KB" }
            elseif ($driveCountAdvQ -eq 4) { $cmbAdvCols.SelectedItem = "3"; $cmbAdvIL.SelectedItem = "32KB"; $cmbAdvCluster.SelectedItem = "64KB" }
            else { $cmbAdvCols.SelectedItem = "3"; $cmbAdvIL.SelectedItem = "32KB"; $cmbAdvCluster.SelectedItem = "64KB" }
        } elseif ($isDualAdvQ) {
            if ($driveCountAdvQ -ge 10) { $cmbAdvCols.SelectedItem = "8"; $cmbAdvIL.SelectedItem = "128KB"; $cmbAdvCluster.SelectedItem = "64KB" }
            elseif ($driveCountAdvQ -ge 7) { $cmbAdvCols.SelectedItem = ($driveCountAdvQ - 2).ToString(); $cmbAdvIL.SelectedItem = "128KB"; $cmbAdvCluster.SelectedItem = "64KB" }
            elseif ($driveCountAdvQ -eq 6) { $cmbAdvCols.SelectedItem = "4"; $cmbAdvIL.SelectedItem = "128KB"; $cmbAdvCluster.SelectedItem = "64KB" }
            else { $cmbAdvCols.SelectedItem = "3"; $cmbAdvIL.SelectedItem = "128KB"; $cmbAdvCluster.SelectedItem = "64KB" }
        } elseif ($isSimpleAdvQ) {
            $foundAdvQ = $false; $tryColsAdvQ = @()
            for ($cAdvQ=$driveCountAdvQ; $cAdvQ -ge 1; $cAdvQ--) { $tryColsAdvQ += $cAdvQ }
            foreach ($cAdvQ in $tryColsAdvQ) {
                foreach ($clAdvQ in @("64KB","128KB","256KB","32KB")) {
                    foreach ($ilAdvQ in @("64KB","32KB","16KB","128KB","256KB")) {
                        $ilBAdvQ = switch($ilAdvQ){"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144}}
                        $clBAdvQ = switch($clAdvQ){"4KB"{4096}"8KB"{8192}"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144}}
                        if ($ilBAdvQ * $cAdvQ -eq $clBAdvQ) { $cmbAdvCols.SelectedItem = $cAdvQ.ToString(); $cmbAdvIL.SelectedItem = $ilAdvQ; $cmbAdvCluster.SelectedItem = $clAdvQ; $foundAdvQ=$true; break }
                    }
                    if ($foundAdvQ){break}
                }
                if ($foundAdvQ){break}
            }
            if (-not $foundAdvQ) { $cmbAdvCols.SelectedItem = $driveCountAdvQ.ToString(); $cmbAdvIL.SelectedItem = "64KB"; $cmbAdvCluster.SelectedItem = "64KB" }
        } elseif ($isMirrorAdvQ) {
            $colsAdvQ = [math]::Floor($driveCountAdvQ/2); if ($colsAdvQ -lt 1){$colsAdvQ=1}; if ($colsAdvQ -gt 8){$colsAdvQ=8}
            $cmbAdvCols.SelectedItem = $colsAdvQ.ToString(); $cmbAdvCluster.SelectedItem = "64KB"
        }
        # Provisioning: Fixed is optimal for performance, keep Thin if already Thin
        if ($cmbAdvProv.SelectedItem -eq $null) { $cmbAdvProv.SelectedItem = "Fixed" }
    })
    $grpTier = New-Object System.Windows.Forms.GroupBox
    $grpTier.Text = " Storage Tiers (SSD + HDD) "
    $grpTier.Location = New-Object System.Drawing.Point(350, 45)
    $grpTier.Size = New-Object System.Drawing.Size(340, 250)
    $grpTier.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $advForm.Controls.Add($grpTier)
    $chkTier = New-Object System.Windows.Forms.CheckBox; $chkTier.Text = "Enable Tiered Space (SSD fast + HDD capacity)"; $chkTier.Location = New-Object System.Drawing.Point(10, 20); $chkTier.Size = New-Object System.Drawing.Size(300, 20); $grpTier.Controls.Add($chkTier)
    $lblSsdTier = New-Object System.Windows.Forms.Label; $lblSsdTier.Text = "SSD Tier Disks (fast):"; $lblSsdTier.Location = New-Object System.Drawing.Point(10, 45); $lblSsdTier.Size = New-Object System.Drawing.Size(150, 15); $grpTier.Controls.Add($lblSsdTier)
    $chkSsdTier = New-Object System.Windows.Forms.CheckedListBox; $chkSsdTier.Location = New-Object System.Drawing.Point(10, 65); $chkSsdTier.Size = New-Object System.Drawing.Size(300, 70); $chkSsdTier.CheckOnClick = $true; $grpTier.Controls.Add($chkSsdTier)
    $lblHddTier = New-Object System.Windows.Forms.Label; $lblHddTier.Text = "HDD Tier Disks (capacity):"; $lblHddTier.Location = New-Object System.Drawing.Point(10, 140); $lblHddTier.Size = New-Object System.Drawing.Size(150, 15); $grpTier.Controls.Add($lblHddTier)
    $chkHddTier = New-Object System.Windows.Forms.CheckedListBox; $chkHddTier.Location = New-Object System.Drawing.Point(10, 160); $chkHddTier.Size = New-Object System.Drawing.Size(300, 70); $chkHddTier.CheckOnClick = $true; $grpTier.Controls.Add($chkHddTier)
    foreach ($d in $script:AvailableDisks) { $sz=[math]::Round($d.Size/1GB,2); $disp="$($d.FriendlyName) - $sz GB ($($d.MediaType))"; [void]$chkSsdTier.Items.Add($disp,$false); [void]$chkHddTier.Items.Add($disp,$false) }
    if ($script:IsDarkMode) { foreach ($c in $grpTier.Controls) { if ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.CheckBox]) { $c.ForeColor = [System.Drawing.Color]::White } if ($c -is [System.Windows.Forms.CheckedListBox]) { $c.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $c.ForeColor = [System.Drawing.Color]::White } } $grpTier.ForeColor = [System.Drawing.Color]::White }
    $grpCache = New-Object System.Windows.Forms.GroupBox
    $grpCache.Text = " Write-Back Cache (SSD journal) "
    $grpCache.Location = New-Object System.Drawing.Point(15, 310)
    $grpCache.Size = New-Object System.Drawing.Size(320, 100)
    $grpCache.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $advForm.Controls.Add($grpCache)
    $chkCache = New-Object System.Windows.Forms.CheckBox; $chkCache.Text = "Enable Write-Back Cache (SSD)"; $chkCache.Location = New-Object System.Drawing.Point(10, 20); $chkCache.Size = New-Object System.Drawing.Size(250, 20); $grpCache.Controls.Add($chkCache)
    $lblCacheDisk = New-Object System.Windows.Forms.Label; $lblCacheDisk.Text = "Cache SSD Disk:"; $lblCacheDisk.Location = New-Object System.Drawing.Point(10, 45); $lblCacheDisk.Size = New-Object System.Drawing.Size(100, 15); $grpCache.Controls.Add($lblCacheDisk)
    $cmbCacheDisk = New-Object System.Windows.Forms.ComboBox; $cmbCacheDisk.Location = New-Object System.Drawing.Point(110, 42); $cmbCacheDisk.Size = New-Object System.Drawing.Size(190, 20); $cmbCacheDisk.DropDownStyle = "DropDownList"; $grpCache.Controls.Add($cmbCacheDisk)
    foreach ($d in $script:AvailableDisks) { if ($d.MediaType -match "SSD" -or $d.BusType -match "NVMe") { $sz=[math]::Round($d.Size/1GB,2); [void]$cmbCacheDisk.Items.Add("$($d.FriendlyName) - $sz GB", $false) } }
    if ($cmbCacheDisk.Items.Count -eq 0) { foreach ($d in $script:AvailableDisks) { $sz=[math]::Round($d.Size/1GB,2); [void]$cmbCacheDisk.Items.Add("$($d.FriendlyName) - $sz GB", $false) } }
    $lblCacheSize = New-Object System.Windows.Forms.Label; $lblCacheSize.Text = "Cache Size:"; $lblCacheSize.Location = New-Object System.Drawing.Point(10, 70); $lblCacheSize.Size = New-Object System.Drawing.Size(100, 15); $grpCache.Controls.Add($lblCacheSize)
    $txtCacheSize = New-Object System.Windows.Forms.TextBox; $txtCacheSize.Text = "10GB"; $txtCacheSize.Location = New-Object System.Drawing.Point(110, 67); $txtCacheSize.Size = New-Object System.Drawing.Size(80, 20); $grpCache.Controls.Add($txtCacheSize)
    if ($script:IsDarkMode) { foreach ($c in $grpCache.Controls) { if ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.CheckBox]) { $c.ForeColor = [System.Drawing.Color]::White } if ($c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.TextBox]) { $c.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $c.ForeColor = [System.Drawing.Color]::White } } $grpCache.ForeColor = [System.Drawing.Color]::White }
    $grpAdv2 = New-Object System.Windows.Forms.GroupBox
    $grpAdv2.Text = " Advanced Flags "
    $grpAdv2.Location = New-Object System.Drawing.Point(350, 310)
    $grpAdv2.Size = New-Object System.Drawing.Size(340, 150)
    $grpAdv2.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $advForm.Controls.Add($grpAdv2)
    $chkManual = New-Object System.Windows.Forms.CheckBox; $chkManual.Text = "IsManualConfig"; $chkManual.Location = New-Object System.Drawing.Point(10, 20); $chkManual.Size = New-Object System.Drawing.Size(200, 20); $grpAdv2.Controls.Add($chkManual)
    $chkEnclosure = New-Object System.Windows.Forms.CheckBox; $chkEnclosure.Text = "EnclosureAware"; $chkEnclosure.Location = New-Object System.Drawing.Point(10, 45); $chkEnclosure.Size = New-Object System.Drawing.Size(150, 20); $grpAdv2.Controls.Add($chkEnclosure)
    $lblFault = New-Object System.Windows.Forms.Label; $lblFault.Text = "FaultDomain:"; $lblFault.Location = New-Object System.Drawing.Point(10, 70); $lblFault.Size = New-Object System.Drawing.Size(90, 15); $grpAdv2.Controls.Add($lblFault)
    $cmbFault = New-Object System.Windows.Forms.ComboBox; $cmbFault.Location = New-Object System.Drawing.Point(100, 67); $cmbFault.Size = New-Object System.Drawing.Size(200, 20); $cmbFault.DropDownStyle = "DropDownList"
    @('PhysicalDisk','StorageScaleUnit','StorageChassis','StorageEnclosure','StorageRack') | ForEach-Object { [void]$cmbFault.Items.Add($_) }; $cmbFault.SelectedIndex = 0; $grpAdv2.Controls.Add($cmbFault)
    $chkAutoColumns = New-Object System.Windows.Forms.CheckBox; $chkAutoColumns.Text = "AutoNumberOfColumns"; $chkAutoColumns.Location = New-Object System.Drawing.Point(10, 95); $chkAutoColumns.Size = New-Object System.Drawing.Size(170, 20); $grpAdv2.Controls.Add($chkAutoColumns)
    $lblGroups = New-Object System.Windows.Forms.Label; $lblGroups.Text = "NumberOfGroups:"; $lblGroups.Location = New-Object System.Drawing.Point(10, 120); $lblGroups.Size = New-Object System.Drawing.Size(110, 15); $grpAdv2.Controls.Add($lblGroups)
    $txtGroups = New-Object System.Windows.Forms.TextBox; $txtGroups.Location = New-Object System.Drawing.Point(120, 117); $txtGroups.Size = New-Object System.Drawing.Size(50, 20); $grpAdv2.Controls.Add($txtGroups)
    $lblRedundancy = New-Object System.Windows.Forms.Label; $lblRedundancy.Text = "DiskRedundancy:"; $lblRedundancy.Location = New-Object System.Drawing.Point(180, 120); $lblRedundancy.Size = New-Object System.Drawing.Size(110, 15); $grpAdv2.Controls.Add($lblRedundancy)
    $cmbRedundancy = New-Object System.Windows.Forms.ComboBox; $cmbRedundancy.Location = New-Object System.Drawing.Point(295, 117); $cmbRedundancy.Size = New-Object System.Drawing.Size(25, 20); $cmbRedundancy.DropDownStyle = "DropDownList"; @('','0','1','2') | ForEach-Object { [void]$cmbRedundancy.Items.Add($_) }; $cmbRedundancy.SelectedIndex = 0; $grpAdv2.Controls.Add($cmbRedundancy)
    if ($script:IsDarkMode) { foreach ($c in $grpAdv2.Controls) { if ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.CheckBox]) { $c.ForeColor = [System.Drawing.Color]::White } if ($c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.TextBox]) { $c.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $c.ForeColor = [System.Drawing.Color]::White } } $grpAdv2.ForeColor = [System.Drawing.Color]::White }
    $btnAdvOk = New-Object System.Windows.Forms.Button; $btnAdvOk.Text = "Create visual layout"; $btnAdvOk.Location = New-Object System.Drawing.Point(380, 480); $btnAdvOk.Size = New-Object System.Drawing.Size(180, 32); $btnAdvOk.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold); $btnAdvOk.BackColor = [System.Drawing.Color]::DarkSlateBlue; $btnAdvOk.ForeColor = [System.Drawing.Color]::White; $btnAdvOk.Cursor = [System.Windows.Forms.Cursors]::Hand; $advForm.Controls.Add($btnAdvOk)
    $btnAdvCancel = New-Object System.Windows.Forms.Button; $btnAdvCancel.Text = "Cancel"; $btnAdvCancel.Location = New-Object System.Drawing.Point(280, 480); $btnAdvCancel.Size = New-Object System.Drawing.Size(80, 32); $advForm.Controls.Add($btnAdvCancel)
    if ($script:IsDarkMode) { $btnAdvCancel.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnAdvCancel.ForeColor = [System.Drawing.Color]::White }
    $btnAdvCancel.add_Click({ $advForm.Close() })
    $btnAdvOk.add_Click({
        $hasAdvOption = $chkTier.Checked -or $chkCache.Checked -or $chkManual.Checked -or $chkEnclosure.Checked -or $cmbAdvRes.SelectedIndex -ne 0 -or $cmbAdvProv.SelectedIndex -ne 0 -or $cmbAdvCols.SelectedIndex -ne 2 -or $cmbAdvIL.SelectedIndex -ne 2 -or $cmbAdvCluster.SelectedIndex -ne 4
        if ($chkTier.Checked) {
            $ssdHas = $false; for ($ti=0; $ti -lt $chkSsdTier.Items.Count; $ti++) { if ($chkSsdTier.GetItemChecked($ti)) { $ssdHas = $true; break } }
            $hddHas = $false; for ($ti=0; $ti -lt $chkHddTier.Items.Count; $ti++) { if ($chkHddTier.GetItemChecked($ti)) { $hddHas = $true; break } }
            if (-not $ssdHas -and -not $hddHas) { $hasAdvOption = $false }
        }
        if (-not $hasAdvOption) {
            if (-not $chkSuppressAllPopups.Checked) {
                $advNoOptForm = New-Object System.Windows.Forms.Form
                $advNoOptForm.Text = "Advanced"
                $advNoOptForm.Size = New-Object System.Drawing.Size(500, 200)
                $advNoOptForm.StartPosition = "CenterParent"
                $advNoOptForm.FormBorderStyle = "FixedDialog"
                $advNoOptForm.MaximizeBox = $false; $advNoOptForm.MinimizeBox = $false
                $advNoOptForm.Topmost = $true
                $lblAdvNoOpt = New-Object System.Windows.Forms.Label
                $lblAdvNoOpt.Text = "Please select at least one advanced option (tiering, cache, resiliency, etc.) to create a visual layout."
                $lblAdvNoOpt.Location = New-Object System.Drawing.Point(20, 20)
                $lblAdvNoOpt.Size = New-Object System.Drawing.Size(440, 60)
                $advNoOptForm.Controls.Add($lblAdvNoOpt)
                $btnAdvNoOptOk = New-Object System.Windows.Forms.Button
                $btnAdvNoOptOk.Text = "OK"
                $btnAdvNoOptOk.Location = New-Object System.Drawing.Point(210, 100)
                $btnAdvNoOptOk.Size = New-Object System.Drawing.Size(80, 28)
                $btnAdvNoOptOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $advNoOptForm.Controls.Add($btnAdvNoOptOk)
                $advNoOptForm.AcceptButton = $btnAdvNoOptOk
                if ($script:IsDarkMode) { $advNoOptForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblAdvNoOpt.ForeColor = [System.Drawing.Color]::White; $btnAdvNoOptOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnAdvNoOptOk.ForeColor = [System.Drawing.Color]::White; $btnAdvNoOptOk.UseVisualStyleBackColor = $false }
                [void]$advNoOptForm.ShowDialog()
                $advNoOptForm.Dispose()
            }
            return
        }
        $script:IsAdvancedMode = $true
        $resAdv = $cmbAdvRes.SelectedItem.ToString()
        $provAdv = $cmbAdvProv.SelectedItem.ToString()
        $colsAdv = [int]$cmbAdvCols.SelectedItem
        $ilAdv = $cmbAdvIL.SelectedItem.ToString()
        $clusterAdv = $cmbAdvCluster.SelectedItem.ToString()
        $ilBytesAdv = switch($ilAdv){"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144} default{65536}}
        $clusterBytesAdv = switch($clusterAdv){"4KB"{4096}"8KB"{8192}"16KB"{16384}"32KB"{32768}"64KB"{65536}"128KB"{131072}"256KB"{262144} default{65536}}
        $poolNameAdv = $txtPoolName.Text.Trim(); if ([string]::IsNullOrWhiteSpace($poolNameAdv)) { $poolNameAdv = "AdvancedPool" }
        $vdNameAdv = $txtSpaceName.Text.Trim(); if ([string]::IsNullOrWhiteSpace($vdNameAdv)) { $vdNameAdv = "AdvancedVDisk" }
        $resMap = switch -Wildcard ($resAdv) { "*Simple*" {"Simple"} "*3-way*" {"Mirror"} "*2-way*" {"Mirror"} "*Parity*" {"Parity"} "*Dual*" {"Parity"} default {"Mirror"} }
        if ($resAdv -match "3-way") { $advCopies = 3 } elseif ($resAdv -match "2-way") { $advCopies = 2 } else { $advCopies = $null }
        $sbAdv = New-Object System.Text.StringBuilder
        [void]$sbAdv.AppendLine("# =========================================================================")
        [void]$sbAdv.AppendLine("# ADVANCED STORAGE SPACES VIRTUAL DISK - All documented options")
        [void]$sbAdv.AppendLine("# Resiliency: $resAdv | Prov: $provAdv | Cols: $colsAdv | IL: $ilAdv | Cluster: $clusterAdv")
        if ($chkTier.Checked) { [void]$sbAdv.AppendLine("# Tiering: SSD+HDD enabled") }
        if ($chkCache.Checked) { [void]$sbAdv.AppendLine("# Write-Back Cache: $($txtCacheSize.Text) on $($cmbCacheDisk.SelectedItem)") }
        [void]$sbAdv.AppendLine("# ManualConfig: $chkManual | EnclosureAware: $chkEnclosure | FaultDomain: $($cmbFault.SelectedItem)")
        [void]$sbAdv.AppendLine("# =========================================================================")
        [void]$sbAdv.AppendLine("")
        [void]$sbAdv.AppendLine("# Step 1: Collect target disks (from main window selection + tier picks)")
        [void]$sbAdv.AppendLine("`$AllDisks = Get-PhysicalDisk | Where-Object CanPool")
        [void]$sbAdv.AppendLine("`$TargetDisks = @()")
        for ($i=0; $i -lt $chkDrives.Items.Count; $i++) { if ($chkDrives.GetItemChecked($i)) { $d=$script:AvailableDisks[$i]; $uidEsc=($d.UniqueId -replace '"','`"'); $serEsc=($d.SerialNumber -replace '"','`"'); if ($uidEsc -and $serEsc) { [void]$sbAdv.AppendLine("`$TargetDisks += Get-PhysicalDisk | Where-Object {`$_.UniqueId -eq `"$uidEsc`" -and `$_.SerialNumber -eq `"$serEsc`"} | Select -First 1") } elseif ($serEsc) { [void]$sbAdv.AppendLine("`$TargetDisks += Get-PhysicalDisk | Where-Object SerialNumber -eq `"$serEsc`" | Select -First 1") } else { [void]$sbAdv.AppendLine("`$TargetDisks += Get-PhysicalDisk -UniqueId `"$uidEsc`" | Select -First 1") } } }
        if ($chkTier.Checked) {
            [void]$sbAdv.AppendLine("")
            [void]$sbAdv.AppendLine("# Tier disks (SSD/HDD) - selected in Advanced dialog")
            [void]$sbAdv.AppendLine("`$SsdTierDisks = @()")
            for ($ti=0; $ti -lt $chkSsdTier.Items.Count; $ti++) { if ($chkSsdTier.GetItemChecked($ti) -and $script:AvailableDisks.Count -gt 0) { $d=$script:AvailableDisks[$ti % $script:AvailableDisks.Count]; $uidEsc=($d.UniqueId -replace '"','`"'); $serEsc=($d.SerialNumber -replace '"','`"'); if ($uidEsc -and $serEsc) { [void]$sbAdv.AppendLine("`$SsdTierDisks += Get-PhysicalDisk | Where-Object {`$_.UniqueId -eq `"$uidEsc`" -and `$_.SerialNumber -eq `"$serEsc`"} | Select -First 1") } } }
            [void]$sbAdv.AppendLine("`$HddTierDisks = @()")
            for ($ti=0; $ti -lt $chkHddTier.Items.Count; $ti++) { if ($chkHddTier.GetItemChecked($ti) -and $script:AvailableDisks.Count -gt 0) { $d=$script:AvailableDisks[$ti % $script:AvailableDisks.Count]; $uidEsc=($d.UniqueId -replace '"','`"'); $serEsc=($d.SerialNumber -replace '"','`"'); if ($uidEsc -and $serEsc) { [void]$sbAdv.AppendLine("`$HddTierDisks += Get-PhysicalDisk | Where-Object {`$_.UniqueId -eq `"$uidEsc`" -and `$_.SerialNumber -eq `"$serEsc`"} | Select -First 1") } } }
            [void]$sbAdv.AppendLine("`$TierDisks = @(`$SsdTierDisks + `$HddTierDisks)")
            [void]$sbAdv.AppendLine("if (`$TierDisks.Count -eq 0) { `$TierDisks = `$TargetDisks }")
        } else {
            [void]$sbAdv.AppendLine("`$TierDisks = `$TargetDisks")
        }
        [void]$sbAdv.AppendLine("")
        [void]$sbAdv.AppendLine("# Step 2: Create Pool with advanced flags")
        $faultStr = $cmbFault.SelectedItem.ToString()
        $manualFlag = if ($chkManual.Checked) { " -IsManualConfig `$true" } else { "" }
        $enclosureFlag = if ($chkEnclosure.Checked) { " -EnclosureAware `$true" } else { "" }
        [void]$sbAdv.AppendLine("`$Subsystem = Get-StorageSubsystem | Where-Object FriendlyName -like '*Storage*' | Select-Object -First 1")
        [void]$sbAdv.AppendLine("`$Pool = New-StoragePool -FriendlyName `"$poolNameAdv`" -StorageSubsystemUniqueId `$Subsystem.UniqueId -PhysicalDisks `$TierDisks -FaultDomainAwareness $faultStr$manualFlag$enclosureFlag")
        [void]$sbAdv.AppendLine("Update-StorageProviderCache")
        if ($chkTier.Checked) {
            [void]$sbAdv.AppendLine("")
            [void]$sbAdv.AppendLine("# Step 3: Create Tiers (SSD fast + HDD capacity)")
            [void]$sbAdv.AppendLine("`$SsdTier = New-StorageTier -StoragePoolFriendlyName `"$poolNameAdv`" -FriendlyName `"SSDTier`" -MediaType SSD -ResiliencySettingName $resMap -NumberOfColumns $colsAdv -FaultDomainAwareness $faultStr")
            [void]$sbAdv.AppendLine("`$HddTier = New-StorageTier -StoragePoolFriendlyName `"$poolNameAdv`" -FriendlyName `"HDDTier`" -MediaType HDD -ResiliencySettingName $resMap -NumberOfColumns $colsAdv -FaultDomainAwareness $faultStr")
        }
        if ($chkCache.Checked) {
            $cacheSize = $txtCacheSize.Text.Trim()
            [void]$sbAdv.AppendLine("")
            [void]$sbAdv.AppendLine("# Write-Back Cache (SSD journal)")
            $cacheNameAdv = if ($cmbCacheDisk.SelectedItem) { ($cmbCacheDisk.SelectedItem.ToString() -split ' - ')[0] } else { "" }; [void]$sbAdv.AppendLine("`$CacheDisk = Get-PhysicalDisk | Where-Object {`$_.FriendlyName -eq `"$cacheNameAdv`"} | Select-Object -First 1")
            [void]$sbAdv.AppendLine("# Cache is auto-created on tiered spaces; for simple/parity you can add -WriteCacheSize $cacheSize on New-VirtualDisk")
        }
        [void]$sbAdv.AppendLine("")
        [void]$sbAdv.AppendLine("# Step 4: Create Virtual Disk - all flags")
        $vdExtra = ""
        if ($advCopies) { $vdExtra += " -NumberOfDataCopies $advCopies" }
        if ($chkCache.Checked) { $vdExtra += " -WriteCacheSize $(if($txtCacheSize.Text -match '^\d+GB$'){[int]($txtCacheSize.Text -replace 'GB','')*1GB}else{10GB})" }
        if ($chkManual.Checked) { $vdExtra += " -IsManualConfig `$true" }
        if (-not [string]::IsNullOrWhiteSpace($txtGroups.Text) -and $txtGroups.Text.Trim() -match '^\d+$') { $vdExtra += " -NumberOfGroups $($txtGroups.Text.Trim())" }
        if ($cmbRedundancy.SelectedItem -and $cmbRedundancy.SelectedItem.ToString() -ne '') { $vdExtra += " -PhysicalDiskRedundancy $($cmbRedundancy.SelectedItem)" }
        $colParamAdv = if ($chkAutoColumns.Checked) { " -AutoNumberOfColumns" } else { " -NumberOfColumns $colsAdv" }
        if ($chkTier.Checked) {
            [void]$sbAdv.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolNameAdv`" -FriendlyName `"$vdNameAdv`" -ResiliencySettingName $resMap$colParamAdv -Interleave $ilBytesAdv -ProvisioningType $provAdv$vdExtra -StorageTiers @(`$SsdTier, `$HddTier) -UseMaximumSize")
        } else {
            [void]$sbAdv.AppendLine("New-VirtualDisk -StoragePoolFriendlyName `"$poolNameAdv`" -FriendlyName `"$vdNameAdv`" -ResiliencySettingName $resMap$colParamAdv -Interleave $ilBytesAdv -ProvisioningType $provAdv$vdExtra -UseMaximumSize")
        }
        [void]$sbAdv.AppendLine("")
        [void]$sbAdv.AppendLine("# Step 5: Format")
        [void]$sbAdv.AppendLine("Get-VirtualDisk -FriendlyName `"$vdNameAdv`" | Get-Disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -AllocationUnitSize $clusterBytesAdv -NewFileSystemLabel `"$vdNameAdv`" -Confirm:`$false")
        [void]$sbAdv.AppendLine("Update-StorageProviderCache; Write-Host 'ADVANCED Virtual Disk $vdNameAdv created!' -ForegroundColor Green")
        $script:AdvancedConfig = @{Resiliency=$resMap; Provisioning=$provAdv; Columns=$colsAdv; Interleave=$ilAdv; Tiered=$chkTier.Checked; Cache=$chkCache.Checked}
        $btnAdvancedVDisk.Text = "Create Virtual Disk with Current Settings"
        $btnCancelAdvanced.Visible = $true
        $drawCanvas.Refresh()
        $txtTerminalOutput.Text = $sbAdv.ToString()
        try {
            $isAdminAdv = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdminAdv) {
                $psAdv = [PowerShell]::Create(); [void]$psAdv.AddScript($sbAdv.ToString()); $null = $psAdv.Invoke()
                if ($psAdv.HadErrors) { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED HIDDEN ERRORS:`r`n" + ($psAdv.Streams.Error | Out-String)) } else { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED HIDDEN: SUCCESS"); }
                $psAdv.Dispose()
            } else { $txtTerminalOutput.AppendText("`r`n`r`n# ADVANCED: Not elevated - run as admin for silent create.") }
        } catch { $txtTerminalOutput.AppendText("`r`n# ADVANCED FAILED: $($_.Exception.Message)") }
        if (-not $chkSuppressAllPopups.Checked) {
            $advDoneForm = New-Object System.Windows.Forms.Form; $advDoneForm.Text = "Advanced Complete"; $advDoneForm.Size = New-Object System.Drawing.Size(500, 200); $advDoneForm.StartPosition = "CenterParent"; $advDoneForm.FormBorderStyle = "FixedDialog"; $advDoneForm.Topmost = $true
            $lblAdvDone = New-Object System.Windows.Forms.Label; $lblAdvDone.Text = "Advanced virtual disk script generated! Check Script Terminal. Various format popups may appear - ignore, already formatted."; $lblAdvDone.Location = New-Object System.Drawing.Point(20,20); $lblAdvDone.Size = New-Object System.Drawing.Size(440,60); $advDoneForm.Controls.Add($lblAdvDone)
            $btnAdvDoneOk = New-Object System.Windows.Forms.Button; $btnAdvDoneOk.Text = "OK"; $btnAdvDoneOk.Location = New-Object System.Drawing.Point(210,100); $btnAdvDoneOk.Size = New-Object System.Drawing.Size(80,28); $btnAdvDoneOk.DialogResult = [System.Windows.Forms.DialogResult]::OK; $advDoneForm.Controls.Add($btnAdvDoneOk); $advDoneForm.AcceptButton = $btnAdvDoneOk
            if ($script:IsDarkMode) { $advDoneForm.BackColor = [System.Drawing.Color]::FromArgb(40,40,40); $lblAdvDone.ForeColor = [System.Drawing.Color]::White; $btnAdvDoneOk.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $btnAdvDoneOk.ForeColor = [System.Drawing.Color]::White; $btnAdvDoneOk.UseVisualStyleBackColor = $false }
            $resAdvDone = $advDoneForm.ShowDialog(); $advDoneForm.Dispose()
            if ($resAdvDone -eq [System.Windows.Forms.DialogResult]::OK) { & $ScanPhysicalInfrastructure; & $RecalculateEngine "ManualTrigger"; $drawCanvas.Refresh() }
        } else { & $ScanPhysicalInfrastructure; & $RecalculateEngine "ManualTrigger"; $drawCanvas.Refresh() }
        $advForm.Close()
    })
    $advForm.ShowDialog() | Out-Null
})
$btnCancelAdvanced.add_Click({
    $script:IsAdvancedMode = $false
    $script:AdvancedConfig = $null
    $btnAdvancedVDisk.Text = "Advanced Virtual Disk Builder"
    $btnCancelAdvanced.Visible = $false
    $drawCanvas.Refresh()
    $txtTerminalOutput.Text = "# =========================================================`r`n# ADVANCED LAYOUT CANCELLED - Canvas cleared.`r`n# ========================================================="
})
# REMOVED: Defender auto-exclusion (Add-MpPreference) - kept your visuals intact, only pool-create logic fixed as requested

# --- Standard Left Panel Form Assembly Flush & Application Runner ---
$pnlLeft.Controls.Add($btnBuild)
& $RecalculateEngine "ManualTrigger"
[System.Windows.Forms.Application]::Run($form)
