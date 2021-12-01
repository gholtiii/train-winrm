#Requires -Version 5
Param (
      [string]$SubjectName = $env:COMPUTERNAME,
      [int]$CertValidityDays = 365,
      $CreateSelfSignedCert = $true
)

$ErrorActionPreference = "Stop"

# Find and start the WinRM service.
Write-Verbose "Verifying WinRM service."
If (!(Get-Service "WinRM")) {
    Throw "Unable to find the WinRM service."
}
ElseIf ((Get-Service "WinRM").Status -ne "Running") {
    Write-Verbose "Starting WinRM service."
    Start-Service -Name "WinRM" -ErrorAction Stop
}

# WinRM should be running; check that we have a PS session config.
If (!(Get-PSSessionConfiguration -Verbose:$false) -or (!(Get-ChildItem WSMan:\localhost\Listener))) {
    Write-Verbose "Enabling PS Remoting."
    Enable-PSRemoting -Force -ErrorAction Stop
}
Else {
    Write-Verbose "PS Remoting is already enabled."
}


# Make sure there is an SSL listener.
$listeners = Get-ChildItem WSMan:\localhost\Listener
If (!($listeners | Where-Object { $_.Keys -like "TRANSPORT=HTTPS" })) {
    # HTTPS-based endpoint does not exist.
    If (Get-Command "New-SelfSignedCertificate" -ErrorAction SilentlyContinue) {
        $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation "Cert:\LocalMachine\My"
        $thumbprint = $cert.Thumbprint
    }
    Else {
        throw "Missing New-SelfSignedCertificate cmdlet"
    }

    # Create the hashtables of settings to be used.  Note the hostname is temporary since this is just a template, so do not specify.
    $valueset = @{ }
    $valueset.Add('CertificateThumbprint', $thumbprint)

    $selectorset = @{ }
    $selectorset.Add('Transport', 'HTTPS')
    $selectorset.Add('Address', '*')

    Write-Verbose "Enabling SSL listener."
    New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset
}
Else {
    Write-Verbose "SSL listener is already active."
}

# Check for basic authentication.
$basicAuthSetting = Get-ChildItem WSMan:\localhost\Service\Auth | Where-Object { $_.Name -eq "Basic" }
If (($basicAuthSetting.Value) -eq $false) {
    Write-Verbose "Enabling basic auth support."
    Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $true
}
Else {
    Write-Verbose "Basic auth is already enabled."
}

# Configure firewall to allow WinRM HTTPS connections.
$fwtest1 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS"
$fwtest2 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS" profile=any
If ($fwtest1.count -lt 5) {
    Write-Verbose "Adding firewall rule to allow WinRM HTTPS."
    netsh advfirewall firewall add rule profile=any name="Allow WinRM HTTPS" dir=in localport=5986 protocol=TCP action=allow
}
ElseIf (($fwtest1.count -ge 5) -and ($fwtest2.count -lt 5)) {
    Write-Verbose "Updating firewall rule to allow WinRM HTTPS for any profile."
    netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new profile=any
}
Else {
    Write-Verbose "Firewall rule already exists to allow WinRM HTTPS."
}

# Test a remoting connection to localhost, which should work.
$httpResult = Invoke-Command -ComputerName "localhost" -ScriptBlock { $env:COMPUTERNAME } -ErrorVariable httpError -ErrorAction SilentlyContinue
$httpsOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

$httpsResult = New-PSSession -UseSSL -ComputerName "localhost" -SessionOption $httpsOptions -ErrorVariable httpsError -ErrorAction SilentlyContinue

If ($httpResult -and $httpsResult) {
    Write-Verbose "HTTP and HTTPS sessions are enabled."
}
ElseIf ($httpsResult -and !$httpResult) {
    Write-Verbose "HTTP sessions are disabled, HTTPS session are enabled."
}
ElseIf ($httpResult -and !$httpsResult) {
    Write-Verbose "HTTPS sessions are disabled, HTTP session are enabled."
}
Else {
    Throw "Unable to establish an HTTP or HTTPS remoting session."
}

Write-Verbose "PS Remoting has been successfully configured!"

# Reset auto logon count
# https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0