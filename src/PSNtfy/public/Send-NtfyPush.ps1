<#
.SYNOPSIS
    Sends a push notification to the desired ntfy server.

.DESCRIPTION
    Builds out a request to send a push notification to the desired ntfy server with the provided parameters. Supports nearly every single parameter that ntfy supports.

.LINK
    https://github.com/hudsonm62/PSNtfy

.LINK
    https://docs.ntfy.sh

.LINK
    https://docs.ntfy.sh/publish/

.PARAMETER NtfyEndpoint
    The ntfy server endpoint to send the notification to. Don't include the topic in this URL.

.PARAMETER Topic
    The topic to send the notification to.

.PARAMETER Title
    Title of the notification.

.PARAMETER Body
    Body of the notification.

.PARAMETER Markdown
    Indicates if the notification body should be interpreted as Markdown.

.PARAMETER Priority
    Priority of the notification (1-5).

.PARAMETER Tags
    Tags associated with the notification. Also used for emojis.

.PARAMETER At
    Schedule the notification for a specific time.

.PARAMETER Actions
    Set of actions to include with the notification.
    Include multiple actions by separating them with commas or using an array.

.PARAMETER Click
    URL to open when the notification is clicked.

.PARAMETER AttachByPath
    Path to a file to attach to the notification.

.PARAMETER AttachByURL
    URL of a file to attach to the notification.

.PARAMETER Filename
    Overrides the filename of the attached file (when using AttachByPath or AttachByURL).

.PARAMETER Icon
    Icon to display with the notification.

.PARAMETER Email
    Email address to forward the notification to. Requires SMTP to be configured on the ntfy server.

.PARAMETER Phone
    Phone number to call from.
    Numbers have to be previously verified (via the web app), so this feature is only available to authenticated users.
    On ntfy.sh, this feature is only supported to ntfy Pro plans.

.PARAMETER Credential
    PSCredential object for Basic Authentication.
    Prefers AccessToken over Credential if both are provided.

.PARAMETER AccessToken
    Access token for Authentication.
    Must be a SecureString that can be decrypted to plain text with ConvertFrom-SecureString.
    Prefers AccessToken over Credential if both are provided.

.PARAMETER TokenType
    Type of AccessToken to use for Authentication. Can only be "Bearer" or "Basic" - Defaults to "Bearer".
    Ignored if Credential is used for authentication, as Credential uses Basic authentication regardless.
    https://swagger.io/docs/specification/v3_0/authentication/bearer-authentication/

.PARAMETER NoCaching
    Whether to disable caching for this notification.

.PARAMETER DisableFirebase
    Whether to disable Firebase delivery for this notification.

.PARAMETER UnifiedPush
    Whether to send the notification via UnifiedPush.

.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        Body = 'A very cool notification'
    }
    Send-NtfyPush @Ntfy

.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        Phone = '+61412345678'
    }
    Send-NtfyPush @Ntfy

.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        Tags  = 'skull', 'cool-tag'
    }
    Send-NtfyPush @Ntfy

.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        AccessToken = (ConvertTo-SecureString '' -AsPlainText -Force)
    }
    Send-NtfyPush @Ntfy
.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        AttachByPath = 'path/to/File.txt'
        Filename = 'Cool.txt'
    }
    Send-NtfyPush @Ntfy
.EXAMPLE
    $Ntfy = @{
        NtfyEndpoint = 'https://ntfy.sh'
        Topic = 'test'
        AttachByURL = 'https://example.com/image.png'
    }
    Send-NtfyPush @Ntfy
