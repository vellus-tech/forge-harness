// lib/red-classify.mjs — classifica um texto de saída de teste como 'behavioral' |
// 'build-error' | 'unknown' (rule testing/regression-red-first.md, item normativo 1:
// "falha de build na árvore pré-correção não é Red; é ruído disfarçado de evidência").
// Zero-dependência, puro (nenhum I/O aqui — o caller decide de onde vem o texto: excerpt
// registrado em evidence/red/*.json na Onda B, ou saída real de teste no replay da Onda C).
//
// Tabela exportada para o gate poder testar cada assinatura isoladamente (w106 [8]).
//
// Furo 8 (correção): a prioridade incondicional de build sobre behavioral causava falsos
// positivos reais — "AssertionError: expected [Function] to throw SyntaxError but got Error"
// (uma asserção sobre uma exceção, texto claramente comportamental) classificava como
// build-error só porque a palavra "SyntaxError" aparece embutida na mensagem. A prioridade
// agora é BEHAVIORAL-primeiro: uma assinatura comportamental clara vence qualquer assinatura
// de build que apareça no mesmo texto — o caso realista de ambíguidade genuína (build error
// de verdade que por acaso contém uma palavra de assertion framework) é bem mais raro do que
// o inverso. Como reforço estrutural (não só a inversão de prioridade), as assinaturas de
// build mais sujeitas a aparecer embutidas em prosa (SyntaxError/ImportError/
// ModuleNotFoundError) são ancoradas ao início de linha — o formato real de traceback
// (Python/Node) sempre as emite como a primeira coisa na linha, nunca no meio de uma frase.
// Isso também distingue, no formato pytest, a linha "ImportError: ..." de uma falha real de
// import/coleta (início de linha, sem prefixo) da linha "E   ImportError: ..." dentro do
// relatório de uma asserção pytest (prefixo "E   " — ver BEHAVIORAL_SIGNATURES abaixo).

export const BUILD_ERROR_SIGNATURES = [
  // JS/TS — ancorado: SyntaxError como PRIMEIRA coisa na linha (traceback real), nunca
  // embutido em prosa de asserção ("...to throw SyntaxError but got...").
  { lang: 'js-ts', label: 'SyntaxError', re: /^SyntaxError\b/m },
  { lang: 'js-ts', label: 'Cannot find module', re: /Cannot find module/ },
  { lang: 'js-ts', label: 'tsc error TSxxxx', re: /\berror TS\d{2,5}\b/ },
  // .NET
  { lang: 'dotnet', label: 'CSxxxx', re: /\berror CS\d{4}\b/ },
  { lang: 'dotnet', label: 'MSBuild error', re: /\berror MSB\d{4}\b|MSBuild error/i },
  // Java/Kotlin
  { lang: 'java-kotlin', label: 'cannot find symbol', re: /cannot find symbol/ },
  { lang: 'java-kotlin', label: 'compilation failed', re: /compilation failed/i },
  { lang: 'java-kotlin', label: 'javac/kotlinc error:', re: /\.(java|kt|kts):\d+:\s*error:/ },
  // Python — ancorado ao início de linha (sem indentação): distingue do "E   ImportError: ..."
  // que o pytest imprime DENTRO do relatório de uma asserção (esse é behavioral, não build).
  { lang: 'python', label: 'ImportError', re: /^ImportError\b/m },
  { lang: 'python', label: 'ModuleNotFoundError', re: /^ModuleNotFoundError\b/m },
  // Go
  { lang: 'go', label: 'undefined:', re: /\bundefined:\s/ },
  { lang: 'go', label: 'build failed', re: /\bbuild failed\b/i },
];

export const BEHAVIORAL_SIGNATURES = [
  { framework: 'generic', label: 'AssertionError', re: /\bAssertionError\b/ },
  { framework: 'jest-vitest', label: 'Expected/Received diff', re: /\bExpected\b[\s\S]{0,200}\bReceived\b/ },
  { framework: 'xunit', label: 'xUnit assertion failure', re: /Xunit\.Sdk\.|Assert\.\w+\(\)\s+Failure/ },
  { framework: 'junit', label: 'JUnit assertion failed', re: /org\.opentest4j\.AssertionFailedError|junit\.framework\.AssertionFailedError/ },
  { framework: 'junit4', label: 'JUnit 4 ComparisonFailure', re: /expected:<[^>]*>\s+but was:<[^>]*>/ },
  // pytest: linha de detalhe de falha (prefixo "E   ") ANCORADA no formato real que o pytest
  // emite — "E   assert ..." ou "E   <Algo>Error/<Algo>Exception: ..." (asserção sobre exceção
  // capturada, ex. pytest.raises). Furo 10 (correção): a versão anterior (`^E\s+\S`) casava
  // QUALQUER linha começando com "E " — inclusive prosa sem relação nenhuma com pytest — e
  // behavioral vence build na prioridade, então um "E " solto classificava texto arbitrário
  // como comportamental.
  { framework: 'pytest', label: 'pytest failure detail line', re: /^E\s+(?:assert\b|\w*(?:Error|Exception)\b)/m },
  // Go
  { framework: 'go', label: '--- FAIL:', re: /^--- FAIL:/m },
  // Rust
  { framework: 'rust', label: 'assertion left/right failed', re: /assertion `left(?: == | != )right` failed|assertion failed: `\(left == right\)`/ },
  // RSpec
  { framework: 'rspec', label: 'RSpec Failure/Error', re: /^\s*Failure\/Error:/m },
  // PHPUnit
  { framework: 'phpunit', label: 'PHPUnit Failed asserting', re: /Failed asserting that/ },
];

// classify(text): 'behavioral' se qualquer assinatura de framework de asserção casar (vence
// build — ver nota acima); senão 'build-error' se qualquer assinatura de build casar; senão
// 'unknown' (texto vazio, ilegível, ou sem assinatura reconhecida — nunca inventa uma
// classificação para não gerar Red falso).
export function classify(text) {
  if (typeof text !== 'string' || !text.trim()) return 'unknown';
  for (const sig of BEHAVIORAL_SIGNATURES) if (sig.re.test(text)) return 'behavioral';
  for (const sig of BUILD_ERROR_SIGNATURES) if (sig.re.test(text)) return 'build-error';
  return 'unknown';
}
