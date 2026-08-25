# BlocLens Information Architecture

## Document status

This specification defines the frozen MVP page tree for the native iPhone app. It is derived from `BlocLens_MVP_PRD_v1.1.docx`. New product surfaces belong in the Post-MVP Backlog unless the MVP is explicitly unfrozen.

## 1. Product navigation principles

- BlocLens is a climbing utility first. Every destination must support gym discovery, route identification, useful beta, or practical climbing records.
- Social behaviour is secondary. Following, comments and Helpful feedback exist only to improve beta utility; there is no general social feed.
- Guest users can browse the nationwide map, gym information, wall-zone lists and route information.
- Authentication is requested only when a guest attempts to reveal beta or perform an account action.
- Private Logbook data never becomes public automatically. A public contribution always requires a separate explicit action.
- Beta is external-link-only. BlocLens never accepts, hosts, mirrors, transcodes, caches or downloads a video file.
- Wall navigation is list-based, using named wall zones and attributes.
- There is no 2D wall map, floor plan or clickable wall hotspot interface.
- The five primary destinations are Home, Map, Add, Logbook and Profile. Add is a central action menu, not a persistent blank destination.
- The Administrator web portal is a separate product surface and is never placed in the iPhone tab bar.

## 2. Complete page tree

### 2.1 App entry

- `ENTRY-001` **Launch** — resolves onboarding state, account state and a pending destination.
  - `ENTRY-002` **Find Gyms Onboarding** — onboarding page one.
  - `ENTRY-003` **Find Beta Onboarding** — onboarding page two.
  - `ENTRY-004` **Record Climbing Onboarding** — onboarding page three.
  - `MAP-001` **Nationwide Gym Map** — map-first guest entry after onboarding.
  - `AUTH-001` **Authentication Gate** — presented only for beta reveal or an account action.
    - `AUTH-002` **Sign in with Apple**
    - `AUTH-003` **Sign in with Google**
    - `AUTH-004` **16+ Self-Declaration**
    - `AUTH-005` **Username Setup**
    - `AUTH-006` **Optional Profile Completion**
    - `AUTH-007` **Authentication Error**
  - `SAFE-001` **Reveal Beta Safety Acknowledgement** — first beta reveal only.
  - `SAFE-002` **Publish Beta Safety Acknowledgement** — first beta publish only.

### 2.2 Home tab

- `HOME-001` **Home** — practical dashboard, never a content feed.
  - `HOME-002` **Current or Frequent Gym**
  - `HOME-003` **Active Projects**
  - `HOME-004` **Latest Resets**
  - `HOME-005` **Recent Logbook Records**
  - `HOME-006` **Project Detail**

### 2.3 Map tab

- `MAP-001` **Nationwide Gym Map**
  - `MAP-002` **Location Permission Context** — shown only after **Nearby Gyms** or the location control is selected.
  - `MAP-003` **Map Filters**
  - `MAP-004` **Search** — gyms, wall zones, route colours or tags, and grades; never users or comments.
  - `MAP-005` **Gym Preview Card**
  - `GYM-001` **Gym Detail**

### 2.4 Gym structure

- `GYM-001` **Gym Detail**
  - `GYM-002` **Wall Zone Directory**
    - `GYM-003` **Wall Zone Detail**
      - `GYM-004` **Route List**
  - `GYM-005` **Latest Reset**
  - `GYM-006` **Hard/Soft Index**
  - `GYM-007` **Opening Information**
  - `GYM-008` **Facilities**
  - `GYM-009` **Claim This Gym** — domain-email or manual verification entry where appropriate.

### 2.5 Route structure

- `ROUTE-001` **Route Detail**
  - `ROUTE-002` **Route Photo**
  - `ROUTE-003` **Quick Logbook State**
  - `BETA-001` **Beta Links**
    - `BETA-002` **Reveal Beta**
  - `GRADE-001` **Community V Grade**
  - `ROUTE-004` **Comments**
  - `ROUTE-005` **Corrections and Reports**
  - `ROUTE-006` **Archived Route State** — read-only historical presentation.

### 2.6 Add action

