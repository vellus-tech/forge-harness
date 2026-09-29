#!/usr/bin/env bash
# Gate de wave do projeto: roda os testes unitários de test/.
set -euo pipefail
node --test test/*.test.js
