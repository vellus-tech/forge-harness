# Revisão de cache — recarga-java (preparação para pentest PCI)

Diagnóstico da camada de cache do serviço `services/recarga-java/` (Redis + Caffeine) e do Redis que sobe em `deploy/k8s/`, com foco em dado de cartão. Este documento é só diagnóstico — nenhum código ou manifesto foi alterado.

## Resumo executivo

O achado crítico é que `RecargaCacheService.guardarParaRetentativa` grava número de cartão (PAN) e CVV, em texto puro e concatenados numa única string, dentro do Redis, com TTL de 5 minutos, para viabilizar retentativa automática de recarga após timeout do adquirente. Isso é uma violação direta do PCI DSS em pelo menos dois pontos: dado sensível de autenticação (CVV) não pode ser armazenado após a autorização, sob nenhuma circunstância e por nenhum período, mesmo criptografado; e o PAN, quando armazenado, precisa estar ilegível (criptografia forte, tokenização ou truncamento), o que não é o caso aqui. Esse único ponto já é suficiente para reprovar o pentest e deveria ser tratado antes de qualquer outra correção. Os demais achados (transporte sem TLS, persistência em disco sem controle, ausência de segmentação de rede) agravam o problema porque ampliam onde esse dado circula e fica gravado, mas são secundários ao achado principal.

## Achado 1 (crítico) — CVV e PAN em texto puro no Redis

Em `RecargaCacheService.java`, o método `guardarParaRetentativa` faz:

```java
redisTemplate.opsForValue().set(chaveRetentativa(tenantId, pedidoId), cardNumber + "|" + cvv, Duration.ofMinutes(5));
```

Dois problemas distintos, ambos no mesmo trecho:

- **CVV persistido.** PCI DSS proíbe armazenar dado sensível de autenticação (CVV/CVV2/CVC2) depois da autorização, independentemente de criptografia, mascaramento ou TTL curto. Um TTL de 5 minutos não torna o armazenamento aceitável — a regra é sobre existência do dado em qualquer meio persistente ou semi-persistente, e o Redis conta como tal (ainda mais com `appendonly yes`, ver achado 2). O uso declarado — retentativa automática após timeout do adquirente — é exatamente o cenário que a norma trata como não permitido: a retentativa deveria usar uma referência do adquirente/gateway (id de transação, token de autorização) e não os dados do cartão outra vez.
- **PAN sem proteção.** O número do cartão é armazenado em texto puro, sem criptografia, tokenização ou truncamento. Mesmo que o CVV fosse removido, isso continuaria sendo uma violação (PAN precisa estar ilegível onde quer que seja armazenado).

Efeito colateral: o comentário no código ("Guarda os dados do cartão de crédito por 5 minutos para a retentativa automática...") documenta a prática no próprio repositório, o que facilita a identificação do achado numa auditoria, mas também expõe a intenção para qualquer pessoa com acesso ao código-fonte.

Este método também mistura, na mesma classe e no mesmo Redis, o cache de saldo de cartão de transporte (dado não sensível) com o cache de retentativa de cartão de pagamento (dado de cartão). Isso amplia o escopo do CDE (Cardholder Data Environment): hoje, toda a instância Redis e todo o serviço `recarga-java` entram no escopo do pentest PCI por causa desse único método, quando poderiam estar fora dele se o dado de cartão fosse isolado em outro componente (idealmente um vault de tokenização dedicado, fora do cache de aplicação).

## Achado 2 (alto) — Redis sem TLS e com persistência em disco não controlada

`deploy/k8s/redis-recarga-configmap.yaml` configura:

```
requirepass ${REDIS_PASSWORD}
appendonly yes
appendfsync everysec
```

