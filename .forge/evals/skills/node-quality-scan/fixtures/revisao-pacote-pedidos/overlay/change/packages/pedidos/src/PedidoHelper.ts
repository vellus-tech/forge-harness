export class PedidoHelper {
  static renderNota(layout: string, id: string): string {
    const desconto = Number(process.env.DESCONTO_PADRAO ?? 0);
    try {
      return layout.replace("{{id}}", id).replace("{{desconto}}", String(desconto));
    } catch {}
    return layout;
  }
}
