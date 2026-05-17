## ADDED Requirements

### Requirement: Navigation host fixes preserve feature boundaries
While the active architecture phase is `evolve_modularity`, changes that modify the home navigation host or feature screens participating in `HomeEmbeddedNavigationHost` back handling MUST preserve the host seam as the collaboration boundary. Such changes MUST NOT introduce new `state -> features`, `application -> features`, or `core -> features` dependencies, and MUST include a focused guardrail when the touched behavior has caused or could cause route recursion.

#### Scenario: Overlay back fix touches feature and home code
- **WHEN** a change fixes back behavior involving `HomeEmbeddedNavigationHost` and feature screens during `evolve_modularity`
- **THEN** the implementation MUST keep navigation coordination owned by the home host seam rather than adding direct feature-to-feature or lower-layer shortcuts

#### Scenario: Back recursion risk is identified
- **WHEN** an OpenSpec change identifies a route recursion or ANR risk in home navigation behavior
- **THEN** the implementation MUST add or tighten a test guardrail that fails if the same back action repeatedly re-enters the same route pop callback
