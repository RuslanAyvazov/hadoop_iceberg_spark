---
name: Ozone Explorer
description: A compact operations board that connects the Ozone namespace to Spark DataFrame results.
colors:
  operations-cobalt: "#124ec2"
  cobalt-depth: "#0a347f"
  cool-paper: "#f3f5f6"
  raised-paper: "#ffffff"
  graphite: "#17202a"
  muted-slate: "#65717c"
  rule-gray: "#c5cdd3"
  working-amber: "#d88d00"
  ready-green: "#16734b"
  error-red: "#b3261e"
typography:
  display:
    fontFamily: "Segoe UI Variable, Segoe UI, Arial, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Segoe UI Variable, Segoe UI, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: "Segoe UI Variable, Segoe UI, Arial, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "Cascadia Mono, SFMono-Regular, Consolas, monospace"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.1em"
rounded:
  square: "0"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "22px"
components:
  button-primary:
    backgroundColor: "{colors.operations-cobalt}"
    textColor: "{colors.raised-paper}"
    rounded: "{rounded.square}"
    padding: "0 16px"
    height: "40px"
  button-primary-hover:
    backgroundColor: "{colors.cobalt-depth}"
    textColor: "{colors.raised-paper}"
  input:
    backgroundColor: "{colors.raised-paper}"
    textColor: "{colors.graphite}"
    rounded: "{rounded.square}"
    padding: "0 10px"
    height: "36px"
  panel:
    backgroundColor: "{colors.raised-paper}"
    textColor: "{colors.graphite}"
    rounded: "{rounded.square}"
    padding: "16px"
---

# Design System: Ozone Explorer

## Overview

**Creative North Star: "The Operations Flight Strip"**

Ozone Explorer looks like an instrument used to follow data through a system. Cool paper, precise graphite rules, compact labels, and tabular values make hierarchy and state visible without turning the product into a generic dashboard. Cobalt is reserved for the active path and actions; amber appears only while work is running.

The interface stays dense enough for file and schema inspection but keeps a clear left-to-right reading order. Namespace, stored path, and DataFrame are parts of one journey, not detached cards.

**Key Characteristics:**

- Squared, ruled work surfaces with no decorative container rounding.
- Cobalt selections and action controls against cool neutral paper.
- Monospaced operational metadata paired with a compact humanist interface face.
- Literal loading, ready, error, and selection states.

## Colors

The palette is cool and utilitarian: near-white paper and dark graphite carry most of the screen, with a single saturated operational accent.

### Primary

- **Operations Cobalt**: Primary actions, active paths, focus relationships, and the completed path-to-schema trace.
- **Cobalt Depth**: Hover state and readable blue text on light surfaces.

### Secondary

- **Working Amber**: Spark work in progress; it must not look like success or ordinary emphasis.
- **Ready Green**: Live cluster confirmation and successful transient messages.
- **Error Red**: Failure messages only.

### Neutral

- **Cool Paper**: Application field and low-contrast structural zones.
- **Raised Paper**: Data surfaces, controls, and tables.
- **Graphite**: Primary text and the strongest structural rules.
- **Muted Slate**: Secondary descriptions and metadata.
- **Rule Gray**: Dividers and quiet borders.

### Named Rules

**The One Operational Accent Rule.** Cobalt marks selection or action; it is never added merely to make a region more colorful.

**The State Is Literal Rule.** Amber means running, green means ready, and red means failure. These colors do not decorate neutral content.

## Typography

**Display Font:** Segoe UI Variable (with Segoe UI and Arial fallback)

**Body Font:** Segoe UI Variable (with Segoe UI and Arial fallback)

**Label/Mono Font:** Cascadia Mono (with SFMono-Regular and Consolas fallback)

**Character:** The sans-serif layer stays familiar and highly legible. The monospaced layer identifies paths, types, metrics, commands, and short operational labels rather than acting as decorative code styling.

### Hierarchy

- **Display** (700, 24px, 1): Product identity only.
- **Headline** (700, 18px): Empty-state and result messages.
- **Title** (700, 15px, 1.2): Workspace zones.
- **Body** (400, 14px, 1.55): Instructions and explanations.
- **Label** (700, 11px, 0.1em, uppercase where appropriate): State, schema, settings, and metrics.

### Named Rules

**The Metadata Has a Voice Rule.** Paths, types, sizes, counts, timestamps, and commands use the monospaced layer; explanatory prose does not.

## Layout

The desktop workspace is a three-zone grid: a narrow namespace rail, a wider file manifest, and a dominant DataFrame surface. A full-width command strip keeps the selected `ofs://` path next to the preview action. At widths below 1180px, the DataFrame moves below the two navigation zones. Below 720px, all zones stack and retain their natural reading order.

The spacing rhythm is compact: 8px for close control relationships, 12–16px inside work surfaces, and 22px at the outer command and masthead edges. Tables and trees may scroll within their own zones; the application itself must not force horizontal page scrolling.

## Elevation & Depth

The system is flat by default. Depth comes from tonal layers and one-pixel rules, not floating cards. Only transient toasts receive a soft ambient shadow so they can sit above the working surface.

### Shadow Vocabulary

- **Transient Message** (`0 10px 30px rgba(23,32,42,.14)`): Toasts only.

### Named Rules

**The Ruled Surface Rule.** Permanent hierarchy is expressed with background tone and borders; shadows do not separate ordinary panels.

## Shapes

Controls, panels, status markers, and tables use square corners. Repeated one-pixel rules form the main geometry. Circular pills and rounded dashboard cards do not belong to this system.

## Components

### Buttons

- **Shape:** Square corners with a minimum 40px action height.
- **Primary:** Operations Cobalt with white text; Cobalt Depth on hover.
- **Hover / Focus:** Color darkens on hover; keyboard focus uses a three-pixel translucent cobalt outline.
- **Quiet:** Transparent at rest and Cool Paper on hover.

### Cards / Containers

- **Corner Style:** Square.
- **Background:** Raised Paper or a slightly translucent equivalent over Cool Paper.
- **Shadow Strategy:** None for persistent surfaces.
- **Border:** One-pixel Graphite for zone boundaries; Rule Gray for internal separation.
- **Internal Padding:** 12–16px, except dense row lists.

### Inputs / Fields

- **Style:** White field, one-pixel slate border, square corners, and 36px height.
- **Focus:** Visible cobalt outline outside the field.
- **Disabled:** Reduced opacity while retaining legible text and shape.

### Navigation

Volumes are stable group labels; buckets and files are direct row actions. The active row uses a pale cobalt field and cobalt text. Mobile preserves the same hierarchy by stacking zones rather than replacing it with a hidden drawer.

### DataFrame Result

Schema fields form a ruled strip immediately above the rows. Column names, Spark types, nullable state, the PySpark command, and execution metrics remain visible as distinct layers of the same result.

## Do's and Don'ts

### Do:

- **Do** keep storage path, schema, and rows visibly connected.
- **Do** use cobalt only for an action or selected state.
- **Do** preserve keyboard focus and reduced-motion behavior.
- **Do** keep operational text at 11px or larger.

### Don't:

- **Don't** turn zones into rounded, floating dashboard cards.
- **Don't** use state colors as generic decoration.
- **Don't** hide the equivalent Spark command after a successful preview.
- **Don't** add decorative grids, chapter numbers, or continuously moving marquees.
