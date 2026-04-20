# Decision Table — Expanded

Detailed guide for deciding where each test scenario belongs, with setup examples.

## Integration Test Scenarios

These scenarios need real infrastructure to be meaningful.

### Happy path (CRUD success)

Verifies that the full chain works: real HTTP request → real middleware → handler → repository → real database → correct response.

```go
func (s *Suite) Test_Creating_item_returns_accepted_with_operation_id() {
    // Insert prerequisite data directly via pool
    _, err := s.pool.Exec(s.ctx, `INSERT INTO ...`)
    s.Require().NoError(err)

    // Send real HTTP request
    w := s.postJSON(s.router(), "/v1/items", body, headers)
    s.Equal(http.StatusAccepted, w.Code)

    // Verify side effects in real DB
    var status string
    s.pool.QueryRow(s.ctx, "SELECT status FROM ...").Scan(&status)
    s.Equal("ACTIVE", status)
}
```

### Middleware validation (e.g., missing idempotency key)

Middleware runs before the handler — you need the real middleware chain to test it.

```go
func (s *Suite) Test_Missing_idempotency_key_returns_400() {
    w := s.postJSON(s.router(), "/v1/items", body, nil) // no headers
    s.Equal(http.StatusBadRequest, w.Code)
}
```

### Idempotency / deduplication

Requires real state in the database to verify that repeated requests produce the same result.

```go
func (s *Suite) Test_Repeating_request_with_same_key_reuses_operation() {
    headers := map[string]string{"Idempotency-Key": "same-key"}
    w1 := s.postJSON(r, url, body, headers)
    w2 := s.postJSON(r, url, body, headers)

    s.Equal(w1.Body.String(), w2.Body.String()) // same operation ID
}
```

### Notifications (pg_notify)

Side effect that only fires with a real database.

```go
func (s *Suite) Test_Operation_notifies_listeners() {
    conn, _ := s.pool.Acquire(s.ctx)
    defer conn.Release()
    conn.Exec(s.ctx, "LISTEN channel_name")

    // Trigger the operation...
    // Wait for notification...
}
```

### Empty list serialization

Verifies the JSON contract (`[]` not `null`) with real data flow.

```go
func (s *Suite) Test_Empty_list_returns_json_array_not_null() {
    w := s.get(s.router(), "/v1/projects/empty-project/items")
    s.Equal(http.StatusOK, w.Code)
    s.Equal("[]", strings.TrimSpace(w.Body.String()))
}
```

## Unit Test Scenarios

These scenarios test handler logic in isolation using mocks.

### Database error → 500

The repository returns a generic error. The handler should return 500 without exposing internal details.

```go
func (s *Suite) Test_Returning_500_when_database_fails() {
    s.repo.On("ListItems", mock.Anything, "owner").
        Return(nil, errors.New("connection refused"))

    // ... send request, assert 500
}
```

### Domain error → 404

The repository returns a domain sentinel error. The handler maps it to the correct HTTP status.

```go
func (s *Suite) Test_Returning_404_when_item_not_found() {
    s.repo.On("DeleteItem", mock.Anything, "proj", "missing", "key").
        Return("", ErrNotFound)

    // ... send request, assert 404
}
```

### Input validation → 400

Handler validates input before calling the repository. The mock should never be called.

```go
func (s *Suite) Test_Returning_400_when_owner_id_is_missing() {
    req, _ := http.NewRequest(http.MethodGet, "/v1/projects//items", nil)
    w := httptest.NewRecorder()
    s.gin.ServeHTTP(w, req)

    s.Equal(http.StatusBadRequest, w.Code)
    s.repo.AssertNotCalled(s.T(), "ListItems", mock.Anything, mock.Anything)
}
```

### Circuit breaker open → 503

Framework-specific pattern (e.g., gobreaker). The repository returns a breaker error.

```go
func (s *Suite) Test_Returning_503_when_circuit_breaker_is_open() {
    s.repo.On("GetItem", mock.Anything, mock.Anything, mock.Anything).
        Return(nil, gobreaker.ErrOpenState)

    // ... send request, assert 503
}
```

### Business logic (not covered by integration)

Tests for behavior driven by configuration or catalog data that integration tests don't exercise.

```go
func (s *Suite) Test_Default_TTL_applied_when_catalog_enables_it() {
    catalog := testcatalog.New(catalog.Entry{DefaultTTL: 3600, TTLEnabled: true})
    // ... verify the handler passes the default TTL to the repository
}
```
