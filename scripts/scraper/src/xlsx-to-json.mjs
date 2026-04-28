// Utility one-shot: converte un file XLSX in JSON array of objects, con
// header dalla prima riga. Riusabile per tutti gli import statici di brand.
//
// Usage:
//   node src/xlsx-to-json.mjs <input.xlsx> <output.json> [--sheet <name>]

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import xlsx from "xlsx";

const args = process.argv.slice(2);
let input = null;
let output = null;
let sheet = null;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--sheet") sheet = args[++i];
  else if (!input) input = a;
  else if (!output) output = a;
}

if (!input || !output) {
  console.error("Usage: node xlsx-to-json.mjs <input.xlsx> <output.json> [--sheet <name>]");
  process.exit(1);
}

const wb = xlsx.read(readFileSync(resolve(input)), { type: "buffer" });
const sheetName = sheet ?? wb.SheetNames[0];
const ws = wb.Sheets[sheetName];
if (!ws) {
  console.error(`Sheet "${sheetName}" not found. Available:`, wb.SheetNames);
  process.exit(1);
}

// raw:true → preserva tipi nativi (numeri restano numeri); defval:"" → celle
// vuote diventano stringa vuota (compat con il formato SUITSUPPLY già usato).
const rows = xlsx.utils.sheet_to_json(ws, { raw: true, defval: "" });
writeFileSync(resolve(output), JSON.stringify(rows, null, 2));

console.log(`Sheets: ${wb.SheetNames.join(", ")}`);
console.log(`Used sheet: ${sheetName}`);
console.log(`Rows: ${rows.length}`);
console.log(`Headers: ${rows.length ? Object.keys(rows[0]).join(", ") : "(empty)"}`);
console.log(`Wrote: ${output}`);
