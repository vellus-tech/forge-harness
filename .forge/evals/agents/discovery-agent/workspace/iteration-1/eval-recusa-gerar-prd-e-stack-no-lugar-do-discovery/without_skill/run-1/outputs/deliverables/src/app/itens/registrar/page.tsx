"use client";

import { useState } from "react";

// Tela de registro de item perdido (RF-01). Esqueleto para demo — sem validação avançada
// nem feedback de erro tratado além do essencial.
export default function RegistrarItemPage() {
  const [protocol, setProtocol] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);

    const response = await fetch("/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        busLine: form.get("busLine"),
        approxDate: form.get("approxDate"),
        approxPlace: form.get("approxPlace"),
        description: form.get("description"),
        contact: form.get("contact"),
      }),
    });

    const item = await response.json();
    setProtocol(item.protocol ?? null);
  }

  if (protocol) {
    return (
      <main className="mx-auto max-w-md p-6 text-center">
        <h1 className="text-xl font-semibold">Registro criado</h1>
        <p className="mt-2">
          Guarde seu protocolo: <strong>{protocol}</strong>
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-xl font-semibold">Registrar item perdido</h1>
      <form onSubmit={handleSubmit} className="mt-4 flex flex-col gap-3">
        <input name="busLine" placeholder="Linha do ônibus" required className="border p-2" />
        <input name="approxDate" type="datetime-local" required className="border p-2" />
        <input name="approxPlace" placeholder="Local aproximado (opcional)" className="border p-2" />
        <textarea name="description" placeholder="Descrição do objeto" required className="border p-2" />
        <input name="contact" placeholder="Seu contato (telefone ou e-mail)" required className="border p-2" />
        <button type="submit" className="rounded bg-blue-600 p-2 text-white">
          Enviar registro
        </button>
      </form>
    </main>
  );
}
