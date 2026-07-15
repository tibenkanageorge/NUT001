-- ============================================================================
-- e-HMIS NUT 001: INTEGRATED NUTRITION REGISTER — DATABASE SCHEMA
-- Ministry of Health | Normalised (3NF) PostgreSQL-flavoured schema
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS nut;

-- ---------------------------------------------------------------------------
-- FACILITIES / USERS / ROLES
-- ---------------------------------------------------------------------------
CREATE TABLE nut.facilities (
    facility_id     BIGSERIAL PRIMARY KEY,
    name            VARCHAR(160) NOT NULL,
    code            VARCHAR(40) UNIQUE,
    level           VARCHAR(20),
    subcounty       VARCHAR(120),
    district        VARCHAR(120),
    hsd             VARCHAR(120)
);

CREATE TABLE nut.roles (
    role_id         SERIAL PRIMARY KEY,
    role_name       VARCHAR(60) UNIQUE NOT NULL   -- Administrator, Facility Nutrition Officer,
                                                    -- Nurse/Data Clerk, District Officer, Read-only User
);

CREATE TABLE nut.users (
    user_id         BIGSERIAL PRIMARY KEY,
    facility_id     BIGINT REFERENCES nut.facilities(facility_id),
    username        VARCHAR(80) UNIQUE NOT NULL,
    full_name       VARCHAR(160) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    role_id         INT REFERENCES nut.roles(role_id),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- LOOKUP / CODE TABLES (all Ministry-defined codes from the register)
-- ---------------------------------------------------------------------------
CREATE TABLE nut.lu_infant_feeding   (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_infant_feeding VALUES ('EBF','Exclusive Breast Feeding'),('RF','Replacement Feeding'),
    ('MF','Mixed Feeding'),('CF','Complementary Feeding'),('NLB','No Longer Breastfeeding'),('NA','Not Applicable');

CREATE TABLE nut.lu_preg_lact_status (code VARCHAR(6) PRIMARY KEY, label VARCHAR(40));
INSERT INTO nut.lu_preg_lact_status VALUES ('Preg','Pregnant'),('Lact','Lactating'),
    ('NLact','Non-lactating, child <6 months'),('NA','Not Applicable');

CREATE TABLE nut.lu_entry_point (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_entry_point VALUES ('YCC','Young Child Clinic'),('ANC','Antenatal Clinic'),
    ('MC','Maternity Clinic'),('PNC','Postnatal Clinic'),('ART','Antiretroviral Treatment Clinic'),
    ('OPD','Out Patient Department / General Outpatient Clinic'),('IPD','Inpatient Therapeutic'),
    ('TB','TB Clinic'),('CHW','Referral by Community Health Worker'),('SR','Self Referral');

CREATE TABLE nut.lu_assessment_method (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_assessment_method VALUES ('M','MUAC Tape'),('WH','Weight for Height/Length Z-score'),
    ('WA','Weight for Age Z-score'),('BA','BMI for Age Z-score'),('BMI','Body Mass Index'),
    ('O','Bilateral Pitting Oedema');

CREATE TABLE nut.lu_nutrition_status (code VARCHAR(10) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_nutrition_status VALUES ('MAM','Moderate Acute Malnutrition'),
    ('SAM','Severe Acute Malnutrition, no oedema'),('SAM_O','Severe Acute Malnutrition with oedema');

CREATE TABLE nut.lu_admission_type (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_admission_type VALUES ('N','New Admission'),('R-R','Re-admission-Relapse'),
    ('R-D','Readmission-Defaulter'),('TI','Transfer In');

CREATE TABLE nut.lu_tb_status (code VARCHAR(4) PRIMARY KEY, label VARCHAR(80));
INSERT INTO nut.lu_tb_status VALUES ('1','No signs/symptoms of TB'),('2','Presumptive — referred for test/sputum sent'),
    ('3G','TB Diagnosed — GeneXpert'),('3M','TB Diagnosed — Microscopy'),('3L','TB Diagnosed — LAM'),
    ('3X','TB Diagnosed — X-ray'),('3O','TB Diagnosed — Other method'),
    ('4','TB NRx — diagnosed, not yet on treatment'),('5','TB Rx — currently on TB treatment'),
    ('6','TB CPTD — TB treatment successfully completed');

CREATE TABLE nut.lu_hiv_status (code VARCHAR(10) PRIMARY KEY, label VARCHAR(40));
INSERT INTO nut.lu_hiv_status VALUES ('Pos','HIV Positive'),('Neg','HIV Negative'),
    ('Unknown','Status Not Known'),('Exposed','HIV-Exposed Child');

CREATE TABLE nut.lu_art_status (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_art_status VALUES ('ART','On ART (incl. eMTCT for pregnant women)'),
    ('NA','Not Yet Enrolled / HIV-negative');

CREATE TABLE nut.lu_disability_nutrition (code VARCHAR(4) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_disability_nutrition VALUES ('1','Cleft Lip and Palate'),('2','Cerebral Palsy'),
    ('3','Down Syndrome'),('4','Epilepsy'),('5','Autism Spectrum Disorder'),('6','Hydrocephalus');

CREATE TABLE nut.lu_disability_other (code VARCHAR(4) PRIMARY KEY, label VARCHAR(80));
INSERT INTO nut.lu_disability_other VALUES
    ('A','Difficulty in seeing'),('B','Albinism'),('C','Difficulty in hearing'),
    ('D','Delayed age motor development'),('E','Difficulty in walking'),('F','Difficulty in understanding'),
    ('G','Difficulty in remembering'),('H','Difficulty in reading'),('I','Difficulty in writing'),
    ('J','Difficulty washing all over or dressing'),('K','Mentally impaired'),('L','Emotionally impaired');

CREATE TABLE nut.lu_appetite_test (code VARCHAR(4) PRIMARY KEY, label VARCHAR(40));
INSERT INTO nut.lu_appetite_test VALUES ('Y','Passed'),('N','Did Not Pass'),('ND','Not Done');

CREATE TABLE nut.lu_counselling_code (code VARCHAR(4) PRIMARY KEY, label VARCHAR(100));
INSERT INTO nut.lu_counselling_code VALUES
    ('1','Optimal dietary practices for adults, incl. pregnant/lactating women'),
    ('2','Use of Therapeutic Foods'),('3','Infant and Young Child Feeding (IYCF)'),
    ('4','Water, Hygiene and Sanitation (WASH)'),('5','ARV adherence'),('6','Others');

CREATE TABLE nut.lu_linkage_service (code VARCHAR(4) PRIMARY KEY, label VARCHAR(80));
INSERT INTO nut.lu_linkage_service VALUES ('1','Linked to livelihood support program'),
    ('2','Linked to social protection services (child and family protection)'),
    ('3','Linked to care group'),('4','Others (specify)');

CREATE TABLE nut.lu_exit_outcome (code VARCHAR(6) PRIMARY KEY, label VARCHAR(60));
INSERT INTO nut.lu_exit_outcome VALUES ('SC','Successfully Treated'),('C','Cured'),
    ('NR','Non-Response'),('DF-C','Defaulter — Confirmed'),('DF-U','Defaulter — Unconfirmed'),
    ('D','Died / Dead');

-- ---------------------------------------------------------------------------
-- CLIENT (the identity that owns an INR Number) + ENROLMENT (per episode/visit-set)
-- ---------------------------------------------------------------------------
CREATE TABLE nut.clients (
    client_id       BIGSERIAL PRIMARY KEY,
    facility_id     BIGINT NOT NULL REFERENCES nut.facilities(facility_id),
    nin             VARCHAR(20),
    surname         VARCHAR(80) NOT NULL,
    given_name      VARCHAR(80) NOT NULL,
    sex             CHAR(1) CHECK (sex IN ('M','F')) NOT NULL,
    category        CHAR(1) CHECK (category IN ('N','R','F')) NOT NULL,   -- National / Refugee / Foreigner
    phone           VARCHAR(20),
    district        VARCHAR(120), subcounty VARCHAR(120), parish VARCHAR(120), village VARCHAR(120),
    -- name+NIN/phone fuzzy match is used at the application layer to prevent a client being issued
    -- a second, duplicate INR Number; this table holds ONE row per real-world client.
    created_at      TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_clients_name ON nut.clients (facility_id, surname, given_name);
CREATE INDEX idx_clients_phone ON nut.clients (facility_id, phone);
CREATE INDEX idx_clients_nin ON nut.clients (nin);

CREATE TABLE nut.next_of_kin (
    id              BIGSERIAL PRIMARY KEY,
    client_id       BIGINT REFERENCES nut.clients(client_id) ON DELETE CASCADE,
    surname         VARCHAR(80), given_name VARCHAR(80), phone VARCHAR(20), relationship VARCHAR(40)
);

CREATE TABLE nut.client_disabilities (
    client_id       BIGINT REFERENCES nut.clients(client_id) ON DELETE CASCADE,
    disability_code VARCHAR(4) NOT NULL,          -- references lu_disability_nutrition OR lu_disability_other
    disability_type VARCHAR(12) NOT NULL CHECK (disability_type IN ('nutrition','other')),
    PRIMARY KEY (client_id, disability_code, disability_type)
);

-- An enrolment = one episode of care under one INR Number (new admission, relapse, transfer-in, etc.)
CREATE TABLE nut.enrolments (
    enrolment_id    BIGSERIAL PRIMARY KEY,
    client_id       BIGINT NOT NULL REFERENCES nut.clients(client_id),
    facility_id     BIGINT NOT NULL REFERENCES nut.facilities(facility_id),
    enrol_date      DATE NOT NULL,
    serial_no       VARCHAR(20) NOT NULL,          -- NNN/MM/YYYY, restarts at 001 each month
    inr_no          VARCHAR(60) NOT NULL,           -- Facility/ClientNo/Year/Type, postfixed -2/-3 for relapse
    age_value       NUMERIC(5,1) NOT NULL,
    age_unit        VARCHAR(6) CHECK (age_unit IN ('months','years')) NOT NULL,
    infant_feeding_code   VARCHAR(6) REFERENCES nut.lu_infant_feeding(code),
    preg_lact_status_code VARCHAR(6) REFERENCES nut.lu_preg_lact_status(code),
    entry_point_code      VARCHAR(6) REFERENCES nut.lu_entry_point(code),
    assessment_method_code VARCHAR(6) REFERENCES nut.lu_assessment_method(code),
    nutrition_status_code  VARCHAR(10) REFERENCES nut.lu_nutrition_status(code),
    oedema_grade    VARCHAR(4),                     -- +, ++, +++ (only when SAM_O)
    admission_type_code VARCHAR(6) REFERENCES nut.lu_admission_type(code),
    mgmt_nc BOOLEAN DEFAULT FALSE, mgmt_sfc BOOLEAN DEFAULT FALSE,
    mgmt_otc BOOLEAN DEFAULT FALSE, mgmt_itc BOOLEAN DEFAULT FALSE,
    nutrition_counselling_given BOOLEAN DEFAULT FALSE,
    tb_status_code  VARCHAR(4) REFERENCES nut.lu_tb_status(code),
    tb_unit_no      VARCHAR(40),
    hiv_status_code VARCHAR(10) REFERENCES nut.lu_hiv_status(code),
    art_status_code VARCHAR(6) REFERENCES nut.lu_art_status(code),
    medical_complications TEXT,
    created_by      BIGINT REFERENCES nut.users(user_id),
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);
-- Serial number is unique per facility per month (matches the register's own numbering rule)
CREATE UNIQUE INDEX uq_enrolment_serial_month
    ON nut.enrolments (facility_id, serial_no, date_trunc('month', enrol_date));
-- INR Number is unique per facility (relapse episodes get their own postfixed INR Number, e.g. xxxx-2)
CREATE UNIQUE INDEX uq_enrolment_inr ON nut.enrolments (facility_id, inr_no);

CREATE INDEX idx_enrolments_client ON nut.enrolments (client_id);
CREATE INDEX idx_enrolments_facility_date ON nut.enrolments (facility_id, enrol_date);

-- ---------------------------------------------------------------------------
-- VISITS (Column 24 — one row per visit, unlimited, unlike the paper's fixed 12 columns)
-- ---------------------------------------------------------------------------
CREATE TABLE nut.visits (
    visit_id        BIGSERIAL PRIMARY KEY,
    enrolment_id    BIGINT NOT NULL REFERENCES nut.enrolments(enrolment_id) ON DELETE CASCADE,
    visit_no        INT NOT NULL,
    visit_date      DATE NOT NULL,
    next_appointment_date DATE,
    oedema_grade    VARCHAR(4),                     -- '', +, ++, +++
    weight_kg       NUMERIC(5,2),
    height_cm       NUMERIC(5,2),
    muac_color      VARCHAR(4),                      -- G, R, Y, ND
    whz_score       NUMERIC(4,2), whz_code VARCHAR(4),   -- SAM / MAM / N / ND
    waz_score       NUMERIC(4,2), waz_code VARCHAR(4),   -- SU / U / N / ND (infants <6mo)
    baz_score       NUMERIC(4,2), baz_code VARCHAR(4),   -- N / MM / SM / OW / O / ND (5-19y BMI-for-age)
    bmi_value       NUMERIC(5,2), bmi_code VARCHAR(4),   -- N / MM / SM / OW / O (adults, auto-classified)
    appetite_test_code VARCHAR(4) REFERENCES nut.lu_appetite_test(code),
    feeds_given     VARCHAR(120),                     -- RUTF, F75, F100, ReSoMal, RUSF, CSB++, FBF, NC...
    counselling_code VARCHAR(4) REFERENCES nut.lu_counselling_code(code),
    UNIQUE(enrolment_id, visit_no)
);

CREATE TABLE nut.enrolment_linkage_services (
    enrolment_id    BIGINT REFERENCES nut.enrolments(enrolment_id) ON DELETE CASCADE,
    service_code    VARCHAR(4) REFERENCES nut.lu_linkage_service(code),
    specify         VARCHAR(120),
    PRIMARY KEY (enrolment_id, service_code)
);

-- ---------------------------------------------------------------------------
-- EXIT (Columns 25–28)
-- ---------------------------------------------------------------------------
CREATE TABLE nut.exits (
    enrolment_id    BIGINT PRIMARY KEY REFERENCES nut.enrolments(enrolment_id) ON DELETE CASCADE,
    exit_oedema_grade VARCHAR(4),
    exit_weight_kg  NUMERIC(5,2),
    exit_height_cm  NUMERIC(5,2),
    exit_muac_color VARCHAR(4),
    target_exit_muac_met BOOLEAN,     -- MUAC >= 12.5 cm (published register target)
    target_exit_whz_met  BOOLEAN,     -- W/H Z-score >= -2SD (published register target)
    target_exit_no_oedema BOOLEAN,
    exit_outcome_code VARCHAR(6) REFERENCES nut.lu_exit_outcome(code),
    exit_date       DATE,
    total_patient_days INT,           -- auto-computed: exit_date - enrol_date
    transfer_out    BOOLEAN DEFAULT FALSE
);

-- ---------------------------------------------------------------------------
-- AUDIT LOG
-- ---------------------------------------------------------------------------
CREATE TABLE nut.audit_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES nut.users(user_id),
    facility_id     BIGINT REFERENCES nut.facilities(facility_id),
    action          VARCHAR(20) CHECK (action IN ('CREATE','UPDATE','DELETE','EXPORT','LOGIN','LOGOUT')),
    entity          VARCHAR(60),
    entity_id       BIGINT,
    before_value    JSONB,
    after_value     JSONB,
    at_time         TIMESTAMPTZ DEFAULT now()
);
