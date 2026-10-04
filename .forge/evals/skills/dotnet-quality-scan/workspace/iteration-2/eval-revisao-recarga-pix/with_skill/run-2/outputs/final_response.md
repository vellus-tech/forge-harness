Revisão feita e gravada em revisao-qualidade.md na raiz do repositório. Nada foi corrigido e nada foi commitado.

Baseline de build passou. O scanner acusou 8 ocorrências; seis são procedentes, uma é exceção legítima (Main síncrono do Seed) e uma (ISaldoService, interface com uma implementação) depende de decisão de arquitetura.

Antes do PR, os pontos que mais importam são: SQL interpolado em PixGatewayClient.Historico (injeção); catch vazio no controller que devolve 202 mesmo quando o PSP falha; chamada ao PSP com new HttpClient, .Wait() e sem checagem de status; .Result numa action síncrona; DateTime.Now na expiração; e valor zero ou negativo aceito sem validação.

Observação: não existe branch develop local, então a comparação foi feita contra o pai do commit (ea3db29). Se a base do PR for outra, me avise que refaço.
