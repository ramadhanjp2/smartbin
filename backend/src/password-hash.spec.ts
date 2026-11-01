import * as bcrypt from "bcrypt";

describe("password hashing", () => {
  // Hash ini dibuat oleh bcryptjs sebelum migrasi ke bcrypt native; akun yang sudah ada harus tetap bisa login.
  const legacyBcryptjsHash =
    "$2b$10$HIXSLJyxg9Qcm975c73CJ.9iaDzCvcEX1yCwmM7GEch5hbKqphDku";

  it("memverifikasi hash lama buatan bcryptjs", async () => {
    await expect(
      bcrypt.compare("kata-sandi-lama", legacyBcryptjsHash),
    ).resolves.toBe(true);
    await expect(bcrypt.compare("salah", legacyBcryptjsHash)).resolves.toBe(
      false,
    );
  });

  it("menghasilkan hash $2b$ dengan cost 12 yang bisa diverifikasi", async () => {
    const hash = await bcrypt.hash("sandi-baru-123", 12);

    expect(hash).toMatch(/^\$2b\$12\$/);
    await expect(bcrypt.compare("sandi-baru-123", hash)).resolves.toBe(true);
  });
});
