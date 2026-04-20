CREATE EXTENSION IF NOT EXISTS btree_gist;

DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS permanent_schedule_changes CASCADE;
DROP TABLE IF EXISTS temporary_schedule_changes CASCADE;
DROP TABLE IF EXISTS doctor_weekly_schedule CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS doctors CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS appointment_status CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

CREATE TYPE user_role AS ENUM ('doctor', 'patient');
CREATE TYPE appointment_status AS ENUM ('scheduled', 'cancelled', 'completed');

-- 1. Потребители
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Лекари
CREATE TABLE doctors (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL
);

-- 3. Пациенти
CREATE TABLE patients (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE RESTRICT
);

-- 4. Базов седмичен график
CREATE TABLE doctor_weekly_schedule (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME,
    end_time TIME,
    break_start TIME,
    break_end TIME,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT chk_working_hours_valid CHECK (
        (start_time IS NULL AND end_time IS NULL AND break_start IS NULL AND break_end IS NULL)
            OR
        (start_time IS NOT NULL AND end_time IS NOT NULL AND start_time < end_time)
        ),

    CONSTRAINT chk_break_valid CHECK (
        (break_start IS NULL AND break_end IS NULL)
            OR
        (
            start_time IS NOT NULL
                AND end_time IS NOT NULL
                AND break_start IS NOT NULL
                AND break_end IS NOT NULL
                AND break_start < break_end
                AND break_start >= start_time
                AND break_end <= end_time
            )
        ),

    CONSTRAINT uq_doctor_weekday_validfrom UNIQUE (doctor_id, weekday, valid_from)
);

-- 5. Временни промени
CREATE TABLE temporary_schedule_changes (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_day_off BOOLEAN NOT NULL DEFAULT FALSE,
    new_start_time TIME,
    new_end_time TIME,
    break_start TIME,
    break_end TIME,

    CONSTRAINT chk_temp_range CHECK (starts_at < ends_at),

    CONSTRAINT chk_temp_day_off_logic CHECK (
        (is_day_off = TRUE AND new_start_time IS NULL AND new_end_time IS NULL AND break_start IS NULL AND break_end IS NULL)
            OR
        (is_day_off = FALSE AND new_start_time IS NOT NULL AND new_end_time IS NOT NULL AND new_start_time < new_end_time)
        ),

    CONSTRAINT chk_temp_break_valid CHECK (
        (break_start IS NULL AND break_end IS NULL)
            OR
        (
            new_start_time IS NOT NULL
                AND new_end_time IS NOT NULL
                AND break_start IS NOT NULL
                AND break_end IS NOT NULL
                AND break_start < break_end
                AND break_start >= new_start_time
                AND break_end <= new_end_time
            )
        )
);

-- Забрана за застъпващи се временни промени за един и същи лекар
ALTER TABLE temporary_schedule_changes
    ADD CONSTRAINT no_overlapping_temp_changes
    EXCLUDE USING gist (
    doctor_id WITH =,
    tstzrange(starts_at, ends_at, '[)') WITH &&
);

-- 6. Постоянни промени
CREATE TABLE permanent_schedule_changes (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    effective_from DATE NOT NULL,
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME,
    end_time TIME,
    break_start TIME,
    break_end TIME,

    CONSTRAINT chk_perm_working_hours_valid CHECK (
        (start_time IS NULL AND end_time IS NULL AND break_start IS NULL AND break_end IS NULL)
            OR
        (start_time IS NOT NULL AND end_time IS NOT NULL AND start_time < end_time)
        ),

    CONSTRAINT chk_perm_break_valid CHECK (
        (break_start IS NULL AND break_end IS NULL)
            OR
        (
            start_time IS NOT NULL
                AND end_time IS NOT NULL
                AND break_start IS NOT NULL
                AND break_end IS NOT NULL
                AND break_start < break_end
                AND break_start >= start_time
                AND break_end <= end_time
            )
        ),

    CONSTRAINT uq_perm_change UNIQUE (doctor_id, weekday, effective_from)
);

-- 7. Посещения
CREATE TABLE appointments (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    start_at TIMESTAMP WITH TIME ZONE NOT NULL,
    end_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status appointment_status NOT NULL DEFAULT 'scheduled',
    cancelled_by INTEGER REFERENCES users(id),
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_app_time CHECK (start_at < end_at)
);

-- Забрана за застъпващи се активни посещения при един и същи лекар
ALTER TABLE appointments
    ADD CONSTRAINT no_overlapping_appointments
    EXCLUDE USING gist (
    doctor_id WITH =,
    tstzrange(start_at, end_at, '[)') WITH &&
)
WHERE (status = 'scheduled');

-- Индекси
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_patients_doctor_id ON patients(doctor_id);
CREATE INDEX idx_weekly_schedule_doctor_weekday ON doctor_weekly_schedule(doctor_id, weekday);
CREATE INDEX idx_temp_changes_doctor_dates ON temporary_schedule_changes(doctor_id, starts_at, ends_at);
CREATE INDEX idx_perm_changes_doctor_effective ON permanent_schedule_changes(doctor_id, effective_from, weekday);
CREATE INDEX idx_appointments_doctor_start ON appointments(doctor_id, start_at);
CREATE INDEX idx_appointments_patient_start ON appointments(patient_id, start_at);