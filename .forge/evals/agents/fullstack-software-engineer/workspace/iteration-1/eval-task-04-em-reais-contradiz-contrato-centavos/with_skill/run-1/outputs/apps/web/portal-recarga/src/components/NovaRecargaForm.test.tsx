import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as client from "../api/client";
import { NovaRecargaForm } from "./NovaRecargaForm";

afterEach(() => vi.restoreAllMocks());

describe("NovaRecargaForm", () => {
  it("rejeita valor fora da faixa sem chamar a API (REQ-02)", async () => {
    const spy = vi.spyOn(client, "criarRecarga");
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor da recarga/i), "999");
    fireEvent.click(screen.getByRole("button", { name: /fazer recarga/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/entre R\$/i);
    expect(spy).not.toHaveBeenCalled();
  });

  it("envia valor em centavos e usa a mesma Idempotency-Key em cada tentativa (DD-001, REQ-03)", async () => {
    const spy = vi.spyOn(client, "criarRecarga").mockResolvedValue({
      id: "R1",
      cartaoId: "C1",
      valorCentavos: 2550,
      status: "PENDENTE",
      criadaEm: "2026-09-20T00:00:00.000Z",
    });
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor da recarga/i), "25,50");
    fireEvent.click(screen.getByRole("button", { name: /fazer recarga/i }));
    await screen.findByText(/recarga solicitada com sucesso/i);
    expect(spy).toHaveBeenCalledWith({ cartaoId: "C1", valorCentavos: 2550 }, expect.any(String));
  });

  it("bloqueia o formulário enquanto a solicitação está em andamento (REQ-04)", async () => {
    let resolveFn: (() => void) | undefined;
    vi.spyOn(client, "criarRecarga").mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveFn = () =>
            resolve({ id: "R1", cartaoId: "C1", valorCentavos: 100, status: "PENDENTE", criadaEm: "2026-09-20T00:00:00.000Z" });
        }),
    );
    render(<NovaRecargaForm cartaoId="C1" />);
    await userEvent.type(screen.getByLabelText(/valor da recarga/i), "1");
    fireEvent.click(screen.getByRole("button", { name: /fazer recarga/i }));
    expect(screen.getByRole("button", { name: /enviando/i })).toBeDisabled();
    expect(screen.getByLabelText(/valor da recarga/i)).toBeDisabled();
    resolveFn?.();
  });
});
