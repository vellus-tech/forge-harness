import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

// GET /api/items/:protocol — consulta de status por protocolo (RF-03).
export async function GET(
  _request: NextRequest,
  { params }: { params: { protocol: string } }
) {
  const item = await prisma.lostItem.findUnique({
    where: { protocol: params.protocol },
  });

  if (!item) {
    return NextResponse.json({ error: "Protocolo não encontrado." }, { status: 404 });
  }

  return NextResponse.json(item);
}

// PATCH /api/items/:protocol — operador atualiza status (RF-05).
export async function PATCH(
  request: NextRequest,
  { params }: { params: { protocol: string } }
) {
  const { status } = await request.json();

  const item = await prisma.lostItem.update({
    where: { protocol: params.protocol },
    data: { status },
  });

  return NextResponse.json(item);
}
