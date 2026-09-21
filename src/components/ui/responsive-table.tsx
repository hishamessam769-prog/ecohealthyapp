import { EmptyState } from "@/components/ui/empty-state";

export type TableColumn<T> = {
  key: string;
  label: string;
  render: (row: T) => React.ReactNode;
  primary?: boolean;
};

export function ResponsiveTable<T>({
  rows,
  columns,
  getKey,
  emptyTitle,
  emptyDescription,
}: {
  rows: T[];
  columns: TableColumn<T>[];
  getKey: (row: T) => string;
  emptyTitle: string;
  emptyDescription: string;
}) {
  if (!rows.length) return <EmptyState title={emptyTitle} description={emptyDescription} />;
  return (
    <>
      <div className="hidden overflow-x-auto md:block">
        <table className="w-full border-collapse text-start text-sm">
          <thead><tr className="border-b border-[var(--border)] bg-[var(--surface-muted)]/55 text-[var(--text-muted)]">{columns.map((column) => <th key={column.key} className="px-5 py-3 text-start text-xs font-extrabold">{column.label}</th>)}</tr></thead>
          <tbody>{rows.map((row) => <tr key={getKey(row)} className="border-b border-[var(--border)] last:border-0 hover:bg-[var(--surface-muted)]/35">{columns.map((column) => <td key={column.key} className="px-5 py-4 align-middle">{column.render(row)}</td>)}</tr>)}</tbody>
        </table>
      </div>
      <div className="grid gap-3 p-3 md:hidden">
        {rows.map((row) => <article key={getKey(row)} className="rounded-xl border border-[var(--border)] bg-white p-4">{columns.map((column) => <div key={column.key} className={column.primary ? "mb-3 text-base font-extrabold" : "flex items-start justify-between gap-4 border-t border-[var(--border)] py-2 text-sm first:border-0"}>{column.primary ? column.render(row) : <><span className="text-[var(--text-muted)]">{column.label}</span><span className="text-end font-semibold">{column.render(row)}</span></>}</div>)}</article>)}
      </div>
    </>
  );
}
