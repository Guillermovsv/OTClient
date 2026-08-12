using System.IO.Compression;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;

namespace OtLauncher;

public class MainForm : Form
{
    // Website path that hosts version.txt and the client zip. Adjust if the
    // site's domain/port changes.
    private static readonly string BaseUrl = NormalizeBaseUrl(
        Environment.GetEnvironmentVariable("DELYRIUMZ_UPDATE_BASE_URL")
        ?? "https://delyriumzot.com/client/otc/");
    private static readonly string VersionManifestUrl = BaseUrl + "version.txt";

    // Assign these later. Empty links intentionally keep their buttons disabled.
    private const string NewsUrl = "";
    private const string WebsiteUrl = "";
    private const string DiscordUrl = "";
    private const string SocialUrl = "";
    private const string CoinsUrl = "";

    private const string ConfigDirName = "OtLauncher";
    private const string DefaultInstallFolderName = "Client";
    private const string DefaultInstallParentName = "DelyriumzOT";
    private const string ShortcutName = "Play OTClient.lnk";

    // Player-owned files are copied over a staged update before it is swapped
    // into place. Program files are deliberately not retained, so removed or
    // renamed modules cannot linger between releases.
    private static readonly string[] PreservedUserFiles =
    {
        "config.otml",
        "otclientrc.lua",
        "config.ini",
        "minimap.otmm"
    };

    private static readonly string[] PreservedUserDirectories =
    {
        "controls",
        "profiles",
        "screenshots",
        "auto_screenshots",
        "logs",
        "exports"
    };

    private static readonly string[] PreservedRootPatterns = { "*.log", "*.otmm" };

    private static readonly Color BgColor = Color.FromArgb(8, 13, 17);
    private static readonly Color PanelColor = Color.FromArgb(13, 21, 26);
    private static readonly Color TextColor = Color.FromArgb(231, 224, 202);
    private static readonly Color MutedTextColor = Color.FromArgb(158, 154, 139);
    private static readonly Color PositiveColor = Color.FromArgb(76, 175, 80);
    private static readonly Color NegativeColor = Color.FromArgb(229, 57, 53);
    private static readonly Color InfoColor = Color.FromArgb(203, 153, 72);
    private static readonly Color AccentBlue = Color.FromArgb(25, 124, 116);
    private static readonly Color NavColor = Color.FromArgb(116, 48, 42);
    private static readonly Color NavHoverColor = Color.FromArgb(174, 77, 52);
    private static readonly Color DisabledColor = Color.FromArgb(70, 70, 74);

