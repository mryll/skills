# Go Reference — Dual Testing

Concrete implementation of the dual testing strategy in Go. Read [../SKILL.md](../SKILL.md) first for the language-neutral strategy (what goes in each layer and why); this file gives the idiomatic Go tooling, test shape, and Go-specific gotchas.

**Stack**: Vertical Slice Architecture, Gin, pgx/pgxpool, MongoDB, testify (`mock` + `suite`), testcontainers-go. If your Go project uses a different router or driver, keep the strategy and translate the tooling.

## Testability Prerequisites

For handlers to be testable with mocks, they need these patterns. This is not about file layout (that is the job of an architecture skill like `/vertical-slice-architecture`), only what dual testing needs.

### Semantic port per handler (ISP)

Each handler defines a small interface for the data operations it needs — not a shared mega-interface. In Go the idiomatic boundary is a per-feature interface:

```go
type Repository interface {
    ListItems(ctx context.Context, ownerID string) ([]Item, error)
}

type handler struct {
    repo Repository
}
```

### Constructor without I/O

`NewRepository` wraps the pool without validation — no ping, no health check. This matters because some integration tests deliberately pass a closed pool to verify that errors surface at request time, not at setup time:

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

## Unit/Slice Tests with testify/suite

In Go the handler and its error mapping live in the same package, so the unit/slice test is a real Gin engine with the repository mocked — small, fast, no infra. Use `testify/suite` so that `SetupTest()` creates fresh mocks before each test:

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

See [go-patterns.md](go-patterns.md) for complete worker test templates.

## Go-Specific Recommendations

These are trade-offs, not hard rules:

- **Fixed error messages in 500 responses**: For mutation endpoints where the API contract matters, return a fixed error string instead of exposing `err.Error()` from the repository. Example: `ctx.JSON(500, gin.H{"error": "operation failed"})` instead of `ctx.JSON(500, gin.H{"error": err.Error()})`. This keeps integration tests from coupling to internal error messages.
- **Empty slices**: Use `make([]T, 0)` instead of `var out []T` in repository list methods. A nil slice serializes as `null` in JSON; `make([]T, 0)` serializes as `[]`. Integration tests should verify this contract. (This nil-vs-`[]` quirk is Go-specific — in most other languages an empty list already serializes as `[]`.)
- **go.mod**: The first time you add `testify/mock` to a project that only used `testify/suite` or `testify/require`, run `go mod tidy` — `testify/mock` brings `github.com/stretchr/objx` as an indirect dependency.

## Go Deep Dives

- [go-decision-table.md](go-decision-table.md) — expanded decision table with a Go code example per scenario
- [go-patterns.md](go-patterns.md) — complete copy-pasteable templates (handler, repository, mocks, unit, integration, worker)
- [go-anti-patterns.md](go-anti-patterns.md) — Go anti-patterns and CI/testcontainers troubleshooting
