export function calculatePoints(weightG: number, ratePerKg: number): number {
  return Math.floor((weightG * ratePerKg) / 1000);
}
