# Inherith base docker image
FROM alexandrosv/todobackend-base:latest
MAINTAINER Alejandro Villamarin <favm@email.com>

# Install python dev dependencies
RUN apt-get update && \
    apt-get install -qy python-dev libmysqlclient-dev

# Install Wheel package (it's used to creating python packages)
RUN . /appenv/bin/activate && \
    pip install wheel --upgrade

# Environmental variable for Wheel
ENV WHEELHOUSE=/wheelhouse PIP_WHEEL_DIR=/wheelhouse PIP_FIND_LINKS=/wheelhouse XDG_CACHE_HOME=/cache

# Directory for Wheel's build artifacts
VOLUME /wheelhouse

# Directory for build cache
VOLUME /build

# Directory for test reports
VOLUME /reports

# Copy test.sh as entrypoint script
COPY scripts/test.sh /usr/local/bin/test.sh
RUN chmod +x /usr/local/bin/test.sh
ENTRYPOINT ["test.sh"]
# Command string
CMD ["python", "manage.py", "test", "--noinput"]
# ^^^ End of Cached Section ^^^

# Copy application source code
COPY src /application
WORKDIR /application