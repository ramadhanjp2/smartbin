import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { Response } from "express";

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const payload = exception.getResponse();
      const body =
        typeof payload === "object" && payload !== null
          ? (payload as Record<string, unknown>)
          : {};
      const code =
        typeof body.code === "string"
          ? body.code
          : status === HttpStatus.TOO_MANY_REQUESTS
            ? "RATE_LIMITED"
            : `HTTP_${status}`;
      const message =
        typeof body.message === "string"
          ? body.message
          : status === HttpStatus.TOO_MANY_REQUESTS
            ? "Terlalu banyak permintaan. Coba lagi sebentar."
            : "Permintaan tidak dapat diproses.";

      response.status(status).json({
        code,
        message,
        ...(body.details !== undefined ? { details: body.details } : {}),
      });
      return;
    }

    this.logger.error(
      "Unhandled API exception",
      exception instanceof Error ? exception.stack : String(exception),
    );
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: "INTERNAL_ERROR",
      message: "Terjadi kesalahan internal.",
    });
  }
}
