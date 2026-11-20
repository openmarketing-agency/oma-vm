#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/versions.env"
image=${1:-oma-vm:local}
version=${image##*:}

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
context="$scratch/context"
mkdir -p "$context/omactl" "$scratch/oma"

release="https://github.com/openmarketing-agency/omactl/releases/download/$OMACTL_TAG"
package=omactl-linux-x64.tar.gz
curl -fsSL --retry 3 "$release/$package" -o "$scratch/$package"
curl -fsSL --retry 3 "$release/SHA256SUMS" -o "$scratch/SHA256SUMS"
(
    cd "$scratch"
    grep -E '^[a-f0-9]{64}  omactl-linux-x64\.tar\.gz$' SHA256SUMS | sha256sum -c -
    tar -xzf "$package" --no-same-owner -C "$context/omactl"
)
test -x "$context/omactl/bin/omactl"

git -C "$scratch/oma" init -q
git -C "$scratch/oma" fetch -q --no-tags --depth=1 \
    https://github.com/openmarketing-agency/openmarketing.agency.git "$OMA_SOURCE_COMMIT"
test "$(git -C "$scratch/oma" rev-parse FETCH_HEAD)" = "$OMA_SOURCE_COMMIT"
git -C "$scratch/oma" archive FETCH_HEAD playbooks skills oma/runtime/installer | tar -x -C "$context"
cp "$root"/{Dockerfile,prepare-seed.sh,bootstrap.py,start.sh,oma-soul.md} "$context/"

docker build --platform linux/amd64 --tag "$image" \
    --build-arg "OMA_AGENT_IMAGE=$OMA_AGENT_IMAGE" --build-arg "OMACTL_TAG=$OMACTL_TAG" \
    --build-arg "OMA_SOURCE_COMMIT=$OMA_SOURCE_COMMIT" --build-arg "OMA_VM_VERSION=$version" \
    "$context"
