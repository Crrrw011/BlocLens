# BlocLens Page State Specification

## 1. Purpose

This specification defines consistent MVP states for the major iPhone page families. State presentation must use localised English (Australia) source copy and preserve native SwiftUI accessibility behaviour. A state may combine with another state, such as an archived route shown from cache while offline.

## 2. Shared state definitions

| State | Definition | Required behaviour |
|---|---|---|
| **Initial** | The destination exists but no request has started. | Show stable page chrome without fake data; begin the first required load once. |
| **Loading** | Required data is being resolved. | Use the reusable loading state or skeleton-like structure; preserve known navigation context. |
| **Loaded** | Required data is available. | Show current content and valid actions. Clearly label official, community, estimated and private information. |
| **Empty** | The request succeeded but no records match. | Explain what belongs here. Offer a relevant optional contribution only when permitted. |
| **Error** | A request failed for a reason other than offline state. | Explain the failure in plain language and provide **Try Again** where retry is safe. Never discard a local draft. |
| **Offline with cache** | Connectivity is unavailable and relevant cached data exists. | Show cached content with an offline or freshness label. Disable network-only actions without removing context. |
| **Offline without cache** | Connectivity is unavailable and no useful cache exists. | Show a clear offline state and a safe return path. Do not present an endless loader. |
| **Permission denied** | A contextual iOS permission was declined or restricted. | Keep core browsing available where possible and explain how to continue without the permission or open Settings. |
| **Authentication required** | A Guest selects a beta or account action. | Preserve the original intent and present **Authentication Gate**. Cancellation returns to unchanged content. |
| **Archived or unavailable** | Content is historical, removed, reset, broken or otherwise unavailable. | Distinguish read-only history from missing data. Preserve confirmed historical records. |
| **Moderation-hidden** | Public content is temporarily hidden under the PRD report rules. | Do not reveal the content. Explain that it is unavailable while review occurs and provide a safe return. |

## 3. State priority

When several states apply, use this presentation priority:

1. Account or content safety: **Moderation-hidden**.
2. Historical truth: **Archived or unavailable**.
3. Access gate for a selected action: **Authentication required**.
4. Connectivity: **Offline with cache** or **Offline without cache**.
5. Permission state for the selected capability.
6. Request lifecycle: **Initial**, **Loading**, **Loaded**, **Empty** or **Error**.

This priority does not erase lower-priority context. For example, an archived cached route remains visibly archived and offline.

## 4. Page-family state matrix

