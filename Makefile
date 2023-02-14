# Makefile for the passwd project

# `a2x / asciidoc` is required to generate the Man page.
# `markdown` is required for the `docs` target, though it is not
# strictly necessary for packaging since unless you are planning on
# serving the docs on a web site they are more readable not as html.
# `shipper` and `gpg` are required for the `release` target, which
# should only be used if you are shipping tarballs (you probably are
# not).

# Get the version number
VERS := $(shell autorevision -s VCS_TAG -o ./passwd.cache | sed -e 's:v/::')
# Date for documentation
DOCDATE := $(shell autorevision -s VCS_DATE -o ./passwd.cache -f | sed -e 's:T.*::')

# Find a md5 program
MD5 := $(shell if command -v "md5" > /dev/null 2>&1; then echo "md5 -q"; elif command -v "md5sum" > /dev/null 2>&1; then echo "md5sum"; fi)

.SUFFIXES: .md .html

.md.html:
	markdown $< > $@


# `prefix`, `mandir` & `DESTDIR` can and should be set on the command line to control installation locations
prefix ?= /usr/local
mandir ?= /share/man
target = $(DESTDIR)$(prefix)


DOCS = \
	NEWS \
	NEWS.passwd-configs \
	update-passwd.asciidoc \
	README.md \
	README.passwd-configs.md \
	README.removing-users.md

SOURCES = \
	$(DOCS) \
	update-passwd.tool \
	Makefile \
	group-fink.conf.txt \
	passwd-fink.conf.txt

EXTRA_DIST = \
	passwd.conf \
	AUTHORS.txt \
	passwd.cache

all : cmd man conf

# The config files
conf: group-fink.conf passwd-fink.conf

# The script
cmd: update-passwd

# Set up the config files
group-fink.conf: group-fink.conf.txt
	sed -e 's:&&PRFIX&&:$(prefix):' $< > $@

passwd-fink.conf: passwd-fink.conf.txt
	sed -e 's:&&PRFIX&&:$(prefix):' $< > $@

# Insert the version number
update-passwd: update-passwd.tool
	sed -e 's:&&UPVERSION&&:$(VERS):g' -e 's:&&PRFIX&&:$(prefix):' update-passwd.tool > update-passwd
	chmod +x update-passwd

# The Man Page
man: update-passwd.1.gz

update-passwd.1.gz: update-passwd.1
	gzip --no-name < update-passwd.1 > update-passwd.1.gz

update-passwd.1: update-passwd.asciidoc
	a2x --attribute="revdate=$(DOCDATE)" --attribute="revnumber=$(VERS)" -f manpage update-passwd.asciidoc

# HTML representation of the man page
update-passwd.html: update-passwd.asciidoc
	asciidoc --attribute="revdate=$(DOCDATE)" --attribute="footer-style=revdate" --attribute="revnumber=$(VERS)" --doctype=manpage --backend=xhtml11 update-passwd.asciidoc

# Authors
auth: AUTHORS.txt

AUTHORS.txt: .mailmap update-passwd.cache
	git log --format='%aN <%aE>' | sort -f | uniq -c | sort -rn | sed 's:^ *[0-9]* *::' > AUTHORS.txt

passwd.sed: passwd.cache
	autorevision -f -t sed -o $< > $@

# The tarball signed and sealed
dist: tarball passwd-$(VERS).tgz.md5 passwd-$(VERS).tgz.sig

# The tarball
tarball: passwd-$(VERS).tgz

# Make an md5 checksum
passwd-$(VERS).tgz.md5: tarball
	$(MD5) passwd-$(VERS).tgz > passwd-$(VERS).tgz.md5

# Make a detached gpg sig
passwd-$(VERS).tgz.sig: tarball
	gpg --armour --detach-sign --output "passwd-$(VERS).tgz.sig" "passwd-$(VERS).tgz"

# The actual tarball
passwd-$(VERS).tgz: $(SOURCES) all auth
	mkdir passwd-$(VERS)
	cp -pR $(SOURCES) $(EXTRA_DIST) passwd-$(VERS)/
	@COPYFILE_DISABLE=1 GZIP=-n9 tar -czf passwd-$(VERS).tgz --exclude=".DS_Store" passwd-$(VERS)
	rm -fr passwd-$(VERS)

install: all
	install -d "$(target)/sbin"
	install -m 755 update-passwd "$(target)/sbin/update-passwd"
	install -d "$(target)$(mandir)/man1"
	install -m 644 update-passwd.1.gz "$(target)$(mandir)/man1/update-passwd.1.gz"
	install -d "$(target)/etc"
	install -m 644 group-fink.conf "$(target)/etc/group-fink.conf"
	install -m 644 passwd-fink.conf "$(target)/etc/passwd-fink.conf"
	install -m 644 passwd.conf "$(target)/etc/passwd.conf"

uninstall:
	rm -f "$(target)/sbin/update-passwd" "$(target)$(mandir)/man1/update-passwd.1.gz" "$(target)/etc/group-fink.conf" "$(target)/etc/passwd-fink.conf" "$(target)/etc/passwd.conf"

clean:
	rm -f update-passwd update-passwd.html update-passwd.1 update-passwd.1.gz
	rm -f update-passwd.sed logo.svg passwd-fink.conf group-fink.conf
	rm -f *.tgz *.md5 *.sig 
	rm -f docbook-xsl.css
	rm -f README.removing-users.html README.passwd-configs.html README.html
	rm -f *~ index.html

# Not safe to run in a tarball
devclean: clean
	rm -f passwd.cache
	rm -f AUTHORS AUTHORS.txt
	rm -f *.orig ./*/*.orig

# HTML versions of doc files suitable for use on a website
docs: \
	update-passwd.html \
	README.html \
	README.passwd-configs.html \
	README.removing-users.html

# Tag with `git tag -s v/<number>` before running this.
release: docs dist
	git tag -v "v/$(VERS)"
#	shipper version=$(VERS) | sh -e -x
