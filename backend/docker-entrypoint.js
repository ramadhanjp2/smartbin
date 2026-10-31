const { spawn } = require("node:child_process");
const { mkdirSync, createWriteStream } = require("node:fs");
const { join } = require("node:path");

const logDirectory = process.env.LOG_DIRECTORY || "/var/log/smartbin";
mkdirSync(logDirectory, { recursive: true });

const logFile = createWriteStream(join(logDirectory, "api.log"), {
  flags: "a",
});
let child;
let shuttingDown = false;
let childFailed = false;

function writeLog(stream, chunk) {
  stream.write(chunk);
  logFile.write(chunk);
}

try {
  child = spawn(process.execPath, ["dist/main"], {
    env: process.env,
    stdio: ["inherit", "pipe", "pipe"],
  });
} catch (error) {
  process.stderr.write(`Unable to start backend: ${error.message}\n`);
  logFile.end();
  process.exitCode = 1;
}

if (child) {
  child.stdout.on("data", (chunk) => writeLog(process.stdout, chunk));
  child.stderr.on("data", (chunk) => writeLog(process.stderr, chunk));

  child.on("error", (error) => {
    childFailed = true;
    process.stderr.write(`Backend process error: ${error.message}\n`);
    logFile.write(`Backend process error: ${error.stack || error.message}\n`);
    process.exitCode = 1;
  });

  child.on("close", (code, signal) => {
    logFile.end(() => {
      process.exitCode = childFailed ? 1 : (code ?? (signal ? 1 : 0));
    });
  });

  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => {
      if (shuttingDown) return;
      shuttingDown = true;
      child.kill(signal);
    });
  }
}
