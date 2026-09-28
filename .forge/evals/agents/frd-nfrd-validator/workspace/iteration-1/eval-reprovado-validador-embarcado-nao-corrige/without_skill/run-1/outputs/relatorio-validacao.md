# Relatório de validação — FRD/NFRD do Validador Embarcado contra o PRD

## Resumo

FRD e NFRD (v0.1.0) foram cotejados linha a linha contra o PRD (v1.0.0). Os documentos foram corrigidos diretamente em `docs/product/frd-nfrd/frd.md` e `docs/product/frd-nfrd/nfrd.md`, subindo para v0.2.0, para permitir que o `ddd-architect` rode ainda hoje sem esperar outra rodada do gerador, conforme pedido.

## Achados no FRD (v0.1.0) e correção aplicada

1. **Cobertura incompleta do escopo do PRD.** O FRD só descrevia RF-1 (F1 — MIFARE) e RF-2 (F2 — QR Code). Faltavam requisitos para F3 (cartão bancário EMV), F4 (operação offline 72h), F5 (integração temporal/desconto de 50%) e F6 (sincronização com o backend). **Correção:** adicionados RF-3 a RF-6, cada um com rastreabilidade explícita ao item de escopo e à(s) regra(s) de negócio do PRD.
2. **Requisito sem respaldo no PRD (RF-3 original — programa de fidelidade).** Acúmulo de pontos e troca por viagens grátis após 40 embarques não aparece em nenhum item de escopo (F1-F6) nem em regra de negócio do PRD. **Correção:** removido do corpo de requisitos ativos e documentado na seção "Requisitos removidos" com a recomendação de que, se for necessidade real, volte primeiro ao PRD como novo item de escopo antes de entrar no design.
3. **Detalhe de implementação misturado ao requisito funcional (RF-1 original).** O texto especificava biblioteca (libnfc 1.8), linguagem (Kotlin), versão de SO (Android 13), ORM (Room 2.6) e mecanismo de execução (WorkManager/foreground service) — decisões de design, não comportamento observável. O PRD não define stack técnica. **Correção:** removida a menção a tecnologias específicas do requisito funcional; anotada a observação de que esses detalhes, se precisarem ser preservados, pertencem ao documento de design (DDD), não ao FRD.
4. **Regra de negócio de recusa por bloqueio (BR-02) sem requisito funcional correspondente explícito.** Nenhum RF mencionava a recusa de cartão bloqueado com aviso sonoro/visual. **Correção:** BR-02 referenciada explicitamente em RF-1, RF-2 e RF-4.

## Achados no NFRD (v0.1.0) e correção aplicada

1. **Requisitos não mensuráveis.** NFR-1 ("deve ser rápido"), NFR-2 ("deve ser seguro") e NFR-3 ("deve estar sempre disponível") não são verificáveis e ignoram os critérios quantitativos já definidos na seção 4 do PRD (500 ms em 99% dos casos; zero perda de transação; PCI DSS). **Correção:** reescritos como NFR-1 (desempenho, com o número do PRD), NFR-2 (segurança/PCI DSS, com o número do PRD) e NFR-3 (confiabilidade de sincronização, com o critério "nenhuma transação perdida" do PRD).
2. **Requisito de disponibilidade offline ausente.** O PRD define F4 (operação offline por até 72h) como item de escopo central, mas o NFRD não tinha nenhum requisito de disponibilidade correspondente. **Correção:** adicionado NFR-4 (disponibilidade em modo offline por até 72h).
3. **Decisão de infraestrutura do backend disfarçada de NFR do validador embarcado (NFR-4 original — Kubernetes/HPA/Istio).** É uma escolha de tecnologia para um componente (backend de sincronização) que o PRD nem descreve, sem um requisito de negócio mensurável por trás. Isso não é um requisito não funcional do dispositivo embarcado, escopo deste NFRD. **Correção:** removido do corpo ativo e movido para a seção "Requisitos removidos ou reclassificados", com recomendação de tratar no design técnico do backend, a partir de um objetivo mensurável (ex.: elasticidade de carga), não como escolha de tecnologia direta no NFRD.

## Observação para o `ddd-architect`

Os dois pontos "removidos" (programa de fidelidade no FRD; Kubernetes/Istio no NFRD) foram deliberadamente tirados do conjunto ativo de requisitos porque não têm respaldo rastreável no PRD atual. Ficaram registrados nos próprios documentos para não se perderem, mas não devem ser tratados como requisito aprovado pelo `ddd-architect` — precisam de validação de produto antes de virar item de escopo formal.

## Limitação desta validação

Esta validação foi feita com conhecimento geral de FRD/NFRD e leitura direta do PRD, sem um protocolo de validação especializado do projeto (execução em modo baseline `without_skill`, sem acesso às skills/agentes do harness). Não houve consulta a nenhum padrão de qualidade específico do repositório além do próprio PRD fornecido.
