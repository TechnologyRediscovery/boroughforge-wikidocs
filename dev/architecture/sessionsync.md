---
title: Session Sync Notes
description: AI Generated ideas for session synchronization using visitor pattern
published: true
date: 2025-12-01T00:43:53.653Z
tags: 
editor: markdown
dateCreated: 2025-12-01T00:43:47.468Z
---

# Session Synchronization Architecture Upgrade
**Date:** November 30, 2025  
**Status:** Planning Phase - Major Surgery Required  
**Estimated Effort:** 1-2 weeks full implementation

---

## 🎯 Executive Summary

The current `SessionBean.navigateToPageCorrespondingToObject()` is a 500+ line procedural mess handling session object coordination. This document outlines a refactor using **Visitor Pattern + Strategy Pattern + CDI Events** to create a maintainable, extensible architecture.

**Current State:** One giant method with if/else spaghetti  
**Target State:** Distributed conductors coordinating via visitor pattern + events  
**Migration:** Not gradual-friendly - requires focused implementation period

---

## 🏗️ Current Architecture Problems

### Problem 1: Procedural Coordination
```java
// SessionBean.navigateToPageCorrespondingToObject() - 500+ lines!
if (bob instanceof Property prop) {
    // 50 lines of property coordination logic
    sessProperty = pdh;
    sessPersonList = perc.getPersonListFromHumanLinkList(pdh.gethumanLinkList());
    sessCECaseList = cc.cecase_upcastCECaseDataHeavyList(sessProperty.getCeCaseList());
    // ... 30 more lines
    
} else if (bob instanceof CECase cse) {
    // 50 lines of case coordination logic
    sessCECase = csedh;
    sessProperty = pc.assemblePropertyDataHeavy(pc.getProperty(cse.getParcelKey()), ua);
    synchronizeOccPeriodAndPersonsFromSessProperty();
    // ... 20 more lines
    
} else if (bob instanceof Person) {
    // Person logic
} else if (bob instanceof OccPeriod) {
    // Period logic
}
// ... etc for 10+ types
```

**Issues:**
- SessionBean knows everything about every domain
- No separation of concerns
- Difficult to test individual sync logic
- Hard to add new object types
- Fragile to changes

### Problem 2: Incomplete Visitor Pattern
```java
// Skeleton exists but only ONE conductor implements it!
SessionOccupancyConductor ✅ - Fully implements visitor
SessionPersonConductor ❌ - Doesn't implement interfaces
SessionCodeConductor ❌ - Doesn't implement interfaces
SessionInspectionConductor ❌ - Doesn't participate
```

### Problem 3: Mixed Synchronization Strategies
Three different sync mechanisms fighting each other:
1. Visitor pattern loop (lines 718-723)
2. Manual `synchronizeOccPeriodAndPersonsFromSessProperty()` (line 916)
3. Direct `getSessionConductor().synchronizeSessionObjects()` (line 925)

---

## 🎓 Pattern Fundamentals

### Visitor Pattern - Core Concept

**Purpose:** Separate operations from the objects they operate on.

**The Double Dispatch Magic:**
```java
// Normal method call (SINGLE dispatch) - loses type info:
conductor.synchronize(sessionObject);
// Problem: If sessionObject is declared as interface, Java picks
// method based on COMPILE-TIME type, not runtime type

// Visitor pattern (DOUBLE dispatch) - preserves type info:
sessionObject.accept(conductor);  // Step 1: Call accept() on ACTUAL runtime type

// Inside PropertyDataHeavy.accept():
@Override
public void accept(IFaceSessionSyncVisitor visitor) {
    visitor.visit(this);  // Step 2: 'this' is PropertyDataHeavy
}
// Java now picks visit(PropertyDataHeavy) overload
```

**Why This Matters:**
Your conductors need to know "Is this a Property? Case? Person?" to sync correctly. Double dispatch gives them that info with compile-time safety.

### Strategy Pattern - Core Concept

**Purpose:** Define a family of algorithms, encapsulate each one, make them interchangeable.

**In Your Context:**
Each conductor IS a strategy for handling its domain:
```java
SessionOccupancyConductor    = "Occupancy synchronization strategy"
SessionPersonConductor        = "Person synchronization strategy"
SessionCodeConductor          = "Code book synchronization strategy"
```

**Strategy Selection:** Automatic via visitor double dispatch - no if/else needed!

---

