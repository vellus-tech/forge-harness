export async function fetchInvoice(id: string) {
  const res = await fetch(`/api/invoices/${id}`);
  if (!res.ok) throw new Error((await res.json()).error.code);
  return res.json();
}
