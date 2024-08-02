update: docs/CNAME
	hugo
	git add .
	git commit
	git push

server:
	hugo server

init:
	git submodule update --init --recursive --remote

docs/CNAME:
	echo air.googol.im > docs/CNAME
