# 加载 Windows Forms 组件
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 初始化主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "自动关机/重启管理器"
$form.Size = New-Object System.Drawing.Size(380, 280)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# 初始化变量
$script:totalSeconds = 0
$script:remainingSeconds = 0
$script:isCounting = $false
$script:warningShown = $false
$script:actionType = "关机" # 默认为关机
$script:autoApplyCount = 15
$script:isAutoApplyPaused = $false
$script:warningForm = $null

# --- 控件创建 ---

# 第一行：功能选择（使用单选按钮）
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

# 第二行：时间设置
$labelTime = New-Object System.Windows.Forms.Label
$labelTime.Text = "倒计时 (分钟)："
$labelTime.Location = New-Object System.Drawing.Point(20, 55)
$labelTime.Size = New-Object System.Drawing.Size(120, 20)

$textTime = New-Object System.Windows.Forms.TextBox
$textTime.Location = New-Object System.Drawing.Point(140, 52)
$textTime.Size = New-Object System.Drawing.Size(100, 20)
$textTime.Text = "2" # 默认 2 分钟

# 状态显示标签
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "等待用户设置..."
$labelStatus.Location = New-Object System.Drawing.Point(20, 90)
$labelStatus.Size = New-Object System.Drawing.Size(340, 20)
$labelStatus.ForeColor = [System.Drawing.Color]::DarkGray

# 第三行：按钮
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "应用 (15)"
$btnApply.Location = New-Object System.Drawing.Point(50, 130)
$btnApply.Size = New-Object System.Drawing.Size(120, 35)
$btnApply.DialogResult = [System.Windows.Forms.DialogResult]::None

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Location = New-Object System.Drawing.Point(200, 130)
$btnCancel.Size = New-Object System.Drawing.Size(120, 35)

# --- 定时器 ---

# 定时器 1：用于应用按钮的 15 秒自动点击
$timerAutoApply = New-Object System.Windows.Forms.Timer
$timerAutoApply.Interval = 1000

# 定时器 2：用于主倒计时
$timerCountdown = New-Object System.Windows.Forms.Timer
$timerCountdown.Interval = 1000

# --- 逻辑函数 ---

# 执行关机或重启命令
function Start-ShutdownAction {
    $cmd = ""
    if ($radioShutdown.Checked) {
        $cmd = "shutdown /s /t 0"
    } else {
        $cmd = "shutdown /r /t 0"
    }
    # 隐藏窗口执行
    Start-Process "cmd.exe" -ArgumentList "/c $cmd" -WindowStyle Hidden
    $labelStatus.Text = "正在执行 $script:actionType ..."
    $labelStatus.ForeColor = [System.Drawing.Color]::Red
    Start-Sleep -Seconds 2
    $form.Close()
}

# 取消所有操作
function Stop-AllActions {
    $timerAutoApply.Stop()
    $timerCountdown.Stop()
    # 尝试取消系统中可能存在的关机计划
    Start-Process "shutdown" -ArgumentList "/a" -WindowStyle Hidden -ErrorAction SilentlyContinue
    
    # 关闭警告窗口（如果存在）
    if ($script:warningForm -ne $null) {
        $script:warningForm.Close()
        $script:warningForm = $null
    }
    
    # 重置界面状态
    $script:isCounting = $false
    $script:warningShown = $false
    $script:autoApplyCount = 15
    $script:isAutoApplyPaused = $false
    
    $btnApply.Enabled = $true
    $btnApply.Text = "应用 (15)"
    $textTime.Enabled = $true
    $radioShutdown.Enabled = $true
    $radioRestart.Enabled = $true
    $labelStatus.Text = "等待用户设置..."
    $labelStatus.ForeColor = [System.Drawing.Color]::DarkGray
}

# 重置自动应用定时器
function Reset-AutoApplyTimer {
    if (-not $script:isCounting) {
        $timerAutoApply.Stop()
        $script:autoApplyCount = 15
        $btnApply.Text = "应用 (15)"
        $timerAutoApply.Start()
    }
}

# 应用按钮点击事件
$btnApply.Add_Click({
    # 验证输入
    $mins = 0
    if (-not [int]::TryParse($textTime.Text, [ref]$mins) -or $mins -le 0) {
        [System.Windows.Forms.MessageBox]::Show("请输入有效的分钟数！", "错误", "OK", "Error")
        return
    }

    # 停止自动应用定时器
    $timerAutoApply.Stop()
    
    # 设置主倒计时
    if ($radioShutdown.Checked) {
        $script:actionType = "关机"
    } else {
        $script:actionType = "重启"
    }
    
    $script:totalSeconds = $mins * 60
    $script:remainingSeconds = $script:totalSeconds
    $script:isCounting = $true
    $script:warningShown = $false

    # 更新 UI 状态
    $btnApply.Enabled = $false
    $btnApply.Text = "已应用"
    $textTime.Enabled = $false
    $radioShutdown.Enabled = $false
    $radioRestart.Enabled = $false
    $labelStatus.ForeColor = [System.Drawing.Color]::Blue
    
    # 启动主倒计时
    $timerCountdown.Start()
})

