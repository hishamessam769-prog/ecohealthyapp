import * as React from "react";
import { cn } from "@/lib/utils";

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost" | "danger";
  size?: "sm" | "md" | "icon";
};

export function Button({
  className,
  variant = "primary",
  size = "md",
  type = "button",
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition disabled:cursor-not-allowed disabled:opacity-50",
        variant === "primary" && "bg-[var(--primary)] text-white hover:bg-[var(--primary-strong)]",
        variant === "secondary" && "border border-[var(--border)] bg-white text-[var(--text)] hover:bg-[var(--surface-muted)]",
        variant === "ghost" && "text-[var(--text-muted)] hover:bg-[var(--surface-muted)] hover:text-[var(--text)]",
        variant === "danger" && "bg-red-50 text-[var(--danger)] hover:bg-red-100",
        size === "sm" && "h-9 px-3 text-sm",
        size === "md" && "h-11 px-4 text-sm",
        size === "icon" && "size-11",
        className,
      )}
      {...props}
    />
  );
}
