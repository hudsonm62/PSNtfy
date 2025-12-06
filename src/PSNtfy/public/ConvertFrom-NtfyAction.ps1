<#
.SYNOPSIS
    Helper to convert a Ntfy Action to an Object, usually for JSON processing.
.DESCRIPTION
    Converts a Ntfy "simple format" action string into a Hashtable for easier or further JSON processing.
.PARAMETER ActionString
    Simple format Ntfy Action string to convert.
.LINK
    https://docs.ntfy.sh/publish/#action-buttons
#>
function ConvertFrom-NtfyAction {
    [Alias('cfn')]
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ActionString
    )
    begin {
        function Convert-ClearStringToBool {
            param ([string]$In)
            return [bool]::Parse($In -replace 'clear=')
        }
        function Get-KeyValueString {
            param ([string]$In, [string]$Prefix)
            $KeyValue = $In -replace "^$Prefix\.", ''
            $name, $value = $KeyValue -split '=', 2
            return @($name, $value)
        }
    }
    process {
        $Keys = ($ActionString -split ',').Trim()

        # Determine action type (first element - view/broadcast/http)
        $ActionType = $Keys[0]
        $Hashtable = @{}

        Add-ObjectPropSafe -Object $Hashtable -Key 'ActionType' -Value $ActionType
        Add-ObjectPropSafe -Object $Hashtable -Key 'Label' -Value $Keys[1] # Label is the only common/required field

        try {
            Write-Verbose "Parsing '$ActionType' action type"
            switch ($ActionType) {
                'view' {
                    # view is simple, only Label, Url, Clear
                    $Hashtable.Label = $Keys[1]
                    $Hashtable.Url = $Keys[2]
                    if($Keys[3]) { $Hashtable.Clear = Convert-ClearStringToBool -In $Keys[3] }
                }
                'broadcast' {
                    # broadcast, Label, optional Intent, optional Extras.*, Clear
                    # Process parts (if any)
                    if ($Keys.Count -gt 2) { <# NOTE- Keys[2] is extras onwards #>
                        foreach ($part in $Keys[2..($Keys.Count - 1)]) {
                            # Process Each "key part"
                            if ($part -like 'extras.*=*') {
                                Write-Verbose "Processing extras part: $part"
                                # extras.one=2  ->  Extras["one"] = "2"
                                $name, $value = Get-KeyValueString -In $part -Prefix 'extras'
                                if (-not $Hashtable.Extras) { $Hashtable.Extras = @{} }
                                Add-ObjectPropSafe -Object $Hashtable.Extras -Key $name -Value $value
                            } elseif ($part -like 'clear=*') {
                                Write-Verbose "Processing clear part: $part"
                                $Hashtable.Clear = Convert-ClearStringToBool -In $part
                            } else {
                                Write-Verbose "Processing intent part: $part"
                                # probably Intent
                                if($Hashtable.Intent) {
                                    throw "Multiple Intent parts detected in ActionString, a potentially malformed string."
                                }
                                $Hashtable.Intent = $part
                            }
                        }
                    }
                }
                'http' {
                    # http, Label, Url, optional Method, optional Headers.*, optional Body, optional Clear
                    $Hashtable.Url = $Keys[2]
                    if ($Keys.Count -gt 3) { <# NOTE- Keys[3] is Method onwards #>
                        foreach ($part in $Keys[3..($Keys.Count - 1)]) {
                            # Process Each "key part"
                            if ($part -like 'headers.*=*') {
                                Write-Verbose "Processing headers part: $part"
                                # headers.one=2  ->  Headers["one"] = "2"
                                $name, $value = Get-KeyValueString -In $part -Prefix 'headers'
                                if (-not $Hashtable.Headers) { $Hashtable.Headers = @{} }
                                Add-ObjectPropSafe -Object $Hashtable.Headers -Key $name -Value $value
                            } elseif ($part -like 'clear=*') {
                                # clear=true/false
                                Write-Verbose "Processing clear part: $part"
                                $Hashtable.Clear = Convert-ClearStringToBool -In $part
                            } elseif ($part -like 'method=*') {
                                # Method
                                Write-Verbose "Processing method part: $part"
                                $MethodType = ($part -replace 'method=')
                                if($MethodType -notmatch '^(get|post|put|delete|patch|head|options)$') {
                                    throw "Invalid 'HTTP' Method '$MethodType' detected in ActionString."
                                }
                                if($Hashtable.Method) {
                                    throw "Multiple method parts detected in ActionString, a potentially malformed string."
                                }
                                $Hashtable.Method = $MethodType
                            } else {
                                Write-Verbose "Processing body part: $part"
                                # probably Body
                                if($Hashtable.Body) {
                                    throw "Multiple body parts detected in ActionString, a potentially malformed string."
                                }
                                $Hashtable.Body = $part
                            }
                        }
                    }
                }
                default {
                    throw "Unknown ActionType '$ActionType' in ActionString."
                }
            }
        } catch {
            Write-TerminatingError -Exception $_.Exception `
                -Message "Failed to parse ActionString." `
                -Category ParserError `
                -ErrorId "Ntfy.ActionStringParseError"
        }

        Write-Verbose "Successfully created action hashtable."
        return $Hashtable
    }
}
Set-Alias -Name cfn -Value ConvertFrom-NtfyAction
