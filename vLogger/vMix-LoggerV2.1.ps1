
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
            

    .EXAMPLE
        
                    
        Description
        -----------
       File format CSV: Input,Title,Input Name,Start,Finish,Duration(Mins)
#>

function initalize {

$allInputsTime.Add($(Get-Date))
$allInputs.add($($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.active}))
$vMix.vmix.overlays.overlay | foreach {
    $allInputsTime.Add($(Get-Date))
    
    $tmp = $_.'#text'
    if ($tmp -eq $null) {
        $tmp = 1
        $tmpInput = $($vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp})
        $tmpInput.key = "None"
        $tmpInput.title = "None"
        $tmpInput.'#text' = "None"
        $allInputs.add($tmpInput)
        } 
    else {
        $allInputs.add($($vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp}))
    }

    #Write-Host $tmp is active on overlay
    
    #$vMix.vmix.inputs.input | Where-Object {$_.number -eq $tmp}

    }

}

$LogFile='testvMixLog.csv'
$vMixUrl='http://127.0.0.1:8088'

$allInputsTime = New-Object System.Collections.ArrayList
$allInputs = New-Object System.Collections.ArrayList

#if (Test-Path ($LogFile)) {} Else {
    #Input,Title,Input Name,Start,Finish,Duration(Mins)
    $output = "`"Layer`",`"Title`",`"Input Name`",`"Start Time`",`"Finish Time`",`"Minutes`""
    $output
    Add-Content $LogFile $output       
#} 
[console]::beep(2000,500)
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
            
                $allInputsTime[$i] = Get-Date
                #$activeThen = $vMix.vmix.active
                $allInputs[$i] = $($vMix.vmix.inputs.input | Where-Object {$_.number -eq $vMix.vmix.overlays.overlay[$i-1].'#text'})
            }
        } #End the overlay loop
    }
}





