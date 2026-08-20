# C4-PlantUML on GitLab — primary notation

C4-PlantUML (the plantuml-stdlib library) is the de-facto standard C4 notation: official-looking elements, a Graphviz layout where relationship labels participate in layout (greatly reducing overlaps), and a native legend. GitLab renders fenced `plantuml` blocks server-side.

## Verified support matrix

Probed directly against the PlantUML server GitLab.com uses (`plantuml.gitlab-static.net`), 2026-08-19, by requesting rendered PNGs:

- WORKS: `!include <C4/C4_Context>`, `<C4/C4_Container>`, `<C4/C4_Component>`, `<C4/C4_Sequence>`, `<C4/C4_Dynamic>`, `<C4/C4_Deployment>` (with nested `Deployment_Node`).
- WORKS: `SHOW_LEGEND(false)` (verified visually: keeps the element type tags AND draws the legend), `LAYOUT_LEFT_RIGHT()`, `SHOW_ELEMENT_DESCRIPTIONS()`, `SHOW_INDEX()`, sequence `alt/else`, `Rel(..., $rel="-->")`.
- **FAILS (HTTP 400): `SHOW_ELEMENT_TYPE()`** — the server bundles an older library version. Never use it; element types render by default anyway.
- GitLab Markdown renders PlantUML as **PNG only**. Acceptable; it reinforces splitting oversized diagrams.

**For a different GitLab instance, re-probe before relying on this**: paste the smallest example below in a comment/MR preview. Record the date and what you probed. The server owns the library version — re-verify after server upgrades.

## GitLab block rule

Inside a fenced `plantuml` block, **omit `@startuml`/`@enduml`** — GitLab adds them. (When probing a raw PlantUML server directly, include them.)

## Per-view include and initial direction

| View | Include | Initial layout |
|---|---|---|
| System landscape | `<C4/C4_Context>` | `LAYOUT_TOP_DOWN()` (the default) |
| System context | `<C4/C4_Context>` | `LAYOUT_LEFT_RIGHT()` |
| Container | `<C4/C4_Container>` | `LAYOUT_LEFT_RIGHT()` |
| Component | `<C4/C4_Component>` | `LAYOUT_LEFT_RIGHT()` |
| Dynamic (sequence) | `<C4/C4_Sequence>` | no layout macro |
| Deployment | `<C4/C4_Deployment>` | `LAYOUT_TOP_DOWN()` |

The direction is a starting value — switch it when the content favors the other orientation. Put configuration macros before element declarations; put `SHOW_LEGEND(false)` last — always with `false`: plain `SHOW_LEGEND()` hides every element's type tag, which violates the explicit-type rule.

## Elements

Use the macro arguments — never manual line breaks:

```text
Person(emp, "Employee", "Creates and follows up tasks.")
System(taskflow, "TaskFlow", "Lets employees manage team tasks.")
System_Ext(mail, "Mail Gateway", "Company e-mail delivery.")
Container(api, "API", "Go", "Task rules and persistence.")
ContainerDb(db, "Database", "PostgreSQL schema", "Tasks and assignments.")
ContainerQueue(events, "task.events", "Kafka topic", "Task state changes.")
Component(svc, "Task Service", "Go", "Task lifecycle rules.")
System_Boundary(tf, "TaskFlow") { ... }
Container_Boundary(apib, "API") { ... }
Deployment_Node(k8s, "Kubernetes cluster", "3 nodes", "Runs the workloads.") { ... }
```

- Name, technology (containers/components), and responsibility go in the arguments; the library renders the type tag itself.
- `_Ext` variants mark out-of-scope elements (rendered gray).
- No `$sprite`, no remote themes, no external icon includes — keep the built-in person symbol. Icons would also need explaining in the key.

## Relationships

```text
Rel(app, api, "Submits and retrieves tasks through", "JSON/HTTPS")
```

- Plain `Rel` with a specific verb phrase; technology/protocol as the fourth argument on container-to-container relationships; none in Context/Landscape views.
- Never `BiRel`. Never duplicate a directed pair without a real semantic difference.
- `Rel_U/D/L/R` only AFTER seeing a real layout problem in the render — never as blind preemptive tuning. `Lay_U/D/L/R` only for unrelated elements, as a last resort.
- Do not use `RelIndex` (deprecated); if numbering is truly needed in a sequence, `SHOW_INDEX()` exists — vertical order usually suffices.

## Dynamic views: C4_Sequence

