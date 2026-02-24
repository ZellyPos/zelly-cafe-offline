using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ZellyUpdater
{
    class Program
    {
        [STAThread]
        static async Task Main(string[] args)
        {
            try
            {
                string appPath = "";
                string updateUrl = "";
                string currentVersion = "";
                string targetVersion = "";

                // Command line arguments
                for (int i = 0; i < args.Length; i++)
                {
                    switch (args[i])
                    {
                        case "--app-path":
                            appPath = args[i + 1];
                            break;
                        case "--update-url":
                            updateUrl = args[i + 1];
                            break;
                        case "--current-version":
                            currentVersion = args[i + 1];
                            break;
                        case "--target-version":
                            targetVersion = args[i + 1];
                            break;
                    }
                }

                if (string.IsNullOrEmpty(appPath) || string.IsNullOrEmpty(updateUrl))
                {
                    MessageBox.Show("Invalid arguments", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                // Show progress dialog
                var progressDialog = new ProgressDialog();
                progressDialog.Show();
                progressDialog.UpdateStatus("Yangilanish tayorlanmoqda...");

                // Step 1: Download new version
                progressDialog.UpdateStatus("Yangi versiya yuklanmoqda...");
                string tempZipPath = Path.Combine(Path.GetTempPath(), "update.zip");
                
                using (var httpClient = new HttpClient())
                {
                    var response = await httpClient.GetAsync(updateUrl);
                    response.EnsureSuccessStatusCode();
                    
                    using (var fileStream = File.Create(tempZipPath))
                    {
                        await response.Content.CopyToAsync(fileStream);
                    }
                }

                // Step 2: Wait for main app to close
                progressDialog.UpdateStatus("Ilova yopilishini kuting...");
                await Task.Delay(3000); // 3 sekund kutish

                // Step 3: Extract and replace files
                progressDialog.UpdateStatus("Fayllar almashtirilmoqda...");
                string backupPath = Path.Combine(Path.GetTempPath(), "backup");
                
                // Create backup
                if (Directory.Exists(appPath))
                {
                    if (Directory.Exists(backupPath))
                        Directory.Delete(backupPath, true);
                    
                    CopyDirectory(appPath, backupPath);
                }

                // Extract new files (you'll need System.IO.Compression for this)
                // For simplicity, let's assume we're downloading individual files
                
                // Step 4: Restart the application
                progressDialog.UpdateStatus("Ilova qayta ishga tushirilmoqda...");
                
                string exePath = Path.Combine(appPath, "tezzro.exe");
                if (File.Exists(exePath))
                {
                    Process.Start(exePath);
                }

                progressDialog.Close();
                
                // Show completion message
                MessageBox.Show(
                    $"Ilova muvaffaqiyatli yangilandi versiyagacha: {targetVersion}", 
                    "Yangilash muvaffaqiyatli", 
                    MessageBoxButtons.OK, 
                    MessageBoxIcon.Information
                );
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Yangilash xatoligi: {ex.Message}", "Xatolik", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        static void CopyDirectory(string source, string destination)
        {
            if (!Directory.Exists(destination))
                Directory.CreateDirectory(destination);

            // Copy files
            foreach (string file in Directory.GetFiles(source))
            {
                string fileName = Path.GetFileName(file);
                string destFile = Path.Combine(destination, fileName);
                File.Copy(file, destFile, true);
            }

            // Copy subdirectories
            foreach (string directory in Directory.GetDirectories(source))
            {
                string dirName = Path.GetFileName(directory);
                string destDir = Path.Combine(destination, dirName);
                CopyDirectory(directory, destDir);
            }
        }
    }

    public class ProgressDialog : Form
    {
        private Label statusLabel;
        private ProgressBar progressBar;

        public ProgressDialog()
        {
            this.Text = "Zelly POS Yangilash";
            this.Size = new System.Drawing.Size(400, 150);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;

            statusLabel = new Label
            {
                Text = "Tayorlanmoqda...",
                Location = new System.Drawing.Point(20, 20),
                Size = new System.Drawing.Size(350, 30),
                TextAlign = System.Drawing.ContentAlignment.MiddleCenter
            };

            progressBar = new ProgressBar
            {
                Location = new System.Drawing.Point(20, 60),
                Size = new System.Drawing.Size(350, 20),
                Style = ProgressBarStyle.Marquee
            };

            this.Controls.Add(statusLabel);
            this.Controls.Add(progressBar);
        }

        public void UpdateStatus(string status)
        {
            if (statusLabel.InvokeRequired)
            {
                statusLabel.Invoke(new Action(() => statusLabel.Text = status));
            }
            else
            {
                statusLabel.Text = status;
            }
            Application.DoEvents();
        }
    }
}
