FROM debian:stable-slim
RUN apt-get -qq update; \
 apt-get install --no-install-recommends -y devscripts equivs; \
 rm -rf /var/lib/apt/lists/*; \
 apt-get clean;
COPY debian/control debian/control
COPY debian/changelog debian/changelog
RUN dch -r -m '';
RUN apt-get -qq update && \
 mk-build-deps --install \
 --tool 'apt-get -y -o Debug:pkgProblemResolver=yes --no-install-recommends' \
 debian/control && \
 rm -rf /var/lib/apt/lists/* && \
 apt-get clean;
COPY . debbugs