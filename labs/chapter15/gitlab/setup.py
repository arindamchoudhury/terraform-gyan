#!/usr/bin/env python
"""One-shot bootstrap for the GitLab CI lab.

Creates an API token, a project, and an instance runner; registers that runner
with the docker executor on the emulator's network; and commits the pipeline
from ./ci into the project so the first pipeline runs immediately.

Everything here is also doable by hand in the UI. The README says how. This
script exists so the lab is repeatable, not to hide the steps.

Python rather than bash because the lab runs on Windows too, and PowerShell
cannot run the bash version. Standard library only, so there is nothing to
install:

  docker compose -f labs/docker-compose.yml up -d                     # emulator
  docker compose -f labs/chapter15/gitlab/docker-compose.yml up -d    # gitlab + runner
  python setup.py
"""

import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

GITLAB_HOST = os.environ.get("GITLAB_HOST", "http://127.0.0.1:8929")
GITLAB_INTERNAL = os.environ.get("GITLAB_INTERNAL", "http://tf-lab-gitlab:8929")
EMULATOR_NETWORK = os.environ.get("EMULATOR_NETWORK", "labs_default")
TF_IMAGE = os.environ.get("TF_IMAGE", "hashicorp/terraform:1.15.8")
PROJECT = os.environ.get("PROJECT", "tf-state-lab")

# A throwaway token for a container on your own loopback interface. Never reuse
# this pattern against an instance anyone else can reach.
TOKEN = os.environ.get("TOKEN", "glpat-tflabtflabtflabtfla")

HERE = pathlib.Path(__file__).resolve().parent


def say(message):
    print("\n=== " + message, flush=True)


def api(path, data=None, method=None, json_body=None):
    """Call the GitLab API with the lab token. Returns the decoded response."""
    url = GITLAB_HOST + path
    headers = {"PRIVATE-TOKEN": TOKEN}
    body = None
    if json_body is not None:
        body = json.dumps(json_body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    elif data is not None:
        body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as response:
        payload = response.read().decode("utf-8")
        return response.status, (json.loads(payload) if payload else None)


def docker(*args):
    """Run a docker command, letting its output through to the terminal."""
    subprocess.run(("docker",) + args, check=True)


def wait_until_serving():
    say("waiting for GitLab to serve (not just to report healthy)")
    # The container reports healthy minutes before Puma and nginx are up, so
    # poll the application itself.
    while True:
        try:
            with urllib.request.urlopen(
                GITLAB_HOST + "/users/sign_in", timeout=10
            ) as response:
                if response.status == 200:
                    break
        except Exception:
            pass
        print(".", end="", flush=True)
        time.sleep(10)
    print(" serving", flush=True)


def create_token():
    say("creating an API token for root")
    # One line, because an argument containing newlines is not carried the same
    # way through a Windows command line as it is through an exec.
    ruby = (
        "u = User.find_by_username('root'); "
        "u.personal_access_tokens.where(name: 'tf-lab').delete_all; "
        "t = u.personal_access_tokens.create!("
        "scopes: ['api'], name: 'tf-lab', expires_at: 30.days.from_now); "
        "t.set_token('{token}'); "
        "t.save!; "
        "puts 'token ready'"
    ).format(token=TOKEN)
    docker("exec", "tf-lab-gitlab", "gitlab-rails", "runner", ruby)


def find_or_create_project():
    say("creating project " + PROJECT)
    _, found = api("/api/v4/projects?" + urllib.parse.urlencode({"search": PROJECT}))
    for project in found or []:
        if project.get("name") == PROJECT:
            print("project id " + str(project["id"]))
            return project["id"]
    _, created = api(
        "/api/v4/projects",
        method="POST",
        data={
            "name": PROJECT,
            "visibility": "private",
            "initialize_with_readme": "true",
        },
    )
    print("project id " + str(created["id"]))
    return created["id"]


def register_runner():
    say("creating and registering an instance runner")
    _, runner = api(
        "/api/v4/user/runners",
        method="POST",
        data={
            "runner_type": "instance_type",
            "description": "tf-lab",
            "run_untagged": "true",
            "locked": "false",
        },
    )
    runner_token = (runner or {}).get("token")
    if not runner_token:
        sys.exit("could not create a runner token. Is " + TOKEN + " an admin token?")

    # --docker-network-mode puts every job container on the emulator's network,
    # which is what makes floci-lab:4566 resolve from inside the job.
    # --clone-url overrides the external_url GitLab advertises (127.0.0.1),
    # which a job container cannot reach.
    docker(
        "exec",
        "tf-lab-gitlab-runner",
        "gitlab-runner",
        "register",
        "--non-interactive",
        "--url", GITLAB_INTERNAL,
        "--token", runner_token,
        "--executor", "docker",
        "--docker-image", TF_IMAGE,
        "--docker-network-mode", EMULATOR_NETWORK,
        "--docker-pull-policy", "if-not-present",
        "--clone-url", GITLAB_INTERNAL,
        "--description", "tf-lab",
    )


def commit_pipeline(project_id):
    say("committing the pipeline from ./ci")
    # "create" fails with 400 if the file is already there, which makes the
    # script non-repeatable. Ask the project what it already has and pick the
    # verb per file.
    existing = set()
    try:
        _, tree = api("/api/v4/projects/" + str(project_id) + "/repository/tree")
        existing = {entry["name"] for entry in tree or []}
    except Exception:
        pass

    actions = [
        {
            "action": "update" if path.name in existing else "create",
            "file_path": path.name,
            "content": path.read_text(encoding="utf-8"),
        }
        for path in sorted((HERE / "ci").iterdir())
    ]
    status, _ = api(
        "/api/v4/projects/" + str(project_id) + "/repository/commits",
        method="POST",
        json_body={
            "branch": "main",
            "commit_message": "Add Terraform pipeline with an S3 backend",
            "actions": actions,
        },
    )
    print("commit: HTTP " + str(status))


def main():
    wait_until_serving()
    create_token()
    project_id = find_or_create_project()
    register_runner()
    commit_pipeline(project_id)
    print(
        "\n"
        "Done.\n"
        "\n"
        "  project   {host}/root/{project}\n"
        "  pipelines {host}/root/{project}/-/pipelines\n"
        "\n"
        "The push triggers validate and plan. apply is manual: run it from the\n"
        "pipeline view, then check the state object:\n"
        "\n"
        "  aws --endpoint-url http://localhost:4566 s3 ls s3://tf-state-lab --recursive\n".format(
            host=GITLAB_HOST, project=PROJECT
        )
    )


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        sys.exit(
            "GitLab returned HTTP {code} for {url}\n{body}".format(
                code=error.code, url=error.url, body=error.read().decode("utf-8", "replace")
            )
        )
    except subprocess.CalledProcessError as error:
        sys.exit("command failed with exit {code}: {cmd}".format(code=error.returncode, cmd=" ".join(error.cmd)))
