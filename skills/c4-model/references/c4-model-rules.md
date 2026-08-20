# C4 Model Rules

Condensed from the official documentation (c4model.com, read in full 2026-08-19). This file covers the model; Mermaid mechanics live in `mermaid-gitlab.md`.

## The abstractions

**Person** — a human user of the system: actor, role, persona, or named individual.

**Software system** — the highest abstraction: something that delivers value to its users, human or not. The hardest one to define. Useful heuristic: a software system is what a single team builds, owns, and can see inside; its boundary often matches the team boundary, sometimes a single repository, often a single deployment unit. Not *usually* software systems: product domains, bounded contexts, business capabilities, feature teams, tribes, squads.

**Container** — an application or data store; something that must be *running* for the system to work. It is a runtime or storage boundary, not Docker. Examples: server-side app, single-page app in a browser, mobile app, console app or batch process, a serverless function, a database schema, a document store, a blob bucket, a file system, a queue or topic, even a shell script. Rules of thumb:
- A server-rendered web app is one container; add a significant JavaScript SPA and it becomes two (two process spaces, inter-process communication).
- Managed services you configure and own (an S3 bucket, an RDS schema) are containers of YOUR system even though someone else hosts them.
- JARs, DLLs, modules, packages: not containers — they organize code inside one.

**Component** — a grouping of related functionality behind a well-defined interface, living inside one container. All components of a container execute in the same process space; components are not separately deployable. In OO code a component is typically several classes/interfaces behind a facade — never equate one class, package, folder, or namespace with a component automatically. Some shared code stays outside any component; that is normal.

**Code** — classes, interfaces, functions. Generate on demand from tooling; rarely worth maintaining by hand.

## The views

| View | Scope | Primary elements | Audience | Recommended |
|---|---|---|---|---|
| System Context | one system | the system in scope; people + directly connected systems | everyone, incl. non-technical | yes, for every team |
| Container | one system | its containers; people + connected systems | technical, inside/outside the team | yes, for every team |
| Component | one container | its components (supporting: connected containers, people, systems) | architects, developers | only if it adds value; consider generating from code |
| Code | one component | classes/functions | developers | no; on demand from IDE/tooling |
| System Landscape | an organization/department | people + all systems in scope | everyone | yes for larger orgs |
| Dynamic | one feature/story/use case | any elements collaborating at runtime | everyone | sparingly, for interesting or complex interactions |
| Deployment | one environment | deployment nodes + instances of systems/containers | technical + ops | yes, one per environment that matters |

**Context vs Landscape**: a Landscape is "a context diagram without a specific focus on one system" — a map of the neighborhood. In a strict Context view, every relationship touches the system in scope; relationships between third parties belong in the Landscape.

**Context views avoid technology**: they focus on people and systems, "rather than technologies, protocols and other low-level details". Technology talk starts at the Container view.

**Deployment**: a container view says nothing about clustering, replicas, or failover — that is deployment information, captured per environment. Deployment nodes nest (cloud → cluster → runtime), and infrastructure nodes (DNS, load balancers, firewalls) may appear as nodes. Icons are fine if the key explains them.

## Microservices

Ownership strongly informs the abstraction — together with whether the services are an internal implementation detail of one system or products in their own right:
- Services owned by **one team** inside one product: model each microservice as a container (or a small group — e.g. API + its schema + a worker). The container diagram shows them all inside the system boundary.
- Services **owned by separate teams**: promote each to a software system, and draw each team's view with the other systems as black boxes.
- A microservice is not automatically one container: it may be several (API, schema, worker). Repository layout and team names are signals, not laws.

## Queues and topics

Never model the message bus as one container — a "Kafka" box hides the real coupling. Two officially valid options:
1. Model each queue/topic as a container (a queue is a data store: producers put data in, consumers take it out).
2. Omit the queue element and put the channel on the relationship label ("sends order events to, via order.created topic").

Pick per diagram based on how load-bearing the queues are. When services belong to different systems, decide (and state) who owns each queue — ownership affects the diagrams.

## Coherence across the diagram set

The classic failures of ad-hoc diagrams: inconsistent notation between diagrams, inconsistent names, no clear reading order, no clear transition between levels. Prevent all four by building the canonical model first (one name per element, reused everywhere), ordering documents from Context downward, and making each lower view a strict zoom of one element from the view above.

## When a diagram grows too big

Don't fight a cluttered canvas — split into several focused diagrams at the same abstraction level, each telling part of the same story. Official split options: business area, functional area or grouping, bounded context, use case, user interaction, feature set, or one view per service showing only its nearest inbound and outbound dependencies. Note in each document which slice it shows.

## Freshness

Context and Container views change slowly; Component views churn with active development; Code views can become outdated very quickly. For long-lived docs, prefer few hand-maintained high-level views + generated lower-level ones. Deployment views can be derived from IaC (Helm, Terraform, manifests).

## Adapting the model

Renaming levels or adding abstraction levels is allowed but is an advanced move: only with a rigorous written definition, otherwise you re-create the ad-hoc-boxes problem C4 exists to fix. Default to the four standard abstractions.

## Self-review checklist

Before delivering, answer for every diagram — fix anything that fails:

1. Does it have a title with diagram type and scope, and a key?
2. Does every element have a name, an explicit type, and a clear responsibility?
3. Is every needed technology stated (containers, components, container-to-container relationships)?
4. Would every acronym be understood by the audience, or is it explained?
5. Does every arrow have a specific label whose wording matches the arrow's direction?
6. Are protocols stated where the relationship is inter-process (and absent from Context/Landscape)?
7. Is the notation consistent with the other diagrams in the set — same names, and the same meaning for every shape, color, icon, border style, line style, arrowhead, and element size used?
8. Can the diagram be (mostly) understood standing alone, without a narrator?
