PLATFORMS=$(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
VERSIONS=$(shell grep -Po 'FROM .*php:.*AS \Kphp.*' Dockerfile)
TESTS=$(subst php,test,$(VERSIONS))

.DEFAULT_GOAL := current
.PHONY: all check-doc clean current help _platforms test update-php-images-sha _versions $(VERSIONS) $(TESTS)

all: PLATFORMS=linux/amd64,linux/arm64
all: $(VERSIONS) ## Build Docker images for all PHP versions

current: $(VERSIONS)

help: ## Display a list of the public targets
	@grep -E -h "^[a-z-]+:.*##" $(MAKEFILE_LIST) | sed -e 's/\(.*\):.*## *\(.*\)/\1|\2/' | column -s '|' -t

_versions: ## Output versions as JSON list
	@echo $(strip $(subst php,,$(VERSIONS))) | jq --compact-output --raw-input 'split(" ") | map(select(. != ""))'

_platforms: ## Output platforms as JSON list
	@echo $(PLATFORMS) | jq --compact-output --raw-input 'split(",") | map(select(. != ""))'

$(VERSIONS): ## Build Docker image for PHP version
	docker buildx build --platform=$(PLATFORMS) --build-arg php=$(subst php,,$@) --file Dockerfile --tag ghcr.io/reload/php-fpm:$(subst php,,$@) --load .

test: $(TESTS) ## Run tests for ghcr.io/reload/php-fpm version

check-doc: README.md Dockerfile ## Check documentation
	./bin/check-doc.sh

update-php-images-sha: ## Update PHP images SHA
	./bin/update-php-images-sha.sh

$(TESTS): $(subst test,php,$@)
	dgoss run -e GOSS_VARS_INLINE='php_version: "$(subst test,,$@)"' ghcr.io/reload/php-fpm:$(subst test,,$@)
