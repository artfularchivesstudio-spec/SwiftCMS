# Responsive Design Guide

SwiftCMS Admin Panel is fully responsive, providing an optimal experience across desktop, tablet, and mobile devices.

## Overview

The responsive design adapts to:

- **Desktop** (1024px+): Full sidebar, table views, maximum screen real estate
- **Tablet** (768px - 1023px): Collapsible sidebar, optimized layouts
- **Mobile** (< 768px): Off-canvas navigation, card views, touch-optimized

## Breakpoints

```css
/* Mobile First Approach */

/* Extra Small (mobile) */
@media (max-width: 639px) { /* xs */ }

/* Small (large mobile) */
@media (min-width: 640px) { /* sm */ }

/* Medium (tablet) */
@media (min-width: 768px) { /* md */ }

/* Large (desktop) */
@media (min-width: 1024px) { /* lg */ }

/* Extra Large (wide desktop) */
@media (min-width: 1280px) { /* xl */ }

/* 2X Large (ultra wide) */
@media (min-width: 1536px) { /* 2xl */ }
```

## Layout Adaptations

### Sidebar

#### Desktop (1024px+)

```
┌─────────┬─────────────────────────────────┐
│         │                                 │
│ Sidebar │ Main Content Area               │
│         │                                 │
│ (fixed) │                                 │
│         │                                 │
└─────────┴─────────────────────────────────┘
    256px            Flexible
```

The sidebar is always visible and fixed-position.

#### Tablet & Mobile

```
Mobile Menu Button
┌──┐
│☰│ ← Fixed top-left
└──┘

Sidebar (hidden by default)
┌─────────────────────────────────┐
│ Sidebar Content                 │
│ (slides in from left)           │
└─────────────────────────────────┘
```

- Hamburger menu button appears in top-left
- Sidebar slides in from left
- Overlay darkens the background
- Swipe to close (touch devices)

### Content Tables

#### Desktop View

```
┌────┬──────────┬────────┬────────────┬─────────┐
│ ☑  │ Title    │ Status │ Created    │ Actions │
├────┼──────────┼────────┼────────────┼─────────┤
│ ☑  │ Post 1   │ Draft  │ 2024-01-15 │ ...     │
│ □  │ Post 2   │ Pub    │ 2024-01-14 │ ...     │
└────┴──────────┴────────┴────────────┴─────────┘
```

- Full table with all columns
- Sortable headers
- Inline actions

#### Mobile Card View

```
┌─────────────────────────────────┐
│ ☑ Post 1              [Draft]   │
│ Created: Jan 15, 2024            │
│ Updated: Jan 16, 2024            │
│                                  │
│ [Edit] [Share] [Delete]          │
└─────────────────────────────────┘
┌─────────────────────────────────┐
│ □ Post 2              [Pub]     │
│ Created: Jan 14, 2024            │
│ Updated: Jan 14, 2024            │
│                                  │
│ [Edit] [Share] [Delete]          │
└─────────────────────────────────┘
```

- Cards replace table rows
- Vertical stacking
- Full-width actions
- Touch-friendly spacing

### Navigation

#### Desktop Breadcrumbs

```
Home > Content > Blog Posts > Edit Post
```

#### Mobile Navigation

```
← Back
Blog Posts
```

Simplified back-navigation on mobile.

## Touch Interactions

### Touch Targets

All interactive elements meet minimum touch target size:

```
Minimum: 44x44px (WCAG AAA)
Recommended: 48x48px
```

Examples:

```css
.btn {
    min-height: 44px;  /* Touch-friendly */
    min-width: 44px;
    padding: 12px 16px;
}

.checkbox {
    width: 44px;
    height: 44px;
}
```

### Swipe Gestures

#### Card Swipe (Mobile)

Swipe cards left to reveal quick actions:

