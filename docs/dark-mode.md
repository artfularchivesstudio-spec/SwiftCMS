# Dark Mode Implementation Guide

## Overview

SwiftCMS admin panel now includes comprehensive dark mode support with automatic system preference detection, manual toggle controls, and smooth transitions between themes.

## Features

### 1. Theme Toggle Controls

- **Sidebar Toggle**: Located in the sidebar header with sun/moon icons
- **Header Toggle**: Available in the main header (desktop only)
- **Smooth Animations**: Icons rotate and scale on hover for better feedback
- **Keyboard Accessible**: All toggle buttons include proper ARIA labels

### 2. Theme Persistence

- **localStorage**: Theme preference is saved to `localStorage` with key `'theme'`
- **Cross-Tab Sync**: Theme changes sync across all open tabs
- **System Preference**: Automatically detects OS-level dark mode setting

### 3. Smooth Transitions

- **Background Colors**: 0.3s ease transition for backgrounds
- **Text Colors**: 0.3s ease transition for text
- **Component Borders**: Smooth border color transitions
- **Prevent Flash**: Theme initializes immediately to prevent white flash

## Technical Implementation

### Theme Detection

```javascript
// System preference detection
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

// Listen for system theme changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    // Update theme if user hasn't set preference
    if (!localStorage.getItem('theme')) {
        this.isDarkMode = e.matches;
        this.applyTheme();
    }
});
```

### Theme Application

```javascript
applyTheme() {
    const theme = this.isDarkMode ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', theme);

    // Add/remove dark class for Tailwind
    if (this.isDarkMode) {
        document.documentElement.classList.add('dark');
    } else {
        document.documentElement.classList.remove('dark');
    }

    // Update mobile browser theme-color
    const metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (metaThemeColor) {
        metaThemeColor.setAttribute('content', this.isDarkMode ? '#111827' : '#ffffff');
    }
}
```

### Tailwind Configuration

```javascript
tailwind.config = {
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                dark: {
                    900: '#111827',
                    800: '#1f2937',
                    700: '#374151',
                    600: '#4b5563',
                }
            }
        }
    }
}
```

## Component Dark Mode Support

### Navigation

- Sidebar backgrounds adapt to theme
- Navigation items have proper hover states
- Active states work in both themes

### Tables

- Table headers have dark backgrounds
- Zebra striping works in both themes
- Hover states are theme-aware

### Forms and Inputs

```css
[data-theme="dark"] input,
[data-theme="dark"] select,
[data-theme="dark"] textarea {
    background-color: #1f2937;
    border-color: #374151;
    color: #f3f4f6;
}
```

### Modals and Dialogs

```css
[data-theme="dark"] .modal-box {
    background-color: #1f2937;
}
```

### Dropdowns

```css
[data-theme="dark"] .dropdown-content {
    background-color: #1f2937;
    border-color: #374151;
}
```

### Code Blocks

```css
[data-theme="dark"] pre,
[data-theme="dark"] code {
    background-color: #1f2937;
    color: #e5e7eb;
}
```

## Customization

### Adding Custom Dark Mode Styles

1. Add styles to the custom `<style>` block in `base.leaf`:

```css
[data-theme="dark"] .your-component {
    background-color: #1f2937;
    color: #f3f4f6;
}
```

### Using Tailwind Dark Mode

```html
<!-- Apply different styles in dark mode -->
<div class="bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100">
    Theme-aware content
</div>
```

### Creating Theme-Aware Utilities

Use the utility classes from `theme-toggle.leaf`:

```html
<div class="theme-bg-primary theme-text-primary theme-border">
    Content that adapts to theme
</div>
```

## Best Practices

1. **Test Both Themes**: Always test UI changes in both light and dark modes
2. **Contrast Ratios**: Ensure text has sufficient contrast in both themes (WCAG AA: 4.5:1)
3. **Images**: Use slightly reduced opacity in dark mode for better integration
4. **Transitions**: Keep transitions short (200-300ms) to avoid feeling sluggish
5. **System Preference**: Respect user's OS preference unless they've manually set a theme

## Browser Support

- Chrome/Edge 76+
- Firefox 67+
- Safari 12.1+
- iOS Safari 13+
- Android Chrome 76+

## Accessibility

- **ARIA Labels**: All toggle buttons have descriptive labels
- **Keyboard Navigation**: Theme toggle is accessible via keyboard
- **Focus States**: Visible focus indicators in both themes
- **Reduced Motion**: Respects `prefers-reduced-motion` setting

## Troubleshooting

### Flash of Wrong Theme

If you see a flash of light theme when dark is selected:

1. Check that theme initialization happens in `<head>`
2. Verify inline script runs before Alpine.js loads
3. Ensure no CSS blocking resources delay theme application

### Component Not Adapting

If a component doesn't adapt to theme:

1. Check if it uses DaisyUI classes (should auto-adapt)
2. Add custom dark mode styles in the style block
3. Use Tailwind `dark:` prefix for utility classes

### Scrollbar Not Styled

Dark mode scrollbars are supported but browser-dependent:

- Chrome/Edge: Styled via CSS
- Firefox: Uses system scrollbars
- Safari: Uses system scrollbars

## Future Enhancements

- [ ] Per-user theme preferences stored in database
- [ ] Theme transition animation preferences
- [ ] Custom theme colors (beyond light/dark)
- [ ] High contrast mode support
- [ ] Automatic theme based on time of day
