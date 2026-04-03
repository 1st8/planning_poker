---
name: daisy-ui
description: "DaisyUI 5 component library reference for this Phoenix/Elixir project. Use this skill whenever building or modifying UI — buttons, forms, cards, modals, navigation, layout, alerts, tables, or any visual component. Also consult this when working with themes, colors, styling, CSS classes, or anything in templates/HEEx files. If you are touching any .heex file or core_components.ex, check this skill first."
---

# DaisyUI 5 in This Project

DaisyUI 5 is a CSS component library built on Tailwind CSS 4. Instead of writing utility classes for every element, you apply semantic class names (`btn`, `card`, `input`, etc.) and layer on modifiers for color, size, and style.

## Project Setup

This project uses DaisyUI via **vendored JS plugins** (not npm). The relevant files:

| File | Purpose |
|------|---------|
| `assets/css/app.css` | Theme configuration, plugin imports, custom variants |
| `assets/vendor/daisyui.js` | Core DaisyUI plugin (update via `curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui.js`) |
| `assets/vendor/daisyui-theme.js` | Theme plugin (update via `curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui-theme.js`) |
| `lib/planning_poker_web/components/core_components.ex` | Phoenix components that wrap DaisyUI classes |

### Existing Core Components

`core_components.ex` already provides Phoenix function components that use DaisyUI internally. Before writing raw HTML with DaisyUI classes, check if one of these components already handles what you need:

- **`<.flash>`** -- Renders flash messages using `toast` + `alert` DaisyUI components
- **`<.button>`** -- Renders `btn` with `btn-primary` (default) or `btn-primary btn-soft` variant; supports navigation via `navigate`/`patch`/`href`
- **`<.input>`** -- Renders form inputs using DaisyUI `input`, `select`, `textarea`, `checkbox` classes inside `fieldset` wrappers
- **`<.header>`** -- Page header with title, subtitle, and actions
- **`<.table>`** -- Data table using `table table-zebra`
- **`<.list>`** -- Data list using `list` and `list-row`
- **`<.icon>`** -- Heroicons via `hero-*` class names

When adding new components, follow the same pattern: define `attr` and `slot` declarations, use DaisyUI classes, and put them in `core_components.ex`.

### Theme Configuration

This project ships two custom themes defined in `assets/css/app.css`:

- **`light`** (default) -- Phoenix-inspired warm palette with orange primary
- **`dark`** (prefers-dark) -- Elixir-inspired purple palette

Themes are toggled via a `data-theme` attribute on `<html>`. The `theme_toggle` component in `layouts.ex` handles system/light/dark switching using `JS.dispatch("phx:set-theme")`. A script in `root.html.heex` persists the choice in `localStorage`.

Dark mode variant in CSS uses: `@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));`

To build a custom theme, use the [theme generator](https://daisyui.com/theme-generator/) and add a new `@plugin "../vendor/daisyui-theme" { ... }` block in `app.css`. All color values use OKLCH format.

## Core Principles

1. **Use semantic color names** -- Write `bg-primary`, `text-error`, `border-secondary`, never Tailwind's raw color names like `bg-red-500` or `text-gray-800`. Semantic names automatically adapt across themes, so the UI looks correct in both light and dark mode. Raw color names break theming.

2. **Pair base + content colors** -- The `*-content` colors are designed to contrast against their base color. When you set a background, use the matching content color for text: `bg-primary text-primary-content`, `bg-error text-error-content`, etc.

3. **Compose classes in layers** -- Component class (`btn`) + optional style modifier (`btn-outline`) + optional color modifier (`btn-primary`) + optional size modifier (`btn-sm`) + Tailwind utilities for spacing/layout as needed.

4. **Prefer DaisyUI components over hand-rolled styles** -- If DaisyUI has a component for what you need, use it rather than building from scratch with Tailwind utilities. Check the [component reference](references/components.md) for the full catalog.

5. **Avoid `!important` and custom CSS** -- Stick to declarative class names. Use the `!` suffix in Tailwind only as a last resort for specificity issues.

## Color System

Semantic colors that adapt automatically across themes:

| Color | Content variant | Usage |
|-------|----------------|-------|
| `primary` | `primary-content` | Key interactive elements, CTAs |
| `secondary` | `secondary-content` | Supporting elements |
| `accent` | `accent-content` | Highlights, decorative |
| `neutral` | `neutral-content` | Subdued UI elements |
| `base-100/200/300` | `base-content` | Page backgrounds, surfaces (100=lightest) |
| `info` | `info-content` | Informational states |
| `success` | `success-content` | Success states |
| `warning` | `warning-content` | Warning states |
| `error` | `error-content` | Error states |

Use in Tailwind utilities: `bg-primary`, `text-primary-content`, `border-secondary`, `ring-error`, etc.

## Common Modifier Patterns

Most components share these modifier patterns (replace `{c}` with the component class name):

- **Colors:** `{c}-neutral`, `{c}-primary`, `{c}-secondary`, `{c}-accent`, `{c}-info`, `{c}-success`, `{c}-warning`, `{c}-error`
- **Sizes:** `{c}-xs`, `{c}-sm`, `{c}-md`, `{c}-lg`, `{c}-xl`
- **Styles:** `{c}-outline`, `{c}-dash`, `{c}-soft`, `{c}-ghost`

## Quick Reference: Most-Used Components

### Buttons
```html
<button class="btn btn-primary">Click</button>
<button class="btn btn-outline btn-error btn-sm">Delete</button>
<button class="btn btn-soft btn-secondary">Secondary</button>
```
Styles: `btn-outline`, `btn-dash`, `btn-soft`, `btn-ghost`, `btn-link`
Shape: `btn-wide`, `btn-block`, `btn-square`, `btn-circle`

### Cards
```html
<div class="card">
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Content</p>
    <div class="card-actions">Actions</div>
  </div>
</div>
```
Styles: `card-border`, `card-dash`. Modifiers: `card-side`, `image-full`.

### Forms
```html
<!-- Use the <.input> core component for form fields -->
<input type="text" class="input input-primary" placeholder="Type here" />
<select class="select select-primary"><option>Pick</option></select>
<textarea class="textarea textarea-primary" placeholder="Bio"></textarea>
<input type="checkbox" class="checkbox checkbox-primary" />
<input type="checkbox" class="toggle toggle-primary" />
```

Wrap fields in `fieldset` with `fieldset-legend` for grouping. Use `floating-label` for floating label pattern.

### Modals
```html
<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3>Title</h3>
    <p>Content</p>
    <div class="modal-action">
      <form method="dialog"><button class="btn">Close</button></form>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop"><button>close</button></form>
</dialog>
```
Open with JS: `my_modal.showModal()`

### Feedback
```html
<div role="alert" class="alert alert-info"><span>Message</span></div>
<span class="loading loading-spinner loading-lg"></span>
<span class="badge badge-primary">Label</span>
```

## Full Component Reference

For the complete catalog of all DaisyUI components with examples, see [references/components.md](references/components.md). Consult it when you need a component not covered above.

## Further Documentation

For detailed docs on specific components: https://daisyui.com/components/