| Page family | Initial / Loading / Loaded | Empty | Error | Offline with cache | Offline without cache | Permission denied | Authentication required | Archived / unavailable | Moderation-hidden |
|---|---|---|---|---|---|---|---|---|---|
| **Launch and Onboarding** | Resolve local onboarding state; pages use bundled content | Not applicable | Fall back to safe Map entry if local state cannot be read | Fully usable | Fully usable | Not requested | Not requested upfront | Not applicable | Not applicable |
| **Nationwide Gym Map** | Load map and gym pins after entry | Explain no gyms in the current area or filters | Retry gym data; retain map position | Show saved-gym shortcuts and cached summaries; no full offline map | Show offline state and saved navigation unavailable | Location denial keeps manual map and search available | Never required for browsing | Closed or unavailable gym is labelled | A hidden user contribution must not appear |
| **Search and Map Filters** | Load searchable index or filter options | **No Matching Results** with filter reset | Retry without clearing query | Search cached recent gyms, zones and routes only | Explain search needs a connection | Not applicable | Never required for public search | Historical routes may appear clearly labelled | Hidden results are excluded |
| **Gym Preview Card** | Show a loading summary before complete data | Gym summary unavailable | Retry or open basic Gym Detail | Show cached summary with stale label | Explain details unavailable offline | Distance may be unavailable without location | Never required | Gym closure or unavailable status is labelled | Hidden contributions are excluded |
| **Gym Detail** | Load routes/zones first, then reset and operating modules | Explain missing gym details without hiding navigation | Module-level retry where possible | Show cached saved gym, zones and recent routes | Show offline state | Location denial affects distance/navigation only | Browsing remains guest-accessible | Closed or historical data is labelled | Hide affected public items only |
| **Wall Zone Directory** | Load ordered named zones and attributes | Explain that no zones are listed; eligible correction prompt may appear | Retry while retaining Gym Detail | Show cached zones | Explain zones unavailable offline | Not applicable | Guest can browse; contribution is gated | Archived/unavailable zone is labelled and read-only | Hidden zone contribution is omitted |
| **Wall Zone Detail and Route List** | Load zone context, reset and route rows | Explain no current routes; optional **Add New Route** with **Not Now** | Retry while preserving filters | Show recently viewed cached routes | Explain current routes unavailable offline | Not applicable | Browsing is public; Add is gated | Historical routes remain labelled | Hidden routes do not reveal content |
| **Route Detail** | Load identity before beta/comments modules | Route data unavailable | Module-level retry; keep route identity | Show cached identity and Logbook state; beta disabled | Explain route unavailable offline | Camera/photo permission only when adding an image | Required for beta reveal, Logbook and contribution actions | Show read-only historical banner and preserved history | Replace hidden content with review-unavailable state |
| **Route Photo** | Load cover and gallery | Optional photo contribution prompt with **Not Now** | Keep route identity and retry image | Show cached image if available | Show text-based route identity | Denial keeps manual browsing; explain camera/library alternatives | Required only to contribute | Historical photos remain attributed | Hidden photo is not displayed |
| **Beta Links and Reveal Beta** | Load blurred preview and attributed link metadata | Optional **Publish Beta Link** prompt with **Not Now** | Broken Link or retry state; allow report when signed in | Metadata may display; reveal/play disabled | Explain external beta requires connection | Not applicable | Always gate Guest reveal | Archived route links remain historical when source exists | Hidden beta is unavailable pending review |
| **Community V Grade** | Load official grade separately from valid community result | **Not Enough Votes Yet**; no prediction before three valid votes | Retry vote/result module | Show cached published median; new vote waits for connection | Explain community result unavailable | Not applicable | Vote requires sign-in and prior attempt | Historical result remains distinguishable | Invalid/hidden votes are excluded from result |
| **Comments** | Load flat comments | **No Comments Yet** | Retry without losing draft | Show cached comments read-only | Explain comments unavailable | Not applicable | Writing requires sign-in | Historical comments remain where allowed | Hidden comment content is not displayed |
| **Add Action Menu** | Present immediately over current tab | Not applicable | Not applicable | Allow private Logbook action; public actions explain connectivity | Same as offline with cache | Camera/photo permission is requested only inside the chosen action | Gate every action for Guest | Route-dependent actions explain unavailable target | Hidden target cannot receive a contribution |
| **Add New Route** | Resolve gym and existing wall-zone choices | No wall zone: explain that ordinary users cannot create zones and offer safe exit | Retain draft and retry | Existing draft remains; publication waits | Draft can begin only if required cached choices exist | Photo permission is optional | Required | Cannot add a current route to unavailable zone | Submission blocked for hidden target context |
| **Publish Beta Link** | Load route selector and validate public URL | No route selected | Retain URL, attribution and tags; retry | Retain local draft only | Retain local draft only | Not applicable | Required | Archived route contribution is unavailable unless explicitly permitted later | Submission blocked while target is hidden |
| **Route Photo and Hold Marking** | Present image and marking controls | Explain that an image is required | Preserve local marks and retry submission | Fully edit local draft; submit later | Fully edit local draft if image is local | Explain camera or library denial and allow the other available source | Required to submit | Historical/unavailable target blocks submission | Hidden target blocks submission |
| **Quick Logbook State and Record Detail** | Save status immediately; load optional private fields | New record form has no empty state | Keep local record and show sync error | Read and write; mark queued | Read local records and write queued changes | Not applicable | Required | Preserve historical route reference in private record | Private record remains private; public moderation does not erase it |
| **Logbook Dashboard and Lists** | Load private local cache first, then synchronise | Explain how to save the first route | Retry sync without hiding local records | Full cached read; new records queue | Same, if local data exists; otherwise explain no local records | Not applicable | Required | Archived route records remain in history | Private records are not moderation-hidden automatically |
| **Logbook Statistics** | Calculate from private records | Explain that more records are needed | Retry calculation or data load | Calculate from cached private records | Same when local records exist | Not applicable | Required | Archived routes remain included as history | Not applicable to private aggregates |
| **Export Logbook** | Confirm scope and prepare export | Explain there are no records to export | Retry without changing records | May export cached local records and label scope | Same if local records exist | File/share permission follows system presentation | Required | Include historical records | Never expose private export publicly |
| **Profile and Following** | Load public profile and private settings | Guest sees contextual sign-in; lists explain no items | Retry individual modules | Show cached profile and lists | Show local account basics only | Photo permission only for optional avatar selection | Required for editing or following | Unavailable profiles are labelled | Blocked or hidden public content is withheld |
| **Notification Settings** | Load local and server preferences | Not applicable | Keep local choices and retry sync | Allow local changes and queue sync | Allow local changes | Notification denial links to system Settings and keeps category controls visible | Required | Not applicable | Not applicable |
| **Help and Policy Pages** | Prefer bundled or cached controlling content | Content unavailable | Retry remote refresh while keeping cached version | Show cached or bundled copy | Show bundled copy where supplied | Not applicable | Public | Superseded content must be version-labelled | Not applicable |
| **In-App Feedback** | Prepare privacy-safe metadata | Empty message validation | Retain draft | Retain draft; send later only if supported by implementation | Retain draft | Screenshot/photo denial leaves text feedback available | Guest feedback may be allowed by product surface | Current page unavailable does not block feedback | Never attach hidden or private content by default |
| **Account Data and Delete Account** | Load account controls and confirm identity | Not applicable | Stop deletion and explain retry; never assume success | Export may use cache; deletion disabled | Deletion disabled | Not applicable | Required | Not applicable | Not applicable |
| **Verified Gym Tools** | Confirm role and load owned gym | No associated verified gym | Retry role/data load | Read cached official data only | Explain management needs a connection | Camera/photo denial affects optional official images only | Required plus Verified Gym role | Archived items are read-only until valid action | Hidden content management defers to admin review |

