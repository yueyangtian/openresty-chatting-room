.PHONY: install run
install:
	docker pull openresty/openresty
run:
	docker run --rm -p 8888:8888   -v ${PWD}:/etc/nginx/conf.d openresty/openresty