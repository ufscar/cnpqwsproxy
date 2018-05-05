#!/bin/bash
PATH="/usr/local/openresty/nginx/sbin:$PATH"
case "$1" in
	start)
		LUA_PATH="?;?.lua"
		for lib in lualibs/*; do
		    LUA_PATH="$LUA_PATH;$lib/?;$lib/?.lua"
		done
		export LUA_PATH
		exec nginx -p `pwd`/ -c conf/nginx.conf
		;;
	stop|quit|reopen|reload)
		exec nginx -p `pwd`/ -s "$1"
		;;
	*)
		echo "usage: $0 start|stop|quit|reopen|reload"
		exit 1
esac
