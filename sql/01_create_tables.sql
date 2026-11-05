DROP DATABASE IF EXISTS team07_taxi_demo;
CREATE DATABASE team07_taxi_demo;
USE team07_taxi_demo;

CREATE TABLE staff (
  staff_id INT PRIMARY KEY,
  full_name VARCHAR(80) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  staff_type VARCHAR(20) NOT NULL,
  hire_date DATE NOT NULL,
  staff_status VARCHAR(10) NOT NULL,
  CHECK (staff_type IN ('Fleet Manager','Maintenance','Administrator','Finance','Management')),
  CHECK (staff_status IN ('Active','Inactive'))
);

CREATE TABLE operating_area (
  area_id INT PRIMARY KEY,
  area_name VARCHAR(40) NOT NULL UNIQUE,
  zone_category VARCHAR(20) NOT NULL
);

CREATE TABLE applicant (
  applicant_id INT PRIMARY KEY,
  full_name VARCHAR(80) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  phone VARCHAR(15) NOT NULL,
  city VARCHAR(40) NOT NULL
);

CREATE TABLE application (
  application_id INT PRIMARY KEY,
  applicant_id INT NOT NULL,
  submitted_date DATE NOT NULL,
  application_status VARCHAR(10) NOT NULL,
  police_verification VARCHAR(10) NOT NULL,
  reviewed_by INT NULL,
  decision_date DATE NULL,
  rejection_reason VARCHAR(200) NULL,
  FOREIGN KEY (applicant_id) REFERENCES applicant(applicant_id),
  FOREIGN KEY (reviewed_by) REFERENCES staff(staff_id),
  CHECK (application_status IN ('Pending','Approved','Rejected')),
  CHECK (police_verification IN ('Pending','Cleared','Failed')),
  CHECK (application_status <> 'Rejected' OR rejection_reason IS NOT NULL),
  CHECK (decision_date IS NULL OR decision_date >= submitted_date)
);

CREATE TABLE application_document (
  document_id INT PRIMARY KEY,
  application_id INT NOT NULL,
  document_type VARCHAR(30) NOT NULL,
  document_ref VARCHAR(40) NOT NULL UNIQUE,
  verified_flag CHAR(1) NOT NULL,
  FOREIGN KEY (application_id) REFERENCES application(application_id),
  CHECK (verified_flag IN ('Y','N'))
);

CREATE TABLE driver (
  driver_id INT PRIMARY KEY,
  application_id INT NOT NULL UNIQUE,
  licence_no VARCHAR(20) NOT NULL UNIQUE,
  driver_type VARCHAR(10) NOT NULL,
  employment_start DATE NOT NULL,
  driver_status VARCHAR(12) NOT NULL,
  base_salary DECIMAL(10,2) NOT NULL,
  commission_rate DECIMAL(4,3) NOT NULL,
  manager_id INT NOT NULL,
  FOREIGN KEY (application_id) REFERENCES application(application_id),
  FOREIGN KEY (manager_id) REFERENCES staff(staff_id),
  CHECK (driver_type IN ('Permanent','Casual')),
  CHECK (driver_status IN ('Active','Inactive','Suspended','Terminated')),
  CHECK ((driver_type = 'Permanent' AND base_salary > 0) OR (driver_type = 'Casual' AND base_salary = 0)),
  CHECK (commission_rate BETWEEN 0 AND 1)
);

CREATE TABLE vehicle (
  vehicle_id INT PRIMARY KEY,
  registration_no VARCHAR(20) NOT NULL UNIQUE,
  make VARCHAR(40) NOT NULL,
  model VARCHAR(60) NOT NULL,
  fuel_type VARCHAR(10) NOT NULL,
  service_interval_km INT NOT NULL CHECK(service_interval_km > 0),
  acquisition_date DATE NOT NULL,
  vehicle_status VARCHAR(25) NOT NULL
);

