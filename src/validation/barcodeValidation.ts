const DIGITS_RE = /^\d+$/;

function eanCheckDigit(digits: number[]): number {
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    sum += digits[i]! * (i % 2 === 0 ? 1 : 3);
  }
  return (10 - (sum % 10)) % 10;
}

export function isValidEAN13(code: string): boolean {
  if (code.length !== 13 || !DIGITS_RE.test(code)) return false;

  const digits = Array.from(code, Number);
  const check = digits.pop()!;
  return eanCheckDigit(digits) === check;
}

export function isValidUPC(code: string): boolean {
  if (code.length !== 12 || !DIGITS_RE.test(code)) return false;

  const digits = Array.from(code, Number);
  const check = digits.pop()!;

  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    sum += digits[i]! * (i % 2 === 0 ? 3 : 1);
  }
  const expected = (10 - (sum % 10)) % 10;
  return expected === check;
}

export function isValidBarcode(code: string): boolean {
  return isValidEAN13(code) || isValidUPC(code);
}
