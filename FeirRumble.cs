
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32.SafeHandles;
using Nefarius.ViGEm.Client.Targets;
using Nefarius.ViGEm.Client.Targets.DualShock4;

namespace Feir
{
    public sealed class Rumble : IDisposable
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFile(string path, uint access, uint share, IntPtr sa, uint mode, uint flags, IntPtr template);
        [DllImport("hid.dll")]
        [return: MarshalAs(UnmanagedType.U1)]
        private static extern bool HidD_GetPreparsedData(SafeFileHandle handle, out IntPtr data);
        [DllImport("hid.dll")]
        [return: MarshalAs(UnmanagedType.U1)]
        private static extern bool HidD_FreePreparsedData(IntPtr data);
        [DllImport("hid.dll")]
        private static extern int HidP_GetValueCaps(int kind, IntPtr caps, ref ushort count, IntPtr data);
        [DllImport("hid.dll")]
        [return: MarshalAs(UnmanagedType.U1)]
        private static extern bool HidD_SetOutputReport(SafeFileHandle handle, byte[] report, int length);

        private readonly SafeFileHandle handle;
        private readonly DualShock4Controller target;
        private readonly byte[] report = { 1, 0, 0, 0, 0 };
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private long gameFeedback;
        private long testUntil;
        private long gamePulseUntil;
        private int gamePulseMotors;
        private int lastSent = -1;
        private int receivedEffects;
        public int ReceivedEffects { get { return Volatile.Read(ref receivedEffects); } }
        public int LastSent { get { return lastSent; } }

        private Rumble(SafeFileHandle handle, DualShock4Controller target)
        {
            this.handle = handle;
            this.target = target;
            if (target != null) target.FeedbackReceived += Receive;
        }

        public static Rumble Open(string interfacePath, DualShock4Controller target)
        {
            if (String.IsNullOrEmpty(interfacePath) ||
                interfacePath.IndexOf("vid_0810&pid_0001", StringComparison.OrdinalIgnoreCase) < 0)
                return null;
            var handle = CreateFile(interfacePath, 0x40000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            if (handle.IsInvalid || !HasSupportedReport(handle))
            {
                handle.Dispose();
                return null;
            }
            return new Rumble(handle, target);
        }

        private static bool HasSupportedReport(SafeFileHandle handle)
        {
            IntPtr data;
            if (!HidD_GetPreparsedData(handle, out data)) return false;
            var caps = Marshal.AllocHGlobal(72 * 16);
            try
            {
                ushort count = 16;
                return HidP_GetValueCaps(1, caps, ref count, data) == 0x110000 && count == 1
                    && (ushort)Marshal.ReadInt16(caps) == 0xFF00
                    && Marshal.ReadByte(caps, 2) == 1
                    && Marshal.ReadInt16(caps, 18) == 8
                    && Marshal.ReadInt16(caps, 20) == 4
                    && Marshal.ReadInt16(caps, 56) == 2;
            }
            finally
            {
                Marshal.FreeHGlobal(caps);
                HidD_FreePreparsedData(data);
            }
        }

        private void Receive(object sender, DualShock4FeedbackReceivedEventArgs feedback)
        {
            ReceiveMotors(feedback.LargeMotor, feedback.SmallMotor);
        }

        public void ReceiveMotors(byte large, byte small)
        {
            int motors = large | (small << 8);
            Interlocked.Exchange(ref gameFeedback, (clock.ElapsedMilliseconds << 16) | (uint)motors);
            if (motors != 0) Interlocked.Increment(ref receivedEffects);
        }

        public void Test()
        {
            testUntil = clock.ElapsedMilliseconds + 700;
        }

        public bool Update(bool enabled, int gain)
        {
            long now = clock.ElapsedMilliseconds;
            long feedback = Interlocked.Read(ref gameFeedback);
            int motors = 0;
            int rawMotors = (int)feedback & 65535;
            if (!enabled)
            {
                gamePulseUntil = 0;
            }
            else if (rawMotors != 0 && now - (feedback >> 16) < 5000)
            {
                motors = Scale(rawMotors & 255, gain) | (Scale(rawMotors >> 8, gain) << 8);
                if (gamePulseMotors != motors || now >= gamePulseUntil)
                {
                    gamePulseMotors = motors;
                    // Hold brief game pulses long enough for the physical motors to spin up.
                    gamePulseUntil = (feedback >> 16) + 130;
                }
            }
            else if (now < gamePulseUntil)
            {
                motors = gamePulseMotors;
            }
            if (now < testUntil) motors = 100 | (100 << 8);

            if (motors == lastSent) return true;
            report[3] = (byte)(motors & 255);
            report[4] = (byte)(motors >> 8);
            if (!HidD_SetOutputReport(handle, report, report.Length)) return false;
            lastSent = motors;
            return true;
        }

        private static int Scale(int value, int gain) { return Math.Min(127, (value * 127 * gain + 12750) / 25500); }

        public void Dispose()
        {
            if (target != null) target.FeedbackReceived -= Receive;
            if (!handle.IsClosed)
            {
                report[3] = report[4] = 0;
                HidD_SetOutputReport(handle, report, report.Length);
                handle.Dispose();
            }
        }
    }
}




