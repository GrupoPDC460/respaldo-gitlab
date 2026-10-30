#!/usr/bin/env bash
# Copia cada repo de GitHub (GH_OWNER) a GitLab (GL_GROUP): ramas y tags.
# Crea el proyecto en GitLab (privado) si todavía no existe.
set -uo pipefail
[ -n "${GL_TOKEN:-}" ] || { echo "::error::Falta el secret GITLAB_TOKEN"; exit 1; }
[ -n "${GL_GROUP:-}" ] || { echo "::error::Falta la variable GITLAB_GROUP"; exit 1; }
API="https://$GL_HOST/api/v4"
enc(){ python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
gl(){ curl -sS -H "PRIVATE-TOKEN: $GL_TOKEN" "$@"; }

ns_id=$(gl "$API/namespaces/$(enc "$GL_GROUP")" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
[ -n "$ns_id" ] || { echo "::error::No encuentro '$GL_GROUP' en GitLab o el token no tiene acceso"; exit 1; }

repos=$(curl -sS -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/users/$GH_OWNER/repos?per_page=100&type=owner" |
  python3 -c 'import json,sys;[print(r["name"]) for r in json.load(sys.stdin) if not r.get("fork") and r["name"]!="respaldo-gitlab"]')

ok=0; fallos=0
for repo in $repos; do
  echo "── $repo"
  code=$(gl -o /dev/null -w '%{http_code}' "$API/projects/$(enc "$GL_GROUP/$repo")")
  if [ "$code" = 404 ]; then
    code=$(gl -o /tmp/nuevo.json -w '%{http_code}' -X POST "$API/projects" \
      --data-urlencode "name=$repo" --data-urlencode "path=$repo" \
      --data "namespace_id=$ns_id&visibility=private&initialize_with_readme=false")
    if [ "$code" != 201 ]; then echo "::warning::No pude crear $repo en GitLab (HTTP $code)"; fallos=$((fallos+1)); continue; fi
    echo "   proyecto creado en GitLab (privado)"
  fi
  rm -rf /tmp/espejo
  if ! git clone -q --bare "https://github.com/$GH_OWNER/$repo.git" /tmp/espejo; then
    echo "::warning::No pude clonar $repo"; fallos=$((fallos+1)); continue; fi
  dest="https://oauth2:$GL_TOKEN@$GL_HOST/$GL_GROUP/$repo.git"
  if git -C /tmp/espejo push -q "$dest" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*' 2>&1; then
    echo "   al día"; ok=$((ok+1))
  else
    echo "::warning::Falló el push de $repo (¿alguien hizo cambios directo en GitLab?)"; fallos=$((fallos+1))
  fi
done
echo "Resultado: $ok repos al día, $fallos con problema."
[ "$fallos" = 0 ]
