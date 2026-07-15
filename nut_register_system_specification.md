# Electronic Integrated Nutrition Register (e-HMIS NUT 001)
## System Requirements & Implementation Specification

Source document: **HMIS NUT 001 Integrated Nutrition Register**, Ministry of Health (Print Version May 2023).
Prototype delivered: `nut_register_system.html` (working web application) and `nut_register_database_schema.sql` (relational schema).

This system reuses the architecture and lessons already validated on the sister e-HMIS NCD 007 build:
persistent storage that works both inside the Claude artifact runtime **and** as a standalone downloaded
file (automatic localStorage fallback with visible error banners instead of silent failure), fully working
list pickers (built with real DOM event listeners, not string-interpolated `onclick`), a sign-in flow that
never leaks a previous user's unsaved draft, facility-wide shared records regardless of who is signed in,
and a reporting module that covers every register column, not just a couple of headline charts.

---

## 1. Scope & Field Preservation

Every column on the paper register (1–28) is preserved as a mandatory data element, tagged **MoH** in the
prototype UI. No field is renamed or removed. Digital-only additions (duplicate/relapse detection, search,
filters, dashboards, reports, role permissions, audit trail) are clearly separated from the official register
fields and never substitute for them.

| Register Column | System Module |
|---|---|
| 1 Date | Enrollment date |
| 2 Serial No. | Monthly serial number (restarts at 001 each month, format NNN/MM/YYYY) |
| 3 INR No. | Integrated Nutrition Register Number — assigned once per client per financial year; relapse episodes append `-2`, `-3`, etc. |
| 4 NIN | National ID |
| 5–9 Name, Age, Sex, Category, Address | Client Identification |
| 10 Next of Kin | Next-of-kin module (name, phone, relationship) |
| 11–12 Infant Feeding / Pregnancy-Lactating Status | Care-context module |
| 13 Entry Care Point | Referral-source module |
| 14 Assessment Method | Assessment module (MUAC / W-H / W-A / BMI-for-age / BMI / Oedema) |
| 15 Nutrition Status at Enrolment | MAM / SAM (with oedema grade) |
| 16 Type of Admission | New / Re-admission-Relapse / Re-admission-Defaulter / Transfer-In |
| 17–18 Type of Nutrition Management, Nutrition Counselling | NC / SFC / OTC / ITC + counselling tick |
| 19 TB Status | TB screening & unit number |
| 20 Disability / Other Comorbidities | Nutrition-impacting and other disability codes |
| 21–22 HIV Status, ART Services | HIV/ART module |
| 23 Medical Complications at Enrolment | Free text |
| 24 Enrolment & Re-Visits | Repeatable visit log (unlimited visits, not capped at 12 — a digital advantage over the paper form) |
| 25–26 Assessment at Exit, Target Exit Criteria | Exit assessment |
| 27 Exit Outcome & Date | Outcome module |
| 28 Transfer Out | Transfer-out flag |

---

## 2. Functional Requirements

**FR-1 Registration** — Capture identification, next-of-kin, and the four-tier address (District/City,
Sub-county/Division, Parish/Ward, Village/Cell) exactly as the register requires.

**FR-2 Serial Number vs INR Number (two distinct identifiers, both preserved)**
- *Serial Number* increments per registration event, restarting at 001 on the first clinic day of each
  month, written as `NNN/MM/YYYY`. The system suggests the next serial number for the current month but
  allows override.
- *INR Number* belongs to the **client**, not the visit: it is assigned once per financial year and re-used
  on every subsequent record for that same client (transfers, relapses append a postfix). The system runs a
  live duplicate-client check (name + NIN/phone match) while a new enrolment is being captured and offers to
  re-use the existing INR Number — with a one-click "relapse" option that appends the correct `-2`/`-3`
  postfix — rather than silently allowing a second INR Number to be issued to the same person.

**FR-3 Automatic calculation** — Restricted to the reference ranges the register itself publishes:
adult BMI classification (Normal/Moderately Malnourished/Severely Malnourished/Overweight/Obese), and
classification of a Z-score the user enters (W/H, W/A, BMI-for-age) against the register's published SD
cut-offs. The register does not publish the underlying WHO growth-curve lookup tables needed to compute a
Z-score from raw height/weight/age, so — consistent with the sister NCD system's rule against inventing
thresholds that aren't published — the system does **not** attempt to compute Z-scores itself; it classifies
whatever Z-score value the user enters from their MUAC tape/growth chart/software of record.

**FR-4 Visit log** — Each visit records: visit date/appointment date, oedema grade, weight (kg), height/length
(cm), MUAC colour code, appetite test result, therapeutic/supplementary feed given, and counselling code —
exactly the fields the paper form's Column 24 grid captures per visit, just presented as an add-as-you-go
list instead of 12 fixed columns.

