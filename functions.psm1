. .\variables.ps1 #importerar variabler
$OutputEncoding = [System.Text.Encoding]::UTF8




function PrintInfo {
    Write-Host "-----Surface Configurator-----`n`tTor Smedberg MMXXIII`n"
    Write-Host "Version $version"
    Write-Host "Chrome från $((Get-ChildItem -Path .\files\$ChromeSetupName).LastWriteTime.ToString('yyyy-MM-dd'))"
    Write-Host "Teams från $((Get-ChildItem -Path .\files\$TeamsSetupName).LastWriteTime.ToString('yyyy-MM-dd'))"
    Write-Host "tightvnc från $((Get-ChildItem -Path .\files\$VncSetupName).LastWriteTime.ToString('yyyy-MM-dd'))"
}

function EnableRestoration {
    # gör så att återställningspunkter kan skapas hur ofta som helst
    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0  -PropertyType "DWORD"
    # aktiverar återrställning
    Enable-ComputerRestore C:
}

function CreateRestorePoint($desc) {
    Write-Host "Skapar återställningspunkt..."
    Checkpoint-Computer -Description $desc -RestorePointType APPLICATION_INSTALL
}
function CopyFiles {
    param (
        [Switch]$Force
    )
    #Remove-Item ger error ifall inte filpathen finns
    if(-not (Test-Path -Path C:\Stena){
	New-Item -Path 'C:\Stena' -ItemType Directory
    }


    Write-Host "Kopierar filer...`nBGInfo"
    if(-not $Force -and (Test-Path -Path C:\Stena)) {
        Write-Host "Filer i C:\Stena finns redan, om du fortsätter tas dessa bort"
        Remove-Item -Confirm -Path C:\Stena -Recurse
    }
    if($Force)
    {
        Remove-Item -Force -Path C:\Stena -Recurse
    }
    Copy-Item .\copy\ C:\Stena -Recurse -ErrorAction Stop
}
function ConfigureNetwork {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $ssid,
        [String]$psk
    )
    Write-Host "Konfigurerar nätverk..."
    <# netsh wlan add filter permission=allow ssid=$ssid networktype=infrastructure
    netsh wlan add filter permission=denyall networktype=infrastructure #>
    foreach ($bs in $blockedSSIDs)
    {
        netsh wlan add filter permission=block ssid="$bs" networktype="infrastructure"
    }
    #Write-Host "Koppla upp mot $ssid manuellt..."
    while (-not (Test-Connection -ComputerName $testDomain -Quiet))
    {
        if($psk.Length -eq 0)
        {
            $ss = Read-Host -AsSecureString "Skriv in lösenordet för $ssid"
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
            $psk = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
        $guid = New-Guid
        $HexArray = $ssid.ToCharArray() | foreach-object { [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($_)) }
        $HexSSID = $HexArray -join ""
@"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
	<name>$($SSID)</name>
	<SSIDConfig>
		<SSID>
			<hex>$($HexSSID)</hex>
			<name>$($SSID)</name>
		</SSID>
	</SSIDConfig>
	<connectionType>ESS</connectionType>
	<connectionMode>auto</connectionMode>
	<MSM>
		<security>
			<authEncryption>
				<authentication>WPA2PSK</authentication>
				<encryption>AES</encryption>
				<useOneX>false</useOneX>
			</authEncryption>
			<sharedKey>
				<keyType>passPhrase</keyType>
				<protected>false</protected>
				<keyMaterial>$($PSK)</keyMaterial>
			</sharedKey>
		</security>
	</MSM>
	<MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
		<enableRandomization>false</enableRandomization>
		<randomizationSeed>1451755948</randomizationSeed>
	</MacRandomization>
</WLANProfile>
"@ | out-file "$($ENV:TEMP)\$guid.SSID"

        Write-Host "Ansluter till $ssid..."

        netsh wlan add profile filename="$($ENV:TEMP)\$guid.SSID"
        #netsh wlan connect name="$ssid"
        Write-Host "Sover i 10 sekunder"
        Start-Sleep -Seconds 10

        remove-item "$($ENV:TEMP)\$guid.SSID" -Force


        #netsh wlan connect ssid=$ssid key=$pw
        #netsh wlan add profile filename="$($ENV:TEMP)\$guid.SSID"
        #remove-item "$($ENV:TEMP)\$guid.SSID" -force
        $psk = ""
    }
}
function ConfigureBGInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $VersionString
    )
    Write-Host "Konfigurerar bginfo..."
    $bytes = Get-Content C:\Stena\bgconfig.bgi -Encoding Byte -ReadCount 0

    #Convert the bytes to hex
    $hexString = [System.BitConverter]::ToString($bytes)
    $enc = [system.Text.Encoding]::ASCII
    #$string1 = "Version $version "+($division.PadLeft(3)) 
    $VersionString = "Version $version $versionString"
    if($VersionString.Length -ne 16) {
        throw "Versionstexten måste vara 16 karaktärer lång"
    }
    $data1 = $enc.GetBytes($VersionString)
    $hx = ($data1|ForEach-Object ToString X2) -join '-'
    Write-Host $hx
    $newHexString = $hexString -replace '56-65-72-73-69-6F-6E-20-[a-fA-F0-9-]{11}-20-[a-fA-F0-9-]{8}',$hx

    #Convert the hex back to bytes
    $newBytes = $newHexString.Split('-') | foreach {[byte]::Parse($_, 'hex')}
    #Update the contents of the file
    $newBytes | Set-Content C:\Stena\bgconfig.bgi -Encoding Byte
    #run bginfo
    C:\Stena\BGInfo\Bginfo64.exe C:\Stena\bgconfig.bgi /silent /timer:0 /nolicprompt
}