```
┌─────────────────────────────────┐
│ Post 1              [Draft]     │ ← Swipe left
│ Created: Jan 15, 2024            │
└─────────────────────────────────┘
         ↓ (swipe)
┌─────────────────────────────────┐
│ [Edit] [Delete]   Post 1        │ ← Quick actions
│                     [Draft]      │
└─────────────────────────────────┘
```

#### Sidebar Swipe

- **Swipe right**: Open sidebar
- **Swipe left**: Close sidebar
- **Tap overlay**: Close sidebar

### Pull to Refresh

Content lists support pull-to-refresh on mobile:

```
┌─────────────────────────────────┐
│     ↓ Pull to refresh            │
├─────────────────────────────────┤
│ Content items...                 │
└─────────────────────────────────┘
```

### Touch Feedback

Visual feedback for touch interactions:

```css
@media (hover: none) {
    .btn:active {
        transform: scale(0.95);
        opacity: 0.8;
    }

    .btn:hover {
        transform: none;  /* Disable hover effect */
    }
}
```

## Responsive Tables

### Horizontal Scroll

Wide tables scroll horizontally on small screens:

```
┌───────────────────────────────────────┐
│ ┌─────────────────────────────────┐  │
│ │ Table content...     →           │  │ ← Scrollable
│ └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

```css
.table-container {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;  /* Smooth scroll on iOS */
}
```

### Sticky Headers

Table headers stick to top while scrolling:

```css
.table thead th {
    position: sticky;
    top: 0;
    z-index: 10;
    background-color: var(--base-100);
}
```

### Column Visibility

Less important columns hide on small screens:

```
Desktop: [ID] [Title] [Status] [Created] [Updated] [Actions]
Tablet:  [Title] [Status] [Created] [Actions]
Mobile:  [Card view with all data]
```

```css
/* Hide on mobile */
.hidden-mobile {
    display: none;
}

@media (min-width: 768px) {
    .hidden-mobile {
        display: table-cell;
    }
}
```

## Form Adaptations

### Input Fields

#### Desktop

```
┌─────────────────────────────────┐
│ Title                            │
│ ┌─────────────────────────────┐ │
│ │ Enter title...               │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### Mobile

```
Title
┌─────────────────────────────┐
│ Enter title...               │
└─────────────────────────────┘
```

- Full-width inputs on mobile
- Larger touch targets
- Auto-focus handling

### Date Pickers

#### Desktop

```
┌─────────────────┐
│ [📅] Select Date│  ← Inline calendar
└─────────────────┘
```

#### Mobile

```
┌─────────────────┐
│ [📅] Select Date│  ← Native picker
└─────────────────┘
```

Uses native date picker for better mobile experience.

### Multi-select

#### Desktop

```
┌─────────────────────────────┐
│ ┌─────┐ ┌─────┐ ┌─────┐     │
│ │Tag1 │ │Tag2 │ │Tag3 │ ...  │
│ └─────┘ └─────┘ └─────┘     │
└─────────────────────────────┘
```

#### Mobile

```
┌─────────────────────────────┐
│ Select Tags           [▼]   │ ← Native picker
├─────────────────────────────┤
│ ☑ Tag 1                     │
│ ☑ Tag 2                     │
│ ☐ Tag 3                     │
└─────────────────────────────┘
```

## Supported Devices

### Mobile Devices

| Device | Screen Width | Support Level |
|--------|--------------|---------------|
| iPhone SE | 375px | ✅ Full |
| iPhone 12/13/14 | 390px | ✅ Full |
| iPhone 14 Pro Max | 430px | ✅ Full |
| Android Small | 360px | ✅ Full |
| Android Large | 412px | ✅ Full |
| Android XL | 480px | ✅ Full |

### Tablet Devices

| Device | Screen Width | Support Level |
|--------|--------------|---------------|
| iPad Mini | 768px | ✅ Full |
| iPad | 810px | ✅ Full |
| iPad Pro 11" | 834px | ✅ Full |
| iPad Pro 12.9" | 1024px | ✅ Full |
| Surface Pro | 912px | ✅ Full |

### Desktop

