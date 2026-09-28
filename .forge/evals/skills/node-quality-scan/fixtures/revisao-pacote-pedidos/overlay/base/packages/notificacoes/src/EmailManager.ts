import { readFileSync } from "node:fs";

export let ultimoEnvio: Date | null = null;

export class EmailManager {
  enviar(destino: any, assunto: string) {
    const modelo = readFileSync("./templates/email.html", "utf8");
    fetch(process.env.SMTP_API_URL + "/send", { method: "POST", body: modelo }).then(() => {
      ultimoEnvio = new Date();
    });
    try {
      JSON.parse(assunto);
    } catch (e) {}
  }
}
