# Dark Mode Guide

SwiftCMS Admin Panel includes a fully-featured dark mode that adapts to your preferences and system settings.

## Overview

The dark mode implementation provides:

- **System preference detection** - Automatically detects your OS dark mode setting
- **Manual toggle** - Switch between light and dark modes manually
- **Persistent preference** - Your choice is saved across sessions
- **Smooth transitions** - Animated theme switching
- **Cross-tab sync** - Theme changes sync across open tabs
- **Accessibility compliant** - Maintains WCAG contrast ratios in both modes

## Using Dark Mode

### Toggle Dark Mode

Click the theme toggle button in the sidebar header:

```
[Sidebar Header]
┌─────────────────────────────┐
│ SwiftCMS        [🌙/☀️]     │ <- Theme toggle
│ Headless CMS                 │
└─────────────────────────────┘
```

### Automatic Detection

When you first visit the admin panel, it checks:

1. **Saved preference** - Your last choice from localStorage
2. **System preference** - Your OS dark mode setting

The panel uses the first available preference:

```javascript
if (savedTheme) {
    use savedTheme
} else if (systemPrefersDark) {
    use dark mode
} else {
    use light mode
}
```

### System Preference Sync

If you haven't manually set a preference, the admin panel automatically adapts when your system theme changes:

```javascript
window.matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', (e) => {
        // Update theme when system preference changes
    })
```

## Theme Customization

### CSS Custom Properties

The theme uses CSS custom properties for easy customization:

```css
:root {
    /* Light mode colors */
    --base-100: #ffffff;
    --base-200: #f5f5f5;
    --base-300: #e5e5e5;
    --base-content: #1f2937;
}

[data-theme="dark"] {
    /* Dark mode colors */
    --base-100: #1f2937;
    --base-200: #111827;
    --base-300: #374151;
    --base-content: #f3f4f6;
}
```

### Custom Theme Colors

Override theme colors in your custom CSS:

```css
[data-theme="dark"] {
    --primary: #667eea;
    --secondary: #764ba2;
    --accent: #f59e0b;
    --neutral: #6b7280;
    --info: #3b82f6;
    --success: #10b981;
    --warning: #f59e0b;
    --error: #ef4444;
}
```

### Component-Specific Overrides

Override specific components in dark mode:

```css
[data-theme="dark"] .table th {
    background-color: #1f2937;
}

[data-theme="dark"] input,
[data-theme="dark"] select,
[data-theme="dark"] textarea {
    background-color: #1f2937;
    border-color: #374151;
    color: #f3f4f6;
}
```

## Accessibility

### Contrast Ratios

All text elements meet WCAG AA standards:

- **Normal text**: 4.5:1 contrast ratio minimum
- **Large text**: 3:1 contrast ratio minimum
- **UI components**: 3:1 contrast ratio minimum

### Focus Indicators

Focus indicators are visible in both themes:

```css
[data-theme="dark"] input:focus,
[data-theme="dark"] select:focus,
[data-theme="dark"] textarea:focus {
    border-color: #667eea;
    outline: 2px solid #667eea;
    outline-offset: 2px;
}
```

### Reduced Motion

Respects prefers-reduced-motion setting:

```css
@media (prefers-reduced-motion: reduce) {
    html {
        transition: none !important;
    }
}
```

## Theme Storage

### localStorage Format

Theme preference is stored in localStorage:

```javascript
localStorage.setItem('theme', 'dark')
// or
localStorage.setItem('theme', 'light')
```

### Cross-Tab Synchronization

Theme changes sync across tabs using storage events:

```javascript
window.addEventListener('storage', (e) => {
    if (e.key === 'theme') {
        applyTheme(e.newValue)
    }
})
```

## Implementation Details

### Theme Application

The theme is applied via `data-theme` attribute:

```html
<html data-theme="dark">
    <!-- Dark mode active -->
</html>
```

```html
<html data-theme="light">
    <!-- Light mode active -->
</html>
```

### Tailwind Dark Mode

Tailwind dark mode uses the class strategy:

```javascript
tailwind.config = {
    darkMode: 'class',
    theme: {
        extend: {
            // ...
        }
    }
}
```

Use dark mode classes:

```html
<div class="bg-white dark:bg-gray-800">
    <p class="text-gray-900 dark:text-gray-100">
        Content
    </p>
</div>
```

### Meta Theme Color

The mobile browser theme color updates with the theme:

```javascript
const metaThemeColor = document.querySelector('meta[name="theme-color"]');
metaThemeColor.setAttribute('content', isDarkMode ? '#111827' : '#ffffff');
```

## Browser Compatibility

| Browser | Dark Mode Support | Notes |
|---------|-------------------|-------|
| Chrome 76+ | ✅ Full | Including system preference detection |
| Firefox 67+ | ✅ Full | Including system preference detection |
| Safari 12.1+ | ✅ Full | Including system preference detection |
| Edge 79+ | ✅ Full | Chromium-based |
| Safari iOS 13+ | ✅ Full | Including system preference detection |
| Chrome Android | ✅ Full | Including system preference detection |

## Best Practices

### 1. Test Both Themes

Always test your custom styles in both themes:

```css
/* Good - works in both themes */
.custom-element {
    background-color: var(--base-100);
    color: var(--base-content);
}

/* Avoid - hardcoded colors */
.custom-element {
    background-color: #ffffff;
    color: #000000;
}
```

### 2. Use Semantic Colors

Use semantic color names from DaisyUI:

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-accent">Accent</button>
```

### 3. Provide High Contrast

Ensure sufficient contrast in both themes:

```css
/* Good - high contrast */
.text {
    color: var(--base-content);
}

/* Avoid - low contrast in dark mode */
.text {
    color: #666;  /* Too dark for dark mode backgrounds */
}
```

### 4. Test Images and Icons

Ensure images and icons work in both themes:

```css
[data-theme="dark"] img {
    opacity: 0.9;
}

[data-theme="dark"] svg {
    color: inherit;
}
```

## Troubleshooting

### Flash of Wrong Theme

Prevent flash of incorrect theme on page load:

```javascript
(function() {
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const isDark = savedTheme ? savedTheme === 'dark' : prefersDark;

    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
})();
```

Run this script immediately in the `<head>` before any content loads.

### Theme Not Applying

1. Check browser console for JavaScript errors
2. Verify localStorage is enabled
3. Check for CSS conflicts with custom styles
4. Ensure `data-theme` attribute is set correctly

### Poor Contrast

If you experience contrast issues:

1. Clear browser cache
2. Check for custom CSS overrides
3. Verify you're using the latest version
4. Report accessibility issues

## Plugin Development

### Dark Mode Support in Plugins

Support dark mode in your custom plugins:

```css
/* In your plugin CSS */
.my-plugin-component {
    background-color: var(--base-100);
    color: var(--base-content);
    border-color: var(--base-300);
}

[data-theme="dark"] .my-plugin-component {
    /* Additional dark mode specific styles */
}
```

### Theme Awareness

Detect theme changes in your JavaScript:

```javascript
// Listen for theme changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (e.matches) {
        // Dark mode activated
        onThemeChange('dark')
    } else {
        // Light mode activated
        onThemeChange('light')
    }
})
```

## Additional Resources

- [DaisyUI Themes Documentation](https://daisyui.com/docs/themes/)
- [Tailwind CSS Dark Mode](https://tailwindcss.com/docs/dark-mode)
- [MDN: prefers-color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme)
- [WCAG Contrast Guidelines](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
