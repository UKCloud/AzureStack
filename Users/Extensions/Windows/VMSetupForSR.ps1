# Create registry entry
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType "DWORD"

# File and Printer sharing firewall rules
Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Set-NetFirewallRule -Profile Any -Enabled true

# Windows Management Instrumentation firewall rules
Get-NetFirewallRule -DisplayGroup "Windows Management Instrumentation (WMI)" | Set-NetFirewallRule -Profile Any -Enabled true