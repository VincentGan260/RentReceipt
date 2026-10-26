// Exact base-10 arithmetic. Only single digit arithmetic uses JS numbers.
// Money, rates and readings never pass through Number/parseFloat.
export class Decimal {
  private digits: string;
  private scale: number;
  private negative: boolean;

  private constructor(digits: string, scale: number, negative: boolean) {
    this.digits = digits.replace(/^0+/, '') || '0';
    this.scale = scale;
    this.negative = negative && this.digits !== '0';
    while (this.scale > 0 && this.digits.endsWith('0')) {
      this.digits = this.digits.slice(0, -1);
      this.scale--;
    }
    if (this.digits === '' || this.digits === '0') { this.digits = '0'; this.scale = 0; }
  }

  static parse(text: string): Decimal {
    const value = text.trim();
    const match = /^([+-]?)(\d+(?:\.\d*)?|\.\d+)(?:[eE]([+-]?\d+))?$/.exec(value);
    if (!match) { throw new Error('数字格式错误'); }
    const exponent = match[3] ? Number(match[3]) : 0;
    if (!Number.isInteger(exponent) || Math.abs(exponent) > 1000 || value.length > 1000) {
      throw new Error('数字过长');
    }
    const parts = match[2].split('.');
    let digits = (parts[0] || '0') + (parts[1] || '');
    let scale = (parts[1] || '').length - exponent;
    if (scale < 0) { digits += '0'.repeat(-scale); scale = 0; }
    return new Decimal(digits, scale, match[1] === '-');
  }

  static zero(): Decimal { return Decimal.parse('0'); }

  private static compareDigits(left: string, right: string): number {
    const a = left.replace(/^0+/, '') || '0';
    const b = right.replace(/^0+/, '') || '0';
    if (a.length !== b.length) { return a.length > b.length ? 1 : -1; }
    return a === b ? 0 : (a > b ? 1 : -1);
  }

  private static addDigits(a: string, b: string): string {
    let carry = 0;
    let output = '';
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      const left = i < a.length ? Number(a[a.length - 1 - i]) : 0;
      const right = i < b.length ? Number(b[b.length - 1 - i]) : 0;
      const sum = left + right + carry;
      output = String(sum % 10) + output;
      carry = Math.floor(sum / 10);
    }
    return carry ? String(carry) + output : output;
  }

  // Caller guarantees a >= b.
  private static subtractDigits(a: string, b: string): string {
    let borrow = 0;
    let output = '';
    for (let i = 0; i < a.length; i++) {
      let digit = Number(a[a.length - 1 - i]) - borrow;
      digit -= i < b.length ? Number(b[b.length - 1 - i]) : 0;
      borrow = digit < 0 ? 1 : 0;
      output = String(digit < 0 ? digit + 10 : digit) + output;
    }
    return output.replace(/^0+/, '') || '0';
  }

  compare(other: Decimal): number {
    if (this.negative !== other.negative) { return this.negative ? -1 : 1; }
    const scale = Math.max(this.scale, other.scale);
    const comparison = Decimal.compareDigits(this.digits + '0'.repeat(scale - this.scale),
      other.digits + '0'.repeat(scale - other.scale));
    return this.negative ? -comparison : comparison;
  }

  add(other: Decimal): Decimal {
    const scale = Math.max(this.scale, other.scale);
    const a = this.digits + '0'.repeat(scale - this.scale);
    const b = other.digits + '0'.repeat(scale - other.scale);
    if (this.negative === other.negative) {
      return new Decimal(Decimal.addDigits(a, b), scale, this.negative);
    }
    const comparison = Decimal.compareDigits(a, b);
    return comparison >= 0 ? new Decimal(Decimal.subtractDigits(a, b), scale, this.negative) :
      new Decimal(Decimal.subtractDigits(b, a), scale, other.negative);
  }

  subtract(other: Decimal): Decimal {
    return this.add(new Decimal(other.digits, other.scale, !other.negative));
  }

  multiply(other: Decimal): Decimal {
    const result: number[] = new Array<number>(this.digits.length + other.digits.length).fill(0);
    for (let i = this.digits.length - 1; i >= 0; i--) {
      for (let j = other.digits.length - 1; j >= 0; j--) {
        const position = i + j + 1;
        const sum = result[position] + Number(this.digits[i]) * Number(other.digits[j]);
        result[position] = sum % 10;
        result[position - 1] += Math.floor(sum / 10);
      }
    }
    return new Decimal(result.join(''), this.scale + other.scale, this.negative !== other.negative);
  }

  // BigDecimal HALF_UP / Swift Decimal .plain: ties round away from zero.
  whole(): Decimal {
    if (this.scale === 0) { return new Decimal(this.digits, 0, this.negative); }
    const padded = this.digits.padStart(this.scale + 1, '0');
    let integer = padded.slice(0, -this.scale);
    if (Number(padded[padded.length - this.scale]) >= 5) {
      integer = Decimal.addDigits(integer, '1');
    }
    return new Decimal(integer, 0, this.negative);
  }

  toString(): string {
    const padded = this.digits.padStart(this.scale + 1, '0');
    const value = this.scale === 0 ? padded :
      padded.slice(0, -this.scale) + '.' + padded.slice(-this.scale);
    return (this.negative ? '-' : '') + value;
  }
}
