%% @author Bip Thelin <bip.thelin@evolope.se>
%% @copyright 2010-2011 Evolope.

-module(zerolog_zeromq).
-author('Bip Thelin <bip.thelin@evolope.se>').

-behaviour(gen_server).

%% API
-export([start_link/0, start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
     terminate/2, code_change/3]).

-include_lib("zerolog.hrl").

-define(DEF_SERVER, zerolog_server).

-type erlzmq_socket() :: binary().
-type erlzmq_context() :: binary().

-record(state, {context :: erlzmq_context(),
                socket  :: erlzmq_socket()}).

init(Config) ->
    Addr = zerolog_config:get_conf(Config, addr, undefined),
    {ok, Context} = erlzmq:context(),
    {ok, Socket} = erlzmq:socket(Context, pull),
    ok = erlzmq:bind(Socket, Addr),
    spawn(fun() -> receive_loop(Socket) end),
    {ok, #state{context=Context, socket=Socket}}.

start_link() ->
    start_link([]).

start_link(Opts) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Opts, []).

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{context=Context, socket=Socket}) ->
    ok = erlzmq:close(Socket),
    erlzmq:term(Context).
    
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Private
receive_loop(Socket) ->
    {ok, Payload} = erlzmq:recv(Socket),
    {{_, Msg}, _} = protobuffs:decode(Payload, bytes),
    gen_server:call(?DEF_SERVER, {receive_log, #message{payload=Msg}}),
    receive_loop(Socket).
