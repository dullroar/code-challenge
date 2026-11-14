# Container image for the .NET regex entry. Run it with: sandbox/container/run-image.sh src/regex-dotnet
# Build stage: the .NET SDK builds the program (no NuGet packages, so nothing to download). Runtime
# stage: the compiled dll on the .NET runtime only, with no SDK.
FROM code-challenge-sandbox:local AS build
USER root
WORKDIR /build
COPY RegexDotnet.csproj Program.cs ./
RUN dotnet build -c Release -v q --nologo -o /build/out

FROM cc-rt-dotnet:local
COPY --from=build /build/out /app
ENV CC_RUN="dotnet /app/RegexDotnet.dll"
