> **Deprecated — folded into the `github` skill.** Use `/publish-github` from the `github`
> bundle (`claude/skills/github/`), which runs this workflow under the parent skill's
> minimal-output contract. This file is retained for history only.

Use the Skill tool to invoke the `publish-github` skill, then follow it exactly.

Arguments (optional): $ARGUMENTS

- If the arguments contain "public" or "private", pass that as the desired visibility.
- Otherwise, the skill will ask the user to choose via AskUserQuestion.

Start at Phase 1 and work through all phases in order.
