<#
.SYNOPSIS
    Applies a configuration from scratch N times and prints the resulting `serial` each time.

.DESCRIPTION
    Chapter 9, section 4. Destroys and deletes the state between runs so every
    apply is a first apply, then reads the top-level `serial` out of
    terraform.tfstate. Repeat runs of one configuration are expected to disagree.

.EXAMPLE
    ./measure-serial.ps1 -Dir provider-backed -Runs 4
    ./measure-serial.ps1 -Dir in-core -Runs 4 -Binary tofu

.NOTES
    Nothing here touches a cloud. random_password and terraform_data create no
    remote objects, so no credentials and no emulator are needed.

    If every command fails with "Failed to load plugin schemas", your security
    software is intercepting Terraform's loopback plugin connection. Scope
    $env:TF_DISABLE_PLUGIN_TLS = "1" to this session as a workaround, never
    persistently: it makes the CLI-to-plugin channel plaintext.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('provider-backed', 'in-core')]
    [string] $Dir,

    [int] $Runs = 4,

    [ValidateSet('terraform', 'tofu')]
    [string] $Binary = 'terraform'
)

$ErrorActionPreference = 'Stop'
$target = Join-Path $PSScriptRoot $Dir
Push-Location $target

try {
    & $Binary init -input=false | Out-Null

    $serials = foreach ($run in 1..$Runs) {
        # Remove the previous run entirely, so each apply is a first apply.
        & $Binary destroy -auto-approve -input=false | Out-Null
        Remove-Item terraform.tfstate, terraform.tfstate.backup -ErrorAction SilentlyContinue

        & $Binary apply -auto-approve -input=false | Out-Null
        $serial = (Get-Content terraform.tfstate -Raw | ConvertFrom-Json).serial

        Write-Host ("run {0}: serial = {1}" -f $run, $serial)
        $serial
    }

    $distinct = $serials | Sort-Object -Unique
    Write-Host ""
    Write-Host ("{0} {1}, {2} runs: {3}" -f $Binary, $Dir, $Runs, ($serials -join ', '))
    Write-Host ($(if ($distinct.Count -gt 1) {
        "Not reproducible - $($distinct.Count) different values from identical runs."
    } else {
        "Same value every run here. Try more runs, or the other directory."
    }))
}
finally {
    Pop-Location
}
