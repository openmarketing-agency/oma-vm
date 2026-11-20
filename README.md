# OMA VM

This `linux/amd64` image ships OMA Agent, Docker Compose, `omactl`, and the OMA playbooks and skills. The build prepares Hermes profiles and paused jobs. Startup seeds an empty member disk, applies that instance's credentials, and launches the services. `omactl` pulls optional application images when you install them.

## Inside the VM

- `/opt/oma/playbooks/` and `/opt/oma/skills/` contain the source trees from `openmarketing.agency` with their original directory layout.
- `/opt/data/profiles/<profile-id>/skills/<skill-name>/SKILL.md` is the installed skill for a named profile. Add default-agent skills under `/opt/data/skills/<skill-name>/SKILL.md`.
- `/usr/local/bin/omactl` is the CLI and `/opt/omactl/catalog/` is its catalog. Run `omactl doctor --json` as `hermes` to check the instance.

To include a skill in a future image, add it to `skills/` or `playbooks/<playbook-id>/skills/` in `openmarketing.agency` and reference it from the relevant agent's `oma_skills`. Build with that source commit. New disks receive the new bundle. Existing disks keep their installed playbooks, skills, and Docker state.

## Build and release

Publish the pinned [omactl release](https://github.com/openmarketing-agency/omactl/releases) first. Update `versions.env` when changing the base image, CLI release, or playbook source commit. Build and smoke-test locally with Docker on a Linux machine that supports nested Docker.

```sh
bash scripts/build.sh oma-vm:local
bash tests/smoke.sh oma-vm:local
```

Push a `vX.Y.Z` tag to run the same build and smoke test before publishing `ghcr.io/openmarketing-agency/oma-vm:vX.Y.Z`. The GitHub Actions summary includes the digest to deploy and the versions it contains. Set the GHCR package visibility to public for anonymous pulls, or give the importing workspace read access.

## Run on Agent37

Import the GHCR digest from the release summary into a workspace template. For the first import, use a disposable template and set the default port to `8642`. Create an instance of type `vm` with its disk mounted at `/opt/data`, use the image's entrypoint, and keep `8642` and `9119` private. Supply the runtime environment shown below. Verify a chat turn, run `omactl doctor --json` as `hermes`, and restart the disposable VM to check persistence before updating the `oma-hermes` member template. Agent37 pins imported images and template updates apply to new instances. [Agent37 custom images](https://www.agent37.com/docs/agents-api/custom-image)

## Run on another Linux host

Use a dedicated Linux VM with nested Docker support. Mount a separate persistent volume for each instance, and pass the three variables from the host environment. The inference endpoint must offer the `oma-hermes` model alias. Set a unique random gateway seed for each instance. The gateway key is the hex HMAC-SHA-256 of `default` for the default profile, or the profile ID for a coordinator, using that seed.

```sh
docker run --detach --name oma-vm --privileged \
  --mount type=volume,source=oma-vm-data,target=/opt/data \
  --publish 127.0.0.1:8642:8642 --publish 127.0.0.1:9119:9119 \
  --env OMA_LITELLM_URL --env OMA_LITELLM_KEY --env OMA_HERMES_GATEWAY_SEED \
  ghcr.io/openmarketing-agency/oma-vm:v0.1.0
```
