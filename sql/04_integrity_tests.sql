-- Team07 - CST4341 Coursework 1
-- Script 4: integrity tests. Every query should return 0 rows.
USE team07_taxi_demo;

-- T1. No driver has two overlapping assignments
SELECT a.driver_id, a.assignment_id, b.assignment_id
FROM vehicle_assignment a
JOIN vehicle_assignment b ON a.driver_id = b.driver_id AND a.assignment_id < b.assignment_id
WHERE (a.end_ts IS NULL OR a.end_ts > b.start_ts)
  AND (b.end_ts IS NULL OR b.end_ts > a.start_ts);

-- T2. Every relief assignment covers an approved absence
SELECT c.assignment_id
FROM vehicle_assignment c
WHERE c.assignment_type = 'Relief'
  AND NOT EXISTS (
    SELECT * FROM vehicle_assignment r
    JOIN driver_absence da ON da.driver_id = r.driver_id
    WHERE r.vehicle_id = c.vehicle_id AND r.shift_type = c.shift_type
      AND r.assignment_type = 'Regular' AND da.absence_status = 'Approved'
      AND DATE(c.start_ts) BETWEEN da.start_date AND da.end_date);

-- T3. Every trip starts and ends inside its shift
SELECT t.trip_id
FROM trip t
JOIN driver_shift s ON s.shift_id = t.shift_id
WHERE t.start_ts < s.login_ts OR t.end_ts > s.logout_ts;

-- T4. Every user account belongs to exactly one driver or one staff member
SELECT user_id
FROM user_account
WHERE (driver_id IS NULL AND staff_id IS NULL)
   OR (driver_id IS NOT NULL AND staff_id IS NOT NULL);

-- T5. Rejected test: a duplicate registration must be refused (Error 1062)
-- INSERT INTO vehicle VALUES (31, 'MH01TX0001', 'Maruti', 'WagonR', 'CNG', 10000, '2026-10-01', 'Assigned');

-- T6. Rejected test: the trigger must refuse a second assignment for driver 1 (Error 1644)
-- INSERT INTO vehicle_assignment VALUES (99, 1, 5, 1, 'Morning', 'Regular', '2026-10-24 06:00:00', NULL, 'Active');
