<#
.SYNOPSIS
    Throws a fully formed terminating error.
.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.cmdlet.throwterminatingerror
#>
function Write-TerminatingError {
    param (
        [Exception]$Exception,
        [string]$Message,
        [System.Management.Automation.ErrorCategory]$Category,
        [string]$ErrorId
    )
    $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception,$ErrorId,$Category,$null)
    $ErrorRecord.ErrorDetails = $Message
    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
}
