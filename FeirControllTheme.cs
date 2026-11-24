
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("Feir Controll")]
[assembly: AssemblyDescription("Mapeador de controles USB para Windows")]
[assembly: AssemblyProduct("Feir Controll")]

namespace Feir
{



    internal static class FeirTypography
    {
        internal static void Draw(Graphics graphics, string text, Font font, Color color, Rectangle bounds,
            StringAlignment alignment = StringAlignment.Near)
        {
            if (String.IsNullOrEmpty(text) || bounds.Width <= 0 || bounds.Height <= 0) return;
            var previous = graphics.TextRenderingHint;
            graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            using (var brush = new SolidBrush(color))
            using (var layout = new StringFormat(StringFormat.GenericDefault))
            {
                layout.Alignment = alignment;
                layout.LineAlignment = StringAlignment.Center;
                layout.Trimming = StringTrimming.EllipsisCharacter;
                layout.FormatFlags = StringFormatFlags.NoWrap;
                graphics.DrawString(text, font, brush, bounds, layout);
            }
            graphics.TextRenderingHint = previous;
        }
    }

    public sealed class FeirLabel : Label
    {
        public FeirLabel() { DoubleBuffered = true; }
        protected override void OnPaint(PaintEventArgs e)
        {
            FeirTypography.Draw(e.Graphics, Text, Font, ForeColor, ClientRectangle);
        }
    }

