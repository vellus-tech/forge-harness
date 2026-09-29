FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Pagamentos.Api -c Release -o /app/out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
RUN adduser --disabled-password --gecos "" appuser
COPY --from=build /app/out .
USER appuser
EXPOSE 8080
ENTRYPOINT ["dotnet", "Pagamentos.Api.dll"]
