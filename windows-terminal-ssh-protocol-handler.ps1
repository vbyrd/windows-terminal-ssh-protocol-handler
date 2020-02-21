# Copyright (c) Victor Byrd. All rights reserved.
# Licensed under the MIT License.
#
# SSH Protocol Handler Script for Windows Terminal
# by Victor Byrd
# Github: https://github.com/vbyrd/windows-terminal-ssh-protocol-handler/
# 
# Requires: Windows Terminal
#   Store Link: https://www.microsoft.com/en-us/p/windows-terminal-preview/9n0dx20hk701
# Requires: SSH Client
#   Option 1: OpenSSH Client - Windows Feature from Windows 10 1809 on
#       How-to Enable: https://bit.ly/2HIcRDm
#   Option 2: plink SSH Client (Putty)
#       Download Link: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
#       Note: plink.exe path must be defined in your PATH environment variable 

# --> Begin user modifiable variables

# Set the SSH Client you would like to call
# Options: <openssh|plink>
# Default: openssh
$sshPreferredClient = 'openssh'

# Set if you would like to see verbose output from the SSH Clients (Debug)
# Default: false
$sshVerbosity = $false

# Set the time OpenSSH will wait for connection in seconds before timing out
# Default: <emptystring> - We will let OpenSSH decide based on the system TCP timeout
# NOTE: Applies to OpenSSH only
$sshConnectionTimeout = 3

# Set the profile Windows Terminal will use as a base
# Default: <emtpystring> - We will let Windows Terminal decide based on it's default profile
$wtProfile = ''

# <-- End user modifiable variables

$inputURI = $args[0]
$inputArguments = @{}

if ($inputURI -match '^(?<Protocol>\w+)\:\/\/(?:(?<Username>[\w|\@|\.]+)@)?(?<Host>.+)\:(?<Port>\d{2,5})$') {
    $inputArguments.Add('Protocol', $Matches.Protocol)
    $inputArguments.Add('Username', $Matches.Username) # Optional
    $inputArguments.Add('Port', $Matches.Port)
    $rawHost = $Matches.Host

   switch -Regex ($rawHost)
   {
       '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' {
            # Basic test for IP Address 
            $inputArguments.Add('Host', $rawHost)
            Break
        }
       '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.)+[a-zA-Z]{2,63}$)' { 
            # Test for a valid Hostname
            $inputArguments.Add('Host', $rawHost)
            Break
        }
        Default {
            Write-Warning 'The Hostname/IP Address passed is invalid. Exiting...'
            Exit  
        }
   }
} else {
    Write-Warning 'The URL passed to the handler script is invalid. Exiting...'
    Exit    
}

$windowsTerminalStatus = Get-AppxPackage -Name 'Microsoft.WindowsTerminal*' | Select-Object -ExpandProperty 'Status'
if ($windowsTerminalStatus -eq 'Ok') {
    $appExec = Get-Command 'wt.exe' | Select-Object -ExpandProperty 'Source'
    if (Test-Path $appExec) {
        $windowsTerminal = $appExec
    } else {
        Write-Warning 'Could not verify Windows Terminal executable path. Exiting...'
        Exit
    }
} else {
    Write-Warning 'Windows Terminal is not installed. Exiting...'
    Exit
}

$sshArguments = ''

if ($sshPreferredClient -eq 'openssh') {
    $appExec = Get-Command 'ssh.exe' | Select-Object -ExpandProperty 'Source'
    if (Test-Path $appExec) {
        $SSHClient = $appExec
    } else {
        Write-Warning 'Could not find ssh.exe in Path. Exiting...'
        Exit
    }
    
    if ($inputArguments.Username) {
        $sshArguments += "{0} -l {1} -p {2}" -f $inputArguments.Host, $inputArguments.Username, $inputArguments.Port
    } else {
        $sshArguments += "{0} -p {1}" -f $inputArguments.Host, $inputArguments.Port   
    }
    
    if ($sshVerbosity) {
        $sshArguments += " -v"
    }

    if ($sshConnectionTimeout) {
        $sshArguments += " -o ConnectTimeout={0}" -f $sshConnectionTimeout
    }
}

if ($sshPreferredClient -eq 'plink') {
    $appExec = Get-Command 'plink.exe' | Select-Object -ExpandProperty 'Source'
    if (Test-Path $appExec) {
        $SSHClient = $appExec
    } else {
        Write-Warning 'Could not find plink.exe in Path. Exiting...'
        Exit
    }

    if ($inputArguments.Username) {
        $sshArguments += "{0} -l {1} -P {2}" -f $inputArguments.Host, $inputArguments.Username, $inputArguments.Port
    } else {
        $sshArguments += "{0} -P {1}" -f $inputArguments.Host, $inputArguments.Port   
    }

    if ($sshVerbosity) {
        $sshArguments += " -v"
    }    
}

$wtArguments = ''

if ($wtProfile) {
    $wtArguments += "-p {0} " -f $wtProfile
}

$sshCommand = $SSHClient + ' ' + $sshArguments
$wtArguments += 'new-tab ' + $sshCommand

#Write-Output "Start-Process Command: $windowsTerminal Arguments: $wtArguments"

Start-Process -FilePath $windowsTerminal -ArgumentList $wtArguments