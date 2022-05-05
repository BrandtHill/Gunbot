FROM alpine

RUN apk upgrade --no-cache && \
    apk add --no-cache postgresql-client bash openssl libgcc libstdc++ ncurses-libs

WORKDIR /app
COPY ./_build/prod/rel/gunbot ./

ENTRYPOINT ["./bin/gunbot"]
CMD ["start"]
