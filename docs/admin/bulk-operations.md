# Bulk Operations Guide

SwiftCMS provides powerful bulk operations for managing multiple content entries at once, with selection persistence, progress tracking, and undo functionality.

## Overview

Bulk operations allow you to:

- Select multiple entries across pages
- Perform actions on all selected items
- Track operation progress in real-time
- Undo operations within 30 minutes
- Persist selection across browser sessions

## Selection

### Desktop Selection

Use checkboxes to select entries:

```
┌───┬────────────┬────────┬──────────┐
│ ☑ │ Title      │ Status │ Actions  │  <- Checkbox for row selection
├───┼────────────┼────────┼──────────┤
│ ☑ │ Post 1     │ Draft  │ ...      │
│ ☑ │ Post 2     │ Pub    │ ...      │
│ □ │ Post 3     │ Draft  │ ...      │
└───┴────────────┴────────┴──────────┘
```

**Select All**: Use the header checkbox to select all visible entries

**Individual Selection**: Click individual row checkboxes

### Mobile Selection

On mobile devices, entries are displayed as cards:

```
┌─────────────────────────┐
│ ☑ Post 1        [Draft] │  <- Checkbox in card header
│ Created: Jan 15          │
│ Updated: Jan 16          │
│ [Edit] [Share] [Delete]  │
└─────────────────────────┘
```

**Touch Actions**: Tap the checkbox to select/deselect entries

### Selection Persistence

Your selection is automatically saved to localStorage:

```javascript
// Selection persists across:
- Page refreshes
- Browser sessions
- Navigation
- Filter changes
```

The selection is keyed by content type:

```javascript
localStorage.setItem('bulkSelection_blog-posts', JSON.stringify([
    'entry-id-1',
    'entry-id-2',
    'entry-id-3'
]))
```

### Clearing Selection

- **Desktop**: Click "Clear" button in bulk operations bar
- **Mobile**: Click "Clear" in mobile selection bar
- **Manual**: Deselect all checkboxes individually

## Bulk Actions

### Available Actions

| Action | Description | Requires Confirmation | Undoable |
|--------|-------------|----------------------|----------|
| **Publish** | Publish draft entries | No | ✅ Yes (30 min) |
| **Unpublish** | Revert to draft | No | ✅ Yes (30 min) |
| **Archive** | Archive entries | No | ✅ Yes (30 min) |
| **Change Locale** | Change entry locale | No | ✅ Yes (30 min) |
| **Delete** | Delete entries | Yes | ✅ Yes (30 min) |

### Publishing

Select entries and click "Publish":

```
┌──────────────────────────────────────────┐
│ 3 selected        [Clear]                │
├──────────────────────────────────────────┤
│ [Publish] [Unpublish] [More ▼]           │
└──────────────────────────────────────────┘
```

**Effect**: Changes status from `draft` to `published`

**Validation**: Entries must be in `draft` status

### Unpublishing

Click "Unpublish" in the bulk actions bar:

**Effect**: Changes status from `published` to `draft`

**Validation**: Entries must be in `published` status

### Archiving

Select "More" → "Archive":

**Effect**: Changes status to `archived`

**Validation**: Works from any status

### Deleting

⚠️ **Warning**: This is a destructive action

1. Select entries
2. Click "More" → "Delete"
3. Confirm in modal dialog
4. Entries are soft-deleted

**Undo**: Available for 30 minutes after deletion

## Advanced Actions

### Change Locale

Change the locale of multiple entries at once:

1. Select entries
2. Click "More" → "Change Locale"
3. Select target locale from dropdown
4. Click "Apply"

Supported locales:
- English (US/UK)
- French
- German
- Spanish
- Italian
- Portuguese (Brazil)
- Chinese (Simplified)
- Japanese
- Korean

## Progress Tracking

### Progress Indicator

When performing bulk operations, a progress indicator appears:

```
┌──────────────────────────────────────────┐
│ Processing...              [Dismiss]     │
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  60%            │
│ 6 of 10 completed                         │
└──────────────────────────────────────────┘
```

### Progress States

- **Processing**: Operation in progress
- **Completed**: All entries processed
- **Partial**: Some entries failed

### Error Handling