## 🏛️ Target Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│  USER ACTION: View Property 123                         │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  SessionBean.navigateToPageCorrespondingToObject()     │
│  • Receives: PropertyDataHeavy                          │
│  • Knows: "This is a SessionSyncTarget"                │
│  • Action: Loop through registered conductors          │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ SYNCHRONOUS PHASE (Visitor Pattern)
                 │
                 ├──► target.accept(SessionOccupancyConductor)
                 │    └─► visit(PropertyDataHeavy)
                 │         → Set sessOccPeriod to first period on property
                 │
                 ├──► target.accept(SessionPersonConductor)
                 │    └─► visit(PropertyDataHeavy)
                 │         → Set sessPerson to first person on property
                 │
                 ├──► target.accept(SessionCodeConductor)
                 │    └─► visit(PropertyDataHeavy)
                 │         → No-op (code doesn't sync to properties)
                 │
                 └──► target.accept(SessionInspectionConductor)
                      └─► visit(PropertyDataHeavy)
                           → Set sessInspectable to property
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  ASYNCHRONOUS PHASE (CDI Events)                       │
│  focusChangeEvent.fire(new SessionFocusChangedEvent()) │
│                                                          │
│  Observers (independent, any order):                    │
│  • AuditLogger: Log "User viewed Property 123"         │
│  • CacheManager: Invalidate stale object caches        │
│  • MetricsCollector: Record property view count        │
│  • UIRefresher: Update breadcrumb component             │
└─────────────────────────────────────────────────────────┘
```

### Interface Structure

```java
/**
 * Marks objects that can become session focus and need coordination
 */
public interface IFaceSessionSyncTarget {
    void accept(IFaceSessionSyncVisitor visitor);
}

/**
 * Visitor interface - defines operations on all session types
 */
public interface IFaceSessionSyncVisitor {
    void visit(PropertyDataHeavy pdh);
    void visit(CECaseDataHeavy csedh);
    void visit(OccPeriodDataHeavy opdh);
    void visit(OccPermit permit);
    void visit(Person p);
}

/**
 * Strategy interface - conductors that need to sync to focus changes
 */
public interface IFaceSessionSynchronizer {
    void synchronizeToSessionFocusObject(IFaceSessionSyncTarget target);
}
```

### Domain Object Implementation

```java
public class PropertyDataHeavy 
    extends Property 
    implements IFaceSessionSyncTarget {
    
    @Override
    public void accept(IFaceSessionSyncVisitor visitor) {
        visitor.visit(this);  // Double dispatch - pass actual type
    }
}

public class CECaseDataHeavy 
    extends CECase 
    implements IFaceSessionSyncTarget {
    
    @Override
    public void accept(IFaceSessionSyncVisitor visitor) {
        visitor.visit(this);
    }
}

// Same pattern for: OccPeriodDataHeavy, Person, OccPermit
```

---

## 🔧 Implementation Guide

### Phase 1: Complete Visitor Pattern

#### Step 1: Fix OccPermit Type Mismatch

```java
// CURRENT: OccPermit is in visitor interface but doesn't implement target
public interface IFaceSessionSyncVisitor {
    void visit(OccPermit permit);  // ← OccPermit here
}

public class OccPermit {
    // ← NOT implementing IFaceSessionSyncTarget!
}

// FIX: Add interface and accept method
public class OccPermit implements IFaceSessionSyncTarget {
    
    @Override
    public void accept(IFaceSessionSyncVisitor visitor) {
        visitor.visit(this);
    }
}
```

#### Step 2: Implement SessionPersonConductor as Visitor

```java
@Named("sessionPersonConductor")
@SessionScoped
public class SessionPersonConductor 
    implements IFaceSessionSynchronizer, 
               IFaceSessionSyncVisitor, 
               Serializable {
    
    // CDI Event injection (for Phase 2)
    @Inject
    private Event<HumanLinkListChangedEvent> humanLinkChangeEvent;
    
    // Session members
    private Person sessPerson;
    private IFace_humanListHolder sessHumanListHolder;
    private HumanLink sessHumanLink;
    private List<HumanLink> sessHumanListRefreshedList;
    private Person sessPersonQueued;
    private List<Person> sessPersonList;
    private boolean onPageLoad_sessionSwitch_viewProfile;
    private boolean certPersonQuickAddNewPersonPathway;
    private QueryPerson queryPerson;
    private List<QueryPerson> queryPersonList;
    private String personNameForSearch;
    
    @PostConstruct
    public void initBean() {
        System.out.println("SessionPersonConductor.initBean");
        
        // CRITICAL: Register with SessionBean
        getSessionBean().registerSessionSynchronizer(this);
    }
    
    /**
     * Entry point for visitor pattern - called by SessionBean
     */
    @Override
    public void synchronizeToSessionFocusObject(IFaceSessionSyncTarget target) {
        System.out.println("SessionPersonConductor.synchronizeToSessionFocusObject");
        if(target != null) {
            target.accept(this);  // Trigger double dispatch
        }
    }
    
    /**
     * STRATEGY: When property becomes focus, set sessPerson to first linked person
     */
    @Override
    public void visit(PropertyDataHeavy pdh) {
        System.out.println("SessionPersonConductor.visit(PropertyDataHeavy) | ID: " + pdh.getPropertyID());
        
        // Extract person list from property
        if(pdh.gethumanLinkList() != null && !pdh.gethumanLinkList().isEmpty()) {
            try {
                PersonCoordinator pc = getPersonCoordinator();
                sessPersonList = pc.getPersonListFromHumanLinkList(pdh.gethumanLinkList());
                
                // Set first person as session person
                if(sessPersonList != null && !sessPersonList.isEmpty()) {
                    sessPerson = pc.getPerson(sessPersonList.get(0));
                    System.out.println("  → Set sessPerson to: " + sessPerson.getName());
                } else {
                    sessPerson = null;
                    System.out.println("  → No persons on property, cleared sessPerson");
                }
            } catch (IntegrationException | BObStatusException ex) {
                System.out.println("SessionPersonConductor.visit(PropertyDataHeavy) error: " + ex);
            }
        } else {
            // No persons on property
            sessPerson = null;
            sessPersonList = new ArrayList<>();
            System.out.println("  → Property has no human links");
        }
    }
    
    /**
     * STRATEGY: When case becomes focus, set sessPerson to first linked person
     */
    @Override
    public void visit(CECaseDataHeavy csedh) {
        System.out.println("SessionPersonConductor.visit(CECaseDataHeavy) | ID: " + csedh.getCaseID());
        
        // Extract person list from case
        if(csedh.gethumanLinkList() != null && !csedh.gethumanLinkList().isEmpty()) {
            try {
                PersonCoordinator pc = getPersonCoordinator();
                sessPersonList = pc.getPersonListFromHumanLinkList(csedh.gethumanLinkList());
                
                if(sessPersonList != null && !sessPersonList.isEmpty()) {
                    sessPerson = pc.getPerson(sessPersonList.get(0));
                    System.out.println("  → Set sessPerson to: " + sessPerson.getName());
                } else {
                    sessPerson = null;
                }
            } catch (IntegrationException | BObStatusException ex) {
                System.out.println("SessionPersonConductor.visit(CECaseDataHeavy) error: " + ex);
            }
        } else {
            sessPerson = null;
            sessPersonList = new ArrayList<>();
        }
    }
    
    /**
     * STRATEGY: When period becomes focus, set sessPerson from period's human links
     */
    @Override
    public void visit(OccPeriodDataHeavy opdh) {
        System.out.println("SessionPersonConductor.visit(OccPeriodDataHeavy) | ID: " + opdh.getPeriodID());
        
        if(opdh.gethumanLinkList() != null && !opdh.gethumanLinkList().isEmpty()) {
            try {
                PersonCoordinator pc = getPersonCoordinator();
                sessPersonList = pc.getPersonListFromHumanLinkList(opdh.gethumanLinkList());
                
                if(sessPersonList != null && !sessPersonList.isEmpty()) {
                    sessPerson = pc.getPerson(sessPersonList.get(0));
                    System.out.println("  → Set sessPerson to: " + sessPerson.getName());
                } else {
                    sessPerson = null;
                }
            } catch (IntegrationException | BObStatusException ex) {
                System.out.println("SessionPersonConductor.visit(OccPeriodDataHeavy) error: " + ex);
            }
        } else {
            sessPerson = null;
            sessPersonList = new ArrayList<>();
        }
    }
    
    /**
     * STRATEGY: When permit becomes focus, inherit from parent period
     */
    @Override
    public void visit(OccPermit permit) {
        System.out.println("SessionPersonConductor.visit(OccPermit) | ID: " + permit.getPermitID());
        
        // Get period and use its person list
        try {
            OccupancyCoordinator oc = getOccupancyCoordinator();
            OccPeriodDataHeavy opdh = oc.assembleOccPeriodDataHeavy(
                oc.getOccPeriod(permit.getPeriodID(), getSessionBean().getSessUser()),
                getSessionBean().getSessUser()
            );
            
            // Delegate to period visit logic
            visit(opdh);
            
        } catch (IntegrationException | BObStatusException ex) {
            System.out.println("SessionPersonConductor.visit(OccPermit) error: " + ex);
            sessPerson = null;
            sessPersonList = new ArrayList<>();
        }
    }
    
    /**
     * STRATEGY: When person becomes focus, just set it directly
     */
    @Override
    public void visit(Person p) {
        System.out.println("SessionPersonConductor.visit(Person) | ID: " + p.getPersonID());
        
        try {
            PersonCoordinator pc = getPersonCoordinator();
            sessPerson = pc.getPerson(p);
            System.out.println("  → Set sessPerson to: " + sessPerson.getName());
            
            // Person list contains just this person
            sessPersonList = new ArrayList<>();
            sessPersonList.add(sessPerson);
            
        } catch (IntegrationException | BObStatusException ex) {
            System.out.println("SessionPersonConductor.visit(Person) error: " + ex);
            sessPerson = p;  // Fallback to passed person
        }
    }
    
    /**
     * Public activation method - used by backing beans
     */
    public void activateSessionPerson(Person pers) {
        if(pers != null) {
            sessPerson = pers;
            System.out.println("SessionPersonConductor.activateSessionPerson | activated person ID: " + pers.getPersonID());
        } else {
            System.out.println("SessionPersonConductor.activateSessionPerson | ERROR null person activated");
        }
    }
    
    // ... getters/setters omitted for brevity
}
```

#### Step 3: Implement SessionCodeConductor

```java
@Named("sessionCodeConductor")
@SessionScoped
public class SessionCodeConductor 
    implements IFaceSessionSynchronizer, 
               IFaceSessionSyncVisitor, 
               Serializable {
    
    // Session members for code book management
    private CodeSet sessCodeSet;
    private CodeSource sessCodeSource;
    private List<CodeElementGuideEntry> sessCodeGuideList;
    
    @PostConstruct
    public void initBean() {
        System.out.println("SessionCodeConductor.initBean");
        
        // CRITICAL: Register with SessionBean
        getSessionBean().registerSessionSynchronizer(this);
    }
    
    @Override
    public void synchronizeToSessionFocusObject(IFaceSessionSyncTarget target) {
        System.out.println("SessionCodeConductor.synchronizeToSessionFocusObject");
        if(target != null) {
            target.accept(this);
        }
    }
    
    /**
     * STRATEGY: Properties don't affect code book - no-op
     */
    @Override
    public void visit(PropertyDataHeavy pdh) {
        System.out.println("SessionCodeConductor.visit(PropertyDataHeavy) | No action");
        // Properties don't influence which code book we're viewing
    }
    
    /**
     * STRATEGY: Cases might need case-specific code set
     */
    @Override
    public void visit(CECaseDataHeavy csedh) {
        System.out.println("SessionCodeConductor.visit(CECaseDataHeavy) | ID: " + csedh.getCaseID());
        
        // If case has a specific code set, activate it
        // Otherwise leave current code set alone
        if(csedh.getCodeSet() != null) {
            sessCodeSet = csedh.getCodeSet();
            System.out.println("  → Activated case's code set: " + sessCodeSet.getCodeSetID());
        }
    }
    
    /**
     * STRATEGY: Periods don't affect code book - no-op
     */
    @Override
    public void visit(OccPeriodDataHeavy opdh) {
        System.out.println("SessionCodeConductor.visit(OccPeriodDataHeavy) | No action");
    }
    
    /**
     * STRATEGY: Permits don't affect code book - no-op
     */
    @Override
    public void visit(OccPermit permit) {
        System.out.println("SessionCodeConductor.visit(OccPermit) | No action");
    }
    
    /**
     * STRATEGY: Persons don't affect code book - no-op
     */
    @Override
    public void visit(Person p) {
        System.out.println("SessionCodeConductor.visit(Person) | No action");
    }
    
    // ... getters/setters
}
```

#### Step 4: Implement SessionInspectionConductor

```java
@Named("sessionInspectionConductor")
@SessionScoped
public class SessionInspectionConductor 
    extends BackingBeanUtils
    implements IFaceSessionSynchronizer, 
               IFaceSessionSyncVisitor, 
               Serializable {
    
    // Session inspectable
    private IFace_inspectable sessInspectable;
    private OccInspection sessInspection;
    
    @PostConstruct
    public void initBean() {
        System.out.println("SessionInspectionConductor.initBean");
        
        // CRITICAL: Register with SessionBean
        getSessionBean().registerSessionSynchronizer(this);
    }
    
    @Override
    public void synchronizeToSessionFocusObject(IFaceSessionSyncTarget target) {
        System.out.println("SessionInspectionConductor.synchronizeToSessionFocusObject");
        if(target != null) {
            target.accept(this);
        }
    }
    
    /**
     * STRATEGY: Properties are inspectable - set as sessInspectable
     */
    @Override
    public void visit(PropertyDataHeavy pdh) {
        System.out.println("SessionInspectionConductor.visit(PropertyDataHeavy)");
        // Properties can be inspected (for code enforcement)
        sessInspectable = pdh;
    }
    
    /**
     * STRATEGY: Cases are inspectable - set as sessInspectable
     */
    @Override
    public void visit(CECaseDataHeavy csedh) {
        System.out.println("SessionInspectionConductor.visit(CECaseDataHeavy)");
        sessInspectable = csedh;
        
        // Set most recent inspection if available
        if(csedh.getInspectionList() != null && !csedh.getInspectionList().isEmpty()) {
            sessInspection = csedh.getInspectionList().get(0);
        }
    }
    
    /**
     * STRATEGY: Periods are inspectable - set as sessInspectable
     */
    @Override
    public void visit(OccPeriodDataHeavy opdh) {
        System.out.println("SessionInspectionConductor.visit(OccPeriodDataHeavy)");
        sessInspectable = opdh;
        
        // Set most recent inspection
        if(opdh.getInspectionList() != null && !opdh.getInspectionList().isEmpty()) {
            sessInspection = opdh.getInspectionList().get(0);
        }
    }
    
    /**
     * STRATEGY: Permits aren't directly inspectable - inherit from period
     */
    @Override
    public void visit(OccPermit permit) {
        System.out.println("SessionInspectionConductor.visit(OccPermit)");
        // Get parent period and use it as inspectable
        try {
            OccupancyCoordinator oc = getOccupancyCoordinator();
            OccPeriodDataHeavy opdh = oc.assembleOccPeriodDataHeavy(
                oc.getOccPeriod(permit.getPeriodID(), getSessionBean().getSessUser()),
                getSessionBean().getSessUser()
            );
            visit(opdh);  // Delegate to period logic
        } catch (IntegrationException | BObStatusException ex) {
            System.out.println("SessionInspectionConductor.visit(OccPermit) error: " + ex);
        }
    }
    
    /**
     * STRATEGY: Persons aren't inspectable - clear
     */
    @Override
    public void visit(Person p) {
        System.out.println("SessionInspectionConductor.visit(Person)");
        sessInspectable = null;
        sessInspection = null;
    }
    
    /**
     * Legacy method - still used by some backing beans
     */
    public void registerSessionInspectable(IFace_inspectable inspectable) {
        this.sessInspectable = inspectable;
        if(inspectable != null) {
            System.out.println("SessionInspectionConductor.registerSessionInspectable | ID: " + 
                inspectable.getHostPK() + " domain: " + inspectable.getDomainEnum().getTitle());
        }
    }
    
    // ... getters/setters
}
```

#### Step 5: Update SessionBean Dispatch

```java
// In SessionBean.navigateToPageCorrespondingToObject()

public String navigateToPageCorrespondingToObject(IFaceActivatableBOB bob) 
    throws BObStatusException, AuthorizationException {
    
    UserAuthorized ua = getSessionBean().getSessUser();
    PropertyCoordinator pc = getPropertyCoordinator();
    PersonCoordinator perc = getPersonCoordinator();
    CaseCoordinator cc = getCaseCoordinator();
    
    // ***************************************************************** 
    // ***************** ACTIVATE THE SESSION CONDUCTORS ***************
    // ***************************************************************** 
    if(bob instanceof IFaceSessionSyncTarget target && 
       sessionSyncRegistry != null && 
       !sessionSyncRegistry.isEmpty()) {
        
        System.out.println("SessionBean.navigateToPageCorrespondingToObject | " +
            "Dispatching to " + sessionSyncRegistry.size() + " conductors");
        
        for(IFaceSessionSynchronizer syncer: sessionSyncRegistry) {
            try {
                syncer.synchronizeToSessionFocusObject(target);
            } catch (Exception ex) {
                // Log but continue - don't let one conductor failure kill others
                System.out.println("SessionBean | Conductor sync failed: " + ex);
                ex.printStackTrace();
            }
        }
    }
    
    // ************************************ 
    // ************* PROPERTY ************* 
    // ************************************ 
    if (bob instanceof Property prop) {
        PropertyDataHeavy pdh = pc.assemblePropertyDataHeavy(prop, ua);
        sessProperty = pdh;
        permCoor.enforceMuniViewFence(pdh, ua);
        
        // REMOVED: sessPersonList extraction - now in SessionPersonConductor
        // REMOVED: sessCECase coordination - stays here (not in conductor yet)
        
        // CE CASES on property
        sessCECaseList = cc.cecase_upcastCECaseDataHeavyList(sessProperty.getCeCaseList());
        if (sessCECaseList == null || sessCECaseList.isEmpty()) {
            sessCECase = null;
        } else {
            if (sessCECaseList != null && !sessCECaseList.isEmpty()) {
                setSessCECase(sessCECaseList.get(0));
            }
        }
        
        // REMOVED: synchronizeOccPeriodAndPersonsFromSessProperty() 
        //          - now handled by conductors
        
        // Events
        getSessionEventConductor().setSessEventsPageEventDomainRequest(EventRealm.PARCEL);
        
        // Blobs
        sessBlobHolder = sessProperty;
        
        // System switches
        sessionDomain = FocusedObjectEnum.PROPERTY;
        
    // ************************************ 
    // ************* PERSON *************** 
    // ************************************ 
    } else if (bob instanceof Person) {
        Person pers = perc.getPerson((Person) bob);
        
        // Use conductor's activation method
        sessionPersonConductor.activateSessionPerson(pers);
        
        // REMOVED: Manual person list setup - conductors handle it
        
        sessionDomain = FocusedObjectEnum.PERSON;
        
    // ************************************ 
    // ************* CE CASE ************** 
    // ************************************ 
    } else if (bob instanceof CECase cse) {
        cc.cecase_forceCaseCacheDump(cse);
        CECaseDataHeavy csedh = cc.cecase_assembleCECaseDataHeavy(
            cc.cecase_getCECase(cse.getCaseID(), ua), ua);
        
        sessCECase = csedh;
        permCoor.enforceMuniViewFence(csedh, ua);
        
        sessProperty = pc.assemblePropertyDataHeavy(
            pc.getProperty(cse.getParcelKey()), ua);
        
        // REMOVED: synchronizeOccPeriodAndPersonsFromSessProperty()
        //          - conductors handle it via visitor pattern
        
        getSessionEventConductor().setSessEventsPageEventDomainRequest(EventRealm.CODE_ENFORCEMENT);
        
        // REMOVED: getSessionInspectionConductor().registerSessionInspectable(sessCECase)
        //          - conductor does this via visitor
        
        sessBlobHolder = sessCECase;
        sessionDomain = FocusedObjectEnum.CECASE;
        
    // ... other types
    }
    
    return "";
}
```

---

### Phase 2: Add CDI Event Layer

#### Event Class

```java
package com.tcvcog.tcvce.entities.events;

import com.tcvcog.tcvce.entities.FocusedObjectEnum;
import com.tcvcog.tcvce.entities.IFaceSessionSyncTarget;
import com.tcvcog.tcvce.entities.UserAuthorized;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * CDI Event fired when session focus changes to a different primary object.
 * Used for cross-cutting concerns like audit logging, cache invalidation,
 * metrics collection, UI refresh triggers.
 * 
 * This event is fired AFTER visitor pattern completes, so all session
 * conductors have already synchronized to the new focus.
 * 
 * @author Ellen Bascomb of Apartment 31Y
 */
public class SessionFocusChangedEvent implements Serializable {
    
    private final IFaceSessionSyncTarget previousFocus;
    private final IFaceSessionSyncTarget newFocus;
    private final FocusedObjectEnum newFocusType;
    private final UserAuthorized performingUser;
    private final LocalDateTime timestamp;
    private final String navigationSource;  // e.g., "search", "link", "breadcrumb"
    
    /**
     * Full constructor
     */
    public SessionFocusChangedEvent(
            IFaceSessionSyncTarget previousFocus,
            IFaceSessionSyncTarget newFocus,
            FocusedObjectEnum newFocusType,
            UserAuthorized performingUser,
            String navigationSource) {
        
        this.previousFocus = previousFocus;
        this.newFocus = newFocus;
        this.newFocusType = newFocusType;
        this.performingUser = performingUser;
        this.navigationSource = navigationSource;
        this.timestamp = LocalDateTime.now();
    }
    
    /**
     * Simplified constructor - no previous focus
     */
    public SessionFocusChangedEvent(
            IFaceSessionSyncTarget newFocus,
            FocusedObjectEnum newFocusType,
            UserAuthorized performingUser) {
        
        this(null, newFocus, newFocusType, performingUser, "unknown");
    }
    
    // Convenience methods for observers
    
    public boolean isFocusTypeProperty() {
        return newFocusType == FocusedObjectEnum.PROPERTY;
    }
    
    public boolean isFocusTypeCase() {
        return newFocusType == FocusedObjectEnum.CECASE;
    }
    
    public boolean isFocusTypePerson() {
        return newFocusType == FocusedObjectEnum.PERSON;
    }
    
    public boolean hasPreviousFocus() {
        return previousFocus != null;
    }
    
    public int getNewFocusID() {
        if(newFocus != null) {
            return newFocus.getHostPK();
        }
        return 0;
    }
    
    public int getPreviousFocusID() {
        if(previousFocus != null) {
            return previousFocus.getHostPK();
        }
        return 0;
    }
    
    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        sb.append("SessionFocusChangedEvent{");
        sb.append("newFocus=").append(newFocusType);
        sb.append(", newFocusID=").append(getNewFocusID());
        if(hasPreviousFocus()) {
            sb.append(", previousFocusID=").append(getPreviousFocusID());
        }
        sb.append(", user=").append(performingUser != null ? performingUser.getUsername() : "null");
        sb.append(", source=").append(navigationSource);
        sb.append(", timestamp=").append(timestamp);
        sb.append('}');
        return sb.toString();
    }
    
    // Getters
    public IFaceSessionSyncTarget getPreviousFocus() { return previousFocus; }
    public IFaceSessionSyncTarget getNewFocus() { return newFocus; }
    public FocusedObjectEnum getNewFocusType() { return newFocusType; }
    public UserAuthorized getPerformingUser() { return performingUser; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public String getNavigationSource() { return navigationSource; }
}
```

#### Fire Event from SessionBean

```java
// In SessionBean
@Inject
private Event<SessionFocusChangedEvent> sessionFocusEvent;

// In navigateToPageCorrespondingToObject()
public String navigateToPageCorrespondingToObject(IFaceActivatableBOB bob) 
    throws BObStatusException, AuthorizationException {
    
    // ... existing code ...
    
    // Save previous focus for event
    IFaceSessionSyncTarget previousFocus = getCurrentSessionFocus();
    FocusedObjectEnum previousFocusType = sessionDomain;
    
    // ***************************************************************** 
    // ***************** ACTIVATE THE SESSION CONDUCTORS ***************
    // ***************************************************************** 
    if(bob instanceof IFaceSessionSyncTarget target) {
        
        // SYNCHRONOUS visitor pattern
        for(IFaceSessionSynchronizer syncer: sessionSyncRegistry) {
            syncer.synchronizeToSessionFocusObject(target);
        }
        
        // ASYNCHRONOUS CDI event (after conductors finish)
        try {
            sessionFocusEvent.fire(new SessionFocusChangedEvent(
                previousFocus,
                target,
                sessionDomain,  // Set by type-specific if/else below
                getSessUser(),
                "navigation"  // Could be dynamic based on caller
            ));
            System.out.println("SessionBean | Fired SessionFocusChangedEvent: " + 
                previousFocusType + " → " + sessionDomain);
        } catch (Exception ex) {
            // Don't let event firing failure kill navigation
            System.out.println("SessionBean | Event fire failed: " + ex);
        }
    }
    
    // ... rest of method
}

/**
 * Helper to get current session focus as IFaceSessionSyncTarget
 */
private IFaceSessionSyncTarget getCurrentSessionFocus() {
    switch(sessionDomain) {
        case PROPERTY:
            return sessProperty;
        case CECASE:
            return sessCECase;
        case PERSON:
            return sessionPersonConductor.getSessPerson();
        case OCC_PERIOD:
            return getSessionOccupancyConductor().getSessOccPeriod();
        default:
            return null;
    }
}
```

#### Example Observers

```java
/**
 * Audit logger - records all session focus changes
 */
@ApplicationScoped
public class SessionAuditLogger extends BackingBeanUtils {
    
    /**
     * Observer method - called automatically by CDI when event fires
     */
    public void onSessionFocusChanged(@Observes SessionFocusChangedEvent event) {
        System.out.println("SessionAuditLogger.onSessionFocusChanged | " + event);
        
        try {
            SystemCoordinator sc = getSystemCoordinator();
            
            // Log to database
            sc.logObjectView(
                event.getPerformingUser(),
                event.getNewFocusType().name(),
                event.getNewFocusID(),
                "Session focus changed from " + 
                    (event.hasPreviousFocus() ? 
                        event.getPreviousFocus().getClass().getSimpleName() : "none")
            );
            
        } catch (Exception ex) {
            System.out.println("SessionAuditLogger | Failed to log: " + ex);
        }
    }
}

/**
 * Cache manager - invalidates stale object caches when focus changes
 */
@ApplicationScoped
public class SessionCacheManager extends BackingBeanUtils {
    
    public void onSessionFocusChanged(@Observes SessionFocusChangedEvent event) {
        System.out.println("SessionCacheManager.onSessionFocusChanged");
        
        // When user leaves a property, schedule cache cleanup
        if(event.hasPreviousFocus() && 
           event.getPreviousFocus() instanceof PropertyDataHeavy oldProp) {
            
            System.out.println("  → Scheduling cache cleanup for property: " + 
                oldProp.getPropertyID());
            
            // Could schedule async cleanup after 5 minutes
            // For now, just log it
        }
        
        // When user views a case, invalidate case cache
        if(event.isFocusTypeCase()) {
            try {
                CaseCoordinator cc = getCaseCoordinator();
                cc.cecase_forceCaseCacheDump(event.getNewFocusID());
                System.out.println("  → Invalidated cache for case: " + 
                    event.getNewFocusID());
            } catch (Exception ex) {
                System.out.println("SessionCacheManager | Cache invalidation failed: " + ex);
            }
        }
    }
}

/**
 * Metrics collector - tracks which objects users view
 */
@ApplicationScoped
public class SessionMetricsCollector {
    
    private final Map<FocusedObjectEnum, AtomicLong> viewCounts = new ConcurrentHashMap<>();
    
    public void onSessionFocusChanged(@Observes SessionFocusChangedEvent event) {
        FocusedObjectEnum type = event.getNewFocusType();
        
        viewCounts.computeIfAbsent(type, k -> new AtomicLong(0))
                  .incrementAndGet();
        
        System.out.println("SessionMetricsCollector | " + type + 
            " views: " + viewCounts.get(type));
    }
    
    public Map<FocusedObjectEnum, Long> getViewCounts() {
        return viewCounts.entrySet().stream()
            .collect(Collectors.toMap(
                Map.Entry::getKey,
                e -> e.getValue().get()
            ));
    }
}
```

---

## 📋 Implementation Checklist

### Phase 1: Complete Visitor Pattern (1 week)

- [ ] **Fix OccPermit type mismatch**
  - [ ] Make OccPermit implement IFaceSessionSyncTarget
  - [ ] Add accept(IFaceSessionSyncVisitor) method
  - [ ] Test compilation

- [ ] **Implement SessionPersonConductor as visitor**
  - [ ] Add implements IFaceSessionSynchronizer, IFaceSessionSyncVisitor
  - [ ] Add registerSessionSynchronizer() call in @PostConstruct
  - [ ] Implement synchronizeToSessionFocusObject() entry point
  - [ ] Implement visit(PropertyDataHeavy) - extract first person
  - [ ] Implement visit(CECaseDataHeavy) - extract first person
  - [ ] Implement visit(OccPeriodDataHeavy) - extract first person
  - [ ] Implement visit(OccPermit) - delegate to period
  - [ ] Implement visit(Person) - just set directly
  - [ ] Test with property → person sync
  - [ ] Test with case → person sync

- [ ] **Implement SessionCodeConductor as visitor**
  - [ ] Add implements IFaceSessionSynchronizer, IFaceSessionSyncVisitor
  - [ ] Add registerSessionSynchronizer() call
  - [ ] Implement all 5 visit() methods (most will be no-ops)
  - [ ] Test code set activation with cases

- [ ] **Implement SessionInspectionConductor as visitor**
  - [ ] Add implements IFaceSessionSynchronizer, IFaceSessionSyncVisitor
  - [ ] Add registerSessionSynchronizer() call
  - [ ] Implement visit() methods for inspectable types
  - [ ] Test inspection sync

- [ ] **Clean up SessionBean**
  - [ ] Remove synchronizeOccPeriodAndPersonsFromSessProperty() method
  - [ ] Remove manual person list setup in Property if-block
  - [ ] Remove manual person sync in Case if-block
  - [ ] Remove manual inspection registration calls
  - [ ] Add error handling to visitor loop
  - [ ] Add logging to track conductor execution

- [ ] **Testing**
  - [ ] Unit test each conductor's visit methods in isolation
  - [ ] Integration test full flow: Property → Case → Person → Period
  - [ ] Verify all 4 conductors execute in correct order
  - [ ] Test error handling - one conductor failure doesn't break others
  - [ ] Performance test - verify no significant slowdown

### Phase 2: Add CDI Event Layer (3-4 days)

- [ ] **Create SessionFocusChangedEvent class**
  - [ ] Implement Serializable
  - [ ] Add all fields (previous, new, type, user, timestamp)
  - [ ] Add convenience methods (isFocusTypeProperty, etc.)
  - [ ] Add toString() for logging
  - [ ] Place in com.tcvcog.tcvce.entities.events package

- [ ] **Update SessionBean to fire events**
  - [ ] Inject Event<SessionFocusChangedEvent>
  - [ ] Add getCurrentSessionFocus() helper method
  - [ ] Fire event after visitor loop completes
  - [ ] Add try/catch so event failure doesn't break navigation
  - [ ] Test event fires correctly

- [ ] **Create example observers**
  - [ ] SessionAuditLogger - log all focus changes to DB
  - [ ] SessionCacheManager - invalidate stale caches
  - [ ] SessionMetricsCollector - track view counts
  - [ ] Test observers receive events correctly
  - [ ] Verify observers are independent (one failure doesn't affect others)

- [ ] **Documentation**
  - [ ] Document when to use visitor vs events
  - [ ] Add JavaDoc to event class
  - [ ] Update architecture diagrams
  - [ ] Create migration guide for future developers

### Phase 3: Migrate Cross-Cutting Concerns (Optional - 1 week)

- [ ] Move existing audit logging to event observers
- [ ] Move cache invalidation logic to event observers
- [ ] Move UI refresh triggers to event observers
- [ ] Remove cross-cutting logic from visitor methods
- [ ] Keep visitor methods focused on pure coordination

---

## 🎯 Critical Success Factors

### 1. Registration is Mandatory
**EVERY conductor MUST register in @PostConstruct:**
```java
@PostConstruct
public void initBean() {
    getSessionBean().registerSessionSynchronizer(this);
    // ... other init
}
```
**Symptom if missed:** Conductor's visit() methods never called, sync doesn't happen

### 2. ALL visit() Methods Must Be Implemented
Even if method body is empty:
```java
@Override
public void visit(Person p) {
    // No action needed for this conductor
}
```
**Symptom if missed:** Compilation error

### 3. Visit Methods Must Be Idempotent
Calling same visit() twice should produce same result:
```java
// BAD - increments counter
private int visitCount = 0;
public void visit(PropertyDataHeavy pdh) {
    visitCount++;  // ← Side effect!
}

// GOOD - sets to consistent value
public void visit(PropertyDataHeavy pdh) {
    sessPerson = pdh.getFirstPerson();  // ← Idempotent
}
```

### 4. Don't Store Target References
Extract data immediately, don't hold references:
```java
// BAD - storing reference to target
private PropertyDataHeavy cachedProperty;
public void visit(PropertyDataHeavy pdh) {
    cachedProperty = pdh;  // ← Stale object hell!
}

// GOOD - extract data
private Person extractedPerson;
public void visit(PropertyDataHeavy pdh) {
    extractedPerson = pdh.getFirstPerson();  // ← Just the data
}
```

### 5. Events Must Be Fire-and-Forget
No return values, no blocking:
```java
// GOOD - async observers
public void onFocusChanged(@Observes SessionFocusChangedEvent evt) {
    log(evt);  // Fire and forget
}

// BAD - trying to return value to event firer
public String onFocusChanged(@Observes SessionFocusChangedEvent evt) {
    return "some value";  // ← Won't work!
}
```

---

## 🔍 Debugging Guide

### Problem: Conductor's visit() never called

**Symptoms:**
- Session person not syncing to property
- Console shows "Dispatching to N conductors" but conductor logs missing

**Diagnosis:**
```java
// Check 1: Is conductor registered?
@PostConstruct
public void initBean() {
    System.out.println("SessionPersonConductor.initBean | REGISTERING");
    getSessionBean().registerSessionSynchronizer(this);  // ← Must be here
}

// Check 2: Does conductor implement both interfaces?
public class SessionPersonConductor 
    implements IFaceSessionSynchronizer,  // ← Need this
               IFaceSessionSyncVisitor {  // ← AND this
```

**Fix:** Add registration call, implement missing interface

### Problem: Wrong visit() method called

**Symptoms:**
- visit(Person) called when you expected visit(PropertyDataHeavy)

**Diagnosis:**
```java
// Check: Does target implement IFaceSessionSyncTarget?
public class PropertyDataHeavy implements IFaceSessionSyncTarget {
    @Override
    public void accept(IFaceSessionSyncVisitor visitor) {
        visitor.visit(this);  // ← Must pass 'this'
    }
}
```

**Fix:** Ensure target class implements interface and calls visitor.visit(this)

### Problem: Events not firing

**Symptoms:**
- Observer methods never called
- No "Fired SessionFocusChangedEvent" log

**Diagnosis:**
```java
// Check 1: Is Event<T> injected?
@Inject
private Event<SessionFocusChangedEvent> sessionFocusEvent;  // ← Need this

// Check 2: Are you firing it?
sessionFocusEvent.fire(new SessionFocusChangedEvent(...));

// Check 3: Is observer method annotated correctly?
public void onFocusChanged(@Observes SessionFocusChangedEvent evt) {
    //                       ^^^^^^^^^ Need this annotation
}

// Check 4: Is observer class @ApplicationScoped?
@ApplicationScoped  // ← Need this for reliable event reception
public class SessionAuditLogger {
```

**Fix:** Add @Inject, fire event, check observer annotations

---

## 📚 Reference Card

### Visitor Pattern Quick Reference

```java
// ELEMENT (session object)
public class PropertyDataHeavy implements IFaceSessionSyncTarget {
    @Override
    public void accept(IFaceSessionSyncVisitor visitor) {
        visitor.visit(this);  // Double dispatch
    }
}

// VISITOR (conductor)
public class SessionPersonConductor 
    implements IFaceSessionSynchronizer, IFaceSessionSyncVisitor {
    
    @PostConstruct
    public void initBean() {
        getSessionBean().registerSessionSynchronizer(this);  // 1. Register
    }
    
    @Override
    public void synchronizeToSessionFocusObject(IFaceSessionSyncTarget target) {
        target.accept(this);  // 2. Accept triggers double dispatch
    }
    
    @Override
    public void visit(PropertyDataHeavy pdh) {  // 3. Type-specific logic
        sessPerson = pdh.getFirstPerson();
    }
}

// CLIENT (SessionBean)
for(IFaceSessionSynchronizer conductor: sessionSyncRegistry) {
    conductor.synchronizeToSessionFocusObject(target);  // Calls all conductors
}
```

### CDI Events Quick Reference

```java
// EVENT CLASS
public class SessionFocusChangedEvent implements Serializable {
    private final IFaceSessionSyncTarget newFocus;
    // ... fields, constructor, getters
}

// PUBLISHER (SessionBean)
@Inject
private Event<SessionFocusChangedEvent> focusEvent;

focusEvent.fire(new SessionFocusChangedEvent(target, type, user));

// OBSERVER (any @ApplicationScoped bean)
@ApplicationScoped
public class SessionAuditLogger {
    public void onFocusChanged(@Observes SessionFocusChangedEvent evt) {
        // React to event
    }
}
```

### Common Patterns

```java
// Pattern: No-op visit
@Override
public void visit(Person p) {
    // Nothing to do for this conductor
}

// Pattern: Delegate to another visit
@Override
public void visit(OccPermit permit) {
    // Get parent period and use its logic
    OccPeriodDataHeavy opdh = getParentPeriod(permit);
    visit(opdh);  // Reuse period logic
}

// Pattern: Extract first from list
@Override
public void visit(PropertyDataHeavy pdh) {
    if(pdh.gethumanLinkList() != null && !pdh.gethumanLinkList().isEmpty()) {
        sessPerson = pdh.gethumanLinkList().get(0).getHuman();
    } else {
        sessPerson = null;  // Clear if empty
    }
}

// Pattern: Set directly
@Override
public void visit(Person p) {
    sessPerson = p;  // Just set it
}
```

---

## 🎯 Summary

**Current:** 500+ line mega-method with procedural coordination  
**Target:** Distributed conductors using visitor + events  
**Benefit:** Maintainable, testable, extensible architecture  
**Effort:** 1-2 weeks focused work  
**Risk:** Medium - requires careful migration, thorough testing

**Next Steps:**
1. Schedule 1-2 week implementation window
2. Start with Phase 1 (visitor pattern)
3. Add Phase 2 (events) after visitor working
4. Migrate cross-cutting concerns gradually (Phase 3)

**Key Insight:** This is "build new bridge while traffic on old one" work - can't do gradually, need focused time to complete properly.

---

**Document Version:** 1.0  
**Last Updated:** November 30, 2025  
**Author:** GitHub Copilot (Claude Sonnet 4.5) + ECD Architecture Discussion
