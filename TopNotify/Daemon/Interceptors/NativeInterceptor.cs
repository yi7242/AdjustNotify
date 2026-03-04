using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using TopNotify.Common;
using SamsidParty_TopNotify.Daemon;
using Windows.UI.Notifications;
using static TopNotify.Daemon.ResolutionFinder;

namespace TopNotify.Daemon
{

    public class NativeInterceptor : Interceptor
    {
        #region WinAPI Methods

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll", EntryPoint = "SetWindowPos")]
        public static extern IntPtr SetWindowPos(IntPtr hWnd, int hWndInsertAfter, int x, int Y, int cx, int cy, int wFlags);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hwnd, ref Rectangle rectangle);

        const short SWP_NOSIZE = 1;
        const short SWP_NOZORDER = 0X4;
        const int SWP_SHOWWINDOW = 0x0040;

        [DllImport("TopNotify.Native")]
        private static extern bool TopNotifyEnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        #endregion

        public IntPtr hwnd;
        public ExtendedStyleManager ExStyleManager;
        public int ScaledPreferredDisplayWidth;
        public int ScaledPreferredDisplayHeight;
        public int RealPreferredDisplayWidth;
        public int RealPreferredDisplayHeight;
        public float ScaleFactor;
        const int MinNotificationDisplayDurationMs = 100;
        const int MaxNotificationDisplayDurationMs = 30000;
        const int NotificationEventDebounceMs = 1200;
        DateTime lastNotificationEventTime = DateTime.MinValue;
        uint lastNotificationId = uint.MaxValue;
        CancellationTokenSource? notificationCloseCts;

        public override void Start()
        {
            base.Start();
            ExStyleManager = new ExtendedStyleManager(new IntPtr(0x00200008)); // Magic Number, Default Notification Style
            Reflow();
        }

        public override void Restart()
        {
            lastNotificationId = uint.MaxValue;
            lastNotificationEventTime = DateTime.MinValue;
            notificationCloseCts?.Cancel();
            notificationCloseCts?.Dispose();
            notificationCloseCts = null;

            base.Restart();
        }

        public override void OnNotification(UserNotification notification)
        {
            if (notification == null)
            {
                return;
            }

            var nowUtc = DateTime.UtcNow;
            var msSinceLastEvent = (nowUtc - lastNotificationEventTime).TotalMilliseconds;
            var duplicateNotificationGraceMs = Math.Max(
                NotificationEventDebounceMs,
                Math.Clamp(Settings.NotificationDisplayDurationMs + 1500, 1500, 8000)
            );

            // Some systems emit multiple added events for the same visual toast.
            if (notification.Id == lastNotificationId && msSinceLastEvent < duplicateNotificationGraceMs)
            {
                Program.Logger.Information($"Ignoring duplicate notification event (id={notification.Id})");
                return;
            }

            lastNotificationId = notification.Id;
            lastNotificationEventTime = nowUtc;
            Program.Logger.Information($"Handling notification event (id={notification.Id})");
            BeginNotificationCloseCountdown(notification.Id);

            base.OnNotification(notification);
        }

        // Modified From https://stackoverflow.com/a/20276701/18071273
        public static IEnumerable<IntPtr> FindCoreWindows()
        {
            List<IntPtr> windows = new List<IntPtr>();

            TopNotifyEnumWindows(delegate (IntPtr hwnd, IntPtr param)
            {
                var classGet = new StringBuilder(1024);
                GetClassName(hwnd, classGet, classGet.Capacity);
                if (classGet.ToString() == "Windows.UI.Core.CoreWindow")
                {
                    windows.Add(hwnd);
                }

                return true;
            }, IntPtr.Zero);

            return windows;
        }

        public override void Reflow()
        {
            if (ExStyleManager == null) { return; } // Return If Start() Has Not Been Called Yet

            base.Reflow();

            try
            {
                var foundHwnd = FindWindow("Windows.UI.Core.CoreWindow", Language.NotificationName);

                if (Settings.EnableDebugForceFallbackMode)
                {
                    Program.Logger.Information($"Fallback detection is being forced");
                    foundHwnd = IntPtr.Zero; // Always use fallback mode if this setting is enabled
                }

                ScaledPreferredDisplayWidth = ResolutionFinder.GetScaledResolution().Width;
                ScaledPreferredDisplayHeight = ResolutionFinder.GetScaledResolution().Height;
                RealPreferredDisplayWidth = ResolutionFinder.GetRealResolution().Width;
                RealPreferredDisplayHeight = ResolutionFinder.GetRealResolution().Height;
                ScaleFactor = ResolutionFinder.GetInverseScale();

                //The Notification Isn't In A Supported Language
                if (foundHwnd == IntPtr.Zero)
                {
                    Program.Logger.Information($"Couldn't use language-specific window detection, using fallback detection");
                    //The Notification Window Is The Only One That Is 396 x 152
                    foreach (var win in FindCoreWindows())
                    {
                        Rectangle rect = new Rectangle();
                        GetWindowRect(win, ref rect);

                        if ((ScaledPreferredDisplayWidth - rect.X) == 396)
                        {
                            foundHwnd = win;
                        }
                    }
                }

                if (foundHwnd != IntPtr.Zero && hwnd != foundHwnd)
                {
                    Program.Logger.Information($"Found notification window {foundHwnd}");
                    hwnd = foundHwnd;
                }
                else if (foundHwnd == IntPtr.Zero)
                {
                    Program.Logger.Error($"Couldn't find the handle of the notification window");
                }

                Update();

            }
            catch { }
        }

