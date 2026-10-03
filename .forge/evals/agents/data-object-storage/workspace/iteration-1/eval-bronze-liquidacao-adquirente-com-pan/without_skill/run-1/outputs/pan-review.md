# Revisão — numero_cartao completo no bronze da liquidação

## Veredito sobre "o cartão está coberto pelo SSE-KMS"

Não está. SSE-KMS com Bucket Key protege o objeto contra acesso não autorizado ao *storage*
(alguém lendo o disco/backup do S3 sem passar pela API), mas qualquer principal com
`s3:GetObject` no bucket e `kms:Decrypt` na chave lê o parquet e enxerga o `numero_cartao`
completo em texto claro — que é exatamente o PAN definido pelo PCI DSS. Criptografia de
storage não substitui proteção do dado: é o mesmo controle que já existia; não reduz o escopo
PCI da tabela nem satisfaz Requirement 3 (tornar o PAN ilegível onde armazenado, ex.:
truncamento/masking para exibição, tokenização, hashing forte, ou criptografia forte de
campo com gestão de chave e acesso segregados do restante do lake).

Consequência prática: todo pipeline, engenheiro de dados, analista ou job downstream com
acesso de leitura ao bronze — que tende a ser um público mais amplo do que o de produção —
passa a ter acesso ao PAN completo. Isso expande a superfície de acesso ao cardholder data
em vez de restringi-la.

## Object Lock COMPLIANCE de 10 anos piora o problema, não é neutro

Object Lock em modo COMPLIANCE é desenhado para ser irreversível: nem a conta root consegue
apagar ou reduzir a retenção antes do prazo. Aplicar isso ao prefixo `bronze/liquidacao/`
enquanto o job grava o PAN em claro significa: se um arquivo com PAN completo for ingerido
por engano, ou se surgir uma exigência de expurgo (ex.: direito ao esquecimento, resposta a
incidente, redução de escopo PCI), **não há como remover esse dado por até 10 anos**. Você
estaria fixando uma exposição de dado sensível de forma imutável, exatamente o oposto do que
se quer ao endurecer o armazenamento.

## Recomendação

Antes de ligar o Object Lock neste prefixo, resolver a proteção do PAN na origem — não depois:

1. **Preferencial:** tokenizar o `numero_cartao` no momento da ingestão (job troca o valor por
   um token de um serviço/vault de tokenização, ou grava apenas BIN (6 primeiros) + últimos 4
   dígitos, que é o padrão de PAN mascarado aceito pelo PCI DSS para uso operacional). O valor
   completo, se for mesmo necessário para reconciliação com a adquirente, fica em um
   componente separado, com escopo PCI próprio, chave e política de acesso restritas — não
   junto de todo o lake de pagamentos.
2. Se a bronze precisa manter fidelidade bruta por design (padrão comum em arquitetura
   medalhão, para permitir reprocessamento), então o Object Lock de 10 anos não deveria valer
   para esse arquivo enquanto ele contiver PAN em claro — ou o dado bruto fica numa zona de
   *landing* transitória (TTL curto, acesso mínimo) e só o que segue para bronze já vem tratado.
3. Qualquer que seja a rota, IAM de leitura no prefixo bronze precisa ser revisto: hoje, SSE-KMS
   com Bucket Key não impõe granularidade nenhuma além de quem já tem `s3:GetObject`.

Não apliquei nenhuma mudança em `jobs/ingestao_liquidacao.py` — a mudança na engenharia de
tratamento do PAN é uma decisão de produto/segurança (qual estratégia de tokenização, se
precisa do valor completo em algum lugar, qual o novo esquema de colunas) que extrapola o
pedido original (Object Lock + bucket policy no Terraform). Ver `job-proposta.patch` neste
diretório para uma proposta de referência (mascaramento BIN+últimos 4), não aplicada.
