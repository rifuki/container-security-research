/**
 * Input Sanitization Utilities
 * Validate and sanitize user input
 */

/**
 * Sanitize numeric input with bounds
 */

export function sanitizeNumber(value, defaultValue, min, max) {
  const num = parseInt(value, 10);
  if (isNaN(num)) return defaultValue;
  if (min !== undefined && num < min) return min;
  if (max !== undefined && num > max) return max;
  return num;
}
