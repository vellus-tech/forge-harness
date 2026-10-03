import { Pool } from 'pg';

const db = new Pool({ connectionString: process.env.DATABASE_URL });

export async function confirmarPedido(pedidoId: string): Promise<void> {
  await db.query('UPDATE public.pedidos SET status = $1, atualizado_em = now() WHERE id = $2', ['CONFIRMADO', pedidoId]);
}
