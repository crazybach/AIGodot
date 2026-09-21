# Quests / field journal

Runtime map for the staged quest implementation. Content lives in `data/quests.json`; NPC voices and topic actions remain in `data/npc_rooftop_content.json`.

## Player flow

**J** or **Journal** opens the journal. Filter All / Main / Side / Completed, select a quest, then Track This Quest or Stop Tracking. One active quest appears on the left HUD; other accepted quests continue progressing. Current stages appear first in details, followed by locked stages and completed history. Requirements, hand-in NPCs, acquisition rules and rewards are visible. Escape/Android Back closes the journal. Touch input uses the same buttons and scrolling.

Ten sample quests include three main quests and seven side quests:

| Quest | Acceptance | Progress / completion |
| --- | --- | --- |
| Above the Mist (main) | Automatic on a new game | Reach rooftop A, then talk to Imani; automatic reward. |
| Emergency Power (main) | Ask Imani after Above the Mist | Two batteries AND one water; hand in to Imani. |
| An Echo from the Breach (main) | After Emergency Power, ask Asha about her model | Visit ground-floor T, then defeat two creatures AND deliver a cracked lens to Asha. |
| Thin the Mist (side) | Ask Mateo | Scout ground-floor M, then defeat three creatures AND hold six 9mm rounds, then return and report to Mateo. |
| A Pantry in the Mist (side) | Discover ground-floor M | Hold two cans AND two water; automatic reward, retain supplies. Existing inventory counts. |
| The Roof Clinic (side) | Ask Dr. Park | Deliver one medkit AND one water. |
| Voices on the Roofs (side) | Ask Grace | Meet five distinct survivors; report to Grace. Prior meetings count. |
| One More Crossing (side) | Ask Tomas | Deliver a portable ladder. |
| Signal Fire (side) | Ask Malik | Deliver an emergency flare. |
| Supper for Two (side) | Ask Nia | Deliver two cans AND one water. |

## Architecture

