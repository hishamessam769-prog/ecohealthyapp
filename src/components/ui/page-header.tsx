export function PageHeader({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow?: string;
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        {eyebrow ? <p className="mb-2 text-xs font-extrabold uppercase tracking-[0.18em] text-[var(--primary)]">{eyebrow}</p> : null}
        <h1 className="text-2xl font-black tracking-tight sm:text-3xl">{title}</h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--text-muted)] sm:text-base">{description}</p>
      </div>
      {action}
    </header>
  );
}
