## ADDED Requirements

### Requirement: RSS HTML article bodies render media without narrow inline layout failures
The RSS reader SHALL render media elements in RSS HTML article bodies with bounded block layout so they do not participate in narrow inline baseline measurement that can produce repeated Flutter layout exceptions.

#### Scenario: Linked RSS image appears in narrow selectable content
- **GIVEN** an RSS article body contains an image inside a link
- **AND** the reader content is selectable
- **AND** the available content width is narrow
- **WHEN** the article body is rendered
- **THEN** the image SHALL be laid out as bounded block content
- **AND** the system SHALL NOT emit Flutter layout exceptions from `RenderImage.computeDryBaseline`, `_RenderCssSizing.performLayout`, or gesture/semantics render objects exceeding narrow constraints

#### Scenario: RSS image or video appears in an article paragraph
- **GIVEN** an RSS article body contains `img` or `video` elements inside paragraph-like HTML
- **WHEN** the article body is rendered in continuous reader or article-flow detail
- **THEN** each media element SHALL be constrained to the reader content width
- **AND** media height SHALL remain automatic or aspect-preserving rather than forcing horizontal overflow

#### Scenario: RSS media rendering is reused across reader surfaces
- **GIVEN** RSS HTML content is rendered in collection continuous reader
- **OR** RSS HTML content is rendered in article-flow detail
- **WHEN** the renderer applies media layout rules
- **THEN** both surfaces SHALL use the same RSS HTML rendering seam
- **AND** direct package-specific `HtmlWidget` configuration SHALL NOT be duplicated across those reader surfaces for RSS body rendering
