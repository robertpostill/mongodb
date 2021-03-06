#lang scribble/doc
@(require scribble/manual
          (for-label racket
                     (only-in srfi/19
                              time? time-type time-utc)
                     db/mongodb))

@title{MongoDB}
@author{@(author+email "Jay McCarthy" "jay@racket-lang.org")}

@defmodule[db/mongodb]

This package provides an interface to @link["http://www.mongodb.org/"]{MongoDB}. It supports and exposes features of MongoDB 1.3, if you use it with an older version they may silently fail.

@table-of-contents[]

@section{Quickstart}

Here's a little snippet that uses the API.

@racketblock[
 (define m (create-mongo))
 (define d (make-mongo-db m "awesome-dot-com"))
 (current-mongo-db d)
 (define-mongo-struct post "posts"
   ([title #:required]
    [body #:required]
    [tags #:set-add #:pull]
    [comments #:push #:pull]
    [views #:inc]))
 
 (define p
   (make-post #:title "Welcome to my blog"
              #:body "This is my first entry, yay!"))
 (set-add-post-tags! p 'awesome)
 (inc-post-views! p)
 
 (set-post-comments! p (list "Can't wait!" "Another blog?"))
 (post-comments p)
 ]             

@section{BSON}

@defmodule[net/bson]

MongoDB depends on @link["http://bsonspec.org/"]{BSON}. This module contains an encoding of BSON values as Scheme values.

A @deftech{BSON document} is a dictionary that maps symbols to @tech{BSON values}.

A @deftech{BSON value} is either
@itemlist[
 @item{ An @racket[inexact?] @racket[real?] number }
 @item{ A @racket[string?] }
 @item{ A @tech{BSON document} }
 @item{ A @tech{BSON sequence} }
 @item{ A @racket[bson-binary?] or @racket[bytes?]}
 @item{ A @racket[bson-objectid?] }
 @item{ A @racket[boolean?] }
 @item{ A SRFI 19 @racket[time?] where @racket[time-type] equals @racket[time-utc] }
 @item{ A @racket[bson-null?] }
 @item{ A @racket[bson-regexp?] }
 @item{ A @racket[bson-javascript?] }
 @item{ A @racket[symbol?] }
 @item{ A @racket[bson-javascript/scope?] }
 @item{ A @racket[int32?] }
 @item{ A @racket[bson-timestamp?] }
 @item{ A @racket[int64?] }
 @item{ @racket[bson-min-key] }
 @item{ @racket[bson-max-key] }
]

A @deftech{BSON sequence} is sequence of @tech{BSON values}.

@defproc[(int32? [x any/c]) boolean?]{ A test for 32-bit integers.}
@defproc[(int64? [x any/c]) boolean?]{ A test for 64-bit integers.}
@defthing[bson-document/c contract?]{A contract for @tech{BSON documents}.}
@defthing[bson-sequence/c contract?]{ A contract for @tech{BSON sequences}. }

A few BSON types do not have equivalents in Scheme.

@defproc[(bson-min-key? [x any/c]) boolean?]{ A test for @racket[bson-min-key]. }
@defthing[bson-min-key bson-min-key?]{ The smallest BSON value. }
@defproc[(bson-max-key? [x any/c]) boolean?]{ A test for @racket[bson-max-key]. }
@defthing[bson-max-key bson-max-key?]{ The largest BSON value. }
@defproc[(bson-null? [x any/c]) boolean?]{ A test for @racket[bson-null]. }
@defthing[bson-null bson-null?]{ The missing BSON value. }
@defstruct[bson-timestamp ([value int64?])]{ A value representing an internal MongoDB type. }
@defproc[(bson-objectid? [x any/c]) boolean?]{ A test for BSON @link["http://www.mongodb.org/display/DOCS/Object+IDs"]{ObjectId}s, an internal MongoDB type. }
@defproc[(new-bson-objectid) bson-objectid?]{ Returns a fresh ObjectId. }
@defproc[(bson-objectid-timestamp [oid bson-objectid?]) exact-integer?]{ Returns the part of the ObjectID conventionally representing a timestamp. }

A few BSON types have equivalents in Scheme, but because of additional tagging of them in BSON, we have to create structures to preserve the tagging.

@defstruct[bson-javascript ([string string?])]{ A value representing Javascript code. }
@defstruct[bson-javascript/scope ([string string?] [scope bson-document/c])]{ A value representing Javascript code and its scope. }
@defstruct[bson-binary ([type (symbols 'function 'binary 'uuid 'md5 'user-defined)] [bs bytes?])]{ A value representing binary data. }
@defstruct[bson-regexp ([pattern string?] [options string?])]{ A value representing a regular expression. }

@subsection{Decoding Conventions}

Only @racket[make-hasheq] dictionaries are returned as @tech{BSON documents}.

A @racket[bson-binary?] where @racket[bson-binary-type] is equal to @racket['binary] is never returned. It is converted to @racket[bytes?].

Only @racket[vector] sequences are returned as @tech{BSON sequences}.

@section{Basic Operations}

@defmodule[db/mongodb/basic/main]

The basic API of MongoDB is provided by this module.

@subsection{Servers}

@defproc[(mongo? [x any/c]) boolean?]{ A test for Mongo servers. }

@defproc[(create-mongo [#:host host string "localhost"]
                       [#:port port port-number? 27017])
         mongo?]{
 Creates a connection to the specified Mongo server.
 }
                
@defproc[(close-mongo! [m mongo?]) void?]{
 Closes the connection to the Mongo server.
}

@defproc[(mongo-list-databases [m mongo?])
         (vectorof bson-document/c)]{
 Returns information about the databases on a server.
 }

@defproc[(mongo-db-names [m mongo?])
         (listof string?)]{
 Returns the names of the databases on the server.
 }
         
@subsection{Databases}

@defstruct[mongo-db ([mongo mongo?] [name string?])]{ A structure representing a Mongo database. The @racket[mongo] field is mutable. }

@defproc[(mongo-db-execute-command! [db mongo-db?] [cmd bson-document/c])
         bson-document/c]{
 Executes command @racket[cmd] on the database @racket[db] and returns Mongo's response. Refer to @link["http://www.mongodb.org/display/DOCS/List+of+Database+Commands"]{List of Database Commands} for more details.
}
                         
@defproc[(mongo-db-collections [db mongo-db?])
         (listof string?)]{
 Returns a list of collection names in the database.
 }
                          
@defproc[(mongo-db-create-collection! [db mongo-db?]
                                      [name string?]
                                      [#:capped? capped? boolean?]
                                      [#:size size number?]
                                      [#:max max (or/c false/c number?) #f])
         mongo-collection?]{
 Creates a new collection in the database and returns a handle to it. Refer to @link["http://www.mongodb.org/display/DOCS/Capped+Collections"]{Capped Collections} for details on the options.
}

@defproc[(mongo-db-drop-collection! [db mongo-db?]
                                    [name string?])
         bson-document/c]{
 Drops a collection from the database.
 }
                         
@defproc[(mongo-db-drop [db mongo-db?])
         bson-document/c]{
 Drops a database from its server.
 }
                       
@defthing[mongo-db-profiling/c contract?]{ Defined as @racket[(symbols 'none 'low 'all)]. }
@defproc[(mongo-db-profiling [db mongo-db?]) mongo-db-profiling/c]{ Returns the profiling level of the database. }
@defproc[(set-mongo-db-profiling! [db mongo-db?] [v mongo-db-profiling/c]) boolean?]{ Sets the profiling level of the database. Returns @racket[#t] on success. }

@defproc[(mongo-db-profiling-info [db mongo-db?]) bson-document/c]{ Returns the profiling information from the database. Refer to @link["http://www.mongodb.org/display/DOCS/Database+Profiler"]{Database Profiler} for more details. }

@defproc[(mongo-db-valid-collection? [db mongo-db?] [name string?]) boolean?]{ Returns @racket[#t] if @racket[name] is a valid collection. }
                          
@subsection{Collections}

@defstruct[mongo-collection ([db mongo-db?] [name string?])]{ A structure representing a Mongo collection. }

@defproc[(mongo-collection-drop! [mc mongo-collection?]) void]{ Drops the collection from its database. }
@defproc[(mongo-collection-valid? [mc mongo-collection?]) boolean?]{ Returns @racket[#t] if @racket[mc] is a valid collection. }
@defproc[(mongo-collection-full-name [mc mongo-collection?]) string?]{ Returns the full name of the collection. }
@defproc[(mongo-collection-find [mc mongo-collection?]
                                [query bson-document/c]
                                [#:tailable? tailable? boolean? #f]
                                [#:slave-okay? slave-okay? boolean? #f]
                                [#:no-timeout? no-timeout? boolean? #f]
                                [#:selector selector (or/c false/c bson-document/c) #f]
                                [#:skip skip int32? 0]
                                [#:limit limit (or/c false/c int32?) #f])
         mongo-cursor?]{
 Performs a query in the collection. Refer to @link["http://www.mongodb.org/display/DOCS/Querying"]{Querying} for more details.
 
 If @racket[limit] is @racket[#f], then a limit of @racket[2] is sent. This is the smallest limit that creates a server-side cursor, because @racket[1] is interpreted as @racket[-1].
 }

@defproc[(mongo-collection-insert-docs! [mc mongo-collection?] [docs (sequenceof bson-document/c)]) void]{ Inserts a sequence of documents into the collection. }
@defproc[(mongo-collection-insert-one! [mc mongo-collection?] [doc bson-document/c]) void]{ Insert an document into the collection. }
@defproc[(mongo-collection-insert! [mc mongo-collection?] [doc bson-document/c] ...) void]{ Inserts any number of documents into the collection. }

@defproc[(mongo-collection-remove! [mc mongo-collection?] [sel bson-document/c]) void]{ Removes documents matching the selector. Refer to @link[
"http://www.mongodb.org/display/DOCS/Removing"]{Removing} for more details. }

@defproc[(mongo-collection-modify! [mc mongo-collection?] [sel bson-document/c] [mod bson-document/c]) void]{ Modifies all documents matching the selector according to @racket[mod]. Refer to @link[
"http://www.mongodb.org/display/DOCS/Updating#Updating-ModifierOperations"]{Modifier Operations} for more details. }

@defproc[(mongo-collection-replace! [mc mongo-collection?] [sel bson-document/c] [doc bson-document/c]) void]{ Replaces the first document matching the selector with @racket[obj]. }

@defproc[(mongo-collection-repsert! [mc mongo-collection?] [sel bson-document/c] [doc bson-document/c]) void]{ If a document matches the selector, it is replaced; otherwise the document is inserted. Refer to @link[
"http://www.mongodb.org/display/DOCS/Updating#Updating-UpsertswithModifiers"]{Upserts with Modifiers} for more details on using modifiers. }

@defproc[(mongo-collection-count [mc mongo-collection?] [query bson-document/c empty]) exact-integer?]{ Returns the number of documents matching the query. }

@subsubsection{Indexing}

Refer to @link["http://www.mongodb.org/display/DOCS/Indexes"]{Indexes} for more details on indexing.

@defproc[(mongo-collection-index! [mc mongo-collection?] [spec bson-document/c] [name string? ....]) void]{ Creates an index of the collection. A name will be automatically generated if not specified. }
@defproc[(mongo-collection-indexes [mc mongo-collection?]) mongo-cursor?]{ Queries for index information. }
@defproc[(mongo-collection-drop-index! [mc mongo-collection?] [name string?]) void]{ Drops an index by name. }

@subsection{Cursors}

Query results are returned as @tech{Mongo cursors}.

A @deftech{Mongo cursor} is a sequence of @tech{BSON documents}.

@defproc[(mongo-cursor? [x any/c]) boolean?]{ A test for @tech{Mongo cursors}. }
@defproc[(mongo-cursor-done? [mc mongo-cursor?]) boolean?]{ Returns @racket[#t] if the cursor has no more answers. @racket[#f] otherwise. }
@defproc[(mongo-cursor-kill! [mc mongo-cursor?]) void]{ Frees the server resources for the cursor. }

@section{ORM Operations}

@defmodule[db/mongodb/orm/main]

An "ORM" style API is built on the basic Mongo operations.

@subsection{Dictionaries}

@defmodule[db/mongodb/orm/dict]

A @deftech{Mongo dictionary} is a dictionary backed by Mongo.

@defproc[(create-mongo-dict [col string?]) mongo-dict?]{ Creates a new @tech{Mongo dictionary} in the @racket[col] collection of the @racket[(current-mongo-db)] database. }

@defproc[(mongo-dict-query [col string?] [query bson-document/c]) (sequenceof mongo-dict?)]{ Queries the collection and returns @tech{Mongo dictionaries}. }

@defproc[(mongo-dict? [x any/c]) boolean?]{ A test for @tech{Mongo dictionaries}. }
@defparam[current-mongo-db db (or/c false/c mongo-db?)]{ The database used in @tech{Mongo dictionary} operations. }
@defproc[(mongo-dict-ref [md mongo-dict?] [key symbol?] [fail any/c bson-null]) any/c]{ Like @racket[dict-ref] but for @tech{Mongo dictionaries}, returns @racket[bson-null] by default on errors or missing values. }
@defproc[(mongo-dict-set! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Like @racket[dict-set!] but for @tech{Mongo dictionaries}. }
@defproc[(mongo-dict-remove! [md mongo-dict?] [key symbol?]) void]{ Like @racket[dict-remove!] but for @tech{Mongo dictionaries}. }
@defproc[(mongo-dict-count [md mongo-dict?]) exact-nonnegative-integer?]{ Like @racket[dict-count] but for @tech{Mongo dictionaries}. }

@defproc[(mongo-dict-inc! [md mongo-dict?] [key symbol?] [amt number? 1]) void]{ Increments @racket[key]'s value by @racket[amt] atomically. }
@defproc[(mongo-dict-push! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Pushes a value onto the sequence atomically. }
@defproc[(mongo-dict-append! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Pushes a sequence of values onto the sequence atomically. }
@defproc[(mongo-dict-set-add! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Adds a value to the sequence if it is not present atomically. }
@defproc[(mongo-dict-set-add*! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Adds a sequence of values to the sequence if they are not present atomically. }
@defproc[(mongo-dict-pop! [md mongo-dict?] [key symbol?]) void]{ Pops a value off the sequence atomically. }
@defproc[(mongo-dict-shift! [md mongo-dict?] [key symbol?]) void]{ Shifts a value off the sequence atomically. }
@defproc[(mongo-dict-pull! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Remove a value to the sequence if it is present atomically. }
@defproc[(mongo-dict-pull*! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Removes a sequence of values to the sequence if they are present atomically. }

@subsection{Structures}

@defmodule[db/mongodb/orm/struct]

@racket[define-mongo-struct] is a macro to create some convenience functions for @tech{Mongo dictionaries}.

@defform/subs[(define-mongo-struct struct collection
                ([field opt ...]
                 ...))
              ([opt #:required #:immutable
                    #:ref #:set! #:inc #:null #:push #:append #:set-add #:set-add* #:pop #:shift #:pull #:pull*])
              #:contracts ([struct identifier?]
                           [collection string?]
                           [field identifier?])]{
 Defines @racket[make-struct] and a set of operations for the fields.
         
 Every field implicitly has the @racket[#:ref] option. Every mutable field implicitly has the @racket[#:set!] option. Every immutable field implicitly has the @racket[#:required] option. It is an error for an immutable field to have any options other than @racket[#:required] and @racket[#:ref], which are both implicit.
 
 @racket[make-struct] takes one keyword argument per field. If the field does not have the @racket[#:required] option, the argument is optional and the instance will not contain a value for the field. @racket[make-struct] returns a @racket[mongo-dict?].
 
 If a field has the @racket[#:ref] option, then @racket[struct-field] is defined. It is implemented with @racket[mongo-dict-ref].
 
 If a field has the @racket[#:set] option, then @racket[set-struct-field!] is defined. It is implemented with @racket[mongo-dict-set!].
 
 If a field has the @racket[#:inc] option, then @racket[inc-struct-field!] is defined. It is implemented with @racket[mongo-dict-inc!].
 
 If a field has the @racket[#:null] option, then @racket[null-struct-field!] is defined. It is implemented with @racket[mongo-dict-remove!].
 
 If a field has the @racket[#:push] option, then @racket[push-struct-field!] is defined. It is implemented with @racket[mongo-dict-push!].
 
 If a field has the @racket[#:append] option, then @racket[append-struct-field!] is defined. It is implemented with @racket[mongo-dict-append!].
 
 If a field has the @racket[#:set-add] option, then @racket[set-add-struct-field!] is defined. It is implemented with @racket[mongo-dict-set-add!].
 
 If a field has the @racket[#:set-add*] option, then @racket[set-add*-struct-field!] is defined. It is implemented with @racket[mongo-dict-set-add*!].
 
 If a field has the @racket[#:pop] option, then @racket[pop-struct-field!] is defined. It is implemented with @racket[mongo-dict-pop!].
 
 If a field has the @racket[#:shift] option, then @racket[shift-struct-field!] is defined. It is implemented with @racket[mongo-dict-shift!].
 
 If a field has the @racket[#:pull] option, then @racket[pull-struct-field!] is defined. It is implemented with @racket[mongo-dict-pull!].
 
 If a field has the @racket[#:pull*] option, then @racket[pull*-struct-field!] is defined. It is implemented with @racket[mongo-dict-pull*!].
 
}

@section{Other}

@subsection{Dispatch Rules}

@(require (for-label web-server/dispatch/mongodb))

@defmodule[web-server/dispatch/mongodb]

@defform[(mongo-dict-arg col) #:contracts ([col string?])]{
A bi-directional match expander for @racketmodname[web-server/dispatch] that serializes to and from @tech{Mongo dictionaries} from the @racket[col] collection.
}

                                                                                                
