# Anti-Patterns and Troubleshooting

Common mistakes when implementing the dual testing strategy, and how to fix them.

## Anti-Patterns

### Duplicating happy paths in unit tests

**Problem**: Writing a unit test with a mock that returns a successful result and asserting 200/201, when an integration test already covers the same happy path with real infrastructure.

**Why it's bad**: The mock test doesn't prove anything the integration test doesn't — it only proves that your mock returns what you told it to return. It adds maintenance cost without adding confidence.

**Fix**: Happy paths belong in integration tests only. Unit tests cover error paths and business logic branches.

**Exception**: If the happy path involves logic that the integration test doesn't exercise (e.g., value type serialization, default TTL application, optimistic locking version handling), it belongs in unit tests — that's business logic, not a "happy path duplicate."

### Forcing infrastructure errors with testcontainers

**Problem**: Dropping tables, closing connections, pausing containers, or corrupting data to force a 500 error in an integration test.

**Why it's bad**: These tests are fragile, slow, non-deterministic, and test container lifecycle rather than your code's error handling.

**Fix**: Use unit tests with mocks to simulate infrastructure errors. `repo.On("Method", ...).Return(nil, errors.New("connection refused"))` is deterministic, fast, and tests exactly the code path you care about.

### Mocking pgxpool instead of a semantic interface

**Problem**: Creating a mock of `pgxpool.Pool` (or a thin DB interface with `Query`, `QueryRow`, `Exec`, `Begin`) and mocking at the SQL level.

**Why it's bad**: You end up mocking `Rows`, `Tx`, `Row` types — complex setup that's fragile and tests SQL strings rather than behavior. The mock is coupled to implementation details.

**Fix**: Define a semantic interface with domain methods (`ListItems`, `CreateItem`, `DeleteItem`). Mock at that level — simple, expressive, and implementation-agnostic.

### NewRepository that validates or pings the pool

**Problem**: Adding validation, ping, or health check logic inside `NewRepository()`.

```go
// BAD
func NewRepository(db *pgxpool.Pool) Repository {
    if err := db.Ping(context.Background()); err != nil {
        panic(err)
    }
    return repository{db: db}
}
```

**Why it's bad**: Some integration tests deliberately pass a closed pool to verify that errors are handled at request time. If `NewRepository` validates the pool, these tests fail at setup instead of exercising the error path.

**Fix**: `NewRepository` should be a pure wrapper.

```go
// GOOD
func NewRepository(db *pgxpool.Pool) Repository {
    return repository{db: db}
}
```

### Shared engine across suite tests (workers)

**Problem**: Creating the `worker.Engine` once in `SetupSuite()` or as a package-level variable, then using it across multiple test methods.

**Why it's bad**: `Engine.Handle()` panics with "duplicate handler registration" if called twice with the same operation type. Since `SetupTest()` re-registers the handler via `feature.Setup(s.engine, ...)`, a shared engine will panic on the second test.

**Fix**: Create a fresh engine in every `SetupTest()`.

```go
func (s *WorkerSuite) SetupTest() {
    s.repo = new(MockRepository)
    s.engine = worker.New(s.repo, 30*time.Second) // fresh engine
    feature.Setup(s.engine, s.repo, factory)       // safe to register
}
```

### Forgetting go mod tidy after adding testify/mock

**Problem**: Adding `testify/mock` imports to test files without running `go mod tidy`. CI fails with `go: updates to go.mod needed`.

**Why it's bad**: If CI commands end with `|| true` (common pattern), the tests silently don't run and coverage is reported as 0%.

**Fix**: Always run `go mod tidy` after adding new test imports. `testify/mock` brings `github.com/stretchr/objx` as an indirect dependency that needs to be recorded in `go.mod`.

## Troubleshooting

### SonarQube shows 0% coverage on new files

**Likely cause**: `go test` failed silently in CI (the command has `|| true`). Check CI logs for `go: updates to go.mod needed` — run `go mod tidy` and push.

### Integration test passes locally but fails in CI

**Common causes**:
- Docker-in-Docker (DinD) not configured — testcontainers needs `DOCKER_HOST` and `DOCKER_TLS_CERTDIR` variables
- Container startup timeout too low — increase `WithStartupTimeout` in CI environments
- Port conflicts — testcontainers uses random ports, verify no hardcoded ports in tests

### Tests depend on execution order

**Symptom**: Tests pass individually but fail when run together (or vice versa).

**Fix**: Add `SetupTest()` with `TRUNCATE ... RESTART IDENTITY CASCADE` to reset database state before each test. Never rely on data from a previous test.
