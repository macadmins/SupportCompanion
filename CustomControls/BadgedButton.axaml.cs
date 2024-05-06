using System.Windows.Input;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
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

        // Get a reference to the Button
        var button = e.NameScope.Find<Button>("PART_Button");

        // Attach an event handler to the Click event
        button.Click += (sender, args) => Command?.Execute(null);
    }

    private void InitializeComponent()
    {
        AvaloniaXamlLoader.Load(this);
    }
}