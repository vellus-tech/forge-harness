# NFRD (rascunho provisório) — Portal do Lojista: Link de Pagamento (Cartão e Pix)

> **Aviso de status:** este documento é um rascunho provisório, gerado sem um PRD aprovado. O comitê de produto só decide o escopo do MVP em 2026-10-02. Os requisitos abaixo foram inferidos a partir das notas de discovery (`docs/discovery/discovery-notes.md`) e de práticas padrão de mercado para produtos de pagamento — **não** representam decisão de produto validada e devem ser revisados e ratificados assim que o PRD existir. Qualquer trabalho de arquitetura que comece a partir deste rascunho corre o risco de retrabalho se o comitê definir escopo diferente do assumido aqui.

## Por que este documento é um rascunho, não um NFRD definitivo

Um NFRD (Non-Functional Requirements Document) normalmente deriva de um PRD e de um FRD já aprovados, porque requisitos não funcionais (disponibilidade, performance, segurança, retenção de dados) dependem de decisões de escopo que ainda não foram tomadas: volume-alvo, SLA comercial, política de retenção de dados de clientes, e se o MVP cobre cartão e Pix simultaneamente ou em fases. Gerar o NFRD antes do PRD inverte a ordem normal do processo e obriga a arquitetura a trabalhar sobre suposições, não sobre requisitos aprovados.

Ainda assim, para não bloquear o trabalho de arquitetura amanhã, este rascunho consolida o que já é conhecido pelas notas de discovery e sinaliza explicitamente onde há lacuna.

## Fontes

- `docs/discovery/discovery-notes.md` — entrevistas com 8 lojistas do varejo de bairro (2026-09-15 e 2026-09-17).
- Nenhum PRD ou FRD disponível na data deste rascunho (2026-09-26).

## Requisitos não funcionais inferidos

### 1. Performance / Tempo de resposta
- **Origem:** "Reclamação recorrente com o concorrente: o link 'demora' para abrir."
- **Requisito provisório:** o link de pagamento gerado deve abrir e ficar pronto para pagamento em até 2 segundos (p95) em conexão móvel 4G, para não repetir a queixa relatada sobre o concorrente.
- **Lacuna:** não há meta de latência formalizada pelo comitê; o número acima é uma referência de mercado para checkout leve, não uma meta aprovada.

### 2. Disponibilidade / Resiliência a picos
- **Origem:** "o painel 'cai' na Black Friday."
- **Requisito provisório:** o serviço de geração e pagamento de link deve manter disponibilidade de pelo menos 99,9% no mês corrido, com capacidade para absorver picos sazonais (Black Friday, datas comemorativas) sem degradação perceptível — implica auto-scaling ou dimensionamento com margem sobre o pico observado no concorrente.
- **Lacuna:** não há dado de volume de pico esperado; só o volume médio informado (abaixo).

### 3. Capacidade / Volume
- **Origem:** "Volume informal: lojistas médios geram de 30 a 200 links por dia."
- **Requisito provisório:** dimensionar para até 200 links/dia por lojista em regime normal, com headroom para múltiplos de pico (ex.: 5x a 10x) em datas sazonais — o multiplicador exato depende de decisão do comitê.
- **Lacuna:** número de lojistas simultâneos no MVP (dezenas? centenas?) não foi definido — impacta diretamente o dimensionamento de infraestrutura.

### 4. Privacidade e retenção de dados
- **Origem:** "Dois lojistas perguntaram se os dados dos clientes ficam guardados e por quanto tempo."
- **Requisito provisório:** definir e comunicar uma política de retenção de dados de clientes (nome, telefone/e-mail, dados de pagamento) compatível com LGPD, com prazo de retenção explícito e mecanismo de exclusão sob solicitação.
- **Lacuna crítica:** esta é uma decisão de produto e compliance, não uma inferência técnica — o comitê precisa decidir prazo de retenção, base legal de tratamento e se há dado de cartão armazenado (o que traria escopo PCI DSS) ou se o link apenas redireciona para um gateway tokenizado.

### 5. Segurança de pagamento
- **Origem:** inferência a partir do tipo de produto (link de pagamento com cartão e Pix), não citada explicitamente nas notas.
- **Requisito provisório:** toda captura de dado de cartão deve ocorrer via gateway/tokenização certificados PCI DSS, nunca em infraestrutura própria não certificada; transações Pix devem seguir os requisitos de segurança do arranjo Pix (BACEN).
- **Lacuna:** não há definição de qual gateway/adquirente será usado nem se a empresa pretende ampliar seu próprio escopo PCI DSS.

## O que falta para este NFRD ser aprovável

1. PRD aprovado pelo comitê (2026-10-02) definindo escopo do MVP (cartão, Pix, ou ambos desde o dia um).
2. FRD com os fluxos funcionais detalhados (criação de link, compartilhamento, conciliação, estorno).
3. Decisão de política de retenção de dados e enquadramento LGPD/PCI DSS.
4. Meta de SLA comercial (disponibilidade, tempo de resposta) formalizada, não apenas inferida de reclamação sobre concorrente.
5. Estimativa de volume de lojistas ativos no MVP e multiplicador de pico esperado.

## Recomendação

Usar este rascunho como insumo de discussão para a arquitetura preliminar (proof-of-concept, escolha de gateway, esboço de arquitetura de alto nível), mas não como base para dimensionamento de infraestrutura de produção nem para compromissos de SLA com lojistas, até o PRD sair e este documento ser revisado formalmente.
