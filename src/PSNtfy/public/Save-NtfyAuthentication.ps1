<#
.SYNOPSIS
    Saves authentication information into the proper hashtable(s).
.DESCRIPTION
    Saves authentication information to the proper hashtable(s) for use in Ntfy requests.
    Payload is the main splat for Invoke-RestMethod, Headers is the headers splat.

.PARAMETER Payload
    Hashtable to the main payload of the Ntfy request.
.PARAMETER Headers
    Hashtable to the headers of the Ntfy request. If not provided, it will be created/modified into the Payload instead.
.PARAMETER AccessToken
    SecureString token to be used for Bearer or Basic authentication.
.PARAMETER Credential
    PSCredential object to be used for Basic authentication.
.PARAMETER TokenType
    Type of token being used for authentication. Valid values are "Bearer" and "Basic".
.EXAMPLE
    $Payload = @{Method='POST'; Body='test'; URI='https://ntfy.sh/test'}
    $Headers = @{}
    $AccessToken = ConvertTo-SecureString 'tk_**' -AsPlainText -Force
    Save-NtfyAuthentication -Payload $Payload -Headers $Headers -AccessToken $AccessToken -TokenType 'Bearer'
    Invoke-RestMethod @Payload
.EXAMPLE
    $Payload = @{Method='POST'; Body='test'; URI='https://ntfy.sh/test'}
    $Headers = @{}
    $Credential = Get-Credential
    Save-NtfyAuthentication -Payload $Payload -Headers $Headers -Credential $Credential
    Invoke-RestMethod @Payload
.EXAMPLE
    $Payload = @{Method='POST'; Body='test'; URI='https://ntfy.sh/test'}
    $AccessToken = ConvertTo-SecureString 'tk_**' -AsPlainText -Force
    Save-NtfyAuthentication -Payload $Payload -AccessToken $AccessToken -TokenType 'Bearer'
    Invoke-RestMethod @Payload

    # Headers parameter is optional and instead will be created or modified within Payload.
#>
function Save-NtfyAuthentication {
    [Alias('Save-NtfyAuth')][Alias('sva')]
    [CmdletBinding(DefaultParameterSetName = "Token")]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload, # ptr
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = $null, # ptr

        [Parameter(ParameterSetName = "Token")]
        [SecureString]$AccessToken = $null,

        [Parameter(ParameterSetName = "Credential")]
        [PSCredential]$Credential = $null,

        [Parameter(ParameterSetName = "Token")]
        [ValidateSet("Bearer","Basic")]
        [string]$TokenType = "Bearer"
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Token" {
            try {
                if($PSVersionTable.PSVersion.Major -le 5){
                    # PS5- Logic
                    if(-not $Headers){
                        if(-not $Payload.Headers){
                            Add-ObjectPropSafe -Object $Payload -Key "Headers" -Value @{}
                        }
                        $Headers = $Payload.Headers
                    }
                    $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken))
                    switch ($TokenType) {
                        "Bearer" {
                            $Headers["Authorization"] = "Bearer $Token"
                        }
                        "Basic" {
                            $Headers["Authorization"] = "Basic $Token"
                        }
                    }
                } else {
                    # PS6+ Logic
                    switch ($TokenType) {
                        "Bearer" {
                            $Payload["Token"] = $AccessToken # should remain a SecureString
                            $Payload["Authentication"] = "Bearer"
                        }
                        "Basic" {
                            if(-not $Headers){
                                if(-not $Payload.Headers){
                                    Add-ObjectPropSafe -Object $Payload -Key "Headers" -Value @{}
                                }
                                $Headers = $Payload.Headers
                            }
                            $Headers["Authorization"] = "Basic $(ConvertFrom-SecureString -AsPlainText $AccessToken)"
                        }
                    }
                }
            } catch {
                Write-TerminatingError -Exception $_.Exception `
                    -Message "Failed to process the -AccessToken for authentication." `
                    -Category ParserError `
                    -ErrorId "Ntfy.AccessTokenError"
            }
        }
        "Credential" {
            if(-not $Headers){
                if(-not $Payload.Headers){
                    Add-ObjectPropSafe -Object $Payload -Key "Headers" -Value @{}
                }
                $Headers = $Payload.Headers
            }
            try {
                $EncodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"))
                $Headers["Authorization"] = "Basic $EncodedAuth"
            } catch {
                Write-TerminatingError -Exception $_.Exception `
                    -Message "Failed to process the -Credential for authentication." `
                    -Category ParserError `
                    -ErrorId "Ntfy.CredentialError"
            }
        }
        default {}
    }
}
Set-Alias -Name sva -Value Save-NtfyAuthentication
Set-Alias -Name Save-NtfyAuth -Value Save-NtfyAuthentication
