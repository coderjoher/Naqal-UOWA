import type { ReactNode } from 'react';

export interface Column<T> {
  key: string;
  header: string;
  cell: (row: T) => ReactNode;
  className?: string;
}

export interface TableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  caption: string;
  empty?: ReactNode;
}

export function Table<T>({ columns, rows, rowKey, caption, empty }: TableProps<T>) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-start">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr className="border-b border-border">
            {columns.map((c) => (
              <th key={c.key} scope="col" className="px-4 py-3 text-start text-label text-text-muted">
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-10 text-center text-text-muted">
                {empty ?? '—'}
              </td>
            </tr>
          ) : (
            rows.map((r) => (
              <tr key={rowKey(r)} className="border-b border-border last:border-0 hover:bg-surface-muted">
                {columns.map((c) => (
                  <td key={c.key} className={c.className ?? 'px-4 py-3'}>
                    {c.cell(r)}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
