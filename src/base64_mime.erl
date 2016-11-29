-module(base64_mime).

-export([mime_decode/1]).

%% One-based decode map.
-define(DECODE_MAP,
    {bad,bad,bad,bad,bad,bad,bad,bad,ws,ws,bad,bad,ws,bad,bad, %1-15
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad, %16-31
        ws,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,62,bad,bad,bad,63, %32-47
        52,53,54,55,56,57,58,59,60,61,bad,bad,bad,eq,bad,bad, %48-63
        bad,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,bad,bad,bad,bad,bad,
        bad,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,51,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,
        bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad}).

% @doc
% Here we have a re-written version of base64's mime_decode because it
% is 2x slower than base64:decode. In this rewrite, we are cautious about
% preserving tail recursion optimizations. The original has a check called
% tail_contains_more, which based on testing appears to cause the compiler
% to collapse the binary tail and add significant overhead.
% (overhead was measured to be 4 msec for a 92 KB base64 binary, when total
% execution time was 8 msec)
mime_decode(Bin) when is_binary(Bin) ->
    mime_decode_binary_1(<<>>, Bin).

%% Skipping pad character if not at end of string. Also liberal about
%% excess padding and skipping of other illegal (non-base64 alphabet)
%% characters. See section 3.3 of RFC4648
mime_decode_binary_1(Result, <<0:8,T/bits>>) ->
    mime_decode_binary_1(Result, T);
mime_decode_binary_1(Result0, <<C:8,T/bits>>) ->
    case element(C, ?DECODE_MAP) of
        Bits when is_integer(Bits) ->
            mime_decode_binary_1(<<Result0/bits,Bits:6>>, T);
        eq ->
            mime_decode_binary_2(Result0, T);
        _ ->
            mime_decode_binary_1(Result0, T)
    end;
mime_decode_binary_1(Result, _) ->
    true = is_binary(Result),
    Result.

mime_decode_binary_2(Result, <<0:8,T/bits>>) ->
    mime_decode_binary_2(Result, T);
mime_decode_binary_2(Result0, <<C:8,T/bits>>) ->
    case element(C, ?DECODE_MAP) of
        bad ->
            mime_decode_binary_2(Result0, T);
        ws ->
            mime_decode_binary_2(Result0, T);
        eq ->
            mime_decode_binary_2(Result0, T);
        Bits when is_integer(Bits) ->
            %% More valid data, skip the eq as invalid
            mime_decode_binary_1(<<Result0/bits,Bits:6>>, T)
    end;
mime_decode_binary_2(Result0, _) ->
    case bit_size(Result0) rem 8 of
        0 ->
            %% '====' is not uncommon.
            Result0;
        4 ->
            %% enforce at least one more '=' only ignoring illegals and spacing
            Split = byte_size(Result0) - 1,
            <<Result:Split/bytes,_:4>> = Result0,
            Result;
        2 ->
            %% remove 2 bits
            Split = byte_size(Result0) - 1,
            <<Result:Split/bytes,_:2>> = Result0,
            Result
    end.
