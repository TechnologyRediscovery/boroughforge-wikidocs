---
title: JEE Auth, HttpSession & Bean Scopes — a CodeNforce Tutorial
description: How CodeNforce leans on WildFly for authentication only, how the HttpSession ties everything together, and the difference between faces-config.xml managed beans and CDI beans, taught through the PGRP.1 muni-switch bug
published: true
date: 2026-10-26T00:00:00.000Z
tags: subsystem:session, audience:dev, type:howto, status:has-planned-ref
editor: markdown
dateCreated: 2026-10-23T00:00:00.000Z
---

# JEE Auth, HttpSession & Bean Scopes — a CodeNforce Tutorial

**Who this is for:** a developer who knows our 3-tier layout (Integrators → Coordinators → Backing
Beans) but has never had to think about what the *server* is doing underneath it.

**What you will be able to do afterwards:**

1. Say exactly which parts of "logging in" WildFly does for us, and which parts are home-rolled.
2. Explain what lives inside an `HttpSession` and why a muni switch does **not** empty it.
3. Tell a `faces-config.xml` managed bean from a CDI bean on sight, and say which one will
   survive a `sessionMap.remove(...)`.
4. Add a new session-scoped bean without re-creating the bug that opened **PGRP.1**
   ("muni X's property groups still render after switching to muni R").

> **Versions this page is written against.** WildFly 26.1 → Jakarta EE 9.1 → Servlet 5.0,
> Faces 3.0, CDI 3.0 (Weld 4.0). Spec links below point at those versions.

---

## 1. The big picture: three layers

```text
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ 3. OUR HOME-ROLLED MUNI FENCE                                            │
 │    SessionBean, Session*Conductor, UserAuthorized + Credential (keycard),│
 │    UMAP choice, Phase 1 / Phase 2 session flush                          │
 ├──────────────────────────────────────────────────────────────────────────┤
 │ 2. BEAN CONTAINERS (two of them, side by side)                           │
 │    Faces managed beans (faces-config.xml)   |   CDI / Weld (@Named)      │
 ├──────────────────────────────────────────────────────────────────────────┤
 │ 1. SERVLET CONTAINER (WildFly: Undertow + Elytron)                       │
 │    Authentication (FORM login), roles, HttpSession, session timeout      │
 └──────────────────────────────────────────────────────────────────────────┘
```

The rule of thumb that explains most surprises: **layers 2 and 3 both park their state in the
layer-1 `HttpSession`**, but they park it in *different ways*, and layer 3 (our code) only knows
how to clean up one of those ways. The rest of this page earns that sentence.

---

## 2. Layer 1: what WildFly does for us (authentication only)

### 2.1 FORM login, declared in `web.xml`

```xml
<login-config>
    <auth-method>FORM</auth-method>
    <realm-name>file</realm-name>
    <form-login-config>
        <form-login-page>/public/loginGF.xhtml</form-login-page>
        <form-error-page>/public/errorLogin.xhtml</form-error-page>
    </form-login-config>
</login-config>

<security-constraint>
    <web-resource-collection>
        <web-resource-name>usergen</web-resource-name>
        <url-pattern>/restricted/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
        <role-name>User</role-name>
    </auth-constraint>
</security-constraint>
<!-- a second constraint on the same pattern grants role "Developer" -->
```

What this buys us, with no Java of ours involved:

- Anything under `/restricted/*` bounces an unauthenticated request to `loginGF.xhtml`.
- The container checks the submitted username/password against its user store.
- Two constraints on the same URL pattern are *combined* by the Servlet spec, so holding either
  `User` or `Developer` gets you through.
- `<realm-name>` is the HTTP **BASIC** realm label; with FORM it does not choose the user store.

### 2.2 Where the user store is chosen: `jboss-web.xml`

```xml
<jboss-web version="8.0" ...>
  <context-root>/tcvce</context-root>
  <security-domain>rolescnfApplicationDomain</security-domain>
</jboss-web>
```

