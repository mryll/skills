# Java Reference — Dual Testing

Concrete implementation of the dual testing strategy in Spring Boot. Read [../SKILL.md](../SKILL.md) first for the language-neutral strategy (what goes in each layer and why); this file gives the idiomatic Spring tooling, test shape, and gotchas.

**Stack**: Spring Boot 3.1+, JUnit 5, [Testcontainers](https://java.testcontainers.org/) with `@ServiceConnection`, MockMvc / `@WebMvcTest`, Mockito. If your project uses Quarkus or Micronaut instead, keep the strategy and translate the tooling (see the last section).

The defining Spring trait: **the error-mapping layer lives outside the controller** (a `@RestControllerAdvice` / `@ExceptionHandler`). So the test that proves the mapping is a **web slice** (`@WebMvcTest`) that loads the controller plus the advice with the service mocked — not a plain controller unit test.

## Testability Prerequisites

### Semantic port + constructor injection

The controller depends on a narrow interface, injected via the constructor. Spring wires the real bean in production; tests provide a mock.

```java
public interface ItemRepository {
    List<Item> listItems(String ownerId);
    String deleteItem(String id, String idempotencyKey);
}

@RestController
@RequestMapping("/v1/items")
class ItemsController {
    private final ItemRepository repo;

    ItemsController(ItemRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/{ownerId}")
    List<Item> list(@PathVariable String ownerId) {
        return repo.listItems(ownerId);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.ACCEPTED)
    Map<String, String> delete(@PathVariable String id,
                               @RequestHeader("Idempotency-Key") String idempotencyKey) {
        return Map.of("operationId", repo.deleteItem(id, idempotencyKey));
    }
}
```

The implementation bean stores its `JdbcTemplate`/`DataSource` without opening a connection in the constructor — let failures surface at request time so the slice layer can exercise them.

### Domain exceptions + mapping layer

Throw typed domain exceptions; map them centrally with `ProblemDetail` (RFC 7807). The controller never builds error responses.

```java
public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) { super(message); }
}

@RestControllerAdvice
class DomainExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    ProblemDetail notFound(NotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, "not found");
    }

    @ExceptionHandler(Exception.class)
    ProblemDetail internal(Exception ex) {   // do not leak ex.getMessage()
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "operation failed");
    }
}
```

## Unit/Slice Tests — error mapping (`@WebMvcTest` + Mockito)

`@WebMvcTest` loads only the web layer plus the `@RestControllerAdvice`, with the repository mocked — so this proves the mapping without any infrastructure. JUnit 5 uses a fresh instance per test method and Mockito resets the mock each test (the Spring equivalent of testify's `SetupTest`).

```java
@WebMvcTest(ItemsController.class)
class ItemsErrorMappingTests {

    @Autowired
    MockMvc mvc;

    @MockitoBean            // @MockBean before Spring Boot 3.4
    ItemRepository repo;

    @Test
    void returning_500_when_database_fails() throws Exception {
        when(repo.listItems("owner-1"))
            .thenThrow(new RuntimeException("connection refused"));

        mvc.perform(get("/v1/items/owner-1"))
           .andExpect(status().isInternalServerError());
    }

    @Test
    void returning_404_when_item_not_found() throws Exception {
        when(repo.deleteItem(eq("missing"), anyString()))
            .thenThrow(new NotFoundException("not found"));

        mvc.perform(delete("/v1/items/missing").header("Idempotency-Key", "k1"))
           .andExpect(status().isNotFound());
    }

    @Test
    void returning_400_when_idempotency_header_missing() throws Exception {
        // framework-owned validation: the missing @RequestHeader fails before the controller body
        mvc.perform(delete("/v1/items/x"))
           .andExpect(status().isBadRequest());
        verifyNoInteractions(repo);
    }
}
```

## Integration Tests — happy paths (Testcontainers + `@ServiceConnection`)

`@ServiceConnection` (Spring Boot 3.1+) auto-wires the datasource from the container — no `@DynamicPropertySource` boilerplate. The container uses a random port; Spring discovers it automatically.

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Testcontainers
class ItemsIntegrationTests {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    MockMvc mvc;

    @Test
    void creating_item_then_listing_returns_it() throws Exception {
        // Arrange: seed rows (repository or SQL). Act: real request → controller → repo → real Postgres.
        mvc.perform(get("/v1/items/owner-1"))
           .andExpect(status().isOk());
    }

    @Test
    void empty_list_serializes_as_array_not_null() throws Exception {
        mvc.perform(get("/v1/items/owner-with-no-items"))
           .andExpect(status().isOk())
           .andExpect(content().json("[]"));
    }
}
```

Apply the schema with Flyway/Liquibase or `schema.sql`. Reset state between tests with `@Transactional` (rolls back after each test) or a `@BeforeEach` truncate.

## Java-Specific Recommendations

- **Return an empty `List`, never `null`.** Jackson serializes an empty list as `[]` but `null` as `null`. The risk in Java is a null return, not the empty-collection case Go has.
- **Use `@ServiceConnection`** (Boot 3.1+) over `@DynamicPropertySource` — it auto-creates the connection details bean from the container.
- **Use `ProblemDetail`** (RFC 7807) for a consistent error contract; fixed messages on 500, don't echo `ex.getMessage()`.
- **`@MockitoBean`** is the current annotation (Spring Framework 6.2 / Boot 3.4+); use `@MockBean` on older versions.
- **Reset DB state**: `@Transactional` rollback per test, or `@BeforeEach` truncate; start the container once per class via the static `@Container` field.
- **Different framework?** Quarkus: `@QuarkusTest` + Dev Services (auto-Testcontainers) + `@InjectMock`. Micronaut: `@MicronautTest` + Test Resources. Same strategy — integration for happy paths, mocked slice for error mapping — different annotations.
