# Project Information (?= -> set if absent; := -> set with simple expansion of values inside)
PROJECT_NAME ?= todobackend
ORG_NAME ?= alexandrosv
REPO_NAME ?= todobackend

# Directories
DEV_COMPOSE_FILE := docker/dev/docker-compose.yml
REL_COMPOSE_FILE := docker/release/docker-compose.yml

# Set unique project names
REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT)dev

# It must match the Docker compose release specification application service name
APP_SERVICE_NAME := app

# Shell expression to be evaluated during runtime. UTC timestamp
BUILD_TAG_EXPRESSION ?= date -u +%Y%m%d%H%M%S

# Evaluation of BUILD_TAG_EXPRESSION
BUILD_EXPRESSION := $(shell $(BUILD_TAG_EXPRESSION))

# Final build tag. The '?=' operator is used so the dafault value can be override by a BUIL_TAG env. variable
BUILD_TAG ?= $(BUILD_EXPRESSION)

# Error & failure handling
INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
  if [[ $(INSPECT) -ne 0 ]]; \
  then exit $(INSPECT); fi' CODE

# If absent set to public Dicker hub registry
DOCKER_REGISTRY ?= docker.io

# For Docker Hub: It must be empty so se can use an authentication URL
DOCKER_REGISTRY_AUTH ?=

.PHONY: test build release clean tag buildtag login logout publish

test:
	${INFO} "Pulling latest images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull
	${INFO} "Building images for test..."
	# --pull ensures that dinamically created images are the latest
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test
	# cache version should be frozen until workflow is finished
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build cache
	${INFO} "Checking DB is up and running..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running tests..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Tests completed"

build:
	${INFO} "Building application artifacts..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Coping artifacts to target directory..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	${INFO} "Build completed"

release:
	${INFO} "Pulling latest images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test
	${INFO} "Building images for release build..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build app
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build webroot
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx
	${INFO} "Checking DB is up and running..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up agent
	${INFO} "Bootstrapping application -> transferring static content..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	${INFO} "Bootstrapping application -> creating DB tables..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	${INFO} "Running Acceptance Tests..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(REL_PROJECT) $(REL_COMPOSE_FILE) test
	${INFO} "Acceptance testing completed"

clean:
	${INFO} "Destroying development environment..."
	@ docker-compose -p $(REL_PROJECT) -f $(DEV_COMPOSE_FILE) kill
	@ docker-compose -p $(REL_PROJECT) -f $(DEV_COMPOSE_FILE) rm -f -v
	${INFO} "Destroying release environment..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) kill
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) rm -f -v
	${INFO} "Deleting dangling images..."
	@ docker images -q -f dangling=true -f label=application=$(REPO_NAME) | xargs -I ARGS docker rmi -f ARGS
	${INFO} "Clean completed"

# https://www.gnu.org/software/make/manual/html_node/Foreach-Function.html
# make tag 0.1 latest ->
#   docker tag <image id> <registry>/<org>/<repo>:0.1
#   docker tag <image id> <registry>/<org>/<repo>:latest
tag:
	${INFO} "Tagging release image. Tags: $(TAG_ARGS)..."
	@ $(foreach tag,$(TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	${INFO} "Tagging completed"

buildtag:
	${INFO} "Tagging release image: suffix $(BUILD_TAG) and build tags $(BUILDTAG_ARGS)"
	@ $(foreach tag,$(BUILDTAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag).$(BUILD_TAG);)
	${INFO} "Tagging completed"

login:
	${INFO} "Logging in to Docker registry $$DOCKER_REGISTRY..."
	@docker login -u $$DOCKER_USER -p $$DOCKER_PASSWORD -e $$DOCKER_EMAIL $(DOCKER_REGISTRY_AUTH)
	${INFO} "Logged in to Docker registry $$DOCKE_REGISTRY"

logout:
	${INFO} "Logging out Docker registry $$DOCKER_REGISTRY..."
	@ docker logout
	${INFO} "Logged out of Docker registry $$DOCKER_REGISTRY"

publish:
	${INFO} "Publishing release image $(IMAGE_ID) to $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)..."
	@ $(foreach tag,$(shell echo $(REPO_EXPR)), docker push $(tag);)
	${INFO} "Publish completed"

# Visual improvements
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Prints info messages. @ -> supress outputting of the literal command; -c -> commands are read from a string
INFO := @bash -c '\
 printf $(YELLOW); \
 echo "=> $$1"; \
 printf $(NC)' MESSAGE


# Get container id of the application server id
APP_CONTAINER_ID := $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

# Get image id if application service
IMAGE_ID := $$(docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))

# Regular expression for filtering tags (i.e. todobackend_app:latest & todobackend_webroot:latest need to be excluded)
ifeq ($(DOCKER_REGISTRY), docker.io)
  REPO_FILTER := $(ORG_NAME)/$(REPO_NAME)[^[:space:]|$$]*
else
  REPO_FILTER := $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)[[^:space:]|$$]*
endif

# Get repositories to push
# docker inspect -f '{{ range.RepoTags }}{{.}} {{end}}' 28b4c583a812
# alexandrosv/todobackend:0.1 alexandrosv/todobackend:0.1.20170624145158 alexandrosv/todobackend:c812925
# alexandrosv/todobackend:latest alexandrosv/todobackend:master.20170624145158 *(todobackend_app:latest
# todobackend_webroot:latest) *last two are excluded by REPO_FILTER
REPO_EXPR := $$(docker inspect -f '{{ range.RepoTags }}{{.}} {{end}}' $(IMAGE_ID) | grep -oh "$(REPO_FILTER)" | xargs)

# Getting arguments for tag goal(instruction)
# https://www.gnu.org/software/make/manual/html_node/Conditional-Example.html
# https://www.gnu.org/software/make/manual/html_node/Goals.html
# https://www.gnu.org/software/make/manual/html_node/Text-Functions.html
# I.e. make tag 1.0 latest -> $(MAKECMDGOALS) = tag 1.0 latest ; $(firstword $(MAKECMDGOAL) = tag
# words -> count of MAKECMDGOALS ; wordlist -> 1.0 latest
ifeq (tag, $(firstword $(MAKECMDGOALS)))
  TAG_ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifeq ($(TAG_ARGS),)
    $(ERROR => tag not specified)
  endif
  # @ -> So 1.0 latest are not specified are make target files
  $(eval $(TAG_ARGS):;@:)
endif

# Getting arguments for buildtag goal
ifeq (buildtag, $(firstword $(MAKECMDGOALS)))
  BUILDTAG_ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifeq ($(BUILDTAG_ARGS),)
    $(ERROR => tag not specified)
  endif
  # @ -> So 1.0 latest are not specified are make target files
  $(eval $(BUILDTAG_ARGS):;@:)
endif