# BlocLens Core User Flows

## Flow conventions

- Each flow is intentionally short and vertical so it remains readable in product and engineering review.
- A solid arrow represents a user or system transition.
- Decision nodes describe PRD-defined conditions, not implementation details.
- Public beta always means an attributed external public link. No video file is transferred to BlocLens.

## Flow 1 — First launch and guest map entry

```mermaid
flowchart TD
    A[Launch] --> B{Onboarding completed?}
    B -- No --> C[Find Gyms Onboarding]
    C --> D[Find Beta Onboarding]
    D --> E[Record Climbing Onboarding]
    E --> F[Nationwide Gym Map]
    B -- Yes --> F
    F --> G[Browse Gym]
    F --> H{User selects Nearby Gyms or location control?}
    H -- No --> G
    H -- Yes --> I[Location Permission Context]
    I --> J[iOS Location Permission]
    J --> F
```

Onboarding is three pages and skippable. The guest arrives at the map without an upfront login wall. Location is never requested during launch or onboarding; it is requested only after the user explicitly selects **Nearby Gyms** or the map location control.

## Flow 2 — Find a target route within 60 seconds

```mermaid
flowchart TD
    A[Map or Search] --> B[Gym Preview Card]
    B --> C[Gym Detail]
    C --> D[Wall Zone Directory]
    D --> E[Wall Zone Detail]
    E --> F[Route List]
    F --> G[Route Detail]
```

The path prioritises the PRD success threshold of 60 seconds or less from gym or zone entry to the target route. The wall-zone directory is a structured list of names, location descriptions, wall attributes, reset information and counts. There is no 2D wall map, floor plan or clickable hotspot step.

## Flow 3 — Reveal beta with authentication gate

```mermaid
flowchart TD
    A[Guest selects Reveal Beta] --> B[Store requested Route Detail and beta link]
    B --> C[Authentication Gate]
    C --> D{Sign-in method}
    D -- Apple --> E[Sign in with Apple]
    D -- Google --> F[Sign in with Google]
    E --> G[16+ Self-Declaration]
    F --> G
    G --> H[Username Setup]
    H --> I{First beta reveal?}
    I -- Yes --> J[Reveal Beta Safety Acknowledgement]
    I -- No --> K[Restore requested Route Detail]
    J --> K
    K --> L[Reveal external beta]
    L --> M{Supported inline playback?}
    M -- Yes --> N[Play inline with source attribution]
    M -- No --> O[Open source platform]
```

Authentication is contextual. After successful authentication, age declaration and username setup, navigation restores the exact route and beta intent rather than sending the user to Home. The source platform, original author and original post remain visible.

## Flow 4 — Quick Logbook save

```mermaid
flowchart TD
    A[Route Detail] --> B{Select private Logbook state}
    B --> C[Want to Try]
    B --> D[Projecting]
    B --> E[Sent]
    B --> F[Flash]
    C --> G[Save immediately]
    D --> G
    E --> G
    F --> G
    G --> H[Optional details sheet]
    H --> I[Attempts, private note and predicted V Grade]
    I --> J{Online?}
    J -- Yes --> K[Synchronise]
    J -- No --> L[Queue private record locally]
    L --> M[Synchronise when connectivity returns]
```

The selected state saves before optional details are requested. **Flash** is always available as a manual choice. Every record is private by default. A predicted V Grade stored in the private record is not a public community vote unless the user performs a separate explicit contribution action.

## Flow 5 — Add a new route

```mermaid
flowchart TD
    A[Add Action Menu] --> B[Add New Route]
    B --> C[Select Gym]
    C --> D[Select existing Wall Zone]
    D --> E[Enter Colour or Tag]
    E --> F[Optional Photo]
    F --> G[Check suspected duplicates]
    G --> H{Suspected duplicate?}
    H -- Yes --> I[Suspected Duplicate Route]
    I --> J{User choice}
    J -- Use existing --> K[Existing Route Detail]
    J -- Continue --> L[Contribution Confirmation]
    H -- No --> L
    L --> M[Publish route immediately]
    M --> N[Public Route Detail]
    N --> O{Three distinct corrections?}
    O -- Yes --> P[Temporarily unpublish and create admin review case]
    O -- No --> N
```

Gym, an existing named wall zone, and colour or tag are the only required creation fields. A photo is optional. Duplicate detection informs rather than blocks: the user can select a likely existing route or explicitly continue.

## Flow 6 — Publish an external beta link

```mermaid
flowchart TD
    A[Add Action Menu] --> B[Publish Beta Link]
    B --> C[Select Route]
    C --> D[Paste public URL]
    D --> E{Supported platform?}
    E -- Yes --> F[Prepare permitted inline playback metadata]
    E -- No --> G[Prepare source-platform handoff]
    F --> H[Enter original author and confirm source attribution]
    G --> H
    H --> I[Select fixed beta tags]
    I --> J{First beta publish?}
    J -- Yes --> K[Publish Beta Safety Acknowledgement]
    J -- No --> L[Contribution Confirmation]
    K --> L
    L --> M[Publish external beta link]
```

