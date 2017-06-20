FROM alexandrosv/todobackend-base:latest
MAINTAINER Alejandro Villamarin <favm@email.com>

# Copy application binaries
COPY target /wheelhouse

# Install application
RUN . /appenv/bin/activate && \
    pip install --no-index -f /wheelhouse todobackend && \
    rm -rf /wheelhouse