# DaisyUI 5 Component Reference

Full catalog of DaisyUI components. This file is organized by category.

## Table of Contents

- [Layout](#layout): navbar, hero, footer, drawer
- [Data Display](#data-display): card, table, stat, badge, list, avatar
- [Navigation](#navigation): menu, tabs, breadcrumbs, steps, pagination, dock
- [Actions](#actions): button, dropdown, modal, swap
- [Forms](#forms): input, textarea, select, checkbox, toggle, radio, range, file-input, fieldset, label, floating-label, validator
- [Feedback](#feedback): alert, toast, loading, progress, radial-progress, skeleton
- [Other](#other): accordion/collapse, carousel, chat, countdown, diff, divider, indicator, join, kbd, link, mask, stack, status, timeline, filter, theme-controller

---

## Layout

### navbar
Top navigation bar.
```html
<div class="navbar">
  <div class="navbar-start">Logo</div>
  <div class="navbar-center">Links</div>
  <div class="navbar-end">Actions</div>
</div>
```

### hero
Full-width hero section.
```html
<div class="hero">
  <div class="hero-content">Content</div>
</div>
```
Parts: `hero-content`, `hero-overlay`

### footer
Page footer.
```html
<footer class="footer footer-horizontal">
  <nav><h6 class="footer-title">Section</h6></nav>
</footer>
```
Modifiers: `footer-center`, `footer-horizontal`, `footer-vertical`

### drawer
Sidebar drawer.
```html
<div class="drawer">
  <input id="drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">Main content</div>
  <div class="drawer-side">
    <label for="drawer" class="drawer-overlay"></label>
    <ul class="menu">Sidebar</ul>
  </div>
</div>
```
Modifiers: `drawer-end`, `drawer-open`

---

## Data Display

### card
Content card.
```html
<div class="card">
  <figure><img src="image.jpg" /></figure>
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Content</p>
    <div class="card-actions">Actions</div>
  </div>
</div>
```
Styles: `card-border`, `card-dash`. Modifiers: `card-side`, `image-full`. Sizes: `card-xs` to `card-xl`.

### table
Data table.
```html
<table class="table table-zebra">
  <thead><tr><th>Name</th></tr></thead>
  <tbody><tr><td>Value</td></tr></tbody>
</table>
```
Modifiers: `table-zebra`, `table-pin-rows`, `table-pin-cols`. Sizes: `table-xs` to `table-xl`.

### stat
Statistics display.
```html
<div class="stats stats-horizontal">
  <div class="stat">
    <div class="stat-title">Total Users</div>
    <div class="stat-value">31K</div>
    <div class="stat-desc">+21% from last month</div>
  </div>
</div>
```
Parts: `stat`, `stat-title`, `stat-value`, `stat-desc`, `stat-figure`, `stat-actions`

### badge
Small label/tag.
```html
<span class="badge badge-primary">Label</span>
```
Styles: `badge-outline`, `badge-dash`, `badge-soft`, `badge-ghost`

### list
Structured list.
```html
<ul class="list">
  <li class="list-row">Item</li>
</ul>
```

### avatar
User avatar.
```html
<div class="avatar avatar-online">
  <div><img src="photo.jpg" /></div>
</div>
```
Container: `avatar-group`. Modifiers: `avatar-online`, `avatar-offline`, `avatar-placeholder`

---

## Navigation

### menu
Navigation menu.
```html
<ul class="menu menu-vertical">
  <li><a>Item</a></li>
  <li><h2 class="menu-title">Section</h2></li>
</ul>
```
Modifiers: `menu-horizontal`, `menu-vertical`, `menu-active`, `menu-disabled`

### tabs
Tab navigation.
```html
<div role="tablist" class="tabs tabs-box">
  <button role="tab" class="tab tab-active">Tab 1</button>
  <button role="tab" class="tab">Tab 2</button>
</div>
```
Styles: `tabs-box`, `tabs-border`, `tabs-lift`. Modifiers: `tab-active`, `tab-disabled`

### breadcrumbs
Breadcrumb trail.
```html
<div class="breadcrumbs">
  <ul><li><a>Home</a></li><li><a>Page</a></li></ul>
</div>
```

### steps
Step indicator.
```html
<ul class="steps steps-horizontal">
  <li class="step step-primary">Register</li>
  <li class="step">Choose plan</li>
</ul>
```

### pagination
Use `join` with buttons.
```html
<div class="join">
  <button class="join-item btn">1</button>
  <button class="join-item btn btn-active">2</button>
  <button class="join-item btn">3</button>
</div>
```

### dock
Bottom navigation dock.
```html
<div class="dock">
  <button><svg>...</svg><span class="dock-label">Home</span></button>
</div>
```

---

## Actions

### button
```html
<button class="btn btn-primary">Click</button>
<button class="btn btn-outline btn-error btn-sm">Delete</button>
```
Styles: `btn-outline`, `btn-dash`, `btn-soft`, `btn-ghost`, `btn-link`
Shape: `btn-wide`, `btn-block`, `btn-square`, `btn-circle`
State: `btn-active`, `btn-disabled`

### dropdown
Dropdown menu.
```html
<details class="dropdown">
  <summary class="btn">Open</summary>
  <ul class="dropdown-content menu bg-base-200 rounded-box w-52 p-2 shadow-sm">
    <li><a>Item</a></li>
  </ul>
</details>
```
Positions: `dropdown-top`, `dropdown-bottom`, `dropdown-left`, `dropdown-right`, `dropdown-start`, `dropdown-center`, `dropdown-end`
Modifiers: `dropdown-hover`, `dropdown-open`

### modal
Dialog modal.
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
Open with JS: `my_modal.showModal()`. Positions: `modal-top`, `modal-middle`, `modal-bottom`

### swap
Toggle between two states.
```html
<label class="swap swap-rotate">
  <input type="checkbox" />
  <div class="swap-on">ON</div>
  <div class="swap-off">OFF</div>
</label>
```

---

## Forms

### input
```html
<input type="text" class="input input-primary" placeholder="Type here" />
```
Style: `input-ghost`

### textarea
```html
<textarea class="textarea textarea-primary" placeholder="Bio"></textarea>
```

### select
```html
<select class="select select-primary">
  <option disabled selected>Pick one</option>
  <option>Option</option>
</select>
```

### checkbox / toggle / radio / range / file-input
```html
<input type="checkbox" class="checkbox checkbox-primary" />
<input type="checkbox" class="toggle toggle-primary" />
<input type="radio" name="group" class="radio radio-primary" />
<input type="range" class="range range-primary" min="0" max="100" />
<input type="file" class="file-input file-input-primary" />
```

### fieldset
Group form fields.
```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Title</legend>
  <input type="text" class="input" />
</fieldset>
```

### label / floating-label
```html
<label class="input">
  <span class="label">Name</span>
  <input type="text" />
</label>

<label class="floating-label">
  <span>Email</span>
  <input type="email" class="input" placeholder="mail@site.com" />
</label>
```

### validator
Form validation hints.
```html
<input type="email" class="input validator" required />
<p class="validator-hint">Please enter a valid email</p>
```

---

## Feedback

### alert
```html
<div role="alert" class="alert alert-info">
  <span>Info message</span>
</div>
```
Styles: `alert-outline`, `alert-dash`, `alert-soft`

### toast
Positioned notification.
```html
<div class="toast toast-end toast-bottom">
  <div class="alert alert-success">Saved!</div>
</div>
```

### loading
Loading spinner.
```html
<span class="loading loading-spinner loading-lg"></span>
```
Styles: `loading-spinner`, `loading-dots`, `loading-ring`, `loading-ball`, `loading-bars`, `loading-infinity`

### progress
```html
<progress class="progress progress-primary" value="50" max="100"></progress>
```

### radial-progress
Circular progress.
```html
<div class="radial-progress" style="--value:70;" role="progressbar">70%</div>
```

### skeleton
Loading placeholder.
```html
<div class="skeleton h-32 w-full"></div>
```

---

## Other

### accordion / collapse
Expandable content.
```html
<div class="collapse collapse-arrow">
  <input type="radio" name="accordion" />
  <div class="collapse-title">Title</div>
  <div class="collapse-content">Content</div>
</div>
```

### carousel
Horizontal scroll.
```html
<div class="carousel">
  <div class="carousel-item"><img src="img.jpg" /></div>
</div>
```

### chat
Chat bubbles.
```html
<div class="chat chat-start">
  <div class="chat-bubble">Hello!</div>
</div>
<div class="chat chat-end">
  <div class="chat-bubble chat-bubble-primary">Hi!</div>
</div>
```

### countdown
```html
<span class="countdown"><span style="--value:42;"></span></span>
```

### diff
Before/after comparison.
```html
<figure class="diff">
  <div class="diff-item-1">Before</div>
  <div class="diff-item-2">After</div>
  <div class="diff-resizer"></div>
</figure>
```

### divider
```html
<div class="divider">OR</div>
<div class="divider divider-horizontal">OR</div>
```

### indicator
Corner badge/notification.
```html
<div class="indicator">
  <span class="indicator-item badge badge-secondary">99+</span>
  <div class="btn">Inbox</div>
</div>
```

### join
Group elements together.
```html
<div class="join">
  <input class="join-item input" placeholder="Search" />
  <button class="join-item btn">Go</button>
</div>
```

### kbd
Keyboard key.
```html
<kbd class="kbd">Ctrl</kbd> + <kbd class="kbd">C</kbd>
```

### link
Styled anchor.
```html
<a class="link link-primary link-hover">Click me</a>
```

### mask
Shape masking for images.
```html
<img class="mask mask-squircle" src="photo.jpg" />
```
Shapes: `mask-squircle`, `mask-heart`, `mask-hexagon`, `mask-circle`, `mask-star`, `mask-diamond`, `mask-triangle`, etc.

### stack
Stacked elements.
```html
<div class="stack">
  <div class="card">Card 1</div>
  <div class="card">Card 2</div>
</div>
```

### status
Status indicator dot.
```html
<span class="status status-success"></span>
```

### timeline
```html
<ul class="timeline timeline-vertical">
  <li>
    <div class="timeline-start">2024</div>
    <div class="timeline-middle"><svg>...</svg></div>
    <div class="timeline-end timeline-box">Event</div>
    <hr />
  </li>
</ul>
```

### filter
Filter toggle group.
```html
<form class="filter">
  <input class="btn btn-square" type="reset" value="x" />
  <input class="btn" type="radio" name="filter" aria-label="All" />
  <input class="btn" type="radio" name="filter" aria-label="Active" />
</form>
```

### theme-controller
Theme switcher.
```html
<input type="checkbox" value="dark" class="toggle theme-controller" />
```

---

## Custom Theme Variables

Required CSS variables for custom themes (all OKLCH format):

**Colors:** `--color-base-100/200/300`, `--color-base-content`, `--color-primary`, `--color-primary-content`, `--color-secondary`, `--color-secondary-content`, `--color-accent`, `--color-accent-content`, `--color-neutral`, `--color-neutral-content`, `--color-info/success/warning/error` + content variants

**Geometry:** `--radius-selector` (1rem), `--radius-field` (0.25rem), `--radius-box` (0.5rem), `--size-selector` (0.25rem), `--size-field` (0.25rem), `--border` (1px)

**Effects:** `--depth` (0 or 1), `--noise` (0 or 1)

Theme generator: https://daisyui.com/theme-generator/
