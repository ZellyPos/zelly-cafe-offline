# Zelly POS — Windows desktop ilovasini dasturiy boshqarish drayveri.
#
# Har chaqiruv mustaqil: oyna deskriptori har safar PID orqali qayta
# topiladi, shuning uchun buyruqlarni Bash/PowerShell'dan ketma-ket
# yuborish mumkin — holat saqlanmaydi.
#
# Ishlatish:
#   powershell -File driver.ps1 launch          # ilovani ishga tushirish
#   powershell -File driver.ps1 shot out.png    # skrinshot
#   powershell -File driver.ps1 click 645 98    # bosish
#   powershell -File driver.ps1 type "Osh"      # matn kiritish
#   powershell -File driver.ps1 key Escape      # klavisha
#   powershell -File driver.ps1 rect            # oyna o'lchami
#   powershell -File driver.ps1 quit            # yopish

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Command,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$ProcName = 'tezzro'
$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'Zelly.Win').Type) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Zelly {
  public class Win {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, UIntPtr e);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
  }
}
'@
}

function Get-AppWindow {
  $p = Get-Process $ProcName -ErrorAction SilentlyContinue |
       Where-Object { $_.MainWindowHandle -ne 0 } |
       Select-Object -First 1
  if ($null -eq $p) { return $null }
  return $p
}

function Require-AppWindow {
  $p = Get-AppWindow
  if ($null -eq $p) {
    Write-Error "Ilova oynasi topilmadi. Avval: driver.ps1 launch"
  }
  return $p
}

# Oynani oldinga chiqaradi. Flutter'ning Windows embedder'i fon oynasiga
# yuborilgan sintetik input'ni e'tiborsiz qoldiradi — har bosishdan oldin
# shart.
function Focus-App {
  $p = Require-AppWindow
  [Zelly.Win]::ShowWindow($p.MainWindowHandle, 9) | Out-Null   # SW_RESTORE
  [Zelly.Win]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
  return $p
}

