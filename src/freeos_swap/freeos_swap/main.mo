import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

actor {
  type Subaccount = Blob;
  type Tokens = Nat;
  type Timestamp = Nat64;

  type Account = {
    owner : Principal;
    subaccount : ?Subaccount;
  };

  type Result<Ok, Err> = {
    #ok : Ok;
    #err : Err;
  };

  type TransferArg = {
    from_subaccount : ?Subaccount;
    to : Account;
    amount : Tokens;
    fee : ?Tokens;
    memo : ?Blob;
    created_at_time : ?Timestamp;
  };

  type BlockIndex = Nat;

  type TransferError = {
    BadFee : { expected_fee : Tokens };
    BadBurn : { min_burn_amount : Tokens };
    InsufficientFunds : { balance : Tokens };
    TooOld : Nat;
    CreatedInFuture : { ledger_time : Timestamp };
    TemporarilyUnavailable : Nat;
    Duplicate : { duplicate_of : BlockIndex };
    GenericError : { error_code : Nat; message : Text };
  };

  type TransferResult = {
    #Ok : BlockIndex;
    #Err : TransferError;
  };

  let ledger_canister = actor ("mxzaz-hqaaa-aaaar-qaada-cai") : actor {
    icrc1_transfer : (TransferArg) -> async TransferResult;
  };

  // Timer variable to store the timer ID
  var mintTimer : Timer.TimerId = 0;

  public shared func mint() : async Result<Nat, Text> {
    let to_principal = Principal.fromText("blwz3-4wsku-3otjv-yriaj-2hhdr-3gh3e-x4z7v-psn6e-ent7z-eytoo-mqe");
    let memoText = "Test transfer";
    let memoBlob = Text.encodeUtf8(memoText);

    let transferArgs = {
      from_subaccount = null;
      to = {
        owner = to_principal;
        subaccount = null;
      };
      amount = 50000;
      fee = ?0;
      memo = ?memoBlob;
      created_at_time = null;
    };

    let transferResult = await ledger_canister.icrc1_transfer(transferArgs);

    switch (transferResult) {
      case (#Ok(blockIndex)) {
        return #ok(blockIndex);
      };
      case (#Err(_transferError)) {
        throw Error.reject("Transfer error");
      };
    };
  };

  // Heartbeat function to run mint every 30 seconds
  system func heartbeat() : async () {
    if (mintTimer == 0) {
      mintTimer := Timer.setTimer(#seconds 30, heartbeatCallback);
    };
  };

  // Callback function for the timer
  func heartbeatCallback() : async () {
    ignore mint();
    mintTimer := Timer.setTimer(#seconds 30, heartbeatCallback);
  };

  // Function to stop the minting process
  public func stopMinting() : async () {
    if (mintTimer != 0) {
      Timer.cancelTimer(mintTimer);
      mintTimer := 0;
    };
  };
};