import { Inbox } from "lucide-react";

export function EmptyState({ title, description }: { title: string; description: string }) {
  return (
    <div className="flex min-h-56 flex-col items-center justify-center px-6 py-10 text-center">
      <span className="mb-4 grid size-14 place-items-center rounded-2xl bg-[var(--primary-soft)] text-[var(--primary)]">
        <Inbox size={25} aria-hidden />
      </span>
      <h3 className="font-extrabold">{title}</h3>
      <p className="mt-2 max-w-md text-sm leading-6 text-[var(--text-muted)]">{description}</p>
    </div>
  );
}
