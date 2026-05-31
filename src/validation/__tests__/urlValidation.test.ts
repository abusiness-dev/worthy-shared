import { describe, it, expect } from "vitest";
import {
  isSafeHttpsUrl,
  validateAffiliateUrl,
  validatePhotoUrls,
} from "../urlValidation";

describe("isSafeHttpsUrl", () => {
  it("accetta https://", () => {
    expect(isSafeHttpsUrl("https://example.com/path?q=1")).toBe(true);
  });

  it("rifiuta http://", () => {
    expect(isSafeHttpsUrl("http://example.com")).toBe(false);
  });

  it("rifiuta javascript:", () => {
    expect(isSafeHttpsUrl("javascript:alert(1)")).toBe(false);
  });

  it("rifiuta data:", () => {
    expect(isSafeHttpsUrl("data:text/html,<script>alert(1)</script>")).toBe(false);
  });

  it("rifiuta URL con spazi/control chars", () => {
    expect(isSafeHttpsUrl("https://example.com/ evil")).toBe(false);
    expect(isSafeHttpsUrl("https://example.com\njavascript:alert(1)")).toBe(false);
  });

  it("rifiuta non-stringhe e stringhe vuote", () => {
    expect(isSafeHttpsUrl(null)).toBe(false);
    expect(isSafeHttpsUrl(undefined)).toBe(false);
    expect(isSafeHttpsUrl(123 as unknown)).toBe(false);
    expect(isSafeHttpsUrl("")).toBe(false);
  });
});

describe("validateAffiliateUrl", () => {
  it("null/undefined/'' → valid (campo opzionale)", () => {
    expect(validateAffiliateUrl(null).valid).toBe(true);
    expect(validateAffiliateUrl(undefined).valid).toBe(true);
    expect(validateAffiliateUrl("").valid).toBe(true);
  });

  it("https valido → valid", () => {
    expect(validateAffiliateUrl("https://aff.example.com/p/123").valid).toBe(true);
  });

  it("javascript: → NOT valid con errore", () => {
    const r = validateAffiliateUrl("javascript:alert(document.cookie)");
    expect(r.valid).toBe(false);
    expect(r.error).toBeDefined();
  });
});

describe("validatePhotoUrls", () => {
  it("null/undefined → valid", () => {
    expect(validatePhotoUrls(null).valid).toBe(true);
    expect(validatePhotoUrls(undefined).valid).toBe(true);
  });

  it("tutti https → valid", () => {
    expect(
      validatePhotoUrls([
        "https://enophqzovmvhhwtfddnm.supabase.co/storage/v1/object/public/a.jpg",
        "https://cdn.example.com/b.png",
      ]).valid,
    ).toBe(true);
  });

  it("un elemento malevolo → NOT valid", () => {
    const r = validatePhotoUrls(["https://ok.com/a.jpg", "javascript:alert(1)"]);
    expect(r.valid).toBe(false);
    expect(r.error).toBeDefined();
  });

  it("ignora elementi vuoti/null", () => {
    expect(validatePhotoUrls(["", null]).valid).toBe(true);
  });
});
