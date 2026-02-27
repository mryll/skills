# Cognitive Complexity Specification (SonarSource v1.7)

## Table of Contents
- [Three Basic Rules](#three-basic-rules)
- [Increment Types](#increment-types)
- [What Increments](#what-increments)
- [What Does NOT Increment](#what-does-not-increment)
- [Nesting Rules](#nesting-rules)
- [Logical Operators](#logical-operators)
- [Compensating Usages](#compensating-usages)

## Three Basic Rules

1. **Ignore shorthand** — Structures that condense multiple statements into one readable form (method extraction, null-coalescing `?.`, `??`, etc.)
2. **+1 for each break in linear flow** — Each structure that interrupts top-to-bottom, left-to-right reading
3. **+1 nesting penalty for nested flow-break structures** — Nesting increases mental cost

## Increment Types

| Type | Description | Examples |
|------|------------|---------|
| **Structural** | Flow-breaking + increases nesting count | `if`, `for`, `while`, `switch`, `catch` |
| **Hybrid** | Flow-breaking, NOT +1 nesting penalty but DOES increase nesting count | `else if`, `elif`, `else` |
| **Fundamental** | Flow-breaking, NOT subject to nesting | logical operator sequences, `goto`, `break LABEL`, `continue LABEL`, recursion |
| **Nesting** | Extra +1 per nesting depth for structural increments | Nested `if` inside `for` = +1 structural + nesting depth |

## What Increments (+1 each)

### Structural increments (also increase nesting level)
- `if`, ternary operator (`? :`)
- `switch` (entire switch = +1, NOT per case)
- `for`, `foreach`, `for...in`, `for...of`
- `while`, `do while`
- `catch`

### Hybrid increments (increase nesting level but no nesting penalty themselves)
- `else if`, `elif`
- `else`

### Fundamental increments (no nesting penalty, don't increase nesting level)
- `goto LABEL`
- `break LABEL`, `break NUMBER`
- `continue LABEL`, `continue NUMBER`
- Each method in a recursion cycle
- Each sequence of same binary logical operators (see Logical Operators section)

## What Does NOT Increment

- Method/function declarations (top-level)
- `try` blocks
- `finally` blocks
- `case` / `default` labels within a switch (the switch itself gets +1)
- Null-coalescing operators: `?.`, `??`, Elvis `?:` (NOT the conditional ternary `cond ? a : b`, which IS an increment)
- Early `return` statements
- Simple `break` or `continue` (without label)
- Lambda/closure declarations (but they DO increase nesting level)

## Nesting Rules

### What increases nesting level
- `if`, `else if`, `else`, ternary operator
- `switch`
- `for`, `foreach`
- `while`, `do while`
- `catch`
- Nested methods, lambdas, closures

### Nesting penalty
Structures that receive a structural increment (`if`, ternary, `switch`, `for`, `while`, `catch`) also get **+1 per nesting depth** when inside another nesting-level-increasing structure.

### Example
```
void myMethod() {
  try {                                          // no increment (try ignored)
    if (condition1) {                            // +1
      for (int i = 0; i < 10; i++) {             // +2 (nesting=1)
        while (condition2) { ... }               // +3 (nesting=2)
      }
    }
  } catch (ExcepType1 | ExcepType2 e) {          // +1
    if (condition2) { ... }                       // +2 (nesting=1)
  }
}                                                // Total = 9
```

## Logical Operators

Increment +1 for each **sequence of like operators**, not per operator:

```
a && b              // +1
a && b && c && d    // +1 (same operator sequence)
a || b              // +1
a || b || c || d    // +1 (same operator sequence)
```

Mixed operators — each change of operator type adds +1:

```
a && b && c         // +1 (one && sequence)
  || d || e         // +1 (one || sequence)
  && f              // +1 (new && sequence)
                    // Total for boolean = 3
```

With negation:
```
if (a                // +1 for if
    && !(b && c))    // +1 for &&, +1 for inner &&
```

## Compensating Usages

Language-specific exceptions to avoid penalizing common idioms:

### COBOL: Missing `else if`
- `ELSE` containing only an `IF` is treated as `else if` (hybrid, no nesting penalty)

### JavaScript: Declarative outer functions
- Outer function used purely as namespace/class (only contains declarations) is ignored
- If it contains structural statements, normal rules apply

### Python: Decorators
- A function containing only a nested function + return statement counts as nesting=0 for the inner function
- If it contains other statements, normal nesting rules apply
