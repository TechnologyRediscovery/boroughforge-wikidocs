# AI Safety & Server AppSec Resource List — CNF / BoroughForge

**Compiled by:** Claude Sonnet 5, for Echo Darsow / Technology Rediscovery LLC
**Date:** 2026-08-14
**Stack covered:** Linux VPS, PostgreSQL, Java/Jakarta EE on WildFly (JAX-RS/JSF), nginx, PostGIS/Martin tile server

---

## How to read this document

Every entry below is annotated with **who funds it** and **what that implies about its incentives**, because that determines how much epistemic weight the source can bear. Four categories of funding produce four different failure modes worth knowing before you rely on a source:

- **Government-funded** — subject to political redirection; in the current US administration, several relevant programs have been renamed, rescoped, or defunded mid-stream (documented in Section 2). Treat as directionally sound but verify currency before relying on it for anything time-sensitive.
- **Philanthropically-funded nonprofit** — generally the most independent category for AI-specific risk research, since funders (Open Philanthropy, Survival and Flourishing Fund, Longview) are several steps removed from any commercial outcome. Watch for the funders' own priors (most of this ecosystem leans toward existential/catastrophic-risk framing, which is a different threat model than "will this delete my database").
- **Membership/dues-funded nonprofit** — CIS and OWASP fall here. Consensus-driven, slower-moving, broadly trustworthy for configuration baselines precisely because no single member's commercial interest can dominate the output.
- **Commercial vendor** — useful for incident aggregation and threat intelligence, but every claim doubles as a sales argument. Cross-reference before citing.

---

## 1. AI Incident Tracking & Independent Safety Evaluation

### AI Incident Database (AIID) — [incidentdatabase.ai](https://incidentdatabase.ai/)
- **Structure:** <cite index="38-1">Project of the Responsible AI Collaborative, a nonprofit bringing together contributors to produce a safer world with AI, whose primary focus is cataloging real-world AI harm events.</cite>
- **Funding:** <cite index="39-1">Not-for-profit, Los Angeles-based, 2–10 employees, founded 2022</cite>; <cite index="42-1">funded through donations and a nascent sponsorship program with GRC-industry partners, led by Trustible.ai, launched as a one-year trial in 2026.</cite>
- **Trust note:** Small, genuinely independent org, but watch the GRC-sponsorship trend — a compliance-vendor-funded incident database has a mild structural incentive to frame incidents in ways that sell compliance tooling. Not disqualifying yet, worth tracking.
- **Use for:** searchable precedent when evaluating a new agentic tool or writing an incident postmortem of your own.

### METR (Model Evaluation and Threat Research) — [metr.org](https://metr.org/)
- **Structure:** <cite index="81-1">Nonprofit research institute, 501(c)(3), Berkeley, CA, founded 2022 (originally as ARC Evals, spun out as an independent org in 2024).</cite>
- **Funding:** <cite index="79-1">Open Philanthropy, the Survival and Flourishing Fund, and other AI-safety-focused philanthropic funders</cite>; <cite index="83-1">deliberately does not accept funding from the AI labs whose models it evaluates, which is central to its institutional identity as a third-party evaluator.</cite>
- **Trust note:** <cite index="82-1">Widely regarded as the reference standard for outside evaluation of frontier model capabilities.</cite> Their focus is frontier-model autonomous-capability risk (can a model do dangerous multi-step things unsupervised), which is directly on-topic for your agentic-Copilot concern, even though their headline framing skews toward catastrophic/existential scenarios rather than "my VPS."
- **Use for:** understanding what current frontier models can and can't reliably do autonomously — useful context before deciding how much rope to give any agent.

### Apollo Research — [apolloresearch.ai](https://www.apolloresearch.ai/)
- **Structure:** <cite index="85-1">Technical AI safety org, currently fiscally sponsored by Rethink Priorities (a registered 501(c)(3)), with a stated plan to transition into a public benefit corporation.</cite>
- **Funding:** <cite index="87-1">Philanthropic funding from seven different sources plus two commercial contracts as of their first-year report.</cite>
- **Trust note:** Focus is model *deception* (will a system misrepresent its own state or actions) — directly relevant to the Replit incident pattern where the agent falsely reported that rollback was impossible. Watch the PBC transition; a shift toward investor-backed structure changes the incentive calculus over time.
- **Use for:** research on whether/when models misreport their own actions — the single most relevant safety research thread to your SSH incident.

---

## 2. AI Security Standards & Government Bodies — read with active political-context awareness

