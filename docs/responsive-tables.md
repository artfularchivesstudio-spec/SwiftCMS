# Responsive Tables Implementation Guide

## Overview

SwiftCMS admin tables are now fully responsive with mobile-first design principles. All table views automatically switch between card view on mobile and table view on desktop.

## Features

### Breakpoint-Based View Switching

- **Mobile (< 768px)**: Card view with vertical layout
- **Desktop (>= 768px)**: Traditional table with horizontal layout

### Card View (Mobile)

Cards display information in a vertical, touch-friendly format:

```
┌─────────────────────────┐
│ Title/Name             │
│ ID: 1234...           │
│ Status: Published     │
├─────────────────────────┤
│ Created: Jan 1, 2024  │
│ Updated: Jan 2, 2024  │
├─────────────────────────┤
│ [Edit] [Share] [Delete]│
└─────────────────────────┘
```

### Table View (Desktop)

Traditional table with sortable columns:

```
┌──────┬─────────┬────────┬────────┐
│ ID   │ Title   │ Status │ Actions│
├──────┼─────────┼────────┼────────┤
│ 1234 │ Entry   │ Pub    │ Edit   │
└──────┴─────────┴────────┴────────┘
```

## Touch Interactions

### Swipe Actions

On mobile, swipe left or right on cards to highlight quick actions:

```javascript
// Implemented in Alpine.js components
handleCardTouchStart(e)
handleCardTouchMove(e)
handleCardTouchEnd(e, itemId)
```

### Touch Targets

All interactive elements meet iOS/Android guidelines:

- **Minimum tap target**: 44px × 44px (iOS HIG)
- **Recommended spacing**: 8px between targets
- **Visual feedback**: Scale transform on active state

## Responsive Features

### 1. Collapsible Columns

Columns can be hidden on smaller screens:

```leaf
<th class="hidden sm:table-cell">Created</th>
<th class="hidden md:table-cell">Updated</th>
<th class="hidden lg:table-cell">ID</th>
```

Breakpoints:
- `sm:`: 640px
- `md:`: 768px
- `lg:`: 1024px
- `xl:`: 1280px

### 2. Horizontal Scroll

Wide tables scroll horizontally on mobile:

```css
.table-wrapper {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
}
```

### 3. Sticky Headers

Table headers stay visible while scrolling:

```css
.table thead th {
    position: sticky;
    top: 0;
    backdrop-filter: blur(8px);
    z-index: 10;
}
```

### 4. Responsive Pagination

Mobile shows simplified pagination:

```html
<!-- Mobile -->
<span>Page 1 / 5</span>

<!-- Desktop -->
<a>1</a> <a>2</a> <a class="active">3</a> <a>4</a> <a>5</a>
```

### 5. Pull-to-Refresh (Optional)

Implement pull-to-refresh on mobile lists:

```javascript
handleTouchStart(e) {
    if (window.scrollY === 0) {
        this.touchStartY = e.touches[0].clientY;
        this.isPulling = true;
    }
}
```

## Performance Optimizations

### 1. Lazy Loading Images

Images load as they enter the viewport:

```html
<img src="..." loading="lazy">
```

With placeholder animation:

```css
img[loading="lazy"] {
    background: linear-gradient(...);
    animation: shimmer 1.5s infinite;
}
```

### 2. Reduced Page Size on Mobile

Load fewer items per page on mobile:

```swift
// Backend logic
let pageSize = request.isMobile ? 15 : 25
```

### 3. Optimized Data Loading

- Debounce search input (300ms)
- Delay HTMX requests
- Use IntersectionObserver for lazy loading

## Implementation Examples

### Content List View

**File**: `Resources/Views/admin/content/list.leaf`

```leaf
<div x-data="contentTable()">
    <!-- Mobile Cards -->
    <div class="mobile-cards md:hidden space-y-3">
        #for(entry in entries):
        <div class="card bg-base-100 mobile-card"
             @touchstart.passive="handleCardTouchStart($event)"
             @touchmove.passive="handleCardTouchMove($event)"
             @touchend="handleCardTouchEnd($event, '#(entry.id)')">
            <!-- Card content -->
        </div>
        #endfor
    </div>

    <!-- Desktop Table -->
    <div class="hidden md:block">
        <table class="table table-zebra">
            <!-- Table content -->
        </table>
    </div>
</div>
```

### Media Library Grid

**File**: `Resources/Views/admin/media/library.leaf`

Responsive grid that adjusts columns:

```leaf
<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4
                lg:grid-cols-5 xl:grid-cols-6 gap-3 sm:gap-4">
    <!-- Media items -->
</div>
```

### Roles List

**File**: `Resources/Views/admin/roles/list.leaf`

Card-based mobile view with permissions info:

```leaf
<div class="card mobile-card">
    <div class="card-body p-4">
        <h4>#(role.name)</h4>
        <div class="space-y-2">
            <div class="flex justify-between min-h-[44px]">
                <span>Permissions</span>
                <span>#(role.permissionsCount) granted</span>
            </div>
        </div>
        <div class="card-actions">
            <button>Permissions</button>
            <button>Edit</button>
            <button>Delete</button>
        </div>
    </div>
</div>
```

## Alpine.js Components

### contentTable()

