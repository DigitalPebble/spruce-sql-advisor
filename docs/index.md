---
title: SPRUCE SQL Advisor
---

# SPRUCE SQL Advisor

A [Claude skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
that lets non-technical FinOps and GreenOps people write SQL queries against AWS CUR
(Cost and Usage Report) data — whether or not it has been enriched with
[SPRUCE](https://github.com/DigitalPebble/spruce) greenops columns (carbon, electricity,
water).

Just ask Claude in plain English; the skill handles the CUR 2.0 schema, engine-specific
syntax (Athena or DuckDB), and SPRUCE column semantics behind the scenes.

<video controls width="100%" src="SPRUCE_skill_teaser.mp4"></video>

## Install

1. Download the latest `spruce-sql-advisor.skill` from the
   [Releases page](https://github.com/DigitalPebble/spruce-sql-advisor/releases).
2. In Claude.ai, go to [**Settings → Customize → Skills**](https://claude.ai/customize/skills),
   click on +, **Create skills** and **Upload a skill**.
3. Start a new chat and ask a CUR question in plain English — Claude will load the skill
   automatically. Alternatively, call it explicitly by typing `/spruce-sql-advisor` in a new
   chat window.

## Related

- [SPRUCE](https://github.com/DigitalPebble/spruce) — the GreenOps platform that produces
  the enriched CUR 2.0 data.
- [DigitalPebble](https://digitalpebble.com) — green software consultancy.

## Licence

Apache License 2.0. See [LICENSE](https://github.com/DigitalPebble/spruce-sql-advisor/blob/main/LICENSE)
and [NOTICE](https://github.com/DigitalPebble/spruce-sql-advisor/blob/main/NOTICE).
