# Project Information
PROJECT_NAME ?= todobackend
ORG_NAME ?= alexandrosv
REPO_NAME ?= todobackend

# Directories
DEV_COMPOSE_FILE := docker/dev/docker-compose.yml
REL_COMPOSE_FILE := docker/release/docker-compose.yml

# Set unique project names
REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT)dev

.PHONY: test build release clean

test:
	$(INFO) "Building images for test..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build
	$(INFO) "Checking DB is up and running..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up agent
	$(INFO) "Running tests..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	$(INFO) "Tests completed"

build:
	$(INFO) "Building application artifacts..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	$(INFO) "Coping artifacts to target directory..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	$(INFO) "Build completed"

release:
	$(INFO) "Building images for release build..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build
	$(INFO) "Checking DB is up and running..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up agent
	$(INFO) "Bootstrapping application -> transferring static content..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	$(INFO) "Bootstrapping application -> creating DB tables..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	$(INFO) "Running Acceptance Tests..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	$(INFO) "Acceptance testing completed"

clean:
	$(INFO) "Destroying development environment..."
	@ docker-compose -p $(REL_PROJECT) -f $(DEV_COMPOSE_FILE) kill
	@ docker-compose -p $(REL_PROJECT) -f $(DEV_COMPOSE_FILE) rm -f -v
	$(INFO) "Destroying release environment..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) kill
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) rm -f -v
	$(INFO) "Deleting dangling images..."
	@ docker images -q -f dangling=true -f label=application=$(REPO_NAME) | xargs -I ARGS docker rmi -f ARGS
	$(INFO) "Clean completed"

# Visual improvements
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Prints info messages. @-> supress outputting of the literal command
INFO := @bash -c '\
 printf $(YELLOW); \
 echo "=> $$1"; \
 printf $(NC)' MESSAGE