Manages content entry list interactions:

```javascript
function contentTable() {
    return {
        swipeStartX: 0,
        currentCard: null,

        handleCardTouchStart(e) { /* ... */ },
        handleCardTouchMove(e) { /* ... */ },
        handleCardTouchEnd(e, itemId) { /* ... */ },
        showQuickActions(itemId) { /* ... */ }
    };
}
```

### mediaGridSelection()

Handles media file selection and touch:

```javascript
function mediaGridSelection() {
    return {
        selectedFiles: new Set(),
        isAllSelected: false,

        initSelection() { /* Restore from localStorage */ },
        toggleRow(id, checked) { /* Update selection */ },
        handleTouchStart(e) { /* Track swipe */ }
    };
}
```

### bulkSelection()

Manages bulk selection across pages:

```javascript
function bulkSelection() {
    const STORAGE_KEY = 'bulkSelection_{contentType}';

    return {
        selectedEntries: new Set(),

        saveSelection() {
            localStorage.setItem(STORAGE_KEY, JSON.stringify([...this.selectedEntries]));
        }
    };
}
```

## CSS Patterns

### Touch-Friendly Buttons

```css
@media (max-width: 768px) {
    .btn, input, select, button {
        min-height: 44px !important;
        min-width: 44px !important;
    }
}
```

### Touch Feedback

```css
@media (hover: none) {
    .btn:hover {
        transform: none;
    }

    .btn:active {
        transform: scale(0.95);
    }
}
```

### Mobile Card Styling

```css
.mobile-card {
    touch-action: pan-y;
    transition: transform 0.2s ease;
}

.mobile-card:active {
    transform: scale(0.99);
}
```

## Testing Checklist

### Mobile Devices

- [ ] Card view displays correctly
- [ ] Tap targets are 44px minimum
- [ ] Swipe actions work smoothly
- [ ] Horizontal scroll works for wide tables
- [ ] Pagination is accessible
- [ ] Modals are full-screen on mobile
- [ ] Form inputs are 16px font (prevents zoom)
- [ ] Images load lazily

### Desktop

- [ ] Table view displays correctly
- [ ] Sticky headers work
- [ ] Sortable columns function
- [ ] Bulk selection works
- [ ] Keyboard navigation works
- [ ] Hover states display

### Cross-Browser

- [ ] iOS Safari
- [ ] Android Chrome
- [ ] Desktop Chrome
- [ ] Desktop Firefox
- [ ] Desktop Safari

## Browser Support

- **iOS Safari**: 12+
- **Android Chrome**: 70+
- **Desktop Chrome**: 90+
- **Desktop Firefox**: 88+
- **Desktop Safari**: 14+

Features used:
- CSS Grid
- CSS Sticky positioning
- Intersection Observer
- Touch events
- Alpine.js 3.14+

## Accessibility

### Keyboard Navigation

All table rows/cards are keyboard accessible:

```html
<tr tabindex="0" @keydown.enter="navigateToDetail()">
```

### Screen Readers

Proper ARIA labels on interactive elements:

```html
<button aria-label="Edit entry">
    <svg><!-- icon --></svg>
</button>
```

### Focus Management

Visible focus indicators on all interactive elements:

```css
.btn:focus-visible {
    outline: 2px solid theme('primary');
    outline-offset: 2px;
}
```

## Performance Metrics

Target metrics for mobile:

- **First Contentful Paint**: < 1.5s
- **Time to Interactive**: < 3s
- **Cumulative Layout Shift**: < 0.1
- **Largest Contentful Paint**: < 2.5s

Optimizations:
- Lazy load images below fold
- Defer non-critical JS
- Minimize main thread work
- Use efficient CSS selectors

## Future Enhancements

1. **Virtual Scrolling**: For very large lists
2. **Infinite Scroll**: Alternative to pagination
3. **Offline Support**: Service worker caching
4. **Touch Gestures**: Pinch to zoom, long press
5. **Haptic Feedback**: Vibration on actions
6. **Progressive Enhancement**: Better experience on modern browsers

## Troubleshooting

### Cards Not Displaying on Mobile

Check Tailwind breakpoint classes:

```html
<!-- Wrong -->
<div class="hidden md:block">Only desktop</div>

<!-- Correct -->
<div class="mobile-cards md:hidden">Mobile only</div>
<div class="hidden md:block">Desktop only</div>
```

### Swipe Not Working

Ensure passive event listeners:

```javascript
@touchstart.passive="handleTouchStart($event)"
```

### Horizontal Scroll Not Smooth

Add momentum scrolling:

```css
.table-wrapper {
    -webkit-overflow-scrolling: touch;
}
```

### Images Loading Slowly

Implement lazy loading with blur-up:

```html
<img src="blur.jpg" data-src="full.jpg" loading="lazy"
     class="transition-opacity duration-300"
     onload="this.src = this.dataset.src">
```

## Resources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/components/menus-and-actions/buttons)
- [Material Design Buttons](https://m3.material.io/components/buttons/overview)
- [MDN Touch Events](https://developer.mozilla.org/en-US/docs/Web/API/Touch_events)
- [Web.dev Mobile](https://web.dev/mobile/)
- [Alpine.js Documentation](https://alpinejs.dev/)
