import type { ButtonHTMLAttributes } from "react";

type ButtonVariant = "primary" | "secondary" | "quiet" | "compact" | "destructive";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
};

export function Button({ className = "", variant = "primary", type = "button", ...props }: ButtonProps) {
  return (
    <button
      className={`button button--${variant} focus-ring ${className}`.trim()}
      type={type}
      {...props}
    />
  );
}
