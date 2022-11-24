export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

PLATFORMS=$(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
VERSIONS=$(shell ls --ignore-backups | grep -E '^Dockerfile-' | sed 's/Dockerfile-/php/')
TESTS=$(subst php,test,$(VERSIONS))

.DEFAULT_GOAL := current
.PHONY: all clean current help _platforms test _versions $(VERSIONS) $(TESTS)

all: PLATFORMS=linux/amd64,linux/arm64
all: $(VERSIONS) ## Build Docker images for all PHP versions

current: $(VERSIONS)

help: ## Display a list of the public targets
	@grep -E -h "^[a-z]+:.*##" $(MAKEFILE_LIST) | sed -e 's/\(.*\):.*## *\(.*\)/\1|\2/' | column -s '|' -t

_versions: ## Output versions as JSON list
	@echo $(strip $(subst php,,$(VERSIONS))) | jq --compact-output --raw-input 'split(" ") | map(select(. != ""))'

_platforms: ## Output platforms as JSON list
	@echo $(PLATFORMS) | jq --compact-output --raw-input 'split(",") | map(select(. != ""))'

$(VERSIONS): ## Build Docker image for PHP version
	docker buildx build --platform=$(PLATFORMS) --file Dockerfile-$(subst php,,$@) --tag ghcr.io/reload/php-fpm:$(subst php,,$@) --load .

test: $(TESTS) ## Run tests for ghcr.io/reload/php-fpm version

$(TESTS): $(subst test,php,$@)
	dgoss run -e PHP_VERSION=$(subst test,,$@) ghcr.io/reload/php-fpm:$(subst test,,$@)
