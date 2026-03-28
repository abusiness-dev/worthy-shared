import type { ProductInsert } from "../types";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HTML_TAG_RE = /<[^>]+>/;
const URL_RE = /https?:\/\/\S+/i;

export function validateProduct(data: Partial<ProductInsert>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data.name || data.name.trim().length === 0) {
    errors.push("Il nome del prodotto è obbligatorio");
  } else {
    const name = data.name.trim();
    if (name.length < 3) errors.push("Il nome del prodotto deve avere almeno 3 caratteri");
    if (name.length > 200) errors.push("Il nome del prodotto non può superare 200 caratteri");
    if (HTML_TAG_RE.test(name)) errors.push("Il nome del prodotto non può contenere tag HTML");
    if (URL_RE.test(name)) errors.push("Il nome del prodotto non può contenere URL");
  }

  if (!data.brand_id) {
    errors.push("Il brand è obbligatorio");
  } else if (!UUID_RE.test(data.brand_id)) {
    errors.push("Il brand_id non è un UUID valido");
  }

  if (!data.category_id) {
    errors.push("La categoria è obbligatoria");
  } else if (!UUID_RE.test(data.category_id)) {
    errors.push("Il category_id non è un UUID valido");
  }

  if (data.price == null) {
    errors.push("Il prezzo è obbligatorio");
  } else {
    if (data.price <= 0) errors.push("Il prezzo deve essere maggiore di zero");
    if (data.price >= 500) errors.push("Il prezzo non può superare €500");
  }

  if (!data.composition || !Array.isArray(data.composition) || data.composition.length === 0) {
    errors.push("La composizione è obbligatoria e deve contenere almeno una fibra");
  }

  return { valid: errors.length === 0, errors };
}
