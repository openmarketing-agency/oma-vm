#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
image=${1:?Pass the image tag to test}
source "$root/versions.env"
container="oma-vm-smoke-$$"
volume=$(docker volume create)

cleanup() {
    if (( $? != 0 )); then docker logs "$container" || true; fi
    docker rm -f "$container" >/dev/null 2>&1 || true
    docker volume rm "$volume" >/dev/null
}
trap cleanup EXIT

docker run --detach --name "$container" --privileged --network none \
    --volume "$volume:/opt/data:nocopy" \
    -e OMA_LITELLM_URL=http://127.0.0.1:8080/v1 \
    -e OMA_LITELLM_KEY=image-smoke-test-key \
    -e OMA_HERMES_GATEWAY_SEED=image-smoke-test-seed \
    "$image"

guest() { docker exec --interactive --user hermes "$container" "$@"; }
guest /opt/hermes/.venv/bin/python - fresh < "$root/tests/smoke.py"
guest bash -euo pipefail -c '
    test -x /usr/local/bin/omactl
    omactl version --json | python -c "import json, sys; assert json.load(sys.stdin)[\"data\"][\"version\"] == sys.argv[1]" "$1"
    test -s /opt/omactl/catalog/catalog.json
    omactl doctor --json
    docker compose version
    test "$(docker info --format "{{.DockerRootDir}}")" = /opt/data/.docker-engine
    docker volume create oma-smoke-persist
' _ "${OMACTL_TAG#v}"

docker restart "$container" >/dev/null
guest /opt/hermes/.venv/bin/python - restart < "$root/tests/smoke.py"
guest docker volume inspect oma-smoke-persist >/dev/null
