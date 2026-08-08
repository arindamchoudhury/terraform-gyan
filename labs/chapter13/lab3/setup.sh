#!/usr/bin/env bash
# Chapter 13 lab 3 — build a throwaway Git module repository locally.
# No GitHub account, no network. Creates two tagged releases of one tiny module
# and writes repo.auto.tfvars pointing at it.
set -euo pipefail

REPO="${TMPDIR:-/tmp}/ch13-lab3/modules-repo"
rm -rf "$REPO"
mkdir -p "$REPO/modules/data-bucket"
cd "$REPO"
git init -q -b main

write_module() {
  cat > modules/data-bucket/main.tf <<EOF
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
  value = "$1"
}
EOF
}

write_module v0.0.1
git add -A
git -c user.email=lab@example.com -c user.name="Ch13 Lab" commit -qm "data-bucket v0.0.1"
git tag -a v0.0.1 -m "first release"

write_module v0.0.2
git add -A
git -c user.email=lab@example.com -c user.name="Ch13 Lab" commit -qm "data-bucket v0.0.2"
git tag -a v0.0.2 -m "second release"

cd - >/dev/null
printf 'module_repo = "file://%s"\n' "$REPO" > repo.auto.tfvars

echo "Module repo: $REPO"
echo "Wrote repo.auto.tfvars:"
cat repo.auto.tfvars