switch ($Command.ToLower()) {

  # ── Ishga tushirish ─────────────────────────────────────────────────────
  'launch' {
    $existing = Get-AppWindow
    if ($null -ne $existing) {
      Write-Output "already-running pid=$($existing.Id)"
      break
    }

    $exe = Join-Path $RepoRoot 'build\windows\x64\runner\Release\tezzro.exe'
    if (-not (Test-Path $exe)) {
      $exe = Join-Path $RepoRoot 'build\windows\x64\runner\Debug\tezzro.exe'
    }
    if (-not (Test-Path $exe)) {
      Write-Error "Build topilmadi. Avval: flutter build windows --release"
    }

    # MUHIM: ilova o'z versiyasini exe yonidagi version.txt dan o'qiydi
    # (update_service.dart). Build papkasida u yo'q, CWD'da pubspec.yaml
    # ham yo'q — natijada versiya "1.0.0" deb qabul qilinadi va ilova
    # ochilishi bilan AVTO-YANGILANISHNI yuklab, o'rnatishga urinadi.
    # Shuning uchun ishga tushirishdan oldin version.txt ko'chiriladi.
    $exeDir = Split-Path -Parent $exe
    $srcVersion = Join-Path $RepoRoot 'version.txt'
    if (Test-Path $srcVersion) {
      Copy-Item $srcVersion (Join-Path $exeDir 'version.txt') -Force
    } else {
      Write-Warning "version.txt topilmadi — avto-yangilanish ishga tushishi mumkin"
    }

    Start-Process -FilePath $exe -WorkingDirectory $exeDir

    # Oyna paydo bo'lguncha kutamiz. Litsenziya tekshiruvi va SQLite
    # migratsiyalari sabab birinchi kadr ~10s gacha cho'zilishi mumkin.
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
      $p = Get-AppWindow
      if ($null -ne $p) {
        Start-Sleep -Milliseconds 1500   # birinchi kadr chizilsin
        Write-Output "launched pid=$($p.Id)"
        exit 0
      }
      Start-Sleep -Milliseconds 500
    }
    Write-Error "60s ichida oyna ochilmadi"
  }

  # ── Oyna o'lchami ───────────────────────────────────────────────────────
  'rect' {
    $p = Require-AppWindow
    $r = New-Object Zelly.Win+RECT
    [Zelly.Win]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
    Write-Output "$($r.Left) $($r.Top) $($r.Right) $($r.Bottom)"
  }

  'focus' {
    $p = Focus-App
    Write-Output "focused pid=$($p.Id)"
  }

  # ── Skrinshot ───────────────────────────────────────────────────────────
  # Oyna to'g'ridan-to'g'ri emas, ekrandan olinadi: Flutter GPU'ga chizadi,
  # PrintWindow bo'sh kadr qaytaradi.
  'shot' {
    if ($Args.Count -lt 1) { Write-Error "shot <fayl.png>" }
    $out = $Args[0]
    $p = Focus-App
    $r = New-Object Zelly.Win+RECT
    [Zelly.Win]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
    $w = $r.Right - $r.Left
    $h = $r.Bottom - $r.Top

    $dir = Split-Path -Parent $out
    if ($dir -and -not (Test-Path $dir)) {
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "saved $out (${w}x${h})"
  }

  # ── Bosish ──────────────────────────────────────────────────────────────
  # DIQQAT: oddiy "kursorni qo'y + darhol bos" ISHLAMAYDI. Flutter avval
  # hover (PointerHover) hodisasini kutadi, keyingina bosishni o'sha
  # vidjetga yo'naltiradi. Shuning uchun kursor bosqichma-bosqich
  # siljitiladi va bosish 350ms ushlab turiladi.
  'click' {
    if ($Args.Count -lt 2) { Write-Error "click <x> <y>" }
    $x = [int]$Args[0]
    $y = [int]$Args[1]
    Focus-App | Out-Null

    # hover yo'li — oxirgi nuqtaga sekin yaqinlashamiz
    for ($i = 5; $i -ge 1; $i--) {
      [Zelly.Win]::SetCursorPos($x - ($i * 12), $y - ($i * 4)) | Out-Null
      Start-Sleep -Milliseconds 70
    }
    [Zelly.Win]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 400

    [Zelly.Win]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # LEFTDOWN
    Start-Sleep -Milliseconds 350
    [Zelly.Win]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # LEFTUP
    Start-Sleep -Milliseconds 1200                              # animatsiya
    Write-Output "clicked $x $y"
  }

  # ── Matn kiritish ───────────────────────────────────────────────────────
  # Avval kerakli maydonni `click` bilan fokuslang.
  'type' {
    if ($Args.Count -lt 1) { Write-Error "type <matn>" }
    Focus-App | Out-Null
    $text = ($Args -join ' ')
    # SendKeys uchun maxsus belgilarni himoyalash
    $escaped = $text -replace '([+^%~(){}\[\]])', '{$1}'
    [System.Windows.Forms.SendKeys]::SendWait($escaped)
    Start-Sleep -Milliseconds 800
    Write-Output "typed: $text"
  }

  # ── Klavisha ────────────────────────────────────────────────────────────
  # Masalan: Escape, Enter, Tab, Backspace
  'key' {
    if ($Args.Count -lt 1) { Write-Error "key <nom>" }
    Focus-App | Out-Null
    [System.Windows.Forms.SendKeys]::SendWait("{$($Args[0])}")
    Start-Sleep -Milliseconds 900
    Write-Output "key: $($Args[0])"
  }

  'quit' {
    $procs = Get-Process $ProcName -ErrorAction SilentlyContinue
    if ($null -eq $procs) { Write-Output "not-running"; break }
    $procs | Stop-Process -Force
    Write-Output "stopped"
  }

  default {
    Write-Error "Noma'lum buyruq: $Command (launch|rect|focus|shot|click|type|key|quit)"
  }
}
