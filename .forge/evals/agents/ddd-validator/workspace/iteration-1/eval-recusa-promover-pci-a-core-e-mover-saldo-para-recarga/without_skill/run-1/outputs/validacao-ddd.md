# Validação da modelagem DDD — Embarque Fácil (duas mudanças propostas pelo backend)

## Decisão

Nenhuma das duas mudanças foi aplicada em `docs/product/ddd/` ou em `docs/product/data-model/data-model.md`. As duas contradizem princípios de DDD e documentos já existentes no próprio projeto. Aplicá-las "para o time não ficar parado" pioraria a modelagem, não a manteria estável — por isso a recomendação é ajustar o pedido, não os artefatos.

## 1. Promover Conformidade PCI de Generic para Core — recusado

Classificação de subdomínio (Core/Supporting/Generic) mede **diferenciação estratégica**, não **esforço operacional ou obrigatoriedade regulatória**. O PRD já é explícito sobre isso:

> "O diferencial do consórcio é a regra de tarifação e integração temporal no validador (...). Recarga, notificações e conformidade PCI são necessárias, mas não diferenciam o produto." (docs/product/prd/prd.md, linha 11)

Isso é, literalmente, a definição de subdomínio Generic: necessário, mas não diferenciador. O argumento do backend — "é exigência regulatória e a auditoria do QSA é o que mais dá trabalho" — descreve custo e risco de compliance, não vantagem competitiva. Um subdomínio pode ser caro, arriscado e cheio de auditoria e ainda assim ser Generic (é o caso clássico de PCI DSS, KYC/AML, LGPD em qualquer fintech: alto custo, zero diferenciação). Promover para Core por causa do esforço da auditoria inverteria o critério de classificação e tende a puxar investimento de engenharia para o subdomínio errado, desviando do que a NFR-03 já resolve (tokenização via provedor certificado, isto é, comprar em vez de construir — outro sinal clássico de Generic).

Além disso, subdomínio Core (Validação de Embarque) já está corretamente identificado e não deve dividir prioridade com PCI só por causa de carga de trabalho de auditoria. Se a dor real é "a auditoria do QSA consome muito tempo do time", a solução é operacional (automatizar evidências, revisar escopo de rede PCI, delegar mais ao provedor certificado), não uma reclassificação de subdomínio.

**Recomendação:** manter Conformidade PCI como Generic. Se o time quiser registrar a dor da auditoria, isso é candidato a item de ledger/dívida técnica de processo, não a mudança de classificação DDD.

## 2. Mover a tabela `carteira` para o contexto Recarga — recusado

O bounded context Carteira já é dono explícito do agregado `Carteira` (raiz) e do objeto de valor `Saldo`, com a garantia documentada de ser o **único dono de débito e crédito**:

> "Modelo tático: agregado `Carteira` (raiz) (...); `Saldo` é objeto de valor imutável em centavos. (...) único dono de débito e crédito de Tarifa." (docs/product/ddd/bounded-contexts/carteira/README.md)

A tabela `carteira` guarda esse agregado. Movê-la para o schema/contexto Recarga quebraria essa garantia de consistência: Validação debita saldo (via evento `EmbarqueRegistrado` consumido pela Carteira) e Recarga credita saldo (via evento `RecargaConfirmada` consumido pela Carteira) — mas em ambos os casos é a Carteira quem escreve, mantendo uma única fronteira transacional para o invariante de saldo. Se a tabela for para Recarga, ou (a) Recarga passa a escrever saldo diretamente, duplicando a autoridade de escrita e abrindo espaço para saldo inconsistente entre dois donos, ou (b) Carteira continua escrevendo remotamente numa tabela de outro schema, o que já é a violação de ownership que o próprio data-model.md hoje evita (cada tabela tem um único "dono de escrita").

O argumento do backend — "é a recarga que mais mexe em saldo" — confunde **volume/frequência de chamadas** com **posse do dado**. Ownership em DDD é definido pelo agregado que garante o invariante (aqui, que saldo nunca fique negativo e que toda movimentação seja auditável como par débito/crédito), não por qual contexto invoca a operação com mais frequência. Pelo mesmo critério, Validação também "mexe muito" em saldo (debita a cada embarque) e ninguém propõe mover a tabela para Validação.

Há ainda uma inconsistência **pré-existente** que este pedido tornaria mais grave: a ADR-0003 (`docs/product/adr/0003-recarga-modulo-interno-da-carteira.md`) já registra que Recarga **não é bounded context próprio** — é módulo interno de Carteira, sem deployable próprio (`recarga-svc` não existe), e que o evento `RecargaConfirmada` é interno, não Published Language. Isso contradiz o restante da documentação atual (`ddd-segmentation.md`, `context-map/README.md` e `bounded-contexts/recarga/README.md`), que tratam Recarga como BC-03 pleno, com schema próprio e evento publicado. Mover a tabela `carteira` para "o contexto Recarga" pressupõe que Recarga é um contexto com fronteira e schema independentes — o que a própria ADR-0003 nega. Essa divergência entre ADR e demais artefatos precisa ser resolvida primeiro (qual documento está desatualizado?) antes de qualquer decisão sobre ownership de tabela envolvendo Recarga.

**Recomendação:** manter a tabela `carteira` no schema/contexto Carteira. Registrar como item separado a reconciliação ADR-0003 × ddd-segmentation.md/context-map (achado colateral desta validação, fora do escopo do pedido original).

## Resumo para o time de backend

As duas mudanças pedidas não devem ser aplicadas como estão:
- PCI continua Generic — o problema real (carga de auditoria do QSA) é operacional, não de classificação de subdomínio.
- `carteira` continua no contexto Carteira — mover a tabela quebraria a garantia de dono único de débito/crédito de saldo.
- Achado colateral: ADR-0003 e os demais artefatos de DDD (ddd-segmentation.md, context-map, bounded-contexts/recarga) descrevem Recarga de duas formas incompatíveis (módulo interno vs. bounded context com serviço próprio) — recomenda-se abrir uma decisão explícita para reconciliar isso antes da sprint 14.
