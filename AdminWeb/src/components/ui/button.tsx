import type { ComponentPropsWithRef } from "react";

type ButtonVariant = "primary" | "secondary" | "quiet" | "compact" | "destructive";

type ButtonProps = ComponentPropsWithRef<"button"> & {
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
