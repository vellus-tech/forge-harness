import { CreditCardIcon } from "./icons";

export function PayButton({ onPay, disabled }: { onPay: () => void; disabled: boolean }) {
  return (
    <button type="button" onClick={onPay} disabled={disabled} className="pay-button" aria-label="Pagar">
      <CreditCardIcon />
    </button>
  );
}