function InstallChrome {
    param (
        [Switch]$Force
    )
    Write-Host "Installerar Google Chrome..."
    $continue = "n"
    if(-not $Force -and (Test-Path -Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
        $continue = Read-Host "Google chrome är redan installerat, vill du intstallera det igen? (y/N)"
    }
    else {
        $continue = "y"
    }
    if($continue -eq "y") {
        Start-Process -Wait -FilePath .\files\$ChromeSetupName -ArgumentList "/install"
    }
    else {
        Write-Host "Skippar Chrome..."
    }
}
function AddHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Hostname
    )
    Write-Host "Lägger till '127.0.0.1	$Hostname' i hosts-filen"
    if((Get-Content C:\Windows\System32\Drivers\Etc\hosts | Select-String -Pattern $hostname).Matches) {
        Write-Host "$hostname finns redan"
    }
    else {
        Add-Content C:\Windows\System32\Drivers\Etc\hosts "`n127.0.0.1	$hostname"
    }
}



function InstallMPS {
    param (
        [Switch]$Force
    )
    $continue = "n"
    if(-not $Force -and (Test-Path -Path C:\AITECH)) {
        Write-Host "Filer i C:\AITECH finns redan, om du fortsätter tas dessa bort"
        $continue = Read-Host "Vill du fortsätta installera AITECH? (y/N)"
    }
    else {
        $continue = "y"
    }
    if($continue -eq "y") {
        Write-Host "Konfigurerar AITECH...`nSkapar mapp..."
        New-Item C:\AITECH\mps -ItemType Directory -Force
        Write-Host "Extraherar filer..."
        Expand-Archive -Force .\files\MPS.zip C:\AITECH\mps
        Write-Host "Lägger till portreservation..."
        netsh http add urlacl url=http://127.0.0.1:80/ user=$env:computername\Admin
        Write-host "Skapar weight-fil"
        New-Item -Path C:\AITECH\weight.json -force
        <# Write-Host "Flyttar filer till rätt plats..."
        Copy-Item -Recurse C:\AITECH\mps\software\* C:\AITECH\mps -Force
        Write-Host "Städar upp..."
        Remove-Item -Recurse C:\AITECH\mps\software #>
    }
    else {
        Write-Host "Skippar AITECH..."
    }
}
function ConfigureMPS {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $configText
    )
    Write-Host "Konfigurerar MPS..."
    
    Out-File -Force -FilePath C:\AITECH\mps\MPS-COM.conf -InputObject $configText

}



