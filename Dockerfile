# Image is reused in the workflow builds for master and the latest version
FROM docker.io/maven:3.9.8-eclipse-temurin-21-alpine AS build
ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3002
USER root

WORKDIR /tmp/ors

COPY ors-api /tmp/ors/ors-api
COPY ors-engine /tmp/ors/ors-engine
COPY pom.xml /tmp/ors/pom.xml
COPY ors-report-aggregation /tmp/ors/ors-report-aggregation

# Build the project
RUN mvn -q clean package -DskipTests

# build final image, just copying stuff inside
FROM docker.io/amazoncorretto:21.0.4-alpine3.20 AS publish

# Build ARGS
ARG UID=1000
ARG GID=1000
ARG ORS_HOME=/home/ors

# Set the default language
ENV LANG='en_US' LANGUAGE='en_US' LC_ALL='en_US'

# Setup the target system with the right user and folders.
RUN apk update && apk add --no-cache openssl bash yq jq  && \
    addgroup ors -g ${GID} && \
    mkdir -p ${ORS_HOME}/logs ${ORS_HOME}/files ${ORS_HOME}/graphs ${ORS_HOME}/elevation_cache  && \
    adduser -D -h ${ORS_HOME} -u ${UID} --system -G ors ors  && \
    chown ors:ors ${ORS_HOME} \
    # Give all permissions to the user
    && chmod -R 777 ${ORS_HOME}

# Copy over the needed bits and pieces from the other stages.
COPY --chown=ors:ors --from=build /tmp/ors/ors-api/target/ors.jar /ors.jar
COPY --chown=ors:ors ./docker-entrypoint.sh /entrypoint.sh

ENV BUILD_GRAPHS="False"
ENV REBUILD_GRAPHS="False"
# Set the ARG to an ENV. Else it will be lost.
ENV ORS_HOME=${ORS_HOME}

WORKDIR ${ORS_HOME}
# Start the container
ENTRYPOINT ["/entrypoint.sh"]
