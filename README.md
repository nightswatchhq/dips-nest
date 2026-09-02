# dips-nest

A [nuthatch](https://github.com/nightswatchhq/nuthatch) nest indexing **Direct Indexer Payments
(DIPS)** on Arbitrum One: the Issuance Allocator, the Recurring Agreement Manager and the Recurring
Collector.

It exists to answer one question before anyone else can: **when does the agreement allocation stop
being zero?**

## Why now

As of 2026-08-28 the whole DIPS contract stack is live on Arbitrum One and switched off. The
allocator is deployed, wired, and distributing.

**Re-read 2026-09-02, and it had moved.** There are now three targets, not two:

```
getIssuancePerBlock()   120.73 GRT/block

target                                       total   allocMint   selfMint
DefaultAllocation     (0x28cd…dde1e)          0.000      0.000      0.000
RewardsManager        (0x971b…a525)          96.584      0.000     96.584
InnovationAllocation  (0x2ff0…b16e)          24.146     24.146      0.000

sum of per-target total == getIssuancePerBlock
```

`InnovationAllocation` (GIP-0089) arrived on mainnet holding **a fifth of all issuance**, and
nothing announced it. It was found by reading the allocator directly.

Two things worth carrying away from that. `Allocation` has **three** fields,
`(totalAllocationRate, allocatorMintingRate, selfMintingRate)`; a two-field ABI decodes without
complaint and returns every value shifted by one position. And a target's share is
`allocatorMintingRate + selfMintingRate`: the fields are mechanism, not amount, and reading either
alone is wrong in one direction or the other. The RewardsManager self-mints its whole 96.584 while
InnovationAllocation is sent its 24.146, so either single-field reading zeroes one of them.

The sum being exactly `getIssuancePerBlock()` is the cheapest correctness check this data has.
GIP-0088's ~5% split is therefore a governance parameter change, not a deployment. Whoever is
already indexing these contracts sees the split move the moment it moves.

The event to watch is `issuance_allocator__target_allocation_updated`.

## Contracts

| Alias | Address (proxy) | Implementation |
|---|---|---|
| `issuance_allocator` | `0xb64f29b2d81140ffc3a135e319561a1bd03b1a7e` | `0xf47b3a62f815121eadddc135f5515b274e2feff2` |
| `recurring_agreement_manager` | `0x51f860b03dee6a6ea27392dcceccd908204149f2` | `0x09ac86ba5edef13673f9035eb76f7e1304413ca8` |
| `recurring_collector` | `0xff0dc7310fbfbcc2524dae230cd4f34727eb84ee` | `0x69315eb3e779dad209fbd0c70fa838c96fae488e` |

All three are transparent proxies. Each ABI therefore also carries the ERC-1967 `Upgraded` and
`AdminChanged` events, because an implementation swapped under our feet is exactly the kind of
governance move this nest exists to notice.

## How the ABIs were established, and why it matters

**The published npm ABIs do not match what is deployed.** Getting this wrong would have produced a
nest that indexes events the contracts never emit: permanently empty tables that look perfectly
healthy.

Neither `@graphprotocol/issuance@1.0.0` nor `@graphprotocol/interfaces@latest` matches the deployed
bytecode, and Sourcify has none of the three implementations. The composition below was established
by extracting the 4-byte function selectors present in each deployed implementation's runtime
bytecode and keeping only interfaces whose selectors are *entirely* present:

| Interface | issuance_allocator | recurring_agreement_manager | recurring_collector |
|---|---|---|---|
| `IssuanceAllocator` (issuance@1.0.0) | **41/41** | 18/41 | 4/41 |
| `IndexingAgreementManager` (issuance@1.0.0) | 18/38 | **21/38** ← rejected | 4/38 |
| `IRecurringAgreementManagement` (interfaces@0.7.1-dips.0) | 0/6 | **6/6** | 0/6 |
| `IRecurringAgreements` (dips) | 0/18 | **18/18** | 0/18 |
| `IRecurringEscrowManagement` (dips) | 0/5 | **5/5** | 0/5 |
| `IRecurringCollector` (dips) | 2/27 | 3/27 | **26/27** |
| `IAuthorizable` (dips) | 0/7 | 0/7 | **7/7** |
| `IAgreementCollector` (dips) | 0/7 | 1/7 | **7/7** |
| `IIssuanceTarget` (dips) | 0/3 | **3/3** | 0/3 |

The trap is the second row. `@graphprotocol/issuance@1.0.0` publishes an `IndexingAgreementManager`
whose events are `AgreementOffered` / `OfferRevoked` / `AgreementCanceled`. Only 21 of its 38
selectors are in the deployed bytecode, so it is a **different version**. The deployed contract is
the `dips`-tagged one, whose events are `AgreementAdded` / `AgreementRejected` / `AgreementRemoved`.
Index the wrong set and you get silence that reads as calm.

The `dips` dist-tag on `@graphprotocol/interfaces` (`0.7.1-dips.0`) is the thing to track; `latest`
is behind mainnet.

## What the index actually found

35 events across 12.3 million blocks, backfilled in 2m04s. Almost all of it is deployment noise.
The six that matter are the configuration timeline, and they say the stack was wired up **three days
ago**:

| Block | When (UTC) | Step | Subject |
|---|---|---|---|
| 486,933,823 | 2026-07-23 16:38 | issuance rate set | 0 → **120.73 GRT/block** |
| 486,933,993 | 2026-07-23 16:39 | agreement manager wired to allocator | `0xb64f29b2…` |
| 498,298,501 | **2026-08-25** 16:56 | collector pause guardian set | `0xb0ad33a2…` |
| 498,298,632 | **2026-08-25** 16:56 | provider-eligibility oracle set | `0x02753bae…` (REO A) |
| 498,298,724 | **2026-08-25** 16:56 | default target set | `0x28cd50e9…` (DefaultAllocation) |
| 498,298,724 | **2026-08-25** 16:56 | target allocation set | RewardsManager ← **120.73 GRT/block** |

Read it as a sequence and it is unambiguous. On 23 July the allocator was switched on. On 25 August,
in one burst, somebody set the collector's pause guardian, pointed the agreement manager at the
Rewards Eligibility Oracle, registered DefaultAllocation as the default target, and allocated the
Rewards Manager the entire 120.73 GRT per block.

That is every step of arming DIPS except the last one. `dips_current_allocation` has exactly one
row, the Rewards Manager taking 100%. **The remaining move is a single number.**

GIP-0089's Innovation Allocation is due to go live on 2026-08-31, and `InnovationAllocation` is
still absent from the mainnet address book while existing on Sepolia. The 25 August wiring is three
days ahead of that date, which is worth watching rather than concluding anything from.

## Arbitrum Sepolia

`nuthatch.sepolia.toml` points the same three contracts at chain 421614, where DIPS **has** been
exercised. Measured 2026-09-02:

```
RecurringCollector          OfferStored 113, AgreementAccepted 111,
                            RCACollected 1099, AgreementCanceled 4
RecurringAgreementManager   AgreementAdded 113, AgreementRejected 0
```

1,440 real lifecycle events, against mainnet's zero. Anything reading the agreement lifecycle
should be developed against this and only then pointed at mainnet, because otherwise its first
contact with real data is the day the numbers matter most.

The ABIs and views are shared unchanged. Confirmed rather than assumed: the mainnet event
signatures decode Sepolia's logs, which is how those counts were taken.

## Views

- `dips_timeline` — every governance move that has configured DIPS, in order. The next row is the
  one that matters.
- `dips_current_allocation` — latest allocation per target. The single number everyone wants.

## Every other table is empty on mainnet, and that is correct

The three contracts were deployed and initialized in a single burst around L2 block 486,895,281 and
have emitted nothing but `Upgraded`, `AdminChanged`, `Initialized`, `RoleGranted` and
`RoleAdminChanged` since. nuthatch says so on startup:

> 56 declared table(s) have no data yet - the event has likely never fired on this chain

That is the finding, not a failure. The rails are built and idle.

## Run it

```sh
nuthatch dev                       # backfill from deployment, follow the tip, serve :8288
nuthatch sql "SELECT * FROM issuance_allocator__target_allocation_updated ORDER BY block_number"

# Sepolia, where the agreement lifecycle has actual rows
nuthatch dev --config nuthatch.sepolia.toml
```

## Consumers

Lodestar's DIPS panel (CAT-1 in
[`lodestar/docs/catalyst-community-roadmap.md`](https://github.com/nightswatchhq/lodestar/blob/main/docs/catalyst-community-roadmap.md)).
