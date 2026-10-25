import "reflect-metadata";
import { BadRequestException, ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import helmet from "helmet";
import { AppModule } from "./app.module";
import { ApiExceptionFilter } from "./common/api-exception.filter";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix(process.env.API_PREFIX ?? "api/v1");
  app.use(helmet());
  app.enableCors({
    origin:
      process.env.WEB_ORIGIN === "*"
        ? true
        : process.env.WEB_ORIGIN?.split(","),
  });
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      exceptionFactory: (errors) =>
        new BadRequestException({
          code: "VALIDATION_ERROR",
          message: "Data yang dikirim tidak valid.",
          details: errors.map(({ property, constraints }) => ({
            field: property,
            rules: Object.values(constraints ?? {}),
          })),
        }),
    }),
  );
  await app.listen(Number(process.env.PORT ?? 3000), "0.0.0.0");
}

void bootstrap();
