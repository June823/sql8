-- =====================================================================
-- Project: Clinic Booking System (MySQL)
-- Author: <your name>
-- File: clinic_booking.sql
-- Description:
--   Complete relational schema for a small clinic booking system.
--   Demonstrates PK, FK, UNIQUE, NOT NULL, CHECK constraints
--   and relationships: 1-1, 1-M, and M-M.
-- =====================================================================

-- Safety: re-create database cleanly (optional if your class forbids)
DROP DATABASE IF EXISTS clinic_booking_db;
CREATE DATABASE clinic_booking_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE clinic_booking_db;

-- ======================================================
-- Reference tables
-- ======================================================

-- Doctors employed by the clinic
CREATE TABLE doctors (
  doctor_id      INT AUTO_INCREMENT PRIMARY KEY,
  first_name     VARCHAR(50)      NOT NULL,
  last_name      VARCHAR(50)      NOT NULL,
  email          VARCHAR(100)     NOT NULL UNIQUE,
  phone          VARCHAR(25)      NOT NULL UNIQUE,
  license_no     VARCHAR(50)      NOT NULL UNIQUE,
  hire_date      DATE             NOT NULL,
  active         TINYINT(1)       NOT NULL DEFAULT 1,
  created_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Medical specialties (e.g., Cardiology, Dermatology)
CREATE TABLE specialties (
  specialty_id   INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(100)     NOT NULL UNIQUE,
  description    VARCHAR(255)
) ENGINE=InnoDB;

-- M-M: a doctor can have multiple specialties; a specialty can have multiple doctors
CREATE TABLE doctor_specialty (
  doctor_id     INT NOT NULL,
  specialty_id  INT NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  CONSTRAINT fk_ds_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ds_specialty
    FOREIGN KEY (specialty_id) REFERENCES specialties(specialty_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Patients
CREATE TABLE patients (
  patient_id     INT AUTO_INCREMENT PRIMARY KEY,
  first_name     VARCHAR(50)      NOT NULL,
  last_name      VARCHAR(50)      NOT NULL,
  date_of_birth  DATE             NOT NULL,
  sex            ENUM('F','M','X') NOT NULL,
  email          VARCHAR(100)     UNIQUE,
  phone          VARCHAR(25)      NOT NULL UNIQUE,
  national_id    VARCHAR(50)      UNIQUE,
  created_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Clinic rooms
CREATE TABLE rooms (
  room_id        INT AUTO_INCREMENT PRIMARY KEY,
  room_number    VARCHAR(20)      NOT NULL UNIQUE,
  room_type      ENUM('Consultation','Lab','Surgery','Other') NOT NULL,
  status         ENUM('Available','Unavailable') NOT NULL DEFAULT 'Available'
) ENGINE=InnoDB;

-- ======================================================
-- Core workflow tables
-- ======================================================

-- Appointments between patients and doctors
CREATE TABLE appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id     INT             NOT NULL,
  doctor_id      INT             NOT NULL,
  room_id        INT,
  start_time     DATETIME        NOT NULL,
  end_time       DATETIME        NOT NULL,
  status         ENUM('Scheduled','CheckedIn','Completed','Cancelled','NoShow')
                  NOT NULL DEFAULT 'Scheduled',
  reason         VARCHAR(255),

  -- Prevent exact duplicate slot for a doctor; full overlap checks are app logic
  UNIQUE KEY uq_doctor_start (doctor_id, start_time),

  CONSTRAINT fk_appt_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_appt_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_appt_room
    FOREIGN KEY (room_id) REFERENCES rooms(room_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  -- Basic time sanity
  CONSTRAINT chk_time_valid CHECK (end_time > start_time)
) ENGINE=InnoDB;

-- 1-1: Each appointment can have at most one prescription (and one prescription belongs to exactly one appointment)
CREATE TABLE prescriptions (
  prescription_id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id  INT NOT NULL UNIQUE,
  notes           VARCHAR(500),

  CONSTRAINT fk_rx_appt
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Medications catalog
CREATE TABLE medications (
  medication_id  INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(120)     NOT NULL UNIQUE,
  unit           VARCHAR(20)      NOT NULL            -- e.g., mg, ml, tabs
) ENGINE=InnoDB;

-- Items within a prescription (M-M between prescriptions and medications)
CREATE TABLE prescription_items (
  prescription_id INT NOT NULL,
  medication_id   INT NOT NULL,
  dosage          VARCHAR(50) NOT NULL,               -- e.g., "500mg"
  quantity        INT         NOT NULL,
  instructions    VARCHAR(255),
  PRIMARY KEY (prescription_id, medication_id),
  CONSTRAINT chk_qty_pos CHECK (quantity > 0),
  CONSTRAINT fk_pxi_rx
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pxi_med
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Billing: one invoice per appointment (1-1)
CREATE TABLE invoices (
  invoice_id     INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL UNIQUE,
  amount_due     DECIMAL(10,2) NOT NULL,
  amount_paid    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status         ENUM('Unpaid','PartiallyPaid','Paid','Voided') NOT NULL DEFAULT 'Unpaid',
  issued_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT chk_amounts_nonneg CHECK (amount_due >= 0 AND amount_paid >= 0),

  CONSTRAINT fk_inv_appt
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Payments (1-M from invoices to payments)
CREATE TABLE payments (
  payment_id   INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id   INT NOT NULL,
  amount       DECIMAL(10,2) NOT NULL,
  paid_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  method       ENUM('Cash','Card','MobileMoney','Insurance') NOT NULL,

  CONSTRAINT chk_payment_pos CHECK (amount > 0),
  CONSTRAINT fk_pay_invoice
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Helpful indexes for common lookups
CREATE INDEX ix_patients_name      ON patients(last_name, first_name);
CREATE INDEX ix_doctors_name       ON doctors(last_name, first_name);
CREATE INDEX ix_appt_patient_time  ON appointments(patient_id, start_time);
CREATE INDEX ix_appt_doctor_time   ON appointments(doctor_id, start_time);
CREATE INDEX ix_payments_invoice   ON payments(invoice_id);

-- =====================================================================
-- (Optional) seed lookups to make ERD screenshots prettier in Workbench
-- Uncomment if you want a tiny bit of data for visuals.
-- INSERT INTO specialties(name) VALUES ('General Practice'), ('Dermatology'), ('Pediatrics');
-- INSERT INTO rooms(room_number, room_type) VALUES ('101','Consultation'), ('201','Lab');
-- =====================================================================

-- Done.
