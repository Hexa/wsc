ARG os

FROM hexa/crystal:$os

ARG branch

RUN git clone -b $branch https://github.com/Hexa/wsc.git

WORKDIR /wsc

RUN crystal build src/wsc.cr --release

FROM scratch

COPY --from=0 /wsc/wsc /wsc
