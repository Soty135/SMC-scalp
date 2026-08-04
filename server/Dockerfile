FROM dart:stable AS build

WORKDIR /app

COPY pubspec.yaml .
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe main.dart -o /app/server

FROM dart:stable AS runtime
WORKDIR /app
COPY --from=build /app/server /app/server

EXPOSE 8080
CMD ["/app/server"]