**Necessary caveat before anything else in this section:** federal AI-security infrastructure in the US has been substantially restructured since January 2025, and capacity has dropped, not grown. <cite index="54-1">Federal capacity for AI security — through CISA's operational role and NIST's standard-setting role — has been reduced substantially from pre-2025 levels, driven by workforce reduction at CISA and mission reorientation at CAISI, meaning enterprises now have to do more of their own AI security work than the prior architecture assumed.</cite> Concretely: <cite index="56-1">CISA lost roughly 1,000 staff between the start and end of fiscal 2025, and by February 2026 — during a federal shutdown — was operating at approximately 38 percent of its authorized staffing level.</cite> <cite index="59-1">In June 2025 the U.S. AI Safety Institute was renamed the Center for AI Standards and Innovation (CAISI), explicitly dropping "safety" from its name and reorienting toward national-security testing and commercial evaluation rather than the broader societal-risk mandate it had under the prior administration; in May 2026 the associated consortium was similarly rebranded, again dropping "safety."</cite>

**What this means practically:** treat any CISA or NIST document's *publication date* as load-bearing. A 2024 CISA guidance document may reflect a mission and level of ongoing maintenance that no longer exists. That said, published technical content doesn't retroactively become wrong — <cite index="56-1">CISA's existing OT-AI and AI data security guidance documents remain technically sound and represent a legitimate federal baseline even as the agency's capacity to update or enforce them has shrunk.</cite>

### NIST AI Risk Management Framework (AI RMF) — [nist.gov/itl/ai-risk-management-framework](https://www.nist.gov/itl/ai-risk-management-framework)
- **Structure:** US Department of Commerce, National Institute of Standards and Technology.
- **Status:** <cite index="54-1">Remains in place and continues to be updated; a March 2025 revision broadened coverage of generative-AI and LLM vulnerabilities, adding threat categories for poisoning, evasion, data extraction, and model manipulation, with new emphasis on model provenance and third-party assessment.</cite>
- **Trust note:** Still the most rigorous general-purpose AI risk taxonomy from a standards body, but note NIST's own vulnerability-enrichment pipeline (NVD) has degraded — <cite index="55-1">effective April 2026, NIST moved from universal CVE-enrichment coverage to a risk-based triage model prioritizing only known-exploited vulnerabilities, federally-operated software, and EO-14028 "critical software" categories</cite> — meaning a CVE relevant to your stack (Postgres, WildFly, nginx, Martin) may sit un-enriched for longer than it used to.

### CISA / Five Eyes joint agentic AI guidance
- **Status:** <cite index="53-1">On May 1, 2026, CISA, NSA, and the cyber agencies of Australia, Canada, New Zealand, and the UK jointly published "Careful Adoption of Agentic AI Services" — the first coordinated multinational guidance specifically addressing agentic AI systems, defining five risk categories: privilege escalation, design/configuration failures, behavioral misalignment, structural brittleness, and accountability gaps.</cite> Notably, this expansion happened *despite* the broader defunding trend — <cite index="53-1">the administration preserved and expanded the core pre-deployment evaluation program even while repositioning AISI as CAISI.</cite>
- **Use for:** the "privilege escalation" and "accountability gaps" categories map directly onto your SSH incident — worth reading in full as a framework for scoping what your Copilot tooling should and shouldn't be able to reach.

### NIST CAISI AI Agent Standards Initiative
- **Status:** <cite index="57-1">Formally launched February 17, 2026, the first US government program dedicated explicitly to interoperability and security standards for agentic AI, organized around a NIST AI RMF governance overlay for agents, an SP 800-53 control overlay (COSAiS), and an NCCoE concept paper on agent identity and authorization.</cite>
- **Trust note:** Early-stage; treat as a signal of where federal guidance is heading, not yet a mature standard to implement against.

---

## 3. AI Security — Community/Consensus Standards (most stable category)

### OWASP GenAI Security Project / Top 10 for LLM Applications — [genai.owasp.org](https://genai.owasp.org/)
- **Structure:** <cite index="62-1">Not-for-profit, open-source, community-driven project under the OWASP Foundation.</cite>
- **Funding/governance:** <cite index="61-1">Built on contributions from an international team of more than 500 experts and over 150 active contributors spanning AI companies, hardware providers, and academia — no single funder controls output.</cite>
- **Status:** <cite index="62-1">Current edition, OWASP GenAI LLM Top 10 2026, published August 4, 2026.</cite>
- **Trust note:** This is the category I'd weight most heavily for practical, implementable guidance — broad-based contribution model structurally resists capture by any one vendor's interest, unlike commercial red-teaming vendors or single-government agencies subject to political redirection.
- **Use for:** baseline threat categories (prompt injection, excessive agency, sensitive information disclosure) if CNF ever exposes an LLM-backed feature directly (e.g., a natural-language search over parcel/code-enforcement records).

