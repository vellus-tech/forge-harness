# syntax=docker/dockerfile:1.7
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
ARG TARGETARCH
ARG TARGETOS
WORKDIR /src
COPY src/ ./src/
RUN --mount=type=cache,target=/root/.nuget/packages,id=nuget-${TARGETARCH} \
    dotnet restore src/Validacao.Api/Validacao.Api.csproj -a $TARGETARCH
RUN --mount=type=cache,target=/root/.nuget/packages,id=nuget-${TARGETARCH} \
    dotnet publish src/Validacao.Api/Validacao.Api.csproj -c Release -a $TARGETARCH -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0.7-alpine AS runtime
RUN apk update && apk upgrade --no-cache && \
    addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser
WORKDIR /app
COPY --from=build /app/publish .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --tries=1 -T 5 -O /dev/null http://127.0.0.1:8080/health/live || exit 1
ENTRYPOINT ["dotnet", "Validacao.Api.dll"]