- `ADD-001` **Add Action Menu**
  - `ADD-002` **Publish Beta Link**
    - `SAFE-002` **Publish Beta Safety Acknowledgement** when required.
    - `ADD-010` **Contribution Confirmation**
    - `ADD-011` **Contribution Success**
    - `ADD-012` **Contribution Error**
  - `ADD-003` **Add New Route**
    - `ADD-006` **Suspected Duplicate Route**
    - `ADD-007` **Route Photo and Hold Marking**
    - `ADD-010` **Contribution Confirmation**
    - `ADD-011` **Contribution Success**
    - `ADD-012` **Contribution Error**
  - `ADD-004` **Record Completed Route**
  - `ADD-005` **Identify or Mark Route**
    - `ADD-007` **Route Photo and Hold Marking**
  - `ADD-008` **Select Route**
  - `ADD-009` **Select Gym and Wall Zone**

There is no video-file upload page or action. **Publish Beta Link** accepts a public external URL only.

### 2.7 Logbook tab

- `LOG-001` **Logbook Dashboard**
  - `LOG-002` **Projects**
  - `LOG-003` **Wants to Try**
  - `LOG-004` **Projecting**
  - `LOG-005` **Sent**
  - `LOG-006` **Flash**
  - `LOG-007` **Record Detail**
  - `LOG-008` **Statistics**
  - `LOG-009` **Export Logbook**

All Logbook records, Projects, notes and statistics are private by default.

### 2.8 Profile tab

- `PROFILE-001` **Profile**
  - `PROFILE-002` **Edit Profile**
  - `PROFILE-003` **Frequent Gym**
  - `PROFILE-004` **Following**
  - `PROFILE-005` **Trusted Contributor Status**
  - `PROFILE-006` **Notification Settings**
  - `PROFILE-007` **Blocked Accounts**
  - `PROFILE-008` **Help Centre**
  - `PROFILE-009` **In-App Feedback**
  - `PROFILE-010` **Safety Information**
  - `PROFILE-011` **Community Guidelines**
  - `PROFILE-012` **Privacy Policy**
  - `PROFILE-013` **Terms of Use**
  - `PROFILE-014` **Copyright and Takedown Policy**
  - `PROFILE-015` **Account Data**
    - `PROFILE-016` **Delete Account**
  - `PROFILE-017` **Sign Out**

### 2.9 Verified gym functions in the iPhone app

- `VGYM-001` **Verified Gym Tools** — available only to a verified gym account.
  - `VGYM-002` **Edit Gym Information** — hours, facilities and contact details.
  - `VGYM-003` **Manage Wall Zones** — names, order, attributes and availability.
  - `VGYM-004` **Manage Resets** — publish official reset information.
  - `VGYM-005` **Manage Gym Routes** — create and maintain official route records.

An **Ordinary User** can contribute routes, photos, beta links, comments, grade votes, corrections and reports under the PRD rules. A **Trusted Contributor** has the same functional permissions plus a permanent trust badge; the role has no moderation authority. A **Verified Gym** can manage its own operating data, wall zones, resets, routes and official content, but cannot edit community grades or hard/soft calculations. The **Administrator web portal** (`ADMIN-WEB-001`) is a separate product surface for moderation, claims, merges, restoration, penalties, configuration and audit records.

## 3. Page inventory

Legend: **G** = Guest, **S** = Signed-in. Access values are **Yes**, **No**, **Gate** or **Conditional**. “Cached” means previously stored data may be shown when offline.

