GOPATH = $(shell pwd -P)/go
GOARCH = arm
GOARM = 7
my_d = $(shell pwd -P)
minio_src := go/src/github.com/minio/minio

.PHONY: build
build: minio_arm_7 pkg_7

.PHONY: clean
clean:
	@rm -rf .git/modules .gitmodules
	@find . -type f -iname "*.tgz" -exec rm -rvf {} \;
	@find . -type f -iname "*.spk" -exec rm -rvf {} \;
	@find . -type f -iname "*.png" -exec rm -rvf {} \;
	@rm -rf go minio*linux*

.PHONY: init
init: artwork
	git clone https://github.com/minio/minio $(minio_src)
	cd $(minio_src) && \
		last_release=$$(git tag | sort -r | gawk '/RELEASE/{print$$1; exit;}') && \
		git checkout --force -b working $${last_release}

.PHONY: artwork
artzip = https://dl.minio.io/logo/Minio_Logo_Black.zip
artwork:
	docker run --rm -it -v $(my_d):/src alpine \
		sh -c 'set -x; apk add --update imagemagick wget unzip; \
			wget $(artzip); \
			unzip $(shell basename $(artzip)); \
			for size in 16 24 32 48 64 72 90 120 256; do \
		       		convert Minio_Logo_Black/Minio_Logo_Black.png -resize $${size}x$${size} \
				/src/1_create_package/ui/minio-$${size}.png;  \
			done; \
			cp /src/1_create_package/ui/minio-120.png /src/2_create_project/PACKAGE_ICON_120.PNG; \
			cp /src/1_create_package/ui/minio-256.png /src/2_create_project/PACKAGE_ICON_256.PNG; \
			cp /src/1_create_package/ui/minio-256.png /src/2_create_project/PACKAGE_ICON.PNG; '


last_release := $(shell cd $(minio_src) 2>&1 /dev/null && git tag | sort -r | gawk '/RELEASE/{print$$1; exit;}' || echo unknown)
date_release := $(shell echo $(last_release) | awk -F'T' '{gsub("RELEASE-", "", $$1); gsub("-",".", $$1); print$$1}')
pkg_version := $(subst RELEASE.,,$(date_release))

.PHONY: info
info:
	@echo "$(last_release) $(pkg_version)"

.PHONY: minio_arm_%
_docker_cmd = docker run --rm -it -v $(my_d)/$(minio_src):/$(minio_src) -v $(my_d):/out --workdir=/$(minio_src)
_docker_ctr = golang:stretch
minio_arm_%: LDFLAGS=$(shell $(_docker_cmd) $(_docker_ctr) bash -c "go run buildscripts/gen-ldflags.go")
minio_arm_%:
	@echo "Working on $(last_release)"
	@echo "Cross-compiling in Docker, this will take a few minutes"
	$(_docker_cmd) \
		--env CGO_ENABLED=0 \
		--env GOOS="linux" \
		--env GOARCH=arm \
		--env GOARM=$*\
		$(_docker_ctr) \
		go build -tags kqeue --ldflags '$(LDFLAGS)' -o /out/minio-$(pkg_version)-linux-arm-$*

.PHONY: pkg_%
pkg_%:
	sed -e "s/version=.*/version=\"$(pkg_version)\"/g" \
		2_create_project/INFO-e > 2_create_project/INFO
	mkdir -p 1_create_package/minio
	cp minio-$(pkg_version)-*$* 1_create_package/minio/minio
	cd 1_create_package && \
		tar cvfhz ../2_create_project/package.tgz *
	cd 2_create_project && \
		tar cvfz ../minio-$(pkg_version)-arm-7.spk --exclude=INFO.in *
	rm -f package.tgz
