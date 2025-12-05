function Add-ObjectPropSafe {
    param($Object,$Key,$Value)
    if($Value -and -not [string]::IsNullOrWhiteSpace($Value)){
        $Object.Add($Key,$Value)
    }
}