Failed operations show error details:

```
┌──────────────────────────────────────────┐
│ Processing...              [Dismiss]     │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  100%            │
│ 8 of 10 completed        2 failed        │
└──────────────────────────────────────────┘
```

Failed entries are listed with error messages:
- "Entry not found"
- "Permission denied"
- "Validation failed"
- "Concurrent modification"

## Undo Functionality

### Undo Notification

After a successful bulk operation, an undo notification appears:

```
┌──────────────────────────────────────────┐
│ ✓                        [Undo] [Dismiss]│
│ Entries published successfully           │
│ 3 entries affected                       │
└──────────────────────────────────────────┘
```

### Undo Period

- **Duration**: 30 minutes
- **Per-operation**: Each operation has its own undo window
- **Auto-dismiss**: Notification dismisses after 30 seconds

### Performing Undo

1. Click "Undo" in the notification
2. System reverses the operation
3. Page refreshes to show changes

### Undo Limitations

- Cannot undo after 30 minutes
- Cannot undo if entries were modified since
- Cannot undo if selection was cleared
- Only one undo level per operation

## Permissions

### Required Permissions

| Action | Permission |
|--------|------------|
| Publish | `content:publish` |
| Unpublish | `content:publish` |
| Archive | `content:archive` |
| Delete | `content:delete` |
| Change Locale | `content:edit` |

### Permission Errors

If you lack permissions:

```
┌──────────────────────────────────────────┐
│ ⚠️ Operation Failed                      │
│ You don't have permission to publish     │
│ entries. Contact your administrator.     │
└──────────────────────────────────────────┘
```

## API Usage

### Bulk Action Endpoint

```http
POST /admin/content/{contentType}/bulk
```

Request body:

```json
{
  "entryIds": [
    "uuid-1",
    "uuid-2",
    "uuid-3"
  ],
  "action": "publish"
}
```

Response:

```json
{
  "successCount": 2,
  "failureCount": 1,
  "canUndo": true,
  "undoToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "failures": [
    {
      "entryId": "uuid-3",
      "error": "Entry not found"
    }
  ]
}
```

### Undo Endpoint

```http
POST /admin/bulk/undo
```

Request body:

```json
{
  "undoToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

## Best Practices

### 1. Verify Selection

Always verify your selection before performing bulk actions:

```
Selected: 150 entries
Filter: Status = Draft, Created > 2024-01-01
```

### 2. Test on Small Sets

When unsure, test on a small subset first:

1. Select 2-3 entries
2. Perform the action
3. Verify results
4. Apply to full selection

### 3. Use Descriptive Names

When saving filters for bulk operations:

```
Good: "Draft posts from January 2024"
Bad: "My filter"
```

### 4. Monitor Progress

Keep the bulk operations page open until completion:

- Don't close the tab during operations
- Don't navigate away while processing
- Check progress indicator regularly

### 5. Handle Failures Gracefully

If some operations fail:

1. Note the failed entry IDs
2. Review error messages
3. Fix issues individually
4. Retry failed entries

## Troubleshooting

### Selection Not Persisting

If selection doesn't persist:

1. Check browser console for errors
2. Verify localStorage is enabled
3. Check for browser extensions blocking storage
4. Try a different browser

### Slow Performance

For large selections:

1. Reduce selection size (< 100 entries)
2. Use filters to narrow scope
3. Perform operations during off-peak hours
4. Consider API usage for automation

### Undo Not Working

If undo fails:

1. Check if 30-minute window expired
2. Verify entries haven't been modified
3. Try manual reversal if possible
4. Contact support for assistance

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl/Cmd + A` | Select all visible entries |
| `Escape` | Clear selection |
| `Ctrl/Cmd + Enter` | Perform primary bulk action |

## Mobile Considerations

### Touch Optimization

On mobile devices:

- Minimum touch target: 44x44px
- Swipe actions for quick operations
- Optimized card view for selection

### Performance

For better mobile performance:

- Limit selection to 50 entries
- Use WiFi when available
- Close other apps during operations

## Additional Resources

- [Content Management Guide](/docs/content-management.md)
- [Permissions Guide](/docs/admin/permissions.md)
- [API Reference](/docs/api/rest.md)
