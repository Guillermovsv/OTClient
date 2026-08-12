using System.IO.Compression;
using System.Text.Json;

namespace OtLauncher;

internal static class LauncherSelfTest
{
    public static int Run(string? outputPath)
    {
        var results = new Dictionary<string, bool>();
        string? error = null;
        var testRoot = Path.Combine(Path.GetTempPath(), $"otlauncher-selftest-{Guid.NewGuid():N}");

        try
        {
            Directory.CreateDirectory(testRoot);

            using (var manifest = JsonDocument.Parse(
                       """{"version":"2026.08.11.01","file":"client-windows.zip","size":123,"sha256":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"""))
            {
                var parsed = MainForm.ParseManifest(manifest.RootElement);
                results["manifestAccepted"] = parsed.Version == "2026.08.11.01";
            }

            results["unsafeLegacyFolderRejected"] =
                !MainForm.IsSafeDedicatedInstallDirectory(
                    Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)) &&
                MainForm.IsSafeDedicatedInstallDirectory(MainForm.GetDefaultInstallDirectory());

            try
            {
                using var badManifest = JsonDocument.Parse(
                    """{"version":"bad","file":"client-windows.zip","size":1}""");
                MainForm.ParseManifest(badManifest.RootElement);
                results["missingHashRejected"] = false;
            }
            catch (InvalidDataException)
            {
                results["missingHashRejected"] = true;
            }

            var safeZip = Path.Combine(testRoot, "safe.zip");
            using (var archive = ZipFile.Open(safeZip, ZipArchiveMode.Create))
            {
                AddTextEntry(archive, "init.lua", "-- updater self-test");
                AddTextEntry(archive, "otclient.exe", "test executable");
                AddTextEntry(archive, "new-program.dll", "new program file");
            }

            var staging = Path.Combine(testRoot, "staging");
            Directory.CreateDirectory(staging);
            MainForm.ExtractPackageSafely(safeZip, staging);
            results["stagedInstallValid"] = MainForm.IsInstallValid(staging);

            var traversalZip = Path.Combine(testRoot, "traversal.zip");
            using (var archive = ZipFile.Open(traversalZip, ZipArchiveMode.Create))
            {
                AddTextEntry(archive, "../escape.txt", "must not escape");
            }

            var traversalDestination = Path.Combine(testRoot, "traversal-destination");
            Directory.CreateDirectory(traversalDestination);
            try
            {
                MainForm.ExtractPackageSafely(traversalZip, traversalDestination);
                results["traversalRejected"] = false;
            }
            catch (InvalidDataException)
            {
                results["traversalRejected"] = !File.Exists(Path.Combine(testRoot, "escape.txt"));
            }

            var install = Path.Combine(testRoot, "Client");
            Directory.CreateDirectory(Path.Combine(install, "controls"));
            File.WriteAllText(Path.Combine(install, "config.ini"), "user config");
            File.WriteAllText(Path.Combine(install, "controls", "hotkeys.otml"), "user hotkeys");
            File.WriteAllText(Path.Combine(install, "obsolete.dll"), "obsolete program file");

            MainForm.PreserveUserData(install, staging);
            results["userStatePreserved"] =
                File.ReadAllText(Path.Combine(staging, "config.ini")) == "user config" &&
                File.Exists(Path.Combine(staging, "controls", "hotkeys.otml")) &&
                !File.Exists(Path.Combine(staging, "obsolete.dll"));

            MainForm.ReplaceInstallAtomically(install, staging);
            results["atomicActivation"] =
                File.Exists(Path.Combine(install, "new-program.dll")) &&
                File.Exists(Path.Combine(install, "controls", "hotkeys.otml")) &&
                !File.Exists(Path.Combine(install, "obsolete.dll"));
        }
        catch (Exception ex)
        {
            results["unhandledException"] = false;
            error = ex.ToString();
        }
        finally
        {
            try
            {
                if (Directory.Exists(testRoot))
                {
                    Directory.Delete(testRoot, recursive: true);
                }
            }
            catch
            {
                results["cleanup"] = false;
            }
        }

        var passed = results.Count > 0 && results.Values.All(value => value);
        if (!string.IsNullOrWhiteSpace(outputPath))
        {
            var parent = Path.GetDirectoryName(Path.GetFullPath(outputPath));
            if (parent != null)
            {
                Directory.CreateDirectory(parent);
            }
            File.WriteAllText(outputPath, JsonSerializer.Serialize(new { passed, results, error }, new JsonSerializerOptions
            {
                WriteIndented = true
            }));
        }

        return passed ? 0 : 1;
    }

    private static void AddTextEntry(ZipArchive archive, string name, string content)
    {
        var entry = archive.CreateEntry(name);
        using var writer = new StreamWriter(entry.Open());
        writer.Write(content);
    }
}
