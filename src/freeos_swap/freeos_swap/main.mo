import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Int "mo:base/Int";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

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
    #BadFee : { expected_fee : Tokens };
    #BadBurn : { min_burn_amount : Tokens };
    #InsufficientFunds : { balance : Tokens };
    #TooOld;
    #CreatedInFuture : { ledger_time : Timestamp };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : BlockIndex };
    #GenericError : { error_code : Nat; message : Text };
  };

  type TransferResult = {
    #Ok : BlockIndex;
    #Err : TransferError;
  };

  // HTTPRequest types
  type HttpHeader = { name : Text; value : Text };
  type HttpRequest = {
    url : Text;
    method : Text;
    body : [Nat8];
    headers : [HttpHeader];
  };
  type HttpResponse = {
    status : Nat;
    headers : [HttpHeader];
    body : [Nat8];
  };
  type IC = actor {
    http_request : HttpRequest -> async HttpResponse;
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

public func makeHttpPostRequest() : async Result.Result<Text, Text> {
    let url = "https://api-xprnetwork-main.saltant.io/v1/chain/get_table_rows";
    
    // Prepare the POST body
    let postBody = "{\"json\":true,\"code\":\"eosio.token\",\"lower_bound\":\"XPR\",\"upper_bound\":\"XPR\",\"table\":\"accounts\",\"scope\":\"tommccann\",\"limit\":1}";
    let bodyAsBlob = Text.encodeUtf8(postBody);
    
    let request : HttpRequest = {
      url = url;
      method = "POST";
      body = Blob.toArray(bodyAsBlob);
      headers = [
        { name = "Content-Type"; value = "application/json" },
        { name = "User-Agent"; value = "Motoko-HTTP-Client" },
      ];
    };

    try {
    // Add cycles
    Cycles.add(21_850_258_000);

      let ic : IC = actor("aaaaa-aa");
      Debug.print("About to call http_request with postBody = " # postBody);
      let response : HttpResponse = await ic.http_request(request);

      // Log response status and headers for debugging
      Debug.print("Response status: " # debug_show(response.status));
      Debug.print("Response headers: " # debug_show(response.headers));

      if (response.status >= 200 and response.status < 300) {
        switch (Text.decodeUtf8(Blob.fromArray(response.body))) {
          case null { #err("Error: Couldn't decode response body") };
          case (?decoded) { #ok(decoded) };
        }
      } else {
        let responseBodyText = switch (Text.decodeUtf8(Blob.fromArray(response.body))) {
                case null { "<unable to decode body>" };
                case (?decoded) { decoded };
            };
            #err("HTTP request failed with status " # Int.toText(response.status) # ". Response body: " # responseBodyText)
      }
    } catch (error) {
      Debug.print("Error making HTTP request: " # Error.message(error));
      #err("Failed to make HTTP request: " # Error.message(error))
    }
  }
  
};