| Page ID | English page name | Parent or presentation source | G | S | Primary purpose | Primary action | Required data | Empty state | Offline behaviour | Surface |
|---|---|---|---:|---:|---|---|---|---|---|---|
| ENTRY-001 | Launch | App process | Yes | Yes | Resolve the correct entry destination | Continue automatically | Onboarding and account state | Branded launch state | Resolve local state | MVP iPhone |
| ENTRY-002 | Find Gyms Onboarding | Launch | Yes | Yes | Explain gym discovery | Continue | Local onboarding copy | Not applicable | Fully available | MVP iPhone |
| ENTRY-003 | Find Beta Onboarding | Onboarding | Yes | Yes | Explain route-linked beta | Continue | Local onboarding copy | Not applicable | Fully available | MVP iPhone |
| ENTRY-004 | Record Climbing Onboarding | Onboarding | Yes | Yes | Explain private climbing records | Open Map | Local onboarding copy | Not applicable | Fully available | MVP iPhone |
| SAFE-001 | Reveal Beta Safety Acknowledgement | Reveal Beta | Gate | Yes | Confirm first-reveal safety notice | Acknowledge and reveal | Safety copy | Not applicable | Requires connection to reveal | MVP iPhone |
| SAFE-002 | Publish Beta Safety Acknowledgement | Publish Beta Link | No | Yes | Confirm first-publish safety notice | Acknowledge and continue | Safety copy | Not applicable | Requires connection | MVP iPhone |
| HOME-001 | Home | Home tab | Limited | Yes | Resume practical climbing activity | Open current gym or Project | Gym, Projects, resets, recent records | Explain how content appears | Cached modules only | MVP iPhone |
| HOME-002 | Current or Frequent Gym | Home | Yes | Yes | Return quickly to a useful gym | Open Gym Detail | Gym summary | Prompt to choose a frequent gym | Cached gym summary | MVP iPhone |
| HOME-003 | Active Projects | Home | No | Yes | Resume unfinished routes | Open Project Detail | Private Projects | Explain how to add a Project | Cached; private | MVP iPhone |
| HOME-004 | Latest Resets | Home | Yes | Yes | Surface useful reset changes | Open Latest Reset | Reset summaries | No recent resets | Cached summaries | MVP iPhone |
| HOME-005 | Recent Logbook Records | Home | No | Yes | Resume recent private records | Open Record Detail | Private Logbook summaries | No records yet | Cached; private | MVP iPhone |
| HOME-006 | Project Detail | Active Projects | No | Yes | Track one private Project | Update Logbook state | Route and private Project | Route unavailable state | Cached updates may queue | MVP iPhone |
| MAP-001 | Nationwide Gym Map | Map tab or onboarding | Yes | Yes | Discover commercial bouldering gyms | Select a gym pin | Gym coordinates and summaries | No gyms in visible area | Cached saved gyms only; no full offline map | MVP iPhone |
| MAP-002 | Location Permission Context | Nearby Gyms or location control | Yes | Yes | Explain contextual location value | Continue to iOS permission | Permission state | Not applicable | Permission can still be requested offline | MVP iPhone sheet |
| MAP-003 | Map Filters | Nationwide Gym Map | Yes | Yes | Narrow gym results | Apply Filters | Gym attributes | No matching gyms | Cached attributes where available | MVP iPhone sheet |
| MAP-004 | Search | Map tab | Yes | Yes | Find gyms, zones and routes | Open result | Search index | No matching results | Cached recent content only | MVP iPhone |
| MAP-005 | Gym Preview Card | Gym pin | Yes | Yes | Evaluate a gym before opening it | Open Gym Detail | Gym summary, distance, status | Loading or unavailable summary | Cached summary | MVP iPhone sheet |
| GYM-001 | Gym Detail | Preview Card, Home or Search | Yes | Yes | Evaluate a gym and enter its zones | Open Wall Zone Directory | Gym, resets and facilities | Gym data unavailable | Cached saved gym | MVP iPhone |
| GYM-002 | Wall Zone Directory | Gym Detail | Yes | Yes | Browse named wall zones | Open Wall Zone Detail | Ordered wall zones | Encourage an optional correction or check later | Cached when saved/recent | MVP iPhone |
| GYM-003 | Wall Zone Detail | Wall Zone Directory | Yes | Yes | Understand one zone and its routes | Open Route List | Zone attributes and reset | Encourage optional route contribution with Not Now | Cached when recent | MVP iPhone |
| GYM-004 | Route List | Wall Zone Detail | Yes | Yes | Find a route by colour, tag and grade | Open Route Detail | Current routes | Encourage Add New Route with Not Now | Cached when recent | MVP iPhone |
| GYM-005 | Latest Reset | Gym Detail or Home | Yes | Yes | Explain official or estimated reset | Open affected zone | Reset record and source | No reset information | Cached | MVP iPhone |
| GYM-006 | Hard/Soft Index | Gym Detail | Yes | Yes | Compare grade bands from valid votes | Inspect grade band | Official grades and valid medians | Insufficient eligible routes | Cached | MVP iPhone |
| GYM-007 | Opening Information | Gym Detail | Yes | Yes | Show operating details | Call or open source where available | Attributed operating details | Details unavailable | Cached data may be stale-labelled | MVP iPhone |
| GYM-008 | Facilities | Gym Detail | Yes | Yes | Show practical gym attributes | None | Facility attributes | No facility details | Cached | MVP iPhone |
| GYM-009 | Claim This Gym | Gym Detail | No | Yes | Begin official gym verification | Submit claim | Domain email or verification details | Not applicable | Requires connection | MVP iPhone sheet |
| ROUTE-001 | Route Detail | Route List, Search or deep link | Yes | Yes | Identify a route and access climbing tools | Set Logbook state or reveal beta | Route, zone, reset and media metadata | Route unavailable | Cached route shell; beta requires connection | MVP iPhone |
| ROUTE-002 | Route Photo | Route Detail | Yes | Yes | Inspect route identity and hold markings | View gallery | Route photos and marks | Invite optional photo contribution with Not Now | Cached image where available | MVP iPhone |
| ROUTE-003 | Quick Logbook State | Route Detail | Gate | Yes | Save private climbing state immediately | Select status | User and route | Not applicable | Write queues locally | MVP iPhone sheet |
| ROUTE-004 | Comments | Route Detail | Read limited | Yes | Add concise route-specific context | Add Comment | Public comments | No comments yet | Cached read; write requires connection | MVP iPhone |
| ROUTE-005 | Corrections and Reports | Route Detail | No | Yes | Improve route accuracy or report harm | Submit | Route and reason | Not applicable | Requires connection | MVP iPhone sheet |
| ROUTE-006 | Archived Route State | Route Detail | Yes | Yes | Preserve read-only route history | View historical records | Archived route and history | Historical data unavailable | Cached history where available | MVP iPhone |
| BETA-001 | Beta Links | Route Detail | Preview only | Yes | Compare attributed external beta links | Reveal Beta | Link metadata and attribution | Invite external link contribution with Not Now | Metadata may cache; playback requires connection | MVP iPhone |
| BETA-002 | Reveal Beta | Beta Links | Gate | Yes | Reveal and play or hand off external beta | Play or Open Source | Public URL, platform and attribution | Broken Link state with report prompt | Requires connection | MVP iPhone sheet |
| GRADE-001 | Community V Grade | Route Detail | Read | Yes | Show attempt-gated median after threshold | Submit or edit vote | Attempt record and valid votes | Fewer than three valid votes | Cached result; vote requires connection | MVP iPhone sheet |
| ADD-001 | Add Action Menu | Central Add control | No | Yes | Choose a creation or recording task | Select action | Account state | Not applicable | Logbook action may queue; public contributions require connection | MVP iPhone sheet |
| ADD-002 | Publish Beta Link | Add Action Menu or Route Detail | No | Yes | Publish an attributed public external URL | Review Link | Route, URL, author, platform and tags | No route selected | Requires connection | MVP iPhone |
| ADD-003 | Add New Route | Add Action Menu | No | Yes | Create a route with minimum identity fields | Check Duplicates | Gym, wall zone, colour or tag | Prompt to select gym and zone | Requires connection | MVP iPhone |
| ADD-004 | Record Completed Route | Add Action Menu | No | Yes | Save a private Sent or Flash record | Save | Route and private status | Route not found | Write queues locally | MVP iPhone sheet |
| ADD-005 | Identify or Mark Route | Add Action Menu | No | Yes | Manually identify holds in an image | Continue to marking | Image, gym and zone context | No image selected | Capture local; submit requires connection | MVP iPhone |
| ADD-006 | Suspected Duplicate Route | Add New Route | No | Yes | Prevent accidental duplicate creation | Use Existing or Continue | Candidate routes | No suspected duplicates | Requires connection | MVP iPhone sheet |
| ADD-007 | Route Photo and Hold Marking | Add New Route or Identify or Mark Route | No | Yes | Mark route membership, Start and Finish | Submit Marks | Image and selected holds | No image or no holds selected | Local draft; submit requires connection | MVP iPhone |
| ADD-008 | Select Route | Beta, Logbook or marking flows | No | Yes | Choose the target route | Continue | Route search results | Route not found | Cached recent routes; contribution requires connection | MVP iPhone sheet |
| ADD-009 | Select Gym and Wall Zone | Add New Route | No | Yes | Set route location context | Continue | Gyms and existing wall zones | No wall zones available; contribution prompt with Not Now | Cached choices; submit requires connection | MVP iPhone sheet |
| ADD-010 | Contribution Confirmation | Public contribution flows | No | Yes | Explain exactly what becomes public | Publish | Contribution summary and visibility | Not applicable | Requires connection | MVP iPhone sheet |
| ADD-011 | Contribution Success | Public contribution flows | No | Yes | Confirm publication | View Contribution | Published record | Not applicable | Shows confirmed server result | MVP iPhone sheet |
| ADD-012 | Contribution Error | Public contribution flows | No | Yes | Explain a failed publication safely | Try Again | Error and retained draft | Not applicable | Retain local draft | MVP iPhone sheet |
| LOG-001 | Logbook Dashboard | Logbook tab | No | Yes | Review private climbing activity | Open a status or record | Private records and statistics | No private records yet | Cached; new records queue | MVP iPhone |
| LOG-002 | Projects | Logbook Dashboard or Home | No | Yes | Review private Project routes | Open Project Detail | Private Projects | No Projects yet | Cached; updates queue | MVP iPhone |
| LOG-003 | Wants to Try | Logbook Dashboard | No | Yes | Review saved future attempts | Open Record Detail | Private Want to Try records | No routes saved | Cached; updates queue | MVP iPhone |
| LOG-004 | Projecting | Logbook Dashboard | No | Yes | Review active attempts | Open Record Detail | Private Projecting records | No active Projects | Cached; updates queue | MVP iPhone |
| LOG-005 | Sent | Logbook Dashboard | No | Yes | Review completed routes | Open Record Detail | Private Sent records | No sends recorded | Cached; updates queue | MVP iPhone |
| LOG-006 | Flash | Logbook Dashboard | No | Yes | Review manually recorded flashes | Open Record Detail | Private Flash records | No flashes recorded | Cached; updates queue | MVP iPhone |
| LOG-007 | Record Detail | Logbook lists or Home | No | Yes | Review and edit one private record | Save Changes | State, date, attempts, note and predicted grade | Route historical/unavailable state | Cached; updates queue | MVP iPhone |
| LOG-008 | Statistics | Logbook Dashboard | No | Yes | Summarise private climbing records | Inspect distribution | Private aggregate data | Insufficient records | Cached local aggregate | MVP iPhone |
| LOG-009 | Export Logbook | Account Data or Logbook | No | Yes | Export private records | Create Export | Private Logbook data | No records to export | Local export may use cached records | MVP iPhone sheet |
| PROFILE-001 | Profile | Profile tab | Public subset | Yes | Manage identity and settings | Edit Profile | Profile and account state | Guest sign-in prompt | Cached public profile | MVP iPhone |
| PROFILE-002 | Edit Profile | Profile | No | Yes | Edit public and optional matching fields | Save | Username and optional fields | Not applicable | Draft locally; save requires connection | MVP iPhone |
| PROFILE-003 | Frequent Gym | Profile | No | Yes | Choose personal gym shortcut | Save Gym | Gym directory | No gym selected | Cached selection | MVP iPhone sheet |
| PROFILE-004 | Following | Profile | No | Yes | Manage beta-only follow relationships | Unfollow or open profile | Followed users | Not following anyone | Cached list; changes require connection | MVP iPhone |
| PROFILE-005 | Trusted Contributor Status | Profile | No | Yes | Explain permanent trust badge progress/status | None | Valid Helpful count and badge | Not yet earned | Cached status | MVP iPhone |
| PROFILE-006 | Notification Settings | Profile | No | Yes | Control four notification categories | Save Settings | Category preferences and iOS state | Not applicable | Local settings available | MVP iPhone |
| PROFILE-007 | Blocked Accounts | Profile | No | Yes | Review and unblock accounts | Unblock | Block list | No blocked accounts | Cached list; changes require connection | MVP iPhone |
| PROFILE-008 | Help Centre | Profile | Yes | Yes | Provide support information | Contact Support | Help content | Help unavailable | Cached articles where available | MVP iPhone |
| PROFILE-009 | In-App Feedback | Profile | Yes | Yes | Submit issue or suggestion safely | Send Feedback | Message and optional safe metadata | Not applicable | Retain draft; send requires connection | MVP iPhone sheet |
| PROFILE-010 | Safety Information | Profile or beta acknowledgements | Yes | Yes | Explain climbing and beta safety | Continue | Policy content | Content unavailable | Bundled or cached | MVP iPhone |
| PROFILE-011 | Community Guidelines | Profile | Yes | Yes | Explain contribution conduct | None | Policy content | Content unavailable | Bundled or cached | MVP iPhone |
| PROFILE-012 | Privacy Policy | Profile | Yes | Yes | Explain data practices | None | Policy content | Content unavailable | Bundled or cached | MVP iPhone |
| PROFILE-013 | Terms of Use | Profile | Yes | Yes | Explain product terms | None | Policy content | Content unavailable | Bundled or cached | MVP iPhone |
| PROFILE-014 | Copyright and Takedown Policy | Profile | Yes | Yes | Explain external-source rights process | Request Removal | Policy content | Content unavailable | Read cached; request requires connection | MVP iPhone |
| PROFILE-015 | Account Data | Profile | No | Yes | Access export and deletion controls | Choose action | Account state | Not applicable | Account changes require connection | MVP iPhone |
| PROFILE-016 | Delete Account | Account Data | No | Yes | Permanently delete the account after confirmation | Delete Account | Confirmed identity | Not applicable | Requires connection | MVP iPhone full-screen cover |
| PROFILE-017 | Sign Out | Profile | No | Yes | End the local signed-in session | Sign Out | Account state | Not applicable | Available locally | MVP iPhone confirmation |
| AUTH-001 | Authentication Gate | Protected action | Yes | Signed out only | Explain why an account is needed and preserve intent | Choose Sign-In Method | Pending destination and action | Not applicable | Requires connection | MVP iPhone full-screen cover |
| AUTH-002 | Sign in with Apple | Authentication Gate | Yes | Signed out only | Authenticate with Apple | Continue with Apple | Provider response | Provider unavailable | Requires connection | MVP iPhone system flow |
| AUTH-003 | Sign in with Google | Authentication Gate | Yes | Signed out only | Authenticate with Google | Continue with Google | Provider response | Provider unavailable | Requires connection | MVP iPhone system flow |
| AUTH-004 | 16+ Self-Declaration | First account creation | Yes | New account | Confirm MVP age eligibility | Confirm 16 or Older | User declaration | Not applicable | Requires connection | MVP iPhone sheet |
| AUTH-005 | Username Setup | First sign-in | No | New account | Set the required public username | Save Username | Available username | Not applicable | Requires connection | MVP iPhone |
| AUTH-006 | Optional Profile Completion | Username Setup or Profile prompt | No | Yes | Add optional height and arm span for beta matching | Save or Not Now | Optional profile fields and visibility | Not applicable | Skip available; save requires connection | MVP iPhone sheet |
| AUTH-007 | Authentication Error | Authentication flow | Yes | Signed out only | Explain recoverable authentication failure | Try Again | Provider error | Not applicable | Requires connection | MVP iPhone |
| VGYM-001 | Verified Gym Tools | Profile or owned Gym Detail | No | Conditional | Enter official gym maintenance tools | Choose Tool | Verified gym role and gym | No verified gym association | Requires connection | MVP iPhone |
| VGYM-002 | Edit Gym Information | Verified Gym Tools | No | Conditional | Maintain hours, facilities and contact details | Save Changes | Owned gym data | Data unavailable | Requires connection | MVP iPhone |
| VGYM-003 | Manage Wall Zones | Verified Gym Tools | No | Conditional | Maintain zone names, order, attributes and availability | Save Changes | Owned wall zones | No zones; add official zone | Requires connection | MVP iPhone |
| VGYM-004 | Manage Resets | Verified Gym Tools | No | Conditional | Publish official reset information | Publish Reset | Owned zone and reset data | No reset history | Requires connection | MVP iPhone |
| VGYM-005 | Manage Gym Routes | Verified Gym Tools | No | Conditional | Maintain official routes and content | Open or Add Route | Owned gym routes | No routes | Requires connection | MVP iPhone |
| ADMIN-WEB-001 | Administrator Web Portal | Separate authenticated web product | No | Administrator only | Moderate, merge, restore, manage claims and audit actions | Open Admin Module | Administrator role and server data | Queue-specific empty states | Requires connection | Separate admin surface |

