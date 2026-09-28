FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /app
COPY . .
RUN dotnet publish src/Pagamentos.Api -c Release -o out
EXPOSE 8080
ENTRYPOINT ["dotnet", "out/Pagamentos.Api.dll"]