        public override void OnKeyUpdate()
        {
            // Delay until the keypress has been processed
            Task.Run(async () =>
            {
                await Task.Delay(100);
                ExStyleManager.Update(hwnd);
            });
            
            base.OnKeyUpdate();
        }

        void TryRemoveNotification(uint notificationId)
        {
            try
            {
                var manager = InterceptorManager.Instance;
                manager?.Listener?.RemoveNotification(notificationId);
                manager?.ActiveNotificationIds.TryRemove(notificationId, out _);
            }
            catch { }
        }

        void BeginNotificationCloseCountdown(uint notificationId)
        {
            notificationCloseCts?.Cancel();
            notificationCloseCts?.Dispose();
            notificationCloseCts = new CancellationTokenSource();
            var closeToken = notificationCloseCts.Token;
            var displayDurationMs = Math.Clamp(Settings.NotificationDisplayDurationMs, MinNotificationDisplayDurationMs, MaxNotificationDisplayDurationMs);

            Task.Run(async () =>
            {
                try
                {
                    await Task.Delay(displayDurationMs, closeToken);

                    if (closeToken.IsCancellationRequested)
                    {
                        return;
                    }

                    Program.Logger.Information($"Closing notification (id={notificationId}) after {displayDurationMs}ms");
                    TryRemoveNotification(notificationId);
                }
                catch (TaskCanceledException) { }
            });
        }

        public override void Update()
        {
            base.Update();

            // Update extended styles
            ExStyleManager.Update(hwnd);

            // Find The Bounds Of The Notification Window
            Rectangle NotifyRect = new Rectangle();
            if (hwnd == IntPtr.Zero || !GetWindowRect(hwnd, ref NotifyRect))
            {
                return;
            }

            // Find The Bounds Of The Preferred Monitor
            var hMonitor = ResolutionFinder.GetPreferredDisplay();
            MonitorInfo currentMonitorInfo = new MonitorInfo();
            ResolutionFinder.GetMonitorInfo(hMonitor, currentMonitorInfo);
            var originX = currentMonitorInfo.Monitor.Left;
            var originY = currentMonitorInfo.Monitor.Top;

            var unscaledWidth = (int)((NotifyRect.Width - NotifyRect.X));
            var unscaledHeight = (int)((NotifyRect.Height - NotifyRect.Y));

            var targetX = originX + 0;
            var targetY = originY + 0;

            if (Settings.Location == NotifyLocation.TopRight)
            {
                targetX = originX + (RealPreferredDisplayWidth - unscaledWidth);
                targetY = 0;
            }
            else if (Settings.Location == NotifyLocation.BottomLeft)
            {
                targetX = originX + 0;
                targetY = originY + (RealPreferredDisplayHeight - unscaledHeight - (int)Math.Round(50f));
            }
            else if (Settings.Location == NotifyLocation.BottomRight) // Default In Windows, But Here For Completeness Sake
            {
                targetX = originX + (RealPreferredDisplayWidth - unscaledWidth);
                targetY = originY + (RealPreferredDisplayHeight - unscaledHeight - (int)Math.Round(50f));
            }
            else if (Settings.Location == NotifyLocation.Custom) // Custom Position
            {
                var xPosition = (int)(Settings.CustomPositionPercentX / 100f * RealPreferredDisplayWidth);
                var yPosition = (int)(Settings.CustomPositionPercentY / 100f * RealPreferredDisplayHeight);

                if (!Settings.EnableDebugRemoveBoundsCorrection)
                {
                    // Make Sure Position Isn't Out Of Bounds
                    xPosition = Math.Clamp(xPosition, 0, RealPreferredDisplayWidth - unscaledWidth);
                    yPosition = Math.Clamp(yPosition, 0, RealPreferredDisplayHeight - unscaledHeight);
                }

                targetX = originX + xPosition;
                targetY = originY + yPosition;
            }

            SetWindowPos(hwnd, 0, targetX, targetY, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_SHOWWINDOW);

        }
    }
}
