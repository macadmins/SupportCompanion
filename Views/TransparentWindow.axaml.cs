using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Controls;
using Microsoft.Extensions.DependencyInjection;
using SupportCompanion.Interfaces;
using SupportCompanion.ViewModels;

namespace SupportCompanion.Views;

public partial class TransparentWindow : Window, ITransparentWindow
{
    private static readonly string DesktopPosition = App.Config.DesktopPosition;

    public TransparentWindow()
    {
        InitializeComponent();
        var viewModel = ((App)Application.Current).ServiceProvider.GetRequiredService<TransparentWindowViewModel>();
        viewModel.TransparentWindow = this;
        DataContext = viewModel;
        PositionWindowInCorner(DesktopPosition);
        Opened += OnWindowOpened;
        ShowActivated = false;
    }

    public void hide()
    {
        base.Hide();
    }

    public void show()
    {
        base.Show();
    }

    public void invalidateVisual()
    {
        InvalidateVisual();
    }

    private void OnWindowOpened(object sender, EventArgs e)
    {
        SetWindowProperties();
    }

    private void SetWindowProperties()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            var handle = GetNativeWindowHandle();
            if (handle != IntPtr.Zero)
            {
                // Set the window level to desktop, behind all other windows
                MacOSInterop.SetWindowLevel(handle, (int)NSWindowLevel.BelowDesktop);

                // Make the window ignore mouse events to prevent it from coming to the foreground
                MacOSInterop.SetIgnoresMouseEvents(handle, true);

                // Set collection behavior to stick the window to the desktop
                const int NSWindowCollectionBehaviorCanJoinAllSpaces = 1 << 0;
                const int NSWindowCollectionBehaviorStationary = 1 << 4;
                MacOSInterop.SetCollectionBehavior(handle,
                    NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary);
            }
        }
    }

    private IntPtr GetNativeWindowHandle()
    {
        var platformHandle = TryGetPlatformHandle();
        return platformHandle?.Handle ?? IntPtr.Zero;
    }

    private void PositionWindowInCorner(string corner)
    {
        var screen = Screens.Primary.WorkingArea;

        switch (corner)
        {
            case "BottomLeft":
                Position = new PixelPoint(screen.X, screen.Y + screen.Height - (int)Height);
                break;
            case "BottomRight":
                Position = new PixelPoint(screen.X + screen.Width - (int)Width,
                    screen.Y + screen.Height - (int)Height);
                break;
            case "TopLeft":
                Position = new PixelPoint(screen.X, screen.Y);
                break;
            case "TopRight":
                Position = new PixelPoint(screen.X + screen.Width - (int)Width, screen.Y);
                break;
            default:
                throw new ArgumentException("Invalid corner specified");
        }
    }

    private enum NSWindowLevel
    {
        Normal = 0,
        Desktop = -1,
        BelowDesktop = -2
    }
}

public static class MacOSInterop
{
    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    public static extern IntPtr objc_getClass(string className);

    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    public static extern IntPtr sel_registerName(string selector);

    [DllImport("/System/Library/Frameworks/AppKit.framework/AppKit")]
    public static extern void objc_msgSend(IntPtr receiver, IntPtr selector, IntPtr arg);

    public static void SetWindowLevel(IntPtr nsWindow, int level)
    {
        var setLevelSelector = sel_registerName("setLevel:");
        objc_msgSend(nsWindow, setLevelSelector, level);
    }

    public static void SetIgnoresMouseEvents(IntPtr nsWindow, bool ignores)
    {
        var setIgnoresMouseEventsSelector = sel_registerName("setIgnoresMouseEvents:");
        objc_msgSend(nsWindow, setIgnoresMouseEventsSelector, ignores ? 1 : 0);
    }

    public static void SetCollectionBehavior(IntPtr nsWindow, int behavior)
    {
        var setCollectionBehaviorSelector = sel_registerName("setCollectionBehavior:");
        objc_msgSend(nsWindow, setCollectionBehaviorSelector, behavior);
    }
}