import { validate } from "class-validator";
import { RegisterDto } from "./dto";

describe("RegisterDto", () => {
  it("accepts an alphanumeric NIM and the campus email domain", async () => {
    const dto = Object.assign(new RegisterDto(), {
      nim: "E32253079",
      name: "Mahasiswa SmartBIN",
      email: "mahasiswa@student.polije.ac.id",
      password: "smartbin123",
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it("rejects malformed NIMs and email addresses outside the campus domain", async () => {
    const dto = Object.assign(new RegisterDto(), {
      nim: "E322-53079",
      name: "Mahasiswa SmartBIN",
      email: "mahasiswa@kampus.ac.id",
      password: "smartbin123",
    });

    const errors = await validate(dto);

    expect(errors.map(({ property }) => property)).toEqual(
      expect.arrayContaining(["nim", "email"]),
    );
  });
});