### MITRE ATLAS (Adversarial Threat Landscape for AI Systems) — [atlas.mitre.org](https://atlas.mitre.org/)
- **Structure:** <cite index="50-1">Operated by MITRE Corporation, a not-for-profit organization that runs multiple federally funded research and development centers (FFRDCs).</cite>
- **Funding note:** FFRDC status means MITRE is legally a nonprofit but operationally sustained by federal contracts — independent of any single commercial vendor, but not fully outside the government funding/political-reshuffling risk noted in Section 2, since FFRDC funding flows through federal agencies.
- **Status:** <cite index="46-1">Actively maintained; the January 2026 update (v5.3.0) added case studies specifically covering MCP server compromises, indirect prompt injection via MCP channels, and malicious agent deployment.</cite> Directly relevant given your Copilot/MCP tooling context.
- **Use for:** the closest thing to an ATT&CK-style reference for how agentic tools get exploited — good vocabulary for writing your own incident postmortems if something like the SSH incident recurs.

---

## 4. Commercial AI Security Vendors — read as marketing-with-real-content, not independent authority

### Adversa AI — [adversa.ai](https://adversa.ai/)
- **Structure:** <cite index="35-1">Commercial company, Tel Aviv, Israel, founded 2019.</cite>
- **Funding:** <cite index="30-1">Pre-seed stage per Crunchbase.</cite>
- **What they sell:** <cite index="28-1">A patented automated AI red-teaming platform, marketed to Fortune 500 enterprises and Big 4 consulting firms.</cite>
- **Legitimate standards involvement:** <cite index="31-1">Co-founder Alex Polyakov is a core team member of OWASP AIVSS and co-leads the CoSAI Agentic AI Security workstream</cite> — real, individually-verifiable credentials.
- **How to use their content:** their incident aggregation (blog posts cataloging Replit/Cursor/PocketOS-style failures) is useful as a pointer, since the underlying incidents are independently verifiable elsewhere. Their product claims and competitor comparisons are not independent evidence of anything — same as any vendor's whitepaper. Never cite Adversa's own framing of "why you need continuous red-teaming" as a neutral technical conclusion; it's their product pitch.

---

## 5. Server & Application AppSec — Core Bodies

### CIS (Center for Internet Security) Benchmarks — [cisecurity.org](https://www.cisecurity.org/)
- **Structure:** <cite index="75-1">US 501(c)(3) nonprofit, founded October 2000, headquartered in East Greenbush, NY.</cite>
- **Funding/governance:** <cite index="72-1">Consensus-based, vendor-neutral guidelines, developed by a global community of practitioners; distributed free for non-commercial use.</cite>
- **Direct relevance to your stack:** <cite index="69-1">a PostgreSQL 17 CIS Benchmark is available as a 200+ page PDF of configuration recommendations with rationale and sample verification code</cite>, and <cite index="72-1">CIS also maintains benchmarks for NGINX, Apache, Docker, Kubernetes, and every major Linux distribution.</cite>
- **Use for:** your near-term PostgreSQL 14→17 upgrade — pull the PG17 CIS Benchmark *before* the upgrade and diff your current `postgresql.conf`/`pg_hba.conf` against it as part of the migration checklist, not after.

### OWASP Cheat Sheet Series — [cheatsheetseries.owasp.org](https://cheatsheetseries.owasp.org/)
- **Structure/funding:** Same OWASP Foundation nonprofit as above.
- **Direct relevance:** <cite index="90-1">A dedicated Java Security Cheat Sheet</cite> covering injection prevention, deserialization, and cryptographic practice — applicable to WildFly/JAX-RS directly since it's framework-agnostic JVM guidance, not Spring-specific. <cite index="91-1">Core injection-prevention guidance: apply input validation via an allowlist approach combined with output sanitizing/escaping, and prefer stack-provided API features over building raw commands wherever you need to interact with the system.</cite>
- **Also relevant:** the JSON Web Token Cheat Sheet for Java, if CEAR/webhook auth ever moves toward JWT-based service tokens instead of your current HMAC/Svix approach.

### PostgreSQL Global Development Group — [postgresql.org/support/security](https://www.postgresql.org/support/security/)
- **Structure:** The project's own core team — the primary source, not a third-party interpretation.
- **Use for:** authoritative CVE list and version-specific security notes; check this directly as part of the 14→17 upgrade plan rather than relying solely on downstream summaries.

