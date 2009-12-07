#!/bin/sh

`dirname $0`/docindexer.rb `find /usr/share/doc/erlang-doc-html/html -name '*.html'`
