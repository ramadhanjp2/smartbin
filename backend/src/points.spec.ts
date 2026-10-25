import { calculatePoints } from "./points";

describe("calculatePoints", () => {
  it("uses whole points and rounds down fractional results", () => {
    expect(calculatePoints(950, 40)).toBe(38);
    expect(calculatePoints(1200, 100)).toBe(120);
    expect(calculatePoints(9, 40)).toBe(0);
  });
});
