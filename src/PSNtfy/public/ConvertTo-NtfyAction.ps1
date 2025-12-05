<#
.SYNOPSIS
    Helper to build a Ntfy Action string

.EXAMPLE
    $1 = ConvertTo-NtfyAction @splat1
    $2 = ConvertTo-NtfyAction @splat2
    Send-NtfyPush @PushSplat -Actions $1,$2

.EXAMPLE
    $1 = ConvertTo-NtfyAction @splat1
    $2 = ConvertTo-NtfyAction @splat2
    Send-NtfyPush @PushSplat -Actions ($1,$2 -join ';')
#>
function ConvertTo-NtfyAction {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("view","broadcast","http")]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$URL,

        [Parameter()]
        [switch]$Clear = $false
    )

    # make string
    return "$Action, $Label, $URL, $Clear"
}
