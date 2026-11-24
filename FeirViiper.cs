
using System;
using System.Runtime.InteropServices;
using Nefarius.ViGEm.Client.Targets.DualShock4;

namespace Feir
{
    public sealed class ViiperServer : IDisposable
    {
        private const string Library = "libVIIPER.dll";
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        private struct ServerConfig
        {
            [MarshalAs(UnmanagedType.LPStr)] public string Address;
            public ulong ConnectionTimeout;
            public ulong DeviceTimeout;
            public uint FlushInterval;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct DeviceState
        {
            public sbyte LX, LY, RX, RY;
            public ushort Buttons;
            public byte DPad, L2, R2;
            public ushort Touch1X, Touch1Y;
            public byte Touch1Active;
            public ushort Touch2X, Touch2Y;
            public byte Touch2Active;
            public short GyroX, GyroY, GyroZ, AccelX, AccelY, AccelZ;
        }
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void Feedback(IntPtr device, byte flags, byte small, byte large,
                                       byte red, byte green, byte blue, byte flashOn, byte flashOff);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool NewUSBServer(ref ServerConfig config, out IntPtr server, IntPtr log);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool CloseUSBServer(IntPtr server);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool CreateUSBBus(IntPtr server, ref uint bus);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool CreateDS4Device(IntPtr server, out IntPtr device, uint bus,
            [MarshalAs(UnmanagedType.I1)] bool autoAttach, ushort vendor, ushort product, IntPtr meta);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool SetDS4DeviceState(IntPtr device, DeviceState state);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool SetDS4OutputCallback(IntPtr device, Feedback callback);
        [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        private static extern bool RemoveDS4Device(IntPtr device);

        private IntPtr server;
        private uint bus;

        public ViiperServer()
        {
            var config = new ServerConfig { Address = "127.0.0.1:3241" };
            if (!NewUSBServer(ref config, out server, IntPtr.Zero))
                throw new InvalidOperationException("Não foi possível iniciar o VIIPER local.");
            if (!CreateUSBBus(server, ref bus))
            {
                Dispose();
                throw new InvalidOperationException("Não foi possível criar o barramento virtual.");
            }
        }

        public Device Create() { return new Device(server, bus); }
        public void Dispose()
        {
            if (server == IntPtr.Zero) return;
            CloseUSBServer(server);
            server = IntPtr.Zero;
        }

        public sealed class Device : IDisposable
        {
            private static readonly byte[] DPad = { 1, 9, 8, 10, 2, 6, 4, 5, 0 };
            private readonly Feedback callback;
            private IntPtr handle;
            public Rumble Motor { get; set; }

            internal Device(IntPtr server, uint bus)
            {
                callback = (device, flags, small, large, red, green, blue, flashOn, flashOff) =>
                {
                    var motor = Motor;
                    if (motor != null && (flags & 1) != 0) motor.ReceiveMotors(large, small);
                };
                if (!CreateDS4Device(server, out handle, bus, true, 0, 0, IntPtr.Zero))
                    throw new InvalidOperationException("Não foi possível conectar o DualShock 4 pelo USB/IP.");
                if (!SetDS4OutputCallback(handle, callback))
                {
                    Dispose();
                    throw new InvalidOperationException("Não foi possível ativar o retorno de vibração.");
                }
            }

            public void SendReport(DualShock4Report report)
            {
                var state = new DeviceState
                {
                    LX = (sbyte)(report.LeftThumbX - 128),
                    LY = (sbyte)(report.LeftThumbY - 128),
                    RX = (sbyte)(report.RightThumbX - 128),
                    RY = (sbyte)(report.RightThumbY - 128),
                    Buttons = (ushort)((report.Buttons & 0xfff0) | (report.SpecialButtons & 3)),
                    DPad = DPad[Math.Min(report.Buttons & 15, 8)],
                    L2 = report.LeftTrigger,
                    R2 = report.RightTrigger,
                    AccelZ = -5023
                };
                if (!SetDS4DeviceState(handle, state))
                    throw new InvalidOperationException("O DualShock 4 virtual foi desconectado.");
            }

            public void Dispose()
            {
                Motor = null;
                if (handle == IntPtr.Zero) return;
                SetDS4OutputCallback(handle, null);
                RemoveDS4Device(handle);
                handle = IntPtr.Zero;
            }
        }
    }
}

