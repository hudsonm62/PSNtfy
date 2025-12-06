<#
.SYNOPSIS
    Queries for push notifications from a Ntfy server.
.DESCRIPTION
    Essentially a wrapper around the Ntfy Subscribe API to query for notifications
    from a specified topic on a Ntfy server. Queries are passed in as HTTP Headers
    via the -Parameters parameter.

    Note that this function automatically adds 'poll=1' to the parameters to
    immediately return results and removes any duplicates of it (and it's aliases).
    If you want to 'subscribe' over a period of time to new messages, you should
    use a different method.
.PARAMETER NtfyEndpoint
    The base URI of the Ntfy server.
.PARAMETER Topic
    The topic to query for notifications.
.PARAMETER Parameters
    HTTP Headers to use as query parameters.
    Preferred over URL Queries, especially for larger/more complex queries.
.PARAMETER Credential
    A PSCredential object containing the username and password for Basic Authentication.
.PARAMETER AccessToken
    A SecureString containing the access token for Bearer or Basic Authentication.
.PARAMETER TokenType
    The type of token provided in AccessToken. Valid values are 'Bearer' and 'Basic'.
    Defaults to 'Bearer'.
.LINK
    https://docs.ntfy.sh/subscribe/api
.LINK
    https://docs.ntfy.sh/subscribe/api/#json-message-format
.LINK
    https://docs.ntfy.sh/subscribe/api/#list-of-all-parameters
.EXAMPLE
    Receive-NtfyPush -NtfyEndpoint "https://ntfy.sh" -Topic "test"
.EXAMPLE
    Receive-NtfyPush -Parameters @{since='2h'} `
        -NtfyEndpoint "https://ntfy.sh" -Topic "test"
.NOTES
    This function automatically adds 'poll=1' to the parameters to immediately return results.
    If you want to 'subscribe' over a period of time to new messages, you should use a different method.
#>
function Receive-NtfyPush {
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    [Alias('Receive-Ntfy')][Alias('rcn')]
    [CmdletBinding(DefaultParameterSetName = 'default')]
    param (
        [Parameter(Mandatory = $true)]
        [Uri]$NtfyEndpoint,
        [Parameter(Mandatory = $true)]
        [string]$Topic,

        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},

        [Parameter(ParameterSetName = 'Credential')]
        [PSCredential]$Credential = $null,

        [Parameter(ParameterSetName = 'AccessToken')]
        [SecureString]$AccessToken = $null,

        [Parameter(ParameterSetName = 'AccessToken')]
        [Parameter(ParameterSetName = 'Credential')]
        [ValidateSet("Bearer","Basic")]
        [string]$TokenType = "Bearer"
    )

    # build uri
    try {
        $builder = [System.UriBuilder]$NtfyEndpoint
        $builder.Path = (Join-Path -Path $builder.Path -ChildPath "$Topic/json")
        $FullUri = $builder.Uri.AbsoluteUri
    } catch {
        Write-TerminatingError -Exception $_.Exception `
            -Message "Failed to construct a properly formed Endpoint URI." `
            -Category InvalidData `
            -ErrorId "Ntfy.EndpointURIError"
    }

    # initial payload and headers
    $Headers = @{}
    $Payload = @{
        Method = "Get"
        Uri    = $FullUri
    }

    # build out access payload from Save-NtfyAuthentication
    switch($PSCmdlet.ParameterSetName) {
        'AccessToken' {
            Save-NtfyAuthentication -Payload $Payload -Headers $Headers -AccessToken $AccessToken -TokenType $TokenType
        }
        'Credential' {
            Save-NtfyAuthentication -Payload $Payload -Headers $Headers -Credential $Credential
        }
        default {<# no auth #>}
    }

    # Join Query Parameters into Headers
    foreach ($key in $Parameters.Keys) {
        Add-ObjectPropSafe -Object $Headers -Key $key -Value $Parameters[$key]
    }
    try {
        # ensure no duplicate poll parameter so we can always ensure it's set.
        'poll','po','X-Poll' | ForEach-Object {
            if ($Headers.ContainsKey($_)) {
                Write-Warning "The '$_' parameter is managed by Receive-NtfyPush and will be overridden to ensure immediate response. You may remove it from your Parameters hashtable."
                $Headers.Remove($_)
            }
        }
    } finally {
        Add-ObjectPropSafe -Object $Headers -Key 'poll' -Value 1
    }

    # Join Headers into Payload
    if($Headers.Count -gt 0) {
        $Payload["Headers"] = $Headers
    }

    # Receive Response
    $response = Invoke-RestMethod @Payload
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Determine response type and parse accordingly
    try {
        $JSONParsed = switch ($response.GetType().Name){
            'String' {
                # Newline-delimited JSON response
                $response -split "`n" | ForEach-Object {
                    if ($_.Trim() -ne "") { # skip empty lines
                        try {
                            $_ | ConvertFrom-Json
                        } catch {
                            # Re-throw to trigger the outer catch and terminating error
                            throw "Failed to parse JSON line: $($_.Exception.Message)"
                        }
                    }
                } | Where-Object { $_ -ne $null } # filter out nulls
                break;
            }
            'PSCustomObject' {
                $response
                break;
            }
            default{}
        }
    }
    catch {
        Write-TerminatingError -Exception $_.Exception `
            -Message "Failed to parse the response from Ntfy." `
            -Category InvalidData `
            -ErrorId "Ntfy.ResponseParseError"
    }


    $JSONParsed | ForEach-Object {
        try {
            if(-not $_.id){
                continue # skip invalid entries
            }

            # cast tags to string array
            $Tags = if($null -ne $_.tags -and $_.tags -ne ""){
                [string[]]$_.tags
            } else {
                [string[]]@()
            }

            # format attachment
            $Attachment = if ($null -ne $_.attachment){
                [PSCustomObject]@{
                    Name    = $_.attachment.name
                    Type    = $_.attachment.type
                    Url     = $_.attachment.url
                    Size    = $_.attachment.size
                    Expires = Get-Date -Date ([DateTimeOffset]::FromUnixTimeSeconds($_.attachment.expires).DateTime) -ErrorAction SilentlyContinue
                }
            }

            # add the object to the list
            $results.Add([PSCustomObject]@{
                Id          = $_.id
                Title       = $_.title
                Message     = $_.message
                Priority    = $_.priority
                Tags        = [string[]]$Tags
                Attachment  = $Attachment
                Click       = $_.click
                Actions     = $_.actions
                Time        = Get-Date -Date ([DateTimeOffset]::FromUnixTimeSeconds($_.time).DateTime)
                Expires     = Get-Date -Date ([DateTimeOffset]::FromUnixTimeSeconds($_.expires).DateTime) -ErrorAction SilentlyContinue
                Icon        = $_.icon
            })
        } catch {
           Write-Error -Message "Failed to parse a notification entry from the response."
        }
    }

    return $results
}
Set-Alias -Name rcn -Value Receive-NtfyPush
Set-Alias -Name Receive-Ntfy -Value Receive-NtfyPush
