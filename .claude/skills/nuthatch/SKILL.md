---
name: nuthatch
description: Query this self-hosted nuthatch nest on arbitrum-one - decoded events, balances, and read-only SQL. Use when asked about on-chain activity for these contracts.
---

# Querying the nuthatch nest

Contracts indexed on arbitrum-one:
- `issuance_allocator` = 0xb64f29b2d81140ffc3a135e319561a1bd03b1a7e
- `recurring_agreement_manager` = 0x51f860b03dee6a6ea27392dcceccd908204149f2
- `recurring_collector` = 0xff0dc7310fbfbcc2524dae230cd4f34727eb84ee

Data is local - never call an external API for it.

## Preferred: MCP
If a `nuthatch` MCP server is configured, use its tools. Call `schema` first to learn the
data model, then `sql` / `entity` / `balance` / `top_balances`.

## Fallback: HTTP (a `nuthatch dev` must be running)
- Recent rows:  `curl localhost:8288/entities?limit=20`
- Read-only SQL: `curl -G localhost:8288/sql --data-urlencode 'q=SELECT count(*) FROM transfers'`

`sql` sees finalized data only; balances/entity cover the live tip.
