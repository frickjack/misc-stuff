# Powershell profile stuff ...
#---------------------
# Reuben stuff
#--------------------

function prompt() {
	# "`n" == newline
	write-host ("" + $(get-location) ) -nonewline -foregroundcolor gray
	return "`n> "
}

new-item -path alias:fdiff -value C:\cygwin\bin\diff.exe
$GLOBAL:docs = $home + "\Documents"
$GLOBAL:a1 = $docs + "\Code\AuCataloging\WIP\AuCataloging"
$GLOBAL:c1 = $docs + "\Code\nick\WIP\nick\commandLine"
$GLOBAL:e1 = $docs + "\Code\etdFormat\WIP\etdFormat"
$GLOBAL:f1 = $docs + "\Code\webEtdFormat\WIP\webEtdFormat"
$GLOBAL:g1 = "C:\glassfishv3-prelude\glassfish\domains\domain1"
$GLOBAL:l1 = $docs + "\Code\littleware\WIP\littleware\littleware"
$GLOBAL:d1 = $docs + "\Code\littleware\WIP\littleware\littleware"
$GLOBAL:n1 = $docs + "\Code\nick\WIP\nick"
$GLOBAL:nd1 = $docs + "\Code\nick\WIP\nick"
$GLOBAL:p1 = $docs + "\Code\N9nPy\WIP\n9n"
$GLOBAL:r1 = $docs + "\Code\repository"
$GLOBAL:rd1 = $docs + "\Code\n9nCommander\WIP\n9nCommander"
$GLOBAL:w1 = $docs + "\Code\nickweb\WIP\nickweb"
$GLOBAL:trash = $Env:TEMP
$Env:CYGWIN = "nodosfilewarning"

#$Env:path = $Env:path + ";C:\Program Files\Microsoft Platform SDK for Windows Server 2003 R2\Bin;C:\Program Files\PuTTY;C:\Program Files\curl-7.19.0"
cd $home
set-alias jtail  "$c1/jtail.bat"
set-alias jpy  "$home/.netbeans/6.8/jython-2.5.1/bin/jpy.bat"
set-alias less "C:/cygwin/bin/less"
set-alias scp "C:/Program Files (x86)/PuTTY/psftp"
set-alias git "C:\Program Files (x86)\Git\bin\git.exe"
set-alias vim "C:\cygwin\bin\vi.exe"
set-alias git "C:\Program Files (x86)\Git\bin\git.exe"
set-alias vim "C:\cygwin\bin\vi.exe"
set-alias mvn "C:\Program Files\NetBeans\7.4\java\maven\bin\mvn.bat"
set-alias mysql "C:\Program Files (x86)\MySQL\MySQL Workbench CE 6.0.8\mysql.exe"
set-alias less "C:\cygwin64\bin\less.exe"
set-alias curl "C:\cygwin64\bin\curl.exe"
set-alias ssh "C:\cygwin64\bin\ssh.exe"
set-alias scp "C:\cygwin64\bin\scp.exe"
set-alias irb "C:\HashiCorp\Vagrant\embedded\bin\irb.bat"
set-alias ruby "C:\HashiCorp\Vagrant\embedded\bin\ruby.bat"

function p4ed( $path ) {
    p4 -c p4cg edit -c default $path
}

function p4add( $path ) {
    p4 -c p4cg add -c default $path
}

function p4diff( $path ) {
    p4 -c p4cg diff -du3 -dw $path
}

function nbs( $path ) {
	& 'C:\Program Files\NetBeans\7.4\bin\netbeans' --console suppress --open $path
}


function vstud( $path ) {
	& 'C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\VWDExpress' $path
}

# uuidgen.exe replacement 
function uuidgen { 
   [guid]::NewGuid().ToString('d') 
}


function jdrive(){
$net = New-Object -com WScript.Network
$net.mapnetworkdrive( 'J:', '\\flagship\cg\CG_Dept' )
}

function rdrive(){
$net = New-Object -com WScript.Network
$net.mapnetworkdrive( 'R:', '\\flagship\cg\RnD' )
}

function recycle( $path ) {
	$clean = resolve-path( $path )
	$item = $shell.Namespace(0).ParseName( $clean )
	$item.InvokeVerb("delete") 
}

function browse( $path ) {
	$clean = resolve-path( $path )
	#echo $clean.path
	$shell.open( $clean.path ) 
}


function df ( $Path ) {
	if ( !$Path ) { $Path = (Get-Location -PSProvider FileSystem).ProviderPath }
	$Drive = (Get-Item $Path).Root -replace "\\"
	$Output = Get-WmiObject -Query "select freespace from win32_logicaldisk where deviceid = `'$drive`'"
	Write-Output "$($Output.FreeSpace / 1mb) MB"
}

function colorMe( $color ) {
    (Get-Host).UI.RawUI.BackgroundColor = $color
}

function docker() {
    ssh -o "ServerAliveInterval=20" -i C:\Users\pasquire\.ssh\id_boot2docker docker@localhost -p 2022;
}



