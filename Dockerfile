FROM ubuntu:26.10 AS base

ENV WINEPREFIX="/root/.wine"
ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN printf 'Acquire::Retries "10";\nAcquire::http::Timeout "120";\nAcquire::https::Timeout "120";\n' > /etc/apt/apt.conf.d/80-retries-timeouts

RUN mkdir -pm755 /etc/apt/keyrings

RUN apt update

RUN apt install -y wget lsb-release xvfb x11vnc ca-certificates

RUN wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

RUN wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/$(lsb_release -cs)/winehq-$(lsb_release -cs).sources"

COPY vendor vendor

RUN --mount=type=bind,source=vendor,target=/vendor \
    apt install -y /vendor/wine-staging_11.22~stonking-1_amd64.deb

RUN apt update && \
    apt install -y --install-recommends winehq-staging

RUN xvfb-run -a wineboot --init

# Workaround: wineboot times out ("boot event wait timed out") before
# populating the 32-bit side of this WoW64-only build's prefix, leaving
# syswow64 empty and breaking 32-bit apps (e.g. MT4) with
# "could not load kernel32.dll, status c0000135".
RUN cp -rn /opt/wine-staging/lib/wine/i386-windows/. "$WINEPREFIX/drive_c/windows/syswow64/"

FROM base AS runtime

ENV WINEPREFIX="/root/.wine"
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh
RUN wget -O /tmp/mt4setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4setup.exe
RUN wget -O /tmp/mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
# The MetaQuotes installers exit non-zero even on success (their final
# "launch terminal" step fails headlessly), so ignore the exit code and
# verify the install by checking for the terminal executable instead.
RUN (xvfb-run -a wine /tmp/mt5setup.exe /auto || true) && \
    sleep 5 && (wineserver -k || true) && sleep 2 && \
    test -f "$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe" && \
    rm -f /tmp/mt5setup.exe

RUN (xvfb-run -a wine /tmp/mt4setup.exe /auto || true) && \
    sleep 5 && (wineserver -k || true) && sleep 2 && \
    find "$WINEPREFIX/drive_c" -iname "terminal.exe" | grep -q . && \
    rm -f /tmp/mt4setup.exe

EXPOSE 5900

ENTRYPOINT [ "./entrypoint.sh" ]
CMD ["mt4"]
