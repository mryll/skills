# Test Anti-Patterns

Read this when reviewing existing tests or avoiding common mistakes. Based on Vladimir Khorikov's testing principles.

## Structural Inspection

Testing that a system has particular implementation characteristics rather than observable behavior.

**Bad** — verifying class implements an interface:
```csharp
Assert.IsAssignableFrom<IProcessor>(processor);
```

**Bad** — verifying internal sub-processor ordering:
```csharp
Assert.Equal(3, processors.Count);
Assert.IsAssignableFrom<HeaderProcessor>(processors[0]);
```

**Why it's wrong**: these tests can't distinguish a bug from a legit refactoring. Reordering components, removing interfaces, or restructuring internals breaks tests despite maintained functionality.

**Fix**: test the `Process` method's output, not the internal composition.

**Litmus test**: "Does this test verify a business requirement?" If not, delete it.

## Rigid Naming Conventions

Using `[MethodUnderTest]_[Scenario]_[ExpectedResult]` or similar templates.

**Bad**:
```
Sum_TwoNumbers_ReturnsSum
IsDeliveryValid_InvalidDate_ReturnsFalse
```

**Why it's wrong**: focuses on implementation (method names, return values), imposes cognitive tax, and couples test names to code structure. Renaming a method forces renaming tests.

**Fix**: plain English describing behavior:
```
Sum_of_two_numbers
Delivery_with_a_past_date_is_invalid
```

## Over-Mocking

Mocking stable internal dependencies (domain objects, value objects, repositories within the same context).

**Bad**:
```csharp
var mockOrder = new Mock<IOrder>();
mockOrder.Setup(o => o.GetTotal()).Returns(100);
sut.Process(mockOrder.Object);
mockOrder.Verify(o => o.ApplyDiscount(10), Times.Once);
```

**Why it's wrong**: couples test to internal collaboration sequence. Any refactoring of how `Process` interacts with `Order` breaks the test even if the final behavior is identical.

**Fix**: use real `Order` instance, verify the end state:
```csharp
var order = new Order(items);
sut.Process(order);
Assert.Equal(90, order.Total);
```

## Testing Implementation Details

Verifying how something works instead of what it produces.

Examples:
- Asserting exact SQL queries instead of query results
- Verifying method call counts on internal collaborators
- Checking private field values instead of public API state
- Asserting specific exception types for internal errors instead of observable error behavior

**Litmus test**: if you refactor the internals without changing behavior, does the test break? If yes, the test is coupled to implementation.

## "Should" in Test Names

Using `should_be`, `should_return`, `should_throw` in test names.

**Bad**: `Delivery_with_a_past_date_should_be_invalid`

**Why it's wrong**: a test is a fact, not a wish. "Should" implies uncertainty.

**Fix**: `Delivery_with_a_past_date_is_invalid`

## Vague Test Names

Using imprecise language that hides what the test actually verifies.

**Bad**: `Delivery_with_invalid_date_is_invalid`

**Why it's wrong**: "invalid date" is ambiguous — past date? Null date? Malformed string? The reader must read the test body to understand.

**Fix**: `Delivery_with_a_past_date_is_invalid` — specific and self-explanatory.

## Testing Trivial Code

Writing tests for getters, setters, simple property assignments, or configuration wiring.

**Why it's wrong**: zero regression detection value. These tests only add maintenance cost.

**Fix**: invest testing effort in domain models and algorithms where bugs actually hide.