## 4. Explicitly excluded from the MVP page tree

- Direct video upload, hosted video storage and video-file processing.
- A 2D or interactive wall map, floor plan or clickable wall hotspot view.
- Activity, Feed, Messages, Groups, Leaderboard, Stories or livestream destinations.
- Administrator modules inside the iPhone five-tab navigation.
- Automatic AI route recognition, AR navigation and advanced training analytics.

## 5. Next-stage implementation-ready page list

The following order provides implementable vertical slices without expanding the frozen MVP. It is a delivery sequence, not a scope change.

### Slice A — Entry and guest discovery

- `ENTRY-001` **Launch**
- `ENTRY-002` **Find Gyms Onboarding**
- `ENTRY-003` **Find Beta Onboarding**
- `ENTRY-004` **Record Climbing Onboarding**
- `MAP-001` **Nationwide Gym Map** shell and states
- `MAP-002` **Location Permission Context**
- `MAP-003` **Map Filters**
- `MAP-004` **Search**
- `MAP-005` **Gym Preview Card**

### Slice B — Gym-to-route discovery

- `GYM-001` **Gym Detail**
- `GYM-002` **Wall Zone Directory**
- `GYM-003` **Wall Zone Detail**
- `GYM-004` **Route List**
- `GYM-005` **Latest Reset**
- `GYM-006` **Hard/Soft Index**
- `GYM-007` **Opening Information**
- `GYM-008` **Facilities**
- `ROUTE-001` **Route Detail**
- `ROUTE-002` **Route Photo**
- `ROUTE-006` **Archived Route State**