CREATE TABLE vehicle_document (
  vehicle_document_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  document_type VARCHAR(20) NOT NULL,
  document_ref VARCHAR(40) NOT NULL UNIQUE,
  valid_until DATE NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  UNIQUE (vehicle_id, document_type),
  CHECK (document_type IN ('Insurance','Permit','Fitness','Pollution'))
);

CREATE TABLE driver_absence (
  absence_id INT PRIMARY KEY,
  driver_id INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  absence_type VARCHAR(12) NOT NULL,
  absence_status VARCHAR(10) NOT NULL,
  approved_by INT NULL,
  FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
  FOREIGN KEY (approved_by) REFERENCES staff(staff_id),
  CHECK (end_date >= start_date),
  CHECK (absence_status IN ('Pending','Approved','Rejected'))
);

CREATE TABLE vehicle_assignment (
  assignment_id INT PRIMARY KEY,
  driver_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  assigned_by INT NOT NULL,
  shift_type VARCHAR(10) NOT NULL,
  assignment_type VARCHAR(10) NOT NULL,
  start_ts DATETIME NOT NULL,
  end_ts DATETIME NULL,
  assignment_status VARCHAR(12) NOT NULL,
  FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  FOREIGN KEY (assigned_by) REFERENCES staff(staff_id),
  CHECK (shift_type IN ('Morning','Night')),
  CHECK (assignment_type IN ('Regular','Relief')),
  CHECK (assignment_status IN ('Active','Completed','Cancelled')),
  CHECK (end_ts IS NULL OR end_ts > start_ts)
);

CREATE TABLE driver_shift (
  shift_id INT PRIMARY KEY,
  assignment_id INT NOT NULL,
  shift_date DATE NOT NULL,
  login_ts DATETIME NOT NULL,
  logout_ts DATETIME NULL,
  FOREIGN KEY (assignment_id) REFERENCES vehicle_assignment(assignment_id),
  UNIQUE (assignment_id, shift_date),
  CHECK (logout_ts IS NULL OR logout_ts > login_ts)
);

CREATE TABLE trip (
  trip_id INT PRIMARY KEY,
  shift_id INT NOT NULL,
  meter_record_ref VARCHAR(45) NOT NULL UNIQUE,
  start_ts DATETIME NOT NULL,
  end_ts DATETIME NOT NULL,
  pickup_area_id INT NOT NULL,
  dropoff_area_id INT NOT NULL,
  meter_km DECIMAL(8,2) NOT NULL CHECK(meter_km >= 0),
  gps_km DECIMAL(8,2) NOT NULL CHECK(gps_km >= 0),
  fare DECIMAL(12,2) NOT NULL CHECK(fare >= 0),
  payment_method VARCHAR(15) NOT NULL,
  trip_status VARCHAR(12) NOT NULL,
  verification_status VARCHAR(10) NOT NULL,
  FOREIGN KEY (shift_id) REFERENCES driver_shift(shift_id),
  FOREIGN KEY (pickup_area_id) REFERENCES operating_area(area_id),
  FOREIGN KEY (dropoff_area_id) REFERENCES operating_area(area_id),
  CHECK (end_ts > start_ts)
);

