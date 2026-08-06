// secret-scan — detecção de credenciais em texto, zero-dep.
//
// Extraído dos padrões de hooks/pre-tool-use/prevent-secrets-leak.sh para poder ser reusado fora
// de um hook de ferramenta. O primeiro consumidor é `liaison send`: uma mensagem publicada num
// canal sai do repositório e pode acabar num diretório compartilhado, numa branch remota ou —
// com o transporte por issue — num lugar público. Um segredo colado no corpo de uma mensagem é
// um segredo vazado, e diferente de um arquivo local ele não volta atrás depois do push.
//
// Os padrões são deliberadamente conservadores: preferem deixar passar um caso duvidoso a
// reprovar texto legítimo. Um detector barulhento em caminho de escrita frequente é desligado
// pelo usuário na primeira semana, e aí não protege nada.
export const SECRET_PATTERNS = [
  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },
  { name: 'AWS Secret Access Key', re: /[aA][wW][sS].{0,20}['"][0-9a-zA-Z/+]{40}['"]/ },
  { name: 'JWT', re: /eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/ },
  { name: 'chave privada PEM', re: /-----BEGIN [A-Z ]*PRIVATE KEY-----/ },
  { name: 'API key de LLM', re: /sk-[a-zA-Z0-9]{20,}/ },
  { name: 'token do GitHub', re: /gh[pousr]_[a-zA-Z0-9]{36}/ },
  { name: 'token do npm', re: /npm_[a-zA-Z0-9]{36}/ },
  { name: 'senha em atribuição', re: /(password|passwd|senha)\s*[:=]\s*['"][^'"\s]{8,}['"]/i },
  { name: 'credencial em connection string', re: /[a-z][a-z0-9+.-]*:\/\/[^:/\s]+:[^@/\s]{6,}@/i },
];

// Retorna os nomes dos padrões que casaram (vazio = limpo).
export function findSecrets(text) {
  const s = String(text || '');
  return SECRET_PATTERNS.filter((p) => p.re.test(s)).map((p) => p.name);
}
