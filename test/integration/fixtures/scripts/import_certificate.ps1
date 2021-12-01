$ErrorActionPreference = "Stop"

Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $true

$client_cert_path = 'C:\vagrant\test\integration\fixtures\.openssl\user.pem'

Import-Certificate -FilePath $client_cert_path -CertStoreLocation cert:\LocalMachine\root
Import-Certificate -FilePath $client_cert_path -CertStoreLocation cert:\LocalMachine\TrustedPeople

$User = "vagrant"
$Pword = ConvertTo-SecureString -String "vagrant" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Pword

New-Item -Path WSMan:\localhost\ClientCertificate `
  -Subject 'vagrant@localhost' `
  -URI * `
  -Issuer ECE52AAE99D69352B61E9367A80BD56B3789AC02 `
  -Credential $Credential `
  -Force

