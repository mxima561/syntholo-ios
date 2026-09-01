#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

if [[ ! -f package.json || ! -f package-lock.json ]]; then
  echo "package.json and package-lock.json are required for content publication tests." >&2
  exit 1
fi

node_major=$(node -p 'process.versions.node.split(".")[0]')
if [[ "$node_major" != "22" ]]; then
  echo "Node 22 is required; found $(node --version)." >&2
  exit 1
fi

firebase_cli="$repository_root/node_modules/.bin/firebase"
if [[ ! -x "$firebase_cli" ]]; then
  echo "Pinned Node dependencies are missing. Run: npm ci" >&2
  exit 1
fi

expected_firebase_version=$(node -p 'require("./package.json").devDependencies["firebase-tools"]')
locked_firebase_version=$(node -p 'require("./package-lock.json").packages["node_modules/firebase-tools"].version')
actual_firebase_version=$("$firebase_cli" --version)
if [[ "$expected_firebase_version" != "$locked_firebase_version" \
      || "$actual_firebase_version" != "$locked_firebase_version" ]]; then
  echo "Firebase CLI version mismatch: package=$expected_firebase_version lock=$locked_firebase_version local=$actual_firebase_version" >&2
  exit 1
fi

expected_admin_version=$(node -p 'require("./package.json").devDependencies["firebase-admin"]')
locked_admin_version=$(node -p 'require("./package-lock.json").packages["node_modules/firebase-admin"].version')
installed_admin_version=$(node -p 'require("./node_modules/firebase-admin/package.json").version')
if [[ "$expected_admin_version" != "$locked_admin_version" \
      || "$installed_admin_version" != "$locked_admin_version" ]]; then
  echo "Firebase Admin version mismatch: package=$expected_admin_version lock=$locked_admin_version local=$installed_admin_version" >&2
  exit 1
fi

discover_java_home() {
  local candidate

  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    printf '%s\n' "$JAVA_HOME"
    return
  fi

  if candidate=$(/usr/libexec/java_home -v 21 2>/dev/null) \
      && [[ -x "$candidate/bin/java" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  for candidate in \
    /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$candidate/bin/java" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
    candidate=$(cd "$(dirname "$(command -v java)")/.." && pwd)
    printf '%s\n' "$candidate"
    return
  fi

  return 1
}

if ! discovered_java_home=$(discover_java_home); then
  echo "Java 21 is required for the Firestore emulator. Install Temurin/OpenJDK 21 or export JAVA_HOME; see docs/setup/firebase.md." >&2
  exit 1
fi
export JAVA_HOME=$discovered_java_home
export PATH="$JAVA_HOME/bin:$PATH"

java_major=$(java -version 2>&1 | sed -E -n '1s/.*version "([0-9]+).*/\1/p')
if [[ -z "$java_major" || "$java_major" -lt 21 ]]; then
  echo "Java 21 or newer is required; found: $(java -version 2>&1 | head -n 1)" >&2
  exit 1
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-content-publication.XXXXXX")
firebase_pid=""

terminate_process_tree() {
  local process_id=$1
  local child_id

  while IFS= read -r child_id; do
    [[ -n "$child_id" ]] && terminate_process_tree "$child_id"
  done < <(pgrep -P "$process_id" 2>/dev/null || true)

  kill -TERM "$process_id" 2>/dev/null || true
}

cleanup() {
  local exit_status=$?
  trap - EXIT INT TERM HUP
  set +e

  if [[ -n "$firebase_pid" ]] && kill -0 "$firebase_pid" 2>/dev/null; then
    terminate_process_tree "$firebase_pid"
    for _ in {1..50}; do
      kill -0 "$firebase_pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$firebase_pid" 2>/dev/null || true
    wait "$firebase_pid" 2>/dev/null || true
  fi

  rm -rf "$temporary_directory"
  exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT TERM HUP

read -r firestore_port firestore_websocket_port hub_port logging_port < <(
  node <<'NODE'
const net = require("node:net");

Promise.all(Array.from({ length: 4 }, () => new Promise((resolve, reject) => {
  const server = net.createServer();
  server.unref();
  server.on("error", reject);
  server.listen(0, "127.0.0.1", () => resolve(server));
}))).then((servers) => {
  const ports = servers.map((server) => server.address().port);
  console.log(ports.join(" "));
  servers.forEach((server) => server.close());
}).catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
)

firebase_config="$temporary_directory/firebase.test.json"
node - "$firebase_config" "$repository_root/firestore.rules" \
  "$repository_root/firestore.indexes.json" "$firestore_port" \
  "$firestore_websocket_port" "$hub_port" "$logging_port" <<'NODE'
const fs = require("node:fs");

const [
  configPath,
  rulesPath,
  indexesPath,
  firestorePort,
  firestoreWebsocketPort,
  hubPort,
  loggingPort,
] = process.argv.slice(2);
const config = {
  firestore: { rules: rulesPath, indexes: indexesPath },
  emulators: {
    firestore: {
      host: "127.0.0.1",
      port: Number(firestorePort),
      websocketPort: Number(firestoreWebsocketPort),
    },
    hub: { host: "127.0.0.1", port: Number(hubPort) },
    logging: { host: "127.0.0.1", port: Number(loggingPort) },
    singleProjectMode: true,
    ui: { enabled: false },
  },
};
fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
NODE

echo "Running curriculum publication tests with firebase-tools $actual_firebase_version and Java $java_major; isolated ports: Firestore=$firestore_port websocket=$firestore_websocket_port hub=$hub_port logging=$logging_port."

publication_output="$temporary_directory/curriculum-publication.tap.log"
"$firebase_cli" emulators:exec \
  --project syntholo-local \
  --config "$firebase_config" \
  --only firestore \
  "node --test --test-reporter=tap tests/firebase/curriculum-publication.test.mjs" \
  > "$publication_output" 2>&1 &
firebase_pid=$!

set +e
wait "$firebase_pid"
firebase_status=$?
set -e
firebase_pid=""

/usr/bin/sed -n 'p' "$publication_output"

if [[ "$firebase_status" -ne 0 ]]; then
  exit "$firebase_status"
fi

node ./scripts/assert_tap_summary.mjs 38 curriculum-publication-tests \
  < "$publication_output"

node - "$firestore_port" "$firestore_websocket_port" "$hub_port" "$logging_port" <<'NODE'
const net = require("node:net");
const ports = process.argv.slice(2).map(Number);
const checks = ports.map((port) => new Promise((resolve, reject) => {
  const socket = net.createConnection({ host: "127.0.0.1", port });
  socket.once("connect", () => {
    socket.destroy();
    reject(new Error(`Firestore emulator still listens on ${port} after firebase emulators:exec returned.`));
  });
  socket.once("error", () => resolve());
  setTimeout(() => {
    socket.destroy();
    resolve();
  }, 1000).unref();
}));
Promise.all(checks).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
NODE
