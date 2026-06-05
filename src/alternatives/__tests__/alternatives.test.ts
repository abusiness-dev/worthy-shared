import { describe, it, expect } from "vitest";
import {
  isEligibleAlternative,
  pickBestAlternatives,
  bestAlternative,
  isAlreadyGood,
  meetsQualityFloor,
  segmentProximity,
  gendersCompatible,
  type AlternativeProduct,
  type AlternativeCandidate,
} from "../index";

const COTONE = [{ fiber: "cotone", percentage: 100 }];
const POLIESTERE = [{ fiber: "poliestere", percentage: 100 }];

function ref(over: Partial<AlternativeProduct> = {}): AlternativeProduct {
  return {
    id: "ref",
    worthy_score: 50,
    price: 50,
    gender: "uomo",
    composition: COTONE,
    market_segment: "fast_fashion",
    brand_id: "brandA",
    category_id: "tshirt",
    ...over,
  };
}

function cand(over: Partial<AlternativeCandidate> = {}): AlternativeCandidate {
  return {
    id: "cand",
    worthy_score: 70,
    price: 52,
    gender: "uomo",
    composition: COTONE,
    market_segment: "fast_fashion",
    brand_id: "brandB",
    category_id: "tshirt",
    ...over,
  };
}

describe("isEligibleAlternative — score gate (mai più basso del riferimento)", () => {
  it("RIFIUTA un'alternativa con score più basso del riferimento (regressione #1)", () => {
    const r = ref({ worthy_score: 90, composition: COTONE, price: 50 });
    const worse = cand({ id: "worse", worthy_score: 70, composition: COTONE, price: 52 });
    expect(isEligibleAlternative(r, worse)).toBe(false);
  });

  it("AMMETTE un'alternativa con score uguale al riferimento (da uguale in su)", () => {
    const r = ref({ worthy_score: 60 });
    const equal = cand({ worthy_score: 60 });
    expect(isEligibleAlternative(r, equal)).toBe(true);
  });

  it("AMMETTE un'alternativa con score più alto", () => {
    expect(isEligibleAlternative(ref({ worthy_score: 50 }), cand({ worthy_score: 70 }))).toBe(true);
  });
});

describe("isEligibleAlternative — floor di qualità (>= fair 51)", () => {
  it("RIFIUTA un candidato sotto 'fair' anche se >= riferimento bassissimo", () => {
    const r = ref({ worthy_score: 30 });
    const meh = cand({ worthy_score: 45 }); // verdict 'meh'
    expect(isEligibleAlternative(r, meh)).toBe(false);
  });

  it("AMMETTE un candidato 'fair' (51) sopra un riferimento pessimo", () => {
    const r = ref({ worthy_score: 30 });
    const fair = cand({ worthy_score: 51 });
    expect(isEligibleAlternative(r, fair)).toBe(true);
  });
});

describe("isEligibleAlternative — segmento (±1)", () => {
  it("RIFIUTA maison ↔ ultra_fast (distanza 3)", () => {
    const r = ref({ market_segment: "maison", worthy_score: 50 });
    const c = cand({ market_segment: "ultra_fast", worthy_score: 80 });
    expect(isEligibleAlternative(r, c)).toBe(false);
  });

  it("AMMETTE premium ↔ fast_fashion (distanza 1)", () => {
    const r = ref({ market_segment: "premium", worthy_score: 50, price: 100 });
    const c = cand({ market_segment: "fast_fashion", worthy_score: 80, price: 120 });
    expect(isEligibleAlternative(r, c)).toBe(true);
  });

  it("AMMETTE quando il segmento del candidato è ignoto (non blocca)", () => {
    const r = ref({ market_segment: "maison", worthy_score: 50, price: 100 });
    const c = cand({ market_segment: null, worthy_score: 80, price: 120 });
    expect(isEligibleAlternative(r, c)).toBe(true);
  });
});

describe("isEligibleAlternative — categoria e gender", () => {
  it("RIFIUTA categoria diversa", () => {
    expect(isEligibleAlternative(ref(), cand({ category_id: "felpe" }))).toBe(false);
  });

  it("matcha per famiglia quando presente, anche con category_id diverso", () => {
    const r = ref({ category_id: "t-shirt", category_family: "top" });
    const c = cand({ category_id: "t-shirt-basic", category_family: "top", worthy_score: 70 });
    expect(isEligibleAlternative(r, c)).toBe(true);
  });

  it("RIFIUTA gender incompatibile (uomo vs donna)", () => {
    expect(isEligibleAlternative(ref({ gender: "uomo" }), cand({ gender: "donna" }))).toBe(false);
  });

  it("AMMETTE unisex", () => {
    expect(isEligibleAlternative(ref({ gender: "uomo" }), cand({ gender: "unisex" }))).toBe(true);
  });
});

