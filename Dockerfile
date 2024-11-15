FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS base

# Copy a sample docx for the purpose of the POC
COPY doc1.docx /home/app/doc1.docx


# With an internet machine you could do this
#RUN apt-get update \
#    && apt-get install -y default-jre libreoffice-java-common \
#    && apt-get install -y libreoffice-writer

#but without internet we copy all the packages and install them manually
WORKDIR /home/app
COPY ./packages/* /home/app/
RUN dpkg -i *.deb; exit 0


#revert back to non-root and carry-on
USER $APP_UID
WORKDIR /app
EXPOSE 8080


# This stage is used to build the service project
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["docx2pdf.csproj", "."]
RUN dotnet restore "./docx2pdf.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "./docx2pdf.csproj" -c $BUILD_CONFIGURATION -o /app/build

# This stage is used to publish the service project to be copied to the final stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./docx2pdf.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# This stage is used in production or when running from VS in regular mode (Default when not using the Debug configuration)
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "docx2pdf.dll"]