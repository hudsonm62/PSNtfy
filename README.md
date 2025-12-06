<!-- banner image here -->

<h1 align="center">PSNtfy</h1>

<div align="center">

Cross-platform PowerShell module to assist with building and sending notifications to Ntfy instances.

[![GitHub Tag](https://img.shields.io/github/v/tag/hudsonm62/PSNtfy?label=latest)](https://github.com/hudsonm62/PSNtfy/releases) [![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/hudsonm62/PSNtfy/test.yml?label=Tests)](https://github.com/hudsonm62/PSNtfy/actions/workflows/ci.yml) ![Codecov](https://img.shields.io/codecov/c/github/hudsonm62/PSNtfy) [![GitHub top language](https://img.shields.io/github/languages/top/hudsonm62/PSNtfy?link=%20)](https://github.com/hudsonm62/PSNtfy/search?l=powershell)

</div>

## 🚀 Overview

PSNtfy is a PowerShell module that simplifies the process of sending notifications to Ntfy instances. It provides functions to send notifications and build out complex Actions, making it easy to integrate Ntfy notifications into your PowerShell scripts and workflows without having to constantly refer to the documentation. _Nearly_ all features of Ntfy are supported within the module!

![Example](.github/images/example.png)

## 👓 Compatibility

PSNtfy has been tested and is compatible with:

- PowerShell 5.1
- PowerShell 7+

> Nothing is tested on versions prior to PowerShell 5.1.
> On older systems, please install PowerShell 7.

## 🐉 Usage

Install the module from the PowerShell Gallery:

```powershell
Install-Module -Name PSNtfy -Scope CurrentUser
```

> [!NOTE]
> We currently do not have any code signing, you will need to set your PowerShell [execution policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy) accordingly.

From there you can import the module and start sending notifications:

```powershell
Import-Module PSNtfy
Send-NtfyPush -NtfyEndpoint 'https://ntfy.sh' -Topic 'test' `
        -Title "Hello, Ntfy!"
```

- Run `Get-Help PSNtfy` for available commands, parameters & examples.

### 🔑 Credentials

Credentials can be provided in 2 ways:

1. Username and Password via a [PSCredential](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscredential).
2. Using a Token (Bearer or Basic Auth) via plaintext [SecureString](https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring).

```powershell
# User/Pass (Basic Auth)
Send-NtfyPush -Credential (Get-Credential)

# By Token (Bearer or Basic Auth)
$tk = ConvertTo-SecureString 'tk_***' -AsPlainText -Force
Send-NtfyPush -TokenType Bearer -AccessToken $tk
Send-NtfyPush -TokenType Basic  -AccessToken $tk
```

The function will handle formatting the Headers correctly for you depending on your PowerShell version (due to the differences in `Invoke-RestMethod` & `ConvertFrom-SecureString` from PS6+). How we handle it under the hood closely resembles the examples in the Ntfy documentation so you don't have to worry about it.

- [Ntfy Docs | Authentication](https://docs.ntfy.sh/publish/#authentication)

> [!CAUTION]
> Don't store your passwords & tokens directly in your scripts. Instead, use alternative methods such as [Secret Management](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/) or [CredentialManager](https://www.powershellgallery.com/packages/CredentialManager/).

### 🧩 Actions

Two functions for converting simple-format Ntfy Actions have been included:

| Function                 | Description                                                                |
| ------------------------ | -------------------------------------------------------------------------- |
| `ConvertTo-NtfyAction`   | Makes a single Ntfy Action string from specified parameters for all types. |
| `ConvertFrom-NtfyAction` | Converts a simple-format Action string into the proper hashtable format.   |

This should improve QoL when building notifications with multiple Actions or from dynamic sources:

```powershell
$r = @{ NtfyEndpoint 'https://ntfy.sh' ; Topic 'test' }
$action1 = ConvertTo-NtfyAction -View -Label 'Open Website' -Url 'https://google.com'
$action2 =  ConvertTo-NtfyAction -Http -Label 'Close door' -Url 'https://api.mygarage.lan/' `
                -Method PUT -Headers @("Authorization=Bearer ExampleToken")

Send-NtfyPush -Actions $action1,$action2 @r
```

Even if you don't want to use `Send-NtfyPush`, you can still use the output of `ConvertTo-NtfyAction` in your own payloads as-is.

## 🐛 Contributing

Please contribute! The most of this was designed and written by a single person in their spare time and is definitely bound to be problems or oversights here and there.

If you are using VSCode or [GitHub Codespaces](https://github.com/features/codespaces), a [DevContainer](.devcontainer/devcontainer.json) has been included for easy setup of a development environment, or needing to test on a Linux-based system.

If you have a suggestion, a bug report, or a feature request, please open an [issue](https://github.com/hudsonm62/PSNtfy/issues). Alternatively you can fork the repository and submit a pull request with your changes.

> [!TIP]
> If you can't contribute code, a [Donation](https://github.com/sponsors/hudsonm62) would also be much appreciated!

## ⚖️ Compliance

**PSNtfy** is licensed under [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
