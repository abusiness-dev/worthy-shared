/**
 * Generates a URL-safe slug from a product name + brand.
 * Example: "T-shirt regular fit in cotone", "zara" → "t-shirt-regular-fit-in-cotone-zara"
 */
export function generateSlug(name: string, brandSlug: string): string {
  const base = `${name}-${brandSlug}`
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // strip accents
    .replace(/[^a-z0-9\s-]/g, "") // remove non-alphanumeric
    .replace(/\s+/g, "-") // spaces to hyphens
    .replace(/-+/g, "-") // collapse multiple hyphens
    .replace(/^-|-$/g, ""); // trim leading/trailing hyphens

  // Add short random suffix to ensure uniqueness
  const suffix = Math.random().toString(36).substring(2, 6);
  return `${base}-${suffix}`;
}
