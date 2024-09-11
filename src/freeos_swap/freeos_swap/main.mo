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
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Buffer "mo:base/Buffer";

import Types "types";

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

//function to transform the response
  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
      let transformed : Types.CanisterHttpResponsePayload = {
          status = raw.response.status;
          body = raw.response.body;
          headers = [
              {
                  name = "Content-Security-Policy";
                  value = "default-src 'self'";
              },
              { name = "Referrer-Policy"; value = "strict-origin" },
              { name = "Permissions-Policy"; value = "geolocation=(self)" },
              {
                  name = "Strict-Transport-Security";
                  value = "max-age=63072000";
              },
              { name = "X-Frame-Options"; value = "DENY" },
              { name = "X-Content-Type-Options"; value = "nosniff" },
          ];
      };
      transformed;
  };

//PUBLIC METHOD
//This method sends a POST request to a URL with a free API you can test.
  public func send_http_post_request() : async Text {

    //1. DECLARE MANAGEMENT CANISTER
    //You need this so you can use it to make the HTTP request
    let ic : Types.IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request

    // 2.1 Setup the URL and its query parameters
    //This URL is used because it allows you to inspect the HTTP request sent from the canister
    let host : Text = "api-xprnetwork-main.saltant.io";
    let url = "https://api-xprnetwork-main.saltant.io/v1/chain/get_table_rows"; //HTTPS that accepts IPV6

    // 2.2 Prepare headers for the system http_request call

    //idempotency keys should be unique so create a function that generates them.
    let idempotency_key: Text = generateUUID();
    let request_headers = [
        { name = "Host"; value = host # ":443" },
        { name = "User-Agent"; value = "http_post_sample" },
        { name= "Content-Type"; value = "application/json" },
        { name= "Idempotency-Key"; value = idempotency_key }
    ];

    // The request body is an array of [Nat8] (see Types.mo) so do the following:
    // 1. Write a JSON string
    // 2. Convert ?Text optional into a Blob, which is an intermediate representation before you cast it as an array of [Nat8]
    // 3. Convert the Blob into an array [Nat8]
    let request_body_json: Text = "{\"json\":true,\"code\":\"eosio.token\",\"lower_bound\":\"XPR\",\"upper_bound\":\"XPR\",\"table\":\"accounts\",\"scope\":\"tommccann\",\"limit\":1}";
    let request_body_as_Blob: Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8: [Nat8] = Blob.toArray(request_body_as_Blob); // e.g [34, 34,12, 0]


    // 2.2.1 Transform context
    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // 2.3 The HTTP request
    let http_request : Types.HttpRequestArgs = {
        url = url;
        max_response_bytes = null; //optional for request
        headers = request_headers;
        //note: type of `body` is ?[Nat8] so it is passed here as "?request_body_as_nat8" instead of "request_body_as_nat8"
        body = ?request_body_as_nat8;
        method = #post;
        transform = ?transform_context;
        // transform = null; //optional for request
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST

    //The management canister will make the HTTP request so it needs cycles
    //See: /docs/current/motoko/main/canister-maintenance/cycles

    //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
    //See: /docs/current/references/ic-interface-spec#ic-http_request
    Cycles.add(21_850_258_000);

    //4. MAKE HTTP REQUEST AND WAIT FOR RESPONSE
    //Since the cycles were added above, you can just call the management canister with HTTPS outcalls below
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

    //5. DECODE THE RESPONSE

    //As per the type declarations in `Types.mo`, the BODY in the HTTP response
    //comes back as [Nat8s] (e.g. [2, 5, 12, 11, 23]). Type signature:

    //public type HttpResponsePayload = {
    //     status : Nat;
    //     headers : [HttpHeader];
    //     body : [Nat8];
    // };

    // You need to decode that [Na8] array that is the body into readable text.
    //To do this:
    //  1. Convert the [Nat8] into a Blob
    //  2. Use Blob.decodeUtf8() method to convert the Blob to a ?Text optional
    //  3. Use Motoko syntax "Let... else" to unwrap what is returned from Text.decodeUtf8()
    let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
    };

    //6. RETURN RESPONSE OF THE BODY
    let result: Text = decoded_text # ". See more info of the request sent at at: " # url # "/inspect";
    result
  };

  //PRIVATE HELPER FUNCTION
  //Helper method that generates a Universally Unique Identifier
  //this method is used for the Idempotency Key used in the request headers of the POST request.
  //For the purposes of this exercise, it returns a constant, but in practice, it should return unique identifiers
  func generateUUID() : Text {
    "UUID-123456789";
  };

// Function to remove whitespace
  func removeWhitespace(text : Text) : Text {
    let chars = Text.toIter(text);
    var result = "";
    var inQuotes = false;
    for (char in chars) {
      if (char == '\"') {
        inQuotes := not inQuotes;
      };
      if (inQuotes or not Text.contains(" \t\n\r", #char char)) {
        result #= Text.fromChar(char);
      };
    };
    result
  };

func substring(json: Text, start: Nat, end: Nat): Text {
    var result = "";
    var i = 0;

    // Iterate through the text and collect characters between start and end.
    for (c in json.chars()) {
        if (i >= start and i < end) {
            result #= Text.fromChar(c);
        };
        i += 1;
    };
    
    result
};

func extractArray(json : Text) : Text {
  let chars = json.chars();
  var start = 0;
  var end = json.size();
  var depth = 0;
  var index = 0;
  var do_continue = true;

  while (do_continue and index < json.size()) {
    switch (chars.next()) {
      case (null) { do_continue := false };
      case (?char) {
        if (char == '[') {
          if (depth == 0) {
            start := index + 1;
          };
          depth += 1;
        } else if (char == ']') {
          depth -= 1;
          if (depth == 0) {
            end := index;
            do_continue := false;
          };
        };
        index += 1;
      };
    };
  };

  substring(json, start, end);
};


// Function to split the array into individual records
func splitRecords(recordArray: Text): [Text] {
    let records = Iter.toArray(Text.split(recordArray, #text "},"));

    // Use Array.tabulate to include index
    Array.tabulate<Text>(Array.size(records), func(index: Nat): Text {
        var updatedRecord = records[index];

        // Append '}' to every record except the last one
        if (index < Array.size(records) - 1) {
            updatedRecord := updatedRecord # "}";
        };

        // For the first record, ensure it starts with '{'
        if (index == 0 and not Text.startsWith(updatedRecord, #text "{")) {
            updatedRecord := "{" # updatedRecord;
        };

        // For the last record, ensure it ends with '}'
        if (index == Array.size(records) - 1 and not Text.endsWith(updatedRecord, #text "}")) {
            updatedRecord := updatedRecord # "}";
        };

        return updatedRecord;
    })
};

  func parseKeyValuePairs(record: Text): [Text] {
      var result: [Text] = []; // Initialize an empty array to store values
      var currentValue = Buffer.Buffer<Char>(32); // Buffer for collecting characters
      var inQuotes = false; // Track if we are inside quotes
      var collectingValue = false; // Track if we are currently collecting a value

      var index = 0;
      while (index < record.size()) {
          switch (getCharAt(record, index)) {
              case (?char) {
                  switch (char) {
                      case '\"' {
                          // Toggle inQuotes when encountering a quote
                          inQuotes := not inQuotes;
                          if (not inQuotes and currentValue.size() > 0 and collectingValue) {
                              // When closing a quote, store the collected value
                              result := Array.append(result, [bufferToText(currentValue)]);
                              currentValue.clear(); // Reset buffer
                              collectingValue := false; // Stop collecting value
                          };
                      };
                      case ':' {
                          // Start collecting the value after a colon, if not inside quotes
                          if (not inQuotes) {
                              collectingValue := true;
                          };
                      };
                      case ',' {
                          // End collecting value when hitting a comma, if not inside quotes
                          if (not inQuotes and currentValue.size() > 0 and collectingValue) {
                              result := Array.append(result, [bufferToText(currentValue)]);
                              currentValue.clear(); // Reset buffer
                              collectingValue := false; // Stop collecting value
                          };
                      };
                      case '}' {
                          // End collecting value when hitting a closing brace, if not inside quotes
                          if (not inQuotes and currentValue.size() > 0 and collectingValue) {
                              result := Array.append(result, [bufferToText(currentValue)]);
                              currentValue.clear(); // Reset buffer
                              collectingValue := false; // Stop collecting value
                          };
                      };
                      case _ {
                          // Collect characters of a value (either in quotes or numbers)
                          if (collectingValue) {
                              currentValue.add(char); // Collect chars inside quotes or numbers
                          };
                      };
                  };
              };
              case (null) {
                  // Skip processing if character is not available
                  // No action needed; continue to the next iteration
              };
          };

          index += 1;
      };

      // Handle the last value if there is one
      if (currentValue.size() > 0 and collectingValue) {
          result := Array.append(result, [bufferToText(currentValue)]);
      };

      return result;
  };



  // Helper function to get a character at a specific position in a Text
  func getCharAt(text : Text, position : Nat) : ?Char {
      let textIter = Text.toIter(text);
      var currentPos = 0;
      
      for (char in textIter) {
          if (currentPos == position) {
              return ?char;
          };
          currentPos += 1;
      };
      
      null
  };

  // Helper function to convert Buffer<Char> to Text
  func bufferToText(buffer: Buffer.Buffer<Char>): Text {
      var text = "";
      for (c in buffer.vals()) {
          text := text # Text.fromChar(c);
      };
      return text;
  };


  public func parse_json() : async Text {

    let jsonString = "{"
      # "\"records\": ["
        # "{"
          # "\"ProtonAccount\": \"tommccann\","
          # "\"ICPrincipal\": \"gpurw-f4h72-qwdnm-vmexj-xnhww-us2kt-kbiua-o3y4u-bzduw-qhb7a-jqe\","
          # "\"Amount\": 100,"
          # "\"DateTime\": 1725805695"
        # "},"
        # "{"
          # "\"ProtonAccount\": \"judetan\","
          # "\"ICPrincipal\": \"22gak-zasla-2cj5r-ix2ds-4kaxw-lrgtq-4zjul-mblvf-gkhsi-fzu3j-cae\","
          # "\"Amount\": 40,"
          # "\"DateTime\": 1725805791"
        # "}"
      # "]"
    # "}";

    let cleanJson = removeWhitespace(jsonString);
    let recordArray = extractArray(cleanJson);
    let records = splitRecords(recordArray);
    Debug.print("test");
    
    for (record in records.vals()) {
      //let fieldValues = extractFieldValues(record);
      Debug.print(debug_show(record));
      Debug.print("Record parsed:");

      let parsedValues = parseKeyValuePairs(record);
      let parsedText = joinTextArray(parsedValues, ", ");

      Debug.print(parsedText);
    };

    ""
  };


  func joinTextArray(arr: [Text], separator: Text): Text {
    var result = ""; // Initialize as an empty Text string
    let length = Array.size(arr);
    var i = 0;

    while (i < length) {
        if (i > 0) {
            // Concatenate the separator before adding the next item
            result := result # separator;
        };

        // Concatenate the current item
        result := result # arr[i];
        i += 1;
    };

    return result;
}


};
