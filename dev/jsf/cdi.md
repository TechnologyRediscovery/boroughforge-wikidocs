---
title: CDI Implementation notes
description: 
published: true
date: 2025-11-26T16:27:37.373Z
tags: 
editor: markdown
dateCreated: 2025-11-26T16:20:44.602Z
---

## **Essential CDI Import Paths Reference**

Here's your complete import reference guide for CDI in Jakarta EE 9+:

---

### **Core CDI Annotations (Package: `jakarta.inject.*`)**

```java
// Bean naming for EL expressions
import jakarta.inject.Inject;   // Dependency injection
import jakarta.inject.Named;    // EL name for beans (e.g., #{sessionPersonConductor})
import jakarta.inject.Qualifier; // Create custom qualifiers (advanced)
```

**Most common:**
- `@Named("beanName")` - Gives your bean a name for XHTML `#{beanName}`
- `@Inject` - Injects dependencies (Event<T>, other beans, etc.)

---

### **CDI Scopes (Package: `jakarta.enterprise.context.*`)**

```java
// Standard CDI scopes
import jakarta.enterprise.context.ApplicationScoped;  // One instance per application
import jakarta.enterprise.context.SessionScoped;      // One instance per HTTP session
import jakarta.enterprise.context.RequestScoped;      // One instance per HTTP request
import jakarta.enterprise.context.Dependent;          // Pseudo-scope (no independent lifecycle)
import jakarta.enterprise.context.Conversation;       // Conversation scope (advanced)
import jakarta.enterprise.context.ConversationScoped; // Long-running conversations (advanced)
```

**JSF-specific scope (different package!):**
```java
// JSF ViewScoped - NOT pure CDI!
import jakarta.faces.view.ViewScoped;  // One instance per JSF view (page)
```

**Most common for you:**
- `@SessionScoped` - Session conductors
- `@ApplicationScoped` - Cache managers, coordinators, integrators
- `@ViewScoped` - Backing beans (JSF package, not CDI!)

---

### **CDI Events (Package: `jakarta.enterprise.event.*`)**

```java
// Event firing and observing
import jakarta.enterprise.event.Event;              // Publisher interface - inject this
import jakarta.enterprise.event.Observes;           // Observer method parameter annotation
import jakarta.enterprise.event.ObservesAsync;      // Async observer (runs in thread pool)
import jakarta.enterprise.event.TransactionPhase;   // Control when observer fires vs transaction
import jakarta.enterprise.event.Reception;          // Conditional observer (advanced)
```

**Event-related (same package):**
```java
import jakarta.enterprise.event.NotificationOptions; // Async event options (advanced)
```

**Most common for you:**
- `@Inject Event<MyEvent>` - Fire events
- `@Observes MyEvent` - Observe events
- `@Observes(during = TransactionPhase.AFTER_SUCCESS)` - Fire after DB commit

---

### **Lifecycle Callbacks (Package: `jakarta.annotation.*`)**

```java
// Bean lifecycle management
import jakarta.annotation.PostConstruct;  // Called after bean constructed and dependencies injected
import jakarta.annotation.PreDestroy;     // Called before bean destroyed
import jakarta.annotation.Priority;       // Order observer execution or alternatives
```

**Most common:**
- `@PostConstruct` - Initialize your bean (you already use this!)
- `@PreDestroy` - Cleanup when session ends, app shuts down

---

### **CDI Producers (Package: `jakarta.enterprise.inject.*`)**

```java
// Advanced: Create custom injection points
import jakarta.enterprise.inject.Produces;   // Method creates injectable object
import jakarta.enterprise.inject.Disposes;   // Cleanup for @Produces
import jakarta.enterprise.inject.Alternative; // Switchable bean implementations
import jakarta.enterprise.inject.Default;    // Default qualifier
import jakarta.enterprise.inject.Any;        // Match any qualifier
import jakarta.enterprise.inject.Instance;   // Programmatic lookup
import jakarta.enterprise.inject.Specializes; // Override another bean
```

**You probably won't need these initially.**

---

### **Serialization (Standard Java)**

```java
// Required for @SessionScoped, @ViewScoped beans
import java.io.Serializable;
```

**CRITICAL:** All session/view scoped beans MUST implement Serializable!

---

## **Your SessionPersonConductor Import Template**

Here's what you'll need for your conductor with events:

