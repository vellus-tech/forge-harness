FROM mcr.microsoft.com/dotnet/aspnet:8.0
USER root
WORKDIR /app
COPY publish/ .
ENTRYPOINT ["dotnet", "Recarga.Api.dll"]
