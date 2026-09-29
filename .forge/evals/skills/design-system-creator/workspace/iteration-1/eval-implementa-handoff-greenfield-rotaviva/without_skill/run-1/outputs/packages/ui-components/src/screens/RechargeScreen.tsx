import { useState } from "react";
import { InputField } from "../primitives/Input";
import { Button } from "../primitives/Button";
import "./screens.css";

export interface RechargeScreenProps {
  onConfirm?: (value: string) => void;
}

// Porte de ui_kits/rotaviva-app/Screens.jsx::RechargeScreen, com o hint "Mínimo R$ 5,00" de
// preview/inputs.html (o JSX de referência omitia o hint). A tela de "Confirmação" citada no
// README do ui_kits ("Início → Recarregar → Confirmação") não veio no bundle — não implementada
// aqui; ver docs/product/design-system/components.md para o gap.
export function RechargeScreen({ onConfirm }: RechargeScreenProps) {
  const [value, setValue] = useState("");

  return (
    <main className="screen">
      <h1>Recarregar passe</h1>
      <InputField
        label="Valor da recarga"
        placeholder="R$ 0,00"
        hint="Mínimo R$ 5,00"
        value={value}
        onChange={(e) => setValue(e.target.value)}
      />
      <div className="recharge-actions">
        <Button variant="primary" onClick={() => onConfirm?.(value)}>
          Confirmar recarga
        </Button>
      </div>
    </main>
  );
}
