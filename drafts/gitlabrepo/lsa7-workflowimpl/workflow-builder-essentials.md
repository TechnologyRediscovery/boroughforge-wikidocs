# Workflow Builder Essentials

This guide is for municipal clerks, code officers, and program staff who need to understand the workflow builder without thinking like a programmer.

A **workflow** is CodeNForce's way of remembering a municipal process from beginning to end. It keeps track of what has happened, what still needs to happen, what object proves a step is complete, and when the system should bring a property back to an officer's attention.

Think of a workflow as a smart checklist attached to a property. It can wait for people, inspections, payments, certificates, letters, forms, and deadlines. It does not replace officer judgment. It helps the officer see the right next action and keeps the history tied together.

---

---

## The Big Picture

A workflow answers four everyday questions:

1. **What process is this property in?**
   Example: Rental Registration, Deed Transfer, Vacant Property Registration.

2. **What facts or documents are we waiting for?**
   Example: payment received, inspection passed, local manager provided, certificate issued.

3. **What happens next?**
   Example: if the inspection fails, request a reinspection; if it passes, issue a certificate.

4. **When should CNF remind or escalate?**
   Example: if a reinspection is not scheduled within 90 days, mark the workflow stalled.

The workflow builder is the screen where an authorized municipal user defines that process once, so staff can run it consistently for many properties.

---

## Core Object 1: Workflows

A **workflow** is the full procedure.

Examples:

- **Rental Registration and Certification**
- **Deed Transfer / Occupancy Permit Review**

A workflow has a title, a version number, and a domain (parcel-level or unit-level). When a workflow is first created it is a draft. Drafts can be edited freely. After it passes validation it can be published. Once published it may already be running on real properties, so major edits should usually become a new version rather than changing the live copy.

When a workflow is started for a real property, that running copy is called a **workflow instance**. In everyday language, staff can just say: "this property is enrolled in the rental workflow."

### Example: Rental Registration

A property owner converts a house into a two-unit rental and submits an online application. CNF starts a Rental Registration workflow for that property. The workflow might guide staff through:

1. Review the application.
2. Confirm the $75 per-unit registration fee.
3. Request local manager information if the owner lives out of state.
4. Schedule the rental inspection.
5. Record whether the inspection passed or failed.
6. If failed, wait for reinspection.
7. If passed, issue the rental certificate.
8. Later, track tenant registration and future periodic inspections.

### Example: Deed Transfer

A property changes hands. The workflow gives officers a single place to track the process:

1. Confirm transfer or pending sale.
2. Request or record inspection.
3. Record inspection result.
4. If deficiencies exist, track whether the buyer accepts them under an affidavit.
5. Issue a temporary occupancy certificate or access certificate when appropriate.
6. Start a 365-day follow-up window.
7. If final requirements are met, issue the final certificate.
8. If the deadline passes without correction, move toward enforcement.

---

## Core Object 2: Steps

A **step** is one stop in the workflow process. Every workflow is made of steps connected by paths.

Examples of steps in a rental workflow:

- Review application
- Collect registration fee
- Schedule and complete rental inspection
- Issue rental certificate
- Send late notice

Steps do three kinds of work:

- **Waiting** — the step holds the workflow until a required event or object appears.
- **Deciding** — a decision step looks at what is known and routes the workflow down the correct path.
- **Acting** — the step causes something to happen: a certificate is issued, a letter is sent, a case is opened.

Every step has a **step kind** that tells CNF exactly what kind of work it does.

### Step Kinds

The builder supports the following step kinds. Each kind is explained below in plain language with a typical use case.

---

#### START

The first step of every workflow. There is always exactly one START step. The workflow begins here when a new instance is created for a property.

**Example use:** "Begin rental registration when an application is submitted."

---

#### END

A terminal step. When the workflow reaches an END step, the process is complete. A workflow can have more than one END step — for example, one for a successful completion and one for a withdrawal or abandonment.

**Example use:** "Close rental registration after the certificate is issued." Or: "Close the process after the owner withdraws the application."

---

#### GATEWAY_XOR

A decision step. The workflow arrives here, evaluates the outgoing paths, and takes exactly one. It does not wait for an officer to act — it routes automatically based on what the workflow knows from slots and rules.

**Example use:** "If the inspection passed, go to certificate issuance. If it failed, go to reinspection request."

