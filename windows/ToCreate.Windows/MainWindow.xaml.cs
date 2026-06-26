using System.Diagnostics;
using System.Windows;
using Microsoft.Web.WebView2.Core;

namespace ToCreate.Windows;

public partial class MainWindow : Window
{
    private static readonly Uri HomeUri = new("https://api.lihe.chat");
    private bool isWebViewReady;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            await Browser.EnsureCoreWebView2Async();
            isWebViewReady = true;

            Browser.CoreWebView2.NewWindowRequested += CoreWebView2_NewWindowRequested;
            Browser.NavigationStarting += Browser_NavigationStarting;
            Browser.NavigationCompleted += Browser_NavigationCompleted;
            Browser.Source = HomeUri;

            UpdateNavigationState();
        }
        catch (Exception ex)
        {
            ShowMessage($"页面加载失败：{ex.Message}");
        }
    }

    private void Browser_NavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        HideMessage();
        AddressText.Text = e.Uri;
        UpdateNavigationState();
    }

    private void Browser_NavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs e)
    {
        UpdateNavigationState();
        if (!e.IsSuccess)
        {
            ShowMessage($"页面加载失败：{e.WebErrorStatus}");
        }
    }

    private void CoreWebView2_NewWindowRequested(object? sender, CoreWebView2NewWindowRequestedEventArgs e)
    {
        e.Handled = true;
        OpenInDefaultBrowser(e.Uri);
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (isWebViewReady && Browser.CanGoBack)
        {
            Browser.GoBack();
        }
    }

    private void ForwardButton_Click(object sender, RoutedEventArgs e)
    {
        if (isWebViewReady && Browser.CanGoForward)
        {
            Browser.GoForward();
        }
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        if (isWebViewReady)
        {
            HideMessage();
            Browser.Reload();
        }
    }

    private void OpenExternalButton_Click(object sender, RoutedEventArgs e)
    {
        OpenInDefaultBrowser(Browser.Source?.AbsoluteUri ?? HomeUri.AbsoluteUri);
    }

    private void UpdateNavigationState()
    {
        BackButton.IsEnabled = isWebViewReady && Browser.CanGoBack;
        ForwardButton.IsEnabled = isWebViewReady && Browser.CanGoForward;
        AddressText.Text = Browser.Source?.AbsoluteUri ?? HomeUri.AbsoluteUri;
    }

    private static void OpenInDefaultBrowser(string uri)
    {
        Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
    }

    private void ShowMessage(string message)
    {
        MessageText.Text = message;
        MessageBanner.Visibility = Visibility.Visible;
    }

    private void HideMessage()
    {
        MessageBanner.Visibility = Visibility.Collapsed;
    }
}
