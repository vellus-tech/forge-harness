import type { ReactNode } from "react";
import "./primitives.css";

export interface CardProps {
  eyebrow?: string;
  children: ReactNode;
}

export function Card({ eyebrow, children }: CardProps) {
  return (
    <div className="card">
      {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
      {children}
    </div>
  );
}
