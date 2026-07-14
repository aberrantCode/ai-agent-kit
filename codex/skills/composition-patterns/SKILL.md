---
name: composition-patterns
description:
  React composition patterns that scale. Use when refactoring components with
  boolean prop proliferation, building flexible component libraries, or
  designing reusable APIs. Triggers on tasks involving compound components,
  render props, context providers, or component architecture. Includes React 19
  API changes.
license: MIT
metadata:
  author: vercel
  version: '1.0.0'
---

# React Composition Patterns

Composition patterns for building flexible, maintainable React components. Avoid
boolean prop proliferation by using compound components, lifting state, and
composing internals. These patterns make codebases easier for both humans and AI
agents to work with as they scale.

## When to Apply

Reference these guidelines when:

- Refactoring components with many boolean props
- Building reusable component libraries
- Designing flexible component APIs
- Reviewing component architecture
- Working with compound components or context providers

## Rule Categories by Priority

| Priority | Category                | Impact | Prefix          |
| -------- | ----------------------- | ------ | --------------- |
| 1        | Component Architecture  | HIGH   | `architecture-` |
| 2        | State Management        | MEDIUM | `state-`        |
| 3        | Implementation Patterns | MEDIUM | `patterns-`     |
| 4        | React 19 APIs           | MEDIUM | `react19-`      |

## Quick Reference

### 1. Component Architecture (HIGH)

- `architecture-avoid-boolean-props` - Don't add boolean props to customize
  behavior; use composition
- `architecture-compound-components` - Structure complex components with shared
  context

### 2. State Management (MEDIUM)

- `state-decouple-implementation` - Provider is the only place that knows how
  state is managed
- `state-context-interface` - Define generic interface with state, actions, meta
  for dependency injection
- `state-lift-state` - Move state into provider components for sibling access

### 3. Implementation Patterns (MEDIUM)

- `patterns-explicit-variants` - Create explicit variant components instead of
  boolean modes
- `patterns-children-over-render-props` - Use children for composition instead
  of renderX props

### 4. React 19 APIs (MEDIUM)

> **React 19+ only.** Skip this section if using React 18 or earlier.

- `react19-no-forwardref` - Don't use `forwardRef`; use `use()` instead of `useContext()`

## Rule Details

### architecture-avoid-boolean-props

**Why it matters:** Boolean props like `isLoading`, `hasError`, `isDisabled` cause components to
accumulate conditional branches over time, making them hard to maintain and extend.

Instead of:
```tsx
// BAD: boolean prop proliferation
<Button isLoading={true} isDisabled={false} hasIcon={true} isOutlined={false} />
```

Use explicit variant components:
```tsx
// GOOD: composition
<Button.Loading />
<Button.Icon icon={<SaveIcon />}>Save</Button.Icon>
<Button.Outlined>Cancel</Button.Outlined>
```

### architecture-compound-components

Structure complex components so related parts share context via a Provider:

```tsx
// GOOD: compound component pattern
const Tabs = ({ children, defaultValue }) => {
  const [active, setActive] = useState(defaultValue)
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      {children}
    </TabsContext.Provider>
  )
}

Tabs.List = TabsList
Tabs.Tab = Tab
Tabs.Panel = TabsPanel

// Usage
<Tabs defaultValue="profile">
  <Tabs.List>
    <Tabs.Tab value="profile">Profile</Tabs.Tab>
    <Tabs.Tab value="settings">Settings</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel value="profile">...</Tabs.Panel>
</Tabs>
```

### state-decouple-implementation

The Provider is the only place that knows how state is managed. Consumers only see the interface:

```tsx
// GOOD: implementation hidden behind interface
interface TabsContextValue {
  state: { activeTab: string }
  actions: { setActiveTab: (tab: string) => void }
}

// The provider can swap useState for useReducer, Zustand, etc.
// without changing any consumer code
```

### state-context-interface

Define a generic interface with `state`, `actions`, and `meta` for dependency injection:

```tsx
interface ContextInterface<TState, TActions, TMeta = undefined> {
  state: TState
  actions: TActions
  meta?: TMeta
}
```

### state-lift-state

Move state into provider components so sibling components can access it:

```tsx
// BAD: state buried in leaf component
const TabPanel = () => {
  const [active, setActive] = useState('first') // siblings can't access this
}

// GOOD: state lifted to provider
const Tabs = ({ children }) => {
  const [active, setActive] = useState('first') // shared via context
  return <TabsContext.Provider value={{ active, setActive }}>{children}</TabsContext.Provider>
}
```

### patterns-explicit-variants

Create explicit named variant components rather than boolean mode switches:

```tsx
// BAD
<Alert type="success" />
<Alert type="error" />

// GOOD
<Alert.Success />
<Alert.Error />
```

### patterns-children-over-render-props

Use `children` for composition instead of `renderX` props:

```tsx
// BAD: render props
<Card renderHeader={() => <h2>Title</h2>} renderFooter={() => <button>OK</button>} />

// GOOD: children composition
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Footer><button>OK</button></Card.Footer>
</Card>
```

### react19-no-forwardref

In React 19+, `ref` is a regular prop — no need for `forwardRef`:

```tsx
// React 18 (old)
const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => (
  <input {...props} ref={ref} />
))

// React 19+ (new)
const Input = ({ ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) => (
  <input {...props} ref={ref} />
)
```

Use `use()` instead of `useContext()`:

```tsx
// React 18
const value = useContext(MyContext)

// React 19+
const value = use(MyContext)
```
