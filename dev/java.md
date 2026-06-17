---
title: Handy java stuff
description: Interesting java code with explanations
published: true
date: 2026-01-18T14:48:39.541Z
tags: 
editor: markdown
dateCreated: 2026-01-18T14:48:33.693Z
---

# Java tip and reference
[Removing duplicates from a list](removing-duplicates-from-a-list)
[Method reference shortcuts](methdo-reference-shortcuts)

## Removing duplicates from a list
Here's how to remove duplicates using a custom comparison with Java streams (Claude Sonnet 4.5 on 18 JAN 2026)

### Basic Pattern - Using a Stateful Filter

```java
// Remove duplicates based on a custom field/expression
list.stream()
    .filter(distinctByKey(obj -> obj.getCustomField()))
    .collect(Collectors.toList());

// Helper method (add to your class)
private static <T> Predicate<T> distinctByKey(Function<? super T, ?> keyExtractor) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();
    return t -> seen.add(keyExtractor.apply(t));
}
```

### Alternative - Using toMap

```java
list.stream()
    .collect(Collectors.toMap(
        obj -> obj.getCustomField(),  // Key: what makes it unique
        Function.identity(),           // Value: the object itself
        (existing, replacement) -> existing  // Merge: keep first occurrence
    ))
    .values()
    .stream()
    .collect(Collectors.toList());
```

### Examples

**Remove duplicates by field:**
```java
// Keep first Person with each unique name
List<Person> unique = people.stream()
    .filter(distinctByKey(Person::getName))
    .collect(Collectors.toList());
```

**Remove duplicates by composite key:**
```java
// Unique by name + age combination
List<Person> unique = people.stream()
    .filter(distinctByKey(p -> p.getName() + "|" + p.getAge()))
    .collect(Collectors.toList());
```

**Remove duplicates by multiple fields:**
```java
// Unique by custom comparison
List<Person> unique = people.stream()
    .filter(distinctByKey(p -> Arrays.asList(p.getFirstName(), p.getLastName())))
    .collect(Collectors.toList());
```

The key is that `keyExtractor` defines what makes two objects "the same" for deduplication purposes, independent of the object's `equals()` implementation.

```java
private static <T> Predicate<T> distinctByKey(Function<? super T, ?> keyExtractor) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();
    return t -> seen.add(keyExtractor.apply(t));
}
```

### Line by Line Dissection

**`private static <T>`**
- `private`: Only accessible within this class
- `static`: Not tied to any instance; purely functional utility
- `<T>`: Generic type parameter - T represents "whatever type your list contains"
  - This T could be `Person`, `PropertyEvaluationOption`, `String`, anything
  - The method doesn't care what T is; it works with any type

**`Predicate<T>`** (Return Type)
- `Predicate<T>` is a functional interface with one method: `boolean test(T t)`
- Used by `stream().filter()` to decide keep (true) or discard (false)
- So this method **returns a function** that tests objects of type T

**`distinctByKey`** (Method Name)
- Just the name; could be anything

**`Function<? super T, ?> keyExtractor`** (Parameter) - THE COMPLEX PART

Let me break down this parameter type piece by piece:

**`Function<INPUT, OUTPUT>`**
- Functional interface with method: `OUTPUT apply(INPUT input)`
- Takes something, transforms it to something else

**`? super T`** (First type parameter - INPUT)
- `?` means "wildcard" - some unknown type
- `super T` means "T or any superclass of T"
- Why? Allows you to pass a function that works on a parent type
- Example: If T is `Dog`, you can pass a function that takes `Animal`
  - Because every function that works on Animal will work on Dog
- This is **contravariance** - input types can be more general

**`?`** (Second type parameter - OUTPUT)
- Just `?` without bounds means "any type at all"
- Could be String, Integer, a custom class, anything
- Why? We don't care what type the key is; we just need to store it in a Set
- This is **invariance** - we accept any output type

**Putting it together:**
```java
Function<? super T, ?>
```
Means: "Give me a function that:
- Takes T (or a parent of T) as input
- Returns ANYTHING as output"

### The Implementation

**`Set<Object> seen = ConcurrentHashMap.newKeySet();`**
- `Set<Object>`: Set to track keys we've already seen
- Why `Object`? Because `keyExtractor` returns `?` (unknown type)
  - We need a type that can hold anything → `Object`
- `ConcurrentHashMap.newKeySet()`: Thread-safe Set implementation
  - Not strictly necessary for single-threaded streams
  - Good practice for parallel streams

**`return t -> seen.add(keyExtractor.apply(t));`**

This is a lambda that becomes the `Predicate<T>`. Let's unpack it:

**`t`** 
- Parameter passed by `filter()` 
- Represents one element from the stream (type T)

**`keyExtractor.apply(t)`**
- Calls the function you passed in
- Extracts the "key" from object t
- Returns the value that determines uniqueness

