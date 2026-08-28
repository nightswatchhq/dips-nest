-- Every governance move that has configured DIPS on Arbitrum One, one row each, in order.
--
-- The whole point of this nest is to see the switch flip. Right now the timeline ends at
-- "DefaultAllocation registered as a target, allocated zero", which is the last step before
-- indexing agreements start being funded. The row that changes that will appear here.
--
-- `rate_dec` is the *decimal companion* of a big-int column - comparing the raw text column
-- would sort "9" after "120730000000000000000".
CREATE VIEW dips_timeline AS
  SELECT block_number, block_timestamp, tx_hash,
         'issuance_rate_set'          AS step,
         'allocator issuance/block'   AS subject,
         newIssuancePerBlock_dec      AS rate_dec
    FROM "issuance_allocator__issuance_per_block_updated"
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash,
         'target_allocation_set', target, newSelfMintingRate_dec
    FROM "issuance_allocator__target_allocation_updated"
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash,
         'default_target_set', newAddress, NULL
    FROM "issuance_allocator__default_target_updated"
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash,
         'agreement_manager_wired', newIssuanceAllocator, NULL
    FROM "recurring_agreement_manager__issuance_allocator_set"
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash,
         'eligibility_oracle_set', newOracle, NULL
    FROM "recurring_agreement_manager__provider_eligibility_oracle_set"
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash,
         'collector_pause_guardian_set', account, NULL
    FROM "recurring_collector__pause_guardian_set";

-- The single number everyone wants: how much issuance currently reaches indexing agreements.
-- Zero today. The day it is not zero, DIPS is live.
CREATE VIEW dips_current_allocation AS
  SELECT t.target,
         t.newSelfMintingRate_dec      AS self_minting_rate_dec,
         t.newAllocatorMintingRate_dec AS allocator_minting_rate_dec,
         t.block_number,
         t.block_timestamp
    FROM "issuance_allocator__target_allocation_updated" t
    JOIN (SELECT target AS tgt, max(block_number) AS bn
            FROM "issuance_allocator__target_allocation_updated"
           GROUP BY target) latest
      ON t.target = latest.tgt AND t.block_number = latest.bn;
