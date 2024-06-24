using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using PropertyList;

namespace SupportCompanion.Helpers;

public class MacPassword
{
    public async Task<Dictionary<string, object>> GetKerberosSSOinfo()
    {
        var realm = await new StartProcess().RunCommand("/usr/bin/app-sso -l --json");
        var realmJson = JsonSerializer.Deserialize<string[]>(realm);
        var realmName = realmJson[0];

        // Get the Kerberos SSO info
        var kerberosSSOInfo = await new StartProcess().RunCommand($"/usr/bin/app-sso -i {realmName}");
        using var stream = new MemoryStream(Encoding.UTF8.GetBytes(kerberosSSOInfo));
        var plistReader = new PlistReader();
        var kerberosSSOInfoDict = plistReader.Read(stream);

        kerberosSSOInfoDict.TryGetValue("user_name", out var userName);
        kerberosSSOInfoDict.TryGetValue("realm", out var kerberosRealm);
        kerberosSSOInfoDict.TryGetValue("local_password_changed_date", out var localPasswordLastChanged);
        kerberosSSOInfoDict.TryGetValue("password_expires_date", out var kerberosPasswordExpiryDate);
        kerberosSSOInfoDict.TryGetValue("password_changed_date", out var kerberosPasswordLastChanged);

        // Convert password dates to an int representing the number of days
        if (kerberosPasswordExpiryDate != null)
        {
            var expiryDate = DateTime.Parse(kerberosPasswordExpiryDate.ToString());
            var daysUntilExpiry = (expiryDate - DateTime.Now).Days;
            kerberosSSOInfoDict["password_expires_date"] = daysUntilExpiry;
            var expiryColor = daysUntilExpiry switch
            {
                < 2 => "#FF4F44",
                < 7 => "#FCE100",
                _ => "LightGreen"
            };
            kerberosSSOInfoDict.Add("password_expiry_color", expiryColor);
        }

        if (kerberosPasswordLastChanged != null)
        {
            var passwordLastChanged = DateTime.Parse(kerberosPasswordLastChanged.ToString());
            var daysSincePasswordChange = (DateTime.Now - passwordLastChanged).Days;
            kerberosSSOInfoDict["password_changed_date"] = daysSincePasswordChange;
        }

        if (localPasswordLastChanged != null)
        {
            var localPasswordChanged = DateTime.Parse(localPasswordLastChanged.ToString());
            var daysSinceLocalPasswordChange = (DateTime.Now - localPasswordChanged).Days;
            kerberosSSOInfoDict["local_password_changed_date"] = daysSinceLocalPasswordChange;
        }

        // return the dictionary
        return kerberosSSOInfoDict;
    }

    public async Task<Dictionary<string, object>> GetPlatformSSOInfo()
    {
        var platformSSOInfoDict = new Dictionary<string, object>
        {
            { "device_configuration", null },
            { "user_configuration", null }
        };
        var output = await new StartProcess().RunCommand("/usr/bin/app-sso platform -s");
        // Parse the output
        // Define regex patterns to match the JSON objects for device and user configurations
        var deviceConfigPattern = @"Device Configuration:\s*({.*?})\s*Login Configuration:";
        var userConfigPattern = @"User Configuration:\s*({.*?})\s*SSO Tokens:";

        // Extract device configuration JSON
        var deviceMatch = Regex.Match(output, deviceConfigPattern, RegexOptions.Singleline);
        if (deviceMatch.Success)
        {
            var deviceJson = deviceMatch.Groups[1].Value;
            var deviceConfig = JsonSerializer.Deserialize<Dictionary<string, object>>(deviceJson);
            platformSSOInfoDict["device_configuration"] = new Dictionary<string, object>(deviceConfig);
        }

        // Extract user configuration JSON
        var userMatch = Regex.Match(output, userConfigPattern, RegexOptions.Singleline);
        if (userMatch.Success)
        {
            var userJson = userMatch.Groups[1].Value;
            var userConfig = JsonSerializer.Deserialize<Dictionary<string, object>>(userJson);
            platformSSOInfoDict["user_configuration"] = new Dictionary<string, object>(userConfig);
        }

        return platformSSOInfoDict;
    }
}