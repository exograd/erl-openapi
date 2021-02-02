-module(openapi_gen).

-export([header/0, module_declaration/1,
         export_declaration/1, export_type_declaration/1,
         type_declaration/1,
         name/2, atom/1, comment/1,
         indent/2]).

-export_type([options/0, type/0]).

-type rename_model_fun() :: fun((binary()) -> binary()).

-type options() ::
        #{module_prefix => binary(),
          rename_model => rename_model_fun(),
          return_binary => boolean()}.

-type type() :: #{name := binary(),
                  args => [binary()],
                  data := iodata(),
                  comment => iodata()}.

-spec header() -> iodata().
header() ->
  Datetime = calendar:system_time_to_rfc3339(os:system_time(second),
                                             [{offset, "Z"}]),
  [comment(["File generated by erl-openapi "
            "(https://github.com/exograd/erl-openapi) on ",
            Datetime]),
   $\n].

-spec module_declaration(Name :: iodata()) -> iodata().
module_declaration(Name) ->
  ["-module(", Name, ").\n"].

-spec export_declaration([iodata()]) -> iodata().
export_declaration(FunSignatures) ->
  ["-export([",
   lists:join(",\n              ", FunSignatures),
   "]).\n"].

-spec export_type_declaration([type()]) -> iodata().
export_type_declaration(Types) ->
  ["-export_type([",
   lists:join(",\n              ", [format_type(Type) || Type <- Types]),
   "]).\n"].

-spec type_declaration(type()) -> iodata().
type_declaration(Type = #{name := Name, data := Data}) ->
  Args = maps:get(args, Type, []),
  Comment = case maps:find(comment, Type) of
              {ok, String} -> comment(String);
              error -> []
            end,
  [Comment,
   "-type ", Name, "(", [lists:join(", ", Args)] ,") ::\n",
   "        ", indent(Data, 10),  ".\n"].

-spec format_type(type()) -> iodata().
format_type(Type = #{name := Name}) ->
  Args = maps:get(args, Type, []),
  [Name, $/, integer_to_binary(length(Args))].

-spec name(binary(), options()) -> binary().
name(Name0, Options) ->
  Name = case maps:find(rename_model, Options) of
           {ok, Fun} -> Fun(Name0);
           error -> Name0
         end,
  Name2 = re:replace(Name, "[^A-Za-z0-9_]+", "_",
                     [global, {return, binary}]),
  name(Name2, <<>>, undefined).

-spec name(binary(), binary(), pos_integer() | undefined) -> binary().
name(<<>>, Acc, _) ->
  string:lowercase(Acc);
name(<<C/utf8, Rest/binary>>, Acc, undefined) ->
  name(Rest, <<Acc/binary, C/utf8>>, C);
name(<<C/utf8, Rest/binary>>, Acc, LastC) when C >= $A, C =< $Z ->
  if
    LastC >= $A, LastC =< $Z ->
      case Rest of
        <<NextC/utf8, _/binary>> when NextC >= $a, NextC =< $z ->
          name(Rest, <<Acc/binary, $_, C/utf8>>, C);
        _ ->
          name(Rest, <<Acc/binary, C/utf8>>, C)
      end;
    LastC /= $_ ->
      name(Rest, <<Acc/binary, $_, C/utf8>>, C);
    true ->
      name(Rest, <<Acc/binary, C/utf8>>, C)
  end;
name(<<C/utf8, Rest/binary>>, Acc, _) ->
  name(Rest, <<Acc/binary, C/utf8>>, C).

-spec atom(binary()) -> binary().
atom(Name) ->
  case is_reserved_word(Name) of
    true ->
      quote_atom(Name);
    false ->
      case re:run(Name, "^[a-z][A-Za-z_@]*$") of
        {match, _} ->
          Name;
        nomatch ->
          quote_atom(Name)
      end
  end.

-spec quote_atom(binary()) -> binary().
quote_atom(Name) ->
  Name2 = string:replace(Name, "'", "\\'", all),
  iolist_to_binary([$', Name2, $']).

-spec comment(iodata()) -> iodata().
comment(Data) ->
  Paragraphs =
    lists:map(fun (LineData) ->
                  case unicode:characters_to_list(LineData) of
                    "" ->
                      prettypr:break(prettypr:text(""));
                    Line ->
                      prettypr:text_par(Line)
                  end
              end, string:split(Data, "\n", all)),
  FilledText = prettypr:format(prettypr:sep(Paragraphs), 77),
  ["%% ", string:replace(FilledText, "\n", "\n%% ", all), $\n].

-spec indent(iodata(), pos_integer()) -> iodata().
indent(Data, N) ->
  S = [$\s || _ <- lists:seq(1, N)],
  string:replace(Data, "\n", ["\n", S], all).

-spec is_reserved_word(binary()) -> boolean().
is_reserved_word(Word) ->
  lists:member(Word, [<<"after">>, <<"and">>, <<"andalso">>, <<"band">>,
                      <<"begin">>, <<"bnot">>, <<"bor">>, <<"bsl">>,
                      <<"bsr">>, <<"bxor">>, <<"case">>, <<"catch">>,
                      <<"cond">>, <<"div">>, <<"end">>, <<"fun">>, <<"if">>,
                      <<"let">>, <<"not">>, <<"of">>, <<"or">>, <<"orelse">>,
                      <<"receive">>, <<"rem">>, <<"try">>, <<"when">>,
                      <<"xor">>]).
