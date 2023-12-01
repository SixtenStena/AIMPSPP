# 1.00
## inte första versionen på riktigt
* Visa knappen pektangentbord
* Visar version och avdelning i bginfo

# 1.10
* Startar om datorn i slutet
* avdelning är gemener när skriptet startas, och ändrar till versaler när skriptet har kört färdigt
* läge för pmr

# 1.15
* Teamsplattor
# 2.00
* Ombyggd för ny version av MPS-programmet
* Lade till verktyg för borttagning av WIFI-filtret `.\removewifiblock.ps1`
# 2.20
* Chrome säkerhetsalternativ sköts automatiskt
* Vnc installeras automatiskt
* Wifi-lösenord skrivs in i terminalen
* många andra saker
# 2.30
* Funkar nu med FT (iprincip likadan som PMR)
* Nu kollar SetComputerName så att inte man har samma namn som man ska byta till innan den byter (Rename-computer ger error om namnet man ska ändra till är samma som det man har på datorn)
* IoT är nu standard wifi istället för SM-Byod, SM-BYOD är nu med i wifi filtret istället
* Ifall man knappar in fel division från början har man nu chans att ändra det