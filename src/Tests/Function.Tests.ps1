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
Describe "Save-NtfyAuthentication" {
    InModuleScope PSNtfy {
        BeforeAll {
            $MockCredString = 'FakePassword'
            $MockSecureString = ConvertTo-SecureString $MockCredString -AsPlainText -Force
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
                $MockUser = "user"
                $MockCredential = New-Object System.Management.Automation.PSCredential ($MockUser, $MockSecureString)
                Save-NtfyAuthentication -Credential $MockCredential @PayloadHeaders
                $EncodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$MockUser" + ':' + "$MockCredString"))
                $Headers["Authorization"] | Should -Be "Basic $EncodedCreds"
            }
            It "should throw if Credential is invalid" {
                { Save-NtfyAuthentication -Credential $null @PayloadHeaders } | Should -Throw
            }
        }
    }
}
#endregion
#region Public
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
                $ActionString = 'http, Post Data, https://example.com/api, INVALIDMETHOD, headers.Authorization=Bearer FakeToken, headers.Content-Type=application/json, {"key":"value"}, clear=true'
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
#endregion
