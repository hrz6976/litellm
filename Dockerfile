ARG LITELLM_WEB_IMAGE=node:18-alpine
# Base image for building
ARG LITELLM_BUILD_IMAGE=cgr.dev/chainguard/python:latest-dev
# Runtime image
ARG LITELLM_RUNTIME_IMAGE=cgr.dev/chainguard/python:latest-dev

FROM $LITELLM_WEB_IMAGE AS web-builder

# Install deps
WORKDIR /app
COPY ./ui/litellm-dashboard/package.json /app/package.json
COPY ./ui/litellm-dashboard/package-lock.json /app/package-lock.json
RUN npm ci

# Build the app
COPY ./ui/litellm-dashboard /app
RUN npm run build

# Builder stage
FROM $LITELLM_BUILD_IMAGE AS builder

# Set the working directory to /app
WORKDIR /app
USER root

# Install build dependencies
RUN apk update && \
    apk add --no-cache gcc python3-dev openssl openssl-dev

RUN pip install --upgrade pip && \
    pip install build

# Copy the current directory contents into the container at /app
COPY requirements.txt .

# Download dependencies
RUN pip wheel --no-cache-dir --wheel-dir=/wheels/ -r requirements.txt

# Build Admin UI
COPY --from=web-builder /app/out /app/litellm/proxy/_experimental/out

# Copy the current directory contents into the container at /app
COPY pyproject.toml poetry.lock README.md ./
COPY enterprise ./enterprise
COPY litellm ./litellm

# Build the package
RUN rm -rf dist/* && python -m build

# There should be only one wheel file now, assume the build only creates one
RUN ls -1 dist/*.whl | head -1

# Install the package
RUN pip install dist/*.whl

# install semantic-cache [Experimental]- we need this here and not in requirements.txt because redisvl pins to pydantic 1.0 
RUN pip install redisvl==0.0.7 --no-deps

# ensure pyjwt is used, not jwt
RUN pip uninstall jwt -y
RUN pip uninstall PyJWT -y
RUN pip install PyJWT==2.9.0 --no-cache-dir

# Runtime stage
FROM $LITELLM_RUNTIME_IMAGE AS runtime

# Ensure runtime stage runs as root
USER root

# Install runtime dependencies
RUN apk update && \
    apk add --no-cache openssl

WORKDIR /app
# Copy the current directory contents into the container at /app
COPY . .
RUN ls -la /app

# Copy the built wheel from the builder stage to the runtime stage; assumes only one wheel file is present
COPY --from=builder /app/dist/*.whl .
COPY --from=builder /wheels/ /wheels/

# Install the built wheel using pip; again using a wildcard if it's the only file
RUN pip install *.whl /wheels/* --no-index --find-links=/wheels/ && rm -f *.whl && rm -rf /wheels

# Generate prisma client
RUN prisma generate
RUN chmod +x docker/entrypoint.sh
RUN chmod +x docker/prod_entrypoint.sh

EXPOSE 4000/tcp

ENTRYPOINT ["docker/prod_entrypoint.sh"]

# Append "--detailed_debug" to the end of CMD to view detailed debug logs 
CMD ["--port", "4000"]
