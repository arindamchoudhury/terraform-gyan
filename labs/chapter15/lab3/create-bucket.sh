#!/usr/bin/env bash
# The gcs backend does not create the bucket: "The bucket must exist prior to
# configuring the backend." Lab 2 bootstraps its bucket with a second Terraform
# configuration; here one API call is enough and keeps the lab to one provider.
set -euo pipefail

ENDPOINT="${FLOCI_GCP_ENDPOINT:-http://127.0.0.1:4588}"
BUCKET="${1:-tf-state-lab}"

curl -sS -X POST "${ENDPOINT}/storage/v1/b?project=floci-local" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${BUCKET}\"}" \
  -o /dev/null -w "created %{http_code} ${BUCKET}\n"
