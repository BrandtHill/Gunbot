FROM alpine

RUN apk add --no-cache bash

WORKDIR /app
COPY ./_build/prod/rel/gunbot ./

ENTRYPOINT ["./bin/gunbot"]
CMD ["start"]
