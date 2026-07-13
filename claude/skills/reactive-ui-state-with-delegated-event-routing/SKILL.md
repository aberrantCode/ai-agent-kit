---
name: reactive-ui-state-with-delegated-event-routing
category: Frontend & UI
description: Use when building or reviewing a single-page/component UI that re-renders on state change and needs a clean way to wire click/interaction handlers, or when a component must react to system preferences like prefers-color-scheme/prefers-reduced-motion in a testable way.
status: active
version: 2026-07-05
---

# Reactive UI State with Delegated Event Routing

## When to use

- A view is re-rendered on every state change (vanilla JS SPA, or a React tree with repeated child components) and you need one consistent place to interpret user interactions instead of re-attaching listeners per render.
- Multiple layouts (e.g. grid view + card view) need to invoke the exact same action, and you want to avoid duplicating event-wiring logic per layout.
- A component's behavior should depend on a system/media preference (`prefers-color-scheme`, `prefers-reduced-motion`) and that behavior needs to be unit-testable, not just visually verified.

## Method

**1. Delegate DOM events through data attributes (vanilla JS / re-rendered DOM).**
Attach a single click handler on a stable ancestor (e.g. `document` or the app root) rather than per-element listeners. Encode intent in `data-*` attributes on interactive elements: `data-action`, `data-task-id`, etc. The handler reads `event.target.closest('[data-action]')` and dispatches based on those attributes. Because listeners live on a node that survives re-renders, freshly rendered DOM automatically works with no re-binding step. Pair this with a strict one-way data flow: every mutation goes through `setState(newState) → render(newState)`, so the delegated handler is always interpreting the current DOM.

**2. Thread callbacks down instead of letting children own event emission (React / component trees).**
Keep a single callback (e.g. `onCardAction(id, action)`) defined at the state-owning level, and pass it down to every child component/layout that needs to trigger it — rather than each component independently emitting or managing its own events. This keeps all state mutation in one place, makes the data-flow direction obvious top-down, and means wiring a new layout (e.g. adding a list view alongside grid/card) only requires invoking the same callback, not re-deriving the action logic.

**3. Read system preferences in JS, not only via CSS, when behavior (not just style) depends on them.**
`@media (prefers-color-scheme)` / `(prefers-reduced-motion)` CSS queries are invisible to jsdom and to any test that asserts on component behavior rather than computed style. Instead:
- Build a custom hook using `useSyncExternalStore` subscribed to `window.matchMedia('(prefers-reduced-motion: reduce)')` (or the color-scheme equivalent).
- Have the component conditionally apply classes/props based on the hook's return value.
- In test setup, shim `window.matchMedia` (jsdom doesn't implement it) so tests can flip the preference and assert the resulting classes/behavior deterministically.

## Gotchas

- Delegated handlers must match on the closest ancestor carrying the `data-action`, not `event.target` directly — a click can land on a child SVG/span inside the button.
- If you skip the shared-callback pattern in React and let each layout own its own handler, you will end up wiring the same action twice and one copy will silently drift out of sync.
- Without a `matchMedia` shim, tests that assert on preference-driven classes will pass vacuously (the hook will throw or default, hiding real regressions) — always verify the test actually fails when the implementation is reverted.
- CSS-only media queries are fine for pure styling; only escalate to the JS hook when the preference gates component *behavior* (e.g. skipping an animation entirely) that needs to be asserted in tests.

## Diagram

[View diagram](diagram.html)
