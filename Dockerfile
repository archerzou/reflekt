# syntax=docker/dockerfile:1
#
# Single-image build for Reflekt: the .NET API serves the built Vue SPA from its
# own wwwroot, so one container runs the whole app (API + SignalR + web UI).
# SQLite lives in /app/data — mount a volume there to persist it.

# ---- Stage 1: build the Vue SPA ----
FROM node:22-alpine AS web
WORKDIR /web
# Install deps first for layer caching
COPY web/reflekt-web/package.json web/reflekt-web/package-lock.json ./
RUN npm ci
COPY web/reflekt-web/ ./
# Build to a clean folder; --outDir overrides the repo-relative path in vite.config.ts
RUN npm run build-only -- --outDir dist --emptyOutDir

# ---- Stage 2: restore, build and publish the .NET API ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
# Drop the built SPA into the API's wwwroot so `dotnet publish` packages it
COPY --from=web /web/dist ./src/Services/Reflekt/Reflekt.API/wwwroot
RUN dotnet publish src/Services/Reflekt/Reflekt.API/Reflekt.API.csproj \
      -c Release -o /app/publish /p:UseAppHost=false

# ---- Stage 3: runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
# curl is only here for the compose healthcheck
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/publish ./
# SQLite database directory (ConnectionStrings:Reflekt = Data Source=./data/reflekt.db)
RUN mkdir -p /app/data
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Reflekt.API.dll"]
