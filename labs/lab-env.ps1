# Environment the book's labs assume. Run it once per shell. This form works
# from anywhere inside the repository, including from within a lab directory:
#
#     . "$(git rev-parse --show-toplevel)/labs/lab-env.ps1"
#
# From the repo root, `. .\labs\lab-env.ps1` is equivalent and shorter. A bare
# relative path is what trips people up, because it resolves against the
# current directory, not against this file.
#
# Dot-sourcing is habit rather than necessity here: `$env:` writes to the
# process environment block, so plainly running the script sets the session
# too. The Bash sibling genuinely must be sourced.
#
# Nothing here touches machine state. Close the shell and it is all gone.
# For a permanent setting instead, see `setx` in docs/book/ch01-iac-fundamentals.md.

# Makes tflocal build the S3 endpoint as http://localhost:4566. Because that
# hostname does not start with "s3.", tflocal writes s3_use_path_style = true
# into its generated override, so bucket names land in the URL path instead of
# becoming public DNS subdomains that have to be resolved over the network.
$env:S3_HOSTNAME = "localhost"

# Dummy credentials. The emulator ignores their value and only wants some
# credentials present, so the AWS CLI never reaches for a real login provider.
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"

Write-Host "Lab environment set: S3_HOSTNAME=$env:S3_HOSTNAME, region $env:AWS_DEFAULT_REGION, dummy credentials."
