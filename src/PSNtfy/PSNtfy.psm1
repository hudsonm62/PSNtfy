[string]$Root = (Get-Item -Path $PSScriptRoot -Force)

# paths
$PublicPath = Join-Path $Root "public"
$PrivatePath = Join-Path $Root "private"
$ClassesPath = Join-Path $Root "classes"

# get all files for import/export
$public  = Get-ChildItem -Path $PublicPath  -Recurse -Force | Where-Object { $_.Extension -eq ".ps1" }
$private = Get-ChildItem -Path $PrivatePath -Recurse -Force | Where-Object { $_.Extension -eq ".ps1" }
$classes = Get-ChildItem -Path $ClassesPath -Recurse -Force | Where-Object { $_.Extension -eq ".ps1" }

# Import all to session
$public  | ForEach-Object { . $_.FullName }
$private | ForEach-Object { . $_.FullName }
$classes | ForEach-Object { . $_.FullName }

# Export 'public' functions (w/ aliases if present)
$aliases = @()
$public | ForEach-Object {
    $alias = Get-Alias -Definition $_.BaseName -ErrorAction SilentlyContinue
    if ($alias) {
        $aliases += $alias
        Export-ModuleMember -Function $_.BaseName -Alias $alias
    } else {
        # Export with no alias
        Export-ModuleMember -Function $_.BaseName
    }
}

# Complain if missing functions in manifest
$ManifestPath = Join-Path $Root "PSNtfy.psd1"
$Manifest = Test-ModuleManifest $ManifestPath -ErrorAction Stop

$Added = $public | Where-Object {$_.BaseName -notin $Manifest.ExportedFunctions.Keys}
$Removed = $Manifest.ExportedFunctions.Keys | Where-Object {$_ -notin $public.BaseName}

$aliasesAdded = $aliases | Where-Object {$_.Name -notin $Manifest.ExportedAliases.Keys}
$aliasesRemoved = $Manifest.ExportedAliases.Keys | Where-Object {$_ -notin $aliases.Name}
if ($Added -or $Removed -or $aliasesAdded -or $aliasesRemoved) {
    throw "Module manifest ExportedFunctions or ExportedAliases is out of date. Please update:`n Added Functions: $($Added.BaseName -join ', ')`n Removed Functions: $($Removed -join ', ')`n Added Aliases: $($aliasesAdded -join ', ')`n Removed Aliases: $($aliasesRemoved -join ', ')"
}
