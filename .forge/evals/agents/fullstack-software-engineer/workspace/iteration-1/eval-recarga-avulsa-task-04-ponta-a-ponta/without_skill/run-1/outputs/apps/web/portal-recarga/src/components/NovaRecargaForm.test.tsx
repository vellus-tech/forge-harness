import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as client from "../api/client";
import { NovaRecargaForm } from "./NovaRecargaForm";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("NovaRecargaForm", () => {
  it("rejeita valor fora da faixa antes de chamar a API", async () => {
    const spy = vi.spyOn(client, "criarRecarga");
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor/i), "0,50");
    await userEvent.click(screen.getByRole("button", { name: /recarregar/i }));
    const alert = await screen.findByRole("alert");
    expect(alert.textContent).toMatch(/entre r\$ 1,00 e r\$ 500,00/i);
    expect(spy).not.toHaveBeenCalled();
  });

  it("bloqueia o formulário durante o envio e mostra sucesso ao concluir", async () => {
    let resolveCall: (v: { id: string; cartaoId: string; valorCentavos: number; status: "PENDENTE"; criadaEm: string }) => void = () => {};
    vi.spyOn(client, "criarRecarga").mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      }),
    );
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor/i), "10,00");
    const button = screen.getByRole("button", { name: /recarregar/i }) as HTMLButtonElement;
    await userEvent.click(button);

    expect(button.disabled).toBe(true);

    resolveCall({ id: "r1", cartaoId: "C1", valorCentavos: 1000, status: "PENDENTE", criadaEm: "2026-01-01T00:00:00.000Z" });
    const status = await screen.findByRole("status");
    expect(status.textContent).toMatch(/recarga.*sucesso|efetuada/i);
    expect(button.disabled).toBe(false);
  });

  it("exibe erro acessível quando a API rejeita", async () => {
    vi.spyOn(client, "criarRecarga").mockRejectedValue(new client.ApiError(400, "INVALID_BODY", "Valor deve estar entre R$ 1,00 e R$ 500,00."));
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor/i), "10,00");
    await userEvent.click(screen.getByRole("button", { name: /recarregar/i }));
    const alert = await screen.findByRole("alert");
    expect(alert.textContent).toMatch(/valor deve estar entre/i);
  });

  it("usa uma nova Idempotency-Key a cada envio bem-sucedido, mas reaproveita a mesma em caso de erro", async () => {
    const spy = vi
      .spyOn(client, "criarRecarga")
      .mockRejectedValueOnce(new client.ApiError(500, "UNKNOWN", "Erro inesperado."))
      .mockResolvedValueOnce({ id: "r1", cartaoId: "C1", valorCentavos: 1000, status: "PENDENTE", criadaEm: "2026-01-01T00:00:00.000Z" });

    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor/i), "10,00");
    await userEvent.click(screen.getByRole("button", { name: /recarregar/i }));
    await screen.findByRole("alert");

    await userEvent.click(screen.getByRole("button", { name: /recarregar/i }));
    await waitFor(() => expect(spy).toHaveBeenCalledTimes(2));

    const [firstCall, secondCall] = spy.mock.calls;
    expect(firstCall[0].idempotencyKey).toBe(secondCall[0].idempotencyKey);
  });
});
