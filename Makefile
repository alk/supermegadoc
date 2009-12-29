
all: install_cdb

BUILT_CDB_FILES = ri.cdb devhelp.cdb erdoc.cdb

ri.cdb:
	./ri-indexer.rb /usr/share/ri/1.8 /var/lib/gems/1.8/doc | cdb -c $@

erdoc.cdb:
	./erdoc-indexer.rb /usr/share/doc/erlang-doc-html/html/lib | cdb -c $@

devhelp.cdb:
	./devhelp-indexer.rb /usr/share/gtk-doc/html | cdb -c $@

install_cdb: $(BUILT_CDB_FILES)
	mkdir -p ~/.supermegadoc
	cp $^ ~/.supermegadoc/

install: supermegadoc
	cp supermegadoc /usr/local/bin/

.PHONY: ri.cdb devhelp.cdb erdoc.cdb install_cdb
