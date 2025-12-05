<#
.SYNOPSIS
    Helper to convert a Ntfy Action to an Object, usually for JSON processing.
#>
function ConvertFrom-NtfyAction {
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ActionString
    )
    process {
        $Keys = ($ActionString -split ',').Trim()
        $result = @{
            Action = $Keys[0]
            Label  = $Keys[1]
            URL    = $Keys[2]
        }

        if($null -ne $Keys[3]){
            [bool]$ToBool = [bool]::Parse($Keys[3] -replace 'clear=') # Convert to bool type
            $result.Add('Clear', $ToBool)
        }

        return $result
    }
}
