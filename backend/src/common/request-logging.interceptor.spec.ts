import { CallHandler, ExecutionContext, Logger } from "@nestjs/common";
import { of } from "rxjs";
import {
  RequestLoggingInterceptor,
  TraceableRequest,
} from "./request-logging.interceptor";

describe("RequestLoggingInterceptor", () => {
  let interceptor: RequestLoggingInterceptor;
  let logSpy: jest.SpyInstance;

  beforeEach(() => {
    interceptor = new RequestLoggingInterceptor();
    logSpy = jest.spyOn(Logger.prototype, "log").mockImplementation();
    jest.spyOn(Logger.prototype, "warn").mockImplementation();
    jest.spyOn(Logger.prototype, "error").mockImplementation();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("logs the route feature, correlation ID, and response duration", () => {
    const request = {
      requestId: "trace-123",
      method: "GET",
      baseUrl: "",
      route: { path: "/deposits/:id" },
      user: { sub: "user-uuid", role: "user" },
    } as unknown as TraceableRequest;
    const response = { statusCode: 200 };
    const context = {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as unknown as ExecutionContext;
    const handler = { handle: () => of({ success: true }) } as CallHandler;

    interceptor.intercept(context, handler).subscribe();

    const messages = logSpy.mock.calls.map(([message]) => String(message));
    expect(
      messages.some((message) => message.includes('"phase":"start"')),
    ).toBe(true);
    expect(
      messages.some(
        (message) =>
          message.includes('"requestId":"trace-123"') &&
          message.includes('"feature":"deposits"') &&
          message.includes('"route":"/deposits/:id"'),
      ),
    ).toBe(true);
    expect(
      messages.some(
        (message) =>
          message.includes('"phase":"finish"') &&
          message.includes('"statusCode":200') &&
          message.includes('"durationMs":'),
      ),
    ).toBe(true);
  });
});
