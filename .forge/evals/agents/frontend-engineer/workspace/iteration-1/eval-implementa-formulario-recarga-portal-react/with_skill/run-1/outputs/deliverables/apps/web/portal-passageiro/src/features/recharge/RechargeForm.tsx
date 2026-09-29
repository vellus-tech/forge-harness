import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useMutation } from '@tanstack/react-query';
import { Button } from '@bilhetagem/ui';
import { RechargeBusinessError, requestRecharge, type RechargeResponse } from '../../services/rechargeService';
import {
  MAX_AMOUNT_CENTS,
  MIN_AMOUNT_CENTS,
  QUICK_AMOUNTS_CENTS,
  centsToFieldValue,
  formatCents,
  generateIdempotencyKey,
  parseAmountToCents,
} from './amount';
import styles from './RechargeForm.module.css';

const schema = z.object({ amount: z.string() }).superRefine((data, ctx) => {
  const cents = parseAmountToCents(data.amount);
  if (cents === null) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['amount'], message: 'Informe um valor.' });
    return;
  }
  if (cents < MIN_AMOUNT_CENTS || cents > MAX_AMOUNT_CENTS) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['amount'],
      message: `Informe um valor entre ${formatCents(MIN_AMOUNT_CENTS)} e ${formatCents(MAX_AMOUNT_CENTS)}.`,
    });
  }
});

type FormValues = z.infer<typeof schema>;

export function RechargeForm({ cardId }: { cardId: string }) {
  const [businessErrorMessage, setBusinessErrorMessage] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { amount: '' } });

  const currentAmountCents = parseAmountToCents(watch('amount'));

  const mutation = useMutation<RechargeResponse, Error, FormValues>({
    mutationFn: (values) => {
      const cents = parseAmountToCents(values.amount);
      if (cents === null) {
        return Promise.reject(new Error('Valor inválido.'));
      }
      return requestRecharge({ cardId, amountCents: cents, idempotencyKey: generateIdempotencyKey() });
    },
    onError: (error) => {
      setBusinessErrorMessage(
        error instanceof RechargeBusinessError ? error.message : 'Não foi possível concluir a recarga. Tente novamente.',
      );
    },
  });

  function selectQuickAmount(cents: number) {
    setBusinessErrorMessage(null);
    setValue('amount', centsToFieldValue(cents), { shouldValidate: true });
  }

  function onFieldChange() {
    setBusinessErrorMessage(null);
  }

  function onSubmit(values: FormValues) {
    if (mutation.isPending) return;
    setBusinessErrorMessage(null);
    mutation.mutate(values);
  }

  if (mutation.isSuccess) {
    const statusLabel = mutation.data.status === 'CONFIRMED' ? 'confirmada' : 'aguardando pagamento';
    return (
      <p role="status" className={styles.confirmation}>
        Recarga confirmada. Status: {statusLabel}.
      </p>
    );
  }

  const { onChange: onAmountChange, ...amountField } = register('amount');

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate className={styles.form} aria-label="Formulário de recarga">
      <div className={styles.quickAmounts} role="group" aria-label="Valores rápidos">
        {QUICK_AMOUNTS_CENTS.map((cents) => (
          <Button
            key={cents}
            type="button"
            variant={currentAmountCents === cents ? 'primary' : 'secondary'}
            onClick={() => selectQuickAmount(cents)}
          >
            {formatCents(cents)}
          </Button>
        ))}
      </div>

      <div className={styles.field}>
        <label htmlFor="recharge-amount">Outro valor</label>
        <input
          id="recharge-amount"
          inputMode="decimal"
          placeholder="0,00"
          aria-describedby={errors.amount ? 'recharge-amount-error' : undefined}
          aria-invalid={Boolean(errors.amount)}
          {...amountField}
          onChange={(event) => {
            onFieldChange();
            void onAmountChange(event);
          }}
        />
        {errors.amount && (
          <span id="recharge-amount-error" role="alert" className={styles.error}>
            {errors.amount.message}
          </span>
        )}
      </div>

      {businessErrorMessage && (
        <p role="alert" className={styles.error}>
          {businessErrorMessage}
        </p>
      )}

      <Button type="submit" loading={mutation.isPending} disabled={mutation.isPending}>
        Recarregar
      </Button>
    </form>
  );
}
