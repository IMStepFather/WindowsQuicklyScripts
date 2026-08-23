# 加载组件
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ========== 主窗口 ==========
$form = New-Object System.Windows.Forms.Form
$form.Text = "自动关机/重启管理器"
$form.Size = New-Object System.Drawing.Size(380, 280)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# ========== 全局变量 ==========
$script:remainingSeconds = 0
$script:isCounting = $false
$script:warningShown = $false
$script:actionType = "关机"
$script:autoApplyCount = 15
$script:warningForm = $null
$script:btnWarnConfirm = $null
$script:warnCount = 10

# ========== 主窗口控件 ==========
$labelFunc = New-Object System.Windows.Forms.Label
$labelFunc.Text = "选择功能："
$labelFunc.Location = New-Object System.Drawing.Point(20, 20)
$labelFunc.Size = New-Object System.Drawing.Size(80, 20)

$radioShutdown = New-Object System.Windows.Forms.RadioButton
$radioShutdown.Text = "关机"
$radioShutdown.Location = New-Object System.Drawing.Point(110, 18)
$radioShutdown.Size = New-Object System.Drawing.Size(60, 20)
$radioShutdown.Checked = $true

$radioRestart = New-Object System.Windows.Forms.RadioButton
$radioRestart.Text = "重启"
$radioRestart.Location = New-Object System.Drawing.Point(180, 18)
$radioRestart.Size = New-Object System.Drawing.Size(60, 20)

$labelTime = New-Object System.Windows.Forms.Label
$labelTime.Text = "倒计时 (分钟)："
$labelTime.Location = New-Object System.Drawing.Point(20, 55)
$labelTime.Size = New-Object System.Drawing.Size(120, 20)

$textTime = New-Object System.Windows.Forms.TextBox
$textTime.Location = New-Object System.Drawing.Point(140, 52)
$textTime.Size = New-Object System.Drawing.Size(100, 20)
$textTime.Text = "2"

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "等待用户设置..."
$labelStatus.Location = New-Object System.Drawing.Point(20, 90)
$labelStatus.Size = New-Object System.Drawing.Size(340, 20)
$labelStatus.ForeColor = [System.Drawing.Color]::DarkGray

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "应用 (15)"
$btnApply.Location = New-Object System.Drawing.Point(50, 130)
$btnApply.Size = New-Object System.Drawing.Size(120, 35)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Location = New-Object System.Drawing.Point(200, 130)
$btnCancel.Size = New-Object System.Drawing.Size(120, 35)

$form.Controls.AddRange(@($labelFunc, $radioShutdown, $radioRestart, $labelTime, $textTime, $labelStatus, $btnApply, $btnCancel))

# ========== 定时器 ==========
$timerAutoApply = New-Object System.Windows.Forms.Timer
$timerAutoApply.Interval = 1000
$timerCountdown = New-Object System.Windows.Forms.Timer
$timerCountdown.Interval = 1000
$timerWarning = New-Object System.Windows.Forms.Timer
$timerWarning.Interval = 1000

# ========== 函数 ==========
# 关闭强提醒窗口
function Close-WarningForm {
    $timerWarning.Stop()
    if ($script:warningForm -ne $null) {
        $wf = $script:warningForm
        $script:warningForm = $null
        $script:btnWarnConfirm = $null
        $wf.Close()
        $wf.Dispose()
    }
}

# 执行关机/重启
function Start-ShutdownAction {
    $timerCountdown.Stop()
    Close-WarningForm            # 执行关机前先关闭提醒窗口，防止阻止关机
    $script:isCounting = $false

    $labelStatus.Text = "正在执行 $script:actionType ..."
    $labelStatus.ForeColor = [System.Drawing.Color]::Red
    $form.Update()

    if ($script:actionType -eq "重启") {
        Start-Process "shutdown" -ArgumentList "/r /t 0" -WindowStyle Hidden
    }
    else {
        Start-Process "shutdown" -ArgumentList "/s /t 0" -WindowStyle Hidden
    }
    $form.Close()
}

# 取消全部操作，回到等待设置状态
function Stop-AllActions {
    $timerAutoApply.Stop()
    $timerCountdown.Stop()
    Close-WarningForm
    Start-Process "shutdown" -ArgumentList "/a" -WindowStyle Hidden -ErrorAction SilentlyContinue

    $script:isCounting = $false
    $script:warningShown = $false
    $script:autoApplyCount = 15

    $btnApply.Enabled = $true
    $btnApply.Text = "应用 (15)"
    $textTime.Enabled = $true
    $radioShutdown.Enabled = $true
    $radioRestart.Enabled = $true
    $labelStatus.Text = "等待用户设置..."
    $labelStatus.ForeColor = [System.Drawing.Color]::DarkGray
    $timerAutoApply.Start()
}

# 用户操作时重置 15 秒自动应用
function Reset-AutoApplyTimer {
    if (-not $script:isCounting) {
        $timerAutoApply.Stop()
        $script:autoApplyCount = 15
        $btnApply.Text = "应用 (15)"
        $timerAutoApply.Start()
    }
}

