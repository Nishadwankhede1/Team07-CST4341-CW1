USE team07_taxi_demo;

SELECT a.driver_id, a.assignment_id, b.assignment_id
FROM vehicle_assignment a
JOIN vehicle_assignment b ON a.driver_id = b.driver_id AND a.assignment_id < b.assignment_id
WHERE (a.end_ts IS NULL OR a.end_ts > b.start_ts)
  AND (b.end_ts IS NULL OR b.end_ts > a.start_ts);

SELECT c.assignment_id
FROM vehicle_assignment c
WHERE c.assignment_type = 'Relief'
  AND NOT EXISTS (
    SELECT * FROM vehicle_assignment r
    JOIN driver_absence da ON da.driver_id = r.driver_id
    WHERE r.vehicle_id = c.vehicle_id AND r.shift_type = c.shift_type
      AND r.assignment_type = 'Regular' AND da.absence_status = 'Approved'
      AND DATE(c.start_ts) BETWEEN da.start_date AND da.end_date);

SELECT t.trip_id
FROM trip t
JOIN driver_shift s ON s.shift_id = t.shift_id
WHERE t.start_ts < s.login_ts OR t.end_ts > s.logout_ts;

SELECT user_id
FROM user_account
WHERE (driver_id IS NULL AND staff_id IS NULL)
   OR (driver_id IS NOT NULL AND staff_id IS NOT NULL);
