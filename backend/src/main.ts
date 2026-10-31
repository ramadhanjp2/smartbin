import "reflect-metadata";
import { BadRequestException, ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { randomUUID } from "node:crypto";
import { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { AppModule } from "./app.module";
import { ApiExceptionFilter } from "./common/api-exception.filter";
import {
  RequestLoggingInterceptor,
  TraceableRequest,
} from "./common/request-logging.interceptor";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix(process.env.API_PREFIX ?? "api/v1");
  app.use((request: Request, response: Response, next: NextFunction) => {
    const traceableRequest = request as TraceableRequest;
    const header = request.header("x-request-id");
    const requestId =
      header && /^[a-zA-Z0-9._-]{1,80}$/.test(header) ? header : randomUUID();
    traceableRequest.requestId = requestId;
    response.setHeader("X-Request-Id", requestId);
    next();
  });
  app.use(helmet());
  app.enableCors({
    origin:
      process.env.WEB_ORIGIN === "*"
        ? true
        : process.env.WEB_ORIGIN?.split(","),
    exposedHeaders: ["X-Request-Id"],
  });
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalInterceptors(new RequestLoggingInterceptor());
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
