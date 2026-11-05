USE team07_taxi_demo;

SET @applicant_email = 'app068@example.test';

WITH my_application AS (
  SELECT ap.applicant_id, ap.full_name, a.application_id, a.submitted_date,
         a.application_status, a.police_verification, a.decision_date, a.rejection_reason
  FROM applicant ap
  JOIN application a ON a.applicant_id = ap.applicant_id
  WHERE ap.email = @applicant_email
),
my_documents AS (
  SELECT application_id,
         COUNT(*) AS documents_sent,
         SUM(CASE WHEN verified_flag = 'Y' THEN 1 ELSE 0 END) AS documents_verified
  FROM application_document
  GROUP BY application_id
)
SELECT m.full_name, m.application_id, m.submitted_date, m.application_status,
       m.police_verification,
       COALESCE(d.documents_sent, 0) AS documents_sent,
       COALESCE(d.documents_verified, 0) AS documents_verified,
       m.decision_date, m.rejection_reason,
       dr.driver_id AS driver_id_if_approved
FROM my_application m
LEFT JOIN my_documents d ON d.application_id = m.application_id
LEFT JOIN driver dr ON dr.application_id = m.application_id;

SET @driver_id = 61;

WITH my_shifts AS (
  SELECT s.shift_id, s.shift_date, s.login_ts, s.logout_ts,
         va.assignment_id, va.vehicle_id, va.shift_type, va.assignment_type
  FROM driver_shift s
  JOIN vehicle_assignment va ON va.assignment_id = s.assignment_id
  WHERE va.driver_id = @driver_id
),
my_trips AS (
  SELECT shift_id,
         COUNT(*) AS completed_trips,
         SUM(meter_km) AS km_driven,
         SUM(fare) AS fares
  FROM trip
  WHERE trip_status = 'Completed'
  GROUP BY shift_id
),
my_fuel AS (
  SELECT assignment_id, DATE(purchase_ts) AS fuel_date,
         SUM(quantity * unit_price) AS fuel_cost
  FROM fuel_transaction
  GROUP BY assignment_id, DATE(purchase_ts)
),
my_fines AS (
  SELECT ms.shift_id, COUNT(f.fine_id) AS fines, SUM(f.fine_amount) AS fine_total
  FROM my_shifts ms
  JOIN traffic_fine f ON f.vehicle_id = ms.vehicle_id
   AND f.violation_ts BETWEEN ms.login_ts AND ms.logout_ts
  GROUP BY ms.shift_id
)
SELECT ms.shift_date, v.registration_no, ms.shift_type, ms.assignment_type,
       COALESCE(t.completed_trips, 0) AS completed_trips,
       COALESCE(t.km_driven, 0) AS km_driven,
       COALESCE(t.fares, 0) AS fares,
       ROUND(COALESCE(t.fares, 0) * d.commission_rate, 2) AS commission_earned,
       COALESCE(fu.fuel_cost, 0) AS fuel_cost,
       COALESCE(fi.fines, 0) AS fines,
       COALESCE(fi.fine_total, 0) AS fine_amount
FROM my_shifts ms
JOIN vehicle v ON v.vehicle_id = ms.vehicle_id
JOIN driver d ON d.driver_id = @driver_id
LEFT JOIN my_trips t ON t.shift_id = ms.shift_id
LEFT JOIN my_fuel fu ON fu.assignment_id = ms.assignment_id AND fu.fuel_date = ms.shift_date
LEFT JOIN my_fines fi ON fi.shift_id = ms.shift_id
ORDER BY ms.shift_date;

