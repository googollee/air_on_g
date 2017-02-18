update:
	rm -rf ./docs
	hugo
	git add .
	git commit
	git push

server:
	hugo server