**`seen.add(...)`**
- Attempts to add the key to the Set
- **CRITICAL**: `Set.add()` returns a boolean:
  - `true` if element was added (wasn't already in set) → FIRST occurrence → KEEP
  - `false` if element already exists (duplicate) → DUPLICATE → DISCARD

**So the lambda returns:**
- `true` (keep) for the first occurrence of each key
- `false` (discard) for subsequent occurrences

### How It Works in Practice

```java
List<Person> people = List.of(
    new Person("Alice", 30),
    new Person("Bob", 25),
    new Person("Alice", 35)  // Duplicate name
);

// Remove duplicates by name
List<Person> unique = people.stream()
    .filter(distinctByKey(Person::getName))
    .collect(Collectors.toList());
```

**Step by step:**
1. First person: Alice, 30
   - `keyExtractor.apply(person)` → `"Alice"`
   - `seen.add("Alice")` → true (added to empty set)
   - Predicate returns true → **KEEP**
   - `seen = {"Alice"}`

2. Second person: Bob, 25
   - `keyExtractor.apply(person)` → `"Bob"`
   - `seen.add("Bob")` → true (new key)
   - Predicate returns true → **KEEP**
   - `seen = {"Alice", "Bob"}`

3. Third person: Alice, 35
   - `keyExtractor.apply(person)` → `"Alice"`
   - `seen.add("Alice")` → false (already in set!)
   - Predicate returns false → **DISCARD**
   - `seen = {"Alice", "Bob"}` (unchanged)

**Result:** Only first Alice and Bob are kept

### Why The Generics Are So Complex

**Without bounds (`Function<T, Object>`):**
```java
// Would fail if you have inheritance
class Animal { String getName() {...} }
class Dog extends Animal { }

List<Dog> dogs = ...;
dogs.stream().filter(distinctByKey(Animal::getName))  // ERROR!
// Function<Animal, String> is not Function<Dog, ?>
```

**With contravariant input (`Function<? super T, ?>`):**
```java
// Works! Function can accept Animal which accepts Dog
List<Dog> dogs = ...;
dogs.stream().filter(distinctByKey(Animal::getName))  // OK!
```

**With wildcard output (`?` instead of `Object`):**
- More flexible - doesn't force the key to be Object
- JVM can optimize better
- Follows "PECS" principle (Producer Extends, Consumer Super)

### The Magic

The **real magic** is the **closure** over `seen`:
- `seen` is created once when you call `distinctByKey()`
- The returned Predicate "closes over" this variable
- Every time `filter()` calls the Predicate, it uses the **same** `seen` Set
- This maintains state across multiple predicate invocations
- That's how it "remembers" what it's already seen

Without this closure, you'd need external state management or complex workarounds.

## Method reference shortcuts

###  Predicate<T> - Complete Review Definition

```java
@FunctionalInterface
public interface Predicate<T> {
    boolean test(T t);  // Single abstract method
    
    // Default methods for composition (bonus features)
    default Predicate<T> and(Predicate<? super T> other) {...}
    default Predicate<T> or(Predicate<? super T> other) {...}
    default Predicate<T> negate() {...}
    static <T> Predicate<T> isEqual(Object targetRef) {...}
    static <T> Predicate<T> not(Predicate<? super T> target) {...}
}
```

### Core Concept

**Predicate = "A question that returns true or false"**

- Takes one argument of type T
- Returns a boolean
- Answers: "Does this T meet my condition?"

### Basic Usage

```java
// Define a predicate
Predicate<Integer> isEven = n -> n % 2 == 0;

// Use it
boolean result = isEven.test(4);  // true
boolean result2 = isEven.test(5); // false
```

### Common Use Cases

**1. Stream Filtering**
```java
List<Integer> numbers = List.of(1, 2, 3, 4, 5, 6);

// filter() expects Predicate<T>
List<Integer> evens = numbers.stream()
    .filter(n -> n % 2 == 0)  // Predicate<Integer>
    .collect(Collectors.toList());
// Result: [2, 4, 6]
```

**2. Collection Methods**
```java
List<String> names = new ArrayList<>(List.of("Alice", "Bob", "Charlie"));

// removeIf() expects Predicate<T>
names.removeIf(name -> name.startsWith("A"));  // Predicate<String>
// names is now ["Bob", "Charlie"]
```

**3. Standalone Validation**
```java
Predicate<String> isValidEmail = email -> 
    email != null && email.contains("@") && email.contains(".");

if (isValidEmail.test(userInput)) {
    // Process email
}
```

### Method Reference Shortcuts

```java
// Lambda
Predicate<String> isEmpty = s -> s.isEmpty();

// Method reference (equivalent)
Predicate<String> isEmpty = String::isEmpty;

// Instance method
Predicate<Person> isAdult = p -> p.getAge() >= 18;
Predicate<Person> isAdult = Person::isAdult;  // if isAdult() method exists
```

### Composition Methods - Combining Predicates

**1. `and()` - Both conditions must be true**
```java
Predicate<Integer> isEven = n -> n % 2 == 0;
Predicate<Integer> isPositive = n -> n > 0;

Predicate<Integer> isPositiveEven = isEven.and(isPositive);

isPositiveEven.test(4);   // true (even AND positive)
isPositiveEven.test(-4);  // false (even but NOT positive)
isPositiveEven.test(3);   // false (positive but NOT even)
```

**2. `or()` - Either condition can be true**
```java
Predicate<Integer> isEven = n -> n % 2 == 0;
Predicate<Integer> isNegative = n -> n < 0;

Predicate<Integer> isEvenOrNegative = isEven.or(isNegative);

isEvenOrNegative.test(4);   // true (even)
isEvenOrNegative.test(-3);  // true (negative)
isEvenOrNegative.test(3);   // false (neither)
```

**3. `negate()` - Flip the result**
```java
Predicate<Integer> isEven = n -> n % 2 == 0;
Predicate<Integer> isOdd = isEven.negate();

isOdd.test(3);  // true
isOdd.test(4);  // false
```

**4. `not()` - Static method (Java 11+)**
```java
Predicate<String> isEmpty = String::isEmpty;

// Old way
Predicate<String> isNotEmpty = isEmpty.negate();

// Java 11+ static method
Predicate<String> isNotEmpty = Predicate.not(String::isEmpty);
```

### Complex Composition Example

```java
Predicate<Person> isAdult = p -> p.getAge() >= 18;
Predicate<Person> hasEmail = p -> p.getEmail() != null;
Predicate<Person> hasVerifiedEmail = p -> p.isEmailVerified();

// Complex condition
Predicate<Person> canReceiveNewsletter = 
    isAdult.and(hasEmail).and(hasVerifiedEmail);

List<Person> eligiblePeople = people.stream()
    .filter(canReceiveNewsletter)
    .collect(Collectors.toList());
```

### Predicate as Parameter - Flexible Filtering

```java
// Generic filter method that accepts any predicate
public List<Person> filterPeople(List<Person> people, Predicate<Person> condition) {
    return people.stream()
        .filter(condition)
        .collect(Collectors.toList());
}

// Usage - pass different predicates
List<Person> adults = filterPeople(people, p -> p.getAge() >= 18);
List<Person> seniors = filterPeople(people, p -> p.getAge() >= 65);
List<Person> namedJohn = filterPeople(people, p -> "John".equals(p.getName()));
```

### Type Parameter `<T>` Explained

```java
Predicate<String>  // Tests strings
Predicate<Integer> // Tests integers
Predicate<Person>  // Tests Person objects

// Generic method that works with any predicate type
public <T> boolean anyMatch(List<T> items, Predicate<T> condition) {
    for (T item : items) {
        if (condition.test(item)) {
            return true;
        }
    }
    return false;
}
```

### Why Predicate Exists

**Before Java 8 (ugly):**
```java
List<Integer> filterEvens(List<Integer> numbers) {
    List<Integer> result = new ArrayList<>();
    for (Integer n : numbers) {
        if (n % 2 == 0) {  // Logic hardcoded
            result.add(n);
        }
    }
    return result;
}
```

**After Java 8 (flexible):**
```java
List<Integer> filter(List<Integer> numbers, Predicate<Integer> condition) {
    return numbers.stream()
        .filter(condition)  // Logic passed as parameter
        .collect(Collectors.toList());
}

// Now you can:
filter(numbers, n -> n % 2 == 0);        // Evens
filter(numbers, n -> n > 10);            // Greater than 10
filter(numbers, n -> n > 0 && n < 100);  // Range
```

### Real-World Pattern in Your Code

```java
// distinctByKey returns a Predicate
private static <T> Predicate<T> distinctByKey(Function<? super T, ?> keyExtractor) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();
    return t -> seen.add(keyExtractor.apply(t));  // Returns Predicate<T>
}

// The returned predicate gets used by filter()
list.stream()
    .filter(distinctByKey(obj -> obj.getKey()))  // Predicate<T> plugs in here
    .collect(Collectors.toList());
```

### Key Principles Summary

1. **Single Purpose**: Test one thing, return true/false
2. **Functional Interface**: Can be used with lambdas and method references
3. **Composable**: Chain with `and()`, `or()`, `negate()`
4. **Reusable**: Define once, use many times
5. **Type-Safe**: Generic `<T>` ensures type consistency
6. **Declarative**: Express WHAT to test, not HOW to loop

### Mental Model

Think of Predicate as:
- A **filter** (keeps items that pass the test)
- A **validator** (checks if something is valid)
- A **condition** (evaluates to true/false)
- A **question** (Does this item meet the criteria?)