# Description: This script is used to get Windows Defender metrics and write them to a file for Prometheus to scrape.

Function Convert-ToUnixDate ($PSdate) {
   $epoch = [timezone]::CurrentTimeZone.ToLocalTime([datetime]'1/1/1970')
   (New-TimeSpan -Start $epoch -End $PSdate).TotalSeconds
}

Function Enabled-ToInt ($Enabled) {
   if ($Enabled) {
      return 1
   }
   return 0
}

Function Diff-Date ($Date) {
   return ((Get-Date) - $Date).Days
}

# Function to get Bios password registry value
Function Get-RegistryProperty($path ) {
    return Get-ItemProperty -Path $path
}

$KeysPath= "HKLM:\SOFTWARE\Microsoft\Microsoft Antimalware"
$defender_registry = Get-RegistryProperty -path "$KeysPath\Real-Time Protection"
$defender_state = Enabled-ToInt ($defender_registry.DisableRealtimeMonitoring -eq $null -or $defender_registry.DisableRealtimeMonitoring -eq 0)
# Get Microsoft Antivirus information from a Windows Server 2012 R2 from registry keys
$signatures_info = Get-RegistryProperty -path "$KeysPath\Signature Updates"
$engine_version = $signatures_info.EngineVersion
$antivirus_signatures_date = [datetime]::FromFileTime([BitConverter]::ToInt64($signatures_info.AVSignatureApplied,0))
$antivirus_signatures_unix_date = Convert-ToUnixDate ($antivirus_signatures_date)
$antivirus_signatures_age = Diff-Date($antivirus_signatures_date)
$antivirus_signatures_version = $signatures_info.AVSignatureVersion
$antispyware_signatures_date = [datetime]::FromFileTime([BitConverter]::ToInt64($signatures_info.ASSignatureApplied,0))
$antispyware_signatures_unix_date = Convert-ToUnixDate ($antispyware_signatures_date)
$antispyware_signatures_age = Diff-Date($antivirus_signatures_date)
$antispyware_signatures_version = $signatures_info.ASSignatureVersion


# Metric to indicate state of Windows Defender
# Label to indicate the state and version of the Windows Defender engine, Service and Signatures and antispyware signatures age
$metrics = "# HELP windows_textfile_defender_state Windows Defender State
# TYPE windows_textfile_defender_state gauge
windows_textfile_defender_state{engine_version=`"$engine_version`", real_time_protection_enabled=`"$defender_state`"} $defender_state
"

# Metric for Antivirus state with signatures version, age and last updated
$metrics += "# HELP windows_textfile_defender_antivirus_state Windows Defender Antivirus State
# TYPE windows_textfile_defender_antivirus_state gauge
windows_textfile_defender_antivirus_state{signatures_age=`"$antivirus_signatures_age`",signatures_version=`"$antivirus_signatures_version`"} 1
# HELP windows_textfile_defender_antivirus_signature_last_update Windows Defender Antivirus Signatures Last Update
# TYPE windows_textfile_defender_antivirus_signature_last_update gauge
windows_textfile_defender_antivirus_signature_last_update{signatures_age=`"$antivirus_signatures_age`",signatures_version=`"$antivirus_signatures_version`"} $antivirus_signatures_unix_date
"

# Metric for Antispyware state with signatures version, age and last updated
$metrics += "# HELP windows_textfile_defender_antispyware_state Windows Defender Antispyware State
# TYPE windows_textfile_defender_antispyware_state gauge
windows_textfile_defender_antispyware_state{signatures_age=`"$antispyware_signatures_age`",signatures_version=`"antispyware_signatures_version`"} 1
# HELP windows_textfile_defender_antispyware_signature_last_update Windows Defender Antispyware Signatures Last Update
# TYPE windows_textfile_defender_antispyware_signature_last_update gauge
windows_textfile_defender_antispyware_signature_last_update{signatures_age=`"$antispyware_signatures_age`",signatures_version=`"$antispyware_signatures_version`"} $antispyware_signatures_unix_date
"

[System.IO.File]::WriteAllText("C:\windows_exporter\textfile_inputs\defender_metrics.prom",$metrics,[System.Text.Encoding]::ASCII)