function FindAndReplace {
    param (
    [string]$path,
    [string]$search,
    [string]$replace
    )
    (Get-Content $path) -replace $search, $replace | Set-Content $path
}

function InstallVnc {
    param (
        [Switch]$Force
    )
    Write-Host "Installerar TightVNC..."
    #Write-Host "Välj Anpassad installation, och markera endast server`nAnge `"access password`" till `"stena`" utan citationstecken.Ange `"admin password`" till `"aitech`" utan citationstecken."
    $continue = "n"
    if(-not $Force -and (Test-Path -Path "C:\Program Files\TightVNC\tvnserver.exe")) {
        $continue = Read-Host "Tightvnc är redan installerat, vill du intstallera det igen? (y/N)"
    }
    else {
        $continue = "y"
    }
    if($continue -eq "y") {
        #Read-Host "Tryck enter för att starta installationen"
        #Start-Process msiexec.exe -Wait -ArgumentList "/i $PWD\files\tightvnc.msi /norestart"
        Start-Process msiexec.exe -Wait -ArgumentList "/i $PWD\files\tightvnc.msi /norestart /quiet ADDLOCAL=Server SET_USEVNCAUTHENTICATION=1 VALUE_OF_USEVNCAUTHENTICATION=1 SET_PASSWORD=1 VALUE_OF_PASSWORD=stena SET_USECONTROLAUTHENTICATION=1 VALUE_OF_USECONTROLAUTHENTICATION=1 SET_CONTROLPASSWORD=1 VALUE_OF_CONTROLPASSWORD=aitech"
    }
    else {
        Write-Host "Skippar Tightvnc..."
    }
    
}

function SetEnergyOptions {
    Write-Host "Ändrar energi-alternativ..."
    # ac är nätadapter, dc är batteri
    powercfg /change standby-timeout-ac 120
    powercfg /change standby-timeout-dc 60
    return
}

function ConfigureAutostart {
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Division
    )
    Write-Host "Konfigurerar autostart (gemensam)..."
    Copy-Item -Recurse -Force .\shortcuts\common\* "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"
    if (Test-Path -Path .\shortcuts\$Division)
    {
        Write-Host "Konfigurerar autostart... ($Division)"
        Copy-Item -Recurse -Force .\shortcuts\$Division\* "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"

    }
    else {
        Write-Host "Det fanns inga specifika genvägar för $Division"
    }
    return
}
function GenerateChromeAutostart {
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Division
        )
    write-host "skapar autostart genväg för Chrome"
    if(-not $mpsDomainLookup.ContainsKey($Division))
    {
        throw "$division fanns inte med i listan över domäner"
    }
    $domain = "$($mpsDomainLookup[$division]).mps.nu"
    write-host "$Division får domänen $domain!!!!"
    $sh = New-Object -comObject WScript.Shell
    $Shortcut = $sh.CreateShortcut("$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Chrome.lnk")
    $Shortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    $Shortcut.Arguments = "https://$domain/client.php https://pikup.se" #när genvägen körs öppnas två flikar, mps och pikup
    $Shortcut.IconLocation = "shell32.dll,208" #ikon blir en stjärna
    $Shortcut.Save()
}

