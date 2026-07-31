#!/usr/bin/env bash
# Applies a configuration from scratch N times and prints the resulting `serial`
# each time. Chapter 9, section 4.
#
#   ./measure-serial.sh provider-backed 4
#   ./measure-serial.sh in-core 4 tofu
#
# Nothing here touches a cloud: random_password and terraform_data create no
# remote objects, so no credentials and no emulator are needed.
set -euo pipefail

dir="${1:?usage: measure-serial.sh <provider-backed|in-core> [runs] [terraform|tofu]}"
runs="${2:-4}"
bin="${3:-terraform}"

cd "$(dirname "$0")/$dir"
"$bin" init -input=false >/dev/null

serials=()
for run in $(seq 1 "$runs"); do
  # Remove the previous run entirely, so each apply is a first apply.
  "$bin" destroy -auto-approve -input=false >/dev/null
  rm -f terraform.tfstate terraform.tfstate.backup

  "$bin" apply -auto-approve -input=false >/dev/null
  serial=$(python -c "import json;print(json.load(open('terraform.tfstate'))['serial'])")

  echo "run $run: serial = $serial"
  serials+=("$serial")
done

echo
echo "$bin $dir, $runs runs: ${serials[*]}"
if [ "$(printf '%s\n' "${serials[@]}" | sort -u | wc -l)" -gt 1 ]; then
  echo "Not reproducible - identical runs disagreed."
else
  echo "Same value every run here. Try more runs, or the other directory."
fi
