export PATH := ./node_modules/.bin:../node_modules/.bin:../../node_modules/.bin:$(PATH)

all: index.html bundle.js

VPATH = src

%.html: %.jade Makefile package.yaml
	jade -D -p $< < $< > $@

%.js: %.coffee Makefile package.yaml
	coffee -o . -c $<

bundle.js: clanwars.js
	cat src/*.js clanwars.js | uglifyjs > $@
