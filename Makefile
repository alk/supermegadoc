
all: install_cdb

BUILT_CDB_FILES = ri.cdb devhelp.cdb man.cdb go.cdb # erdoc.cdb

ri.cdb:
	./ri-indexer.rb | cdb -cu $@

erdoc.cdb:
	./erdoc-indexer.rb /usr/share/doc/erlang-doc | cdb -cu $@

devhelp.cdb:
	./devhelp-indexer.rb /usr/share/gtk-doc/html | cdb -cu $@

man.cdb:
	./man-indexer.rb | cdb -cu $@

go.cdb:
	(cd go-indexer/ && go run . --chdir=..) | cdb -cu $@

install_cdb: $(BUILT_CDB_FILES)
	mkdir -p ~/.supermegadoc
	cp $^ ~/.supermegadoc/

install: supermegadoc
	cp supermegadoc /usr/local/bin/
	ln -f /usr/local/bin/supermegadoc /usr/local/bin/superman

.PHONY: ri.cdb devhelp.cdb erdoc.cdb man.cdb go.cdb install_cdb