describe("isEligibleAlternative — cap prezzo superiore", () => {
  it("RIFIUTA un candidato oltre 2.5x il prezzo del riferimento", () => {
    const r = ref({ price: 20, worthy_score: 50 });
    const c = cand({ price: 60, worthy_score: 80 }); // 3x
    expect(isEligibleAlternative(r, c)).toBe(false);
  });

  it("AMMETTE un candidato molto più economico (nessun cap inferiore)", () => {
    const r = ref({ price: 100, worthy_score: 50 });
    const c = cand({ price: 30, worthy_score: 80 }); // 0.3x, più economico E migliore
    expect(isEligibleAlternative(r, c)).toBe(true);
  });
});

describe("pickBestAlternatives — ranking e scelta", () => {
  it("preferisce lo score più alto, non la fibra simile (regressione #1)", () => {
    // ref 90 cotone 50€. A: 70 cotone (peggiore → escluso). B: 92 poliestere (ammesso).
    const r = ref({ worthy_score: 90, composition: COTONE, price: 50 });
    const a = cand({ id: "A", worthy_score: 70, composition: COTONE, price: 52 });
    const b = cand({ id: "B", worthy_score: 92, composition: POLIESTERE, price: 95 });
    const best = bestAlternative(r, [a, b]);
    expect(best?.id).toBe("B");
  });

  it("non forza lo stesso brand quando esiste un'alternativa nettamente migliore (regressione ALT-2)", () => {
    // ref 50. same-brand 66 (+16) vs other-brand 92 (+42) → vince other-brand.
    const r = ref({ worthy_score: 50, brand_id: "brandA" });
    const sameBrand = cand({ id: "same", worthy_score: 66, brand_id: "brandA" });
    const otherBrand = cand({ id: "other", worthy_score: 92, brand_id: "brandZ" });
    const best = bestAlternative(r, [sameBrand, otherBrand]);
    expect(best?.id).toBe("other");
  });

  it("a parità sostanziale lo stesso brand riceve un bonus minimo", () => {
    const r = ref({ worthy_score: 50, brand_id: "brandA" });
    const same = cand({ id: "same", worthy_score: 70, brand_id: "brandA" });
    const other = cand({ id: "other", worthy_score: 70, brand_id: "brandZ" });
    const best = bestAlternative(r, [other, same]);
    expect(best?.id).toBe("same");
  });

  it("rispetta il limit e ordina per score desc", () => {
    const r = ref({ worthy_score: 50 });
    const cands = [
      cand({ id: "c70", worthy_score: 70 }),
      cand({ id: "c90", worthy_score: 90 }),
      cand({ id: "c80", worthy_score: 80 }),
    ];
    const ranked = pickBestAlternatives(r, cands, { limit: 2 });
    expect(ranked.map((c) => c.id)).toEqual(["c90", "c80"]);
    expect(ranked[0].scoreDelta).toBe(40);
  });

  it("ritorna lista vuota quando non esistono candidati migliori", () => {
    const r = ref({ worthy_score: 95 });
    const cands = [cand({ worthy_score: 70 }), cand({ worthy_score: 80 })];
    expect(pickBestAlternatives(r, cands)).toEqual([]);
  });

  it("è deterministico a parità di candidati", () => {
    const r = ref({ worthy_score: 50 });
    const cands = [
      cand({ id: "z", worthy_score: 70 }),
      cand({ id: "a", worthy_score: 70 }),
    ];
    const run1 = pickBestAlternatives(r, cands).map((c) => c.id);
    const run2 = pickBestAlternatives(r, [...cands].reverse()).map((c) => c.id);
    expect(run1).toEqual(run2);
  });
});

describe("helper soglie", () => {
  it("isAlreadyGood: 71 (worthy) sì, 70 no", () => {
    expect(isAlreadyGood(71)).toBe(true);
    expect(isAlreadyGood(70)).toBe(false);
    expect(isAlreadyGood(90)).toBe(true);
  });

  it("meetsQualityFloor: 51 sì, 50 no", () => {
    expect(meetsQualityFloor(51)).toBe(true);
    expect(meetsQualityFloor(50)).toBe(false);
  });

  it("segmentProximity: stesso = 1, distanza 1 ≈ 0.67, ignoto = 0.5", () => {
    expect(segmentProximity("premium", "premium")).toBe(1);
    expect(segmentProximity("premium", "fast_fashion")).toBeCloseTo(0.6667, 3);
    expect(segmentProximity("premium", null)).toBe(0.5);
  });

  it("gendersCompatible", () => {
    expect(gendersCompatible("uomo", "uomo")).toBe(true);
    expect(gendersCompatible("uomo", "donna")).toBe(false);
    expect(gendersCompatible("uomo", "unisex")).toBe(true);
    expect(gendersCompatible(null, "donna")).toBe(true);
  });
});