Use `<C4/C4_Sequence>` (not `<C4/C4_Dynamic>` — that one draws the collaboration variant). Declare C4 elements as participants and use PlantUML sequence constructs:

```plantuml
!include <C4/C4_Sequence>
title Dynamic diagram for TaskFlow task creation
SHOW_ELEMENT_DESCRIPTIONS()

Container(app, "Web App", "JavaScript SPA", "Task UI in the browser.")
Container(api, "API", "Go", "Task rules and persistence.")
ContainerDb(db, "Database", "PostgreSQL schema", "Tasks and assignments.")

Rel(app, api, "submits the task form", "JSON/HTTPS")
Rel(api, db, "inserts the task", "SQL")
alt insert fails
  Rel(api, db, "retries the insert once", "SQL")
  alt retry succeeds
    Rel(api, app, "returns the created task", "JSON/HTTPS", $rel="-->")
  else retry fails
    Rel(api, app, "reports the error", "JSON/HTTPS", $rel="-->")
  end
else success
  Rel(api, app, "returns the created task", "JSON/HTTPS", $rel="-->")
end
SHOW_LEGEND(false)
```

- `SHOW_ELEMENT_DESCRIPTIONS()` keeps each participant's responsibility visible, so the view stands alone.
- `$rel="-->"` marks responses as dashed. `alt/else`, `loop`, `par`, `group`, `ref` are all available — retries and branches are first-class here.
- `SHOW_LEGEND(false)` does not explain sequence constructs: keep a brief Markdown Key for dashed responses and `alt`/`loop` frames.

## Deployment views

- One diagram per environment. Nest `Deployment_Node`; place system/container instances inside as leaves.
- `ContainerDb`/`ContainerQueue` instances where they apply. Show replica counts in the node's type argument when confirmed ("Deployment, 3 replicas").
- Infrastructure (DNS, load balancers, firewalls) = `Deployment_Node`, never fake containers.

## Legend and the Markdown unit

`SHOW_LEGEND(false)` renders the notation key inside the image — the Markdown unit then carries only: intro, Acronyms (if any), Scope and assumptions, Evidence (for code-derived docs), and a brief Key ONLY for sequence constructs the legend misses. Everything else in the output contract (SKILL.md) applies unchanged.

## Complete example — Container view as delivered

````markdown
## Container diagram for TaskFlow

The applications and data stores inside TaskFlow, and how they communicate.

```plantuml
!include <C4/C4_Container>
LAYOUT_LEFT_RIGHT()
title Container diagram for TaskFlow

Person(emp, "Employee", "Creates and follows up tasks.")
System_Boundary(tf, "TaskFlow") {
  Container(app, "Web App", "JavaScript SPA", "Task UI in the browser.")
  Container(api, "API", "Go", "Task rules and persistence.")
  ContainerDb(db, "Database", "PostgreSQL schema", "Tasks and assignments.")
  ContainerQueue(events, "task.events", "Kafka topic", "Task state changes.")
}
System_Ext(mail, "Mail Gateway", "Company e-mail delivery.")

Rel(emp, app, "Manages tasks with")
Rel(app, api, "Submits and retrieves tasks through", "JSON/HTTPS")
Rel(api, db, "Reads from and writes to", "SQL")
Rel(api, events, "Publishes task changes to", "Kafka protocol")
Rel(api, mail, "Sends notifications with", "SMTP")
SHOW_LEGEND(false)
```

### Acronyms

| Acronym | Meaning |
|---|---|
| API | Application Programming Interface |
| UI | User Interface |
| SPA | Single-page application |
| JSON | JavaScript Object Notation |
| HTTPS | Hypertext Transfer Protocol Secure |
| SQL | Structured Query Language (database access) |
| SMTP | Simple Mail Transfer Protocol |

### Scope and assumptions

- Conceptual example; represents the current architecture of the fictional TaskFlow.
````

## Minimal probe (for a new instance)

```plantuml
!include <C4/C4_Context>
Person(user, "User", "Tests diagram rendering.")
System(probe, "Probe", "Tests C4-PlantUML support.")
Rel(user, probe, "Tests diagram rendering with")
SHOW_LEGEND(false)
```

If this renders in a comment preview, the instance supports C4-PlantUML; then spot-check every include you will use — `<C4/C4_Container>`, `<C4/C4_Component>`, `<C4/C4_Sequence>`, nested `<C4/C4_Deployment>` — before committing a full document set.
