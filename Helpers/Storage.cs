using System.Collections;
using System.Text;
using PropertyList;

namespace SupportCompanion.Helpers;

public class Storage
{
    private readonly string _storageCommand = "/usr/sbin/diskutil info -plist /";
    private Dictionary<string, object> _storageInfo = new();

    public async Task<IDictionary> GetStorageInfo()
    {
        try
        {
            var StorageInfo = await new StartProcess().RunCommand(_storageCommand);
            // Parse the plist output and return the StorageInfo
            var PlistReader = new PlistReader();
            var stream = new MemoryStream(Encoding.UTF8.GetBytes(StorageInfo));
            var Plist = PlistReader.Read(stream);
            var storageInfo = (IDictionary)Plist;
            // Get storage total and used space
            var totalSize = storageInfo["TotalSize"];
            var volumeFree = storageInfo["APFSContainerFree"];
            // convert to GB and round to .5
            var totalSizeGB = Math.Round(Convert.ToDouble(totalSize) / 1000 / 1000 / 1000, 1);
            var volumeFreeGB = Math.Round(Convert.ToDouble(volumeFree) / 1000 / 1000 / 1000, 1);
            var volumeUsedGB = totalSizeGB - volumeFreeGB;
            var volumeUsedPercentage = Math.Round(volumeUsedGB / totalSizeGB * 100, 1);
            // Create a new dictionary with the desired keys and values
            var storageDictionary = new Dictionary<string, object>
            {
                { "VolumeType", storageInfo["FilesystemUserVisibleName"] },
                { "VolumeName", storageInfo["VolumeName"] },
                { "VolumeSize", totalSizeGB },
                { "VolumeUsed", volumeUsedGB },
                { "VolumeFree", volumeFreeGB },
                { "VolumeUsedPercentage", volumeUsedPercentage },
                { "IsEncrypted", storageInfo["Encryption"] },
                { "FileVaultEnabled", storageInfo["FileVault"] }
            };

            _storageInfo = storageDictionary;
        }
        catch (Exception e)
        {
            Logger.LogWithSubsystem("Storage", $"Failed to get storage info: {e.Message}", 2);
        }

        return _storageInfo;
    }
}