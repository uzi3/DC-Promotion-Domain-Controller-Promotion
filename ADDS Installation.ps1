<#
IMPORTANT NOTES:
1) Server should be a member of domain where you wish to do DC promotion and domain name should be resolvable.

2)This script can be used to promote domain controller in an existing domain. It cannot be used to install a first domain controller.

3) Credential validation to an existing domain controller may be sent over plain text hence kindly ensure all the security mechanism are in place.
#>

# 1.0 Perform Prechecks

Write-Host "Please wait while information is being gathered..." -ForegroundColor Green

#Get hostname
$name=HOSTNAME.EXE 

# Get cores#
$cores=Get-WmiObject -Class win32_processor | select -ExpandProperty numberofcores
$sockets=Get-WmiObject -Class win32_processor | select -ExpandProperty socketdesignation
$ProcessorName=Get-WmiObject -Class win32_processor | select -ExpandProperty name
$sum=0
$cores | Foreach {$sum += $_}

# Get Memory
$Memory=Get-WmiObject -Class win32_physicalmemory | select -ExpandProperty capacity
$newmemory=[math]::Round($Memory/1000000000)

#Get NIC speed
$bitsPS=Get-WmiObject -Class win32_networkadapter | select -ExpandProperty speed
$GBPS=$bitsPS/1000000000

#Get time zone
$TimeZone=Get-WmiObject -Class win32_timezone | select -expandproperty caption

#Get Network details
$IP=Get-WmiObject win32_networkadapterconfiguration | select -expandproperty IPaddress
$DNS=Get-WmiObject win32_networkadapterconfiguration | select -expandproperty dnsserversearchorder

$data=@{"Hostname"=$name;"Processor - vCPU"=[string]$sum+' Cores';"Processor - Name"=[string]$ProcessorName;"Processor - Sockets"=[string]$sockets.count+' Sockets';"RAM"=[string]$newmemory+' GB';"NIC Speed"=[string]$GBPS+' GBPS';"Time Zone"=$TimeZone;"IP address"=$IP;"DNS Servers"=$DNS}

$Disk=Get-WmiObject -Class win32_logicaldisk | select caption, @{Label="size";Expression={[string]([math]::Round($_.size/1000000000,2))+' GB'}}, @{Label="freespace";Expression={[string]([math]::Round($_.freespace/1000000000,2))+' GB'}} | Ft

$data
$Disk

Do {
Write-Host `n `n `n "Above is the configuration of the server. Do you wish to continue with DC Promotion?" -ForegroundColor Green
$Input=read-Host " (Y/N)?"}
until (($input -eq "Y") -or ($Input -eq "N"))
If ($input -eq "Y")
{Out-Null}
ElseIF ($input -eq "N")
{
Write-Host `n `n "User selected to cancel DC promotion" -ForegroundColor Red
Start-Sleep -s 2
}





# 1.1 Check ADDS role is installed or not. If not install, will install it

Write-Host `n `n "Checking ADDS role installation state..." -ForegroundColor Green `n

$installedstate=(Get-WindowsFeature -Name ad-domain-services).installstate
If ($installedstate -ne "Installed")
    {
     Write-Host "Installing ADDS roles.... Please wait" -ForegroundColor Cyan `n `n `n
     Install-WindowsFeature -Name ad-domain-services
     Start-Sleep -Seconds 3

     $installedstate2=(Get-WindowsFeature -Name ad-domain-services).installstate

     If ($installedstate2 -ne "Installed")
        {
         Write-Warning "ADDS role installation failed. Please check logs or install manually"
        }

     elseif ($installedstate2 -eq "Installed")
        {
         Write-Host "ADDS role installation completed. Proceeding with DNS Check" -ForegroundColor Cyan `n `n `n
        }
    }

else

    {
    write-host `n `n "ADDS role is already installed. Proceeding with DNS check" -ForegroundColor Cyan `n `n `n
    }




# 1.2 Check DNS role is installed or not. If not install, will install it

Write-Host `n `n "Checking DNS role installation state..." -ForegroundColor Green `n

$installedstate=(Get-WindowsFeature -Name DNS).installstate
If ($installedstate -ne "Installed")
    {
     Write-Host "Installing DNS roles.... Please wait" -ForegroundColor Cyan `n `n `n
     Install-WindowsFeature -Name DNS
     Start-Sleep -Seconds 3

     $installedstate2=(Get-WindowsFeature -Name DNS).installstate

     If ($installedstate2 -ne "Installed")
        {
         Write-Warning "DNS role installation failed. Please check logs or install manually"
        }

     elseif ($installedstate2 -eq "Installed")
        {
         Write-Host "DNS role installation completed. Proceeding with DC Promotion" -ForegroundColor Cyan `n `n `n
        }
    }

