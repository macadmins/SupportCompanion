using System.Collections.Generic;
using Newtonsoft.Json;
using ReactiveUI;

namespace SupportCompanion.ViewModels
{
    public class CustomWidgetsBaseViewModel : ViewModelBase
    {
        private string _icon;
        private string _header;
        private Dictionary<string, string> _data;
        
        [JsonProperty("icon")]
        public string Icon
        {
            get => _icon;
            set => this.RaiseAndSetIfChanged(ref _icon, value);
        }
        
        [JsonProperty("header")]
        public string Header
        {
            get => _header;
            set => this.RaiseAndSetIfChanged(ref _header, value);
        }
        
        [JsonProperty("data")]
        public Dictionary<string, string> Data
        {
            get => _data;
            set => this.RaiseAndSetIfChanged(ref _data, value);
        }
    }
}