    public static class DeviceOrigin
    {
        [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
        private static extern int CM_Locate_DevNodeW(out uint node, string id, uint flags);
        [DllImport("cfgmgr32.dll")]
        private static extern int CM_Get_Parent(out uint parent, uint node, uint flags);
        [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
        private static extern int CM_Get_DevNode_Registry_PropertyW(uint node, uint property,
            out uint type, byte[] buffer, ref uint length, uint flags);

        public static bool IsUsbIp(string path)
        {
            if (String.IsNullOrEmpty(path)) return false;
            var parts = path.Split('#');
            if (parts.Length < 3) return false;
            if (parts[0].StartsWith(@"\\?\", StringComparison.Ordinal)) parts[0] = parts[0].Substring(4);
            var id = String.Join("\\", parts, 0, 3);
            uint node;
            if (CM_Locate_DevNodeW(out node, id, 0) != 0) return false;
            const uint ServiceProperty = 5;
            var buffer = new byte[512];
            for (int depth = 0; depth < 8; depth++)
            {
                uint type;
                uint length = (uint)buffer.Length;
                if (CM_Get_DevNode_Registry_PropertyW(node, ServiceProperty, out type, buffer, ref length, 0) == 0 &&
                    String.Equals(System.Text.Encoding.Unicode.GetString(buffer, 0, (int)length).TrimEnd('\0'),
                        "usbip2_ude", StringComparison.OrdinalIgnoreCase)) return true;
                uint parent;
                if (CM_Get_Parent(out parent, node, 0) != 0) break;
                node = parent;
            }
            return false;
        }
    }

    public sealed class SignalForm : Form
    {
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);

        protected override void OnHandleCreated(EventArgs args)
        {
            base.OnHandleCreated(args);
            if (!SystemInformation.HighContrast)
            {
                int on = 1;
                DwmSetWindowAttribute(Handle, 20, ref on, sizeof(int));
            }
        }
    }

    public sealed class SignalBanner : Panel
    {
        public SignalBanner() { DoubleBuffered = true; ResizeRedraw = true; }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var bounds = ClientRectangle;
            if (bounds.Width < 2 || bounds.Height < 2) return;
            var g = e.Graphics;
            g.Clear(Parent.BackColor);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            using (var outline = RoundedPaint.Shape(bounds, 17 * g.DpiX / 96))
            using (var fill = new LinearGradientBrush(bounds, Color.FromArgb(12, 25, 20),
                         Color.FromArgb(13, 48, 32), LinearGradientMode.Horizontal))
            {
                g.FillPath(fill, outline);
                var saved = g.Save();
                g.SetClip(outline);
                DrawData(g, bounds);
                g.Restore(saved);
            }
        }

        private static void DrawData(Graphics g, Rectangle bounds)
        {
            var random = new Random(4821);
            const string alphabet = "010101.:/+=<>XZV";
            using (var type = new Font("Consolas", 10, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var faint = new SolidBrush(Color.FromArgb(34, 90, 255, 157)))
            using (var mid = new SolidBrush(Color.FromArgb(64, 90, 255, 157)))
            using (var bright = new SolidBrush(Color.FromArgb(143, 119, 255, 180)))
            using (var trace = new Pen(Color.FromArgb(84, 83, 222, 143), 1))
            {
                for (int x = bounds.Width / 2; x < bounds.Width - 18; x += 15)
                {
                    int end = random.Next(23, bounds.Height + 24);
                    for (int y = end - 75; y <= end; y += 12)
                    {
                        if (random.Next(5) == 0) continue;
                        var ink = y == end && x > bounds.Width * .62 ? bright : y > end - 24 ? mid : faint;
                        g.DrawString(alphabet[random.Next(alphabet.Length)].ToString(), type, ink, x, y);
                    }
                }
                int right = bounds.Width - 28;
                g.DrawLines(trace, new[] { new Point(right - 214, 67), new Point(right - 62, 67),
                    new Point(right - 48, 53), new Point(right, 53) });
                g.DrawLines(trace, new[] { new Point(right - 106, 18), new Point(right - 21, 18),
                    new Point(right - 12, 27), new Point(right, 27) });
            }
        }
    }

    public sealed class SignalList : ListView
    {
        public SignalList() { DoubleBuffered = true; OwnerDraw = true; }

        protected override void OnDrawSubItem(DrawListViewSubItemEventArgs e)
        {
            if (e.Item == null || e.SubItem == null) return;
            var pressed = e.Item.SubItems.Count > 2 && e.Item.SubItems[2].Text != "—";
            var background = pressed ? e.Item.BackColor :
                e.Item.Selected ? Color.FromArgb(33, 68, 50) : e.Item.BackColor;
            var foreground = pressed ? Color.FromArgb(170, 255, 208) : ForeColor;
            using (var brush = new SolidBrush(background)) e.Graphics.FillRectangle(brush, e.Bounds);
            var text = e.Bounds;
            text.X += 5;
            text.Width -= 8;
            if (e.ColumnIndex == 0 && SmallImageList != null && e.Item.ImageIndex >= 0)
            {
                int top = e.Bounds.Top + (e.Bounds.Height - SmallImageList.ImageSize.Height) / 2;
                SmallImageList.Draw(e.Graphics, text.X, top, e.Item.ImageIndex);
                text.X += SmallImageList.ImageSize.Width + 2;
                text.Width -= SmallImageList.ImageSize.Width + 2;
            }
            FeirTypography.Draw(e.Graphics, e.SubItem.Text, Font, foreground, text);
        }
    }


    public sealed class SignalCombo : Button
    {
        private readonly ToolStripDropDown menu = new ToolStripDropDown();
        private int selectedIndex = -1;

        public SignalCombo()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            Cursor = Cursors.Hand;
            Items = new System.Collections.ArrayList();
            AccessibleRole = AccessibleRole.ComboBox;
            menu.Padding = new Padding(4);
            menu.Renderer = new MenuRenderer();
            menu.BackColor = Color.FromArgb(19, 31, 25);
        }

        public System.Collections.ArrayList Items { get; private set; }
        public object SelectedItem
        {
            get { return selectedIndex >= 0 && selectedIndex < Items.Count ? Items[selectedIndex] : null; }
        }
        public int SelectedIndex
        {
            get { return selectedIndex; }
            set
            {
                if (value < -1 || value >= Items.Count) throw new ArgumentOutOfRangeException("value");
                if (selectedIndex == value) return;
                selectedIndex = value;
                Invalidate();
            }
        }
        public event EventHandler SelectionChangeCommitted;

        public void RefreshOptions()
        {
            if (selectedIndex >= Items.Count) selectedIndex = -1;
            Invalidate();
        }

        private void Commit(int index)
        {
            if (index < 0 || index >= Items.Count || index == selectedIndex) return;
            SelectedIndex = index;
            var handler = SelectionChangeCommitted;
            if (handler != null) handler(this, EventArgs.Empty);
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            if (menu.Visible || Items.Count == 0) return;
            while (menu.Items.Count > 0) menu.Items[0].Dispose();
            for (int i = 0; i < Items.Count; i++)
            {
                int index = i;
                var entry = new ToolStripMenuItem(Convert.ToString(Items[i]));
                entry.ForeColor = ForeColor;
                entry.AutoSize = false;
                entry.Width = Math.Max(125, Width - 8);
                entry.Height = Math.Max(24, Font.Height + 11);
                entry.Checked = i == SelectedIndex;
                entry.Click += (sender, args) => Commit(index);
                menu.Items.Add(entry);
            }
            menu.Show(this, new Point(0, Height + 3));
            if (selectedIndex >= 0) menu.Items[selectedIndex].Select();
        }

        protected override bool IsInputKey(Keys keyData)
        {
            var key = keyData & Keys.KeyCode;
            return key == Keys.Down || key == Keys.Up || key == Keys.F4 || base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.F4 || (e.Alt && e.KeyCode == Keys.Down))
                OnClick(EventArgs.Empty);
            else if (e.KeyCode == Keys.Up || e.KeyCode == Keys.Down)
                Commit(Math.Max(0, Math.Min(Items.Count - 1, selectedIndex + (e.KeyCode == Keys.Down ? 1 : -1))));
            else
            {
                base.OnKeyDown(e);
                return;
            }
            e.Handled = true;
            e.SuppressKeyPress = true;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var bounds = ClientRectangle;
            if (bounds.Width <= 2 || bounds.Height <= 2) return;
            using (var parent = new SolidBrush(Parent.BackColor)) e.Graphics.FillRectangle(parent, bounds);
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var outline = new Rectangle(0, 0, bounds.Width - 1, bounds.Height - 1);
            using (var path = RoundedPaint.Shape(outline, 8 * e.Graphics.DpiX / 96))
            using (var fill = new SolidBrush(BackColor))
            using (var edge = new Pen(Focused ? Color.FromArgb(117, 224, 165) : Color.FromArgb(58, 91, 75)))
            using (var arrow = new Pen(Color.FromArgb(162, 232, 190), 1.4f))
            {
                e.Graphics.FillPath(fill, path);
                e.Graphics.DrawPath(edge, path);
                int x = bounds.Right - 15;
                int y = bounds.Height / 2;
                e.Graphics.DrawLines(arrow, new[] { new Point(x - 4, y - 2), new Point(x, y + 2), new Point(x + 4, y - 2) });
                var text = new Rectangle(10, 0, bounds.Width - 36, bounds.Height);
                FeirTypography.Draw(e.Graphics, Convert.ToString(SelectedItem), Font, ForeColor, text);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) menu.Dispose();
            base.Dispose(disposing);
        }

        private sealed class MenuRenderer : ToolStripProfessionalRenderer
        {
            public MenuRenderer() : base(new Colors()) { RoundedEdges = true; }
            private sealed class Colors : ProfessionalColorTable
            {
                public override Color ToolStripDropDownBackground { get { return Color.FromArgb(19, 31, 25); } }
                public override Color MenuBorder { get { return Color.FromArgb(58, 91, 75); } }
                public override Color MenuItemBorder { get { return Color.FromArgb(58, 91, 75); } }
                public override Color MenuItemSelected { get { return Color.FromArgb(31, 68, 48); } }
                public override Color ImageMarginGradientBegin { get { return ToolStripDropDownBackground; } }
                public override Color ImageMarginGradientMiddle { get { return ToolStripDropDownBackground; } }
                public override Color ImageMarginGradientEnd { get { return ToolStripDropDownBackground; } }
                public override Color CheckBackground { get { return MenuItemSelected; } }
                public override Color CheckSelectedBackground { get { return MenuItemSelected; } }
            }
        }
    }
}