### Slice C — Protected beta journey

- `BETA-001` **Beta Links**
- `BETA-002` **Reveal Beta**
- `AUTH-001` **Authentication Gate**
- `AUTH-002` **Sign in with Apple**
- `AUTH-003` **Sign in with Google**
- `AUTH-004` **16+ Self-Declaration**
- `AUTH-005` **Username Setup**
- `AUTH-006` **Optional Profile Completion**
- `AUTH-007` **Authentication Error**
- `SAFE-001` **Reveal Beta Safety Acknowledgement**

### Slice D — Private climbing records

- `ROUTE-003` **Quick Logbook State**
- `LOG-001` **Logbook Dashboard**
- `LOG-002` **Projects**
- `LOG-003` **Wants to Try**
- `LOG-004` **Projecting**
- `LOG-005` **Sent**
- `LOG-006` **Flash**
- `LOG-007` **Record Detail**
- `LOG-008` **Statistics**
- `LOG-009` **Export Logbook**
- `HOME-001` **Home** and its practical dashboard modules

### Slice E — Contribution flows

- `ADD-001` **Add Action Menu**
- `ADD-002` **Publish Beta Link**
- `ADD-003` **Add New Route**
- `ADD-004` **Record Completed Route**
- `ADD-005` **Identify or Mark Route**
- `ADD-006` **Suspected Duplicate Route**
- `ADD-007` **Route Photo and Hold Marking**
- `ADD-008` **Select Route**
- `ADD-009` **Select Gym and Wall Zone**
- `ADD-010` **Contribution Confirmation**
- `ADD-011` **Contribution Success**
- `ADD-012` **Contribution Error**
- `SAFE-002` **Publish Beta Safety Acknowledgement**
- `GRADE-001` **Community V Grade**
- `ROUTE-004` **Comments**
- `ROUTE-005` **Corrections and Reports**

### Slice F — Identity, settings and official gym tools

- `PROFILE-001` through `PROFILE-017`
- `GYM-009` **Claim This Gym**
- `VGYM-001` through `VGYM-005`

The separate `ADMIN-WEB-001` **Administrator Web Portal** is not an iPhone implementation item and remains outside this Xcode project.