else

    {
    write-host `n `n "DNS role is already installed. Proceeding with DC Promotion" -ForegroundColor Cyan `n `n `n
    }


Write-Host "Proceeding with domain controller installation..." -ForegroundColor Green
Start-Sleep -s 1


Import-Module ADDSDeployment



# 2 Information Gathering



############################################################################################################

Import-Module activedirectory

############################################################################################################

# 2.1 Function to verify credentials

function Verify-ADCredential 
{
    [CmdletBinding()]
    Param
    (
        $UserName,
        $Password
    )
    if (!($UserName) -or !($Password)) 
    {
        Write-Warning 'Test-ADCredential: Please specify both user name and password'
    } else 
    {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine')
        $DS.ValidateCredentials($UserName, $Password)
    }
}

############################################################################################################

# 2.2 Get Replication partner

Do
{
 $RepSourceDC = Read-Host "Kindly enter the FQDN of source replication partner DC"
 
 $Nslookup = nslookup $RepSourceDC
 $NewNslookup = $Nslookup -split ":"
 $finaldata = ($NewNslookup[6]) -replace " ", ""
 If ($finaldata -ne $RepSourceDC)
    {
     Write-Host `n `n
     Write-Host "Entered DC name is not valid or DNS is not able to resolve the name" -ForegroundColor Yellow
     Write-Host `n
     Write-Host "User Action:" -ForegroundColor Yellow
     Write-Host "Kindly Re-verify the entered replication DC name and check whether the primary DNS is able to resolve replication DC." 
     write-host "Once done kindly Re enter the proper replication DC name below"
     Write-Host `n `n
    }
}
Until ($finaldata -eq $RepSourceDC)

############################################################################################################

$PSDefaultParameterValues = @{"*-AD*:Server"="$RepSourceDC"}
$Domains=Get-ADForest | select -ExpandProperty domains | sort
$Sites=Get-ADForest | select -ExpandProperty sites | sort

#2.3 Get domain details
Do
{
 Write-Host `n `n
 $DomainName = Read-Host "Kindly enter the domain FQDN where you wish to install this domain controller"
 $DomainCheck = $domains -contains $DomainName
    If ($DomainCheck -eq $false)
        {
         Write-Host `n `n
         Write-Host "Entered domain name is not valid. Kindly Re enter the domain name" -ForegroundColor Yellow
        }
     else
        {
         Write-Host `n `n
         Write-Host "Selected Domain: $DomainName" -ForegroundColor Green
        }
 
}
until ($DomainCheck -eq $true)

############################################################################################################

#2.4 Get site details
Do
{
 Write-Host `n `n
 $SiteName = Read-Host "Kindly enter the AD logical site name where this domain controller will reside"
 $SiteCheck = $Sites -contains $SiteName
    If ($SiteCheck -eq $false)
        {
         Write-Host `n `n
         Write-Host "Entered site name is not valid. Kindly Re enter the domain name" -ForegroundColor Yellow
        }
     else
        {
         Write-Host `n `n
         Write-Host "Selected Site: $SiteName" -ForegroundColor Green
        }
 
}
until ($SiteCheck -eq $true)



############################################################################################################

#2.5 Get user details having permission to promote a domain controller

Do {
    $credPro = Get-Credential -Message "Kindly enter your the credentials having DC promotion rights"

    $CredCheckResult2=verify-ADCredential $credPro.UserName $credPro.GetNetworkCredential().password
     If ($CredCheckResult2 -eq $false)
        {
         Write-Host `n
         Write-Warning "Username or Password is incorrect. Kindly re enter proper credentials"
         Write-Host `n `n
        }
     else
        {
        Write-Host `n
        Write-Host "Password Accepted" -ForegroundColor Green
        Write-Host `n `n
        }
   }
 
 until ($CredCheckResult2 -eq $true)

$InstallCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credPro.UserName, $credPro.Password

############################################################################################################

#2.6 Get DSRM password

$safeModePwd = Read-Host "Enter the DSRM Password" -AsSecureString
 
############################################################################################################

#2.7 Set DB, SYSVOL and Logs path

$DBPath = "C:\windows\NTDS"
$LogPath = "C:\windows\NTDS"
$SYSVOLPath = "C:\windows\SYSVOL"

############################################################################################################


#3.1 Promote a server to domain controller

Install-ADDSDomainController -InstallDns -DomainName $DomainName -Credential $InstallCredential -CreateDnsDelegation -SiteName $SiteName -ReplicationSourceDC $RepSourceDC -DatabasePath $DBPath -LogPath $LogPath -SysvolPath $SYSVOLPath -SafeModeAdministratorPassword $safeModePwd -Confirm