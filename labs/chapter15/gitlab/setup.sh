#!/usr/bin/env bash
# One-shot bootstrap for the GitLab CI lab.
#
# Creates an API token, a project, and an instance runner; registers that runner
# with the docker executor on the emulator's network; and commits the pipeline
# from ./ci into the project so the first pipeline runs immediately.
#
# Everything here is also doable by hand in the UI — the README says how. This
# script exists so the lab is repeatable, not to hide the steps.
#
#   docker compose -f labs/docker-compose.yml up -d                     # emulator
#   docker compose -f labs/chapter15/gitlab/docker-compose.yml up -d    # gitlab + runner
#   ./setup.sh
set -euo pipefail

GITLAB_HOST="${GITLAB_HOST:-http://127.0.0.1:8929}"
GITLAB_INTERNAL="${GITLAB_INTERNAL:-http://tf-lab-gitlab:8929}"
EMULATOR_NETWORK="${EMULATOR_NETWORK:-labs_default}"
TF_IMAGE="${TF_IMAGE:-hashicorp/terraform:1.15.8}"
PROJECT="${PROJECT:-tf-state-lab}"

# A throwaway token for a container on your own loopback interface. Never reuse
# this pattern against an instance anyone else can reach.
TOKEN="${TOKEN:-glpat-tflabtflabtflabtfla}"

say() { printf '\n=== %s\n' "$1"; }

say "waiting for GitLab to serve (not just to report healthy)"
# The container reports healthy minutes before Puma and nginx are up, so poll
# the application itself.
until [ "$(curl -s -o /dev/null -w '%{http_code}' "${GITLAB_HOST}/users/sign_in" || true)" = "200" ]; do
  printf '.'
  sleep 10
done
echo " serving"

say "creating an API token for root"
docker exec tf-lab-gitlab gitlab-rails runner "
u = User.find_by_username('root')
u.personal_access_tokens.where(name: 'tf-lab').delete_all
t = u.personal_access_tokens.create!(scopes: ['api'], name: 'tf-lab', expires_at: 30.days.from_now)
t.set_token('${TOKEN}')
t.save!
puts 'token ready'
"

api() { curl -sS -H "PRIVATE-TOKEN: ${TOKEN}" "$@"; }

say "creating project ${PROJECT}"
PROJECT_ID="$(api "${GITLAB_HOST}/api/v4/projects?search=${PROJECT}" |
  grep -o '"id":[0-9]*' | head -1 | cut -d: -f2 || true)"

if [ -z "${PROJECT_ID}" ]; then
  PROJECT_ID="$(api -X POST "${GITLAB_HOST}/api/v4/projects" \
    -d "name=${PROJECT}&visibility=private&initialize_with_readme=true" |
    grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)"
fi
echo "project id ${PROJECT_ID}"

say "creating and registering an instance runner"
RUNNER_TOKEN="$(api -X POST "${GITLAB_HOST}/api/v4/user/runners" \
  -d "runner_type=instance_type&description=tf-lab&run_untagged=true&locked=false" |
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)"

if [ -z "${RUNNER_TOKEN}" ]; then
  echo "could not create a runner token — is ${TOKEN} an admin token?" >&2
  exit 1
fi

# --docker-network-mode puts every job container on the emulator's network, which is
# what makes floci-lab:4566 resolve from inside the job.
# --clone-url overrides the external_url GitLab advertises (127.0.0.1), which a
# job container cannot reach.
docker exec tf-lab-gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_INTERNAL}" \
  --token "${RUNNER_TOKEN}" \
  --executor docker \
  --docker-image "${TF_IMAGE}" \
  --docker-network-mode "${EMULATOR_NETWORK}" \
  --docker-pull-policy if-not-present \
  --clone-url "${GITLAB_INTERNAL}" \
  --description "tf-lab"

say "committing the pipeline from ./ci"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$(
  GITLAB_HOST="${GITLAB_HOST}" PROJECT_ID="${PROJECT_ID}" TOKEN="${TOKEN}" python - "$here" <<'PY'
import json, os, pathlib, sys, urllib.request
here = pathlib.Path(sys.argv[1]) / "ci"
# "create" fails with 400 if the file is already there, which makes the script
# non-repeatable. Ask the project what it already has and pick the verb per file.
existing = set()
try:
    req = urllib.request.Request(
        os.environ["GITLAB_HOST"] + "/api/v4/projects/" + os.environ["PROJECT_ID"] + "/repository/tree",
        headers={"PRIVATE-TOKEN": os.environ["TOKEN"]},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        existing = {e["name"] for e in json.load(r)}
except Exception:
    pass
actions = []
for f in sorted(here.iterdir()):
    actions.append({
        "action": "update" if f.name in existing else "create",
        "file_path": f.name,
        "content": f.read_text(encoding="utf-8"),
    })
print(json.dumps({
    "branch": "main",
    "commit_message": "Add Terraform pipeline with an S3 backend",
    "actions": actions,
}))
PY
)"

api -X POST "${GITLAB_HOST}/api/v4/projects/${PROJECT_ID}/repository/commits" \
  -H "Content-Type: application/json" \
  -d "${payload}" -o /dev/null -w 'commit: HTTP %{http_code}\n'

cat <<EOF

Done.

  project   ${GITLAB_HOST}/root/${PROJECT}
  pipelines ${GITLAB_HOST}/root/${PROJECT}/-/pipelines

The push triggers validate and plan. apply is manual — run it from the pipeline
view, then check the state object:

  aws --endpoint-url http://localhost:4566 s3 ls s3://tf-state-lab --recursive
EOF