| Owner | Responsibility |
| --- | --- |
| `QuestDefinitions.gd` | Validates and normalizes immutable authored definitions: IDs, counts, objective types, item IDs, acceptance/completion modes and acyclic dependencies. |
| `NPCContentDatabase.gd` | Loads NPC and quest JSON separately; rejects duplicate quest IDs and malformed definitions. |
| `QuestLogComponent.gd` | Per-character states, stage states, event baselines, inventory requirements, hand-ins, one-time scrip rewards and tracking. No UI dependency. |
| `Player.gd` | Binds backpack/wallet. On `quest_completed`, grants configured reward XP (fallback: skill table's quest XP). |
| `GameManager.gd` | Reports kills and building/layer entry; applies relationship rewards to the giver and player; updates story progress. |
| `DialoguePanel.gd` | Passes the current NPC ID to acceptance/hand-in calls. Topic `quest_event` emits a generic event. Applies topic relationship effects separately. |
| `NPCDialogueComponent.gd` | Offers all eligible quests/hand-ins for the speaker, not only its legacy `quest_id`. That field selects custom authored dialogue text. |
| `QuestLocationTrigger.gd` | Editor-authored Area2D: set `location_id`, add CollisionShape2D; Player entry calls `arrive`. |
| `QuestJournal.gd`, `QuestTrackerPanel.gd` | Full details and compact selected-quest display. Only call public quest APIs. |

## Content schema

```json
{
  "id": "supply_route",
  "title": "Supply Route",
  "description": "Scout the yard, then return with supplies.",
  "category": "side",
  "giver_id": "imani_okafor",
  "giver_name": "Imani Okafor",
  "location_hint": "Ashdown rooftop (A)",
  "acceptance": {"mode": "talk", "npc_id": "imani_okafor", "requires": []},
  "completion": {"mode": "talk", "npc_id": "imani_okafor", "npc_name": "Imani Okafor"},
  "rewards": {"scrip": 35, "xp": 150, "relationship": 8},
  "stages": [
    {"id": "scout", "title": "Scout the yard", "objectives": [
      {"type": "arrival", "location": "ground:A", "amount": 1}
    ]},
    {"id": "supplies", "title": "Bring supplies", "requires": ["scout"], "objectives": [
      {"type": "kill", "amount": 3},
      {"type": "item", "item_id": "battery_cell", "amount": 2, "consume": true}
    ]}
  ]
}
```

- `category`: `main` / `side`; `hidden: true` hides undiscovered quests from the journal.
- Acceptance `requires` contains **quest IDs**, all of which must be completed. Modes: `manual` (journal), `talk` + `npc_id` (dialogue answer), `arrival` + `location` (entry), `event` + `event_id` (arbitrary world/topic event), `auto` (prerequisites satisfied). Display fields: `npc_name`, `location_name`, `hint`.
- Stage `requires` contains **stage IDs** from the same quest. No dependencies means a root stage. All dependencies must complete. Parallel stages and joins are supported; references/cycles are validated.
- All objectives in a stage are AND requirements. Objective types: `item` + `item_id`; `kill` (default `mist_kill`, optional `event_id`); `event` + `event_id`; `talk` + `npc_id`; `arrival` + `location`; `meet_npcs`. Optional `id` defaults to its stable array index; `amount` defaults to 1; `label` overrides display text.
- Nonterminal stages default to automatic completion. Terminal stages inherit quest `completion`. Each stage may override completion with `auto` or `talk` + `npc_id`. A talk stage waits for an explicit hand-in response even when its requirements are met. Multiple terminal branches can require different NPCs. Final quest rewards wait until **every stage** is completed.
- Item objectives read the bound backpack, not equipment or NPC containers. `consume` defaults true; items are removed when that stage completes. For automatic possession objectives use `consume: false`. Item removal before hand-in revokes readiness. Duplicate consuming objectives require the aggregate quantity.
- Event objectives count only events after stage activation by default. `lifetime: true` counts prior events; `meet_npcs` defaults to lifetime, and lifetime arrival checks a visited-location set (use amount 1). Item possession always checks current inventory. Locked stages cannot accidentally progress.

## APIs and invariants

Create QuestLogComponent, `bind_owner(backpack, wallet)`, then `setup(definitions)` before play. Setup validates the table before replacement; it is an initialization API, not a live content migration API.

- `accept(id, source="manual", target="")` and `acceptance_reason(...)` enforce acquisition mode, giver/trigger and quest prerequisites.
- `record_event(id, amount=1)`, `arrive(location)`, `meet_character(npc_id)` update all accepted quests. Triggering events count for quests accepted by that same event, but never spill into newly unlocked later stages.
- `can_turn_in(id, npc_id)` / `turn_in(id, npc_id)` enforce ready objectives and the stage's correct NPC. A turn-in may advance an intermediate stage without completing the quest. The UI checks resulting quest state before displaying completion text.
- `set_tracked(id)` accepts one active quest or an empty ID to untrack. Tracking never controls progress. Completion clears that selection; accepting a quest when none is tracked selects it.
- Read-only presentation helpers: `active_stages`, `stage_state`, `objective_value`, `objective_lines`, `objective_summary`, `completion_text`, `journal_ids`.
- Signals: `quest_changed(id,state)`, `quest_completed(id)`, `quest_progress`, `tracking_changed(id)`. Reward state is set before callbacks; duplicate rewards are rejected. Inventory-driven evaluation is deferred until after the container transaction finishes.
- `GameManager._update_quest_location()` emits entry events for layer IDs (`ground`, `roofs`) and building IDs (`ground:M`, `roofs:A`); outdoor areas use `<layer>:streets`. It uses the active layer's real building polygons, so crossing between roofs also counts. Arbitrary rooms/areas can use QuestLocationTrigger.
- Future crafting, investigation, switches, escort checkpoints: emit a named event and author an `event` objective/acceptance rule. A new objective algorithm belongs in `QuestDefinitions.OBJECTIVE_TYPES`, validation, `objective_value`, `objective_event` (if counted) and `objective_label`.

Current scope is session state, matching the existing world/quest lifecycle. No full-game persistence or quest failure/abandon/OR branches yet. A future save manager must store `states`, `stage_states` (including baselines), `event_counts`, `met_characters`, `visited_locations`, `tracked_quest`, inventory, wallet and skill XP together. Never restore completed states separately from paid rewards.

## References and validation

The [official Baldur's Gate 3 journal structure](https://docs.baldursgate3.game/index.php?title=Journal_Structure_Overview) informed categorized quests, stage history and current-objective emphasis. [Cyberpunk 2077 Update 2.0](https://www.cyberpunk.net/en/news/49060/update-2-0) describes category tabs and untracking from the journal. This implementation adapts those UI patterns to Ashdown; it does not reproduce either game's internal quest model or art.

Run `tests/quest_system_smoke.gd` headlessly: multiple objectives, past-event isolation, dependent/parallel stages, acquisition rules, auto/explicit completion, aggregate consumption, one-time rewards, real travel/dialogue hooks, untracked progression, journal selection and touch/Back routing. `tests/quest_journal_visual.gd` runs with the renderer, injects real mouse events, and captures `.godot_local/quest-*.png` at 1920×1080. Also run NPC dialogue, skill-tree and touch smoke suites when modifying integration points.
