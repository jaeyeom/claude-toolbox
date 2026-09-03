## Summary

<!-- Which plugin (if any), new vs change, what changed and why. Reviewers
     should understand the purpose from this section alone. Use bullets.
     Link the issue if there is one. -->

Resolves #

## Demo

<!-- Optional. Skill pressure-test, hook before/after, or slash-command
     output. Delete this section if it would not help a reviewer. -->

## Test plan

<!-- Fill in what you actually ran. Do not check an item unless you ran that
     command and looked at the output. Delete subsections that do not apply.

     `make check` already covers Biome, marketplace↔directory sync, name and
     version consistency, SKILL.md description frontmatter, and hook
     executability. Do not restate those. Add the checks CI cannot do. -->

- [ ] `make check` is green

### Skill (delete if this PR does not change a skill)

<!-- Reading SKILL.md is not enough. Name the prompt you used. -->

- [ ] After `/plugin install <name>` (or a local install), a prompt that
      should trigger the skill — the agent followed the new guidance

### Hook (delete if this PR does not change a hook)

- [ ] The hook fires on the matcher in a real Claude Code session
- [ ] Uses `${CLAUDE_PLUGIN_ROOT}` (not `$CLAUDE_PLUGIN_DIR`)

### New plugin (delete if this is not a new marketplace plugin)

- [ ] `/plugin install <name>` matches `plugin.json` name/version
- [ ] Listed in the root README plugin directory (and a bundle guide if it
      belongs in one)

## Reviewer notes

<!-- Optional. Semver (did this need a bump?), description-trigger wording,
     or other decisions you want a second opinion on. Delete if none. -->
