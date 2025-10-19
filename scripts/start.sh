#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# GitHex Docker start helper
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: scripts/start.sh [options]

Run the GitHex Docker image. Builds the image automatically if it is missing.

Options:
  -t, --tag <value>   Image tag to run (defaults to package version or 'latest')
  -n, --name <value>  Container name (defaults to githex)
  -p, --port <value>  Host port to expose (defaults to 8001)
  -d, --detach        Run container in detached mode
  -h, --help          Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_BASENAME="githex-app"
TAG=""
ENV_FILE="$PROJECT_ROOT/.env"
CONTAINER_NAME="githex"
HOST_PORT="8001"
DETACH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tag)
      TAG="$2"
      shift 2
      ;;
    -n|--name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    -p|--port)
      HOST_PORT="$2"
      shift 2
      ;;
    -d|--detach)
      DETACH=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TAG" ]]; then
  if [[ -f "$PROJECT_ROOT/package.json" ]]; then
    TAG="$(grep '"version"' "$PROJECT_ROOT/package.json" | head -n 1 | cut -d '"' -f4)"
  fi
  TAG="${TAG:-latest}"
fi

IMAGE_NAME="${IMAGE_BASENAME}:${TAG}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but not installed or not on PATH." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Environment file not found: $ENV_FILE" >&2
  exit 1
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[githex] Image '${IMAGE_NAME}' not found locally; building..."
  "$SCRIPT_DIR/build.sh" --tag "$TAG"
fi

RUN_ARGS=(
  --rm
  --name "$CONTAINER_NAME"
  --env-file "$ENV_FILE"
  -p "${HOST_PORT}:8001"
)

if $DETACH; then
  RUN_ARGS+=(-d)
else
  RUN_ARGS+=(-it)
fi

echo "[githex] Starting container '${CONTAINER_NAME}' from image '${IMAGE_NAME}' on port ${HOST_PORT}"
docker run "${RUN_ARGS[@]}" "$IMAGE_NAME"
