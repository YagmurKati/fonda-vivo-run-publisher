#!/usr/bin/env bash
# FONDA 2026-10-20: add whole-node energy, idle power, power over time and hourly grid carbon to a
# Kubernetes run on ONE node that scripts/publish-run.sh has already published.
# See collector/collect_k8s_node_power.py. scripts/publish-run.sh and the normal collector are not changed.
#
# Usage (on your computer, VPN connected, same config/publisher.env as for publish-run.sh):
#   scripts/add-node-power.sh RUN_ID
# Run it at least 12 minutes after the run ended (the quiet window after the run must have passed)
# and within 24 hours (Electricity Maps' hourly history covers the last 24 hours only).
#
# Changes nothing in VIVO or on the cluster: it copies the run's Turtle file from the PVC outbox
# (with a short-lived reader pod) and writes two Turtle files to node-power/RUN_ID/ for
# Site Admin > Add/Remove RDF data: first ..._REMOVE.ttl ("remove mixed RDF"), then ..._ADD.ttl
# ("add mixed RDF").
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

need_command kubectl
need_command python3
need_command curl
load_config

RUN_ID="${1:-}"
[[ "$RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Usage: $0 RUN_ID"
OUT="$ROOT_DIR/node-power/$RUN_ID"
mkdir -p "$OUT"
POD="fonda-outbox-reader-$(date +%s)"
IMAGE="nextflow/nextflow@sha256:b035b9fa7243ed09b9896c2b752d9e399f337827932bd45495efb0aed8e1dca1"
PF=""
cleanup() {
  [[ -n "$PF" ]] && kill "$PF" 2>/dev/null || true
  kubectl -n "$NS" delete pod "$POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== 1. Copy the run's Turtle file from the PVC $PVC_NAME"
kubectl -n "$NS" run "$POD" --restart=Never --image="$IMAGE" --overrides="{
  \"spec\": {
    \"nodeSelector\": {\"usedby\": \"$NODE_USEDBY\"},
    \"containers\": [{\"name\": \"reader\", \"image\": \"$IMAGE\", \"command\": [\"sleep\", \"900\"],
                      \"volumeMounts\": [{\"name\": \"work\", \"mountPath\": \"/workspace\", \"readOnly\": true}]}],
    \"volumes\": [{\"name\": \"work\", \"persistentVolumeClaim\": {\"claimName\": \"$PVC_NAME\", \"readOnly\": true}}]
  }}" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready "pod/$POD" --timeout=300s >/dev/null
remote="$(kubectl -n "$NS" exec "$POD" -- sh -c "ls -t /workspace/vivo-outbox/${RUN_ID}-[0-9]*T[0-9]*Z.ttl 2>/dev/null | head -1")"
[[ -n "$remote" ]] || die "No Turtle file for $RUN_ID in /workspace/vivo-outbox; publish the run first"
local_ttl="$OUT/$(basename "$remote")"
kubectl -n "$NS" exec "$POD" -- cat "$remote" > "$local_ttl"
echo "   $remote"

echo "== 2. Prometheus on localhost:19090"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://localhost:19090/-/ready || true)" != "200" ]]; then
  kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 19090:9090 >/dev/null 2>&1 &
  PF=$!
  for _ in $(seq 1 20); do
    [[ "$(curl -s -o /dev/null -w '%{http_code}' -m 2 http://localhost:19090/-/ready || true)" == "200" ]] && break
    sleep 1
  done
fi

echo "== 3. Node power, idle power and grid carbon"
python3 "$ROOT_DIR/collector/collect_k8s_node_power.py" --ttl "$local_ttl" --namespace "$NS" \
  --prom-url http://localhost:19090 --out-dir "$OUT"
echo
echo "Upload in VIVO (Site Admin > Add/Remove RDF data, format Turtle):"
echo "  1. the _REMOVE.ttl file with 'remove mixed RDF'"
echo "  2. the _ADD.ttl file with 'add mixed RDF'"
echo "To undo: the _ADD.ttl file with 'remove mixed RDF', then the _REMOVE.ttl file with 'add mixed RDF'."
