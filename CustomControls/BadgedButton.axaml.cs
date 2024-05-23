using System.Windows.Input;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Markup.Xaml;

namespace SupportCompanion.CustomControls;

public partial class BadgedButton : TemplatedControl
{
    public static readonly StyledProperty<string> ContentProperty =
        AvaloniaProperty.Register<BadgedButton, string>(nameof(Content));

    public static readonly StyledProperty<bool> BadgeVisibleProperty =
        AvaloniaProperty.Register<BadgedButton, bool>(nameof(BadgeVisible));

    public static readonly StyledProperty<string> BadgeContentProperty =
        AvaloniaProperty.Register<BadgedButton, string>(nameof(BadgeContent));

    public static readonly StyledProperty<ICommand> CommandProperty =
        AvaloniaProperty.Register<BadgedButton, ICommand>(nameof(Command));


    private Button _button;

    public BadgedButton()
    {
        InitializeComponent();
    }

    public ICommand Command
    {
        get => GetValue(CommandProperty);
        set => SetValue(CommandProperty, value);
    }

    public string Content
    {
        get => GetValue(ContentProperty);
        set => SetValue(ContentProperty, value);
    }

    public bool BadgeVisible
    {
        get => GetValue(BadgeVisibleProperty);
        set => SetValue(BadgeVisibleProperty, value);
    }

    public string BadgeContent
    {
        get => GetValue(BadgeContentProperty);
        set => SetValue(BadgeContentProperty, value);
    }

    protected override void OnApplyTemplate(TemplateAppliedEventArgs e)
    {
        base.OnApplyTemplate(e);

        // Detach the previous event handler if the template is reapplied
        if (_button != null) _button.Click -= OnButtonClick;

        // Get a reference to the Button
        _button = e.NameScope.Find<Button>("PART_Button");

        // Attach an event handler to the Click event
        if (_button != null) _button.Click += OnButtonClick;
    }

    private void OnButtonClick(object sender, RoutedEventArgs e)
    {
        if (Command?.CanExecute(null) == true) Command.Execute(null);
    }

    private void InitializeComponent()
    {
        AvaloniaXamlLoader.Load(this);
    }
}