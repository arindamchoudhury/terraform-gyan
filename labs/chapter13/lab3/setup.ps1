# Chapter 13 lab 3 — build a throwaway Git module repository locally.
# No GitHub account, no network. Creates two tagged releases of one tiny module
# and writes repo.auto.tfvars pointing at it.
$ErrorActionPreference = "Stop"

$labRoot = Join-Path $env:TEMP "ch13-lab3"
$repo    = Join-Path $labRoot "modules-repo"

if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
New-Item -ItemType Directory -Force (Join-Path $repo "modules\data-bucket") | Out-Null

Push-Location $repo
git init -q -b main

function Write-Module([string]$Version) {
    $body = @"
variable "name" {
  type = string
}

resource "aws_s3_bucket" "this" {
  bucket = var.name
}

output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "module_version" {
  value = "$Version"
}
"@
    Set-Content -Path "modules\data-bucket\main.tf" -Value $body
}

Write-Module "v0.0.1"
git add -A
git -c user.email=lab@example.com -c user.name="Ch13 Lab" commit -qm "data-bucket v0.0.1"
git tag -a v0.0.1 -m "first release"

Write-Module "v0.0.2"
git add -A
git -c user.email=lab@example.com -c user.name="Ch13 Lab" commit -qm "data-bucket v0.0.2"
git tag -a v0.0.2 -m "second release"

Pop-Location

# go-getter wants forward slashes and a file:/// URL.
$url = "file:///" + ($repo -replace '\\', '/')
Set-Content -Path (Join-Path $PSScriptRoot "repo.auto.tfvars") -Value "module_repo = `"$url`""

Write-Host "Module repo: $repo"
Write-Host "Wrote repo.auto.tfvars:"
Get-Content (Join-Path $PSScriptRoot "repo.auto.tfvars")