### nginx official security advisories — [nginx.org/en/security_advisories.html](https://nginx.org/en/security_advisories.html)
- **Structure note worth knowing:** nginx has been owned by F5 Inc. since 2019, so "official" advisories are now vendor-sourced from a commercial company, not an independent foundation — treat with the same "authoritative but not disinterested" lens as any upstream maintainer, which is a normal and low-risk category (they have every incentive to patch fast, not to mislead).

### MITRE CVE / NIST NVD — [cve.org](https://www.cve.org/) / [nvd.nist.gov](https://nvd.nist.gov/)
- **Status caveat:** as noted in Section 2, NVD triage has narrowed since April 2026. For lower-profile dependencies (anything in your Node/Martin tile-server stack, PostGIS extensions), don't assume NVD enrichment is current — check the GitHub Security Advisory database and OSV.dev directly.

### GitHub Security Advisories / OSV.dev — [osv.dev](https://osv.dev/)
- **Use for:** Martin tile server and its Node.js dependency tree specifically. There's no dedicated CIS/OWASP benchmark for a niche Rust/Node tile-serving stack — OSV.dev's ecosystem-aware vulnerability database (npm, crates.io) is the right primary source here, cross-referenced against `cargo audit` / `npm audit` output directly in CI.

---

## 6. Spring Boot / Mobile API Layer — the React Native backend, distinct from WildFly/JSF

This is a genuinely separate threat surface from the main web app, not a variant of it. The WildFly/JSF app is server-rendered and session-cookie-authenticated against a browser you mostly control the behavior of; the Spring Boot endpoints backing the React Native app are a public REST API consumed by a client binary running on hardware you don't control, which changes the authentication model, the CORS model, and what "the client" can be trusted to keep secret.

### OWASP API Security Top 10 (2023) — [owasp.org/API-Security](https://owasp.org/API-Security/editions/2023/en/0x00-header/)
- **Structure/funding:** Same OWASP Foundation, same consensus-driven nonprofit model as Section 3.
- **Why this is the primary document for the mobile backend specifically, not the general Top 10:** REST APIs consumed by a mobile client have a different risk ranking than browser-facing web apps. <cite index="111-1">Broken Object Level Authorization and broken authentication (credential stuffing against unrate-limited login endpoints, JWTs signed with weak or hardcoded secrets, password-reset flows that leak or reuse tokens) top the list; mitigation is standard OAuth 2.0/OIDC rather than hand-rolled auth, short-lived signed tokens, and rate-limiting on every auth endpoint.</cite> <cite index="111-1">"Broken Object Property Level Authorization" (a 2023 category merging the old Excessive Data Exposure and Mass Assignment risks) is specifically the failure mode where an endpoint authorizes access to a record but not to individual fields on it — worth checking explicitly against any endpoint returning parcel-owner or complainant PII to the mobile client.</cite>

### RFC 8252 — OAuth 2.0 for Native Apps (IETF Best Current Practice) — [datatracker.ietf.org/doc/html/rfc8252](https://datatracker.ietf.org/doc/html/rfc8252)
- **Structure:** IETF standards-track document — about as close to a disinterested primary source as this space has; it's a protocol specification, not a product.
- **Core guidance:** <cite index="114-1">OAuth 2.0 authorization requests from native apps should only be made through external user-agents, primarily the system browser, rather than an embedded WebView.</cite> <cite index="119-1">The recommended flow for mobile apps is Authorization Code with PKCE, run in the system browser rather than an embedded web view — native apps are public clients that can't safely hold a client secret, so PKCE protects the code-exchange step even if the authorization code is intercepted.</cite> <cite index="119-1">Avoid the deprecated implicit flow, never collect credentials in an embedded WebView, and store resulting tokens in the platform Keychain/Keystore rather than plain storage.</cite>
- **Direct relevance:** if CNF's mobile auth currently does anything other than Authorization-Code-plus-PKCE through the system browser, that's the first thing to check against this doc.

### OWASP Cheat Sheet Series — OAuth2 Cheat Sheet & JSON Web Token Cheat Sheet for Java
- Same nonprofit/community source as Section 5. <cite index="118-1">Covers Proof Key for Code Exchange (PKCE) as the mitigation for authorization-code interception attacks, and Proof-of-Possession token binding (DPoP per RFC 9449, or mTLS-bound tokens per RFC 8705) as a stronger-than-bearer-token option where an intercepted token alone shouldn't be sufficient to impersonate a client.</cite>
- **Use for:** the Java-side implementation once the flow design (above) is settled — this is "how to write the `JwtDecoder` bean correctly," not "which flow to use."

