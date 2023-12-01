[CmdletBinding()]
param(
    [Switch]$ShowVersion,
    [String]$Division,
    [Switch]$NoRestorePoints,
    [String]$hostname,
    [int]$port,
    [String]$scaleType,
    [String]$ssid="SM-IoT",
    [String]$psk,
    [Switch]$Force
    )
Import-Module .\functions.psm1
. .\variables.ps1 #importerar variabler
$OutputEncoding = [ System.Text.Encoding]::UTF8


PrintInfo
if ($ShowVersion)
{
    return
}



if($Division -notin $divisions)
{
    Write-Host "Ej giltig avdelning, välj ny"
    $division = ""
    return
}

if($division -eq "")
{
    for($i = 0; $i -lt $divisions.Length; $i++)
    {
        Write-Host $i $divisions[$i]
    }
    $index = 0
    $inputValid = [int]::TryParse((Read-Host "Välj läge 0 -"($divisions.Length-1)),[ref] $index)
    if(-not $inputValid -or $index -lt 0 -or $index -ge $divisions.Length) {
        throw "Ej giltigt val av avdelning, avdelningsnummret ska vara mellan 0 och $i"
        return
    }
    $division = $divisions[$index]
}



#$createRestorePoints = Read-Host "Vill du skapa återställningspunkter? (y/N)"
if(-not $NoRestorePoints) {
    EnableRestoration
    CreateRestorePoint("Före installation")
}
CopyFiles -Force:$Force
ConfigureNetwork -ssid $ssid -psk $psk
SetComputerName
ConfigureBGInfo -VersionString ($division.ToLower().PadLeft(3))
InstallChrome -Force:$Force
InstallVnc -Force:$Force
if($division -notin @("TMS","PRD"))
{
    InstallMPS -Force:$Force
    if($scaleType -eq "" -or $scaleType -notin $scaleTypes)
    {
        while($True)
        {
            for($i = 0; $i -lt $scaleTypes.Length; $i++)
            {
                Write-Host $i $scaleTypes[$i]
            }
            $si = 0
            $inputValid = [int]::TryParse((Read-Host "Välj vågtyp 0 -"($scaleTypes.Length-1)),[ref] $si)
            if(-not $inputValid -or $si -lt 0 -or $si -ge $scaleTypes.Length) {
                throw "Ej giltigt val av våg"
                continue
            }
            $scaleType = $scaleTypes[$si]
            break
        }
    }
    
    #om hostname har matats in med argument ska vi inte ändra det
    if($hostname -eq "")
    {
        if($hostnameLookup.ContainsKey($division))
        {
            $hostname = $hostnameLookup[$division]
            $port = $portLookup[$division]
            write-host "Hostname för $division är $hostname"
        }
        else {
            #default hostname och port
            $hostname = "127.0.0.1"
            $port = 80 
        }
    }
    write-host "Hostname blir $hostname"
    $configText = @"
        INTERFACE=AUTO
        ENCODING=ASCII
        BAUDRATE=9600
        DEV=False
        SCALESIMULATOR=False
        MANUFACTURER=$scaleType
        JSON=True
        JSONPATH=C:\AITECH\weight.json
        MYSQL=False
        DBNAME=$($Division.ToLower())
        DBUSER=root
        DBPASS=
        HTTPSERVER=True
        HOSTNAME=$hostname
        PORT=$port
        DEBUG=False
"@
    if($hostname -ne "127.0.0.1")
    {
        write-host "Sätter hostname till $hostname"
        AddHost -Hostname $hostname
    }
    netsh http add urlacl url="http://$($hostname):$port/" user=$env:computername\Admin
    ConfigureMPS -ConfigText $configText
    InstallFTDI
    GenerateChromeAutostart -division $division
    #FixStartLayout -Division $division
    #FixTaskbar
    #PromptUnsecureContent
    ConfigureChrome
}
else 
{
    if($division -eq "TMS")
    {
        InstallTeams -Force:$Force
    }
    #annars PRD, vilken är generisk platta med endast chrome
    #FixStartLayout -Division $division
    #FixTaskbar
}
FixStartLayout -Division $division
FixTaskbar
SetEnergyOptions
ConfigureAutostart -Division $division
ConfigureBGInfo -VersionString ($division.ToUpper().PadLeft(3))
SetInstallInfo -Division $division
if(-not $NoRestorePoints) {
    CreateRestorePoint("Efter installation")
}
Write-Host "Färdig!`nNu blir Lasse glad!"
PromptRestart