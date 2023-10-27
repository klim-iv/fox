FROM ruby:2.7.4

RUN apt update; \
    apt-get install --yes \
        vim mc \
        ffmpeg

EXPOSE 4567

WORKDIR /fox
COPY ./web /fox
RUN bundle install

CMD ["/fox/start.bash", "-n"]
