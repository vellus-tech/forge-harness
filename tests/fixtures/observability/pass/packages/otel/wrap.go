package otel

import "fmt"

// Logger é o wrapper de instrumentação declarado em observability.wrapper_paths — a
// implementação DELE pode chamar o primitivo cru; é a fonte do logger estruturado, não
// uma violação do gate REQ-09b (arquivo excluído da varredura por estar sob wrapper_paths).
func rawSink(msg string) {
	fmt.Println(msg)
}
