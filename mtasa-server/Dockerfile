FROM debian:bookworm
RUN apt-get update && apt-get install -y wget curl ca-certificates libncursesw5 unzip dos2unix

RUN wget https://nightly.multitheftauto.com/multitheftauto_linux_x64-1.6.0-rc-22076.tar.gz && \
    tar -xzf multitheftauto_linux_x64-1.6.0-rc-22076.tar.gz && \
    rm multitheftauto_linux_x64-1.6.0-rc-22076.tar.gz && \
    mv multitheftauto_linux_x64-1.6.0-rc-22076 mtasa
WORKDIR /mtasa

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN dos2unix /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