function FixStartLayout {
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Division
    )
    $Division = $layoutLookup[$Division]
    Write-Host "Får layouten $Division"
    Write-Host "Ändrar om aktivitetsfältet..."
    Import-StartLayout -LayoutPath ".\layouts\StartLayout-$Division.xml" -MountPath C:\ #kopierar layouten på aktivitetsfältet
}
function FixTaskbar {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Value 0 #inaktiverar cortana
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 #inaktiverar aktivitetsvy
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2 #inaktiverar nyheter och intressen
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchBoxTaskbarMode" -Value 0 #inaktiverar sökrutan
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace" -Name "PenWorkspaceButtonDesiredVisibility" -Value 0 #tar bort penn-läge
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" -Name "TipbandDesiredVisibility" -Value 1 #visar knappen skärmtangentbord
    if(-Not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    }
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1 -PropertyType "DWORD" -Force #tar bort möte nu-knappen
    Stop-Process -Name explorer -Force #utforskaren måste startas om för att att ändringarna ska visas
}
function InstallFTDI {
    Write-Host "Installerar FTDI-Drivrutiner..."
    Start-Process -Wait -FilePath .\files\ftdi\Setup.exe
}

function SetComputerName {
    $mac = (Get-CimInstance win32_networkadapterconfiguration | Where-Object -FilterScript {$null -ne $_.IPAddress}).macaddress
    if ($null -eq $mac)
    {
        ipconfig.exe /all
        Write-Error "Mac-addressen för datorn kunde inte hittas, skippar att sätta namn.`novan finns information om nätverkskorten"
        return
    }
    
    $name = "PT-"+($mac.Substring(12) -replace ":", "")
    Write-host "Byter datornamn till $name..."
    
    #Ifall redan datorn heter namnet, Rename-Computer ger error ifall den ska byta namn till namnet datorn redan är
    if($name -eq $env:computername){
        Write-host "Datorn heter redan $name, skippar steget"
        return
    }
    Rename-Computer -NewName $name
    Write-Host "Datornamnet är ändrat"
}

function InstallTeams {
    param (
        [Switch]$Force
    )
    Write-Host "Installerar Microsoft Teams..."
    $continue = "n"
    if(-not $Force -and (Test-Path -Path $env:LOCALAPPDATA\Microsoft\Teams)) {
        $continue = Read-Host "Teams är redan installerat, vill du intstallera det igen? (y/N)"
    }
    else {
        $continue = "y"
    }
    if($continue -eq "y") {
        Start-Process -Wait -FilePath .\files\$TeamsSetupName -ArgumentList "-s"
    }
    else {
        Write-Host "Skippar Teams..."
    }
}

function SetInstallInfo
{
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Division
    )
    $jsonData = @"
{
    "version":$version,
    "division":"$Division",
}
"@
    Out-File -FilePath C:\Stena\installInfo.json -InputObject $jsonData
}

function PromptRestart()
{
    Write-host "Plattan måste startas om (stänga av funkar inte) för att namnbytet ska börja gälla.`nTryck på enter för att starta om"
    Read-Host
    shutdown /r /t 0
}
<# function PromptUnsecureContent {
    Write-Host "Öppna mps-sidan, klicka på hänglåset i addressfältet, sedan webbplatsinställningar. Scrolla ned till `"Osäkert innehåll`" och ändra till `"Tillåt`"`nTryck valfri tangent för att fortsätta"
    Read-host
} #>
function ConfigureChrome {
    New-Item -Path "HKLM:Software\Policies\Google\Chrome\InsecureContentAllowedForUrls" -Force
    New-ItemProperty -Path "HKLM:Software\Policies\Google\Chrome\InsecureContentAllowedForUrls" -Type String -Name 1 -Value "*://[*.]mps.nu/client.php"
    New-ItemProperty -Path "HKLM:Software\Policies\Google\Chrome\" -Name PasswordManagerEnabled -Type DWORD -Value 0
    New-ItemProperty -Path "HKLM:Software\Policies\Google\Chrome\" -Name FullscreenAllowed -Type DWORD -Value 0
    New-ItemProperty -Path "HKLM:Software\Policies\Google\Chrome\" -Name DefaultBrowserSettingEnabled -Type DWORD -Value 1
}