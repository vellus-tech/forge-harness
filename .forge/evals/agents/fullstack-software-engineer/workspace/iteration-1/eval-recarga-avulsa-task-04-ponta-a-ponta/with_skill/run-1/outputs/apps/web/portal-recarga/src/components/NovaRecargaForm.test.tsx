// @vitest-environment jsdom
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { ApiError } from "../api/client";
import { NovaRecargaForm } from "./NovaRecargaForm";

vi.mock("../api/client", async () => {
  const actual = await vi.importActual<typeof import("../api/client")>("../api/client");
  return { ...actual, criarRecarga: vi.fn() };
});

import { criarRecarga } from "../api/client";

const criarRecargaMock = vi.mocked(criarRecarga);

async function preencherEEnviar(valor: string) {
  const user = userEvent.setup();
  render(<NovaRecargaForm cartaoId="C1" />);
  await user.type(screen.getByLabelText("Valor da recarga (R$)"), valor);
  await user.click(screen.getByRole("button", { name: /solicitar recarga/i }));
  return user;
}

describe("NovaRecargaForm", () => {
  it("rejeita valor abaixo de R$ 1,00 sem chamar a API (REQ-02)", async () => {
    await preencherEEnviar("0,50");

    expect(await screen.findByRole("alert")).toHaveTextContent("Informe um valor entre R$ 1,00 e R$ 500,00.");
    expect(criarRecargaMock).not.toHaveBeenCalled();
  });

  it("rejeita valor acima de R$ 500,00 sem chamar a API (REQ-02)", async () => {
    await preencherEEnviar("501,00");

    expect(await screen.findByRole("alert")).toHaveTextContent("Informe um valor entre R$ 1,00 e R$ 500,00.");
    expect(criarRecargaMock).not.toHaveBeenCalled();
  });

  it("desabilita o botão durante o envio e mostra sucesso ao concluir (REQ-04)", async () => {
    let resolver: (value: Awaited<ReturnType<typeof criarRecarga>>) => void = () => {};
    criarRecargaMock.mockReturnValue(
      new Promise((resolve) => {
        resolver = resolve;
      }),
    );

    const user = userEvent.setup();
    render(<NovaRecargaForm cartaoId="C1" />);
    await user.type(screen.getByLabelText("Valor da recarga (R$)"), "10,00");
    await user.click(screen.getByRole("button", { name: /solicitar recarga/i }));

    expect(screen.getByRole("button", { name: /enviando/i })).toBeDisabled();

    resolver({ id: "r1", cartaoId: "C1", valorCentavos: 1000, status: "PENDENTE", criadaEm: "2026-09-26T12:00:00.000Z" });

    expect(await screen.findByRole("status")).toHaveTextContent("Recarga solicitada com sucesso.");
  });

  it("exibe erro acessível quando a API rejeita a solicitação", async () => {
    criarRecargaMock.mockRejectedValue(new ApiError(409, "RECARGA_EM_ANDAMENTO", "Já existe uma recarga em andamento."));

    await preencherEEnviar("10,00");

    const alerta = await screen.findByRole("alert");
    expect(alerta).toHaveTextContent("Já existe uma recarga em andamento.");
  });

  it("mantém a mesma Idempotency-Key em reenvios da mesma solicitação (REQ-03)", async () => {
    criarRecargaMock.mockRejectedValueOnce(new Error("falha de rede"));
    criarRecargaMock.mockResolvedValueOnce({
      id: "r1",
      cartaoId: "C1",
      valorCentavos: 1000,
      status: "PENDENTE",
      criadaEm: "2026-09-26T12:00:00.000Z",
    });

    const user = await preencherEEnviar("10,00");
    await waitFor(() => expect(criarRecargaMock).toHaveBeenCalledTimes(1));

    await user.click(screen.getByRole("button", { name: /solicitar recarga/i }));
    await waitFor(() => expect(criarRecargaMock).toHaveBeenCalledTimes(2));

    const [, , primeiraChave] = criarRecargaMock.mock.calls[0]!;
    const [, , segundaChave] = criarRecargaMock.mock.calls[1]!;
    expect(segundaChave).toBe(primeiraChave);
  });
});
