# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY BepTroLy.API/*.csproj ./BepTroLy.API/
RUN dotnet restore "./BepTroLy.API/BepTroLy.API.csproj"
COPY BepTroLy.API/. ./BepTroLy.API/
WORKDIR /src/BepTroLy.API
RUN dotnet publish -c Release -o /app/publish

# Runtime Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
ENTRYPOINT ["dotnet", "BepTroLy.API.dll"]