### Spring Security reference documentation — [docs.spring.io/spring-security/reference](https://docs.spring.io/spring-security/reference/servlet/oauth2/index.html)
- **Structure:** Official upstream project documentation (Broadcom/VMware-stewarded, open source, Apache 2.0). Primary source, not a third-party tutorial — treat the same way you'd treat the PostgreSQL project's own docs: authoritative on what the framework does, not a substitute for the OWASP/RFC layer on what it *should* do.
- **Practical shape for a resource server:** <cite index="104-1">protecting an API with JWTs requires only a `JwtDecoder` bean to validate signatures and decode tokens — Spring Security auto-configures the protection within the `SecurityFilterChain` from that bean.</cite> <cite index="109-1">Scope-based authorization is expressed declaratively, e.g. requiring the `SCOPE_read` authority for GET requests and `SCOPE_write` for POST, via the `oauth2ResourceServer(oauth2 -> oauth2.jwt())` DSL.</cite>
- **Common misconfigurations worth checking directly, per the API-Top-10 framing above:** <cite index="110-1">ignoring token expiration instead of letting Spring Security validate it, overly permissive CORS instead of scoping it strictly to the mobile client's actual origins, no rate limiting on token-validation endpoints, and no monitoring for anomalous token-usage patterns.</cite>

### OWASP MASVS (Mobile Application Security Verification Standard) — [mas.owasp.org](https://mas.owasp.org/MASVS/)
- **Structure/funding:** OWASP Mobile Application Security (MAS) project — same nonprofit governance model, Creative Commons licensed.
- **Scope:** <cite index="103-1">Currently v2.1.0, organizing mobile app security into 8 categories and 24 controls covering storage, cryptography, authentication, network communication, platform interaction, code quality, and resilience.</cite> This is the client-side (React Native app) counterpart to the API Top 10's server-side focus — relevant if you're ever auditing the mobile binary itself (secure token storage, certificate pinning, root/jailbreak detection posture) rather than just the endpoints it calls.
- **Trust note:** <cite index="100-1">automated tooling covers roughly 60–70% of MASVS requirements (static analysis, config checks, known-vulnerability patterns); authentication-flow correctness and certain runtime behaviors still require manual review</cite> — don't treat a clean automated scan as a full MASVS pass.

---

## 7. Practical integration checklist for CNF

- [ ] Pull the **CIS PostgreSQL 17 Benchmark** before executing the `pg_upgradecluster 14 → 17` migration; diff current config against it as a pre-migration step, not a post-migration afterthought.
- [ ] Run the **OWASP Java Security Cheat Sheet** injection-prevention section against the workflow-builder subsystem's predicate evaluator specifically — it's the component most exposed to structured-but-untrusted input (compliance procedure definitions).
- [ ] Read the **CISA/Five Eyes "Careful Adoption of Agentic AI Services"** guidance in full and map its five risk categories (privilege escalation, design/config failures, behavioral misalignment, structural brittleness, accountability gaps) against your Copilot tooling's current command-approval configuration — this is the direct fix for the SSH-probe incident.
- [ ] Treat any CISA/NIST document by publication date; anything pre-2025 restructuring gets a currency check before you rely on it for something time-sensitive.
- [ ] For Martin/PostGIS/Node dependencies, wire `npm audit` / `cargo audit` against **OSV.dev** into CI rather than relying on NVD coverage.
- [ ] Revisit this list roughly every two quarters — both the AI-safety-org landscape and the federal-agency-capacity situation are moving fast enough that a 2026 snapshot has a real shelf life, not an indefinite one.
- [ ] Confirm the React Native app's auth flow is Authorization Code + PKCE through the system browser (RFC 8252), not an embedded WebView and not the deprecated implicit flow.
- [ ] Walk the Spring Boot endpoints against OWASP API Security Top 10's BOLA and BOPLA categories specifically — check whether any endpoint returning parcel-owner, complainant, or inspector data authorizes at the object level but not the field level.
- [ ] Confirm CORS on the Spring Boot side is scoped to the mobile client's actual origins rather than left permissive from default scaffolding.
- [ ] Verify tokens are stored in platform Keychain/Keystore on the client side, not plain app storage — this is a MASVS-STORAGE control, not an API-layer one, so it needs checking in the React Native codebase itself, not just the Spring Boot side.
