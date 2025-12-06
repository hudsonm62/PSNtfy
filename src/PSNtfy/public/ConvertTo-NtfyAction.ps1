<#
.SYNOPSIS
    Helper to build a Ntfy Action string

.DESCRIPTION
    Helps build a Ntfy "simple format" action string for use with Send-NtfyPush or directly with ntfy.sh.
.PARAMETER View
    Specifies a "view" action type.
.PARAMETER Broadcast
    Specifies a "broadcast" action type.
.PARAMETER Http
    Specifies an "http" action type.
.PARAMETER Label
    The label for the action button.
.PARAMETER Url
    The URL to open (for view and http actions).
.PARAMETER Intent
    Android Intent name (for broadcast actions).
    "io.heckel.ntfy.USER_ACTION" as Ntfy.sh default.
.PARAMETER Extras
    Extras to include with the broadcast (for broadcast actions).
    Use the format "key=value" as per ntfy.sh documentation. Will be prefixed with "extras." automatically so only provide the key and value.
.PARAMETER Method
    The HTTP method to use (for http actions). Defaults to POST as per ntfy.sh documentation.
.PARAMETER Headers
    Headers to include with the HTTP request (for http actions).
    Use the format "key=value" as per ntfy.sh documentation. Will be prefixed with "headers." automatically so only provide the key and value.
.PARAMETER Body
    The body to include with the HTTP request (for http actions).
.PARAMETER Clear
    Whether to clear the notification when the action is taken. Defaults to $false and always included in the output regardless of value.
.LINK
    https://docs.ntfy.sh/publish/#action-buttons
.EXAMPLE
    ConvertTo-NtfyAction -View -Label "Open Website" -Url "https://example.com" -Clear

    Produces the string: "view, Open Website, https://example.com, clear=true"
.EXAMPLE
    ConvertTo-NtfyAction -Http -Label "Send Data" -Url "https://api.example.com/endpoint" -Method "POST" -Headers "Some=Value","Another=Header" -Body '{"data":"value"}'

    Produces the string: "http, Send Data, https://api.example.com/endpoint, POST, headers.Some=Value, headers.Another=Header, {"data":"value"}, clear=false"
#>
function ConvertTo-NtfyAction {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'parameter sets for switches')]
    [Alias('ctn')]
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param (
        # Action type switches
        [Parameter(Mandatory = $true, ParameterSetName = 'View')]
        [switch]$View,

        [Parameter(Mandatory = $true, ParameterSetName = 'Broadcast')]
        [switch]$Broadcast,

        [Parameter(Mandatory = $true, ParameterSetName = 'Http')]
        [switch]$Http,

        # Common
        [Parameter(Mandatory = $true, ParameterSetName = 'View')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Broadcast')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Http')]
        [string]$Label,

        # view + http require URL
        [Parameter(Mandatory = $true, ParameterSetName = 'View')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Http')]
        [string]$Url,

        # broadcast-only
        [Parameter(ParameterSetName = 'Broadcast')]
        [string]$Intent,

        [Parameter(ParameterSetName = 'Broadcast')]
        [string[]]$Extras,

        # http-only
        [Parameter(ParameterSetName = 'Http')]
        [ValidateSet('GET','POST','PUT','DELETE','PATCH','HEAD','OPTIONS')]
        [string]$Method,

        [Parameter(ParameterSetName = 'Http')]
        [string[]]$Headers,

        [Parameter(ParameterSetName = 'Http')]
        [string]$Body,

        # common optional
        [Parameter(ParameterSetName = 'View')]
        [Parameter(ParameterSetName = 'Broadcast')]
        [Parameter(ParameterSetName = 'Http')]
        [switch]$Clear = $false
    )
    try {
        $ClearString = "clear=$($Clear.ToString().ToLower())"
        Write-Verbose "Building Ntfy Action string for Action type '$($PSCmdlet.ParameterSetName.ToLowerInvariant())'"
        $return = switch ($PSCmdlet.ParameterSetName) {
            'View' {
                "view, $Label, $Url, $ClearString"
            }
            'Broadcast' {
                $string = "broadcast, $Label"
                if ($Intent) { $string += ", $Intent" }
                if ($Extras) { $string += ", extras." + ($Extras -join ', extras.') }
                "$string, $ClearString"
            }
            'Http' {
                $string = "http, $Label, $Url"
                if ($Method) { $string += ", method=$($Method.ToUpperInvariant())" }
                if ($Headers) { $string += ", headers." + ($Headers -join ', headers.') }
                if ($Body) { $string += ", $Body" }
                "$string, $ClearString"
            }
            default {
                throw "Unknown or missing Action."
            }
        }
    } catch {
        Write-TerminatingError -Exception $_.Exception `
            -Message "Failed to construct Ntfy Action string." `
            -Category InvalidOperation `
            -ErrorId "Ntfy.ActionStringConstructionError"
    }

    Write-Verbose "Successfully built Ntfy Action string."
    Write-Debug "Final Action string: $return"
    return $return
}
Set-Alias -Name ctn -Value ConvertTo-NtfyAction