## 5. Cache and offline write policy

### 5.1 Pages that may display cached data

- Saved gyms and their practical summaries.
- Projects and private Logbook records.
- Recently viewed wall zones and routes.
- Published community grade results and comments when previously loaded.
- Profile basics, settings and followed/blocked-account lists.
- Bundled or previously cached help and policy content.

Cached operating information and reset estimates must show freshness or estimate labels where relevant.

### 5.2 Pages that may write offline

- **Quick Logbook State**.
- **Record Detail**, including attempts and private notes.
- Private Logbook status changes and locally derived statistics.
- Local drafts for route, photo/marking, beta-link and feedback flows may be retained, but public publication is not complete until the server confirms it.

An offline public-contribution draft must never appear publicly or be reported as successful.

### 5.3 Actions that require connectivity

- Authentication and account creation.
- External beta reveal, inline playback and source-platform handoff.
- Public route, photo, beta-link, comment, grade-vote, correction and report submission.
- Follow, block-list changes and server notification preference synchronisation.
- Gym claims and Verified Gym management.
- Account deletion.

## 6. Authentication requirements

- Guest access includes the map, gym information, named wall zones, routes and public non-beta summaries.
- **Reveal Beta** invokes **Authentication Gate** and restores the original route after successful setup.
- Logbook, contributions, community voting, comments, reports, following, blocking and account management require sign-in.
- The 16+ self-declaration occurs during first account creation, not during guest map browsing.

## 7. Contribution prompt rules

Eligible contexts include:

- Empty wall zones or route lists.
- Missing route attributes or photos.
- A post-climb private save followed by a separate public contribution opportunity.
- Reset confirmation.
- Broken beta links.
- Optional profile fields that improve beta matching.

Every prompt must:

1. State exactly what data would be shared.
2. State whether visibility is public or anonymous.
3. Explain the direct climbing benefit.
4. Provide a clear primary action such as **Share** or **Add Details**.
5. Provide a visible **Not Now** action.
6. Respect dismissal and a frequency cap.
7. Leave core functionality available after dismissal.
8. Never expose or automatically convert private Logbook information.

## 8. Error and empty-state language

- Use practical, non-blaming language.
- Do not imply urgency, guilt or lost access for declining a contribution.
- Distinguish **No Results**, **Offline**, **Permission Denied**, **Sign In Required**, **Archived**, **Unavailable** and **Hidden for Review** rather than using a generic failure for all cases.
- Error actions use precise labels such as **Try Again**, **Open Settings**, **Sign In**, **View Cached Gym**, **Keep Draft**, or **Not Now**.
- Source English follows English (Australia). Korean and Simplified Chinese must preserve the same voluntary, privacy-safe meaning.
