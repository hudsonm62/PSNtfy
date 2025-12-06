[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'testing suite')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'testing suite')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'testing suite')]
param()

BeforeDiscovery {
    if(-not (Get-Module PSNtfy -ErrorAction SilentlyContinue)){
        $ModuleRoot = Resolve-path (Join-Path -Path $PSScriptRoot -ChildPath "../PSNtfy")
        Import-Module $ModuleRoot -Force -ErrorAction Stop
    }
}

#region Private
Describe "Add-ObjectPropSafe" {
    InModuleScope PSNtfy {
        BeforeEach {
            $object = @{}
        }
        Context "When value is valid" {
            It "should add property when value is not null or empty" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value "TestValue"
                $object["TestKey"] | Should -Be "TestValue"
            }

            It "should add property when value is numeric" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value 123
                $object["TestKey"] | Should -Be 123
            }
        }

        Context "When value is invalid" {
            It "should not add property when value is null" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value $null
                $object.ContainsKey("TestKey") | Should -Be $false
            }

            It "should not add property when value is empty string" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value ""
                $object.ContainsKey("TestKey") | Should -Be $false
            }

            It "should not add property when value is whitespace only" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value "   "
                $object.ContainsKey("TestKey") | Should -Be $false
            }

            It "should not add property when value is zero" {
                Add-ObjectPropSafe -Object $object -Key "TestKey" -Value 0
                $object.ContainsKey("TestKey") | Should -Be $false
            }
        }

        Context "When data is incomplete" {
            It "should throw when Key is duplicated" {
                $KeyName = "TestKey"
                Add-ObjectPropSafe -Object $object -Key $KeyName -Value "FirstValue"
                { Add-ObjectPropSafe -Object $object -Key $KeyName -Value "SecondValue" } | Should -Throw
            }

            It "should throw when Object is null" {
                { Add-ObjectPropSafe -Object $null -Key "TestKey" -Value "TestValue" } | Should -Throw
            }

            It "should throw when Object param is missing" {
                { Add-ObjectPropSafe -Key "TestKey" -Value "TestValue" } | Should -Throw
            }
        }
    }
}
Describe "Write-TerminatingError" {
    InModuleScope PSNtfy {
        It "should throw terminating error" {
            $ExceptionObject = New-Object System.Exception
            {
                Write-TerminatingError -Exception $ExceptionObject `
                    -Message "A Terminating Error Occurred." `
                    -Category OperationStopped `
                    -ErrorId "Test.TerminatingError"
            } | Should -Throw -ExpectedMessage "Exception of type 'System.Exception' was thrown."
        }
        It "should throw a terminating error from caught exception" {
            {
                try {
                    throw "Some Major Issue"
                }
                catch {
                    Write-TerminatingError -Exception $_.Exception `
                        -Message "A Terminating Error Occurred." `
                        -Category OperationStopped `
                        -ErrorId "Test.TerminatingError"
                }
            } | Should -Throw -ExpectedMessage "Some Major Issue" -ErrorId "Test.TerminatingError"
        }
    }
}
#endregion
#region Public
Describe "Save-NtfyAuthentication" {
    InModuleScope PSNtfy {
        BeforeAll {
            $MockCredString = 'FakePassword'
            $MockSecureString = ConvertTo-SecureString $MockCredString -AsPlainText -Force
            $MockUser = "user"
            $MockCredential = New-Object System.Management.Automation.PSCredential ($MockUser, $MockSecureString)
            $EncodedMockCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$MockUser" + ':' + "$MockCredString"))
        }
        BeforeEach {
            $Payload = @{}
            $Headers = @{}
            $PayloadHeaders = @{
                Payload = $Payload
                Headers = $Headers
            }
        }
        Context "Using AccessToken" {
            It "should use Bearer token by default" {
                Save-NtfyAuthentication -AccessToken $MockSecureString @PayloadHeaders

                if($PSVersionTable.PSVersion.Major -le 5){
                    $Headers["Authorization"] | Should -Be "Bearer $MockCredString"
                } else {
                    $Payload["Token"] | Should -Be $MockSecureString
                    $Payload["Authentication"] | Should -Be "Bearer"
                }
            }
            It "should specify Basic token when requested" {
                Save-NtfyAuthentication -AccessToken $MockSecureString -TokenType "Basic" @PayloadHeaders
                $Headers["Authorization"] | Should -Be "Basic $MockCredString"
            }
            It "should throw if SecureString is empty" {
                { Save-NtfyAuthentication -AccessToken (ConvertTo-SecureString "" -AsPlainText -Force) @PayloadHeaders } | Should -Throw
            }
        }
        Context "Using Credential" {
            It "should use Basic Auth Credential" {
                Save-NtfyAuthentication -Credential $MockCredential @PayloadHeaders
                $Headers["Authorization"] | Should -Be "Basic $EncodedMockCreds"
            }
            It "should throw if Credential is invalid" {
                { Save-NtfyAuthentication -Credential $null @PayloadHeaders } | Should -Throw
            }
        }
        Context "Header Creation" {
            It "should create headers in payload if not present" {
                $Payload = @{}
                Save-NtfyAuthentication -Payload $Payload -Credential $MockCredential
                $Payload.ContainsKey("Headers") | Should -Be $true
                $Payload.Headers.Authorization | Should -Not -Be $null
                $Payload.Headers.Authorization | Should -Be "Basic $EncodedMockCreds"
            }
            It "should add headers to payload's header property" {
                $PayloadWithHeaders = @{ Headers = @{ ExistingKey = "ExistingValue" } }
                Save-NtfyAuthentication -Payload $PayloadWithHeaders -Credential $MockCredential
                $PayloadWithHeaders.ContainsKey("Headers") | Should -Be $true
                # Confirm didn't overwrite unrelated headers
                $PayloadWithHeaders.Headers.ExistingKey | Should -Be "ExistingValue"
                # Confirm added Authorization
                $PayloadWithHeaders.Headers.Authorization | Should -Be "Basic $EncodedMockCreds"
            }
            It "should work with Bearer Token on PS5" {
                $Payload = @{}
                Save-NtfyAuthentication -Payload $Payload -AccessToken $MockSecureString -TokenType "Bearer"
                $Payload.ContainsKey("Headers") | Should -Be $true
                $Payload.Headers.Authorization | Should -Be "Bearer $MockCredString"
            } -Skip:($PSVersionTable.PSVersion.Major -ge 6) # skip on PS6+
            It "should not create headers for Bearer Token on PS6+" {
                $Payload = @{}
                Save-NtfyAuthentication -Payload $Payload -AccessToken $MockSecureString -TokenType "Bearer"
                $Payload.ContainsKey("Headers") | Should -Be $false
            } -Skip:($PSVersionTable.PSVersion.Major -lt 6) # skip on LT PS6
            It "should create header for Basic Token on PS6+" {
                $Payload = @{}
                Save-NtfyAuthentication -Payload $Payload -AccessToken $MockSecureString -TokenType "Basic"
            } -Skip:($PSVersionTable.PSVersion.Major -lt 6) # skip on LT PS6
            It "should overwrite existing headers" {
                $PayloadWithHeaders = @{ Headers = @{ Authorization = "Basic OldValue" } }
                Save-NtfyAuthentication -Payload $PayloadWithHeaders -Credential $MockCredential
                $PayloadWithHeaders.Headers.Authorization | Should -Be "Basic $EncodedMockCreds"
            }
        }
    }
}
Describe "ConvertTo-NtfyAction" {
    Context "view actions" {
        It "should convert a view action" {
            $result = ConvertTo-NtfyAction -View `
                -Label "Open App" -Url "myapp://open"

            $result | Should -Be "view, Open App, myapp://open, clear=false"
        }
    }
    Context "broadcast actions" {
        It "should convert a basic broadcast action" {
            $result = ConvertTo-NtfyAction -Broadcast -Label "Send Broadcast"
            $result | Should -Be "broadcast, Send Broadcast, clear=false"
        }
        It "should convert a broadcast action with all params" {
            $result = ConvertTo-NtfyAction -Broadcast `
                -Label "Send Broadcast" -Intent "com.example.ACTION" `
                -Extras @("key1=value1", "key2=value2") -Clear:$true

            $result | Should -Be "broadcast, Send Broadcast, com.example.ACTION, extras.key1=value1, extras.key2=value2, clear=true"
        }
    }
    Context "http actions" {
        It "should convert a basic http action" {
            $result = ConvertTo-NtfyAction -Http -Label "Open Website" -Url "https://example.com"
            $result | Should -Be "http, Open Website, https://example.com, clear=false"
        }
        It "should convert an http action with all params" {
            $result = ConvertTo-NtfyAction -Http `
                -Label "Post Data" -Url "https://example.com/api" `
                -Method "POST" `
                -Headers @("Authorization=Bearer FakeToken", "Content-Type=application/json") `
                -Body '{"key":"value"}' -Clear:$true

            $result | Should -Be 'http, Post Data, https://example.com/api, method=POST, headers.Authorization=Bearer FakeToken, headers.Content-Type=application/json, {"key":"value"}, clear=true'
        }
    }
}
Describe "ConvertFrom-NtfyAction" {
    It "should throw on unknown action type" {
        $ActionString = "unknown, Do Something, somevalue, clear=false"
        { ConvertFrom-NtfyAction -Action $ActionString } | Should -Throw
    }
    Context "view actions" {
        It "should parse a view action" {
            $ActionString = "view, Open App, myapp://open, clear=false"
            $result = ConvertFrom-NtfyAction -Action $ActionString

            $result.ActionType | Should -Be "View"
            $result.Label | Should -Be "Open App"
            $result.Url | Should -Be "myapp://open"
            $result.Clear | Should -Be $false
        }
    }
    Context "broadcast actions" {
        It "should parse a simple broadcast action" {
            $ActionString = "broadcast, Send Broadcast, clear=false"
            $result = ConvertFrom-NtfyAction -Action $ActionString

            $result.ActionType | Should -Be "Broadcast"
            $result.Label | Should -Be "Send Broadcast"
            $result.Clear | Should -Be $false
        }
        It "should parse a broadcast action" {
            $ActionString = "broadcast, Send Broadcast, com.example.ACTION, extras.key1=value1, extras.key2=value2, extras.key3=value3, clear=true"
            $result = ConvertFrom-NtfyAction -Action $ActionString

            $result.ActionType | Should -Be "Broadcast"
            $result.Label | Should -Be "Send Broadcast"
            $result.Intent | Should -Be "com.example.ACTION"
            $result.Clear | Should -Be $true
            $result.Extras.Keys | Should -BeIn @("key1", "key2", "key3")
            $result.Extras.Values | Should -BeIn @("value1", "value2", "value3")
        }

        Context "malformed broadcast actions" {
            It "should throw on multiple intent parts" {
                $ActionString = "broadcast, Send Broadcast, com.example.ACTION1, com.example.ACTION2, extras.key1=value1, clear=true"
                { ConvertFrom-NtfyAction -Action $ActionString } | Should -Throw
            }
        }
    }
    Context "http actions" {
        It "should parse a simple http action" {
            $ActionString = "http, Open Website, https://example.com, clear=false"
            $result = ConvertFrom-NtfyAction -Action $ActionString

            $result.ActionType | Should -Be "Http"
            $result.Label | Should -Be "Open Website"
            $result.Url | Should -Be "https://example.com"
            $result.Clear | Should -Be $false
        }
        It "should parse an http action" {
            $ActionString = 'http, Post Data, https://example.com/api, method=POST, headers.Authorization=Bearer FakeToken, headers.Content-Type=application/json, {"key":"value"}, clear=true'
            $result = ConvertFrom-NtfyAction -Action $ActionString

            $result.ActionType | Should -Be "Http"
            $result.Label | Should -Be "Post Data"
            $result.Url | Should -Be "https://example.com/api"
            $result.Method | Should -Be "POST"
            $result.Body | Should -Be '{"key":"value"}'
            $result.Clear | Should -Be $true
            $result.Headers.Keys | Should -BeIn @("Authorization", "Content-Type")
            $result.Headers.Values | Should -BeIn @("Bearer FakeToken", "application/json")
        }

        Context "malformed http actions" {
            It "should throw on malformed method type" {
                $ActionString = 'http, Post Data, https://example.com/api, method=INVALIDMETHOD, headers.Authorization=Bearer FakeToken, headers.Content-Type=application/json, {"key":"value"}, clear=true'
                { ConvertFrom-NtfyAction -Action $ActionString } | Should -Throw
            }
            It "should throw on malformed body type" {
                $ActionString = 'http, Post Data, https://example.com/api, method=POST, body1, body2, body3,and4'
                { ConvertFrom-NtfyAction -Action $ActionString } | Should -Throw
            }
            It "should throw on multiple method parts" {
                $ActionString = 'http, Post Data, https://example.com/api, method=POST, method=GET'
                { ConvertFrom-NtfyAction -Action $ActionString } | Should -Throw
            }
        }
    }
}
Describe "Send-NtfyPush" {
    BeforeAll {
        $NtfyTestEndpoint = "https://ntfy.sh"
    }

    Context "URI Construction" {
        BeforeEach {
            Mock 'Invoke-RestMethod' { } -ModuleName PSNtfy
        }
        It "should construct proper URI with valid endpoint and topic" {
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test" }
        }
        It "should construct proper URI with trailing slash in endpoint" {
            Send-NtfyPush -NtfyEndpoint "$NtfyTestEndpoint/" -Topic "ps-test"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test" }
        }
        It "should construct proper URI with leading slash in topic" {
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "/ps-test"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test" }
        }
        It "should throw on invalid URI" {
            { Send-NtfyPush -NtfyEndpoint "ht!tp://invalid-uri" -Topic "ps-test" } | Should -Throw
        }
    }
    Context "Authentication Handling" {
        BeforeAll {
            Mock 'Invoke-RestMethod' { } -ModuleName PSNtfy
            $MockCredString = 'FakePassword'
            $MockSecureString = ConvertTo-SecureString $MockCredString -AsPlainText -Force
            $MockUser = "user"
            $MockCredential = New-Object System.Management.Automation.PSCredential ($MockUser, $MockSecureString)
            $TokenParamFilter = {
                # PS5 path: Authorization header is set
                (
                    $Headers -and
                    $Headers.ContainsKey("Authorization") -and
                    $Headers["Authorization"] -contains "Bearer $MockCredString"
                ) -or
                # PS6+ path: Token & Authentication fields on the payload/body
                (
                    $Authentication -contains "Bearer" -and
                    $Token -eq $MockSecureString
                )
            }
        }
        It "should use Basic token when AccessToken is provided" {
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -AccessToken $MockSecureString -TokenType "Basic"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.ContainsKey("Authorization") -and
                $Headers["Authorization"] -eq "Basic $MockCredString"
            }
        }
        It "should use Bearer token when AccessToken is provided" {
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -AccessToken $MockSecureString -TokenType "Bearer"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter $TokenParamFilter
        }
        It "should use AccessToken even if Credentials are provided" {
            Mock Write-Warning { } -ModuleName PSNtfy
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -AccessToken $MockSecureString -Credential $MockCredential -TokenType "Bearer"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter $TokenParamFilter
        }
        It "should handle Basic Auth Credential" {
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -Credential $MockCredential
            $EncodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$MockUser" + ':' + "$MockCredString"))
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.ContainsKey("Authorization") -and
                $Headers["Authorization"] -eq "Basic $EncodedCreds"
            }
        }
    }
    Context "Test switches" {
        It "should work with all switches" { # primarily for code coverage
            Mock 'Invoke-RestMethod' { } -ModuleName PSNtfy
            Send-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" `
                -NoCaching -DisableFirebase -UnifiedPush -Markdown
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.Markdown -eq 'yes' -and
                $Headers.Cache -eq 'no' -and
                $Headers.Firebase -eq 'no' -and
                $Headers.UnifiedPush -eq '1'
            }
        }
    }
    Context "Test real notify to ntfy.sh" {
        It "should send a basic notification to ntfy.sh" {
            # Note: This test may fail if there are network issues or if ntfy.sh is down

            # Arrange
            $Actions = ConvertTo-NtfyAction -View -Label "GitHub" -Url 'https://github.com/hudsonm62/PSNtfy'
            $payload = @{
                NtfyEndpoint = $NtfyTestEndpoint
                Title   = "PSNtfy Test Notification"
                Body = "This is a **test notification** sent from Pester!"
                Topic   = "ps-test"
                Actions = $Actions
                Priority = 'urgent'
                Click   = 'https://github.com/hudsonm62/PSNtfy'
                Markdown = $true
                Tags    = @('test_tube', 'testing-code')
            }

            # Act
            $result = Send-NtfyPush @payload

            # Assert
            $result | Should -Not -Be $null
            $result | Should -Not -Contain 'error'
            $result.topic | Should -Be 'ps-test'
            $ActionsResult = $result.actions[0]
            $ActionsResult.action | Should -Be "view"
            $ActionsResult.label | Should -Be "GitHub"
            $ActionsResult.url | Should -Be 'https://github.com/hudsonm62/PSNtfy'
        }
    }
}
Describe "Receive-NtfyPush" {
    BeforeAll {
        $MultiLineJson = "{ id: 'test', 'message': 'test' }`n{ id: 'test2', 'message': 'test' }`n"
        $SingleLineObject = [PSCustomObject]@{ id = 'test'; message = 'test' }
        $FullObject = [PSCustomObject]@{
            # copied from https://docs.ntfy.sh/subscribe/api/#json-message-format
            id = "sPs71M8A2T";time = 1643935928;expires = 1643936928;event = "message"
            topic = "mytopic";priority = 5
            tags = @("warning","skull");click = "https://homecam.mynet.lan/incident/1234"
            attachment = @{
                name = "camera.jpg";type = "image/png"
                size = 33848;expires = 1643946728
                url = "https://ntfy.sh/file/sPs71M8A2T.png"
            }
            title = "Unauthorized access detected";message = "Movement detected in the yard. You better go check"
        }
        $NtfyTestEndpoint = "https://ntfy.sh"
    }
    Context "URI Construction" {
        BeforeEach {
            Mock 'Invoke-RestMethod' {
                return $MultiLineJson
            } -ModuleName PSNtfy
        }

        It "should construct proper URI with valid endpoint and topic" {
            Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test/json" }
        }
        It "should construct proper URI with trailing slash in endpoint" {
            Receive-NtfyPush -NtfyEndpoint "$NtfyTestEndpoint/" -Topic "ps-test" -ErrorAction Stop
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test/json" }
        }
        It "should construct proper URI with leading slash in topic" {
            Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "/ps-test" -ErrorAction Stop
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter { $Uri -eq "$NtfyTestEndpoint/ps-test/json" }
        }
        It "should throw on invalid URI" {
            { Receive-NtfyPush -NtfyEndpoint "ht!tp://invalid-uri" -Topic "ps-test" -ErrorAction Stop } | Should -Throw
        }
    }
    Context "Authentication Handling" {
        BeforeAll {
            Mock 'Invoke-RestMethod' { return $SingleLineObject } -ModuleName PSNtfy
            $MockCredString = 'FakePassword'
            $MockSecureString = ConvertTo-SecureString $MockCredString -AsPlainText -Force
            $MockUser = "user"
            $MockCredential = New-Object System.Management.Automation.PSCredential ($MockUser, $MockSecureString)
            $TokenParamFilter = {
                # PS5 path: Authorization header is set
                (
                    $Headers -and
                    $Headers.ContainsKey("Authorization") -and
                    $Headers["Authorization"] -contains "Bearer $MockCredString"
                ) -or
                # PS6+ path: Token & Authentication fields on the payload/body
                (
                    $Authentication -contains "Bearer" -and
                    $Token -eq $MockSecureString
                )
            }

            $splat = @{
                NtfyEndpoint = $NtfyTestEndpoint
                Topic        = "ps-test"
                ErrorAction = "Stop"
            }
        }
        It "should use Basic token when AccessToken is provided" {
            Receive-NtfyPush @splat -AccessToken $MockSecureString -TokenType "Basic"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.ContainsKey("Authorization") -and
                $Headers["Authorization"] -eq "Basic $MockCredString"
            }
        }
        It "should use Bearer token when AccessToken is provided" {
            Receive-NtfyPush @splat -AccessToken $MockSecureString -TokenType "Bearer"
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter $TokenParamFilter
        }
        It "should handle Basic Auth Credential" {
            Receive-NtfyPush @splat -Credential $MockCredential
            $EncodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$MockUser" + ':' + "$MockCredString"))
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.ContainsKey("Authorization") -and
                $Headers["Authorization"] -eq "Basic $EncodedCreds"
            }
        }
        It "should throw if both AccessToken & Credentials are provided" {
            { Receive-NtfyPush @splat -AccessToken $MockSecureString -Credential $MockCredential -TokenType "Bearer" } |
                Should -Throw -ErrorId 'AmbiguousParameterSet,Receive-NtfyPush'
        }
    }
    Context "Header Creation" {
        BeforeEach {
            Mock 'Invoke-RestMethod' {
                return $MultiLineJson
            } -ModuleName PSNtfy
        }
        It "should not double up on poll parameter" {
            Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -Parameters @{'X-Poll'=1} -ErrorAction Stop -WarningAction SilentlyContinue
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                -not $Headers.ContainsKey("X-Poll") -and
                $Headers["poll"] -eq 1
            }
        }
        It "should append poll parameter if not present" {
            Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
            Should -Invoke Invoke-RestMethod -ModuleName PSNtfy -ParameterFilter {
                $Headers.ContainsKey("poll") -and
                $Headers["poll"] -eq 1
            }
        }
    }
    Context "Response Parsing" {
        Context "Multi Lined" {
            It "should successfully parse multi-lined JSON response" {
                Mock 'Invoke-RestMethod' {
                    return $MultiLineJson
                } -ModuleName PSNtfy

                $result = Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
                $result | Should -Not -Be $null

                $result.Count | Should -BeExactly 2
                $result[0].Id | Should -Be 'test'
                $result[0].Message | Should -Be 'test'
                $result[1].Id | Should -Be 'test2'
                $result[1].Message | Should -Be 'test'
            }
            It "should skip invalid entries in multi-lined JSON response" {
                $InvalidMultiLineJson = "{ id: 'test', 'message': 'test' }`n{ 'message': 'missing id' }`n{ id: 'test2', 'message': 'test' }`n"
                Mock 'Invoke-RestMethod' {
                    return $InvalidMultiLineJson
                } -ModuleName PSNtfy

                $result = Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
                $result | Should -Not -Be $null

                $result.Count | Should -BeExactly 2
                $result[0].Id | Should -Be 'test'
                $result[0].Message | Should -Be 'test'
                $result[1].Id | Should -Be 'test2'
                $result[1].Message | Should -Be 'test'
            }
            It "should handle empty multi-lined JSON response" {
                Mock 'Invoke-RestMethod' {
                    return "`n`n`n"
                } -ModuleName PSNtfy

                $result = Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
                $result | Should -Be $null
                $result.Count | Should -BeExactly 0
            }
            It "should throw on malformed JSON response" {
                $MalformedJson = "{ id: 'test', 'message': 'test' `n{ id: 'test2', 'message': 'test' }`n"
                Mock 'Invoke-RestMethod' {
                    return $MalformedJson
                } -ModuleName PSNtfy

                { Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop } | Should -Throw -ErrorId "Ntfy.ResponseParseError"
            }
        }
        Context "Single Object" {
            It "should handle single object response" {
                Mock 'Invoke-RestMethod' {
                    return $SingleLineObject
                } -ModuleName PSNtfy

                $result = Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop

                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'test'
                $result[0].Message | Should -Be 'test'
            }
            It "should handle a full single line object" {
                Mock 'Invoke-RestMethod' {
                    return $FullObject
                } -ModuleName PSNtfy

                $result = Receive-NtfyPush -NtfyEndpoint $NtfyTestEndpoint -Topic "ps-test" -ErrorAction Stop
                $result.Count | Should -Be 1
                $result.Id | Should -Be $FullObject.id
                $result.Title | Should -Be $FullObject.title
                $result.Message | Should -Be $FullObject.message
                $result.Priority | Should -Be $FullObject.priority
                $result.Time | Should -BeOfType DateTime
                $result.Attachment | Should -Not -Be $null
                $result.Attachment.Name | Should -Be $FullObject.attachment.name
                $result.Attachment.Expires | Should -BeOfType DateTime
            }
        }
    }
}
#endregion
