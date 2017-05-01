update: docs/CNAME
	hugo
	git add .
	git commit
	git push

server:
	hugo server

docs/CNAME:
	echo air.googol.im > docs/CNAME
