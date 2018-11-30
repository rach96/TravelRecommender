:- use_module(library(http/json)).
:- use_module(library(http/http_open)).

:- use_module(library(clpfd)).
:- use_module(library(apply)).

% Entry point into the project
main_fn() :-
    write("Please select a location to query, Type in quotes"),
    nl,
    read(Location),
    chars_replaced(Location, ParsedLocation),
    string_validate_location(ParsedLocation).

% Helper - ensure location and type are entered as strings
string_validate_location(Location) :-
    (string(Location) ->
    write("Please select one of the following categories to query: Hotels, Shopping, Restaurants, Type in quotes"),
    nl,
    read(Type),
    chars_replaced(Type, ParsedType),
    string_validate_type(Location, ParsedType);
    write("Sorry, please enter with quotes."),
    fail).

string_validate_type(Location, Type) :-
    (string(Type) ->
    result_geocoder(Location, Type);
    write("Sorry, please enter with quotes."),
    fail).

% Given the Location and Category, call a helper to query results
result_geocoder(Location, Type) :-
    open_url_geocoder(Data, Location),
    Response = Data.get('Response'),
    View = Response.get('View'),
    length(View, Len),
    result_geocoder_helper(View, Location, Type, Len).

% Query HERE API for JSON for a specific location corresponding to Hotels/Shopping/Restaurants
open_url_query(Data, Lat, Lon, Type) :-
    Url_Start = "https://places.cit.api.here.com/places/v1/discover/search?at=",
    Lat_lon_separator = "%2C",
    Query_type = "&q=",
    Url_End = "&Accept-Language=en-US%2Cen%3Bq%3D0.9&app_id=W5Xg9ORY6hBSX1duzPmA&app_code=2VnalmJE6DVdLhahnV2_TA",
    string_concat(Url_Start, Lat, Url_1),
    string_concat(Url_1, Lat_lon_separator, Url_2),
    string_concat(Url_2, Lon, Url_3),
    string_concat(Url_3, Query_type, Url_4),
    string_concat(Url_4, Type, Url_5),
    string_concat(Url_5, Url_End, URL),
    setup_call_cleanup(
    http_open(URL, In, [request_header('Accept'='application/json')]),
        json_read_dict(In, Data),
        close(In)
    ).

% Query HERE API for JSON for a Lat/Lon Pair given a Location name (i.e. City, Country, etc)
open_url_geocoder(Data, Location) :-
    Url_Start = "https://geocoder.api.here.com/6.2/geocode.json?app_id=W5Xg9ORY6hBSX1duzPmA&app_code=2VnalmJE6DVdLhahnV2_TA&searchtext=",
    string_concat(Url_Start, Location, URL),
    setup_call_cleanup(
    http_open(URL, In, [request_header('Accept'='application/json')]),
    json_read_dict(In, Data),
    close(In)
    ).

% Obtain Latitde and Longitude to query based on location specified
% Query the correct Lat/Lon and print results
result_geocoder_helper(_,_, _, 0) :-
    format("Sorry, please specify a correct location ~n").

result_geocoder_helper(View, Location, Type, _) :-
    nth0(0, View, FirstView),
    Result = FirstView.get('Result'),
    nth0(0, Result, FirstResult),
    nl,
    PointLocation = FirstResult.get('Location'),
    DisplayPosition = PointLocation.get('DisplayPosition'),
    Lat = DisplayPosition.get('Latitude'),
    Lon = DisplayPosition.get('Longitude'),
    result_query(Lat, Lon, Type, ResultList),
    printResult(ResultList, Type, Location).

% Obtain array of information corresponding to Restuarant/Shopping/Hotel Records
result_query(Lat, Lon, "Restaurants", ResultList) :-
    open_url_query(Data, Lat, Lon, "Restaurants"),
    Results = Data.get(results),
    Items = Results.get(items),
    maplist(getAttributes, Items, ResultList).

result_query(Lat, Lon, "Shopping", ResultList) :-
    open_url_query(Data, Lat, Lon, "Shopping"),
    Results = Data.get(results),
    Items = Results.get(items),
    maplist(getAttributes, Items, ResultList).

result_query(Lat, Lon, "Hotels", ResultList) :-
    open_url_query(Data, Lat, Lon, "Hotels"),
    Results = Data.get(results),
    Items = Results.get(items),
    maplist(getAttributes, Items, ResultList).

result_query(_, _, _, _) :-
   format("Sorry, please specify one of the categories provided ~n").

getAttributes(Item, [Title, Address, Categories]) :-
    Title = Item.get(title),
    Address = Item.get(vicinity),
    Categories_Obj = Item.get(category),
    Categories = Categories_Obj.get(title).

% Helper functions to print records
printResult(ResultList, "Restaurants", Location) :-
    format('~nHere are some of the delicious Restaurants in  ~w~n', [Location]),
    obtain_result_lengths(ResultList, MaxTitleLength, MaxAddressLength),
    formatList(ResultList, MaxTitleLength, MaxAddressLength).

printResult(ResultList, "Hotels", Location) :-
    format('~nHere are some of the available Hotels in ~w~n', [Location]),
    obtain_result_lengths(ResultList, MaxTitleLength, MaxAddressLength),
    formatList(ResultList, MaxTitleLength, MaxAddressLength).

printResult(ResultList, "Shopping", Location) :-
    format('~nHere are some of the Shopping Stores in ~w~n', [Location]),
    obtain_result_lengths(ResultList, MaxTitleLength, MaxAddressLength),
    formatList(ResultList, MaxTitleLength, MaxAddressLength).

printResult(_, _,_).

obtain_result_lengths(ResultList, MaxTitleLength, MaxAddressLength) :-
    maplist(nth0(0), ResultList, Titles),
    maplist(nth0(1), ResultList, Addresses),
    maplist(string_length, Titles, TitleLengths),
    maplist(string_length, Addresses, AddressLengths),
    max_list(TitleLengths, MaxTitleLength),
    max_list(AddressLengths, MaxAddressLength).

formatSublist([], _, _).
formatSublist([A,B,C|[]], MaxTitleLength, MaxAddressLength) :-
    format('Name: ~w', A),
    string_length(A, ALen),
    tab(MaxTitleLength - ALen + 10),
    format('Address: ~w', B),
    string_length(B, BLen),
    tab(MaxAddressLength - BLen + 10),
    format('Categories: ~w~n', C).

formatList([], _, _, _).
formatList([H|T], MaxTitleLength, MaxAddressLength) :-
    formatSublist(H, MaxTitleLength, MaxAddressLength),
    formatList(T, MaxTitleLength, MaxAddressLength).

% Helper - replace whitespace for location in URL
chars_replaced(Str, String) :-
    split_string(Str, " ", "", Res),
    maplist(atom_string, Res, NewList),
    atomic_list_concat(NewList, '', Atom),
    atom_string(Atom, String).



