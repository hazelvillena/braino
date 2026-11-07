# Braino design system

Braino should feel light, direct and a little tactile. The dissolving pixel brain and rounded lowercase wordmark are the identity. Preserve the supplied artwork and its transparency; do not fill, silhouette, trace, or recolor it.

## Foundations

| Token | Value | Use |
| --- | --- | --- |
| Lemon | #F5D928 | Selected planning pill, completion check, add button |
| Carbon | #191A17 | Text, icons, scratch line |
| Canvas | #F9F8F2 | Neutral, lightly warm app background |
| Surface | #FFFFFF | Task cards and capture |
| Muted | #7D7F75 | Supporting text |
| Divider | #E9E9DF | Quiet separation |
| Type | SF Pro Rounded / system rounded sans | Brand, headings, controls, supporting copy |
| Card radius | 14 px | Tasks and capture |
| Spacing | 4, 8, 12, 16, 24 px | Repeated rhythm |

Headings are bold rounded sans, never serif. Body text uses medium and regular weights; reserve heavy weight for the wordmark and headings. Avoid tracking-heavy uppercase footers. Footer copy: “Take it easy. One thing at a time.” Yellow stays in small purposeful accents, not large panels or the icon background. The current browser falls back to the available system sans; the native app uses Apple's rounded system font.

## Information architecture

- Today: scheduled today and overdue tasks. No silent disappearance at midnight.
- This week: Monday–Sunday in local time, all seven days in one continuous list, including empty days, each with inline task capture.
- Someday: undated tasks. It replaces a separate inbox for this small first version.
- Categories: optional per-task text, none by default. Filter by all, uncategorized, or a category. The dropdown includes New category… for lightweight creation; empty categories persist and are selected immediately. No setup required.
- Completed: collapsed below open tasks, independent of the planning tab, honoring the category filter. Completion immediately moves the task here after the feedback animation. Reopen via its check.
- Completed opens with Past week selected. Filters: Past day (today), Past week (today + previous six local dates), Past month (today + previous 29 local dates), All time, Custom range (inclusive dates). These are calendar-day ranges, not rolling-hour windows.
- Legacy completed tasks without a timestamp appear only in All time; never fabricate a completion date.
- Keep on top: icon-only pin with a short hover tooltip and an accessible name. It controls floating-window behavior on Mac. In the browser it demonstrates state and explains the native behavior.

## Completion feedback

Browser sequence: immediate yellow check with a small settling motion (~170–260 ms); scratch line draws left to right (~240 ms, begins 80 ms after click); row fades after 340 ms; task enters Completed at ~480 ms. A subtle check-local ring reinforces the action, without screen-wide effects, sound, streaks or pressure. Undo remains available for the last completion. The native app uses a check fill, spring settle, line sweep and ~450 ms handoff with Undo. Check and status announce the result without relying only on color.

Reduced motion: respect OS preferences. The browser also exposes a Reduce motion control. In reduced motion the state changes immediately and retains clear static feedback; no delay, scale, ring or movement is required.

## Research and judgment

[NN/g: The Role of Animation and Motion in UX](https://www.nngroup.com/articles/animation-purpose-ux/) recommends brief, unobtrusive motion that communicates feedback and state changes, and warns that irrelevant motion distracts.

[NN/g: Executing UX Animations](https://www.nngroup.com/articles/animation-duration/) recommends defining trigger, transformation, timing and easing, with shorter, subtler feedback for frequent actions. The exact Braino timings are design choices, not experimentally proven optimal durations.

[Deci & Ryan, 2000: The What and Why of Goal Pursuits](https://selfdeterminationtheory.org/SDT/documents/2000_DeciRyan_PIWhatWhy.pdf) discusses autonomy and competence in motivation. This supports a restrained design hypothesis: make the user's progress visible without introducing controlling rewards. It does not establish that a particular task animation releases dopamine or universally “scratches the brain.”

[W3C: Understanding Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions) explains supporting user control over nonessential motion. Braino follows OS reduced-motion preferences and keeps its completion signal understandable without animation.

Validate subjective satisfaction by trying repeated completions, including keyboard use and reduced motion. “Satisfying” is a product hypothesis, not a medical or universal psychological claim.

## Refinement: movement and editing

Planning pills share one sliding yellow highlight. Browser transform/width transitions use a 430 ms decelerating curve, preserving the highlight element through task renders. Native tabs use a matched-geometry capsule with a 430 ms spring. Reduced motion disables the movement.

Task details are drafts. A small Save action commits title, notes, schedule and category together and closes the editor. Cancel discards changes. Browser drafts survive task-list rerenders until saved or cancelled. Soft neutral fields use minimal borders, quieter labels, and visible focus feedback. Command-Enter saves.

The weekly list shows all seven day sections, including empty days, without a second row of day toggles. Each day has a quiet Add a task… field; Return saves to that day and leaves focus there. Category-filtered inline capture inherits the chosen category.

## Compact shortcut panel

The wordmark is the largest text. View labels are 19 px semibold, planning pills use 10.5–11 px labels and 6 px vertical padding, and explanatory subtitles are removed. Task cards are compact with a 44 px minimum in the browser. The browser's active task list scrolls independently for long lists; the native capture line stays outside the task scroll region so shortcut focus does not scroll the list to the bottom.

Quick capture is a quiet plus-and-text line, with Return to save. Capture belongs to the selected planning view. Its optional details contain a clearly labeled Due date and category picker, hidden until opened. There are no additional planning pills in capture. Due date is independent of planning placement and starts unset. Category and date metadata do not block capture.

## View flow and secondary details

Browser view changes fade and settle content by 5 px over 260 ms while smoothly adapting its height; the yellow planning highlight retains its separate continuous slide. Native task groups use an opacity/5 px transition alongside the selected pill spring. Both respect reduced motion.

The category filter lives in the title row as a quiet small control. Notes are collapsed behind a Notes disclosure by default; expand to read the full note or choose Edit note. Task due dates display as explicitly labeled metadata and never change the planning view. Existing scheduled dates remain planning dates; no historical deadline is invented during migration.
