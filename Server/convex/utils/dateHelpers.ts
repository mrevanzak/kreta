/**
 * Date utility functions for normalizing train schedule times to selected dates
 * All times are handled in WIB (Western Indonesian Time, UTC+7) timezone
 */

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000; // UTC+7 offset in milliseconds

/**
 * Extract hour and minute from a milliseconds timestamp in WIB timezone
 * @param timeMs - Milliseconds since epoch representing a recurring daily time
 * @returns Object with hour (0-23) and minute (0-59)
 */
export function extractHourMinuteFromMs(timeMs: number): {
  hour: number;
  minute: number;
} {
  // Convert to WIB timezone by adding offset, then extract hour:minute
  const wibTimeMs = timeMs + WIB_OFFSET_MS;
  const date = new Date(wibTimeMs);
  return {
    hour: date.getUTCHours(),
    minute: date.getUTCMinutes(),
  };
}

/**
 * Normalize a time (stored as ms with only hour:minute meaningful) to a selected date
 * @param timeMs - Milliseconds since epoch representing a recurring daily time
 * @param selectedDateMs - Selected date in milliseconds since epoch
 * @returns Normalized milliseconds since epoch with hour:minute from timeMs applied to selectedDateMs in WIB
 */
export function normalizeTimeToDate(
  timeMs: number,
  selectedDateMs: number
): number {
  const { hour, minute } = extractHourMinuteFromMs(timeMs);

  // Get selected date in WIB timezone
  const selectedDate = new Date(selectedDateMs + WIB_OFFSET_MS);
  const year = selectedDate.getUTCFullYear();
  const month = selectedDate.getUTCMonth();
  const day = selectedDate.getUTCDate();

  // Create new date with hour:minute applied
  const normalizedDate = new Date(Date.UTC(year, month, day, hour, minute, 0));

  // Convert back from UTC to milliseconds since epoch (subtract WIB offset)
  return normalizedDate.getTime() - WIB_OFFSET_MS;
}

/**
 * Normalize arrival time, handling next-day arrivals
 * If arrival time is before departure time, assumes arrival is on the next day
 * @param departureMs - Departure time in milliseconds (normalized to selected date)
 * @param arrivalMs - Arrival time in milliseconds (raw from DB, only hour:minute meaningful)
 * @param selectedDateMs - Selected date in milliseconds since epoch
 * @returns Normalized arrival time in milliseconds, adjusted for next day if needed
 */
export function normalizeArrivalTime(
  departureMs: number,
  arrivalMs: number,
  selectedDateMs: number
): number {
  // First normalize arrival to selected date
  let normalizedArrival = normalizeTimeToDate(arrivalMs, selectedDateMs);

  // If arrival is before departure, it's the next day - add 24 hours
  if (normalizedArrival < departureMs) {
    normalizedArrival += 24 * 60 * 60 * 1000; // Add 24 hours in milliseconds
  }

  return normalizedArrival;
}
