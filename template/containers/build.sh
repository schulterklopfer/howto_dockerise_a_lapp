docker build bitcoind -t bitcoind:latest && \
docker build lnd -t lnd:latest -t lnd:0.4-beta && \
docker build lapp_base -t lapp_base:latest && \
docker build lapp -t lapp:latest