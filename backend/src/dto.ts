import { Transform } from "class-transformer";
import {
  IsEmail,
  IsEnum,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";

export class RegisterDto {
  @IsString()
  @Matches(/^[A-Za-z0-9]{8,15}$/)
  nim!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @IsEmail()
  @MaxLength(254)
  @Matches(/^[^@\s]+@student\.polije\.ac\.id$/i)
  email!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;
}

export class LoginDto {
  @IsString()
  @MinLength(1)
  identifier!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(72)
  password!: string;
}

export class RefreshDto {
  @IsString()
  @MinLength(32)
  refreshToken!: string;
}

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  oldPassword?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword?: string;
}

export class CardLinkDto {
  @IsString()
  @MinLength(4)
  @MaxLength(64)
  uid!: string;
}

export class UnlinkCardDto {
  @IsString()
  @MinLength(1)
  password!: string;
}

export class DepositQueryDto {
  @IsOptional()
  @IsEnum(["ORGANIK", "ANORGANIK"])
  type?: "ORGANIK" | "ANORGANIK";

  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 20;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  cursor?: string;
}

export class IngestDepositDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  transactionId!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(64)
  uid!: string;

  @IsEnum(["ORGANIK", "ANORGANIK"])
  type!: "ORGANIK" | "ANORGANIK";

  @IsOptional()
  @IsString()
  @MaxLength(120)
  itemLabel = "";

  @IsInt()
  @Min(1)
  @Max(100_000)
  weightG!: number;

  @IsISO8601()
  deviceTime!: string;
}

export class UpdateRatesDto {
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  organikPerKg!: number;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  anorganikPerKg!: number;
}

export class MachineStatusDto {
  @IsEnum(["SIAP", "PENUH", "GANGGUAN", "OFFLINE"])
  status!: "SIAP" | "PENUH" | "GANGGUAN" | "OFFLINE";

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  organicFill?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  inorganicFill?: number;
}
