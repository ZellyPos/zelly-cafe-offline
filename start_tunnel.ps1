# Tezzro POS — Cloudflare Tunnel + Telegram Mini App
# Ishlatish: PowerShell da o'ng klik -> "Run with PowerShell"

$cloudflaredPath = "$env:USERPROFILE\Downloads\cloudflared-windows-386.exe"
# Token va Chat ID ni ilovaning Sozlamalar > Telegram bo'limidan oling
$botToken = ""   # Bu yerga token yozing yoki ilovadan boshqaring
$chatId   = ""   # Bu yerga chat_id yozing
$port     = 8080

if (-not (Test-Path $cloudflaredPath)) {
    Write-Host "❌ cloudflared.exe topilmadi: $cloudflaredPath" -ForegroundColor Red
    Read-Host "Enter bosing..."
    exit
}

Write-Host "🚀 Cloudflare tunnel ishga tushmoqda..." -ForegroundColor Cyan

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName        = $cloudflaredPath
$psi.Arguments       = "tunnel --url http://localhost:$port"
$psi.UseShellExecute = $false
$psi.RedirectStandardError  = $true
$psi.RedirectStandardOutput = $true
$psi.CreateNoWindow  = $false

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

$script:tunnelUrl = $null
$script:sent      = $false

$handler = {
    param($s, $e)
    if (-not $e.Data) { return }
    Write-Host $e.Data
    if (-not $script:sent -and $e.Data -match 'https://[a-z0-9\-]+\.trycloudflare\.com') {
        $script:tunnelUrl = $Matches[0]
        $script:sent = $true

        $webAppUrl = "$($script:tunnelUrl)/reports/view"
        Write-Host ""
        Write-Host "✅ URL topildi: $webAppUrl" -ForegroundColor Green
        Write-Host "📤 Telegram ga yuborilmoqda..." -ForegroundColor Yellow

        $body = [ordered]@{
            chat_id    = $chatId
            text       = "✅ *POS serveri ishga tushdi*`n🕐 Vaqt: $(Get-Date -Format 'HH:mm dd.MM.yyyy')"
            parse_mode = "Markdown"
            reply_markup = @{
                inline_keyboard = @(
                    @( @{ text = "📊 Hisobotni ochish"; web_app = @{ url = $webAppUrl } } )
                )
            }
        } | ConvertTo-Json -Depth 10 -Compress

        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            Invoke-RestMethod `
                -Uri "https://api.telegram.org/bot$botToken/sendMessage" `
                -Method POST `
                -ContentType "application/json; charset=utf-8" `
                -Body $bytes | Out-Null
            Write-Host "✅ Telegram ga yuborildi!" -ForegroundColor Green
        } catch {
            Write-Host "❌ Telegram xato: $_" -ForegroundColor Red
        }
    }
}

$process.add_ErrorDataReceived($handler)
$process.add_OutputDataReceived($handler)

$process.Start() | Out-Null
$process.BeginErrorReadLine()
$process.BeginOutputReadLine()

Write-Host "Tunnel ishlayapti. To'xtatish uchun bu oynani yoping." -ForegroundColor DarkGray
$process.WaitForExit()
