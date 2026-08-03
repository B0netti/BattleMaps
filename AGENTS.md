# BattleMaps Development Instructions

## Project

BattleMaps is a World of Warcraft Retail PvP battlefield-map addon written
primarily in Lua. The user tests on the current Retail client and sometimes
on PTR.

## Working rules

- Inspect the relevant implementation before editing.
- For complex changes, present a plan before modifying files.
- Preserve existing behaviour unless the requested change requires otherwise.
- Prefer modifying the established implementation over adding duplicate systems.
- Search the full repository for related settings, defaults, migrations,
  previews, reset behaviour and test-mode behaviour.
- Do not invent Blizzard APIs or events.
- Treat protected functions, restricted values, combat lockdown and taint as
  important architectural constraints.
- Avoid hooking or modifying Blizzard map pins unless specifically required.
- Do not suppress Lua errors instead of fixing their cause.
- Treat uploaded SavedVariables files as diagnostic evidence only. Do not edit, overwrite, normalize, or include them in release packages. Fix invalid, missing, or outdated values through addon defaults, validation, or migration code instead.
- Preserve TOC load order unless a change is necessary and explained.
- Avoid unnecessary custom frameworks when an established included library
  already provides the required behaviour.
- Do not remove existing features merely to simplify implementation.

## Change procedure

1. Inspect all related files.
2. Explain the likely cause or proposed design.
3. Make the smallest coherent implementation.
4. Review the full diff for accidental changes.
5. Check Lua syntax and references across files.
6. Summarize changed files and required in-game tests.
7. Do not create a release ZIP until explicitly requested.

## Verification

Automated checks cannot replace testing inside World of Warcraft.

For each change, provide a focused test list covering:
- login and `/reload`
- options defaults and saved settings
- test mode
- live battleground behaviour where relevant
- combat lockdown and taint risk
- interaction with the Blizzard battlefield map
- ElvUI compatibility where relevant

## Packaging

When requested to package a release:
- include the addon folder at the ZIP root
- exclude `.git`, development notes, AGENTS.md, logs and temporary files
- verify the TOC version
- list the packaged files
- do not overwrite the last known-good release archive
- When preparing any release archive: do not leak the developer's IRL identity
 