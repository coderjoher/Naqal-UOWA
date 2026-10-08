import { clsx } from 'clsx';
import { motion } from 'motion/react';
import type { ReactNode } from 'react';
import { itemVariants, listVariants } from './motion';

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
      <table className="w-full border-separate border-spacing-0 text-start">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} scope="col" className="whitespace-nowrap bg-surface-muted px-4 py-3 text-start text-caption font-semibold text-text-muted first:rounded-s-pill last:rounded-e-pill">
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <motion.tbody variants={listVariants} initial="hidden" animate="show">
          {rows.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-12 text-center text-text-muted">
                {empty ?? '—'}
              </td>
            </tr>
          ) : (
            rows.map((r) => (
              <motion.tr variants={itemVariants} key={rowKey(r)} className="group transition-colors duration-200 hover:bg-surface-muted/60">
                {columns.map((c) => (
                  <td key={c.key} className={clsx('border-b border-border group-last:border-0', c.className ?? 'px-4 py-4 align-middle')}>
                    {c.cell(r)}
                  </td>
                ))}
              </motion.tr>
            ))
          )}
        </motion.tbody>
      </table>
    </div>
  );
}
