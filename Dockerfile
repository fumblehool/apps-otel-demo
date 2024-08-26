# Use the official OpenTelemetry Collector Contrib base image
FROM otel/opentelemetry-collector-contrib:0.107.0 AS base

# Use Alpine as the build stage to generate the config file
FROM alpine:3.18 AS config-generator

# Set the working directory
WORKDIR /app

# Create the conf directory and the config file using cat
RUN mkdir -p conf && \
    cat > conf/relay.yaml <<EOL
exporters:
  debug:
    verbosity: detailed
  prometheusremotewrite:
    endpoint: http://144.126.250.22:9090/api/v1/write
    resource_to_telemetry_conversion:
      enabled: true
    retry_on_failure:
      enabled: true
    tls:
      insecure: true
extensions:
  health_check:
    endpoint: \${env:MY_POD_IP}:13133
processors:
  batch:
    send_batch_max_size: 16384
    send_batch_size: 8192
  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
receivers:

service:
  extensions:
  - health_check
  pipelines:
    metrics:
      exporters:
      - debug
      - prometheusremotewrite
      processors:
      - memory_limiter
      receivers:
      - kubeletstats
  telemetry:
    logs:
      level: debug
    metrics:
      address: 0.0.0.0:8888
EOL

# Use the base stage as the final image
FROM base

# Copy the generated config file from the config-generator stage
COPY --from=config-generator /app/conf/relay.yaml /conf/relay.yaml
