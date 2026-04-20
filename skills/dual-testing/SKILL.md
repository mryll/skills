---
name: dual-testing
version: 1.0.0
description: "Go dual testing strategy: integration tests (testcontainers) verify full-chain wiring for happy paths, unit tests (testify/mock) verify error handling logic. Apply when designing test strategy for a Go project, creating a new handler or feature that needs tests, or deciding what type of test to write for a scenario. Triggers: 'dual testing', 'error path coverage', 'testcontainers vs mocks', 'what type of test', 'where should this test go', 'integration vs unit', creating Go handlers/features/workers that need tests. Does NOT trigger on: writing individual test assertions, renaming tests, test naming conventions (use test-namer for those)."
---

# Dual Testing

Strategy for Go projects: **integration tests verify the full chain works, unit tests verify error handling logic.** Derived from real implementations across multiple Go microservices using Vertical Slice Architecture, Gin, pgx/pgxpool, MongoDB, and testcontainers-go.

## Core Rule

Integration tests (testcontainers) and unit tests (mocks) have different responsibilities:

- **Integration tests** prove that the **full chain** works end-to-end: HTTP request → middleware → handler → repository → database → response. They use real infrastructure via testcontainers.
- **Unit tests** prove that the handler's **error handling logic** is correct: mapping domain errors to HTTP status codes, validating input, handling infrastructure failures gracefully. They use testify/mock.

Some natural overlap on boundary scenarios (400, 404) is acceptable because the two test types exercise different concerns — integration proves the chain, unit proves the mapping. The anti-pattern to avoid is duplicating **happy paths** in both layers.

## Decision Table

Use this to decide where a test scenario belongs:

| Scenario | Test type | Why |
|---|---|---|
| Happy path (successful CRUD) | Integration | Proves real wiring works |
| Handler input validation → 400 | Unit | Pure handler logic, no infra needed |
| Middleware validation (e.g., idempotency key) → 400 | Integration | Requires the real middleware chain |
| Resource not found → 404 | Both acceptable | Integration: proves chain. Unit: proves error mapping |
| Database/infra error → 500 | Unit | Cannot force reliably with real infra |
| Circuit breaker open → 503 | Unit | Resilience pattern (e.g., gobreaker) |
| Context canceled → 499 | Unit | Timeout handling |
| Complex business logic (TTL defaults, OL) | Unit | Does not need real infra |
| Idempotency / deduplication | Integration | Requires real state in DB |
| Notifications (pg_notify, events) | Integration | Side effect of real infra |
| Side effects in another DB (e.g., Mongo collections) | Integration | Verifies real effect |
| Empty list serialization (`[]` vs `null`) | Integration | Contract verified with real DB |

For the expanded table with code examples, see [references/decision-table.md](references/decision-table.md).

## Testability Prerequisites

For handlers to be testable with mocks, they need these patterns. The skill does not prescribe file layout (that is the job of a project architecture skill like `/vertical-slice-architecture`), only what is needed for dual testing to work.

### Interface per handler (ISP)

Each handler defines a small interface for the data operations it needs — not a shared mega-interface:

```go
type Repository interface {
    ListItems(ctx context.Context, ownerID string) ([]Item, error)
}

type handler struct {
    repo Repository
}
```

### Pure constructor

`NewRepository` wraps the pool without validation — no ping, no health check. This is important because some integration tests deliberately pass a closed pool to verify that errors surface at request time, not at setup time:

```go
func NewRepository(db *pgxpool.Pool) Repository {
    return repository{db: db}
}
```

### Setup with dependency injection

A single `Setup` function that accepts the interface. The caller decides what to inject — real repo in production and integration tests, mock in unit tests:

```go
func Setup(r *gin.RouterGroup, repo Repository) {
    h := handler{repo: repo}
    r.GET("/items/:ownerID", h.handle)
}
```

### Hand-written mocks (testify/mock)

One mock per interface in `mocks_test.go`. Add a nil check before type assertions only for return types that can be nil (slices, pointers, maps). String or primitive returns do not need the check:

```go
// Slice return — needs nil check
func (m *mockRepository) ListItems(ctx context.Context, ownerID string) ([]Item, error) {
    args := m.Called(ctx, ownerID)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).([]Item), args.Error(1)
}

// String return — no nil check needed
func (m *mockRepository) DeleteItem(ctx context.Context, id string) (string, error) {
    args := m.Called(ctx, id)
    return args.String(0), args.Error(1)
}
```

### Transactional handlers

When a handler orchestrates a database transaction (Begin → queries → Commit), encapsulate the entire transaction in a single repository method. The handler only maps the result to an HTTP response. Use domain error sentinels to distinguish business errors (404) from infrastructure errors (500):

