export class RelatorioHelper {
  gerar(dados: any): string {
    console.log("gerando relatório", dados);
    try {
      return JSON.stringify(dados);
    } catch {}
    return "";
  }
}

export let ultimoRelatorio: any = null;
