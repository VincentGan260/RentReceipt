import { Bill } from '../model/Models';
export class ReceiptBatchResult { saved: number = 0; total: number = 0; cancelled: boolean = false; }
// Own only the paths returned by render; never clean up gallery/user-selected files.
export async function runReceiptBatch(bills: Bill[], render: (bill: Bill) => Promise<string>,
  save: (paths: string[]) => Promise<number>, cleanup: (path: string) => Promise<void>,
  cancelled: () => boolean, progress: (complete: number,total: number) => void): Promise<ReceiptBatchResult> {
  const paths: string[] = []; const result = new ReceiptBatchResult(); result.total = bills.length;
  try {
    for (const bill of bills) {
      if (cancelled()) { break; }
      paths.push(await render(bill)); progress(paths.length,bills.length);
    }
    if (cancelled()) { result.cancelled = true; return result; }
    if (paths.length) { result.saved = await save(paths); }
    return result;
  } finally {
    for (const path of paths) { try { await cleanup(path); } catch {} }
  }
}
