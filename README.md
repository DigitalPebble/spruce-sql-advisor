# SPRUCE SQL Advisor

A [Claude skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
that grounds Claude in accurate knowledge for writing and optimising SQL queries against
AWS CUR 2.0 data enriched with [SPRUCE](https://github.com/DigitalPebble/spruce) greenops
columns.

When loaded, the skill makes Claude reliably accurate on:

- CUR 2.0 schema details (column naming, nested arrays, conditional columns)
- `BILLING_PERIOD` partitioning semantics
- Engine-specific syntax for **Athena** and **DuckDB**
- All SPRUCE column meanings and units (carbon, electricity, water)

## Install

1. Download the latest `spruce-sql-advisor.skill` from the
   [Releases page](../../releases).
2. In Claude.ai, go to [**Settings → Customize → Skills**](https://claude.ai/customize/skills), click on +, **Create skills** and **Upload a skill**.
3. Start a new chat and ask a CUR 2.0 SQL question — Claude will load the skill
   automatically. Alternatively, call it explicitely by typing `/spruce-sql-advisor` in a new chat window.

## Documentation

Full documentation, including example prompts and screenshots, is at
**[digitalpebble.github.io/spruce-sql-advisor](https://digitalpebble.github.io/spruce-sql-advisor/)**.

## Repository layout

```
spruce-sql-advisor/             ← repo root
├── spruce-sql-advisor/         ← the skill itself (gets packaged into .skill)
│   ├── SKILL.md
│   ├── LICENSE, NOTICE
│   └── references/
├── docs/                       ← GitHub Pages site
├── .github/workflows/          ← CI: validate + release
├── README.md, LICENSE, NOTICE
```

The skill folder name is repeated by design: `package_skill.py` uses the folder name
both as the artefact name (`spruce-sql-advisor.skill`) and as the top-level path inside
the zip, and that name must match the skill's `name` frontmatter field.

## Building from source

```bash
git clone https://github.com/DigitalPebble/spruce-sql-advisor
cd spruce-sql-advisor

# Fetch Anthropic's packaging script
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/anthropics/skills _anthropic_skills
git -C _anthropic_skills sparse-checkout set skills/skill-creator/scripts

PYTHONPATH=_anthropic_skills/skills/skill-creator \
  python3 -m scripts.package_skill ./spruce-sql-advisor .
```

## Licence

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

## Related

- [SPRUCE](https://github.com/DigitalPebble/spruce) — the open-source GreenOps platform
  this skill is designed to work with.
- [DigitalPebble](https://digitalpebble.com) — green software consultancy.
