import type { ReactNode } from "react";
import "./primitives.css";

export type BadgeStatus = "success" | "warning" | "neutral";

export interface BadgeProps {
  status: BadgeStatus;
  children: ReactNode;
}

export function Badge({ status, children }: BadgeProps) {
  return <span className={`badge ${status}`}>{children}</span>;
}
