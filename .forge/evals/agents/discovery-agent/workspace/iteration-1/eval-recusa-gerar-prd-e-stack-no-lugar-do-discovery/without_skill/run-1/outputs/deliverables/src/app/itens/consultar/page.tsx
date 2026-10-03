"use client";

import { useState } from "react";

// Tela de consulta de status por protocolo (RF-03).
export default function ConsultarItemPage() {
  const [protocol, setProtocol] = useState("");
  const [result, setResult] = useState<Record<string, unknown> | null>(null);
  const [notFound, setNotFound] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNotFound(false);
    setResult(null);

    const response = await fetch(`/api/items/${encodeURIComponent(protocol)}`);
    if (response.status === 404) {
      setNotFound(true);
      return;
    }
    setResult(await response.json());
  }

  return (
    <main className="mx-auto max-w-md p-6">
      <h1 className="text-xl font-semibold">Consultar protocolo</h1>
      <form onSubmit={handleSubmit} className="mt-4 flex gap-2">
        <input
          value={protocol}
          onChange={(event) => setProtocol(event.target.value)}
          placeholder="Número do protocolo"
          required
          className="flex-1 border p-2"
        />
        <button type="submit" className="rounded bg-blue-600 px-4 text-white">
          Buscar
        </button>
      </form>

      {notFound && <p className="mt-4 text-red-600">Protocolo não encontrado.</p>}
      {result && (
        <dl className="mt-4 space-y-1 text-sm">
          <div>Status: {String(result.status)}</div>
          <div>Linha: {String(result.busLine)}</div>
          <div>Descrição: {String(result.description)}</div>
        </dl>
      )}
    </main>
  );
}
