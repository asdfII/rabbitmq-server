%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2017 Pivotal Software, Inc.  All rights reserved.
%%


-module(term_to_binary_compat_prop_SUITE).

-compile(export_all).

-include("rabbit.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("proper/include/proper.hrl").

-define(ITERATIONS_TO_RUN_UNTIL_CONFIDENT, 10000).

all() ->
    [
        pre_3_6_11_works,
        term_to_binary_latin_atom,
        queue_name_to_binary
    ].

erts_gt_8() ->
    Vsn = erlang:system_info(version),
    [Maj|_] = string:tokens(Vsn, "."),
    list_to_integer(Maj) > 8.

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    rabbit_ct_helpers:run_setup_steps(Config).

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config).

init_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_started(Config, Testcase).

%% If this test fails - the erlang version is not supported in
%% RabbitMQ-3.6.10 and earlier.
pre_3_6_11_works(Config) ->
    Property = fun () -> prop_pre_3_6_11_works(Config) end,
    rabbit_ct_proper_helpers:run_proper(Property, [],
                                        ?ITERATIONS_TO_RUN_UNTIL_CONFIDENT).

prop_pre_3_6_11_works(_Config) ->
    ?FORALL(Term, any(),
        begin
            Current = term_to_binary(Term),
            Compat = term_to_binary_compat:term_to_binary_1(Term),
            binary_to_term(Current) =:= binary_to_term(Compat)
        end).

term_to_binary_latin_atom(Config) ->
    Property = fun () -> prop_term_to_binary_latin_atom(Config) end,
    rabbit_ct_proper_helpers:run_proper(Property, [],
                                        ?ITERATIONS_TO_RUN_UNTIL_CONFIDENT).

prop_term_to_binary_latin_atom(_Config) ->
    ?FORALL(LatinString, list(integer(0, 255)),
        begin
            Length = length(LatinString),
            Atom = list_to_atom(LatinString),
            Binary = list_to_binary(LatinString),
            <<131,100, Length:16, Binary/binary>> =:=
                term_to_binary_compat:term_to_binary_1(Atom)
        end).

queue_name_to_binary(Config) ->
    Property = fun () -> prop_queue_name_to_binary(Config) end,
    rabbit_ct_proper_helpers:run_proper(Property, [],
                                        ?ITERATIONS_TO_RUN_UNTIL_CONFIDENT).


prop_queue_name_to_binary(_Config) ->
    ?FORALL({VHost, QName}, {binary(), binary()},
            begin
                VHostBSize = byte_size(VHost),
                NameBSize = byte_size(QName),
                Expected =
                    <<131,                               %% Binary format "version"
                      104, 4,                            %% 4-element tuple
                      100, 0, 8, "resource",             %% `resource` atom
                      109, VHostBSize:32, VHost/binary,  %% Vhost binary
                      100, 0, 5, "queue",                %% `queue` atom
                      109, NameBSize:32, QName/binary>>, %% Name binary
                Resource = rabbit_misc:r(VHost, queue, QName),
                Current = term_to_binary_compat:term_to_binary_1(Resource),
                Current =:= Expected
            end).
