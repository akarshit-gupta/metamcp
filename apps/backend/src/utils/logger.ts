import { format } from "util";
const { LOG_LEVEL } = process.env;

const validLogLevels = ["all", "info", "errors-only", "none"] as const;
type ValidLogLevel = (typeof validLogLevels)[number];

const getValidLogLevel = (
  level: string | undefined,
): LoggerOptions["shouldConsoleLog"] => {
  if (!level) return "errors-only";
  if (validLogLevels.includes(level as ValidLogLevel)) {
    return level as ValidLogLevel;
  }
  return "errors-only";
};

export interface LoggerOptions {
  shouldConsoleLog?: boolean | "all" | "info" | "errors-only" | "none";
}

export class Logger {
  private consoleMode: "all" | "info" | "errors-only" | "none";

  constructor(options: LoggerOptions = {}) {
    const { shouldConsoleLog = "all" } = options;

    this.consoleMode =
      typeof shouldConsoleLog === "boolean"
        ? shouldConsoleLog
          ? "all"
          : "none"
        : shouldConsoleLog;
  }

  private formatDate(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, "0");

    return (
      `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(date.getDate())} - ` +
      `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
    );
  }

  private customLog(
    level: "DEBUG" | "INFO" | "WARN" | "ERROR",
    ...args: unknown[]
  ) {
    if (this.consoleMode === "none") {
      return;
    }

    const shouldEmit =
      this.consoleMode === "all" ||
      (this.consoleMode === "info" && level === "INFO") ||
      (this.consoleMode === "errors-only" &&
        (level === "WARN" || level === "ERROR"));

    if (!shouldEmit) {
      return;
    }

    const logMessage = format(...(args as unknown[]));
    const formattedMessage = `[${level}] ${this.formatDate(new Date())} | ${logMessage}`;

    if (level === "INFO") {
      console.info(formattedMessage);
    } else if (level === "ERROR") {
      console.error(formattedMessage);
    } else if (level === "WARN") {
      console.warn(formattedMessage);
    } else {
      console.log(formattedMessage);
    }
  }

  public debug = (...args: unknown[]) => this.customLog("DEBUG", ...args);
  public info = (...args: unknown[]) => this.customLog("INFO", ...args);
  public warn = (...args: unknown[]) => this.customLog("WARN", ...args);
  public error = (...args: unknown[]) => this.customLog("ERROR", ...args);

  public close(): void {}
}

const logger = new Logger({
  shouldConsoleLog: getValidLogLevel(LOG_LEVEL),
});

export default logger;
