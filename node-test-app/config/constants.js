import "dotenv/config";

export const APP_PORT = process.env.PORT || 3000;
export const MAX_MEMORY_MB = process.env.MAX_MEMORY_MB || 512;
export const MAX_ITERATIONS = process.env.MAX_ITERATIONS || 100000000; // 100M iterations max
