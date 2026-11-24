
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class FeirSetup
{
    [STAThread]
    private static int Main(string[] args)
    {
        bool test = args.Length == 2 && args[0] == "--test";
        string temporary = Path.Combine(Path.GetTempPath(), "FeirSetup-" + Guid.NewGuid());
        try
        {
            Directory.CreateDirectory(temporary);
            string payload = Path.Combine(temporary, "payload.zip");
            var assembly = typeof(FeirSetup).Assembly;
            using (var source = assembly.GetManifestResourceStream("Feir.Payload"))
            using (var file = File.Create(payload))
                source.CopyTo(file);

            using (var source = assembly.GetManifestResourceStream("Feir.Install"))
            using (var reader = new StreamReader(source))
            using (var runspace = RunspaceFactory.CreateRunspace())
            using (var shell = PowerShell.Create())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                shell.Runspace = runspace;
                shell.AddScript(reader.ReadToEnd()).AddArgument(payload);
                if (test) shell.AddParameter("TestDestination", args[1]);
                shell.Invoke();
                if (shell.HadErrors)
                    throw new InvalidOperationException(shell.Streams.Error[0].ToString());
            }
            if (!test)
                MessageBox.Show("Instalação concluída. Abra Feir Controll pelo menu Iniciar.",
                                "Feir Controll", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }
        catch (Exception error)
        {
            if (test) Console.Error.WriteLine(error);
            else MessageBox.Show(error.Message, "Feir Controll", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            if (Directory.Exists(temporary)) Directory.Delete(temporary, true);
        }
    }
}


