import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from "@nestjs/common";
import { Request, Response } from "express";
import { defer, finalize, Observable } from "rxjs";

export interface TraceableRequest extends Request {
  requestId?: string;
  user?: { sub: string; role: string };
}

const FEATURE_NAMES: Record<string, string> = {
  admin: "admin",
  auth: "auth",
  captures: "captures",
  cards: "cards",
  deposits: "deposits",
  health: "health",
  machines: "machines",
  me: "profile",
  notifications: "notifications",
  points: "points",
  rates: "rates",
};

function routeTemplate(request: TraceableRequest): string {
  const route = request.route?.path;
  if (typeof route !== "string") return "unmatched";
  return `${request.baseUrl}${route}` || "/";
}

function featureName(route: string): string {
  const firstSegment = route.split("/").filter(Boolean)[0];
  return firstSegment ? (FEATURE_NAMES[firstSegment] ?? "other") : "other";
}

@Injectable()
export class RequestLoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(RequestLoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<TraceableRequest>();
    const response = http.getResponse<Response>();
    const route = routeTemplate(request);
    const feature = featureName(route);
    const requestId = request.requestId ?? "missing";
    const startedAt = Date.now();
    const baseLog = {
      event: "http.request",
      requestId,
      method: request.method,
      route,
      feature,
      ...(request.user
        ? { userId: request.user.sub, role: request.user.role }
        : {}),
    };

    return defer(() => {
      this.logger.log(JSON.stringify({ ...baseLog, phase: "start" }), feature);
      return next.handle().pipe(
        finalize(() => {
          const statusCode = response.statusCode;
          const entry = {
            ...baseLog,
            phase: "finish",
            statusCode,
            durationMs: Date.now() - startedAt,
          };
          const message = JSON.stringify(entry);
          if (statusCode >= 500) {
            this.logger.error(message, feature);
          } else if (statusCode >= 400) {
            this.logger.warn(message, feature);
          } else {
            this.logger.log(message, feature);
          }
        }),
      );
    });
  }
}
