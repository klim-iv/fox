FROM ruby:2.7.4

RUN apt update; \
    apt-get install --yes \
        vim mc \
        ffmpeg
RUN cd /tmp; \
    git clone https://github.com/nginx/nginx.git; \
    cd nginx; \
    git checkout release-1.25.3; \
	auto/configure --with-http_mp4_module --prefix=/usr/local --sbin-path=/usr/local/bin; \
	make; \
	make install

EXPOSE 4567

WORKDIR /fox
COPY ./web /fox
RUN bundle install

CMD ["/fox/start.bash", "-e", "/Downloads"]