CREATE TABLE gps_point (
  gps_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  event_ts DATETIME NOT NULL,
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  area_id INT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  FOREIGN KEY (area_id) REFERENCES operating_area(area_id),
  CHECK (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
);

CREATE TABLE relocation (
  relocation_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  from_area_id INT NOT NULL,
  to_area_id INT NOT NULL,
  requested_by INT NOT NULL,
  requested_ts DATETIME NOT NULL,
  reason VARCHAR(100) NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  FOREIGN KEY (from_area_id) REFERENCES operating_area(area_id),
  FOREIGN KEY (to_area_id) REFERENCES operating_area(area_id),
  FOREIGN KEY (requested_by) REFERENCES staff(staff_id),
  CHECK (from_area_id <> to_area_id)
);

CREATE TABLE fuel_transaction (
  fuel_txn_id INT PRIMARY KEY,
  assignment_id INT NOT NULL,
  receipt_ref VARCHAR(30) NOT NULL UNIQUE,
  purchase_ts DATETIME NOT NULL,
  quantity DECIMAL(8,2) NOT NULL CHECK(quantity > 0),
  unit_price DECIMAL(8,2) NOT NULL CHECK(unit_price > 0),
  odometer_km INT NOT NULL CHECK(odometer_km >= 0),
  ocr_quantity DECIMAL(8,2) NULL,
  ocr_amount DECIMAL(10,2) NULL,
  verification_status VARCHAR(10) NOT NULL,
  FOREIGN KEY (assignment_id) REFERENCES vehicle_assignment(assignment_id),
  CHECK (verification_status IN ('Verified','Pending','Rejected'))
);

CREATE TABLE vehicle_expense (
  expense_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  expense_ref VARCHAR(30) NOT NULL UNIQUE,
  expense_date DATE NOT NULL,
  expense_type VARCHAR(20) NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK(amount >= 0),
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  CHECK (expense_type IN ('Insurance','Registration','Permit','Depreciation','Other'))
);

CREATE TABLE problem_report (
  report_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  reported_by_driver_id INT NULL,
  reported_ts DATETIME NOT NULL,
  problem_type VARCHAR(30) NOT NULL,
  description VARCHAR(255) NOT NULL,
  report_status VARCHAR(15) NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  FOREIGN KEY (reported_by_driver_id) REFERENCES driver(driver_id),
  CHECK (report_status IN ('Open','Under Review','Resolved'))
);

CREATE TABLE problem_photo (
  photo_id INT PRIMARY KEY,
  report_id INT NOT NULL,
  photo_ref VARCHAR(100) NOT NULL UNIQUE,
  FOREIGN KEY (report_id) REFERENCES problem_report(report_id)
);

CREATE TABLE maintenance_job (
  job_id INT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  report_id INT NULL,
  assigned_staff_id INT NOT NULL,
  job_type VARCHAR(15) NOT NULL,
  start_ts DATETIME NOT NULL,
  completed_ts DATETIME NULL,
  job_status VARCHAR(15) NOT NULL,
  odometer_km INT NOT NULL CHECK(odometer_km >= 0),
  labour_cost DECIMAL(10,2) NOT NULL CHECK(labour_cost >= 0),
  roadworthy CHAR(1) NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  FOREIGN KEY (report_id) REFERENCES problem_report(report_id),
  FOREIGN KEY (assigned_staff_id) REFERENCES staff(staff_id),
  CHECK (job_type IN ('Scheduled','Repair','Emergency')),
  CHECK (job_status IN ('Pending','In Progress','Completed')),
  CHECK (roadworthy IN ('Y','N')),
  CHECK (completed_ts IS NULL OR completed_ts > start_ts)
);

CREATE TABLE maintenance_part (
  part_id INT PRIMARY KEY,
  job_id INT NOT NULL,
  part_ref VARCHAR(20) NOT NULL,
  part_description VARCHAR(100) NOT NULL,
  quantity INT NOT NULL CHECK(quantity > 0),
  unit_cost DECIMAL(10,2) NOT NULL CHECK(unit_cost >= 0),
  FOREIGN KEY (job_id) REFERENCES maintenance_job(job_id)
);

CREATE TABLE traffic_fine (
  fine_id INT PRIMARY KEY,
  challan_no VARCHAR(20) NOT NULL UNIQUE,
  notice_registration_no VARCHAR(20) NOT NULL,
  vehicle_id INT NULL,
  violation_ts DATETIME NOT NULL,
  violation_type VARCHAR(40) NOT NULL,
  fine_amount DECIMAL(10,2) NOT NULL CHECK(fine_amount > 0),
  responsibility VARCHAR(15) NOT NULL,
  payment_status VARCHAR(15) NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicle(vehicle_id),
  CHECK (responsibility IN ('Driver','Company','Unresolved')),
  CHECK (payment_status IN ('Unpaid','Paid','Partially Paid'))
);

CREATE TABLE driver_payment (
  payment_id INT PRIMARY KEY,
  driver_id INT NOT NULL,
  pay_month DATE NOT NULL,
  base_pay DECIMAL(10,2) NOT NULL CHECK(base_pay >= 0),
  commission_pay DECIMAL(10,2) NOT NULL CHECK(commission_pay >= 0),
  deduction DECIMAL(10,2) NOT NULL CHECK(deduction >= 0),
  payment_status VARCHAR(12) NOT NULL,
  FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
  UNIQUE (driver_id, pay_month),
  CHECK (payment_status IN ('Calculated','Approved','Paid'))
);

CREATE TABLE user_account (
  user_id INT PRIMARY KEY,
  username VARCHAR(40) NOT NULL UNIQUE,
  user_role VARCHAR(20) NOT NULL,
  driver_id INT NULL UNIQUE,
  staff_id INT NULL UNIQUE,
  account_status VARCHAR(10) NOT NULL,
  mfa_enabled CHAR(1) NOT NULL,
  FOREIGN KEY (driver_id) REFERENCES driver(driver_id),
  FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
  CHECK ((driver_id IS NOT NULL AND staff_id IS NULL) OR (driver_id IS NULL AND staff_id IS NOT NULL)),
  CHECK (account_status IN ('Active','Inactive')),
  CHECK (mfa_enabled IN ('Y','N'))
);

CREATE TABLE data_load_log (
  load_id INT PRIMARY KEY,
  source_system VARCHAR(60) NOT NULL,
  load_started DATETIME NOT NULL,
  load_finished DATETIME NULL,
  load_status VARCHAR(12) NOT NULL,
  records_loaded INT NOT NULL CHECK(records_loaded >= 0),
  records_rejected INT NOT NULL CHECK(records_rejected >= 0),
  CHECK (load_status IN ('Success','Failed','Partial','Running')),
  CHECK (load_finished IS NULL OR load_finished >= load_started)
);

CREATE TABLE data_quality_issue (
  issue_id INT PRIMARY KEY,
  load_id INT NOT NULL,
  source_table VARCHAR(40) NOT NULL,
  affected_record_id INT NULL,
  issue_type VARCHAR(15) NOT NULL,
  issue_description VARCHAR(200) NOT NULL,
  issue_status VARCHAR(10) NOT NULL,
  detected_ts DATETIME NOT NULL,
  FOREIGN KEY (load_id) REFERENCES data_load_log(load_id),
  CHECK (issue_type IN ('Missing','Duplicate','Invalid','Inconsistent')),
  CHECK (issue_status IN ('Pending','Resolved'))
);

DELIMITER $$
CREATE TRIGGER check_assignment
BEFORE INSERT ON vehicle_assignment
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT * FROM vehicle_assignment
             WHERE driver_id = NEW.driver_id
             AND (end_ts IS NULL OR end_ts > NEW.start_ts)
             AND (NEW.end_ts IS NULL OR start_ts < NEW.end_ts)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This driver already has an assignment at this time';
  END IF;

  IF NEW.assignment_type = 'Regular' AND EXISTS (
             SELECT * FROM vehicle_assignment
             WHERE vehicle_id = NEW.vehicle_id
             AND shift_type = NEW.shift_type
             AND assignment_type = 'Regular'
             AND (end_ts IS NULL OR end_ts > NEW.start_ts)
             AND (NEW.end_ts IS NULL OR start_ts < NEW.end_ts)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This taxi already has a regular driver for this shift';
  END IF;

  IF NEW.assignment_type = 'Relief' AND NOT EXISTS (
             SELECT * FROM vehicle_assignment va
             JOIN driver_absence da ON da.driver_id = va.driver_id
             WHERE va.vehicle_id = NEW.vehicle_id
             AND va.shift_type = NEW.shift_type
             AND va.assignment_type = 'Regular'
             AND da.absence_status = 'Approved'
             AND DATE(NEW.start_ts) BETWEEN da.start_date AND da.end_date) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Relief cover needs an approved absence';
  END IF;
END$$
DELIMITER ;

SHOW TABLES;
