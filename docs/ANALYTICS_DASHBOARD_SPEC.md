# Analytics Dashboard Specification

This document specifies the PostHog dashboards and insights to create for monitoring Kreta's key metrics.

## ✅ Implementation Status

**Completed:** November 11, 2025

All 5 dashboards have been successfully created in PostHog with 19 total insights:

| Dashboard           | Insights | Status      | URL                                                                      |
| ------------------- | -------- | ----------- | ------------------------------------------------------------------------ |
| Executive Overview  | 3        | ✅ Complete | [View Dashboard](https://us.posthog.com/project/241616/dashboard/643558) |
| Journey Performance | 4        | ✅ Complete | [View Dashboard](https://us.posthog.com/project/241616/dashboard/643560) |
| Feature Adoption    | 5        | ✅ Complete | [View Dashboard](https://us.posthog.com/project/241616/dashboard/643562) |
| User Engagement     | 4        | ✅ Complete | [View Dashboard](https://us.posthog.com/project/241616/dashboard/643566) |
| Technical Health    | 3        | ✅ Complete | [View Dashboard](https://us.posthog.com/project/241616/dashboard/643569) |

**Key Metrics Tracked:**

- Journey funnel and completion rates
- Active users (DAU/WAU/MAU)
- Alarm adoption and reliability
- Popular stations, routes, and trains
- App lifecycle and backend activity

**Next Steps:**

- Configure alerts (critical, warning, and weekly summary)
- Review dashboards with team
- Consider implementing recommended additional events

## Dashboard 1: Executive Overview

**Purpose:** High-level health metrics for weekly review
**Audience:** Product managers, executives

### Insights

#### 1. North Star Metric Card

- **Metric:** Completed Journeys per Active User per Week
- **Type:** Trend
- **Formula:** `count(journey_completed) / unique_users(journey_started)` per week
- **Time Range:** Last 30 days
- **Visualization:** Large number with trend line

#### 2. Journey Funnel

- **Type:** Funnel
- **Steps:**
  1. `train_search_initiated`
  2. `station_selected` (departure)
  3. `station_selected` (arrival)
  4. `train_selected`
  5. `journey_started`
  6. `journey_completed`
- **Time Range:** Last 7 days
- **Breakdown:** None
- **Goal:** Identify drop-off points in journey creation

#### 3. Journey Completion Rate

- **Type:** Trend
- **Formula:** `(count(journey_completed) / count(journey_started)) × 100`
- **Time Range:** Last 30 days, grouped by day
- **Visualization:** Line chart
- **Target Line:** 85%

#### 4. Active Users Trend

- **Type:** Trend
- **Metrics:**
  - DAU (Daily Active Users)
  - WAU (Weekly Active Users)
  - MAU (Monthly Active Users)
- **Time Range:** Last 90 days
- **Visualization:** Multi-line chart

#### 5. Retention Cohorts

- **Type:** Retention table
- **Cohort By:** User signup/first journey date
- **Returning Event:** `journey_started`
- **Time Range:** Last 12 weeks
- **Breakdown:** By week

---

## Dashboard 2: Journey Performance

**Purpose:** Deep dive into journey lifecycle and quality
**Audience:** Product managers, data analysts

### Insights

#### 1. Journey States Breakdown

- **Type:** Pie chart
- **Events:**
  - `journey_completed` (completion_type: "arrival_screen")
  - `journey_completed` (completion_type: "scheduled_arrival")
  - `journey_cancelled`
- **Time Range:** Last 30 days
- **Goal:** Understand how journeys end

#### 2. Cancellation Reasons

- **Type:** Bar chart
- **Event:** `journey_cancelled`
- **Breakdown:** By `reason` property
- **Time Range:** Last 30 days
- **Sort:** Descending by count

#### 3. Average Journey Duration

- **Type:** Trend
- **Event:** `journey_completed`
- **Formula:** `avg(journey_duration_actual_minutes)`
- **Time Range:** Last 30 days, grouped by day
- **Visualization:** Line chart with confidence interval

#### 4. Journey Duration Distribution

- **Type:** Histogram
- **Event:** `journey_completed`
- **Property:** `journey_duration_actual_minutes`
- **Bins:** 0-30, 30-60, 60-120, 120-180, 180-300, 300+
- **Time Range:** Last 30 days

#### 5. Round-Trip Behavior

- **Type:** Insights list
- **Metrics:**
  - Count of `round_trip_completed` events
  - % of users with round trips (vs total active users)
  - Average `days_between_trips`
- **Time Range:** Last 30 days

#### 6. Round-Trip Direction Analysis

- **Type:** Pie chart
- **Event:** `round_trip_completed`
- **Breakdown:** By `is_reverse_direction` (true/false)
- **Time Range:** Last 30 days
- **Goal:** Understand commuter vs. tourist behavior

---

## Dashboard 3: Feature Adoption

**Purpose:** Track adoption of key features
**Audience:** Product managers, feature owners

### Insights

#### 1. Alarm Adoption Rate

- **Type:** Trend
- **Formula:** `(count(journey_started WHERE has_alarm_enabled=true) / count(journey_started)) × 100`
- **Time Range:** Last 30 days, grouped by day
- **Visualization:** Line chart
- **Target Line:** 70%

#### 2. Alarm Reliability

- **Type:** Insights list
- **Metrics:**
  - Total `alarm_scheduled` events
  - Total `alarm_triggered` events
  - Trigger rate: `(triggered / scheduled) × 100`
- **Time Range:** Last 7 days
- **Goal:** Validate alarm system reliability

#### 3. Live Activity State Transitions

- **Type:** Sankey diagram
- **Event:** `live_activity_state_changed`
- **Flow:** state property values over time
- **Time Range:** Last 7 days
- **Goal:** Understand Live Activity usage patterns

#### 4. Notification Engagement

- **Type:** Funnel
- **Steps:**
  1. `alarm_triggered`
  2. `notification_interaction`
  3. `arrival_confirmed`
- **Time Range:** Last 7 days
- **Goal:** Measure notification-to-action conversion

#### 5. Deep Link Usage

- **Type:** Table
- **Event:** `deep_link_opened`
- **Columns:**
  - URL path
  - Count
  - Unique users
- **Time Range:** Last 30 days
- **Sort:** Descending by count

#### 6. Feedback Engagement

- **Type:** Insights list
- **Metrics:**
  - Total feedback submissions (backend metric)
  - Unique users submitting feedback
  - % active users providing feedback
- **Time Range:** Last 30 days

---

## Dashboard 4: User Engagement

**Purpose:** Understand user behavior and engagement patterns
**Audience:** Growth team, product managers

### Insights

#### 1. Popular Stations (Departures)

- **Type:** Bar chart
- **Event:** `station_selected` WHERE `selection_type = "departure"`
- **Breakdown:** By `station_name`
- **Time Range:** Last 30 days
- **Limit:** Top 20
- **Sort:** Descending

#### 2. Popular Stations (Arrivals)

- **Type:** Bar chart
- **Event:** `station_selected` WHERE `selection_type = "arrival"`
- **Breakdown:** By `station_name`
- **Time Range:** Last 30 days
- **Limit:** Top 20
- **Sort:** Descending

#### 3. Popular Routes

- **Type:** Table
- **Event:** `journey_started`
- **Columns:**
  - Route: `from_station_name → to_station_name`
  - Journey count
  - Unique users
  - Avg completion rate
- **Time Range:** Last 30 days
- **Limit:** Top 50

#### 4. Popular Trains

- **Type:** Bar chart
- **Event:** `train_selected`
- **Breakdown:** By `train_name`
- **Time Range:** Last 30 days
- **Limit:** Top 20
- **Sort:** Descending

#### 5. Booking Lead Time

- **Type:** Histogram
- **Event:** `journey_started`
- **Property:** `time_until_departure_minutes`
- **Bins:** 0-30, 30-60, 60-180, 180-360, 360-1440, 1440+
- **Time Range:** Last 30 days
- **Goal:** Understand when users plan journeys (just-in-time vs advance planning)

#### 6. Time of Day Usage

- **Type:** Heatmap
- **Event:** `journey_started`
- **X-axis:** Hour of day (0-23)
- **Y-axis:** Day of week
- **Color:** Count of events
- **Time Range:** Last 30 days

---

## Dashboard 5: Technical Health

**Purpose:** Monitor technical performance and reliability
**Audience:** Engineering team, product managers

### Insights

#### 1. Screen Views

- **Type:** Table
- **Event:** Screen viewed (from Telemetry service)
- **Columns:**
  - Screen name
  - View count
  - Unique users
  - Avg time on screen (if available)
- **Time Range:** Last 7 days
- **Sort:** Descending by count

#### 2. Error Rate

- **Type:** Trend
- **Data Source:** Sentry integration
- **Metrics:**
  - Total errors
  - Unique errors
  - Affected users
- **Time Range:** Last 7 days, grouped by hour
- **Visualization:** Line chart

#### 3. API Response Times

- **Type:** Trend
- **Data Source:** Custom backend metrics (if available)
- **Metrics:**
  - P50, P95, P99 response times
- **Time Range:** Last 24 hours, grouped by hour
- **Visualization:** Multi-line chart

#### 4. Real-time Sync Latency

- **Type:** Trend
- **Data Source:** Convex metrics (if available)
- **Metric:** Time from backend update to client render
- **Time Range:** Last 24 hours
- **Visualization:** Line chart with bands

#### 5. Push Token Registration Success Rate

- **Type:** Insights list
- **Data Source:** Backend `registrations` table
- **Metrics:**
  - Total registration attempts
  - Successful registrations
  - Success rate percentage
- **Time Range:** Last 7 days

---

## Alerts to Configure

### Critical Alerts (PagerDuty/Slack immediately)

1. **Journey Completion Rate Drop**

   - Condition: `(journey_completed / journey_started) < 0.70` for 1 hour
   - Severity: P1
   - Recipients: On-call engineer, Product Manager

2. **Alarm Trigger Rate Drop**

   - Condition: `(alarm_triggered / alarm_scheduled) < 0.90` for 1 hour
   - Severity: P1
   - Recipients: On-call engineer
   - Reason: Critical feature failure

3. **Crash Rate Spike**
   - Condition: Crash-free rate `< 98%` in last hour
   - Severity: P1
   - Recipients: Engineering team

### Warning Alerts (Slack during business hours)

4. **Journey Funnel Drop-off**

   - Condition: Drop-off between `train_selected` and `journey_started` > 40%
   - Severity: P2
   - Recipients: Product Manager

5. **DAU Drop**

   - Condition: DAU drops > 20% compared to 7-day average
   - Severity: P2
   - Recipients: Growth team, Product Manager

6. **Feedback Volume Spike**
   - Condition: Feedback submissions > 2x normal rate
   - Severity: P3
   - Recipients: Product Manager, Support team
   - Reason: May indicate new issue or viral moment

### Weekly Summary Alerts (Email every Monday)

7. **Weekly Metrics Summary**
   - Content:
     - North Star Metric trend
     - Journey completion rate
     - Top cancellation reasons
     - New vs returning users
     - Top feature requests from feedback
   - Recipients: All stakeholders

---

## Custom Events to Add

Based on the analysis above, consider tracking these additional events:

### Recommended Additions

1. **`journey_paused`**

   - When: User backgrounds the app during active journey
   - Properties: time_remaining_minutes, journey_progress_percent
   - Value: Understand engagement patterns

2. **`journey_resumed`**

   - When: User returns to app during active journey
   - Properties: time_away_minutes
   - Value: Measure re-engagement

3. **`map_interaction`**

   - When: User pans/zooms map, taps train marker
   - Properties: action_type (pan/zoom/tap), current_journey_state
   - Value: Understand map engagement

4. **`alarm_settings_changed`**

   - When: User modifies alarm offset or enables/disables
   - Properties: old_value, new_value, setting_type
   - Value: Understand alarm preferences

5. **`live_activity_viewed`**

   - When: User looks at Live Activity (estimate via screen unlock with active activity)
   - Properties: journey_state, time_until_arrival_minutes
   - Value: Measure Live Activity value

6. **`feature_discovery`**
   - When: User interacts with feature for first time
   - Properties: feature_name (alarm, live_activity, feedback, etc.)
   - Value: Track feature discoverability

---

## Implementation Checklist

- [x] Create PostHog account/project (if not exists)
- [x] Set up Dashboards 1-5 as specified above
  - [x] Dashboard 1: Executive Overview (3 insights)
  - [x] Dashboard 2: Journey Performance (4 insights)
  - [x] Dashboard 3: Feature Adoption (5 insights)
  - [x] Dashboard 4: User Engagement (4 insights)
  - [x] Dashboard 5: Technical Health (3 insights)
- [ ] Configure critical alerts with PagerDuty/Slack
- [ ] Configure warning alerts with Slack
- [ ] Set up weekly summary email
- [x] Share dashboard links with team (URLs documented below)
- [ ] Schedule weekly metrics review meeting
- [x] Document dashboard access instructions (URLs provided below)
- [ ] Consider implementing additional recommended events
- [ ] Set up Sentry integration in PostHog (if available)
- [ ] Configure session recordings (optional, privacy-conscious)

---

## Dashboard URLs

✅ **All dashboards have been created in PostHog:**

- **Executive Overview:** https://us.posthog.com/project/241616/dashboard/643558
- **Journey Performance:** https://us.posthog.com/project/241616/dashboard/643560
- **Feature Adoption:** https://us.posthog.com/project/241616/dashboard/643562
- **User Engagement:** https://us.posthog.com/project/241616/dashboard/643566
- **Technical Health:** https://us.posthog.com/project/241616/dashboard/643569

---

## Maintenance

- **Review Frequency:** Monthly
- **Owner:** Product Manager
- **Next Review:** December 5, 2025
- **Update Triggers:**
  - New feature launches
  - Metric targets change
  - Alert threshold adjustments needed
  - Additional insights requested by stakeholders