# 取消按钮点击事件
$btnCancel.Add_Click({
    Stop-AllActions
})

# 单选框改变事件 - 暂停自动应用倒计时
$radioShutdown.Add_Click({
    Reset-AutoApplyTimer
})

$radioRestart.Add_Click({
    Reset-AutoApplyTimer
})

# 文本框改变事件 - 暂停自动应用倒计时
$textTime.Add_TextChanged({
    Reset-AutoApplyTimer
})

# 自动应用定时器逻辑 (15 秒倒计时)
$timerAutoApply.Add_Tick({
    $script:autoApplyCount--
    if ($script:autoApplyCount -le 0) {
        $timerAutoApply.Stop()
        $btnApply.PerformClick() # 自动触发应用
    } else {
        $btnApply.Text = "应用 ($script:autoApplyCount)"
    }
})

# 创建警告窗口
function Show-WarningForm {
    $warningForm = New-Object System.Windows.Forms.Form
    $warningForm.Text = "强提醒"
    $warningForm.Size = New-Object System.Drawing.Size(400, 200)
    $warningForm.StartPosition = "CenterScreen"
    $warningForm.TopMost = $true
    $warningForm.FormBorderStyle = "FixedDialog"
    $warningForm.MaximizeBox = $false
    $warningForm.Icon = [System.Drawing.SystemIcons]::Warning
    
    # 警告图标
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap()
    $pictureBox.Location = New-Object System.Drawing.Point(20, 30)
    $pictureBox.Size = New-Object System.Drawing.Size(40, 40)
    $pictureBox.SizeMode = "StretchImage"
    
    # 警告文本
    $labelWarning = New-Object System.Windows.Forms.Label
    $labelWarning.Text = "警告：系统即将在 30 秒内 $script:actionType！`n请保存所有工作。"
    $labelWarning.Location = New-Object System.Drawing.Point(80, 30)
    $labelWarning.Size = New-Object System.Drawing.Size(280, 50)
    $labelWarning.ForeColor = [System.Drawing.Color]::DarkRed
    $labelWarning.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10, [System.Drawing.FontStyle]::Bold)
    
    # 确定按钮
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "确定"
    $btnOK.Location = New-Object System.Drawing.Point(80, 110)
    $btnOK.Size = New-Object System.Drawing.Size(100, 35)
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnOK.Add_Click({
        $warningForm.Close()
    })
    
    # 取消按钮
    $btnCancelWarn = New-Object System.Windows.Forms.Button
    $btnCancelWarn.Text = "取消"
    $btnCancelWarn.Location = New-Object System.Drawing.Point(210, 110)
    $btnCancelWarn.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancelWarn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnCancelWarn.Add_Click({
        Stop-AllActions
        $warningForm.Close()
    })
    
    $warningForm.Controls.Add($pictureBox)
    $warningForm.Controls.Add($labelWarning)
    $warningForm.Controls.Add($btnOK)
    $warningForm.Controls.Add($btnCancelWarn)
    
    $script:warningForm = $warningForm
    $warningForm.ShowDialog()
}

# 主倒计时定时器逻辑
$timerCountdown.Add_Tick({
    if ($script:remainingSeconds -gt 0) {
        $script:remainingSeconds--
        
        # 更新状态栏显示
        $m = [math]::Floor($script:remainingSeconds / 60)
        $s = $script:remainingSeconds % 60
        $labelStatus.Text = "距离 $script:actionType 还有：{0}分 {1}秒" -f $m, $s

        # 倒计时不足 30 秒时，强提醒（不停止倒计时）
        if ($script:remainingSeconds -le 30 -and -not $script:warningShown) {
            $script:warningShown = $true
            # 显示非模态警告窗口，倒计时继续
            Show-WarningForm
        }
    } else {
        # 倒计时结束
        $timerCountdown.Stop()
        Start-ShutdownAction
    }
})

# 窗口关闭事件处理 - 防止在倒计时中关闭窗口
$form.Add_FormClosing({
    if ($script:isCounting) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "倒计时进行中，确定要取消并关闭脚本吗？", 
            "确认退出", 
            [System.Windows.Forms.MessageBoxButtons]::YesNo, 
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true # 阻止关闭
        } else {
            Stop-AllActions
        }
    }
})

# --- 组装界面 ---
$form.Controls.Add($labelFunc)
$form.Controls.Add($radioShutdown)
$form.Controls.Add($radioRestart)
$form.Controls.Add($labelTime)
$form.Controls.Add($textTime)
$form.Controls.Add($labelStatus)
$form.Controls.Add($btnApply)
$form.Controls.Add($btnCancel)

# 启动自动应用定时器
$timerAutoApply.Start()

# 显示窗口
$form.ShowDialog()