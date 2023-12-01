$version = "2.30"
$divisions = @("NF", "PMR", "FT", "TMS", "PRD")
$scaleTypes = @("Lundaman", "ScanVaegt", "ScanLoad")
#domän som används för att testa internetanslutningen under installationen
$testDomain = "mps.nu"
#vilket hostname som mps.nu kommunicerar med lokalt
$hostnameLookup = @{
    "pmr"="127.0.0.1"
    "ft"="127.0.0.1"
    "nf"="nf-api.local"
}
#vilken port som används till ovanstående hostname
$portLookup = @{
    "pmr"=80
    "ft"=80
    "nf"=8080
}
#vad installationsprogrammen heter, ligger i mappen files.
$ChromeSetupName = "ChromeSetup.exe"
$TeamsSetupName = "TeamsSetup_c_w_.exe"
$VncSetupName = "tightvnc.msi"
#vilka ssid:n surfacen inte kan se eller ansluta till
$blockedSSIDs = @("SM01","SM Guest", "SM-Mobile", "SM-Info","SM-Innovation","SM04","SMILE","SM-SCEP","SM-REUSE","SM-P01")
#används för att sätta domän på mps, t.ex. nf ger nf.mps.nu
$mpsDomainLookup = @{
    "nf"="nf"
    "pmr"="pmr"
    "elp"="plastic"
    "ft"="pmr"
    "ldpe"="ldpe"
    "lanna(???)"="lanna"
}
#vilka avdelningar som ska ha vilka layouter på aktivitetsfältet.
$layoutLookup = @{
    "nf"="nf"
    "pmr"="nf"
    "ft"="nf"
    "tms"="prd"
    "prd"="prd"
}
<# $defaultScaleLookup = @{
    "nf"="nf"
    "pmr"="nf"
    "ft"="nf"
} #>