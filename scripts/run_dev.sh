#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/study-space-dev"
mkdir -p "$LOG_DIR"
export PATH="$HOME/.local/bin:$PATH"

DB_CONTAINER="learnhouse-db-dev"
REDIS_CONTAINER="learnhouse-redis-dev"

ensure_container() {
  local name="$1"
  shift
  if docker container inspect "$name" >/dev/null 2>&1; then
    docker start "$name" >/dev/null 2>&1 || true
  else
    docker run -d --name "$name" "$@" >/dev/null
  fi
}

wait_for_dependencies() {
  local attempt
  for attempt in {1..30}; do
    if docker exec "$DB_CONTAINER" pg_isready -U learnhouse >/dev/null 2>&1 \
      && docker exec "$REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "PostgreSQL or Redis did not become ready in time." >&2
  exit 1
}

ensure_container "$DB_CONTAINER" \
  -e POSTGRES_USER=learnhouse \
  -e POSTGRES_PASSWORD=learnhouse \
  -e POSTGRES_DB=learnhouse \
  -p 5432:5432 \
  -v learnhouse_db_dev_data:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

ensure_container "$REDIS_CONTAINER" \
  -p 6379:6379 \
  -v learnhouse_redis_dev_data:/data \
  redis:8.6.1-alpine redis-server --appendonly yes

wait_for_dependencies

SECRETS_FILE="$ROOT_DIR/.dev-secrets"
if [[ ! -f "$SECRETS_FILE" ]]; then
  {
    printf 'LEARNHOUSE_AUTH_JWT_SECRET_KEY=%s\n' "$(openssl rand -base64 32 | tr -d '=+/\n' | cut -c1-43)"
    printf 'COLLAB_INTERNAL_KEY=%s\n' "$(openssl rand -base64 32 | tr -d '=+/\n' | cut -c1-43)"
    printf 'LEARNHOUSE_INITIAL_ADMIN_PASSWORD=%s\n' "$(openssl rand -base64 18 | tr -d '=+/\n' | cut -c1-24)"
  } > "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
fi

# shellcheck disable=SC1090
set -a
source "$SECRETS_FILE"
if [[ -f "$ROOT_DIR/apps/api/.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/apps/api/.env"
fi
set +a

export LEARNHOUSE_SQL_CONNECTION_STRING="postgresql+asyncpg://learnhouse:learnhouse@localhost:5432/learnhouse"
export LEARNHOUSE_REDIS_CONNECTION_STRING="redis://localhost:6379/0"
export LEARNHOUSE_DEVELOPMENT_MODE=true
export LEARNHOUSE_PORT=1338
export LEARNHOUSE_HOST=0.0.0.0
export LEARNHOUSE_DOMAIN="localhost:3000"
export LEARNHOUSE_FRONTEND_DOMAIN="localhost:3000"
export LEARNHOUSE_INITIAL_ADMIN_EMAIL="${LEARNHOUSE_INITIAL_ADMIN_EMAIL:-admin@school.dev}"
export LEARNHOUSE_AI_PROVIDER="${LEARNHOUSE_AI_PROVIDER:-openai}"
export LEARNHOUSE_AI_MODEL_FAST="${LEARNHOUSE_AI_MODEL_FAST:-gpt-4o-mini}"
export LEARNHOUSE_AI_MODEL_STANDARD="${LEARNHOUSE_AI_MODEL_STANDARD:-gpt-4o-mini}"
export LEARNHOUSE_AI_MODEL_PRO="${LEARNHOUSE_AI_MODEL_PRO:-gpt-4o-mini}"
export LEARNHOUSE_AI_EMBEDDING_PROVIDER="${LEARNHOUSE_AI_EMBEDDING_PROVIDER:-openai}"
export LEARNHOUSE_AI_EMBEDDING_MODEL="${LEARNHOUSE_AI_EMBEDDING_MODEL:-text-embedding-3-small}"
if [[ -n "${LEARNHOUSE_AI_API_KEY:-}" ]]; then
  export LEARNHOUSE_IS_AI_ENABLED=true
fi
export NEXT_PUBLIC_LEARNHOUSE_BACKEND_URL=http://localhost:1338
export NEXT_PUBLIC_COLLAB_URL=ws://localhost:4000

export COLLAB_PORT=4000
export LEARNHOUSE_API_URL=http://localhost:1338
export LEARNHOUSE_REDIS_URL=redis://localhost:6379

PIDS=()
cleanup() {
  trap - EXIT INT TERM
  if ((${#PIDS[@]})); then
    kill "${PIDS[@]}" 2>/dev/null || true
    wait "${PIDS[@]}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

(
  cd "$ROOT_DIR/apps/api"
  uv run uvicorn app:app --host 0.0.0.0 --port 1338 --log-level info
) >"$LOG_DIR/api.log" 2>&1 &
PIDS+=("$!")

(
  cd "$ROOT_DIR/apps/collab"
  bun run start
) >"$LOG_DIR/collab.log" 2>&1 &
PIDS+=("$!")

(
  cd "$ROOT_DIR/apps/web"
  if [[ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]]; then
    mkdir -p "$LOG_DIR/node"
    NODE_BIN="$(npx --yes --prefix "$LOG_DIR/node" node@20 -p 'process.execPath')"
    export PATH="$(dirname "$NODE_BIN"):$PATH"
  fi
  bun run dev
) >"$LOG_DIR/web.log" 2>&1 &
PIDS+=("$!")

echo "Study Space is starting."
echo "Web:   http://localhost:3000"
echo "API:   http://localhost:1338"
echo "Collab: ws://localhost:4000"
echo "Logs:  $LOG_DIR"
echo "Admin: ${LEARNHOUSE_INITIAL_ADMIN_EMAIL}"
echo "Password: $(grep '^LEARNHOUSE_INITIAL_ADMIN_PASSWORD=' "$SECRETS_FILE" | cut -d= -f2-)"

wait -n "${PIDS[@]}"
status=$?
echo "A service exited with status $status. Check logs in $LOG_DIR." >&2
exit "$status"
