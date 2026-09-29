import './Button.css';
export function Button({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button className="ds-button" {...props}>{children}</button>;
}
