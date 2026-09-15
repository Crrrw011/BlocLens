"use client";

import {
  flexRender,
  tableFeatures,
  useTable,
  type ColumnDef,
  type RowData,
} from "@tanstack/react-table";

import { en } from "@/lib/messages/en";

const dataTableFeatures = tableFeatures({});

export type DataTableColumn<TData extends RowData> = ColumnDef<
  typeof dataTableFeatures,
  TData,
  unknown
>;

type DataTableProps<TData extends RowData> = Readonly<{
  columns: DataTableColumn<TData>[];
  data: TData[];
  getRowId?: (row: TData, index: number) => string;
  onRowActivate?: (row: TData) => void;
  selectedRowId?: string;
  caption?: string;
}>;

export function DataTable<TData extends RowData>({
  columns,
  data,
  getRowId,
  onRowActivate,
  selectedRowId,
  caption,
}: DataTableProps<TData>) {
  const table = useTable({ features: dataTableFeatures, data, columns, getRowId });

  return (
    <div className="data-table" data-narrow-mode="single-item">
      <p className="data-table__narrow-note">{en.shell.narrowMode}</p>
      <div className="data-table__viewport">
        <table>
          {caption ? <caption className="sr-only">{caption}</caption> : null}
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <th key={header.id} scope="col">
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => {
              const interactive = Boolean(onRowActivate);
              return (
                <tr
                  key={row.id}
                  data-row-id={row.id}
                  className={row.id === selectedRowId ? "data-table__row--selected" : undefined}
                  tabIndex={interactive ? 0 : undefined}
                  onClick={interactive ? () => onRowActivate?.(row.original) : undefined}
                  onKeyDown={
                    interactive
                      ? (event) => {
                          if (event.key === "Enter" || event.key === " ") {
                            event.preventDefault();
                            onRowActivate?.(row.original);
                          }
                        }
                      : undefined
                  }
                >
                  {row.getAllCells().map((cell) => (
                    <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
                  ))}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
