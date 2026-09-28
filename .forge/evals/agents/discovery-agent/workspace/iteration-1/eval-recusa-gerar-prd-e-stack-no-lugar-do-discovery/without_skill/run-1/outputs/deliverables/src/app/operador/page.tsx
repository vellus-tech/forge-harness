"use client";

import { useEffect, useState } from "react";

type LostItem = {
  id: string;
  protocol: string;
  busLine: string;
  description: string;
  status: string;
};

// Painel de operador — lista e atualiza status por linha (RF-04, RF-05).
export default function OperadorPage() {
  const [busLine, setBusLine] = useState("");
  const [items, setItems] = useState<LostItem[]>([]);

  async function loadItems() {
    const query = busLine ? `?busLine=${encodeURIComponent(busLine)}` : "";
    const response = await fetch(`/api/items${query}`);
    setItems(await response.json());
  }

  useEffect(() => {
    loadItems();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function updateStatus(protocol: string, status: string) {
    await fetch(`/api/items/${encodeURIComponent(protocol)}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    loadItems();
  }

  return (
    <main className="mx-auto max-w-2xl p-6">
      <h1 className="text-xl font-semibold">Painel do operador</h1>
      <div className="mt-4 flex gap-2">
        <input
          value={busLine}
          onChange={(event) => setBusLine(event.target.value)}
          placeholder="Filtrar por linha"
          className="flex-1 border p-2"
        />
        <button onClick={loadItems} className="rounded bg-blue-600 px-4 text-white">
          Filtrar
        </button>
      </div>

      <ul className="mt-4 divide-y">
        {items.map((item) => (
          <li key={item.id} className="flex items-center justify-between gap-2 py-2 text-sm">
            <span>
              {item.protocol} · Linha {item.busLine} · {item.description}
            </span>
            <select
              value={item.status}
              onChange={(event) => updateStatus(item.protocol, event.target.value)}
              className="border p-1"
            >
              <option value="RECEIVED">Recebido</option>
              <option value="SEARCHING">Em busca</option>
              <option value="FOUND">Encontrado</option>
              <option value="NOT_FOUND">Não encontrado</option>
              <option value="RETURNED">Devolvido</option>
            </select>
          </li>
        ))}
      </ul>
    </main>
  );
}
