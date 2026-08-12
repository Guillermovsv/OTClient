namespace OtLauncher;

internal static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        var selfTestArg = args.FirstOrDefault(arg =>
            arg.StartsWith("--self-test", StringComparison.OrdinalIgnoreCase));
        if (selfTestArg != null)
        {
            var outputPath = selfTestArg.StartsWith("--self-test-output=", StringComparison.OrdinalIgnoreCase)
                ? selfTestArg[(selfTestArg.IndexOf('=') + 1)..]
                : null;
            Environment.ExitCode = LauncherSelfTest.Run(outputPath);
            return;
        }

        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}
