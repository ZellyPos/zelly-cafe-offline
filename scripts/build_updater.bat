@echo off
echo Building Zelly Updater...

REM Check if .NET is installed
dotnet --version >nul 2>&1
if %errorlevel% neq 0 (
    echo .NET SDK topilmadi. Iltimos .NET 6.0 yoki undan yuqori versiyasini o'rnating.
    pause
    exit /b 1
)

REM Create project directory
if not exist "updater-project" mkdir updater-project
cd updater-project

REM Create new console project
dotnet new console -n ZellyUpdater --force

REM Copy the C# code
echo using System; > ZellyUpdater/Program.cs
echo using System.Diagnostics; >> ZellyUpdater/Program.cs
echo using System.IO; >> ZellyUpdater/Program.cs
echo using System.Net.Http; >> ZellyUpdater/Program.cs
echo using System.Threading.Tasks; >> ZellyUpdater/Program.cs
echo using System.Windows.Forms; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo namespace ZellyUpdater >> ZellyUpdater/Program.cs
echo { >> ZellyUpdater/Program.cs
echo     class Program >> ZellyUpdater/Program.cs
echo     { >> ZellyUpdater/Program.cs
echo         [STAThread] >> ZellyUpdater/Program.cs
echo         static async Task Main(string[] args) >> ZellyUpdater/Program.cs
echo         { >> ZellyUpdater/Program.cs
echo             try >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 string appPath = ""; >> ZellyUpdater/Program.cs
echo                 string updateUrl = ""; >> ZellyUpdater/Program.cs
echo                 string currentVersion = ""; >> ZellyUpdater/Program.cs
echo                 string targetVersion = ""; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Command line arguments >> ZellyUpdater/Program.cs
echo                 for (int i = 0; i ^< args.Length; i++) >> ZellyUpdater/Program.cs
echo                 { >> ZellyUpdater/Program.cs
echo                     switch (args[i]) >> ZellyUpdater/Program.cs
echo                     { >> ZellyUpdater/Program.cs
echo                         case "--app-path": >> ZellyUpdater/Program.cs
echo                             appPath = args[i + 1]; >> ZellyUpdater/Program.cs
echo                             break; >> ZellyUpdater/Program.cs
echo                         case "--update-url": >> ZellyUpdater/Program.cs
echo                             updateUrl = args[i + 1]; >> ZellyUpdater/Program.cs
echo                             break; >> ZellyUpdater/Program.cs
echo                         case "--current-version": >> ZellyUpdater/Program.cs
echo                             currentVersion = args[i + 1]; >> ZellyUpdater/Program.cs
echo                             break; >> ZellyUpdater/Program.cs
echo                         case "--target-version": >> ZellyUpdater/Program.cs
echo                             targetVersion = args[i + 1]; >> ZellyUpdater/Program.cs
echo                             break; >> ZellyUpdater/Program.cs
echo                     } >> ZellyUpdater/Program.cs
echo                 } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 if (string.IsNullOrEmpty(appPath) ^|^| string.IsNullOrEmpty(updateUrl)) >> ZellyUpdater/Program.cs
echo                 { >> ZellyUpdater/Program.cs
echo                     MessageBox.Show("Invalid arguments", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error); >> ZellyUpdater/Program.cs
echo                     return; >> ZellyUpdater/Program.cs
echo                 } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Show progress dialog >> ZellyUpdater/Program.cs
echo                 var progressDialog = new ProgressDialog(); >> ZellyUpdater/Program.cs
echo                 progressDialog.Show(); >> ZellyUpdater/Program.cs
echo                 progressDialog.UpdateStatus("Yangilanish tayorlanmoqda..."); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Step 1: Download new version >> ZellyUpdater/Program.cs
echo                 progressDialog.UpdateStatus("Yangi versiya yuklanmoqda..."); >> ZellyUpdater/Program.cs
echo                 string tempZipPath = Path.Combine(Path.GetTempPath(), "update.zip"); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 using (var httpClient = new HttpClient()) >> ZellyUpdater/Program.cs
echo                 { >> ZellyUpdater/Program.cs
echo                     var response = await httpClient.GetAsync(updateUrl); >> ZellyUpdater/Program.cs
echo                     response.EnsureSuccessStatusCode(); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                     using (var fileStream = File.Create(tempZipPath)) >> ZellyUpdater/Program.cs
echo                     { >> ZellyUpdater/Program.cs
echo                         await response.Content.CopyToAsync(fileStream); >> ZellyUpdater/Program.cs
echo                     } >> ZellyUpdater/Program.cs
echo                 } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Step 2: Wait for main app to close >> ZellyUpdater/Program.cs
echo                 progressDialog.UpdateStatus("Ilova yopilishini kuting..."); >> ZellyUpdater/Program.cs
echo                 await Task.Delay(3000); // 3 sekund kutish >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Step 3: Extract and replace files >> ZellyUpdater/Program.cs
echo                 progressDialog.UpdateStatus("Fayllar almashtirilmoqda..."); >> ZellyUpdater/Program.cs
echo                 string backupPath = Path.Combine(Path.GetTempPath(), "backup"); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Create backup >> ZellyUpdater/Program.cs
echo                 if (Directory.Exists(appPath)) >> ZellyUpdater/Program.cs
echo                 { >> ZellyUpdater/Program.cs
echo                     if (Directory.Exists(backupPath)) >> ZellyUpdater/Program.cs
echo                         Directory.Delete(backupPath, true); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                     CopyDirectory(appPath, backupPath); >> ZellyUpdater/Program.cs
echo                 } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Step 4: Restart the application >> ZellyUpdater/Program.cs
echo                 progressDialog.UpdateStatus("Ilova qayta ishga tushirilmoqda..."); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 string exePath = Path.Combine(appPath, "tezzro.exe"); >> ZellyUpdater/Program.cs
echo                 if (File.Exists(exePath)) >> ZellyUpdater/Program.cs
echo                 { >> ZellyUpdater/Program.cs
echo                     Process.Start(exePath); >> ZellyUpdater/Program.cs
echo                 } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 progressDialog.Close(); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo                 // Show completion message >> ZellyUpdater/Program.cs
echo                 MessageBox.Show( >> ZellyUpdater/Program.cs
echo                     $"Ilova muvaffaqiyatli yangilandi versiyagacha: {targetVersion}", >> ZellyUpdater/Program.cs
echo                     "Yangilash muvaffaqiyatli", >> ZellyUpdater/Program.cs
echo                     MessageBoxButtons.OK, >> ZellyUpdater/Program.cs
echo                     MessageBoxIcon.Information >> ZellyUpdater/Program.cs
echo                 ); >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo             catch (Exception ex) >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 MessageBox.Show($"Yangilash xatoligi: {ex.Message}", "Xatolik", MessageBoxButtons.OK, MessageBoxIcon.Error); >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo         } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo         static void CopyDirectory(string source, string destination) >> ZellyUpdater/Program.cs
echo         { >> ZellyUpdater/Program.cs
echo             if (!Directory.Exists(destination)) >> ZellyUpdater/Program.cs
echo                 Directory.CreateDirectory(destination); >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo             // Copy files >> ZellyUpdater/Program.cs
echo             foreach (string file in Directory.GetFiles(source)) >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 string fileName = Path.GetFileName(file); >> ZellyUpdater/Program.cs
echo                 string destFile = Path.Combine(destination, fileName); >> ZellyUpdater/Program.cs
echo                 File.Copy(file, destFile, true); >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo             // Copy subdirectories >> ZellyUpdater/Program.cs
echo             foreach (string directory in Directory.GetDirectories(source)) >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 string dirName = Path.GetFileName(directory); >> ZellyUpdater/Program.cs
echo                 string destDir = Path.Combine(destination, dirName); >> ZellyUpdater/Program.cs
echo                 CopyDirectory(directory, destDir); >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo         } >> ZellyUpdater/Program.cs
echo     } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo     public class ProgressDialog : Form >> ZellyUpdater/Program.cs
echo     { >> ZellyUpdater/Program.cs
echo         private Label statusLabel; >> ZellyUpdater/Program.cs
echo         private ProgressBar progressBar; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo         public ProgressDialog() >> ZellyUpdater/Program.cs
echo         { >> ZellyUpdater/Program.cs
echo             this.Text = "Zelly POS Yangilash"; >> ZellyUpdater/Program.cs
echo             this.Size = new System.Drawing.Size(400, 150); >> ZellyUpdater/Program.cs
echo             this.StartPosition = FormStartPosition.CenterScreen; >> ZellyUpdater/Program.cs
echo             this.FormBorderStyle = FormBorderStyle.FixedDialog; >> ZellyUpdater/Program.cs
echo             this.MaximizeBox = false; >> ZellyUpdater/Program.cs
echo             this.MinimizeBox = false; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo             statusLabel = new Label >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 Text = "Tayorlanmoqda...", >> ZellyUpdater/Program.cs
echo                 Location = new System.Drawing.Point(20, 20), >> ZellyUpdater/Program.cs
echo                 Size = new System.Drawing.Size(350, 30), >> ZellyUpdater/Program.cs
echo                 TextAlign = System.Drawing.ContentAlignment.MiddleCenter >> ZellyUpdater/Program.cs
echo             }; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo             progressBar = new ProgressBar >> ZellyUpdater/Program.cs
echo             { >> ZIFYUpdater/Program.cs
echo                 Location = new System.Drawing.Point(20, 60), >> ZellyUpdater/Program.cs
echo                 Size = new System.Drawing.Size(350, 20), >> ZellyUpdater/Program.cs
echo                 Style = ProgressBarStyle.Marquee >> ZellyUpdater/Program.cs
echo             }; >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo             this.Controls.Add(statusLabel); >> ZellyUpdater/Program.cs
echo             this.Controls.Add(progressBar); >> ZellyUpdater/Program.cs
echo         } >> ZellyUpdater/Program.cs
echo. >> ZellyUpdater/Program.cs
echo         public void UpdateStatus(string status) >> ZellyUpdater/Program.cs
echo         { >> ZellyUpdater/Program.cs
echo             if (statusLabel.InvokeRequired) >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 statusLabel.Invoke(new Action(() ^> statusLabel.Text = status)); >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo             else >> ZellyUpdater/Program.cs
echo             { >> ZellyUpdater/Program.cs
echo                 statusLabel.Text = status; >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo             } >> ZellyUpdater/Program.cs
echo             Application.DoEvents(); >> ZellyUpdater/Program.cs
echo         } >> ZellyUpdater/Program.cs
echo     } >> ZellyUpdater/Program.cs
echo } >> ZellyUpdater/Program.cs

REM Add Windows Forms reference
cd ZellyUpdater
dotnet add package System.Windows.Forms

REM Build as single file executable
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishReadyToRun=true -o ../updater.exe

cd ..
echo Updater muvaffaqiyatli yaratildi: updater.exe
pause
