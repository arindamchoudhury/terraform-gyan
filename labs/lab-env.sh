# Environment the book's labs assume. Source it once per shell, from the repo
# root, then cd into any lab directory:
#
#     source labs/lab-env.sh
#     cd labs/chapter13/lab1
#     tflocal apply
#
# Sourced rather than run as a wrapper on purpose: lab directories sit at
# different depths under labs/, so a wrapper would need a different relative
# path from each one. This sets the shell once and every depth works.
#
# Nothing here touches machine state. Close the shell and it is all gone.
# For a permanent setting instead, see the shell-rc lines in
# docs/book/ch01-iac-fundamentals.md.

# Makes tflocal build the S3 endpoint as http://localhost:4566. Because that
# hostname does not start with "s3.", tflocal writes s3_use_path_style = true
# into its generated override, so bucket names land in the URL path instead of
# becoming public DNS subdomains that have to be resolved over the network.
export S3_HOSTNAME=localhost

# Dummy credentials. The emulator ignores their value and only wants some
# credentials present, so the AWS CLI never reaches for a real login provider.
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

echo "Lab environment set: S3_HOSTNAME=$S3_HOSTNAME, region $AWS_DEFAULT_REGION, dummy credentials." >&2