---

#### REVIEW

An officer review step. The workflow pauses here while a staff member reviews information and manually advances the step by recording their decision.

**Example use:** "Review the application and decide whether it is complete. If complete, proceed to fee collection. If incomplete, return to the owner for more information."

---

#### AWAIT

A waiting step with no officer action required. The workflow pauses here and watches for a required object or event to appear in a slot. When the slot is filled correctly, the workflow can move on.

**Example use:** "Wait for the county data import to detect the deed change." Or: "Wait for the buyer to schedule a reinspection."

---

#### INSPECTION

A step specifically for recording an inspection result. The workflow pauses here while an inspection is scheduled and carried out. The outcome — pass or fail — feeds into the transition logic that follows.

**Example use:** "Rental inspection. Pass goes to certificate issuance. Fail goes to correction and reinspection."

---

#### PAYMENT

A step for recording and confirming a fee payment. The workflow pauses here until a payment is received and confirmed. Rules on this step check whether the payment exists and has been verified.

**Example use:** "Collect the $75 per-unit registration fee. Once confirmed, proceed to inspection scheduling."

---

#### GATE

A hold or checkpoint step. The workflow pauses here until a staff member explicitly clears it. GATE steps are useful for compliance holds, management approvals, or legal review stops that must be formally released.

**Example use:** "Management review hold — supervisor must approve release before the certificate is prepared."

---

#### PUBLICFORM

A step that waits for a public-facing form submission to be linked to the workflow. The workflow pauses here until the form is submitted and appears in the designated slot.

**Example use:** "Wait for the tenant registration form to be submitted online." Or: "Wait for the rental application to be submitted through the public portal."

---

#### PERSONLINK

A step that waits for a person record to be linked. The workflow pauses until a specific person — such as a local manager, an authorized agent, or a new property owner — is recorded in a slot.

**Example use:** "Require a local manager person to be linked before proceeding when the owner is out of state."

---

#### LETTER

A step for preparing and sending a formal letter. The workflow can create a letter from a template and record it in a slot. Letters can be informational, regulatory, or enforcement-related.

**Example use:** "Send a late notice to the property owner when they have not scheduled a reinspection within 90 days."

---

#### CERTIFICATE

A step for issuing a certificate. The workflow creates or records an occupancy certificate, rental certificate, or similar document in a designated slot.

**Example use:** "Issue the rental certificate after the inspection passes and the fee is confirmed."

---

#### EVENT

A slot-bound step whose designated object is a CNF event record. Think of it like an INSPECTION step, but for events: the workflow pauses here until a CNF event of the required category has been linked to the step's event slot. The slot holds the event record, and REQUIRE rules on the step check that it is present and of the right type before the workflow can advance.

This is **not** the same as the per-step event emission settings (Emit on Activate / Emit on Complete), which automatically spawn events as a silent side effect when any step starts or finishes. Use an EVENT step when the presence of a specific, confirmed event record is itself a required milestone that must be visible in the workflow graph.

**Example use:** "Require that a 'violation notice delivered' event has been recorded in the `noticedelivered` slot before routing to the enforcement follow-up step."

---

#### ACTION

A general-purpose action step. ACTION steps run a defined system operation that does not fit neatly into the other categories — such as updating a status flag, copying information from one object to another, or running a coordinator method.

**Example use:** "Mark the occupancy period as active once all conditions for the final certificate are met."

---

#### CASESPAWN

A step for opening or linking a code enforcement case. When the workflow reaches a CASESPAWN step, CNF creates a new CE case or links an existing one to the workflow.

**Example use:** "Open an enforcement case if the owner has not responded within the required window." Or: "Open a shadow enforcement case when a deed transfer occurred without a required CNF process."

---

#### EXTERNAL

A step for integrating with an external system. EXTERNAL steps hand off a workflow signal to a third-party service, such as a county records system, a permitting portal, or a state reporting interface.

**Example use:** "Report the completed rental registration to the state housing database."

---

### Object Rules on a Step

