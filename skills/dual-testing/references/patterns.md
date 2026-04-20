# Code Patterns — Complete Templates

Copy-pasteable templates for each file in the dual testing pattern. Based on real implementations.

## HTTP Handler Pattern

### handler.go

```go
package feature

import (
    "context"
    "errors"
    "log/slog"
    "net/http"

    "github.com/gin-gonic/gin"
)

var ErrNotFound = errors.New("resource not found")

type Repository interface {
    DoSomething(ctx context.Context, id string) (string, error)
}

type handler struct {
    repo Repository
}

func Setup(r *gin.RouterGroup, repo Repository) {
    h := handler{repo: repo}
    r.POST("/resources/:id", h.handle)
}

func (h handler) handle(ctx *gin.Context) {
    id := ctx.Param("id")
    if id == "" {
        ctx.JSON(http.StatusBadRequest, gin.H{"error": "id is required"})
        return
    }

    result, err := h.repo.DoSomething(ctx, id)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            ctx.JSON(http.StatusNotFound, gin.H{"error": "not found"})
            return
        }
        slog.Error("operation failed", "id", id, "error", err)
        ctx.JSON(http.StatusInternalServerError, gin.H{"error": "operation failed"})
        return
    }

    ctx.JSON(http.StatusOK, gin.H{"result": result})
}
```

### repository.go — Simple query

```go
package feature

import (
    "context"

    "github.com/jackc/pgx/v5/pgxpool"
)

type repository struct {
    db *pgxpool.Pool
}

// NewRepository is a pure wrapper — no validation, no ping.
func NewRepository(db *pgxpool.Pool) Repository {
    return repository{db: db}
}

func (r repository) DoSomething(ctx context.Context, id string) (string, error) {
    var result string
    err := r.db.QueryRow(ctx, `SELECT name FROM resources WHERE id = $1`, id).Scan(&result)
    if err != nil {
        return "", err
    }
    return result, nil
}
```

### repository.go — Transactional

```go
package feature

import (
    "context"
    "errors"
    "fmt"
    "log/slog"

    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"
)

type repository struct {
    db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) Repository {
    return repository{db: db}
}

func (r repository) DoSomething(ctx context.Context, id, idemKey string) (string, error) {
    tx, err := r.db.Begin(ctx)
    if err != nil {
        return "", fmt.Errorf("begin tx: %w", err)
    }
    defer func() {
        if err := tx.Rollback(ctx); err != nil && err != pgx.ErrTxClosed {
            slog.Error("rollback failed", "error", err)
        }
    }()

    // Query within transaction
    var resourceID string
    err = tx.QueryRow(ctx, `UPDATE ... RETURNING id`, id).Scan(&resourceID)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return "", ErrNotFound
        }
        return "", fmt.Errorf("query: %w", err)
    }

    // Enqueue operation, notify, etc.
    // ...

    if err := tx.Commit(ctx); err != nil {
        return "", fmt.Errorf("commit: %w", err)
    }

    return resourceID, nil
}
```

### mocks_test.go

```go
package feature

import (
    "context"

    "github.com/stretchr/testify/mock"
)

type mockRepository struct {
    mock.Mock
}

// String return — no nil check needed
func (m *mockRepository) DoSomething(ctx context.Context, id string) (string, error) {
    args := m.Called(ctx, id)
    return args.String(0), args.Error(1)
}
```

For methods returning slices, pointers, or interfaces — add the nil guard:

```go
// Slice return — needs nil check
func (m *mockRepository) ListItems(ctx context.Context, ownerID string) ([]Item, error) {
    args := m.Called(ctx, ownerID)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).([]Item), args.Error(1)
}
```

### handler_test.go — Unit tests (error paths)

```go
package feature

import (
    "errors"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/mock"
    "github.com/stretchr/testify/suite"
)

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
    s.repo.On("DoSomething", mock.Anything, "res-1").
        Return("", errors.New("connection refused"))

    req, _ := http.NewRequest(http.MethodPost, "/v1/resources/res-1", nil)
    w := httptest.NewRecorder()
    s.gin.ServeHTTP(w, req)

    s.Equal(http.StatusInternalServerError, w.Code)
    s.repo.AssertExpectations(s.T())
}

func (s *HandlerSuite) Test_Returning_404_when_resource_not_found() {
    s.repo.On("DoSomething", mock.Anything, "missing").
        Return("", ErrNotFound)

    req, _ := http.NewRequest(http.MethodPost, "/v1/resources/missing", nil)
    w := httptest.NewRecorder()
    s.gin.ServeHTTP(w, req)

    s.Equal(http.StatusNotFound, w.Code)
    s.repo.AssertExpectations(s.T())
}

func (s *HandlerSuite) Test_Returning_400_when_id_is_empty() {
    req, _ := http.NewRequest(http.MethodPost, "/v1/resources/", nil)
    w := httptest.NewRecorder()
    s.gin.ServeHTTP(w, req)

    s.Equal(http.StatusBadRequest, w.Code)
    s.repo.AssertNotCalled(s.T(), "DoSomething", mock.Anything, mock.Anything)
}
```

### integration_test.go — Happy paths

