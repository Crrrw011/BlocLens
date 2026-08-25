# BlocLens Access Matrix

## 1. Role definitions

- **Guest** — an unauthenticated person. Can browse practical gym and route information but cannot reveal beta or perform account actions.
- **Signed-in User** — an eligible user aged 16 or older with a completed username.
- **Trusted Contributor** — a Signed-in User who has accumulated 67 valid Helpful reactions. The permanent badge does not add moderation authority.
- **Verified Gym** — an official account authorised to manage its own gym information, wall zones, resets, routes and official content.
- **Administrator** — an operational role whose moderation and data-governance work occurs primarily in the separate Administrator web portal.

## 2. Permission legend

- **Allow** — the role can perform the capability under normal MVP rules.
- **Read** — the role can view the resulting public information but cannot perform the write action.
- **Gate** — authentication and account eligibility are required before continuing.
- **Own gym** — allowed only for gyms assigned to the verified account.
- **Web portal** — performed primarily in the separate Administrator web portal, not through the iPhone tab bar.
- **No** — not permitted.

## 3. Capability matrix

| Capability | Guest | Signed-in User | Trusted Contributor | Verified Gym | Administrator | Governing condition |
|---|---|---|---|---|---|---|
| View map | Allow | Allow | Allow | Allow | Allow | Nationwide commercial bouldering gyms are guest-accessible. |
| View gym | Allow | Allow | Allow | Allow | Allow | Includes operating information, facilities and named wall zones. |
| View wall-zone list | Allow | Allow | Allow | Allow | Allow | Navigation is list-based; there is no 2D wall map. |
| View route | Allow | Allow | Allow | Allow | Allow | Public route information remains available without beta reveal. |
| Reveal beta | Gate | Allow | Allow | Allow | Allow | Guest must authenticate, complete 16+ declaration and username setup, then acknowledge first-reveal safety. |
| Add route | Gate | Allow | Allow | Allow | Web portal | Minimum fields are gym, existing wall zone, and colour or tag. |
| Publish external beta link | Gate | Allow | Allow | Allow | Web portal | Public URL only, with attribution and fixed tags. No video file transfer exists. |
| Add route photo | Gate | Allow | Allow | Allow | Web portal | Photo may be contributed during route creation or later. |
| Mark holds | Gate | Allow | Allow | Allow | Web portal | Select all route holds and mark Start and Finish; no move sequence is required. |
| Vote community V Grade | Gate | Allow | Allow | Allow as a user | Web portal oversight | The voter must first record an attempt; one editable vote per user per route. |
| Comment | Gate | Allow | Allow | Allow | Web portal moderation | Flat comments only, maximum 200 characters. |
| Report | Gate | Allow | Allow | Allow | Web portal review | Ordinary reports use the three-account threshold; severe reports use the one-report rule. |
| Submit correction | Gate | Allow | Allow | Allow | Web portal review | Three distinct ordinary corrections temporarily unpublish a route. |
| Save Logbook entry | Gate | Allow | Allow | Allow as a user | Allow as a user | Private by default; offline writes queue for later synchronisation. |
| View own Logbook | No | Allow | Allow | Allow as a user | Allow as a user | Never public in the MVP. |
| Export own Logbook | No | Allow | Allow | Allow as a user | Allow as a user | Export is restricted to the account owner. |
| Follow user | Gate | Allow | Allow | Allow as a user | Allow as a user | Following exists only for new-beta notifications. |
| Block user | Gate | Allow | Allow | Allow as a user | Allow as a user | Hides that account's beta, comments and profile and cancels following. |
| Manage own public profile | Gate | Allow | Allow | Allow | Allow | Username required; height and arm span are optional public matching fields when supplied. |
| Manage notification categories | Gate | Allow | Allow | Allow | Allow | Each of the four MVP categories has an independent control. |
| Manage gym operating data | No | Submit correction | Submit correction | Own gym | Web portal | Verified Gym can edit hours, facilities and contact details for its own gym. |
| Create, rename or reorder wall zones | No | No | No | Own gym | Web portal | Only Verified Gym and Administrator roles can manage zone structure. |
| Publish official reset | No | Confirm reset | Confirm reset | Own gym | Web portal | Official reset takes effect immediately; otherwise three distinct users confirm. |
| Maintain official gym routes | No | Contribute public route | Contribute public route | Own gym | Web portal | Verified Gym content displays official status where applicable. |
| Edit community grade | No | Own vote only | Own vote only | Own vote only | No direct edit | Verified Gym and Administrator roles cannot rewrite the community median or hard/soft calculations. Invalid votes may be handled through governed moderation, not grade editing. |
| Moderate content | No | No | No | No | Web portal | Trusted Contributor status never grants moderation authority. |
| Merge duplicate routes | No | Propose merge | Propose merge | Propose merge | Web portal | Only an Administrator confirms a merge and chooses the canonical route. |
| Restore archived or hidden content | No | No | No | No | Web portal | Administrator restoration preserves attribution and history. |
| Manage gym claims | No | Submit claim | Submit claim | View own status | Web portal | Verification uses domain email where possible or manual review. |
| Apply warnings, restrictions or bans | No | No | No | No | Web portal | Every enforcement action requires a reason and audit record. |
| View moderation audit trail | No | No | No | No | Web portal | Operational administrator capability only. |
| Delete own account | No | Allow | Allow | Allow | Allow as account owner | Requires identity confirmation and explicit irreversible confirmation. |

## 4. Cross-cutting access rules

1. A protected action stores its intended destination before presenting **Authentication Gate**.
2. Guests are returned to the originally requested route or action after successful authentication and setup.
3. Community V Grade voting remains attempt-gated for every non-administrator role. Administrative status is not a substitute for an attempt.
4. Verified Gym accounts cannot alter community grades, Helpful signals or hard/soft index calculations.
5. Trusted Contributor is a quality badge, not a permission escalation for moderation.
6. Private Logbook data is visible only to its owner and never becomes a public route, grade, photo or beta contribution automatically.
7. The Administrator web portal is a separate product surface. It is not a sixth iPhone tab and is not linked as a general user destination.
8. No role has permission to upload a video file to BlocLens. The only MVP beta contribution is a public external link.
