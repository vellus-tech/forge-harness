# Bounded Contexts — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação DDD inicial |

Nove bounded contexts, cada um em correspondência 1:1 com um subdomínio — a segmentação não juntou nem partiu subdomínios porque nenhum deles, examinado à luz de PRD/FRD/NFRD/TRD, mostrou dois modelos concorrentes que justificassem split, nem sobreposição de linguagem que justificasse fusão, exceto o ponto de atenção do glossário (seção 4 do glossário) sobre o termo "validação".

## 1. Embarque (Boarding)
Dono da decisão de embarque: recebe cartão + linha, consulta a projeção local de saldo/bloqueio (replicada da Carteira), aplica a regra de integração temporal e decide aprovar/negar em até 300 ms, inclusive offline. Publica o evento de embarque ocorrido para os contextos a jusante. Modelo: `Embarque`, `DecisaoDeEmbarque`, `TarifaVigente`, `JanelaDeIntegracao`.

## 2. Clearing (Revenue Settlement)
Dono da apuração e do repasse diário. Consome embarques já ocorridos, atribui cada um à operadora dona da linha e fecha um arquivo de repasse imutável por dia; correção pós-publicação vira arquivo de ajuste, nunca reescrita. Modelo: `ApuracaoDiaria`, `LancamentoDeRepasse`, `ArquivoDeAjuste`.

## 3. Carteira (Wallet)
Dono do saldo, da lista de bloqueio e do histórico de viagens do passageiro. É a fonte de verdade que Embarque replica localmente nos validadores. Modelo: `Carteira`, `SaldoDisponivel`, `Bloqueio`, `LancamentoDeSaldo`.

## 4. Recarga (Top-up)
Dono do processo de compra de crédito — pelo app (via Integração de Pagamentos) ou no ponto de venda (registro manual). Não guarda saldo; ao concluir, emite comando/evento para a Carteira creditar. Modelo: `PedidoDeRecarga`, `RecargaEmDinheiro`, `RecargaViaCartao`.

## 5. Frota de Validadores (Validator Fleet)
Dono do inventário de equipamentos, do protocolo de sincronização em lote e da tradução (anticorruption layer) do formato proprietário ValidaBus para os eventos canônicos do domínio Tarifa Viva. Também propaga bloqueios de cartão para os validadores na próxima sincronização. Modelo: `Validador`, `LoteDeSincronizacao`, `EventoValidaBusBruto` (não sai do contexto).

## 6. Cadastro de Linhas e Operadoras (Route & Operator Registry)
Dono do dado mestre "linha pertence a operadora" e da tarifa vigente por linha. Open Host Service consumido em leitura por Embarque e por Clearing. Modelo: `Linha`, `Operadora`, `TabelaDeTarifas`.

## 7. Identidade do Passageiro (Passenger Identity)
Dono de credenciais, sessão e MFA. Modelo: `ContaDoPassageiro`, `Credencial`, `Sessao`.

## 8. Notificações (Push Notification)
Dono do envio de avisos ao passageiro; hoje só saldo baixo, mas desenhado para crescer. Modelo: `Notificacao`, `PreferenciaDeNotificacao`.

## 9. Integração com Meios de Pagamento (Payment Gateway Integration)
Anticorruption layer para o adquirente de cartão de crédito e o PSP de Pix. Nunca persiste dado de cartão (NFR-03) — trafega só token e resultado de autorização. Modelo: `AutorizacaoDePagamento`, `TokenDeCartao` (opaco, emitido pelo adquirente).

## 10. Por que não fundir Embarque com Frota de Validadores
A tentação óbvia é uma só: "é tudo o validador". Mas Frota de Validadores fala o protocolo instável de um fornecedor terceiro (TEC-03) e sua responsabilidade é isolar essa instabilidade; Embarque fala a linguagem do negócio (tarifa, integração, saldo) e precisa ficar estável mesmo quando o fornecedor muda de firmware. Fundir os dois vazaria o modelo de dados do ValidaBus para dentro da regra de tarifação — exatamente o tipo de acoplamento que uma ACL existe para evitar.

## 11. Por que não fundir Carteira com Recarga
Carteira é o dono do saldo; Recarga é um processo de aquisição de crédito com dois caminhos completamente diferentes (cartão de crédito via adquirente, dinheiro no PDV) que não compartilham invariante nenhuma entre si além de "no final, credita a Carteira". Manter Recarga separada permite adicionar um terceiro canal de recarga (ex.: boleto, Pix direto) sem tocar no modelo de saldo.