    private static readonly string ConfigDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), ConfigDirName);
    private static readonly string ConfigPath = Path.Combine(ConfigDir, "config.json");

    private readonly Label _titleLabel = new();
    private readonly Label _statusLabel = new();
    private readonly Label _installPathLabel = new();
    private readonly Label _versionLabel = new();
    private readonly ProgressBar _progressBar = new();
    private readonly Label _progressPercentLabel = new();
    private readonly RichTextBox _log = new();
    private readonly Button _updateButton = new();
    private readonly Button _retryButton = new();
    private readonly Button _playButton = new();

    // How often to silently re-check version.txt while the launcher stays
    // open, so players never have to close/reopen it to pick up an update.
    private static readonly TimeSpan UpdateCheckInterval = TimeSpan.FromMinutes(3);

    private readonly System.Windows.Forms.Timer _updateCheckTimer = new()
    {
        Interval = (int)UpdateCheckInterval.TotalMilliseconds
    };

    private LauncherConfig _config = new();
    private string? _latestVersion;
    private string? _latestFileName;
    private long _latestSize;
    private string? _latestSha256;
    private Func<Task>? _retryAction;
    private bool _repairMode;
    private bool _isBusy;
    private System.Diagnostics.Process? _clientProcess;
    private bool _updatePendingAfterClientExit;

    public MainForm()
    {
        Text = "Delyriumz Open Tibia Server";
        ClientSize = new Size(1100, 700);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = BgColor;
        Font = new Font("Trebuchet MS", 9);
        BackgroundImage = LoadEmbeddedImage("launcher-background.png");
        BackgroundImageLayout = ImageLayout.Stretch;

        _titleLabel.SetBounds(48, 32, 1004, 56);
        _titleLabel.Text = "DELYRIUMZ";
        _titleLabel.Font = new Font("Georgia", 28, FontStyle.Bold);
        _titleLabel.ForeColor = TextColor;
        _titleLabel.BackColor = Color.Transparent;

        var channelLabel = new Label
        {
            Text = "OPEN TIBIA SERVER  •  2D PIXEL MMORPG",
            ForeColor = InfoColor,
            BackColor = Color.Transparent,
            Font = new Font("Trebuchet MS", 9, FontStyle.Bold)
        };
        channelLabel.SetBounds(52, 88, 500, 24);

        var newsPanel = new Panel { BackColor = PanelColor };
        newsPanel.SetBounds(430, 126, 560, 330);
        newsPanel.Visible = false;
        var newsHeading = new Label
        {
            Text = "LATEST NEWS & UPDATES",
            ForeColor = InfoColor,
            BackColor = Color.Transparent,
            Font = new Font("Georgia", 15, FontStyle.Bold)
        };
        newsHeading.SetBounds(24, 20, 510, 28);
        var closeNewsButton = new Button { Text = "×", Width = 34, Height = 30 };
        closeNewsButton.SetBounds(510, 12, 34, 30);
        StyleButton(closeNewsButton, NavColor);
        closeNewsButton.FlatAppearance.BorderSize = 1;
        closeNewsButton.FlatAppearance.BorderColor = InfoColor;
        closeNewsButton.Click += (_, _) => newsPanel.Hide();
        var newsBody = new RichTextBox
        {
            ReadOnly = true,
            BorderStyle = BorderStyle.None,
            BackColor = Color.FromArgb(18, 26, 31),
            ForeColor = TextColor,
            Font = new Font("Trebuchet MS", 10),
            Text = "News feed is ready.\n\nAssign NewsUrl in MainForm.cs when the website news endpoint is available. The launcher can then display your latest announcements here."
        };
        newsBody.SetBounds(24, 58, 512, 246);
        newsPanel.Controls.Add(newsHeading);
        newsPanel.Controls.Add(closeNewsButton);
        newsPanel.Controls.Add(newsBody);

        var linksPanel = new FlowLayoutPanel
        {
            BackColor = Color.Transparent,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false
        };
        linksPanel.SetBounds(1004, 126, 72, 330);
        var newsButton = AddLinkButton(linksPanel, "NEWS", "\uE8A5", NewsUrl);
        newsButton.Click += (_, _) => newsPanel.Visible = !newsPanel.Visible;
        AddLinkButton(linksPanel, "WEB", "\uE774", WebsiteUrl);
        AddLinkButton(linksPanel, "CHAT", "\uE8BD", DiscordUrl);
        AddLinkButton(linksPanel, "SOCIAL", "\uE716", SocialUrl);
        AddLinkButton(linksPanel, "COINS", "\uE8C7", CoinsUrl);

        _statusLabel.SetBounds(430, 478, 560, 28);
        _statusLabel.Text = "Checking for updates...";
        _statusLabel.Font = new Font("Trebuchet MS", 10, FontStyle.Bold);
        _statusLabel.ForeColor = InfoColor;
        _statusLabel.BackColor = Color.Transparent;

        _installPathLabel.SetBounds(430, 508, 560, 20);
        _installPathLabel.ForeColor = MutedTextColor;
        _installPathLabel.BackColor = Color.Transparent;

        _versionLabel.SetBounds(430, 530, 560, 20);
        _versionLabel.ForeColor = MutedTextColor;
        _versionLabel.BackColor = Color.Transparent;

        _progressBar.SetBounds(430, 558, 560, 20);
        _progressBar.Minimum = 0;
        _progressBar.Maximum = 100;
        _progressBar.Visible = false;

        _progressPercentLabel.SetBounds(430, 558, 560, 20);
        _progressPercentLabel.TextAlign = ContentAlignment.MiddleCenter;
        _progressPercentLabel.ForeColor = TextColor;
        _progressPercentLabel.Font = new Font("Segoe UI", 8, FontStyle.Bold);
        _progressPercentLabel.Visible = false;
        _progressPercentLabel.BringToFront();

        _updateButton.SetBounds(430, 596, 140, 48);
        _updateButton.Text = "Install";
        _updateButton.Visible = false;
        StyleButton(_updateButton, AccentBlue);
        _updateButton.Click += async (_, _) => await DownloadAndInstallUpdateAsync();

        _retryButton.SetBounds(580, 596, 140, 48);
        _retryButton.Text = "Retry";
        _retryButton.Visible = false;
        StyleButton(_retryButton, NegativeColor);
        _retryButton.Click += async (_, _) =>
        {
            if (_retryAction != null)
            {
                await _retryAction();
            }
        };

        _playButton.SetBounds(750, 588, 240, 58);
        _playButton.Text = "ENTER DELYRIUMZ";
        StyleButton(_playButton, PositiveColor);
        _playButton.Click += (_, _) => LaunchClient();
        SetPlayEnabled(false);

        _log.SetBounds(48, 478, 350, 168);
        _log.ReadOnly = true;
        _log.BackColor = PanelColor;
        _log.ForeColor = TextColor;
        _log.BorderStyle = BorderStyle.FixedSingle;
        _log.Font = new Font("Consolas", 8);

        Controls.Add(channelLabel);
        Controls.Add(newsPanel);
        Controls.Add(linksPanel);
        Controls.Add(_titleLabel);
        Controls.Add(_statusLabel);
        Controls.Add(_installPathLabel);
        Controls.Add(_versionLabel);
        Controls.Add(_progressBar);
        Controls.Add(_progressPercentLabel);
        Controls.Add(_updateButton);
        Controls.Add(_retryButton);
        Controls.Add(_playButton);
        Controls.Add(_log);

        _updateCheckTimer.Tick += async (_, _) => await CheckForUpdatesAsync(background: true);

        Load += async (_, _) =>
        {
            await InitializeAsync();
            _updateCheckTimer.Start();
        };
    }

    private static Button AddLinkButton(Control parent, string text, string glyph, string url)
    {
        var button = new Button
        {
            Text = text,
            Image = CreateLinkIcon(glyph),
            TextImageRelation = TextImageRelation.ImageAboveText,
            ImageAlign = ContentAlignment.MiddleCenter,
            TextAlign = ContentAlignment.MiddleCenter,
            Width = 68,
            Height = 56,
            Margin = new Padding(0, 0, 0, 8)
        };
        StyleButton(button, NavColor);
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.BorderColor = InfoColor;
        button.FlatAppearance.MouseOverBackColor = NavHoverColor;
        button.FlatAppearance.MouseDownBackColor = InfoColor;
        if (!string.IsNullOrWhiteSpace(url))
        {
            button.Click += (_, _) => System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true });
        }
        else
        {
            new ToolTip().SetToolTip(button, text == "NEWS" ? "Show or hide news" : "Link not configured yet");
        }
        parent.Controls.Add(button);
        return button;
    }

    private static Bitmap CreateLinkIcon(string glyph)
    {
        var bitmap = new Bitmap(24, 24);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.Transparent);
        graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        using var font = new Font("Segoe MDL2 Assets", 15, FontStyle.Regular, GraphicsUnit.Pixel);
        using var brush = new SolidBrush(Color.White);
        using var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        graphics.DrawString(glyph, font, brush, new RectangleF(0, 0, 24, 24), format);
        return bitmap;
    }

    private static Image? LoadEmbeddedImage(string fileName)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith(fileName, StringComparison.OrdinalIgnoreCase));

        if (resourceName == null)
        {
            return null;
        }

        using var stream = assembly.GetManifestResourceStream(resourceName);
        return stream == null ? null : Image.FromStream(stream);
    }

    private static string NormalizeBaseUrl(string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttps &&
             !(uri.Scheme == Uri.UriSchemeHttp && uri.IsLoopback)))
        {
            throw new InvalidOperationException("The update base URL must use HTTPS (HTTP is allowed only for localhost testing).");
        }

        return value.TrimEnd('/') + "/";
    }

    private static void StyleButton(Button button, Color accent)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = accent;
        button.ForeColor = Color.White;
        button.Font = new Font("Segoe UI", 9, FontStyle.Bold);
        button.Cursor = Cursors.Hand;
    }

    internal static bool IsInstallValid(string installDir)
    {
        if (!Directory.Exists(installDir))
        {
            return false;
        }

        // init.lua is the marker file the client itself requires to start;
        // if it's missing the install is broken regardless of what
        // version.txt says was installed.
        if (!File.Exists(Path.Combine(installDir, "init.lua")))
        {
            return false;
        }

        return File.Exists(Path.Combine(installDir, "otclient.exe"));
    }

    private void EnterRepairMode(string reason)
    {
        _repairMode = true;
        SetStatus("Installation needs repair.", NegativeColor);
        AppendLog(reason, NegativeColor);
        _updateButton.Text = "Repair";
        StyleButton(_updateButton, NegativeColor);
        _updateButton.Visible = true;
        _updateButton.Enabled = true;
        SetPlayEnabled(false);
    }

    private void SetPlayEnabled(bool enabled)
    {
        _playButton.Enabled = enabled;
        _playButton.BackColor = enabled ? PositiveColor : DisabledColor;
        _playButton.ForeColor = enabled ? Color.White : MutedTextColor;
    }

    private void SetStatus(string text, Color color)
    {
        _statusLabel.Text = text;
        _statusLabel.ForeColor = color;
    }

    private void AppendLog(string message, Color color)
    {
        if (_log.IsDisposed)
        {
            return;
        }

        _log.SelectionStart = _log.TextLength;
        _log.SelectionLength = 0;
        _log.SelectionColor = color;
        _log.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}\n");
        _log.ScrollToCaret();
    }

    private async Task InitializeAsync()
    {
        _config = LauncherConfig.Load(ConfigPath);
        AppendLog("Launcher started.", MutedTextColor);

        if (!IsSafeDedicatedInstallDirectory(_config.InstallDir))
        {
            if (!string.IsNullOrWhiteSpace(_config.InstallDir))
            {
                AppendLog(
                    $"Ignored unsafe legacy install folder '{_config.InstallDir}'. No files there were changed.",
                    NegativeColor);
            }

            _config.InstallDir = GetDefaultInstallDirectory();
            _config.InstalledVersion = null;
            _config.Save(ConfigPath);
            AppendLog($"Install folder set to {_config.InstallDir}", MutedTextColor);
        }

        Directory.CreateDirectory(_config.InstallDir!);
        _installPathLabel.Text = "Install folder: " + _config.InstallDir;
        _versionLabel.Text = "Installed version: " + (_config.InstalledVersion ?? "none");

        if (await TryInstallBundledReleaseAsync())
        {
            // Still check the website after bootstrapping. If it has not been
            // deployed yet, CheckForUpdatesAsync keeps this valid local build
            // playable and exposes Retry without undoing the installation.
            await CheckForUpdatesAsync();
            return;
        }

        await CheckForUpdatesAsync();
    }

    internal static string GetDefaultInstallDirectory() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        DefaultInstallParentName,
        DefaultInstallFolderName);

    internal static bool IsSafeDedicatedInstallDirectory(string? installDir)
    {
        if (string.IsNullOrWhiteSpace(installDir))
        {
            return false;
        }

        try
        {
            var fullPath = Path.GetFullPath(installDir).TrimEnd(Path.DirectorySeparatorChar);
            if (!Path.GetFileName(fullPath).Equals(DefaultInstallFolderName, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            var parent = Directory.GetParent(fullPath);
            return parent != null && Directory.GetParent(parent.FullName) != null;
        }
        catch
        {
            return false;
        }
    }

    private async Task<bool> TryInstallBundledReleaseAsync()
    {
        var launcherPath = Environment.ProcessPath;
        var launcherDir = launcherPath == null ? null : Path.GetDirectoryName(launcherPath);
        if (launcherDir == null)
        {
            return false;
        }

        var manifestPath = Path.Combine(launcherDir, "version.txt");
        if (!File.Exists(manifestPath))
        {
            return false;
        }

        try
        {
            using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(manifestPath));
            var manifest = ParseManifest(doc.RootElement);
            var packagePath = Path.Combine(launcherDir, manifest.FileName);
            if (!File.Exists(packagePath))
            {
                AppendLog($"Bundled manifest found, but {manifest.FileName} is missing beside the launcher.", InfoColor);
                return false;
            }

            if (_config.InstalledVersion == manifest.Version && IsInstallValid(_config.InstallDir!))
            {
                return false;
            }

            _latestVersion = manifest.Version;
            _latestFileName = manifest.FileName;
            _latestSize = manifest.Size;
            _latestSha256 = manifest.Sha256;
            AppendLog($"Installing bundled client {manifest.Version}...", InfoColor);
            await DownloadAndInstallUpdateAsync(packagePath);
            return _config.InstalledVersion == manifest.Version && IsInstallValid(_config.InstallDir!);
        }
        catch (Exception ex)
        {
            AppendLog("Bundled release could not be installed: " + ex.Message, NegativeColor);
            return false;
        }
    }

    // background=true is used by the periodic timer (and the post-game-exit
    // recheck): it skips the "Checking for updates..." status noise and,
    // most importantly, never interrupts a session already in progress.
    private async Task CheckForUpdatesAsync(bool background = false)
    {
        if (_isBusy)
        {
            return;
        }

        var clientRunning = _clientProcess != null && !_clientProcess.HasExited;
        if (background && clientRunning)
        {
            // Don't touch installed files while the game is running - just see
            // whether an update exists so it's ready the moment they close it.
            try
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
                var json = await http.GetStringAsync(VersionManifestUrl);
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                var manifest = ParseManifest(root);
                var remoteVersion = manifest.Version;

                if (remoteVersion != _config.InstalledVersion && !_updatePendingAfterClientExit)
                {
                    _latestVersion = remoteVersion;
                    _latestFileName = manifest.FileName;
                    _latestSize = manifest.Size;
                    _latestSha256 = manifest.Sha256;
                    _updatePendingAfterClientExit = true;
                    AppendLog($"Update available: {_config.InstalledVersion} -> {_latestVersion}. Will install as soon as you close the game.", InfoColor);
                    SetStatus("Update ready - will install after you close the game.", InfoColor);
                }
            }
            catch
            {
                // Silent by design - a background connectivity blip while playing
                // shouldn't surface an error; the next periodic tick will retry.
            }
            return;
        }

        _isBusy = true;
        _retryButton.Visible = false;
        if (!background)
        {
            SetStatus("Checking for updates...", InfoColor);
            AppendLog("Checking for updates...", MutedTextColor);
        }

        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
            var json = await http.GetStringAsync(VersionManifestUrl);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var manifest = ParseManifest(root);
            _latestVersion = manifest.Version;
            _latestFileName = manifest.FileName;
            _latestSize = manifest.Size;
            _latestSha256 = manifest.Sha256;

            if (_config.InstalledVersion == _latestVersion)
            {
                _updatePendingAfterClientExit = false;

                if (!IsInstallValid(_config.InstallDir!))
                {
                    AppendLog("Installed files are missing or incomplete - repairing automatically.", NegativeColor);
                    _repairMode = true;
                    _isBusy = false;
                    await DownloadAndInstallUpdateAsync();
                    return;
                }

                if (!background)
                {
                    SetStatus($"Up to date ({_latestVersion}).", PositiveColor);
                    AppendLog($"Up to date ({_latestVersion}).", PositiveColor);
                }
                SetPlayEnabled(true);
                _updateButton.Visible = false;
            }
            else
            {
                var isFirstInstall = _config.InstalledVersion == null;
                AppendLog(
                    isFirstInstall
                        ? $"New install available: {_latestVersion}. Installing automatically..."
                        : $"Update available: {_config.InstalledVersion} -> {_latestVersion}. Updating automatically...",
                    InfoColor);
                // No manual click required - download and install right away.
                _isBusy = false;
                await DownloadAndInstallUpdateAsync();
                return;
            }
        }
        catch (Exception ex)
        {
            if (!background)
            {
                SetStatus("Could not check for updates.", NegativeColor);
                AppendLog("Update check failed: " + ex.Message, NegativeColor);
                _retryAction = () => CheckForUpdatesAsync();
                _retryButton.Visible = true;
                // Don't hard-block play if we've already installed a version before and
                // the update check itself is what failed (e.g. no internet right now) -
                // but only if the files are actually still there.
                SetPlayEnabled(_config.InstalledVersion != null && IsInstallValid(_config.InstallDir!));
            }
        }
        finally
        {
            _isBusy = false;
        }
    }

    private async Task DownloadAndInstallUpdateAsync(string? bundledPackagePath = null)
    {
        if (_latestFileName == null || _latestVersion == null || _latestSha256 == null)
        {
            return;
        }

        _isBusy = true;
        _updateButton.Enabled = false;
        _retryButton.Visible = false;
        SetPlayEnabled(false);
        _progressBar.Visible = true;
        _progressBar.Value = 0;
        _progressPercentLabel.Visible = true;
        _progressPercentLabel.Text = "0%";
        SetStatus(bundledPackagePath == null ? "Downloading update..." : "Preparing bundled client...", InfoColor);
        AppendLog(
            bundledPackagePath == null ? $"Downloading {_latestFileName}..." : $"Reading bundled {_latestFileName}...",
            MutedTextColor);

        var tempZip = Path.Combine(Path.GetTempPath(), $"otclient-{Guid.NewGuid()}.zip");
        string? stagingDir = null;
        var downloadUrl = BaseUrl + _latestFileName;

        try
        {
            if (bundledPackagePath != null)
            {
                await using var source = new FileStream(bundledPackagePath, FileMode.Open, FileAccess.Read, FileShare.Read);
                await using var destination = new FileStream(tempZip, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                await source.CopyToAsync(destination);
                _progressBar.Value = 100;
                _progressPercentLabel.Text = "100%";
            }
            else
            {
                using var http = new HttpClient();
                using var response = await http.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var totalBytes = response.Content.Headers.ContentLength ?? _latestSize;
                await using var httpStream = await response.Content.ReadAsStreamAsync();
                await using var fileStream = new FileStream(tempZip, FileMode.Create, FileAccess.Write, FileShare.None);

                var buffer = new byte[81920];
                long readTotal = 0;
                int read;
                while ((read = await httpStream.ReadAsync(buffer)) > 0)
                {
                    await fileStream.WriteAsync(buffer.AsMemory(0, read));
                    readTotal += read;
                    if (totalBytes > 0)
                    {
                        var pct = (int)(readTotal * 100 / totalBytes);
                        pct = Math.Clamp(pct, 0, 100);
                        _progressBar.Value = pct;
                        _progressPercentLabel.Text = $"{pct}%";
                    }
                }
            }

            var downloadedSize = new FileInfo(tempZip).Length;
            if (_latestSize > 0 && downloadedSize != _latestSize)
            {
                throw new InvalidDataException($"Downloaded size mismatch: expected {_latestSize:N0} bytes, received {downloadedSize:N0}.");
            }

            string downloadedSha256;
            await using (var packageStream = File.OpenRead(tempZip))
            {
                downloadedSha256 = Convert.ToHexString(await SHA256.HashDataAsync(packageStream));
            }
            if (!downloadedSha256.Equals(_latestSha256, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Downloaded package failed SHA-256 verification.");
            }

            AppendLog("Package size and SHA-256 verified.", PositiveColor);

            AppendLog(_repairMode ? "Download complete. Staging repair..." : "Download complete. Staging update...", MutedTextColor);
            SetStatus(_repairMode ? "Repairing..." : "Installing...", InfoColor);
            _progressBar.Value = 100;
            _progressPercentLabel.Text = "100%";

            var installDir = Path.GetFullPath(_config.InstallDir!);
            var installParent = Directory.GetParent(installDir)?.FullName
                ?? throw new InvalidOperationException("The selected install directory has no parent directory.");
            stagingDir = Path.Combine(installParent, $".{Path.GetFileName(installDir)}.update-{Guid.NewGuid():N}");
            Directory.CreateDirectory(stagingDir);

            ExtractPackageSafely(tempZip, stagingDir);
            if (!IsInstallValid(stagingDir))
            {
                throw new InvalidDataException("The staged package is missing init.lua or otclient.exe.");
            }

            PreserveUserData(installDir, stagingDir);
            ReplaceInstallAtomically(installDir, stagingDir);
            stagingDir = null;

            _config.InstalledVersion = _latestVersion;
            _config.Save(ConfigPath);

            CreateShortcuts();

            _repairMode = false;
            _versionLabel.Text = "Installed version: " + _latestVersion;
            SetStatus($"Up to date ({_latestVersion}).", PositiveColor);
            AppendLog($"Installed version {_latestVersion} successfully.", PositiveColor);
            _updateButton.Visible = false;
            SetPlayEnabled(true);
        }
        catch (Exception ex)
        {
            SetStatus(_repairMode ? "Repair failed." : "Update failed.", NegativeColor);
            AppendLog((_repairMode ? "Repair failed: " : "Update failed: ") + ex.Message, NegativeColor);
            _updateButton.Enabled = true;
            _retryAction = () => DownloadAndInstallUpdateAsync();
            _retryButton.Visible = true;
        }
        finally
        {
            _progressBar.Visible = false;
            _progressPercentLabel.Visible = false;
            if (File.Exists(tempZip))
            {
                File.Delete(tempZip);
            }
            if (stagingDir != null && Directory.Exists(stagingDir))
            {
                Directory.Delete(stagingDir, recursive: true);
            }
            _isBusy = false;
        }
    }

    internal static ReleaseManifest ParseManifest(JsonElement root)
    {
        if (!root.TryGetProperty("version", out var versionProperty) ||
            !root.TryGetProperty("file", out var fileProperty) ||
            !root.TryGetProperty("size", out var sizeProperty) ||
            !root.TryGetProperty("sha256", out var sha256Property) ||
            versionProperty.ValueKind != JsonValueKind.String ||
            fileProperty.ValueKind != JsonValueKind.String ||
            sha256Property.ValueKind != JsonValueKind.String ||
            !sizeProperty.TryGetInt64(out var size))
        {
            throw new InvalidDataException("Update manifest is missing required fields or contains invalid field types.");
        }

        var version = versionProperty.GetString();
        var fileName = fileProperty.GetString();
        var sha256 = sha256Property.GetString();

        if (string.IsNullOrWhiteSpace(version))
        {
            throw new InvalidDataException("Update manifest has no version.");
        }
        if (string.IsNullOrWhiteSpace(fileName) ||
            fileName != Path.GetFileName(fileName) ||
            !fileName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Update manifest contains an invalid package filename.");
        }
        if (size <= 0)
        {
            throw new InvalidDataException("Update manifest contains an invalid package size.");
        }
        if (string.IsNullOrWhiteSpace(sha256) || sha256.Length != 64 || !sha256.All(Uri.IsHexDigit))
        {
            throw new InvalidDataException("Update manifest contains an invalid SHA-256 value.");
        }

        return new ReleaseManifest(version, fileName, size, sha256.ToUpperInvariant());
    }

    internal static void ExtractPackageSafely(string zipPath, string destination)
    {
        var root = Path.GetFullPath(destination) + Path.DirectorySeparatorChar;
        using var archive = ZipFile.OpenRead(zipPath);
        foreach (var entry in archive.Entries)
        {
            var normalizedName = entry.FullName.Replace('/', Path.DirectorySeparatorChar);
            var destinationPath = Path.GetFullPath(Path.Combine(destination, normalizedName));
            if (!destinationPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException($"Package entry escapes the install directory: {entry.FullName}");
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(destinationPath);
                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
            entry.ExtractToFile(destinationPath, overwrite: true);
        }
    }

    internal static void PreserveUserData(string sourceRoot, string destinationRoot)
    {
        if (!Directory.Exists(sourceRoot))
        {
            return;
        }

        foreach (var relativePath in PreservedUserFiles)
        {
            CopyPreservedFile(sourceRoot, destinationRoot, relativePath);
        }

        foreach (var pattern in PreservedRootPatterns)
        {
            foreach (var sourceFile in Directory.GetFiles(sourceRoot, pattern, SearchOption.TopDirectoryOnly))
            {
                CopyPreservedFile(sourceRoot, destinationRoot, Path.GetFileName(sourceFile));
            }
        }

        foreach (var relativePath in PreservedUserDirectories)
        {
            var sourceDir = Path.Combine(sourceRoot, relativePath);
            if (!Directory.Exists(sourceDir))
            {
                continue;
            }

            foreach (var sourceFile in Directory.GetFiles(sourceDir, "*", SearchOption.AllDirectories))
            {
                var childPath = Path.GetRelativePath(sourceRoot, sourceFile);
                CopyPreservedFile(sourceRoot, destinationRoot, childPath);
            }
        }
    }

    private static void CopyPreservedFile(string sourceRoot, string destinationRoot, string relativePath)
    {
        var sourcePath = Path.Combine(sourceRoot, relativePath);
        if (!File.Exists(sourcePath))
        {
            return;
        }

        var destinationPath = Path.Combine(destinationRoot, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
        File.Copy(sourcePath, destinationPath, overwrite: true);
    }

    internal static void ReplaceInstallAtomically(string installDir, string stagingDir)
    {
        var backupDir = installDir + $".previous-{Guid.NewGuid():N}";
        var hadExistingInstall = Directory.Exists(installDir);

        try
        {
            if (hadExistingInstall)
            {
                Directory.Move(installDir, backupDir);
            }
            Directory.Move(stagingDir, installDir);
        }
        catch
        {
            if (!Directory.Exists(installDir) && Directory.Exists(backupDir))
            {
                Directory.Move(backupDir, installDir);
            }
            throw;
        }

        // The new install is already live. A locked file in the old tree must
        // not turn a successful update into a false failure; the leftover is
        // uniquely named and can be removed by a later maintenance pass.
        try
        {
            if (Directory.Exists(backupDir))
            {
                Directory.Delete(backupDir, recursive: true);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }

    private void CreateShortcuts()
    {
        try
        {
            var exePath = Environment.ProcessPath;
            if (exePath == null)
            {
                return;
            }

            var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            var startMenu = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);

            CreateShortcut(Path.Combine(desktop, ShortcutName), exePath);
            CreateShortcut(Path.Combine(startMenu, ShortcutName), exePath);
        }
        catch (Exception ex)
        {
            // Shortcut creation is a convenience, not a requirement.
            AppendLog("Could not create shortcuts: " + ex.Message, InfoColor);
        }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath)
    {
        if (File.Exists(shortcutPath))
        {
            return;
        }

        var shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null)
        {
            return;
        }

        dynamic shell = Activator.CreateInstance(shellType)!;
        var shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = targetPath;
        shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
        shortcut.Save();
    }

    private void LaunchClient()
    {
        if (_config.InstallDir == null)
        {
            return;
        }

        if (!IsInstallValid(_config.InstallDir))
        {
            EnterRepairMode("Installation is missing required files - use Repair.");
            return;
        }

        var exe = Path.Combine(_config.InstallDir, "otclient.exe");

        AppendLog("Launching client...", MutedTextColor);
        _clientProcess = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = exe,
            WorkingDirectory = _config.InstallDir,
            UseShellExecute = false,
            CreateNoWindow = true
        });

        if (_clientProcess != null)
        {
            _clientProcess.EnableRaisingEvents = true;
            _clientProcess.Exited += (_, _) =>
            {
                if (IsDisposed)
                {
                    return;
                }

                // Process.Exited fires on a threadpool thread - hop back onto the
                // UI thread before touching any control or awaiting HTTP calls.
                BeginInvoke(new Action(() =>
                {
                    _clientProcess = null;
                    if (_updatePendingAfterClientExit)
                    {
                        _updatePendingAfterClientExit = false;
                        AppendLog("Game closed - installing the update that was waiting.", MutedTextColor);
                        _ = CheckForUpdatesAsync();
                    }
                }));
            };
        }
    }
}

internal sealed record ReleaseManifest(string Version, string FileName, long Size, string Sha256);

internal class LauncherConfig
{
    public string? InstallDir { get; set; }
    public string? InstalledVersion { get; set; }

    public static LauncherConfig Load(string path)
    {
        if (!File.Exists(path))
        {
            return new LauncherConfig();
        }

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<LauncherConfig>(json) ?? new LauncherConfig();
        }
        catch
        {
            return new LauncherConfig();
        }
    }

    public void Save(string path)
    {
        var dir = Path.GetDirectoryName(path);
        if (dir != null)
        {
            Directory.CreateDirectory(dir);
        }

        File.WriteAllText(path, JsonSerializer.Serialize(this));
    }
}