Fixed tags are **Full Solution**, **Crux**, **Static**, **Dynamic**, **Short-person Beta**, and **Tall/Long-reach Beta**. Unsupported platforms open at the source. Publication stores link metadata, attribution, tags and moderation state only; no video file transfer to BlocLens occurs.

## Flow 7 — Route photo and hold marking

```mermaid
flowchart TD
    A[Identify or Mark Route] --> B{Image source}
    B -- Camera --> C[Capture image]
    B -- Photo Library --> D[Select image]
    C --> E[Select every route hold]
    D --> E
    E --> F[Mark Start]
    F --> G[Mark Finish]
    G --> H[Review route membership]
    H --> I{All required marks present?}
    I -- No --> E
    I -- Yes --> J[Submit]
```

Hold marking records route membership only. Start and Finish are separately identified. The MVP does not require move order and does not perform automatic AI route recognition.

## Flow 8 — Community V Grade

```mermaid
flowchart TD
    A[Route Detail] --> B{Attempt recorded?}
    B -- No --> C[Record an attempt in private Logbook]
    C --> D[Submit predicted V Grade as explicit public vote]
    B -- Yes --> D
    D --> E[Store one editable vote for this user and route]
    E --> F{At least three distinct valid votes?}
    F -- No --> G[Do not display community prediction]
    F -- Yes --> H[Display median community V Grade]
    H --> I[Recalculate eligible gym bands]
    I --> J[V0–V2, V3–V5 and V6+ Hard/Soft Index]
```

The public community result is the median, never the arithmetic mean. Official grades and community predictions remain visually distinct. Only routes meeting the three-vote threshold participate in gym hard/soft calculations.

## Flow 9 — Reset and archive lifecycle

```mermaid
flowchart TD
    A[Reset information received] --> B{Verified Gym official reset?}
    B -- Yes --> C[Apply reset immediately]
    B -- No --> D{Three distinct users confirm same zone reset?}
    D -- Yes --> E[Apply community-confirmed reset]
    D -- No --> F[Keep existing state]
    C --> G[Estimate archive date when needed]
    E --> G
    G --> H[Label date as approximate]
    H --> I{Three distinct removal reports and date reached?}
    I -- No --> J[Keep route current]
    I -- Yes --> K[Archive route]
    K --> L[Preserve beta links, grades, comments and Logbook history]
    L --> M{Administrator restoration?}
    M -- Yes --> N[Restore route with audit record]
    M -- No --> O[Remain read-only historical route]
```

Official reset data has priority. Estimated dates are always labelled as estimates. Archive does not erase route history or the user's private Logbook references.

## Flow 10 — Reporting and moderation

```mermaid
flowchart TD
    A[User submits report] --> B{Severe category?}
    B -- No --> C{Three distinct reports?}
    C -- No --> D[Keep public and retain report]
    C -- Yes --> E[Temporarily hide content]
    B -- Yes --> E
    E --> F[Create prioritised admin review case]
    F --> G{Administrator decision}
    G -- Restore --> H[Restore content]
    G -- Violation --> I[Warning, restriction or ban]
    H --> J[Record reason and audit trail]
    I --> J
```

Nudity, harassment, violence or child-privacy reports use the severe one-report temporary-hide rule. Other beta and comment reports require three distinct accounts. Severe cases may skip earlier enforcement steps, but every decision records a reason and audit trail.

## Flow 11 — Voluntary contribution prompt

```mermaid
flowchart TD
    A[Contextual contribution opportunity] --> B[Explain exactly what data is shared]
    B --> C[Explain public or anonymous visibility]
    C --> D[Explain the practical climbing benefit]
    D --> E{User choice}
    E -- Share or Add Details --> F[Explicit contribution flow]
    E -- Not Now --> G[Dismiss without losing core functionality]
    F --> H[Apply frequency cap]
    G --> H
    H --> I[Respect dismissal before another prompt]
```

Prompts may appear for empty wall zones, missing route details, post-climb opportunities, reset confirmation, broken beta links or optional profile fields. They never use guilt, urgency or preselected consent. They never convert private Logbook data into public data.

## Flow 12 — Account deletion and Logbook export

```mermaid
flowchart TD
    A[Account Data] --> B{User choice}
    B -- Export Logbook --> C[Confirm identity]
    C --> D[Create Logbook export]
    D --> A
    B -- Delete Account --> E[Confirm identity]
    E --> F[Explain account deletion consequences]
    F --> G{Explicit confirmation?}
    G -- No --> A
    G -- Yes --> H[Delete account]
    H --> I[Sign out]
    I --> J[Remove local account data]
    J --> K[Return to guest map entry]
```

Export and deletion are separate controls. The deletion explanation must remain limited to confirmed product consequences. This specification does not invent legal retention periods or exceptions that are absent from the PRD.
