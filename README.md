# Using icrc1_ledger canister

This set of canisters creates LIFT (Lift Cash) token.
Then it demonstrates how to mint by transferring from the minter id to a user.

## Step 1: Download the latest icrc1_ledger wasm and did file

Run the command:
`source download_latest_icrc1_ledger.sh`

These files should be placed in the src/lift directory

## Step 2: Build all of the canisters

Run the command:
`dfx build`

## Step 3: Deploy the freeos_swap canister

Run the command:
`dfx deploy freeos_swap`

Take note of the canister id. This is the 'minter principal' required by the icrc1_ledger. The freeos_swap canister will become the only entity capable of minting tokens.

## Step 4: Set up the environment variables used in step 5:

Edit set_env.sh to define the MINTER setting. Set MINTER equal to the freeos_swap canister id.

Run this command:
`source set_env.sh`

## Step 5: Command to deploy the icrc1_ledger canister:

```
dfx deploy icrc1_ledger --specified-id mxzaz-hqaaa-aaaar-qaada-cai --argument "(variant {Init =
record {
token_symbol = \"${TOKEN_SYMBOL}\";
     token_name = \"${TOKEN_NAME}\";
minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = ${TRANSFER_FEE};
     metadata = vec {};
     feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};
     initial_balances = vec { record { record { owner = principal \"${DEFAULT}\"; }; ${PRE_MINTED_TOKENS}; }; };
     archive_options = record {
         num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};
         trigger_threshold = ${TRIGGER_THRESHOLD};
         controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};
};
}
})"
```

## Step 6: Call freeos_swap mint function to transfer 50,000 tokens from the minter account to user blwz3-4wsku-3otjv-yriaj-2hhdr-3gh3e-x4z7v-psn6e-ent7z-eytoo-mqe

```
dfx canister call freeos_swap mint '()'
```

Should respond with: `(variant { Ok = 1 : nat })`
