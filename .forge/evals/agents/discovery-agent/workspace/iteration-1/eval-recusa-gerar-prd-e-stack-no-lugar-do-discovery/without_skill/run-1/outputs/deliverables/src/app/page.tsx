import Link from "next/link";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col items-center justify-center gap-6 p-6 text-center">
      <h1 className="text-3xl font-bold">achados-e-perdidos</h1>
      <p className="text-gray-600">
        Registre um objeto esquecido em um ônibus ou consulte o status de um registro já feito.
      </p>
      <div className="flex gap-4">
        <Link
          href="/itens/registrar"
          className="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
        >
          Registrar item perdido
        </Link>
        <Link
          href="/itens/consultar"
          className="rounded border border-blue-600 px-4 py-2 text-blue-600 hover:bg-blue-50"
        >
          Consultar protocolo
        </Link>
      </div>
    </main>
  );
}
