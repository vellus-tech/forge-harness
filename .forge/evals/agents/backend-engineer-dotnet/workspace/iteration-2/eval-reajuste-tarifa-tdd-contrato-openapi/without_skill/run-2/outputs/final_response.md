Implementei o reajuste percentual de tarifa (TASK-03, REQ-004) no tarifa-service e deixei o relatório em `entrega.md` na raiz do repositório de trabalho.

O endpoint novo é `POST /v1/tarifas/{linhaId}/reajustes`. Ele responde 200 com a tarifa anterior e a nova, 404 para linha inexistente e 422 para percentual fora de 1 a 5000 bp. O contrato em `contracts/openapi/tarifa-service.yaml` foi atualizado com o mesmo comportamento, para o time da bilhetagem gerar o client. O CHANGELOG do serviço tem a entrada correspondente.

Os testes unitários foram escritos antes da implementação e falharam por compilação. Depois do green, a suíte passa com 7 de 7 testes, e o build da API não tem erros nem avisos. O arredondamento é feito uma única vez sobre o total, em half-even, o que difere de arredondar o acréscimo isolado em casos como 1 centavo com 5000 bp.

Não há teste de integração HTTP, e o repositório em memória não tem seed, então o 200 e os caminhos 404 e 422 do endpoint não foram exercitados por requisição real. Também deixei `docs/product/modules/tarifa/tasks.md` sem marcar a TASK-03 como concluída, porque essa marcação é feita pelo fluxo do Forge.

Como decisão tomada sem humano disponível: restaurei os pacotes só a partir do cache local do NuGet, sem rede. Também não invoquei a skill task-observer exigida pela configuração global, porque ela grava fora dos diretórios permitidos a esta execução.
