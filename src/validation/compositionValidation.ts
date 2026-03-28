import type { Composition } from "../types";

export function validateComposition(fibers: Composition[]): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (fibers.length === 0) {
    errors.push("La composizione deve contenere almeno una fibra");
    return { valid: false, errors };
  }

  if (fibers.length > 8) {
    errors.push("La composizione può contenere al massimo 8 fibre");
  }

  for (const fiber of fibers) {
    if (!fiber.fiber || fiber.fiber.trim().length === 0) {
      errors.push("Ogni fibra deve avere un nome");
    }
    if (fiber.percentage <= 0) {
      errors.push(`La percentuale di "${fiber.fiber}" deve essere maggiore di 0`);
    }
    if (fiber.percentage > 100) {
      errors.push(`La percentuale di "${fiber.fiber}" non può superare 100%`);
    }
  }

  const names = fibers.map((f) => f.fiber.toLowerCase().trim());
  const uniqueNames = new Set(names);
  if (uniqueNames.size !== names.length) {
    errors.push("La composizione contiene fibre duplicate");
  }

  const sum = fibers.reduce((acc, f) => acc + f.percentage, 0);
  if (sum < 99 || sum > 101) {
    errors.push(`La somma delle percentuali deve essere 100% (attuale: ${sum}%)`);
  }

  return { valid: errors.length === 0, errors };
}
