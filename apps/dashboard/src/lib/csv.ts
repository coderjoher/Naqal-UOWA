export interface RosterRow {
  studentId: string;
  name: string;
  nameAr?: string;
  gender: 'male' | 'female';
}

const GENDER: Record<string, 'male' | 'female'> = { male: 'male', m: 'male', ذكر: 'male', female: 'female', f: 'female', أنثى: 'female', انثى: 'female' };

/** Minimal CSV line parser with quoted fields ("a, b"). */
function splitLine(line: string): string[] {
  const out: string[] = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      if (quoted && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else quoted = !quoted;
    } else if ((c === ',' || c === ';' || c === '\t') && !quoted) {
      out.push(cur.trim());
      cur = '';
    } else cur += c;
  }
  out.push(cur.trim());
  return out;
}

/**
 * Parses a registrar CSV: student number, name, Arabic name (optional), gender.
 * A header row is skipped when its first cell is not a student number. Returns the rows and
 * the 1-based line numbers that could not be read.
 */
export function parseRoster(text: string): { rows: RosterRow[]; badLines: number[] } {
  const rows: RosterRow[] = [];
  const badLines: number[] = [];
  const lines = text.replace(/^﻿/, '').split(/\r?\n/);
  lines.forEach((raw, i) => {
    if (!raw.trim()) return;
    const cells = splitLine(raw);
    const [id, name, third, fourth] = cells;
    const genderCell = (fourth ?? third ?? '').toLowerCase();
    const gender = GENDER[genderCell] ?? GENDER[genderCell.trim()];
    const nameAr = fourth !== undefined ? third : undefined;
    if (!id || !/^[A-Za-z0-9-]{1,40}$/.test(id) || !name || !gender) {
      if (i > 0 || /\d/.test(id ?? '')) badLines.push(i + 1);
      return;
    }
    rows.push({ studentId: id, name, nameAr: nameAr || undefined, gender });
  });
  return { rows, badLines };
}