# 显示强提醒窗口（非模态，主倒计时不暂停）
function Show-WarningForm {
    if ($script:warningForm -ne $null) { return }

    $wf = New-Object System.Windows.Forms.Form
    $wf.Text = "强提醒"
    $wf.Size = New-Object System.Drawing.Size(430, 220)
    $wf.StartPosition = "CenterScreen"
    $wf.TopMost = $true
    $wf.FormBorderStyle = "FixedDialog"
    $wf.MaximizeBox = $false
    $wf.MinimizeBox = $false

    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap()
    $pb.Location = New-Object System.Drawing.Point(20, 30)
    $pb.Size = New-Object System.Drawing.Size(40, 40)
    $pb.SizeMode = "StretchImage"

    $lb = New-Object System.Windows.Forms.Label
    $lb.Text = "警告：系统即将在 30 秒内 $script:actionType！`n请保存所有工作，10 秒未操作将自动确定。"
    $lb.Location = New-Object System.Drawing.Point(75, 25)
    $lb.Size = New-Object System.Drawing.Size(330, 60)
    $lb.ForeColor = [System.Drawing.Color]::DarkRed
    $lb.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9, [System.Drawing.FontStyle]::Bold)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "确定关机 (10)"
    $btnOK.Location = New-Object System.Drawing.Point(90, 120)
    $btnOK.Size = New-Object System.Drawing.Size(110, 40)
    $btnOK.Add_Click({ Close-WarningForm })      # 仅关闭提醒，倒计时继续

    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Text = "取消关机"
    $btnNo.Location = New-Object System.Drawing.Point(220, 120)
    $btnNo.Size = New-Object System.Drawing.Size(110, 40)
    $btnNo.Add_Click({ Stop-AllActions })        # 终止整个流程

    $wf.Add_FormClosed({
            $script:warningForm = $null
            $script:btnWarnConfirm = $null
            $timerWarning.Stop()
        })

    $wf.Controls.AddRange(@($pb, $lb, $btnOK, $btnNo))

    $script:warningForm = $wf
    $script:btnWarnConfirm = $btnOK
    $script:warnCount = 10
    $wf.Show()
    $timerWarning.Start()
}

# ========== 事件 ==========
$btnApply.Add_Click({
        $mins = 0
        if (-not [int]::TryParse($textTime.Text, [ref]$mins) -or $mins -le 0) {
            [System.Windows.Forms.MessageBox]::Show("请输入有效的分钟数！", "错误", "OK", "Error")
            return
        }

        $timerAutoApply.Stop()
        $script:actionType = if ($radioShutdown.Checked) { "关机" } else { "重启" }
        $script:remainingSeconds = $mins * 60
        $script:isCounting = $true
        $script:warningShown = $false

        $btnApply.Enabled = $false
        $btnApply.Text = "已应用"
        $textTime.Enabled = $false
        $radioShutdown.Enabled = $false
        $radioRestart.Enabled = $false
        $labelStatus.ForeColor = [System.Drawing.Color]::Blue
        $timerCountdown.Start()
    })

$btnCancel.Add_Click({ Stop-AllActions })

$radioShutdown.Add_Click({ Reset-AutoApplyTimer })
$radioRestart.Add_Click({ Reset-AutoApplyTimer })
$textTime.Add_TextChanged({ Reset-AutoApplyTimer })

# 15 秒自动应用
$timerAutoApply.Add_Tick({
        $script:autoApplyCount--
        if ($script:autoApplyCount -le 0) {
            $timerAutoApply.Stop()
            $btnApply.PerformClick()
        }
        else {
            $btnApply.Text = "应用 ($script:autoApplyCount)"
        }
    })

# 强提醒 10 秒自动确定
$timerWarning.Add_Tick({
        $script:warnCount--
        if ($script:warnCount -le 0) {
            Close-WarningForm
        }
        elseif ($script:btnWarnConfirm -ne $null) {
            $script:btnWarnConfirm.Text = "确定关机 ($script:warnCount)"
        }
    })

# 主倒计时
$timerCountdown.Add_Tick({
        if ($script:remainingSeconds -gt 0) {
            $script:remainingSeconds--
            $m = [math]::Floor($script:remainingSeconds / 60)
            $s = $script:remainingSeconds % 60
            $labelStatus.Text = "距离 $script:actionType 还有：{0}分 {1}秒" -f $m, $s

            if ($script:remainingSeconds -le 30 -and -not $script:warningShown) {
                $script:warningShown = $true
                Show-WarningForm
            }
        }
        else {
            $timerCountdown.Stop()
            Start-ShutdownAction
        }
    })

# 关闭窗口逻辑：系统关机时直接放行，不阻止
$form.Add_FormClosing({
        param($sender, $e)
        if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::WindowsShutDown -or
            $e.CloseReason -eq [System.Windows.Forms.CloseReason]::TaskManagerClosing) {
            Close-WarningForm
            return
        }
        if ($script:isCounting) {
            $r = [System.Windows.Forms.MessageBox]::Show("倒计时进行中，确定要取消并关闭脚本吗？", "确认退出", "YesNo", "Question")
            if ($r -eq [System.Windows.Forms.DialogResult]::No) { $e.Cancel = $true } else { Stop-AllActions }
        }
    })

# ========== 启动 ==========
$timerAutoApply.Start()
[void][System.Windows.Forms.Application]::Run($form)