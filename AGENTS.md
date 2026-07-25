# CleanerXcode Engineering Rules

These instructions apply to the entire repository.

## Mandatory workflow

- Classify every Swift task before editing and state which relevant skill is being used.
- Use `swiftui-expert-skill` for SwiftUI implementation and review.
- For every SwiftUI interface implementation or refactor, use `build-ios-apps:swiftui-view-refactor`, `build-ios-apps:swiftui-liquid-glass`, and the capabilities provided by the `build-ios-apps` plugin. This project's MVVM rules override the view-refactor skill's default preference for MV.
- Use `build-ios-apps:swiftui-ui-patterns` for navigation and component composition.
- Build interfaces without `GeometryReader` whenever possible. Treat it as a last resort and use it only when no suitable SwiftUI layout or container API can satisfy a highly necessary requirement.
- Use native macOS 26 Liquid Glass APIs. Group related effects with `GlassEffectContainer`, apply glass after layout modifiers, and use interactive glass only for interactive controls.
- Start performance work with a code-first audit.
- Use App Intents guidance only for Shortcuts, Spotlight, widgets, controls, or other system surfaces.
- Use the GitHub plugin to open pull requests.

## Testing and macOS policy

- Never create or run UI tests. This includes XCUITest, `XCUIApplication`, element queries, snapshot tests, rendered-view assertions, automated screenshots, and tests that interact with SwiftUI or AppKit elements.
- Unit tests and non-UI debugging may run on the local macOS destination.
- Keep DerivedData and package caches in a writable temporary directory when required by the environment.
- Use TDD for behavior changes: add a failing unit test, implement the smallest production change, make the test pass, then refactor.
- Do not invent tests for documentation-only, organization-only, or purely visual changes. Validate those with static review and a non-launching build.
- Tests, previews, and fixtures must never execute real disk-cleaning scripts, terminate the app, open external URLs, or mutate a developer's Xcode data.

## Architecture

- MVVM is mandatory for screens and behavioral components.
- A View must not contain business logic or access services, managers, persistence, command executors, analytics, or disk-cleaning abstractions.
- A View must not create a ViewModel or any of its dependencies.
- A screen or component that owns state, performs an action, handles a gesture, starts asynchronous work, or makes a decision must have a dedicated ViewModel.
- A purely visual leaf View may receive ready-to-render values and callbacks without a ViewModel.
- ViewModels own presentation state, user actions, data transformation, and coordination with injected service abstractions.
- Cross-feature navigation and feature graph construction belong to `AppRouter`. Long-lived dependency creation belongs to `AppContainer`.
- Views and ViewModels navigate only through the `AppRouting` abstraction. They never instantiate destination Views or destination ViewModels.
- `AppRootView` is the only View allowed to observe `AppRouter` directly, and it may only render the route state supplied by the Router.
- Services, stores, managers, helpers, command executors, analytics, URL opening, application termination, and persistence implementations must be injected. Do not hide dependencies in convenience initializers or global singletons.
- Destructive disk operations must remain behind injected abstractions and must be replaced by stubs in tests and previews.

## View rules

- Organize `CleanerXcode/Views` by feature domain. Each screen folder keeps its main View file at the folder root and places supporting View files in a `Components/` subfolder. Do not mix unrelated domains in the same folder.
- `body` may directly read values that the ViewModel already prepared for display and may call ViewModel actions.
- Do not place ternaries, comparisons, optional fallbacks, formatting, filtering, `Binding(get:set:)`, or business decisions inline in a component declaration.
- Prefer a UI-ready ViewModel property. When adaptation is exclusively visual, use a descriptive private computed property on the View.
- All View stored and computed properties are `private` unless an explicit external API requires broader visibility.
- Keep `body` pure, small, stable, and free of side effects.
- Every View and component source file must include a functional `#Preview` without a surrounding `#if DEBUG`. Previews use deterministic, preview-safe dependencies and never access live analytics, networking, app termination, or disk-cleaning commands.

## Swift organization

- Use Swift 6 language mode, complete strict concurrency checking, and macOS 26 APIs.
- Use the following exact `// MARK: -` names and ordering.
- Views use, when applicable: `Environments`, `Bindables`, `Bindings`, `App Storage`, `Scene Storage`, `Focus State`, `Gesture State`, `Namespaces`, `States`, `Public Properties`, `Body`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Non-View types use, when applicable: `Public Properties`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Every stored property wrapper must be directly preceded by its matching View `// MARK: -` section.
- Omit empty sections, but never reorder or rename applicable sections.
- Every explicit initializer uses an unlabeled first parameter.
- Default callbacks and implementation details to `private`; expose only real API.
- Use exactly one blank line before and after every `// MARK: -` declaration.
- Keep exactly one blank line at the start and end of each nonempty type, initializer, and function declaration when that boundary is adjacent to another declaration or `// MARK: -` section.
- Prefer Swift's implicit return for a single-expression property, closure, subscript getter, or function.
- When an explicit `return` is required after preceding work or control flow in the same scope, place exactly one blank line immediately before it.
- Use exactly one blank line before and after every `guard`, `if`, `switch`, loop, `do`, `catch`, and `defer` declaration only when another nonblank code line exists before or after it in the same scope.
- Keep consecutive stored `let` and `var` properties in one contiguous group within the same visibility or property-wrapper section.
- Except for the required spacing around declarations, `// MARK: -`, control-flow statements, and explicit `return`s, do not add a blank line immediately after an opening brace or immediately before a closing brace.
- Write empty scopes as `{}`.
