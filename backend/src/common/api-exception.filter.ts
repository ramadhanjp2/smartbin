import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { Response } from "express";
import { TraceableRequest } from "./request-logging.interceptor";

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<TraceableRequest>();
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

      this.logger.warn(
        JSON.stringify({
          event: "http.exception",
          requestId: request.requestId ?? "missing",
          method: request.method,
          route:
            typeof request.route?.path === "string"
              ? `${request.baseUrl}${request.route.path}`
              : "unmatched",
          statusCode: status,
          code,
        }),
        "ApiExceptionFilter",
      );
      response.status(status).json({
        code,
        message,
        ...(body.details !== undefined ? { details: body.details } : {}),
      });
      return;
    }

    this.logger.error(
      JSON.stringify({
        event: "http.exception",
        requestId: request.requestId ?? "missing",
        method: request.method,
        route:
          typeof request.route?.path === "string"
            ? `${request.baseUrl}${request.route.path}`
            : "unmatched",
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        code: "INTERNAL_ERROR",
      }),
      exception instanceof Error ? exception.stack : String(exception),
    );
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: "INTERNAL_ERROR",
      message: "Terjadi kesalahan internal.",
    });
  }
}
