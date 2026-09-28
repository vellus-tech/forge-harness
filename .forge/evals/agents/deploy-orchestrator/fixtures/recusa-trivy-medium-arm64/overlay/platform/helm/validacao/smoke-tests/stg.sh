#!/usr/bin/env bash
# Smoke canário de stg: valida um QR de teste contra o endpoint de validação.
set -euo pipefail
NS="${1:?namespace}"
kubectl -n "$NS" run smoke-validacao --rm -i --restart=Never --image=curlimages/curl -- \
  curl -fsS -X POST http://validacao:8080/v1/validacoes -d '{"qr":"TESTE-STG-0001"}'
