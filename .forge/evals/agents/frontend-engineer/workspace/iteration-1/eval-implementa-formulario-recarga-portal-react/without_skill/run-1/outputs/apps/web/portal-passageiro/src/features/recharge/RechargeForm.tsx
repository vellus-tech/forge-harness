import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { z } from 'zod';
import { Button } from '@bilhetagem/ui';
import { HttpError } from '../../services/httpClient';
import { postRecharge, type RechargeResponse } from '../../services/rechargeService';
import { generateId } from '../../lib/uuid';
import styles from './RechargeForm.module.css';

const QUICK_AMOUNTS_REAIS = [10, 20, 50] as const;

const formSchema = z
  .object({
    quickAmount: z.number().nullable(),
    customAmount: z.string(),
  })
  .superRefine((data, ctx) => {
    const raw = data.customAmount.trim();
    if (raw === '' && data.quickAmount === null) {
      ctx.addIssue({
        path: ['customAmount'],
        code: z.ZodIssueCode.custom,
        message: 'Escolha um valor rápido ou digite outro valor.',
      });
      return;
    }
    if (raw !== '') {
      const value = Number(raw.replace(',', '.'));
      if (Number.isNaN(value)) {
        ctx.addIssue({
          path: ['customAmount'],
          code: z.ZodIssueCode.custom,
          message: 'Digite um valor numérico válido.',
        });
        return;
      }
      if (value < 5 || value > 500) {
        ctx.addIssue({
          path: ['customAmount'],
          code: z.ZodIssueCode.custom,
          message: 'Digite um valor entre R$ 5,00 e R$ 500,00.',
        });
      }
    }
  });

type FormValues = z.infer<typeof formSchema>;

const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

function amountToCents(values: FormValues): number {
  const raw = values.customAmount.trim();
  if (raw !== '') {
    return Math.round(Number(raw.replace(',', '.')) * 100);
  }
  return Math.round((values.quickAmount ?? 0) * 100);
}

export function RechargeForm({ cardId }: { cardId: string }) {
  const [idempotencyKey, setIdempotencyKey] = useState(() => generateId());
  const [businessErrorMessage, setBusinessErrorMessage] = useState<string | null>(null);
  const [confirmed, setConfirmed] = useState<RechargeResponse | null>(null);

  const { register, handleSubmit, watch, setValue, reset, formState } = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: { quickAmount: null, customAmount: '' },
  });

  const quickAmount = watch('quickAmount');

  const mutation = useMutation({
    mutationFn: (amountCents: number) => postRecharge(cardId, amountCents, idempotencyKey),
    onSuccess: (data) => {
      setConfirmed(data);
      setBusinessErrorMessage(null);
      setIdempotencyKey(generateId());
    },
    onError: (error: unknown) => {
      if (error instanceof HttpError && error.status === 422 && isBusinessErrorBody(error.body)) {
        setBusinessErrorMessage(error.body.message);
        return;
      }
      setBusinessErrorMessage('Não foi possível concluir a recarga. Tente novamente.');
    },
  });

  const onSubmit = handleSubmit((values) => {
    setBusinessErrorMessage(null);
    mutation.mutate(amountToCents(values));
  });

  if (confirmed) {
    return (
      <div className={styles.confirmation} role="status">
        <p>Recarga confirmada.</p>
        <p>Status: {confirmed.status === 'CONFIRMED' ? 'Confirmada' : 'Pagamento pendente'}</p>
        <Button
          type="button"
          variant="secondary"
          onClick={() => {
            setConfirmed(null);
            reset({ quickAmount: null, customAmount: '' });
          }}
        >
          Fazer nova recarga
        </Button>
      </div>
    );
  }

  return (
    <form className={styles.form} onSubmit={onSubmit} noValidate>
      <fieldset className={styles.quickAmounts}>
        <legend>Valor rápido</legend>
        {QUICK_AMOUNTS_REAIS.map((value) => (
          <Button
            key={value}
            type="button"
            variant={quickAmount === value ? 'primary' : 'secondary'}
            aria-pressed={quickAmount === value}
            onClick={() => {
              setValue('quickAmount', value, { shouldValidate: true });
              setValue('customAmount', '', { shouldValidate: true });
            }}
          >
            {currency.format(value)}
          </Button>
        ))}
      </fieldset>

      <label className={styles.field} htmlFor="recharge-custom-amount">
        Outro valor
        <input
          id="recharge-custom-amount"
          inputMode="decimal"
          placeholder="0,00"
          {...register('customAmount', {
            onChange: () => setValue('quickAmount', null, { shouldValidate: true }),
          })}
        />
      </label>
      {formState.errors.customAmount && (
        <p role="alert" className={styles.error}>
          {formState.errors.customAmount.message}
        </p>
      )}

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

function isBusinessErrorBody(body: unknown): body is { code: string; message: string } {
  return typeof body === 'object' && body !== null && 'message' in body;
}