```go
package feature_test

import (
    "context"
    "net/http"
    "net/http/httptest"
    "testing"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/stretchr/testify/suite"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
    "github.com/testcontainers/testcontainers-go/wait"
    "your/module/internal/features/feature"
)

type IntegrationSuite struct {
    suite.Suite
    ctx  context.Context
    pg   *postgres.PostgresContainer
    pool *pgxpool.Pool
}

func TestIntegrationSuite(t *testing.T) {
    suite.Run(t, new(IntegrationSuite))
}

func (s *IntegrationSuite) SetupSuite() {
    testcontainers.SkipIfProviderIsNotHealthy(s.T())
    s.ctx = context.Background()

    pgc, err := postgres.Run(s.ctx, "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("testuser"),
        postgres.WithPassword("testpass"),
        postgres.WithInitScripts("path/to/migrations.sql"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections").
                WithOccurrence(2).
                WithStartupTimeout(90*time.Second),
        ),
    )
    s.Require().NoError(err)
    s.pg = pgc

    connStr, _ := s.pg.ConnectionString(s.ctx, "sslmode=disable")
    cfg, _ := pgxpool.ParseConfig(connStr)
    cfg.ConnConfig.ConnectTimeout = 10 * time.Second
    pool, err := pgxpool.NewWithConfig(s.ctx, cfg)
    s.Require().NoError(err)

    // Wait for pool readiness with retry
    deadline := time.Now().Add(15 * time.Second)
    for time.Now().Before(deadline) {
        ctx, cancel := context.WithTimeout(s.ctx, 2*time.Second)
        if pool.Ping(ctx) == nil {
            cancel()
            break
        }
        cancel()
        time.Sleep(300 * time.Millisecond)
    }
    s.pool = pool
}

func (s *IntegrationSuite) TearDownSuite() {
    if s.pool != nil { s.pool.Close() }
    if s.pg != nil { s.pg.Terminate(s.ctx) }
}

func (s *IntegrationSuite) SetupTest() {
    // Truncate tables to isolate tests
    _, err := s.pool.Exec(s.ctx, `TRUNCATE my_table RESTART IDENTITY CASCADE`)
    s.Require().NoError(err)
}

// Router helper — creates a fresh gin engine with the real repository
func (s *IntegrationSuite) router() *gin.Engine {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    group := r.Group("/v1")
    feature.Setup(group, feature.NewRepository(s.pool))
    return r
}

func (s *IntegrationSuite) Test_Creating_resource_returns_success() {
    // Arrange: insert prerequisite data
    // Act: send HTTP request via httptest
    // Assert: check response + verify DB state
}
```

## Worker Pattern

### handler_test.go — Worker with engine

```go
package feature_test

import (
    "context"
    "errors"
    "testing"
    "time"

    "your/module/internal/features/feature"
    "your/module/internal/platform/repo"
    "your/module/internal/platform/worker"

    "github.com/stretchr/testify/mock"
    "github.com/stretchr/testify/suite"
)

type WorkerSuite struct {
    suite.Suite
    repo    *MockOperationRepository
    applier *MockApplier
    engine  *worker.Engine
}

func TestWorkerSuite(t *testing.T) {
    suite.Run(t, new(WorkerSuite))
}

// CRITICAL: Engine.Handle panics on duplicate registration.
// Each test needs a fresh engine.
func (s *WorkerSuite) SetupTest() {
    s.repo = new(MockOperationRepository)
    s.applier = new(MockApplier)
    s.engine = worker.New(s.repo, 30*time.Second)
    feature.Setup(s.engine, s.repo, func(ctx context.Context, uri string) (feature.ApplierInterface, error) {
        return s.applier, nil
    })
}

func (s *WorkerSuite) Test_Returning_error_when_operation_fails() {
    ctx := context.Background()
    opErr := errors.New("operation failed")

    op := &repo.Operation{ID: "op-1", Type: "MY_OP", KVSID: "kvs-1", Attempt: 5}
    target := &repo.Target{
        MongoURI:       "mongodb://localhost:27017",
        DatabaseName:   "testdb",
        CollectionName: "testcoll",
    }

    // Mock the full engine dispatch protocol
    s.repo.On("ClaimNext", ctx, 30*time.Second).Return(op, true, nil).Once()
    s.repo.On("ClaimNext", ctx, 30*time.Second).Return(nil, false, nil).Once()
    s.repo.On("ResolveTarget", mock.Anything, "kvs-1").Return(target, nil)

    s.applier.On("DoWork", mock.Anything, "testdb", "testcoll").Return(opErr)
    s.applier.On("Close", mock.Anything).Return(nil)
    s.repo.On("SetKVSStatus", mock.Anything, "kvs-1", "FAILED", opErr).Return(nil)
    s.repo.On("Fail", mock.Anything, "op-1", opErr).Return(nil)

    s.engine.DrainAll(ctx)

    s.repo.AssertExpectations(s.T())
    s.applier.AssertExpectations(s.T())
}

// Factory failure test — needs its own engine with a failing factory
func (s *WorkerSuite) Test_Returning_error_when_applier_connection_fails() {
    ctx := context.Background()
    connectErr := errors.New("connection failed")

    // Override with a failing factory
    s.engine = worker.New(s.repo, 30*time.Second)
    feature.Setup(s.engine, s.repo, func(ctx context.Context, uri string) (feature.ApplierInterface, error) {
        return nil, connectErr
    })

    // ... setup ClaimNext, ResolveTarget, Fail expectations ...
    s.engine.DrainAll(ctx)
    s.repo.AssertExpectations(s.T())
}
```
