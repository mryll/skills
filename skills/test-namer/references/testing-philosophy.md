# Testing Philosophy

Based on Vladimir Khorikov's testing principles. Read this when making deeper decisions about **what** to test, **how** to structure tests, and **where** to invest testing effort.

## The Three Pillars of a Valuable Test

Every test is evaluated against these three properties. A test that fails on any one is not worth keeping.

1. **High regression detection** — exercises meaningful code paths with real business logic. Testing trivial getters or configuration wiring adds no value.
2. **Low false positives** — does not break during legitimate refactoring. Tests coupled to implementation details produce false alarms. Verify end results, not intermediate steps.
3. **Fast feedback** — runs quickly enough to execute frequently during development.

These properties are in tension — maximizing one can compromise others. End-to-end tests catch more regressions but run slowly. Tests coupled to implementation catch bugs but fail during refactoring. The goal is to find the sweet spot for each test.

## Testing Styles — When to Use Each

### Output-Based (Functional)

Feed input, examine output. No side effects.

```
input -> SUT -> output (assert this)
```

- **Best false-positive resistance** — inputs/outputs remain stable across refactorings
- Use for: pure functions, domain logic, calculations, transformations
- Requires: code structured so business logic is free of side effects

### State-Based

Perform operation, verify the system's resulting state through its public API.

```
operation -> SUT -> state (assert this via public API)
```

- **Good approximation** of output-based when outputs aren't practical
- Use for: domain objects with state, aggregates, entities
- Key rule: only verify through public API — never inspect private fields

### Communication-Based (Mocks)

Verify interactions between the system and its dependencies.

```
operation -> SUT -> dependency call (assert this with mock/spy)
```

- **Highest false-positive risk** — couples tests to implementation
- Use ONLY for: uncontrolled external dependencies (SMTP, message bus, third-party APIs)
- Never use for: domain object interactions, repository calls within the same bounded context, stable internal dependencies

## Pragmatic Unit Testing

### Black-Box Over White-Box

Always treat the SUT as a black box. Verify what it does, not how it does it. This applies at ALL testing levels, not just integration tests. White-box testing encourages coupling to implementation details.

### Architecture for Testability

Separate business logic from volatile dependencies:

- **Domain model**: pure business logic, no I/O, no framework dependencies. Test with output-based and state-based styles.
- **Application services**: coordinate between domain and infrastructure. Thin orchestration layer.
- **Infrastructure**: database, APIs, file system. Wrapped behind interfaces.

Code should either depend on the outside world OR contain business logic — never both.

### What to Mock

- **Mock volatile (uncontrolled) dependencies**: external APIs, email services, message buses — things you don't own
- **Never mock stable dependencies**: domain classes, value objects, other internal code — use real instances
- Extracting interfaces from domain entities solely for testing is a design smell ("header interfaces")

### Test Investment Strategy

Not all code deserves the same testing effort:

| Code Type | Complexity | Dependencies | Test Value |
|-----------|-----------|--------------|------------|
| Domain model | High | None | **Highest** — test thoroughly |
| Algorithms | High | None | **High** — test edge cases |
| Controllers/orchestration | Low | Many | **Medium** — integration tests for happy path |
| Trivial code | Low | None | **None** — don't test |
| Overcomplicated code | High | Many | **Refactor first** — then test |

Focus testing effort on domain models and algorithms. These have the highest regression detection with the lowest false-positive risk.

## Pragmatic Integration Testing

### When to Use Integration Tests

- Cover application services and coordination logic that unit tests can't reach
- Verify happy paths and sophisticated edge cases — not exhaustive scenarios
- Test interaction with real controlled dependencies (database, file system)

### Controlled vs Uncontrolled Dependencies

- **Controlled** (database, file system): exercise directly in integration tests with real instances
- **Uncontrolled** (SMTP, message bus, third-party APIs): verify through mocks/spies

### Spies Over Mocks

Prefer spies (record calls for manual examination) over strict mocks for external dependencies:

- Explicitly specify what information is testable
- Reusable across tests
- Better protection against false positives

### Public API Boundary

- How domain objects communicate with each other = **implementation detail** (don't mock)
- How your application communicates with other applications = **public API** (verify with mocks/spies)
