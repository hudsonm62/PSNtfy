Get-Item -Path (Join-Path $PSScriptRoot "../src/PSNtfy") | Get-ChildItem -Recurse -Force -Filter "*.ps1" -ErrorAction Stop | ForEach-Object {
    . $_.FullName
}