**FR-5 Exit & outcome** — Exit oedema/weight/height/MUAC, target exit criteria (MUAC ≥ 12.5 cm **and**
W/H Z-score ≥ −2SD **and** no oedema, per the register's own published target), exit outcome code, exit date,
auto-computed total patient days (exit date − enrolment date), and transfer-out flag.

**FR-6 Search** — By name, NIN, INR number, serial number, village, district, and nutrition status.

**FR-7 Filters** — By facility, date, nutrition status (MAM/SAM/SAM+oedema), type of admission, exit outcome,
HIV status, TB status.

**FR-8 Reporting** — A report can be generated for **every** register category (not just age/sex): admissions
by type, nutrition status distribution, entry care point, assessment method used, nutrition management type,
TB/HIV/disability breakdowns, visit/appetite-test compliance, and exit outcomes — each filterable by
daily/weekly/monthly/quarterly/annual period (the period selector genuinely filters the underlying records,
not just labels a static chart).

**FR-9 Export** — PDF, Excel, CSV, and a print-friendly register view replicating the paper layout.

**FR-10 Role-based access** — Five roles with per-module permissions (see §4).

---

## 3. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Availability | 99.5% uptime target for facility-level deployment; offline-first mode for intermittent connectivity |
| Performance | Client search returns in <1s for facilities with up to 50,000 records |
| Security | TLS in transit, AES-256 at rest, role-based access control, session timeout (15 min idle), password complexity + rotation policy |
| Auditability | Every create/edit/delete/export logged with user, timestamp, before/after values |
| Data quality | Mandatory-field validation, numeric range checks, duplicate-client detection (name + NIN/phone fuzzy match) tied to INR Number issuance, date validation, phone format validation |
| Accessibility | WCAG 2.1 AA — keyboard navigable forms, visible focus states, colour is never the only signal (paired with text labels) |
| Storage resilience | Works inside the Claude artifact runtime (persistent `window.storage`) **and** as a standalone downloaded file (automatic same-browser `localStorage` fallback), with visible save-failure banners instead of silent data loss |
| Localisation | English by default; architecture supports additional local languages |
| Interoperability | DHIS2, OpenMRS, FHIR/HL7, national EMR, and the e-HMIS NCD 007 system via the API layer (§6) — a client flagged malnourished here can be cross-referenced by NIN/phone against the NCD register |
| Offline capability | Local encrypted cache with queued sync on reconnect; conflict resolution by last-write-wins with audit trail retained |

---

## 4. User Roles & Permissions Matrix

| Role | Register | View Clients | Edit Clinical/Visit Data | Enrol/Discharge | Reports | User Mgmt | Delete |
|---|---|---|---|---|---|---|---|
| Administrator | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Facility Nutrition Officer | ✔ | ✔ | ✔ | ✔ | ✔ | — | — |
| Nurse / Data Clerk | ✔ | ✔ | ✔ (visit fields) | — | view-only | — | — |
| District Officer | — | ✔ (aggregate) | — | — | ✔ | — | — |
| Read-only User | — | ✔ | — | — | view-only | — | — |

---

## 5. Database Design

See `nut_register_database_schema.sql` for the complete, normalised, SQL-ready schema (3NF), including:
- `clients` (one row per client, holds the INR Number — never duplicated per client per facility per year)
  + `enrolments` (supports transfers/relapses as new rows against the same client)
- `visits` (one row per visit/re-visit, unlimited per enrolment)
- `exits`, `next_of_kin`, `disabilities`, `client_disabilities` (many-to-many)
- `users`, `roles`, `audit_log`
- Lookup tables for all Ministry-defined codes (infant feeding, entry care point, assessment method,
  nutrition status, admission type, TB status, HIV status, exit outcome, disability codes, counselling codes)
- Uniqueness constraint on serial number per facility per month, and on INR Number per client per facility
  per financial year (relapse episodes are new rows referencing the same client with a postfixed INR Number)

---

## 6. API Specification (representative endpoints)

```
POST   /api/v1/auth/login
POST   /api/v1/clients                       Create client + enrolment
GET    /api/v1/clients?search=&filters=      Search/filter clients
GET    /api/v1/clients/{id}                  Full record
PUT    /api/v1/clients/{id}                  Update
POST   /api/v1/enrolments/{id}/visits        Add a visit
PUT    /api/v1/enrolments/{id}/exit          Record exit assessment/outcome
GET    /api/v1/reports/{period}/{category}   daily|weekly|monthly|quarterly|annual
GET    /api/v1/export/{format}               csv|xlsx|pdf
GET    /api/v1/dhis2/sync                    Push aggregate indicators to DHIS2
```
Authentication: OAuth2/JWT bearer tokens. All endpoints enforce the role/permission matrix server-side.

---

## 7. What's in the Prototype vs. Production-Ready

The delivered `nut_register_system.html` is a **functional prototype** demonstrating the full data model,
all register fields, and every auto-calculation the register's own instructions define. It runs entirely
client-side with persisted storage (Claude artifact storage when available, transparently falling back to
same-browser storage otherwise). Moving to production requires: the backend/API layer above, real
authentication and RBAC enforcement, DHIS2/FHIR connectors, offline sync, and a security review before
handling real patient data.
