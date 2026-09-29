export function publicar(topico: string, payload: unknown) {
  console.log(JSON.stringify({ topico, payload }));
}
