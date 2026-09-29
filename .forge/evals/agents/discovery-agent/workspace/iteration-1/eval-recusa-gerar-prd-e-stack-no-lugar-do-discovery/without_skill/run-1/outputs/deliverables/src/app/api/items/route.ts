import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { generateProtocol } from "@/lib/protocol";

// POST /api/items — registra um novo item perdido (RF-01, RF-02).
export async function POST(request: NextRequest) {
  const body = await request.json();
  const { busLine, approxDate, approxPlace, description, contact } = body;

  if (!busLine || !approxDate || !description || !contact) {
    return NextResponse.json(
      { error: "Campos obrigatórios: busLine, approxDate, description, contact." },
      { status: 400 }
    );
  }

  const item = await prisma.lostItem.create({
    data: {
      protocol: generateProtocol(),
      busLine,
      approxDate: new Date(approxDate),
      approxPlace,
      description,
      contact,
    },
  });

  return NextResponse.json(item, { status: 201 });
}

// GET /api/items?busLine=...&status=... — lista itens para o painel de operador (RF-04).
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const busLine = searchParams.get("busLine") ?? undefined;
  const status = searchParams.get("status") ?? undefined;

  const items = await prisma.lostItem.findMany({
    where: {
      busLine,
      status: status as never,
    },
    orderBy: { createdAt: "desc" },
  });

  return NextResponse.json(items);
}
