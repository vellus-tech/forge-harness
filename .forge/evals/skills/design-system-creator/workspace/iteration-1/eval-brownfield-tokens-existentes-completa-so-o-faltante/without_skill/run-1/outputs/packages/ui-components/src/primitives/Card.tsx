import type { HTMLAttributes, ReactNode } from 'react';

export type CardProps = HTMLAttributes<HTMLDivElement> & {
  eyebrow?: ReactNode;
};

/** Contêiner de superfície com raio grande e sombra suave. */
export function Card({ eyebrow, children, className, ...rest }: CardProps) {
  return (
    <div className={['card', className].filter(Boolean).join(' ')} {...rest}>
      {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
      {children}
    </div>
  );
}
