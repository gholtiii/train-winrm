# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "gusztavvargadr/windows-server-2016-standard-desktop"
  config.vm.box_url = "https://vagrantcloud.com/gusztavvargadr/windows-server-2016-standard-desktop"
  config.vm.box_version = "1607.0.2109"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 1
  end

  # config.vm.provision "shell", name: "install-chocolatey", inline: <<-SHELL
  #   Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  #   choco install chefdk -y
  # SHELL

  #  # Using separate provision block to make sure path is set
  #  config.vm.provision "shell", name: "chef shell-init", inline: <<-SHELL
  #    chef shell-init powershell >> C:\\Users\\vagrant\\Documents\\WindowsPowerShell\\Microsoft.PowerShell_profile.ps1
  #  SHELL

  # Using separate provision block to make sure path is set
  config.vm.provision "shell", name: "enable winrm", inline: <<-SHELL
    winrm quickconfig -q
  SHELL

  config.vm.provision "shell", path: "test/integration/fixtures/scripts/winrm.ps1"

  config.vm.provision "shell", path: "test/integration/fixtures/scripts/import_certificate.ps1"
end
