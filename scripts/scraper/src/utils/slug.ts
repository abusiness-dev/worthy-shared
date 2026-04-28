/**
 * Generates a URL-safe slug from a product name + brand.
 * Example: "T-shirt regular fit in cotone", "zara" → "t-shirt-regular-fit-in-cotone-zara"
 *
 * Deterministic: nessun random suffix. L'unicità reale è garantita dal check
 * pre-insert su `affiliate_url` (vedi pipeline/inserter.ts). Così due insert
 * ripetuti dello stesso SKU vengono scartati invece di creare duplicati.
 */
export function generateSlug(name: string, brandSlug: string): string {
  return `${name}-${brandSlug}`
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // strip accents
    .replace(/[^a-z0-9\s-]/g, "") // remove non-alphanumeric
    .replace(/\s+/g, "-") // spaces to hyphens
    .replace(/-+/g, "-") // collapse multiple hyphens
    .replace(/^-|-$/g, ""); // trim leading/trailing hyphens
}