```go
var ErrNotFound = errors.New("resource not found")

// Repository method wraps the full transaction
func (r repository) DeleteItem(ctx context.Context, id, idemKey string) (string, error) {
    tx, err := r.db.Begin(ctx)
    // ... query, enqueue, commit ...
    if errors.Is(err, pgx.ErrNoRows) {
        return "", ErrNotFound
    }
    return opID, nil
}

// Handler just maps errors
opID, err := h.repo.DeleteItem(ctx, id, idem)
if err != nil {
    if errors.Is(err, ErrNotFound) {
        ctx.JSON(404, gin.H{"error": "not found"})
        return
    }
    ctx.JSON(500, gin.H{"error": "operation failed"})
    return
}
```

## Unit Tests with testify/suite

Use `testify/suite` so that `SetupTest()` creates fresh mocks before each test:

```go
type HandlerSuite struct {
    suite.Suite
    repo *mockRepository
    gin  *gin.Engine
}

func TestHandlerSuite(t *testing.T) {
    suite.Run(t, new(HandlerSuite))
}

func (s *HandlerSuite) SetupTest() {
    s.repo = new(mockRepository)
    gin.SetMode(gin.TestMode)
    s.gin = gin.New()
    group := s.gin.Group("/v1")
    Setup(group, s.repo)
}

func (s *HandlerSuite) Test_Returning_500_when_database_fails() {
    s.repo.On("ListItems", mock.Anything, "owner-1").
        Return(nil, errors.New("connection refused"))

    req, _ := http.NewRequest(http.MethodGet, "/v1/items/owner-1", nil)
    w := httptest.NewRecorder()
    s.gin.ServeHTTP(w, req)

    s.Equal(http.StatusInternalServerError, w.Code)
    s.repo.AssertExpectations(s.T())
}
```

## Worker Variant

Background workers that process operations via an engine dispatch loop (ClaimNext → handler → Succeed/Fail) need special handling:

- `SetupTest()` must create a **fresh engine** on every test — `Engine.Handle()` panics if you register the same handler type twice
- Mocks need expectations for the full dispatch protocol: `ClaimNext`, `ResolveTarget`, `SetKVSStatus`, `Succeed` or `Fail`
- For applier-factory failure tests, create a separate engine with a factory that returns an error

```go
func (s *WorkerSuite) SetupTest() {
    s.repo = new(MockOperationRepository)
    s.applier = new(MockApplier)
    s.engine = worker.New(s.repo, 30*time.Second) // fresh engine
    feature.Setup(s.engine, s.repo, func(ctx context.Context, uri string) (feature.ApplierInterface, error) {
        return s.applier, nil
    })
}
```

See [references/patterns.md](references/patterns.md) for complete worker test templates.

## Recommendations

These are trade-offs, not hard rules:

- **Fixed error messages in 500 responses**: For mutation endpoints where the API contract matters, consider returning a fixed error string instead of exposing `err.Error()` from the repository. This prevents coupling integration tests to internal error messages. Example: `ctx.JSON(500, gin.H{"error": "operation failed"})` instead of `ctx.JSON(500, gin.H{"error": err.Error()})`.
- **Empty slices**: Use `make([]T, 0)` instead of `var out []T` in repository list methods. This serializes as `[]` in JSON, not `null`. Integration tests should verify this contract.
- **go.mod**: The first time you add `testify/mock` to a project that only used `testify/suite` or `testify/require`, run `go mod tidy` — `testify/mock` brings `github.com/stretchr/objx` as an indirect dependency.

## When This Strategy Does NOT Apply

Not every test scenario needs the dual approach:

- **Pure functions** (no external dependencies): Use output-based tests directly. See `/test-namer` for guidance on testing styles.
- **Domain logic** without infrastructure dependencies: Unit tests with real objects, no mocks needed.
- **Utility code**: Simple tests, no strategy needed.

The dual testing strategy is specifically for code that sits at the boundary between your application and external infrastructure (databases, APIs, message queues).

## Composing with Other Skills

This skill decides **where** and **what type** of test to write. Other skills handle the rest:

- `/test-namer`: Decides **how to name** the test. Example: dual-testing says "this error path goes in handler_test.go as a unit test"; test-namer says "name it `Test_Returning_500_when_database_fails`".
- `/vertical-slice-architecture`: Decides **how to structure** the feature directory. Dual-testing decides which test files to create within that structure.
- `/low-complexity`: Applies to all code including tests — keeps test functions readable.

## Checklist

For each new handler or feature, verify:

- [ ] Handler has an interface for each external dependency (ISP)
- [ ] Repository with concrete implementation and `NewRepository()` constructor
- [ ] `Setup()` receives the interface, not a concrete type
- [ ] `mocks_test.go` with hand-written mock (testify/mock)
- [ ] `handler_test.go` with unit tests (testify/suite) for each `if err != nil` branch in the handler
- [ ] `integration_test.go` with happy paths using testcontainers
- [ ] Happy paths are NOT duplicated in unit tests