| Resolution | Support Level |
|------------|---------------|
| 1366x768 | ✅ Full |
| 1920x1080 | ✅ Full |
| 2560x1440 | ✅ Full |
| 3840x2160 (4K) | ✅ Full |

## Browser Compatibility

### Mobile Browsers

| Browser | Version | Support |
|---------|---------|---------|
| Safari iOS | 13+ | ✅ Full |
| Chrome Android | 90+ | ✅ Full |
| Firefox Android | 90+ | ✅ Full |
| Samsung Internet | 14+ | ✅ Full |

### Desktop Browsers

| Browser | Version | Support |
|---------|---------|---------|
| Chrome | 90+ | ✅ Full |
| Firefox | 88+ | ✅ Full |
| Safari | 14+ | ✅ Full |
| Edge | 90+ | ✅ Full |

## Performance Optimization

### Image Loading

Responsive images with lazy loading:

```html
<img
    src="image-small.jpg"
    srcset="image-small.jpg 400w,
            image-medium.jpg 800w,
            image-large.jpg 1200w"
    sizes="(max-width: 640px) 400px,
           (max-width: 1024px) 800px,
           1200px"
    loading="lazy"
    alt="Description">
```

### Font Loading

Optimized font loading for mobile:

```css
/* Critical fonts inline */
@font-face {
    font-family: 'Inter';
    font-display: swap;  /* Show fallback immediately */
    src: url('/fonts/inter.woff2') format('woff2');
}
```

### Code Splitting

JavaScript is split by route:

```javascript
// Admin (desktop)
const TableComponent = lazy(() => import('./Table'))

// Mobile
const CardComponent = lazy(() => import('./Card'))
```

## Testing Responsive Design

### Browser DevTools

1. Open Chrome DevTools (F12)
2. Click device toolbar icon (Ctrl/Cmd + Shift + M)
3. Select device from dropdown
4. Test interactions

### Real Device Testing

Test on actual devices for:

- Touch interactions
- Performance
- Rendering accuracy
- Native picker behavior

### Common Issues

#### Text Too Small

```
Mobile: 14px minimum
Recommended: 16px base size
```

#### Touch Targets Too Small

```
Minimum: 44x44px
Use padding to increase size
```

#### Horizontal Scroll

Avoid unintended horizontal scroll:

```css
body {
    overflow-x: hidden;
}

.container {
    max-width: 100%;
    overflow-x: auto;
}
```

## Accessibility

### Screen Readers

Responsive design maintains accessibility:

- Semantic HTML structure
- ARIA labels for mobile elements
- Logical tab order
- Keyboard navigation support

### Zoom Support

Support up to 200% zoom:

- Text reflows appropriately
- No horizontal scroll at 200%
- Touch targets remain usable
- Content remains accessible

## Best Practices

### 1. Mobile First

Design for mobile first, then enhance:

```css
/* Base styles (mobile) */
.container {
    padding: 1rem;
}

/* Desktop enhancement */
@media (min-width: 1024px) {
    .container {
        padding: 2rem;
        max-width: 1200px;
    }
}
```

### 2. Touch-Friendly Spacing

Provide adequate spacing:

```css
.button-group {
    gap: 1rem;  /* Space between buttons */
}

.form-field {
    margin-bottom: 1.5rem;  /* Space between fields */
}
```

### 3. Test Real Interactions

Test on real devices, not just emulators:

- Touch gestures
- Performance
- Battery usage
- Network conditions

### 4. Optimize Images

Use responsive images:

```html
<picture>
    <source srcset="image.webp" type="image/webp">
    <source srcset="image.jpg" type="image/jpeg">
    <img src="image.jpg" alt="Description">
</picture>
```

## Additional Resources

- [Tailwind Responsive Design](https://tailwindcss.com/docs/responsive-design)
- [MDN Responsive Design](https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design)
- [Web.dev Mobile](https://web.dev/mobile/)
- [Touch Targets (WCAG)](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html)