WITH recruitment AS (
  SELECT COUNT(*) AS received,
         SUM(CASE WHEN application_status = 'Approved' THEN 1 ELSE 0 END) AS approved,
         SUM(CASE WHEN application_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected,
         SUM(CASE WHEN application_status = 'Pending'  THEN 1 ELSE 0 END) AS pending
  FROM application
),
cover AS (
  SELECT COUNT(*) AS absences,
         SUM(CASE WHEN EXISTS (
               SELECT * FROM vehicle_assignment r
               JOIN vehicle_assignment c ON c.vehicle_id = r.vehicle_id
                AND c.shift_type = r.shift_type AND c.assignment_type = 'Relief'
                AND DATE(c.start_ts) = da.start_date
               WHERE r.driver_id = da.driver_id AND r.assignment_type = 'Regular')
             THEN 1 ELSE 0 END) AS covered
  FROM driver_absence da
  WHERE da.absence_status = 'Approved'
),
trips AS (
  SELECT SUM(CASE WHEN trip_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
         SUM(CASE WHEN verification_status = 'Flagged' THEN 1 ELSE 0 END) AS flagged
  FROM trip
),
fuel AS (
  SELECT ROUND(SUM(quantity * unit_price), 2) AS fuel_cost,
         SUM(CASE WHEN verification_status = 'Pending' THEN 1 ELSE 0 END) AS pending
  FROM fuel_transaction
),
fines AS (
  SELECT COUNT(*) AS total,
         SUM(CASE WHEN responsibility = 'Unresolved' THEN 1 ELSE 0 END) AS unresolved,
         SUM(CASE WHEN vehicle_id IS NULL THEN 1 ELSE 0 END) AS unmatched
  FROM traffic_fine
),
busiest_area AS (
  SELECT oa.area_name, COUNT(*) AS pickups
  FROM trip t JOIN operating_area oa ON oa.area_id = t.pickup_area_id
  WHERE t.trip_status = 'Completed'
  GROUP BY oa.area_name
  ORDER BY pickups DESC LIMIT 1
),
quietest_area AS (
  SELECT oa.area_name, COUNT(*) AS pickups
  FROM trip t JOIN operating_area oa ON oa.area_id = t.pickup_area_id
  WHERE t.trip_status = 'Completed'
  GROUP BY oa.area_name
  ORDER BY pickups ASC LIMIT 1
)
SELECT 'Recruitment' AS area, 'Applications received' AS measure, received AS value FROM recruitment
UNION ALL SELECT 'Recruitment', 'Approved', approved FROM recruitment
UNION ALL SELECT 'Recruitment', 'Rejected', rejected FROM recruitment
UNION ALL SELECT 'Recruitment', 'Pending', pending FROM recruitment
UNION ALL SELECT 'Fleet', 'Taxis in service', COUNT(*) FROM vehicle WHERE vehicle_status <> 'Out of Service'
UNION ALL SELECT 'Fleet', 'Approved absences', absences FROM cover
UNION ALL SELECT 'Fleet', 'Absences covered by relief', covered FROM cover
UNION ALL SELECT 'Fleet', 'Relocations requested', COUNT(*) FROM relocation
UNION ALL SELECT 'Performance', 'Completed trips', completed FROM trips
UNION ALL SELECT 'Checks', 'Trips flagged (meter vs GPS)', flagged FROM trips
UNION ALL SELECT 'Checks', 'Fuel cost (Rs)', fuel_cost FROM fuel
UNION ALL SELECT 'Checks', 'Fuel receipts pending', pending FROM fuel
UNION ALL SELECT 'Checks', 'Traffic fines', total FROM fines
UNION ALL SELECT 'Checks', 'Fines unresolved', unresolved FROM fines
UNION ALL SELECT 'Checks', 'Fines with unknown taxi', unmatched FROM fines
UNION ALL SELECT 'Demand', CONCAT('Busiest pickup area: ', area_name), pickups FROM busiest_area
UNION ALL SELECT 'Demand', CONCAT('Quietest pickup area: ', area_name), pickups FROM quietest_area;

WITH reports AS (
  SELECT vehicle_id,
         COUNT(*) AS problems_reported,
         SUM(CASE WHEN report_status <> 'Resolved' THEN 1 ELSE 0 END) AS open_problems,
         COUNT(DISTINCT problem_type) AS problem_types
  FROM problem_report
  GROUP BY vehicle_id
),
parts AS (
  SELECT job_id, SUM(quantity * unit_cost) AS parts_cost
  FROM maintenance_part
  GROUP BY job_id
),
jobs AS (
  SELECT j.vehicle_id,
         COUNT(*) AS jobs,
         SUM(CASE WHEN j.job_status <> 'Completed' THEN 1 ELSE 0 END) AS open_jobs,
         MAX(j.completed_ts) AS last_completed,
         SUM(j.labour_cost) AS labour_cost,
         SUM(COALESCE(p.parts_cost, 0)) AS parts_cost,
         SUM(TIMESTAMPDIFF(MINUTE, j.start_ts, j.completed_ts)) / 60 AS downtime_hours
  FROM maintenance_job j
  LEFT JOIN parts p ON p.job_id = j.job_id
  GROUP BY j.vehicle_id
)
SELECT v.registration_no, v.vehicle_status,
       COALESCE(r.problems_reported, 0) AS problems_reported,
       COALESCE(r.open_problems, 0) AS open_problems,
       COALESCE(j.jobs, 0) AS jobs,
       COALESCE(j.open_jobs, 0) AS open_jobs,
       j.last_completed,
       COALESCE(j.labour_cost, 0) + COALESCE(j.parts_cost, 0) AS repair_cost,
       ROUND(COALESCE(j.downtime_hours, 0), 1) AS downtime_hours,
       CASE WHEN COALESCE(r.problems_reported, 0) > 1 THEN 'Repeat issue' ELSE '' END AS warning
FROM vehicle v
LEFT JOIN reports r ON r.vehicle_id = v.vehicle_id
LEFT JOIN jobs j ON j.vehicle_id = v.vehicle_id
WHERE r.vehicle_id IS NOT NULL OR j.vehicle_id IS NOT NULL
ORDER BY open_jobs DESC, repair_cost DESC;

WITH daily_trips AS (
  SELECT s.shift_date AS day,
         COUNT(DISTINCT va.vehicle_id) AS taxis_used,
         COUNT(DISTINCT va.driver_id) AS drivers_worked,
         COUNT(t.trip_id) AS completed_trips,
         SUM(t.fare) AS revenue
  FROM driver_shift s
  JOIN vehicle_assignment va ON va.assignment_id = s.assignment_id
  JOIN trip t ON t.shift_id = s.shift_id AND t.trip_status = 'Completed'
  GROUP BY s.shift_date
),
daily_fuel AS (
  SELECT DATE(purchase_ts) AS day, SUM(quantity * unit_price) AS fuel_cost
  FROM fuel_transaction
  GROUP BY DATE(purchase_ts)
),
period_costs AS (
  SELECT (SELECT SUM(labour_cost) FROM maintenance_job)
       + (SELECT SUM(quantity * unit_cost) FROM maintenance_part) AS maintenance_cost,
         (SELECT SUM(amount) FROM vehicle_expense) AS other_vehicle_costs
)
SELECT t.day, t.taxis_used, t.drivers_worked, t.completed_trips,
       ROUND(t.revenue, 2) AS revenue,
       ROUND(COALESCE(f.fuel_cost, 0), 2) AS fuel_cost,
       ROUND(t.revenue / t.taxis_used, 2) AS revenue_per_taxi,
       NULL AS maintenance_cost, NULL AS other_vehicle_costs,
       ROUND(t.revenue - COALESCE(f.fuel_cost, 0), 2) AS contribution
FROM daily_trips t
LEFT JOIN daily_fuel f ON f.day = t.day
UNION ALL
SELECT 'Total', (SELECT COUNT(*) FROM vehicle),
       (SELECT COUNT(*) FROM driver WHERE driver_status = 'Active'),
       SUM(t.completed_trips), ROUND(SUM(t.revenue), 2),
       ROUND((SELECT SUM(quantity * unit_price) FROM fuel_transaction), 2),
       ROUND(SUM(t.revenue) / (SELECT COUNT(*) FROM vehicle), 2),
       pc.maintenance_cost, pc.other_vehicle_costs,
       ROUND(SUM(t.revenue) - (SELECT SUM(quantity * unit_price) FROM fuel_transaction)
             - pc.maintenance_cost - pc.other_vehicle_costs, 2)
FROM daily_trips t CROSS JOIN period_costs pc
GROUP BY pc.maintenance_cost, pc.other_vehicle_costs;

WITH checks AS (
  SELECT 'Duplicate meter records' AS check_name,
         (SELECT COUNT(*) - COUNT(DISTINCT meter_record_ref) FROM trip) AS issues
  UNION ALL SELECT 'Trips with meter vs GPS difference over 5%',
         (SELECT COUNT(*) FROM trip WHERE ABS(meter_km - gps_km) > 0.05 * meter_km)
  UNION ALL SELECT 'Fuel receipts where OCR amount differs',
         (SELECT COUNT(*) FROM fuel_transaction
          WHERE ocr_amount IS NULL OR ABS(ocr_amount - quantity * unit_price) > 0.01)
  UNION ALL SELECT 'Fuel receipts not verified',
         (SELECT COUNT(*) FROM fuel_transaction WHERE verification_status <> 'Verified')
  UNION ALL SELECT 'Fines with no matching taxi',
         (SELECT COUNT(*) FROM traffic_fine WHERE vehicle_id IS NULL)
  UNION ALL SELECT 'Fines not yet investigated',
         (SELECT COUNT(*) FROM traffic_fine WHERE responsibility = 'Unresolved')
  UNION ALL SELECT 'Assignments with no worked shift',
         (SELECT COUNT(*) FROM vehicle_assignment va
          WHERE NOT EXISTS (SELECT * FROM driver_shift s WHERE s.assignment_id = va.assignment_id))
  UNION ALL SELECT 'Open data-quality issues',
         (SELECT COUNT(*) FROM data_quality_issue WHERE issue_status <> 'Resolved')
  UNION ALL SELECT 'Rows rejected in data loads',
         (SELECT SUM(records_rejected) FROM data_load_log)
  UNION ALL SELECT 'Failed data loads',
         (SELECT COUNT(*) FROM data_load_log WHERE load_status <> 'Success')
)
SELECT check_name, issues,
       CASE WHEN issues = 0 THEN 'OK' ELSE 'Review' END AS result
FROM checks
UNION ALL
SELECT CONCAT('Last data load finished: ', MAX(load_finished)), NULL, 'Info'
FROM data_load_log;

WITH shift_hours AS (
  SELECT va.driver_id, va.shift_type, va.assignment_type, s.shift_id,
         TIMESTAMPDIFF(MINUTE, s.login_ts, s.logout_ts) / 60 AS hours_worked
  FROM driver_shift s
  JOIN vehicle_assignment va ON va.assignment_id = s.assignment_id
),
shift_revenue AS (
  SELECT shift_id, COUNT(*) AS trips, SUM(fare) AS revenue
  FROM trip
  WHERE trip_status = 'Completed'
  GROUP BY shift_id
),
driver_totals AS (
  SELECT h.driver_id, h.shift_type,
         MAX(h.assignment_type) AS driver_role,
         COUNT(h.shift_id) AS shifts,
         SUM(COALESCE(r.trips, 0)) AS trips,
         SUM(COALESCE(r.revenue, 0)) AS revenue,
         SUM(h.hours_worked) AS hours
  FROM shift_hours h
  LEFT JOIN shift_revenue r ON r.shift_id = h.shift_id
  GROUP BY h.driver_id, h.shift_type
),
ranked AS (
  SELECT dt.*, ROUND(dt.revenue / dt.hours, 2) AS revenue_per_hour,
         RANK() OVER (PARTITION BY dt.shift_type ORDER BY dt.revenue / dt.hours DESC) AS rank_in_shift
  FROM driver_totals dt
)
SELECT r.shift_type, r.rank_in_shift, ap.full_name AS driver, r.driver_role,
       r.shifts, r.trips, ROUND(r.revenue, 2) AS revenue,
       ROUND(r.hours, 1) AS hours_worked, r.revenue_per_hour
FROM ranked r
JOIN driver d ON d.driver_id = r.driver_id
JOIN application a ON a.application_id = d.application_id
JOIN applicant ap ON ap.applicant_id = a.applicant_id
WHERE r.rank_in_shift <= 5
ORDER BY r.shift_type, r.rank_in_shift;
