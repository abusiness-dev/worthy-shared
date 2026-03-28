import { describe, it, expect } from "vitest";
import { isValidEAN13, isValidUPC, isValidBarcode } from "../barcodeValidation";

describe("isValidEAN13", () => {
  it("EAN-13 valido → true", () => {
    // 400638133393 → check digit: 1  →  4006381333931
    expect(isValidEAN13("4006381333931")).toBe(true);
  });

  it("EAN-13 con check digit sbagliato → false", () => {
    expect(isValidEAN13("4006381333932")).toBe(false);
  });

  it("stringa di 12 cifre → false per EAN-13", () => {
    expect(isValidEAN13("400638133393")).toBe(false);
  });

  it("stringa con lettere → false", () => {
    expect(isValidEAN13("400638133393A")).toBe(false);
  });

  it("stringa vuota → false", () => {
    expect(isValidEAN13("")).toBe(false);
  });
});

describe("isValidUPC", () => {
  it("UPC valido → true", () => {
    // 036000291452 è un UPC-A valido
    expect(isValidUPC("036000291452")).toBe(true);
  });

  it("UPC con check digit sbagliato → false", () => {
    expect(isValidUPC("036000291453")).toBe(false);
  });

  it("stringa di 13 cifre → false per UPC", () => {
    expect(isValidUPC("0360002914520")).toBe(false);
  });
});

describe("isValidBarcode", () => {
  it("EAN-13 valido → true", () => {
    expect(isValidBarcode("4006381333931")).toBe(true);
  });

  it("UPC valido → true", () => {
    expect(isValidBarcode("036000291452")).toBe(true);
  });

  it("codice invalido → false", () => {
    expect(isValidBarcode("123")).toBe(false);
  });
});