The name `rolescnfApplicationDomain` is mapped to an actual credential store in the **server**
configuration (WildFly's Elytron subsystem), which is *not in this repo*. The comment in
`SessionInitializer` states the intent: *"JBoss is responsible for the first query against the
DB."* If you need to change how passwords are verified, that is server administration, not code.

### 2.3 The one-line handshake from container to our code

Once the container has authenticated someone, our code asks a single question of the request:

```java
// SessionInitializer.sessionInit_getContainerAuthenticatedUser()
HttpServletRequest request = (HttpServletRequest) ec.getRequest();
String usr = request.getRemoteUser();
```

That string is the **only thing we take from the container.** Everything after it is ours:

1. Look the username up to a `User`.
2. List that user's valid UMAPs (user-muni-authorization periods) and let them pick one.
3. `UserCoordinator.auth_authorizeUser_SECURITYCRITICAL(ua, umap)` builds the `UserAuthorized`
   with its `Credential` (the **keycard**). From here on, "which muni may you touch" is answered
   by our keycard, never by a container role. The container knows `User`/`Developer`; it has no
   concept of a municipality.

### 2.4 Session lifetime: container default, then bumped

`web.xml` sets a 30 minute idle timeout:

```xml
<session-config><session-timeout>30</session-timeout></session-config>
```

and `SessionInitializer.sessionInit_configureSession` extends it once a real internal user is
credentialed:

```java
HttpSession httpSession = (HttpSession) getFacesContext().getExternalContext().getSession(false);
if (httpSession != null) {
    httpSession.setMaxInactiveInterval(28800); // 480 min = 8 hours
}
```

### 2.5 Logout: two calls, in this order

```java
// LogoutServlet.doPost
req.logout();                       // drops the FORM-auth principal the container holds
HttpSession session = req.getSession(false);
if (session != null) {
    session.invalidate();           // destroys the session and everything in it
}
```

The source comment explains why both are needed: invalidating alone can leave a later request
arriving still authenticated. Keep the two distinct in your head:

| Call | Ends the… |
|---|---|
| `HttpServletRequest.logout()` | **authentication** (who the container thinks you are) |
| `HttpSession.invalidate()` | **session** (the bag of state, including every bean stored in it) |

---

## 3. The HttpSession is the shared closet

An `HttpSession` is a per-browser map the container keeps alive between requests. Faces exposes it
to us as `FacesContext.getCurrentInstance().getExternalContext().getSessionMap()`. Three kinds of
tenant live in that closet:

| Tenant | How it is keyed | Example |
|---|---|---|
| Faces session-scoped **managed beans** | by **bean name** | `sessionBean` |
| **CDI** session-scoped beans (Weld) | by Weld's **own scheme**, not the bean name | `WELD_S#…` keys plus `WELD_S_HASH` |
| Faces/PrimeFaces infrastructure | by framework key | `com.sun.faces…`, `org.primefaces…` |

The Weld key shape comes from Weld's source
(`HttpSessionContextImpl`: prefix `WELD_S`, delimiter `#`, index hash stored as `WELD_S_HASH`,
tag 4.0.3.Final) and was confirmed in a live WildFly dump on 26 Oct 2026; see section 5.4.

### 3.1 A muni switch is a session *re-init*, not a new session

This is the fact that makes the PGRP.1 bug possible. The chain, with real names:

```text
sessMuni.xhtml  [Change muni] -> [Go]
   -> MissionControlBB.reauthenticateWithFullReports()
        -> SessionConductor.clearSessionObjectsForSessionReInit()
             PHASE 1  clearConductorStateBeforeMapRemoval()   (explicit, per-bean)
             PHASE 2  removeSessionInfrastructureForSessionReinit()  (sessionMap.remove by name)
        -> returns the navigation outcome "sessionReinit"
   -> faces-config.xml navigation rule redirects to /restricted/initiateInternalSession.xhtml
```

```xml
<navigation-rule>
    <from-view-id>*</from-view-id>
    <navigation-case>
        <from-outcome>sessionReinit</from-outcome>
        <to-view-id>/restricted/initiateInternalSession.xhtml</to-view-id>
        <redirect />
    </navigation-case>
</navigation-rule>
```

**Nobody calls `session.invalidate()`.** The user stays authenticated (that is the point: no
re-login to look at another muni), so the `HttpSession`, and everything that was *not* explicitly
removed from it, carries straight over into the new muni. Phase 1 and Phase 2 exist to empty the
closet by hand. That works only for tenants our code can reach. Which brings us to the two bean
systems.

---

## 4. Two bean systems, side by side

### 4.1 Declaring a bean

**Style A: `faces-config.xml` managed bean (the legacy Faces facility).** 132 of these in
`WEB-INF/faces-config.xml` today (21 session, 74 view, 28 application, 8 request, 1 none):

```xml
<managed-bean>
    <managed-bean-name>sessionBean</managed-bean-name>
    <managed-bean-class>com.tcvcog.tcvce.session.SessionBean</managed-bean-class>
    <managed-bean-scope>session</managed-bean-scope>
</managed-bean>
```

**Style B: CDI bean (annotations, discovered by Weld).** About 45 `@Named` classes today, mostly
`@ApplicationScoped` coordinators/integrators; **three** are CDI `@SessionScoped`:

```java
// PropertyGroupsBB.java (one of the three)
@Named("propertyGroupsBB")
@SessionScoped            // jakarta.enterprise.context.SessionScoped, a CDI scope
public class PropertyGroupsBB extends BackingBeanUtils implements Serializable { ... }
```

The other two CDI session beans are `FileImportBB` and `SessionPropertyConductor`.

`WEB-INF/beans.xml` is what turns CDI on for the whole WAR:

```xml
<beans ... bean-discovery-mode="all" version="3.0"> </beans>
```

### 4.2 The comparison that matters

| | **faces-config.xml managed bean** | **CDI bean (`@Named` + scope)** |
|---|---|---|
| Declared in | XML (`<managed-bean>`) | annotations on the class |
| Instantiated by | Faces' own managed-bean facility | Weld |
| Session storage | **session-map entry named after the bean** | Weld's own session-map keys (`WELD_S#…`) |
| `sessionMap.remove("name")` | **works**: next EL access builds a fresh instance | **does not reliably reach it**; the Weld bean store is not keyed by name |
| `@PostConstruct` | runs on each fresh instance | runs **once per contextual instance**, not on a name removal |
| What `#{name}` returns | the object itself | a **client proxy** that forwards to the contextual instance (creating it if absent) |
| Wiring dependencies | facility-specific; we look beans up through EL (`BackingBeanUtils`) instead | `@Inject` is the standard mechanism |
| Future | **removed in Jakarta Faces 4.0** | the platform's only bean model |

Three consequences worth tattooing somewhere:

1. **Phase 2 of our flush is a name-based `sessionMap.remove`.** It is correct for style A and
   blind to style B. The session-map categorizer in `SessionManagementUtils` even *keeps* keys it
   cannot classify (`UNKNOWN`), and a `WELD_S#…` key matches none of our name patterns.
2. **A CDI bean is created lazily, through a proxy, and keeps its fields until the session
   ends.** `@PostConstruct` is *not* a "new muni" hook for it. This is the entire PGRP.1 bug.
3. **`bean-discovery-mode="all"` makes every class in the WAR a CDI bean candidate**, including
   classes we registered in `faces-config.xml` (they become `@Dependent` CDI beans). We resolve
   those through EL, so it is harmless today, but `@Inject SessionBean` would hand you a *fresh,
   unrelated instance*, not the session's. Inject only things that are CDI-scoped on purpose.

### 4.3 `@ViewScoped` is CDI too

The older note on [CDI Implementation notes](/dev/jsf/cdi) says `@ViewScoped` is "NOT pure CDI".
More precisely: `jakarta.faces.view.ViewScoped` is a **CDI scope defined by the Faces spec**
(its javadoc: `@NormalScope(passivating=true)`), activated for any `@Named` bean that carries it.
The nine `@Named @ViewScoped` classes in the codebase (for example `PublicFormSubmitBB`,
`MuniContactBB`) are CDI beans; the 74 view-scoped `faces-config.xml` beans are *not*. Same word,
different engine.

### 4.4 Where we are headed

> 📅 **Planned.** The platform plan targets WildFly 40 / Jakarta EE 10. Jakarta Faces 4.0 removes
> the managed-bean facility, so all 132 `faces-config.xml` beans must become CDI beans. That
> migration makes the PGRP.1 lesson *universal*: every session-scoped bean will be a Weld bean,
> and name-based Phase 2 cleanup will stop working for all of them. Phase 1 style explicit
> clearing (or a single structural replacement, section 7) is the survivor. See
> [Faces issue #1547, "Remove native managed bean support"](https://github.com/jakartaee/faces/issues/1547).

---

## 5. Worked example: the PGRP.1 bug, end to end

**Symptom.** In muni X, open Property Groups, load groups, queue some properties. Switch to muni R
through *Change muni → Go*. The panel still shows muni X's groups and queue.

### 5.1 Why every existing flush missed it

`PropertyGroupsBB` is a **style B** bean. Walk it through section 3.1:

| Step | What happened to `PropertyGroupsBB` |
|---|---|
| `SessionBean.clearSessionForMuniChange()` | irrelevant: it clears *SessionBean's* fields |
| Phase 1, the ten `Session*Conductor.clearSessionForMuniChange()` calls | not in the list |
| Phase 2, `sessionMap.remove("propertyGroupsBB")` | no entry has that name: Weld keyed it differently |
| Next page load | the proxy hands back the *same* instance; `@PostConstruct` does not re-run |

The name `"propertyGroupsBB"` did appear in the `KNOWN_SESSION_SCOPED_BEANS` set and in the
`CDI_BEANS` category of `SessionManagementUtils`, which *looked* like coverage. Both are name
lists feeding a name-based removal, so they could never have reached a Weld-owned bean.

### 5.2 The fix, in three parts (as built)

**Part 1: give the bean a clear method and call it from Phase 1.**

```java
// PropertyGroupsBB
public void clearSessionForMuniChange(){
    currentPropertyGroup = null;
    selectedPropertyGroup = null;
    propertyGroupList = null;
    queuedPropertyList = new ArrayList<>();
    showQueueForGroupingLink = false;
}
```

```java
// SessionConductor.clearConductorStateBeforeMapRemoval()
// Each CDI bean gets its OWN try/catch so one failure cannot skip the other.
try {
    getPropertyGroupsBBForFlush().clearSessionForMuniChange();
} catch (Exception e) { /* log and continue */ }

private PropertyGroupsBB getPropertyGroupsBBForFlush() {
    FacesContext context = getFacesContext();
    return context.getApplication()
            .evaluateExpressionGet(context, "#{propertyGroupsBB}", PropertyGroupsBB.class);
}
```

`#{propertyGroupsBB}` resolves through the CDI EL resolver to a **client proxy**. Calling a
method on it reaches the real session instance (or creates one if this session never opened the
page). `FileImportBB` had the identical hole and got the identical treatment.

**Part 2: make the bean tolerate being created mid-switch, and re-seed lazily.**

The proxy call in Part 1 can *instantiate* the bean in the middle of the switch, at which point
`SessionBean` has just been nulled. The old `@PostConstruct` called `refreshPropertyGroupList()`
(a DB read against the session muni) and would have failed. So:

```java
@PostConstruct
public void initBean(){
    showQueueForGroupingLink = false;   // no DB work, never reads SessionBean
}

// Managed getter (BB Rule 4's one sanctioned exception to "pure getters")
public List<PropertyGroupPropertyListHeavy> getManagedPropertyGroupList() {
    if(propertyGroupList == null && getSessionBean().getSessMuni() != null){
        refreshPropertyGroupList();
        if(propertyGroupList == null){
            propertyGroupList = new ArrayList<>();   // do not retry on every EL evaluation
        }
    }
    return propertyGroupList;
}
```

`propertyGroups.xhtml` and `propInfoCC.xhtml` now bind to `#{propertyGroupsBB.managedPropertyGroupList}`.
After a clear the list is `null`, so the **first render in the new muni** loads that muni's groups.

**Part 3: a fence in the Coordinator, so a stale bean can never write across munis.**

Parts 1 and 2 fix the UI. They do not stop a bean that is stale *for any other reason* from
saving muni X's group while the user governs muni R. Per BB Rule 8, permission logic lives in the
Coordinator, once, exposed twice:

```java
// PropertyCoordinator
public boolean permissionCheckpointEnforceMuniGroupFenceIsViewEditAllowed(UserAuthorized ua, PropertyGroup grp){
    if(ua == null || grp == null || grp.getMuni() == null
            || ua.getKeyCard() == null
            || ua.getKeyCard().getGoverningAuthPeriod() == null
            || ua.getKeyCard().getGoverningAuthPeriod().getMuni() == null){
        return false;
    }
    return ua.getKeyCard().getGoverningAuthPeriod().getMuni().getMuniCode() == grp.getMuni().getMuniCode();
}

private void parcelGroup_verifyMuniFence(UserAuthorized ua, PropertyGroup grp) throws AuthorizationException {
    if(!permissionCheckpointEnforceMuniGroupFenceIsViewEditAllowed(ua, grp)){
        throw new AuthorizationException("User is not allowed to change a parcel group outside their governing muni");
    }
}
```

`parcelGroup_verifyMuniFence` is the first thing `insertParcelGroup`, `updateParcelGroup`,
`deactivateParcelGroup`, `linkParcelToParcelGroup` and `removeParcelFromParcelGroup` do after
their null checks. The BB never trusts its own UI to be the gate. `PropertyGroupMuniFenceTest`
pins the rule (same muni allowed; other muni, null user/group/muni/keycard all denied).

### 5.3 The lesson, stated once

> A name-based `sessionMap.remove(...)` is a **faces-config** tool. For a **CDI** session bean
> the only supported "reset" is for the bean to reset *itself* (an explicit clear method that
> Phase 1 calls) and for its `@PostConstruct` to be cheap and muni-agnostic, with muni-bound data
> loaded lazily through a `getManagedXxx` getter. The only thing that fully destroys a CDI session
> bean is the whole session ending (`HttpSession.invalidate()`, the Weld `destroy(HttpSession)` path).

### 5.4 What the log showed after the fix (26 Oct 2026)

After the fix, one muni switch (COG Land to East McKeesport) produced a dump that settles the
open question and teaches two more lessons. Abridged excerpt of the `SESSION STATE BEFORE CLEANUP`
block (other framework keys omitted):

```text
Uncategorized:
  - WELD_S_HASH
  - org.jboss.weld.context.beanstore.http.LockStore
  - WELD_S#1
  - letterSearchBB
  - ...
```

1. **Confirmed: Weld keys CDI session beans as `WELD_S#<n>`**, and Phase 2 keeps them because they
   are `UNKNOWN`. A CDI bean is reachable only through its own `clearSessionForMuniChange()`.
2. **Counting objects shows the flush ran.** The session map held 20 objects before Phase 1 and 27
   after. The seven extras are five shell conductors plus the two CDI beans (`SessionPropertyConductor`,
   `FileImportBB`) that Phase 1's proxy call created. So `PropertyGroupsBB` was already there as
   `WELD_S#1`. Good evidence, but indirect: the flush itself printed nothing, so both clear
   methods now log a line.
3. **The same dump exposed a leak the fix had not covered.** `letterSearchBB` is a *faces-config*
   session bean, so Phase 2 *could* remove it, but its name was in no category pattern, so it was
   `UNKNOWN` and kept. Auditing `faces-config.xml` found four more of the same kind
   (`workflowMonitorBB`, `printStyleManagerBB`, `letterStyleManagerBB`,
   `letterDistributionRuleManagerBB`). All five cache muni-scoped lists until the user reloads them.
   They now sit in `SessionObjectCategory.MUNI_SCOPED_BEANS`. The lesson: **a faces-config session
   bean in no name list leaks exactly like a CDI one**; the hand-maintained list is the weak point.

---

## 6. Debugging toolkit

`MissionControlBB.reauthenticateWithFullReports()` already prints three blocks to the server log
on every muni switch. Learn to read them:

| Log block | What it tells you |
|---|---|
| `SESSION STATE BEFORE CLEANUP` | every session-map key, bucketed by category |
| `SESSION CLEANUP DRY RUN` | what Phase 2 *would* remove (anything categorized `UNKNOWN` or `JSF_INFRASTRUCTURE` is kept) |
| `ACTUAL CLEARING` | Phase 1 then Phase 2 execution; Phase 1 now ends with "SessionBean + all 10 conductors + 2 CDI backing beans processed" |

**Diagnostic recipe for "stale data after a muni switch":**

1. Is the stale thing in a bean? Find its scope: `grep` the bean in `faces-config.xml`
   (style A) and for `@Named`/`@SessionScoped` (style B).
2. Style A: is its name in a `SessionObjectCategory` pattern list in `SessionManagementUtils`
   (for example `MUNI_SCOPED_BEANS`)? Phase 2 removes only keys that fall in a category. A name in
   no category is `UNKNOWN` and is **kept**, which is how `letterSearchBB` leaked. (The
   `KNOWN_SESSION_SCOPED_BEANS` set only feeds the legacy fallback cleanup and the basic report.)
3. Style B? Is it called from `clearConductorStateBeforeMapRemoval()`? If not, it leaks.
4. Does its `@PostConstruct` read `SessionBean` or the DB? If so it will misbehave when Phase 1
   instantiates it.
5. Is a muni-bound list read through a plain getter that was seeded once? Move it to a
   `getManaged…` lazy getter.

> ✅ **Confirmed in our logs (26 Oct 2026).** The `WELD_S#…` key shape was observed in a live
> WildFly dump: `WELD_S#1` sits in the Uncategorized bucket and is not in the dry-run removal list
> (section 5.4). The May 2026 log lacked it only because no CDI session bean had been created yet.

---

## 7. Checklist: adding a new session-scoped bean

- [ ] **Do you need session scope at all?** Prefer `@ViewScoped` for page state; session scope is
      for things that must survive navigation (the conductors, `SessionBean`).
- [ ] **CDI (`@Named` + `@SessionScoped`)** for anything new. It is the only model that survives
      Jakarta EE 10 (section 4.4).
- [ ] Add `public void clearSessionForMuniChange()` that nulls **every** muni-bound field.
- [ ] Call it from `SessionConductor.clearConductorStateBeforeMapRemoval()` in **its own
      `try/catch`**, resolving the bean through `evaluateExpressionGet` like the others.
- [ ] Keep `@PostConstruct` free of DB work and `SessionBean` reads.
- [ ] Load muni-bound data through a `getManagedXxx` lazy getter; keep every other getter pure.
- [ ] Put the muni fence in the **Coordinator**, re-checked inside every mutating method.
- [ ] If you must use `faces-config.xml` (legacy), add the bean name to a `SessionObjectCategory`
      pattern list in `SessionManagementUtils` (Phase 2 only removes categorized keys) and to
      `KNOWN_SESSION_SCOPED_BEANS` (legacy fallback and report).

> 📅 **Planned.** Backlog item #6 (recommendation c) proposes an `IFaceSessionClearable`
> interface so Phase 1 can discover and clear every session bean generically (for example via
> CDI `Instance<IFaceSessionClearable>`), replacing the hand-maintained list above. Not built yet.

---

## 8. Known gaps (honest list)

- **Hand-maintained Phase 1.** Forgetting a new bean silently reintroduces PGRP.1; that is what
  `IFaceSessionClearable` would remove.
- **Hand-maintained Phase 2 name lists.** A faces-config session bean in no category is kept
  (found 26 Oct 2026: five beans, now in `MUNI_SCOPED_BEANS`). Same failure mode, same structural fix.
- **Shared `try/catch` in Phase 1.** The ten conductor clears sit in one `try` block even though
  the Javadoc promises per-conductor isolation, so one throw skips the rest. Pre-existing and
  not changed by PGRP.1.
- **Unfenced group reads.** `getParcelGroupParcelHeavy(int)` takes no `UserAuthorized`, so the
  group-muni fence guards writes only. Read-side fencing needs a signature change.
- **Server-side auth config is outside the repo.** The user store behind
  `rolescnfApplicationDomain` is documented nowhere in this codebase.

---

## 9. Official documentation and further reading

**Specifications (the versions we run: Jakarta EE 9.1)**

- Jakarta EE Platform 9.1: <https://jakarta.ee/specifications/platform/9.1/>
- Jakarta Servlet 5.0 spec (sessions, `login-config`, `security-constraint`): <https://jakarta.ee/specifications/servlet/5.0/jakarta-servlet-spec-5.0.html>
- Jakarta Contexts and Dependency Injection 3.0 spec (scopes, contexts, client proxies, discovery modes): <https://jakarta.ee/specifications/cdi/3.0/jakarta-cdi-spec-3.0.html>
- Jakarta Faces 3.0 spec: <https://jakarta.ee/specifications/faces/3.0/jakarta-faces-3.0.html>
- Jakarta Security 2.0 (the modern authentication API, for context): <https://jakarta.ee/specifications/security/2.0/>

**API docs we cite above**

- `HttpSession`: <https://jakarta.ee/specifications/servlet/5.0/apidocs/jakarta/servlet/http/HttpSession.html>
- `HttpServletRequest` (`getRemoteUser`, `logout`): <https://jakarta.ee/specifications/servlet/5.0/apidocs/jakarta/servlet/http/HttpServletRequest.html>
- CDI `@SessionScoped`: <https://jakarta.ee/specifications/cdi/3.0/apidocs/jakarta/enterprise/context/SessionScoped.html>
- Faces `@ViewScoped`: <https://jakarta.ee/specifications/faces/3.0/apidocs/jakarta/faces/view/ViewScoped.html>

**Server and implementation docs**

- Weld reference guide (4.0, scopes and contexts): <https://docs.jboss.org/weld/reference/4.0.0.Final/en-US/html/scopescontexts.html>
- Weld source, the session context discussed in section 3: <https://github.com/weld/core/blob/4.0.3.Final/modules/web/src/main/java/org/jboss/weld/module/web/context/http/HttpSessionContextImpl.java>
- WildFly 26.1 documentation home: <https://docs.wildfly.org/26.1/>
- WildFly Elytron security (authentication mechanisms, security domains): <https://docs.wildfly.org/26.1/WildFly_Elytron_Security.html>
- Undertow (WildFly's web server): <https://undertow.io/>

**Where the platform is going**

- Jakarta EE 10: <https://jakarta.ee/specifications/platform/10/>
- Jakarta Faces 4.0: <https://jakarta.ee/specifications/faces/4.0/>
- Removal of Faces managed beans: <https://github.com/jakartaee/faces/issues/1547>

**Session-security background (general, not WildFly-specific)**

- OWASP Session Management Cheat Sheet: <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>
- NIST SP 800-63B, Digital Identity Guidelines (authentication and session management): <https://pages.nist.gov/800-63-3/sp800-63b.html>

**In this wiki**

- [CDI Implementation notes](/dev/jsf/cdi): import paths and annotation cheat sheet
- [Session Sync Notes](/dev/architecture/sessionsync): ideas for keeping session objects in step with each other
- [Subsystem registry](/system/subsystem-registry): the `session` (X1) entry that owns this page
