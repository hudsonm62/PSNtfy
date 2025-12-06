# Change Log

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog] and this project adheres to [Semantic Versioning](http://semver.org/).

[Unreleased]: https://github.com/hudsonm62/PSNtfy/compare/v0.2.2...dev

## [Unreleased]

## [v0.2.3] - 2025-12-06

### Added

- Make `Save-NtfyAuthentication` public.
    - Added aliases - `sva`, `Save-NtfyAuth`

## [v0.2.2] - 2025-12-06

### Added

- `Receive-NtfyPush` to query for push notifications from a Ntfy server.
- Verbose & Debug logging.

### Changed

- Join Headers using `Add-ObjectPropSafe`.

[v0.2.2]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.2.2

## [v0.2.1] - 2025-12-06

### Fixed

- Fixed incorrect `http` method formats.

[v0.2.1]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.2.1

## [v0.2.0] - 2025-12-06

### Added

- Private function `Save-NtfyAuthentication` to handle authentication headers.
- `about_PSNtfy` help topic.
- Add CodeCov test report and coverage uploads.

### Changed

- Use `URIBuilder` instead of `[Uri]::new()`.
- Changelog 'unreleased' to reference `dev` branch.
- Using `Add-ObjectPropSafe` more, where applicable.
- Renamed some internal functions for clarity.
- Pester: Using `ps-test` to avoid flooding common public topic.
- Renovate: Use `dev` branch as 'base'.

[v0.2.0]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.2.0

## [v0.1.1] - 2025-12-05

### Added

- Aliases:
    - `Send-NtfyPush`: `Send-Ntfy`, `sdn`
    - `ConvertTo-NtfyAction`: `ctn`
    - `ConvertFrom-NtfyAction`: `cfn`

### Fixed

- Issue with changed Alias checking on module import.

[v0.1.1]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.1.1

## [v0.1.0] - 2025-12-05

### Added

- This changelog file.
- Initial Development Workflow
- Initial Module & Testing

[v0.1.0]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.1.0

<!--TEMPLATE
## [v0.0.0] - YYYY-MM-YY

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security
[Unreleased]: https://github.com/hudsonm62/PSNtfy/compare/v0.0.0...dev
[v0.0.0]: https://github.com/hudsonm62/PSNtfy/releases/tag/v0.0.0
-->

[Keep a Changelog]: http://keepachangelog.com/

<!-- markdownlint-enable MD024 -->
