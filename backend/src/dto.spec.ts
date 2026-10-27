import { validate } from "class-validator";
import { RegisterDto } from "./dto";

describe("RegisterDto", () => {
  it("accepts a 16-digit NIK and a public email address", async () => {
    const dto = Object.assign(new RegisterDto(), {
      nik: "1234567890123456",
      name: "Pengguna SmartBIN",
      email: "pengguna@example.com",
      password: "smartbin123",
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it("rejects malformed NIKs and invalid email addresses", async () => {
    const dto = Object.assign(new RegisterDto(), {
      nik: "12345-789",
      name: "Pengguna SmartBIN",
      email: "bukan-email",
      password: "smartbin123",
    });

    const errors = await validate(dto);

    expect(errors.map(({ property }) => property)).toEqual(
      expect.arrayContaining(["nik", "email"]),
    );
  });
});