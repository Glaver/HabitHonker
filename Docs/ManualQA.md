# Manual QA Checklist

This checklist captures the current Stabilization Phase baseline. Run it before and after stabilization changes. Do not use it to validate new product features.

## Test Setup

- Build and run the `HabitHonker` scheme.
- Prefer a clean simulator or a known test device state.
- Record whether iCloud is signed in and whether notification permission has already been granted.
- Use at least one repeating habit and one due-date habit during testing.

## 1. App Launch

- [ ] App launches without crash.
- [ ] Launch screen completes and the main UI appears.
- [ ] App does not stay on a blank system background.
- [ ] If iCloud is unavailable, app still launches.
- [ ] Relaunch after force quit preserves previously saved local data.

Notes:

- Current risk: SwiftData container creation can silently fall back to an in-memory container.

## 2. All 4 Tabs

- [ ] List tab opens.
- [ ] Priority tab opens.
- [ ] Statistic tab opens.
- [ ] Settings tab opens.
- [ ] Switching tabs repeatedly does not crash or reset visible state unexpectedly.
- [ ] Tab titles/icons render correctly.

## 3. Create Habit

- [ ] Tap plus from List.
- [ ] Enter habit title.
- [ ] Optionally enter description.
- [ ] Select icon.
- [ ] Select icon color.
- [ ] Select priority.
- [ ] Create a repeating habit with selected weekdays.
- [ ] Create a due-date habit with date/time.
- [ ] Save dismisses the detail screen.
- [ ] New habit appears in the List tab.
- [ ] New habit appears in the correct Priority Matrix quadrant.
- [ ] Relaunch app and verify new habit persists.

Known risks:

- Save dismisses before async persistence visibly completes.
- `HabitModel` is UI-coupled through `SwiftUI.Color`.

## 4. Edit Habit

- [ ] Open an existing habit from the List tab.
- [ ] Change title.
- [ ] Change description.
- [ ] Change icon.
- [ ] Change icon color.
- [ ] Change priority.
- [ ] Change repeating weekdays or due date.
- [ ] Save changes.
- [ ] Verify List updates.
- [ ] Verify Priority Matrix updates if priority changed.
- [ ] Relaunch and verify changes persist.

Known risks:

- Detail lookup can fall back to a mock habit if the item is missing.
- Notification disable state needs explicit verification.

## 5. Complete Habit

- [ ] Swipe an incomplete habit and tap complete.
- [ ] Habit moves to Completed section for today.
- [ ] Completion count/history persists after relaunch.
- [ ] Completing the same habit again does not crash.
- [ ] Priority Matrix still displays the habit consistently.
- [ ] Statistics calendar reflects the completion after refresh/opening Statistics.

Known risks:

- Completion uses optimistic in-memory update plus persistence event reload.
- Statistics refresh can become stale when selected habit IDs do not change.

## 6. Delete / Archive Habit

- [ ] Open an existing habit.
- [ ] Tap delete.
- [ ] Confirm destructive alert.
- [ ] Detail screen dismisses.
- [ ] Habit is removed from List.
- [ ] Habit is removed from Priority Matrix.
- [ ] Relaunch and verify habit remains removed from active lists.
- [ ] If the deleted habit was selected in Statistics, verify historical statistics behavior remains understandable.

Known risks:

- Delete archives to `DeletedHabitSD`.
- Notification cancellation can be missed for deleted habits.

## 7. Restore Status

Current status: UNKNOWN from baseline audit. Repository and service methods exist, but no active restore UI entry point was confirmed.

- [ ] Verify whether any current UI exposes deleted/archived habits.
- [ ] If restore UI exists, restore a deleted habit.
- [ ] Verify restored habit appears in List.
- [ ] Verify restored habit appears in Priority Matrix.
- [ ] Verify restored habit preserves completion history.
- [ ] If no restore UI exists, record "Restore UI not available in current baseline."

Known risks:

- Restore support exists below the UI layer but may not be user-accessible.

## 8. Priority Matrix Drag / Change

- [ ] Open Priority tab.
- [ ] Verify all four quadrants render.
- [ ] Drag a habit to each other quadrant.
- [ ] Verify the moved habit visually changes quadrant.
- [ ] Return to List and verify priority changed.
- [ ] Relaunch and verify priority persists.
- [ ] Open Settings, change priority colors/titles, save.
- [ ] Verify Priority tab reflects updated labels/colors.

Known risks:

- Drag/drop changes are optimistic and then persisted.
- Matrix detail tap is currently not an active navigation path.

## 9. Statistics Refresh

- [ ] Open Statistic tab.
- [ ] Open habit selection.
- [ ] Select up to the current maximum number of habits.
- [ ] Save selection.
- [ ] Verify selected habits appear as filters.
- [ ] Complete a selected habit from List.
- [ ] Return to Statistic tab.
- [ ] Verify completion appears on the correct day.
- [ ] Relaunch and verify selected statistics habits persist.
- [ ] Delete a selected habit and verify historical stats behavior remains understandable.

Known risks:

- Statistics can become stale because calendar generation may ignore record-only changes.
- Deleted habits can be included for historical statistics.

## 10. Notification Schedule / Disable / Delete

- [ ] Grant notification permission when requested.
- [ ] Create or edit a repeating habit.
- [ ] Enable notification.
- [ ] Select weekdays and reminder time.
- [ ] Save and verify no crash.
- [ ] Create or edit a due-date habit with future date/time.
- [ ] Enable notification.
- [ ] Save and verify no crash.
- [ ] Disable notification for a previously scheduled habit.
- [ ] Save and verify notification should no longer be pending.
- [ ] Delete a habit that had notifications enabled.
- [ ] Verify deleted habit should no longer have pending notifications.

Known risks:

- Notification lifecycle is fragile.
- Current cancellation logic may use stale ViewModel item state.
- Notification scheduling errors are currently not user-visible.

## 11. iCloud Toggle

- [ ] Open Settings.
- [ ] Verify iCloud sync toggle renders.
- [ ] If signed out of iCloud, try enabling sync.
- [ ] Verify the sign-in alert appears.
- [ ] If signed in to iCloud, toggle sync on.
- [ ] Verify app remains usable after container rebuild.
- [ ] Create a habit while sync is on.
- [ ] Relaunch and verify data remains.
- [ ] Toggle sync off.
- [ ] Verify app remains usable after container rebuild.
- [ ] Relaunch again and verify local data behavior is understandable.

Known risks:

- CloudKit/in-memory fallback can hide persistence failures.
- Sync toggle rebuilds the SwiftData container at runtime.
- Migration behavior between local and CloudKit stores is not fully documented.

## Current Known Risks Summary

- [ ] Notification lifecycle: disable/delete cancellation needs stabilization.
- [ ] Statistics stale refresh: record changes can fail to regenerate visible calendar state.
- [ ] CloudKit/in-memory fallback: failed container creation can fall back to in-memory storage.
- [ ] No test target: automated regression coverage is not present yet.
- [ ] Restore UI unknown: restore exists in lower layers but UI availability is unconfirmed.
- [ ] `HabitModel` is UI-coupled through `SwiftUI.Color`.
