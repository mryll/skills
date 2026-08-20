# Codebase Analysis — Evidence Before Model

For documenting an existing repository. The model must be *derived* from evidence, never guessed: a wrong architecture diagram is worse than none, because readers trust it. Separate what the code proves from what you infer, and mark everything unconfirmed in the "Scope and assumptions" section of the output.

## Evidence → candidate C4 element

Code and configuration evidence (examples lean Go, the mapping is general):

| Evidence | Candidate element |
|---|---|
| `cmd/*`, a built binary, an entry point, a long-running process | Container |
| A client-side web application (significant SPA) | Container (separate from its backend) |
| A database schema, migrations directory | Data container |
| A bucket or file store the system owns | Data container |
| A queue or topic the system owns | Container (or a "via" label on the relationship — see c4-model-rules.md) |
| An HTTP/gRPC client, an event producer/consumer | Relationship between containers (with its protocol) |
| A functional grouping behind a stable interface | Component |
| A package, file, or struct by itself | Evidence only — never an automatic component |

Kubernetes and delivery evidence:

| Evidence | Interpretation |
|---|---|
| Kubernetes cluster or node | Candidate deployment node |
| Pod or runtime environment | Candidate node running an instance |
| Deployment, StatefulSet, DaemonSet | Evidence of instances, replicas, and strategy |
| Namespace | Logical grouping — not automatically a node |
| OCI image | Deployed artifact — not automatically a C4 container |
| Service or Ingress | Network/infrastructure evidence |
| Helm charts, manifests | Topology and environment evidence (one Deployment view per environment) |
| GitLab CI | Build/deploy evidence — not a runtime element by itself |

The level of detail in a Deployment view follows the purpose of that view, not everything the manifests contain.

## Verification rules

1. Find real processes before declaring containers — something must *run* (or store data) to be a container.
2. Find real protocols before labeling relationships — read the client code or config, don't assume HTTP.
3. Find ownership before fixing system boundaries — who builds and operates it strongly informs system vs container, together with whether it is an internal detail of one product (see c4-model-rules.md, Microservices).
4. Use configuration and manifests as evidence for deployment and for relationships (connection strings, brokers, endpoints).
5. Mark unconfirmed data explicitly — in the model and in the output's assumptions section.

And one classic trap: a `go.mod` dependency (or any build-time import) is **not** a runtime call. Only runtime communication — HTTP, gRPC, SQL, messaging — becomes a relationship between containers.

## Tie into the output

Every diagram documenting an existing codebase carries an **Evidence** section listing the files that support its elements and relationships (`cmd/api/main.go`: the API process; `deploy/values-prod.yaml`: 3 replicas). This keeps reviews cheap and prevents silent invention.
