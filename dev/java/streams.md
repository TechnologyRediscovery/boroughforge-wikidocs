---
title: Streams
description: quick reference
published: true
date: 2026-01-18T15:16:19.784Z
tags: 
editor: markdown
dateCreated: 2026-01-18T15:16:15.715Z
---

# Java Streams Quick Reference for CNF

A practical guide to Java Streams for CodeNForce developers. By Claude Sonnet 4.5 Jan-2026.

## Table of Contents
- [What is a Stream?](#what-is-a-stream)
- [Creating Streams](#creating-streams)
- [Intermediate Operations](#intermediate-operations)
- [Terminal Operations](#terminal-operations)
- [Collectors](#collectors)
- [Method References](#method-references)
- [Common Patterns](#common-patterns)
- [Performance Tips](#performance-tips)

---

## What is a Stream?

A **Stream** is a sequence of elements that supports functional-style operations. Think of it as a "pipeline" that transforms data.

**Key Characteristics:**
- **Lazy**: Intermediate operations don't execute until a terminal operation is called
- **One-time use**: Once consumed, a stream cannot be reused
- **Functional**: Operations don't modify the source collection
- **Chainable**: Operations can be chained for readable, declarative code

**Basic Pattern:**
```java
list.stream()                    // Create stream
    .filter(predicate)           // Intermediate operation
    .map(function)               // Intermediate operation
    .collect(Collectors.toList()); // Terminal operation
```

---

## Creating Streams

### From Collections
```java
List<Person> people = new ArrayList<>();
Stream<Person> stream = people.stream();

// Parallel stream for performance
Stream<Person> parallelStream = people.parallelStream();
```

### From Arrays
```java
String[] names = {"Alice", "Bob", "Charlie"};
Stream<String> stream = Arrays.stream(names);
Stream<String> stream2 = Stream.of("Alice", "Bob", "Charlie");
```

### From Values
```java
Stream<String> empty = Stream.empty();
Stream<Integer> numbers = Stream.of(1, 2, 3, 4, 5);
```

### Infinite Streams
```java
// Generate infinite stream
Stream<Integer> infinite = Stream.iterate(0, n -> n + 1);

// Must use limit() to avoid infinite loop
List<Integer> first10 = infinite.limit(10).collect(Collectors.toList());
```

---

## Intermediate Operations

**Returns a new Stream** - can be chained. **Lazy** - not executed until terminal operation.

### `filter(Predicate<T>)` - Keep elements that match condition

```java
// Keep only active properties
List<Property> activeProperties = properties.stream()
    .filter(prop -> prop.isActive())
    .collect(Collectors.toList());

// Multiple filters (AND logic)
List<Property> filtered = properties.stream()
    .filter(prop -> prop.isActive())
    .filter(prop -> prop.getMuniCode() == 999)
    .collect(Collectors.toList());
```

### `map(Function<T,R>)` - Transform each element

```java
// Extract person IDs from list of persons
List<Integer> personIDs = persons.stream()
    .map(person -> person.getPersonID())
    .collect(Collectors.toList());

// Method reference (cleaner)
List<Integer> personIDs = persons.stream()
    .map(Person::getPersonID)
    .collect(Collectors.toList());

// Transform to different type
List<String> propertyAddresses = properties.stream()
    .map(prop -> prop.getAddress().getStreet())
    .collect(Collectors.toList());
```

### `flatMap(Function<T,Stream<R>>)` - Flatten nested collections

```java
// Get all events from all cases
List<EventCnF> allEvents = cases.stream()
    .flatMap(ceCase -> ceCase.getEventList().stream())
    .collect(Collectors.toList());

// Get all persons from multiple properties
List<Person> allPersons = properties.stream()
    .flatMap(prop -> prop.getPersonList().stream())
    .collect(Collectors.toList());
```

### `distinct()` - Remove duplicates (uses equals())

```java
// Get unique muni codes from properties
List<Integer> uniqueMuniCodes = properties.stream()
    .map(Property::getMuniCode)
    .distinct()
    .collect(Collectors.toList());
```

**For custom distinctness** (not based on equals()):
```java
// Helper method - add to BackingBeanUtils or coordinator
private static <T> Predicate<T> distinctByKey(Function<? super T, ?> keyExtractor) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();
    return t -> seen.add(keyExtractor.apply(t));
}

// Use it - distinct by person name, not personID
List<Person> uniqueByName = persons.stream()
    .filter(distinctByKey(Person::getLastName))
    .collect(Collectors.toList());
```

### `sorted()` - Sort elements

```java
// Natural order (Comparable)
List<Integer> sorted = numbers.stream()
    .sorted()
    .collect(Collectors.toList());

// Custom comparator
List<Person> sortedByName = persons.stream()
    .sorted((p1, p2) -> p1.getLastName().compareTo(p2.getLastName()))
    .collect(Collectors.toList());

// Using Comparator methods
List<Person> sortedByAge = persons.stream()
    .sorted(Comparator.comparing(Person::getAge))
    .collect(Collectors.toList());

// Reverse order
List<Person> oldestFirst = persons.stream()
    .sorted(Comparator.comparing(Person::getAge).reversed())
    .collect(Collectors.toList());

// Multiple sort keys
List<Person> sorted = persons.stream()
    .sorted(Comparator.comparing(Person::getLastName)
                      .thenComparing(Person::getFirstName))
    .collect(Collectors.toList());
```

### `limit(n)` - Take first n elements

```java
// Get first 10 properties
List<Property> first10 = properties.stream()
    .limit(10)
    .collect(Collectors.toList());
```

### `skip(n)` - Skip first n elements

```java
// Skip first 20, get next 10 (pagination)
List<Property> page2 = properties.stream()
    .skip(20)
    .limit(10)
    .collect(Collectors.toList());
```

### `peek(Consumer<T>)` - Debug/side-effects (careful!)

```java
// Useful for debugging
List<String> names = persons.stream()
    .peek(p -> System.out.println("Processing: " + p.getPersonID()))
    .map(Person::getLastName)
    .peek(name -> System.out.println("Name: " + name))
    .collect(Collectors.toList());
```

---

## Terminal Operations

**Triggers execution** of the stream pipeline. **Returns a result** (not a stream).

### `collect(Collector)` - Most versatile terminal operation

See [Collectors section](#collectors) below for details.

### `forEach(Consumer<T>)` - Execute action on each element

```java
// Print all person names
persons.stream()
    .forEach(person -> System.out.println(person.getLastName()));

// Method reference
persons.stream()
    .forEach(System.out::println);

// Side effect: add to external collection (use collect instead!)
List<String> names = new ArrayList<>();
persons.stream()
    .forEach(p -> names.add(p.getLastName())); // BAD - use map().collect()
```

### `count()` - Count elements

```java
// Count active properties
long activeCount = properties.stream()
    .filter(Property::isActive)
    .count();
```

### `anyMatch(Predicate<T>)` - Check if any element matches

```java
// Check if any person is over 65
boolean hasSenior = persons.stream()
    .anyMatch(p -> p.getAge() > 65);
```

### `allMatch(Predicate<T>)` - Check if all elements match

```java
// Check if all properties are active
boolean allActive = properties.stream()
    .allMatch(Property::isActive);
```

### `noneMatch(Predicate<T>)` - Check if no elements match

```java
// Check if no properties are deactivated
boolean noneDeactivated = properties.stream()
    .noneMatch(prop -> prop.getDeactivatedTS() != null);
```

### `findFirst()` - Get first element (Optional)

```java
// Get first active property
Optional<Property> firstActive = properties.stream()
    .filter(Property::isActive)
    .findFirst();

// With default value
Property prop = properties.stream()
    .filter(Property::isActive)
    .findFirst()
    .orElse(null);

// Throw exception if not found
Property prop = properties.stream()
    .filter(Property::isActive)
    .findFirst()
    .orElseThrow(() -> new BObStatusException("No active property found"));
```

### `findAny()` - Get any element (faster in parallel streams)

```java
Optional<Property> anyActive = properties.stream()
    .filter(Property::isActive)
    .findAny();
```

### `reduce()` - Combine elements into single result

```java
// Sum all property values
int totalValue = properties.stream()
    .map(Property::getAssessedValue)
    .reduce(0, (a, b) -> a + b);

// Or use Integer::sum
int totalValue = properties.stream()
    .map(Property::getAssessedValue)
    .reduce(0, Integer::sum);

// Find max age
Optional<Integer> maxAge = persons.stream()
    .map(Person::getAge)
    .reduce(Integer::max);
```

### `min() / max()` - Find minimum/maximum

```java
// Oldest person
Optional<Person> oldest = persons.stream()
    .max(Comparator.comparing(Person::getAge));

// Youngest person
Optional<Person> youngest = persons.stream()
    .min(Comparator.comparing(Person::getAge));
```

---

## Collectors

**Collectors** define how to collect stream elements into a result.

### `toList()` - Collect to ArrayList

```java
List<Person> result = persons.stream()
    .filter(Person::isActive)
    .collect(Collectors.toList());
```

### `toSet()` - Collect to HashSet (removes duplicates)

```java
Set<Integer> uniqueMuniCodes = properties.stream()
    .map(Property::getMuniCode)
    .collect(Collectors.toSet());
```

### `toMap()` - Collect to HashMap

```java
// Map personID -> Person
Map<Integer, Person> personMap = persons.stream()
    .collect(Collectors.toMap(
        Person::getPersonID,  // Key
        person -> person       // Value
    ));

// Or with method reference
Map<Integer, Person> personMap = persons.stream()
    .collect(Collectors.toMap(
        Person::getPersonID,
        Function.identity()
    ));

// Handle duplicate keys
Map<Integer, Person> personMap = persons.stream()
    .collect(Collectors.toMap(
        Person::getPersonID,
        Function.identity(),
        (existing, replacement) -> existing  // Keep first
    ));
```

### `groupingBy()` - Group elements by key

```java
// Group properties by muni code
Map<Integer, List<Property>> byMuni = properties.stream()
    .collect(Collectors.groupingBy(Property::getMuniCode));

// Group persons by age bracket
Map<String, List<Person>> byAgeBracket = persons.stream()
    .collect(Collectors.groupingBy(p -> {
        if (p.getAge() < 18) return "Minor";
        if (p.getAge() < 65) return "Adult";
        return "Senior";
    }));

// Count by group
Map<Integer, Long> countByMuni = properties.stream()
    .collect(Collectors.groupingBy(
        Property::getMuniCode,
        Collectors.counting()
    ));
```

### `partitioningBy()` - Split into two groups (true/false)

```java
// Partition into active/inactive
Map<Boolean, List<Property>> partitioned = properties.stream()
    .collect(Collectors.partitioningBy(Property::isActive));

List<Property> active = partitioned.get(true);
List<Property> inactive = partitioned.get(false);
```

### `joining()` - Concatenate strings

```java
// Comma-separated names
String nameList = persons.stream()
    .map(Person::getLastName)
    .collect(Collectors.joining(", "));
// Result: "Smith, Jones, Williams"

// With prefix/suffix
String nameList = persons.stream()
    .map(Person::getLastName)
    .collect(Collectors.joining(", ", "Names: [", "]"));
// Result: "Names: [Smith, Jones, Williams]"
```

### `summarizingInt/Double/Long()` - Statistics

```java
IntSummaryStatistics ageStats = persons.stream()
    .collect(Collectors.summarizingInt(Person::getAge));

System.out.println("Average age: " + ageStats.getAverage());
System.out.println("Min age: " + ageStats.getMin());
System.out.println("Max age: " + ageStats.getMax());
System.out.println("Total count: " + ageStats.getCount());
```

---

## Method References

Shorthand for lambdas that just call a method.

### Types of Method References

```java
// 1. Static method reference
// Lambda: s -> Integer.parseInt(s)
Function<String, Integer> parser = Integer::parseInt;

// 2. Instance method on specific object
// Lambda: s -> system.out.println(s)
Consumer<String> printer = System.out::println;

// 3. Instance method on parameter
// Lambda: s -> s.isEmpty()
Predicate<String> isEmpty = String::isEmpty;

// 4. Constructor reference
// Lambda: () -> new Person()
Supplier<Person> personFactory = Person::new;
```

### Common Usage in Streams

```java
// map() with getter method reference
List<Integer> ids = persons.stream()
    .map(Person::getPersonID)  // Instead of: p -> p.getPersonID()
    .collect(Collectors.toList());

// filter() with boolean method reference
List<Property> active = properties.stream()
    .filter(Property::isActive)  // Instead of: p -> p.isActive()
    .collect(Collectors.toList());

// forEach() with method reference
persons.stream()
    .forEach(System.out::println);  // Instead of: p -> System.out.println(p)
```

---

## Common Patterns

### Pattern 1: Extract Sub-Objects (Transform Collection)

**Problem**: You have `List<Person>` and want `List<String>` of names.

```java
// Extract single field
List<String> lastNames = persons.stream()
    .map(Person::getLastName)
    .collect(Collectors.toList());

// Extract and transform
List<String> fullNames = persons.stream()
    .map(p -> p.getFirstName() + " " + p.getLastName())
    .collect(Collectors.toList());

// Extract nested field
List<String> streetNames = properties.stream()
    .map(prop -> prop.getAddress())
    .map(addr -> addr.getStreet())
    .collect(Collectors.toList());

// Or chain in one map() call
List<String> streetNames = properties.stream()
    .map(prop -> prop.getAddress().getStreet())
    .collect(Collectors.toList());
```

### Pattern 2: Filter-Map-Collect

```java
// Get IDs of active persons over 18
List<Integer> adultIDs = persons.stream()
    .filter(p -> p.getAge() >= 18)
    .filter(Person::isActive)
    .map(Person::getPersonID)
    .collect(Collectors.toList());
```

### Pattern 3: Flatten Nested Collections

```java
// Get all events from all cases
List<EventCnF> allEvents = cases.stream()
    .flatMap(ceCase -> ceCase.getEventList().stream())
    .collect(Collectors.toList());

// With filtering on nested items
List<EventCnF> recentEvents = cases.stream()
    .flatMap(ceCase -> ceCase.getEventList().stream())
    .filter(event -> event.getEventDate().isAfter(LocalDate.now().minusDays(30)))
    .collect(Collectors.toList());
```

### Pattern 4: Remove Nulls

```java
// Filter out null values before processing
List<String> nonNullNames = persons.stream()
    .map(Person::getEmail)
    .filter(Objects::nonNull)  // Remove nulls
    .collect(Collectors.toList());
```

### Pattern 5: Find First or Default

```java
// Find person by ID, return null if not found
Person person = persons.stream()
    .filter(p -> p.getPersonID() == targetID)
    .findFirst()
    .orElse(null);

// Throw exception if not found
Person person = persons.stream()
    .filter(p -> p.getPersonID() == targetID)
    .findFirst()
    .orElseThrow(() -> new BObStatusException("Person not found: " + targetID));

// Return default object
Person person = persons.stream()
    .filter(p -> p.getPersonID() == targetID)
    .findFirst()
    .orElse(getDefaultPerson());
```

### Pattern 6: Check Existence

```java
// Check if list contains active property
boolean hasActive = properties.stream()
    .anyMatch(Property::isActive);

// Check if person exists by ID
boolean exists = persons.stream()
    .anyMatch(p -> p.getPersonID() == targetID);
```

### Pattern 7: Group and Count

```java
// Count properties by muni
Map<Integer, Long> countByMuni = properties.stream()
    .collect(Collectors.groupingBy(
        Property::getMuniCode,
        Collectors.counting()
    ));

// Get count for specific muni
long count = countByMuni.getOrDefault(999, 0L);
```

### Pattern 8: Sort and Limit (Top N)

```java
// Get 5 oldest persons
List<Person> oldest5 = persons.stream()
    .sorted(Comparator.comparing(Person::getAge).reversed())
    .limit(5)
    .collect(Collectors.toList());
```

### Pattern 9: Convert to Map for Fast Lookup

```java
// Create lookup map for O(1) access
Map<Integer, Person> personLookup = persons.stream()
    .collect(Collectors.toMap(
        Person::getPersonID,
        Function.identity()
    ));

// Use it
Person person = personLookup.get(targetID);
```

### Pattern 10: Combine Operations

```java
// Complex real-world example
List<String> result = properties.stream()
    .filter(Property::isActive)                    // Only active
    .filter(p -> p.getMuniCode() == 999)          // Specific muni
    .sorted(Comparator.comparing(Property::getAddress)) // Sort by address
    .limit(10)                                     // Top 10
    .map(p -> p.getAddress().getStreet())         // Extract street
    .filter(Objects::nonNull)                      // Remove nulls
    .distinct()                                    // Remove duplicates
    .collect(Collectors.toList());                // Collect result
```

---

## Performance Tips

### 1. Use Parallel Streams Carefully

```java
// Good for CPU-intensive operations on large collections
List<Property> result = hugePropertyList.parallelStream()
    .filter(Property::isActive)
    .collect(Collectors.toList());

// ⚠️ NOT good for small collections (overhead > benefit)
List<Property> result = smallList.parallelStream()  // Don't do this
    .filter(Property::isActive)
    .collect(Collectors.toList());

// ⚠️ NOT good for I/O operations (database, file access)
properties.parallelStream()  // Don't do this
    .forEach(prop -> database.save(prop));  // I/O in each thread
```

### 2. Filter Early

```java
// ✓ GOOD - filter reduces work for map()
List<Integer> ids = properties.stream()
    .filter(Property::isActive)      // Reduce size first
    .map(Property::getPropertyID)    // Less work
    .collect(Collectors.toList());

// ✗ BAD - map() processes everything before filter
List<Integer> ids = properties.stream()
    .map(Property::getPropertyID)    // Process everything
    .filter(id -> properties.stream()
        .anyMatch(p -> p.getPropertyID() == id && p.isActive()))
    .collect(Collectors.toList());
```

### 3. Avoid Multiple Passes

```java
// ✗ BAD - three separate stream operations
int count = persons.stream().filter(Person::isActive).count();
int sum = persons.stream().filter(Person::isActive).mapToInt(Person::getAge).sum();
double avg = persons.stream().filter(Person::isActive).mapToInt(Person::getAge).average().orElse(0);

// ✓ GOOD - single pass with statistics collector
IntSummaryStatistics stats = persons.stream()
    .filter(Person::isActive)
    .mapToInt(Person::getAge)
    .summaryStatistics();
int count = (int) stats.getCount();
int sum = (int) stats.getSum();
double avg = stats.getAverage();
```

### 4. Don't Collect If Not Needed

```java
// ✗ BAD - unnecessary collection
boolean hasActive = properties.stream()
    .filter(Property::isActive)
    .collect(Collectors.toList())  // Wasteful!
    .size() > 0;

// ✓ GOOD - short-circuit with anyMatch
boolean hasActive = properties.stream()
    .anyMatch(Property::isActive);  // Stops at first match
```

### 5. Choose Right Collector

```java
// ✗ BAD - collecting to list then to set
Set<Integer> uniqueIDs = properties.stream()
    .map(Property::getPropertyID)
    .collect(Collectors.toList())  // Unnecessary intermediate list
    .stream()
    .collect(Collectors.toSet());

// ✓ GOOD - collect directly to set
Set<Integer> uniqueIDs = properties.stream()
    .map(Property::getPropertyID)
    .collect(Collectors.toSet());
```

---

## When NOT to Use Streams

### Simple Loops Are Often Better

```java
// Stream overkill for simple iteration
properties.stream().forEach(prop -> prop.setActive(true));

// Better: use enhanced for-loop
for (Property prop : properties) {
    prop.setActive(true);
}
```

### Modifying Source Collection

```java
// ✗ BAD - concurrent modification exception
properties.stream()
    .forEach(prop -> properties.remove(prop));  // CRASH!

// ✓ GOOD - use removeIf
properties.removeIf(prop -> !prop.isActive());
```

### Multiple Return Values

```java
// Streams return ONE result
// If you need multiple results, consider traditional loop or multiple streams
```

---

## Quick Reference Card

| **Task** | **Stream Operation** |
|----------|----------------------|
| Keep items matching condition | `.filter(predicate)` |
| Transform each item | `.map(function)` |
| Flatten nested collections | `.flatMap(function)` |
| Remove duplicates | `.distinct()` |
| Sort | `.sorted()` or `.sorted(comparator)` |
| Take first N | `.limit(n)` |
| Skip first N | `.skip(n)` |
| Collect to list | `.collect(Collectors.toList())` |
| Collect to set | `.collect(Collectors.toSet())` |
| Collect to map | `.collect(Collectors.toMap(keyMapper, valueMapper))` |
| Group by key | `.collect(Collectors.groupingBy(classifier))` |
| Count | `.count()` |
| Find first | `.findFirst()` |
| Check if any match | `.anyMatch(predicate)` |
| Check if all match | `.allMatch(predicate)` |
| Get min/max | `.min(comparator)` / `.max(comparator)` |

---

## Additional Resources

- [Official Java Stream Documentation](https://docs.oracle.com/javase/8/docs/api/java/util/stream/Stream.html)
- [Java 8 Stream Tutorial](https://www.baeldung.com/java-8-streams)
- CNF Codebase: See `BackingBeanUtils` for stream utility methods
- CNF Codebase: Search for `.stream()` to see real-world usage patterns

---

*Last Updated: January 2026*