```java
package com.tcvcog.tcvce.session;

// CDI Core
import jakarta.inject.Named;                          // @Named("sessionPersonConductor")
import jakarta.inject.Inject;                         // @Inject Event<T>

// CDI Scopes
import jakarta.enterprise.context.SessionScoped;      // @SessionScoped

// CDI Events
import jakarta.enterprise.event.Event;                // Event<HumanLinkListChangedEvent>

// Lifecycle
import jakarta.annotation.PostConstruct;              // @PostConstruct
import jakarta.annotation.PreDestroy;                 // @PreDestroy (optional)

// Serialization
import java.io.Serializable;                          // implements Serializable

// Your domain classes
import com.tcvcog.tcvce.entities.IFace_humanListHolder;
import com.tcvcog.tcvce.entities.LinkedObjectSchemaEnum;
import com.tcvcog.tcvce.entities.HumanLink;
import com.tcvcog.tcvce.entities.events.HumanLinkListChangedEvent;

// Standard Java
import java.util.List;

@Named("sessionPersonConductor")
@SessionScoped
public class SessionPersonConductor implements Serializable {
    
    @Inject
    private Event<HumanLinkListChangedEvent> humanLinkChangeEvent;
    
    @PostConstruct
    public void initBean() {
        System.out.println("SessionPersonConductor.initBean (CDI)");
    }
    
    @PreDestroy
    public void cleanup() {
        System.out.println("SessionPersonConductor.cleanup - session ending");
    }
    
    // ... your methods
}
```

---

## **Observer Class Import Template**

For your cache managers and audit loggers:

```java
package com.tcvcog.tcvce.coordinators; // or wherever

// CDI Scope
import jakarta.enterprise.context.ApplicationScoped;  // @ApplicationScoped

// CDI Events
import jakarta.enterprise.event.Observes;             // @Observes
import jakarta.enterprise.event.TransactionPhase;     // TransactionPhase.AFTER_SUCCESS

// Optional: Observer ordering
import jakarta.annotation.Priority;                   // @Priority(100)

// Your domain classes
import com.tcvcog.tcvce.entities.events.HumanLinkListChangedEvent;
import com.tcvcog.tcvce.entities.LinkedObjectSchemaEnum;

@ApplicationScoped
public class HumanLinkCacheManager {
    
    // Basic observer
    public void onHumanLinkChanged(@Observes HumanLinkListChangedEvent event) {
        clearCache(event.getHolderObjectID());
    }
    
    // Observer with transaction phase
    public void onHumanLinkChangedAfterCommit(
            @Observes(during = TransactionPhase.AFTER_SUCCESS) 
            HumanLinkListChangedEvent event) {
        clearCache(event.getHolderObjectID());
    }
    
    // Observer with priority
    public void onHumanLinkChangedFirst(
            @Observes @Priority(100) 
            HumanLinkListChangedEvent event) {
        clearCache(event.getHolderObjectID());
    }
}
```

---

## **Quick Reference Card**

### **Most Common Imports (80% of use cases):**

```java
// Bean definition
import jakarta.inject.Named;                         // @Named
import jakarta.inject.Inject;                        // @Inject
import jakarta.enterprise.context.SessionScoped;     // @SessionScoped
import jakarta.enterprise.context.ApplicationScoped; // @ApplicationScoped
import jakarta.faces.view.ViewScoped;                // @ViewScoped (JSF!)

// Events
import jakarta.enterprise.event.Event;               // Event<T>
import jakarta.enterprise.event.Observes;            // @Observes

// Lifecycle
import jakarta.annotation.PostConstruct;             // @PostConstruct

// Serialization
import java.io.Serializable;                         // implements Serializable
```

### **Package Families:**

| **Package** | **Purpose** | **Common Classes** |
|------------|-------------|-------------------|
| `jakarta.inject.*` | Core DI | `@Named`, `@Inject` |
| `jakarta.enterprise.context.*` | CDI scopes | `@SessionScoped`, `@ApplicationScoped` |
| `jakarta.enterprise.event.*` | Events | `Event<T>`, `@Observes` |
| `jakarta.annotation.*` | Lifecycle | `@PostConstruct`, `@PreDestroy`, `@Priority` |
| `jakarta.faces.view.*` | JSF scopes | `@ViewScoped` |

---

## **Import Path Memory Tricks**

```
jakarta.inject.*           → Core injection (@Named, @Inject)
jakarta.enterprise.*       → Enterprise features (CDI events, contexts)
  ├── .context.*          → Scopes (@SessionScoped, etc.)
  ├── .event.*            → Events (Event<T>, @Observes)
  └── .inject.*           → Advanced DI (@Produces, @Alternative)
jakarta.annotation.*       → Lifecycle (@PostConstruct, @Priority)
jakarta.faces.*            → JSF-specific (@ViewScoped)
```

**Rule of thumb:**
- **`inject`** = Basic stuff (Named, Inject)
- **`enterprise`** = Advanced CDI (events, scopes)
- **`annotation`** = Lifecycle (PostConstruct)
- **`faces`** = JSF only (ViewScoped)

---

## **Your Cheat Sheet**

Save this for quick copy-paste:

```java
// SESSION-SCOPED EVENT PUBLISHER
import jakarta.inject.Named;
import jakarta.inject.Inject;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.event.Event;
import jakarta.annotation.PostConstruct;
import java.io.Serializable;

// APPLICATION-SCOPED OBSERVER
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.event.TransactionPhase;

// VIEW-SCOPED BACKING BEAN
import jakarta.inject.Named;
import jakarta.faces.view.ViewScoped;
import jakarta.annotation.PostConstruct;
import java.io.Serializable;
```
---
*Documentation created with assistance from GitHub Copilot Claude Sonnet 4.5*  
*Last updated: November 26, 2025*