# ── Build Stage ──────────────────────────────────────────────
FROM swift:6.0-jammy AS build

WORKDIR /build
COPY Package.swift Package.resolved ./
RUN swift package resolve

COPY Sources/ Sources/
COPY Tests/ Tests/
COPY Resources/ Resources/

RUN swift build -c release --static-swift-stdlib

# ── Runtime Stage ────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    libcurl4 libxml2 libz3-4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /build/.build/release/App /app/App
COPY --from=build /build/Resources /app/Resources
COPY --from=build /build/Public /app/Public

EXPOSE 8080

ENV SWIFT_LOG_LEVEL=info

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