Every step can carry **object rules** — checks that must be satisfied for the step to advance, or that govern what staff may attach at this step. Rules are described fully in [Core Object 4: Rules](#core-object-4-rules) below. On the step editor they appear as a collapsible list so the step form stays clean.

### Deadlines on a Step

A step can carry a **deadline** — a countdown that watches how long the workflow sits on that step. If the time runs out, the workflow can route to a different step automatically. Deadlines are configured with:

- **Deadline (days):** how many days to allow.
- **Deadline reference point:** what event starts the clock (for example, when the step was entered).
- **Deadline anchor slot:** an optional slot that pins the clock to a specific object's date.
- **On deadline exceeded, go to step:** the step to route to if time expires.

Deadlines are described in full in [Core Object 6: Deadlines](#core-object-6-deadlines).

### Event Emission on a Step

A step can be configured to emit a **CNF event category** when the step is completed. This writes a record into the audit trail for the property automatically, without a separate EVENT step. Use event emission when you want a milestone logged but do not need a dedicated event step in the workflow graph.

---

## Core Object 3: Slots

A **slot** is a named place where the workflow remembers an important CNF object.

A slot does not hold a typed note. It points to a real object already managed by CNF, such as:

- an inspection,
- a payment,
- a certificate,
- a letter,
- a public form submission,
- a code enforcement case,
- a parcel log,
- a person record,
- an occupancy period / permit file.

A useful way to think about a slot: **"When this process needs proof, where should CNF look?"**

### Rental Registration Slot Examples

| Slot name | What it points to | Why it matters |
|---|---|---|
| `applicationform` | Public form submission | Shows the owner applied for rental registration. |
| `registrationpayment` | Payment | Proves the application fee was paid. |
| `localmanager` | Person | Stores the required local manager when the owner is out of state. |
| `rentalinspection` | Inspection | Stores the current rental inspection result. |
| `rentalcertificate` | Certificate | Stores the certificate issued after approval. |
| `tenantform` | Public form submission | Stores tenant registration information. |
| `lateletter` | Letter | Stores the late notice sent for missed inspection scheduling. |
| `enforcementcase` | Code enforcement case | Stores the case opened if the property remains non-compliant. |

When a first inspection fails and a reinspection later passes, the same `rentalinspection` slot can be updated to point to the newer inspection. CNF keeps the history, but the workflow knows which inspection is current.

### Deed Transfer Slot Examples

| Slot name | What it points to | Why it matters |
|---|---|---|
| `deedchangelog` | Parcel log | Shows the county data import detected an ownership change. |
| `transferinspection` | Inspection | Stores the inspection tied to the transfer. |
| `buyerperson` | Person | Stores the new owner / deed holder. |
| `currentperiod` | Occupancy period / permit file | Stores the permit-file container for certificate work. |
| `temporarycert` | Certificate | Stores a temporary occupancy or access certificate. |
| `finalcert` | Certificate | Stores the final certificate after conditions are satisfied. |
| `shadowcase` | Code enforcement case | Stores the enforcement case if the transfer bypassed the required process. |

Slots let the workflow ask simple questions, such as:

- Does an inspection exist?
- Did the inspection pass?
- Has a payment been confirmed?
- Has the certificate been issued?
- Has a county deed-change parcel log appeared?

---

## Core Object 4: Rules

Rules are the checks a workflow uses to decide whether a step is ready or complete.

For most users, the important part is this: **a rule looks at a slot and asks a yes/no question.**

Examples:

- Is there a payment in the `registrationpayment` slot?
- Is the payment confirmed?
- Is there an inspection in the `rentalinspection` slot?
- Did that inspection pass?
- Is there a local manager person linked?
- Has a certificate been issued?

Rules appear inside the step editor as a collapsible section called **Object Rules**. Multiple rules can be added to a single step.

### Rule Types in Plain Language

| Rule type | Plain meaning | Example |
|---|---|---|
| Require | This must be true before the step can finish. | Require `rentalinspection.result = PASS`. |
| Permit | Staff may attach this kind of object here. | Permit an officer to attach a police complaint or CE action request. |
| Produce | CNF should create or prepare an object. | Produce a new occupancy period or draft certificate. |
| Emit | CNF should log an event. | Emit an event saying the application was reviewed. |

A clerk does not need to memorize the technical names. The builder uses them so the system knows whether a row is a hard requirement, an optional attachment, something CNF should create, or an audit event.

### Rule Conditions and the Condition Builder

A **Require** rule can carry an optional condition — a check that must be true on the bound object before the step is considered complete. The builder provides a guided form with three fields: **Attribute**, **Operator**, and **Value**.

The **attribute** is a property of the object in the slot (for example, `result` on an inspection).  
The **operator** is the comparison to perform (`==`, `!=`, `>`, `>=`, `<`, `<=`).  
The **value** is what the attribute is compared against.

Clicking **Build** assembles these three pieces into a JSON expression automatically. You can also type or paste a JSON expression directly into the Condition JSON field if you need something more complex.

A step can have multiple rules with separate conditions. All Require conditions on a step must be satisfied before the step is considered complete.

#### Condition Syntax

Conditions use [JsonLogic](https://jsonlogic.com/) format. The variable path is always `slotname.attribute`.

Simple equality check:
```json
{"==": [{"var": "rentalinspection.result"}, "PASS"]}
```

Existence check (any bound object, regardless of its state):
```json
{"==": [{"var": "rentalinspection.exists"}, true]}
```

Numeric comparison:
```json
{">=": [{"var": "registrationpayment.amount"}, 75]}
```

Logical AND (both must be true):
```json
{"and": [
  {"==": [{"var": "rentalinspection.exists"}, true]},
  {"==": [{"var": "rentalinspection.result"}, "PASS"]}
]}
```

Logical OR:
```json
{"or": [
  {"==": [{"var": "transferinspection.result"}, "PASS"]},
  {"==": [{"var": "buyeraffidavit.exists"}, true]}
]}
```

#### Attribute and Value Reference

The table below lists every attribute available for each slot type and the valid values to use in the Value field. Enum values are **case-sensitive** and must be typed exactly as shown. Booleans are lowercase `true` or `false`. For date attributes, use ISO format (`YYYY-MM-DD`) and prefer `>=` or `<=` rather than `==`.

---

**All slot types**

| Attribute | Valid values | Notes |
|---|---|---|
| `exists` | `true` | True as soon as any object is bound to the slot. Used for simple "is it there" checks. |

---

**Inspection**

| Attribute | Valid values | Notes |
|---|---|---|
| `result` | `PASS` `VIOLATION` `NOTINSPECTED` | The outcome of the inspection. `PASS` = fully passed. `VIOLATION` = one or more failed items. `NOTINSPECTED` = not yet started. |
| `finalized` | `true` `false` | Whether the inspection record has been finalized by the inspector. |
| `dor` | ISO date (e.g. `2024-06-01`) | Date of record. Use `>=` or `<=` for date comparisons. |

---

**Payment**

| Attribute | Valid values | Notes |
|---|---|---|
| `confirmed` | `true` `false` | Whether the payment has been confirmed by staff. |
| `amount` | Any number (e.g. `75`) | Dollar amount. Use `>=` or `<=`, not `==`. |

---

**Letter**

| Attribute | Valid values | Notes |
|---|---|---|
| `mailed` | `true` `false` | Whether a mailing attempt has been recorded. |
| `dateissued` | ISO date | Date the letter was issued. Use `>=` or `<=`. |

---

**Certificate**

| Attribute | Valid values | Notes |
|---|---|---|
| `certtype` | admin-configured title | Matches the title field in the Certificate Types configuration screen. Exact string match. |
| `isnullified` | `true` `false` | Whether the certificate has been voided. |
| `isamended` | `true` `false` | Whether the certificate has been amended. |
| `dateissued` | ISO date | Date of issue. Use `>=` or `<=`. |
| `expires` | ISO date | Scheduled expiry date. Use `>=` or `<=`. |
| `dateofexpiry` | ISO date | Actual expiry date as recorded. Use `>=` or `<=`. |

---

**CE Case**

| Attribute | Valid values | Notes |
|---|---|---|
| `status` | See below | The current phase of the CE case. Case-sensitive camelCase. |

CE case status values in workflow order:

| Value | Plain meaning |
|---|---|
| `PrelimInvestigationPending` | Violation recorded; investigation not yet started. |
| `IssueNotice` | Generating and sending notice of violation. |
| `InsideComplianceWindow` | Inside the compliance window. |
| `TimeframeExpiredNotCited` | Compliance window expired; officer action required. |
| `Cited` | Citation issued. |
| `AwaitingHearingDate` | Citation issued; waiting for hearing date. |
| `HearingPreparation` | Hearing scheduled; preparing case. |
| `InsideCourtOrderedComplianceTimeframe` | Inside a court-ordered extension. |
| `CourtOrderedComplainceTimeframeExpired` | Court-ordered extension has expired. |
| `InactiveHolding` | Case placed on inactive hold. |
| `FinalReview` | Full compliance; awaiting final review. |
| `Closed` | Case closed. |

---

**Occupancy Period (Permit File)**

| Attribute | Valid values | Notes |
|---|---|---|
| `status` | See below | The current status of the occupancy period. SCREAMING_SNAKE_CASE. |

Occupancy period status values:

| Value | Plain meaning |
|---|---|
| `APPLICATION_AWAITING_REVIEW` | Application submitted; not yet reviewed. |
| `PRE_INSPECTION` | Application accepted; ready for inspection. |
| `INSPECTION_IN_PROCESS` | Inspection started but not finalized. |
| `FAILED_FIN_REINSPECTIONWINDOW_INSIDE` | Failed initial inspection; still inside reinspection window. |
| `FAILED_FIN_REINSPECTIONWINDOW_EXPIRED` | Failed initial inspection; outside reinspection window. |
| `PRE_PERMIT` | Passed inspection; preparing permit. |
| `TEMPPERMIT_ISSUED_VALIDITYWINDOW_INSIDE` | Valid temporary certificate issued. |
| `TEMPPERMIT_ISSUED_VALIDITYWINDOW_EXPIRED` | Temporary certificate has expired. |
| `NONEXPPERMIT_ISSUED` | Non-expiring permit issued. |
| `FORCE_CLOSE` | File force-closed by an officer. |
| `UNKNOWN` | Status could not be determined. |

---

**Parcel Log**

| Attribute | Valid values | Notes |
|---|---|---|
| `logtype` | See below | The type of log entry. Matches county data import events. SCREAMING_SNAKE_CASE. |
| `logts` | ISO date | Timestamp of the log entry. Use `>=` or `<=`. |

Common parcel log type values:

| Value | Plain meaning |
|---|---|
| `PARCEL_UPDATED` | Existing CNF parcel updated from county data. |
| `PARCEL_CREATED` | New CNF parcel created from county data. |
| `OWNER_HUMAN_LINKED` | Owner successfully linked to an existing person record. |
| `OWNER_HUMAN_CREATED` | New person record created for owner. |
| `PARCEL_ID_MATCH` | Parcel matched to CNF record by ID. |
| `ADDRESS_MATCH` | Parcel matched by address. |
| `MANUAL_REVIEW_APPROVED` | Log entry approved in manual review. |
| `MANUAL_REVIEW_REJECTED` | Log entry rejected in manual review. |
| `DATA_QUALITY_WARNING` | Data quality issue was detected. |

---

**Event**

| Attribute | Valid values | Notes |
|---|---|---|
| `category` | admin-configured title | Matches the title of the CNF event category. Exact string match. |
| `eventts` | ISO date | Timestamp of the event. Use `>=` or `<=`. |

---

**Person**

| Attribute | Valid values | Notes |
|---|---|---|
| `linkrole` | admin-configured title | Matches the title of the linked object role (e.g., "Local Manager", "Property Owner"). Exact string match. |
| `linkid` | numeric ID | Internal person record ID. Rarely used in conditions. |

---

**Property Evaluation**

| Attribute | Valid values | Notes |
|---|---|---|
| `status` | `PENDING` `SUCCESS` `ERROR` `DISABLED` | Sync status with WestMC AppSheets. |

---

#### Operators

| Operator | Meaning | Best used for |
|---|---|---|
| `==` | Equal to | Enum values, booleans, exact string matches |
| `!=` | Not equal to | Enum exclusions |
| `>` | Greater than | Numeric amounts |
| `>=` | Greater than or equal | Numeric amounts, date comparisons |
| `<` | Less than | Numeric amounts |
| `<=` | Less than or equal | Numeric amounts, date comparisons |

---

## Core Object 5: Transitions

A **transition** is the path from one step to the next.

If a workflow is a map, the steps are the stops and transitions are the roads between them.

Some transitions are simple:

- After "Application reviewed", go to "Collect payment".
- After "Payment confirmed", go to "Schedule inspection".

Some transitions branch based on what happened:

- If the inspection passed, go to "Issue certificate".
- If the inspection failed, go to "Request corrections and reinspection".
- If the owner does not respond by the deadline, go to "Enforcement review".

### Rental Registration Transition Example

A rental inspection step might have two paths:

| If this is true | Go to this next step |
|---|---|
| `rentalinspection` exists and result is PASS | Issue rental certificate |
| `rentalinspection` exists and result is FAIL | Wait for reinspection |

### Deed Transfer Transition Example

| Situation | Path |
|---|---|
| Owner/seller contacted the borough before the sale | Start the normal pre-sale inspection and certificate path. |
| County data shows the deed changed, but CNF has no completed process | Start a shadow-transfer review and likely enforcement path. |

That choice is handled with an early GATEWAY_XOR step that routes on whether a normal process parcel log exists.

---

### The Default Path

Every step that has more than one outgoing path must include one path with **no condition** — a
fallback that is taken automatically when none of the specific conditions match.

This fallback is called the **default path**.

Without a default path, the workflow can get stuck. If the conditions on all outgoing paths fail
to match — because the data is in an unexpected state, because a new inspection result type was
added later, or because of any other edge case — the workflow has nowhere to go. The property
stays frozen on that step with no way forward.

CNF will not let you publish a workflow that has a step with outgoing paths but no default path.
The publish check will show an error and explain which step is missing one.

#### Which outcome should be the default?

Choose the **safer** outcome — the path that requires more attention rather than less. For
inspection steps, that means the violation or failed path is typically the default, not the
passed path. This way, an unexpected or incomplete result never accidentally advances the workflow
toward a certificate or approval.

Examples:

| Step | Conditional path | Default path |
|---|---|---|
| Inspection step | `result == PASS` → issue certificate | → corrections and reinspection |
| Review step | Decision is "Complete" → payment step | → return for more information |
| Payment step | `confirmed == true` → schedule inspection | → follow up on outstanding payment |

The default path is not a path for bad data — it is the path for anything that does not
explicitly match a known good outcome. Treating it as the fallback for the worst case keeps the
workflow safe.

#### The GATEWAY_XOR step and the default path

A GATEWAY_XOR step is a dedicated decision node. Its only job is to look at what is known and
pick one outgoing path. CNF enforces that every GATEWAY_XOR has exactly one default path. This
is stricter than other steps because a gateway with no default is always broken — it can never
route safely under all possible conditions.

For non-gateway steps that branch (INSPECTION, PAYMENT, REVIEW), the same rule applies: at
least one outgoing path must have no condition. CNF blocks publish if this is missing.

---

## Core Object 6: Deadlines

A **deadline** is a countdown attached to a step. It watches how long the workflow sits on that step and can route the process somewhere else automatically if time runs out.

Deadlines help CNF notice when a process has been sitting too long. They are especially important because municipal workflows often stretch across weeks, months, or years.

Examples:

- Owner must schedule a rental reinspection within 90 days.
- Rental properties must be inspected every two years.
- Buyer has 365 days after a deed transfer temporary certificate to correct violations.
- A late notice gives owners until a specific date to schedule inspection or pay a fee.

Deadlines do not mean the system is making legal decisions by itself. They surface the next required review to staff.

### Deadline Configuration

Each step's deadline has four settings:

| Setting | Meaning |
|---|---|
| **Deadline (days)** | How many days the step may sit before the deadline fires. |
| **Deadline reference point** | What event starts the clock — usually when the step was entered. |
| **Deadline anchor slot** | Optional. Ties the clock to a specific date on a slot object rather than the step entry date. |
| **On deadline exceeded, go to step** | Where the workflow routes automatically when time runs out. |

### Rental Registration Deadline Example

A rental inspection fails. The owner must schedule a reinspection within 90 days.

The workflow can:

1. Start a 90-day deadline when the failed inspection is recorded.
2. Watch for a new scheduled or completed reinspection.
3. Warn officers before the deadline.
4. Move to a "Send late notice" step if nothing happens.
5. Help the officer move toward an enforcement case if the owner still does not respond.

### Deed Transfer Deadline Example

A buyer receives a temporary occupancy certificate because repairs are needed after the sale.

The workflow can:

1. Start a 365-day deadline.
2. Watch for a passed inspection and final certificate.
3. Complete the workflow if the final certificate is issued.
4. Move the property into enforcement review if the deadline passes without compliance.

---

## How These Pieces Work Together

Here is a simple rental example:

1. The workflow is **Rental Registration**.
2. The step is **Inspection Review** (kind: INSPECTION).
3. The important slot is `rentalinspection`.
4. The object rule says the inspection must exist and have a result.
5. The transition says:
   - PASS goes to certificate issuance (kind: CERTIFICATE),
   - FAIL goes to reinspection (another INSPECTION step).
6. A deadline says the owner has 90 days to schedule or complete the follow-up; if not, route to a LETTER step.
7. The INSPECTION step emits an "inspection reviewed" event category to the property record when completed.

Here is a simple deed-transfer example:

1. The workflow is **Deed Transfer Review**.
2. The step is **Determine Entry Path** (kind: GATEWAY_XOR).
3. The important slot is `deedchangelog`.
4. The transition says:
   - If a normal transfer process parcel log exists, continue to the pre-sale inspection path.
   - If the county change appeared with no completed CNF process, go to a CASESPAWN step.
5. A deadline later watches the 365-day correction window and routes to enforcement if the final certificate never appears.

---

## What Workflow Authors Should Decide Before Building

Before opening the builder, write down the process in plain language. A good starting worksheet:

1. **Name the process.**
   Example: Rental Registration and Certification.

2. **List the major steps and their kinds.**
   Example: application review (REVIEW), payment (PAYMENT), inspection (INSPECTION), reinspection (INSPECTION), certificate issuance (CERTIFICATE), late notice (LETTER), enforcement referral (CASESPAWN).

3. **List the proof needed at each step.**
   Example: payment, inspection, certificate, tenant form, letter.

4. **Turn the proof into slots.**
   Example: `registrationpayment`, `rentalinspection`, `rentalcertificate`.

5. **Write the pass/fail choices.**
   Example: inspection passed goes to certificate; inspection failed goes to reinspection.

6. **Write the deadlines.**
   Example: 90 days for reinspection, two years for periodic inspection, 365 days for deed-transfer corrections.

7. **Write the exceptions.**
   Example: out-of-state owner needs a PERSONLINK step; shadow deed transfer should go directly to a CASESPAWN step.

---

## What Makes a Good Workflow

A good workflow is:

- **Specific enough to guide staff**, but not so detailed that every unusual situation breaks it.
- **Built around real CNF objects**, not loose notes.
- **Clear about deadlines**, especially when ordinances require follow-up.
- **Clear about branches**, such as pass/fail, paid/unpaid, complete/incomplete.
- **Easy to explain to another staff member.** If the workflow cannot be described out loud, it is probably too complicated.

---

## Common Mistakes to Avoid

- **Using one vague slot for too many things.**
  "Documents" is less useful than `inspectionreport`, `tenantform`, or `affidavit`.

- **Forgetting the failure path.**
  Every INSPECTION, PAYMENT, and REVIEW step needs a plan for "not passed", "not paid", or "incomplete".

- **Creating a deadline without deciding what happens next.**
  A deadline should lead to a review, reminder, stalled state, late fee, or enforcement path.

- **Trying to automate officer judgment.**
  The workflow should bring the right facts to the officer. It should not hide discretion where the ordinance requires review.

- **Editing a published process casually.**
  Published workflows may already be running on real properties. Major changes should usually become a new version.

---

## Quick Glossary

| Word | Plain meaning |
|---|---|
| Workflow | The full procedure, like Rental Registration or Deed Transfer. |
| Workflow instance | One property's running copy of a workflow. |
| Step | One stop in the process. Every step has a step kind that tells CNF what type of work it does. |
| Step kind | The category of a step — REVIEW, INSPECTION, PAYMENT, CERTIFICATE, LETTER, GATEWAY_XOR, and so on. See the Step Kinds section above. |
| Slot | A named place where the workflow remembers a real CNF object, such as an inspection or payment. |
| Rule | A check the workflow uses to decide if a step is ready or complete. Rules live inside the step editor. |
| Transition | The path from one step to another. |
| Deadline | A countdown on a step. If the step sits too long, the workflow routes somewhere else automatically. |
| Stalled | The workflow is stuck and needs staff attention. |
| Published | A workflow that has passed validation and is active for use on properties. |
| Draft | A workflow that is still being designed and has not been published yet. |

---

## Core Object 7: Workflow Lifecycle

Every workflow definition moves through a defined lifecycle from first draft to final retirement.
Understanding this lifecycle helps admins manage their procedures over time, especially as
requirements change and older workflows are replaced by newer versions.

---

### The Six Lifecycle Statuses

#### 1. Draft

A workflow that has not been published. Staff are still designing steps, slots, rules, and
transitions. Nothing is running yet.

- **Can a property be enrolled?** No.
- **Can it be deactivated?** Yes — a draft that is no longer needed can be removed.

---

#### 2. Published – No Enrollments

A workflow that passed validation and was published, but no property has been enrolled in it yet.

- **Can a property be enrolled?** Yes.
- **Can it be deactivated?** Yes — if you decide not to use it after all.

---

#### 3. Published – Active Enrollments

A workflow that is running on one or more properties. At least one enrollment is currently in
progress (not yet complete or abandoned).

- **Can a property be enrolled?** Yes.
- **Can it be deactivated?** No — you cannot remove a workflow while active enrollments are
  running. You may queue it for retirement instead.
- **Available action:** Queue for Retirement (see below).

---

#### 4. Published – All Enrollments Closed

A workflow that was used in the past and all enrollments have since been completed or abandoned.
No enrollment is currently open.

- **Can a property be enrolled?** Yes — but this state usually means the workflow is ready to
  be wound down.
- **Can it be deactivated?** Yes.
- **Available action:** Queue for Retirement or Deactivate directly.

---

#### 5. Retirement Queued

An admin has declared that this workflow is moving toward retirement. No new properties will be
enrolled. Enrollments that are already running continue until they close naturally.

- **Can a property be enrolled?** No — the enrollment door is closed.
- **What happens to open enrollments?** They continue normally. Officers work through them as
  usual. The workflow is just waiting for them to finish.
- **When does retirement complete?** As soon as all currently open enrollments reach a closed
  status (complete or abandoned), CNF automatically marks the workflow as Retired. An admin can
  also manually trigger retirement early if all enrollments are already closed.
- **Can it be cancelled?** Yes — if circumstances change, an admin can cancel the retirement
  queue and return the workflow to Published status.

---

#### 6. Retired

All enrollments are closed and the workflow is fully wound down. It can no longer accept new
enrollments and is treated as a read-only historical record.

- **Can a property be enrolled?** No.
- **Is the history preserved?** Yes — all past enrollment records, steps, documents, and events
  remain visible for audit and reference.
- **Can it be un-retired?** No — retirement is final. If you need the same procedure again, create
  a new version of the workflow.

---

### How Retirement Works in Practice

The retirement pathway is designed for workflows that have been replaced by a newer version or a
changed procedure. The typical flow looks like this:

1. The admin authors and publishes a new version of the workflow.
2. The admin queues the old version for retirement. New enrollments go to the new version.
3. Open enrollments on the old version continue running normally.
4. As each enrollment finishes, CNF counts down toward zero open enrollments.
5. When the last enrollment closes, CNF automatically retires the old workflow overnight.
6. The admin sees the old workflow marked as Retired in the workflow list.

If all enrollments have already closed before the admin queues retirement (Status 4), the admin
can also click "Complete Retirement Now" to immediately mark it Retired without waiting for the
nightly sweep.

---

### Lifecycle Actions Summary

| Current Status | Available Actions |
|---|---|
| Draft | Deactivate |
| Published – No Enrollments | Deactivate |
| Published – Active Enrollments | Queue for Retirement |
| Published – All Enrollments Closed | Deactivate · Queue for Retirement |
| Retirement Queued (open enrollments) | Cancel Retirement Queue |
| Retirement Queued (all closed) | Cancel Retirement Queue · Complete Retirement Now |
| Retired | (view only) |

---

## Short Version

A workflow is a smart checklist for a property. Steps are the stops in the process — each with a kind (REVIEW, INSPECTION, PAYMENT, CERTIFICATE, etc.) that tells CNF what to do. Slots tell CNF which real objects matter at each step. Rules ask whether those objects satisfy the step. Transitions decide where the process goes next. Deadlines make sure follow-up windows do not disappear.

For rental registration, this helps staff manage applications, fees, inspections, certificates, tenant information, late letters, and enforcement. For deed transfers, it helps staff manage inspections, temporary certificates, owner changes, shadow transfers, correction windows, and final occupancy approval.
