
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

namespace Feir
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            string directory = AppDomain.CurrentDomain.BaseDirectory;
            Environment.SetEnvironmentVariable("FEIR_BRIDGE_DIR", directory);
            Environment.SetEnvironmentVariable("FEIR_START_IN_TRAY",
                args.Contains("--background", StringComparer.OrdinalIgnoreCase) ? "1" : "0");

            try
            {
                using (var runspace = RunspaceFactory.CreateRunspace())
                using (var shell = PowerShell.Create())
                {
                    runspace.ApartmentState = ApartmentState.STA;
                    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    runspace.Open();
                    shell.Runspace = runspace;
                    shell.AddScript(File.ReadAllText(Path.Combine(directory, "Feir-DualShock4.ps1")));
                    shell.Invoke();
                    if (shell.HadErrors && shell.Streams.Error.Count > 0)
                        throw new InvalidOperationException(shell.Streams.Error[0].ToString());
                }
            }
            catch (Exception error)
            {
                MessageBox.Show(error.Message, "Feir Controll", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    internal static class RoundedPaint
    {
        internal static GraphicsPath Shape(Rectangle bounds, float radius)
        {
            var path = new GraphicsPath();
            float diameter = Math.Min(radius * 2, Math.Min(bounds.Width, bounds.Height));
            float right = bounds.Right - diameter;
            float bottom = bounds.Bottom - diameter;
            path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
            path.AddArc(right, bounds.Top, diameter, diameter, 270, 90);
            path.AddArc(right, bottom, diameter, diameter, 0, 90);
            path.AddArc(bounds.Left, bottom, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }

        internal static void Fill(Control control, Graphics graphics, Color fill, int radius)
        {
            if (control.Width <= 1 || control.Height <= 1) return;
            graphics.Clear(control.Parent == null ? SystemColors.Control : control.Parent.BackColor);
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            using (var shape = Shape(new Rectangle(0, 0, control.Width, control.Height), radius * graphics.DpiX / 96f))
            using (var brush = new SolidBrush(fill))
                graphics.FillPath(brush, shape);
        }
    }

    public sealed class RoundedPanel : Panel
    {
        public RoundedPanel() { DoubleBuffered = true; }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            RoundedPaint.Fill(this, e.Graphics, BackColor, 18);
        }
    }

    public sealed class RoundedButton : Button
    {
        private bool hovered;
        private bool pressed;

        public RoundedButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hovered = true; Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hovered = false; Invalidate(); }
        protected override void OnMouseDown(MouseEventArgs e) { base.OnMouseDown(e); pressed = e.Button == MouseButtons.Left; Invalidate(); }
        protected override void OnMouseUp(MouseEventArgs e) { base.OnMouseUp(e); pressed = false; Invalidate(); }
        protected override void OnMouseCaptureChanged(EventArgs e) { base.OnMouseCaptureChanged(e); pressed = false; Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Color fill = pressed && hovered ? FlatAppearance.MouseDownBackColor :
                         hovered ? FlatAppearance.MouseOverBackColor : BackColor;
            RoundedPaint.Fill(this, e.Graphics, fill, 11);
            FeirTypography.Draw(e.Graphics, Text, Font, ForeColor, ClientRectangle, System.Drawing.StringAlignment.Center);
            if (Focused && ShowFocusCues)
            {
                var focus = Rectangle.Inflate(ClientRectangle, -5, -5);
                ControlPaint.DrawFocusRectangle(e.Graphics, focus, ForeColor, fill);
            }
        }
    }
}




