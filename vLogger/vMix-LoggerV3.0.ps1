
<#
    .SYNOPSIS   
        Tracks content been played in vMix.   
            
    .DESCRIPTION   
        Generates a csv of date / time a graphic gets output to allow durations to be calculated .
            
    .PARAMETER LogFile
        Location to output to
    .PARAMETER vMixUrl
        Location of vMix
            
    .NOTES
        Name: vMix-Logger
        Author: Keith Marston SnE Consulting 07775664324
        Created: 6/7/16
        Modified:
        Version: 1.0
            1.0 - Initial creation
            2.0 - Added logging of overlays and using of array for all inputs
            2.1 - Added detection of FTB
            
            3.0 - Added support for MQTT publishing
                Command line paramters now work
    .EXAMPLE
        
                    
       Description
       -----------
       File format CSV: Input,Title,Input Name,Start,Finish,Duration(Mins)
       
       This is a grate site for MQTT
       http://www.hivemq.com/demos/websocket-client/?

       With MQTT you can search the topics SnE/+/vMix/log/CSV or SnE/+/vMix/log/ch/#
       Second parameter will be the machine name the logger is running on.
       "C:\Program Files (x86)\mosquitto\mosquitto_sub.exe" -h broker.mqttdashboard.com -v -t SnE/+/vMix/log/ch/#


       Known bugs
       ----------

       When launch before vMix the arrays for the overlay channels get in a mess
#>

Param(
    [string]$LogFile = 'vMixLog.csv',
    [string]$vMixIP = '127.0.0.1',
    [string]$broker = 'broker.mqttdashboard.com',
    [string]$TopicPrefix = 'SnE'
)
$vMixURL = "http://$vMixIP`:8088"
$vMixURL

function initalize {

$allInputsTime.Add($(Get-Date))
$allInputs.add($($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.active}))
$vMix.vmix.overlays.overlay | foreach {
    $allInputsTime.Add($(Get-Date))
    
    $tmp = $_.'#text'
    if ($tmp -eq $null) {
        $tmp = 1
        $tmpInput = $($vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp})
        $tmpInput.key = "Blank"
        $tmpInput.title = "Blank"
        $tmpInput.'#text' = "Blank"
        $allInputs.add($tmpInput)
        } 
    else {
        $allInputs.add($($vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp}))
    }

    #Write-Host $tmp is active on overlay
    
    #$vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp}

    }

}

function Add-MQTT {
    Param($Topic)
    if ($output -eq $null) {$output = "Blank"}
    if (test-path "C:\Program Files (x86)\mosquitto\mosquitto_pub.exe") {
        if ($Topic -eq $null) {
            & "C:\Program Files (x86)\mosquitto\mosquitto_pub.exe" -h $broker -t $TopicPrefix/$env:computername/vMix/log -m $output
        } else {
            & "C:\Program Files (x86)\mosquitto\mosquitto_pub.exe" -h $broker -t $TopicPrefix/$env:computername/vMix/log/$Topic -m $output
        }
    }
    
}



$allInputsTime = New-Object System.Collections.ArrayList
$allInputs = New-Object System.Collections.ArrayList

#if (Test-Path ($LogFile)) {} Else {
    #Input,Title,Input Name,Start,Finish,Duration(Mins)
    $output = "`"Layer`",`"Title`",`"Input Name`",`"Start Time`",`"Finish Time`",`"Minutes`""
    $output
    Add-Content $LogFile $output       
#} 
#[console]::beep(2000,500)
$Webclient = new-object net.webclient 
$Webclient.UseDefaultCredentials = $True
$vMix = [xml]$Webclient.DownloadString("$($vMixUrl)/API?")


initalize



$loop = $true
while ($loop) {
    $vMix = [xml]$Webclient.DownloadString("$($vMixUrl)/API?")
    #$vMix.vmix.fadeToBlack
    if ($vMix.vmix.fadeToBlack -eq $True) {
        Write-Host "We are on FTB..."
        $allInputsTime = New-Object System.Collections.ArrayList
        $allInputs = New-Object System.Collections.ArrayList
        initalize
    } else {
        #First do PGM out
        if ($(($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.active}).'#text') -ne $($allInputs[0].'#text')) {
            write-host "Active changed"
            Write-Host "Started at $($allInputsTime[0].ToString()) for duration of $( ($(Get-Date) - $allInputsTime[0]).TotalMinutes)"
 
            #Input,Title,Input Name,Start,Finish,Duration(Mins)
            $output = "`"PGM`",`"$($allInputs[0].title)`",`"$($allInputs[0].'#text')`",`"$($allInputsTime[0].ToString())`",`"$(get-date)`",`"$($($(Get-Date) - $allInputsTime[0]).TotalMinutes)`""
            $output
        
            Add-Content $LogFile $output
            Add-MQTT("CSV") 
            $output = $(($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.active}).'#text')
            Add-MQTT("ch/PGM")
            
            $allInputsTime[0] = Get-Date
            #$activeThen = $vMix.vmix.active
            $allInputs[0] = $($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.active})
        } #END PGM OUT  

        #$($allInputs.Count -1)
        for ($i=1 
        $i -le $($allInputs.Count -1)
        $i++) {
            if ($(($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.overlays.overlay[$i-1].'#text'}).'#text') -ne $($allInputs[$i].'#text')) {
                write-host "Active changed on Overlay $i"
                Write-Host "Started at $($allInputsTime[$i].ToString()) for duration of $( ($(Get-Date) - $allInputsTime[$i]).TotalMinutes)"
 
                #Input,Title,Input Name,Start,Finish,Duration(Mins)
                $output = "`"OVRLAY $i`",`"$($allInputs[$i].title)`",`"$($allInputs[$i].'#text')`",`"$($allInputsTime[$i].ToString())`",`"$(get-date)`",`"$($($(Get-Date) - $allInputsTime[$i]).TotalMinutes)`""
                $output
                Add-Content $LogFile $output
                Add-MQTT("CSV")
                $output = $(($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.overlays.overlay[$i-1].'#text'}).'#text')
                Add-MQTT("ch/$i")
            
                $allInputsTime[$i] = Get-Date
                #$activeThen = $vMix.vmix.active
                $allInputs[$i] = $($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.overlays.overlay[$i-1].'#text'})
            }
        } #End the overlay loop
    }
}





