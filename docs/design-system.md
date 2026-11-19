# Braino design system

Current implementation: **0.8.1**. The shared HTML, CSS and JavaScript in `preview/` define the interface in both the browser and the Mac app. Native AppKit code supplies the window, menu bar, global shortcut, text-editing menus and persistence. Earlier separate SwiftUI controls are no longer part of the app.

## Product principle

**One shortcut. Start typing.**

Braino aims to reduce the effort of capturing a small task. People already have tools; the design opportunity is making the way into this one short and predictable. Writing comes before organizing. See [product intent](product.md) for the positioning, scope and claims to use in the portfolio.

## Visual foundations

| Token | Value | Use |
| --- | --- | --- |
| Lemon | `#F5D928` | Selected planning pill, completion and other focused feedback |
| Carbon | `#191A17` | Text, icons and scratch line |
| Canvas | `#F9F8F2` | Lightly warm window background |
| Surface | `#FFFFFF` | Tasks, weekly day cards and secondary controls |
| Muted | `#7D7F75` | Supporting text |
| Divider | `#E9E9DF` | Quiet separation |
| Type | System sans: `-apple-system`, `BlinkMacSystemFont`, `Segoe UI`, sans-serif | Shared browser and desktop stack |
| Task radius | 14 px | Rounded task surfaces |
| Spacing | 4, 8, 12, 16, 24 px | Repeated rhythm |

The wordmark is the strongest text. Section headings are compact, approximately 19 px; planning-pill labels are approximately 10.5–11 px. Keep the top area short so tasks are visible when the shortcut opens the window. Avoid serif headings and decorative subtitles inside the app.

The supplied transparent pixel brain is the identity. Preserve its silhouette and open spaces; do not replace it with a solid fill. `Assets/BrainoMark.png` is the original source. The Dock and installer icon use a larger brain over a shaded lemon tile; header and menu-bar marks remain transparent. `scripts/BrandAssets.swift` generates these assets.

## Capture and focus

The input reads “add something” inside a soft dashed container. Return saves and leaves capture ready for another task. The footer reads “Log your to do’s.”

A title is sufficient. Due date and category controls start collapsed; opening them should be a choice, not a required step. Due dates begin unset. Category defaults to none unless a category filter supplies the capture context.

Control–Space shows and focuses the Mac app from the background. Pressing it again while the window is active hides it. Delayed focus callbacks must never reopen a hidden window. In This week, capture focus goes to today's inline field, expanding its day card if needed. The browser shortcut only focuses capture within the page.

## Planning and metadata

- **Today:** tasks planned for today and earlier. Tasks do not silently disappear at midnight.
- **This week:** Monday–Sunday in local time, with a white collapsible card and inline capture for every day, including empty days. Entering the view initially scrolls Today to the top; earlier days remain above it. Today is not a sticky header.
- **Someday:** tasks without a planned day.
- **Due date:** separate from planning placement. Setting one does not move the task between views.
- **Categories:** optional names, with All, Uncategorized and named filters. The custom category menu includes New category…; named categories persist even when empty.
- **Completed:** absent until at least one task is completed. It opens with Past week selected and honors the category filter. Reopen a task using its check.

Completed ranges use local calendar dates: Past day is today; Past week is today plus six previous dates; Past month is today plus 29 previous dates. Custom dates are inclusive. Legacy completions without timestamps appear in All time; do not invent completion dates.

The category trigger sits immediately before the task count and reads “All” when unfiltered. Open tasks display only explicitly assigned due dates and categories, not logging-date records.

## Window and list density

The desktop starts at its minimum width of 410 points. Its height fits content within screen limits. Capture remains reachable outside the main task scroll region.

The weekly list has its own scroll area, capped at `min(48vh, 370px)` in the shared CSS. Day cards start expanded and can be collapsed independently. The same shared layout runs in WKWebView; there is no separate native weekly layout to maintain.

Task cards must not shrink inside the flex list. Opening a structured task editor releases the ordinary task-list height cap so Save/Cancel and padding remain reachable.

## Editing, ordering and recovery

Titles and expanded notes edit directly in place and persist as typed. There is no separate Edit note link. The icon-only note chevron sits immediately before the ellipsis. The structured editor keeps Save/Cancel for notes, due date and category, without duplicating the inline title field.

A small grip before the check appears on hover or focus. Pointer capture supports dragging in both browser and WebKit. A lifted task preview follows the pointer; a full yellow destination gap opens while neighbors slide aside. The task settles into its final position on release. Edge scrolling supports long lists. Empty or collapsed weekly days accept a drop and open after a successful move. Escape cancels.

Order persists in the task array. Cross-day moves change the planning day, not the due date. Category-filtered moves preserve unrelated tasks and metadata. Completed history remains ordered by completion date. Keyboard alternative: focus the grip, then Option–Up/Down within the current list or day.

Delete appears on hover or keyboard focus. Completion, deletion and moving share the latest-action on-screen Undo slot. Move Undo restores the prior order and planning day while preserving later text edits and newly captured tasks.

## Motion

Motion should clarify what changed without delaying capture or creating another step.

- **Planning:** one continuous sliding yellow highlight, with a separate short content fade/settle. Preserve the highlight element through rerenders.
- **Notes and day cards:** animate expansion downward and reverse on collapse; collapsed content remains inaccessible to keyboard and screen readers.
- **Completion:** immediate yellow check and settling feedback, a left-to-right scratch, then row fade and handoff to history at approximately 480 ms. Retain Undo.
- **Ordering:** show the destination before release, slide neighbors into place, then settle and briefly highlight the dropped task.
- **Reduced motion:** respect OS preferences; the browser also offers a Reduce motion control. Keep static state feedback understandable without movement.

Portfolio animation can use a more expressive keypress, spring and tuck-away to explain the interaction. Label it as a motion illustration; do not imply that a staged animation is a native-app recording. Gallery covers remain graphics without wordmarks, taglines or interface chrome.

## Voice and validation

Prefer practical language about capture and access. Avoid framing users as lacking places to write, or implying that all existing tools are too formal. Aim for low friction; do not claim it is frictionless for everyone.

Subjective satisfaction and reduced interruption are design hypotheses. Do not claim a completion animation releases dopamine or universally “scratches the brain.” Validate by observing first capture, repeated use, keyboard navigation and reduced motion.

Further reading retained from the original design exploration:

- [NN/g: The Role of Animation and Motion in UX](https://www.nngroup.com/articles/animation-purpose-ux/)
- [NN/g: Executing UX Animations](https://www.nngroup.com/articles/animation-duration/)
- [Deci & Ryan: The What and Why of Goal Pursuits](https://selfdeterminationtheory.org/SDT/documents/2000_DeciRyan_PIWhatWhy.pdf)
- [W3C: Understanding Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions)
