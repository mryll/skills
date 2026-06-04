# .NET / C# Reference — Dual Testing

Concrete implementation of the dual testing strategy in ASP.NET Core. Read [../SKILL.md](../SKILL.md) first for the language-neutral strategy (what goes in each layer and why); this file gives the idiomatic .NET tooling, test shape, and gotchas.

**Stack**: ASP.NET Core, xUnit, [Testcontainers for .NET](https://dotnet.testcontainers.org/), `WebApplicationFactory<T>`, Moq (NSubstitute works the same way). If your project uses a different framework (Minimal APIs, FastEndpoints, gRPC), keep the strategy and translate the tooling.

The defining .NET trait: **the error-mapping layer lives outside the controller** (an `IExceptionHandler`, exception filter, or middleware). So the test that proves the mapping must run the real pipeline with the service mocked — a **slice test** via `WebApplicationFactory`, not a pure controller unit test.

## Testability Prerequisites

### Semantic port + DI

The handler depends on a narrow interface, not the DB driver. Register the real implementation in `Program.cs`; tests swap it for a mock.

```csharp
public interface IItemRepository
{
    Task<IReadOnlyList<Item>> ListItemsAsync(string ownerId, CancellationToken ct);
    Task<string> DeleteItemAsync(string id, string idempotencyKey, CancellationToken ct);
}

[ApiController]
[Route("v1/items")]
public sealed class ItemsController(IItemRepository repo) : ControllerBase
{
    [HttpGet("{ownerId}")]
    public Task<IReadOnlyList<Item>> List(string ownerId, CancellationToken ct)
        => repo.ListItemsAsync(ownerId, ct);

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(
        string id,
        [FromHeader(Name = "Idempotency-Key")] string idempotencyKey,
        CancellationToken ct)
    {
        var operationId = await repo.DeleteItemAsync(id, idempotencyKey, ct);
        return Accepted(new { operationId });
    }
}
```

### Constructor without I/O

The repository wraps the data source — no `Open()`, no ping. Let connection failures surface at request time so the unit/slice layer can exercise them.

```csharp
public sealed class ItemRepository(NpgsqlDataSource db) : IItemRepository
{
    // db is stored as-is. No connection opened here.
}
```

### Domain exceptions + mapping layer

Throw typed domain exceptions; map them centrally. The controller never builds error responses.

```csharp
public sealed class NotFoundException(string message) : Exception(message);

public sealed class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        var status = ex switch
        {
            NotFoundException => StatusCodes.Status404NotFound,
            _ => StatusCodes.Status500InternalServerError,   // do not leak ex.Message
        };
        ctx.Response.StatusCode = status;
        await ctx.Response.WriteAsJsonAsync(
            new ProblemDetails { Status = status, Title = status == 404 ? "not found" : "operation failed" }, ct);
        return true;
    }
}

// Program.cs
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddProblemDetails();
// ...
app.UseExceptionHandler();
```

`Program` must be reachable by the test host — add `public partial class Program { }` at the end of `Program.cs` so `WebApplicationFactory<Program>` can target it.

## Unit/Slice Tests — error mapping (Moq + WebApplicationFactory)

A factory that replaces the repository with a strict mock. The pipeline (controller + `DomainExceptionHandler`) is real, so this proves the mapping. xUnit instantiates the test class **per test**, so resetting the mock in the constructor gives fresh expectations each test (the .NET equivalent of testify's `SetupTest`).

```csharp
public sealed class MockedAppFactory : WebApplicationFactory<Program>
{
    public Mock<IItemRepository> Repo { get; } = new(MockBehavior.Strict);

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IItemRepository>();
            services.AddSingleton(Repo.Object);
        });
}

public sealed class ItemsErrorMappingTests : IClassFixture<MockedAppFactory>
{
    private readonly MockedAppFactory _factory;
    private readonly HttpClient _client;

    public ItemsErrorMappingTests(MockedAppFactory factory)
    {
        _factory = factory;
        _factory.Repo.Reset();           // fresh expectations per test
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Returning_500_when_database_fails()
    {
        _factory.Repo
            .Setup(r => r.ListItemsAsync("owner-1", It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("connection refused"));

        var res = await _client.GetAsync("/v1/items/owner-1");

        Assert.Equal(HttpStatusCode.InternalServerError, res.StatusCode);
    }

    [Fact]
    public async Task Returning_404_when_item_not_found()
    {
        _factory.Repo
            .Setup(r => r.DeleteItemAsync("missing", It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new NotFoundException("not found"));

        var res = await _client.SendAsync(
            new HttpRequestMessage(HttpMethod.Delete, "/v1/items/missing")
            {
                Headers = { { "Idempotency-Key", "k1" } },
            });

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }
}
```

Input validation that the framework owns (model binding, `[Required]`, missing required header) is also covered here — it runs in the same pipeline and the mock is never called.

## Integration Tests — happy paths (Testcontainers)

A factory that starts a real Postgres container via `IAsyncLifetime` and injects its **dynamic** connection string (never hardcode — Testcontainers assigns a random port).

```csharp
public sealed class PostgresAppFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _db = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public async Task InitializeAsync()
    {
        await _db.StartAsync();
        await Migrations.ApplyAsync(_db.GetConnectionString());   // create schema
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseSetting("ConnectionStrings:Default", _db.GetConnectionString());

    public new async Task DisposeAsync() => await _db.DisposeAsync();
}

public sealed class ItemsIntegrationTests(PostgresAppFactory factory) : IClassFixture<PostgresAppFactory>
{
    [Fact]
    public async Task Creating_item_then_listing_returns_it()
    {
        var client = factory.CreateClient();
        // Arrange: seed prerequisite rows directly, or POST through the API
        // Act: real HTTP request → controller → real repository → real Postgres
        var res = await client.GetAsync("/v1/items/owner-1");
        // Assert: status + body + verify DB state with a direct query
        res.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Empty_list_serializes_as_array_not_null()
    {
        var client = factory.CreateClient();
        var body = await client.GetStringAsync("/v1/items/owner-with-no-items");
        Assert.Equal("[]", body.Trim());
    }
}
```

## .NET-Specific Recommendations

- **Return an empty collection, never `null`.** `System.Text.Json` renders an empty `List<T>` as `[]` but `null` as `null`. The risk in .NET is a null return, not the empty-collection case Go has.
- **Use `ProblemDetails`** (`AddProblemDetails` + the exception handler) for a consistent error contract; map server errors to a fixed title, don't echo `ex.Message`.
- **Never hardcode connection strings** — inject `container.GetConnectionString()` via `UseSetting`/`ConfigureAppConfiguration`.
- **Reset state between tests**: start the container once per class/collection via `IAsyncLifetime`; reset rows between tests with [Respawn](https://github.com/jbogard/Respawn) or `TRUNCATE`. Reset the mock per test (constructor) in the slice layer.
- **Container fixture scope**: `IClassFixture` (per class) or `ICollectionFixture` (shared across a collection) keeps the container alive without restarting it per test.
