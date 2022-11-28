<#
 .SYNOPSIS
    Removes older dotnetcore products

 .DESCRIPTION
    Removes all dotnetcore products except for latest version or removes all versions

    Currently removes the following products:
      * Microsoft .NET Core Runtime
      * Microsoft .NET Core Host
      * Microsoft .NET Core Host FX Resolver
      * Microsoft .NET Core SDK
      * Microsoft ASP.NET Core

 .PARAMETER RemoveAll
 Switch to force removal of all versions of dotnetcore products
#>

#Requires -Version 3.0
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess=$true)]
Param (
    [switch] $RemoveAll
)

#Function to remove a single version of dotnetCore - supports -whatif
Function Remove-DotNetCore {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([string] $GUID )

    if ($PSCmdlet.ShouldProcess($GUID)) {
        pushd $env:SYSTEMROOT\System32
        Start-Process msiexec -wait -ArgumentList ("/x $GUID /qn IGNOREDEPENDENCIES=ALL")
        popd
    }
}

#Host consists of Runtime, Host and Host FX Resolver
$Products = @('Microsoft .NET Core Runtime -*',
              'Microsoft .NET Core Host -*',
              'Microsoft .NET Core Host FX Resolver -*',
              'Microsoft .NET Core SDK*',
              'Microsoft ASP.NET Core*Targeting*',
              'Microsoft ASP.NET Core*Shared*')

$MajorVersions = @("1.0*",
"1.1*",
"2.0*",
"2.1*",
"2.2*",
"3.0*",
"5.0*",
"3.1*",
"6.0*",
"7.0*")

if ($RemoveAll.IsPresent) {
    $Keep = 0
} else {
    $Keep = 1
}

$MajorVersions | ForEach-Object {
    $MajorVersion = $_
    $Products | ForEach-Object {
        $Product = $_
        Write-Host "Processing  $Product version $MajorVersion" -ForegroundColor Cyan
        #Get all installed apps from Registry matching our product
        $DotNetCoreProduct = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'  |
                Where-Object {$_.displayname -like $Product} |
                Select-Object DisplayName, DisplayVersion, UninstallString

        #Keep latest
        $DotNetCoreProduct | Where-object {$_.DisplayVersion -like $MajorVersion } | Sort-Object { [System.Version]::new($_.DisplayVersion)} -Descending |
            Select-Object -First $Keep | ForEach-Object {
                Write-Host "Keeping $($_.DisplayName) version $($_.DisplayVersion)" -ForegroundColor Cyan
            }

        #Convert WMI version to System.version, sort decending, skip latest, and remove
        $DotNetCoreProduct | Where-object {$_.DisplayVersion -like $MajorVersion } | Sort-Object { [System.Version]::new($_.DisplayVersion)} -Descending |
            Select-Object -Skip $Keep |
                ForEach-Object {
                    $IdentifyingNumber = "{  $($_.UninstallString.split("{")[1].split("}")[0])}"
                    $DisplayName = $_.DisplayName
                    Write-Host "*** Removing  $($_.DisplayName) version $($_.DisplayVersion) Uninstall: $($_.UninstallString)" -ForegroundColor Red
                    Remove-DotNetCore -GUID $IdentifyingNumber

                    #Now check if there's the same DisplayName  in 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                    $WOWProduct = Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'  |
                        Where-Object {$_.displayname -like $DisplayName} |
                        Select-Object DisplayName, DisplayVersion, UninstallString
                     $IdentifyingNumber = "{$($WOWProduct.UninstallString.split("{")[1].split("}")[0])}"
                    Remove-DotNetCore -GUID $IdentifyingNumber
                }
}