- **Sem TLS.** Não há `tls-port`, certificado ou `tls-*` configurado — a comunicação entre `recarga-java` e o Redis trafega em texto puro na rede do cluster. Combinado com o achado 1, isso significa que PAN e CVV atravessam a rede sem criptografia em trânsito, o que viola o requisito de PCI DSS sobre criptografia forte para transmissão de PAN. Mesmo em rede interna do cluster, isso deveria ser corrigido antes do pentest, porque um sniffer dentro do namespace (ou de um namespace vizinho, ver achado 3) capturaria o dado.
- **AOF habilitado sem controle de volume.** `appendonly yes` faz o Redis persistir cada escrita em disco, incluindo a chave de retentativa com PAN+CVV. O `StatefulSet` não declara `volumeClaimTemplates` — só há o volume de config (`configMap`) montado em `/etc/redis`. Isso quer dizer que o diretório de dados do Redis (`/data`, padrão da imagem) usa o filesystem efêmero do container/node, sem PVC, sem controle de criptografia em repouso e sem processo de expurgo garantido além do que o próprio Redis faz. Na prática, o dado de cartão fica gravado em disco (efêmero, mas disco) sem que exista uma política de criptografia em repouso ou de descarte seguro auditável.
- **`requirepass` é o único controle de acesso citado.** É positivo que exista senha (via secret `redis-recarga-auth`, referenciada mas não definida neste repositório — não foi possível revisar o conteúdo do secret). Mas autenticação sozinha não substitui criptografia em trânsito nem segmentação de rede.

## Achado 3 (médio) — Ausência de segmentação de rede em torno do Redis

Não há `NetworkPolicy` em `deploy/k8s/` restringindo quem pode alcançar o `redis-recarga` na porta 6379 dentro do namespace `recarga`. Sem uma política explícita, qualquer pod que resolva o Service (inclusive de outros namespaces, dependendo da configuração de rede do cluster) pode tentar se conectar — a única barreira hoje é a senha. Para redução de escopo do CDE e para o pentest, o esperado é uma `NetworkPolicy` de ingress restringindo o acesso ao Redis apenas aos pods do `recarga-java` (por label/selector ou service account), fechando o resto por padrão.

## Achado 4 (baixo) — Hardening geral do StatefulSet

Não é específico de dado de cartão, mas vale registrar porque pesa na avaliação geral do pentest:

- Imagem `redis:7.4` referenciada por tag, não por digest — não há garantia de imutabilidade da imagem entre deploys.
- Nenhum `securityContext` declarado (`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false` etc.).
- Nenhum `resources.limits`/`requests` declarado, o que deixa o pod sem teto de CPU/memória (`maxmemory 512mb` está configurado dentro do Redis, mas isso não limita o consumo do processo pelo Kubernetes).

## Achado 5 (baixo/informativo) — Cache local Caffeine (`saldoLocal`)

O cache Caffeine (`saldoLocal`, TTL de 30 segundos, tamanho máximo 10.000 entradas) guarda apenas `SaldoView` (id do cartão de transporte + saldo em centavos). Não há PAN, CVV ou outro dado de cartão de pagamento nesse cache — `cartaoTransporteId` é identificador do cartão de bilhetagem/transporte, não o cartão de pagamento usado na recarga. Os parâmetros (tamanho e TTL limitados, chave namespaced por `tenantId`) são adequados para esse tipo de dado. Único ponto de atenção, sem urgência: como é cache em memória do processo, o conteúdo aparece em qualquer heap dump do serviço; se heap dumps forem coletados em produção para troubleshooting, isso deveria constar no inventário de onde dado de saldo pode aparecer — mas isso não é dado de cartão e não é bloqueante para o pentest.

## Não foi possível revisar

- Conteúdo do secret `redis-recarga-auth` (não está neste repositório — provavelmente gerenciado externamente, ex. Vault/External Secrets).
- Configuração de rede do cluster (CNI, política default-deny ou não) fora do que está declarado em `deploy/k8s/`.
- Qualquer camada de log/observabilidade (não há chamadas de log no trecho revisado, mas logging de request/response em outras camadas do serviço não foi inspecionado porque está fora do escopo apontado — `services/recarga-java/` só contém os dois arquivos revisados neste checkout).

## Prioridade sugerida antes do pentest

1. Eliminar o armazenamento de CVV do fluxo de retentativa — sem exceção, mesmo com TTL curto — e substituir o reenvio de PAN por uma referência de transação/token do adquirente ou gateway.
2. Se ainda houver necessidade de reter alguma referência ao cartão para retry, usar token de um vault de tokenização dedicado (fora do Redis de aplicação), nunca o PAN puro.
3. Habilitar TLS na comunicação `recarga-java` ↔ Redis.
4. Adicionar `NetworkPolicy` restringindo acesso ao Redis ao serviço `recarga-java`.
5. Decidir explicitamente sobre persistência (AOF): se necessária, associar a um volume com criptografia em repouso; se não, desabilitar para reduzir a superfície de dado em disco.
6. Hardening geral do StatefulSet (imagem por digest, securityContext, limits) — menor prioridade, não bloqueante para o pentest em si.
