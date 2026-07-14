#!/usr/bin/env bash
# Print a bearer token for the Twenty SUT (for API-level testbot flows).
#
# Twenty authenticates over GraphQL at the /metadata endpoint (NOT /graphql — that path
# serves the workspace-data schema and has no auth mutations). Two steps:
#   1) getLoginTokenFromCredentials(email, password, origin) -> loginToken
#   2) getAuthTokensFromLoginToken(loginToken, origin)        -> tokens.accessOrWorkspaceAgnosticToken.token
#
# Seeded dev user: tim@apple.dev; the dev seed sets the password equal to the email
# (frontend prefills password: 'tim@apple.dev'). Override creds via env.
# NOTE: Twenty's auth mutations shift between releases — if this fails, confirm the
#       mutation names/shape against packages/twenty-front/src/modules/auth against the
#       cloned HEAD and adjust. UI/DOM testbot flows use the recorded browser session
#       (storageState) instead and do not need this script.
set -euo pipefail
BASE="${TWENTY_BASE_URL:-http://localhost:2020}"
EMAIL="${TWENTY_EMAIL:-tim@apple.dev}"
PASSWORD="${TWENTY_PASSWORD:-tim@apple.dev}"
ORIGIN="${TWENTY_ORIGIN:-$BASE}"

login_token="$(curl -sf -m 15 -X POST "$BASE/metadata" \
  -H 'content-type: application/json' -H "origin: $ORIGIN" \
  --data @- <<JSON | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['getLoginTokenFromCredentials']['loginToken']['token'])"
{"operationName":"GetLoginTokenFromCredentials",
 "query":"mutation GetLoginTokenFromCredentials(\$email:String!,\$password:String!,\$origin:String!){getLoginTokenFromCredentials(email:\$email,password:\$password,origin:\$origin){loginToken{token}}}",
 "variables":{"email":"$EMAIL","password":"$PASSWORD","origin":"$ORIGIN"}}
JSON
)"

curl -sf -m 15 -X POST "$BASE/metadata" \
  -H 'content-type: application/json' -H "origin: $ORIGIN" \
  --data @- <<JSON | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['getAuthTokensFromLoginToken']['tokens']['accessOrWorkspaceAgnosticToken']['token'])"
{"operationName":"GetAuthTokensFromLoginToken",
 "query":"mutation GetAuthTokensFromLoginToken(\$loginToken:String!,\$origin:String!){getAuthTokensFromLoginToken(loginToken:\$loginToken,origin:\$origin){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
 "variables":{"loginToken":"$login_token","origin":"$ORIGIN"}}
JSON
