using System.Text.Json;
using SupportCompanion.Helpers;
using SupportCompanion.Models;
using SupportCompanion.Services;

namespace SupportCompanion.ViewModels;

public class MacPasswordViewModel : ViewModelBase
{
    private readonly ActionsService _actionsService;
    private readonly MacPasswordService _macPasswordService;
    private bool _disposed;

    public MacPasswordViewModel(ActionsService actionsService, MacPasswordService macPasswordService)
    {
        _actionsService = actionsService;
        _macPasswordService = macPasswordService;
        KerberosSSO = new KerberosSSOModel();
        PlatformSSO = new PlatformSSOModel();
        InitializeAsync();
    }

    public KerberosSSOModel? KerberosSSO { get; private set; }
    public PlatformSSOModel? PlatformSSO { get; private set; }

    private async void InitializeAsync()
    {
        await GetMacPasswordInfo();
    }

    private T GetValueOrDefault<T>(Dictionary<string, object> dictionary, string key, T defaultValue = default)
    {
        if (dictionary == null)
        {
            Logger.LogWithSubsystem("MacPasswordViewModel", "Dictionary is null.", 1);
            return defaultValue;
        }

        if (!dictionary.TryGetValue(key, out var value))
        {
            Logger.LogWithSubsystem("MacPasswordViewModel", $"Key '{key}' not found in dictionary.", 1);
            return defaultValue;
        }

        if (value == null)
        {
            Logger.LogWithSubsystem("MacPasswordViewModel", $"Value for key '{key}' is null.", 1);
            return defaultValue;
        }

        if (value is JsonElement element)
            try
            {
                if (typeof(T) == typeof(string)) return (T)(object)element.GetString();
                if (typeof(T) == typeof(int)) return (T)(object)element.GetInt32();
                if (typeof(T) == typeof(bool)) return (T)(object)element.GetBoolean();
                if (typeof(T) == typeof(decimal)) return (T)(object)element.GetDecimal();
            }
            catch (Exception ex)
            {
                Logger.LogWithSubsystem("MacPasswordViewModel",
                    $"Error converting value for key '{key}' to type '{typeof(T)}': {ex.Message}", 1);
                return defaultValue;
            }

        if (value is T typedValue) return typedValue;

        Logger.LogWithSubsystem("MacPasswordViewModel", $"Value for key '{key}' is not of type '{typeof(T)}'.", 1);
        return defaultValue;
    }

    private void UpdatePlatformSSOModel(Dictionary<string, object> deviceConfig, Dictionary<string, object> userConfig)
    {
        PlatformSSO.IsPlatformSSO = true;
        PlatformSSO.ExtensionIdentifier = GetValueOrDefault<string>(deviceConfig, "extensionIdentifier");
        PlatformSSO.RegistrationCompleted = GetValueOrDefault<bool>(deviceConfig, "registrationCompleted");
        PlatformSSO.LoginFrequency = GetValueOrDefault<int>(deviceConfig, "loginFrequency");
        PlatformSSO.NewUserAuthorizationMode = GetValueOrDefault<string>(deviceConfig, "newUserAuthorizationMode");
        PlatformSSO.SharedDeviceKeys = GetValueOrDefault<bool>(deviceConfig, "sharedDeviceKeys");
        PlatformSSO.UserAuthorizationMode = GetValueOrDefault<string>(deviceConfig, "userAuthorizationMode");
        PlatformSSO.SdkVersionString = GetValueOrDefault<decimal>(deviceConfig, "sdkVersionString");
        var loginType = GetValueOrDefault<string>(userConfig, "loginType");
        if (loginType != null)
            loginType.Split(" ").ToList().ForEach(x =>
            {
                if (x.Contains("(1)"))
                    PlatformSSO.LoginType = "Password";
                else if (x.Contains("(2)"))
                    PlatformSSO.LoginType = "Secure Enclave";
                else if (x.Contains("(3)")) PlatformSSO.LoginType = "Smart Card";
            });
        PlatformSSO.RegistrationStatusColor = PlatformSSO.RegistrationCompleted ? "LightGreen" : "#FF4F44";
    }

    private async Task GetMacPasswordInfo()
    {
        // Check if we're using Kerberos SSO
        var realm = await _actionsService.RunCommandWithOutput("/usr/bin/app-sso -l --json");
        var PlatformSSOInfo = await _macPasswordService.GetPlatformSsoInfo();
        var realmJson = JsonSerializer.Deserialize<string[]>(realm);
        var realmName = string.Empty;
        if (realmJson != null && realmJson.Length > 0) realmName = realmJson[0];

        if (!string.IsNullOrEmpty(realmName))
        {
            KerberosSSO.IsKerberosSSO = true;
            var kerberosInfo = await _macPasswordService.GetKerberosSsoInfo();
            KerberosSSO.UserName = kerberosInfo["user_name"].ToString();
            KerberosSSO.KerberosRealm = kerberosInfo["realm"].ToString();
            KerberosSSO.LocalPasswordLastChanged = Convert.ToInt32(kerberosInfo["local_password_changed_date"]);
            KerberosSSO.KerberosPasswordExpiryDays = Convert.ToInt32(kerberosInfo["password_expires_date"]);
            KerberosSSO.KerberosPasswordLastChangedDays = Convert.ToInt32(kerberosInfo["password_changed_date"]);
            KerberosSSO.ExpiryColor = kerberosInfo["password_expiry_color"].ToString();
        }
        else
        {
            if (PlatformSSOInfo.TryGetValue("device_configuration", out var deviceConfigObj) &&
                deviceConfigObj is Dictionary<string, object> deviceConfig)
            {
                Dictionary<string, object> userConfig = null;
                if (PlatformSSOInfo.TryGetValue("user_configuration", out var userConfigObj) &&
                    userConfigObj is Dictionary<string, object> tempUserConfig) userConfig = tempUserConfig;
                UpdatePlatformSSOModel(deviceConfig, userConfig);
            }
        }
    }

    private void CleanUp()
    {
        KerberosSSO = null;
        PlatformSSO = null;
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing) CleanUp();
            _disposed = true;
        }
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    ~MacPasswordViewModel()
    {
        Dispose(false);
    }
}