#>
function Send-NtfyPush {
    [Alias('Send-Ntfy')][Alias('sdn')]
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $true)]
        [Uri]$NtfyEndpoint,

        [Parameter(Mandatory = $true)]
        [string]$Topic,

        [Parameter()]
        [string]$Title = $null,

        [Parameter()]
        [string]$Body = $null,

        [Parameter()]
        [switch]$Markdown = $false,

        [Parameter()]
        [ValidateSet(
            1,2,3,4,5,
            'default','min','low','high','max','urgent')]
        [string]$Priority = $null,

        [Parameter()]
        [string[]]$Tags = $null,

        [Parameter()]
        [string]$At = $null,

        [Parameter()]
        [Object[]]$Actions = $null,

        [Parameter()]
        [string]$Click = $null,

        [Parameter(ParameterSetName = 'AttachByPath')]
        [string]$AttachByPath = $null,

        [Parameter(ParameterSetName = 'AttachByURL')]
        [string]$AttachByURL = $null,

        [Parameter(ParameterSetName = 'AttachByURL')]
        [Parameter(ParameterSetName = 'AttachByPath')]
        [string]$Filename = $null,

        [Parameter()]
        [string]$Icon = $null,

        [Parameter()]
        [string]$Email = $null,

        [Parameter()]
        [string]$Phone = $null,

        [Parameter()]
        [PSCredential]$Credential = $null,

        [Parameter()]
        [SecureString]$AccessToken = $null,

        [Parameter()][ValidateSet("Bearer","Basic")]
        [string]$TokenType = "Bearer",

        [Parameter()]
        [switch]$NoCaching = $false,

        [Parameter()]
        [switch]$DisableFirebase = $false,

        [Parameter()]
        [switch]$UnifiedPush = $false
    )

    try {
        $builder = [System.UriBuilder]$NtfyEndpoint
        $builder.Path = (Join-Path -Path $builder.Path -ChildPath $Topic)
        $FullUri = $builder.Uri.AbsoluteUri
        Write-Debug "Constructed Full URI: $FullUri"
    } catch {
        Write-TerminatingError -Exception $_.Exception `
            -Message "Failed to construct a properly formed Endpoint URI." `
            -Category InvalidData `
            -ErrorId "Ntfy.EndpointURIError"
    }

    $Headers = @{}
    $Payload = @{
        Method = "Post"
        Uri    = $FullUri
    }

    # build out access payload from Save-NtfyAuthentication
    if($AccessToken) {
        Write-Verbose "Using AccessToken for authentication with TokenType: $TokenType"
        Save-NtfyAuthentication -Payload $Payload -Headers $Headers -AccessToken $AccessToken -TokenType $TokenType -ErrorAction Stop
        if($Credential) {
            Write-Warning "Both AccessToken and Credential were provided. Only AccessToken will be used for authentication."
        }
    } elseif($Credential) {
        Write-Verbose "Using PSCredential for Basic authentication"
        Save-NtfyAuthentication -Payload $Payload -Headers $Headers -Credential $Credential -ErrorAction Stop
    } else {
        Write-Verbose "No authentication method specified - Proceeding Anonymously."
    }

    # build out notification
    Add-ObjectPropSafe -Object $Headers -Key "Title" -Value $Title
    Add-ObjectPropSafe -Object $Payload -Key "Body" -Value $Body
    Add-ObjectPropSafe -Object $Headers -Key "Priority" -Value $Priority
    Add-ObjectPropSafe -Object $Headers -Key "At" -Value $At
    Add-ObjectPropSafe -Object $Headers -Key "Click" -Value $Click
    Add-ObjectPropSafe -Object $Headers -Key "Icon" -Value $Icon
    Add-ObjectPropSafe -Object $Headers -Key "Email" -Value $Email
    Add-ObjectPropSafe -Object $Headers -Key "Call" -Value $Phone

    ## file attachment
    Add-ObjectPropSafe -Object $Headers -Key "Filename" -Value $Filename
    Add-ObjectPropSafe -Object $Payload -Key "InFile" -Value $AttachByPath
    Add-ObjectPropSafe -Object $Headers -Key "Attach" -Value $AttachByURL

    ## Booleans & Arrays
    if($Actions) {
        $Headers["Actions"] = ($Actions -join ";")
        Write-Verbose "Added $($Actions.Count) action(s)."
        Write-Debug "Actions string: $($Headers["Actions"])"
    }
    if($Tags) {
        $Headers["Tags"] = ($Tags -join ",")
        Write-Verbose "Added $($Tags.Count) tag(s)."
        Write-Debug "Tags string: $($Headers["Tags"])"
    }
    if($Markdown.IsPresent) { $Headers["Markdown"] = "yes" }
    if($NoCaching.IsPresent) { $Headers["Cache"] = "no" }
    if($DisableFirebase.IsPresent) { $Headers["Firebase"] = "no" }
    if($UnifiedPush.IsPresent) { $Headers["UnifiedPush"] = "1" }


    # Join Headers into Payload
    Add-ObjectPropSafe -Object $Payload -Key "Headers" -Value $Headers

    # Send Web Request
    Invoke-RestMethod @Payload
}
Set-Alias -Name sdn -Value Send-NtfyPush
Set-Alias -Name Send-Ntfy -Value Send-NtfyPush
