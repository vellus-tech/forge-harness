FROM mcr.microsoft.com/dotnet/sdk:latest AS build
WORKDIR /src
COPY src/ ./src/
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet publish src/Validacao.Api/Validacao.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "Validacao.Api.dll"]
